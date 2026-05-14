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

    var _stored = party_model_copy_caught_mon(_mon);
    if (!is_struct(_stored)) return { ok:false, location:"none", mon:undefined };

    _stored = party_model__copy_capture_move_fields(_stored, party_model__find_capture_mon_source(_mon), true);
    _stored = party_model__copy_capture_move_fields(_stored, _mon, false);

    if (!variable_struct_exists(_stored, "pokeball_item_id") || !is_real(variable_struct_get(_stored, "pokeball_item_id")) || variable_struct_get(_stored, "pokeball_item_id") <= 0){
        variable_struct_set(_stored, "pokeball_item_id", 4);
    }

    var _party = party_model_get_mons(_pid);
    var _party_count = array_length(_party);
    var _party_cap = party_model_get_party_capacity();

    if (_party_count < _party_cap){
        party_model_ensure_ot_idno(_stored, _pid, _party_count);

        // Preserve moves after OT/ID assignment too.
        _stored = party_model__copy_capture_move_fields(_stored, party_model__find_capture_mon_source(_mon), true);
        _stored = party_model__copy_capture_move_fields(_stored, _mon, false);

        var _slot = party_model_add_mon(_pid, _stored);
        _stored = party_model_assign_level_moves_if_missing(_stored);

        return { ok:(_slot >= 0), location:"party", slot_index:_slot, mon:_stored };
    }

    if (!is_undefined(pc_store_mon_to_box_info)){
        var _pc_info = pc_store_mon_to_box_info(_pid, _stored);
        if (is_struct(_pc_info) && variable_struct_exists(_pc_info, "ok") && _pc_info.ok == true){
            return _pc_info;
        }
    }

    if (!is_undefined(pc_store_mon_to_box)){
        var _pc_ok = pc_store_mon_to_box(_pid, _stored);
        if (_pc_ok){
            return { ok:true, location:"pc", box_index:0, slot_index:-1, mon:_stored };
        }
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

    _stored = party_model__copy_capture_move_fields(_stored, party_model__find_capture_mon_source(_mon), true);
    _stored = party_model__copy_capture_move_fields(_stored, _mon, false);

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

    var _box_index = floor(variable_struct_get(_store_info, "box_index"));
    var _slot_index = floor(variable_struct_get(_store_info, "slot_index"));

    if (_slot_index >= 0 && !is_undefined(pc_set_stored_mon_nickname)){
        var _pc_nick_ok = pc_set_stored_mon_nickname(_pid, _box_index, _slot_index, _nick);
        if (_pc_nick_ok){
            if (variable_struct_exists(_store_info, "mon") && is_struct(variable_struct_get(_store_info, "mon"))){
                var _store_mon = variable_struct_get(_store_info, "mon");
                if (is_string(_nick) && string_length(string_trim(_nick)) > 0) variable_struct_set(_store_mon, "nickname", string_trim(_nick));
                else variable_struct_set(_store_mon, "nickname", undefined);
                variable_struct_set(_store_info, "mon", _store_mon);
            }
            return true;
        }
    }

    var _pc = party_model_pc_ensure(_pid);
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

function party_model_copy_caught_mon(_source){
    if (!is_struct(_source)) return undefined;

    // Correct capture behavior:
    // find the exact full Pokemon object made for the wild encounter, copy that,
    // and only then apply capture metadata. This preserves learnset/moves/PP/stats.
    var _exact = party_model__find_exact_capture_mon_source(_source);
    if (is_struct(_exact)){
        var _out_exact = party_model__copy_full_capture_mon(_exact);

        // Capture wrapper may carry ball/item metadata, but should not replace full mon data.
        _out_exact = party_model__copy_capture_identity_fields(_out_exact, _source, false);
        _out_exact = party_model__copy_capture_move_fields(_out_exact, _source, false);

        _out_exact = party_model_attach_capture_learnset(_out_exact);
        _out_exact = party_model_assign_level_moves_if_missing(_out_exact);
        if (!is_undefined(party_model_ensure_species_id)) _out_exact = party_model_ensure_species_id(_out_exact);
        if (!is_undefined(party_mon_ensure_name)) _out_exact = party_mon_ensure_name(_out_exact);

        return _out_exact;
    }

    // Fallback for old/incomplete wrappers only.
    var _base = party_model__find_capture_mon_source(_source);
    if (!is_struct(_base)) _base = _source;

    var _out = party_model_copy_mon(_base);

    _out = party_model__copy_capture_identity_fields(_out, _base, true);
    _out = party_model__copy_capture_move_fields(_out, _base, true);

    if (_source != _base){
        _out = party_model__copy_capture_identity_fields(_out, _source, false);
        _out = party_model__copy_capture_move_fields(_out, _source, false);
    }

    _out = party_model_attach_capture_learnset(_out);
    _out = party_model_assign_level_moves_if_missing(_out);
    if (!is_undefined(party_model_ensure_species_id)) _out = party_model_ensure_species_id(_out);
    if (!is_undefined(party_mon_ensure_name)) _out = party_mon_ensure_name(_out);

    _out = party_model__copy_capture_move_fields(_out, _base, true);
    if (_source != _base) _out = party_model__copy_capture_move_fields(_out, _source, false);
    _out = party_model_attach_capture_learnset(_out);
    _out = party_model_assign_level_moves_if_missing(_out);

    return _out;
}

function party_model__copy_known_capture_fields(_dst, _src){
    if (!is_struct(_dst) || !is_struct(_src)) return _dst;

    var _keys = ["moves","move_ids","move_slots","current_moves","pp","pp_now","pp_max","nickname","name","species_id","species","id","level","lvl","hp","hp_now","hp_max","maxhp","ability","ability_id","nature","gender","shiny","exp","held_item","item"];
    for (var _i = 0; _i < array_length(_keys); ++_i){
        var _k = _keys[_i];
        if (variable_struct_exists(_src, _k)){
            variable_struct_set(_dst, _k, variable_struct_get(_src, _k));
        }
    }

    return _dst;
}

function party_model__capture_move_field_names(){
    return [
        "moves",
        "move_ids",
        "move_slots",
        "current_moves",
        "known_moves",
        "learned_moves",
        "battle_moves",
        "move_list",
        "pp",
        "pps",
        "pp_now",
        "pp_max",
        "move_pp",
        "move_pp_now",
        "move_pp_max"
    ];
}

function party_model__copy_capture_move_fields(_dst, _src, _force){
    if (!is_struct(_dst) || !is_struct(_src)) return _dst;

    var _move_keys = party_model__capture_move_field_names();
    for (var _i = 0; _i < array_length(_move_keys); ++_i){
        var _key = _move_keys[_i];
        if (!variable_struct_exists(_src, _key)) continue;
        if (!_force && variable_struct_exists(_dst, _key)) continue;

        var _value = variable_struct_get(_src, _key);
        if (is_undefined(_value)) continue;

        if (is_array(_value)){
            var _copy = [];
            for (var _m = 0; _m < array_length(_value); ++_m) array_push(_copy, _value[_m]);
            variable_struct_set(_dst, _key, _copy);
        } else {
            variable_struct_set(_dst, _key, _value);
        }
    }

    return _dst;
}

function party_model__copy_capture_identity_fields(_dst, _src, _force){
    if (!is_struct(_dst) || !is_struct(_src)) return _dst;

    var _keys = [
        "nickname",
        "name",
        "species_id",
        "species",
        "id",
        "_id",
        "level",
        "lvl",
        "hp",
        "hp_now",
        "hp_max",
        "maxhp",
        "ability",
        "ability_id",
        "nature",
        "gender",
        "shiny",
        "exp",
        "held_item",
        "item",
        "pokeball_item_id"
    ];

    for (var _i = 0; _i < array_length(_keys); ++_i){
        var _key = _keys[_i];
        if (!variable_struct_exists(_src, _key)) continue;
        if (!_force && variable_struct_exists(_dst, _key)) continue;

        var _value = variable_struct_get(_src, _key);
        if (is_undefined(_value)) continue;
        variable_struct_set(_dst, _key, _value);
    }

    return _dst;
}

function party_model__find_capture_mon_source(_source){
    if (!is_struct(_source)) return undefined;

    if (variable_struct_exists(_source, "mon") && is_struct(variable_struct_get(_source, "mon"))) return variable_struct_get(_source, "mon");
    if (variable_struct_exists(_source, "pokemon") && is_struct(variable_struct_get(_source, "pokemon"))) return variable_struct_get(_source, "pokemon");
    if (variable_struct_exists(_source, "data") && is_struct(variable_struct_get(_source, "data"))) return variable_struct_get(_source, "data");
    if (variable_struct_exists(_source, "pkmn") && is_struct(variable_struct_get(_source, "pkmn"))) return variable_struct_get(_source, "pkmn");
    if (variable_struct_exists(_source, "target_mon") && is_struct(variable_struct_get(_source, "target_mon"))) return variable_struct_get(_source, "target_mon");
    if (variable_struct_exists(_source, "enemy_mon") && is_struct(variable_struct_get(_source, "enemy_mon"))) return variable_struct_get(_source, "enemy_mon");

    return _source;
}

function party_model__mon_has_any_moves(_mon){
    if (!is_struct(_mon)) return false;

    var _move_keys = party_model__capture_move_field_names();
    for (var _i = 0; _i < array_length(_move_keys); ++_i){
        var _key = _move_keys[_i];
        if (!variable_struct_exists(_mon, _key)) continue;

        var _value = variable_struct_get(_mon, _key);
        if (is_array(_value) && array_length(_value) > 0) return true;
        if (!is_array(_value) && !is_undefined(_value)) return true;
    }

    return false;
}

function party_model__move_array_has_valid_move(_arr){
    if (!is_array(_arr)) return false;
    for (var _i = 0; _i < array_length(_arr); ++_i){
        var _mv = _arr[_i];
        if (is_real(_mv) && _mv > 0) return true;
        if (is_struct(_mv)){
            if (variable_struct_exists(_mv, "move") && is_real(variable_struct_get(_mv, "move")) && variable_struct_get(_mv, "move") > 0) return true;
            if (variable_struct_exists(_mv, "id") && is_real(variable_struct_get(_mv, "id")) && variable_struct_get(_mv, "id") > 0) return true;
            if (variable_struct_exists(_mv, "move_id") && is_real(variable_struct_get(_mv, "move_id")) && variable_struct_get(_mv, "move_id") > 0) return true;
        }
    }
    return false;
}

function party_model__mon_has_valid_current_moves(_mon){
    if (!is_struct(_mon)) return false;
    if (variable_struct_exists(_mon, "moves") && party_model__move_array_has_valid_move(variable_struct_get(_mon, "moves"))) return true;
    if (variable_struct_exists(_mon, "move_ids") && party_model__move_array_has_valid_move(variable_struct_get(_mon, "move_ids"))) return true;
    if (variable_struct_exists(_mon, "current_moves") && party_model__move_array_has_valid_move(variable_struct_get(_mon, "current_moves"))) return true;
    if (variable_struct_exists(_mon, "move_slots") && party_model__move_array_has_valid_move(variable_struct_get(_mon, "move_slots"))) return true;
    return false;
}

function party_model__move_id_from_entry(_entry){
    if (is_real(_entry)) return floor(_entry);
    if (is_struct(_entry)){
        if (variable_struct_exists(_entry, "move") && is_real(variable_struct_get(_entry, "move"))) return floor(variable_struct_get(_entry, "move"));
        if (variable_struct_exists(_entry, "id") && is_real(variable_struct_get(_entry, "id"))) return floor(variable_struct_get(_entry, "id"));
        if (variable_struct_exists(_entry, "move_id") && is_real(variable_struct_get(_entry, "move_id"))) return floor(variable_struct_get(_entry, "move_id"));
    }
    return -1;
}

function party_model__latest_four_unique_moves(_learnset){
    var _out = [];
    if (!is_array(_learnset)) return _out;
    for (var _i = array_length(_learnset) - 1; _i >= 0; --_i){
        var _move_id = party_model__move_id_from_entry(_learnset[_i]);
        if (!is_real(_move_id) || _move_id <= 0) continue;
        var _dupe = false;
        for (var _j = 0; _j < array_length(_out); ++_j){
            if (_out[_j] == _move_id){ _dupe = true; break; }
        }
        if (_dupe) continue;
        array_insert(_out, 0, _move_id);
        if (array_length(_out) >= 4) break;
    }
    return _out;
}

function party_model_assign_level_moves_if_missing(_mon){
    if (!is_struct(_mon)) return _mon;

    var _has_moves = false;
    if (variable_struct_exists(_mon, "moves") && is_array(variable_struct_get(_mon, "moves"))){
        var _arr = variable_struct_get(_mon, "moves");
        for (var _i = 0; _i < array_length(_arr); ++_i){
            if (is_real(_arr[_i]) && _arr[_i] > 0){ _has_moves = true; break; }
        }
    }
    if (_has_moves) return _mon;

    var _species_id = -1;
    if (!is_undefined(party_model_resolve_species_id)) _species_id = party_model_resolve_species_id(_mon);
    else {
        if (variable_struct_exists(_mon, "species_id") && is_real(variable_struct_get(_mon, "species_id"))) _species_id = floor(variable_struct_get(_mon, "species_id"));
        else if (variable_struct_exists(_mon, "id") && is_real(variable_struct_get(_mon, "id"))) _species_id = floor(variable_struct_get(_mon, "id"));
        else if (variable_struct_exists(_mon, "_id") && is_real(variable_struct_get(_mon, "_id"))) _species_id = floor(variable_struct_get(_mon, "_id"));
    }

    var _level = 1;
    if (variable_struct_exists(_mon, "level") && is_real(variable_struct_get(_mon, "level"))) _level = max(1, floor(variable_struct_get(_mon, "level")));
    else if (variable_struct_exists(_mon, "lvl") && is_real(variable_struct_get(_mon, "lvl"))) _level = max(1, floor(variable_struct_get(_mon, "lvl")));

    var _moves = [];
    if (is_real(_species_id) && _species_id > 0 && !is_undefined(__pfc_last4_levelup_moves)){
        var _factory_moves = __pfc_last4_levelup_moves(_species_id, _level);
        if (is_array(_factory_moves)){
            for (var _m = 0; _m < array_length(_factory_moves); ++_m){
                if (is_real(_factory_moves[_m]) && _factory_moves[_m] > 0) array_push(_moves, _factory_moves[_m]);
            }
        }
    }

    if (array_length(_moves) > 0){
        variable_struct_set(_mon, "moves", _moves);
        variable_struct_set(_mon, "move_ids", _moves);
        variable_struct_set(_mon, "current_moves", _moves);

        var _pps = [];
        for (var _p = 0; _p < array_length(_moves); ++_p){
            var _pp = 5;
            if (!is_undefined(__pfc_move_pp)) _pp = __pfc_move_pp(_moves[_p]);
            array_push(_pps, _pp);
        }
        variable_struct_set(_mon, "pps", _pps);
        variable_struct_set(_mon, "pp", _pps);
        variable_struct_set(_mon, "pp_now", _pps);
        variable_struct_set(_mon, "pp_max", _pps);
    }

    return _mon;
}

function party_model__resolve_capture_level(_mon){
    if (!is_struct(_mon)) return 1;
    if (variable_struct_exists(_mon, "level") && is_real(variable_struct_get(_mon, "level"))) return max(1, floor(variable_struct_get(_mon, "level")));
    if (variable_struct_exists(_mon, "lvl") && is_real(variable_struct_get(_mon, "lvl"))) return max(1, floor(variable_struct_get(_mon, "lvl")));
    return 1;
}

function party_model__is_full_capture_mon(_mon){
    if (!is_struct(_mon)) return false;

    // A full factory Pokemon usually has these core fields.
    var _has_species = (variable_struct_exists(_mon, "species_id") || variable_struct_exists(_mon, "species") || variable_struct_exists(_mon, "id") || variable_struct_exists(_mon, "_id"));
    var _has_level = (variable_struct_exists(_mon, "level") || variable_struct_exists(_mon, "lvl"));
    var _has_moves = false;
    if (variable_struct_exists(_mon, "moves") && is_array(variable_struct_get(_mon, "moves"))) _has_moves = true;
    if (variable_struct_exists(_mon, "move_ids") && is_array(variable_struct_get(_mon, "move_ids"))) _has_moves = true;
    if (variable_struct_exists(_mon, "current_moves") && is_array(variable_struct_get(_mon, "current_moves"))) _has_moves = true;

    // The strongest signal is a factory learnset, but not every generated mon may have one yet.
    if (variable_struct_exists(_mon, "learnset") && is_array(variable_struct_get(_mon, "learnset")) && _has_species && _has_level) return true;

    // Good enough: full mon with species/level/moves/stat fields.
    var _has_stats = (variable_struct_exists(_mon, "hp") || variable_struct_exists(_mon, "hp_now") || variable_struct_exists(_mon, "hp_max") || variable_struct_exists(_mon, "maxhp"));
    return (_has_species && _has_level && _has_moves && _has_stats);
}

function party_model__copy_full_capture_mon(_mon){
    if (!is_struct(_mon)) return undefined;

    // Copy the exact full Pokemon struct shallowly, preserving all factory fields:
    // learnset, moves, PP, stats, types, icon, IV/EV, nature, ability, etc.
    var _out = {};
    var _names = variable_struct_get_names(_mon);
    for (var _i = 0; _i < array_length(_names); ++_i){
        var _key = _names[_i];
        variable_struct_set(_out, _key, variable_struct_get(_mon, _key));
    }
    return _out;
}

function party_model__find_exact_capture_mon_source(_source){
    if (!is_struct(_source)) return undefined;

    // If the incoming value itself is already the full Pokemon, use it first.
    if (party_model__is_full_capture_mon(_source)) return _source;

    // Common direct wrapper fields.
    var _keys = [
        "original_mon",
        "source_mon",
        "wild_mon",
        "factory_mon",
        "pokemon",
        "mon",
        "data",
        "pkmn",
        "target_mon",
        "enemy_mon",
        "battler_mon"
    ];

    for (var _i = 0; _i < array_length(_keys); ++_i){
        var _key = _keys[_i];
        if (variable_struct_exists(_source, _key)){
            var _candidate = variable_struct_get(_source, _key);
            if (party_model__is_full_capture_mon(_candidate)) return _candidate;
        }
    }

    // One-level nested search for battle actor wrappers.
    var _outer_names = variable_struct_get_names(_source);
    for (var _o = 0; _o < array_length(_outer_names); ++_o){
        var _outer_value = variable_struct_get(_source, _outer_names[_o]);
        if (!is_struct(_outer_value)) continue;

        if (party_model__is_full_capture_mon(_outer_value)) return _outer_value;

        for (var _j = 0; _j < array_length(_keys); ++_j){
            var _nested_key = _keys[_j];
            if (variable_struct_exists(_outer_value, _nested_key)){
                var _nested_candidate = variable_struct_get(_outer_value, _nested_key);
                if (party_model__is_full_capture_mon(_nested_candidate)) return _nested_candidate;
            }
        }
    }

    return undefined;
}

function party_model_attach_capture_learnset(_mon){
    if (!is_struct(_mon)) return _mon;

    var _species_id = -1;
    if (!is_undefined(party_model_resolve_species_id)) _species_id = party_model_resolve_species_id(_mon);
    else {
        if (variable_struct_exists(_mon, "species_id") && is_real(variable_struct_get(_mon, "species_id"))) _species_id = floor(variable_struct_get(_mon, "species_id"));
        else if (variable_struct_exists(_mon, "id") && is_real(variable_struct_get(_mon, "id"))) _species_id = floor(variable_struct_get(_mon, "id"));
        else if (variable_struct_exists(_mon, "_id") && is_real(variable_struct_get(_mon, "_id"))) _species_id = floor(variable_struct_get(_mon, "_id"));
    }

    var _level = 1;
    if (variable_struct_exists(_mon, "level") && is_real(variable_struct_get(_mon, "level"))) _level = max(1, floor(variable_struct_get(_mon, "level")));
    else if (variable_struct_exists(_mon, "lvl") && is_real(variable_struct_get(_mon, "lvl"))) _level = max(1, floor(variable_struct_get(_mon, "lvl")));

    if (is_real(_species_id) && _species_id > 0 && !is_undefined(scr_poke_moves_upto_level)){
        var _learnset = scr_poke_moves_upto_level(_species_id, _level);
        if (is_array(_learnset)){
            variable_struct_set(_mon, "learnset", _learnset);
        }
    }

    return _mon;
}
