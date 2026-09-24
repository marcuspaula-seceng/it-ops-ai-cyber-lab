#!/usr/bin/env python3
"""Salas de reunião como IoT do escritório — Ciclo 15 (IT Ops × AI × Cyber).

O `room_readiness_report.py` público (projecto 05) responde "a sala funciona?" (pass/warning/
fail por sala). Esta camada responde "os dispositivos da sala são seguros?" — displays, codecs,
controladores e câmaras são computadores em rede que ninguém trata como computadores:

  DEFAULT_CREDS      credenciais de fábrica por mudar                        HIGH
  WRONG_SEGMENT      dispositivo AV na LAN corporativa ou de convidados       HIGH (corp) / HIGH (guest)
  REMOTE_MGMT_EXPOSED gestão remota ligada fora da VLAN de AV                 HIGH
  FIRMWARE_STALE     firmware > 180 dias                                     MEDIUM
  OFFLINE            last_seen > 7 dias                                      MEDIUM

Reutiliza `build_report()` público (intocado) para a taxa de prontidão operacional e junta a
taxa de segurança. CLI fail-closed: exit 1 se houver HIGH; exit 2 se faltarem colunas.
Biblioteca padrão. Nunca toca em dispositivo nenhum.
"""

from __future__ import annotations

import argparse
import csv
import importlib.util
import json
import pathlib
import sys
from datetime import date, timedelta

HERE = pathlib.Path(__file__).resolve().parent
_spec = importlib.util.spec_from_file_location("room_readiness_report", HERE / "room_readiness_report.py")
rr = importlib.util.module_from_spec(_spec)
sys.modules["room_readiness_report"] = rr
_spec.loader.exec_module(rr)

REQUIRED = {"room", "device_type", "firmware_date", "default_creds_changed", "network_segment", "remote_mgmt_enabled", "last_seen"}
AV_SEGMENT = "av-vlan"


def read_devices(path: pathlib.Path) -> list[dict]:
    with path.open(newline="", encoding="utf-8-sig") as fh:
        reader = csv.DictReader(fh)
        missing = REQUIRED - set(reader.fieldnames or [])
        if missing:
            raise ValueError(f"colunas em falta em {path.name}: {sorted(missing)}")
        return [{k: (v or "").strip() for k, v in row.items()} for row in reader]


def classify(devices: list[dict], today: date, firmware_days: int = 180, offline_days: int = 7) -> dict:
    findings = []

    def add(kind, d, sev, evidence, reason):
        findings.append({"kind": kind, "room": d["room"], "device": d["device_type"], "severity": sev, "evidence": evidence, "reason": reason})

    for d in devices:
        if d["default_creds_changed"].lower() != "yes":
            add("DEFAULT_CREDS", d, "HIGH", f"default_creds_changed={d['default_creds_changed']}", "credenciais de fabrica: qualquer pessoa na rede entra")
        seg = d["network_segment"].lower()
        if seg != AV_SEGMENT:
            add("WRONG_SEGMENT", d, "HIGH", f"network_segment={seg}", "dispositivo AV fora da VLAN de AV: pivot para a LAN de utilizadores" if seg == "corp" else "dispositivo AV na rede de convidados: exposto a quem esta de passagem")
        if d["remote_mgmt_enabled"].lower() == "yes" and seg != AV_SEGMENT:
            add("REMOTE_MGMT_EXPOSED", d, "HIGH", f"remote_mgmt=yes segment={seg}", "gestao remota alcancavel de fora da VLAN de AV")
        try:
            fw = date.fromisoformat(d["firmware_date"])
            if (today - fw).days > firmware_days:
                add("FIRMWARE_STALE", d, "MEDIUM", f"firmware={fw} ({(today - fw).days}d)", "vulnerabilidades conhecidas por corrigir")
        except ValueError:
            add("FIRMWARE_UNKNOWN", d, "MEDIUM", f"firmware_date={d['firmware_date']!r}", "sem data nao se afirma actualizado")
        try:
            seen = date.fromisoformat(d["last_seen"])
            if (today - seen).days > offline_days:
                add("OFFLINE", d, "MEDIUM", f"last_seen={seen} ({(today - seen).days}d)", "sem visibilidade; 'pass' operacional pode estar velho")
        except ValueError:
            add("OFFLINE", d, "MEDIUM", f"last_seen={d['last_seen']!r}", "sem data")

    order = {"HIGH": 0, "MEDIUM": 1}
    findings.sort(key=lambda f: (order[f["severity"]], f["room"], f["kind"]))
    rooms = sorted({d["room"] for d in devices})
    bad_rooms = {f["room"] for f in findings if f["severity"] == "HIGH"}
    return {"devices": len(devices), "rooms": len(rooms), "rooms_with_high": len(bad_rooms),
            "secure_room_pct": round(100 * (len(rooms) - len(bad_rooms)) / len(rooms), 1) if rooms else 0.0,
            "findings": findings, "decision": "NENHUMA - relatorio para o humano; nenhum dispositivo foi tocado"}


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n", 1)[0])
    ap.add_argument("--results", required=True, type=pathlib.Path, help="CSV publico room,result,...")
    ap.add_argument("--devices", required=True, type=pathlib.Path)
    ap.add_argument("--today", default="2026-09-24")
    ap.add_argument("--json", action="store_true")
    a = ap.parse_args(argv)
    sys.stdout.reconfigure(encoding="utf-8")
    try:
        ops = rr.build_report(rr.read_results(a.results))
        devices = read_devices(a.devices)
    except (FileNotFoundError, ValueError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2
    sec = classify(devices, date.fromisoformat(a.today))
    # a classe publica ja traz total e readiness_rate — usar o que existe, nao recalcular
    out = {"ops": {"rooms": ops.total, "pass": ops.passed, "warning": ops.warning, "fail": ops.failed,
                   "pass_pct": ops.readiness_rate}, "sec": sec}
    if a.json:
        print(json.dumps(out, ensure_ascii=False, indent=2))
    else:
        print(f"ops: rooms={ops.total} pass={ops.passed} warning={ops.warning} fail={ops.failed} pass_pct={ops.readiness_rate}%")
        print(f"sec: devices={sec['devices']} rooms={sec['rooms']} rooms_with_high={sec['rooms_with_high']} secure_room_pct={sec['secure_room_pct']}%")
        for f in sec["findings"]:
            print(f"  [{f['severity']:<6}] {f['kind']:<20} {f['room']:<8} {f['device']:<10} {f['evidence']}")
        print(f"decision: {sec['decision']}")
    return 1 if sec["rooms_with_high"] else 0


if __name__ == "__main__":
    sys.exit(main())
