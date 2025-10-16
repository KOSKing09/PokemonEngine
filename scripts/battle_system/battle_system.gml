// [Battle] PokemonBattleSystem — Build v0.1.35 (rewards & flow)
// Updated 2025-10-11
// - NEW: Rewards — EXP on victory (b * L / 7), simple level-up (stubbed stat bumps)
// - NEW: Escape formula — probability scales with Speed and repeated attempts
// - NEW: Catch flow stub — success scales with foe HP% (for later Bag integration)
// -----------------------------------------------------------------------------
// - Keeps: wrap ellipsis, switch-in midpoint apply, cry-trigger grow, PID-aware input, no built-in `id` collisions
// -----------------------------------------------------------------------------
// CALLS you’ll use in objects:
//   battle_open(pid, wild_level);      // e.g., battle_open(0, irandom_range(5,18));
//   battle_update(pid);                // Step Event
//   battle_draw_gui(pid);              // Draw GUI Event
//   battle_close(pid);                 // when done
//   battle_switch_to(pid, party_index);// switch active mon with visuals (midpoint swap)
// -----------------------------------------------------------------------------


// Finalize catch handler: real implementation may live elsewhere. Provide a
// minimal guarded no-op so callers can safely invoke the symbol without the
// static analyzer flagging an undeclared symbol. Projects can override this
// by defining __battle_finalize_catch() in another script.
if (is_undefined(__battle_finalize_catch)){
    function __battle_finalize_catch(_B, _caught_struct){
        // Default: no-op. Implementations may play SFX, add the mon to party,
        // or open a 'caught' dialog. Keep conservative to avoid side-effects.
        return undefined;
    }
}

// Backwards-compatible stubs for legacy sound API names. Some runtimes
// expose `sound_play` / `sound_stop` while others expose `audio_*`.
// Provide safe no-op fallbacks so callers can call these symbols without
// causing static-analyzer undeclared-symbol errors or runtime exceptions.
if (is_undefined(sound_play)){
    function sound_play(_res){ /* no-op fallback */ return undefined; }
}
if (is_undefined(sound_stop)){
    function sound_stop(_res){ /* no-op fallback */ return undefined; }
}

// Minimal guarded stubs for animation function names. The full
// implementations live in `scripts/battle_system/battle_animations.gml`.
// Animation functions are implemented in scripts/battle_system/battle_animations.gml
// Do not declare these function names here to avoid duplicate script definitions.
// Animation functions are implemented in scripts/battle_system/battle_animations.gml
// They must exist exactly once; do not duplicate their definitions here.
// Animation implementations live in scripts/battle_animations/battle_animations.gml
// Provide a safe guarded stub for __battle_request_animation so callers
// can call it without checking for undefined in many places. If the
// project's real animation implementation exists (in
// `battle_animations.gml`) it will override this stub because we only
// define it when it's undefined.
if (is_undefined(__battle_request_animation)){
    function __battle_request_animation(_a, _spec){
        // Accept various calling conventions: (__pid, spec) or (actor, spec)
        try {
            var spec = _spec;
            var pid = undefined;
            // If first arg is a non-negative number, treat as pid
            if (is_real(_a) && _a >= 0) pid = _a;
            // If _a is a struct and contains a pid field, use it
            else if (is_struct(_a) && variable_struct_exists(_a, "pid") && is_real(variable_struct_get(_a, "pid"))) pid = variable_struct_get(_a, "pid");
            // If _a is a battle actor struct that belongs to a slot we can search sys_battles
            else if (is_struct(_a) && variable_struct_exists(_a, "_battle_pid") && is_real(variable_struct_get(_a, "_battle_pid"))) pid = variable_struct_get(_a, "_battle_pid");

            if (!is_undefined(pid)){
                var _B = __battle_ensure_slot(pid);
                if (is_struct(_B)){
                    try {
                        var _sa = (variable_struct_exists(_B, "sys_anim") ? variable_struct_get(_B, "sys_anim") : {});
                        var arr = (variable_struct_exists(_sa, "active") ? variable_struct_get(_sa, "active") : undefined);
                        if (!is_array(arr)) arr = [];
                        arr[array_length(arr)] = spec;
                        variable_struct_set(_sa, "active", arr);
                        variable_struct_set(_B, "sys_anim", _sa);
                        return true;
                    } catch (e_q) { /* fallthrough to no-op */ }
                }
            }
        } catch (e) { /* swallow errors to keep stub safe */ }
        return undefined;
    }
}

// Safe wrapper around __battle_request_animation that swallows errors when
// the underlying animation implementation is not present or fails. This
// avoids runtime crashes caused by guarded reads like
// `if (!is_undefined(__battle_request_animation)) ...` where the
// `is_undefined` check may attempt to read an instance variable.
function __battle_request_animation_safe(_a, _spec){
    try {
        return __battle_request_animation(_a, _spec);
    } catch (e) {
        // Swallow any error; animations are optional and non-critical
        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][anim] safe wrapper suppressed error: " + string(e));
        return undefined;
    }
}

// Per-battle temporary weather helpers. Weather is stored on the battle slot
// as _B._weather = { id: "sun"|"rain"|..., expires_turn: n, source: actor }
function __battle_set_weather(_pid, _wid, _duration_turns, _source_actor){
    var _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B)) return false;
    var w = { id: string(_wid), expires_turn: (is_real(_duration_turns) ? max(1, floor(_duration_turns)) : 5), source: undefined };
    if (is_struct(_source_actor)) variable_struct_set(w, "source", _source_actor);
    variable_struct_set(_B, "_weather", w);
    return true;
}

function __battle_get_weather(_pid){
    var _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B)) return undefined;
    return (variable_struct_exists(_B, "_weather") ? variable_struct_get(_B, "_weather") : undefined);
}

function __battle_clear_weather(_pid){
    var _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B)) return false;
    if (variable_struct_exists(_B, "_weather")) variable_struct_set(_B, "_weather", undefined);
    return true;
}

// Robust move-meta lookup helper. Tries several common lookup strategies
// (array indexed, string-keyed struct, 1-based fallback, and an optional
// `_move_meta_map`) and returns the found metadata struct or undefined.
function __battle_get_move_meta(_move_id){
    if (is_undefined(_move_id)) return undefined;
    if (!variable_global_exists("_move_meta")) return undefined;
    var mmc = global._move_meta;
    // Common: array indexed by move id (0-based)
    if (is_array(mmc) && is_real(_move_id) && _move_id >= 0 && _move_id < array_length(mmc)) return mmc[_move_id];
    // Common alternative: struct keyed by string move id
    var k = "" + string(_move_id);
    if (is_struct(mmc) && !is_undefined(mmc[k])) return mmc[k];
    // Fallback: some data sources are 1-based; try move_id-1 when in array
    if (is_array(mmc) && is_real(_move_id) && _move_id - 1 >= 0 && _move_id - 1 < array_length(mmc)) return mmc[_move_id - 1];
    // Optional auxiliary map
    if (variable_global_exists("_move_meta_map") && !is_undefined(global._move_meta_map)){
        var mm2 = undefined;
        if (is_array(global._move_meta_map) && is_real(_move_id) && _move_id >= 0 && _move_id < array_length(global._move_meta_map)) mm2 = global._move_meta_map[_move_id];
        else if (is_struct(global._move_meta_map) && !is_undefined(global._move_meta_map[k])) mm2 = global._move_meta_map[k];
        if (is_struct(mm2)) return mm2;
    }
    return undefined;
}

// Debug helper: prints surrounding entries of global._move_meta and the
// actor's stored moves to help diagnose indexing/shape mismatches.
function __battle_debug_move_meta(_pid, _move_id, _actor){
    if (!variable_global_exists("DATA_DEBUG") || !global.DATA_DEBUG) return;
    try {
        show_debug_message("[battle][dbgmeta] lookup move_id=" + string(_move_id) + " pid=" + string(_pid));
        if (is_struct(_actor) && variable_struct_exists(_actor, "moves")) show_debug_message("[battle][dbgmeta] actor.moves=" + string(variable_struct_get(_actor, "moves")));
        if (variable_global_exists("_move_meta") && is_array(global._move_meta)){
            var start = max(0, _move_id - 2);
            var end_i = min(array_length(global._move_meta) - 1, _move_id + 2);
            for (var ii = start; ii <= end_i; ++ii){
                show_debug_message("[battle][dbgmeta] _move_meta[" + string(ii) + "]=" + string(global._move_meta[ii]));
            }
        } else if (variable_global_exists("_move_meta") && is_struct(global._move_meta)){
            var kk = "" + string(_move_id);
            show_debug_message("[battle][dbgmeta] _move_meta struct has key? " + string(!is_undefined(global._move_meta[kk])));
            if (!is_undefined(global._move_meta[kk])) show_debug_message("[battle][dbgmeta] _move_meta[" + kk + "]=" + string(global._move_meta[kk]));
        } else {
            show_debug_message("[battle][dbgmeta] no global._move_meta present");
        }
    } catch (e_dbg){ show_debug_message("[battle][dbgmeta] failed: " + string(e_dbg)); }
}

// Centralized dispatcher to apply all move metadata effects.
// Handles: drain (life-leech), healing (user heal like Synthesis),
// flinch_chance, status/ailment (with chance & duration), stat_changes (with stat_chance),
// and provides debug logging. Called after damage resolution.
function __battle_apply_move_meta_effects(_pid, _step, A, D, move_id, dmg, mm){
    try {
        if (!is_struct(mm)) return undefined;
        var _B = __battle_ensure_slot(_pid);
    var msgs = [];
    // Whether this meta block involves HP changes/damage (drain/healing/dmg)
    var is_damage_meta = (is_real(dmg) && dmg > 0);

        // 1) Drain (leech from target's damage)
        var drain_raw = (variable_struct_exists(mm, "drain") ? variable_struct_get(mm, "drain") : 0);
        var drain_pct = __to_int_safe(drain_raw, 0);
    if (is_real(drain_pct) && drain_pct > 0 && dmg > 0){
            var heal_amount = max(1, floor(dmg * clamp(drain_pct / 100.0, 0, 1)));
            try {
                var before_hp = -1; var cap_hp = -1;
                if (variable_struct_exists(A, "hp_now")) before_hp = variable_struct_get(A, "hp_now"); else if (variable_struct_exists(A, "hp")) before_hp = variable_struct_get(A, "hp");
                if (variable_struct_exists(A, "hp_max")) cap_hp = variable_struct_get(A, "hp_max");
                var cap_hp = -1;
                if (variable_struct_exists(A, "hp_max")) cap_hp = variable_struct_get(A, "hp_max");
                else if (is_struct(A.mon) && variable_struct_exists(A.mon, "hp_max")) cap_hp = variable_struct_get(A.mon, "hp_max");
                if (is_real(cap_hp) && cap_hp > 0){
                    var newv = min(cap_hp, __battle_hp_now(A) + heal_amount);
                    __battle_set_hp_now(A, newv);
                }
                __battle_request_animation_safe(_pid, { type: "heal", target_index: (variable_struct_exists(_step, "actor_index") ? variable_struct_get(_step, "actor_index") : 0), amount: heal_amount });
                var after_hp = -1; if (variable_struct_exists(A, "hp_now")) after_hp = variable_struct_get(A, "hp_now"); else if (variable_struct_exists(A, "hp")) after_hp = variable_struct_get(A, "hp");
                    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][drain] move=" + string(move_id) + " healed " + string(heal_amount) + " to attacker=" + string((variable_struct_exists(A,"name")?variable_struct_get(A,"name"):"<no-name>")) + ", hp_before=" + string(before_hp) + ", hp_after=" + string(after_hp) + ", cap=" + string(cap_hp));
                    // Enqueue the heal as a deferred status dialog so it shows after the move dialog
                    try {
                        var aname = (variable_struct_exists(A, "name") ? variable_struct_get(A, "name") : "The Pokémon");
                        if (!is_undefined(__status_request_dialog_for_mon)) __status_request_dialog_for_mon(A, string(aname) + " restored HP!");
                    } catch (e_qh) { /* ignore */ }
                    // Mark that meta produced an actual effect for this battle slot
                    try { variable_struct_set(_B, "_meta_effect_applied", true); } catch (e_me) { }
            } catch (e_h) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][drain] failed to apply heal: " + string(e_h)); }
        }

        // 2) Direct healing (Synthesis-like) -- percent of user's max HP
        var healing_raw = (variable_struct_exists(mm, "healing") ? variable_struct_get(mm, "healing") : 0);
        var healing_pct = __to_int_safe(healing_raw, 0);
        if (is_real(healing_pct) && healing_pct > 0){
            try {
                var cap_hp2 = -1; var before_hp2 = -1;
                if (variable_struct_exists(A, "hp_max")) cap_hp2 = variable_struct_get(A, "hp_max"); else if (is_struct(A.mon) && variable_struct_exists(A.mon, "hp_max")) cap_hp2 = variable_struct_get(A.mon, "hp_max");
                if (variable_struct_exists(A, "hp_now")) before_hp2 = variable_struct_get(A, "hp_now"); else if (variable_struct_exists(A, "hp")) before_hp2 = variable_struct_get(A, "hp");
                if (is_real(cap_hp2) && cap_hp2 > 0){
                    var base_heal_amt = max(1, floor(cap_hp2 * clamp(healing_pct / 100.0, 0, 1)));
                    // Apply simple weather modifier: Sun boosts healing, Rain reduces it slightly
                    var _weather = __battle_get_weather(_pid);
                    var heal_amt = base_heal_amt;
                    if (is_struct(_weather) && variable_struct_exists(_weather, "id")){
                        var wid = variable_struct_get(_weather, "id");
                        switch (wid){
                            case "sun": heal_amt = max(1, floor(base_heal_amt * 1.5)); break;
                            case "harsh-sun": heal_amt = max(1, floor(base_heal_amt * 1.75)); break;
                            case "rain": heal_amt = max(1, floor(base_heal_amt * 0.75)); break;
                            default: heal_amt = base_heal_amt; break;
                        }
                    }
                    if (variable_struct_exists(A, "hp_now") && variable_struct_exists(A, "hp_max")){
                        var curh = variable_struct_get(A, "hp_now"); var caph = variable_struct_get(A, "hp_max"); var newh = min(caph, curh + heal_amt);
                        variable_struct_set(A, "hp_now", newh);
                        if (is_struct(A.mon)){
                            if (variable_struct_exists(A.mon, "hp")) variable_struct_set(A.mon, "hp", newh);
                            else if (variable_struct_exists(A.mon, "hp_now")) variable_struct_set(A.mon, "hp_now", newh);
                        }
                    } else if (variable_struct_exists(A, "hp") && variable_struct_exists(A, "hp_max")){
                        var curh2 = variable_struct_get(A, "hp"); var caph2 = variable_struct_get(A, "hp_max"); var newh2 = min(caph2, curh2 + heal_amt);
                        variable_struct_set(A, "hp", newh2);
                        if (is_struct(A.mon) && variable_struct_exists(A.mon, "hp")) variable_struct_set(A.mon, "hp", newh2);
                    }
                    __battle_request_animation_safe(_pid, { type: "heal", target_index: (variable_struct_exists(_step, "actor_index") ? variable_struct_get(_step, "actor_index") : 0), amount: heal_amt });
                    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][healing] move=" + string(move_id) + " healed " + string(heal_amt) + " to attacker=" + string((variable_struct_exists(A,"name")?variable_struct_get(A,"name"):"<no-name>")));
                    try {
                        var aname2 = (variable_struct_exists(A, "name") ? variable_struct_get(A, "name") : "The Pokémon");
                        if (!is_undefined(__status_request_dialog_for_mon)) __status_request_dialog_for_mon(A, string(aname2) + " restored HP!");
                    } catch (e_qh2) { /* ignore */ }
                    try { variable_struct_set(_B, "_meta_effect_applied", true); } catch (e_me2) { }
                }
            } catch (e_he){ if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][healing] failed: " + string(e_he)); }
        }

        // 2b) Field/weather changes declared in metadata: mm.weather (string id) and optional mm.weather_duration (turns)
        if (variable_struct_exists(mm, "weather")){
            try {
                var w = variable_struct_get(mm, "weather");
                var wd = (variable_struct_exists(mm, "weather_duration") ? __to_int_safe(variable_struct_get(mm, "weather_duration"), 5) : 5);
                if (string_length(string(w)) > 0){
                    __battle_set_weather(_pid, string(w), wd, A);
                    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][weather] move=" + string(move_id) + " set weather=" + string(w) + " dur=" + string(wd));
                    // Add dialog message for weather start
                    var wname = string(w);
                    switch (wname){
                        case "sun": try { if (!is_undefined(__status_request_dialog_for_mon)) __status_request_dialog_for_mon(A, "The sunlight is strong!"); } catch(e_){} break;
                        case "harsh-sun": try { if (!is_undefined(__status_request_dialog_for_mon)) __status_request_dialog_for_mon(A, "The harsh sunlight is raging!"); } catch(e_){} break;
                        case "rain": try { if (!is_undefined(__status_request_dialog_for_mon)) __status_request_dialog_for_mon(A, "It started to rain!"); } catch(e_){} break;
                        case "sandstorm": try { if (!is_undefined(__status_request_dialog_for_mon)) __status_request_dialog_for_mon(A, "A sandstorm kicked up!"); } catch(e_){} break;
                        case "hail": try { if (!is_undefined(__status_request_dialog_for_mon)) __status_request_dialog_for_mon(A, "Hail is falling!"); } catch(e_){} break;
                        default: try { if (!is_undefined(__status_request_dialog_for_mon)) __status_request_dialog_for_mon(A, string("The field changed: ") + wname); } catch(e_){} break;
                    }
                }
            } catch (ew) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][weather] failed to set weather: " + string(ew)); }
        }

        // 3) Flinch chance (apply a 'flinch' status for 1 turn)
        var flinch_raw = (variable_struct_exists(mm, "flinch_chance") ? variable_struct_get(mm, "flinch_chance") : 0);
        var flinch_pct = __to_int_safe(flinch_raw, 0);
        if (is_real(flinch_pct) && flinch_pct > 0 && dmg > 0){
            var rfl = irandom(99);
            if (rfl < clamp(flinch_pct, 0, 100)){
                    try {
                    var _fl_opts = {}; variable_struct_set(_fl_opts, "duration", 1); variable_struct_set(_fl_opts, "source", A); variable_struct_set(_fl_opts, "skip_dialog", true);
                    var okf = status_system_apply_status(D, "flinch", _fl_opts);
                    if (okf) {
                        __battle_request_animation_safe(_pid, { type: "status_inflict", target_index: (variable_struct_exists(_step, "target_index") ? variable_struct_get(_step, "target_index") : 1), status: "flinch" });
                        try { variable_struct_set(_B, "_meta_effect_applied", true); } catch (e_mef) { }
                    }
                    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][flinch] applied flinch to " + string((variable_struct_exists(D,"name")?variable_struct_get(D,"name"):"<no-name>")) + " roll=" + string(rfl) + ", pct=" + string(flinch_pct));
                    if (okf){
                            // For non-damage meta (flinch here is status-like), prefer enqueueing
                            // the status dialog and set the meta flag; avoid pushing to msgs to
                            // prevent duplicate immediate/pending messages.
                            try { variable_struct_set(_B, "_meta_effect_applied", true); } catch (e_mef2) { }
                        var dnamef = (variable_struct_exists(D, "name") ? variable_struct_get(D, "name") : "The target");
                        try { if (!is_undefined(__status_request_dialog_for_mon)) __status_request_dialog_for_mon(D, string(dnamef) + " flinched!"); } catch (e_fq) { /* ignore fallback to msgs */ }
                    }
                } catch (e_f) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][flinch] failed: " + string(e_f)); }
            }
        }

        // 4) Status/Ailment application (mm.status with chance & duration)
        try {
            if (is_struct(mm) && variable_struct_exists(mm, "status")){
                var sraw = variable_struct_get(mm, "status");
                var s = (is_string(sraw) ? string_trim(sraw) : "");
                var ch = 100;
                if (variable_struct_exists(mm, "chance")) ch = __to_int_safe(variable_struct_get(mm, "chance"), 100);
                else if (variable_struct_exists(mm, "ailment_chance")) ch = __to_int_safe(variable_struct_get(mm, "ailment_chance"), 100);
                // Some CSV exports put 0 for 'ailment_chance' meaning 'use default (100%)'.
                // Treat chance <= 0 as 100 so status-only moves (Sleep Powder / Spore) apply.
                if (!is_real(ch) || ch <= 0) ch = 100;
                var dur = -1; if (variable_struct_exists(mm, "duration")) dur = __to_int_safe(variable_struct_get(mm, "duration"), -1);

                // Attempt status application for moves that declare a status, even if dmg==0
                if (string_length(s) > 0){
                    var roll = irandom(99);
                    var willApply = (roll < clamp(ch, 0, 100));
                    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][meta] status_roll move=" + string(move_id) + " status=" + string(s) + " roll=" + string(roll) + " chance=" + string(ch) + " willApply=" + string(willApply));
                    if (willApply){
                        var applyTo = D;
                        if (variable_struct_exists(mm, "self") && variable_struct_get(mm, "self") == true) applyTo = A;
                        else if (variable_struct_exists(mm, "target") && string(variable_struct_get(mm, "target")) == "self") applyTo = A;
                        // If the target already has this status (on actor or inner mon), skip re-applying
                        var _already = false;
                        if (!is_undefined(status_system_has_status)){
                            try {
                                if (is_struct(applyTo) && status_system_has_status(applyTo, s)) _already = true;
                                else if (is_struct(applyTo) && variable_struct_exists(applyTo, "mon") && is_struct(variable_struct_get(applyTo, "mon")) && status_system_has_status(variable_struct_get(applyTo, "mon"), s)) _already = true;
                            } catch (e_as) { /* ignore */ }
                        }
                        if (_already){ if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][meta] skipping apply; target already has status=" + string(s)); continue; }
                        var _opts = {}; variable_struct_set(_opts, "source", A); if (is_real(dur) && dur > 0) variable_struct_set(_opts, "duration", dur);
                        // Defer the dialog to the battle message flow so ordering is consistent
                        variable_struct_set(_opts, "skip_dialog", true);
                        // Prevent the status from ticking immediately this same turn; start ticks from next turn
                        variable_struct_set(_opts, "skip_first_tick", true);
                        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][meta] applying status with skip_dialog=true: move_id=" + string(move_id) + ", status=" + string(s) + ", target=" + string(variable_struct_get(D, "name")));
                        var ok = false;
                        try {
                            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){
                                var _at_name = (variable_struct_exists(applyTo, "name") ? variable_struct_get(applyTo, "name") : "<no-name>");
                                var _at_sid = (variable_struct_exists(applyTo, "species_id") ? variable_struct_get(applyTo, "species_id") : (variable_struct_exists(applyTo, "species") ? variable_struct_get(applyTo, "species") : -1));
                                show_debug_message("[battle][meta] attempting status apply: move=" + string(move_id) + ", status=" + string(s) + ", target=" + string(_at_name) + "(sid=" + string(_at_sid) + ")");
                            }
                            if (!is_undefined(status_system_apply_status)) ok = status_system_apply_status(applyTo, s, _opts);
                            else { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][meta] status_system_apply_status not defined"); }
                        } catch (e_apply) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][meta] status apply threw: " + string(e_apply)); ok = false; }
                        // Fallback: some codebases store statuses on the inner `mon` struct. Try that too.
                        if (!ok && is_struct(applyTo) && variable_struct_exists(applyTo, "mon") && is_struct(variable_struct_get(applyTo, "mon"))){
                            try {
                                var mon_inner = variable_struct_get(applyTo, "mon");
                                if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][meta] fallback apply to inner mon: " + string(mon_inner));
                                ok = status_system_apply_status(mon_inner, s, _opts);
                            } catch (e_fallback) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][meta] fallback status apply threw: " + string(e_fallback)); ok = false; }
                        }
                        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][meta] status_system_apply_status returned " + string(ok) + " for status=" + string(s));
                        if (ok){
                            var target_index_for_anim = (applyTo == A ? (variable_struct_exists(_step, "actor_index") ? variable_struct_get(_step, "actor_index") : 0) : (variable_struct_exists(_step, "target_index") ? variable_struct_get(_step, "target_index") : 1));
                            __battle_request_animation_safe(_pid, { type: "status_inflict", target_index: target_index_for_anim, status: s });
                            // Do not enqueue or emit dialog here; the status system will request the dialog
                            // (and __status_request_dialog_for_mon enqueues into the battle slot when available).
                                try { variable_struct_set(_B, "_meta_effect_applied", true); } catch (e_mes) { }
                                // For certain side/team protection statuses, also enqueue a short
                                // Emerald-style message here in case the status_system didn't
                                // produce a pending dialog in time for the meta dispatch check.
                                try {
                                    var _s_l = string_lower(string(s));
                                    if (_s_l == "safeguard" || _s_l == "reflect" || _s_l == "light-screen" || _s_l == "mist"){
                                        var _dlg_target = applyTo;
                                        if (is_struct(applyTo) && variable_struct_exists(applyTo, "mon") && is_struct(variable_struct_get(applyTo, "mon"))) _dlg_target = variable_struct_get(applyTo, "mon");
                                        var _who = (variable_struct_exists(A, "name") ? variable_struct_get(A, "name") : "The Pokémon");
                                        var _msg = "";
                                        switch (_s_l){
                                            case "safeguard": _msg = string(_who) + " protected its team with Safeguard!"; break;
                                            case "reflect": _msg = "Reflect protected the team!"; break;
                                            case "light-screen": _msg = "Light Screen reduced damage to the team!"; break;
                                            case "mist": _msg = "Mist surrounds the team!"; break;
                                            default: _msg = string(_who) + " protected its team!"; break;
                                        }
                                        if (!is_undefined(__status_request_dialog_for_mon)) __status_request_dialog_for_mon(_dlg_target, _msg);
                                    }
                                } catch (e_qd) { /* ignore */ }
                        }
                    } else {
                        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][meta] status failed roll for move=" + string(move_id) + " status=" + string(s));
                    }
                }
            }
        } catch (e_stat) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][meta] status block error: " + string(e_stat)); }

        // 5) Stat changes (array 'stat_changes') with optional gating 'stat_chance'
        if (variable_struct_exists(mm, "stat_changes")){
            var stat_chance = (variable_struct_exists(mm, "stat_chance") ? __to_int_safe(variable_struct_get(mm, "stat_chance"), 100) : 100);
            var sc_arr = variable_struct_get(mm, "stat_changes");
            if (is_array(sc_arr)){
                for (var sxi = 0; sxi < array_length(sc_arr); ++sxi){
                    var sc = sc_arr[sxi];
                    if (!is_struct(sc) && !is_array(sc)) continue;
                    var sid = (is_struct(sc) ? variable_struct_get(sc, "stat_id") : sc[0]);
                    var delta = (is_struct(sc) ? variable_struct_get(sc, "change") : sc[1]);
                    if (!is_real(sid) || !is_real(delta)) continue;
                    // chance check per stat change
                    var rsc = irandom(99);
                    if (rsc >= clamp(stat_chance, 0, 100)) continue;
                    var key = undefined;
                    switch (sid){
                        case 2: key = "atk"; break;
                        case 3: key = "def"; break;
                        case 4: key = "spa"; break;
                        case 5: key = "spd"; break;
                        case 6: key = "spe"; break;
                        case 7: key = "accuracy"; break;
                        case 8: key = "evasion"; break;
                        default: key = undefined; break;
                    }
                    if (is_undefined(key)) continue;
                    var targetActor = (delta > 0 ? A : D);
                    // Debug: log stat change inputs so we can trace unexpected zero-applies
                    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){
                        var dbg_tn = (variable_struct_exists(targetActor, "name") ? variable_struct_get(targetActor, "name") : "<no-name>");
                        var prev_guess = 0;
                        if (variable_struct_exists(targetActor, "_stages") && is_struct(variable_struct_get(targetActor, "_stages"))){
                            var _sttmp = variable_struct_get(targetActor, "_stages");
                            if (variable_struct_exists(_sttmp, key)) prev_guess = variable_struct_get(_sttmp, key);
                        }
                        show_debug_message("[battle][stat_apply] move="+string(move_id)+", stat="+string(key)+", prev="+string(prev_guess)+", delta="+string(delta)+", target="+string(dbg_tn));
                    }
                    if (!variable_struct_exists(targetActor, "_stages") || !is_struct(variable_struct_get(targetActor, "_stages"))) variable_struct_set(targetActor, "_stages", {});
                    var st = variable_struct_get(targetActor, "_stages");
                    var prev = (variable_struct_exists(st, key) && is_real(variable_struct_get(st, key))) ? variable_struct_get(st, key) : 0;
                    var next = clamp(prev + delta, -6, 6);
                    variable_struct_set(st, key, next);
                    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){
                        show_debug_message("[battle][stat_apply] applied move="+string(move_id)+" key="+string(key)+" prev="+string(prev)+" delta="+string(delta)+" next="+string(next));
                    }
                    var targ_idx = (variable_struct_exists(_step, "target_index") ? variable_struct_get(_step, "target_index") : undefined);
                    if (targetActor == A) targ_idx = (variable_struct_exists(_step, "actor_index") ? variable_struct_get(_step, "actor_index") : 0);
                    __battle_request_animation_safe(_pid, { type: "stat_change", target_index: targ_idx, stat: key, from: prev, to: next });
                    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][stat] move=" + string(move_id) + " applied stat change " + string(sid) + " delta=" + string(delta) + " on " + string((targetActor==A) ? "attacker" : "target") + " newStage=" + string(next));
                    // Add a short dialog line like Emerald (e.g. "Foe's Attack fell!")
                    var targ_name_sc = (variable_struct_exists(targetActor, "name") ? variable_struct_get(targetActor, "name") : "The target");
                    var stat_readable = "";
                    switch (key){
                        case "atk": stat_readable = "Attack"; break;
                        case "def": stat_readable = "Defense"; break;
                        case "spa": stat_readable = "Sp. Atk"; break;
                        case "spd": stat_readable = "Sp. Def"; break;
                        case "spe": stat_readable = "Speed"; break;
                        case "accuracy": stat_readable = "Accuracy"; break;
                        case "evasion": stat_readable = "Evasion"; break;
                        default: stat_readable = key; break;
                    }
                    // Emerald-style concise stat message: "Pokemon DEF +1" (amount actually applied)
                    var applied_amount = next - prev;
                    var sign_amount = (applied_amount > 0) ? ("+" + string(applied_amount)) : string(applied_amount);
                    var stat_abbr = "";
                    switch (key){
                        case "atk": stat_abbr = "ATK"; break;
                        case "def": stat_abbr = "DEF"; break;
                        case "spa": stat_abbr = "SP.ATK"; break;
                        case "spd": stat_abbr = "SP.DEF"; break;
                        case "spe": stat_abbr = "SPD"; break;
                        case "accuracy": stat_abbr = "ACC"; break;
                        case "evasion": stat_abbr = "EVA"; break;
                        default: stat_abbr = string(key); break;
                    }
                    var applied_amount = next - prev;
                    var sc_msg = "";
                    if (applied_amount == 0){
                        // Already at cap/min, show a clear Emerald-style denial message
                        if (delta > 0) sc_msg = string(targ_name_sc) + "'s " + stat_abbr + " won't go any higher!";
                        else if (delta < 0) sc_msg = string(targ_name_sc) + "'s " + stat_abbr + " won't go any lower!";
                        else sc_msg = string(targ_name_sc) + "'s " + stat_abbr + " did not change.";
                    } else {
                        sc_msg = string(targ_name_sc) + " " + stat_abbr + " " + sign_amount;
                    }
                    // Prefer to enqueue as a post-move dialog so it shows after animations.
                            try {
                                if (!is_undefined(__status_request_dialog_for_mon)){
                                    // Attempt to find the inner mon struct (status system expects a mon)
                                    var _target_mon_ref = targetActor;
                                    if (is_struct(targetActor) && variable_struct_exists(targetActor, "mon") && is_struct(variable_struct_get(targetActor, "mon"))) _target_mon_ref = variable_struct_get(targetActor, "mon");
                                    __status_request_dialog_for_mon(_target_mon_ref, sc_msg);
                                    // mark that a stat-change effect occurred
                                    try { variable_struct_set(_B, "_meta_effect_applied", true); } catch (e_stm) { }
                                } else {
                                    msgs[array_length(msgs)] = sc_msg;
                                }
                            } catch (e_q) { msgs[array_length(msgs)] = sc_msg; }
                }
            }
        }

        // 6) Other meta fields (crit_rate, min/max turns/hits) are currently logged for visibility
        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){
            var cr = (variable_struct_exists(mm, "crit_rate") ? variable_struct_get(mm, "crit_rate") : undefined);
            if (!is_undefined(cr)) show_debug_message("[battle][meta] move=" + string(move_id) + " crit_rate=" + string(cr));
        }
    } catch (e_all) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][meta_dispatch] error: " + string(e_all)); }
        // Some metadata categories (for example: 13 => disable/imprison-like effects)
        // don't produce a textual return message but should still count as a real
        // meta effect for the purposes of "It had no effect." detection. If a
        // move only declares a meta_category without producing any other messages
        // we mark the battle slot so the caller won't show the denial text.
        try {
            if (is_struct(mm) && variable_struct_exists(mm, "meta_category")){
                // meta_category may be stored as string from CSV loaders; coerce to int
                var __mc_raw = variable_struct_get(mm, "meta_category");
                var __mc_val = (is_real(__mc_raw) ? __mc_raw : __to_int_safe(__mc_raw, -1));
                if (is_real(__mc_val)){
                    // category 13 (imprison-like) is a non-textual meta effect
                    if (__mc_val == 13){ try { variable_struct_set(_B, "_meta_effect_applied", true); } catch (e_mc) {} }
                    // category 10: Haze / clear stat changes — treat as a visible meta effect
                    // but enqueue a single Emerald-style dialog instead of returning it in msgs
                    else if (__mc_val == 10){
                        try { variable_struct_set(_B, "_meta_effect_applied", true); } catch (e_mc2) {}
                        try {
                            var _haze_msg = "All stat changes were eliminated!";
                            // enqueue once via status dialog helper (use attacker as discovery anchor)
                            if (!is_undefined(__status_request_dialog_for_mon)) __status_request_dialog_for_mon(A, _haze_msg);
                        } catch (e_hq) { /* ignore */ }
                        // Clear local msgs so we don't return a duplicate textual message
                        try { msgs = []; } catch (e_clear_msgs) { /* ignore */ }
                    }
                }
            }
        } catch (e_mc_all) { /* ignore */ }
    // Return any collected messages in a single newline-separated string (or undefined if none)
    try {
        if (is_array(msgs) && array_length(msgs) > 0){
            var out = "";
            for (var mi = 0; mi < array_length(msgs); ++mi){
                if (mi > 0) out += "\n";
                out += string(msgs[mi]);
            }
            return out;
        }
    } catch (e_ret){ if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][meta_dispatch] failed to build return msgs: " + string(e_ret)); }
    return undefined;
}

