#!/usr/bin/env python3
"""Source guardrails for compact iPhone screens and a shared app brand logo."""
from pathlib import Path
import re

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
ruby = read("N2CuaTrung/Sources/JapaneseRuby.swift")
series = read("N2CuaTrung/Sources/LearningSeries.swift")
series_picker = read("N2CuaTrung/Sources/LearningSeriesPickerView.swift")

# The actual flashcard/deck screen must NEVER vertically scroll.
# The separate details sheet may scroll for very long examples only.
before_grammar, after_grammar = flash.split("struct GrammarFlashcardView")
vocab_main = before_grammar.split(".sheet(isPresented: $showFullExample)")[0]
grammar_main = after_grammar.split(".sheet(isPresented: $showFullGrammar)")[0]
kanji_main = kanji.split(".sheet(isPresented: $showFullDetails)")[0]
for deck in (vocab_main, grammar_main, kanji_main):
    assert "GeometryReader { proxy in" in deck
    executable = "\n".join(line.split("//", 1)[0] for line in deck.splitlines())
    assert not re.search(r"\bScrollView\s*[({]", executable), "Flashcards must not scroll"
    assert "proxy.size.height" in deck
assert "cardSurface(card, height: cardHeight, compact: compact)" in vocab_main
assert "grammarCard(item, height: cardHeight, compact: compact)" in grammar_main
assert "cardSurface(card, height: cardHeight, compact: compact)" in kanji_main
assert "FuriganaText(" in before_grammar and "centered: true" in before_grammar
assert "FuriganaText(" in after_grammar and "centered: true" in after_grammar
assert "abs(dy) >= 45" not in before_grammar
assert "abs(dy) >= 45" not in after_grammar
assert "abs(dy) >= 45" not in kanji
assert ".padding(.bottom, max(24, proxy.safeAreaInsets.bottom) + 92)" not in kanji
assert ".lineLimit(2)" in style and ".minimumScaleFactor(0.83)" in style
assert 'var centered: Bool = false' in ruby
assert 'centerRows: centered' in ruby
assert 'var icon: String { "books.vertical.fill" }' in series
assert 'SeriesBookMark(active: selected)' in series_picker
assert 'struct SeriesBookMark' in style
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
assert "ASSETCATALOG_COMPILER_APPICON_NAME: ''" in project

# Same identifier: reinstalling a correctly signed 1.9.3 test build may
# update the old app while preserving user progress.
assert "PRODUCT_BUNDLE_IDENTIFIER: vn.trung.n2master2027" in project
assert "MARKETING_VERSION: '1.9.3'" in project
assert "CURRENT_PROJECT_VERSION: '13'" in project
print("PASS: stationary vocabulary/Kanji/grammar flashcards, centered ruby, unified book/app branding")
