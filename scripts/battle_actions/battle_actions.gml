// Battle action helpers (extracted from battle_system.gml)

function __battle_consume_pp(_A, _move_slot){
    if (!is_struct(_A)) return false;
    if (!is_array(_A.pps)) return false;
    if (!is_real(_move_slot) || _move_slot < 0 || _move_slot >= array_length(_A.pps)) return false;
    var cur = _A.pps[_move_slot];
    if (!is_real(cur) || cur <= 0) return false;
    _A.pps[_move_slot] = max(0, cur - 1);
    return true;
}

function __battle_roll_hit(_move_id){
    var acc = __battle_move_accuracy(_move_id);
    return (irandom(99) < clamp(floor(acc), 0, 100));
}

// Applies damage and returns [dmg, beforeHP, afterHP]
function __battle_apply_move_damage(_pid, _target_index, _A, _D, _move_id, _mv_power){
    var dmg = __battle_calc_damage(_A, _D, _move_id, _mv_power);
    var before = _D.hp_now;
    __battle_apply_damage(_pid, _target_index, dmg);
    var after = _D.hp_now;
    return [dmg, before, after];
}
