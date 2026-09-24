"""Ciclo 15 — um motivo por teste. CSVs sintéticos."""
import importlib.util
import pathlib
import unittest
from datetime import date

HERE = pathlib.Path(__file__).resolve().parent
_spec = importlib.util.spec_from_file_location("room_readiness_sec", HERE / "room_readiness_sec.py")
sec = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(sec)

TODAY = date(2026, 9, 24)
DEV = sec.read_devices(HERE / "examples" / "room-devices.csv")
OUT = sec.classify(DEV, TODAY)
BY = {(f["kind"], f["room"], f["device"]) for f in OUT["findings"]}


class Rules(unittest.TestCase):
    def test_default_creds_is_high(self):
        self.assertIn(("DEFAULT_CREDS", "Room-02", "controller"), BY)
        self.assertIn(("DEFAULT_CREDS", "Room-07", "controller"), BY)

    def test_av_device_on_corp_lan_is_wrong_segment(self):
        self.assertIn(("WRONG_SEGMENT", "Room-03", "codec"), BY)

    def test_av_device_on_guest_is_wrong_segment_too(self):
        self.assertIn(("WRONG_SEGMENT", "Room-05", "camera"), BY)

    def test_remote_mgmt_on_av_vlan_is_fine_but_outside_is_exposed(self):
        self.assertNotIn(("REMOTE_MGMT_EXPOSED", "Room-01", "codec"), BY)
        self.assertIn(("REMOTE_MGMT_EXPOSED", "Room-03", "codec"), BY)
        self.assertIn(("REMOTE_MGMT_EXPOSED", "Room-05", "camera"), BY)

    def test_firmware_older_than_180_days_is_stale(self):
        self.assertIn(("FIRMWARE_STALE", "Room-02", "controller"), BY)   # 2025-11-01
        self.assertNotIn(("FIRMWARE_STALE", "Room-06", "codec"), BY)     # 2026-09-01

    def test_offline_after_7_days(self):
        self.assertIn(("OFFLINE", "Room-04", "display"), BY)             # 2026-09-10

    def test_clean_room_has_no_findings(self):
        self.assertFalse(any(k[1] == "Room-06" for k in BY))


class Contract(unittest.TestCase):
    def test_secure_room_pct_counts_rooms_with_HIGH_only(self):
        # HIGH em Room-02, 03, 05, 07 -> 4 de 7 salas; Room-04 so tem MEDIUM
        self.assertEqual(OUT["rooms"], 7); self.assertEqual(OUT["rooms_with_high"], 4)
        self.assertEqual(OUT["secure_room_pct"], round(100 * 3 / 7, 1))

    def test_missing_column_is_refused_not_guessed(self):
        p = HERE / "examples" / "_tmp_bad.csv"
        p.write_text("room,device_type\nRoom-01,display\n", encoding="utf-8")
        try:
            with self.assertRaises(ValueError):
                sec.read_devices(p)
        finally:
            p.unlink()

    def test_public_report_untouched_and_used(self):
        ops = sec.rr.build_report(sec.rr.read_results(HERE / "examples" / "synthetic-room-results.csv"))
        self.assertEqual(ops.total, ops.passed + ops.warning + ops.failed)
        self.assertEqual(ops.readiness_rate, round(100 * ops.passed / ops.total, 1))

    def test_cli_exit_1_on_high_and_2_on_bad_csv(self):
        self.assertEqual(sec.main(["--results", str(HERE / "examples" / "synthetic-room-results.csv"), "--devices", str(HERE / "examples" / "room-devices.csv"), "--json"]), 1)
        self.assertEqual(sec.main(["--results", str(HERE / "examples" / "synthetic-room-results.csv"), "--devices", str(HERE / "nope.csv"), "--json"]), 2)

    def test_never_decides(self):
        self.assertTrue(OUT["decision"].startswith("NENHUMA"))


if __name__ == "__main__":
    unittest.main()
