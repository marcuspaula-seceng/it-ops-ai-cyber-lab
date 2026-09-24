# Pester 3.4.0. Dados sinteticos; nenhum teste toca no host. Um motivo por teste.
Import-Module (Join-Path $PSScriptRoot 'EndpointReadiness.psm1') -Force

Describe 'ops checks (injected)' {
    It 'disk: 25GB passes at min 20' { (Test-DiskSpace -FreeGb 25).Status | Should Be 'Pass' }
    It 'disk: 5GB fails with a reason' { $r = Test-DiskSpace -FreeGb 5; $r.Status | Should Be 'Fail'; $r.Reason | Should Not BeNullOrEmpty }
    It 'route: absent fails' { (Test-DefaultRoute -HasRoute $false).Status | Should Be 'Fail' }
    It 'service: Stopped + Manual (trigger-start) passes - the host taught this' {
        (Test-ServiceRunning -Name wuauserv -Status 'Stopped' -StartType 'Manual').Status | Should Be 'Pass'
    }
    It 'service: Disabled fails regardless of status' {
        (Test-ServiceRunning -Name wuauserv -Status 'Stopped' -StartType 'Disabled').Status | Should Be 'Fail'
    }
    It 'service: Running passes' { (Test-ServiceRunning -Name wuauserv -Status 'Running' -StartType 'Manual').Status | Should Be 'Pass' }
    It 'av devices: camera without audio fails' { (Test-AvDevices -Classes @('Camera','Net')).Status | Should Be 'Fail' }
}

Describe 'security checks (injected)' {
    It 'defender: signatures 10 days old fail even with RTP on (ThirdParty injected empty so the host SecurityCenter is not consulted)' {
        (Test-DefenderStatus -Mp ([pscustomobject]@{ AntivirusEnabled=$true; RealTimeProtectionEnabled=$true; AntivirusSignatureAge=10 }) -ThirdParty @()).Status | Should Be 'Fail'
    }
    It 'defender off but a third-party AV registered passes as AntiVirus - the host taught this' {
        $r = Test-DefenderStatus -Mp ([pscustomobject]@{ AntivirusEnabled=$false; RealTimeProtectionEnabled=$false; AntivirusSignatureAge=65535 }) -ThirdParty @('Vendor Antivirus')
        $r.Status | Should Be 'Pass'; $r.Check | Should Be 'AntiVirus'
    }
    It 'defender off and only Defender registered fails' {
        (Test-DefenderStatus -Mp ([pscustomobject]@{ AntivirusEnabled=$false; RealTimeProtectionEnabled=$false; AntivirusSignatureAge=65535 }) -ThirdParty @('Windows Defender')).Status | Should Be 'Fail'
    }
    It 'defender: all good passes' {
        (Test-DefenderStatus -Mp ([pscustomobject]@{ AntivirusEnabled=$true; RealTimeProtectionEnabled=$true; AntivirusSignatureAge=1 })).Status | Should Be 'Pass'
    }
    It 'firewall: one profile off fails and names it' {
        $p = @([pscustomobject]@{Name='Domain';Enabled=$true},[pscustomobject]@{Name='Private';Enabled=$true},[pscustomobject]@{Name='Public';Enabled=$false})
        $r = Test-FirewallProfiles -Profiles $p; $r.Status | Should Be 'Fail'; $r.Evidence | Should Match 'Public'
    }
    It 'bitlocker: Off fails' { (Test-DiskEncryption -Volume ([pscustomobject]@{ ProtectionStatus='Off' })).Status | Should Be 'Fail' }
    It 'baseline: Microsoft-signed "outside roots" is evidence, not a finding' {
        $f = @([pscustomobject]@{ Check='ServicePathRisk'; Name='WinDefend'; Reason='Binary outside Program Files / Windows'; Signer='CN=Microsoft Windows Publisher' })
        (Test-WinOpsBaseline -Findings $f).Status | Should Be 'Pass'
    }
    It 'baseline: unquoted path is a real finding' {
        $f = @([pscustomobject]@{ Check='ServicePathRisk'; Name='vendor'; Reason='Unquoted path with spaces (T1574.009)'; Signer='CN=Vendor' })
        $r = Test-WinOpsBaseline -Findings $f; $r.Status | Should Be 'Fail'; $r.Evidence | Should Match 'vendor'
    }
    It 'baseline: empty findings pass' { (Test-WinOpsBaseline -Findings @()).Status | Should Be 'Pass' }
}

Describe 'contract' {
    It 'every check object has the same shape' {
        $r = Test-DiskSpace -FreeGb 1
        ($r.PSObject.Properties.Name -join ',') | Should Be 'Area,Check,Status,Evidence,Reason'
    }
    It 'Status is limited to Pass/Fail/Unknown' {
        { [void](& (Get-Module EndpointReadiness) { New-Check 'x' 'y' 'Maybe' 'z' }) } | Should Throw
    }
}
