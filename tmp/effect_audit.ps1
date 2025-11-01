$prose = Import-Csv "datafiles/data/csv/move_effect_prose.csv"
$moves = Import-Csv "datafiles/data/csv/moves.csv"
$meta = Import-Csv "datafiles/data/csv/move_meta_stat_changes.csv"

$all = $prose | ForEach-Object { [int]$_.move_effect_id } | Sort-Object -Unique

# Explicit effect_ids found in code (hardcoded from grep results)
$explicit = @(340,351,280,392,367,369,352,353,419)

# Map move_id -> effect_id for moves referenced by meta stat changes
$meta_move_ids = $meta | ForEach-Object { [int]$_.move_id } | Sort-Object -Unique
$effect_ids_from_meta = @()
foreach ($mid in $meta_move_ids) {
    $m = $moves | Where-Object { [int]$_.id -eq $mid }
    if ($m -and $m.effect_id -ne $null -and $m.effect_id -ne '') { $effect_ids_from_meta += [int]$m.effect_id }
}
$effect_ids_from_meta = $effect_ids_from_meta | Sort-Object -Unique

Write-Output "=== Effect ID Audit ==="
Write-Output "Total effect_ids in prose: $($all.Count)"
Write-Output ""
Write-Output "Explicitly implemented effect_ids (from code grep):"
$explicit | ForEach-Object { Write-Output "- $_" }
Write-Output ""
Write-Output "Effect IDs covered by stat_changes (via move_meta_stat_changes -> moves.csv):"
$effect_ids_from_meta | ForEach-Object { Write-Output "- $_" }
Write-Output ""
$missing = $all | Where-Object { $explicit -notcontains $_ -and $effect_ids_from_meta -notcontains $_ }
Write-Output "Missing / unimplemented effect_ids (count: $($missing.Count)) (first 200 shown):"
$missing | Select-Object -First 200 | ForEach-Object { Write-Output "- $_" }

# Produce CSV mapping effect_id,status
$out = @()
foreach ($eid in $all) {
    $status = if ($explicit -contains $eid) { 'explicit' } elseif ($effect_ids_from_meta -contains $eid) { 'covered_by_stat_changes' } else { 'missing' }
    $loc = ''
    if ($status -eq 'explicit') { $loc = 'scripts/battle_system/battle_system.gml (lines ~580-660) and scripts/battle_moves_impls/battle_moves_impls.gml (meta-moves)' }
    $out += [pscustomobject]@{ effect_id = $eid; status = $status; location = $loc }
}

$out | Export-Csv -NoTypeInformation -Path "tmp/effect_id_audit_report.csv"
Write-Output "\nWrote report to tmp/effect_id_audit_report.csv"

Write-Output "Done."