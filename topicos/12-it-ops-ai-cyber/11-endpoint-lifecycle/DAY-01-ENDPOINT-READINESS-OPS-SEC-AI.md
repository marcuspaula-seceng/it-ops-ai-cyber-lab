# Ciclo 11 · Dia 1 — Readiness pós-imagem: operacional + segurança + IA

**23/09/2026** · `EndpointReadiness.psm1` · Pester 3.4.0 · host próprio (só leitura) · `qwen2.5:7b` local.

## Rótulo de claim

```text
PROCESSO REAL, SANITIZADO  — o método de validação pós-imagem que o autor padronizou num ambiente
                             EMEA distribuído. Sem nome do empregador. Sem números absolutos da operação.
REAL PERSONAL LAB          — corrido no PC do autor, só leitura; saída no scratchpad, não no git.
```

## O que era, e o que passa a ser

O processo real (público, sanitizado, projecto 01 do portfólio de operações): checks pós-imagem
repetíveis — câmara, microfone, áudio, rede, updates — corridos numa instância de teste diária,
com resultado documentado de **−75 % no tempo de preparação por dispositivo** e **capacidade de
rede de imaging ×10** (*resultado operacional documentado, não auditado*; percentagens derivadas
do que já é público).

Este ciclo acrescenta o que a imagem **tem** de trazer e o processo original não verificava:

| Área | Check | Fail significa |
|---|---|---|
| ops | disco ≥ 20 GB · rota por defeito · `wuauserv` disponível · câmara + áudio | o utilizador não consegue trabalhar |
| **sec** | AV activo e actualizado (Defender **ou** terceiro registado) · firewall nos 3 perfis · BitLocker `On` · baseline `WinOpsAudit` (serviços inseguros, tarefas SYSTEM, admins extra) | a imagem sai insegura |

Veredicto: `READY` só com **zero Fail e zero Unknown em segurança**. `Unknown ≠ Pass`.

## TESTAR — 18 testes sintéticos, e depois o host

Pester 18/18 — depois de um teste meu deixar de ser sintético sem eu notar: sem `-ThirdParty`
injectado, `Test-DefenderStatus` consultou o SecurityCenter **do host** e passou por causa do
AV real. Teste corrigido para injectar lista vazia. No host real, **três verificações estavam
erradas — as minhas, não o host**:

| O host disse | O que eu tinha assumido | Correcção |
|---|---|---|
| `wuauserv` **Stopped** | serviço parado = falha | no Win10/11 é *trigger-start*: `Stopped`+`Manual` é normal; só `Disabled` falha |
| Defender `av=False rtp=False sigAge=65535` | sem AV | havia **outro AV registado** no SecurityCenter; Defender em passivo é esperado. O check consulta `root/SecurityCenter2` antes de dizer Fail |
| BitLocker `Access denied` | — | `Unknown`, e o veredicto fica `NOT READY` por isso. Correcto: sem elevação não se afirma cifra |

Depois das correcções, o que resta no host é **verdadeiro**: 2 serviços com caminho sem aspas
(T1574.009), 1 admin local extra (a conta do próprio — esperado num PC pessoal, não numa
imagem corporativa), e BitLocker `Unknown` por falta de elevação.

## A IA — 75 s, 4 achados, `cmdGuardDropped=0`, `intentFlagged=0`

O modelo ordenou os 4 e propôs uma verificação por linha. Nenhuma linha foi removida pela
guarda de comandos nem marcada pela guarda de intenção — desta vez o modelo **só sugeriu
verificações**. Duas notas:

- Ordenou o Defender como #1 "High" a partir do relatório **anterior** à correcção (o que o
  host tinha dado antes de eu consultar o SecurityCenter). A IA prioriza o que lhe dão: se o
  dado está errado, a prioridade está errada, com confiança. A correcção tem de estar **antes**
  do modelo, no módulo.
- "Confirm the status of other critical services that depend on WUAUSRV" — verificação
  plausível, sem valor. O modelo pequeno preenche o formato; o humano filtra.

## QUEBRAR

- A lista de classes PnP para câmara/áudio (`Camera`/`Image`, `AudioEndpoint`/`MEDIA`) veio
  do host; noutro fabricante pode variar. Declarado.
- `Test-WinOpsBaseline` conta o admin extra sempre — em imagem corporativa é correcto; num PC
  pessoal é ruído. Não há flag para o distinguir: decisão de deixar ruído, como no Ciclo 4.

## EXPLICAR

> *"Você padronizou a validação pós-imagem. O que é que uma imagem 'pronta' tem de provar,
> e o que fez quando o seu próprio check estava errado?"*

```text
MARCUS REFLECTION: PENDING
```