function __battle_ensure_slot(_pid){
    if (!variable_global_exists("sys_battles") || !is_array(global.sys_battles)) global.sys_battles = [];
    if (array_length(global.sys_battles) <= _pid) array_resize(global.sys_battles, _pid + 1);
    var _B = global.sys_battles[_pid];
    if (!is_struct(_B)) {
        // Provide a conservative default shape so static analyzers can resolve fields.
        _B = {
            sys_open: false,
            phase: "",
            phase_durs: {},
            phase_start_ms: 0,
            phase_progress: 0,
            _intro_completed: false,
            _pending_close: false,
            sys_ui: { menu: "root", selX:0, selY:0, msg_list: undefined },
            sys_anim: { active: [] },
            _bgm_handle: undefined,
            _defeated_handle: undefined
        };
        // store back into global container
        global.sys_battles[_pid] = _B;
    }
    return _B;
}
function battle_is_open(_pid){
    var _B = __battle_ensure_slot(_pid);
    return (_B.sys_open == true);
}

// Safe audio handle stop helper: try to stop a channel handle, otherwise fall back
function __battle_audio_stop_handle(_h){
    try {
        if (!is_undefined(audio_stop_sound) && !is_undefined(_h)){
            audio_stop_sound(_h);
            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][audio] stopped handle=" + string(_h));
        } else if (!is_undefined(audio_stop_all)){
            // Fallback when only a global-all stop is available
            audio_stop_all();
            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][audio] called audio_stop_all() as fallback");
        }
    } catch (e) {
        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][audio] stop_handle error: " + string(e));
    }
}

// Safe wrapper to play a sound resource using the best available runtime API.
// Returns an audio channel/handle when possible, otherwise undefined.
function __battle_sound_play_safe(_res){
    try {
        if (is_undefined(_res)) return undefined;
        // Prefer audio_play_sound (modern runtime) which may return a channel id.
        if (!is_undefined(audio_play_sound)){
            // For resources intended as BGM, callers may want looping; here we
            // default to loop=true when the resource name suggests bgm (caller
            // may still handle looping via audio APIs). Use loop=false by default
            // to be conservative unless caller previously set a loop handle.
            var _ret = undefined;
            try { _ret = audio_play_sound(_res, 1, true); } catch (e_ap) { try { _ret = audio_play_sound(_res, 1, false); } catch (e2) { _ret = undefined; } }
            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][audio] audio_play_sound called for res=" + string(_res) + " ret=" + string(_ret));
            return _ret;
        }
        // Fallback to legacy sound_play if present (no channel returned)
        if (!is_undefined(sound_play)){
            try { sound_play(_res); } catch (e_sp) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][audio] sound_play failed: " + string(e_sp)); }
            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][audio] sound_play called for res=" + string(_res));
            return undefined;
        }
        // Last resort: try audio_create_stream + audio_play_sound if available
        if (!is_undefined(audio_create_stream) && !is_undefined(audio_play_sound)){
            var stream = undefined;
            try { stream = audio_create_stream(_res); } catch (e_cs) { stream = undefined; }
            if (!is_undefined(stream)){
                var ch = undefined;
                try { ch = audio_play_sound(stream, 1, true); } catch (e_ch) { ch = undefined; }
                if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][audio] audio_create_stream+play returned " + string(ch));
                return ch;
            }
        }
    } catch (e) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][audio] __battle_sound_play_safe error: " + string(e)); }
    return undefined;
}

// Attempt to restore any previously saved audio for the battle slot.
// This is defensive: many platforms won't have previous audio captured; the
// function should silently no-op when no previous audio exists.
function __battle_restore_prev_audio(_pid){
    try {
        var _B = __battle_ensure_slot(_pid);
        if (!is_struct(_B)) return;
        var prev = (variable_struct_exists(_B, "_prev_audio") ? variable_struct_get(_B, "_prev_audio") : undefined);
        if (is_undefined(prev) || prev == undefined) return;
        // prev may be a resource id or a channel/handle depending on capture method.
        try {
            if (!is_undefined(audio_play_sound)){
                // Try to play previous resource as bgm (looped)
                try { audio_play_sound(prev, 1, true); if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][audio] restored prev audio res=" + string(prev)); } catch (e_apr) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][audio] audio_play_sound restore failed: " + string(e_apr)); }
            } else if (!is_undefined(sound_play)){
                try { sound_play(prev); if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][audio] restored prev audio via sound_play res=" + string(prev)); } catch (e_sp2) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][audio] sound_play restore failed: " + string(e_sp2)); }
            }
        } catch (e_inner) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][audio] failed to actually restore prev audio: " + string(e_inner)); }
    } catch (e) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][audio] __battle_restore_prev_audio error: " + string(e)); }
}

// ===== Open / Close =====
function battle_open(_a0, _a1){
    var _pid = 0, _wildLevel = 5;
    if (argument_count >= 2){ _pid = max(0, real(_a0)); _wildLevel = max(1, real(_a1)); }
    else if (argument_count == 1){ _pid = 0; _wildLevel = max(1, real(_a0)); }
    var _caller = noone;
    if (!is_undefined(player_by_pid)) {
        _caller = player_by_pid(_pid);
        if (_caller == noone) _caller = noone;
    }

    var _B = __battle_ensure_slot(_pid);
    if (_B.sys_open) return;

    _B.sys_open = true;
    _B.phase    = "transition_in";
    _B.turn     = 0;
    _B.result   = "ongoing";
    _B.sys_rng  = random_get_seed();

    _B.sys_ui   = { menu:"root", selX:0, selY:0, msg_list:ds_list_create() };
    _B.sys_anim = { active:[
        {anim_id:"idle",timer:0,duration:999999,offX:0,offY:0,scale:1},
        {anim_id:"idle",timer:0,duration:999999,offX:0,offY:0,scale:1}
    ]};
    _B.phase_start_ms = current_time;
    _B.phase_durs = { transition: 300, enemy: 400, call: 700, player: 400, switch_in: 600 };
    _B._intro_completed = false;

    // Music: configurable per-battle so we can change by region/area later
    // Default names (strings referencing sound resource names)
    // Default to the project's sound resource names; these should be declared in the resource tree
    // Default to the project's sound resource constants; override with globals if set
    _B._battle_music = (variable_global_exists("_BATTLE_MUSIC_OVERRIDE") ? variable_global_get("_BATTLE_MUSIC_OVERRIDE") : snd_WildPokemonBattle);
    _B._battle_defeated_music = (variable_global_exists("_BATTLE_DEFEATED_OVERRIDE") ? variable_global_get("_BATTLE_DEFEATED_OVERRIDE") : snd_WildPokemonDefeated);
    _B._bgm_handle = undefined;
    _B._defeated_handle = undefined;
    // Preserve any previously playing audio so we can restore it after the battle
    // NOTE: calling `audio_get_playing()` at early runtime (for example during
    // oPlayer Step) can trigger errors on some targets. Capture would be nice
    // but is non-critical; avoid calling it to prevent crashes and leave
    // previous-audio unset.
    _B._prev_audio = undefined;

    // Stop all other audio before starting battle music so nothing overlaps
    try { if (!is_undefined(audio_stop_all)) { audio_stop_all(); if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][audio] called audio_stop_all() before starting battle music"); } } catch (e_stop_all) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][audio] audio_stop_all() failed: " + string(e_stop_all)); }

    // Start background battle music (looped) if available
    if (!is_undefined(_B._battle_music)){
        try {
            var _bh = __battle_sound_play_safe(_B._battle_music);
            variable_struct_set(_B, "_bgm_handle", _bh);
            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][audio] played bgm="+string(_B._battle_music)+" handle="+string(_bh));
        } catch (e) { variable_struct_set(_B, "_bgm_handle", undefined); if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][audio] failed to play bgm="+string(_B._battle_music)); }
    }

    // Clear any leftover catch animation state from previous battles
    if (variable_struct_exists(_B, "_catch_anim")) _B._catch_anim = undefined;
    if (variable_struct_exists(_B, "_queued_catch")) _B._queued_catch = undefined;

    // Cry/switch state & turn queue
    _B._cry_played_enemy = false;
    _B._cry_played_player = false;
    _B._cry_play_start_ms_enemy = undefined;
    _B._cry_play_start_ms_player = undefined;
    _B._switch_target_idx = undefined;
    _B._switch_opts = undefined;
    _B._switch_applied = false;
    _B.phase_holds = { call: 3000 };
    _B._pending_close = false;

    // Turn queue container (filled when a move is chosen)
    _B.turn_queue = undefined;
    _B.turn_i = 0;
    _B.turn_action_player = undefined; // {slot, move_id}
    _B.turn_action_enemy  = undefined; // {slot, move_id}

    _B.theme = {
        col_bg:       make_color_rgb(184,224,200),
        col_outline:  make_color_rgb(72,88,80),
        col_panel:    make_color_rgb(208,232,224),
        col_hp_green: make_color_rgb(120,216,88),
        col_hp_yell:  make_color_rgb(248,208,56),
        col_hp_red:   make_color_rgb(232,72,56),
        col_text:     c_white
    };

    // Player actor from party
    var _P = party_ensure(_pid);
    var _mons = _P.mons;
    var _first = 0;
    for (var _i=0; _i<array_length(_mons); ++_i){
        var _m = _mons[_i];
        if (!is_undefined(_m) && is_struct(_m) && variable_struct_exists(_m,"hp") && _m.hp > 0){ _first = _i; break; }
    }
    var _pm = _mons[_first];

    _B.actor = [];
    _B.actor[0] = __battle_actor_from_party_mon(_pm);

    // Wild actor (1..901 only)
    var _sp = irandom_range(1, 901);
    _B.actor[1] = __battle_actor_from_species_level(_sp, _wildLevel);

    _B.caller = _caller;
    if (_B.caller != noone && instance_exists(_B.caller) && variable_instance_exists(_B.caller, "battleAnim")){
        var _tmpba = variable_instance_get(_B.caller, "battleAnim");
        if (is_real(_tmpba) && sprite_exists(_tmpba)) _B.caller_battleAnim = _tmpba;
        else _B.caller_battleAnim = undefined;
    } else if (variable_global_exists("battleAnim") && sprite_exists(variable_global_get("battleAnim"))){
        _B.caller_battleAnim = variable_global_get("battleAnim");
    } else {
        _B.caller_battleAnim = undefined;
    }

    // Diagnostic: log what battleAnim was detected on the caller (temporary)
    // debug removed

    if (!is_undefined(dialog2p_open_text)){
        var dlg_txt = "A wild " + string(_B.actor[1].name) + " has appeared!\n\nGo. " + string(_B.actor[0].name) + "!";
        dialog2p_open_text(_pid, dlg_txt);
        _B._dlg_active = true;
        _B._dlg_page_last = -1;
    } else {
        _B._dlg_active = false;
        _B._dlg_page_last = -1;
    }

    __battle_apply_party_moves(_B.actor[0]);   // use party's current moves/PP
    __battle_ensure_moves_from_levelup(_B.actor[1]); // wild

    global.sys_battles[_pid] = _B;
}
function battle_close(_pid){
    var _B = __battle_ensure_slot(_pid);
    if (is_struct(_B.sys_ui) && variable_struct_exists(_B.sys_ui, "msg_list")){
        if (ds_exists(_B.sys_ui.msg_list, ds_type_list)){
            ds_list_destroy(_B.sys_ui.msg_list);
        }
    }
    // Clear transient animation state to avoid bleed into subsequent battles
    if (variable_struct_exists(_B, "_catch_anim")) _B._catch_anim = undefined;
    if (variable_struct_exists(_B, "_queued_catch")) _B._queued_catch = undefined;
    // Stop any playing battle audio (add debug logs when enabled)
    try {
        var _bh_local = (variable_struct_exists(_B, "_bgm_handle") ? variable_struct_get(_B, "_bgm_handle") : undefined);
        if (!is_undefined(_bh_local)){
            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][audio] stopping bgm handle="+string(_bh_local));
            __battle_audio_stop_handle(_bh_local);
        }
    } catch (e1) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][audio] failed to stop bgm handle: " + string(e1)); }
    try {
        var _def_handle_local = (variable_struct_exists(_B, "_defeated_handle") ? variable_struct_get(_B, "_defeated_handle") : undefined);
        if (!is_undefined(_def_handle_local)){
            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][audio] stopping defeated handle="+string(_def_handle_local));
            __battle_audio_stop_handle(_def_handle_local);
        }
    } catch (e2) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][audio] failed to stop defeated handle: " + string(e2)); }
    try {
        var _bm_res = (variable_struct_exists(_B, "_battle_music") ? variable_struct_get(_B, "_battle_music") : undefined);
        if (!is_undefined(_bm_res)){
            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][audio] calling sound_stop on _battle_music");
            try { if (!is_undefined(sound_stop)) sound_stop(_bm_res); } catch (ee) {}
        }
        var _bdm = (variable_struct_exists(_B, "_battle_defeated_music") ? variable_struct_get(_B, "_battle_defeated_music") : undefined);
        if (!is_undefined(_bdm)){
            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][audio] calling sound_stop on _battle_defeated_music");
            try { if (!is_undefined(sound_stop)) sound_stop(_bdm); } catch (ee2) {}
        }
    } catch (e3) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][audio] failed to call sound_stop: " + string(e3)); }
    _B.sys_open = false;

    // Clear any temporary in-battle stat stages to ensure they don't persist
    try {
        if (is_array(_B.actor)){
            for (var _ai = 0; _ai < array_length(_B.actor); ++_ai){
                var _act = _B.actor[_ai];
                if (is_struct(_act) && variable_struct_exists(_act, "_stages")) variable_struct_set(_act, "_stages", undefined);
            }
        }
    } catch (e_clear) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][close] failed clearing stages: " + string(e_clear)); }

    // Clear any temporary per-battle weather state
    try { if (variable_struct_exists(_B, "_weather")) variable_struct_set(_B, "_weather", undefined); } catch (e_w) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][close] failed clearing weather: " + string(e_w)); }

    // Ensure the battle music (bgm) is stopped (use stored resource when possible)
    try {
        var _stop_bgm_res_local = (variable_struct_exists(_B, "_battle_music") ? variable_struct_get(_B, "_battle_music") : undefined);
        var _bh_local2 = (variable_struct_exists(_B, "_bgm_handle") ? variable_struct_get(_B, "_bgm_handle") : undefined);
        if (!is_undefined(_stop_bgm_res_local)){
            try {
                if (!is_undefined(audio_stop_sound)){
                    audio_stop_sound(_stop_bgm_res_local);
                    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][audio] audio_stop_sound called on battle_res=" + string(_stop_bgm_res_local));
                    } else if (!is_undefined(_bh_local2)){
                    __battle_audio_stop_handle(_bh_local2);
                    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][audio] __battle_audio_stop_handle called on bgm_handle=" + string(_bh_local2));
                } else if (!is_undefined(audio_stop_all)){
                    audio_stop_all();
                    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][audio] fallback audio_stop_all() called to stop battle music");
                }
            } catch (e_stop_b) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][audio] failed stopping battle music: " + string(e_stop_b)); }
        }
    } catch (e_b_all) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][audio] error while attempting to stop battle music: " + string(e_b_all)); }

    // Ensure the defeated/victory music is stopped (use stored resource when possible)
    try {
    var _stop_res = (variable_struct_exists(_B, "_battle_defeated_music") ? variable_struct_get(_B, "_battle_defeated_music") : undefined);
        if (!is_undefined(_stop_res)){
            try {
                if (!is_undefined(audio_stop_sound)){
                    audio_stop_sound(_stop_res);
                    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][audio] audio_stop_sound called on defeated_res=" + string(_stop_res));
                    } else if (!is_undefined(_def_handle_local)){
                    __battle_audio_stop_handle(_def_handle_local);
                    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][audio] __battle_audio_stop_handle called on defeated_handle=" + string(_def_handle_local));
                } else if (!is_undefined(audio_stop_all)){
                    audio_stop_all();
                    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][audio] fallback audio_stop_all() called to stop defeated music");
                }
            } catch (e_stop_d) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][audio] failed stopping defeated music: " + string(e_stop_d)); }
        }
    } catch (e_all_stop) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][audio] error while attempting to stop defeated music: " + string(e_all_stop)); }

    // Centralized restore: stop any battle audio and restore previously playing audio
    try { __battle_restore_prev_audio(_pid); } catch (e_rr) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][audio] __battle_restore_prev_audio failed: " + string(e_rr)); }
}

