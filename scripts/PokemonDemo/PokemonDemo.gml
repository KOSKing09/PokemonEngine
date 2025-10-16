// [Pokémon Demo]: PokemonDemo_STRUCTS — Build v2.9 (NameSupport) — Updated 2025-10-06
// ============================================================================
// PokemonDemo_STRUCTS.gml  (no maps)
// - Seeds PARTY[pid].mons with real data using the struct-based index
// - Adds .name (canonical species name) and .nickname (optional) on every mon
// ============================================================================

/// (Local) demo_mon_ensure_name(_mon) -> _mon
/// Guarantees .name (canonical species name) and .nickname (may be undefined)
function demo_mon_ensure_name(_mon) {
    if (is_undefined(_mon)) return _mon;
    if (!variable_struct_exists(_mon, "nickname")) _mon.nickname = undefined;
    var __sid = -1;
    if (variable_struct_exists(_mon, "species_id") && is_real(_mon.species_id)) __sid = _mon.species_id;
    else if (variable_struct_exists(_mon, "id") && is_real(_mon.id)) __sid = _mon.id;
    if (!variable_struct_exists(_mon, "name") || !is_string(_mon.name) || string_length(_mon.name) <= 0) {
        _mon.name = (__sid > 0) ? scr_poke_name_by_id(__sid) : "???";
    }
    return _mon;
}

/// scr_poke_runtime_demo_init_random(count=3)  — v2.1 (NameSupport)
/// Seeds PARTY[0] (and PARTY[1] if present) with COUNT random Pokémon.
/// Requires your index arrays (global._id_list / global._name_list) to be built.
function scr_poke_runtime_demo_init_random(_count)
{
    var count = is_undefined(_count) ? 3 : max(1, _count);

    if (!(variable_global_exists("_id_list") && is_array(global._id_list) && array_length(global._id_list) > 0)) {
        show_debug_message("[DEMO] _id_list missing or empty — build your index arrays first.");
        return;
    }
    if (!(variable_global_exists("_name_list") && is_array(global._name_list) && array_length(global._name_list) > 0)) {
        show_debug_message("[DEMO] _name_list missing or empty — build your index arrays first.");
        return;
    }

    // Always seed random party entries first, then optionally overwrite specific slots
    // with forced species if `global.DEMO_FORCE_SPECIES` is defined. This keeps the
    // random flavour while allowing deterministic replacements for testing.
    scr_party_debug_seed_random(0, count);
    if (instance_number(oPlayer) > 1) scr_party_debug_seed_random(1, count);

    if (variable_global_exists("DEMO_FORCE_SPECIES") && is_array(global.DEMO_FORCE_SPECIES) && array_length(global.DEMO_FORCE_SPECIES) > 0){
        scr_party_demo_apply_forced(0);
        if (instance_number(oPlayer) > 1) scr_party_demo_apply_forced(1);
    }
}

/// scr_party_debug_seed_list(pid, species_array)
/// Seeds PARTY[pid] using the exact species ids provided in `species_array` (array of numeric ids).
function scr_party_debug_seed_list(_pid, _species_array){
    var P = party_ensure(_pid);
    if (!is_array(P.mons)) P.mons = [];
    array_resize(P.mons, 0);
    if (!is_array(_species_array) || array_length(_species_array) == 0) return;
    for (var i=0;i<array_length(_species_array);i++){
        var sid = floor(_species_array[i]);
        if (sid <= 0) continue;
        var L = irandom_range(5,18);
        var _demo_ot = variable_global_exists("PLAYER_NAME") ? string(global.PLAYER_NAME) : "YOU";
        if (_pid == 1 && variable_global_exists("PLAYER2_NAME")) _demo_ot = string(global.PLAYER2_NAME);
        var _factory_opts = { ot: _demo_ot, idno: sid, shiny: false, icon: spr_mon_icon_placeholder };
        var _mon_struct = pokemon_factory_create(sid, L, _factory_opts);
        _mon_struct = demo_mon_ensure_name(_mon_struct);
        party_model_add_mon(_pid, _mon_struct);
    }
    P.sel = 0; P.scroll = 0; P.swap_index = -1; P.menu_sel = 0; P.lock = 0;
    show_debug_message("[DEMO] Seeded " + string(array_length(P.mons)) + " forced Pokémon to PARTY[" + string(_pid) + "].");
}

