"""Run with: python -m unittest discover tests"""

import json
import os
import sys
import unittest
from datetime import date

ROOT = os.path.join(os.path.dirname(__file__), "..")
sys.path.insert(0, os.path.join(ROOT, "api"))

from forecast import forecast, next_restock  # noqa: E402

with open(os.path.join(ROOT, "tests", "forecast_vectors.json"), encoding="utf8") as f:
    VECTORS = json.load(f)


class VectorTests(unittest.TestCase):
    """The same vectors run in test/forecast_test.dart, so Python and Dart can't drift."""

    def test_vectors(self):
        for v in VECTORS:
            with self.subTest(v["name"]):
                logs = [{**l, "product": v["product"]["id"]} for l in v["logs"]]
                out = forecast({"products": [v["product"]], "logs": logs, "events": v["events"], "today": v["today"], "restockDay": v["restockDay"]})["results"][0]
                for key, want in v["expect"].items():
                    got = out[key]
                    if want is None or isinstance(want, bool):
                        self.assertEqual(got, want, key)
                    else:
                        self.assertAlmostEqual(got, want, places=2, msg=key)


class RuleTests(unittest.TestCase):
    def test_restock_day_is_never_zero_days_away(self):
        wednesday = date(2026, 11, 4)
        self.assertEqual(next_restock(wednesday, 3), 7)
        self.assertEqual(next_restock(wednesday, 4), 1)
        self.assertEqual(next_restock(wednesday, 1), 5)
        self.assertEqual(next_restock(wednesday, None), 7)

    def test_bad_input_returns_nothing_rather_than_inventing(self):
        self.assertEqual(forecast({"today": "2026-11-04"})["results"], [])


if __name__ == "__main__":
    unittest.main()
