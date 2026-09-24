#Requires -Version 5.1
Set-StrictMode -Version Latest
<#
.SYNOPSIS
    EndpointReadiness - Ciclo 11. Validacao pos-imagem SO LEITURA: operacional + seguranca.
.DESCRIPTION
    Evolucao do Get-EndpointReadiness.ps1 publico (it-infrastructure-operations-portfolio,
    projeto 01): de script a modulo testavel. Cada verificacao devolve o mesmo objecto
    {Area, Check, Status, Evidence, Reason} com Status em Pass / Fail / Unknown - e Unknown
    NUNCA conta como Pass (licao dos Ciclos 7 e 9).
    Processo real, sanitizado: o metodo de validacao pos-imagem que o autor padronizou num
    ambiente EMEA distribuido (sem nome do empregador, sem numeros absolutos). O que era
    "camara, microfone, audio, rede, updates" ganha a camada de seguranca que uma imagem
    tem de trazer: Defender activo, firewall nos 3 perfis, disco cifrado, e a baseline do
    WinOpsAudit (servicos, tarefas SYSTEM, admins locais).
    Ficheiro em ASCII: PS 5.1 le UTF-8 sem BOM como cp1252.
#>
$script:OnWindows = ($env:OS -eq 'Windows_NT')
$script:WinOps = Join-Path $PSScriptRoot '..\..\10-it-automation-ai\WinOpsAudit\WinOpsAudit.psm1'

function New-Check {
    param([string]$Area, [string]$Check, [ValidateSet('Pass', 'Fail', 'Unknown')][string]$Status, [string]$Evidence, [string]$Reason = '')
    [pscustomobject]@{ Area = $Area; Check = $Check; Status = $Status; Evidence = $Evidence; Reason = $Reason }
}

# ---------- operacional (do script publico, agora injectavel) ----------
function Test-DiskSpace {
    <# .SYNOPSIS Espaco livre no disco de sistema. -FreeGb para testes. #>
    [CmdletBinding()] param([Nullable[double]]$FreeGb, [double]$MinGb = 20)
    if ($null -eq $FreeGb) {
        try { $d = Get-PSDrive -Name ($env:SystemDrive.TrimEnd(':')) -ErrorAction Stop; $FreeGb = [math]::Round($d.Free / 1GB, 1) } catch { return New-Check 'ops' 'DiskSpace' 'Unknown' 'query failed' }
    }
    if ($FreeGb -ge $MinGb) { New-Check 'ops' 'DiskSpace' 'Pass' "free=${FreeGb}GB min=${MinGb}GB" }
    else { New-Check 'ops' 'DiskSpace' 'Fail' "free=${FreeGb}GB min=${MinGb}GB" 'imagem nova sem espaco para updates' }
}
function Test-DefaultRoute {
    <# .SYNOPSIS Ha rota por defeito? -HasRoute para testes. #>
    [CmdletBinding()] param([Nullable[bool]]$HasRoute)
    if ($null -eq $HasRoute) {
        try { $HasRoute = [bool](Get-NetRoute -ErrorAction Stop | Where-Object DestinationPrefix -eq '0.0.0.0/0') } catch { return New-Check 'ops' 'DefaultRoute' 'Unknown' 'Get-NetRoute failed' }
    }
    if ($HasRoute) { New-Check 'ops' 'DefaultRoute' 'Pass' 'default route present' } else { New-Check 'ops' 'DefaultRoute' 'Fail' 'no 0.0.0.0/0' 'sem rede o endpoint nao recebe politicas nem updates' }
}
function Test-ServiceRunning {
    <# .SYNOPSIS Servico disponivel? Dia 1 (host real): wuauserv e trigger-start no Win10/11 - Stopped e
       normal; so Disabled e falha. -Status/-StartType para testes. #>
    [CmdletBinding()] param([Parameter(Mandatory)][string]$Name, [string]$Status, [string]$StartType, [string]$Area = 'ops')
    if (-not $Status) {
        try { $s = Get-Service -Name $Name -ErrorAction Stop; $Status = $s.Status.ToString(); $StartType = $s.StartType.ToString() } catch { return New-Check $Area "Service:$Name" 'Unknown' 'not found' }
    }
    if ($StartType -eq 'Disabled') { return New-Check $Area "Service:$Name" 'Fail' "status=$Status start=$StartType" 'servico desactivado na imagem' }
    if ($Status -eq 'Running' -or $StartType -in @('Manual', 'Automatic')) { New-Check $Area "Service:$Name" 'Pass' "status=$Status start=$StartType" }
    else { New-Check $Area "Service:$Name" 'Fail' "status=$Status start=$StartType" }
}
function Test-AvDevices {
    <# .SYNOPSIS Camara e microfone presentes (PnP). -Classes para testes. #>
    [CmdletBinding()] param([string[]]$Classes)
    if (-not $Classes) { try { $Classes = @(Get-PnpDevice -Status OK -ErrorAction Stop | Select-Object -ExpandProperty Class -Unique) } catch { return New-Check 'ops' 'AvDevices' 'Unknown' 'Get-PnpDevice failed' } }
    $cam = $Classes -contains 'Camera' -or $Classes -contains 'Image'
    $aud = $Classes -contains 'AudioEndpoint' -or $Classes -contains 'MEDIA'
    if ($cam -and $aud) { New-Check 'ops' 'AvDevices' 'Pass' "camera=$cam audio=$aud" } else { New-Check 'ops' 'AvDevices' 'Fail' "camera=$cam audio=$aud" 'reunioes remotas dependem disto' }
}

