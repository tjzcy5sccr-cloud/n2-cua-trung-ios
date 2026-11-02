#!/usr/bin/env python3
"""Tests with synthetic example lines only (no commercial book content)."""
import unittest
from unittest.mock import patch
from audit_sou_matome_book_only import check_source_records, compact


class Page:
    def __init__(self, source):
        self.source = source

    def get_text(self, mode):
        assert mode == "text"
        return self.source


class Book:
    def __init__(self, *pages):
        self.pages = pages

    def __len__(self):
        return len(self.pages)

    def __getitem__(self, key):
        return Page(self.pages[key])


class BookOnlyAuditTests(unittest.TestCase):
    def test_source_page_match_and_gaps_are_not_approved(self):
        fixture = {
            "goi-vi": Book("改善する かいぜんする\ncải thiện", "あ"),
            "kanji-vi": Book("①調 ちょう ĐIỀU"),
            "bunpou-vi": Book("A: 〜ように\nÝ nghĩa: để"),
        }
        entries = [
            dict(id="goi-vi:1:0", bookId="goi-vi", page=1,
                 heading="改善する", reading="かいぜんする", detail="cải thiện"),
            dict(id="goi-vi:2:0", bookId="goi-vi", page=2,
                 heading="不足", reading="ふそく", detail=""),
            dict(id="kanji-vi:1:0", bookId="kanji-vi", page=1,
                 heading="調", sourceHanViet="ĐIỀU", detail=""),
            dict(id="bunpou-vi:1:0", bookId="bunpou-vi", page=1,
                 heading="〜ように", detail="để"),
        ]
        with patch("audit_sou_matome_book_only.KNOWN",
                   {"goi-vi": 2, "kanji-vi": 1, "bunpou-vi": 1}):
            out = check_source_records(entries, fixture)
        self.assertFalse(out["externalSourcesUsed"])
        self.assertEqual(out["verifiedTranslationCount"], 0)
        problems = {(row["id"], row["reason"])
                    for row in out["recordsNeedingReview"]}
        self.assertIn(("goi-vi:2:0",
                       "HEADING_NOT_CONTIGUOUS_IN_SOURCE_PDF"), problems)
        self.assertIn(("goi-vi:2:0",
                       "MEANING_NOT_CAPTURED_FROM_SOURCE_PDF"), problems)
        self.assertNotIn(("goi-vi:1:0",
                          "HEADING_NOT_CONTIGUOUS_IN_SOURCE_PDF"), problems)

    def test_requires_same_exact_page(self):
        with patch("audit_sou_matome_book_only.KNOWN",
                   {"goi-vi": 1, "kanji-vi": 1, "bunpou-vi": 1}):
            with self.assertRaises(ValueError):
                check_source_records([
                    dict(id="goi-vi:4:0", bookId="goi-vi",
                         page=4, heading="改善", detail="cải thiện")
                ], {"goi-vi": Book("改善"),
                    "kanji-vi": Book("調"), "bunpou-vi": Book("〜ように")})

    def test_unicode_width_and_whitespace(self):
        self.assertEqual(compact(" 改　善\nする "), "改善する")


if __name__ == "__main__":
    unittest.main()
