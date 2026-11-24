"""Validate bundled data against the pinned upstream reference metadata."""
import hashlib
import json
import sqlite3
import zipfile
import tempfile
import xml.etree.ElementTree as ET

from import_quran import ROOT, SOURCES, OUTPUT

manifest = json.loads((SOURCES / "manifest.json").read_text())
for name, expected in manifest["sha256"].items():
    assert hashlib.sha256((SOURCES / name).read_bytes()).hexdigest() == expected, name
assert hashlib.sha256((OUTPUT / "quran.db").read_bytes()).hexdigest() == (
    OUTPUT / "quran.db.sha256").read_text().strip()
db = sqlite3.connect(f"file:{OUTPUT / 'quran.db'}?mode=ro", uri=True)
metadata = ET.parse(SOURCES / "quran-data.xml").getroot()
assert db.execute("PRAGMA integrity_check").fetchone()[0] == "ok"
assert db.execute("SELECT count(*) FROM surahs").fetchone()[0] == 114
assert db.execute("SELECT count(*) FROM ayahs").fetchone()[0] == 6236
for surah in metadata.find("suras"):
    index, count = int(surah.attrib["index"]), int(surah.attrib["ayas"])
    assert db.execute("SELECT count(*) FROM ayahs WHERE surah=?", (index,)).fetchone()[0] == count
for group, column, count in (("pages", "page", 604), ("juzs", "juz", 30)):
    assert [r[0] for r in db.execute(f"SELECT DISTINCT {column} FROM ayahs ORDER BY {column}")] == list(range(1, count + 1))
    for entry in metadata.find(group):
        first = db.execute(f"SELECT surah, number FROM ayahs WHERE {column}=? ORDER BY id LIMIT 1",
                           (int(entry.attrib["index"]),)).fetchone()
        assert first == (int(entry.attrib["sura"]), int(entry.attrib["aya"]))
original = [line for line in (SOURCES / "quran-uthmani.txt").read_bytes().splitlines()
            if line and line[:1].isdigit()]
stored = [f"{s}|{n}|{t}".encode() for s, n, t in db.execute(
    "SELECT surah, number, text FROM ayahs ORDER BY id")]
assert original == stored, "Quran text bytes changed"
assert db.execute("SELECT count(*) FROM ayahs WHERE basmalah_prefix != ''").fetchone()[0] == 112
try:
    db.execute("DELETE FROM ayahs")
    raise AssertionError("Quran database allowed a write")
except sqlite3.OperationalError:
    pass
with zipfile.ZipFile(SOURCES / "qpc-v1-glyph-codes-wbw.json.zip") as archive:
    words = json.loads(archive.read("qpc-v1-glyph-codes-wbw.json"))
word_ids = {int(word["id"]): (int(word["surah"]), int(word["ayah"]))
            for word in words.values()}
ayah_ids = {(s, n): i for i, s, n in db.execute("SELECT id, surah, number FROM ayahs")}
expected_spans = set()
with tempfile.TemporaryDirectory() as directory:
    from pathlib import Path
    layout_path = Path(directory) / "layout.db"
    with zipfile.ZipFile(SOURCES / "qpc-v1-15-lines.db.zip") as archive:
        layout_path.write_bytes(archive.read("qpc-v1-15-lines.db"))
    with sqlite3.connect(layout_path) as layout:
        for page, line, first, last in layout.execute(
            "SELECT page_number, line_number, first_word_id, last_word_id FROM pages WHERE line_type='ayah'"
        ):
            for word in range(first, last + 1):
                expected_spans.add((ayah_ids[word_ids[word]], page, line))
actual_words = {row[0]: (row[1], row[2]) for row in db.execute(
    "SELECT id, ayah_id, glyph FROM mushaf_words")}
assert len(actual_words) == len(words)
for word in words.values():
    assert actual_words[int(word["id"])] == (
        ayah_ids[(int(word["surah"]), int(word["ayah"]))], word["text"])
assert db.execute("SELECT count(DISTINCT page) FROM mushaf_lines").fetchone()[0] == 604
actual_spans = set(db.execute("SELECT ayah_id, page, line FROM ayah_lines"))
assert actual_spans == expected_spans, "QUL line spans differ from source word ranges"
assert {i for i, _, _ in actual_spans} == set(range(1, 6237))
assert {page for _, page, _ in actual_spans} == set(range(1, 605))
assert all(1 <= line <= 15 for _, _, line in actual_spans)
print(f"PASS: {len(actual_spans)} exact QUL ayah-line spans across 604 pages.")
db.close()
print("PASS: checksums, exact text bytes, 114 surahs, 6236 ayahs, 604 pages, 30 juz, and read-only access.")

font_manifest = json.loads((SOURCES / "quran-fonts.json").read_text())
assert len(font_manifest["sha256"]) == 604
for name, expected in font_manifest["sha256"].items():
    assert hashlib.sha256((ROOT / "assets/quran_fonts" / name).read_bytes()).hexdigest() == expected, name
print("PASS: all 604 QUL font checksums and original glyph mappings.")
