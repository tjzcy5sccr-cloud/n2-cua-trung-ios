#!/usr/bin/env python3
"""Synthetic, original examples only. No lines from commercial textbooks."""
import unittest
from audit_sou_matome_personal_pack import inspect_pack


def good_card(n):
    examples = [
        ("改善", "かいぜん", "cải thiện"),
        ("検討", "けんとう", "cân nhắc"),
        ("予定", "よてい", "dự định"),
        ("環境", "かんきょう", "môi trường"),
    ]
    word, read, meaning = examples[n]
    return {
        "id": "test-vocab-" + str(n),
        "word":word, "reading":read,"meaning":meaning,
        "week":1,"topic":"Nguồn bài luyện tự soạn","example":"",
        "exampleVi":"","meaningStatus":"editorial_reviewed",
        "exampleStatus":"pending"
    }


class PersonalPackAuditTests(unittest.TestCase):
    def test_four_distinct_verified_meanings_enable_quiz(self):
        result = inspect_pack({"vocab":[good_card(i) for i in range(4)],
                               "grammar":[], "kanji":[], "readings":[], "listening":[]})
        self.assertNotIn("quiz_needs_four_unique_meanings", result["issueCounts"])
        self.assertEqual(result["counts"]["approved_vocab"],4)

    def test_unapproved_items_not_marked_ready(self):
        cards=[good_card(i) for i in range(4)]
        cards[3]["meaningStatus"]="pending"
        result=inspect_pack({"vocab":cards,"grammar":[],"kanji":[]})
        self.assertIn("not_editorially_approved",result["issueCounts"])
        self.assertIn("quiz_needs_four_unique_meanings",result["issueCounts"])
        self.assertEqual(result["counts"]["approved_vocab"],3)

    def test_duplicate_id_and_missing_kana_are_flagged(self):
        cards=[good_card(i) for i in range(4)]
        cards[1]["id"]=cards[0]["id"]
        cards[2]["reading"]="not-a-reading"
        result=inspect_pack({"vocab":cards})
        self.assertEqual(result["issueCounts"]["duplicate_id"],1)
        self.assertEqual(result["issueCounts"]["missing_kana_reading"],1)

    def test_page_source_must_exist_and_be_in_range(self):
        cards=[good_card(i) for i in range(4)]
        cards[0]["meaningSource"]="private-book:goi-vi:page-999"
        result=inspect_pack({"vocab":cards})
        self.assertIn("source_page_out_of_range", result["issueCounts"])
        self.assertEqual(result["sourcePagesReferenced"],0)

    def test_no_invented_audio_and_no_bad_answer_indices(self):
        result=inspect_pack({"listening":[{
            "id":"test-one","title":"Bài tự soạn","choices":["A","A"],"answer":9,
            "explanation":"Giải thích độc lập"
        }]})
        self.assertIn("invalid_or_duplicate_choices",result["issueCounts"])
        self.assertIn("invalid_answer",result["issueCounts"])
        self.assertFalse(result["complete"])


if __name__ == "__main__":
    unittest.main()
