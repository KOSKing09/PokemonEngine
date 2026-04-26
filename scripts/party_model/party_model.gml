// Party model: data-only helpers for party manipulation and queries.
// Keep this file free of UI, drawing, or input state.

// Return the mons array for a player id, or an empty array when missing.
// Params: _pid (int)
// Returns: array of mon structs (may be empty)
function party_model_get_mons(_pid){
    if (variable_global_exists("PARTY") && is_array(global.PARTY) && array_length(global.PARTY) > _pid){
        var _p = global.PARTY[_pid];
        if (is_struct(_p) && variable_struct_exists(_p,"mons") && is_array(_p.mons)) return _p.mons;
    }
    return [];
}

// Safe accessor: return mon struct at `_index` for `_pid`, or undefined.
// Params: _pid (int), _index (int)
// Returns: mon struct or undefined
function party_model_get_mon(_pid, _index){
    var _mons = party_model_get_mons(_pid);
    if (!is_array(_mons)) return undefined;
    if (_index < 0 || _index >= array_length(_mons)) return undefined;
    return _mons[_index];
}

// Add a mon to the end of the specified player's party.
// Normalizes HP fields and ensures party container exists.
// Returns: new index (int) or -1 on failure.
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
    // Normalize HP fields to avoid hp_max < current HP issues
    if (is_struct(_mon)){
        var cur_hp = 0;
        if (variable_struct_exists(_mon, "hp_now") && is_real(variable_struct_get(_mon, "hp_now"))) cur_hp = variable_struct_get(_mon, "hp_now");
        else if (variable_struct_exists(_mon, "hp") && is_real(variable_struct_get(_mon, "hp"))) cur_hp = variable_struct_get(_mon, "hp");
        var cur_max = undefined;
        if (variable_struct_exists(_mon, "hp_max") && is_real(variable_struct_get(_mon, "hp_max"))) cur_max = variable_struct_get(_mon, "hp_max");
        else if (variable_struct_exists(_mon, "maxhp") && is_real(variable_struct_get(_mon, "maxhp"))) cur_max = variable_struct_get(_mon, "maxhp");
        var final_max = max(1, max(cur_hp, (is_real(cur_max) ? cur_max : 0)));
        variable_struct_set(_mon, "hp_max", final_max);
        variable_struct_set(_mon, "maxhp", final_max);
        // Ensure canonical current hp fields exist
        if (!variable_struct_exists(_mon, "hp_now") && variable_struct_exists(_mon, "hp")) variable_struct_set(_mon, "hp_now", variable_struct_get(_mon, "hp"));
        if (!variable_struct_exists(_mon, "hp") && variable_struct_exists(_mon, "hp_now")) variable_struct_set(_mon, "hp", variable_struct_get(_mon, "hp_now"));
    }
    array_push(_mons, _mon);
    // ensure global.PARTY updated below
    _P.mons = _mons;
    global.PARTY[_pid] = _P;
    return array_length(_mons) - 1;
}

// Remove a mon at `_index` from player's party. Returns true on success.
// Params: _pid (int), _index (int)
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

// Swap two party slots by index. Returns true when swap succeeds.
// Preserves struct references to avoid breaking external refs.
function party_model_swap(_pid, _i, _j){
    var _mons = party_model_get_mons(_pid);
    if (!is_array(_mons)) return false;
    var _n = array_length(_mons);
    if (_i < 0 || _i >= _n || _j < 0 || _j >= _n) return false;
    var _t = _mons[_i]; _mons[_i] = _mons[_j]; _mons[_j] = _t;
    var _P = global.PARTY[_pid]; _P.mons = _mons; global.PARTY[_pid] = _P;
    return true;
}

// Find the next alive (hp > 0) party index after `_startIndex`.
// Returns index (int) or -1 if none found.
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

// Ensure `ot` (original trainer name) and `idno` exist on `_mon`.
// Mutates `_mon` in-place and returns it.
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

