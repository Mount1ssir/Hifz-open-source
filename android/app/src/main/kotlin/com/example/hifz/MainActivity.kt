package com.example.hifz

import android.os.SystemClock
import android.Manifest
import android.content.pm.PackageManager
import android.media.AudioFormat
import android.media.AudioRecord
import android.view.WindowManager
import kotlin.math.abs
import kotlin.math.sqrt
import android.media.MediaRecorder
import com.k2fsa.sherpa.onnx.*
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Semaphore
import java.util.concurrent.TimeUnit
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

class MainActivity : FlutterActivity() {
    private lateinit var channel: MethodChannel
    private val worker = Executors.newSingleThreadExecutor()
    private var engine: OfflineRecognizer? = null // accessed on worker only
    @Volatile private var active: Int? = null
    private var permissionRequest: Int? = null
    private val rate = 16000

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "hifz/device").setMethodCallHandler { call, reply ->
            if (call.method == "timeZone") reply.success(java.util.TimeZone.getDefault().id)
            else reply.notImplemented()
        }
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "hifz/recitation")
        channel.setMethodCallHandler { call, reply ->
            val id = call.arguments as? Int
            when (call.method) {
                "start" -> {
                    if (id == null || permissionRequest != null) {
                        reply.error("busy", null, null)
                    } else {
                        active = id
                        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED) {
                            listen(id)
                        } else {
                            permissionRequest = id
                            requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), 4827)
                        }
                        reply.success(null)
                    }
                }
                "stop" -> { if (id != null) endSession(id); reply.success(null) }
                else -> reply.notImplemented()
            }
        }
    }

    override fun onRequestPermissionsResult(code: Int, permissions: Array<out String>, results: IntArray) {
        super.onRequestPermissionsResult(code, permissions, results)
        if (code != 4827) return
        val id = permissionRequest ?: return
        permissionRequest = null
        if (active != id) return
        if (results.firstOrNull() == PackageManager.PERMISSION_GRANTED) listen(id)
        else fail(id, "permission")
    }

    private fun endSession(id: Int) {
        if (active != id) return
        active = null
        window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }

    private fun openMicrophone(): AudioRecord {
        val minBytes = AudioRecord.getMinBufferSize(rate, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT)
        val recorder = AudioRecord(MediaRecorder.AudioSource.VOICE_RECOGNITION, rate,
            AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT, maxOf(minBytes, rate * 2))
        try {
            check(recorder.state == AudioRecord.STATE_INITIALIZED)
            recorder.startRecording()
            check(recorder.recordingState == AudioRecord.RECORDSTATE_RECORDING)
            return recorder
        } catch (error: Exception) {
            recorder.release()
            throw error
        }
    }

    private fun fail(id: Int, reason: String) = runOnUiThread {
        if (active == id) {
            endSession(id)
            channel.invokeMethod("failure", mapOf("id" to id, "reason" to reason))
        }
    }

    private fun listen(id: Int) = worker.execute {
        var mic: AudioRecord? = null
        var capture: Thread? = null
        val running = AtomicBoolean(true)
        try {
            if (active != id) return@execute
            val recognizer = engine ?: OfflineRecognizer(assets, OfflineRecognizerConfig(
                modelConfig = OfflineModelConfig(
                    zipformerCtc = OfflineZipformerCtcModelConfig(model = "quran-asr/model.int8.onnx"),
                    tokens = "quran-asr/tokens.txt", numThreads = 2
                )
            )).also { engine = it }
            if (active != id) return@execute
            mic = openMicrophone()
            // Retain capture while inference is busy. Decode overlapping spans in
            // sample order even if a decode takes longer than the nominal hop.
            val ring = FloatArray(rate * 60)
            val available = Semaphore(0)
            var written = 0L
            capture = Thread {
                val chunk = ShortArray(rate / 20)
                try {
                    var lastSample = SystemClock.elapsedRealtime()
                    var restarts = 0
                    while (running.get() && active == id) {
                        val recorder = mic ?: break
                        val n = recorder.read(chunk, 0, chunk.size, AudioRecord.READ_NON_BLOCKING)
                        if (n <= 0) {
                            if (n == 0 && SystemClock.elapsedRealtime() - lastSample < 2500) {
                                Thread.sleep(12)
                                continue
                            }
                            // Some drivers return zero indefinitely after a transient
                            // capture error. Reopen the input without resetting the follower.
                            check(++restarts <= 3)
                            try { recorder.stop() } catch (_: IllegalStateException) {}
                            recorder.release()
                            mic = null
                            Thread.sleep(100L * restarts)
                            if (active == id && running.get()) mic = openMicrophone()
                            lastSample = SystemClock.elapsedRealtime()
                            continue
                        }
                        lastSample = SystemClock.elapsedRealtime()
                        restarts = 0
                        synchronized(ring) {
                            for (i in 0 until n) {
                                ring[(written++ % ring.size).toInt()] = chunk[i] / 32768f
                            }
                        }
                        available.release()
                    }
                } catch (_: Exception) {
                    if (running.get()) fail(id, "audio")
                } finally { running.set(false) }
            }.also { it.start() }
            runOnUiThread { if (active == id) {
                window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                channel.invokeMethod("ready", mapOf("id" to id))
            } }
            data class HeardWord(val text: String, val startMs: Long)
            var previous = emptyList<HeardWord>()
            var processed = 0L
            var decodeFailures = 0
            var contextSeconds = 8
            while (active == id && running.get()) {
                if (!available.tryAcquire(200, TimeUnit.MILLISECONDS)) continue
                available.drainPermits()
                val window = synchronized(ring) {
                    if (written - processed < rate / 2) null else {
                        val oldest = maxOf(0L, written - ring.size)
                        processed = minOf(written, maxOf(processed, oldest) + rate * contextSeconds / 2)
                        val start = maxOf(oldest, processed - rate * contextSeconds)
                        val size = (processed - start).toInt()
                        val offset = (start % ring.size).toInt()
                        val first = minOf(size, ring.size - offset)
                        val samples = FloatArray(size)
                        ring.copyInto(samples, 0, offset, offset + first)
                        if (first < size) ring.copyInto(samples, first, 0, size - first)
                        start to samples
                    }
                } ?: continue
                val stream = recognizer.createStream()
                try {
                    val samples = window.second
                    var power = 0.0
                    var peak = 0f
                    for (sample in samples) {
                        power += sample * sample
                        peak = maxOf(peak, abs(sample))
                    }
                    val rms = sqrt(power / samples.size)
                    val tail = minOf(rate / 3, samples.size)
                    var tailPower = 0.0
                    for (i in samples.size - tail until samples.size) tailPower += samples[i] * samples[i]
                    val quiet = sqrt(tailPower / tail) < maxOf(0.0004, rms * 0.30)
                    // Raise quiet input within peak headroom; measure pauses
                    // before modifying the waveform used for inference.
                    if (rms > 0.0002 && peak > 0) {
                        val gain = minOf(12.0, 0.055 / rms, 0.94 / peak).coerceAtLeast(1.0).toFloat()
                        if (gain > 1f) for (i in samples.indices) samples[i] *= gain
                    }
                    stream.acceptWaveform(samples, rate)
                    val decodeStart = SystemClock.elapsedRealtime()
                    recognizer.decode(stream)
                    // Keep overlapping audio even when the phone slows down under heat.
                    val decodeMs = SystemClock.elapsedRealtime() - decodeStart
                    if (decodeMs > contextSeconds * 400L && contextSeconds > 5) contextSeconds--
                    else if (decodeMs < 700 && contextSeconds < 8) contextSeconds++
                    val result = recognizer.getResult(stream)
                    decodeFailures = 0
                    val tokens = result.tokens
                    val times = result.timestamps
                    // A partial hypothesis without alignments cannot advance the cursor.
                    if (tokens.size != times.size) continue
                    val words = mutableListOf<HeardWord>()
                    var startMs = 0L
                    val word = StringBuilder()
                    fun flush() {
                        if (word.isNotEmpty()) {
                            words.add(HeardWord(word.toString(), startMs))
                            word.clear()
                        }
                    }
                    for (i in tokens.indices) {
                        for (letter in tokens[i]) {
                            if (letter == '▁' || letter.isWhitespace()) flush() else {
                                if (word.isEmpty()) startMs = window.first * 1000 / rate + (times[i] * 1000).toLong()
                                word.append(letter)
                            }
                        }
                    }
                    flush()
                    // A window can predict a complete word while the learner is still
                    // pronouncing it. Confirm it in overlapping audio and wait for a
                    // following word or a quiet ending before revealing the last word.
                    val endMs = (window.first + samples.size) * 1000 / rate
                    // CTC can emit its final character at the window edge even in silence.
                    // Use measured trailing silence rather than that character timestamp.
                    val confirmed = words.filterIndexed { i, candidate ->
                        (i < words.lastIndex || (quiet && endMs - candidate.startMs >= 400)) &&
                            previous.any { it.text == candidate.text && abs(it.startMs - candidate.startMs) < 210 }
                    }.map { mapOf("text" to it.text, "ms" to it.startMs) }
                    previous = words
                    if (confirmed.isNotEmpty()) runOnUiThread {
                        if (active == id) channel.invokeMethod("words", mapOf("id" to id, "words" to confirmed))
                    }
                } catch (error: RuntimeException) {
                    if (++decodeFailures >= 3) throw error
                    previous = emptyList()
                } finally { stream.release() }
            }
        } catch (_: Exception) { fail(id, "audio") }
          catch (_: LinkageError) { fail(id, "model") }
        finally {
            running.set(false)
            capture?.join()
            try { mic?.stop() } catch (_: IllegalStateException) {}
            mic?.release()
        }
    }

    override fun onStop() {
        active?.let { if (permissionRequest == null) fail(it, "stopped") }
        super.onStop()
    }

    override fun onDestroy() {
        active = null
        worker.execute { engine?.release(); engine = null }
        worker.shutdown()
        super.onDestroy()
    }
}
