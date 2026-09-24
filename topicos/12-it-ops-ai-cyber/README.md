# 12 — IT Operations × AI × Cybersecurity

**Origem:** Marcus, 23/09/2026 — *"cadê as coisas que fizemos … como IT Operacional … fase de
estudos unindo AI e Cybersecurity da mesma forma"* → *"sim, entra tudo, apenas não coloque
nome da empresa, e sem número: só % e melhorias ou desenvolvimento"*.
**Ciclos:** 11–16. **Estado:** em curso.

## As regras desta trilha (fixadas por Marcus, 23/09)

```text
1  NUNCA o nome do empregador. Dizer "o empregador" / "um ambiente EMEA distribuído".
2  NUNCA número absoluto da operação (dispositivos, salas, países, horas, tickets).
3  Percentagem só se Marcus a atestar por item — e vai marcada
   "atestado por Marcus, sem documento primário" (convenção da MATRIZ PRIVADA: as alegações
   quantitativas estão todas PENDENTE). Sem atestado: descreve-se a melhoria, sem número.
4  Nada do acervo privado do empregador entra em laboratório. Nenhum documento interno é copiado.
5  Todo laboratório: dados sintéticos, host próprio, só leitura, -WhatIf provado.
6  Rótulo em todo artefacto: SYNTHETIC LAB · REAL PERSONAL LAB · ou "processo real, sanitizado".
```

Isto **não contradiz** a regra do repositório de estudo ("não é lugar para material do empregador"):
o que entra é o **método** que Marcus praticou, reconstruído em laboratório — não o material.

## A árvore

| Ciclo | Processo real (sanitizado) | Base já existente | Cyber | AI (sempre com guarda; nunca age) |
|---|---|---|---|---|
| **11** | Endpoint lifecycle — imaging e readiness | `it-infrastructure-operations-portfolio/projects/01` (`Get-EndpointReadiness.ps1`) | baseline pós-imagem = `WinOpsAudit` (Ciclo 9) | prioriza N relatórios; guarda de comandos + intenção |
| **12** | Asset management & audit | `projects/02` (`asset_audit.py`, CSVs) | activo desconhecido = superfície; devolvido-com-sessão = risco | classifica discrepâncias, validado contra o CSV |
| **13** | Asset return & redeployment (JML de hardware) | `projects/04` (workflow, RACI) | liga ao Ciclo 1 (JML de identidade) | playbook estilo Ciclo 7, `decision: NENHUMA` |
| **14** | MDM & mobile | mapa de competências (MDM); schema oficial Graph/Intune | liga à regra 3 do Ciclo 5 (dispositivo não conforme) | triagem de não-conformidade, nunca remove |
| **15** | Meeting rooms / RTO readiness | `projects/05` (`room_readiness_report.py`) | dispositivos de sala como IoT do escritório | resumo executivo com números validados |
| **16** | **CASE-05** — um dia de IT Ops, ponta a ponta | 11→13→14 | política do Ciclo 10 aplicada a operações | onde a IA ajuda e onde é proibida |

Cada ciclo: `DAY-*.md` com APRENDER / IMPLEMENTAR / TESTAR / QUEBRAR / EXPLICAR, uma
pergunta de entrevista no fim, e a linha para o `GATE-4-PERGUNTAS.md`.

## Onde a experiência real fica registada (privado, fora daqui)

`D:\GITHUB-PORTFOLIO-REBUILD\LOCAL-CONFIDENTIAL\EXPERIENCE-ANALYSIS\MATRIZ-PRIVADA-DE-ATIVIDADES.md`
— A-07 (operações EMEA, *parcialmente comprovado*), A-08 (activos, *pendente*). Esta trilha
produz os artefactos que podem, um dia, tornar essas linhas **comprovadas por método** — não
por número.
