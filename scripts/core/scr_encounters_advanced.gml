/// @file scr_encounters_advanced.gml
/// Encounter sets keyed by id; surface + time bucket tables

globalvar ENCOUNTER_SETS;
if (!variable_global_exists("ENCOUNTER_SETS")) ENCOUNTER_SETS = ds_map_create();

function encounter_define_set(_id, _struct) { ds_map_replace(ENCOUNTER_SETS, _id, _struct); }
function encounter_get_set(_id) { return ENCOUNTER_SETS[? _id]; }

function encounter_weighted_pick(_table) {
    var n = array_length(_table); if (n <= 0) return undefined;
    var total = 0; for (var i = 0; i < n; i++) total += _table[i].weight;
    var roll = irandom_range(1, max(1, total));
    var acc = 0;
    for (var j = 0; j < n; j++) { acc += _table[j].weight; if (roll <= acc) return _table[j]; }
    return _table[0];
}

function encounter_roll_zone(_surface) {
    var z = zone_active();
    var set = encounter_get_set(z.enc_set_id);
    if (is_undefined(set)) return undefined;

    var bucket = time_get_bucket();
    var surf_tbl = set[_surface];
    if (is_undefined(surf_tbl)) return undefined;

    var time_tbl = surf_tbl[? bucket];
    if (is_undefined(time_tbl)) time_tbl = surf_tbl[? "Any"];
    if (is_undefined(time_tbl)) return undefined;

    return encounter_weighted_pick(time_tbl);
}
