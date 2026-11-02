#!/usr/bin/env python3
"""Check offline-source preview and online GitHub audio integration, not CD reproduction."""
from pathlib import Path
import json

root=Path(__file__).resolve().parents[1]
read=lambda p:(root/p).read_text(encoding="utf-8")

manifest=json.loads(read("content-packs/sou-matome-audio-streams.json"))
assert manifest["schemaVersion"] == 1
assert isinstance(manifest["tracks"],list)
assert not manifest["tracks"], "Do not publish unlicensed CD tracks with an unverified permission scope"
audio=read("N2CuaTrung/Sources/SouMatomeOnlineAudio.swift")
lib=read("N2CuaTrung/Sources/SouMatomeLibraryView.swift")
source=read("N2CuaTrung/Sources/SouMatomeSourceEntriesView.swift")
preview=read("N2CuaTrung/Sources/SouMatomeExtractedPracticeView.swift")
flash=read("N2CuaTrung/Sources/FlashcardView.swift")
assert '"raw.githubusercontent.com"' in audio
assert 'AVPlayer(url: track.url)' in lib
assert "onlineAudio.refresh(from: onlineManifestAddress)" in lib
assert "onlineAudio.tracks" in lib
assert "private-draft-candidates.json" in preview
assert "SouMatomeExtractedPracticeView(entries: source.entries)" in source
assert "SouMatomePrivateHanViet.localReadings()" in flash
assert "readings.append(\"—\")" in flash
assert "return parts.isEmpty ? nil : parts.joined" in preview
print("PASS: GitHub HTTPS audio manifest only; source-only private deck and honest Hán–Việt gaps")
