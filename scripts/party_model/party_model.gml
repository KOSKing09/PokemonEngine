// Party model: data-only helpers for party manipulation and queries.
// Keep this file free of UI, drawing, or input state.

function party_model_resolve_species_id(_mon){
    if (!is_struct(_mon)) return -1;

    if (variable_struct_exists(_mon, "species_id") && is_real(variable_struct_get(_mon, "species_id"))) return floor(variable_struct_get(_mon, "species_id"));
    if (variable_struct_exists(_mon, "id") && is_real(variable_struct_get(_mon, "id"))) return floor(variable_struct_get(_mon, "id"));
    if (variable_struct_exists(_mon, "species") && is_real(variable_struct_get(_mon, "species"))) return floor(variable_struct_get(_mon, "species"));

    var _probe_name = "";
    if (variable_struct_exists(_mon, "species") && is_string(variable_struct_get(_mon, "species"))) _probe_name = string_lower(string_trim(variable_struct_get(_mon, "species")));
    else if (variable_struct_exists(_mon, "name") && is_string(variable_struct_get(_mon, "name"))) _probe_name = string_lower(string_trim(variable_struct_get(_mon, "name")));

    if (string_length(_probe_name) <= 0) return -1;
    if (!(variable_global_exists("_pokemon") && is_array(global._pokemon))) return -1;

    for (var _sid = 0; _sid < array_length(global._pokemon); ++_sid){
        var _entry = global._pokemon[_sid];
        if (!is_struct(_entry) || !variable_struct_exists(_entry, "name")) continue;
        var _entry_name = string_lower(string_trim(string(variable_struct_get(_entry, "name"))));
        if (_entry_name == _probe_name) return _sid;
    }

    return -1;
}

function party_model_ensure_species_id(_mon){
    if (!is_struct(_mon)) return _mon;

    var _sid = party_model_resolve_species_id(_mon);
    if (_sid < 0) return _mon;

    variable_struct_set(_mon, "species_id", _sid);
    if (!variable_struct_exists(_mon, "id") || !is_real(variable_struct_get(_mon, "id"))) variable_struct_set(_mon, "id", _sid);
    if (!variable_struct_exists(_mon, "species") || !is_real(variable_struct_get(_mon, "species"))) variable_struct_set(_mon, "species", _sid);

    return _mon;
}

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
        _mon = party_model_ensure_species_id(_mon);
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

// Party capacity is currently fixed to the mainline six-slot team limit.
// Keep this helper as the single source of truth so catch routing and UI stay aligned.
function party_model_get_party_capacity(){
    return 6;
}

// Minimal PC storage backing for caught Pokemon when the party is full.
// This is intentionally data-only so a future PC UI/system can adopt the same
// global shape or migrate it in one place without battle code changes.
function party_model_pc_ensure(_pid){
    if (!variable_global_exists("PC_STORAGE")) global.PC_STORAGE = [];
    if (!is_array(global.PC_STORAGE)) global.PC_STORAGE = [];
    if (_pid < 0) _pid = 0;
    if (array_length(global.PC_STORAGE) <= _pid) array_resize(global.PC_STORAGE, _pid + 1);

    var _pc = global.PC_STORAGE[_pid];
    if (!is_struct(_pc)) _pc = { box_capacity:30, boxes:[] };
    if (!variable_struct_exists(_pc, "box_capacity") || !is_real(_pc.box_capacity) || _pc.box_capacity <= 0) _pc.box_capacity = 30;
    if (!variable_struct_exists(_pc, "boxes") || !is_array(_pc.boxes)) _pc.boxes = [];
    if (array_length(_pc.boxes) <= 0) array_push(_pc.boxes, { name:"Box 1", mons:[] });

    global.PC_STORAGE[_pid] = _pc;
    return _pc;
}

