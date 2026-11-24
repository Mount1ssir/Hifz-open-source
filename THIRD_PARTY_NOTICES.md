# Third-party notices

| Component | Source and applicable terms |
| --- | --- |
| Tanzil Uthmani Quran text | The original text is in `data/sources/quran-uthmani.txt`. Tanzil permits verbatim redistribution with attribution, its copyright notice, and a link to Tanzil. The importer preserves the text and embeds the notice in the derived database. [Bundled notice](assets/data/TANZIL-NOTICE.txt) · [Tanzil Project](https://tanzil.net/) · [Text terms](https://tanzil.net/docs/Text_License) |
| Quran metadata | Tanzil.info, copyright 2008–2009. The original XML declares CC BY. The quarter boundaries in `lib/domain/quarter_boundaries.dart` are derived from this metadata. [Original file with attribution](data/sources/quran-data.xml) · [Upstream metadata](https://tanzil.net/res/text/metadata/quran-data.xml) |
| Quran ASR Small | Abdou’s Arabic speech model and vocabulary, distributed under MIT. [Model revision](https://huggingface.co/Abdou/quran-asr-small/tree/0c2744b9d70aaf45ba574c30c5d318c575258e66) · [License](android/app/src/main/assets/quran-asr/LICENSE) |
| sherpa-onnx Android runtime | The prebuilt Android archive is from sherpa-onnx 2.0.2, Apache-2.0. Retain its runtime and dependency notices. [Release](https://github.com/k2-fsa/sherpa-onnx/releases/tag/v2.0.2) · [License](android/app/src/main/assets/quran-asr/SHERPA-LICENSE) · [ONNX Runtime license](android/app/src/main/assets/quran-asr/ONNXRUNTIME-LICENSE) · [Third-party notices](android/app/src/main/assets/quran-asr/ONNXRUNTIME-ThirdPartyNotices.txt) |

The build uses Flutter and the packages recorded in `pubspec.lock` under their respective licenses. The public checkout includes source references and checksums for the externally supplied Mushaf layout, fonts, and tajweed data. Their original providers and the tafsir edition are listed in the [content sources](assets/data/QUL-SOURCES.txt).
