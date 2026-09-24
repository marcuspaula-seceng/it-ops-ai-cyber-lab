# Ciclo 12 · Dia 1 — Auditoria de activos: o que a reconciliação não diz, e a IA que não pode inventar um activo

**23/09/2026** · `asset_audit_sec.py` sobre o `asset_audit.py` público (projecto 02) · 11 testes · `qwen2.5:7b` local.

## Rótulo de claim

```text
PROCESSO REAL, SANITIZADO — o método de auditoria de stock por scan que o autor operou num
                            ambiente EMEA multi-site; a ferramenta original era de um colega
                            (declarado no público). Resultado documentado: 99 % de visibilidade
                            de stock (não auditado). Sem nome do empregador, sem volumes.
SYNTHETIC LAB             — CSVs v2 sintéticos (SAMPLE-*); nada de inventário real.
```

## APRENDER — reconciliar não é avaliar risco

O `reconcile()` público responde *bate / não bate* em 4 categorias. Segurança precisa de
saber **o que cada categoria significa** — e isso está nas colunas que o reconcile ignora
(`status`, `device_type`, `scan_point`):

| Achado | Severidade | Porquê |
|---|---|---|
| `UNKNOWN_ASSET` — no chão, fora do inventário | HIGH | superfície não gerida |
| `LOST_OR_UNTRACKED` — `in_stock` e não scanned | HIGH se porta dados (laptop/desktop/phone), senão MEDIUM | pode ter saído sem registo |
| `RETURNED_STILL_ACTIVE` — `returned` mas scanned numa secretária | HIGH | devolvido no papel, em uso na prática → liga ao JML de identidade (Ciclo 1) e ao Ciclo 13 |
| `PROCESS_ERROR` — scan duplicado | MEDIUM | dois scanners ou etiqueta clonada; o `scanned_by` distingue |
| `ASSIGNED_NOT_IN_STOCK` | INFO | atribuído a alguém; não estar no stock é o esperado |

`visibility_pct = matched / expected` — a métrica que o processo real documentou como 99 %.
No conjunto sintético: **72,7 %** (8/11), de propósito, para haver o que analisar.

## TESTAR — 11/11

O `reconcile()` público **não foi tocado**; o primeiro teste prova que os 4 contadores continuam
iguais aos dele. Os outros provam cada linha da tabela acima com um activo concreto.

## A IA — 112 s, 7 achados, `invented=0`, `change_intent=0`

Validadores em código, depois do modelo: (1) **toda etiqueta mencionada tem de existir** nos
CSV — o risco #1 de IA em inventário é inventar um activo; (2) verbos de mudança marcados.
Os dois deram zero. O modelo propôs causas plausíveis e verificações só leitura (inspecção
física, logs de scan, confirmar com o utilizador).

**O que o validador não viu:** chamou *"laptop"* ao `SAMPLE-0003`, que é **desktop** no CSV.
Validar **etiquetas** não valida **atributos**. É um erro pequeno aqui e grave num relatório
que alguém use para decidir o que comprar. Fica como limite medido e próximo validador.

## QUEBRAR

- `read_rows` deixa a última linha ganhar em etiqueta repetida no *expected* — duplicado no
  inventário mestre fica invisível. Declarado; o reconcile público faz o mesmo.
- Severidade por `device_type` depende de o CSV o preencher; vazio → MEDIUM, nunca HIGH.

## EXPLICAR

> *"A sua auditoria de stock dava 99 % de visibilidade. O que faz com o 1 % — e o que é que
> um activo 'devolvido' encontrado numa secretária significa para segurança?"*

```text
MARCUS REFLECTION: PENDING
```
