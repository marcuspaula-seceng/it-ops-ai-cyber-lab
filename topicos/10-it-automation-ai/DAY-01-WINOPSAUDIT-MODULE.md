# Ciclo 9 · Dia 1 — O módulo `WinOpsAudit`: inventário só leitura, com a lógica da detecção

**22/09/2026** · `WinOpsAudit/WinOpsAudit.psm1` · 22 testes Pester 3.4.0 · Windows PowerShell 5.1.

## Rótulo de claim

```text
REAL LOCAL LAB — código próprio, Windows PowerShell 5.1 do host, Pester 3.4.0 já presente,
nada instalado. Testes com objectos sintéticos: nenhum teste toca no host.
```

## APRENDER — o que um módulo "defensável" tem

`Set-StrictMode -Version Latest` · `[CmdletBinding()]` · ajuda baseada em comentário em
todas as funções · `SupportsShouldProcess` **só** onde há escrita (`Invoke-WinOpsAudit
-OutFile`) · pipeline (`ValueFromPipeline`) para que os testes injectem dados sintéticos e
o host seja o **defeito**, não o único caminho · `Unknown` em vez de silêncio quando falta
elevação ou o campo não existe.

## IMPLEMENTAR — três inventários, uma lógica reutilizada

| Função | Lógica | De onde vem |
|---|---|---|
| `Get-ScheduledTaskRisk` | principal `S-1-5-18` ou `SYSTEM` por nome · gatilho `PT1M..PT5M`, `BootTrigger`, `LogonTrigger` · fora de `\Microsoft\` (porta declarada; `-IncludeMicrosoftPath`) · `Reason` avisa que `RunLevel` não descreve risco | regra 1/2 do Ciclo 5; armadilha do `RunLevel` do Ciclo 3.1 |
| `Get-ServicePathRisk` | caminho sem aspas com espaços (T1574.009) · binário fora de Program Files / Windows | clássico de hardening |
| `Get-LocalAdminInventory` | membros de Administrators; grupo aninhado = `Unknown depth`, não "resolvido" | princípio "Unknown ≠ ok" |

## TESTAR — 22/22 à primeira

```text
Test-PersistentTrigger      7   PT1M sim · PT5M sim (limite) · PT10M não · Boot/Logon sim · semanal não · null não
Get-ScheduledTaskRisk       7   sample real (SYSTEM+PT1M) · semanal · utilizador · \Microsoft\ oculto/visível · SYSTEM por nome · não muta
Get-ServicePathRisk         5   sem aspas · com aspas · fora das raízes · svchost · PathName vazio
Get-LocalAdminInventory     3   Administrator esperado · extra local · grupo aninhado
```

Pester 3.4.0 usa `Should Be` / `Should Match` (sintaxe antiga) — o teste foi escrito para a
versão que existe, não para a que eu preferia. Não se instala para o teste passar (regra 7).

## QUEBRAR — o que o Dia 2 vai mostrar

O módulo passou 22/22 com dados sintéticos. Isso é exactamente o que o Ciclo 5 Dia 2
ensinou: *uma suíte que passa prova que a suíte não separa*. O host real é o teste que
falta — e é no Dia 2.

```text
MARCUS REFLECTION: PENDING
```
