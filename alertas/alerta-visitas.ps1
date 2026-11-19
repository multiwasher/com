# Alerta de visitas inversas marcadas para amanhã.
# Lê a folha "visitas" pelo mesmo Apps Script da app e aplica a mesma regra
# de resolução: por (pessoa, dia) vale o registo mais recente; ANULADO remove.

$GOOGLE_SCRIPT_URL = "https://script.google.com/macros/s/AKfycbwEEWLyq_MNjkmHbFBUdHbTgciYcwfBTOwisBBOQJqN-uZ5eaQ0PLOvnHgDF23HNUSy/exec"
$inv = [Globalization.CultureInfo]::InvariantCulture

Add-Type -AssemblyName System.Windows.Forms

function Aviso($texto, $icone) {
    [System.Windows.Forms.MessageBox]::Show($texto, "Visitas inversas", "OK", $icone) | Out-Null
}

# A folha devolve as datas como "yyyy-MM-dd", "dd/MM/yyyy" ou Date.toString()
# ("Tue Aug 11 2026 00:00:00 GMT+0100 ..."). Tudo passa a "yyyy-MM-dd".
function DiaISO($v) {
    $t = "$v".Trim()
    if (-not $t) { return "" }
    if ($t -match '^(\d{4})-(\d{2})-(\d{2})') { return "$($Matches[1])-$($Matches[2])-$($Matches[3])" }
    if ($t -match '^(\d{1,2})[/-](\d{1,2})[/-](\d{4})') { return "{0}-{1:D2}-{2:D2}" -f $Matches[3], [int]$Matches[2], [int]$Matches[1] }
    if ($t -match '^\w{3} (\w{3} \d{1,2} \d{4})') {
        try { return [datetime]::ParseExact($Matches[1], 'MMM d yyyy', $inv).ToString('yyyy-MM-dd') } catch {}
    }
    return ""
}

# Hora de gravação normalizada para "yyyy-MM-dd HH:mm", para ordenar.
function NormTime($v) {
    $t = "$v".Trim()
    if ($t -match '^\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}') { return $t.Substring(0, 16).Replace('T', ' ') }
    if ($t -match '^\w{3} (\w{3} \d{1,2} \d{4} \d{2}:\d{2})') {
        try { return [datetime]::ParseExact($Matches[1], 'MMM d yyyy HH:mm', $inv).ToString('yyyy-MM-dd HH:mm') } catch {}
    }
    return $t
}

try {
    $resp = Invoke-RestMethod -Uri "$GOOGLE_SCRIPT_URL`?action=visitas" -UseBasicParsing -TimeoutSec 60
} catch {
    Aviso "Não foi possível ler a folha das visitas.`n`n$($_.Exception.Message)" "Warning"
    exit 1
}

$i = 0
$eventos = foreach ($row in @($resp.rows)) {
    $i++
    $nome = "$($row.memberName)".Trim()
    $dia = DiaISO $row.dia
    if (-not $nome -or -not $dia) { continue }
    [pscustomobject]@{ Nome = $nome; Dia = $dia; T = (NormTime $row.time); Ordem = $i; Row = $row }
}

# Reposição cronológica: o último registo de cada (pessoa, dia) manda.
$dias = @{}
foreach ($ev in ($eventos | Sort-Object T, Ordem)) {
    $chave = "$($ev.Nome.ToLower())|$($ev.Dia)"
    if ("$($ev.Row.visita)".Trim().ToUpper() -eq 'ANULADO') { $dias.Remove($chave) }
    else { $dias[$chave] = $ev }
}

$amanha = (Get-Date).AddDays(1).ToString('yyyy-MM-dd')
$deAmanha = @($dias.Values | Where-Object { $_.Dia -eq $amanha } | Sort-Object Nome)

if ($deAmanha.Count -eq 0) { exit 0 }   # nada para amanhã: não incomoda

$linhas = $deAmanha | ForEach-Object {
    $extra = @($_.Row.visita, $_.Row.pais) | Where-Object { "$_".Trim() }
    "• $($_.Nome)" + $(if ($extra) { " — " + ($extra -join ' · ') } else { "" })
}
$dataPt = (Get-Date).AddDays(1).ToString('dddd, dd/MM/yyyy', [Globalization.CultureInfo]'pt-PT')
Aviso "Visitas inversas amanhã ($dataPt):`n`n$($linhas -join "`n")" "Information"