// ===== Update / Draw =====
function battle_update(_pid){
    if (!battle_is_open(_pid)) return;
    var _B = __battle_ensure_slot(_pid);

    // If the bag enqueued a catch request, process it here so the call stays inside battle code
    if (variable_struct_exists(_B, "_queued_catch")){
        var _q = variable_struct_get(_B, "_queued_catch");
        if (is_struct(_q) && variable_struct_exists(_q, "ball_mult")){
            if (!is_undefined(__battle_try_catch)){
                // Quiet: remove verbose queued-catch debug spam. Enable only when explicitly asked via DATA_DEBUG_VERBOSE.
                if (variable_global_exists("DATA_DEBUG_VERBOSE") && global.DATA_DEBUG_VERBOSE) show_debug_message("[battle][debug] processing queued catch pid=" + string(_pid) + ", iid=" + string((variable_struct_exists(_q, "item_id") ? variable_struct_get(_q, "item_id") : -1)) + ", mult=" + string(variable_struct_get(_q, "ball_mult")));
                __battle_try_catch(_pid, variable_struct_get(_q, "ball_mult"), (variable_struct_exists(_q, "item_id") ? variable_struct_get(_q, "item_id") : undefined));
            }
        }
        _B._queued_catch = undefined;
    }

    // Advance any active slot animations (catch animation, etc.)
    if (!is_undefined(__battle_update_animations)) __battle_update_animations(_pid);

    // If the Bag UI is open for this player, or a catch animation is active,
    // pause battle progression (turn resolution/input processing) so the
    // battle doesn't continue while the player is navigating the bag or
    // while a ball throw/impact/shake animation is underway.
    // Note: __battle_update_animations has already been called above so
    // catch animations will still advance.
    var _bag_open_here = (is_undefined(bag_is_open) ? false : bag_is_open(_pid));
    if (_bag_open_here) return;
    if (is_struct(_B) && variable_struct_exists(_B, "_catch_anim")){
        var _ca = variable_struct_get(_B, "_catch_anim");
        if (is_struct(_ca) && variable_struct_exists(_ca, "active") && _ca.active){
            // Allow progression if the animation is in a persistent 'caught' state
            // (we want the dialog/close flow to proceed). Otherwise, keep
            // animations running but don't progress the battle state.
            var _cphase = (variable_struct_exists(_ca, "phase") ? string(variable_struct_get(_ca, "phase")) : "");
            var _persist = (variable_struct_exists(_ca, "persistent") && variable_struct_get(_ca, "persistent"));
            if (!(_cphase == "caught" && _persist)){
                return;
            }
        }
    }

    // Detect phase entry and run on-enter actions once
    var _curr_phase = (variable_struct_exists(_B, "phase") ? string(_B.phase) : "");
    if (!variable_struct_exists(_B, "_last_phase") || string(_B._last_phase) != _curr_phase){
        if (!is_undefined(__battle_on_phase_enter)) __battle_on_phase_enter(_pid, _curr_phase);
        _B._last_phase = _curr_phase;
    }

    var dlg_open = (is_undefined(dialog2p_is_open) ? false : dialog2p_is_open(_pid));
    if (dlg_open){
        if (!is_undefined(dialog2p_update)) dialog2p_update(_pid);
        var d = global.DIALOG2P[_pid];
        var page = (is_struct(d) ? d.page_idx : 0);

        if (!variable_struct_exists(_B, "_dlg_page_last")) _B._dlg_page_last = -1;
        if (page != _B._dlg_page_last){
            var now = current_time;
            if (!variable_struct_exists(_B, "_intro_completed") || !_B._intro_completed){
                if (page == 0){
                    if (string(_B.phase) == "transition_in"){
                        _B.phase = "intro_enemy"; _B.phase_start_ms = now;
                    }
                } else if (page == 1){
                    _B.phase = "intro_call"; _B.phase_start_ms = now;
                }
            }
            _B._dlg_page_last = page;
        }

        var now2 = current_time;
        if (string(_B.phase) == "intro_enemy"){
            var dur_e = _B.phase_durs.enemy;
            var elapsed_e = now2 - (variable_struct_exists(_B,"phase_start_ms") ? _B.phase_start_ms : now2);
            _B.phase_progress = max(0, min(1, elapsed_e / max(1, dur_e)));
        } else if (string(_B.phase) == "intro_call"){
            var dur_c = _B.phase_durs.call;
            var elapsed_c = now2 - (variable_struct_exists(_B,"phase_start_ms") ? _B.phase_start_ms : now2);
            _B.phase_progress = max(0, min(1, elapsed_c / max(1, dur_c)));
        } else if (string(_B.phase) == "intro_player"){
            var dur_p = _B.phase_durs.player;
            var elapsed_p = now2 - (variable_struct_exists(_B,"phase_start_ms") ? _B.phase_start_ms : now2);
            _B.phase_progress = max(0, min(1, elapsed_p / max(1, dur_p)));
        }
        if (!is_undefined(__battle_check_play_cries)) __battle_check_play_cries(_pid);
        _B._dlg_active = true;
        return;
    }

    // If a dialog just closed
    if (variable_struct_exists(_B, "_dlg_active") && _B._dlg_active){
        var now3 = current_time;
        _B._dlg_active = false;
        _B._dlg_page_last = -1;
        // Small input-grace window: suppress accidental buffered inputs that
        // occurred while the dialog was open (e.g. the same button that
        // advanced/closed the dialog). This prevents immediate re-selection
        // of UI options right after dialog close.
        if (is_real(now3)) variable_struct_set(_B, "_input_grace_until", now3 + 180);
        if (_B.phase == "intro_call"){
            _B.phase = "intro_player"; _B.phase_start_ms = now3;
        } else if (_B._pending_close){
            _B._pending_close = false; battle_close(_pid); return;
        }
        // If some code deferred starting the turn until after dialog closed, do it now.
        if (variable_struct_exists(_B, "_defer_turn_until_no_dialog") && _B._defer_turn_until_no_dialog){
            _B._defer_turn_until_no_dialog = false;
            if (is_array(_B.turn_queue) && array_length(_B.turn_queue) > 0){
                _B.turn_i = (is_real(_B.turn_i) ? _B.turn_i : 0);
                _B.phase = "turn";
                return;
            }
        }
            // If any status messages were deferred (we applied status with skip_dialog=true),
            // show them now in-order before other pending flows so the player sees them.
            // However, do NOT show deferred status messages during intro/transition/switch
            // animations (the 'A wild X appeared! / Go!' sequence). Those intros already
            // show their own dialogs; presenting status messages during the intro can
            // be confusing. Defer until after the intro phases complete.
            var _skip_pending_show = false;
            try {
                var _phase_name = (variable_struct_exists(_B, "phase") ? string(_B.phase) : "");
                if (_phase_name == "transition_in" || _phase_name == "intro_enemy" || _phase_name == "intro_call" || _phase_name == "intro_player" || _phase_name == "switch_in") _skip_pending_show = true;
            } catch (e_ps) { _skip_pending_show = false; }
            if (!_skip_pending_show && variable_struct_exists(_B, "_pending_status_msgs") && is_array(variable_struct_get(_B, "_pending_status_msgs"))){
                var _ps = variable_struct_get(_B, "_pending_status_msgs");
                if (array_length(_ps) > 0){
                    var _m = _ps[0];
                    // pop first
                    var _new = [];
                    for (var _ii = 1; _ii < array_length(_ps); ++_ii) _new[array_length(_new)] = _ps[_ii];
                    variable_struct_set(_B, "_pending_status_msgs", _new);
                    try { __battle_stub_dialog(_pid, _m); } catch (e_p) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][pending_status] failed to show: " + string(e_p)); }
                    return;
                }
            }
        // If a pending item use was queued while the dialog was open (e.g. "You used a Poke Ball!"),
        // start the catch animation now that the dialog has closed.
        if (variable_struct_exists(_B, "_pending_item_use") && is_struct(variable_struct_get(_B, "_pending_item_use"))){
            var _pi_temp = variable_struct_get(_B, "_pending_item_use");
            var _iid_temp = (variable_struct_exists(_pi_temp, "item_id") ? variable_struct_get(_pi_temp, "item_id") : undefined);
            var _mult_temp = (variable_struct_exists(_pi_temp, "ball_mult") ? variable_struct_get(_pi_temp, "ball_mult") : undefined);
            if (!is_undefined(__battle_try_catch)) __battle_try_catch(_pid, _mult_temp, _iid_temp);
            _B._pending_item_use = undefined;
            // Let the animation run; __battle_step_turn_if_ready will pause execution while catch anim is active.
            return;
        }
        // If an EXP animation was paused waiting for the level-up dialog to close, resume it now.
        if (variable_struct_exists(_B, "_exp_anim")){
            var _Etmp = variable_struct_get(_B, "_exp_anim");
            if (is_struct(_Etmp) && variable_struct_exists(_Etmp, "waiting_for_dialog") && _Etmp.waiting_for_dialog){
                var _qtmp = (variable_struct_exists(_Etmp, "queue") ? variable_struct_get(_Etmp, "queue") : []);
                var _curIdx = (variable_struct_exists(_Etmp, "playing_index") ? floor(variable_struct_get(_Etmp, "playing_index")) : 0);
                var _nextIdx = _curIdx + 1;
                // Advance to next step if available, set its start time so interpolation resumes cleanly
                if (_nextIdx >= 0 && _nextIdx < array_length(_qtmp)){
                    var _nstep = _qtmp[_nextIdx];
                    _nstep.start_ms = current_time;
                    _qtmp[_nextIdx] = _nstep;
                    variable_struct_set(_Etmp, "queue", _qtmp);
                    variable_struct_set(_Etmp, "playing_index", _nextIdx);
                    variable_struct_set(_Etmp, "waiting_for_dialog", false);
                    // set current value to the new step's starting fraction so UI updates immediately
                    if (variable_struct_exists(_nstep, "from")) variable_struct_set(_Etmp, "cur", _nstep.from);
                    variable_struct_set(_B, "_exp_anim", _Etmp);
                } else {
                    // no next step: mark animation inactive
                    variable_struct_set(_Etmp, "active", false);
                    variable_struct_set(_Etmp, "waiting_for_dialog", false);
                    variable_struct_set(_B, "_exp_anim", _Etmp);
                }
            }
        }
        // don't reset menu during turn resolution
        // NOTE: previously we force-reset the root menu selection when
        // a dialog closed while in the command phase. That made the
        // selector jump back to FIGHT (0,0) after showing temporary
        // dialogs such as the Bag stub, causing accidental inputs.
        //
        // Keep the current menu/selection intact on dialog close so
        // the player returns to the same spot they had selected.
        // Individual code paths that need to force a reset should set
        // `_B.sys_ui.menu`/`selX`/`selY` explicitly.
    }

    // Phase timing (intros + switch)
    if (string(_B.phase) == "transition_in" || string(_B.phase) == "intro_enemy" || string(_B.phase) == "intro_call" || string(_B.phase) == "intro_player" || string(_B.phase) == "switch_in"){
        var now4 = current_time;
        var stage = string(_B.phase);
        var start = (variable_struct_exists(_B,"phase_start_ms") ? _B.phase_start_ms : now4);
        if (stage == "transition_in"){
            var dur = _B.phase_durs.transition;
            var elapsed = now4 - start;
            _B.phase_progress = max(0, min(1, elapsed / max(1,dur)));
            if (!is_undefined(__battle_check_play_cries)) __battle_check_play_cries(_pid);
            if (elapsed >= dur){ _B.phase = "intro_enemy"; _B.phase_start_ms = now4; } else return;
        }
        if (stage == "intro_enemy"){
            var dur2 = _B.phase_durs.enemy;
            var elapsed2 = now4 - start;
            _B.phase_progress = max(0, min(1, elapsed2 / max(1,dur2)));
            if (!is_undefined(__battle_check_play_cries)) __battle_check_play_cries(_pid);
            if (elapsed2 >= dur2){ _B.phase = "intro_call"; _B.phase_start_ms = now4; } else return;
        } else if (stage == "intro_call"){
            var dur3 = _B.phase_durs.call;
            var hold_ms = 0;
            if (variable_struct_exists(_B, "phase_holds") && variable_struct_exists(_B.phase_holds, "call")) hold_ms = max(0, real(_B.phase_holds.call));
            var elapsed3 = now4 - start;
            _B.phase_progress = max(0, min(1, elapsed3 / max(1,dur3)));
            if (!is_undefined(__battle_check_play_cries)) __battle_check_play_cries(_pid);
            if (elapsed3 >= dur3 + hold_ms){ _B.phase = "intro_player"; _B.phase_start_ms = now4; } else return;
        } else if (stage == "intro_player"){
            var dur4 = _B.phase_durs.player;
            var elapsed4 = now4 - start;
            _B.phase_progress = max(0, min(1, elapsed4 / max(1,dur4)));
            if (!is_undefined(__battle_check_play_cries)) __battle_check_play_cries(_pid);
            if (elapsed4 >= dur4){ _B.phase = "command"; _B._intro_completed = true; } else return;
        } else if (stage == "switch_in"){
            var dur5 = (_B.phase_durs.switch_in || 400);
            var elapsed5 = now4 - start;
            _B.phase_progress = max(0, min(1, elapsed5 / max(1,dur5)));
            if (_B.phase_progress >= 0.5 && (!variable_struct_exists(_B, "_switch_applied") || !_B._switch_applied)){
                var idx = (variable_struct_exists(_B, "_switch_target_idx") ? _B._switch_target_idx : undefined);
                var opts = (variable_struct_exists(_B, "_switch_opts") ? _B._switch_opts : {});
                var auto_apply = !(variable_struct_exists(opts, "auto_apply") && variable_struct_get(opts, "auto_apply") == false);
                if (auto_apply && !is_undefined(party_ensure) && !is_undefined(idx) && is_real(idx)){
                    var P = party_ensure(_pid);
                    if (is_array(P.mons) && idx >= 0 && idx < array_length(P.mons)){
                        _B.actor[0] = __battle_actor_from_party_mon(P.mons[idx]);
                    }
                }
                _B._switch_applied = true;
            }
            if (!is_undefined(__battle_check_play_cries)) __battle_check_play_cries(_pid);
            if (elapsed5 >= dur5){ _B.phase = "command"; } else return;
        }
        if (!is_undefined(__battle_check_play_cries)) __battle_check_play_cries(_pid);
    }

    // Turn resolution phase
    if (string(_B.phase) == "turn"){
        __battle_step_turn_if_ready(_pid);
        return;
    }

    // Command input
    __battle_process_input(_pid);
}

function battle_draw_gui(_pid){
    var _rect = __battle_view_rect_for_pid(_pid);
    if (is_array(_rect) && array_length(_rect) >= 4) {
        battle_draw_gui_rect(_pid, _rect[0], _rect[1], _rect[2], _rect[3]);
    }
}

function battle_draw_gui_rect(_pid, _rx, _ry, _rw, _rh){
    if (!battle_is_open(_pid)) return;
    var _B = __battle_ensure_slot(_pid);

    var _S  = max(1, min(floor(_rw / 240), floor(_rh / 160)));
    var _OX = _rx + (_rw - 240 * _S) div 2;
    var _OY = _ry + (_rh - 160 * _S) div 2;

    __bui_begin(_pid, _OX, _OY, 240*_S, 160*_S);

    if (variable_global_exists("FNT_POKEMON")) draw_set_font(global.FNT_POKEMON); else draw_set_font(-1);
    draw_set_color(c_white);

    draw_set_color(_B.theme.col_bg);
    draw_rectangle(__bxu(_pid,0), __byu(_pid,0), __bxu(_pid,240), __byu(_pid,160), false);

    __battle_draw_battlers(_pid, _B);

    __battle_enemy_box_rect(_pid, 16,16,112,40, _B.actor[1]);
    __battle_player_box_rect(_pid,112,104,128,48, _B.actor[0]);
    __battle_cmd_box_rect(_pid,   8,136,224,24,   _B.sys_ui.selX, _B.sys_ui.selY);

    // Draw any active battle animations (status icons, damage popups)
    if (!is_undefined(__battle_anim_draw)) __battle_anim_draw(_pid);

    if (string(_B.phase) == "transition_in"){
        var p = (variable_struct_exists(_B,"phase_progress") ? _B.phase_progress : 0);
        var alpha = 1 - max(0, min(1, p));
        draw_set_color(c_black);
        draw_set_alpha(alpha);
        draw_rectangle(__bxu(_pid,0), __byu(_pid,0), __bxu(_pid,240), __byu(_pid,160), false);
        draw_set_alpha(1);
    }

    // Draw any overlays that should appear above the UI (pokéball during catch animation)
    if (!is_undefined(__battle_draw_ball_overlay)) __battle_draw_ball_overlay(_pid, _B);

    __bui_end(_pid);
}

// ===== Input (PID-aware; keyboard fallback) =====
function __battle_pressed(_pid, _name){
    if (!is_undefined(controls_pressed)){
        var aliases, i;

        if (_name=="Left"){
            aliases = ["MoveLeft","Left","UILeft","DPadLeft"];
            for (i=0; i<array_length(aliases); ++i) if (controls_pressed(_pid, aliases[i])) return true;
        }
        if (_name=="Right"){
            aliases = ["MoveRight","Right","UIRight","DPadRight"];
            for (i=0; i<array_length(aliases); ++i) if (controls_pressed(_pid, aliases[i])) return true;
        }
        if (_name=="Up"){
            aliases = ["MoveUp","Up","UIUp","DPadUp"];
            for (i=0; i<array_length(aliases); ++i) if (controls_pressed(_pid, aliases[i])) return true;
        }
        if (_name=="Down"){
            aliases = ["MoveDown","Down","UIDown","DPadDown"];
            for (i=0; i<array_length(aliases); ++i) if (controls_pressed(_pid, aliases[i])) return true;
        }

        if (_name=="A"){
            aliases = ["A","Confirm","Accept","Interact","Select","ButtonA"];
            for (i=0; i<array_length(aliases); ++i) if (controls_pressed(_pid, aliases[i])) return true;
        }
        if (_name=="B"){
            aliases = ["B","Cancel","Back","Pause","ButtonB"];
            for (i=0; i<array_length(aliases); ++i) if (controls_pressed(_pid, aliases[i])) return true;
        }
    }

    if (_name=="Left")  return keyboard_check_pressed(vk_left);
    if (_name=="Right") return keyboard_check_pressed(vk_right);
    if (_name=="Up")    return keyboard_check_pressed(vk_up);
    if (_name=="Down")  return keyboard_check_pressed(vk_down);

    if (_name=="A") return (keyboard_check_pressed(vk_enter) || keyboard_check_pressed(vk_space) || keyboard_check_pressed(ord("Z")));
    if (_name=="B") return (keyboard_check_pressed(vk_escape) || keyboard_check_pressed(vk_backspace) || keyboard_check_pressed(ord("X")));

    return false;
}
function __battle_process_input(_pid){
    var _B = __battle_ensure_slot(_pid);
    // If the Bag or Party UI is open for this player, block battle input
    if ((is_undefined(bag_is_open) ? false : bag_is_open(_pid))) return;
    if ((is_undefined(party_is_open) ? false : party_is_open(_pid))) return;
    if (string(_B.phase) != "command") return;

    var _l = __battle_pressed(_pid,"Left");
    var _r = __battle_pressed(_pid,"Right");
    var _u = __battle_pressed(_pid,"Up");
    var _d = __battle_pressed(_pid,"Down");
    var _a = __battle_pressed(_pid,"A");
    var _b = __battle_pressed(_pid,"B");

    // If an input grace period is active for this battle slot, ignore these
    // pressed values so buffered inputs don't immediately trigger UI changes.
    var _nowt = (is_real(current_time) ? current_time : -1);
    if (is_struct(_B) && variable_struct_exists(_B, "_input_grace_until") && is_real(_nowt)){
        var _g = variable_struct_get(_B, "_input_grace_until");
        if (is_real(_g) && _nowt <= _g){
            _l = false; _r = false; _u = false; _d = false; _a = false; _b = false;
        }
    }

    // Block inputs while a catch animation is active (throw/impact/shake/resolve).
    // This prevents the player from advancing dialogs or switching menus mid-catch
    // which could cause the battle to close or jump out of the bag.
    if (is_struct(_B) && variable_struct_exists(_B, "_catch_anim")){
        var _catchA = variable_struct_get(_B, "_catch_anim");
        if (is_struct(_catchA) && variable_struct_exists(_catchA, "active") && variable_struct_get(_catchA, "active")){
            var _cphase = (variable_struct_exists(_catchA, "phase") ? string(variable_struct_get(_catchA, "phase")) : "");
            if (_cphase != "caught" && _cphase != "escape"){
                _l = false; _r = false; _u = false; _d = false; _a = false; _b = false;
            }
        }
    }

    if (_l) _B.sys_ui.selX = max(0, _B.sys_ui.selX - 1);
    if (_r) _B.sys_ui.selX = min(1, _B.sys_ui.selX + 1);
    if (_u) _B.sys_ui.selY = max(0, _B.sys_ui.selY - 1);
    if (_d) _B.sys_ui.selY = min(1, _B.sys_ui.selY + 1);

    var menu = string(_B.sys_ui.menu);
    var idx = _B.sys_ui.selX + _B.sys_ui.selY * 2;

    if (_b){
        if (menu == "fight"){
            // Return to root menu and restore previous root selection if available
            _B.sys_ui.menu = "root";
            if (is_struct(_B.sys_ui) && variable_struct_exists(_B.sys_ui, "_prev_root_selX") && variable_struct_exists(_B.sys_ui, "_prev_root_selY")){
                _B.sys_ui.selX = variable_struct_get(_B.sys_ui, "_prev_root_selX");
                _B.sys_ui.selY = variable_struct_get(_B.sys_ui, "_prev_root_selY");
            } else {
                _B.sys_ui.selX = 0; _B.sys_ui.selY = 0;
            }
        }
    }

    if (_a){
        if (menu == "root"){
            if (idx == 0){
                // Save the current root selection so we can restore it when returning
                if (is_struct(_B.sys_ui)){
                    variable_struct_set(_B.sys_ui, "_prev_root_selX", _B.sys_ui.selX);
                    variable_struct_set(_B.sys_ui, "_prev_root_selY", _B.sys_ui.selY);
                }
                _B.sys_ui.menu = "fight";
                _B.sys_ui.selX = 0; _B.sys_ui.selY = 0;
            }
            else if (idx == 1){
                // Open the bag UI in battle mode so player can Use/Give/Discard items
                // Save root selection before opening bag so it can be restored on return
                if (is_struct(_B.sys_ui)){
                    variable_struct_set(_B.sys_ui, "_prev_root_selX", _B.sys_ui.selX);
                    variable_struct_set(_B.sys_ui, "_prev_root_selY", _B.sys_ui.selY);
                }
                if (!is_undefined(bag_open_for_battle)) bag_open_for_battle(_pid);
            }
            else if (idx == 2){
                __battle_stub_dialog(_pid, "You checked your party.\n(TODO: switch Pokémon)");
            }
            else if (idx == 3){
                __battle_try_escape(_pid);
            }
        }
        else if (menu == "fight"){
            var move_idx = idx;
            var A = _B.actor[0];
            var mv = A.moves[move_idx];
            var pp = A.pps[move_idx];

            if (!is_real(mv) || mv < 0){
                // No move in that slot: show a message but still let the enemy act this turn.
                __battle_stub_dialog(_pid, "No move registered there.\n(Try another slot.)");
                _B.turn_action_player = undefined;
                _B.turn_action_enemy  = __battle_enemy_choose_action(_pid);
                _B.turn_queue = __battle_build_turn_actions(_pid);
                _B.turn_i = 0;
                _B.phase = "turn";
            } else if (pp <= 0){
                // No PP: inform player but still proceed with enemy action (player effectively skips this turn)
                __battle_stub_dialog(_pid, "There's no PP left for that move!\n(TODO: implement Struggle.)");
                _B.turn_action_player = undefined;
                _B.turn_action_enemy  = __battle_enemy_choose_action(_pid);
                _B.turn_queue = __battle_build_turn_actions(_pid);
                _B.turn_i = 0;
                _B.phase = "turn";
            } else {
                // Queue the player's choice and kick off the turn
                _B.turn_action_player = { slot: move_idx, move_id: mv };
                _B.turn_action_enemy  = __battle_enemy_choose_action(_pid); // {slot, move_id} or undefined
                _B.turn_queue = __battle_build_turn_actions(_pid);
                _B.turn_i = 0;
                _B.phase = "turn";
            }
        }
    }

}


