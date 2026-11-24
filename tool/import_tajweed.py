"""Fetch Quran Foundation V4 fonts and map each printed word by verse and position."""
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import sqlite3
import subprocess
import re

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/tajweed"
FONT = "https://verses.quran.foundation/fonts/quran/hafs/v4/colrv1/ttf"
API = "https://api.quran.com/api/v4/verses/by_chapter"


def fetch(url):
    return subprocess.check_output(["curl", "-fsSL", "--retry", "3", "--max-time", "90", url])


def font(page):
    path = OUT / f"p{page}.ttf"
    data = path.read_bytes() if path.exists() else fetch(f"{FONT}/{path.name}")
    tables = {data[i:i+4] for i in range(12, 12+16*int.from_bytes(data[4:6], "big"), 16)}
    if not {b'COLR', b'CPAL', b'cmap'} <= tables:
        raise ValueError(f"Invalid color font {page}")
    if not path.exists():
        path.write_bytes(data)
    return path.name, hashlib.sha256(data).hexdigest()


def chapter(number):
    verses = {}
    page = 1
    while page:
        url = f"{API}/{number}?words=true&word_fields=code_v2,v2_page,text_uthmani&per_page=50&page={page}"
        response = json.loads(fetch(url))
        for verse in response["verses"]:
            words = verse["words"]
            if [w["position"] for w in words] != list(range(1,len(words)+1)) or words[-1]['char_type_name'] != 'end':
                raise ValueError(verse['verse_key'])
            verses[verse["id"]] = [(w["v2_page"], w["code_v2"], w["text_uthmani"]) for w in words]
        page = response["pagination"]["next_page"]
    return verses


def main():
    OUT.mkdir(exist_ok=True)
    with ThreadPoolExecutor(max_workers=10) as pool:
        hashes = dict(pool.map(font, range(1,605)))
        verses = {i: words for group in pool.map(chapter, range(1,115)) for i, words in group.items()}
        if len(verses) != 6236:
            raise ValueError("Incomplete verse corpus")
        db = sqlite3.connect(ROOT / "assets/data/quran.db")
        for ayah, count in db.execute("SELECT ayah_id,COUNT(*) FROM mushaf_words GROUP BY ayah_id"):
            words = verses[ayah]
            if count != len(words):
                split = []
                for source, glyphs, text in words:
                    tokens = [t for t in text.split() if re.search('[ء-يٱ]', t)]
                    if len(tokens) > 1 and len(tokens) == len(glyphs.replace(' ', '')):
                        split.extend((source, char, token) for char, token in zip(glyphs.replace(' ', ''),tokens))
                    else:
                        split.append((source,glyphs,text))
                if len(split) != count:
                    raise ValueError((ayah,count,words))
                words = split
            verses[ayah] = [(source,glyph) for source,glyph,_ in words]
        for page in range(1,605):
            ids = db.execute("SELECT DISTINCT ayah_id FROM mushaf_words WHERE page=? ORDER BY ayah_id",(page,))
            rows = [word for (i,) in ids for word in verses[i]]
            (OUT / f"p{page}.json").write_text(json.dumps(rows,ensure_ascii=False,separators=(',',':')))
    hashes.update({p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in OUT.glob('*.json')})
    manifest = ROOT / "data/sources/tajweed-sha256.json"
    manifest.write_text(json.dumps(hashes,sort_keys=True,indent=2)+'\n')


if __name__ == '__main__':
    main()
