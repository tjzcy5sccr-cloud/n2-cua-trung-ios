#!/usr/bin/env python3
"""Validate original JLPT N2 curriculum metadata and source-only textbook boundaries."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PATH = ROOT / "N2CuaTrung/Resources/n2-four-series-curriculum.json"
COURSE = ROOT / "N2CuaTrung/Sources/FourSeriesCurriculumView.swift"
PROJECT = ROOT / "project.yml"
DASHBOARD = ROOT / "N2CuaTrung/Sources/DashboardView.swift"
PLAN = ROOT / "N2CuaTrung/Sources/PlanProgressView.swift"

plan = json.loads(PATH.read_text(encoding="utf-8"))
assert plan["schemaVersion"] == 1
assert len(plan["weeks"]) == 35
assert len(plan["tracks"]) == 4
assert {x["id"] for x in plan["tracks"]} == {"mimikara", "shin-kanzen", "so-matome", "speed-master"}
assert plan["daysPerWeek"] == 6 and plan["hoursPerDay"] == 90
assert plan["totalWeeks"] == 35
assert len({x["number"] for x in plan["weeks"]}) == 35
assert [x["number"] for x in plan["weeks"]] == list(range(1, 36))
assert sum(len(x["days"]) for x in plan["weeks"]) == 210
all_ids = [d["id"] for w in plan["weeks"] for d in w["days"]]
assert len(set(all_ids)) == 210
assert all(len(w["days"]) == 6 and len({d["day"] for d in w["days"]}) == 6 for w in plan["weeks"])
assert all(w["theme"] and w["grammarFocus"] and w["dateRange"] for w in plan["weeks"])
assert all(w["days"][i]["primarySkill"] in {"Từ vựng", "Kanji", "Ngữ pháp", "Đọc hiểu", "Nghe hiểu", "Luyện đề"}
           for w in plan["weeks"] for i in range(6))
targets = plan["targets"]
assert targets["vocabulary"] == 6000 and targets["kanji"] == 1100 and targets["grammar"] == 150
for key in ("vocabulary", "kanji", "grammar"):
    assert sum(w["targets"][key] for w in plan["weeks"]) == targets[key]
assert targets["readingSessions"] == 70 and targets["listeningSessions"] == 70
assert "mục tiêu" in plan["targetsNote"].lower() or "chỉ tiêu" in plan["targetsNote"].lower()
sources = COURSE.read_text(encoding="utf-8")
assert 'Bundle.main.url(forResource: "n2-four-series-curriculum"' in sources
assert 'UserDefaults.standard.set(completedDayIDs.sorted()' in sources
assert "store.course.vocab.count" in sources and "store.course.kanji.count" in sources
assert "FreshPracticeSessionView(type: \"Nghe hiểu\")" in sources
assert "FreshPracticeSessionView(type: \"Đọc hiểu\")" in sources
assert "FourSeriesCurriculumView()" in DASHBOARD.read_text(encoding="utf-8")
assert "FourSeriesCurriculumView()" in PLAN.read_text(encoding="utf-8")
assert "N2CuaTrung/Resources/n2-four-series-curriculum.json" in PROJECT.read_text(encoding="utf-8")
print("PASS: 4 study orientations, 35 weeks / 210 actionable days, targets 6000/1100/150.")
print("PASS: SwiftUI integration with original course data and offline iPhone daily checklist.")
print("NOTE: targets are NOT claims of 6000 vocabulary items already built/verified in the IPA.")
