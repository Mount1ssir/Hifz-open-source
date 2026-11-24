import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'app_modules.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'Tanzil Quran text — https://tanzil.net',
    ], await rootBundle.loadString('assets/data/TANZIL-NOTICE.txt'));
  });
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'QUL — Quranic Universal Library',
    ], await rootBundle.loadString('assets/data/QUL-SOURCES.txt'));
  });
  LicenseRegistry.addLicense(() async* {
    const notices = {
      'LICENSE': 'Quran ASR Small — Abdou',
      'SHERPA-LICENSE': 'sherpa-onnx',
      'ONNXRUNTIME-LICENSE': 'ONNX Runtime',
      'ONNXRUNTIME-ThirdPartyNotices.txt': 'ONNX Runtime · Third-party notices',
    };
    for (final notice in notices.entries) {
      yield LicenseEntryWithLineBreaks(
        [notice.value],
        await rootBundle.loadString(
          'android/app/src/main/assets/quran-asr/${notice.key}',
        ),
      );
    }
  });
  runApp(const HifzApp());
}