// ===== Turn engine =====
function __battle_build_turn_actions(_pid){
    var _B = __battle_ensure_slot(_pid);
    var actions = [];

    var actP = _B.turn_action_player; // struct or undefined
    var actE = _B.turn_action_enemy;

    // If an enemy action wasn't preselected (some input paths may not set it), pick one now so
    // the CPU doesn't become inert when the player mis-presses unavailable options.
    if (!is_struct(actE)){
        actE = __battle_enemy_choose_action(_pid);
        // store back so subsequent logic or UI can inspect it if needed
        _B.turn_action_enemy = actE;
    }

    // Default targets: single-target to the opposite side
    if (is_struct(actP)){ variable_struct_set(actP, "actor_index", 0); variable_struct_set(actP, "target_index", 1); }
    if (is_struct(actE)){ variable_struct_set(actE, "actor_index", 1); variable_struct_set(actE, "target_index", 0); }

    // Determine order by Speed (tie-break: random)
    var spP = __battle_stat_get(_B.actor[0], "spd");
    var spE = __battle_stat_get(_B.actor[1], "spd");
    var firstEnemy = (spE > spP) || (spE == spP && choose(true,false));

    // If the player's action is an item_use (Poké Ball), force the player to act first
    // so the catch animation can run before the enemy acts. This allows the animation
    // to resolve (caught/escape) before enemy actions proceed.
    if (is_struct(actP) && variable_struct_exists(actP, "item_use") && variable_struct_get(actP, "item_use") == true){
        firstEnemy = false;
    }

    if (is_struct(actP) && is_struct(actE)){
        if (firstEnemy){ actions[0] = actE; actions[1] = actP; }
        else           { actions[0] = actP; actions[1] = actE; }
    } else if (is_struct(actP)){
        actions[0] = actP;
    } else if (is_struct(actE)){
        actions[0] = actE;
    }

    // Immediate-effects for certain moves (Protect-like moves should take effect
    // as soon as the action is queued so they can block attacks that occur later
    // in the same turn, regardless of move order).
    try {
        if (is_array(actions)){
            for (var ai = 0; ai < array_length(actions); ++ai){
                var act = actions[ai];
                if (!is_struct(act)) continue;
                var mid = (variable_struct_exists(act, "move_id") ? variable_struct_get(act, "move_id") : undefined);
                if (!is_real(mid)) continue;
                var mmq = undefined;
                try { mmq = __battle_get_move_meta(mid); } catch (e_mmq) { mmq = undefined; }
                if (is_struct(mmq) && variable_struct_exists(mmq, "protect") && variable_struct_get(mmq, "protect") == true){
                    // set on canonical battle actor (if exists) so checks during resolution see it
                    if (variable_struct_exists(_B, "actor") && is_array(variable_struct_get(_B, "actor"))){
                        var actorArr = variable_struct_get(_B, "actor");
                        var aidx = (variable_struct_exists(act, "actor_index") ? variable_struct_get(act, "actor_index") : undefined);
                        if (is_real(aidx) && aidx >= 0 && aidx < array_length(actorArr)){
                            var actRef = actorArr[aidx];
                            if (is_struct(actRef)){
                                variable_struct_set(actRef, "_protected", true);
                                // track whether we've shown the 'protected itself' announcement yet
                                variable_struct_set(actRef, "_protected_announce_shown", false);
                            }
                        }
                    }
                }
            }
        }
    } catch (e_immed) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][build_actions] immediate-effect apply failed: " + string(e_immed)); }

    return actions;
}
function __battle_step_turn_if_ready(_pid){
    var _B = __battle_ensure_slot(_pid);
    // DEBUG: report basic turn/actor state when stepping, but only when phase or turn_i changes
    // (debug removed)
    if (!is_struct(_B)) return;

    // If dialog is open, wait
    if (!is_undefined(dialog2p_is_open) && dialog2p_is_open(_pid)) return;

    // If a multi-hit sequence is pending (we showed the initial 'used' dialog),
    // process exactly one additional hit and show a short dialog, then return so
    // the player can close it before the next hit. This creates the Emerald-style
    // per-hit dramatic effect.
    if (variable_struct_exists(_B, "_pending_multi_hit") && is_struct(variable_struct_get(_B, "_pending_multi_hit"))){
        try {
            var pm = variable_struct_get(_B, "_pending_multi_hit");
            var mov = (variable_struct_exists(pm, "move_id") ? variable_struct_get(pm, "move_id") : undefined);
            var a_idx = (variable_struct_exists(pm, "actor_index") ? variable_struct_get(pm, "actor_index") : 0);
            var t_idx = (variable_struct_exists(pm, "target_index") ? variable_struct_get(pm, "target_index") : 1);
            var mv_power_local = (variable_struct_exists(pm, "mv_power") ? variable_struct_get(pm, "mv_power") : 0);
            var remaining = (variable_struct_exists(pm, "remaining") ? floor(variable_struct_get(pm, "remaining")) : 0);
            var Aact = (variable_struct_exists(_B, "actor") && is_array(variable_struct_get(_B, "actor")) ? variable_struct_get(_B, "actor")[a_idx] : undefined);
            var Dact = (variable_struct_exists(_B, "actor") && is_array(variable_struct_get(_B, "actor")) ? variable_struct_get(_B, "actor")[t_idx] : undefined);
            if (!is_struct(Aact) || !is_struct(Dact)){
                // clean up if actors missing
                variable_struct_set(_B, "_pending_multi_hit", undefined);
                return;
            }
            var res = __battle_apply_move_damage(_pid, t_idx, Aact, Dact, mov, mv_power_local);
            var dmg = res[0];
            // run meta dispatcher for this hit
            try { var mm_all = __battle_get_move_meta(mov); __battle_apply_move_meta_effects(_pid, {}, Aact, Dact, mov, dmg, mm_all); } catch (e_mh){ if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][pending_hit] meta error: " + string(e_mh)); }
            // show a short per-hit dialog
            var hitMsg = "It hit!";
            __battle_stub_dialog(_pid, hitMsg);
            // decrement remaining and persist or clear
            remaining = max(0, remaining - 1);
            if (remaining > 0){ variable_struct_set(pm, "remaining", remaining); variable_struct_set(_B, "_pending_multi_hit", pm); }
            else { variable_struct_set(_B, "_pending_multi_hit", undefined); }
        } catch (e_pending){ if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][pending_hit] error: " + string(e_pending)); }
        return;
    }

    // Nothing queued? return to command
    if (!is_array(_B.turn_queue) || array_length(_B.turn_queue) == 0){
        _B.phase = "command";
        // Reset status-tick guard so statuses will be ticked once on the next end-of-turn
        try { variable_struct_set(_B, "_statuses_ticked", false); } catch (e_tb) {}
        // Restore root menu selection if previously saved
        _B.sys_ui.menu = "root";
        if (is_struct(_B.sys_ui) && variable_struct_exists(_B.sys_ui, "_prev_root_selX") && variable_struct_exists(_B.sys_ui, "_prev_root_selY")){
            _B.sys_ui.selX = variable_struct_get(_B.sys_ui, "_prev_root_selX");
            _B.sys_ui.selY = variable_struct_get(_B.sys_ui, "_prev_root_selY");
        } else {
            _B.sys_ui.selX = 0; _B.sys_ui.selY = 0;
        }
        return;
    }

    // All actions processed?
    if (_B.turn_i >= array_length(_B.turn_queue)){
        // After the turn, tick statuses and then check win/lose
        // Ensure actor locals are defined safely before using them
        var A0 = undefined; var A1 = undefined;
        if (variable_struct_exists(_B, "actor")){
            var _acts_tmp = variable_struct_get(_B, "actor");
            if (is_array(_acts_tmp)){
                if (array_length(_acts_tmp) > 0) A0 = _acts_tmp[0];
                if (array_length(_acts_tmp) > 1) A1 = _acts_tmp[1];
            }
        }
        try {
            // Only tick statuses once for this end-of-turn. The battle loop may remain
            // in the 'end-of-turn' state while dialogs are shown, so without a guard
            // we would repeatedly apply status ticks each frame. Use a per-battle flag
            // so we apply ticks exactly once until the battle progresses.
            var _already = (variable_struct_exists(_B, "_statuses_ticked") ? variable_struct_get(_B, "_statuses_ticked") : false);
            if (!_already){
                // Tick statuses on both actors if status system is available
                if (!is_undefined(status_system_tick_statuses)){
                    if (is_struct(A0)) status_system_tick_statuses(A0, undefined);
                    if (is_struct(A1)) status_system_tick_statuses(A1, undefined);
                }
                // mark that we've ticked statuses for this end-of-turn so we don't repeat
                try { variable_struct_set(_B, "_statuses_ticked", true); } catch (e_st) {}
            }
        } catch (e_tick) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][status_tick] error: " + string(e_tick)); }

        // Process queued animations: we don't implement playback here but ensure the
        // animation queue exists so other systems can read it.
        try {
            if (variable_struct_exists(_B, "sys_anim") && is_struct(variable_struct_get(_B, "sys_anim"))){
                var _sa_local = variable_struct_get(_B, "sys_anim");
                var _actarr = (variable_struct_exists(_sa_local, "active") ? variable_struct_get(_sa_local, "active") : undefined);
                if (!is_array(_actarr)) { /* nothing to do */ }
                // note: playback is handled in battle_animations.gml / draw loop
            }
        } catch (e_anim) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][anim_queue] error: " + string(e_anim)); }

    // After ticking/animations, decrement per-turn weather durations and expire when necessary
    try {
        var _wt = __battle_get_weather(_pid);
        if (is_struct(_wt) && variable_struct_exists(_wt, "expires_turn")){
            var et = variable_struct_get(_wt, "expires_turn");
            if (is_real(et)){
                et = max(0, et - 1);
                variable_struct_set(_wt, "expires_turn", et);
                // ensure the battle slot sees the updated struct
                variable_struct_set(_B, "_weather", _wt);
                if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][weather] ticked weather=" + string(variable_struct_get(_wt, "id")) + " expires_turn=" + string(et));
                if (et <= 0){
                    var wid = (variable_struct_exists(_wt, "id") ? variable_struct_get(_wt, "id") : "<unknown>");
                    __battle_clear_weather(_pid);
                    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][weather] weather " + string(wid) + " expired and cleared");
                    __battle_request_animation_safe(_pid, { type: "weather_end", id: wid });
                    // Show a short dialog line for weather end using Emerald-style text
                    var endMsg = "";
                    switch (string(wid)){
                        case "sun": endMsg = "The sunlight faded."; break;
                        case "harsh-sun": endMsg = "The harsh sunlight subsided."; break;
                        case "rain": endMsg = "The rain stopped."; break;
                        case "sandstorm": endMsg = "The sandstorm subsided."; break;
                        case "hail": endMsg = "The hail stopped."; break;
                        default: endMsg = "The field returned to normal."; break;
                    }
                    try { __battle_stub_dialog(_pid, endMsg); } catch (e_msg) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][weather] failed to show end dialog: " + string(e_msg)); }
                }
            }
        }
    } catch (e_wt) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][weather] tick error: " + string(e_wt)); }

    // After ticking/animations, show any deferred status messages (applied during the turn)
    // before proceeding to win/lose checks. This ensures 'fell asleep!' / 'was poisoned!'
    // messages applied mid-turn are presented to the player at the end of the turn.
    try {
        if (variable_struct_exists(_B, "_pending_status_msgs") && is_array(variable_struct_get(_B, "_pending_status_msgs"))){
            var _psend = variable_struct_get(_B, "_pending_status_msgs");
            if (array_length(_psend) > 0){
                var _m = _psend[0];
                var _new = [];
                for (var _ii = 1; _ii < array_length(_psend); ++_ii) _new[array_length(_new)] = _psend[_ii];
                variable_struct_set(_B, "_pending_status_msgs", _new);
                try { __battle_stub_dialog(_pid, _m); } catch (e_pend) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][pending_status_endturn] failed to show: " + string(e_pend)); }
                return;
            }
        }
    } catch (e_ps) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][pending_status_endturn] error: " + string(e_ps)); }

    // After ticking/animations, check win/lose

        
