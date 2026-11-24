"""Download the matching QUL V1 page fonts and pin their checksums."""
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import time
import subprocess

ROOT = Path(__file__).resolve().parents[1]
FONTS = ROOT / "assets/quran_fonts"
MANIFEST = ROOT / "data/sources/quran-fonts.json"
BASE = "https://static-cdn.tarteel.ai/qul/fonts/quran_fonts/v1-optimized/ttf"


def fetch(page):
    name = f"p{page}.ttf"
    path = FONTS / name
    if not path.exists():
        for attempt in range(3):
            try:
                data = subprocess.check_output([
                    "curl", "-fsSL", "--max-time", "45", f"{BASE}/{name}",
                ])
                if data[:4] not in (b"\x00\x01\x00\x00", b"OTTO"):
                    raise ValueError(f"Invalid font: {name}")
                temporary = path.with_suffix(".tmp")
                temporary.write_bytes(data)
                temporary.replace(path)
                break
            except Exception:
                if attempt == 2:
                    raise
                time.sleep(attempt + 1)
    return name, hashlib.sha256(path.read_bytes()).hexdigest()


if __name__ == "__main__":
    FONTS.mkdir(parents=True, exist_ok=True)
    with ThreadPoolExecutor(max_workers=8) as pool:
        hashes = dict(pool.map(fetch, range(1, 605)))
    if MANIFEST.exists():
        previous = json.loads(MANIFEST.read_text())["sha256"]
        if previous != hashes:
            raise ValueError("Font checksums changed; review the source update.")
    MANIFEST.write_text(json.dumps({
        "resource": "https://qul.tarteel.ai/resources/font/238",
        "base_url": BASE, "sha256": hashes,
    }, indent=2) + "\n")
    print(f"Downloaded and pinned {len(hashes)} QUL page fonts.")
