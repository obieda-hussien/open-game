#!/usr/bin/env python3
"""Synchronize pinned external GLB assets before Godot imports the project.

The repository keeps provenance, byte size and SHA-256 in a small manifest while
large generated binary assets stay out of git history. Downloads are atomic and
cryptographically verified so CI never exports an APK containing a partial or
silently changed model.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import pathlib
import shutil
import sys
import tempfile
import time
import urllib.error
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[1]
DEFAULT_MANIFEST = ROOT / "data" / "assets" / "remote_assets.json"


def sha256_file(path: pathlib.Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def validate_existing(path: pathlib.Path, expected_size: int, expected_sha: str) -> bool:
    if not path.is_file():
        return False
    if expected_size > 0 and path.stat().st_size != expected_size:
        return False
    return sha256_file(path) == expected_sha.lower()


def download_asset(url: str, destination: pathlib.Path, expected_size: int, expected_sha: str) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    last_error: Exception | None = None

    for attempt in range(1, 4):
        temp_path: pathlib.Path | None = None
        try:
            fd, raw_path = tempfile.mkstemp(
                prefix=f".{destination.name}.", suffix=".part", dir=destination.parent
            )
            os.close(fd)
            temp_path = pathlib.Path(raw_path)

            request = urllib.request.Request(
                url,
                headers={
                    "User-Agent": "LastShiftAssetSync/2.0",
                    "Accept": "application/octet-stream,*/*",
                },
            )
            with urllib.request.urlopen(request, timeout=90) as response, temp_path.open("wb") as output:
                shutil.copyfileobj(response, output, length=1024 * 1024)

            actual_size = temp_path.stat().st_size
            if expected_size > 0 and actual_size != expected_size:
                raise RuntimeError(
                    f"size mismatch for {destination.name}: expected {expected_size}, got {actual_size}"
                )

            actual_sha = sha256_file(temp_path)
            if actual_sha != expected_sha.lower():
                raise RuntimeError(
                    f"SHA-256 mismatch for {destination.name}: expected {expected_sha}, got {actual_sha}"
                )

            os.replace(temp_path, destination)
            return
        except (OSError, urllib.error.URLError, RuntimeError) as exc:
            last_error = exc
            if temp_path is not None:
                temp_path.unlink(missing_ok=True)
            if attempt < 3:
                time.sleep(attempt * 1.5)

    raise RuntimeError(f"failed to download {destination.name}: {last_error}")


def load_manifest(path: pathlib.Path) -> dict:
    with path.open("r", encoding="utf-8") as handle:
        data = json.load(handle)
    if int(data.get("version", 0)) < 1 or not isinstance(data.get("assets"), list):
        raise ValueError("asset manifest has an unsupported shape")
    return data


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", type=pathlib.Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--required", action="store_true", help="fail if any asset cannot be synchronized")
    parser.add_argument("--check", action="store_true", help="verify only; never download")
    args = parser.parse_args()

    manifest_path = args.manifest if args.manifest.is_absolute() else ROOT / args.manifest
    try:
        manifest = load_manifest(manifest_path)
    except Exception as exc:
        print(f"[assets] manifest error: {exc}", file=sys.stderr)
        return 2

    failures = 0
    downloaded = 0
    reused = 0

    for asset in manifest["assets"]:
        asset_id = str(asset.get("id", "unnamed"))
        relative_path = pathlib.Path(str(asset["path"]))
        destination = ROOT / relative_path
        expected_size = int(asset.get("size", 0))
        expected_sha = str(asset["sha256"]).lower()
        url = str(asset["url"])

        if validate_existing(destination, expected_size, expected_sha):
            reused += 1
            print(f"[assets] OK    {asset_id:<24} {relative_path}")
            continue

        if args.check:
            failures += 1
            print(f"[assets] MISS  {asset_id:<24} {relative_path}", file=sys.stderr)
            continue

        print(f"[assets] GET   {asset_id:<24} {relative_path}")
        try:
            download_asset(url, destination, expected_size, expected_sha)
            downloaded += 1
            print(f"[assets] READY {asset_id:<24} {destination.stat().st_size / 1024 / 1024:.2f} MiB")
        except Exception as exc:
            failures += 1
            print(f"[assets] ERROR {asset_id}: {exc}", file=sys.stderr)

    print(
        f"[assets] summary: {reused} cached, {downloaded} downloaded, {failures} failed"
    )
    if failures and args.required:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