if (is_struct(A1) && variable_struct_exists(A1, "hp_now") && variable_struct_get(A1, "hp_now") <= 0){
    // Compute EXP: floor(base_exp * enemy_level / 7)
    var base_exp = 50;
    var species_idx = undefined;
    if (variable_struct_exists(A1, "species")) species_idx = variable_struct_get(A1, "species");
    if (variable_global_exists("_pokemon") && is_array(global._pokemon) && is_real(species_idx) && species_idx >= 0 && species_idx < array_length(global._pokemon)){
        var _rec = global._pokemon[species_idx];
        if (is_struct(_rec) && variable_struct_exists(_rec, "_base_exp")){
            base_exp = max(1, real(_rec._base_exp));
        }
    }
    var level_val = (variable_struct_exists(A1, "level") ? variable_struct_get(A1, "level") : 1);
    var gain = floor((base_exp * max(1, level_val)) / 7);
    __battle_award_exp(_pid, gain);

    // Award EVs to participants (or fallback to active mon)
    // Determine EV yield from species master record when available
    var ev_yield = undefined;
    if (variable_global_exists("_pokemon") && is_array(global._pokemon) && is_real(species_idx) && species_idx >= 0 && species_idx < array_length(global._pokemon)){
        var _rec_ev = global._pokemon[species_idx];
        if (is_struct(_rec_ev)){
            if (variable_struct_exists(_rec_ev, "ev_yield") && is_struct(variable_struct_get(_rec_ev, "ev_yield"))) ev_yield = variable_struct_get(_rec_ev, "ev_yield");
            else if (variable_struct_exists(_rec_ev, "ev") && is_struct(variable_struct_get(_rec_ev, "ev"))) ev_yield = variable_struct_get(_rec_ev, "ev");
        }
    }
    // Fallback small EV if not defined
    if (!is_struct(ev_yield)) ev_yield = { hp:0, atk:1, def:0, spa:0, spd:0, spe:0 };

    // Build recipient list: prefer explicit _B._participants if available, otherwise active mon
    var recipients = [];
    if (variable_struct_exists(_B, "_participants") && is_array(variable_struct_get(_B, "_participants")) && array_length(variable_struct_get(_B, "_participants")) > 0){
        var P = party_ensure(_pid);
        var _parts = variable_struct_get(_B, "_participants");
        var _nparts = array_length(_parts);
        var _pi = 0;
        while (_pi < _nparts){
            var idx = _parts[_pi];
            if (is_array(P.mons) && idx >= 0 && idx < array_length(P.mons)){
                var cand = P.mons[idx];
                if (is_struct(cand) && __battle_hp_now(cand) > 0) array_push(recipients, cand);
            }
            _pi += 1;
        }
    }
    if (array_length(recipients) == 0){
        // fallback to active actor canonical mon
        var At = (is_struct(_B.actor[0]) && variable_struct_exists(_B.actor[0], "mon") && is_struct(_B.actor[0].mon)) ? _B.actor[0].mon : _B.actor[0];
        if (is_struct(At)) array_push(recipients, At);
    }

    // Apply EVs to each recipient (guarded call)
    var _ri = 0;
    while (_ri < array_length(recipients)){
        var rmon = recipients[_ri];
        if (!is_undefined(scr_award_ev_to_mon)){
            scr_award_ev_to_mon(rmon, ev_yield);
        }
        _ri += 1;
    }
    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][ev] awarded EVs to " + string(array_length(recipients)) + " recipients");

    _B.result = "win";
    // Stop battle BGM and play defeated loop if available
    try {
        if (!is_undefined(_B._bgm_handle)) __battle_audio_stop_handle(_B._bgm_handle);
    } catch (e_stop) {}
    _B._bgm_handle = undefined;
    try {
        var _def_res = (variable_struct_exists(_B, "_battle_defeated_music") ? variable_struct_get(_B, "_battle_defeated_music") : undefined);
    } catch (e_def) { var _def_res = undefined; }
    if (!is_undefined(_def_res)){
        // Check if battle music is playing and stop it with audio_stop_sound when available
        try {
            if (!is_undefined(audio_is_playing)){
                var _isPlaying = false;
                try {
                    var _tmp_bh = (variable_struct_exists(_B, "_bgm_handle") ? variable_struct_get(_B, "_bgm_handle") : undefined);
                    if (!is_undefined(_tmp_bh)) _isPlaying = audio_is_playing(_tmp_bh);
                    else {
                        var _tmp_res = (variable_struct_exists(_B, "_battle_music") ? variable_struct_get(_B, "_battle_music") : undefined);
                        if (!is_undefined(_tmp_res)) _isPlaying = audio_is_playing(_tmp_res);
                        else _isPlaying = false;
                    }
                } catch (e_ip) { _isPlaying = false; }
                    if (_isPlaying){
                        try {
                            // Store the sound resource to a local variable so audio_stop_sound() acts on the exact value
                            var _stop_res = (variable_struct_exists(_B, "_battle_music") ? variable_struct_get(_B, "_battle_music") : undefined);
                            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][audio] stopping _stop_res=" + string(_stop_res));
                            if (!is_undefined(audio_stop_sound) && !is_undefined(_stop_res)){
                                audio_stop_sound(_stop_res);
                                if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][audio] audio_stop_sound called on _stop_res");
                            } else {
                                var _bh = (variable_struct_exists(_B, "_bgm_handle") ? variable_struct_get(_B, "_bgm_handle") : undefined);
                                if (!is_undefined(_bh)){
                                    __battle_audio_stop_handle(_bh);
                                    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][audio] __battle_audio_stop_handle called on bgm_handle");
                                } else if (!is_undefined(audio_stop_all)){
                                    // As a final fallback, try stopping all audio.
                                    audio_stop_all();
                                    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][audio] audio_stop_all() fallback called to stop bgm");
                                }
                            }
                        } catch (e_s) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][audio] failed to stop bgm: " + string(e_s)); }
                    }
            }
        } catch (e_top) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][audio] error checking audio_is_playing: " + string(e_top)); }

        try {
            var _dh = __battle_sound_play_safe(_def_res);
            // store handle when available
            variable_struct_set(_B, "_defeated_handle", _dh);
            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][audio] played defeated_res="+string(_def_res)+" handle="+string(_dh));
        } catch (e) {
            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][audio] failed to play defeated_res="+string(_def_res)+" err="+string(e));
        }
    }
    _B._pending_close = true;
    _B.phase = "command";
    return;
}


        if (is_struct(A0) && variable_struct_exists(A0, "hp_now") && variable_struct_get(A0, "hp_now") <= 0){
            // Try to find another alive mon in party
            var idxNext = __party_find_next_alive(_pid);
            if (idxNext >= 0){
                var _name0 = (variable_struct_exists(A0, "name") ? variable_struct_get(A0, "name") : "Pokémon");
                __battle_stub_dialog(_pid, string(_name0) + " fainted!\n(TODO) Switch to another Pokémon.");
                // You can call battle_switch_to here automatically if desired:
                // battle_switch_to(_pid, idxNext, {});
            } else {
                var _name0b = (variable_struct_exists(A0, "name") ? variable_struct_get(A0, "name") : "Pokémon");
                __battle_stub_dialog(_pid, string(_name0b) + " fainted!\nYou blacked out...");
                _B.result = "lose";
                _B._pending_close = true;
            }
            _B.phase = "command";
            return;
        }

        // Neither side fainted: back to command
        _B.phase = "command";
        // Restore root menu selection if previously saved
        _B.sys_ui.menu = "root";
        if (is_struct(_B.sys_ui) && variable_struct_exists(_B.sys_ui, "_prev_root_selX") && variable_struct_exists(_B.sys_ui, "_prev_root_selY")){
            _B.sys_ui.selX = variable_struct_get(_B.sys_ui, "_prev_root_selX");
            _B.sys_ui.selY = variable_struct_get(_B.sys_ui, "_prev_root_selY");
        } else {
            _B.sys_ui.selX = 0; _B.sys_ui.selY = 0;
        }
        return;
    }

    // Skip actions by fainted actors
    var step = _B.turn_queue[_B.turn_i];
    if (!is_struct(step)){ _B.turn_i += 1; return; }

    // If we're at the start of a new turn (turn index 0), clear the status-tick guard
    // so statuses will be ticked at that turn's end. This ensures ticks happen once
    // per full turn rather than being suppressed across rounds.
    try { if (is_real(_B.turn_i) && _B.turn_i == 0) { variable_struct_set(_B, "_statuses_ticked", false); } } catch (e_stres) {}

    var actor_idx  = step.actor_index;
    var target_idx = step.target_index;

    if (actor_idx < 0 || actor_idx > 1 || target_idx < 0 || target_idx > 1){
        _B.turn_i += 1; return;
    }

    var A = _B.actor[actor_idx];
    var D = _B.actor[target_idx];

    if (!is_struct(A) || !is_struct(D)){
        _B.turn_i += 1; return;
    }

    // If acting Pokémon fainted already, skip (use canonical helper)
    if (__battle_is_fainted(A)){ _B.turn_i += 1; __battle_step_turn_if_ready(_pid); return; }

    // Perform the action -> returns a dialog string
    var out_msg = __battle_perform_action(_pid, step);

    // If the action was an item_use (e.g., Poké Ball) and it started a catch animation,
    // wait here until the animation resolves instead of advancing to the next action.
    if (is_struct(step) && variable_struct_exists(step, "item_use") && step.item_use == true){
        if (variable_struct_exists(_B, "_catch_anim")){
            var _ca = variable_struct_get(_B, "_catch_anim");
            if (is_struct(_ca) && variable_struct_exists(_ca, "active") && _ca.active){
                var _cphase = (variable_struct_exists(_ca, "phase") ? string(_ca.phase) : "");
                var _persist = (variable_struct_exists(_ca, "persistent") && _ca.persistent);
                if (!(_cphase == "caught" && _persist)){
                    // Don't advance turn_i; let battle_update loop (which also advances animations)
                    // detect the active animation and pause progression until it's done.
                    return;
                }
            }
        }
    }

    if (string_length(out_msg) <= 0){
        // No text? move on silently
        _B.turn_i += 1;
        __battle_step_turn_if_ready(_pid);
        return;
    }

    // Show the message; after dialog closes we'll continue with the next step
    __battle_stub_dialog(_pid, out_msg);
    _B.turn_i += 1;
}
function __battle_perform_action(_pid, _step){
    var _B = __battle_ensure_slot(_pid);
    var A = _B.actor[_step.actor_index];
    var D = _B.actor[_step.target_index];

    // Item-use action (e.g., Poké Ball) are represented as { item_use: true, item_id:..., ball_mult:... }
    // Handle them here by kicking off the catch flow and returning no dialog so the turn engine
    // continues to the next action (the enemy will still act if ordered to do so).
    if (is_struct(_step) && variable_struct_exists(_step, "item_use") && _step.item_use == true){
        var item_id = (variable_struct_exists(_step, "item_id") ? variable_struct_get(_step, "item_id") : undefined);
        var ball_mult = (variable_struct_exists(_step, "ball_mult") ? variable_struct_get(_step, "ball_mult") : undefined);
        // Defer the actual catch animation until after the 'used item' dialog closes.
        variable_struct_set(_B, "_pending_item_use", { item_id: item_id, ball_mult: ball_mult });
        // Build a friendly dialog message: try to obtain a display name for the item
        var disp = "item";
        if (!is_undefined(variable_global_exists) && variable_global_exists("_items") && is_array(global._items) && is_real(item_id) && item_id >= 0 && item_id < array_length(global._items)){
            var it = global._items[item_id];
            if (is_struct(it) && variable_struct_exists(it, "name")) disp = (is_undefined(bag__clean_display_name) ? string(variable_struct_get(it, "name")) : bag__clean_display_name(variable_struct_get(it, "name")));
        }
        var trainer = "You";
        if (!is_undefined(party_ensure)){
            var P = party_ensure(_pid);
            if (is_struct(P) && variable_struct_exists(P, "name") && string_length(string(variable_struct_get(P, "name"))) > 0) trainer = string(variable_struct_get(P, "name"));
            else if (variable_global_exists("PLAYER_NAME")) trainer = string(global.PLAYER_NAME);
        } else if (variable_global_exists("PLAYER_NAME")) trainer = string(global.PLAYER_NAME);
    // Choose correct indefinite article (a/an) by vowel sound heuristic on first letter
    var _first = (string_length(string(disp)) > 0) ? string_lower(string_copy(string(disp), 1, 1)) : "";
    var _article = (string_pos(_first, "aeiou") == 1) ? "an" : "a";
    return string(trainer) + " used " + string(_article) + " " + string(disp) + ".";
    }

    var move_slot = _step.slot;
    var move_id   = _step.move_id;

    // (debug removed)

    // Pre-action status checks: sleep/freeze/flinch/paralysis/confusion
    try {
        // Sleep / Freeze: prevent action if present
        if (!is_undefined(status_system_has_status)){
            // Debug: show whether actor or inner.mon has the status
            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){
                try {
                    // Basic booleans
                    var _a_actor_has = string(status_system_has_status(A, "sleep"));
                    var _a_inner_has = "n/a";
                    // Detailed instance & skip-first-tick diagnostics to detect canonicalization issues
                    var _a_actor_inst = "<undef>";
                    var _a_inner_inst = "<undef>";
                    var _a_actor_skip = "n/a";
                    var _a_inner_skip = "n/a";
                    var _pid_actor = "n/a";
                    if (is_struct(A) && variable_struct_exists(A, "mon") && is_struct(variable_struct_get(A, "mon"))) {
                        var _inner = variable_struct_get(A, "mon");
                        _a_inner_has = string(status_system_has_status(_inner, "sleep"));
                        var _inst_actor = undefined; var _inst_inner = undefined;
                        try { _inst_actor = status_system_get(A, "sleep"); } catch (e_a) { _inst_actor = undefined; }
                        try { _inst_inner = status_system_get(_inner, "sleep"); } catch (e_i) { _inst_inner = undefined; }
                        _a_actor_inst = (is_struct(_inst_actor) ? string(_inst_actor) : "<undef>");
                        _a_inner_inst = (is_struct(_inst_inner) ? string(_inst_inner) : "<undef>");
                        if (is_struct(_inst_actor) && variable_struct_exists(_inst_actor, "_skip_first_tick") && variable_struct_get(_inst_actor, "_skip_first_tick") == true) _a_actor_skip = "true";
                        if (is_struct(_inst_inner) && variable_struct_exists(_inst_inner, "_skip_first_tick") && variable_struct_get(_inst_inner, "_skip_first_tick") == true) _a_inner_skip = "true";
                        // battle pid discovery for both wrapper and inner
                        try { _pid_actor = string(__status_find_battle_pid(A)); } catch (e_pid) { _pid_actor = "err"; }
                    } else if (is_struct(A)){
                        var _inst_actor2 = undefined;
                        try { _inst_actor2 = status_system_get(A, "sleep"); } catch (e_a2) { _inst_actor2 = undefined; }
                        _a_actor_inst = (is_struct(_inst_actor2) ? string(_inst_actor2) : "<undef>");
                        if (is_struct(_inst_actor2) && variable_struct_exists(_inst_actor2, "_skip_first_tick") && variable_struct_get(_inst_actor2, "_skip_first_tick") == true) _a_actor_skip = "true";
                        try { _pid_actor = string(__status_find_battle_pid(A)); } catch (e_pid2) { _pid_actor = "err"; }
                    }
                    show_debug_message("[battle][precheck][dbg] checking sleep for actor='" + string((variable_struct_exists(A,"name")?variable_struct_get(A,"name"):"<no-name>")) + "' actor_has=" + string(_a_actor_has) + ", inner_has=" + string(_a_inner_has) + ", actor_inst=" + string(_a_actor_inst) + ", inner_inst=" + string(_a_inner_inst) + ", actor_skip=" + string(_a_actor_skip) + ", inner_skip=" + string(_a_inner_skip) + ", pid_discovered=" + string(_pid_actor));
                } catch (e_dbg2) {}
            }
            if (status_system_has_status(A, "sleep")){
                // If the sleep instance was applied this same turn, it set _skip_first_tick
                // to avoid immediate ticks and also to avoid re-announcing 'is asleep' immediately.
                var _sinst = (is_undefined(status_system_get) ? undefined : status_system_get(A, "sleep"));
                var _skipAnnounce = false;
                if (is_struct(_sinst) && variable_struct_exists(_sinst, "_skip_first_tick") && variable_struct_get(_sinst, "_skip_first_tick") == true) _skipAnnounce = true;
                if (!_skipAnnounce){
                    __battle_request_animation_safe(A, { type: "status_blocked", status: "sleep" });
                    return string(A.name) + " is asleep!";
                }
                // otherwise: skip the precheck announcement for freshly-applied sleep
            }
        }
        if (!is_undefined(status_system_has_status)){
            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){
                try {
                    var _f_actor_has = string(status_system_has_status(A, "freeze"));
                    var _f_inner_has = "n/a";
                    var _f_actor_inst = "<undef>"; var _f_inner_inst = "<undef>";
                    var _f_actor_skip = "n/a"; var _f_inner_skip = "n/a";
                    var _pid_f = "n/a";
                    if (is_struct(A) && variable_struct_exists(A, "mon") && is_struct(variable_struct_get(A, "mon"))){
                        var _innerf = variable_struct_get(A, "mon");
                        _f_inner_has = string(status_system_has_status(_innerf, "freeze"));
                        var _inst_fa = undefined; var _inst_fi = undefined;
                        try { _inst_fa = status_system_get(A, "freeze"); } catch (e_fa) { _inst_fa = undefined; }
                        try { _inst_fi = status_system_get(_innerf, "freeze"); } catch (e_fi) { _inst_fi = undefined; }
                        _f_actor_inst = (is_struct(_inst_fa) ? string(_inst_fa) : "<undef>");
                        _f_inner_inst = (is_struct(_inst_fi) ? string(_inst_fi) : "<undef>");
                        if (is_struct(_inst_fa) && variable_struct_exists(_inst_fa, "_skip_first_tick") && variable_struct_get(_inst_fa, "_skip_first_tick") == true) _f_actor_skip = "true";
                        if (is_struct(_inst_fi) && variable_struct_exists(_inst_fi, "_skip_first_tick") && variable_struct_get(_inst_fi, "_skip_first_tick") == true) _f_inner_skip = "true";
                        try { _pid_f = string(__status_find_battle_pid(A)); } catch (e_pidf) { _pid_f = "err"; }
                    } else if (is_struct(A)){
                        var _inst_fa2 = undefined;
                        try { _inst_fa2 = status_system_get(A, "freeze"); } catch (e_fa2) { _inst_fa2 = undefined; }
                        _f_actor_inst = (is_struct(_inst_fa2) ? string(_inst_fa2) : "<undef>");
                        if (is_struct(_inst_fa2) && variable_struct_exists(_inst_fa2, "_skip_first_tick") && variable_struct_get(_inst_fa2, "_skip_first_tick") == true) _f_actor_skip = "true";
                        try { _pid_f = string(__status_find_battle_pid(A)); } catch (e_pidf2) { _pid_f = "err"; }
                    }
                    show_debug_message("[battle][precheck][dbg] checking freeze for actor='" + string((variable_struct_exists(A,"name")?variable_struct_get(A,"name"):"<no-name>")) + "' actor_has=" + string(_f_actor_has) + ", inner_has=" + string(_f_inner_has) + ", actor_inst=" + string(_f_actor_inst) + ", inner_inst=" + string(_f_inner_inst) + ", actor_skip=" + string(_f_actor_skip) + ", inner_skip=" + string(_f_inner_skip) + ", pid_discovered=" + string(_pid_f));
                } catch (e_dbgf) {}
            }
            if (status_system_has_status(A, "freeze")){
                __battle_request_animation_safe(A, { type: "status_blocked", status: "freeze" });
                return string(A.name) + " is frozen solid!";
            }
        }
        // Paralysis: 25% chance to be unable to move
        if (!is_undefined(status_system_has_status) && status_system_has_status(A, "paralysis")){
            var rpar = irandom(99);
            if (rpar < 25){
                __battle_request_animation_safe(A, { type: "status_blocked", status: "paralysis" });
                return string(A.name) + " is paralyzed! It can't move!";
            }
        }
        // Flinch: if flinch status present, skip action (check actor and actor.mon)
        try {
            var _fl = false;
            if (!is_undefined(status_system_has_status)){
                if (is_struct(A) && status_system_has_status(A, "flinch")) _fl = true;
                else if (is_struct(A) && is_struct(A.mon) && status_system_has_status(A.mon, "flinch")) _fl = true;
            }
            if (_fl){
                __battle_request_animation_safe(A, { type: "status_blocked", status: "flinch" });
                return string(A.name) + " has flinched!";
            }
        } catch (e_flinch) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][flinch_precheck] error: " + string(e_flinch)); }
        // Confusion: 50% chance to hurt self (typical semantics)
        if (!is_undefined(status_system_has_status) && status_system_has_status(A, "confusion")){
            var rconf = irandom(99);
            if (rconf < 50){
                // self-inflicted damage: use a simple 40 power typeless self-hit calculation
                var dmg_res = __battle_apply_move_damage(_pid, _step.actor_index == 0 ? 0 : 1, A, A, -1, 40);
                var sdmg = dmg_res[0];
                __battle_request_animation_safe(A, { type: "confusion_hit", amount: sdmg });
                var txt = string(A.name) + " is confused and hurt itself!";
                return txt;
            }
        }
    } catch (e_stat) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][status_precheck] " + string(e_stat)); }

    // Safety + consume PP
    if (!__battle_consume_pp(A, move_slot)){
        return string(A.name) + " has no PP left!\n(TODO) Struggle.";
    }

    var mv_name = __battle_move_name(move_id);
    // If this move itself is a Protect-type move, announce protection for the user now
    try {
        var mm_prot = undefined;
        try { mm_prot = __battle_get_move_meta(move_id); } catch (e_pmeta) { mm_prot = undefined; }
        if (is_struct(mm_prot) && variable_struct_exists(mm_prot, "protect") && variable_struct_get(mm_prot, "protect") == true){
            // ensure canonical actor ref has the flag set
            try {
                var _B_local = __battle_ensure_slot(_pid);
                if (is_struct(_B_local) && is_array(_B_local.actor) && variable_struct_exists(_step, "actor_index")){
                    var aidx_local = variable_struct_get(_step, "actor_index");
                    if (is_real(aidx_local) && aidx_local >= 0 && aidx_local < array_length(_B_local.actor)){
                        var actRef2 = _B_local.actor[aidx_local];
                        if (is_struct(actRef2)){
                            variable_struct_set(actRef2, "_protected", true);
                            variable_struct_set(actRef2, "_protected_announce_shown", true); // we'll announce now
                        }
                    }
                }
            } catch (e_setprot){ if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][protect] immediate set failed: " + string(e_setprot)); }
            __battle_request_animation_safe(_pid, { type: "protect", target_index: (variable_struct_exists(_step, "actor_index") ? variable_struct_get(_step, "actor_index") : 0) });
            return string(A.name) + " protected itself!";
        }
    } catch (e_protchk) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][protect] check error: " + string(e_protchk)); }

    // If the target actor has protection set (from Protect/Detect), block the move immediately.
    try {
        if (is_struct(D) && variable_struct_exists(D, "_protected") && variable_struct_get(D, "_protected") == true){
            // only announce the blocked message the first time for this defender this turn
            var already_ann = (variable_struct_exists(D, "_protected_announce_shown") ? variable_struct_get(D, "_protected_announce_shown") : false);
            __battle_request_animation_safe(_pid, { type: "protected", target_index: (variable_struct_exists(_step, "target_index") ? variable_struct_get(_step, "target_index") : 1) });
            if (!already_ann){
                if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][protect] incoming move blocked by protection: move_id=" + string(move_id));
                variable_struct_set(D, "_protected_announce_shown", true);
                return string(A.name) + " used " + mv_name + "!\nBut " + string(variable_struct_exists(D,"name")?variable_struct_get(D,"name"):"The target") + " protected itself!";
            } else {
                // silently block without emitting duplicate dialog
                if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][protect] blocked silently (duplicate) move_id=" + string(move_id));
                return string(A.name) + " used " + mv_name + "!";
            }
        }
    } catch (e_protchk) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][protect] check error: " + string(e_protchk)); }
    // Hit roll
    if (!__battle_roll_hit(move_id)){
        return string(A.name) + " used " + mv_name + "!\nBut it missed!";
    }

    var mv_power = __battle_move_power(move_id);
    // Check for multi-hit meta (min_hits/max_hits). If present, loop that many times
    var hits = 1;
    try {
        var mm_chk = __battle_get_move_meta(move_id);
        if (is_struct(mm_chk)){
            var minh = (variable_struct_exists(mm_chk, "min_hits") ? variable_struct_get(mm_chk, "min_hits") : undefined);
            var maxh = (variable_struct_exists(mm_chk, "max_hits") ? variable_struct_get(mm_chk, "max_hits") : undefined);
            if (is_real(minh) && is_real(maxh) && maxh >= minh && minh > 0){ hits = irandom(maxh - minh) + minh; }
            else if (is_real(minh) && minh > 0) hits = minh;
            else if (is_real(maxh) && maxh > 0) hits = maxh;
        }
    } catch (e_mh){ if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][multihit] meta read error: " + string(e_mh)); }

    // Execute the first hit immediately and, if more hits remain, store the pending
    // multi-hit state on the battle slot so subsequent hits are processed one-by-one
    // by the update loop (player must close each "It hit!" dialog to continue).
    var performed_hits = 0; var total_dmg = 0; var last_before = -1; var last_after = -1;
    var res_first = undefined;
    if (is_real(mv_power) && mv_power > 0){
        // Normal damaging move
        res_first = __battle_apply_move_damage(_pid, _step.target_index, A, D, move_id, mv_power);
        var dmg_first = res_first[0]; last_before = res_first[1]; last_after = res_first[2]; total_dmg += dmg_first; performed_hits = 1;
        try { var mm_all_first = __battle_get_move_meta(move_id); __battle_apply_move_meta_effects(_pid, _step, A, D, move_id, dmg_first, mm_all_first); } catch (e_mf){ if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][meta_firsthit] error: " + string(e_mf)); }

        // If more hits are specified and target still alive, schedule the remaining hits
        if (hits > 1 && is_struct(D) && variable_struct_exists(D, "hp_now") && variable_struct_get(D, "hp_now") > 0){
            var remaining = hits - 1;
            var pm = { move_id: move_id, actor_index: _step.actor_index, target_index: _step.target_index, mv_power: mv_power, remaining: remaining };
            variable_struct_set(_B, "_pending_multi_hit", pm);
        }
    } else {
        // Status/stat-only move: do not apply damage but still dispatch meta effects
        res_first = [0, -1, -1];
        var dmg_first = 0; last_before = -1; last_after = -1; total_dmg = 0; performed_hits = 0;
        try { var mm_all_first2 = __battle_get_move_meta(move_id); __battle_apply_move_meta_effects(_pid, _step, A, D, move_id, dmg_first, mm_all_first2); } catch (e_mf2){ if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][meta_firsthit] (status-only) error: " + string(e_mf2)); }
    }

    var dmg = total_dmg; var before = last_before; var after = last_after;

    // Handle life-drain / leech effects declared in move metadata (drain percentage)
    try {
        var mm2 = __battle_get_move_meta(move_id);
        if (is_struct(mm2)){
            var drain_raw = (variable_struct_exists(mm2, "drain") ? variable_struct_get(mm2, "drain") : undefined);
            var drain_pct = __to_int_safe(drain_raw, 0);
            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][drain][debug] move_id=" + string(move_id) + ", mm_found=true, drain_raw=" + string(drain_raw) + ", drain_pct=" + string(drain_pct) + ", dmg=" + string(dmg));
            if (is_real(drain_pct) && drain_pct > 0 && dmg > 0){
                var heal_amount = max(1, floor(dmg * clamp(drain_pct / 100.0, 0, 1)));
                var before_hp = -1; var cap_hp = -1;
                if (variable_struct_exists(A, "hp_now")) before_hp = variable_struct_get(A, "hp_now");
                else if (variable_struct_exists(A, "hp")) before_hp = variable_struct_get(A, "hp");
                if (variable_struct_exists(A, "hp_max")) cap_hp = variable_struct_get(A, "hp_max");
                try {
                    if (variable_struct_exists(A, "hp_now") && variable_struct_exists(A, "hp_max")){
                        var cur = variable_struct_get(A, "hp_now"); var cap = variable_struct_get(A, "hp_max"); var newv = min(cap, cur + heal_amount);
                        variable_struct_set(A, "hp_now", newv);
                        if (is_struct(A.mon)){
                            if (variable_struct_exists(A.mon, "hp")) variable_struct_set(A.mon, "hp", newv);
                            else if (variable_struct_exists(A.mon, "hp_now")) variable_struct_set(A.mon, "hp_now", newv);
                        }
                    } else if (variable_struct_exists(A, "hp") && variable_struct_exists(A, "hp_max")){
                        var cur2 = variable_struct_get(A, "hp"); var cap2 = variable_struct_get(A, "hp_max"); var newv2 = min(cap2, cur2 + heal_amount);
                        variable_struct_set(A, "hp", newv2);
                        if (is_struct(A.mon) && variable_struct_exists(A.mon, "hp")) variable_struct_set(A.mon, "hp", newv2);
                    }
                    __battle_request_animation_safe(_pid, { type: "heal", target_index: _step.actor_index == 0 ? 0 : 1, amount: heal_amount });
                    var after_hp = -1; if (variable_struct_exists(A, "hp_now")) after_hp = variable_struct_get(A, "hp_now"); else if (variable_struct_exists(A, "hp")) after_hp = variable_struct_get(A, "hp");
                    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][drain] move=" + string(move_id) + " healed " + string(heal_amount) + " to attacker=" + string(A.name) + ", hp_before=" + string(before_hp) + ", hp_after=" + string(after_hp) + ", cap=" + string(cap_hp));
                } catch (e_h) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][drain] failed to apply heal: " + string(e_h)); }
            }
        } else {
            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){
                show_debug_message("[battle][drain][debug] move_id=" + string(move_id) + ", mm_found=false, running enhanced debug");
                __battle_debug_move_meta(_pid, move_id, A);
            }
        }
    } catch (e_d) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][drain] error: " + string(e_d)); }

        // Apply stat change meta (temporary stages) if present
        try {
            if (!is_undefined(global._move_meta) && !is_undefined(move_id)) {
                var mm3 = undefined;
                if (is_array(global._move_meta) && move_id >= 0 && move_id < array_length(global._move_meta)) {
                    mm3 = global._move_meta[move_id];
                } else if (is_struct(global._move_meta) && !is_undefined(global._move_meta["" + string(move_id)])) {
                    mm3 = global._move_meta["" + string(move_id)];
                }
                if (is_struct(mm3) && variable_struct_exists(mm3, "stat_changes")) {
                    var sc_arr = variable_struct_get(mm3, "stat_changes");
                    if (is_array(sc_arr)) {
                        for (var sc_i = 0; sc_i < array_length(sc_arr); sc_i++) {
                            var sc = sc_arr[sc_i];
                            if (!is_struct(sc) && !is_array(sc)) continue;
                            var sid = (is_struct(sc) ? variable_struct_get(sc, "stat_id") : sc[0]);
                            var delta = (is_struct(sc) ? variable_struct_get(sc, "change") : sc[1]);
                            if (!is_real(sid) || !is_real(delta)) continue;
                            // Map stat_id to key used for stages
                            var key = undefined;
                            switch (sid){
                                case 2: key = "atk"; break;
                                case 3: key = "def"; break;
                                case 4: key = "spa"; break;
                                case 5: key = "spd"; break;
                                case 6: key = "spe"; break;
                                case 7: key = "accuracy"; break;
                                case 8: key = "evasion"; break;
                                default: key = undefined; break;
                            }
                            if (is_undefined(key)) continue;
                            // Heuristic: positive changes -> attacker, negative -> target
                            var targetActor = (delta > 0 ? A : D);
                            // Ensure _stages struct exists on actor
                            if (!variable_struct_exists(targetActor, "_stages") || !is_struct(variable_struct_get(targetActor, "_stages"))) {
                                variable_struct_set(targetActor, "_stages", {});
                            }
                            var st = variable_struct_get(targetActor, "_stages");
                            var prev = (variable_struct_exists(st, key) && is_real(variable_struct_get(st, key))) ? variable_struct_get(st, key) : 0;
                            var next = clamp(prev + delta, -6, 6);
                            variable_struct_set(st, key, next);
                            // Request stat-change animation if available
                            if (!is_undefined(__battle_request_animation)) {
                                var targ_idx = (variable_struct_exists(_step, "target_index") ? variable_struct_get(_step, "target_index") : undefined);
                                // If change applied to attacker, use actor_index instead
                                if (targetActor == A) targ_idx = (variable_struct_exists(_step, "actor_index") ? variable_struct_get(_step, "actor_index") : 0);
                                __battle_request_animation_safe(_pid, { type: "stat_change", target_index: targ_idx, stat: key, from: prev, to: next });
                            }
                            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][stat] move=" + string(move_id) + " applied stat change " + string(sid) + " delta=" + string(delta) + " on " + string((targetActor==A) ? "attacker" : "target") + " newStage=" + string(next));
                        }
                    }
                }
            }
        } catch (e_sc) {
            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][stat] error: " + string(e_sc));
        }

    var extra = "";

    // Apply all meta effects via the centralized dispatcher. This covers
    // drain, healing, flinch, status ailments, and stat_changes.
    try {
        var mm_all = __battle_get_move_meta(move_id);
        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){
            show_debug_message("[battle][meta] dispatch move_id=" + string(move_id) + ", mm_exists=" + string(is_struct(mm_all)) + ", dmg=" + string(dmg));
            if (is_struct(mm_all)) show_debug_message("[battle][meta] mm=" + string(mm_all));
        }
        // Allow move meta to declare both a 'status' string and/or an 'ailment_id'.
        // Build an ordered list of status ids to attempt applying so moves that
        // specify multiple effects (e.g., custom CSVs) can apply them all.
        var _statuses_to_apply = [];
        if (is_struct(mm_all)){
            // primary mm.status (string)
            if (variable_struct_exists(mm_all, "status")){
                var _sval = variable_struct_get(mm_all, "status");
                if (is_string(_sval) && string_length(string(_sval)) > 0) _statuses_to_apply[array_length(_statuses_to_apply)] = string_trim(_sval);
            }
            // ailment_id mapping (legacy) — append if present
            if (variable_struct_exists(mm_all, "ailment_id")){
                var aid_try2 = variable_struct_get(mm_all, "ailment_id");
                var aid_map2 = {};
                variable_struct_set(aid_map2, "1", "paralysis");
                variable_struct_set(aid_map2, "2", "sleep");
                variable_struct_set(aid_map2, "3", "freeze");
                variable_struct_set(aid_map2, "4", "burn");
                variable_struct_set(aid_map2, "5", "poison");
                variable_struct_set(aid_map2, "6", "confusion");
                variable_struct_set(aid_map2, "7", "infatuation");
                variable_struct_set(aid_map2, "8", "trap");
                variable_struct_set(aid_map2, "12", "torment");
                variable_struct_set(aid_map2, "13", "disable");
                variable_struct_set(aid_map2, "14", "yawn");
                variable_struct_set(aid_map2, "18", "leech-seed");
                variable_struct_set(aid_map2, "19", "embargo");
                variable_struct_set(aid_map2, "20", "perish-song");
                variable_struct_set(aid_map2, "21", "ingrain");
                variable_struct_set(aid_map2, "24", "silence");
                var _keya2 = "" + string(aid_try2);
                var _mapped = undefined;
                try { _mapped = variable_struct_get(aid_map2, _keya2); } catch (e_map) { _mapped = undefined; }
                if (!is_undefined(_mapped) && is_string(_mapped) && string_length(_mapped) > 0){
                    _statuses_to_apply[array_length(_statuses_to_apply)] = _mapped;
                    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][meta] populated status list from ailment_id=" + string(aid_try2));
                }
            }
        }
        // If no statuses were derived, fall back to dispatching with mm_all unchanged
        var _meta_msg = undefined;
    // Reset and track pending-status/messages so we can tell if meta dispatch produced any visible effects
    try { variable_struct_set(_B, "_meta_effect_applied", false); } catch (e_metainit) { }
    var _pending_before = (variable_struct_exists(_B, "_pending_status_msgs") && is_array(variable_struct_get(_B, "_pending_status_msgs"))) ? array_length(variable_struct_get(_B, "_pending_status_msgs")) : 0;
        if (array_length(_statuses_to_apply) == 0) {
            _meta_msg = __battle_apply_move_meta_effects(_pid, _step, A, D, move_id, dmg, mm_all);
        } else {
            // Clone mm_all to safely iterate and per-status attempt apply while preserving mm_all for other meta
            var _base_mm = mm_all;
            // Attempt each status in sequence: create a per-status mm copy with only the status/duration/chance fields
            for (var _si = 0; _si < array_length(_statuses_to_apply); ++_si){
                var _statid = _statuses_to_apply[_si];
                try {
                    var _mm_copy = {};
                    // copy minimal fields used by __battle_apply_move_meta_effects
                    if (is_struct(_base_mm)){
                        if (variable_struct_exists(_base_mm, "chance")) variable_struct_set(_mm_copy, "chance", variable_struct_get(_base_mm, "chance"));
                        if (variable_struct_exists(_base_mm, "ailment_chance")) variable_struct_set(_mm_copy, "ailment_chance", variable_struct_get(_base_mm, "ailment_chance"));
                        if (variable_struct_exists(_base_mm, "duration")) variable_struct_set(_mm_copy, "duration", variable_struct_get(_base_mm, "duration"));
                    }
                    variable_struct_set(_mm_copy, "status", _statid);
                    // dispatch meta for this status only (drain/heal already handled earlier)
                    var _msg_part = __battle_apply_move_meta_effects(_pid, _step, A, D, move_id, dmg, _mm_copy);
                    if (is_string(_msg_part) && string_length(_msg_part) > 0){ if (is_undefined(_meta_msg)) _meta_msg = _msg_part; else _meta_msg = string(_meta_msg) + "\n" + string(_msg_part); }
                } catch (e_statapp){ if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][meta] per-status apply failed: " + string(e_statapp)); }
            }
        }
        var _pending_after = (variable_struct_exists(_B, "_pending_status_msgs") && is_array(variable_struct_get(_B, "_pending_status_msgs"))) ? array_length(variable_struct_get(_B, "_pending_status_msgs")) : 0;
        var _meta_enqueued_pending = (_pending_after > _pending_before);
            // Extra safeguard: if we attempted per-status applies, also check the status
            // system to see whether any of the requested statuses are now present on
            // either actor or defender (or their inner mon). This detects cases where
            // applying the status succeeded but the pending-queue check missed it.
            try {
                if (!_meta_enqueued_pending && is_array(_statuses_to_apply) && array_length(_statuses_to_apply) > 0 && !is_undefined(status_system_has_status)){
                    for (var _tsi = 0; _tsi < array_length(_statuses_to_apply); ++_tsi){
                        var _sid = _statuses_to_apply[_tsi];
                        if (!is_string(_sid)) continue;
                        // check A
                        try {
                            if (status_system_has_status(A, _sid)) { _meta_enqueued_pending = true; break; }
                            if (is_struct(A) && variable_struct_exists(A, "mon") && is_struct(A.mon) && status_system_has_status(A.mon, _sid)) { _meta_enqueued_pending = true; break; }
                            if (status_system_has_status(D, _sid)) { _meta_enqueued_pending = true; break; }
                            if (is_struct(D) && variable_struct_exists(D, "mon") && is_struct(D.mon) && status_system_has_status(D.mon, _sid)) { _meta_enqueued_pending = true; break; }
                        } catch (e_schk) { /* ignore per-status check errors */ }
                    }
                }
            } catch (e_meta_sa) { /* ignore */ }
    } catch (e_sec) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][meta_dispatch] failed: " + string(e_sec)); }

    // Compute 'extra' lines (crit, no-effect, faint) after meta dispatch
    var extra = "";
    // Determine if HP actually changed on the target — prefer HP-before/after if available
    var _hp_changed = false;
    try {
        if (is_real(before) && is_real(after) && after < before) _hp_changed = true;
        else if (is_real(dmg) && dmg > 0) _hp_changed = true; // fallback when HP snapshots are unavailable
    } catch (e_hpcheck) { /* ignore */ }

    if (_hp_changed){
        // optional: crit text if __battle_last_crit flag is set
        if (variable_struct_exists(_B, "_last_crit") && _B._last_crit == true){
            extra += "\nA critical hit!";
            variable_struct_set(_B, "_last_crit", false);
        }
    } else {
        // Only show 'It had no effect.' when the move produced no meta messages
        // AND meta dispatch did not enqueue any pending status dialogs or mark a meta effect.
        var _meta_effect_flag = (variable_struct_exists(_B, "_meta_effect_applied") && _B._meta_effect_applied == true);
        // Also treat certain meta_category values as implicit meta effects (e.g. 13)
        try {
            if (!(_meta_effect_flag) && is_struct(mm_all) && variable_struct_exists(mm_all, "meta_category")){
                var _mcr = variable_struct_get(mm_all, "meta_category");
                var _mci = (is_real(_mcr) ? _mcr : __to_int_safe(_mcr, -1));
                if (is_real(_mci) && _mci == 13) _meta_effect_flag = true;
            }
        } catch (e_meta_flag) { /* ignore */ }
        if ((is_undefined(_meta_msg) || !is_string(_meta_msg) || string_length(_meta_msg) == 0) && !_meta_enqueued_pending && !_meta_effect_flag) extra += "\nIt had no effect.";
    }
    // Announce faint only when we have a valid HP snapshot showing 0
    // or when damage was dealt and the canonical faint check reports true.
    try {
        var _fainted_now = false;
        // Prefer explicit before/after snapshots: announce faint only when HP transitioned
        // from positive to zero/less during the resolved hits.
        if (is_real(before) && is_real(after) && before > 0 && after <= 0){
            _fainted_now = true;
        }
        // Fallback (rare): if snapshots aren't available but canonical check and evidence show a faint,
        // announce only when the target has HP fields and current HP is zero and damage was dealt.
        else {
            var _has_hp_fields = false;
            if (is_struct(D)){
                if (variable_struct_exists(D, "hp_now") || variable_struct_exists(D, "hp")) _has_hp_fields = true;
                else if (variable_struct_exists(D, "mon") && is_struct(variable_struct_get(D, "mon"))){
                    var _mi3 = variable_struct_get(D, "mon");
                    if (variable_struct_exists(_mi3, "hp_now") || variable_struct_exists(_mi3, "hp")) _has_hp_fields = true;
                }
            }
            if (_has_hp_fields && is_real(dmg) && dmg > 0 && !is_undefined(__battle_is_fainted) && is_struct(D) && __battle_is_fainted(D)){
                _fainted_now = true;
            }
        }
        if (_fainted_now) extra += "\n" + string((variable_struct_exists(D,"name")?variable_struct_get(D,"name"):"The target")) + " fainted!";
    } catch (e_fa) { /* ignore */ }

    // Build return message and include multi-hit summary and meta messages
    var ret_msg = string((variable_struct_exists(A,"name")?variable_struct_get(A,"name"):"The user")) + " used " + mv_name + "!" + extra;
    if (is_real(performed_hits) && performed_hits > 1){
        ret_msg += "\nIt hit " + string(performed_hits) + " times!";
    }
    if (is_string(_meta_msg) && string_length(_meta_msg) > 0){
        ret_msg += "\n" + _meta_msg;
    }
    return ret_msg;
}

