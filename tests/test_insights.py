"""Run with:  python -m unittest discover tests"""

import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "api"))

from insights import analyse, demo_business  # noqa: E402


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


class DemoTests(unittest.TestCase):
    def test_demo_gives_three_different_actions(self):
        r = analyse(demo_business("2026-10-14"))
        self.assertEqual(len(r["actions"]), 3)
        self.assertEqual(len({a["rule"] for a in r["actions"]}), 3)
        self.assertIn("Reply 1, 2 or 3", r["whatsapp"])

    def test_demo_sees_saturday_pattern(self):
        r = analyse(demo_business("2026-10-14"))
        self.assertTrue(any(a["rule"] == "R4" and "Saturday" in a["title"] for a in r["actions"] + r["more"]))


if __name__ == "__main__":
    unittest.main()
