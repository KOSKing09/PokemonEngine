// ============================================================================
// PokemonDemo_STRUCTS.gml  (no maps)
// - Seeds PARTY[pid].mons with real data using the struct-based index
// ============================================================================

/// scr_poke_runtime_demo_init_random(count=3)  — v2.0
/// Seeds PARTY[0] (and PARTY[1] if present) with COUNT random Pokémon.
/// Requires your index arrays (global._id_list / global._name_list) to be built.
function scr_poke_runtime_demo_init_random(_count)
{
    // default 3 mons
    var count = is_undefined(_count) ? 3 : max(1, _count);

    // Make sure index arrays exist (built by your index builder)
    if (!(variable_global_exists("_id_list") && is_array(global._id_list) && array_length(global._id_list) > 0)) {
        show_debug_message("[DEMO] _id_list missing or empty — build your index arrays first.");
        return;
    }
    if (!(variable_global_exists("_name_list") && is_array(global._name_list) && array_length(global._name_list) > 0)) {
        show_debug_message("[DEMO] _name_list missing or empty — build your index arrays first.");
        return;
    }

    // Seed both players if you’re running splitscreen later; always P0
    scr_party_debug_seed_random(0, count);

    if (instance_number(oPlayer) > 1) {
        scr_party_debug_seed_random(1, count);
    }
}

/// scr_party_debug_seed_random(pid, count) — v2.0
/// Pulls COUNT random species from _id_list/_name_list, builds basic stats, pushes into PARTY[pid].mons.
function scr_party_debug_seed_random(_pid, _count)
{
    var P = party_ensure(_pid);
    if (!is_array(P.mons)) P.mons = [];
    array_resize(P.mons, 0);

    // Distinct random picks from the index list
    var pool  = global._id_list;                // array of species IDs (sorted)
    var plen  = array_length(pool);
    var takes = min(_count, plen);

    // Simple unique selection without shuffling entire list
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

    // Build party entries
    for (var j = 0; j < array_length(chosen); j++) {
        var sid  = chosen[j];
        var name_ident = scr_poke_name_by_id(sid);                    // e.g., "bulbasaur"
        if (string_length(name_ident) <= 0) continue;

        // base stats (fallbacks if your helper isn’t ready)
        var st = is_undefined(scr_poke_stats) ? undefined : scr_poke_stats(sid);
        var base_hp  = (is_undefined(st) || is_undefined(st.hp))  ? 45 : st.hp;
        var base_atk = (is_undefined(st) || is_undefined(st.atk)) ? 49 : st.atk;
        var base_def = (is_undefined(st) || is_undefined(st.def)) ? 49 : st.def;
        var base_spa = (is_undefined(st) || is_undefined(st.spa)) ? 65 : st.spa;
        var base_spd = (is_undefined(st) || is_undefined(st.spd)) ? 65 : st.spd;
        var base_spe = (is_undefined(st) || is_undefined(st.spe)) ? 45 : st.spe;

        // Random-ish level each run
        var L = irandom_range(5, 18);

        // Calc basic stats (your demo calcs)
        var hpmax = (is_undefined(scr_poke_calc_hp))   ? (20 + L * 2) : scr_poke_calc_hp(base_hp, L);
        var atk   = (is_undefined(scr_poke_calc_stat)) ? (10 + L)     : scr_poke_calc_stat(base_atk, L);
        var def   = (is_undefined(scr_poke_calc_stat)) ? (10 + L)     : scr_poke_calc_stat(base_def, L);
        var spa   = (is_undefined(scr_poke_calc_stat)) ? (10 + L)     : scr_poke_calc_stat(base_spa, L);
        var spd   = (is_undefined(scr_poke_calc_stat)) ? (10 + L)     : scr_poke_calc_stat(base_spd, L);
        var spe   = (is_undefined(scr_poke_calc_stat)) ? (10 + L)     : scr_poke_calc_stat(base_spe, L);

        // Push mon entry (fields match your party UI expectations)
        array_push(P.mons, {
            species_id : sid,
            species    : name_ident,           // identifier string (lowercase-with-dashes)
            level      : L,                    // your party UI reads .level (and falls back to .lvl)
            hp         : hpmax,
            maxhp      : hpmax,
            atk        : atk,
            def        : def,
            spa        : spa,
            spd        : spd,
            spe        : spe,
            icon       : spr_mon_icon_placeholder // your placeholder 32x32 (2 frames)
        });
    }

    // Reset UI state, don’t auto-open
    P.sel = 0; P.scroll = 0; P.swap_index = -1; P.menu_sel = 0; P.lock = 0;
    show_debug_message("[DEMO] Seeded " + string(array_length(P.mons)) + " random Pokémon to PARTY[" + string(_pid) + "].");
}

