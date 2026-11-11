#!/usr/bin/env python3
"""Rasterize application icons into a PNG cache for the launchpad.

Qt rasterizes an SVG again every time an image becomes visible, so a launcher
page full of scalable icons costs about a second to open on slower devices.
Rendering one PNG per icon keeps that cost out of the open path.
"""

from __future__ import annotations

import argparse
import hashlib
import sys
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cache", required=True, help="PNG cache directory")
    parser.add_argument("--size", type=int, default=256, help="square pixel size")
    parser.add_argument("paths", nargs="*", help="source icon files")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if not 16 <= args.size <= 1024:
        print("error: --size must be between 16 and 1024", file=sys.stderr)
        return 2
    try:
        import gi

        gi.require_version("GdkPixbuf", "2.0")
        from gi.repository import GdkPixbuf, GLib
    except (ImportError, ValueError) as exc:
        print(f"error: GdkPixbuf is unavailable: {exc}", file=sys.stderr)
        return 3

    cache = Path(args.cache)
    try:
        cache.mkdir(parents=True, exist_ok=True)
    except OSError as exc:
        print(f"error: cannot create cache directory: {exc}", file=sys.stderr)
        return 4

    seen: set[str] = set()
    for raw in args.paths:
        if not raw or raw in seen:
            continue
        seen.add(raw)
        source = Path(raw)
        try:
            mtime = source.stat().st_mtime_ns
        except OSError:
            continue
        digest = hashlib.sha1(f"{source}:{mtime}:{args.size}".encode()).hexdigest()[:20]
        target = cache / f"{digest}.png"
        if not target.is_file():
            try:
                pixbuf = GdkPixbuf.Pixbuf.new_from_file_at_scale(
                    str(source), args.size, args.size, True
                )
                pixbuf.savev(str(target), "png", [], [])
            except GLib.Error as exc:
                print(f"warn: {source}: {exc.message}", file=sys.stderr)
                continue
        print(f"{raw}\t{target}", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
