#!/usr/bin/env python3
"""Generate the String Catalogs (.xcstrings) from Tools/strings_source.py."""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
import strings_source  # noqa: E402


def catalog(entries: dict) -> dict:
    strings = {}
    for key in sorted(entries):
        en, es = entries[key]
        strings[key] = {
            "extractionState": "manual",
            "localizations": {
                "en": {"stringUnit": {"state": "translated", "value": en}},
                "es": {"stringUnit": {"state": "translated", "value": es}},
            },
        }
    return {"sourceLanguage": "en", "strings": strings, "version": "1.0"}


def write(path: str, data: dict) -> None:
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2, sort_keys=True)
        f.write("\n")


def main() -> int:
    res = os.path.join(ROOT, "AICat", "Resources")
    os.makedirs(res, exist_ok=True)
    write(os.path.join(res, "Localizable.xcstrings"), catalog(strings_source.STRINGS))
    write(os.path.join(res, "InfoPlist.xcstrings"), catalog(strings_source.INFOPLIST))
    print(f"Localizable.xcstrings: {len(strings_source.STRINGS)} keys; InfoPlist.xcstrings: {len(strings_source.INFOPLIST)} keys")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