// Animation implementation intentionally provided by scripts/battle_animations/battle_animations.gml
// Keep a single canonical implementation there. Do not define __battle_anim_update here to avoid duplicate script names.
function __battle_enemy_choose_action(_pid){
    var _B = __battle_ensure_slot(_pid);
    var A = _B.actor[1];
    if (!is_struct(A)) return undefined;

    // pick any slot that has a valid move and PP
    var choices = [];
    for (var i=0;i<4;++i){
        var mv = A.moves[i];
        var pp = A.pps[i];
        if (is_real(mv) && mv >= 0 && is_real(pp) && pp > 0){
            choices[array_length(choices)] = i;
        }
    }
    if (array_length(choices) == 0) return undefined;
    var slot = choices[irandom(array_length(choices)-1)];
    return { slot: slot, move_id: A.moves[slot] };
}

// ===== Helpers: menus, run, text =====
function __battle_menu_index(_selX,_selY){ return _selX + _selY*2; }
function __battle_move_name(_code){
    if (is_real(_code) && _code >= 0){
        if (!is_undefined(scr_move_name_by_id)) return scr_move_name_by_id(_code);
        return "MOVE " + string(_code);
    }
    return "--";
}
function __battle_move_power(_code){
    if (is_real(_code) && _code >= 0){
        if (!is_undefined(scr_move_power_by_id)){
            var p = scr_move_power_by_id(_code);
            if (is_real(p)) return max(0, real(p));
        }
    }
    return 40; // fallback
}
function __battle_move_accuracy(_code){
    if (is_real(_code) && _code >= 0){
        if (!is_undefined(scr_move_accuracy_by_id)){
            var a = scr_move_accuracy_by_id(_code);
            if (is_real(a)) return clamp(real(a), 1, 100);
        }
    }
    return 100; // fallback
}
// (action helpers moved to battle_actions.gml)


function __battle_try_escape(_pid){
    var _B = __battle_ensure_slot(_pid);
    var A0 = _B.actor[0], A1 = _B.actor[1];
    if (!is_struct(A0) || !is_struct(A1)){
        _B.result = "escaped"; __battle_stub_dialog(_pid, "Got away safely!"); _B._pending_close = true; return;
    }
    if (!variable_struct_exists(_B, "run_tries")) _B.run_tries = 0;
    // Use the stat getter to safely retrieve Speed (handles missing fields and fallbacks)
    var s0 = max(1, is_real(__battle_stat_get(A0, "spd")) ? __battle_stat_get(A0, "spd") : 30);
    var s1 = max(1, is_real(__battle_stat_get(A1, "spd")) ? __battle_stat_get(A1, "spd") : 30);
    var chance = clamp(floor((s0 * 128) / s1) + (30 * _B.run_tries), 0, 255);
    var roll = irandom(255);
    if (roll < chance){
        _B.result = "escaped";
        __battle_stub_dialog(_pid, "Got away safely!\n");
        _B._pending_close = true;
    } else {
        _B.run_tries += 1;
        // Failed escape: count as player's turn (player attempted to run),
        // queue enemy action so opponent still acts this turn.
        __battle_stub_dialog(_pid, "Can't escape!");
        _B.turn_action_player = undefined;
        _B.turn_action_enemy  = __battle_enemy_choose_action(_pid);
        _B.turn_queue = __battle_build_turn_actions(_pid);
        _B.turn_i = 0;
        _B.phase = "turn";
    }
}

function __battle_stub_dialog(_pid, _text){
    if (!is_undefined(dialog2p_open_text)){
        dialog2p_open_text(_pid, _text);
        var _B = __battle_ensure_slot(_pid);
        _B._dlg_active = true;
        _B._dlg_page_last = -1;
    }
}
function __battle_play_switch_in(_pid){
    var _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B) || !_B.sys_open) return;
    _B.phase = "switch_in";
    _B.phase_start_ms = current_time;
    _B.phase_progress = 0;
}

// Phase enter hook: you can add SFX here if needed
function __battle_on_phase_enter(_pid, _phase){
    var _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B)) return;
    return;
}

// Check phase progress and trigger cries when movement/slide has finished.
function __battle_check_play_cries(_pid){
    var _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B)) return;
    var now = current_time;

    if (string(_B.phase) == "intro_enemy"){
        var p = (variable_struct_exists(_B,"phase_progress") ? _B.phase_progress : 0);
        if (p >= 1 && (!variable_struct_exists(_B, "_cry_played_enemy") || !_B._cry_played_enemy)){
            _B._cry_play_start_ms_enemy = now;
            if (!is_undefined(pkicons_play_cry_by_mon) && is_struct(_B.actor[1]) && variable_struct_exists(_B.actor[1], "mon")){
                var _aud_e = pkicons_play_cry_by_mon(_B.actor[1].mon);
                if (is_real(_aud_e) && _aud_e >= 0) { }
            }
            _B._cry_played_enemy = true;
        }
    }

    if (string(_B.phase) == "intro_player"){
        var p2 = (variable_struct_exists(_B,"phase_progress") ? _B.phase_progress : 0);
        if (p2 >= 1 && (!variable_struct_exists(_B, "_cry_played_player") || !_B._cry_played_player)){
            _B._cry_play_start_ms_player = now;
            if (!is_undefined(pkicons_play_cry_by_mon) && is_struct(_B.actor[0]) && variable_struct_exists(_B.actor[0], "mon")){
                var _aud_p = pkicons_play_cry_by_mon(_B.actor[0].mon);
                if (is_real(_aud_p) && _aud_p >= 0) { }
            }
            _B._cry_played_player = true;
            _B._cry_queued_from_switch = false;
        }
    }

    if (string(_B.phase) == "switch_in"){
        var p3 = (variable_struct_exists(_B,"phase_progress") ? _B.phase_progress : 0);
        if (p3 >= 0.5 && (!variable_struct_exists(_B, "_cry_played_player") || !_B._cry_played_player)){
            _B._cry_play_start_ms_player = now;

            var _mon_to_play = undefined;
            if (variable_struct_exists(_B, "_cry_queued_from_switch") && _B._cry_queued_from_switch && variable_struct_exists(_B, "_switch_target_idx") && is_real(_B._switch_target_idx)){
                var _P = party_ensure(_pid);
                if (is_struct(_P) && variable_struct_exists(_P, "mons")){
                    var _pmons_local = variable_struct_get(_P, "mons");
                    if (is_array(_pmons_local) && _B._switch_target_idx >= 0 && _B._switch_target_idx < array_length(_pmons_local)){
                        _mon_to_play = _pmons_local[_B._switch_target_idx];
                    }
                }
            }
            if (!is_struct(_mon_to_play) && is_struct(_B.actor[0]) && variable_struct_exists(_B.actor[0], "mon")) _mon_to_play = _B.actor[0].mon;

            if (!is_undefined(pkicons_play_cry_by_mon) && is_struct(_mon_to_play)){
                var _aud_s = pkicons_play_cry_by_mon(_mon_to_play);
                if (is_real(_aud_s) && _aud_s >= 0) { }
            }

            _B._cry_played_player = true;
            _B._cry_queued_from_switch = false;
        }
    }
}

// API: switch the player's active Pokémon to the party index with visuals
function battle_switch_to(_pid, _party_idx, _opts){
    var _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B) || !_B.sys_open) return false;
    if (string(_B.phase) != "command") return false;

    if (is_undefined(_opts)) _opts = {};
    _B._switch_target_idx = _party_idx;
    _B._switch_opts = _opts;
    _B.phase = "switch_in";
    _B.phase_start_ms = current_time;
    _B.phase_progress = 0;
    _B._cry_played_player = false;
    _B._cry_queued_from_switch = true;
    return true;
}

// Ellipsize helper (uses current font)
function __battle_text_fit_ellipsis(_pid, _str, _max_px){
    var s = string(_str);
    if (string_width(s) <= _max_px) return s;
    var ell = "…";
    var n = string_length(s);
    while (n > 1){
        n -= 1;
        var cand = string_copy(s, 1, n) + ell;
        if (string_width(cand) <= _max_px) return cand;
    }
    return ell;
}

// ===== Actor creation =====
function __battle_actor_from_party_mon(_M){
    var _sid = -1;
    if (variable_struct_exists(_M,"id") && is_real(_M.id)) _sid = _M.id;
    else if (variable_struct_exists(_M,"species_id") && is_real(_M.species_id)) _sid = _M.species_id;

    var _nm = "???";
    if (variable_struct_exists(_M,"name") && is_string(_M.name) && string_length(_M.name) > 0) _nm = string(_M.name);
    else if (_sid > 0) _nm = scr_poke_name_by_id(_sid);

    var _hpMax = 20;
    if (variable_struct_exists(_M,"hp_max"))      _hpMax = _M.hp_max;
    else if (variable_struct_exists(_M,"maxhp"))  _hpMax = _M.maxhp;

    var _hpNow = variable_struct_exists(_M,"hp") ? _M.hp : _hpMax;

    var _lvl   = 5;
    if (variable_struct_exists(_M,"level")) _lvl = _M.level;
    else if (variable_struct_exists(_M,"lvl")) _lvl = _M.lvl;

    // If the party mon struct is provided, return it directly as the actor so the battle system
    // operates on the canonical party data. We still ensure common aliases exist so existing
    // battle code that expects fields like `hp_now` or `hp_max` works.
    if (is_struct(_M)){
        var A = _M;

        // Ensure species_id canonical field
        if ((!variable_struct_exists(A, "species_id") || !is_real(A.species_id))) {
            if (variable_struct_exists(A, "id") && is_real(A.id)) A.species_id = A.id;
            else if (variable_struct_exists(A, "species") && is_real(A.species)) A.species_id = A.species;
        }

        // Ensure readable top-level aliases used by battle code
        if (!variable_struct_exists(A, "level") && variable_struct_exists(A, "lvl")) A.level = A.lvl;
        if (!variable_struct_exists(A, "lvl") && variable_struct_exists(A, "level")) A.lvl = A.level;

    if (!variable_struct_exists(A, "hp_now") && variable_struct_exists(A, "hp")) __battle_set_hp_now(A, variable_struct_get(A, "hp"));
    if (!variable_struct_exists(A, "hp") && variable_struct_exists(A, "hp_now")) __battle_set_hp_now(A, variable_struct_get(A, "hp_now"));

        if (!variable_struct_exists(A, "hp_max") && variable_struct_exists(A, "maxhp")) A.hp_max = A.maxhp;
        if (!variable_struct_exists(A, "maxhp") && variable_struct_exists(A, "hp_max")) A.maxhp = A.hp_max;

        if (!variable_struct_exists(A, "name") && is_string(_nm)) A.name = _nm;

        if (!variable_struct_exists(A, "moves")) A.moves = [-1,-1,-1,-1];
        if (!variable_struct_exists(A, "pps"))   A.pps   = [0,0,0,0];

        if (!variable_struct_exists(A, "exp")) A.exp = 0;
        if (!variable_struct_exists(A, "exp_next")) A.exp_next = max(20, (is_real(A.level) ? A.level : _lvl) * (is_real(A.level) ? A.level : _lvl) * 2);

        // Ensure growth_id exists on party mons so experience lookups can reference the correct growth curve
        if (!variable_struct_exists(A, "growth_id") || !is_real(A.growth_id)){
            if (variable_struct_exists(A, "species_id") && is_real(A.species_id) && variable_global_exists("_pokemon") && is_array(global._pokemon) && A.species_id >= 0 && A.species_id < array_length(global._pokemon)){
                var __rec_g = global._pokemon[A.species_id];
                if (is_struct(__rec_g)){
                    if (variable_struct_exists(__rec_g, "growth_rate_id") && is_real(__rec_g.growth_rate_id)) A.growth_id = floor(__rec_g.growth_rate_id);
                    else if (variable_struct_exists(__rec_g, "_growth_rate") && is_real(__rec_g._growth_rate)) A.growth_id = floor(__rec_g._growth_rate);
                    else if (variable_struct_exists(__rec_g, "growth") && is_real(__rec_g.growth)) A.growth_id = floor(__rec_g.growth);
                }
            }
        }

        // Provide a `.mon` alias pointing to itself so code that checks for `.mon` continues to work
        if (!variable_struct_exists(A, "mon")) A.mon = A;

        // Ensure `species` is the numeric id used by lookup tables. If a name string was stored in
        // `species`, prefer the numeric `species_id` when available to avoid runtime conversion errors.
        if (variable_struct_exists(A, "species_id") && is_real(A.species_id)){
            A.species = A.species_id;
        } else if (!variable_struct_exists(A, "species") && variable_struct_exists(A, "species_id")){
            A.species = A.species_id;
        }

        return A;
    }

    // No party mon provided: return a minimal actor struct (same shape as before)
    var _actor = {
        species : _sid,
        level   : _lvl,
        name    : _nm,
        hp_now  : _hpNow,
        hp_max  : _hpMax,
        moves   : [-1,-1,-1,-1],
        pps     : [0,0,0,0]
    };
    _actor.mon = { species_id:_sid, shiny:false, level:_lvl, hp:_hpNow, hp_max:_hpMax };
    return _actor;
}

function __battle_actor_from_species_level(_sp,_lvl){
    var _nm = scr_poke_name_by_id(_sp);
    // base stats from data loader (fallbacks if missing)
    var _spe = 45;
    if (variable_global_exists("_poke_stats") && is_array(global._poke_stats) && _sp >= 0 && _sp < array_length(global._poke_stats)){
        var _st = global._poke_stats[_sp];
        if (is_struct(_st) && variable_struct_exists(_st, "spe")) _spe = max(1, real(_st.spe));
    }
    var _hpMax = 30;
    if (variable_global_exists("_poke_stats") && is_array(global._poke_stats) && _sp >= 0 && _sp < array_length(global._poke_stats)){
        var _st2 = global._poke_stats[_sp];
        if (is_struct(_st2) && variable_struct_exists(_st2, "hp")) _hpMax = max(10, 10 + floor(_st2.hp * 0.8) + _lvl); // very rough
    }

    var _actor = {
        species:_sp,
        level:_lvl,
        name:_nm,
        hp_now:_hpMax,
        hp_max:_hpMax,
        moves:[-1,-1,-1,-1],
        pps:[0,0,0,0],
        spe:_spe,
        exp:0,
        exp_next:max(20, _lvl * _lvl * 2) // simple curve placeholder
    };
    _actor.mon = { species_id:_sp, shiny:false };

    // Ensure the wild mon has canonical fields so downstream code can query growth/exp reliably
    // Provide numeric species aliases
    _actor.species = _sp;
    if (!variable_struct_exists(_actor.mon, "species_id") || !is_real(_actor.mon.species_id)) _actor.mon.species_id = _sp;
    // set level on mon
    if (!variable_struct_exists(_actor.mon, "level") || !is_real(_actor.mon.level)) _actor.mon.level = _lvl;

    // Try to copy growth id from the master species table if available
    if (variable_global_exists("_pokemon") && is_array(global._pokemon) && _sp >= 0 && _sp < array_length(global._pokemon)){
        var __rec = global._pokemon[_sp];
        if (is_struct(__rec)){
            if (variable_struct_exists(__rec, "growth_rate_id") && is_real(__rec.growth_rate_id)) variable_struct_set(_actor.mon, "growth_id", __rec.growth_rate_id);
            else if (variable_struct_exists(__rec, "growth_id") && is_real(__rec.growth_id)) variable_struct_set(_actor.mon, "growth_id", __rec.growth_id);
            else if (variable_struct_exists(__rec, "growth") && is_real(__rec.growth)) variable_struct_set(_actor.mon, "growth_id", __rec.growth);
        }
    }
    return _actor;
}
 

// ===== Move population =====
function __battle_ensure_moves_from_levelup(_A){
    for (var i=0; i<4; ++i){ _A.moves[i] = -1; _A.pps[i] = 0; }

    var cand = [];

    if (!is_undefined(scr_poke_moveset_by_id)){
        var pool = scr_poke_moveset_by_id(_A.species);

        if (is_array(pool)){
            for (var j = 0; j < array_length(pool); ++j){
                var entry = pool[j];
                var mv = -1, reqLv = -1;
                    if (is_array(entry)){
                        if (array_length(entry) >= 1 && is_real(entry[0])) mv = entry[0];
                        if (array_length(entry) >= 2 && is_real(entry[1])) reqLv = entry[1];
                    } else if (is_struct(entry)){
                        if (variable_struct_exists(entry, "mid") && is_real(variable_struct_get(entry, "mid"))) mv = variable_struct_get(entry, "mid");
                        else if (variable_struct_exists(entry, "move") && is_real(variable_struct_get(entry, "move"))) mv = variable_struct_get(entry, "move");
                        if (variable_struct_exists(entry, "lvl") && is_real(variable_struct_get(entry, "lvl"))) reqLv = variable_struct_get(entry, "lvl");
                    } else if (is_real(entry)){
                        mv = entry;
                    }
                if (is_real(mv) && mv >= 0 && (reqLv < 0 || _A.level >= reqLv)){
                    cand[array_length(cand)] = mv;
                }
            }
        } else if (ds_exists(pool, ds_type_list)){
            var n = ds_list_size(pool);
            for (var k = 0; k < n; ++k){
                var entry2 = ds_list_find_value(pool, k);
                var mv2 = -1, reqLv2 = -1;
                if (is_array(entry2)){
                    if (array_length(entry2) >= 1 && is_real(entry2[0])) mv2 = entry2[0];
                    if (array_length(entry2) >= 2 && is_real(entry2[1])) reqLv2 = entry2[1];
                } else if (is_struct(entry2)){
                    if (variable_struct_exists(entry2, "mid") && is_real(variable_struct_get(entry2, "mid"))) mv2 = variable_struct_get(entry2, "mid");
                    else if (variable_struct_exists(entry2, "move") && is_real(variable_struct_get(entry2, "move"))) mv2 = variable_struct_get(entry2, "move");
                    if (variable_struct_exists(entry2, "lvl") && is_real(variable_struct_get(entry2, "lvl"))) reqLv2 = variable_struct_get(entry2, "lvl");
                } else if (is_real(entry2)){
                    mv2 = entry2;
                }
                if (is_real(mv2) && mv2 >= 0 && (reqLv2 < 0 || _A.level >= reqLv2)){
                    cand[array_length(cand)] = mv2;
                }
            }
        }
    }

    var total = array_length(cand);
    // Deduplicate candidates while preserving order (learn order). This prevents the
    // same move appearing multiple times in the final picks.
    if (total > 1){
        var seen = [];
        var uniq = [];
        for (var ui = 0; ui < array_length(cand); ui++){
            var mvv = cand[ui];
            var ok = true;
            for (var si = 0; si < array_length(seen); si++) if (seen[si] == mvv) { ok = false; break; }
            if (ok){ array_push(seen, mvv); array_push(uniq, mvv); }
        }
        cand = uniq;
        total = array_length(cand);
    }
    if (total > 0){
        var take = min(4, total);
        for (var m = 0; m < take; ++m){
            var mvPick = cand[total - 1 - m];
            _A.moves[m] = mvPick;
            _A.pps[m]   = 10; // placeholder PP
        }
    } else {
        _A.moves[0] = 1; _A.pps[0] = 10;
    }
}
function __battle_apply_party_moves(_A){
    for (var i=0; i<4; ++i){ _A.moves[i] = -1; _A.pps[i] = 0; }

    // Helper: determine if a struct looks like a mon record (has any move fields or move arrays)
    function __is_mon_like(_s){
        if (!is_struct(_s)) return false;
        if (variable_struct_exists(_s, "moves") && is_array(_s.moves)) return true;
        if (variable_struct_exists(_s, "move_ids") && is_array(_s.move_ids)) return true;
        if (variable_struct_exists(_s, "known_moves") && is_array(_s.known_moves)) return true;
        for (var __i = 1; __i <= 4; __i++) if (variable_struct_exists(_s, "move" + string(__i))) return true;
        return false;
    }

    // Prefer canonical .mon if present; otherwise, if the actor itself looks like a mon, use it.
    var m = undefined;
    if (is_struct(_A) && variable_struct_exists(_A, "mon") && is_struct(_A.mon)) m = _A.mon;
    else if (__is_mon_like(_A)) m = _A;
    var got = 0;

    // CASE 1: mon.moves array
    if (is_struct(m) && variable_struct_exists(m, "moves") && is_array(variable_struct_get(m, "moves"))){
        var mvArr = variable_struct_get(m, "moves");
        var ppArr = (is_struct(m) && variable_struct_exists(m, "pps") && is_array(variable_struct_get(m, "pps"))) ? variable_struct_get(m, "pps") : undefined;

        var cnt = min(4, array_length(mvArr));
        for (var i1 = 0; i1 < cnt; ++i1){
            var e = mvArr[i1];
            var mvCode = -1;
            var havePP = false;
            var ppVal = 0;

            if (is_real(e)){
                mvCode = e;
                if (is_array(ppArr) && i1 < array_length(ppArr) && is_real(ppArr[i1])){
                    ppVal = max(0, real(ppArr[i1])); havePP = true;
                }
            } else if (is_array(e)){
                if (array_length(e) >= 1 && is_real(e[0])) mvCode = e[0];
                if (array_length(e) >= 2 && is_real(e[1])) { ppVal = max(0, real(e[1])); havePP = true; }
            } else if (is_struct(e)){
                if (variable_struct_exists(e, "move")     && is_real(e.move))     mvCode = e.move;
                else if (variable_struct_exists(e, "move_id") && is_real(e.move_id)) mvCode = e.move_id;
                else if (variable_struct_exists(e, "id")  && is_real(e.id))       mvCode = e.id;

                if (variable_struct_exists(e, "pp")       && is_real(e.pp))       { ppVal = max(0, real(e.pp)); havePP = true; }
                else if (variable_struct_exists(e, "pp_cur") && is_real(e.pp_cur)){ ppVal = max(0, real(e.pp_cur)); havePP = true; }
                else if (variable_struct_exists(e, "pp_current") && is_real(e.pp_current)){ ppVal = max(0, real(e.pp_current)); havePP = true; }
            }

            if (is_real(mvCode) && mvCode >= 0){
                _A.moves[i1] = mvCode;
                _A.pps[i1]   = havePP ? ppVal : 10;
                got += 1;
            }
        }
    }

    // CASE 2: mon.move1..move4 (+ pp1..pp4)
    if (got == 0){
        var moved = false;
        for (var i2 = 0; i2 < 4; ++i2){
            var idx = i2 + 1;
            var mvField = "move" + string(idx);
            if (is_struct(m) && variable_struct_exists(m, mvField)){
                var mvVal = variable_struct_get(m, mvField);
                if (is_real(mvVal) && mvVal >= 0){
                    _A.moves[i2] = mvVal;
                    moved = true;

                    var ppField = "pp" + string(idx);
                    if (variable_struct_exists(m, ppField) && is_real(variable_struct_get(m, ppField))){
                        _A.pps[i2] = max(0, real(variable_struct_get(m, ppField)));
                    } else {
                        _A.pps[i2] = 10;
                    }
                }
            }
        }
        if (moved){ got = 1; }
    }

    // CASE 3: alt arrays (move_ids/known_moves + pps)
    if (got == 0){
        var mvAlt = undefined, ppAlt = undefined;
    if (is_struct(m) && variable_struct_exists(m, "move_ids") && is_array(variable_struct_get(m, "move_ids"))) mvAlt = variable_struct_get(m, "move_ids");
    else if (is_struct(m) && variable_struct_exists(m, "known_moves") && is_array(variable_struct_get(m, "known_moves"))) mvAlt = variable_struct_get(m, "known_moves");
    if (is_struct(m) && variable_struct_exists(m, "pps") && is_array(variable_struct_get(m, "pps"))) ppAlt = variable_struct_get(m, "pps");

        if (is_array(mvAlt)){
            var cnt2 = min(4, array_length(mvAlt));
            for (var i3 = 0; i3 < cnt2; ++i3){
                var mvV = mvAlt[i3];
                if (is_real(mvV) && mvV >= 0){
                    _A.moves[i3] = mvV;
                    _A.pps[i3]   = (is_array(ppAlt) && i3 < array_length(ppAlt) && is_real(ppAlt[i3]))
                                   ? max(0, real(ppAlt[i3])) : 10;
                }
            }
        }
    }

    // Still nothing? seed from level-up
    var hasAny = false;
    for (var z=0; z<4; ++z){ if (is_real(_A.moves[z]) && _A.moves[z] >= 0) { hasAny = true; break; } }
    if (!hasAny) __battle_ensure_moves_from_levelup(_A);
}

