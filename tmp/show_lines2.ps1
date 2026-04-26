$p='c:\Users\trane\GameMakerProjects\PokemonEngine\scripts\party_input\party_input.gml'
$lines=Get-Content -LiteralPath $p
$targets=@(725,761,924)
foreach($ln in $targets){
  $text=$lines[$ln-1]
  Write-Output ("{0}: {1}" -f $ln, $text)
}