/// scr_party_demo_apply_forced(pid)
/// Overwrites seeded party slots with species from global.DEMO_FORCE_SPECIES while
/// preserving the existing seeded level where possible.
function scr_party_demo_apply_forced(_pid){
    if (!variable_global_exists("DEMO_FORCE_SPECIES") || !is_array(global.DEMO_FORCE_SPECIES) || array_length(global.DEMO_FORCE_SPECIES) == 0) return;
    var P = party_ensure(_pid);
    if (!is_array(P.mons) || array_length(P.mons) == 0) return;
    var forced = global.DEMO_FORCE_SPECIES;
    for (var i=0; i<array_length(forced) && i<array_length(P.mons); i++){
        var sid = floor(forced[i]); if (sid <= 0) continue;
        // Preserve level from existing seeded mon if present; else pick random small level
        var prev = P.mons[i];
        var lvl = 5;
        if (is_struct(prev) && variable_struct_exists(prev, "level") && is_real(prev.level)) lvl = prev.level;
        else if (is_struct(prev) && variable_struct_exists(prev, "lvl") && is_real(prev.lvl)) lvl = prev.lvl;

        var _demo_ot = variable_global_exists("PLAYER_NAME") ? string(global.PLAYER_NAME) : "YOU";
        if (_pid == 1 && variable_global_exists("PLAYER2_NAME")) _demo_ot = string(global.PLAYER2_NAME);
        var _factory_opts = { ot: _demo_ot, idno: sid, shiny: false, icon: spr_mon_icon_placeholder };
        var newmon = pokemon_factory_create(sid, lvl, _factory_opts);
        newmon = demo_mon_ensure_name(newmon);
        // Replace slot
        P.mons[i] = newmon;
    }
    // persist back
    var __Ptmp = party_ensure(_pid); __Ptmp.mons = P.mons;
}


