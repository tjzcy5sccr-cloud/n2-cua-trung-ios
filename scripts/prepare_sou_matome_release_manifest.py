#!/usr/bin/env python3
"""Prepare a GitHub Release MP3 streaming manifest from a user's authorized CD files.

Does not upload, publish, or alter source MP3s. Run only for files you have
permission to redistribute through the selected GitHub repository/release.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil


def prepare(source: Path, destination: Path, repo: str, tag: str, manifest: Path):
    if not source.is_dir() or repo.count("/") != 1 or not tag:
        raise ValueError("A folder with CD1/CD2, a GitHub owner/repo and tag are required")
    if any(not t.replace("-", "").replace("_", "").isalnum() for t in (repo.replace("/", ""), tag)):
        raise ValueError("Unsafe repo or release tag")
    recordings = []
    audit = []
    for cd, total in (("CD1", 64), ("CD2", 52)):
        for num in range(1, total + 1):
            original = source / cd / f"{num:02}.mp3"
            if not original.is_file():
                raise ValueError(f"Missing track: {original}")
            with original.open("rb") as f:
                first_bytes = f.read(3)
            if first_bytes != b"ID3" and not (
                len(first_bytes) >= 2 and first_bytes[0] == 0xFF and first_bytes[1] & 0xE0 == 0xE0
            ):
                raise ValueError(f"Not a recognized MP3: {original}")
            if original.stat().st_size <= 1024:
                raise ValueError(f"Empty/invalid MP3: {original}")
            name = f"{cd}_{num:02}.mp3"
            recordings.append({
                "cd": cd,
                "track": num,
                "url": f"https://github.com/{repo}/releases/download/{tag}/{name}",
            })
            digest = hashlib.sha256()
            with original.open("rb") as reader:
                for chunk in iter(lambda: reader.read(1024 * 1024), b""):
                    digest.update(chunk)
            audit.append({"filename": name, "sha256": digest.hexdigest()})
    destination.mkdir(parents=True, exist_ok=True)
    for row in recordings:
        name = f"{row['cd']}_{row['track']:02}.mp3"
        shutil.copy2(source / row["cd"] / f"{row['track']:02}.mp3", destination / name)
    manifest.parent.mkdir(parents=True, exist_ok=True)
    manifest.write_text(json.dumps({"schemaVersion": 1, "tracks": recordings},
                                   ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (destination / "sha256-audit.json").write_text(
        json.dumps(audit, indent=2) + "\n", encoding="utf-8")
    print(f"Prepared {len(recordings)} named assets in {destination}")
    print(f"Generated {manifest}; release URLs become usable only AFTER publishing the assets.")
    print("This tool did NOT upload or publish any MP3.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, help="Extracted directory containing CD1 and CD2")
    parser.add_argument("--repo", required=True, help="GitHub owner/repository")
    parser.add_argument("--tag", required=True, help="Release tag, e.g. soumatome-n2-audio-authorized")
    parser.add_argument("--stage-dir", type=Path, default=Path("build/cd-github-release"))
    parser.add_argument("--manifest", type=Path,
                        default=Path("content-packs/sou-matome-audio-streams.json"))
    args = parser.parse_args()
    prepare(args.source, args.stage_dir, args.repo, args.tag, args.manifest)
