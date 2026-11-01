#!/usr/bin/env python3
"""Synthetic source metadata fixtures, no copyright-protected excerpts."""
import unittest
from enrich_sou_matome_kanji_source_metadata import parse_source, extract


class FakePage:
    def __init__(self, lines):
        self.lines = lines

    def get_text(self, mode):
        assert mode == "text"
        return "\n".join(self.lines)


class PrivateKanjiSourceTests(unittest.TestCase):
    def test_han_viet_kana_and_source_headings(self):
        page = FakePage([
            "① 禁", "CẤM", "きん", "禁止",
            "② 努", "VỤ", "ど／つと・める", "努力",
            "③ 突", "とつ／つ・く", "突然"
        ])
        got = parse_source(page, 25)
        self.assertEqual(len(got), 3)
        self.assertEqual(got[0]["id"], "kanji-vi:25:0")
        self.assertEqual(got[0]["sourceHanViet"], "CẤM")
        self.assertEqual(got[0]["sourceOnKun"], "きん")
        # Preserve the ORIGINAL source even when it conflicts with external
        # dictionary reference. A reviewer must resolve this discrepancy.
        self.assertEqual(got[1]["sourceHanViet"], "VỤ")
        self.assertEqual(got[2]["sourceHanViet"], "")
        self.assertEqual(got[2]["sourceOnKun"], "とつ／つ・く")

    def test_inline_label_and_reading(self):
        page = FakePage([
            "① 横", "HOÀNH, HOÀNG おう／よこ", "横断", "道"
        ])
        got = parse_source(page, 30)
        self.assertEqual(got[0]["sourceHanViet"], "HOÀNH, HOÀNG")
        self.assertEqual(got[0]["sourceOnKun"], "おう／よこ")

    def test_multiline_and_cross_page_kana_are_reassembled(self):
        first = FakePage(["① 険", "HIỂM", "けん／けわ・"])
        next_page = FakePage([
            "Kanji Somatome N2", "Page 2", "しい", "危険"
        ])
        rows = extract([first, next_page])
        self.assertEqual(rows[0]["sourceOnKun"], "けん／けわ・しい")
        self.assertTrue(rows[0]["_reading_reassembled"])

        same_page = FakePage([
            "① 覚", "GIÁC", "かく／おぼ・える／さ・ます／さ・",
            "める", "覚える"
        ])
        parsed = parse_source(same_page, 11)
        self.assertEqual(parsed[0]["sourceOnKun"],
                         "かく／おぼ・える／さ・ます／さ・める")


if __name__ == "__main__":
    unittest.main()
