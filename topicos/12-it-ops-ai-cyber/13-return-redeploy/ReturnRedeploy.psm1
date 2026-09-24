#Requires -Version 5.1
Set-StrictMode -Version Latest
<#
.SYNOPSIS
    ReturnRedeploy - Ciclo 13. O workflow publico de devolucao/redeploy (projecto 04) com GATES de
    seguranca e ShouldProcess em todo passo destrutivo. Nada corre de verdade: cada passo escreve
    no ledger (so-acrescimo) o que FARIA. Ficheiro ASCII (PS 5.1 / cp1252).
.DESCRIPTION
    Etapas (do workflow publico): Receipt -> Assessment -> SecureWipe -> Reimage -> QualityCheck
    -> Storage -> Redeploy | Dispose.
    Gates (novos; sao a parte de seguranca):
      G1 Receipt exige tracking ref e utilizador anterior identificado.
      G2 Identidade: a conta do utilizador anterior tem de estar 'disabled' ou 'leaver-complete'
         antes de Storage/Redeploy/Dispose. Wipe pode avancar, FECHAR nao (Ciclo 12: devolvido
         no papel, activo na pratica).
      G3 Reimage exige SecureWipe registado no ledger (nunca reimaginar por cima de dados).
      G4 Storage/Redeploy exigem QualityCheck = READY (Ciclo 11: zero Fail, zero Unknown sec).
      G5 Dispose exige evidencia de wipe (certificado/ref) no ledger.
    Unknown nunca satisfaz um gate.
#>
$script:Destructive = @('SecureWipe', 'Reimage', 'Dispose')
$script:Order = @('Receipt', 'Assessment', 'SecureWipe', 'Reimage', 'QualityCheck', 'Storage', 'Redeploy', 'Dispose')

function New-ReturnTicket {
    <# .SYNOPSIS Cria o estado de uma devolucao. Ledger vazio. #>
    [CmdletBinding()] param(
        [Parameter(Mandatory)][string]$AssetTag, [string]$TrackingRef, [string]$PreviousUser,
        [ValidateSet('active', 'disabled', 'leaver-complete', 'unknown')][string]$PreviousUserAccount = 'unknown',
        [ValidateSet('reusable', 'damaged', 'uncertain', 'disposal')][string]$Condition = 'uncertain')
    [pscustomobject]@{ AssetTag = $AssetTag; TrackingRef = $TrackingRef; PreviousUser = $PreviousUser
        PreviousUserAccount = $PreviousUserAccount; Condition = $Condition; Readiness = 'unknown'; WipeEvidence = ''
        Ledger = [System.Collections.Generic.List[object]]::new() }
}

function Test-ReturnGate {
    <# .SYNOPSIS Avalia os gates para um passo. Devolve {Step, Allowed, Gate, Reason}. Nunca muta o ticket. #>
    [CmdletBinding()] param([Parameter(Mandatory)]$Ticket, [Parameter(Mandatory)][ValidateSet('Receipt','Assessment','SecureWipe','Reimage','QualityCheck','Storage','Redeploy','Dispose')][string]$Step)
    # bloco de script, nao -MemberName: `ForEach-Object Step` honra -WhatIf e devolve NADA -> o gate
    # via o ledger vazio e registava um bloqueio falso. Um teste apanhou.
    $done = @($Ticket.Ledger | ForEach-Object { $_.Step })
    $fail = { param($g, $r) [pscustomobject]@{ Step = $Step; Allowed = $false; Gate = $g; Reason = $r } }
    switch ($Step) {
        'Receipt'      { if (-not $Ticket.TrackingRef -or -not $Ticket.PreviousUser) { return & $fail 'G1' 'sem tracking ref ou utilizador anterior: nada entra no fluxo sem rasto' } }
        'Assessment'   { if ('Receipt' -notin $done) { return & $fail 'order' 'Receipt em falta' } }
        'SecureWipe'   { if ('Assessment' -notin $done) { return & $fail 'order' 'Assessment em falta' }
                         if ($Ticket.Condition -eq 'disposal') { return & $fail 'flow' 'dispositivo para descarte: wipe segue outro caminho (Dispose exige evidencia)' } }
        'Reimage'      { if ('SecureWipe' -notin $done) { return & $fail 'G3' 'reimage sem wipe registado: nunca reimaginar por cima de dados' } }
        'QualityCheck' { if ('Reimage' -notin $done) { return & $fail 'order' 'Reimage em falta' } }
        'Storage'      { if ($Ticket.Readiness -ne 'READY') { return & $fail 'G4' "readiness=$($Ticket.Readiness): so READY entra em stock (Unknown != READY)" }
                         if ($Ticket.PreviousUserAccount -notin @('disabled', 'leaver-complete')) { return & $fail 'G2' "conta do utilizador anterior = $($Ticket.PreviousUserAccount): devolvido no papel, activo na pratica" } }
        'Redeploy'     { if ('Storage' -notin $done) { return & $fail 'order' 'Storage em falta' }
                         if ($Ticket.PreviousUserAccount -notin @('disabled', 'leaver-complete')) { return & $fail 'G2' 'conta anterior ainda activa' } }
        'Dispose'      { if ('Assessment' -notin $done) { return & $fail 'order' 'Assessment em falta' }
                         if (-not $Ticket.WipeEvidence) { return & $fail 'G5' 'descarte sem evidencia de wipe: dados saem do edificio' }
                         if ($Ticket.PreviousUserAccount -notin @('disabled', 'leaver-complete')) { return & $fail 'G2' 'conta anterior ainda activa' } }
    }
    [pscustomobject]@{ Step = $Step; Allowed = $true; Gate = ''; Reason = 'gates ok' }
}

