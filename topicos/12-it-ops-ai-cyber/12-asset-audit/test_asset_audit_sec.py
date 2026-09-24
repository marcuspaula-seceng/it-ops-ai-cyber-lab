"""Ciclo 12 — testes que falham pelo motivo certo. Dados sintéticos (v2)."""
import importlib.util
import pathlib
import unittest

HERE = pathlib.Path(__file__).resolve().parent
_spec = importlib.util.spec_from_file_location("asset_audit_sec", HERE / "asset_audit_sec.py")
sec = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(sec)

EXP = sec.read_rows(HERE / "examples" / "expected-assets-v2.csv")
SCN = sec.read_scans(HERE / "examples" / "scanned-assets-v2.csv")
OUT = sec.classify(EXP, SCN)
BY = {(f["kind"], f["asset_tag"]): f for f in OUT["findings"]}


class Categories(unittest.TestCase):
    def test_public_reconcile_is_untouched_and_agrees(self):
        self.assertEqual(OUT["summary"], {"matched": 8, "missing": 3, "unexpected": 2, "duplicate": 1})

    def test_unknown_asset_on_the_floor_is_high(self):
        self.assertEqual(BY[("UNKNOWN_ASSET", "SAMPLE-0099")]["severity"], "HIGH")

    def test_in_stock_laptop_missing_is_high_but_dock_is_medium(self):
        self.assertEqual(BY[("LOST_OR_UNTRACKED", "SAMPLE-0010")]["severity"], "HIGH")
        self.assertNotIn(("LOST_OR_UNTRACKED", "SAMPLE-0011"), BY)  # dock foi scanned

    def test_assigned_not_in_stock_is_info_not_a_loss(self):
        self.assertEqual(BY[("ASSIGNED_NOT_IN_STOCK", "SAMPLE-0006")]["severity"], "INFO")
        self.assertEqual(BY[("ASSIGNED_NOT_IN_STOCK", "SAMPLE-0007")]["severity"], "INFO")

    def test_returned_laptop_found_at_a_desk_is_high(self):
        f = BY[("RETURNED_STILL_ACTIVE", "SAMPLE-0008")]
        self.assertEqual(f["severity"], "HIGH")
        self.assertIn("floor-3-desk-12", f["evidence"])

    def test_returned_monitor_in_stock_room_is_not_flagged(self):
        self.assertNotIn(("RETURNED_STILL_ACTIVE", "SAMPLE-0009"), BY)

    def test_duplicate_scan_names_both_scanners(self):
        f = BY[("PROCESS_ERROR", "SAMPLE-0003")]
        self.assertIn("scanner-a", f["evidence"]); self.assertIn("scanner-b", f["evidence"])


class Contract(unittest.TestCase):
    def test_visibility_percentage(self):
        self.assertEqual(OUT["visibility_pct"], round(100 * 8 / 11, 1))

    def test_high_first_then_medium_then_info(self):
        sev = [f["severity"] for f in OUT["findings"]]
        self.assertEqual(sev, sorted(sev, key={"HIGH": 0, "MEDIUM": 1, "INFO": 2}.get))

    def test_never_decides(self):
        self.assertTrue(OUT["decision"].startswith("NENHUMA"))

    def test_inputs_not_modified(self):
        self.assertEqual(sec.read_rows(HERE / "examples" / "expected-assets-v2.csv"), EXP)


if __name__ == "__main__":
    unittest.main()
