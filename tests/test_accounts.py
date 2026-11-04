import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "api"))

from accounts import identifier_keys, key, norm_business, norm_email, norm_phone  # noqa: E402


class Normalising(unittest.TestCase):
    def test_business_names_match_loosely(self):
        self.assertEqual(norm_business("  Ama  Provisions! "), "ama provisions")
        self.assertEqual(norm_business("AMA provisions"), "ama provisions")
        self.assertEqual(norm_business("Côte Mart"), "cote mart")

    def test_phone_numbers(self):
        for typed in ["0241234567", "024 123 4567", "+233 24 123 4567", "233241234567", "00233241234567"]:
            self.assertEqual(norm_phone(typed), "+233241234567", typed)
        self.assertEqual(norm_phone("+234 801 234 5678"), "+2348012345678")
        self.assertIsNone(norm_phone("Ama Provisions"))
        self.assertIsNone(norm_phone("12345"))

    def test_email(self):
        self.assertEqual(norm_email(" Ama@Shop.COM "), "ama@shop.com")
        self.assertIsNone(norm_email("ama provisions"))

    def test_identifier_tries_every_kind(self):
        kinds = [k for k, _ in identifier_keys("0241234567")]
        self.assertEqual(kinds, ["phone", "business"])
        self.assertEqual([k for k, _ in identifier_keys("ama@shop.com")][0], "email")
        self.assertEqual(identifier_keys("Ama Provisions"), [("business", "ama provisions")])

    def test_keys_hide_the_value(self):
        k = key("phone", "+233241234567")
        self.assertEqual(len(k), 64)
        self.assertNotIn("241234567", k)


if __name__ == "__main__":
    unittest.main()
