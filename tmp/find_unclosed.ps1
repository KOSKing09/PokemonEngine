$p='c:\Users\trane\GameMakerProjects\PokemonEngine\scripts\party_input\party_input.gml'
$lines=Get-Content -LiteralPath $p
$open=0; $close=0; $diffs = @()
for($i=0; $i -lt $lines.Count; $i++){
    $s = $lines[$i]
    $open += ($s.ToCharArray() | Where-Object { $_ -eq '{' }).Count
    $close += ($s.ToCharArray() | Where-Object { $_ -eq '}' }).Count
    $diffs += ($open - $close)
}
$lastPos = -1
for($i=$diffs.Count-1; $i -ge 0; $i--){ if($diffs[$i] -gt 0){ $lastPos = $i; break } }
if($lastPos -eq -1){ Write-Output "No positive diff found"; exit }
$ln = $lastPos + 1
Write-Output "LAST_POS line=$ln diff=$($diffs[$lastPos])"
$start = [Math]::Max(1, $ln - 12)
$end = [Math]::Min($lines.Count, $ln + 12)
for($j=$start; $j -le $end; $j++){
    $num = $j.ToString().PadLeft(4,' ')
    Write-Output ("{0}: {1}" -f $num, $lines[$j-1])
}
