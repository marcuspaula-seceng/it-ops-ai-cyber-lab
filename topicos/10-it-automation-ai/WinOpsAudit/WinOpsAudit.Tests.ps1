# Pester 3.4.0 (o que o host tem). Dados SINTÉTICOS: nenhum teste toca no host.
# Cada teste falha por um motivo, nomeado.
Import-Module (Join-Path $PSScriptRoot 'WinOpsAudit.psm1') -Force

function New-Trigger([string]$Type, [string]$Interval) {
    $t = [pscustomobject]@{ Repetition = $null }
    if ($Interval) { $t.Repetition = [pscustomobject]@{ Interval = $Interval } }
    $t.PSObject.TypeNames.Insert(0, "Microsoft.Management.Infrastructure.CimInstance#MSFT_Task$Type")
    $t
}
function New-Task([string]$Path, [string]$Name, [string]$UserId, $Triggers, [string]$Exe, [string]$Args, [string]$RunLevel = 'Limited') {
    [pscustomobject]@{
        TaskPath  = $Path; TaskName = $Name; Author = 'test'; State = 'Ready'
        Principal = [pscustomobject]@{ UserId = $UserId; RunLevel = $RunLevel }
        Triggers  = @($Triggers)
        Actions   = @([pscustomobject]@{ Execute = $Exe; Arguments = $Args })
    }
}

Describe 'Test-PersistentTrigger' {
    It 'PT1M repetition is persistent' { Test-PersistentTrigger (New-Trigger 'TimeTrigger' 'PT1M') | Should Be $true }
    It 'PT5M is the upper bound and is persistent' { Test-PersistentTrigger (New-Trigger 'TimeTrigger' 'PT5M') | Should Be $true }
    It 'PT10M is NOT persistent' { Test-PersistentTrigger (New-Trigger 'TimeTrigger' 'PT10M') | Should Be $false }
    It 'BootTrigger is persistent' { Test-PersistentTrigger (New-Trigger 'BootTrigger' $null) | Should Be $true }
    It 'LogonTrigger is persistent' { Test-PersistentTrigger (New-Trigger 'LogonTrigger' $null) | Should Be $true }
    It 'weekly CalendarTrigger without repetition is NOT persistent' { Test-PersistentTrigger (New-Trigger 'CalendarTrigger' $null) | Should Be $false }
    It 'null trigger is NOT persistent (no crash)' { Test-PersistentTrigger $null | Should Be $false }
}

Describe 'Get-ScheduledTaskRisk (synthetic)' {
    $evil   = New-Task '\' 'eviltask' 'S-1-5-18' (New-Trigger 'TimeTrigger' 'PT1M') 'C:\tools\shell.cmd' '' 'LeastPrivilege'
    $weekly = New-Task '\' 'WeeklyCleanup' 'S-1-5-18' (New-Trigger 'CalendarTrigger' $null) 'C:\Scripts\cleanup.ps1' ''
    $user   = New-Task '\' 'SyncNotes' 'LAB\u1' (New-Trigger 'TimeTrigger' 'PT1M') 'C:\Tools\sync.exe' ''
    $msft   = New-Task '\Microsoft\Windows\Fake\' 'Updater' 'S-1-5-18' (New-Trigger 'BootTrigger' $null) 'C:\Windows\Temp\a.cmd' ''
    $byName = New-Task '\' 'ByName' 'NT AUTHORITY\SYSTEM' (New-Trigger 'LogonTrigger' $null) 'C:\x.exe' ''

    It 'flags the real-sample pattern (SYSTEM + PT1M) with the RunLevel note in Reason' {
        $r = @($evil | Get-ScheduledTaskRisk)
        $r.Count | Should Be 1
        $r[0].TaskName | Should Be '\eviltask'
        $r[0].Reason | Should Match 'RunLevel does not describe risk'
    }
    It 'does not flag SYSTEM + weekly' { @($weekly | Get-ScheduledTaskRisk).Count | Should Be 0 }
    It 'does not flag user principal + PT1M' { @($user | Get-ScheduledTaskRisk).Count | Should Be 0 }
    It 'hides \Microsoft\ by default (declared evasion door)' { @($msft | Get-ScheduledTaskRisk).Count | Should Be 0 }
    It 'shows \Microsoft\ with -IncludeMicrosoftPath' { @($msft | Get-ScheduledTaskRisk -IncludeMicrosoftPath).Count | Should Be 1 }
    It 'recognises SYSTEM by name as well as by SID' { @($byName | Get-ScheduledTaskRisk).Count | Should Be 1 }
    It 'never mutates input' {
        $before = $evil | ConvertTo-Json -Depth 5
        $null = $evil | Get-ScheduledTaskRisk
        ($evil | ConvertTo-Json -Depth 5) | Should Be $before
    }
}

Describe 'Get-ServicePathRisk (synthetic)' {
    function New-Svc([string]$Name, [string]$Path) { [pscustomobject]@{ Name = $Name; DisplayName = $Name; PathName = $Path; StartName = 'LocalSystem'; StartMode = 'Auto' } }
    It 'flags unquoted path with spaces' {
        $r = @((New-Svc 'bad' 'C:\Program Files\Vendor App\svc.exe -k') | Get-ServicePathRisk)
        $r.Count | Should Be 1
        $r[0].Reason | Should Match 'Unquoted'
    }
    It 'accepts quoted path with spaces under Program Files' {
        @((New-Svc 'ok' '"C:\Program Files\Vendor App\svc.exe" -k') | Get-ServicePathRisk).Count | Should Be 0
    }
    It 'flags binary outside trusted roots' {
        $r = @((New-Svc 'tmp' '"C:\Users\Public\svc.exe"') | Get-ServicePathRisk)
        $r[0].Reason | Should Match 'outside'
    }
    It 'accepts Windows system services' {
        @((New-Svc 'w' 'C:\WINDOWS\system32\svchost.exe -k netsvcs') | Get-ServicePathRisk).Count | Should Be 0
    }
    It 'skips services with empty PathName instead of crashing' {
        @((New-Svc 'e' '') | Get-ServicePathRisk).Count | Should Be 0
    }
}

Describe 'Get-LocalAdminInventory (synthetic)' {
    function New-Mbr([string]$Name, [string]$Class, [string]$Src) { [pscustomobject]@{ Name = $Name; ObjectClass = $Class; PrincipalSource = $Src } }
    It 'built-in Administrator is Expected' { (New-Mbr 'PC\Administrator' 'User' 'Local' | Get-LocalAdminInventory).Reason | Should Be 'Expected' }
    It 'extra local user admin is flagged' { (New-Mbr 'PC\marcus' 'User' 'Local' | Get-LocalAdminInventory).Reason | Should Match 'Extra local admin' }
    It 'nested group is flagged as Unknown depth, not resolved silently' { (New-Mbr 'DOM\Helpdesk' 'Group' 'ActiveDirectory' | Get-LocalAdminInventory).Reason | Should Match 'Unknown depth' }
}
