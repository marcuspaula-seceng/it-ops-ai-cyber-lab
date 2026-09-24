#Requires -Version 5.1
Set-StrictMode -Version Latest

<#
.SYNOPSIS
    WinOpsAudit — auditoria operacional de um host Windows, SÓ LEITURA.
.DESCRIPTION
    Ciclo 9 (IT Automation & AI) · 22/09/2026.
    Três inventários que um engenheiro de IT/segurança pede primeiro num host, com a mesma
    lógica das regras de detecção do Ciclo 5 aplicada ao sistema vivo:
      Get-ScheduledTaskRisk   tarefas a correr como SYSTEM com gatilho persistente (T1053.005)
      Get-ServicePathRisk     serviços com caminho sem aspas ou fora de Program Files/Windows
      Get-LocalAdminInventory membros de Administrators, com origem (local / domínio / grupo)
    Nenhuma função altera o host. Nenhuma função precisa de elevação para o que devolve
    (o que exigir elevação é marcado como Unknown, não escondido).
    Cada objecto devolvido leva Evidence (o dado bruto que sustenta o veredito) e Reason.
#>

$script:SystemSids = @('S-1-5-18')
$script:SystemNames = @('SYSTEM', 'NT AUTHORITY\SYSTEM', 'LOCAL SYSTEM', 'LOCALSYSTEM')
$script:TrustedRoots = @("$env:ProgramFiles", "${env:ProgramFiles(x86)}", "$env:SystemRoot") |
    Where-Object { $_ } | ForEach-Object { $_.TrimEnd('\').ToLowerInvariant() }

function Test-PersistentTrigger {
    <# .SYNOPSIS Gatilho é persistente? Repetição <= 5 min, arranque ou logon — a regra do Ciclo 3/5. #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowNull()]$Trigger)
    if ($null -eq $Trigger) { return $false }
    $type = $Trigger.PSObject.TypeNames[0]
    if ($type -match 'BootTrigger|LogonTrigger') { return $true }
    $rep = $null
    if ($Trigger.PSObject.Properties['Repetition']) { $rep = $Trigger.Repetition }
    if ($rep -and $rep.PSObject.Properties['Interval'] -and $rep.Interval) {
        $iv = [string]$rep.Interval
        if ($iv -match '^PT(\d+)M$' -and [int]$Matches[1] -le 5) { return $true }
        if ($iv -match '^PT(\d+)S$') { return $true }
    }
    return $false
}

function Get-ScheduledTaskRisk {
    <#
    .SYNOPSIS
        Tarefas agendadas que correm como SYSTEM com gatilho persistente, fora de \Microsoft\.
    .DESCRIPTION
        É a regra 1/2 do Ciclo 5 aplicada ao Task Scheduler vivo, sem depender de auditoria
        4698 ligada. Só leitura. O filtro \Microsoft\ é declarado como porta (Ciclo 3.1):
        use -IncludeMicrosoftPath para o desligar.
    .PARAMETER Task
        Objectos de tarefa (Get-ScheduledTask) — para testes com dados sintéticos. Por defeito lê o host.
    .EXAMPLE
        Get-ScheduledTaskRisk | Format-Table TaskName, Principal, Trigger, Reason
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)]$Task,
        [switch]$IncludeMicrosoftPath
    )
    begin { $tasks = [System.Collections.Generic.List[object]]::new(); $fromHost = $false }
    process { if ($null -ne $Task) { $tasks.Add($Task) } }
    end {
        if ($tasks.Count -eq 0) {
            $fromHost = $true
            try { Get-ScheduledTask -ErrorAction Stop | ForEach-Object { $tasks.Add($_) } }
            catch { Write-Warning "Get-ScheduledTask falhou: $_"; return }
        }
        foreach ($t in $tasks) {
            $path = [string]$t.TaskPath
            if (-not $IncludeMicrosoftPath -and $path -like '\Microsoft\*') { continue }
            $p = $t.Principal
            $uid = if ($p -and $p.PSObject.Properties['UserId']) { [string]$p.UserId } else { '' }
            $isSystem = ($script:SystemSids -contains $uid) -or ($script:SystemNames -contains $uid.ToUpperInvariant())
            if (-not $isSystem) { continue }
            $persist = @($t.Triggers | Where-Object { Test-PersistentTrigger -Trigger $_ })
            if ($persist.Count -eq 0) { continue }
            $trig = $persist[0]
            $trigDesc = $trig.PSObject.TypeNames[0] -replace '.*\.', ''
            if ($trig.PSObject.Properties['Repetition'] -and $trig.Repetition -and $trig.Repetition.Interval) { $trigDesc += " every $($trig.Repetition.Interval)" }
            $cmd = ''
            if ($t.Actions) { $a = @($t.Actions)[0]; if ($a.PSObject.Properties['Execute']) { $cmd = "$($a.Execute) $($a.Arguments)".Trim() } }
            [pscustomobject]@{
                Check     = 'ScheduledTaskRisk'
                TaskName  = "$path$($t.TaskName)"
                Principal = $uid
                RunLevel  = if ($p -and $p.PSObject.Properties['RunLevel']) { [string]$p.RunLevel } else { 'Unknown' }
                Trigger   = $trigDesc
                Command   = $cmd
                Author    = if ($t.PSObject.Properties['Author']) { [string]$t.Author } else { '' }
                State     = if ($t.PSObject.Properties['State']) { [string]$t.State } else { 'Unknown' }
                Reason    = 'Runs as SYSTEM with persistent trigger outside \Microsoft\ (T1053.005 pattern). RunLevel does not describe risk when principal is SYSTEM.'
                Evidence  = "Principal.UserId=$uid; Trigger=$trigDesc; Action=$cmd"
                Source    = if ($fromHost) { $env:COMPUTERNAME } else { 'input' }
            }
        }
    }
}

