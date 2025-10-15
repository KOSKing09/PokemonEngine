// Move learn helper
// Attempts to teach _move_id to _mon. Returns { status:"learned"|"skipped"|"need_replace", slot: <index or -1> }
// Optional third parameter _preferred_slot (0..3) will attempt inserting there if available.
function scr_move_learn_try(_mon, _move_id, _preferred_slot){
    // Validate inputs
    if (!is_struct(_mon)) return { status:"skipped", slot:-1 };
    if (!is_real(_move_id) || _move_id <= 0) return { status:"skipped", slot:-1 };

    // Ensure moves array exists and normalize placeholder values
    if (!variable_struct_exists(_mon, "moves") || !is_array(_mon.moves)) _mon.moves = [];
    var _mv = _mon.moves;

    // Duplicate check: if already known, return skipped with slot index
    for (var i = 0; i < array_length(_mv); i++){
        if (_mv[i] == _move_id) return { status:"skipped", slot:i };
    }

    // Normalize preferred slot
    var _pref = -1;
    if (is_real(_preferred_slot)) _pref = clamp(_preferred_slot, 0, 3);

    // First try: if preferred slot provided and empty/placeholder, insert there
    if (_pref >= 0){
        // pad with placeholders if needed
        while (array_length(_mv) < _pref) array_push(_mv, -1);
        if (array_length(_mv) == _pref){
            array_push(_mv, _move_id);
            _mon.moves = _mv;
            return { status:"learned", slot:_pref };
        } else {
            // slot exists: accept if it's a placeholder (<= 0)
            if (!is_real(_mv[_pref]) || _mv[_pref] <= 0){
                _mv[_pref] = _move_id;
                _mon.moves = _mv;
                return { status:"learned", slot:_pref };
            }
        }
    }

    // Second try: find first placeholder slot (-1 or <=0)
    for (var j = 0; j < array_length(_mv); j++){
        if (!is_real(_mv[j]) || _mv[j] <= 0){
            _mv[j] = _move_id;
            _mon.moves = _mv;
            return { status:"learned", slot:j };
        }
    }

    // Third try: if less than 4 moves, append
    if (array_length(_mv) < 4){
        array_push(_mv, _move_id);
        _mon.moves = _mv;
        return { status:"learned", slot: array_length(_mv) - 1 };
    }

    // Otherwise, party code should trigger replace flow
    return { status:"need_replace", slot:-1 };
}
