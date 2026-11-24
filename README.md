# Hifz · حفظ

Hifz is an Arabic-first Android Quran reader for memorization and revision. It includes a printed Mushaf reader, word-by-word recall, offline speech following, daily portions, reading goals, Arabic tafsir, and personal and daily adhkar. Learner progress stays on the device.

## Get started

Use Flutter 3.50.0 with Dart 3.14, the Android SDK, and Python 3. From the repository root:

```sh
flutter pub get
flutter analyze
flutter test test/domain
```

These checks run entirely from the public checkout. The full reader and the remaining integration and widget tests require the local content described below.

## Prepare the offline reader

1. Obtain the two QUL source archives for the [V1 printed layout](https://qul.tarteel.ai/resources/mushaf-layout/15) and [matching word script](https://qul.tarteel.ai/resources/quran-script/57) under terms that cover your use. Place the original files in `data/sources/` as `qpc-v1-15-lines.db.zip` and `qpc-v1-glyph-codes-wbw.json.zip`. The expected hashes are in `manifest.json` in that directory.
2. Run `python3 tool/import_quran.py`. It checks the source hashes, combines the layout with the included Tanzil text and metadata, and writes the database and its checksum to `assets/data/`.
3. Supply the matching [QUL page fonts](https://qul.tarteel.ai/resources/font/238) under `assets/quran_fonts/p1.ttf` through `p604.ttf`. For an authorized download use `python3 tool/fetch_quran_fonts.py`. Run `python3 tool/verify_quran.py` to check all 604 fonts, the text, and the printed layout.
4. To enable colored tajweed, supply the authorized QCF V4 page fonts and their matching per-page word maps in `assets/tajweed/` as `p1.ttf` and `p1.json` through page 604. The importer, `tool/import_tajweed.py`, documents the format and can generate the package after the database is built. Check the [Quran Foundation terms](https://api-docs.quran.foundation/legal/developer-terms/) for your use of font files and word data.
5. To enable tafsir, supply your authorized Arabic digital edition of Tafsir al-Jalalayn in `assets/tafsir/1.json` through `114.json`. Each file is a UTF-8 JSON array of the surah’s tafsir strings in ayah order, starting with ayah 1. The reader indexes this array by ayah number.

The generated database, QUL archives, page fonts, tajweed maps, and tafsir JSON are ignored by Git. The local speech model, vocabulary, and Android speech runtime are included with their upstream notices.

## Run on Android

Enable USB debugging, connect the phone, and accept its authorization prompt. With the offline content prepared, run:

```sh
flutter doctor -v
flutter devices
flutter test
flutter run -d DEVICE_ID
```

Replace `DEVICE_ID` with the identifier printed by Flutter. For a release APK, run `flutter build apk --release`. Configure your own Android release signing before store distribution.

## License

The original Hifz application code, tests, and tools are distributed under the [MIT License](LICENSE). The Quran text, metadata, and speech components have their own terms. See the [third-party notices](THIRD_PARTY_NOTICES.md) for sources and applicable licenses.
