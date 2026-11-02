#!/usr/bin/env python3
"""Prevent reintroducing outside-source overrides into the Sou Matome mode."""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
entries = (ROOT / "N2CuaTrung/Sources/SouMatomeSourceEntriesView.swift").read_text()
reviews = (ROOT / "N2CuaTrung/Sources/SouMatomePersonalReview.swift").read_text()
swipe = (ROOT / "N2CuaTrung/Sources/KanjiSwipeDeckView.swift").read_text()
details = (ROOT / "N2CuaTrung/Sources/KanjiVocabularyView.swift").read_text()
audit = (ROOT / "scripts/audit_sou_matome_book_only.py").read_text()
packs = (ROOT / "N2CuaTrung/Sources/ContentUpdates.swift").read_text()
whole_books = (ROOT / "N2CuaTrung/Sources/SouMatomeWholeBooksView.swift").read_text()

assert "dictionaryHanViet" not in entries
assert "dictionaryReference" not in entries
assert "entry.dictionaryHanViet" not in reviews
assert "hanViet: entry.sourceHanViet" in reviews
assert "invalidateNonBookHanVietApprovals" in reviews
assert "invalidateNonBookHanVietApprovals" in entries
# Stationary Kanji flashcards never inject an outside dictionary.
# The separate Kanji detail screen keeps other-series lookups isolated.
assert "KangxiReference.info" not in swipe
assert "KangxiReference.radical" not in swipe
assert "if let label = card.hanViet" in swipe
assert "if bookSourceOnly {" in details
assert "study.selectedSeries == .souMatome" in details
assert '"externalSourcesUsed": False' in audit
assert '"verifiedTranslationCount": 0' in audit
assert "bookOnlyEligiblePacks" in packs
assert '"sou-matome-personal-reviewed"' in packs
assert '"sou-matome-personal-exercises"' in packs
assert "pack.seriesId != LearningSeries.souMatome.rawValue" in packs
assert "bookVerifiedPacks.flatMap" in packs
assert "Gói luyện N2 cũ chưa gắn trang sách" in whole_books
print("PASS: textbook-only Sou Matome source policy; external dictionary not used to fill book gaps")