// Store a caught mon in the active party when space exists, otherwise into the
// minimal PC backing store. Callers should use this instead of open-coding the
// 6-slot check so battle, future catch flows, and a later PC UI share one path.
function party_model_store_caught_mon(_pid, _mon){
    if (!is_struct(_mon)) return { ok:false, location:"none", mon:undefined };

    var _stored = party_model_copy_mon(_mon);
    if (!variable_struct_exists(_stored, "pokeball_item_id") || !is_real(variable_struct_get(_stored, "pokeball_item_id")) || variable_struct_get(_stored, "pokeball_item_id") <= 0){
        variable_struct_set(_stored, "pokeball_item_id", 4);
    }

    var _party = party_model_get_mons(_pid);
    var _party_count = array_length(_party);
    var _party_cap = party_model_get_party_capacity();
    if (_party_count < _party_cap){
        party_model_ensure_ot_idno(_stored, _pid, _party_count);
        var _slot = party_model_add_mon(_pid, _stored);
        return { ok:(_slot >= 0), location:"party", slot_index:_slot, mon:_stored };
    }

    var _pc = party_model_pc_ensure(_pid);
    var _boxes = variable_struct_get(_pc, "boxes");
    var _box_cap = max(1, floor(variable_struct_get(_pc, "box_capacity")));
    var _target_box = -1;
    var _target_slot = -1;

    for (var _bi = 0; _bi < array_length(_boxes); _bi++){
        var _box = _boxes[_bi];
        if (!is_struct(_box)) _box = { name:"Box " + string(_bi + 1), mons:[] };
        if (!variable_struct_exists(_box, "name")) _box.name = "Box " + string(_bi + 1);
        if (!variable_struct_exists(_box, "mons") || !is_array(_box.mons)) _box.mons = [];
        _boxes[_bi] = _box;
        if (array_length(_box.mons) < _box_cap){
            _target_box = _bi;
            _target_slot = array_length(_box.mons);
            break;
        }
    }

    if (_target_box < 0){
        _target_box = array_length(_boxes);
        _target_slot = 0;
        array_push(_boxes, { name:"Box " + string(_target_box + 1), mons:[] });
    }

    var _store_key = _party_cap + (_target_box * _box_cap) + _target_slot;
    party_model_ensure_ot_idno(_stored, _pid, _store_key);
    var _dst_box = _boxes[_target_box];
    array_push(_dst_box.mons, _stored);
    _boxes[_target_box] = _dst_box;
    _pc.boxes = _boxes;
    global.PC_STORAGE[_pid] = _pc;
    return { ok:true, location:"pc", box_index:_target_box, slot_index:_target_slot, mon:_stored };
}

function party_model_set_stored_mon_nickname(_pid, _store_info, _nick){
    if (!is_struct(_store_info) || !variable_struct_exists(_store_info, "location")) return false;
    var _location = string(variable_struct_get(_store_info, "location"));
    if (_location == "party"){
        if (!variable_struct_exists(_store_info, "slot_index") || !is_real(variable_struct_get(_store_info, "slot_index"))) return false;
        return party_set_nickname(_pid, floor(variable_struct_get(_store_info, "slot_index")), _nick);
    }
    if (_location != "pc") return false;

    if (!variable_struct_exists(_store_info, "box_index") || !is_real(variable_struct_get(_store_info, "box_index"))) return false;
    if (!variable_struct_exists(_store_info, "slot_index") || !is_real(variable_struct_get(_store_info, "slot_index"))) return false;
    var _pc = party_model_pc_ensure(_pid);
    var _box_index = floor(variable_struct_get(_store_info, "box_index"));
    var _slot_index = floor(variable_struct_get(_store_info, "slot_index"));
    var _boxes = variable_struct_get(_pc, "boxes");
    if (_box_index < 0 || _box_index >= array_length(_boxes)) return false;
    var _box = _boxes[_box_index];
    if (!is_struct(_box) || !variable_struct_exists(_box, "mons") || !is_array(variable_struct_get(_box, "mons"))) return false;
    var _mons = variable_struct_get(_box, "mons");
    if (_slot_index < 0 || _slot_index >= array_length(_mons)) return false;
    var _mon = _mons[_slot_index];
    if (!is_struct(_mon)) return false;
    if (!is_undefined(party_mon_ensure_name)) _mon = party_mon_ensure_name(_mon);
    if (is_string(_nick) && string_length(string_trim(_nick)) > 0) variable_struct_set(_mon, "nickname", string_trim(_nick));
    else variable_struct_set(_mon, "nickname", undefined);
    _mons[_slot_index] = _mon;
    variable_struct_set(_box, "mons", _mons);
    _boxes[_box_index] = _box;
    variable_struct_set(_pc, "boxes", _boxes);
    global.PC_STORAGE[_pid] = _pc;
    if (variable_struct_exists(_store_info, "mon") && is_struct(variable_struct_get(_store_info, "mon"))){
        var _store_mon = variable_struct_get(_store_info, "mon");
        if (is_string(_nick) && string_length(string_trim(_nick)) > 0) variable_struct_set(_store_mon, "nickname", string_trim(_nick));
        else variable_struct_set(_store_mon, "nickname", undefined);
        variable_struct_set(_store_info, "mon", _store_mon);
    }
    return true;
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
