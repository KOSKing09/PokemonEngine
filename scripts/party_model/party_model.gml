// Party model: data-only helpers for party manipulation and queries.
// Keep this file free of UI, drawing, or input state.

// Return the mons array for a pid, or empty array
function party_model_get_mons(_pid){
    if (variable_global_exists("PARTY") && is_array(global.PARTY) && array_length(global.PARTY) > _pid){
        var _p = global.PARTY[_pid];
        if (is_struct(_p) && variable_struct_exists(_p,"mons") && is_array(_p.mons)) return _p.mons;
    }
    return [];
}

// Safe accessor: get mon struct at index (returns undefined if missing)
function party_model_get_mon(_pid, _index){
    var _mons = party_model_get_mons(_pid);
    if (!is_array(_mons)) return undefined;
    if (_index < 0 || _index >= array_length(_mons)) return undefined;
    return _mons[_index];
}

// Add a mon to the end of the party. Returns new index or -1 on failure
function party_model_add_mon(_pid, _mon){
    if (is_undefined(_mon)) return -1;
    if (!variable_global_exists("PARTY")) global.PARTY = [];
    if (!is_array(global.PARTY)) global.PARTY = [];
    if (array_length(global.PARTY) <= _pid) array_resize(global.PARTY, _pid + 1);
    var _P = global.PARTY[_pid];
    if (!is_struct(_P)){
        _P = { open:false, mode:"list", sel:0, scroll:0, menu_sel:0, swap_index:-1, lock:0, mons:[], sum_move_sel:0, sum_learn_sel:0 };
        global.PARTY[_pid] = _P;
    }
    if (!variable_struct_exists(_P,"mons") || !is_array(_P.mons)) _P.mons = [];
    var _mons = _P.mons;
    array_push(_mons, _mon);
    _P.mons = _mons;
    global.PARTY[_pid] = _P;
    return array_length(_mons) - 1;
}

// Remove a mon by index. Returns true if removed.
function party_model_remove_mon(_pid, _index){
    var _mons = party_model_get_mons(_pid);
    if (!is_array(_mons)) return false;
    var _n = array_length(_mons);
    if (_index < 0 || _index >= _n) return false;
    for (var i = _index; i < _n - 1; i++) _mons[i] = _mons[i+1];
    array_resize(_mons, _n - 1);
    var _P = global.PARTY[_pid]; _P.mons = _mons; global.PARTY[_pid] = _P;
    return true;
}

// Swap two indices. Returns true if successful.
function party_model_swap(_pid, _i, _j){
    var _mons = party_model_get_mons(_pid);
    if (!is_array(_mons)) return false;
    var _n = array_length(_mons);
    if (_i < 0 || _i >= _n || _j < 0 || _j >= _n) return false;
    var _t = _mons[_i]; _mons[_i] = _mons[_j]; _mons[_j] = _t;
    var _P = global.PARTY[_pid]; _P.mons = _mons; global.PARTY[_pid] = _P;
    return true;
}

// Find next alive (hp > 0) starting after startIndex. Returns index or -1.
function party_model_find_next_alive(_pid, _startIndex){
    var _mons = party_model_get_mons(_pid);
    var _n = array_length(_mons);
    if (_n <= 0) return -1;
    var s = _startIndex + 1;
    for (var i = 0; i < _n; i++){
        var idx = (s + i) mod _n;
        var m = _mons[idx];
        if (is_struct(m)){
            var hp = 0; if (variable_struct_exists(m,"hp")) hp = m.hp; else if (variable_struct_exists(m,"HP")) hp = m.HP;
            if (is_real(hp) && hp > 0) return idx;
        }
    }
    return -1;
}

