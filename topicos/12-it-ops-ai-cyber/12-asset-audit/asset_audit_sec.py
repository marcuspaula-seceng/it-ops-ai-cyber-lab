#!/usr/bin/env python3
"""Camada de segurança sobre o asset_audit.py público — Ciclo 12 (IT Ops × AI × Cyber).

O `reconcile()` público diz O QUE bate e o que não bate. Esta camada diz O QUE ISSO SIGNIFICA
para segurança, usando as colunas que o reconcile ignora (status, device_type, scan_point):

  UNKNOWN_ASSET          scanned, não esperado          -> dispositivo no chão fora do inventário: superfície
  LOST_OR_UNTRACKED      esperado in_stock, não scanned -> activo com dados pode ter saído sem registo
  RETURNED_STILL_ACTIVE  esperado 'returned', scanned fora do stock_room -> devolvido no papel, em uso
                                                           na prática (liga ao Ciclo 13 e ao JML do Ciclo 1)
  PROCESS_ERROR          scanned mais de uma vez        -> duplo scan ou etiqueta clonada
  ASSIGNED_NOT_IN_STOCK  esperado 'assigned', não scanned no stock_room -> esperado; informativo

Severidade sobe se device_type for portador de dados (laptop, desktop, phone). Produz também
a % de visibilidade (matched / expected) — a métrica que o processo real documentou como
99 % (resultado operacional, não auditado). Biblioteca padrão. Nunca altera os CSV.
"""

from __future__ import annotations

import argparse
import csv
import importlib.util
import json
import pathlib
import sys

HERE = pathlib.Path(__file__).resolve().parent
_spec = importlib.util.spec_from_file_location("asset_audit", HERE / "asset_audit.py")
audit = importlib.util.module_from_spec(_spec)
sys.modules["asset_audit"] = audit  # @dataclass procura o modulo em sys.modules; sem isto rebenta
_spec.loader.exec_module(audit)

DATA_BEARING = {"laptop", "desktop", "phone", "tablet", "server"}


def read_rows(path: pathlib.Path) -> dict[str, dict]:
    """Linhas por asset_tag normalizado (a última ganha, como no reconcile)."""
    rows = {}
    with path.open(newline="", encoding="utf-8-sig") as fh:
        for row in csv.DictReader(fh):
            tag = (row.get(audit.ASSET_TAG_FIELD) or "").strip()
            if tag:
                rows[audit._normalise(tag)] = {k: (v or "").strip() for k, v in row.items()}
    return rows


def read_scans(path: pathlib.Path) -> dict[str, list[dict]]:
    scans: dict[str, list[dict]] = {}
    with path.open(newline="", encoding="utf-8-sig") as fh:
        for row in csv.DictReader(fh):
            tag = (row.get(audit.ASSET_TAG_FIELD) or "").strip()
            if tag:
                scans.setdefault(audit._normalise(tag), []).append({k: (v or "").strip() for k, v in row.items()})
    return scans


def classify(expected_rows: dict[str, dict], scans: dict[str, list[dict]]) -> dict:
    result = audit.reconcile(list(expected_rows), [t for t, lst in scans.items() for _ in lst])
    findings = []

    def add(kind, tag, severity, evidence, reason):
        findings.append({"kind": kind, "asset_tag": tag, "severity": severity, "evidence": evidence, "reason": reason})

    for tag in result.unexpected:
        where = sorted({s.get("scan_point", "?") for s in scans[tag]})
        add("UNKNOWN_ASSET", tag, "HIGH", f"scan_point={where}", "dispositivo presente e fora do inventário: superfície não gerida")
    for tag in result.missing:
        row = expected_rows[tag]
        status, dtype = row.get("status", ""), row.get("device_type", "").lower()
        if status == "in_stock":
            sev = "HIGH" if dtype in DATA_BEARING else "MEDIUM"
            add("LOST_OR_UNTRACKED", tag, sev, f"status=in_stock device_type={dtype}", "esperado em stock e não scanned: pode ter saído sem registo")
        elif status == "assigned":
            add("ASSIGNED_NOT_IN_STOCK", tag, "INFO", f"status=assigned device_type={dtype}", "atribuído a utilizador; não estar no stock room é o esperado")
        else:
            add("LOST_OR_UNTRACKED", tag, "MEDIUM", f"status={status} device_type={dtype}", "não scanned, estado não conclusivo")
    for tag in result.duplicate:
        by = sorted({s.get("scanned_by", "?") for s in scans[tag]})
        add("PROCESS_ERROR", tag, "MEDIUM", f"scans={len(scans[tag])} by={by}", "duplo scan (dois scanners) ou etiqueta clonada — distinguir pelo scanned_by")
    for tag in result.matched:
        row = expected_rows[tag]
        if row.get("status") == "returned":
            outside = [s.get("scan_point", "?") for s in scans[tag] if s.get("scan_point") != "stock_room"]
            if outside:
                sev = "HIGH" if row.get("device_type", "").lower() in DATA_BEARING else "MEDIUM"
                add("RETURNED_STILL_ACTIVE", tag, sev, f"status=returned scan_point={sorted(set(outside))}", "devolvido no registo, encontrado fora do stock: sessão/dados possivelmente ainda activos")
    visibility = round(100 * len(result.matched) / len(expected_rows), 1) if expected_rows else 0.0
    order = {"HIGH": 0, "MEDIUM": 1, "INFO": 2}
    findings.sort(key=lambda f: (order[f["severity"]], f["kind"], f["asset_tag"]))
    return {"summary": result.as_summary(), "visibility_pct": visibility, "findings": findings,
            "decision": "NENHUMA — relatório para o humano; nada foi alterado no inventário"}


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n", 1)[0])
    ap.add_argument("--expected", required=True, type=pathlib.Path)
    ap.add_argument("--scanned", required=True, type=pathlib.Path)
    ap.add_argument("--json", action="store_true")
    a = ap.parse_args(argv)
    out = classify(read_rows(a.expected), read_scans(a.scanned))
    # o console Windows e cp1252; redireccionar `--json > f` sem isto grava bytes invalidos
    sys.stdout.reconfigure(encoding="utf-8")
    if a.json:
        print(json.dumps(out, ensure_ascii=False, indent=2))
    else:
        s = out["summary"]
        print(f"matched={s['matched']} missing={s['missing']} unexpected={s['unexpected']} duplicate={s['duplicate']}  visibility={out['visibility_pct']}%")
        for f in out["findings"]:
            print(f"  [{f['severity']:<6}] {f['kind']:<22} {f['asset_tag']:<12} {f['evidence']}")
        print(f"decision: {out['decision']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
