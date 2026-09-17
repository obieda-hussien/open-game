#!/usr/bin/env python3
"""Inject ephemeral Android signing values into export_presets.cfg during CI only."""

from __future__ import annotations

import argparse
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PRESETS = ROOT / "export_presets.cfg"


def replace(key: str, value: str) -> None:
    text = PRESETS.read_text(encoding="utf-8")
    escaped = value.replace("\\", "/").replace('"', '\\"')
    pattern = rf'^{re.escape(key)}=".*"$'
    replacement = f'{key}="{escaped}"'
    updated, count = re.subn(pattern, replacement, text, flags=re.MULTILINE)
    if count == 0:
        raise SystemExit(f"Missing export preset key: {key}")
    PRESETS.write_text(updated, encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--debug-keystore")
    parser.add_argument("--debug-user", default="androiddebugkey")
    parser.add_argument("--debug-password", default="android")
    parser.add_argument("--release-keystore")
    parser.add_argument("--release-user")
    parser.add_argument("--release-password")
    args = parser.parse_args()

    if args.debug_keystore:
        replace("keystore/debug", str(Path(args.debug_keystore).resolve()))
        replace("keystore/debug_user", args.debug_user)
        replace("keystore/debug_password", args.debug_password)

    if args.release_keystore:
        if not args.release_user or not args.release_password:
            raise SystemExit("Release user/password are required with --release-keystore.")
        replace("keystore/release", str(Path(args.release_keystore).resolve()))
        replace("keystore/release_user", args.release_user)
        replace("keystore/release_password", args.release_password)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
