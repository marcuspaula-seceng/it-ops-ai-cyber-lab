# it-ops-ai-cyber-lab

Real IT-operations processes — endpoint imaging validation, asset audit, device return and
redeployment, MDM compliance, meeting-room readiness — rebuilt as **read-only automation**
with the security layer they originally lacked, and a **local LLM** that ranks and explains
findings behind deterministic guards whose limits were measured.

[![python-tests](https://github.com/marcuspaula-seceng/it-ops-ai-cyber-lab/actions/workflows/python-tests.yml/badge.svg)](https://github.com/marcuspaula-seceng/it-ops-ai-cyber-lab/actions/workflows/python-tests.yml)

---

## Professional context vs. laboratory — read this first

| | |
|---|---|
| **Professional context** | The five processes are ones I operated as an IT engineer in a distributed EMEA environment. The employer is not named. No internal document, system name or absolute operational figure is reproduced here. The only figures quoted are percentages already documented in my public operations portfolio, labelled *documented, not audited*. |
| **Laboratory** | Everything runnable in this repository was written and tested in 2026-09 on my own machine. Host runs were read-only and their outputs are **not** committed. All CSV/JSON inputs are synthetic (`SAMPLE-*`, `MDM-*`, `Room-*`, `example.com`). |
| **What it does not claim** | No production use. No organisational rollout. No certification. The LLM steps ran against a local open-weights model only. |

## What is here

```text
topicos/10-it-automation-ai/
  WinOpsAudit/WinOpsAudit.psm1      read-only Windows audit: SYSTEM scheduled tasks, service path risks, local admins
  WinOpsAudit/IntentGuard.psm1      second-layer guard: flags change *intent* in natural language, never deletes
  Invoke-AiTriage.ps1               local model ranks findings; command guard; decision is always NONE
topicos/12-it-ops-ai-cyber/
  11-endpoint-lifecycle/            post-image readiness: ops + security checks; READY only with zero Fail and zero Unknown
  12-asset-audit/                   risk layer over my public reconcile(); AI validated for invented identifiers
  13-return-redeploy/               device return workflow with five security gates; ShouldProcess on every destructive step
  14-mdm-mobile/                    MDM compliance rules on the official Graph managedDevice schema (no tenant)
  15-meeting-rooms/                 meeting-room devices treated as office IoT; fail-closed CLI
  16-case-05/                       one day of IT operations, end to end, and the five measured classes of AI error
```

Lab notes (`DAY-*.md`, `CASE-05`) are in Portuguese, as written during the sessions. Each
ends with the interview question it prepares.

## How to verify

**Python (runs in CI, Ubuntu, standard library only):**

```text
python -m unittest discover -s topicos/12-it-ops-ai-cyber/12-asset-audit
python -m unittest discover -s topicos/12-it-ops-ai-cyber/14-mdm-mobile
python -m unittest discover -s topicos/12-it-ops-ai-cyber/15-meeting-rooms
                                              -> 11 + 12 + 12 = 35 tests
```

**PowerShell (local only — Windows PowerShell 5.1 with Pester 3.4.0, the version present on
the lab host; not executed in CI):**

```text
Invoke-Pester topicos/10-it-automation-ai/WinOpsAudit/*.Tests.ps1              22 + 7  = 29
Invoke-Pester topicos/12-it-ops-ai-cyber/11-endpoint-lifecycle/*.Tests.ps1     18
Invoke-Pester topicos/12-it-ops-ai-cyber/13-return-redeploy/*.Tests.ps1        15
                                                                            -> 62 tests
```

Last local run (2026-09-24): Pester 62/62, unittest 35/35. The AI steps require an Ollama
endpoint at `127.0.0.1:11434` with `qwen2.5:7b`; they are not part of any test suite and
their raw outputs are quoted in the notes.

## The rules every module follows

`Unknown ≠ Pass` · `-WhatIf` proven with `Test-Path` · every finding carries `Evidence` and
`Reason` · `decision: NONE` in every AI output · AI output validated for executable commands,
change intent, invented identifiers and unverified numbers — and the notes record the two error
classes those validators **cannot** catch (wrong attribute / wrong-domain verification;
softened policy semantics).

## Licence

No licence has been chosen yet; all rights reserved by default.
