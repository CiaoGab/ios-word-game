#!/usr/bin/env python3
"""
WordFall dictionary generator.

Produces two JSON files for the iOS app:
  words3_common.json  – common 3-letter English words (zipf >= 4.0, no abbrevs)
  words4to6.json      – 4-6 letter words (existing common list, no blocklist entries)

Requirements:
  pip install wordfreq

Run from the repo root:
  python3 scripts/gen_dictionaries.py

Output goes to:
  ios-word-game/WordFall/Resources/words3_common.json
  ios-word-game/WordFall/Resources/words4to6.json
"""

import json
import os
import re
import sys

try:
    from wordfreq import zipf_frequency, top_n_list
except ImportError:
    print("ERROR: wordfreq is required. Install it with: pip install wordfreq", file=sys.stderr)
    sys.exit(1)

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT   = os.path.dirname(SCRIPT_DIR)
RESOURCES   = os.path.join(REPO_ROOT, "ios-word-game", "ios-word-game", "WordFall", "Resources")
SOURCE_JSON = os.path.join(RESOURCES, "words_3_6.json")
BLOCKLIST   = os.path.join(RESOURCES, "words_blocklist.txt")
BLOCKLIST_ALT = os.path.join(
    REPO_ROOT, "ios-word-game", "WordFall", "Resources", "words_blocklist.txt"
)
OUT_3       = os.path.join(RESOURCES, "words3_common.json")
OUT_4TO6    = os.path.join(RESOURCES, "words4to6.json")

# ---------------------------------------------------------------------------
# 3-letter words: vowel-free allowlist (short common words spelled without
# standard vowels that are clearly real English words, not abbreviations).
# ---------------------------------------------------------------------------
VOWEL_FREE_ALLOWLIST: set[str] = {
    "gym", "sky", "why", "try", "fly", "cry", "dry", "fry", "pry",
    "sly", "spy", "shy", "ply", "sty", "wry", "thy", "nth", "psych",
    "gym", "gyn", "crypt",  # keep crypt but it's 5 letters – harmless
}

# Standard vowels
VOWELS = set("aeiou")

ZIPF_MIN = 4.0


def load_blocklist(path: str) -> set[str]:
    blocked: set[str] = set()
    if not os.path.exists(path):
        print(f"Warning: blocklist not found at {path}", file=sys.stderr)
        return blocked
    with open(path) as f:
        for line in f:
            line = line.strip().lower()
            if not line or line.startswith("#"):
                continue
            blocked.add(line)
    return blocked


def has_vowel(word: str) -> bool:
    return any(ch in VOWELS for ch in word)


def is_valid_3letter(word: str, blocked: set[str]) -> bool:
    """Return True if word should be included in the 3-letter common set."""
    if len(word) != 3:
        return False
    if word in blocked:
        return False
    # Must have a vowel OR be in the explicit allowlist.
    if not has_vowel(word) and word not in VOWEL_FREE_ALLOWLIST:
        return False
    # Must meet frequency threshold.
    z = zipf_frequency(word, "en")
    return z >= ZIPF_MIN


def is_valid_4to6(word: str, blocked: set[str]) -> bool:
    """Return True if word should be included in the 4-6 letter set."""
    n = len(word)
    if n < 4 or n > 6:
        return False
    return word not in blocked


def normalize(word: str) -> str:
    return word.strip().lower()


def main() -> None:
    # --- Load source words ---
    if not os.path.exists(SOURCE_JSON):
        print(f"ERROR: source file not found: {SOURCE_JSON}", file=sys.stderr)
        sys.exit(1)

    with open(SOURCE_JSON) as f:
        raw_words: list[str] = json.load(f)

    words = [normalize(w) for w in raw_words]
    words = [w for w in words if re.fullmatch(r"[a-z]+", w)]

    blocked = load_blocklist(BLOCKLIST)
    print(f"Blocklist entries: {len(blocked)}")

    # --- 3-letter words ---
    # Strategy: take the union of:
    #   (a) existing 3-letter words that pass filters
    #   (b) any extra high-frequency 3-letter words from wordfreq not in source
    source_3 = {w for w in words if len(w) == 3}

    common3: list[str] = []
    for w in sorted(source_3):
        if is_valid_3letter(w, blocked):
            common3.append(w)

    # Also scan wordfreq's top English words for any 3-letter words we missed.
    try:
        top_words = top_n_list("en", 50_000, wordlist="large")
        for w in top_words:
            w = normalize(w)
            if len(w) == 3 and w not in source_3 and is_valid_3letter(w, blocked):
                common3.append(w)
    except Exception as e:
        print(f"Warning: top_n_list failed ({e}); skipping supplemental scan", file=sys.stderr)

    common3 = sorted(set(common3))

    # --- 4-6 letter words ---
    words4to6 = sorted({w for w in words if is_valid_4to6(w, blocked)})

    # --- Write outputs ---
    os.makedirs(RESOURCES, exist_ok=True)

    with open(OUT_3, "w") as f:
        json.dump(common3, f, ensure_ascii=True)
    print(f"Wrote {len(common3)} words  -> {OUT_3}")

    with open(OUT_4TO6, "w") as f:
        json.dump(words4to6, f, ensure_ascii=True)
    print(f"Wrote {len(words4to6)} words -> {OUT_4TO6}")

    # --- Verification ---
    print("\n-- Verification --")
    for check_word in ["ekg", "emg", "gme", "cat", "dog", "the", "and"]:
        in3 = check_word in common3
        in46 = check_word in words4to6
        lbl = "3-common" if in3 else ("4-6" if in46 else "REJECTED")
        print(f"  {check_word!r:8s} -> {lbl}")


if __name__ == "__main__":
    main()