function Invoke-ReturnStep {
    <# .SYNOPSIS Executa (simula) um passo se os gates permitirem. Passos destrutivos passam por ShouldProcess.
       Escreve no ledger (so-acrescimo). Devolve o registo do ledger ou o gate que bloqueou. #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param([Parameter(Mandatory)]$Ticket, [Parameter(Mandatory)][string]$Step, [string]$Evidence = '')
    $g = Test-ReturnGate -Ticket $Ticket -Step $Step
    if (-not $g.Allowed) {
        $Ticket.Ledger.Add([pscustomobject]@{ When = (Get-Date).ToUniversalTime().ToString('o'); Step = "BLOCKED:$Step"; Gate = $g.Gate; Note = $g.Reason })
        return $g
    }
    if ($Step -in $script:Destructive) {
        if (-not $PSCmdlet.ShouldProcess("$($Ticket.AssetTag)", "$Step (SIMULATED - nothing is wiped, imaged or disposed by this module)")) {
            return [pscustomobject]@{ Step = $Step; Allowed = $false; Gate = 'ShouldProcess'; Reason = 'nao confirmado / -WhatIf' }
        }
    }
    if ($Step -eq 'SecureWipe' -and $Evidence) { $Ticket.WipeEvidence = $Evidence }
    $rec = [pscustomobject]@{ When = (Get-Date).ToUniversalTime().ToString('o'); Step = $Step; Gate = ''; Note = if ($Evidence) { $Evidence } else { 'SIMULATED' } }
    $Ticket.Ledger.Add($rec)
    $rec
}

function Get-OpenGates {
    <# .SYNOPSIS O que falta para fechar a devolucao - a lista que um humano (ou o playbook) le. #>
    [CmdletBinding()] param([Parameter(Mandatory)]$Ticket)
    $target = if ($Ticket.Condition -eq 'disposal') { 'Dispose' } else { 'Redeploy' }
    $open = @()
    foreach ($s in $script:Order) {
        if ($s -eq 'Dispose' -and $target -ne 'Dispose') { continue }
        if ($s -in @('SecureWipe','Reimage','QualityCheck','Storage','Redeploy') -and $target -eq 'Dispose') { continue }
        if ($s -in @($Ticket.Ledger | ForEach-Object { $_.Step })) { continue }
        $g = Test-ReturnGate -Ticket $Ticket -Step $s
        $open += [pscustomobject]@{ Check = $s; Status = if ($g.Allowed) { 'NEXT' } else { 'BLOCKED' }; Reason = $g.Reason; Evidence = "gate=$($g.Gate)" }
        if (-not $g.Allowed) { break }
    }
    $open
}
Export-ModuleMember -Function New-ReturnTicket, Test-ReturnGate, Invoke-ReturnStep, Get-OpenGates
