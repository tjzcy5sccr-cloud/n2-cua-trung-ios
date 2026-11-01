#!/usr/bin/env python3
"""Entirely synthetic Japanese/Vietnamese fixtures; no textbook excerpts."""
import unittest
from extract_sou_matome_private_candidates import grammar_candidates


class FakePDFPage:
    def __init__(self, text):
        self.text = text

    def get_text(self, mode):
        if mode == "text":
            return self.text
        raise AssertionError("Unexpected read format")


class GrammarCandidateTests(unittest.TestCase):
    def test_several_patterns_from_one_page(self):
        sample = (
            "Bài 1: Mẫu tự biên soạn\n"
            "A: 時間があれば。\n"
            "Ý nghĩa: nếu có thời gian\n"
            "Cách chia: 動詞\n"
            "B : 忘れないように。\n"
            "Ý nghĩa: để không quên\n"
            "練習\n"
        )
        cards = grammar_candidates(FakePDFPage(sample), 18)
        self.assertEqual(len(cards), 2)
        self.assertEqual(cards[0]["heading"], "時間があれば。")
        self.assertEqual(cards[0]["detail"], "nếu có thời gian")
        self.assertEqual(cards[1]["heading"], "忘れないように。")
        self.assertEqual(cards[1]["detail"], "để không quên")
        self.assertEqual([c["id"] for c in cards],
                         ["bunpou-vi:18:0", "bunpou-vi:18:1"])

    def test_does_not_make_up_meaning_when_missing(self):
        cards = grammar_candidates(
            FakePDFPage("A: しなければならない\n例：これは自作の例。\n"), 3)
        self.assertEqual(len(cards), 1)
        self.assertEqual(cards[0]["detail"], "")
        self.assertIn("CHECK_FURIGANA_AND_LINE_BREAKS",
                      cards[0]["qaFlags"])

    def test_furigana_break_keeps_candidate_flagged(self):
        cards = grammar_candidates(
            FakePDFPage("A; 読\nよ\nみたい\nÝ nghĩa: muốn đọc\n"), 5)
        self.assertEqual(len(cards), 1)
        self.assertEqual(cards[0]["heading"], "読")
        self.assertTrue(cards[0]["qaFlags"])


if __name__ == "__main__":
    unittest.main()
