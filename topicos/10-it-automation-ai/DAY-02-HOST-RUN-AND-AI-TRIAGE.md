# Ciclo 9 · Dia 2 — O host real e a IA com guarda

**22/09/2026** · `Invoke-WinOpsAudit` no PC de Marcus (só leitura) · `Invoke-AiTriage.ps1` com `qwen2.5:7b` local.

## Rótulo de claim

```text
REAL PERSONAL LAB — host pessoal de Marcus, só leitura. A saída (JSON com nome de máquina,
contas e caminhos) ficou no scratchpad da sessão e NÃO entra no git. Aqui só contagens e
nomes de serviços de fornecedor. Nada instalado; nada saiu da máquina.
```

## O host: 6 achados

| Check | # | O que era |
|---|---|---|
| `ServicePathRisk` | 5 | 3 × Microsoft Defender em `C:\ProgramData\Microsoft\…` ("fora das raízes") · 2 × serviços Ubisoft com **caminho sem aspas e espaços** (T1574.009) |
| `LocalAdminInventory` | 1 | a conta do próprio utilizador em Administrators — esperado num PC pessoal |
| `ScheduledTaskRisk` | 0 | nenhuma tarefa SYSTEM persistente fora de `\Microsoft\` |

## QUEBRAR — o que o host ensinou que os 22 testes não

1. **Falso positivo por lista de raízes.** O Defender vive em `ProgramData`, não em
   `Program Files`. A tentação era acrescentar `ProgramData\Microsoft` à lista — hardcode
   que esconde. Em vez disso, o módulo passou a anexar **`Get-AuthenticodeSignature`**
   (só leitura): `Signature=Valid · Signer=CN=Microsoft Windows Publisher`. O achado fica,
   a evidência decide, o humano lê. Sem ficheiro → `Unknown`, não `ok`.
2. **Os dois Ubisoft são reais.** Assinados (`CN=UBISOFT ENTERTAINMENT INC.`) — e mesmo
   assim caminho sem aspas com espaços é o T1574.009 de manual. Assinatura válida não
   corrige configuração. **Nenhuma acção foi tomada**: reportar não é corrigir (RUNBOOK).
3. **`-WhatIf` provado:** `Invoke-WinOpsAudit -OutFile x -WhatIf` imprime o *What if* e
   **não cria o ficheiro** — verificado com `Test-Path`.

## A IA com guarda — 133 s, 6 achados, `GuardDropped=0`

O modelo ordenou os 6 e propôs uma verificação por linha. Duas coisas para o registo:

- **A guarda apanha comandos, não intenções.** Sobre a conta admin, o modelo escreveu
  *"consider removing if not required"*. Não há cmdlet nessa frase; passou. É uma
  recomendação de mudança em linguagem natural — exactamente a classe que a regex não vê.
  Mitigação honesta: a guarda garante que **nada é executável**; não garante que nada é
  *sugerido*. O `Decision: NONE` e o humano no fim continuam a ser a fronteira (Ciclo 8).
- **Alucinação de tipo:** para um *serviço* sugeriu *"inspect the task XML"* — verificação
  que existe para tarefas, não para serviços. O modelo pequeno mistura os dois inventários.
  Custo: zero (é texto); lição: a IA prioriza bem, verifica mal — cabe ao módulo dar a
  evidência (assinatura) para o modelo não ter de a inventar.

## O que a evidência sustenta

- O módulo corre no host sem elevação e sem alterar nada, e devolve achados com evidência.
- A assinatura Authenticode separa "fora do sítio habitual" de "desconhecido".
- A guarda removeu 0 linhas porque 0 linhas continham comandos — e isso é o seu limite.

## O que NÃO sustenta

- Que os 22 testes cobrem o host: não cobriam o `ProgramData`. O host é o teste.
- Que a IA acrescenta valor além de ordenar: 6 achados cabem num ecrã; o ganho aparece
  a 60, não a 6.

```text
MARCUS REFLECTION: PENDING
```
