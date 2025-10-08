// [Pokémon Index]: PokemonIndex_STRUCTS — Build v2.5 — Updated 2025-10-03
// ============================================================================
// PokemonIndex_STRUCTS.gml  (arrays only)
// Builds:
//  - global._name_by_id[id] = "bulbasaur"
//  - global._name_list[] (sorted)
//  - global._id_list[]   (sorted; pairs with _name_list)
// Helpers:
//  - scr_poke_index_by_name(name) -> id (binary search)
//  - scr_poke_name_by_id(id) -> name
//  - scr_poke_stats(id) -> {hp,atk,def,spa,spd,spe}
//  - stat calcs (hp/stat) as before
// ============================================================================

/// scr_poke_index_build_simple_structs()  v1.1
/// Builds three arrays from global._pokemon (struct array from your CSV):
///   global._name_by_id[species_id] = "identifier"
///   global._name_list  = ["bulbasaur","ivysaur",... ]  (sorted a→z)
///   global._id_list    = [1, 2, ...]                   (same order as _name_list)
///
/// Requirements:
///   - global._pokemon is an array of structs with at least:
///       { _id: <real>, identifier: <string> }
function scr_poke_index_build_simple_structs()
{
    // validate source
    if (!(variable_global_exists("_pokemon") && is_array(global._pokemon))) {
        show_debug_message("[INDEX] _pokemon source missing (run data_load_all_structs() first).");
        return;
    }

    // fresh outputs
    global._name_by_id = [];
    global._name_list  = [];
    global._id_list    = [];

    var src = global._pokemon;
    var n   = array_length(src);

    // collect valid pairs
    var pairs = [];
    for (var i = 0; i < n; i++) {
        var rec = src[i];
        if (!is_struct(rec)) continue;

        var sid = (!is_undefined(rec._id) && is_real(rec._id)) ? rec._id : -1;
        var nam = (!is_undefined(rec.identifier)) ? string(rec.identifier) : "";

        if (sid > 0 && string_length(nam) > 0) {
            array_push(pairs, { idv: sid, n: string_lower(nam) });
        }
    }

    // insertion sort by name (case-insensitive); avoid string_compare()
    var m = array_length(pairs);
    for (var k = 1; k < m; k++) {
        var key = pairs[k];
        var j = k - 1;
        // compare using plain lexicographic operators on the pre-lowered strings
        while (j >= 0 && pairs[j].n > key.n) {
            pairs[j + 1] = pairs[j];
            j--;
        }
        pairs[j + 1] = key;
    }

    // fill outputs
    var max_id = 0;
    for (var t = 0; t < m; t++) {
        var p = pairs[t];
        global._name_by_id[p.idv] = p.n;   // sparse by species id
        array_push(global._name_list, p.n);
        array_push(global._id_list,   p.idv);
        if (p.idv > max_id) max_id = p.idv;
    }

    show_debug_message("[INDEX] built arrays: names=" + string(m) + " max_id=" + string(max_id));
}


/// scr_poke_index_by_name(name) -> species_id or -1   (structs, no string_compare)
/// Requires:
///   - global._name_list : array of lowercase identifiers, sorted A→Z
///   - global._id_list   : array of ids, same order/length as _name_list
function scr_poke_index_by_name(_name)
{
    if (is_undefined(_name)) return -1;
    if (!(variable_global_exists("_name_list") && is_array(global._name_list))) return -1;
    if (!(variable_global_exists("_id_list")   && is_array(global._id_list)))   return -1;

    var list = global._name_list;
    var ids  = global._id_list;
    var n    = array_length(list);
    if (n <= 0) return -1;

    var target = string_lower(string(_name));

    // standard binary search without string_compare()
    var lo = 0;
    var hi = n - 1;
    while (lo <= hi) {
        var mid = (lo + hi) div 2;
        var cur = list[mid];

        if (cur == target) return ids[mid];
        else if (cur > target) hi = mid - 1;   // lexicographic compare
        else                   lo = mid + 1;
    }
    return -1;
}


/// scr_poke_name_by_id(id) -> identifier (lowercase) or ""
function scr_poke_name_by_id(_sid)
{
    if (!is_real(_sid)) return "";
    if (!(variable_global_exists("_name_by_id") && is_array(global._name_by_id))) return "";
    var idx = floor(_sid);
    if (idx < 0 || idx >= array_length(global._name_by_id)) return "";
    var v = global._name_by_id[idx];
    return is_string(v) ? v : "";
}


function scr_poke_stats(_sid){
    if (!variable_global_exists("_poke_stats")) return {hp:45,atk:49,def:49,spa:65,spd:65,spe:45};
    if (_sid < 0 || _sid >= array_length(global._poke_stats)) return {hp:45,atk:49,def:49,spa:65,spd:65,spe:45};
    var s = global._poke_stats[_sid];
    return is_struct(s) ? s : {hp:45,atk:49,def:49,spa:65,spd:65,spe:45};
}

// STAT CALCS (same as before)
function scr_poke_calc_hp(_base, _lvl){
    var b = max(1, _base);
    var L = max(1, _lvl);
    return floor(((2*b)*L)/100) + L + 10;
}
function scr_poke_calc_stat(_base, _lvl){
    var b = max(1, _base);
    var L = max(1, _lvl);
    return floor(((2*b)*L)/100) + 5;
}


// ======== APPENDED: SAFE LOOKUPS & DESCRIPTION HELPERS (Build v2.5) ========
// Change: scr_poke_moves_upto_level now de-duplicates move IDs while preserving learn order.