# ---------- seguranca pos-imagem (novo) ----------
function Test-DefenderStatus {
    <# .SYNOPSIS Defender real-time + assinaturas recentes. -Mp para testes (objecto com AntivirusEnabled, RealTimeProtectionEnabled, AntivirusSignatureAge). #>
    [CmdletBinding()] param($Mp, $ThirdParty)
    if ($null -eq $Mp) { try { $Mp = Get-MpComputerStatus -ErrorAction Stop } catch { return New-Check 'sec' 'Defender' 'Unknown' 'Get-MpComputerStatus failed' } }
    $ok = $Mp.AntivirusEnabled -and $Mp.RealTimeProtectionEnabled -and ([int]$Mp.AntivirusSignatureAge -le 7)
    $ev = "av=$($Mp.AntivirusEnabled) rtp=$($Mp.RealTimeProtectionEnabled) sigAgeDays=$($Mp.AntivirusSignatureAge)"
    if ($ok) { return New-Check 'sec' 'Defender' 'Pass' $ev }
    # Dia 1 (host real): av=False porque OUTRO AV e o registado. Consultar o SecurityCenter antes de Fail.
    if ($null -eq $ThirdParty) {
        try { $ThirdParty = @(Get-CimInstance -Namespace root/SecurityCenter2 -ClassName AntiVirusProduct -ErrorAction Stop | Select-Object -ExpandProperty displayName) } catch { $ThirdParty = $null }
    }
    $other = @($ThirdParty | Where-Object { $_ -and $_ -notlike '*Defender*' })
    if ($other.Count -gt 0) { return New-Check 'sec' 'AntiVirus' 'Pass' ("$ev; SecurityCenter=" + ($other -join ',')) 'AV de terceiro registado; Defender em passivo e esperado' }
    New-Check 'sec' 'Defender' 'Fail' $ev 'endpoint sem AV activo/actualizado nao vai para o utilizador'
}
function Test-FirewallProfiles {
    <# .SYNOPSIS Os 3 perfis ligados. -Profiles para testes (objectos Name, Enabled). #>
    [CmdletBinding()] param($Profiles)
    if ($null -eq $Profiles) { try { $Profiles = Get-NetFirewallProfile -ErrorAction Stop } catch { return New-Check 'sec' 'Firewall' 'Unknown' 'Get-NetFirewallProfile failed' } }
    $off = @($Profiles | Where-Object { -not $_.Enabled } | ForEach-Object Name)
    if ($off.Count -eq 0) { New-Check 'sec' 'Firewall' 'Pass' 'Domain/Private/Public enabled' } else { New-Check 'sec' 'Firewall' 'Fail' "disabled=$($off -join ',')" }
}
function Test-DiskEncryption {
    <# .SYNOPSIS BitLocker no disco de sistema. Exige elevacao: sem ela -> Unknown, nunca Pass. -Volume para testes (ProtectionStatus). #>
    [CmdletBinding()] param($Volume)
    if ($null -eq $Volume) {
        try { $Volume = Get-BitLockerVolume -MountPoint $env:SystemDrive -ErrorAction Stop } catch { return New-Check 'sec' 'DiskEncryption' 'Unknown' "Get-BitLockerVolume: $($_.Exception.Message.Split([char]10)[0])" 'exige elevacao; Unknown != Pass' }
    }
    if ([string]$Volume.ProtectionStatus -eq 'On') { New-Check 'sec' 'DiskEncryption' 'Pass' 'ProtectionStatus=On' } else { New-Check 'sec' 'DiskEncryption' 'Fail' "ProtectionStatus=$($Volume.ProtectionStatus)" 'portatil sem cifra = fuga de dados ao primeiro roubo' }
}
function Test-WinOpsBaseline {
    <# .SYNOPSIS Baseline do Ciclo 9: servicos inseguros, tarefas SYSTEM persistentes, admins extra. -Findings para testes. #>
    [CmdletBinding()] param($Findings)
    if ($null -eq $Findings) {
        if (-not (Test-Path $script:WinOps)) { return New-Check 'sec' 'WinOpsBaseline' 'Unknown' 'WinOpsAudit module not found' }
        Import-Module $script:WinOps -Force
        $Findings = @(Get-ServicePathRisk) + @(Get-ScheduledTaskRisk) + @(Get-LocalAdminInventory | Where-Object Reason -ne 'Expected')
    }
    $Findings = @($Findings)
    # assinatura Microsoft valida em "fora das raizes" e evidencia, nao achado (Ciclo 9 Dia 2)
    $real = @($Findings | Where-Object { -not ($_.PSObject.Properties['Signer'] -and $_.Signer -like '*Microsoft*' -and $_.Reason -like '*outside*') })
    if ($real.Count -eq 0) { New-Check 'sec' 'WinOpsBaseline' 'Pass' "findings=$($Findings.Count) real=0" }
    else { New-Check 'sec' 'WinOpsBaseline' 'Fail' ("real=$($real.Count): " + (($real | ForEach-Object { $_.Check + '/' + ($_.PSObject.Properties['Name','TaskName'] | Where-Object Value | Select-Object -First 1 -ExpandProperty Value) }) -join '; ')) 'imagem nao deve sair com isto' }
}

