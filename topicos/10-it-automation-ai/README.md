# 10 — IT Automation & AI

**Origem:** Marcus, 22/09/2026 — *"IT Automation security and geral"* · *"Engineer for IT
Automation & AI transformation"*. **Ciclo:** 9. **Estado:** em curso.

O delta de posicionamento que o segundo pedido implica está **proposto** em
`CICLO-ATUAL.md` (secção Ciclo 9) e aguarda `ACCEPT`; nada foi alterado em
`DECISOES-CANONICAS.md`.

## O que é

Um engenheiro de automação de IT entrega três coisas: **inventário fiável**, **mudança
controlada** e, agora, **IA que ajuda sem mandar**. Este ciclo faz as três com PowerShell
(20 anos de base do Marcus) e o Ollama local:

| Peça | Ficheiro | O que faz |
|---|---|---|
| Módulo | `WinOpsAudit/WinOpsAudit.psm1` | `Get-ScheduledTaskRisk` · `Get-ServicePathRisk` · `Get-LocalAdminInventory` · `Invoke-WinOpsAudit` (-WhatIf) — **só leitura**, cada achado com `Evidence` e `Reason` |
| Testes | `WinOpsAudit/WinOpsAudit.Tests.ps1` | Pester **3.4.0** (o que o host tem, sem instalar), dados sintéticos, 22 testes |
| IA | `Invoke-AiTriage.ps1` | o modelo local prioriza e sugere **verificações**; guarda em código remove linhas que proponham alterar o host; `Decision: NONE` |
| Intenção (9.1) | `WinOpsAudit/IntentGuard.psm1` + `.Tests.ps1` | segunda camada: verbos de mudança em linguagem natural → `[ADVICE: CHANGE - human decision]`; marcou a frase exacta que passou no Dia 2 |

A lógica de `Get-ScheduledTaskRisk` é a das regras 1/2 do Ciclo 5 — SYSTEM + gatilho
persistente fora de `\Microsoft\` — aplicada ao Task Scheduler **vivo**, sem depender de
auditoria 4698. Detecção e inventário são o mesmo conhecimento em dois sítios.

## Regras desta série

- Nenhuma função altera o host. A única escrita é o JSON de saída, com `-WhatIf`.
- Saída do host real vai para o scratchpad da sessão, **nunca para o git** (nomes de
  máquina, contas, caminhos).
- A IA não tem ferramentas. Não pode agir. O que sugere passa por filtro determinístico.
- Falso positivo não se esconde por hardcode: acrescenta-se evidência (assinatura) e o
  humano decide.
