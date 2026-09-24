#!/usr/bin/env python3
"""Build local placeholder manifest entries for private image folders.

The script scans image filenames only. It does not OCR, classify, summarize, or
invent descriptions for private/reference images.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp"}
OUTPUT_PATH = Path("assets/asset_manifest.local.json")


def slug(value: str) -> str:
    value = value.lower()
    value = re.sub(r"[^a-z0-9]+", "_", value)
    return value.strip("_") or "image"


def default_prefix(directory_name: str) -> str:
    match = re.fullmatch(r"chapter_(\d+)", directory_name.lower())
    if match:
        return f"ch{int(match.group(1)):03d}"
    return slug(directory_name)


def res_path(path: Path) -> str:
    return "res://" + path.as_posix()


def load_existing() -> dict:
    if not OUTPUT_PATH.exists():
        return {}
    with OUTPUT_PATH.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: python tools/build_asset_manifest.py <image_directory>")
        return 2

    scan_dir = Path(sys.argv[1])
    if not scan_dir.exists() or not scan_dir.is_dir():
        print(f"Not a directory: {scan_dir}")
        return 2

    existing = load_existing()
    prefix = default_prefix(scan_dir.name)

    for image_path in sorted(scan_dir.rglob("*")):
        if image_path.suffix.lower() not in IMAGE_EXTENSIONS:
            continue

        entry_id = f"{prefix}_{slug(image_path.stem)}"
        if entry_id in existing:
            continue

        existing[entry_id] = {
            "file": res_path(image_path),
            "category": "unclassified",
            "characters": [],
            "location": None,
            "recommended_use": None,
            "notes": "",
        }

    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    with OUTPUT_PATH.open("w", encoding="utf-8") as handle:
        json.dump(existing, handle, indent=2, ensure_ascii=False)
        handle.write("\n")

    print(f"Wrote {OUTPUT_PATH}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