function Get-ServicePathRisk {
    <#
    .SYNOPSIS
        Serviços cujo binário tem caminho sem aspas com espaços (T1574.009) ou fora de raízes de confiança.
    .PARAMETER Service
        Objectos com Name, DisplayName, PathName, StartName, StartMode — para testes. Por defeito lê o host via CIM.
    #>
    [CmdletBinding()]
    param([Parameter(ValueFromPipeline)]$Service)
    begin { $svcs = [System.Collections.Generic.List[object]]::new(); $fromHost = $false }
    process { if ($null -ne $Service) { $svcs.Add($Service) } }
    end {
        if ($svcs.Count -eq 0) {
            $fromHost = $true
            try { Get-CimInstance Win32_Service -ErrorAction Stop | ForEach-Object { $svcs.Add($_) } }
            catch { Write-Warning "Win32_Service falhou: $_"; return }
        }
        foreach ($s in $svcs) {
            $pn = [string]$s.PathName
            if (-not $pn) { continue }
            $reasons = @()
            $exe = $pn
            if ($pn.StartsWith('"')) { $exe = $pn.Split('"')[1] }
            else {
                $exe = ($pn -split '\s+-|\s+/')[0]
                if ($exe -match '\s' -and $exe -notmatch '^[A-Za-z]:\\[^ ]+\.exe$') { $reasons += 'Unquoted path with spaces (T1574.009)' }
            }
            $dir = $exe.ToLowerInvariant()
            $trusted = $false
            foreach ($r in $script:TrustedRoots) { if ($dir.StartsWith($r + '\')) { $trusted = $true } }
            if (-not $trusted -and $dir -notmatch '^\\\\\?\\' ) { $reasons += 'Binary outside Program Files / Windows' }
            if ($reasons.Count -eq 0) { continue }
            # Dia 2: o host real devolveu o Defender (C:\ProgramData\Microsoft\...) como "fora das
            # raízes". Em vez de esconder por hardcode, anexa-se a assinatura Authenticode (só
            # leitura) — o humano vê "Microsoft-signed" e decide. Sem ficheiro: Unknown, não ok.
            $sigStatus = 'Unknown'; $signer = ''
            if ($fromHost -and $exe -and (Test-Path -LiteralPath $exe -PathType Leaf)) {
                try {
                    $sig = Get-AuthenticodeSignature -LiteralPath $exe -ErrorAction Stop
                    $sigStatus = [string]$sig.Status
                    if ($sig.SignerCertificate) { $signer = [string]$sig.SignerCertificate.Subject }
                } catch { $sigStatus = 'Error' }
            } elseif (-not $fromHost) { $sigStatus = 'NotChecked(input)' }
            [pscustomobject]@{
                Check     = 'ServicePathRisk'
                Name      = [string]$s.Name
                Display   = [string]$s.DisplayName
                Path      = $pn
                RunsAs    = [string]$s.StartName
                StartMode = [string]$s.StartMode
                Signature = $sigStatus
                Signer    = $signer
                Reason    = ($reasons -join '; ')
                Evidence  = "PathName=$pn; Signature=$sigStatus; Signer=$signer"
                Source    = if ($fromHost) { $env:COMPUTERNAME } else { 'input' }
            }
        }
    }
}

function Get-LocalAdminInventory {
    <#
    .SYNOPSIS
        Membros do grupo Administrators local, com origem e classe. Só leitura.
    .PARAMETER Member
        Objectos com Name, ObjectClass, PrincipalSource — para testes. Por defeito lê o host.
    #>
    [CmdletBinding()]
    param([Parameter(ValueFromPipeline)]$Member, [string]$Group = 'Administrators')
    begin { $items = [System.Collections.Generic.List[object]]::new(); $fromHost = $false }
    process { if ($null -ne $Member) { $items.Add($Member) } }
    end {
        if ($items.Count -eq 0) {
            $fromHost = $true
            try { Get-LocalGroupMember -Group $Group -ErrorAction Stop | ForEach-Object { $items.Add($_) } }
            catch { Write-Warning "Get-LocalGroupMember falhou (pode exigir elevação): $_"; return }
        }
        foreach ($m in $items) {
            $cls = [string]$m.ObjectClass
            $src = [string]$m.PrincipalSource
            $flag = @()
            if ($cls -eq 'Group') { $flag += 'Nested group: membership not resolved (Unknown depth)' }
            if ($src -eq 'Local' -and $cls -eq 'User' -and ([string]$m.Name) -notmatch '\\Administrator$') { $flag += 'Extra local admin account' }
            [pscustomobject]@{
                Check    = 'LocalAdminInventory'
                Name     = [string]$m.Name
                Class    = $cls
                Origin   = $src
                Reason   = if ($flag) { $flag -join '; ' } else { 'Expected' }
                Evidence = "ObjectClass=$cls; PrincipalSource=$src"
                Source   = if ($fromHost) { $env:COMPUTERNAME } else { 'input' }
            }
        }
    }
}

function Invoke-WinOpsAudit {
    <#
    .SYNOPSIS
        Corre os três inventários e devolve um relatório JSON-serializável. Só leitura.
    .PARAMETER OutFile
        Se dado, grava JSON. Suporta -WhatIf porque escrever ficheiro é a única acção.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param([string]$OutFile)
    $report = [ordered]@{
        Host       = $env:COMPUTERNAME
        Generated  = (Get-Date).ToUniversalTime().ToString('o')
        ReadOnly   = $true
        Findings   = @(
            @(Get-ScheduledTaskRisk) + @(Get-ServicePathRisk) + @(Get-LocalAdminInventory | Where-Object Reason -ne 'Expected')
        )
    }
    $report.Count = @($report.Findings).Count
    if ($OutFile -and $PSCmdlet.ShouldProcess($OutFile, 'Write audit JSON')) {
        $report | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $OutFile -Encoding UTF8
    }
    [pscustomobject]$report
}

Export-ModuleMember -Function Get-ScheduledTaskRisk, Get-ServicePathRisk, Get-LocalAdminInventory, Invoke-WinOpsAudit, Test-PersistentTrigger
