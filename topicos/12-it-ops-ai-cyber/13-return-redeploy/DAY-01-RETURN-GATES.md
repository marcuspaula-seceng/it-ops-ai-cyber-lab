# Ciclo 13 · Dia 1 — Devolução e redeploy: o workflow ganha gates, e nada corre de verdade

**24/09/2026** · `ReturnRedeploy.psm1` · 15 testes Pester 3.4.0 · `qwen2.5:7b` local.

## Rótulo de claim

```text
PROCESSO REAL, SANITIZADO — o workflow de devolução/redeploy que o autor aplicou em três sites
                            (público, projecto 04): receipt → assessment → wipe → reimage →
                            quality → storage → redeploy | dispose. Sem nome do empregador.
SYNTHETIC LAB             — tickets sintéticos; ShouldProcess em todo passo destrutivo; nada é
                            limpo, reimaginado ou descartado por este módulo.
```

## APRENDER — um workflow é uma ordem; um gate é uma condição

O workflow público diz *o que vem a seguir*. Segurança pergunta *o que tem de ser verdade
antes*. Os cinco gates:

| Gate | Antes de | Condição | De onde vem |
|---|---|---|---|
| G1 | Receipt | tracking ref + utilizador anterior identificados | sem rasto não entra |
| **G2** | Storage · Redeploy · Dispose | conta do utilizador anterior `disabled` ou `leaver-complete` — **Unknown não conta** | Ciclo 12 `RETURNED_STILL_ACTIVE`; Ciclo 1 (JML de identidade) |
| G3 | Reimage | `SecureWipe` registado no ledger | nunca reimaginar por cima de dados |
| G4 | Storage | `Readiness = READY` | Ciclo 11: zero Fail, zero Unknown em segurança |
| G5 | Dispose | evidência de wipe (certificado/ref) | dados não saem do edifício |

Decisão de desenho: **o wipe não é bloqueado pela conta activa** — dados primeiro; o que a
conta activa bloqueia é o *fecho* (stock, redeploy, descarte). Devolvido no papel e activo
na prática é um estado que não pode terminar.

## IMPLEMENTAR

`New-ReturnTicket` · `Test-ReturnGate` (nunca muta) · `Invoke-ReturnStep` (`SupportsShouldProcess`,
`ConfirmImpact High` nos destrutivos; regista no ledger **inclusive os bloqueios**) ·
`Get-OpenGates` (o que falta, parando no primeiro bloqueado — a lista que o playbook lê).

## TESTAR — 15/15, depois de um teste apanhar o PowerShell

`-WhatIf` num `SecureWipe` escreveu no ledger — não devia. Causa: `ForEach-Object Step`
(forma `-MemberName`) **honra `-WhatIf`** e devolve nada; o gate viu o ledger vazio e
registou um bloqueio falso. Correcção: bloco de script `{ $_.Step }`. É a segunda armadilha
de PS 5.1 desta trilha (a primeira foi o travessão em cp1252).

Cenário corrido: portátil devolvido, wipe com certificado, reimage, quality `READY`, conta
do utilizador anterior **`active`** → `BLOCKED:Storage G2`, escrito no ledger.

## A IA — 21 s, `cmdGuardDropped=0`, `intentFlagged=0`

Ordenou o único gate aberto como prioridade máxima e explicou porquê — e sugeriu *"inspect
the task XML"* para um gate de **identidade**. Terceira vez na trilha que o modelo pequeno
recicla uma verificação de outro domínio (serviço → tarefa; identidade → tarefa). Os guards
não apanham isto porque não é comando nem intenção: é **irrelevância**. O humano no fim
continua a ser a fronteira.

## QUEBRAR

- O estado da conta vem do ticket; num sistema real viria do directório — e aí `unknown` é
  o valor mais comum, não o mais raro. G2 vai bloquear muito. É o objectivo.
- Não há gate para *quem* confirmou o wipe. Evidência é uma string; um certificado falso
  passa. Declarado.

## EXPLICAR

> *"Um portátil é devolvido, limpo e reimaginado. Por que é que ainda não pode ir para stock?"*

```text
MARCUS REFLECTION: PENDING
```
