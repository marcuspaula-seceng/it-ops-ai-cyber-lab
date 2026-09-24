# Pester 3.4.0. Ciclo 9.1 — a frase que passou no Dia 2 é o primeiro teste.
Import-Module (Join-Path $PSScriptRoot 'IntentGuard.psm1') -Force

Describe 'Test-ChangeIntent' {
    It 'flags the exact sentence that passed the command guard on Day 2' {
        Test-ChangeIntent "Confirm Marcus' role and permissions are necessary, and consider removing if not required." | Should Be $true
    }
    It 'flags disable / uninstall / revoke without any cmdlet' {
        Test-ChangeIntent 'Disable the service until the vendor confirms.' | Should Be $true
        Test-ChangeIntent 'Uninstall the anti-cheat component.' | Should Be $true
        Test-ChangeIntent 'Revoke local admin rights for this account.' | Should Be $true
    }
    It 'does NOT flag read-only verifications' {
        Test-ChangeIntent 'Inspect the service configuration and check the file signature.' | Should Be $false
        Test-ChangeIntent 'Confirm the group membership with the owner.' | Should Be $false
        Test-ChangeIntent 'Review the service logs for suspicious activity.' | Should Be $false
    }
    It 'respects a close negation' {
        Test-ChangeIntent 'Do not remove the account before the review.' | Should Be $false
        Test-ChangeIntent 'Verify the path; never delete the binary yourself.' | Should Be $false
    }
    It 'declared limit: negation more than 3 words away still flags (false positive by design)' {
        # 1.a versao deste teste usava "...and without approval, remove" — "without" ficava a 2
        # palavras do verbo e a guarda (correctamente) nao marcou. O teste estava errado, nao o modulo.
        Test-ChangeIntent 'We should not, unless the security team explicitly agrees otherwise, remove the account.' | Should Be $true
    }
    It 'empty line is not intent' { Test-ChangeIntent '' | Should Be $false }
}

Describe 'Invoke-IntentGuard' {
    It 'labels flagged lines and keeps the rest verbatim' {
        $r = Invoke-IntentGuard "Check the signature.`nConsider removing the account.`nReview logs."
        $r.Flagged | Should Be 1
        ($r.Text -split "`n")[1] | Should Match '^\[ADVICE: CHANGE'
        ($r.Text -split "`n")[0] | Should Be 'Check the signature.'
    }
}
