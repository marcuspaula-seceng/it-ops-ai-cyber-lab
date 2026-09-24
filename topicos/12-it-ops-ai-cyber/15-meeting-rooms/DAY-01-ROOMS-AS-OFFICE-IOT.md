# Ciclo 15 · Dia 1 — Salas de reunião como IoT do escritório

**24/09/2026** · `room_readiness_sec.py` sobre o `room_readiness_report.py` público (projecto 05) · 12 testes · `qwen2.5:7b` local.

## Rótulo de claim

```text
PROCESSO REAL, SANITIZADO — as verificações de prontidão de salas que o autor manteve durante
                            uma transição/coexistência de plataformas de reunião (público,
                            projecto 05). Sem nome do empregador, sem número de salas.
SYNTHETIC LAB             — CSV público de resultados (sintético) + CSV novo de dispositivos
                            de sala (sintético). Nenhum dispositivo real tocado.
```

## APRENDER — "a sala funciona" e "a sala é segura" são perguntas diferentes

O relatório público responde à primeira: `pass/warning/fail` por sala, **73,7 %** de prontidão
no CSV sintético. A segunda ninguém costuma fazer, porque displays, codecs, controladores e
câmaras não são tratados como computadores — e são computadores em rede, muitas vezes com
credenciais de fábrica e gestão remota ligada:

| Regra | Sev. | Porquê |
|---|---|---|
| `DEFAULT_CREDS` | HIGH | quem está na rede entra |
| `WRONG_SEGMENT` (corp / guest) | HIGH | na LAN corporativa é *pivot*; na de convidados está exposto a quem passa |
| `REMOTE_MGMT_EXPOSED` | HIGH | gestão remota fora da VLAN de AV |
| `FIRMWARE_STALE` (> 180 d) | MEDIUM | |
| `OFFLINE` (> 7 d) | MEDIUM | um `pass` operacional de há duas semanas não é um `pass` |

Métrica nova: **`secure_room_pct`** conta salas **sem HIGH** — 42,9 % no sintético. As duas
percentagens juntas dizem o que uma só esconde: uma sala pode passar em tudo e ter o codec
na LAN corporativa com password de fábrica.

## IMPLEMENTAR

`build_report()` público **intocado** (usa-se `total`, `warning`, `readiness_rate` — os campos
que a classe tem, depois de um erro meu por assumir `warnings`). CLI *fail-closed*: exit 1 se
houver HIGH, exit 2 se faltarem colunas — colunas em falta são recusadas, não adivinhadas.

## TESTAR — 12/12

Inclui: gestão remota **na** VLAN de AV é aceitável (Room-01) e fora não (Room-03/05/07);
`secure_room_pct` ignora MEDIUM; coluna em falta levanta; exit codes provados.

## A IA — 126 s, `invented=0`, `change_intent=0`, `unverified_numbers=0`

Validador novo neste ciclo: **todo número que o modelo afirma tem de existir no relatório**
(percentagens, contagens, dias). Zero infracções. E, mesmo assim, um erro que nenhum dos três
validadores apanha: *"confirm the device's connection to the appropriate network segment
(AV **or guest**)"*. O modelo **suavizou a regra** — guest é exactamente um dos segmentos
errados. Não é comando, não é intenção, não é número, não é activo inventado: é **semântica
de política**. Quarto tipo de erro medido na trilha; o humano no fim continua a ser a fronteira.

## QUEBRAR

- `network_segment` é uma string do CSV; um `AV-VLAN` em maiúsculas passa (`.lower()`), mas
  `av_vlan` não. Declarado.
- Sem inventário de CVEs, `FIRMWARE_STALE` é só idade; um firmware de 200 dias sem CVE
  conhecido é MEDIUM à mesma.

## EXPLICAR

> *"Uma sala passa em todos os testes de reunião. Por que é que pode ser o dispositivo mais
> perigoso do andar?"*

```text
MARCUS REFLECTION: PENDING
```
