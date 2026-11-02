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
assert "cardSurface(card, height: cardHeight, compact: compact || cardHeight < 270)" in vocab_main
assert "grammarCard(item, height: cardHeight, compact: compact || cardHeight < 260)" in grammar_main
assert "cardSurface(card, height: cardHeight, compact: compact || cardHeight < 265)" in kanji_main
assert "FuriganaText(" in before_grammar and "centered: true" in before_grammar
assert "FuriganaText(" in after_grammar and "centered: true" in after_grammar
# Vertical swipes CHANGE the displayed card, they never move the page.
# The gesture code follows the sheet declaration in these SwiftUI views,
# so check each complete view rather than the pre-sheet layout excerpt.
assert "changeCard(by: dy < 0 ? 1 : -1)" in before_grammar
assert "changeGrammarCard(by: dy < 0 ? 1 : -1)" in after_grammar
assert "changeCard(by: dy < 0 ? 1 : -1)" in kanji
assert "abs(dy) >= 45" in before_grammar and "abs(dy) >= 45" in after_grammar
assert "abs(dy) >= 45" in kanji
assert ".padding(.bottom, max(24, proxy.safeAreaInsets.bottom) + 92)" not in kanji
assert ".lineLimit(2)" in style and ".minimumScaleFactor(0.83)" in style
assert 'var centered: Bool = false' in ruby
assert 'centerRows: centered' in ruby
assert 'var icon: String { "books.vertical.fill" }' in series
assert 'SeriesBookMark(active: selected)' in series_picker
assert 'struct SeriesBookMark' in style
assert "LazyVGrid(" in dashboard
assert ".fixedSize(horizontal: false, vertical: true)" in dashboard

# Every action row must be reserved BEFORE assigning the remaining screen
# height to the card. Keep buttons large enough to tap, including smaller
# iPhones, while never pushing the mastery buttons under the tab bar.
for deck in (vocab_main, grammar_main, kanji_main):
    assert "let actionHeight: CGFloat = 44" in deck
    assert "height: actionHeight" in deck
    assert "let cardHeight = max(72, proxy.size.height - " in deck
    assert ".navigationBarTitleDisplayMode(.inline)" in deck
assert "if height >= 270 && sentence.count" in before_grammar
assert "if height >= 260 && example.text.count" in after_grammar
assert ".frame(height: height)" in before_grammar
assert ".frame(height: height)" in after_grammar
assert ".frame(height: height)" in kanji

def required_height(kind: str, height: int, has_message: bool) -> float:
    compact = height < 690
    short = height < 520
    action_height = 44
    gap = ((4 if short else 6 if compact else 8) if kind == "grammar"
           else (3 if short else 5 if compact else 7))
    vertical_padding = (4 if short else 8 if kind in ("grammar", "kanji") else 7)
    status_height = 30 if kind == "kanji" else 28
    picker_height = (29 if short else 32) if kind == "vocab" else 0
    rows = 2 if kind == "grammar" else 3
    gaps = (6 if has_message else 5) if kind == "vocab" else (
        (4 if has_message else 3) if kind == "grammar" else
        (5 if has_message else 4))
    reserved = (picker_height + status_height + rows * action_height
                + gaps * gap + 2 * vertical_padding
                + (15 if has_message else 0))
    card = max(72, height - reserved)
    return reserved + card

for kind in ("vocab", "grammar", "kanji"):
    for available_height in (340, 375, 410, 450, 520, 600, 689, 690, 760, 820):
        for message in (False, True):
            used = required_height(kind, available_height, message)
            assert used <= available_height, (
                f"{kind}: {used}pt content overflows {available_height}pt"
            )

# Audio buttons are half-width like the known/unknown buttons. The detail
# action remains available in the navigation bar, not as a third narrow button.
vocab_audio = vocab_main.split("// Full-width, equal-sized audio buttons, matching the mastery row.", 1)[1].split("HStack(spacing: 7) {", 2)[1]
assert 'smallAction("Nghe từ", symbol: "speaker.wave.2"' in vocab_audio
assert 'smallAction("Nghe ví dụ", symbol: "waveform"' in vocab_audio
assert 'smallAction("Xem đủ"' not in vocab_main
assert ".toolbar {" in vocab_main and 'Image(systemName: "text.book.closed")' in vocab_main
assert 'accessibilityLabel("Xem đầy đủ ví dụ")' in vocab_main
assert '.font(.subheadline.weight(.semibold))' in before_grammar

# Auto-advance must be three seconds on both vocabulary and Kanji, with
# no interval picker and no 5s/8s controls reappearing in the main view.
for source in (before_grammar, kanji):
    assert "private let autoAdvanceSeconds = 3" in source
    assert "if elapsed >= autoAdvanceSeconds" in source
    assert "intervalSeconds" not in source
    assert 'Picker("Đổi từ sau"' not in source
    assert 'Picker("Đổi chữ sau"' not in source
    assert 'Text("5 giây")' not in source
    assert 'Text("8 giây")' not in source
    assert '"Tự chạy"' in source
    assert '"Tự chạy (3 giây)"' not in source

print("PASS: large two-column audio buttons; vocabulary/Kanji autoplay fixed at 3s")

print("PASS: portrait safe-area layouts keep all controls visible, with 44pt targets")

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

# Same identifier: reinstalling a correctly signed 1.9.4 test build may
# update the old app while preserving user progress.
assert "PRODUCT_BUNDLE_IDENTIFIER: vn.trung.n2master2027" in project
assert "MARKETING_VERSION: '1.9.4'" in project
assert "CURRENT_PROJECT_VERSION: '14'" in project
print("PASS: stationary vocabulary/Kanji/grammar flashcards with four-way swipe, centered ruby, unified brand")
