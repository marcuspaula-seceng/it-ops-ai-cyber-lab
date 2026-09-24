#Requires -Version 5.1
Set-StrictMode -Version Latest
<#
.SYNOPSIS
    IntentGuard - Ciclo 9.1. Fecha o limite medido no Dia 2: a guarda de comandos deixou
    passar "consider removing if not required". Esta classifica INTENCAO em linguagem natural.
    (Ficheiro em ASCII: PS 5.1 sem BOM le UTF-8 como cp1252.)
.DESCRIPTION
    Deterministico, sem modelo. Uma linha e marcada se contiver um verbo de mudanca
    (remove, delete, disable, uninstall, revoke, kill, stop, reset, wipe, purge, rotate...)
    dirigido a um objecto do host, mesmo sem cmdlet. Linhas marcadas nao sao apagadas: sao
    rotuladas [ADVICE: CHANGE] para o humano ver que e sugestao de mudanca, nao verificacao.
    Limite declarado: regex sobre ingles; frases negativas ("do not remove") sao tratadas
    como nao-mudanca so quando a negacao esta a <=3 palavras do verbo.
#>
$script:ChangeVerbs = 'remov(e|ing|al)|delet(e|ing|ion)|disabl(e|ing)|uninstall(ing)?|revok(e|ing)|kill(ing)?|stop(ping)?|reset(ting)?|wip(e|ing)|purg(e|ing)|rotat(e|ing)|terminat(e|ing)|shut ?down|unregister(ing)?|block(ing)?|deny(ing)?|quarantin(e|ing)|reinstall(ing)?|chang(e|ing) the (password|permission|config)'
$script:Negation = '\b(do not|don''t|never|avoid|without|not)\b'

function Test-ChangeIntent {
    <# .SYNOPSIS True se a frase sugere alterar o host. #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Line)
    if (-not $Line) { return $false }
    $m = [regex]::Match($Line, "(?i)\b($($script:ChangeVerbs))\b")
    if (-not $m.Success) { return $false }
    # negacao ate 3 palavras antes do verbo
    $before = $Line.Substring(0, $m.Index)
    $tail = ($before -split '\s+' | Where-Object { $_ } | Select-Object -Last 3) -join ' '
    if ($tail -match "(?i)$script:Negation") { return $false }
    return $true
}

function Invoke-IntentGuard {
    <# .SYNOPSIS Rotula linhas com intenção de mudança. Devolve texto e contagem. #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Text)
    $n = 0; $out = @()
    foreach ($line in ($Text -split "`r?`n")) {
        # ASCII de proposito: PS 5.1 le UTF-8 sem BOM como cp1252 e um travessao (E2 80 94) vira aspas.
        if (Test-ChangeIntent -Line $line) { $n++; $out += "[ADVICE: CHANGE - human decision] $line" }
        else { $out += $line }
    }
    [pscustomobject]@{ Flagged = $n; Text = ($out -join "`n") }
}
Export-ModuleMember -Function Test-ChangeIntent, Invoke-IntentGuard