function Invoke-EndpointReadiness {
    <# .SYNOPSIS Corre tudo; Ready so se NENHUM Fail e NENHUM Unknown em seguranca. -OutFile com -WhatIf. #>
    [CmdletBinding(SupportsShouldProcess)] param([string]$OutFile)
    $checks = @(Test-DiskSpace; Test-DefaultRoute; (Test-ServiceRunning -Name wuauserv); Test-AvDevices
                Test-DefenderStatus; Test-FirewallProfiles; Test-DiskEncryption; Test-WinOpsBaseline)
    $fail = @($checks | Where-Object Status -eq 'Fail').Count
    $unkSec = @($checks | Where-Object { $_.Status -eq 'Unknown' -and $_.Area -eq 'sec' }).Count
    $verdict = if ($fail -eq 0 -and $unkSec -eq 0) { 'READY' } elseif ($fail -eq 0) { 'NOT READY - security checks Unknown (needs elevation or module)' } else { 'NOT READY' }
    $r = [ordered]@{ Host = $env:COMPUTERNAME; Generated = (Get-Date).ToUniversalTime().ToString('o'); ReadOnly = $true; Verdict = $verdict; Fail = $fail; UnknownSecurity = $unkSec; Checks = $checks }
    if ($OutFile -and $PSCmdlet.ShouldProcess($OutFile, 'Write readiness JSON')) { $r | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $OutFile -Encoding UTF8 }
    [pscustomobject]$r
}
Export-ModuleMember -Function Test-DiskSpace, Test-DefaultRoute, Test-ServiceRunning, Test-AvDevices, Test-DefenderStatus, Test-FirewallProfiles, Test-DiskEncryption, Test-WinOpsBaseline, Invoke-EndpointReadiness
