$p='c:\Users\trane\GameMakerProjects\PokemonEngine\scripts\party_input\party_input.gml'
$lines=Get-Content -LiteralPath $p
$open=0; $close=0; $found=$false
for($i=0; $i -lt $lines.Count; $i++){
    $s = $lines[$i]
    $open += ($s.ToCharArray() | Where-Object { $_ -eq '{' }).Count
    $close += ($s.ToCharArray() | Where-Object { $_ -eq '}' }).Count
    if(-not $found -and $close -gt $open){
        Write-Output "FIRST_CLOSE_GT_OPEN at line $($i+1): open=$open close=$close"
        $found = $true
    }
}
Write-Output "FINAL_COUNTS open=$open close=$close"
if(-not $found){
    if($open -ne $close){ Write-Output "NO_EARLY_CLOSE_BUT_UNBALANCED final_diff=$($open-$close)" } else { Write-Output "BRACES_BALANCED" }
}