// Shallow-copy a mon struct into a new struct to avoid shared references.
// Returns a new struct or the original value if not a struct.
function party_model_copy_mon(_mon){
    if (!is_struct(_mon)) return _mon;
    var out = {};
    var k = variable_struct_get_names(_mon);
    for (var i=0; i<array_length(k); i++){
        var key = k[i];
        var val = undefined;
        if (variable_struct_exists(_mon, key)) val = variable_struct_get(_mon, key);
        variable_struct_set(out, key, val);
    }
    return out;
}

// Update or replace a mon struct at `_index` in the given player's party.
// Preserves existing slot object where possible (in-place field copy).
// Performs defensive normalization (hp_max >= current hp).
// Returns: true on success, false on failure.
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
                    // Debug: log changes to the shiny flag for tracing
                    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG && __k == "shiny"){
                        var __prev = (variable_struct_exists(__old, "shiny") ? string(variable_struct_get(__old, "shiny")) : "<none>");
                        var __next = string(__val);
                        show_debug_message("[party_model_update_mon][SHINY] pid=" + string(_pid) + ", slot=" + string(_index) + ", prev=" + __prev + ", next=" + __next);
                    }
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
    // Defensive normalization: ensure hp_max >= current hp for this slot
    if (_index >= 0 && _index < array_length(_mons) && is_struct(_mons[_index])){
        var __m = _mons[_index];
        var __cur = 0;
        if (variable_struct_exists(__m, "hp_now") && is_real(variable_struct_get(__m, "hp_now"))) __cur = variable_struct_get(__m, "hp_now");
        else if (variable_struct_exists(__m, "hp") && is_real(variable_struct_get(__m, "hp"))) __cur = variable_struct_get(__m, "hp");
        var __mx = undefined;
        if (variable_struct_exists(__m, "hp_max") && is_real(variable_struct_get(__m, "hp_max"))) __mx = variable_struct_get(__m, "hp_max");
        else if (variable_struct_exists(__m, "maxhp") && is_real(variable_struct_get(__m, "maxhp"))) __mx = variable_struct_get(__m, "maxhp");
        var __final = max(1, max(__cur, (is_real(__mx) ? __mx : 0)));
        variable_struct_set(__m, "hp_max", __final);
        variable_struct_set(__m, "maxhp", __final);
        if (!variable_struct_exists(__m, "hp_now") && variable_struct_exists(__m, "hp")) variable_struct_set(__m, "hp_now", variable_struct_get(__m, "hp"));
        if (!variable_struct_exists(__m, "hp") && variable_struct_exists(__m, "hp_now")) variable_struct_set(__m, "hp", variable_struct_get(__m, "hp_now"));
        _mons[_index] = __m;
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

// Move fainted mons (hp <= 0) to the end of the party array preserving order.
// Returns true if the party ordering changed.
function party_model_reorder_fainted_to_bottom(_pid){
    var _mons = party_model_get_mons(_pid);
    if (!is_array(_mons)) return false;
    var _alive = [];
    var _fainted = [];
    var changed = false;
    for (var i = 0; i < array_length(_mons); i++){
        var m = _mons[i];
        var hp = 1;
        if (is_struct(m)){
            if (variable_struct_exists(m, "hp")) hp = m.hp;
            else if (variable_struct_exists(m, "HP")) hp = m.HP;
        }
        if (is_real(hp) && hp <= 0) array_push(_fainted, m);
        else array_push(_alive, m);
    }
    if (array_length(_fainted) > 0){
        var _new = array_create(0);
        for (var ai = 0; ai < array_length(_alive); ai++) array_push(_new, _alive[ai]);
        for (var fi = 0; fi < array_length(_fainted); fi++) array_push(_new, _fainted[fi]);
        // Check whether ordering changed
        if (array_length(_new) == array_length(_mons)){
            for (var k = 0; k < array_length(_new); k++){
                if (_new[k] != _mons[k]){ changed = true; break; }
            }
        } else changed = true;
        if (changed){
            var _P = global.PARTY[_pid]; _P.mons = _new; global.PARTY[_pid] = _P;
            return true;
        }
    }
    return false;
}