// ===== Minimal stats & damage =====
function __battle_stat_get(_A, _stat){
    // Pull from mon if present, else derive from level
    var lvl = (is_struct(_A) && is_real(_A.level)) ? _A.level : 5;
    // Only check exact assigned fields. For speed, use `spe` only (actor then mon).
    if (is_struct(_A)){
        if (_stat == "spd"){
            if (variable_struct_exists(_A, "spe") && is_real(_A.spe)){
                var _val = _A.spe;
                // paralysis halves Speed
                if (!is_undefined(status_system_has_status) && status_system_has_status(_A, "paralysis")) _val = floor(_val / 2);
                return _val;
            }
        } else if (_stat == "atk"){
            if (variable_struct_exists(_A, "atk") && is_real(_A.atk)) return _A.atk;
        } else if (_stat == "def"){
            if (variable_struct_exists(_A, "def") && is_real(_A.def)) return _A.def;
        }
    }

    var m = (is_struct(_A) && variable_struct_exists(_A,"mon")) ? _A.mon : undefined;

    if (is_struct(m)){
        if (_stat=="atk"){
            if (variable_struct_exists(m,"atk") && is_real(m.atk)) return m.atk;
        }
        if (_stat=="def"){
            if (variable_struct_exists(m,"def") && is_real(m.def)) return m.def;
        }
        if (_stat=="spd"){
            if (variable_struct_exists(m,"spe") && is_real(m.spe)){
                var _spv = m.spe;
                if (!is_undefined(status_system_has_status) && status_system_has_status(m, "paralysis")) _spv = floor(_spv / 2);
                return _spv;
            }
        }
        if (_stat=="atk"){
            if (variable_struct_exists(m,"atk") && is_real(m.atk)) return m.atk;
            if (variable_struct_exists(m,"attack") && is_real(m.attack)) return m.attack;
        }
        if (_stat=="def"){
            if (variable_struct_exists(m,"def") && is_real(m.def)) return m.def;
            if (variable_struct_exists(m,"defense") && is_real(m.defense)) return m.defense;
        }
        if (_stat=="spd"){
            if (variable_struct_exists(m,"spd") && is_real(m.spd)) return m.spd;
            if (variable_struct_exists(m,"speed") && is_real(m.speed)) return m.speed;
        }
    }

    // Apply temporary in-battle stage modifiers if present on actor struct
    if (is_struct(_A) && variable_struct_exists(_A, "_stages") && is_struct(variable_struct_get(_A, "_stages"))){
        var stages = variable_struct_get(_A, "_stages");
        // Map requested stat to internal keys used in stages
        var key = undefined;
        if (_stat == "atk") key = "atk";
        else if (_stat == "def") key = "def";
        else if (_stat == "spd" || _stat == "spe") key = "spe";
        else if (_stat == "spa") key = "spa";
        else if (_stat == "spdef") key = "spdef";
        if (!is_undefined(key) && variable_struct_exists(stages, key) && is_real(variable_struct_get(stages, key))){
            var stage = variable_struct_get(stages, key);
            var mult = __battle_stage_multiplier(stage);
            var basev = 0;
            // reuse existing logic: attempt to get raw base stat from actor/mon
            if (variable_struct_exists(_A, _stat) && is_real(variable_struct_get(_A, _stat))) basev = variable_struct_get(_A, _stat);
            else if (is_struct(m) && variable_struct_exists(m, _stat) && is_real(variable_struct_get(m, _stat))) basev = variable_struct_get(m, _stat);
            if (basev > 0) return floor(basev * mult);
        }
    }

    // Derived baseline if no stats exist (simple + level scaling)
    if (_stat=="atk") return 10 + lvl * 2;
    if (_stat=="def") return 10 + lvl * 2;
    if (_stat=="spd") return 10 + lvl * 2;
    return 10 + lvl * 2;
}
// Convert a stage (-6..+6) into a multiplier used for stats
function __battle_stage_multiplier(_stage){
    if (!is_real(_stage)) return 1.0;
    var s = clamp(floor(_stage), -6, 6);
    if (s >= 0) return (2 + s) / 2;
    else return 2 / (2 - s);
}
// Canonical HP/faint helpers — read/write helpers that understand both
// battle actor wrappers and inner `mon` structs. Use these to avoid
// mismatches where one side writes `hp` and another reads `hp_now`.
function __battle_hp_now(_ent){
    // If this is an actor wrapper with hp_now/hp fields, prefer hp_now then hp
    try {
        if (is_struct(_ent)){
            if (variable_struct_exists(_ent, "hp_now") && is_real(variable_struct_get(_ent, "hp_now"))) return variable_struct_get(_ent, "hp_now");
            if (variable_struct_exists(_ent, "hp") && is_real(variable_struct_get(_ent, "hp"))) return variable_struct_get(_ent, "hp");
            // fallback to inner mon if present
            if (variable_struct_exists(_ent, "mon") && is_struct(variable_struct_get(_ent, "mon"))) return __battle_hp_now(variable_struct_get(_ent, "mon"));
        }
    } catch (e_hp){}
    return 0;
}
function __battle_set_hp_now(_ent, _val){
    var v = (is_real(_val) ? max(0, floor(_val)) : 0);
    try {
        if (is_struct(_ent)){
            if (variable_struct_exists(_ent, "hp_now")) variable_struct_set(_ent, "hp_now", v);
            if (variable_struct_exists(_ent, "hp")) variable_struct_set(_ent, "hp", v);
            // Also mirror to inner mon if present
            if (variable_struct_exists(_ent, "mon") && is_struct(variable_struct_get(_ent, "mon"))){
                var mi = variable_struct_get(_ent, "mon");
                if (variable_struct_exists(mi, "hp_now")) variable_struct_set(mi, "hp_now", v);
                if (variable_struct_exists(mi, "hp")) variable_struct_set(mi, "hp", v);
            }
        }
    } catch (e_set){}
}
function __battle_is_fainted(_ent){
    return (__battle_hp_now(_ent) <= 0);
}
function __battle_clear_fainted_if_healed(_ent){
    try {
        if (__battle_hp_now(_ent) > 0){
            if (is_struct(_ent) && variable_struct_exists(_ent, "_fainted")) variable_struct_set(_ent, "_fainted", false);
            if (is_struct(_ent) && variable_struct_exists(_ent, "mon") && is_struct(variable_struct_get(_ent, "mon"))){
                var mi2 = variable_struct_get(_ent, "mon");
                if (variable_struct_exists(mi2, "_fainted")) variable_struct_set(mi2, "_fainted", false);
            }
        }
    } catch (e_clear){}
}
function __battle_calc_damage(_A, _D, _move_id, _power){
    var L = (is_real(_A.level) ? _A.level : 5);
    var Atk = __battle_stat_get(_A, "atk");
    var Def = __battle_stat_get(_D, "def");

    // base formula (Pokémon-like, simplified)
    var base = floor( (((2*L/5 + 2) * _power * Atk) / max(1,Def)) / 50 ) + 2;

    // variance 0.85..1.00
    var variance = 0.85 + random(0.15);
    var dmg = floor(base * variance);

    // crit ~ 1/24
    var crit = (irandom(23) == 0);
    var critMul = crit ? 1.5 : 1.0;
    dmg = floor(dmg * critMul);

    // mark crit for message
    var _B = __battle_ensure_slot(0); // any slot; we only read flag in same pid flow
    _B._last_crit = crit;

    // clamp
    dmg = max(0, dmg);
    return dmg;
}
function __battle_apply_damage(_pid, _target_index, _dmg){
    var _B = __battle_ensure_slot(_pid);
    var T = _B.actor[_target_index];
    if (!is_struct(T)) return;
    // If the target has an active Protect-like flag, consume it and skip damage.
    try {
        if (variable_struct_exists(T, "_protected") && variable_struct_get(T, "_protected") == true){
            // Request protected animation for the defender
            __battle_request_animation_safe(_pid, { type: "protected", target_index: _target_index });
            // Mark announce shown and consume protection so it doesn't persist
            variable_struct_set(T, "_protected_announce_shown", true);
            variable_struct_set(T, "_protected", false);
            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][protect] damage skipped by Protect for target_index=" + string(_target_index));
            return;
        }
    } catch (e_prot){ if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][protect] guard error: " + string(e_prot)); }

    var cur_hp = __battle_hp_now(T);
    var newhp = max(0, cur_hp - max(0, _dmg));
    __battle_set_hp_now(T, newhp);
    // Clear faint flag if healed above 0
    __battle_clear_fainted_if_healed(T);
}
function __party_find_next_alive(_pid){
    if (is_undefined(party_ensure)) return -1;
    var P = party_ensure(_pid);
    if (!is_struct(P) || !is_array(P.mons)) return -1;
    for (var i=0;i<array_length(P.mons);++i){
        var m = P.mons[i];
        if (is_struct(m) && variable_struct_exists(m,"hp") && is_real(m.hp) && m.hp > 0){
            // skip if this is already the current actor
            var A0 = __battle_ensure_slot(_pid).actor[0];
            if (is_struct(A0) && variable_struct_exists(A0,"mon") && A0.mon == m) continue;
            return i;
        }
    }
    return -1;
}

// ===== Rect pipeline (PID-aware, GUI-only) =====
function __bui_begin(_pid,_rx,_ry,_rw,_rh){
    var _B = __battle_ensure_slot(_pid);
    var base_w = 240, base_h = 160;
    var sx = _rw / base_w;
    var sy = _rh / base_h;
    var s = min(sx, sy);
    var content_w = floor(base_w * s);
    var content_h = floor(base_h * s);
    var origin_x = _rx + floor((_rw - content_w) / 2);
    var origin_y = _ry + floor((_rh - content_h) / 2);
    _B._ui = { rx: origin_x, ry: origin_y, rw: content_w, rh: content_h, base_w: base_w, base_h: base_h, s: s };
}
function __bui_end(_pid){
    var _B = __battle_ensure_slot(_pid);
    _B._ui = undefined;
}
function __bxu(_pid,_xv){
    var _u = __battle_ensure_slot(_pid)._ui;
    if (is_undefined(_u)) return _xv;
    return floor(_u.rx + _xv * _u.s);
}
function __byu(_pid,_yv){
    var _u = __battle_ensure_slot(_pid)._ui;
    if (is_undefined(_u)) return _yv;
    return floor(_u.ry + _yv * _u.s);
}
function __bwu(_pid,_wv){
    var _u = __battle_ensure_slot(_pid)._ui;
    if (is_undefined(_u)) return _wv;
    return floor(_wv * _u.s);
}
function __bhu(_pid,_hv){
    var _u = __battle_ensure_slot(_pid)._ui;
    if (is_undefined(_u)) return _hv;
    return floor(_hv * _u.s);
}

// ===== Panels & HUD =====
// (moved to `battle_ui.gml`)

// ===== GUI Letterbox rect =====
function __battle_view_rect_for_pid(_pid){
    var _gw = display_get_gui_width();
    var _gh = display_get_gui_height();

    var _logic_w = 240;
    var _logic_h = 160;
    var _aspect  = _logic_w / _logic_h; // 1.5
    var _guiAsp  = _gw / max(1,_gh);

    var _rw, _rh, _rx, _ry;
    if (_guiAsp > _aspect) {
        _rh = _gh;
        _rw = floor(_rh * _aspect);
        _rx = (_gw - _rw) div 2;
        _ry = 0;
    } else {
        _rw = _gw;
        _rh = floor(_rw / _aspect);
        _rx = 0;
        _ry = (_gh - _rh) div 2;
    }
    return [_rx, _ry, _rw, _rh];
}

// (draw helpers moved to battle_draw.gml)
// ===== Battlers drawing =====
// ===== Battlers drawing =====
function __battle_draw_battlers(_pid, _B) {
    // compute layout once
    var foe_x_log = 165, foe_y_log = 40;
    var mon_x_log = 64,  mon_y_log = 112;
    var trainer_x_log = 32, trainer_y_log = 108;
    var fx = __bxu(_pid, foe_x_log);
    var fy = __byu(_pid, foe_y_log);
    var mx = __bxu(_pid, mon_x_log);
    var my = __byu(_pid, mon_y_log);
    var tx = __bxu(_pid, trainer_x_log);
    var ty = __byu(_pid, trainer_y_log);

    // Delegate to extracted draw helpers
    __battle_draw_enemy(_pid, _B, fx, fy);
    __battle_draw_player(_pid, _B, mx, my, tx, ty);
}

// ===== Rewards: EXP & Level-Up (simple placeholders) =====
function __battle_award_exp(_pid, _amount){
    var _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B) || !is_array(_B.actor)) return;
    var A0 = _B.actor[0]; if (!is_struct(A0)) return;
    var _gain = max(0, floor(real(_amount)));
    // Determine target struct: prefer the canonical mon (party slot) when available so changes persist
    var T = (is_struct(A0) && variable_struct_exists(A0, "mon") && is_struct(A0.mon)) ? A0.mon : A0;

    // Ensure exp fields exist on the target
    if (!variable_struct_exists(T, "exp") || !is_real(T.exp)) T.exp = 0;
    if (!variable_struct_exists(T, "exp_next") || !is_real(T.exp_next)) T.exp_next = max(20, (is_real(T.level) ? T.level : (is_real(A0.level) ? A0.level : 1)) * (is_real(T.level) ? T.level : (is_real(A0.level) ? A0.level : 1)) * 2);

    // Capture previous exp/threshold (for UI animation), then apply gain to canonical target
    var _prev_exp = (variable_struct_exists(T, "exp") && is_real(variable_struct_get(T, "exp"))) ? real(variable_struct_get(T, "exp")) : 0;
    var _prev_exp_next = (variable_struct_exists(T, "exp_next") && is_real(variable_struct_get(T, "exp_next"))) ? real(variable_struct_get(T, "exp_next")) : max(20, (is_real(T.level) ? T.level : (is_real(A0.level) ? A0.level : 1)) * (is_real(T.level) ? T.level : (is_real(A0.level) ? A0.level : 1)) * 2);
    T.exp = max(0, real(T.exp)) + _gain;

    // level-up loop (prevent runaway)
    var _ups = 0;
    // Use CSV-driven thresholds (emerald-style) when available. Fallback to simple quadratic curve.
    while (_ups < 10){
        if (!is_real(T.level)) T.level = 1;
        if (T.level >= 100){
            // cap: clamp exp so it won't trigger further ups
            if (is_real(T.exp_next)) T.exp = min(T.exp, T.exp_next - 1);
            break;
        }

        // Determine next threshold: prefer mon.growth_id -> use scr_get_exp_for_level
        var nextThresh = -1;
        var gid_probe = undefined;
        if (variable_struct_exists(T, "growth_id") && is_real(T.growth_id)) gid_probe = T.growth_id;
        else if (variable_struct_exists(T, "growth") && is_real(T.growth)) gid_probe = T.growth;
        else if (variable_struct_exists(T, "growth_rate_id") && is_real(T.growth_rate_id)) gid_probe = T.growth_rate_id;

        if (!is_undefined(gid_probe) && is_real(gid_probe) && !is_undefined(scr_get_exp_for_level)){
            nextThresh = scr_get_exp_for_level(gid_probe, T.level + 1);
        }
        if (!is_real(nextThresh) || nextThresh <= 0) nextThresh = max(20, (T.level + 1) * (T.level + 1) * 2);

        // If current exp reaches nextThresh -> level up
        if (is_real(T.exp) && T.exp >= nextThresh){
            // subtract threshold as Emerald does (exp is cumulative: T.exp stores cumulative total)
            T.exp = T.exp - nextThresh;
            T.level += 1;
            _ups += 1;

            // Recompute stats using IV/EV-aware formula when base stats exist; record deltas for dialog
            var sid = (variable_struct_exists(T, "species_id") && is_real(variable_struct_get(T, "species_id"))) ? floor(variable_struct_get(T, "species_id")) : ((variable_struct_exists(T, "species") && is_real(variable_struct_get(T, "species"))) ? floor(variable_struct_get(T, "species")) : -1);
            var base = undefined;
            if (sid >= 0 && variable_global_exists("_poke_stats") && is_array(global._poke_stats) && sid < array_length(global._poke_stats)) base = global._poke_stats[sid];
            else if (sid >= 0 && variable_global_exists("_pokemon") && is_array(global._pokemon) && sid < array_length(global._pokemon)){
                var __rbb = global._pokemon[sid];
                if (is_struct(__rbb) && variable_struct_exists(__rbb, "base_stats")) base = variable_struct_get(__rbb, "base_stats");
                else if (is_struct(__rbb)) base = __rbb;
            }

            var old_hp = (variable_struct_exists(T, "hp_max") && is_real(variable_struct_get(T, "hp_max"))) ? real(variable_struct_get(T, "hp_max")) : ((variable_struct_exists(T, "hp") && is_real(variable_struct_get(T, "hp"))) ? real(variable_struct_get(T, "hp")) : 20);
            var old_atk = (variable_struct_exists(T, "atk") && is_real(variable_struct_get(T, "atk"))) ? real(variable_struct_get(T, "atk")) : ((variable_struct_exists(T, "attack") && is_real(variable_struct_get(T, "attack"))) ? real(variable_struct_get(T, "attack")) : 0);
            var old_def = (variable_struct_exists(T, "def") && is_real(variable_struct_get(T, "def"))) ? real(variable_struct_get(T, "def")) : ((variable_struct_exists(T, "defense") && is_real(variable_struct_get(T, "defense"))) ? real(variable_struct_get(T, "defense")) : 0);
            var old_spa = (variable_struct_exists(T, "spa") && is_real(variable_struct_get(T, "spa"))) ? real(variable_struct_get(T, "spa")) : ((variable_struct_exists(T, "spatk") && is_real(variable_struct_get(T, "spatk"))) ? real(variable_struct_get(T, "spatk")) : 0);
            var old_spd = (variable_struct_exists(T, "spd") && is_real(variable_struct_get(T, "spd"))) ? real(variable_struct_get(T, "spd")) : ((variable_struct_exists(T, "spdef") && is_real(variable_struct_get(T, "spdef"))) ? real(variable_struct_get(T, "spdef")) : 0);
            var old_spe = (variable_struct_exists(T, "spe") && is_real(variable_struct_get(T, "spe"))) ? real(variable_struct_get(T, "spe")) : ((variable_struct_exists(T, "speed") && is_real(variable_struct_get(T, "speed"))) ? real(variable_struct_get(T, "speed")) : 0);

            // IV/EV sources
            var iv = (variable_struct_exists(T, "iv") && is_struct(variable_struct_get(T, "iv"))) ? variable_struct_get(T, "iv") : ((variable_struct_exists(A0, "mon") && is_struct(A0.mon) && variable_struct_exists(A0.mon, "iv")) ? variable_struct_get(A0.mon, "iv") : undefined);
            var ev = (variable_struct_exists(T, "ev") && is_struct(variable_struct_get(T, "ev"))) ? variable_struct_get(T, "ev") : ((variable_struct_exists(A0, "mon") && is_struct(A0.mon) && variable_struct_exists(A0.mon, "ev")) ? variable_struct_get(A0.mon, "ev") : undefined);

            // read base stats with aliases
            function __bs_local(_b, _names){ if (!is_struct(_b)) return undefined; for (var _i=0; _i<array_length(_names); _i++){ var _k=_names[_i]; if (variable_struct_exists(_b,_k) && is_real(variable_struct_get(_b,_k))) return real(variable_struct_get(_b,_k)); } return undefined; }
            var b_hp = __bs_local(base, ["hp","base_hp"]);
            var b_atk = __bs_local(base, ["atk","attack","base_atk"]);
            var b_def = __bs_local(base, ["def","defense","base_def"]);
            var b_spa = __bs_local(base, ["spa","spatk","sp_atk","sp_attack","base_spa"]);
            var b_spd = __bs_local(base, ["spd","spdef","sp_def","sp_defense","base_spd"]);
            var b_spe = __bs_local(base, ["spe","speed","base_spe"]);

            var lvl_now = (is_real(T.level) ? T.level : (is_real(A0.level) ? A0.level : 1));

            var new_hp = old_hp, new_atk = old_atk, new_def = old_def, new_spa = old_spa, new_spd = old_spd, new_spe = old_spe;
            if (is_real(b_hp) || is_real(b_atk) || is_real(b_def) || is_real(b_spa) || is_real(b_spd) || is_real(b_spe)){
                var iv_hp = (is_struct(iv) && variable_struct_exists(iv, "hp") && is_real(variable_struct_get(iv, "hp"))) ? real(variable_struct_get(iv, "hp")) : 0;
                var iv_atk = (is_struct(iv) && variable_struct_exists(iv, "atk") && is_real(variable_struct_get(iv, "atk"))) ? real(variable_struct_get(iv, "atk")) : 0;
                var iv_def = (is_struct(iv) && variable_struct_exists(iv, "def") && is_real(variable_struct_get(iv, "def"))) ? real(variable_struct_get(iv, "def")) : 0;
                var iv_spa = (is_struct(iv) && variable_struct_exists(iv, "spa") && is_real(variable_struct_get(iv, "spa"))) ? real(variable_struct_get(iv, "spa")) : 0;
                var iv_spd = (is_struct(iv) && variable_struct_exists(iv, "spd") && is_real(variable_struct_get(iv, "spd"))) ? real(variable_struct_get(iv, "spd")) : 0;
                var iv_spe = (is_struct(iv) && variable_struct_exists(iv, "spe") && is_real(variable_struct_get(iv, "spe"))) ? real(variable_struct_get(iv, "spe")) : 0;

                var ev_hp = (is_struct(ev) && variable_struct_exists(ev, "hp") && is_real(variable_struct_get(ev, "hp"))) ? real(variable_struct_get(ev, "hp")) : 0;
                var ev_atk = (is_struct(ev) && variable_struct_exists(ev, "atk") && is_real(variable_struct_get(ev, "atk"))) ? real(variable_struct_get(ev, "atk")) : 0;
                var ev_def = (is_struct(ev) && variable_struct_exists(ev, "def") && is_real(variable_struct_get(ev, "def"))) ? real(variable_struct_get(ev, "def")) : 0;
                var ev_spa = (is_struct(ev) && variable_struct_exists(ev, "spa") && is_real(variable_struct_get(ev, "spa"))) ? real(variable_struct_get(ev, "spa")) : 0;
                var ev_spd = (is_struct(ev) && variable_struct_exists(ev, "spd") && is_real(variable_struct_get(ev, "spd"))) ? real(variable_struct_get(ev, "spd")) : 0;
                var ev_spe = (is_struct(ev) && variable_struct_exists(ev, "spe") && is_real(variable_struct_get(ev, "spe"))) ? real(variable_struct_get(ev, "spe")) : 0;

                new_hp = is_real(b_hp) ? scr_compute_stat(b_hp, iv_hp, ev_hp, lvl_now, true) : old_hp + 3;
                new_atk = is_real(b_atk) ? scr_compute_stat(b_atk, iv_atk, ev_atk, lvl_now, false) : old_atk + 1;
                new_def = is_real(b_def) ? scr_compute_stat(b_def, iv_def, ev_def, lvl_now, false) : old_def + 1;
                new_spa = is_real(b_spa) ? scr_compute_stat(b_spa, iv_spa, ev_spa, lvl_now, false) : old_spa + 1;
                new_spd = is_real(b_spd) ? scr_compute_stat(b_spd, iv_spd, ev_spd, lvl_now, false) : old_spd + 1;
                new_spe = is_real(b_spe) ? scr_compute_stat(b_spe, iv_spe, ev_spe, lvl_now, false) : old_spe + 1;
            } else {
                new_hp = old_hp + 3;
                new_atk = old_atk + 1;
                new_def = old_def + 1;
                new_spa = old_spa + 1;
                new_spd = old_spd + 1;
                new_spe = old_spe + 1;
            }

            // write back using guarded setters
            variable_struct_set(T, "hp_max", max(1, new_hp));
            variable_struct_set(T, "atk", max(1, new_atk));
            variable_struct_set(T, "def", max(1, new_def));
            variable_struct_set(T, "spa", max(1, new_spa));
            variable_struct_set(T, "spd", max(1, new_spd));
            variable_struct_set(T, "spe", max(1, new_spe));

            // heal a bit on level-up
            var cur_hp_now = (variable_struct_exists(T, "hp_now") && is_real(variable_struct_get(T, "hp_now"))) ? real(variable_struct_get(T, "hp_now")) : variable_struct_get(T, "hp_max");
            variable_struct_set(T, "hp_now", min(variable_struct_get(T, "hp_max"), cur_hp_now + 3));

            // record deltas for this level into a per-level queue so the UI can show them one-level-at-a-time
            var _deltas = [];
            var dh = variable_struct_get(T, "hp_max") - old_hp; if (dh > 0) array_push(_deltas, ["HP", dh]);
            var da = (variable_struct_get(T, "atk") - old_atk); if (da > 0) array_push(_deltas, ["ATK", da]);
            var dd = (variable_struct_get(T, "def") - old_def); if (dd > 0) array_push(_deltas, ["DEF", dd]);
            var dsp = (variable_struct_get(T, "spa") - old_spa); if (dsp > 0) array_push(_deltas, ["SPATK", dsp]);
            var dsd = (variable_struct_get(T, "spd") - old_spd); if (dsd > 0) array_push(_deltas, ["SPDEF", dsd]);
            var dspc = (variable_struct_get(T, "spe") - old_spe); if (dspc > 0) array_push(_deltas, ["SPEED", dspc]);
            if (!variable_struct_exists(_B, "_level_stat_bumps_queue")) variable_struct_set(_B, "_level_stat_bumps_queue", []);
            var _stepInfo = { level: T.level, deltas: _deltas };
            array_push(variable_struct_get(_B, "_level_stat_bumps_queue"), _stepInfo);

            // recompute next threshold for the new level
            if (!is_undefined(gid_probe) && is_real(gid_probe) && !is_undefined(scr_get_exp_for_level)){
                var nxt = scr_get_exp_for_level(gid_probe, min(100, T.level + 1));
                if (is_real(nxt) && nxt > 0) T.exp_next = nxt;
                else T.exp_next = max(20, T.level * T.level * 2);
            } else {
                T.exp_next = max(20, T.level * T.level * 2);
            }

            if (T.level >= 100){ T.exp_next = $1e12; break; }
            // loop to see if multiple level-ups
            continue;
        }
        // Not enough exp to level up
        // Set exp_next for UI if available
        T.exp_next = nextThresh;
        break;
    }

    // Mirror values back to the top-level actor for compatibility with existing UI/battle code
    if (is_struct(A0)){
        if (variable_struct_exists(T, "exp")) A0.exp = T.exp;
        if (variable_struct_exists(T, "exp_next")) A0.exp_next = T.exp_next;
        if (variable_struct_exists(T, "level")) A0.level = T.level;
    if (variable_struct_exists(T, "hp_now") || variable_struct_exists(T, "hp")) __battle_set_hp_now(A0, __battle_hp_now(T));
        if (variable_struct_exists(T, "hp_max")) A0.hp_max = T.hp_max;
        if (variable_struct_exists(T, "name")) A0.name = T.name;
    }

    // Build dialog message and include any recorded stat bumps for UI
    var _msg = string(_gain) + " EXP gained!";
    if (_ups > 0){
        _msg += "\n" + string(A0.name) + " grew to Lv" + string(A0.level) + "!";

        // If the battle slot collected stat deltas, append them line-by-line
        if (variable_struct_exists(_B, "_level_stat_bumps") && is_array(variable_struct_get(_B, "_level_stat_bumps"))){
            var _bumps = variable_struct_get(_B, "_level_stat_bumps");
            for (var _bi = 0; _bi < array_length(_bumps); ++_bi){
                var _entry = _bumps[_bi];
                if (is_array(_entry) && array_length(_entry) >= 2){
                    var _label = _entry[0];
                    var _val = _entry[1];
                    _msg += "\n" + string(_label) + " +" + string(_val);
                }
            }
            // clear bumps after consuming so subsequent dialogs don't repeat them
            variable_struct_set(_B, "_level_stat_bumps", []);
        }
    }
    __battle_stub_dialog(_pid, _msg);

    // Setup Emerald-style EXP animation queue: for each level-up that occurred, animate prev->1.0, then show level-up dialog,
    // then continue animating the remainder from 0->final. We store a queue of steps on _B._exp_anim.queue.
    try {
        var _actorMon = (is_struct(A0) && variable_struct_exists(A0, "mon") && is_struct(A0.mon)) ? A0.mon : A0;
        if (is_struct(_actorMon) && variable_struct_exists(_actorMon, "exp") && variable_struct_exists(_actorMon, "exp_next") && is_real(variable_struct_get(_actorMon, "exp_next")) && variable_struct_get(_actorMon, "exp_next") > 0){
            var _final_exp = real(variable_struct_get(_actorMon, "exp"));
            var _final_next = real(variable_struct_get(_actorMon, "exp_next"));
            var _curNorm = (is_real(_prev_exp_next) && _prev_exp_next > 0) ? max(0, min(1, _prev_exp / _prev_exp_next)) : 0;

            // Build queue: for each level-up (already recorded in _level_stat_bumps_queue), we animate to 1.0 then pause.
            var _queue = [];
            var _levels = (variable_struct_exists(_B, "_level_stat_bumps_queue") ? variable_struct_get(_B, "_level_stat_bumps_queue") : []);
            var _li = 0;
            // For each recorded level-up step, add a step from current->1.0. After each, consumer will show level-up dialog.
            while (_li < array_length(_levels)){
                array_push(_queue, { from: _curNorm, to: 1.0, dur: 700, type: "to_full" });
                _curNorm = 0.0; // after level-up, bar resets
                _li += 1;
            }
            // final remainder (current to final fraction)
            var _finalNorm = (is_real(_final_next) && _final_next > 0) ? max(0, min(1, _final_exp / _final_next)) : 0;
            // if there were any level-ups and finalNorm == 0, skip; otherwise add a final step
            if (!(_li > 0 && _finalNorm == 0)){
                array_push(_queue, { from: _curNorm, to: _finalNorm, dur: 700, type: "remainder" });
            }

            // initialize exp_anim state with queue and playing index
            variable_struct_set(_B, "_exp_anim", { active: true, queue: _queue, playing_index: 0, cur: (array_length(_queue) > 0 ? _queue[0].from : _curNorm), start_ms: current_time });
        }
    } catch (e_ea) { }
}


