#!/usr/bin/env python3
"""Source guardrails for compact iPhone screens and a shared app brand logo."""
from pathlib import Path

root = Path(__file__).resolve().parents[1]
source = root / "N2CuaTrung" / "Sources"
read = lambda f: (root / f).read_text(encoding="utf-8")
app = read("N2CuaTrung/Sources/N2CuaTrungApp.swift")
flash = read("N2CuaTrung/Sources/FlashcardView.swift")
kanji = read("N2CuaTrung/Sources/KanjiSwipeDeckView.swift")
style = read("N2CuaTrung/Sources/Style.swift")
dashboard = read("N2CuaTrung/Sources/DashboardView.swift")
about = read("N2CuaTrung/Sources/AboutView.swift")
widget = read("N2Widget/N2WordWidget.swift")
project = read("project.yml")
icon = read("scripts/generate_clover_icon.swift")

# No screen-fixed stack whose controls extend beneath the TabView.
before_grammar = flash.split("struct GrammarFlashcardView")[0]
assert "ScrollView(.vertical, showsIndicators: false)" in before_grammar
assert "GeometryReader { _ in" not in before_grammar
assert "cardSurface(card, height: 338)" in before_grammar
assert ".lineLimit(2)" in before_grammar
assert ".padding(.bottom, max(24, proxy.safeAreaInsets.bottom) + 92)" not in kanji
assert "cardSurface(card, height: 330)" in kanji
assert ".lineLimit(2)" in style and ".minimumScaleFactor(0.83)" in style
assert "LazyVGrid(" in dashboard
assert ".fixedSize(horizontal: false, vertical: true)" in dashboard

# Exactly the same PNG generator serves the app icon, brand mark and widget.
assert "for index in 0..<3" in icon and "Double(index) * 120" in icon
assert 'let path = "N2CuaTrung/Assets.xcassets/AppIcon.appiconset/AppIcon.png"' in icon
assert '"N2CuaTrung/Assets.xcassets/BrandLogo.imageset"' in icon
assert '"N2Widget/Assets.xcassets/BrandLogo.imageset"' in icon
assert '"BrandLogo"' in style
assert "BrandMark(size: 72)" in dashboard
assert "BrandMark(size: 104)" in about
assert widget.count('Image("BrandLogo")') >= 2
assert 'Image(systemName: "leaf.fill")' not in widget
assert "- path: N2Widget/Assets.xcassets" in project

# Same identifier: reinstalling a correctly signed 1.9.3 test build may
# update the old app while preserving user progress.
assert "PRODUCT_BUNDLE_IDENTIFIER: vn.trung.n2master2027" in project
assert "MARKETING_VERSION: '1.9.3'" in project
assert "CURRENT_PROJECT_VERSION: '13'" in project
print("PASS: compact iPhone layout, one canonical 3-leaf app/widget logo, stable iOS bundle/version")