/// scr_party_debug_seed_random(pid, count) — v2.1 (NameSupport)
/// Pulls COUNT random species from _id_list/_name_list, builds basic stats, pushes into PARTY[pid].mons.
function scr_party_debug_seed_random(_pid, _count)
{
    var P = party_ensure(_pid);
    if (!is_array(P.mons)) P.mons = [];
    array_resize(P.mons, 0);

    var full_pool = global._id_list;
    var pool = [];
    for (var _pi = 0; _pi < array_length(full_pool); _pi++) {
        var _sid_chk = full_pool[_pi];
        if (_sid_chk >= 1 && _sid_chk <= 901) array_push(pool, _sid_chk);
    }
    var plen  = array_length(pool);
    var takes = min(_count, plen);

    var chosen = [];
    var guard  = 0;
    while (array_length(chosen) < takes && guard < 10000) {
        guard++;
        var idx = irandom(plen - 1);
        var sid = pool[idx];
        var dup = false;
        for (var i = 0; i < array_length(chosen); i++) if (chosen[i] == sid) { dup = true; break; }
        if (!dup) array_push(chosen, sid);
    }

    for (var j = 0; j < array_length(chosen); j++) {
        var sid  = chosen[j];
        var name_ident = scr_poke_name_by_id(sid);
        if (string_length(name_ident) <= 0) continue;

        var st = is_undefined(scr_poke_stats) ? undefined : scr_poke_stats(sid);
        var base_hp  = (is_undefined(st) || is_undefined(st.hp))  ? 45 : st.hp;
        var base_atk = (is_undefined(st) || is_undefined(st.atk)) ? 49 : st.atk;
        var base_def = (is_undefined(st) || is_undefined(st.def)) ? 49 : st.def;
        var base_spa = (is_undefined(st) || is_undefined(st.spa)) ? 65 : st.spa;
        var base_spd = (is_undefined(st) || is_undefined(st.spd)) ? 65 : st.spd;
        var base_spe = (is_undefined(st) || is_undefined(st.spe)) ? 45 : st.spe;

        var L = irandom_range(5, 18);

        var hpmax = (is_undefined(scr_poke_calc_hp))   ? (20 + L * 2) : scr_poke_calc_hp(base_hp, L);
        var atk   = (is_undefined(scr_poke_calc_stat)) ? (10 + L)     : scr_poke_calc_stat(base_atk, L);
        var def   = (is_undefined(scr_poke_calc_stat)) ? (10 + L)     : scr_poke_calc_stat(base_def, L);
        var spa   = (is_undefined(scr_poke_calc_stat)) ? (10 + L)     : scr_poke_calc_stat(base_spa, L);
        var spd   = (is_undefined(scr_poke_calc_stat)) ? (10 + L)     : scr_poke_calc_stat(base_spd, L);
        var spe   = (is_undefined(scr_poke_calc_stat)) ? (10 + L)     : scr_poke_calc_stat(base_spe, L);

        var _demo_ot = variable_global_exists("PLAYER_NAME") ? string(global.PLAYER_NAME) : "YOU";
        if (_pid == 1 && variable_global_exists("PLAYER2_NAME")) _demo_ot = string(global.PLAYER2_NAME);
        var _id_val  = sid;

        var _icon_spr = spr_mon_icon_placeholder;
        if (!is_undefined(pkicons_get_icon32_dir)) {
            var _tmp = pkicons_get_icon32_dir(sid, "down");
            if (is_undefined(_tmp) || !sprite_exists(_tmp)) _tmp = pkicons_get_icon32_dir(sid, "front");
            if (!is_undefined(_tmp) && sprite_exists(_tmp)) _icon_spr = _tmp;
        }

        var _t1 = -1, _t2 = -1; var _types_arr = [];
        if (variable_global_exists("_species_types") && is_array(global._species_types)) {
            if (sid < array_length(global._species_types)) {
                var __ta = global._species_types[sid];
                if (is_array(__ta)) {
                    if (array_length(__ta) > 0) _t1 = __ta[0];
                    if (array_length(__ta) > 1) _t2 = __ta[1];
                    for (var __i=0; __i<array_length(__ta); __i++) array_push(_types_arr, __ta[__i]);
                }
            }
        } else if (variable_global_exists("_pokemon") && is_array(global._pokemon)) {
            if (sid < array_length(global._pokemon)) {
                var __rec = global._pokemon[sid];
                if (is_struct(__rec)) {
                    if (variable_struct_exists(__rec,"type1")) _t1 = __rec.type1;
                    if (variable_struct_exists(__rec,"type2")) _t2 = __rec.type2;
                }
            }
            if (_t1 != -1) array_push(_types_arr,_t1);
            if (_t2 != -1) array_push(_types_arr,_t2);
        }
        if (array_length(_types_arr) == 0) { _t1 = 1; array_push(_types_arr, _t1); }

        // Build mon struct via factory to centralize creation logic
        var _factory_opts = { ot: _demo_ot, idno: _id_val, shiny: false, icon: _icon_spr };
        var _mon_struct = pokemon_factory_create(sid, L, _factory_opts);
        // Ensure names
        _mon_struct = demo_mon_ensure_name(_mon_struct);
        // Use model API to add mon
        party_model_add_mon(_pid, _mon_struct);
    }

    P.sel = 0; P.scroll = 0; P.swap_index = -1; P.menu_sel = 0; P.lock = 0;
    show_debug_message("[DEMO] Seeded " + string(array_length(P.mons)) + " random Pokémon to PARTY[" + string(_pid) + "].");

    var _mons_arr = party_model_get_mons(_pid);
    if (array_length(_mons_arr) > 0){
        var shiny_index = irandom(array_length(_mons_arr)-1);
        // mutate via direct struct access (shallow copy not required here)
        if (is_struct(_mons_arr[shiny_index])) _mons_arr[shiny_index].shiny = true;
        // persist back
        var _Ptmp = party_ensure(_pid); _Ptmp.mons = _mons_arr; 
        show_debug_message("[DEMO] Shiny assigned to party slot " + string(shiny_index));
    }

    var _party = party_ensure(_pid);
    if (is_array(_party.mons)) {
        for (var _i = 0; _i < array_length(_party.mons); _i++) {
            var _mon = _party.mons[_i];
            if (!is_struct(_mon)) continue;

            var _speciesId = _mon.species_id;
            var _level = is_undefined(_mon.level) ? (is_undefined(_mon.lvl) ? 5 : _mon.lvl) : _mon.level;

            var _abilityId = scr_poke_pick_ability(_speciesId, _speciesId * 1000 + _level);
            _mon.ability_id = _abilityId;
            _mon.ability    = scr_ability_name_by_id(_abilityId);

            var _moveIds = scr_poke_moves_upto_level(_speciesId, _level);
            if (array_length(_moveIds) > 4) {
                var _start = array_length(_moveIds) - 4;
                var _trim = [];
                for (var _j = _start; _j < array_length(_moveIds); _j++) array_push(_trim, _moveIds[_j]);
                _moveIds = _trim;
            }

            _mon.moves = _moveIds;

            var _named = [];
            for (var _k = 0; _k < array_length(_moveIds); _k++) {
                var _mid = _moveIds[_k];
                array_push(_named, { id:_mid, name:scr_move_name_by_id(_mid), desc:scr_move_desc_by_id(_mid) });
            }
            _mon.moves_named = _named;

            _mon.describe = scr_poke_describe(_speciesId, _level);

            // Ensure names again after enrichment (in case external loaders touched fields)
            _mon = demo_mon_ensure_name(_mon);
            // persist enriched mon back to the party via model array write
            var __mons_local = party_model_get_mons(_pid);
            if (is_array(__mons_local) && _i >= 0 && _i < array_length(__mons_local)) __mons_local[_i] = _mon;
            var __Ptmp = party_ensure(_pid); __Ptmp.mons = __mons_local;
        }
    }
}
