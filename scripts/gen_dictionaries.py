#!/usr/bin/env python3
"""
WordFall dictionary generator.

Produces two JSON files for the iOS app:
  words3_common.json  – common 3-letter English words (zipf >= 4.0, no abbrevs)
  words4to6.json      – 4-20 letter words from a broad English vocabulary

Requirements:
  pip install wordfreq

Run from the repo root:
  python3 scripts/gen_dictionaries.py

Output goes to:
  ios-word-game/WordFall/Resources/words3_common.json
  ios-word-game/WordFall/Resources/words4to6.json
"""

import json
import pathlib
import re
import sys

try:
    from wordfreq import zipf_frequency, top_n_list
except ImportError:
    print("ERROR: wordfreq is required. Install it with: pip install wordfreq", file=sys.stderr)
    sys.exit(1)

# ---------------------------------------------------------------------------
# Paths  (use pathlib.resolve() so the script works regardless of CWD)
# ---------------------------------------------------------------------------
_SCRIPT   = pathlib.Path(__file__).resolve()
RESOURCES = _SCRIPT.parent.parent / "ios-word-game" / "WordFall" / "Resources"
BLOCKLIST = RESOURCES / "words_blocklist.txt"
OUT_3     = RESOURCES / "words3_common.json"
OUT_4TO20 = RESOURCES / "words4to6.json"   # filename kept for app compatibility

# ---------------------------------------------------------------------------
# 3-letter words: allowlist of vowel-free words that are clearly real English
# ---------------------------------------------------------------------------
VOWEL_FREE_ALLOWLIST: set[str] = {
    "gym", "sky", "why", "try", "fly", "cry", "dry", "fry", "pry",
    "sly", "spy", "shy", "ply", "sty", "wry", "thy", "nth",
}

VOWELS = set("aeiou")

ZIPF_MIN_3 = 4.0

# Number of top English words to pull from wordfreq.
# 500k covers common through moderately rare words (zipf >= ~1.5), capturing
# inflected forms like "pastels", "quickly", "twisted", "playing", "flowers".
TOP_N = 500_000


def load_blocklist(path: pathlib.Path) -> set[str]:
    blocked: set[str] = set()
    try:
        text = path.read_text(encoding="utf-8")
    except OSError:
        print(f"Warning: blocklist not found at {path}", file=sys.stderr)
        return blocked
    for line in text.splitlines():
        line = line.strip().lower()
        if not line or line.startswith("#"):
            continue
        blocked.add(line)
    return blocked


def has_vowel(word: str) -> bool:
    return any(ch in VOWELS for ch in word)


def is_valid_3letter(word: str, blocked: set[str]) -> bool:
    if len(word) != 3:
        return False
    if word in blocked:
        return False
    if not has_vowel(word) and word not in VOWEL_FREE_ALLOWLIST:
        return False
    z = zipf_frequency(word, "en")
    return z >= ZIPF_MIN_3


def is_valid_4to20(word: str, blocked: set[str]) -> bool:
    n = len(word)
    if n < 4 or n > 20:
        return False
    return word not in blocked


def normalize(word: str) -> str:
    return word.strip().lower()


def main() -> None:
    blocked = load_blocklist(BLOCKLIST)
    print(f"Blocklist entries: {len(blocked)}")

    # Pull a broad English vocabulary from wordfreq.
    print(f"Fetching top {TOP_N:,} English words from wordfreq (this may take a moment)...")
    try:
        raw_top = top_n_list("en", TOP_N, wordlist="large")
    except Exception as e:
        print(f"ERROR: top_n_list failed: {e}", file=sys.stderr)
        sys.exit(1)

    # Normalize and keep only pure alpha words.
    all_words: list[str] = []
    for w in raw_top:
        w = normalize(w)
        if re.fullmatch(r"[a-z]+", w):
            all_words.append(w)

    print(f"  {len(all_words):,} alpha words after normalization")

    # --- 3-letter common words ---
    common3: list[str] = sorted(
        {w for w in all_words if is_valid_3letter(w, blocked)}
    )

    # --- 4-20 letter words ---
    words4to20: list[str] = sorted(
        {w for w in all_words if is_valid_4to20(w, blocked)}
    )

    # --- Write outputs ---
    RESOURCES.mkdir(parents=True, exist_ok=True)

    OUT_3.write_text(json.dumps(common3, ensure_ascii=True), encoding="utf-8")
    print(f"Wrote {len(common3):,} words  -> {OUT_3}")

    OUT_4TO20.write_text(json.dumps(words4to20, ensure_ascii=True), encoding="utf-8")
    print(f"Wrote {len(words4to20):,} words -> {OUT_4TO20}")

    # --- Length distribution ---
    print("\n-- Length distribution (4+ letter words) --")
    lengths: dict[int, int] = {}
    for w in words4to20:
        lengths[len(w)] = lengths.get(len(w), 0) + 1
    for length in sorted(lengths):
        print(f"  {length:2d} letters: {lengths[length]:,}")

    # --- Spot-check ---
    set3   = set(common3)
    set420 = set(words4to20)
    print("\n-- Spot-check --")
    checks = [
        "ekg", "emg", "gme", "cat", "dog", "the", "and",
        "pastels", "quickly", "twisted", "playing", "flowers", "painted",
        "started", "garden", "words", "beautiful", "complicated",
    ]
    for word in checks:
        lbl = "3-common" if word in set3 else ("4-20" if word in set420 else "REJECTED")
        print(f"  {word!r:14s} -> {lbl}")


if __name__ == "__main__":
    main()
