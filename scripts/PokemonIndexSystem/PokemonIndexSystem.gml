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
    global._dex_id_list = [];

    var src = global._pokemon;
    var n   = array_length(src);

    // collect valid pairs
    var pairs = [];
    for (var i = 0; i < n; i++) {
        var rec = src[i];
        if (!is_struct(rec)) continue;

        var sid = (!is_undefined(rec._id) && is_real(rec._id)) ? rec._id : -1;
        var nam = (!is_undefined(rec.identifier)) ? string(rec.identifier) : "";

        if (sid >= 0 && string_length(nam) > 0) {
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

    for (var _dex_id = 0; _dex_id <= max_id; ++_dex_id) {
        if (_dex_id < array_length(global._name_by_id) && is_string(global._name_by_id[_dex_id])) {
            array_push(global._dex_id_list, _dex_id);
        }
    }

    show_debug_message("[INDEX] built arrays: names=" + string(m) + " dex_ids=" + string(array_length(global._dex_id_list)) + " max_id=" + string(max_id));
}

// ----- New: index_build_all() compatibility wrapper -----
// Builds DS maps and other lookup maps expected by data_verify_and_seed()
// Creates globals:
//   POKEMON_SPECIES        (ds_map) id -> species struct
//   POKEMON_MOVES          (ds_map) id -> move struct
//   BATTLE_TYPES           (ds_map) name -> type id
//   BATTLE_TYPE_EFFICACY   (ds_map) key "atk:def" -> multiplier
//   POKEMON_ID_BY_NAME     (ds_map) name -> id
//   MOVE_ID_BY_NAME        (ds_map) name -> id
//   TYPE_ID_BY_NAME        (ds_map) name -> id
function index_build_all()
{
    // POKEMON_SPECIES: from global._pokemon
    if (variable_global_exists("_pokemon") && is_array(global._pokemon)){
        if (!variable_global_exists("POKEMON_SPECIES") || !ds_exists(global.POKEMON_SPECIES, ds_type_map)) global.POKEMON_SPECIES = ds_map_create();
        else ds_map_clear(global.POKEMON_SPECIES);
        for (var i = 0; i < array_length(global._pokemon); i++){
            var rec = global._pokemon[i];
            if (!is_struct(rec) || is_undefined(rec._id)) continue;
            ds_map_add(global.POKEMON_SPECIES, string(rec._id), rec);
        }
    }

    // POKEMON_MOVES: from global._moves
    if (variable_global_exists("_moves") && is_array(global._moves)){
        if (!variable_global_exists("POKEMON_MOVES") || !ds_exists(global.POKEMON_MOVES, ds_type_map)) global.POKEMON_MOVES = ds_map_create();
        else ds_map_clear(global.POKEMON_MOVES);
        for (var j = 0; j < array_length(global._moves); j++){
            var m = global._moves[j];
            if (!is_struct(m) || is_undefined(m.id)) continue;
            ds_map_add(global.POKEMON_MOVES, string(m.id), m);
        }
    }

    // TYPE_NAME -> id maps (TYPE_ID_BY_NAME) from any existing type lists
    if (variable_global_exists("_types") && is_array(global._types)){
        if (!variable_global_exists("TYPE_ID_BY_NAME") || !ds_exists(global.TYPE_ID_BY_NAME, ds_type_map)) global.TYPE_ID_BY_NAME = ds_map_create();
        else ds_map_clear(global.TYPE_ID_BY_NAME);
        for (var t = 0; t < array_length(global._types); t++){
            var tv = global._types[t];
            if (!is_struct(tv) || is_undefined(tv.id) || is_undefined(tv.identifier)) continue;
            ds_map_add(global.TYPE_ID_BY_NAME, string_lower(string(tv.identifier)), tv.id);
        }
    }

    // BATTLE_TYPES / BATTLE_TYPE_EFFICACY: best-effort if type efficacy table exists (global._type_efficacy)
    if (variable_global_exists("_type_efficacy") && is_array(global._type_efficacy)){
        if (!variable_global_exists("BATTLE_TYPE_EFFICACY") || !ds_exists(global.BATTLE_TYPE_EFFICACY, ds_type_map)) global.BATTLE_TYPE_EFFICACY = ds_map_create();
        else ds_map_clear(global.BATTLE_TYPE_EFFICACY);
        for (var e = 0; e < array_length(global._type_efficacy); e++){
            var row = global._type_efficacy[e];
            if (!is_struct(row) || is_undefined(row.attack) || is_undefined(row.defense) || is_undefined(row.mult)) continue;
            var key = string(row.attack) + ":" + string(row.defense);
            ds_map_add(global.BATTLE_TYPE_EFFICACY, key, row.mult);
        }
    }

    // Build simple name->id DS maps for verification probes
    if (!variable_global_exists("POKEMON_ID_BY_NAME") || !ds_exists(global.POKEMON_ID_BY_NAME, ds_type_map)) global.POKEMON_ID_BY_NAME = ds_map_create(); else ds_map_clear(global.POKEMON_ID_BY_NAME);
    if (!variable_global_exists("MOVE_ID_BY_NAME")    || !ds_exists(global.MOVE_ID_BY_NAME, ds_type_map))    global.MOVE_ID_BY_NAME    = ds_map_create(); else ds_map_clear(global.MOVE_ID_BY_NAME);

    // Fill POKEMON_ID_BY_NAME from global._pokemon
    if (variable_global_exists("_pokemon") && is_array(global._pokemon)){
        for (var _pi = 0; _pi < array_length(global._pokemon); _pi++){
            var pr = global._pokemon[_pi];
            if (!is_struct(pr) || is_undefined(pr._id) || is_undefined(pr.identifier)) continue;
            ds_map_add(global.POKEMON_ID_BY_NAME, string_lower(string(pr.identifier)), pr._id);
        }
    }

    // Fill MOVE_ID_BY_NAME from global._moves
    if (variable_global_exists("_moves") && is_array(global._moves)){
        for (var mi = 0; mi < array_length(global._moves); mi++){
            var mr = global._moves[mi];
            if (!is_struct(mr) || is_undefined(mr.id) || is_undefined(mr.identifier)) continue;
            ds_map_add(global.MOVE_ID_BY_NAME, string_lower(string(mr.identifier)), mr.id);
        }
    }

    // BATTLE_TYPES best-effort from TYPE_ID_BY_NAME
    if (variable_global_exists("TYPE_ID_BY_NAME") && ds_exists(global.TYPE_ID_BY_NAME, ds_type_map)){
        if (!variable_global_exists("BATTLE_TYPES") || !ds_exists(global.BATTLE_TYPES, ds_type_map)) global.BATTLE_TYPES = ds_map_create(); else ds_map_clear(global.BATTLE_TYPES);
        var _k = ds_map_find_first(global.TYPE_ID_BY_NAME);
        while (_k != undefined){
            var _v = ds_map_find_value(global.TYPE_ID_BY_NAME, _k);
            ds_map_add(global.BATTLE_TYPES, _k, _v);
            _k = ds_map_find_next(global.TYPE_ID_BY_NAME, _k);
        }
    }

    show_debug_message("[INDEX] index_build_all() completed");
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
    if (variable_global_exists("_move_text") && is_array(global._move_text) && _mid >= 0 && _mid < array_length(global._move_text)){
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
    if (_mid < 0 || _mid >= array_length(global._move_text)) return "";
    var t = global._move_text[_mid];
    if (!is_struct(t)) return "";
    return is_undefined(t.short_desc) ? "" : t.short_desc;
}

// Debug helper: dump a species' level-up moves and which are eligible at a given level
function scr_debug_species_moves(_sid, _level){
    if (!is_real(_sid)) { show_debug_message("[DBG][moves] invalid species id: " + string(_sid)); return; }
    var sid = floor(_sid);
    var L = (is_real(_level) ? floor(_level) : 1);
    show_debug_message("[DBG][moves] species=" + string(sid) + " level=" + string(L));
    if (!variable_global_exists("_species_moves") || !is_array(global._species_moves)){
        show_debug_message("[DBG][moves] no global._species_moves loaded"); return;
    }
    if (sid < 0 || sid >= array_length(global._species_moves)){ show_debug_message("[DBG][moves] sid out of range"); return; }
    var rows = global._species_moves[sid];
    if (!is_array(rows)){ show_debug_message("[DBG][moves] no rows for species " + string(sid)); return; }
    show_debug_message("[DBG][moves] total rows=" + string(array_length(rows)));
    var elig = [];
    for (var i = 0; i < array_length(rows); i++){
        var r = rows[i];
        if (!is_struct(r)) { show_debug_message("  row[" + string(i) + "] not struct"); continue; }
        var lvl = (variable_struct_exists(r,"lvl") && is_real(r.lvl)) ? floor(r.lvl) : -1;
        var mid = (variable_struct_exists(r,"mid") && is_real(r.mid)) ? floor(r.mid) : -1;
        show_debug_message("  row[" + string(i) + "] lvl=" + string(lvl) + " mid=" + string(mid) + " name=" + string(scr_move_name_by_id(mid)) );
        if (mid > 0 && lvl <= L) array_push(elig, mid);
    }
    // Deduplicate eligible moves while preserving order so debug output matches
    // what the factory/battle selection will pick.
    var elig_unique = [];
    if (array_length(elig) > 0){
        var seen = [];
        for (var ei = 0; ei < array_length(elig); ei++){
            var mv = elig[ei];
            var dup = false;
            for (var si = 0; si < array_length(seen); si++) if (seen[si] == mv) { dup = true; break; }
            if (!dup){ array_push(seen, mv); array_push(elig_unique, mv); }
        }
    }
    show_debug_message("[DBG][moves] eligible_count=" + string(array_length(elig)) + " unique=" + string(array_length(elig_unique)) + " -> last4:");
    // show last up to 4 unique picks
    var n = array_length(elig_unique);
    for (var j = max(0, n - 4); j < n; j++) show_debug_message("   pick: " + string(elig_unique[j]) + " " + string(scr_move_name_by_id(elig_unique[j])) );
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
    // Experience / growth info (if available)
    var growth_id = -1;
    if (variable_global_exists("_pokemon") && is_array(global._pokemon) && _sid >= 0 && _sid < array_length(global._pokemon)){
        var prec = global._pokemon[_sid];
        if (is_struct(prec) && variable_struct_exists(prec, "growth_rate_id") && is_real(prec.growth_rate_id)) growth_id = floor(prec.growth_rate_id);
        else if (is_struct(prec) && variable_struct_exists(prec, "_growth_rate") && is_real(prec._growth_rate)) growth_id = floor(prec._growth_rate);
    }
    var exp_cur = -1; var exp_next = -1;
    if (is_real(growth_id) && growth_id >= 0){
        var vcur = scr_get_exp_for_level(growth_id, lvl);
        var vnext = scr_get_exp_for_level(growth_id, lvl + 1);
        if (is_real(vcur)) exp_cur = vcur;
        if (is_real(vnext)) exp_next = vnext;
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
        , growth_rate_id: growth_id
        , exp_current: exp_cur
        , exp_next: exp_next
    };

}

/// ===== Move helpers (PlayerIndex) =========================================
/// All helpers read from global._moves / global._move_names populated by your
/// data loaders. They’re defensive and return sensible defaults if fields
/// are missing in a given dataset entry.

/// Return the localized/display name for a move (already exists in your file,
/// included here for proximity reference)
/// function scr_move_name_by_id(_mid) { ... }

/// Accuracy in percent (0/undefined treated as 100% in many DBs)
function scr_move_accuracy_by_id(_mid) {
    var mv = (is_array(global._moves) && is_real(_mid) && _mid >= 0 && _mid < array_length(global._moves))
             ? global._moves[_mid] : undefined;
    if (is_struct(mv) && variable_struct_exists(mv, "accuracy") && is_real(variable_struct_get(mv, "accuracy"))) {
        var mv_acc = real(variable_struct_get(mv, "accuracy"));
        // Some datasets use 0 or -1 for “never misses”; default to 100
        if (mv_acc <= 0) return 100;
        return mv_acc;
    }
    return 100;
}

/// Base PP
function scr_move_pp_by_id(_mid) {
    var mv = (is_array(global._moves) && is_real(_mid) && _mid >= 0 && _mid < array_length(global._moves))
             ? global._moves[_mid] : undefined;
    if (is_struct(mv) && variable_struct_exists(mv, "pp") && is_real(variable_struct_get(mv, "pp"))) {
        return max(0, real(variable_struct_get(mv, "pp")));
    }
    return 0;
}

/// Base Power (0 for status / variable-power moves)
function scr_move_power_by_id(_mid) {
    var mv = (is_array(global._moves) && is_real(_mid) && _mid >= 0 && _mid < array_length(global._moves))
             ? global._moves[_mid] : undefined;
    if (is_struct(mv) && variable_struct_exists(mv, "power") && is_real(variable_struct_get(mv, "power"))) {
        var mv_pow = real(variable_struct_get(mv, "power"));
        return max(0, mv_pow);
    }
    return 0;
}

/// Type ID (returns -1 if unknown)
function scr_move_type_id_by_id(_mid, _A = undefined) {
    if (is_real(_mid) && floor(_mid) == 237) {
        var _iv_src = undefined;
        try {
            if (is_struct(_A) && variable_struct_exists(_A, "iv") && is_struct(variable_struct_get(_A, "iv"))) _iv_src = variable_struct_get(_A, "iv");
            else if (is_struct(_A) && variable_struct_exists(_A, "mon") && is_struct(variable_struct_get(_A, "mon")) && variable_struct_exists(variable_struct_get(_A, "mon"), "iv") && is_struct(variable_struct_get(variable_struct_get(_A, "mon"), "iv"))) _iv_src = variable_struct_get(variable_struct_get(_A, "mon"), "iv");
        } catch (e_hp_iv) { _iv_src = undefined; }
        if (is_struct(_iv_src)) {
            var _iv_hp = (variable_struct_exists(_iv_src, "hp") && is_real(variable_struct_get(_iv_src, "hp"))) ? floor(variable_struct_get(_iv_src, "hp")) : 0;
            var _iv_atk = (variable_struct_exists(_iv_src, "atk") && is_real(variable_struct_get(_iv_src, "atk"))) ? floor(variable_struct_get(_iv_src, "atk")) : 0;
            var _iv_def = (variable_struct_exists(_iv_src, "def") && is_real(variable_struct_get(_iv_src, "def"))) ? floor(variable_struct_get(_iv_src, "def")) : 0;
            var _iv_spe = (variable_struct_exists(_iv_src, "spe") && is_real(variable_struct_get(_iv_src, "spe"))) ? floor(variable_struct_get(_iv_src, "spe")) : 0;
            var _iv_spa = (variable_struct_exists(_iv_src, "spa") && is_real(variable_struct_get(_iv_src, "spa"))) ? floor(variable_struct_get(_iv_src, "spa")) : 0;
            var _iv_spd = (variable_struct_exists(_iv_src, "spd") && is_real(variable_struct_get(_iv_src, "spd"))) ? floor(variable_struct_get(_iv_src, "spd")) : 0;
            var _type_value = (_iv_hp & 1) + ((_iv_atk & 1) << 1) + ((_iv_def & 1) << 2) + ((_iv_spe & 1) << 3) + ((_iv_spa & 1) << 4) + ((_iv_spd & 1) << 5);
            var _type_index = clamp(floor(_type_value * 15 / 63), 0, 15);
            var _type_map = [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17];
            return _type_map[_type_index];
        }
        return 1;
    }
    if (is_real(_mid) && floor(_mid) == 311){
        try {
            var _pid_weather_ball = undefined;
            if (!is_undefined(__status_find_battle_pid)) _pid_weather_ball = __status_find_battle_pid(_A);
            if (is_real(_pid_weather_ball) && !is_undefined(__battle_get_weather)){
                var _wb_weather = __battle_get_weather(_pid_weather_ball);
                if (is_struct(_wb_weather) && variable_struct_exists(_wb_weather, "active") && variable_struct_get(_wb_weather, "active") == true){
                    var _wb_id = "";
                    if (variable_struct_exists(_wb_weather, "id")) _wb_id = string_lower(string(variable_struct_get(_wb_weather, "id")));
                    switch (_wb_id){
                        case "sun":
                        case "harsh-sun":
                            return 10;
                        case "rain":
                            return 11;
                        case "sandstorm":
                            return 6;
                        case "hail":
                        case "snow":
                            return 15;
                    }
                }
            }
        } catch (e_weather_ball_type) {}
    }
    if (is_real(_mid) && floor(_mid) == 363){
        try {
            if (!is_undefined(__battle_get_natural_gift_profile)){
                var _gift_profile = __battle_get_natural_gift_profile(_A);
                if (is_struct(_gift_profile) && variable_struct_exists(_gift_profile, "type_id") && is_real(variable_struct_get(_gift_profile, "type_id"))) return variable_struct_get(_gift_profile, "type_id");
            }
        } catch (e_natural_gift_type) {}
    }
    try {
        if (is_struct(_A) && !is_undefined(__battle_actor_ability_actions)){
            var _type_actions = __battle_actor_ability_actions(_A, "move_type_check");
            if (array_length(_type_actions) > 0){
                var _ab_key = "";
                try { if (!is_undefined(__battle_actor_ability_name_lc)) _ab_key = __battle_actor_ability_name_lc(_A); } catch (e_ab_type_key) { _ab_key = ""; }
                var _base_mv = (is_array(global._moves) && is_real(_mid) && _mid >= 0 && _mid < array_length(global._moves)) ? global._moves[_mid] : undefined;
                var _base_type = -1;
                if (is_struct(_base_mv) && variable_struct_exists(_base_mv, "type_id") && is_real(variable_struct_get(_base_mv, "type_id"))) _base_type = real(variable_struct_get(_base_mv, "type_id"));
                var _normal_id = __pokemon_index_type_id_safe("normal", 1);
                var _converted_type = -1;
                if (_ab_key == "normalize") _converted_type = _normal_id;
                else if (_base_type == _normal_id){
                    if (_ab_key == "refrigerate") _converted_type = __pokemon_index_type_id_safe("ice", 15);
                    else if (_ab_key == "pixilate") _converted_type = __pokemon_index_type_id_safe("fairy", 18);
                    else if (_ab_key == "aerilate") _converted_type = __pokemon_index_type_id_safe("flying", 3);
                    else if (_ab_key == "galvanize") _converted_type = __pokemon_index_type_id_safe("electric", 13);
                } else if (_ab_key == "liquid-voice"){
                    var _sound_move = false;
                    try { if (!is_undefined(__battle_ability_move_is_sound)) _sound_move = __battle_ability_move_is_sound(_mid); } catch (e_sound_type) { _sound_move = false; }
                    if (_sound_move) _converted_type = __pokemon_index_type_id_safe("water", 11);
                }
                if (_converted_type > 0) return _converted_type;
            }
        }
    } catch (e_ability_move_type) {}
    var mv = (is_array(global._moves) && is_real(_mid) && _mid >= 0 && _mid < array_length(global._moves))
             ? global._moves[_mid] : undefined;
    if (is_struct(mv) && variable_struct_exists(mv, "type_id") && is_real(variable_struct_get(mv, "type_id"))) {
        return real(variable_struct_get(mv, "type_id"));
    }
    return -1;
}

function __pokemon_index_type_id_safe(_name, _fallback){
    try {
        if (variable_global_exists("TYPE_ID_BY_NAME")){
            var _tm = variable_global_get("TYPE_ID_BY_NAME");
            if (ds_exists(_tm, ds_type_map) && ds_map_exists(_tm, string_lower(string(_name)))) return ds_map_find_value(_tm, string_lower(string(_name)));
        }
    } catch (e_type_lookup_safe) {}
    return _fallback;
}

/// Damage class ID (1=status, 2=physical, 3=special in most datasets)
function scr_move_damage_class_by_id(_mid) {
    var mv = (is_array(global._moves) && is_real(_mid) && _mid >= 0 && _mid < array_length(global._moves))
             ? global._moves[_mid] : undefined;
    if (is_struct(mv) && variable_struct_exists(mv, "damage_class_id") && is_real(variable_struct_get(mv, "damage_class_id"))) {
        return real(variable_struct_get(mv, "damage_class_id"));
    }
    return 0;
}

/// Priority (can be negative/positive; default 0)
function scr_move_priority_by_id(_mid) {
    var mv = (is_array(global._moves) && is_real(_mid) && _mid >= 0 && _mid < array_length(global._moves))
             ? global._moves[_mid] : undefined;
    if (is_struct(mv) && variable_struct_exists(mv, "priority") && is_real(variable_struct_get(mv, "priority"))) {
        return real(variable_struct_get(mv, "priority"));
    }
    switch (_mid) {
        case 182: // Protect
        case 197: // Detect
            return 4;
    }
    return 0;
}


/// Return species type IDs and human-readable names for a given species id
function scr_poke_types_by_id(_sid){
    var ids = [];
    if (is_real(_sid) && variable_global_exists("_species_types") && is_array(global._species_types) && _sid >= 0 && _sid < array_length(global._species_types)){
        var tmp = global._species_types[_sid];
        if (is_array(tmp)) for (var i=0;i<array_length(tmp);++i) if (is_real(tmp[i])) array_push(ids, tmp[i]);
    } else if (is_real(_sid) && variable_global_exists("POKEMON_SPECIES") && ds_exists(global.POKEMON_SPECIES, ds_type_map) && ds_map_exists(global.POKEMON_SPECIES, string(_sid))){
        var sp = ds_map_find_value(global.POKEMON_SPECIES, string(_sid));
        if (is_struct(sp)){
            if (variable_struct_exists(sp, "types") && is_array(variable_struct_get(sp, "types"))) {
                var _sp_types = variable_struct_get(sp, "types");
                for (var j=0;j<array_length(_sp_types);++j) if (is_real(_sp_types[j])) array_push(ids, _sp_types[j]);
            }
            else {
                if (variable_struct_exists(sp, "type1") && is_real(variable_struct_get(sp, "type1"))) array_push(ids, variable_struct_get(sp, "type1"));
                if (variable_struct_exists(sp, "type2") && is_real(variable_struct_get(sp, "type2"))) array_push(ids, variable_struct_get(sp, "type2"));
            }
        }
    }
    return ids;
}

/// Return a human-readable type string like "Fire/Flying" for a species id
function scr_poke_type_str(_sid){
    var ids = scr_poke_types_by_id(_sid);
    var names = [];
    var __builtin = ["Normal","Fire","Water","Electric","Grass","Ice","Fighting","Poison","Ground","Flying","Psychic","Bug","Rock","Ghost","Dark","Dragon","Steel","Fairy"];
    for (var k=0;k<array_length(ids);++k){
        var tid = ids[k];
        var resolved = "";
        if (variable_global_exists("TYPE_ID_BY_NAME") && ds_exists(TYPE_ID_BY_NAME, ds_type_map)){
            var _first = ds_map_find_first(TYPE_ID_BY_NAME);
            while(_first != undefined){ var _v = ds_map_find_value(TYPE_ID_BY_NAME, _first); if (is_real(_v) && _v == tid){ resolved = string(_first); break; } _first = ds_map_find_next(TYPE_ID_BY_NAME, _first); }
        }
        if (string_length(resolved) == 0){ if (is_real(tid) && tid >= 1 && tid <= array_length(__builtin)) resolved = __builtin[tid - 1]; else resolved = "Type" + string(tid); }
        if (string_length(resolved) > 0) resolved = string_upper(string_copy(resolved,1,1)) + string_delete(resolved,1,1);
        array_push(names, resolved);
    }
    var out = "";
    if (array_length(names) > 0){ out = names[0]; for (var xi=1; xi<array_length(names); ++xi) out += "/" + names[xi]; }
    return out;
}

// ============================================================================
// Poke-Index UI / player discovery state
// ============================================================================

function poke_index_init(_players){
    var _n = (argument_count > 0) ? max(1, floor(_players)) : 1;
    if (!variable_global_exists("POKE_INDEX") || !is_array(global.POKE_INDEX)) global.POKE_INDEX = [];
    if (array_length(global.POKE_INDEX) < _n) array_resize(global.POKE_INDEX, _n);
    for (var _pid = 0; _pid < _n; ++_pid){
        poke_index_ensure(_pid);
        poke_index_seed_party_discovery(_pid);
    }
}

function poke_index__default_state(){
    return {
        open:false,
        sel:0,
        scroll:0,
        page:"list",
        filter:0,
        lock:0,
        seen:[],
        caught:[]
    };
}

function poke_index_ensure(_pid){
    var _p = max(0, floor(_pid));
    if (!variable_global_exists("POKE_INDEX") || !is_array(global.POKE_INDEX)) global.POKE_INDEX = [];
    if (array_length(global.POKE_INDEX) <= _p) array_resize(global.POKE_INDEX, _p + 1);
    var _S = global.POKE_INDEX[_p];
    if (!is_struct(_S)) _S = poke_index__default_state();
    if (!variable_struct_exists(_S, "open")) _S.open = false;
    if (!variable_struct_exists(_S, "sel")) _S.sel = 0;
    if (!variable_struct_exists(_S, "scroll")) _S.scroll = 0;
    if (!variable_struct_exists(_S, "page")) _S.page = "list";
    if (!variable_struct_exists(_S, "filter")) _S.filter = 0;
    if (!variable_struct_exists(_S, "lock")) _S.lock = 0;
    if (!variable_struct_exists(_S, "seen") || !is_array(_S.seen)) _S.seen = [];
    if (!variable_struct_exists(_S, "caught") || !is_array(_S.caught)) _S.caught = [];
    global.POKE_INDEX[_p] = _S;
    return _S;
}

function poke_index_is_open(_pid){
    if (!variable_global_exists("POKE_INDEX") || !is_array(global.POKE_INDEX)) return false;
    if (_pid < 0 || _pid >= array_length(global.POKE_INDEX)) return false;
    var _S = global.POKE_INDEX[_pid];
    return is_struct(_S) && variable_struct_exists(_S, "open") && _S.open;
}

function poke_index_open(_pid){
    var _S = poke_index_ensure(_pid);
    poke_index_seed_party_discovery(_pid);
    _S.open = true;
    _S.page = "list";
    _S.lock = 2;
    poke_index__clamp_state(_pid, _S);
}

function poke_index_close(_pid){
    var _S = poke_index_ensure(_pid);
    _S.open = false;
    _S.page = "list";
    _S.lock = 2;
}

function poke_index_toggle(_pid){
    if (poke_index_is_open(_pid)) poke_index_close(_pid); else poke_index_open(_pid);
}

function poke_index_mark_seen(_pid, _species_id){
    var _sid = floor(_species_id);
    if (_sid <= 0) return false;
    var _S = poke_index_ensure(_pid);
    if (array_length(_S.seen) <= _sid) array_resize(_S.seen, _sid + 1);
    _S.seen[_sid] = true;
    return true;
}

function poke_index_mark_caught(_pid, _species_id){
    var _sid = floor(_species_id);
    if (_sid <= 0) return false;
    var _S = poke_index_ensure(_pid);
    if (array_length(_S.seen) <= _sid) array_resize(_S.seen, _sid + 1);
    if (array_length(_S.caught) <= _sid) array_resize(_S.caught, _sid + 1);
    _S.seen[_sid] = true;
    _S.caught[_sid] = true;
    return true;
}

function poke_index_has_seen(_pid, _species_id){
    var _S = poke_index_ensure(_pid);
    var _sid = floor(_species_id);
    return (_sid >= 0 && _sid < array_length(_S.seen) && _S.seen[_sid] == true);
}

function poke_index_has_caught(_pid, _species_id){
    var _S = poke_index_ensure(_pid);
    var _sid = floor(_species_id);
    return (_sid >= 0 && _sid < array_length(_S.caught) && _S.caught[_sid] == true);
}

function poke_index_mark_mon_seen(_pid, _mon){
    var _sid = poke_index__species_from_mon(_mon);
    if (_sid > 0) return poke_index_mark_seen(_pid, _sid);
    return false;
}

function poke_index_mark_mon_caught(_pid, _mon){
    var _sid = poke_index__species_from_mon(_mon);
    if (_sid > 0) return poke_index_mark_caught(_pid, _sid);
    return false;
}

function poke_index_seed_party_discovery(_pid){
    if (is_undefined(party_model_get_mons)) return false;
    var _mons = party_model_get_mons(_pid);
    if (!is_array(_mons)) return false;
    for (var _i = 0; _i < array_length(_mons); ++_i){
        var _mon = _mons[_i];
        if (is_struct(_mon)) poke_index_mark_mon_caught(_pid, _mon);
    }
    return true;
}

function poke_index__species_from_mon(_mon){
    if (!is_struct(_mon)) return -1;
    if (variable_struct_exists(_mon, "species_id") && is_real(_mon.species_id)) return floor(_mon.species_id);
    if (variable_struct_exists(_mon, "species") && is_real(_mon.species)) return floor(_mon.species);
    if (variable_struct_exists(_mon, "id") && is_real(_mon.id)) return floor(_mon.id);
    if (variable_struct_exists(_mon, "mon") && is_struct(_mon.mon)) return poke_index__species_from_mon(_mon.mon);
    return -1;
}

function poke_index__species_ids(){
    var _out = [];
    if (variable_global_exists("_dex_id_list") && is_array(global._dex_id_list)){
        for (var _d = 0; _d < array_length(global._dex_id_list); ++_d){
            if (is_real(global._dex_id_list[_d]) && global._dex_id_list[_d] >= 0) array_push(_out, floor(global._dex_id_list[_d]));
        }
        return _out;
    }
    if (variable_global_exists("_name_by_id") && is_array(global._name_by_id)){
        for (var _sid = 0; _sid < array_length(global._name_by_id); ++_sid){
            if (is_string(global._name_by_id[_sid])) array_push(_out, _sid);
        }
        return _out;
    }
    if (variable_global_exists("_id_list") && is_array(global._id_list)){
        for (var _i = 0; _i < array_length(global._id_list); ++_i){
            if (is_real(global._id_list[_i]) && global._id_list[_i] >= 0) array_push(_out, floor(global._id_list[_i]));
        }
        for (var _a = 1; _a < array_length(_out); ++_a){
            var _key = _out[_a];
            var _j = _a - 1;
            while (_j >= 0 && _out[_j] > _key){
                _out[_j + 1] = _out[_j];
                _j -= 1;
            }
            _out[_j + 1] = _key;
        }
        return _out;
    }
    if (variable_global_exists("_pokemon") && is_array(global._pokemon)){
        for (var _p = 0; _p < array_length(global._pokemon); ++_p){
            var _rec = global._pokemon[_p];
            if (is_struct(_rec) && variable_struct_exists(_rec, "_id") && is_real(_rec._id) && _rec._id >= 0) array_push(_out, floor(_rec._id));
        }
    }
    for (var _b = 1; _b < array_length(_out); ++_b){
        var _key_b = _out[_b];
        var _jb = _b - 1;
        while (_jb >= 0 && _out[_jb] > _key_b){
            _out[_jb + 1] = _out[_jb];
            _jb -= 1;
        }
        _out[_jb + 1] = _key_b;
    }
    return _out;
}

function poke_index__species_art_ready(_sid){
    if (!is_real(_sid) || _sid < 0) return false;
    try {
        if (!is_undefined(pkicons_has_art96)) return pkicons_has_art96(floor(_sid));
        if (!is_undefined(pkicons_get_art96)){
            var _spr = pkicons_get_art96(floor(_sid));
            if (!sprite_exists(_spr)) return false;
            if (variable_global_exists("PKICONS") && is_struct(global.PKICONS) && variable_struct_exists(global.PKICONS, "missing_art96") && _spr == global.PKICONS.missing_art96) return false;
            return true;
        }
    } catch (e_pidx_art) {}
    return true;
}

function poke_index__display_name(_sid, _known){
    if (!_known) return "----------";
    var _name = "";
    if (!is_undefined(scr_poke_name_by_id)) _name = scr_poke_name_by_id(_sid);
    if (string_length(string_trim(_name)) <= 0 && variable_global_exists("_pokemon") && is_array(global._pokemon) && _sid >= 0 && _sid < array_length(global._pokemon)){
        var _rec = global._pokemon[_sid];
        if (is_struct(_rec) && variable_struct_exists(_rec, "identifier")) _name = string(_rec.identifier);
    }
    _name = string_replace_all(string(_name), "-", " ");
    if (string_length(_name) <= 0) return "Pokemon";
    return string_upper(string_copy(_name, 1, 1)) + string_delete(_name, 1, 1);
}

function poke_index__rows(){
    var _ids = poke_index__species_ids();
    var _rows = [];
    for (var _i = 0; _i < array_length(_ids); ++_i){
        var _sid = _ids[_i];
        if (!poke_index__species_art_ready(_sid)) continue;
        array_push(_rows, { species_id:_sid, dex_no:_sid });
    }
    return _rows;
}

function poke_index__filter_label(_filter){
    var _f = floor(_filter);
    if (_f == 1) return "SEEN";
    if (_f == 2) return "UNSEEN";
    return "ALL";
}

function poke_index__filtered_rows(_pid, _S){
    var _base = poke_index__rows();
    var _filter = 0;
    if (is_struct(_S) && variable_struct_exists(_S, "filter")) _filter = floor(_S.filter);
    if (_filter < 0 || _filter > 2) _filter = 0;
    var _out = [];
    for (var _i = 0; _i < array_length(_base); ++_i){
        var _row = _base[_i];
        var _sid = variable_struct_get(_row, "species_id");
        var _is_seen = poke_index_has_seen(_pid, _sid);
        if (_filter == 1 && !_is_seen) continue;
        if (_filter == 2 && _is_seen) continue;
        array_push(_out, _row);
    }
    return _out;
}

function poke_index__clamp_state(_pid, _S){
    var _rows = poke_index__filtered_rows(_pid, _S);
    var _n = array_length(_rows);
    _S.sel = clamp(_S.sel, 0, max(0, _n - 1));
    _S.scroll = clamp(_S.scroll, 0, max(0, _n - 8));
    if (_S.sel < _S.scroll) _S.scroll = _S.sel;
    if (_S.sel >= _S.scroll + 8) _S.scroll = max(0, _S.sel - 7);
}

function poke_index_update(){
    if (!variable_global_exists("POKE_INDEX") || !is_array(global.POKE_INDEX)) return;
    for (var _pid = 0; _pid < array_length(global.POKE_INDEX); ++_pid){
        var _S = global.POKE_INDEX[_pid];
        if (!is_struct(_S) || !_S.open) continue;

        var _rows = poke_index__filtered_rows(_pid, _S);
        var _n = array_length(_rows);
        if (_S.lock > 0) _S.lock--;

        if (controls_pressed(_pid, "Run") || controls_pressed(_pid, "Back")){
            if (string(_S.page) == "area") {
                _S.page = "list";
                _S.lock = 2;
            } else if (_S.lock <= 0) {
                poke_index_close(_pid);
            }
            continue;
        }

        if (string(_S.page) == "area"){
            if (controls_pressed(_pid, "Interact") && _S.lock <= 0){
                _S.page = "list";
                _S.lock = 2;
            }
            continue;
        }

        if (controls_pressed(_pid, "MoveRight")){
            _S.filter += 1;
            if (_S.filter > 2) _S.filter = 0;
            _S.sel = 0;
            _S.scroll = 0;
            _rows = poke_index__filtered_rows(_pid, _S);
            _n = array_length(_rows);
        }
        if (controls_pressed(_pid, "MoveLeft")){
            _S.filter -= 1;
            if (_S.filter < 0) _S.filter = 2;
            _S.sel = 0;
            _S.scroll = 0;
            _rows = poke_index__filtered_rows(_pid, _S);
            _n = array_length(_rows);
        }

        if (_n > 0 && controls_pressed(_pid, "MoveDown")) _S.sel = clamp(_S.sel + 1, 0, _n - 1);
        if (_n > 0 && controls_pressed(_pid, "MoveUp")) _S.sel = clamp(_S.sel - 1, 0, _n - 1);
        poke_index__clamp_state(_pid, _S);

        if (controls_pressed(_pid, "Interact") && _S.lock <= 0 && _n > 0){
            _S.page = "area";
            _S.lock = 2;
        }
    }
}

function poke_index__location_label(_raw){
    var _s = string_replace_all(string(_raw), "_", " ");
    _s = string_replace_all(_s, "-", " ");
    if (string_length(_s) <= 0) return "Unknown";
    return string_upper(string_copy(_s, 1, 1)) + string_delete(_s, 1, 1);
}

function poke_index_locations_for_species(_species_id){
    var _sid = floor(_species_id);
    var _out = [];
    if (!variable_global_exists("OVERWORLD_ENCOUNTERS") || !is_struct(global.OVERWORLD_ENCOUNTERS)){
        if (!is_undefined(overworld_encounter_tables_init)) overworld_encounter_tables_init();
    }
    if (!variable_global_exists("OVERWORLD_ENCOUNTERS") || !is_struct(global.OVERWORLD_ENCOUNTERS)) return _out;
    var _E = global.OVERWORLD_ENCOUNTERS;
    if (!variable_struct_exists(_E, "tables") || !is_struct(_E.tables)) return _out;

    var _regions = variable_struct_get_names(_E.tables);
    for (var _ri = 0; _ri < array_length(_regions); ++_ri){
        var _region_key = _regions[_ri];
        var _region = variable_struct_get(_E.tables, _region_key);
        if (!is_struct(_region)) continue;
        var _habitats = variable_struct_get_names(_region);
        for (var _hi = 0; _hi < array_length(_habitats); ++_hi){
            var _habitat_key = _habitats[_hi];
            var _table = variable_struct_get(_region, _habitat_key);
            if (!is_array(_table)) continue;
            var _min_level = 999;
            var _max_level = -1;
            var _found = false;
            for (var _ei = 0; _ei < array_length(_table); ++_ei){
                var _entry = _table[_ei];
                if (!is_struct(_entry)) continue;
                var _entry_sid = -1;
                if (variable_struct_exists(_entry, "species_id") && is_real(_entry.species_id)) _entry_sid = floor(_entry.species_id);
                else if (variable_struct_exists(_entry, "id") && is_real(_entry.id)) _entry_sid = floor(_entry.id);
                else if (variable_struct_exists(_entry, "species") && is_real(_entry.species)) _entry_sid = floor(_entry.species);
                if (_entry_sid != _sid) continue;
                _found = true;
                var _lo = (variable_struct_exists(_entry, "min_level") && is_real(_entry.min_level)) ? floor(_entry.min_level) : 1;
                var _hi_level = (variable_struct_exists(_entry, "max_level") && is_real(_entry.max_level)) ? floor(_entry.max_level) : _lo;
                _min_level = min(_min_level, _lo);
                _max_level = max(_max_level, _hi_level);
            }
            if (_found){
                var _label = poke_index__location_label(_region_key) + " - " + poke_index__location_label(_habitat_key);
                var _lvl = (_max_level >= _min_level && _min_level < 999) ? ("Lv." + string(_min_level) + "-" + string(_max_level)) : "";
                array_push(_out, { region:_region_key, habitat:_habitat_key, label:_label, levels:_lvl });
            }
        }
    }
    return _out;
}

function poke_index__wrap_lines(_text, _max_w){
    var _out = [];
    var _words = string_split(string(_text), " ");
    var _line = "";
    for (var _i = 0; _i < array_length(_words); ++_i){
        var _w = _words[_i];
        var _try = (_line == "") ? _w : (_line + " " + _w);
        if (string_width(_try) <= _max_w) _line = _try;
        else {
            if (_line != "") array_push(_out, _line);
            _line = _w;
        }
    }
    if (_line != "") array_push(_out, _line);
    if (array_length(_out) <= 0) array_push(_out, "");
    return _out;
}

function poke_index_draw_gui_rect(_pid, _rx, _ry, _rw, _rh){
    if (!poke_index_is_open(_pid)) return;
    var _S = poke_index_ensure(_pid);
    var _rows = poke_index__filtered_rows(_pid, _S);
    poke_index__clamp_state(_pid, _S);
    _rows = poke_index__filtered_rows(_pid, _S);

    draw_set_alpha(1);
    draw_set_color(c_white);
    gpu_set_blendmode(bm_normal);
    if (variable_global_exists("FNT_POKEMON")) draw_set_font(global.FNT_POKEMON); else draw_set_font(-1);

    var _s = max(1, min(floor(_rw / 240), floor(_rh / 160)));
    var _ox = _rx + (_rw - 240 * _s) div 2;
    var _oy = _ry + (_rh - 160 * _s) div 2;
    var _text_dy = 5 * _s;
    var _t = current_time / 1000;
    var _pulse = 0.75 + 0.25 * sin(_t * 5);

    var C_BG1 = make_color_rgb(80, 176, 152);
    var C_BG2 = make_color_rgb(56, 144, 136);
    var C_PANEL = make_color_rgb(240, 232, 184);
    var C_EDGE = make_color_rgb(40, 72, 88);
    var C_SEL = make_color_rgb(232, 96, 72);
    var C_MAP = make_color_rgb(120, 200, 144);

    for (var _yy = 0; _yy < 160; _yy += 8){
        draw_set_color(((_yy div 8) & 1) ? C_BG1 : C_BG2);
        draw_rectangle(_ox, _oy + _yy * _s, _ox + 240 * _s, _oy + (_yy + 8) * _s, false);
    }

    draw_set_color(C_EDGE);
    draw_rectangle(_ox + 4 * _s, _oy + 4 * _s, _ox + 236 * _s, _oy + 156 * _s, false);
    draw_set_color(C_PANEL);
    draw_rectangle(_ox + 7 * _s, _oy + 7 * _s, _ox + 233 * _s, _oy + 153 * _s, false);

    draw_set_color(C_EDGE);
    draw_text(_ox + 14 * _s, _oy + 11 * _s + _text_dy, "POKE-INDEX");
    draw_text(_ox + 152 * _s, _oy + 11 * _s + _text_dy, poke_index__filter_label(_S.filter));
    draw_text(_ox + 190 * _s, _oy + 11 * _s + _text_dy, "SEEN " + string(poke_index_seen_count(_pid)));

    if (array_length(_rows) <= 0){
        draw_set_color(c_white);
        draw_text(_ox + 24 * _s, _oy + 72 * _s + _text_dy, "No Pokemon data.");
        return;
    }

    var _row = _rows[_S.sel];
    var _sid = variable_struct_get(_row, "species_id");
    var _seen = poke_index_has_seen(_pid, _sid);
    var _got = poke_index_has_caught(_pid, _sid);

    if (string(_S.page) == "area"){
        poke_index__draw_area_page(_pid, _S, _sid, _seen, _got, _ox, _oy, _s, _text_dy, C_EDGE, C_PANEL, C_MAP);
        return;
    }

    var _list_x = 12, _list_y = 30, _list_w = 132, _list_h = 112;
    var _info_x = 150, _info_y = 30, _info_w = 74, _info_h = 112;
    draw_set_color(c_white);
    draw_rectangle(_ox + _list_x * _s, _oy + _list_y * _s, _ox + (_list_x + _list_w) * _s, _oy + (_list_y + _list_h) * _s, false);
    draw_set_color(C_EDGE);
    draw_rectangle(_ox + _list_x * _s - _s, _oy + _list_y * _s - _s, _ox + (_list_x + _list_w) * _s + _s, _oy + (_list_y + _list_h) * _s + _s, true);

    var _line_h = max(12, string_height("A") + 2);
    var _caught_marks = _S.caught;
    for (var _r = 0; _r < 8; ++_r){
        var _idx = _S.scroll + _r;
        if (_idx >= array_length(_rows)) break;
        var _row_entry = _rows[_idx];
        var _rsid = variable_struct_get(_row_entry, "species_id");
        var _known = poke_index_has_seen(_pid, _rsid);
        var _row_got = false;
        if (_rsid >= 0 && _rsid < array_length(_caught_marks)){
            if (_caught_marks[_rsid] == true) _row_got = true;
        }
        var _row_y = _oy + (_list_y + 7 + _r * _line_h) * _s;
        if (_idx == _S.sel){
            draw_set_alpha(_pulse);
            draw_set_color(C_SEL);
            draw_rectangle(_ox + (_list_x + 3) * _s, _row_y - 1 * _s, _ox + (_list_x + _list_w - 3) * _s, _row_y + (_line_h - 1) * _s, false);
            draw_set_alpha(1);
        }
        draw_set_color(c_white);
        var _cursor_txt = " ";
        if (_idx == _S.sel) _cursor_txt = ">";
        draw_text(_ox + (_list_x + 6) * _s, _row_y + _text_dy, _cursor_txt);
        draw_text(_ox + (_list_x + 18) * _s, _row_y + _text_dy, string_format(_rsid, 3, 0));
        draw_text(_ox + (_list_x + 46) * _s, _row_y + _text_dy, poke_index__display_name(_rsid, _known));
        if (_row_got){
            draw_text(_ox + (_list_x + _list_w - 14) * _s, _row_y + _text_dy, "*");
        }
    }

    draw_set_color(C_MAP);
    draw_rectangle(_ox + _info_x * _s, _oy + _info_y * _s, _ox + (_info_x + _info_w) * _s, _oy + (_info_y + _info_h) * _s, false);
    draw_set_color(C_EDGE);
    draw_rectangle(_ox + _info_x * _s - _s, _oy + _info_y * _s - _s, _ox + (_info_x + _info_w) * _s + _s, _oy + (_info_y + _info_h) * _s + _s, true);
    draw_set_color(c_white);
    draw_text(_ox + (_info_x + 6) * _s, _oy + (_info_y + 8) * _s + _text_dy, "No." + string_format(_sid, 3, 0));
    draw_text(_ox + (_info_x + 6) * _s, _oy + (_info_y + 22) * _s + _text_dy, poke_index__display_name(_sid, _seen));
    var _status_txt = "UNKNOWN";
    if (_seen) _status_txt = "SEEN";
    if (_got) _status_txt = "CAUGHT";
    draw_text(_ox + (_info_x + 6) * _s, _oy + (_info_y + 38) * _s + _text_dy, _status_txt);
    if (_seen){
        var _type_txt = "";
        if (!is_undefined(scr_poke_type_str)) _type_txt = scr_poke_type_str(_sid);
        var _lines = poke_index__wrap_lines(_type_txt, (_info_w - 12) * _s);
        for (var _li = 0; _li < min(2, array_length(_lines)); ++_li) draw_text(_ox + (_info_x + 6) * _s, _oy + (_info_y + 54 + _li * 12) * _s + _text_dy, _lines[_li]);
    }
    draw_text(_ox + (_info_x + 6) * _s, _oy + (_info_y + 92) * _s + _text_dy, "AREA");
}

function poke_index__draw_area_page(_pid, _S, _sid, _seen, _got, _ox, _oy, _s, _text_dy, _C_EDGE, _C_PANEL, _C_MAP){
    draw_set_color(_C_EDGE);
    draw_text(_ox + 14 * _s, _oy + 30 * _s + _text_dy, "AREA");
    draw_set_color(c_white);
    draw_text(_ox + 14 * _s, _oy + 44 * _s + _text_dy, "No." + string_format(_sid, 3, 0) + " " + poke_index__display_name(_sid, _seen));

    draw_set_color(_C_MAP);
    draw_rectangle(_ox + 14 * _s, _oy + 62 * _s, _ox + 226 * _s, _oy + 136 * _s, false);
    draw_set_color(_C_EDGE);
    draw_rectangle(_ox + 14 * _s - _s, _oy + 62 * _s - _s, _ox + 226 * _s + _s, _oy + 136 * _s + _s, true);

    draw_set_color(c_white);
    if (!_seen){
        draw_text(_ox + 24 * _s, _oy + 88 * _s + _text_dy, "Area unknown.");
        return;
    }

    var _locs = poke_index_locations_for_species(_sid);
    if (array_length(_locs) <= 0){
        draw_text(_ox + 24 * _s, _oy + 88 * _s + _text_dy, "No known wild area.");
        return;
    }
    var _max_rows = 5;
    for (var _i = 0; _i < min(_max_rows, array_length(_locs)); ++_i){
        var _loc = _locs[_i];
        var _txt = _loc.label;
        if (variable_struct_exists(_loc, "levels") && string_length(_loc.levels) > 0) _txt += " " + _loc.levels;
        draw_text(_ox + 22 * _s, _oy + (72 + _i * 12) * _s + _text_dy, _txt);
    }
}

function poke_index_draw_gui(_pid){
    var _gw = display_get_gui_width();
    var _gh = display_get_gui_height();
    poke_index_draw_gui_rect(_pid, 0, 0, _gw, _gh);
}

function poke_index_seen_count(_pid){
    var _S = poke_index_ensure(_pid);
    var _n = 0;
    for (var _i = 0; _i < array_length(_S.seen); ++_i) if (_S.seen[_i] == true) _n++;
    return _n;
}
