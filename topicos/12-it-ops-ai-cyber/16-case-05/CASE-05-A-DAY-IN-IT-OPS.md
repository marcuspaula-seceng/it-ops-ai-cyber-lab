# CASE-05 — Um dia de IT Ops, ponta a ponta: onde a IA ajuda e onde é proibida

**Ciclo 16 · artefacto de fecho da trilha IT Ops × AI × Cyber · 24/09/2026**

## Environment and claim label

```text
SYNTHETIC LAB — ligação dos Ciclos 11–15. Cada passo abaixo aponta para código e testes que
existem e correram; nenhum passo novo foi executado para este caso. Processo real, sanitizado:
sem empregador, sem volumes; percentagens só as documentadas no público (−75 % turnaround,
rede ×10, 99 % visibilidade) ou as do laboratório sintético.
```

## 1. O dia

Uma pessoa entra; recebe portátil e telemóvel; trabalha em salas; sai; devolve. É o ciclo
que o autor operou num ambiente EMEA distribuído. Aqui, com a camada de segurança que o
processo original não tinha e a camada de IA que não existia.

| # | Momento | Ciclo | O que o código faz | O que a IA faz | O que a IA **não** pode fazer |
|---|---|---|---|---|---|
| 1 | Portátil sai da imagem | **11** `EndpointReadiness` | ops + sec; `READY` só com zero Fail e zero Unknown em segurança | ordena os Fail, sugere verificações só leitura | marcar READY; corrigir um check |
| 2 | Telemóvel é inscrito no MDM | **14** `mdm_compliance` | 8 regras sobre o schema oficial; `joinKey` para identidade | causa provável + verificação por dispositivo | retirar, apagar, bloquear |
| 3 | Reunião numa sala | **15** `room_readiness_sec` | prontidão *e* segurança dos dispositivos de sala | ordenar; explicar | "AV or guest" — suavizou a regra |
| 4 | Sign-in de um dispositivo não conforme | **5** regra 3 · **14** `UNREGISTERED` | a linha do CASE-03; sem `azureADDeviceId` a regra é cega | — | decidir se é ataque |
| 5 | Auditoria de stock trimestral | **12** `asset_audit_sec` | `RETURNED_STILL_ACTIVE` aparece: um portátil "devolvido" numa secretária | causa + verificação, sem inventar activos | inventar um activo; chamar laptop a um desktop (fez) |
| 6 | A pessoa sai; devolve o portátil | **13** `ReturnRedeploy` | wipe avança; **G2 bloqueia o fecho** até a conta estar `disabled` | lê os gates abertos e prioriza | executar o wipe; fechar o ticket |
| 7 | Conta desactivada (JML) | **1** AD automation | `leaver` com `ShouldProcess` | — | correr sem `-WhatIf` primeiro |
| 8 | Portátil volta a stock | **13** G4 + **11** | só com `READY` | — | — |

## 2. O que este dia prova

- **Um princípio, seis ciclos:** *a IA informa; o código decide o que é permitido; o humano
  decide o que é feito.* Em nenhum passo a IA tem uma ferramenta que altere estado
  (Ciclo 8, R2/R3 da política do Ciclo 10).
- **Os gates ligam-se entre si:** o `READY` do 11 é o G4 do 13; o `RETURNED_STILL_ACTIVE`
  do 12 é o G2 do 13; o `azureADDeviceId` do 14 é a chave da regra 3 do 5. Detecção,
  inventário e workflow são o mesmo conhecimento em três sítios.
- **`Unknown ≠ ok` em todos os ciclos:** BitLocker sem elevação, `complianceState=unknown`,
  conta `unknown` no G2, coluna em falta no CSV. Nunca vira Pass.

## 3. Os cinco tipos de erro de IA medidos na trilha

| Tipo | Onde | Validador que apanha |
|---|---|---|
| Comando executável | Ciclo 9 | regex de comandos ✅ |
| Intenção de mudança em linguagem natural | Ciclo 9 Dia 2 ("consider removing") | `IntentGuard` ✅ |
| Activo inventado | Ciclo 12 (0 ocorrências) | validador de identificadores ✅ |
| Atributo errado / verificação de outro domínio | Ciclo 12 (desktop→laptop), 13 ("task XML") | **nenhum** |
| Semântica de política suavizada | Ciclo 15 ("AV or guest") | **nenhum** |

Os dois últimos são a razão de `decision: NENHUMA` existir em todos os scripts. Não é
cautela: é o limite medido do que os validadores determinísticos conseguem.

## 4. O que a trilha não prova

- Que isto correu numa organização: correu num PC e em CSVs sintéticos.
- Que as percentagens do público (−75 %, ×10, 99 %) foram auditadas: são documentadas.
- Que os validadores chegam: os erros de atributo e de semântica passaram.

## 5. O que "Engineer for IT Automation & AI transformation" pode dizer com isto

*Pode:* que pega em processos operacionais reais, os reconstrói como automação testada e
só leitura, acrescenta a camada de segurança que faltava, e integra IA local com guardas
cujos limites mediu. *Não pode:* números da operação, nome de plataformas internas,
"transformação" de uma organização. O delta de posicionamento continua com Marcus.

## MITRE ATT&CK, para o dia

T1053.005 (Ciclo 11 baseline) · T1574.009 (Ciclo 11) · T1078.004 / T1556.006 (passo 4) ·
T1200 Hardware Additions (passo 5, activo desconhecido) · T1021 via dispositivo de sala em
LAN corporativa (passo 3).

```text
MARCUS REFLECTION: PENDING
```
