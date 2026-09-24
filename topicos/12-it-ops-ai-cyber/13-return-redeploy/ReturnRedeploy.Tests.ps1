# Pester 3.4.0. Tickets sinteticos. Um motivo por teste. Nada e apagado, imaginado ou descartado.
Import-Module (Join-Path $PSScriptRoot 'ReturnRedeploy.psm1') -Force

function New-T([string]$Acct = 'disabled', [string]$Cond = 'reusable', [string]$Ref = 'RET-0001') {
    New-ReturnTicket -AssetTag 'SAMPLE-0008' -TrackingRef $Ref -PreviousUser 'u.sample' -PreviousUserAccount $Acct -Condition $Cond
}
function Advance($t, [string[]]$Steps) { foreach ($s in $Steps) { $null = Invoke-ReturnStep -Ticket $t -Step $s -Confirm:$false } }

Describe 'G1 receipt' {
    It 'no tracking ref blocks Receipt' { (Test-ReturnGate -Ticket (New-T -Ref '') -Step Receipt).Allowed | Should Be $false }
    It 'with ref and user, Receipt passes' { (Test-ReturnGate -Ticket (New-T) -Step Receipt).Allowed | Should Be $true }
}

Describe 'G3 wipe before reimage' {
    It 'Reimage without SecureWipe is blocked with G3' {
        $t = New-T; Advance $t @('Receipt','Assessment')
        $g = Test-ReturnGate -Ticket $t -Step Reimage; $g.Allowed | Should Be $false; $g.Gate | Should Be 'G3'
    }
    It 'Reimage after wipe passes' { $t = New-T; Advance $t @('Receipt','Assessment','SecureWipe'); (Test-ReturnGate -Ticket $t -Step Reimage).Allowed | Should Be $true }
}

Describe 'G4 readiness before storage' {
    It 'readiness unknown blocks Storage (Unknown != READY)' {
        $t = New-T; Advance $t @('Receipt','Assessment','SecureWipe','Reimage','QualityCheck')
        $g = Test-ReturnGate -Ticket $t -Step Storage; $g.Allowed | Should Be $false; $g.Gate | Should Be 'G4'
    }
    It 'readiness READY allows Storage' {
        $t = New-T; Advance $t @('Receipt','Assessment','SecureWipe','Reimage','QualityCheck'); $t.Readiness = 'READY'
        (Test-ReturnGate -Ticket $t -Step Storage).Allowed | Should Be $true
    }
}

Describe 'G2 identity: returned on paper, active in practice' {
    It 'previous account still active blocks Storage even when READY' {
        $t = New-T -Acct 'active'; Advance $t @('Receipt','Assessment','SecureWipe','Reimage','QualityCheck'); $t.Readiness = 'READY'
        $g = Test-ReturnGate -Ticket $t -Step Storage; $g.Allowed | Should Be $false; $g.Gate | Should Be 'G2'
    }
    It 'unknown account state is NOT accepted' {
        $t = New-T -Acct 'unknown'; Advance $t @('Receipt','Assessment','SecureWipe','Reimage','QualityCheck'); $t.Readiness = 'READY'
        (Test-ReturnGate -Ticket $t -Step Storage).Gate | Should Be 'G2'
    }
    It 'wipe itself is NOT blocked by an active account (data first, closure later)' {
        $t = New-T -Acct 'active'; Advance $t @('Receipt','Assessment')
        (Test-ReturnGate -Ticket $t -Step SecureWipe).Allowed | Should Be $true
    }
}

Describe 'G5 disposal' {
    It 'Dispose without wipe evidence is blocked' {
        $t = New-T -Cond 'disposal'; Advance $t @('Receipt','Assessment')
        (Test-ReturnGate -Ticket $t -Step Dispose).Gate | Should Be 'G5'
    }
    It 'Dispose with evidence and disabled account passes' {
        $t = New-T -Cond 'disposal'; Advance $t @('Receipt','Assessment'); $t.WipeEvidence = 'WIPE-CERT-0042'
        (Test-ReturnGate -Ticket $t -Step Dispose).Allowed | Should Be $true
    }
}

Describe 'ShouldProcess and ledger' {
    It '-WhatIf on SecureWipe writes nothing to the ledger' {
        $t = New-T; Advance $t @('Receipt','Assessment'); $before = $t.Ledger.Count
        $null = Invoke-ReturnStep -Ticket $t -Step SecureWipe -WhatIf
        $t.Ledger.Count | Should Be $before
    }
    It 'a blocked step is recorded as BLOCKED, never silently dropped' {
        $t = New-T; Advance $t @('Receipt','Assessment'); $null = Invoke-ReturnStep -Ticket $t -Step Reimage -Confirm:$false
        ($t.Ledger | Select-Object -Last 1).Step | Should Be 'BLOCKED:Reimage'
    }
    It 'ledger only grows' {
        $t = New-T; Advance $t @('Receipt'); $n = $t.Ledger.Count; Advance $t @('Assessment'); $t.Ledger.Count | Should Be ($n + 1)
    }
    It 'Get-OpenGates stops at the first blocked gate and names it' {
        $t = New-T -Acct 'active'; Advance $t @('Receipt','Assessment','SecureWipe','Reimage','QualityCheck'); $t.Readiness = 'READY'
        $o = @(Get-OpenGates -Ticket $t); $o[0].Check | Should Be 'Storage'; $o[0].Status | Should Be 'BLOCKED'; $o[0].Evidence | Should Match 'G2'
    }
}
