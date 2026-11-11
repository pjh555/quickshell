#!/usr/bin/env python3
"""Scan Clavis pet pack directories and emit a JSON array for QML.

Usage:
    list-pet-packs.py <pack-dir> [<override-pack-dir> ...]

Each <pack-dir>/<id>/pet.json is validated and normalized. Later directories
override earlier packs with the same id. Only local files are referenced.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path


def _uri(path: Path) -> str:
    return path.resolve().as_uri()


def _load(manifest: Path):
    try:
        data = json.loads(manifest.read_text(encoding="utf-8"))
    except Exception as exc:  # noqa: BLE001
        print(f"skip {manifest}: {exc}", file=sys.stderr)
        return None
    if not isinstance(data, dict):
        print(f"skip {manifest}: manifest must be an object", file=sys.stderr)
        return None

    pack_id = str(data.get("id") or manifest.parent.name).strip()
    if not pack_id:
        print(f"skip {manifest}: missing id", file=sys.stderr)
        return None

    animations = data.get("animations")
    renderer = str(data.get("renderer") or ("frames" if isinstance(animations, dict) else "image"))

    pack = {
        "id": pack_id,
        "name": str(data.get("name") or pack_id),
        "description": str(data.get("description") or ""),
        "author": str(data.get("author") or ""),
        "license": str(data.get("license") or ""),
        "renderer": renderer,
        "source": "pack",
        "packDir": str(manifest.parent),
    }

    appearance = data.get("appearance")
    if isinstance(appearance, dict):
        pack["appearance"] = appearance
    # Pass through the full behavior/action contract. The QML profile layer is
    # intentionally the only consumer; the scanner only resolves asset paths.
    for key, expected in (("agentStates", dict), ("actions", dict),
                          ("interactions", dict), ("ambient", list),
                          ("menu", list), ("workStatusTexts", (list, dict)),
                          ("statusTexts", (list, dict)), ("ui", dict),
                          ("sleep", dict), ("locales", dict), ("i18n", dict)):
        value = data.get(key)
        if isinstance(value, expected):
            pack[key] = value
    for key in ("language", "locale"):
        value = data.get(key)
        if isinstance(value, str) and value:
            pack[key] = value
    aliases = data.get("aliases")
    if isinstance(aliases, list):
        pack["aliases"] = [str(x) for x in aliases if str(x)]
    dsh = data.get("dsh")
    if isinstance(dsh, dict):
        pack["dsh"] = dsh

    preview = data.get("preview")
    if preview:
        preview_path = (manifest.parent / str(preview)).resolve()
        if preview_path.is_file():
            pack["previewUrl"] = _uri(preview_path)

    if renderer == "frames":
        normalized = {}
        if isinstance(animations, dict):
            for name, anim in animations.items():
                if not isinstance(anim, dict):
                    continue
                frames = anim.get("frames")
                if not isinstance(frames, list):
                    continue
                urls = []
                missing = False
                for rel in frames:
                    frame_path = (manifest.parent / str(rel)).resolve()
                    if not frame_path.is_file():
                        print(f"skip {manifest}: missing frame {rel}", file=sys.stderr)
                        missing = True
                        break
                    urls.append(_uri(frame_path))
                if missing or not urls:
                    continue
                try:
                    fps = float(anim.get("fps") or 8)
                except (TypeError, ValueError):
                    fps = 8.0
                normalized[str(name)] = {
                    "frames": urls,
                    "fps": max(0.1, min(60.0, fps)),
                    "loop": bool(anim.get("loop", True)),
                    "pingpong": bool(anim.get("pingpong", False)),
                }
        if not normalized.get("idle"):
            print(f"skip {manifest}: frames renderer needs an idle animation", file=sys.stderr)
            return None
        pack["animations"] = normalized
    elif renderer == "image":
        image = data.get("image") or preview
        if not image:
            print(f"skip {manifest}: image renderer needs image/preview", file=sys.stderr)
            return None
        image_path = (manifest.parent / str(image)).resolve()
        if not image_path.is_file():
            print(f"skip {manifest}: missing image {image}", file=sys.stderr)
            return None
        pack["imageUrl"] = _uri(image_path)
    else:
        print(f"skip {manifest}: unsupported renderer {renderer!r}", file=sys.stderr)
        return None

    behavior = data.get("behavior")
    pack["behavior"] = behavior if isinstance(behavior, dict) else {}
    return pack


def main() -> int:
    seen = {}
    for arg in sys.argv[1:]:
        root = Path(arg).expanduser()
        if not root.is_dir():
            continue
        for manifest in sorted(root.glob("*/pet.json")):
            pack = _load(manifest)
            if pack is not None:
                seen[pack["id"]] = pack
    print(json.dumps(list(seen.values()), ensure_ascii=False, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
