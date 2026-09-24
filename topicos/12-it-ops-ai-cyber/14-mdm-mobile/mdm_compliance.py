#!/usr/bin/env python3
"""Conformidade de dispositivos móveis/MDM — Ciclo 14 (sem tenant; schema oficial do Graph).

Lê objectos `managedDevice` (nomes de campo e enums do $metadata oficial, 24/09/2026) e
classifica risco. O que o portal de MDM mostra como uma cor, aqui é uma regra com evidência:

  NONCOMPLIANT           complianceState = noncompliant | conflict | error
  GRACE_EXPIRED          inGracePeriod com complianceGracePeriodExpirationDateTime no passado
  JAILBROKEN             jailBroken = "True"                         (string no schema!)
  UNENCRYPTED            isEncrypted = false
  STALE_SYNC             lastSyncDateTime > N dias                   (defeito 14)
  UNREGISTERED           azureADRegistered = false ou azureADDeviceId vazio -> nao se cruza
                         com SigninLogs (regra 3 do Ciclo 5 fica cega para ele)
  COMPLIANCE_UNKNOWN     complianceState = unknown -> Unknown != compliant
  PERSONAL_PRIVILEGED    managedDeviceOwnerType = personal em conta de servico/privilegiada
                         (heuristica por prefixo svc-/adm-; declarada)

Cada achado leva a chave de correlacao com identidade (azureADDeviceId <-> SigninLogs
DeviceDetail.deviceId) — e o que liga este ciclo a regra 3 do Ciclo 5. Biblioteca padrao.
"""

from __future__ import annotations

import argparse
import json
import pathlib
import sys
from datetime import datetime, timedelta, timezone

NONCOMPLIANT_STATES = {"noncompliant", "conflict", "error"}
PRIV_PREFIXES = ("svc-", "adm-")


def _t(s):
    if not s:
        return None
    return datetime.fromisoformat(str(s).replace("Z", "+00:00"))


def classify(devices: list[dict], now: datetime, stale_days: int = 14) -> dict:
    findings = []

    def add(kind, d, sev, evidence, reason):
        findings.append({"kind": kind, "deviceName": d.get("deviceName", ""), "user": d.get("userPrincipalName", ""),
                         "os": d.get("operatingSystem", ""), "severity": sev, "evidence": evidence, "reason": reason,
                         "joinKey": {"azureADDeviceId": d.get("azureADDeviceId", "")}})

    for d in devices:
        if "_note" in d:
            continue
        cs = d.get("complianceState", "unknown")
        if cs in NONCOMPLIANT_STATES:
            add("NONCOMPLIANT", d, "HIGH", f"complianceState={cs}", "falha politica; com sign-in bem-sucedido e a linha da regra 3 do Ciclo 5")
        elif cs == "inGracePeriod":
            exp = _t(d.get("complianceGracePeriodExpirationDateTime"))
            if exp and exp < now:
                add("GRACE_EXPIRED", d, "HIGH", f"grace expirou {exp.date()}", "o periodo de graca acabou; na pratica e noncompliant")
            else:
                add("GRACE_PERIOD", d, "MEDIUM", f"inGracePeriod ate {exp.date() if exp else '?'}", "janela para corrigir; monitorizar")
        elif cs == "unknown":
            add("COMPLIANCE_UNKNOWN", d, "MEDIUM", "complianceState=unknown", "Unknown != compliant; normalmente enrolment recente ou agente sem reporte")
        if str(d.get("jailBroken", "")).lower() == "true":
            add("JAILBROKEN", d, "HIGH", "jailBroken=True", "controlo do SO comprometido; MDM nao consegue garantir nada")
        if d.get("isEncrypted") is False:
            add("UNENCRYPTED", d, "HIGH", "isEncrypted=false", "dados em claro se o dispositivo for perdido")
        ls = _t(d.get("lastSyncDateTime"))
        if ls and (now - ls) > timedelta(days=stale_days):
            add("STALE_SYNC", d, "MEDIUM", f"lastSync={ls.date()} ({(now - ls).days}d)", "o estado reportado e velho; 'compliant' de ha um mes nao e compliant")
        if not d.get("azureADRegistered") or not d.get("azureADDeviceId"):
            add("UNREGISTERED", d, "MEDIUM", f"azureADRegistered={d.get('azureADRegistered')} azureADDeviceId={d.get('azureADDeviceId')!r}", "sem chave para cruzar com SigninLogs: a regra de identidade nao o ve")
        upn = str(d.get("userPrincipalName", "")).lower()
        if d.get("managedDeviceOwnerType") == "personal" and upn.startswith(PRIV_PREFIXES):
            add("PERSONAL_PRIVILEGED", d, "HIGH", f"owner=personal upn={upn}", "conta privilegiada em dispositivo pessoal")

    order = {"HIGH": 0, "MEDIUM": 1, "INFO": 2}
    findings.sort(key=lambda f: (order[f["severity"]], f["kind"], f["deviceName"]))
    total = len([d for d in devices if "_note" not in d])
    flagged = len({f["deviceName"] for f in findings})
    return {"devices": total, "devices_with_findings": flagged,
            "compliance_pct": round(100 * (total - flagged) / total, 1) if total else 0.0,
            "findings": findings, "decision": "NENHUMA - relatorio para o humano; nenhum dispositivo foi retirado, apagado ou bloqueado"}


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n", 1)[0])
    ap.add_argument("--devices", required=True, type=pathlib.Path)
    ap.add_argument("--now", default="2026-09-24T00:00:00Z")
    ap.add_argument("--json", action="store_true")
    a = ap.parse_args(argv)
    out = classify(json.loads(a.devices.read_text(encoding="utf-8")), _t(a.now))
    sys.stdout.reconfigure(encoding="utf-8")
    if a.json:
        print(json.dumps(out, ensure_ascii=False, indent=2))
    else:
        print(f"devices={out['devices']} with_findings={out['devices_with_findings']} clean={out['compliance_pct']}%")
        for f in out["findings"]:
            print(f"  [{f['severity']:<6}] {f['kind']:<20} {f['deviceName']:<9} {f['os']:<8} {f['evidence']}")
        print(f"decision: {out['decision']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
