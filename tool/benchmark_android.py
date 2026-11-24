"""Measure existing-install Hifz startup without clearing app data."""
import argparse
import json
from pathlib import Path
import re
import shutil
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
PACKAGE = "com.example.hifz"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--serial", help="ADB device serial, required with multiple devices")
    parser.add_argument("--output", type=Path, default=ROOT / "build/database-timing.json")
    args = parser.parse_args()
    adb = shutil.which("adb")
    if not adb:
        parser.error("Run source .hifz-env/activate first.")
    devices = subprocess.check_output([adb, "devices"], text=True)
    available = [line.split()[0] for line in devices.splitlines()[1:]
                 if len(line.split()) >= 2 and line.split()[1] == "device"]
    serial = args.serial
    if serial is None and len(available) == 1:
        serial = available[0]
    if serial not in available:
        parser.error("Connect and authorize a phone; use --serial if multiple devices are connected.")

    def run(*arguments):
        return subprocess.check_output([adb, "-s", serial, *arguments],
                                       text=True, stderr=subprocess.STDOUT, timeout=30).strip()

    component = run("shell", "cmd", "package", "resolve-activity", "--brief", PACKAGE).splitlines()[-1]
    if not component.startswith(PACKAGE + "/"):
        parser.error("Install the Phase 1 Hifz debug APK on the phone first.")
    report = {
        "model": run("shell", "getprop", "ro.product.model"),
        "android": run("shell", "getprop", "ro.build.version.release"),
        "low_ram_device": run("shell", "getprop", "ro.config.low_ram"),
        "package": PACKAGE,
        "method": "One unmeasured launch followed by five process restarts; existing app data retained.",
        "target_ms": 500,
        "warm_ms": [],
    }
    for attempt in range(6):
        run("shell", "am", "force-stop", PACKAGE)
        # Use a timestamp cursor so an old log message cannot become a new sample.
        cursor = run("shell", "date", "+%m-%d %H:%M:%S.000")
        run("shell", "am", "start", "-W", "-n", component)
        pid = run("shell", "pidof", PACKAGE)
        if not pid.isdigit():
            raise RuntimeError("Hifz did not start as a single process.")
        deadline = time.monotonic() + 20
        while time.monotonic() < deadline:
            logs = run("logcat", "-d", "-T", cursor, "--pid=" + pid, "-s", "flutter:I")
            match = re.search(r"Hifz database open: (\d+) ms", logs)
            if match:
                duration = int(match.group(1))
                if attempt:
                    report["warm_ms"].append(duration)
                print(f"Launch {attempt + 1}: {duration} ms", flush=True)
                break
            time.sleep(0.5)
        else:
            raise RuntimeError("No database timing log found. Install the Phase 1 debug APK.")
    report["warm_target_met"] = max(report["warm_ms"]) <= report["target_ms"]
    report["first_install_ms"] = None
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2) + "\n")
    print(f"Saved {args.output}. First-install measurement and device classification remain separate.")


if __name__ == "__main__":
    main()