// Ensure OT/idno on a mon (mutates). Returns mon.
function party_model_ensure_ot_idno(_mon, _pid, _slot){
    if (!is_struct(_mon)) return _mon;
    if (!variable_struct_exists(_mon, "ot")){
        var __otName = "YOU";
        if (variable_global_exists("PLAYER_NAME")) __otName = string(global.PLAYER_NAME);
        if (_pid == 1 && variable_global_exists("PLAYER2_NAME")) __otName = string(global.PLAYER2_NAME);
        _mon.ot = __otName;
    }
    if (!variable_struct_exists(_mon, "idno")){
        var __sid_seed = -1;
        if (variable_struct_exists(_mon,"species_id")) __sid_seed = _mon.species_id;
        else if (variable_struct_exists(_mon,"_id")) __sid_seed = _mon._id;
        if (!is_real(__sid_seed) || __sid_seed < 0) __sid_seed = (_slot * 17) + (_pid * 101);
        var __raw = ( (__sid_seed * 7919) + (_slot * 271) + (_pid * 997) ) mod 90000;
        _mon.idno = 10000 + __raw;
    }
    return _mon;
}

// Helper: shallow copy a mon struct (to avoid accidental shared refs)
function party_model_copy_mon(_mon){
    if (!is_struct(_mon)) return _mon;
    var out = {};
    var k = variable_struct_get_names(_mon);
    for (var i=0; i<array_length(k); i++) out[k[i]] = _mon[k[i]];
    return out;
}

// Update/replace a mon struct at index in the party. Ensures the party
// container exists and writes the struct back in a single place.
// Returns true on success, false on failure.
function party_model_update_mon(_pid, _index, _mon){
    if (!is_struct(_mon)) return false;
    if (!variable_global_exists("PARTY")) global.PARTY = [];
    if (!is_array(global.PARTY)) global.PARTY = [];
    if (_pid < 0) return false;
    if (array_length(global.PARTY) <= _pid) array_resize(global.PARTY, _pid + 1);
    var _P = global.PARTY[_pid];
    if (!is_struct(_P)){
        _P = { open:false, mode:"list", sel:0, scroll:0, menu_sel:0, swap_index:-1, lock:0, mons:[], sum_move_sel:0, sum_learn_sel:0 };
        global.PARTY[_pid] = _P;
    }
    if (!variable_struct_exists(_P, "mons") || !is_array(_P.mons)) _P.mons = [];
    var _mons = _P.mons;
    if (!is_real(_index) || _index < 0) return false;
    if (_index >= array_length(_mons)) array_resize(_mons, _index + 1);
    // If an existing mon struct is present at this slot, prefer updating it in-place
    // so other references (for example, battle actor.mon or UI copies) remain valid.
    if (_index < array_length(_mons) && is_struct(_mons[_index])){
        var __old = _mons[_index];
        // Copy fields from provided _mon into the existing struct
        if (is_struct(__old) && is_struct(_mon)){
                var __keys = variable_struct_get_names(_mon);
                for (var __ik = 0; __ik < array_length(__keys); __ik++){
                    var __k = __keys[__ik];
                    var __val = undefined;
                    if (variable_struct_exists(_mon, __k)) __val = variable_struct_get(_mon, __k);
                    variable_struct_set(__old, __k, __val);
                }
            // Ensure the slot holds the same (mutated) object reference
            _mons[_index] = __old;
        } else {
            // Fallback: replace entirely
            _mons[_index] = _mon;
        }
    } else {
        _mons[_index] = _mon;
    }
    _P.mons = _mons;
    global.PARTY[_pid] = _P;
    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){
        // Try to show a concise snapshot of the mon's moves for debugging
        var mvtxt = "";
        if (variable_struct_exists(_mon, "moves")){
            var __mv_arr = variable_struct_get(_mon, "moves");
            if (is_array(__mv_arr)){
                for (var _mi=0; _mi<array_length(__mv_arr); _mi++) mvtxt += string(__mv_arr[_mi]) + ( _mi < array_length(__mv_arr)-1 ? "," : "");
            }
        }
        show_debug_message("[party_model_update_mon] pid=" + string(_pid) + ", slot=" + string(_index) + ", moves=[" + mvtxt + "]");
    }
    return true;
}
