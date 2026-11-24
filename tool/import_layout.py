"""Join QUL V1 word IDs to printed lines without modifying Quran text."""
import json
import sqlite3
import tempfile
import zipfile
from pathlib import Path

LAYOUT = "qpc-v1-15-lines.db"
WORDS = "qpc-v1-glyph-codes-wbw.json"
LAYOUT_ID = "qpc-v1-1405h"


def import_layout(db, sources):
    with zipfile.ZipFile(sources / (WORDS + ".zip")) as archive:
        words = json.loads(archive.read(WORDS))
    ayah_ids = {(s, n): i for i, s, n in db.execute("SELECT id, surah, number FROM ayahs")}
    word_ayahs = {}
    word_glyphs = {}
    for word in words.values():
        identifier = int(word["id"])
        if identifier in word_ayahs:
            raise ValueError("Duplicate QUL word ID")
        word_glyphs[identifier] = word["text"]
        word_ayahs[identifier] = ayah_ids[(int(word["surah"]), int(word["ayah"]))]
    with tempfile.TemporaryDirectory() as directory:
        file = Path(directory) / LAYOUT
        with zipfile.ZipFile(sources / (LAYOUT + ".zip")) as archive:
            file.write_bytes(archive.read(LAYOUT))
        with sqlite3.connect(f"file:{file}?mode=ro", uri=True) as layout:
            info = layout.execute("SELECT number_of_pages, lines_per_page FROM info").fetchone()
            if info != (604, 15):
                raise ValueError("Unexpected QUL layout")
            page_lines = layout.execute(
                "SELECT page_number, line_number, line_type, is_centered, surah_number FROM pages "
                "ORDER BY page_number, line_number"
            ).fetchall()
            lines = layout.execute(
                "SELECT page_number, line_number, first_word_id, last_word_id "
                "FROM pages WHERE line_type='ayah' ORDER BY page_number, line_number"
            ).fetchall()
    db.executescript("""
        CREATE TABLE ayah_lines(
            ayah_id INTEGER NOT NULL REFERENCES ayahs(id),
            page INTEGER NOT NULL,
            line INTEGER NOT NULL,
            PRIMARY KEY(ayah_id, page, line));
    """)
    db.executescript('''
        CREATE TABLE mushaf_lines(
          page INTEGER NOT NULL, line INTEGER NOT NULL, kind TEXT NOT NULL,
          centered INTEGER NOT NULL, surah INTEGER,
          PRIMARY KEY(page,line));
        CREATE TABLE mushaf_words(
          id INTEGER PRIMARY KEY, ayah_id INTEGER NOT NULL REFERENCES ayahs(id),
          page INTEGER NOT NULL, line INTEGER NOT NULL, glyph TEXT NOT NULL);
        CREATE INDEX mushaf_words_page ON mushaf_words(page,line,id);
'''
    )
    db.executemany("INSERT INTO mushaf_lines VALUES (?,?,?,?,?)",
        [(page, line, kind, centered, int(surah) if surah else None)
         for page, line, kind, centered, surah in page_lines])
    spans = set()
    seen_words = set()
    seen_lines = set()
    for page, line, first, last in lines:
        if not (1 <= page <= 604 and 1 <= line <= 15 and first <= last):
            raise ValueError("Invalid printed line")
        if (page, line) in seen_lines:
            raise ValueError("Duplicate printed line")
        seen_lines.add((page, line))
        for word in range(first, last + 1):
            if word in seen_words:
                raise ValueError("Word assigned to multiple lines")
            seen_words.add(word)
            spans.add((word_ayahs[word], page, line))
            db.execute("INSERT INTO mushaf_words VALUES (?,?,?,?,?)",
                (word, word_ayahs[word], page, line, word_glyphs[word]))
    if seen_words != word_ayahs.keys():
        raise ValueError("QUL layout does not cover the complete word dataset")
    if {i for i, _, _ in spans} != set(ayah_ids.values()):
        raise ValueError("QUL layout does not cover every ayah")
    if {page for _, page, _ in spans} != set(range(1, 605)):
        raise ValueError("QUL layout does not cover every page")
    db.executemany("INSERT INTO ayah_lines VALUES (?, ?, ?)", sorted(spans))
    db.executemany("INSERT INTO metadata VALUES (?, ?)", [
        ("layout_id", LAYOUT_ID), ("lines_per_page", "15"),
        ("layout_source", "https://qul.tarteel.ai/resources/mushaf-layout/15"),
        ("words_source", "https://qul.tarteel.ai/resources/quran-script/57"),
    ])
    return len(word_ayahs), len(spans)
