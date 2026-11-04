"""Run with:  python -m unittest discover tests"""

import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "api"))

from datetime import date, timedelta  # noqa: E402

from insights import analyse  # noqa: E402


def shop(moves, items=None, today="2026-10-12"):
    items = items or [{"id": "rice", "name": "Rice", "unit": "bag", "cost": 90, "price": 115, "reorder": 5}]
    return {"business": {"name": "Test", "owner": "Ama"}, "items": items, "movements": moves, "today": today}


class StockTests(unittest.TestCase):
    def test_stock_on_hand(self):
        r = analyse(shop([
            {"item": "rice", "type": "opening", "qty": 20, "date": "2026-10-10"},
            {"item": "rice", "type": "received", "qty": 5, "date": "2026-10-11"},
            {"item": "rice", "type": "sale", "qty": 7, "date": "2026-10-11"},
            {"item": "rice", "type": "waste", "qty": 1, "date": "2026-10-12"},
        ]))
        self.assertEqual(r["items"][0]["on_hand"], 17)

    def test_low_stock_goes_on_market_list(self):
        r = analyse(shop([
            {"item": "rice", "type": "opening", "qty": 6, "date": "2026-10-11"},
            {"item": "rice", "type": "sale", "qty": 3, "date": "2026-10-12"},
        ]))
        self.assertEqual(r["actions"][0]["rule"], "R1")
        self.assertIn("Market list", r["actions"][0]["title"])


class RuleTests(unittest.TestCase):
    def test_no_records_asks_for_first_tally(self):
        self.assertEqual(analyse(shop([]))["actions"][0]["rule"], "R8")

    def test_data_gap_nudge(self):
        r = analyse(shop([{"item": "rice", "type": "sale", "qty": 1, "date": "2026-10-01"}]))
        self.assertTrue(any(a["rule"] == "R8" for a in r["actions"]))

    def test_margin_squeeze_after_supplier_rise(self):
        r = analyse(shop([
            {"item": "rice", "type": "opening", "qty": 50, "date": "2026-10-10"},
            {"item": "rice", "type": "received", "qty": 10, "cost": 110, "date": "2026-10-11"},
            {"item": "rice", "type": "sale", "qty": 2, "date": "2026-10-12"},
        ]))
        squeeze = [a for a in r["actions"] + r["more"] if a["rule"] == "R5"]
        self.assertTrue(squeeze)
        self.assertIn("went up", squeeze[0]["why"])


def three_weeks():
    """Test-only fixture: a perishable that sells 20 a day but only 8 on Saturdays."""
    items = [{"id": "bread", "name": "Bread", "unit": "loaf", "cost": 10, "price": 15, "perishable": True}]
    start, moves = date(2026, 9, 14), []
    for n in range(28):
        d = start + timedelta(days=n)
        sold = 8 if d.weekday() == 5 else 20
        moves += [
            {"item": "bread", "type": "received", "qty": 22, "date": d.isoformat()},
            {"item": "bread", "type": "sale", "qty": sold, "date": d.isoformat()},
            {"item": "bread", "type": "waste", "qty": 22 - sold, "date": d.isoformat()},
        ]
    return shop(moves, items, today=(start + timedelta(days=27)).isoformat())


class PatternTests(unittest.TestCase):
    def test_saturday_pattern_and_waste(self):
        r = analyse(three_weeks())
        rules = {a["rule"]: a for a in r["actions"] + r["more"]}
        self.assertIn("Saturday", rules["R4"]["title"])
        self.assertIn("WASTE", rules)
        self.assertIn("Reply 1, 2 or 3", r["whatsapp"])

    def test_owner_event_changes_advice(self):
        data = three_weeks()
        data["events"] = [{"name": "School break", "start": "2026-10-13", "effect": -0.4}]
        r = analyse(data)
        cal = [a for a in r["actions"] + r["more"] if a["rule"] == "R7"]
        self.assertIn("School break", cal[0]["title"])

    def test_at_most_one_action_per_rule(self):
        r = analyse(three_weeks())
        self.assertEqual(len({a["rule"] for a in r["actions"]}), len(r["actions"]))


if __name__ == "__main__":
    unittest.main()
