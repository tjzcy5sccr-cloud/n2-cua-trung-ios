#!/usr/bin/env python3
"""Reject incomplete, mislabelled or accidentally publishable research queues."""
import collections
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
Q=ROOT/"research/licensed-cumulative-queue"
summary=json.loads((Q/"summary.json").read_text(encoding="utf-8"))
assert summary["status"]=="SOURCE_ONLY_UNREVIEWED"
assert summary["not100PercentComplete"] and summary["notOfficialJLPTList"]
assert summary["externalExpertVerifiedCount"]==0
assert summary["license"]=="CC BY-SA 4.0"
assert all(x["commit"] and len(x["commit"])==40 for x in summary["sources"])
assert set(summary["selectedCandidateCounts"])=={"vocab","kanji","grammar"}
used=set()
for cat in ("vocab","kanji","grammar"):
    path=Q/f"{cat}-source-only.jsonl"
    rows=[json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line]
    expected=summary["selectedCandidateCounts"][cat]
    assert len(rows)==expected and len(rows)>0,(cat,len(rows),expected)
    assert len(rows)<=summary["target"][{"vocab":"vocabulary","kanji":"kanji","grammar":"grammar"}[cat]]
    ids=[x["id"] for x in rows]
    assert len(ids)==len(set(ids)) and not any(x in used for x in ids),cat
    used.update(ids)
    for x in rows:
        assert x["reviewStatus"]=="candidate_only_not_approved"
        assert x["canPublishInIPA"] is False
        assert len(x["reviewChecklist"])==5
        assert x["sourceLicense"]=="CC BY-SA 4.0"
        assert 1<=x["curriculumWeek"]<=35
        assert x["learningTrackHint"] in {"mimikara","shin-kanzen","sou-matome","speed-master"}
        if x["sourceLevel"]=="N1":
            assert x["isN2OrLowerFoundation"] is False
            assert "N1_extension_not_required_for_N2" in x["qualityFlags"]
    assert all(x["id"].startswith("research-") for x in rows)
    print("PASS",cat,expected,"unapproved research candidates only")
# N2-specific goal must NEVER be filled using beginner N5/N4 grammar.
grammar_levels=summary["candidateByLevel"]["grammar"]
assert grammar_levels.get("N2",0)>=110,grammar_levels
assert grammar_levels.get("N5",0)==0 and grammar_levels.get("N4",0)==0
assert sum(grammar_levels.values())==summary["selectedCandidateCounts"]["grammar"]
weeks=json.loads((Q/"35-week-review-index.json").read_text(encoding="utf-8"))["weeks"]
assert len(weeks)==35 and [x["week"] for x in weeks]==list(range(1,36))
for cat in ("vocab","kanji","grammar"):
    all_week_ids=[name for week in weeks for name in week["ids"][cat]]
    count=summary["selectedCandidateCounts"][cat]
    assert len(all_week_ids)==count and len(set(all_week_ids))==count
radicals=json.loads((Q/"214-radicals-source-only.json").read_text(encoding="utf-8"))
assert radicals["count"] == 214 and len(radicals["entries"]) == 214
assert [x["number"] for x in radicals["entries"]] == list(range(1,215))
assert len({x["baseIdeograph"] for x in radicals["entries"]}) == 214
assert all(x["canPublishInIPA"] is False and x["vietnameseMeaning"] is None
           and x["reviewStatus"] == "pending_manual_han_viet_review"
           for x in radicals["entries"])
assert not any("research/licensed-cumulative-queue" in line
                for line in (ROOT/"project.yml").read_text(encoding="utf-8").splitlines())
print("PASS: 214 Unicode radicals, untranslated draft only; no IPA leakage.")
print("PASS 35-week research index; no candidate connected to iOS project.")