function scr_move_name_by_id(_mid){
    if (!is_real(_mid) || _mid <= 0) return "";
    if (variable_global_exists("_move_text") && is_array(global._move_text) && _mid < array_length(global._move_text)){
        var t = global._move_text[_mid];
        if (is_struct(t) && !is_undefined(t.name) && t.name != "") return t.name;
    }
    if (variable_global_exists("_moves") && is_array(global._moves) && _mid < array_length(global._moves)){
        var m = global._moves[_mid];
        if (is_struct(m) && !is_undefined(m.identifier)){
            var s = m.identifier; 
            if (string_length(s) > 0) return string_replace_all(string_upper(string_copy(s,1,1)) + string_delete(s,1,1), "-", " ");
        }
    }
    return "";
}

function scr_move_desc_by_id(_mid){
    if (!is_real(_mid) || _mid <= 0) return "";
    if (!(variable_global_exists("_move_text") && is_array(global._move_text))) return "";
    if (_mid >= array_length(global._move_text)) return "";
    var t = global._move_text[_mid];
    if (!is_struct(t)) return "";
    return is_undefined(t.short_desc) ? "" : t.short_desc;
}

function scr_ability_name_by_id(_aid){
    if (!is_real(_aid) || _aid <= 0) return "";
    if (variable_global_exists("_ability_text") && is_array(global._ability_text) && _aid < array_length(global._ability_text)){
        var t = global._ability_text[_aid];
        if (is_struct(t) && !is_undefined(t.name) && t.name != "") return t.name;
    }
    if (variable_global_exists("_abilities") && is_array(global._abilities) && _aid < array_length(global._abilities)){
        var a = global._abilities[_aid];
        if (is_struct(a) && !is_undefined(a.identifier)){
            var s = a.identifier; 
            if (string_length(s) > 0) return string_replace_all(string_upper(string_copy(s,1,1)) + string_delete(s,1,1), "-", " ");
        }
    }
    return "";
}

function scr_poke_abilities_by_id(_sid){
    if (!(variable_global_exists("_species_abilities") && is_array(global._species_abilities))) return [];
    if (_sid < 0 || _sid >= array_length(global._species_abilities)) return [];
    var arr = global._species_abilities[_sid];
    return is_array(arr) ? arr : [];
}

function scr_poke_moveset_by_id(_sid){
    if (!(variable_global_exists("_species_moves") && is_array(global._species_moves))) return [];
    if (_sid < 0 || _sid >= array_length(global._species_moves)) return [];
    var arr = global._species_moves[_sid];
    return is_array(arr) ? arr : [];
}

// UPDATED: returns unique move IDs up to level, preserving learn order
function scr_poke_moves_upto_level(_sid, _lvl){
    var lvl = max(1, is_real(_lvl) ? _lvl : 1);
    var ms = scr_poke_moveset_by_id(_sid);
    var out = [];
    for (var _i = 0; _i < array_length(ms); _i++){
        var m = ms[_i];
        if (!(is_struct(m) && m.lvl <= lvl)) continue;
        var _mid = m.mid;
        var _seen = false;
        for (var _j = 0; _j < array_length(out); _j++){
            if (out[_j] == _mid) { _seen = true; break; }
        }
        if (!_seen) array_push(out, _mid);
    }
    return out;
}

function scr_poke_moves_future(_sid, _lvl){
    var lvl = max(1, is_real(_lvl) ? _lvl : 1);
    var ms = scr_poke_moveset_by_id(_sid);
    var out = [];
    for (var _i = 0; _i < array_length(ms); _i++){
        var m = ms[_i];
        if (is_struct(m) && m.lvl > lvl) array_push(out, { lvl:m.lvl, mid:m.mid });
    }
    return out;
}

function scr_poke_pick_ability(_sid, _seed_opt){
    var arr = scr_poke_abilities_by_id(_sid);
    if (!is_array(arr) || array_length(arr) == 0) return 0;
    var idx = 0;
    if (is_real(_seed_opt)) {
        var _old = random_get_seed();
        random_set_seed(_seed_opt);
        idx = irandom(array_length(arr)-1);
        random_set_seed(_old);
    } else {
        idx = irandom(array_length(arr)-1);
    }
    return arr[idx];
}

function scr_poke_describe(_sid, _lvl){
    var name_ident = scr_poke_name_by_id(_sid);
    var stats = scr_poke_stats(_sid);
    var lvl = max(1, is_real(_lvl) ? _lvl : 1);
    var ability_ids = scr_poke_abilities_by_id(_sid);
    var ability_names = [];
    for (var _i = 0; _i < array_length(ability_ids); _i++){
        var _aid = ability_ids[_i];
        array_push(ability_names, scr_ability_name_by_id(_aid));
    }
    var learned_ids = scr_poke_moves_upto_level(_sid, lvl);
    var learned = [];
    for (var _j = 0; _j < array_length(learned_ids); _j++){
        var _mid = learned_ids[_j];
        array_push(learned, { id:_mid, name:scr_move_name_by_id(_mid), desc:scr_move_desc_by_id(_mid) });
    }
    var future_pairs = scr_poke_moves_future(_sid, lvl);
    var future = [];
    for (var _k = 0; _k < array_length(future_pairs); _k++){
        var p = future_pairs[_k];
        array_push(future, { lvl:p.lvl, id:p.mid, name:scr_move_name_by_id(p.mid), desc:scr_move_desc_by_id(p.mid) });
    }
    return {
        species_id     : _sid,
        name_ident     : name_ident,
        stats          : stats,
        level          : lvl,
        ability_ids    : ability_ids,
        ability_names  : ability_names,
        moves_learned  : learned,
        moves_future   : future
    };
}
