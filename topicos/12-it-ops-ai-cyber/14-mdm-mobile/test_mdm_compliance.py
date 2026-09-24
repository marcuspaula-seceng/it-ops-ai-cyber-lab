"""Ciclo 14 — um motivo por teste. Dataset sintético com nomes/enums oficiais."""
import importlib.util
import json
import pathlib
import unittest
from datetime import datetime, timezone

HERE = pathlib.Path(__file__).resolve().parent
_spec = importlib.util.spec_from_file_location("mdm_compliance", HERE / "mdm_compliance.py")
mdm = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(mdm)

NOW = datetime(2026, 9, 24, tzinfo=timezone.utc)
DEV = json.loads((HERE / "examples" / "managed-devices.json").read_text(encoding="utf-8"))
OUT = mdm.classify(DEV, NOW)
BY = {(f["kind"], f["deviceName"]): f for f in OUT["findings"]}


class Rules(unittest.TestCase):
    def test_noncompliant_is_high_and_carries_the_join_key(self):
        f = BY[("NONCOMPLIANT", "MDM-0002")]
        self.assertEqual(f["severity"], "HIGH"); self.assertEqual(f["joinKey"]["azureADDeviceId"], "aad-0002")

    def test_jailbroken_is_a_string_in_the_schema_and_still_detected(self):
        self.assertIn(("JAILBROKEN", "MDM-0003"), BY)

    def test_unencrypted_kiosk_is_high(self):
        self.assertEqual(BY[("UNENCRYPTED", "MDM-0004")]["severity"], "HIGH")

    def test_grace_period_expired_is_high_not_medium(self):
        self.assertEqual(BY[("GRACE_EXPIRED", "MDM-0005")]["severity"], "HIGH")
        self.assertNotIn(("GRACE_PERIOD", "MDM-0005"), BY)

    def test_stale_sync_after_14_days(self):
        self.assertIn(("STALE_SYNC", "MDM-0006"), BY)
        self.assertNotIn(("STALE_SYNC", "MDM-0001"), BY)

    def test_unknown_compliance_is_flagged_not_trusted(self):
        self.assertIn(("COMPLIANCE_UNKNOWN", "MDM-0007"), BY)

    def test_unregistered_device_is_invisible_to_identity_rule(self):
        f = BY[("UNREGISTERED", "MDM-0007")]
        self.assertIn("SigninLogs", f["reason"])

    def test_clean_device_has_no_findings(self):
        self.assertFalse(any(k[1] == "MDM-0008" for k in BY))


class Contract(unittest.TestCase):
    def test_compliance_pct_counts_devices_not_findings(self):
        self.assertEqual(OUT["devices"], 8)
        self.assertEqual(OUT["compliance_pct"], round(100 * (8 - OUT["devices_with_findings"]) / 8, 1))

    def test_note_row_is_ignored(self):
        self.assertEqual(OUT["devices"], 8)

    def test_never_decides(self):
        self.assertTrue(OUT["decision"].startswith("NENHUMA"))

    def test_stale_threshold_is_a_parameter(self):
        out = mdm.classify(DEV, NOW, stale_days=90)
        self.assertFalse(any(f["kind"] == "STALE_SYNC" for f in out["findings"]))


if __name__ == "__main__":
    unittest.main()
