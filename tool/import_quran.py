"""Rebuild the bundled database from pinned, unmodified Tanzil downloads."""
import bisect
import hashlib
import json
from pathlib import Path
import sqlite3
import tempfile
import xml.etree.ElementTree as ET

from import_layout import import_layout

ROOT = Path(__file__).resolve().parents[1]
SOURCES = ROOT / "data/sources"
OUTPUT = ROOT / "assets/data"


def build():
    manifest = json.loads((SOURCES / "manifest.json").read_text())
    for name, digest in manifest["sha256"].items():
        if hashlib.sha256((SOURCES / name).read_bytes()).hexdigest() != digest:
            raise ValueError(f"Source checksum mismatch: {name}")
    metadata = ET.parse(SOURCES / "quran-data.xml").getroot()
    surahs = list(metadata.find("suras"))
    offsets = {int(s.attrib["index"]): int(s.attrib["start"]) for s in surahs}
    boundaries = {}
    for group, tag in (("pages", "page"), ("juzs", "juz")):
        boundaries[tag] = [
            offsets[int(e.attrib["sura"])] + int(e.attrib["aya"])
            for e in metadata.find(group)
        ]
    source = (SOURCES / "quran-uthmani.txt").read_text()
    records = [line.split("|", 2) for line in source.splitlines()
               if line and line[0].isdigit()]
    notice = source[source.index("# PLEASE"):].strip()
    basmalah = records[0][2]
    OUTPUT.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(dir=OUTPUT, suffix=".db", delete=False) as temp:
        temp_path = Path(temp.name)
    try:
        with sqlite3.connect(temp_path) as db:
            db.executescript("""
                CREATE TABLE metadata(key TEXT PRIMARY KEY, value TEXT NOT NULL);
                CREATE TABLE surahs(id INTEGER PRIMARY KEY, name TEXT NOT NULL,
                    ayah_count INTEGER NOT NULL, first_ayah_id INTEGER NOT NULL);
                CREATE TABLE ayahs(id INTEGER PRIMARY KEY, surah INTEGER NOT NULL,
                    number INTEGER NOT NULL, text TEXT NOT NULL,
                    basmalah_prefix TEXT NOT NULL, page INTEGER NOT NULL,
                    juz INTEGER NOT NULL, UNIQUE(surah, number));
                CREATE INDEX ayahs_page ON ayahs(page, id);
                CREATE INDEX ayahs_juz ON ayahs(juz, id);
            """)
            db.executemany("INSERT INTO metadata VALUES (?, ?)", [
                ("riwayah", "hafs"), ("numbering", "hafs-kufi"),
                ("total_ayahs", str(sum(int(s.attrib["ayas"]) for s in surahs))),
                ("source_notice", notice),
                ("source_sha256", manifest["sha256"]["quran-uthmani.txt"]),
            ])
            db.executemany("INSERT INTO surahs VALUES (?, ?, ?, ?)", [
                (int(s.attrib["index"]), s.attrib["name"], int(s.attrib["ayas"]),
                 int(s.attrib["start"]) + 1) for s in surahs
            ])
            for identifier, (surah, number, text) in enumerate(records, 1):
                surah, number = int(surah), int(number)
                if identifier != offsets[surah] + number:
                    raise ValueError("Unexpected ayah ordering")
                prefix = ""
                if number == 1 and surah not in (1, 9):
                    prefix = " ".join(text.split(" ")[:4]) + " "
                    if prefix.rstrip() not in (basmalah, basmalah.replace("بِ", "بِّ", 1)):
                        raise ValueError(f"Unexpected opening Basmalah in {surah}")
                db.execute("INSERT INTO ayahs VALUES (?, ?, ?, ?, ?, ?, ?)", (
                    identifier, surah, number, text, prefix,
                    bisect.bisect_right(boundaries["page"], identifier),
                    bisect.bisect_right(boundaries["juz"], identifier),
                ))
            if len(records) != 6236:
                raise ValueError("Incomplete Hafs text")
            word_count, span_count = import_layout(db, SOURCES)
            db.execute("PRAGMA user_version = 2")
        temp_path.replace(OUTPUT / "quran.db")
    finally:
        temp_path.unlink(missing_ok=True)
    (OUTPUT / "TANZIL-NOTICE.txt").write_text(notice + "\n")
    print(f"Imported {word_count} QUL words and {span_count} ayah-line spans.")
    digest = hashlib.sha256((OUTPUT / "quran.db").read_bytes()).hexdigest()
    (OUTPUT / "quran.db.sha256").write_text(digest + "\n")


if __name__ == "__main__":
    build()
