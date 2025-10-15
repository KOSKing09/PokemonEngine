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
        if (!variable_global_exists("POKEMON_SPECIES") || !ds_exists(POKEMON_SPECIES, ds_type_map)) POKEMON_SPECIES = ds_map_create();
        else ds_map_clear(POKEMON_SPECIES);
        for (var i = 0; i < array_length(global._pokemon); i++){
            var rec = global._pokemon[i];
            if (!is_struct(rec) || is_undefined(rec._id)) continue;
            ds_map_add(POKEMON_SPECIES, string(rec._id), rec);
        }
    }

    // POKEMON_MOVES: from global._moves
    if (variable_global_exists("_moves") && is_array(global._moves)){
        if (!variable_global_exists("POKEMON_MOVES") || !ds_exists(POKEMON_MOVES, ds_type_map)) POKEMON_MOVES = ds_map_create();
        else ds_map_clear(POKEMON_MOVES);
        for (var j = 0; j < array_length(global._moves); j++){
            var m = global._moves[j];
            if (!is_struct(m) || is_undefined(m.id)) continue;
            ds_map_add(POKEMON_MOVES, string(m.id), m);
        }
    }

    // TYPE_NAME -> id maps (TYPE_ID_BY_NAME) from any existing type lists
    if (variable_global_exists("_types") && is_array(global._types)){
        if (!variable_global_exists("TYPE_ID_BY_NAME") || !ds_exists(TYPE_ID_BY_NAME, ds_type_map)) TYPE_ID_BY_NAME = ds_map_create();
        else ds_map_clear(TYPE_ID_BY_NAME);
        for (var t = 0; t < array_length(global._types); t++){
            var tv = global._types[t];
            if (!is_struct(tv) || is_undefined(tv.id) || is_undefined(tv.identifier)) continue;
            ds_map_add(TYPE_ID_BY_NAME, string_lower(string(tv.identifier)), tv.id);
        }
    }

    // BATTLE_TYPES / BATTLE_TYPE_EFFICACY: best-effort if type efficacy table exists (global._type_efficacy)
    if (variable_global_exists("_type_efficacy") && is_array(global._type_efficacy)){
        if (!variable_global_exists("BATTLE_TYPE_EFFICACY") || !ds_exists(BATTLE_TYPE_EFFICACY, ds_type_map)) BATTLE_TYPE_EFFICACY = ds_map_create();
        else ds_map_clear(BATTLE_TYPE_EFFICACY);
        for (var e = 0; e < array_length(global._type_efficacy); e++){
            var row = global._type_efficacy[e];
            if (!is_struct(row) || is_undefined(row.attack) || is_undefined(row.defense) || is_undefined(row.mult)) continue;
            var key = string(row.attack) + ":" + string(row.defense);
            ds_map_add(BATTLE_TYPE_EFFICACY, key, row.mult);
        }
    }

    // Build simple name->id DS maps for verification probes
    if (!variable_global_exists("POKEMON_ID_BY_NAME") || !ds_exists(POKEMON_ID_BY_NAME, ds_type_map)) POKEMON_ID_BY_NAME = ds_map_create(); else ds_map_clear(POKEMON_ID_BY_NAME);
    if (!variable_global_exists("MOVE_ID_BY_NAME")    || !ds_exists(MOVE_ID_BY_NAME, ds_type_map))    MOVE_ID_BY_NAME    = ds_map_create(); else ds_map_clear(MOVE_ID_BY_NAME);

    // Fill POKEMON_ID_BY_NAME from global._pokemon
    if (variable_global_exists("_pokemon") && is_array(global._pokemon)){
        for (var _pi = 0; _pi < array_length(global._pokemon); _pi++){
            var pr = global._pokemon[_pi];
            if (!is_struct(pr) || is_undefined(pr._id) || is_undefined(pr.identifier)) continue;
            ds_map_add(POKEMON_ID_BY_NAME, string_lower(string(pr.identifier)), pr._id);
        }
    }

    // Fill MOVE_ID_BY_NAME from global._moves
    if (variable_global_exists("_moves") && is_array(global._moves)){
        for (var mi = 0; mi < array_length(global._moves); mi++){
            var mr = global._moves[mi];
            if (!is_struct(mr) || is_undefined(mr.id) || is_undefined(mr.identifier)) continue;
            ds_map_add(MOVE_ID_BY_NAME, string_lower(string(mr.identifier)), mr.id);
        }
    }

    // BATTLE_TYPES best-effort from TYPE_ID_BY_NAME
    if (variable_global_exists("TYPE_ID_BY_NAME") && ds_exists(TYPE_ID_BY_NAME, ds_type_map)){
        if (!variable_global_exists("BATTLE_TYPES") || !ds_exists(BATTLE_TYPES, ds_type_map)) BATTLE_TYPES = ds_map_create(); else ds_map_clear(BATTLE_TYPES);
        var _k = ds_map_find_first(TYPE_ID_BY_NAME);
        while (_k != undefined){
            var _v = ds_map_find_value(TYPE_ID_BY_NAME, _k);
            ds_map_add(BATTLE_TYPES, _k, _v);
            _k = ds_map_find_next(TYPE_ID_BY_NAME, _k);
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
    if (is_struct(mv) && variable_struct_exists(mv, "accuracy") && is_real(mv.accuracy)) {
        var mv_acc = real(mv.accuracy);
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
    if (is_struct(mv) && variable_struct_exists(mv, "pp") && is_real(mv.pp)) {
        return max(0, real(mv.pp));
    }
    return 0;
}

/// Base Power (0 for status / variable-power moves)
function scr_move_power_by_id(_mid) {
    var mv = (is_array(global._moves) && is_real(_mid) && _mid >= 0 && _mid < array_length(global._moves))
             ? global._moves[_mid] : undefined;
    if (is_struct(mv) && variable_struct_exists(mv, "power") && is_real(mv.power)) {
        var mv_pow = real(mv.power);
        return max(0, mv_pow);
    }
    return 0;
}

/// Type ID (returns -1 if unknown)
function scr_move_type_id_by_id(_mid) {
    var mv = (is_array(global._moves) && is_real(_mid) && _mid >= 0 && _mid < array_length(global._moves))
             ? global._moves[_mid] : undefined;
    if (is_struct(mv) && variable_struct_exists(mv, "type_id") && is_real(mv.type_id)) {
        return real(mv.type_id);
    }
    return -1;
}

/// Damage class ID (1=status, 2=physical, 3=special in most datasets)
function scr_move_damage_class_by_id(_mid) {
    var mv = (is_array(global._moves) && is_real(_mid) && _mid >= 0 && _mid < array_length(global._moves))
             ? global._moves[_mid] : undefined;
    if (is_struct(mv) && variable_struct_exists(mv, "damage_class_id") && is_real(mv.damage_class_id)) {
        return real(mv.damage_class_id);
    }
    return 0;
}

/// Priority (can be negative/positive; default 0)
function scr_move_priority_by_id(_mid) {
    var mv = (is_array(global._moves) && is_real(_mid) && _mid >= 0 && _mid < array_length(global._moves))
             ? global._moves[_mid] : undefined;
    if (is_struct(mv) && variable_struct_exists(mv, "priority") && is_real(mv.priority)) {
        return real(mv.priority);
    }
    return 0;
}
