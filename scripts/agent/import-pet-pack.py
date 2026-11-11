#!/usr/bin/env python3
"""Import a pet from another format into a Clavis pet pack.

Supported inputs:
  * Clavis pack: directory with pet.json + renderer/animations -> copied
  * Codex/OpenPet pet: pet.json + spritesheet.webp (1536x1872 or 1536x2288)
  * Static image: a .png/.webp/.jpg file -> image renderer pack

An import does NOT invent a shared "pet/feed/play" vocabulary. Dialogue,
actions, menu labels and status texts belong to the character profile. Supply
them in the source pet.json or with --profile. Otherwise the imported pet gets
only neutral mechanics (idle/walk/drag) plus the framework's Agent/settings
controls. DSH/dsh-pet settings are handled by dsh-pet-settings.py; DSH webm
clips can be converted to frames with ffmpeg and used as a normal frames pack.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import shutil
from pathlib import Path
from PIL import Image

PACKS = Path.home() / ".config/clavis/pets"
ROW_MAP = {
    "idle": 0,
    "running-right": 1,
    "running-left": 2,
    "waving": 3,
    "jumping": 4,
    "failed": 5,
    "waiting": 6,
    "running": 7,
    "review": 8,
}
PROFILE_FIELDS = (
    "actions", "menu", "interactions", "ui", "workStatusTexts", "statusTexts",
    "agentStates", "behavior", "sleep", "language", "locale", "aliases",
    "locales", "i18n",
)
DEFAULT_AGENT_STATES = {
    "thinking": "review",
    "working": "running",
    "result": "review",
    "waiting": "waiting",
    "success": "jumping",
    "error": "failed",
}


def slug(value: str) -> str:
    value = str(value or "").strip().lower()
    value = re.sub(r"[^a-z0-9._-]+", "-", value)
    return value.strip("-._") or "imported-pet"


def unique_output(pack_id: str, force: bool) -> Path:
    out = PACKS / pack_id
    if out.exists():
        if not force:
            raise SystemExit(f"目标已存在：{out}（加 --force 覆盖）")
        shutil.rmtree(out)
    return out


def source_profile(meta: dict, profile_path: str | None) -> dict:
    profile = {}
    for key in PROFILE_FIELDS:
        if key in meta:
            profile[key] = meta[key]
    if profile_path:
        path = Path(profile_path).expanduser().resolve()
        try:
            extra = json.loads(path.read_text(encoding="utf-8"))
        except Exception as error:
            raise SystemExit(f"无法读取 profile：{path}: {error}")
        if not isinstance(extra, dict):
            raise SystemExit("profile 必须是 JSON object")
        profile.update(extra)
    return profile


def write_manifest(out: Path, pack_id: str, name: str, desc: str, source: str,
                   animations: dict, profile: dict, renderer: str = "frames",
                   image: str = "") -> None:
    behavior = profile.get("behavior") if isinstance(profile.get("behavior"), dict) else {}
    behavior = dict(behavior)
    behavior.setdefault("wander", renderer == "frames")
    behavior.setdefault("speed", 24)
    behavior.setdefault("facing", "right")

    interactions = profile.get("interactions")
    if not isinstance(interactions, dict):
        interactions = {}
    interactions = dict(interactions)
    interactions.setdefault("rightClick", "menu")
    if renderer == "frames":
        interactions.setdefault("dragStart", {
            "animation": "jumping", "duration": 60, "loop": True,
        })
        interactions.setdefault("dragEnd", "idle")

    actions = profile.get("actions") if isinstance(profile.get("actions"), dict) else {}
    menu = profile.get("menu") if isinstance(profile.get("menu"), list) else []
    ui = profile.get("ui") if isinstance(profile.get("ui"), dict) else {}
    agent_states = profile.get("agentStates")
    if not isinstance(agent_states, dict):
        agent_states = DEFAULT_AGENT_STATES

    pet = {
        "schemaVersion": 2,
        "id": pack_id,
        "name": name,
        "description": desc,
        "author": f"imported from {source}",
        "license": "See NOTICE.md",
        "renderer": renderer,
        "preview": "preview.png",
        "animations": animations,
        "behavior": behavior,
        "agentStates": agent_states,
        "actions": actions,
        "menu": menu,
        "interactions": interactions,
        "ui": ui,
    }
    for key in ("workStatusTexts", "statusTexts", "sleep", "language", "locale",
                "aliases", "locales", "i18n"):
        if key in profile:
            pet[key] = profile[key]
    if renderer == "image":
        pet["image"] = image
    (out / "pet.json").write_text(json.dumps(pet, ensure_ascii=False, indent=2) + "\n",
                                  encoding="utf-8")


def import_clavis(src: Path, pack_id: str, name: str, force: bool) -> Path:
    out = unique_output(pack_id, force)
    shutil.copytree(src, out)
    data = json.loads((out / "pet.json").read_text(encoding="utf-8"))
    data["id"] = pack_id
    if name:
        data["name"] = name
    (out / "pet.json").write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n",
                                  encoding="utf-8")
    return out


def import_atlas(src: Path, pack_id: str, name: str, force: bool,
                 profile_path: str | None) -> Path:
    meta = json.loads((src / "pet.json").read_text(encoding="utf-8"))
    sheet_rel = meta.get("spritesheetPath") or meta.get("spritesheet") or "spritesheet.webp"
    sheet_path = (src / sheet_rel).resolve()
    if not sheet_path.is_file():
        raise SystemExit(f"找不到图集：{sheet_path}")
    img = Image.open(sheet_path).convert("RGBA")
    cw, ch = 192, 208
    cols = img.width // cw
    rows = img.height // ch
    if cols < 8 or rows < 9:
        raise SystemExit(f"不支持的图集尺寸：{img.size}，需要至少 8x9 个 {cw}x{ch} 单元")
    out = unique_output(pack_id, force)
    frames = out / "frames"
    frames.mkdir(parents=True, exist_ok=True)

    counts = {}
    for state, row in ROW_MAP.items():
        saved = 0
        for i in range(min(8, cols)):
            cell = img.crop((i * cw, row * ch, (i + 1) * cw, (row + 1) * ch))
            if cell.getbbox() is None:
                continue
            cell.save(frames / f"{state}_{i}.png")
            saved += 1
        counts[state] = saved
    if counts.get("idle", 0) == 0:
        raise SystemExit("图集第 0 行没有可用帧")

    def anim(state, fps, loop=True):
        return {
            "frames": [f"frames/{state}_{i}.png" for i in range(8)
                       if (frames / f"{state}_{i}.png").is_file()],
            "fps": fps,
            "loop": loop,
        }

    animations = {
        "idle": anim("idle", 6),
        "walk": anim("running-right", 10),
        "running": anim("running", 10),
        "waiting": anim("waiting", 6),
        "failed": anim("failed", 6),
        "review": anim("review", 6),
        "waving": anim("waving", 8, False),
        "jumping": anim("jumping", 8),
        "drag": anim("jumping", 8),
    }
    shutil.copy2(frames / "idle_0.png", out / "preview.png")
    display = name or str(meta.get("displayName") or meta.get("name") or pack_id)
    write_manifest(
        out, pack_id, display,
        str(meta.get("description") or "Imported Codex/OpenPet character"),
        str(sheet_path), animations, source_profile(meta, profile_path),
    )
    shutil.copy2(frames / "idle_0.png", out / "preview.png")
    for filename in ("LICENSE", "LICENSE-ART-CC-BY-NC-4.0", "NOTICE.md"):
        license_path = src / filename
        if license_path.is_file():
            shutil.copy2(license_path, out / filename)
    (out / "NOTICE.md").write_text(
        f"# {display}\n\nImported from: {src}\n\n"
        "This pack was generated from a Codex/OpenPet-compatible spritesheet. "
        "Check the source artwork license before redistribution.\n", encoding="utf-8")
    return out


def import_image(src: Path, pack_id: str, name: str, force: bool,
                 profile_path: str | None) -> Path:
    out = unique_output(pack_id, force)
    out.mkdir(parents=True, exist_ok=True)
    ext = src.suffix.lower() or ".png"
    target = out / ("pet" + ext)
    shutil.copy2(src, target)
    Image.open(target).convert("RGBA").save(out / "preview.png")
    display = name or src.stem
    profile = source_profile({}, profile_path)
    write_manifest(
        out, pack_id, display, "Imported static pet image", str(src), {},
        profile, renderer="image", image=target.name,
    )
    (out / "NOTICE.md").write_text(
        f"# {display}\n\nImported from: {src}\n\n"
        "Check the source image license before redistribution.\n", encoding="utf-8")
    return out


def main() -> int:
    parser = argparse.ArgumentParser(description="Import a pet into Clavis")
    parser.add_argument("source", help="directory or image file")
    parser.add_argument("--id", default="")
    parser.add_argument("--name", default="")
    parser.add_argument("--profile", default="",
                        help="JSON profile with this character's actions, say lines, menu, ui, language")
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args()
    src = Path(args.source).expanduser().resolve()
    if not src.exists():
        raise SystemExit(f"输入不存在：{src}")
    if src.is_file():
        ext = src.suffix.lower()
        if ext not in (".png", ".webp", ".jpg", ".jpeg", ".gif"):
            raise SystemExit("图片只支持 png/webp/jpg/jpeg/gif")
        pack_id = slug(args.id or src.stem)
        out = import_image(src, pack_id, args.name, args.force, args.profile)
        print(f"imported image pet -> {out}")
        return 0
    manifest = src / "pet.json"
    if not manifest.is_file():
        raise SystemExit(f"目录中没有 pet.json：{src}")
    data = json.loads(manifest.read_text(encoding="utf-8"))
    pack_id = slug(args.id or data.get("id") or src.name)
    if data.get("renderer") or isinstance(data.get("animations"), dict):
        out = import_clavis(src, pack_id, args.name, args.force)
        print(f"imported Clavis pack -> {out}")
    elif data.get("spritesheetPath") or data.get("spritesheet"):
        out = import_atlas(src, pack_id, args.name, args.force, args.profile)
        print(f"imported Codex/OpenPet atlas -> {out}")
    else:
        raise SystemExit("无法识别：需要 Clavis pet.json、Codex 图集或单张图片")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