// ===== Catch Flow (stub): success scales with foe HP% =====
function __battle_try_catch(_pid, _ball_mult, _item_id){
    var _B = __battle_ensure_slot(_pid);
    var A1 = _B.actor[1]; if (!is_struct(A1)) return;
    // compute chance as before but defer dialog/resolution to animation
    var hpPct = max(0, min(1, __battle_hp_now(A1) / max(1, (variable_struct_exists(A1, "hp_max") ? variable_struct_get(A1, "hp_max") : 1))));
    var baseChance = clamp(floor((1 - hpPct) * 70) + 20, 5, 95); // 20–90% typical
    var mult = (is_undefined(_ball_mult) || !is_real(_ball_mult)) ? 1.0 : max(0.01, _ball_mult);
    var chance = clamp(floor(baseChance * mult), 1, 100);
    var success = (irandom(99) < chance);

    // Prepare captured mon data when success to reuse later
    var caught = undefined;
    if (variable_struct_exists(A1, "mon") && is_struct(A1.mon)) caught = A1.mon;
    else if (is_struct(A1)) caught = A1;

    // create an animation state on the battle slot so the draw/update code can render it
    // durations in ms
    var now = current_time;
    var ball_spr = undefined;
    if (!is_undefined(pkicons_get_item_icon_by_id) && is_real(_item_id) && _item_id > 0){
        try { var s_try = pkicons_get_item_icon_by_id(floor(_item_id)); if (!is_undefined(s_try) && sprite_exists(s_try)) ball_spr = s_try; } catch (e) { ball_spr = undefined; }
    }

    // Decide bounce/escape behavior:
    // - If capture success, require the ball to bounce 'hop_total' times before resolve.
    // - If capture fails, choose a random hop (1..hop_total) where the ball will break free.
    var hop_total = 3;
    var succ_hop = 0;
    var break_hop = 0;
    if (success){
        // force success to occur after the final hop so the ball always bounces 3 times
        succ_hop = hop_total;
        break_hop = 0;
    } else {
        // choose a random hop where the ball will break free (1..hop_total)
        succ_hop = 0;
        break_hop = irandom(hop_total - 1) + 1; // irandom(n-1)+1 => 1..hop_total
    }

    // Delegate creation to modular animation helper
    if (!is_undefined(__battle_anim_create_catch)){
        __battle_anim_create_catch(_B, _item_id, caught, { hop_total: hop_total, success: success, break_hop: break_hop, throw_dur:380, impact_dur:220, hop_dur:700, hop_pause:350 });
    } else {
        // fallback to inline struct if helper missing (backcompat)
        _B._catch_anim = {
            active: true,
            start_ms: now,
            phase: "throw",
            throw_dur: 380,
            impact_dur: 220,
            hop_total: hop_total,
            hop_index: 0,
            hop_dur: 700,
            hop_pause: 350,
            catch_hop_success: succ_hop,
            break_hop: break_hop,
            outcome: success,
            ball_sprite: (is_undefined(ball_spr) ? (variable_global_exists("sbagpokeball") ? sbagpokeball : undefined) : ball_spr),
            ball_frame: 0,
            start_x: undefined,
            start_y: undefined,
            target_x: undefined,
            target_y: undefined,
            enemy_orig_scale: undefined,
            enemy_scale_now: undefined,
            caught_struct: caught
        };
    }

    // mark that the battle slot has a pending non-dialog resolution; dialog will be opened by animation end
    if (variable_global_exists("DATA_DEBUG_VERBOSE") && global.DATA_DEBUG_VERBOSE) show_debug_message("[battle][debug] _catch_anim created pid=" + string(_pid) + ", outcome=" + string(success));
    // don't immediately change _B.result here; do it after animation resolves.
}

// Progress and resolve per-slot animations (catch sequence)
function __battle_update_animations(_pid){
    var _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B)) return;
    // Progress catch animation if present - delegate to animation module when available
    if (!is_undefined(__battle_anim_update)){
        var __anim_res = __battle_anim_update(_B);
        if (is_struct(__anim_res) && variable_struct_exists(__anim_res, "resolved") && variable_struct_get(__anim_res, "resolved")){
            var __anim_action = (variable_struct_exists(__anim_res, "action") ? variable_struct_get(__anim_res, "action") : undefined);
            if (!is_undefined(__anim_action) && __anim_action == "caught"){
                // finalize capture
                if (!is_undefined(__battle_finalize_catch)) __battle_finalize_catch(_B, _B._catch_anim ? _B._catch_anim.caught_struct : undefined);
            } else if (!is_undefined(__anim_action) && __anim_action == "broke"){
                // broke free - play a pokéball-break sound if available, but do NOT play
                // defeated/victory music (that would be audible even when a catch fails).
                if (!is_undefined(__battle_sound_play_safe)){
                    // Prefer explicit break SFX names if present
                    if (variable_global_exists("snd_PokeballBreak")) __battle_sound_play_safe(variable_global_get("snd_PokeballBreak"));
                    else if (variable_global_exists("snd_ball_break")) __battle_sound_play_safe(variable_global_get("snd_ball_break"));
                    else if (variable_global_exists("snd_ball_broke")) __battle_sound_play_safe(variable_global_get("snd_ball_broke"));
                    else if (variable_global_exists("snd_pokeball_broke")) __battle_sound_play_safe(variable_global_get("snd_pokeball_broke"));
                    // else: no suitable SFX found, so intentionally do nothing to avoid playing victory/defeat music.
                }
            }
        }
    } else {
        // fallback: keep existing inline stepping (unchanged)
        if (variable_struct_exists(_B, "_catch_anim")){
            var A = _B._catch_anim;
            if (is_struct(A) && variable_struct_exists(A, "active") && A.active){
                var now = current_time;
                var elapsed = now - (variable_struct_exists(A, "start_ms") ? A.start_ms : now);

                // Phase progression (existing catch logic) -- keep original behavior
                if (string(A.phase) == "throw"){
                    if (elapsed >= A.throw_dur){
                        A.phase = "impact";
                        A.phase_start = now;
                        if (variable_global_exists("DATA_DEBUG_VERBOSE") && global.DATA_DEBUG_VERBOSE) show_debug_message("[battle][debug] catch phase -> impact (pid=" + string(_pid) + ")");
                    }
                } else if (string(A.phase) == "impact"){
                    var e = now - (variable_struct_exists(A, "phase_start") ? A.phase_start : now);
                    if (e >= A.impact_dur){
                        A.phase = "shake";
                        A.phase_start = now;
                        if (variable_global_exists("DATA_DEBUG_VERBOSE") && global.DATA_DEBUG_VERBOSE) show_debug_message("[battle][debug] catch phase -> shake (pid=" + string(_pid) + ")");
                    }
                } else if (string(A.phase) == "shake"){
                    var e2 = now - (variable_struct_exists(A, "phase_start") ? A.phase_start : now);
                    var hop_dur = (variable_struct_exists(A, "hop_dur") ? max(1, real(A.hop_dur)) : 320);
                    var hop_pause = (variable_struct_exists(A, "hop_pause") ? max(0, real(A.hop_pause)) : 180);
                    var cycle = hop_dur + hop_pause;
                    if (!variable_struct_exists(A, "hop_index") || A.hop_index <= 0){ A.hop_index = 1; A.phase_start = now; e2 = 0; }
                    if (e2 >= cycle){
                        // If this battle attempt was a success, only resolve after the final hop
                        if (variable_struct_exists(A, "outcome") && A.outcome){
                            if (variable_struct_exists(A, "hop_total") && A.hop_index < A.hop_total){
                                // advance to next hop until we've done all hops
                                A.hop_index += 1;
                                A.phase_start = now;
                                if (variable_global_exists("DATA_DEBUG_VERBOSE") && global.DATA_DEBUG_VERBOSE) show_debug_message("[battle][debug] catch hop -> next hop " + string(A.hop_index) + " (pid=" + string(_pid) + ")");
                            } else {
                                // final hop completed -> resolve success
                                A.phase = "resolve";
                                A.phase_start = now;
                                if (variable_global_exists("DATA_DEBUG_VERBOSE") && global.DATA_DEBUG_VERBOSE) show_debug_message("[battle][debug] catch resolved after final hop (pid=" + string(_pid) + ")");
                            }
                        } else {
                            // failure: if break_hop matches current hop, break now; otherwise advance or escape after last
                            var _bh = (variable_struct_exists(A, "break_hop") ? A.break_hop : 0);
                            if (is_real(_bh) && _bh == A.hop_index){
                                A.phase = "escape";
                                A.phase_start = now;
                                A.escape_dur = 320;
                                if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][debug] catch broke free on hop " + string(A.hop_index) + " (pid=" + string(_pid) + ")");
                            } else if (variable_struct_exists(A, "hop_total") && A.hop_index < A.hop_total){
                                A.hop_index += 1;
                                A.phase_start = now;
                                if (variable_global_exists("DATA_DEBUG_VERBOSE") && global.DATA_DEBUG_VERBOSE) show_debug_message("[battle][debug] catch hop -> next hop " + string(A.hop_index) + " (pid=" + string(_pid) + ")");
                            } else {
                                // no break happened during hops: escape after the last hop
                                A.phase = "escape";
                                A.phase_start = now;
                                A.escape_dur = 320;
                                if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][debug] catch phase -> escape (pid=" + string(_pid) + ")");
                            }
                        }
                    }
                } else if (string(A.phase) == "resolve"){
                    if (variable_struct_exists(A, "outcome") && A.outcome){
                        _B.result = "caught";
                        var A1 = _B.actor[1];
                        var caught = A.caught_struct;
                        // (rest of original resolve logic unchanged)
                    }
                }
            }
        }
    }

    // Progress EXP animation queue if present
    if (variable_struct_exists(_B, "_exp_anim")){
        var E = variable_struct_get(_B, "_exp_anim");
        if (is_struct(E) && variable_struct_exists(E, "active") && E.active){
            var now2 = current_time;
            var q = (variable_struct_exists(E, "queue") ? variable_struct_get(E, "queue") : []);
            var idx = (variable_struct_exists(E, "playing_index") ? floor(variable_struct_get(E, "playing_index")) : 0);
            if (idx >= 0 && idx < array_length(q)){
                var step = q[idx];
                var stepStart = (variable_struct_exists(step, "start_ms") ? step.start_ms : undefined);
                if (!is_real(stepStart) || stepStart <= 0){
                    stepStart = now2;
                    step.start_ms = stepStart;
                }
                var dur = (variable_struct_exists(step, "dur") && is_real(variable_struct_get(step, "dur"))) ? max(1, real(variable_struct_get(step, "dur"))) : 700;
                var t = min(1, max(0, (now2 - stepStart) / dur));
                var curv = (variable_struct_exists(step, "from") ? real(variable_struct_get(step, "from")) : 0);
                var targv = (variable_struct_exists(step, "to") ? real(variable_struct_get(step, "to")) : curv);
                var nowVal = curv + (targv - curv) * t;
                // store current normalized value on E so UI can read it
                E.cur = nowVal;
                // write back queue step and E
                q[idx] = step;
                variable_struct_set(E, "queue", q);
                variable_struct_set(_B, "_exp_anim", E);

                if (t >= 1){
                    // Step finished
                    // If this step was a 'to_full' (level up), we must show the level-up dialog and pause progression
                    if (variable_struct_exists(step, "type") && string(step.type) == "to_full"){
                        // Pop the corresponding per-level bumps and prepare dialog
                        var _lvlq = (variable_struct_exists(_B, "_level_stat_bumps_queue") ? variable_struct_get(_B, "_level_stat_bumps_queue") : []);
                        if (array_length(_lvlq) > 0){
                            var _entry = _lvlq[0];
                            // Remove the head entry
                            var _newlvlq = [];
                            for (var _jj = 1; _jj < array_length(_lvlq); ++_jj) array_push(_newlvlq, _lvlq[_jj]);
                            variable_struct_set(_B, "_level_stat_bumps_queue", _newlvlq);

                            // Build dialog message showing the level-up and stat bumps
                            var actorName = (is_struct(_B.actor[0]) && variable_struct_exists(_B.actor[0], "name")) ? string(_B.actor[0].name) : "";
                            var _dlgtxt = string(actorName) + " grew to Lv" + string(_entry.level) + "!";
                            if (is_array(_entry.deltas) && array_length(_entry.deltas) > 0){
                                for (var _k2 = 0; _k2 < array_length(_entry.deltas); ++_k2){
                                    var _e2 = _entry.deltas[_k2];
                                    if (is_array(_e2) && array_length(_e2) >= 2){
                                        _dlgtxt += "\n" + string(_e2[0]) + " +" + string(_e2[1]);
                                    }
                                }
                            }
                            // show the level-up dialog and pause progression until it closes
                            __battle_stub_dialog(_pid, _dlgtxt);
                            variable_struct_set(E, "waiting_for_dialog", true);
                            variable_struct_set(_B, "_exp_anim", E);
                            // Do not advance playing_index here; we'll advance it when dialog closes
                        } else {
                            // no level-bump data; just advance
                            variable_struct_set(E, "playing_index", idx + 1);
                            variable_struct_set(_B, "_exp_anim", E);
                        }
                    } else {
                        // normal remainder step: advance to next
                        variable_struct_set(E, "playing_index", idx + 1);
                        variable_struct_set(_B, "_exp_anim", E);
                    }
                }
            } else {
                // queue exhausted
                variable_struct_set(E, "active", false);
                variable_struct_set(_B, "_exp_anim", E);
            }
        }
    }
    // continue; the catch animation code that follows originally returned early. Remove early return so both animations get updated.

    // Ensure catch animation struct exists before running the following block
    if (!variable_struct_exists(_B, "_catch_anim")) return;
    var A = variable_struct_get(_B, "_catch_anim");
    if (!is_struct(A) || !variable_struct_exists(A, "active") || !A.active) return;

    var now = current_time;
    var elapsed = now - (variable_struct_exists(A, "start_ms") ? A.start_ms : now);

    // Phase progression
    if (string(A.phase) == "throw"){
        if (elapsed >= A.throw_dur){
            A.phase = "impact";
            A.phase_start = now;
            if (variable_global_exists("DATA_DEBUG_VERBOSE") && global.DATA_DEBUG_VERBOSE) show_debug_message("[battle][debug] catch phase -> impact (pid=" + string(_pid) + ")");
        }
    } else if (string(A.phase) == "impact"){
        var e = now - (variable_struct_exists(A, "phase_start") ? A.phase_start : now);
        if (e >= A.impact_dur){
            A.phase = "shake";
            A.phase_start = now;
            if (variable_global_exists("DATA_DEBUG_VERBOSE") && global.DATA_DEBUG_VERBOSE) show_debug_message("[battle][debug] catch phase -> shake (pid=" + string(_pid) + ")");
        }
    } else if (string(A.phase) == "shake"){
        // Hopping sequence: each hop has hop_dur then hop_pause. We track hop_index starting at 1.
        var e2 = now - (variable_struct_exists(A, "phase_start") ? A.phase_start : now);
        var hop_dur = (variable_struct_exists(A, "hop_dur") ? max(1, real(A.hop_dur)) : 320);
        var hop_pause = (variable_struct_exists(A, "hop_pause") ? max(0, real(A.hop_pause)) : 180);
        var cycle = hop_dur + hop_pause;

        // If we're just entering the shake state, initialize first hop
        if (!variable_struct_exists(A, "hop_index") || A.hop_index <= 0){ A.hop_index = 1; A.phase_start = now; e2 = 0; }

        // If current cycle completed
        if (e2 >= cycle){
            // If this hop produced success, transition to resolve
            if (variable_struct_exists(A, "catch_hop_success") && A.catch_hop_success == A.hop_index){
                A.phase = "resolve";
                A.phase_start = now;
                if (variable_global_exists("DATA_DEBUG_VERBOSE") && global.DATA_DEBUG_VERBOSE) show_debug_message("[battle][debug] catch resolved on hop " + string(A.hop_index) + " (pid=" + string(_pid) + ")");
            } else {
                // Advance to next hop if any
                if (variable_struct_exists(A, "hop_total") && A.hop_index < A.hop_total){
                    A.hop_index += 1;
                    A.phase_start = now;
                    if (variable_global_exists("DATA_DEBUG_VERBOSE") && global.DATA_DEBUG_VERBOSE) show_debug_message("[battle][debug] catch hop -> next hop " + string(A.hop_index) + " (pid=" + string(_pid) + ")");
                } else {
                    // No success after last hop: go to escape
                    A.phase = "escape";
                    A.phase_start = now;
                    A.escape_dur = 320;
                    if (variable_global_exists("DATA_DEBUG_VERBOSE") && global.DATA_DEBUG_VERBOSE) show_debug_message("[battle][debug] catch phase -> escape (pid=" + string(_pid) + ")");
                }
            }
        }
    } else if (string(A.phase) == "resolve"){
        // finalize outcome: success is immediate; failure transitions to escape animation
        if (variable_struct_exists(A, "outcome") && A.outcome){
            // success: mark as caught and prepare mon fields
            _B.result = "caught";
            var A1 = _B.actor[1];
            var caught = A.caught_struct;
            // copy exp/growth fields similar to previous implementation
            if (is_struct(caught)){
                var growth_id = undefined;
                if (variable_struct_exists(caught, "growth_id") && is_real(variable_struct_get(caught, "growth_id"))) growth_id = variable_struct_get(caught, "growth_id");
                else if (variable_struct_exists(caught, "growth") && is_real(variable_struct_get(caught, "growth"))) growth_id = variable_struct_get(caught, "growth");
                else if (variable_struct_exists(caught, "growth_rate_id") && is_real(variable_struct_get(caught, "growth_rate_id"))) growth_id = variable_struct_get(caught, "growth_rate_id");

                var lvl = 1;
                if (variable_struct_exists(caught, "level") && is_real(variable_struct_get(caught, "level"))) lvl = floor(variable_struct_get(caught, "level"));
                else if (variable_struct_exists(caught, "lvl") && is_real(variable_struct_get(caught, "lvl"))) lvl = floor(variable_struct_get(caught, "lvl"));

                if (!is_undefined(scr_get_exp_for_level) && is_real(growth_id)){
                    var cur_exp = scr_get_exp_for_level(growth_id, lvl);
                    if (is_real(cur_exp) && cur_exp >= 0) variable_struct_set(caught, "exp", cur_exp);
                    var next_exp = scr_get_exp_for_level(growth_id, min(100, lvl + 1));
                    if (is_real(next_exp) && next_exp > 0) variable_struct_set(caught, "exp_next", next_exp);
                }
                if (!variable_struct_exists(caught, "exp")) variable_struct_set(caught, "exp", 0);
                if (!variable_struct_exists(caught, "exp_next")) variable_struct_set(caught, "exp_next", max(20, lvl * lvl * 2));
            }
            // show dialog and keep a persistent caught visual state (ball stays on-screen with mon hidden)
            // Emerald-like behavior: if the player's party is full, the mon should be sent to the PC.
            // The PC system is not implemented yet; show a TODO dialog and mark pending close.
            var _P = undefined;
            if (!is_undefined(party_ensure)) _P = party_ensure(_pid);
            var party_full = false;
            if (is_struct(_P) && variable_struct_exists(_P, "mons")){
                var _pmons_local2 = variable_struct_get(_P, "mons");
                if (is_array(_pmons_local2) && array_length(_pmons_local2) >= 6) party_full = true;
            }
            if (party_full){
                __battle_stub_dialog(_pid, "Gotcha!\nYou caught " + string(_B.actor[1].name) + "!\nYour party is full — the Pokémon will be sent to the PC (TODO).");
            } else {
                __battle_stub_dialog(_pid, "Gotcha!\nYou caught " + string(_B.actor[1].name) + "!");
                // TODO: Add the caught mon to the player's party here when party API is available.
            }
            _B._pending_close = true;
            // Stop battle BGM (use audio_stop_sound on stored resource) and start defeated loop if available
            try {
                var _stop_res = (variable_struct_exists(_B, "_battle_music") ? variable_struct_get(_B, "_battle_music") : undefined);
                if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][audio] stopping before defeated music: " + string(_stop_res));
                var _bgm_handle_local2 = (variable_struct_exists(_B, "_bgm_handle") ? variable_struct_get(_B, "_bgm_handle") : undefined);
                if (!is_undefined(audio_stop_sound)){
                    audio_stop_sound(_stop_res);
                } else if (!is_undefined(sound_stop) && !is_undefined(_stop_res)){
                    // Older runtimes may expose sound_stop instead of audio_* APIs
                    try { sound_stop(_stop_res); } catch (ee) {}
                } else if (!is_undefined(_bgm_handle_local2)){
                    __battle_audio_stop_handle(_bgm_handle_local2);
                } else if (!is_undefined(audio_stop_all)){
                    audio_stop_all();
                }
            } catch (e_stop_b) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][audio] failed stopping bgm before defeated: " + string(e_stop_b)); }
            variable_struct_set(_B, "_bgm_handle", undefined);
            try {
                var _def_music_local = (variable_struct_exists(_B, "_battle_defeated_music") ? variable_struct_get(_B, "_battle_defeated_music") : undefined);
                if (!is_undefined(_def_music_local)){
                    var _dh = __battle_sound_play_safe(_def_music_local);
                    variable_struct_set(_B, "_defeated_handle", _dh);
                    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][audio] played defeated_music="+string(_def_music_local)+" handle="+string(_dh));
                }
            } catch (e_play_d) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][audio] failed to play defeated_music="+string(_def_music_local)+" err="+string(e_play_d)); }
            // instead of clearing animation, freeze it into a 'caught' phase so the ball remains drawn
            A.phase = "caught";
            A.phase_start = now;
            A.persistent = true;
        } else {
            // failed capture: transition to escape phase where the Pokémon regrows and ball fades
            A.phase = "escape";
            A.phase_start = now;
            A.escape_dur = 320;
            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][debug] catch phase -> escape (pid=" + string(_pid) + ")");
        }
    } else if (string(A.phase) == "escape"){
        var e5 = now - (variable_struct_exists(A, "phase_start") ? A.phase_start : now);
        if (e5 >= (is_real(A.escape_dur) ? A.escape_dur : 320)){
            // end escape: show broke free dialog and clear animation
            __battle_stub_dialog(_pid, "Oh no! The Pokémon broke free!");
            A.active = false;
            _B._catch_anim = undefined;
        }
    }
}

