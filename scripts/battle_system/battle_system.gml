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

// NOTE: registration helpers are implemented in `scripts/battle_impls/battle_impls.gml`
// and `scripts/battle_moves_impls/battle_moves_impls.gml`. Do not provide duplicate
// definitions here or the GM compiler will report duplicate script names.

// Quiet-mode defaults: prevent noisy debug spam by default. Projects that
// want verbose debug output can set these to true in a controlled place
// (for example at boot or via an in-game debug toggle). We guard each
// assignment so we don't override an explicit debug enable set elsewhere.
try {
    if (!variable_global_exists("DATA_DEBUG")) global.DATA_DEBUG = false;
} catch (e) {}
try {
    if (!variable_global_exists("BATTLE_META_DEBUG")) global.BATTLE_META_DEBUG = false;
} catch (e) {}
// Add more fine-grained, quiet-mode defaults for high-volume subsystems.
try { if (!variable_global_exists("DIALOG_DEBUG")) global.DIALOG_DEBUG = false; } catch (e) {}
try { if (!variable_global_exists("MOVES_DEBUG")) global.MOVES_DEBUG = false; } catch (e) {}

// Auto-register battle move implementations if the impl file exposes the register function.
// This is idempotent and guarded so it won't override explicit init behavior elsewhere.
try {
    if (!variable_global_exists("_battle_impls_registered") || !global._battle_impls_registered){
        if (!is_undefined(__battle_moves_impls_register)){
            try {
                __battle_moves_impls_register();
                global._battle_impls_registered = true;
                if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][init] __battle_moves_impls_register() auto-called");
            } catch (e_regcall){ if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][init] __battle_moves_impls_register() failed: " + string(e_regcall)); }
        }
    }
} catch (e_auto) {}


// IMPORTANT CONFIGURATION NOTE:
// GameMaker requires that global script/function names be unique across the
// entire project. The function `__battle_apply_move_meta_effects` is the
// canonical meta-effect handler and must be implemented only once. If you
// provide alternative implementations (for testing or modularization), either
// register them via the `_battle_impls` registry or place them in this file.
// Do NOT define `__battle_apply_move_meta_effects` in multiple files — doing
// so will cause the engine to fail script compilation.


// Finalize catch handler: real implementation may live elsewhere. Provide a
// minimal guarded no-op so callers can safely invoke the symbol without the
// static analyzer flagging an undeclared symbol. Projects can override this
function __battle_perform_action(_pid, _step){
    // Try impl registry first (populated by battle_impls.gml), then fall back to direct symbol.
    try {
    // (impl registration is expected to occur in impl scripts at load time)
        if (variable_global_exists("_battle_impls") && is_struct(variable_global_get("_battle_impls")) && variable_struct_exists(variable_global_get("_battle_impls"), "__battle_perform_action_impl")) {
                var _fn = variable_struct_get(variable_global_get("_battle_impls"), "__battle_perform_action_impl"); 
                if (!is_undefined(_fn)) return _fn(_pid, _step); 
            }
        // Prefer registry-provided impl; avoid referencing a direct symbol that may not exist
        try {
            if (variable_global_exists("_battle_impls") && is_struct(variable_global_get("_battle_impls")) && variable_struct_exists(variable_global_get("_battle_impls"), "__battle_perform_action_impl")){
                var _fnr = variable_struct_get(variable_global_get("_battle_impls"), "__battle_perform_action_impl"); if (!is_undefined(_fnr)) return _fnr(_pid, _step);
            }
        } catch (e_r) {}
    } catch (e_reg) {}
    // Fallback: implementation not present. Return a safe placeholder and advance turn to avoid blocking.
    var _B = __battle_ensure_slot(_pid);
    try { if (is_struct(_B)) _B.turn_i = (is_real(_B.turn_i) ? _B.turn_i + 1 : 0); } catch (e) {}
        return "An action was performed.";
}
function __battle_apply_entry_hazards(_pid, _actor_index){
    // Apply entry hazards and related effects for a switched-in actor.
    // Signature: (_pid, _actor_index)
    try {
        var _B = __battle_ensure_slot(_pid);
        if (!is_struct(_B)) return false;
        if (!is_real(_actor_index)) return false;
        var A = undefined;
        try {
            var _actors = (variable_struct_exists(_B, "actor") ? variable_struct_get(_B, "actor") : undefined);
            if (is_array(_actors) && is_real(_actor_index) && _actor_index >= 0 && _actor_index < array_length(_actors)) A = _actors[_actor_index]; else A = undefined;
        } catch (e_act) { A = undefined; }
        if (!is_struct(A)) return false;

        // Collect defender types into tlist (supports various shapes)
        var tlist = [];
        try {
            if (variable_struct_exists(A, "types") && is_array(variable_struct_get(A, "types"))){
                var _atypes = variable_struct_get(A, "types"); for (var _ii=0; _ii<array_length(_atypes); ++_ii) array_push(tlist, _atypes[_ii]);
            }
            if (variable_struct_exists(A, "type1") && is_real(variable_struct_get(A, "type1"))) array_push(tlist, variable_struct_get(A, "type1"));
            if (variable_struct_exists(A, "type2") && is_real(variable_struct_get(A, "type2"))) array_push(tlist, variable_struct_get(A, "type2"));
            // species-level fallback
            if (variable_struct_exists(A, "mon") && is_struct(variable_struct_get(A, "mon"))){
                var _mi = variable_struct_get(A, "mon");
                if (variable_struct_exists(_mi, "species_id") && variable_global_exists("_species_types") && is_array(global._species_types)){
                    var sid2 = variable_struct_get(_mi, "species_id");
                    if (is_real(sid2) && sid2 >= 0 && sid2 < array_length(global._species_types)){
                        var st2 = global._species_types[sid2]; if (is_array(st2)) for (var _zz=0; _zz<array_length(st2); ++_zz) array_push(tlist, st2[_zz]);
                    }
                }
            }
        } catch (e_t){}

        // Normalize: check for any type id that maps to "flying" name
        var immune_flying = false;
        var flying_id = undefined;
        if (variable_global_exists("TYPE_ID_BY_NAME")){
            try { var _tmp_type_by_name = variable_global_get("TYPE_ID_BY_NAME"); if (ds_exists(_tmp_type_by_name, ds_type_map)) flying_id = ds_map_find_value(_tmp_type_by_name, string_lower("flying")); } catch (e) { flying_id = undefined; }
        }
        for (var _j=0; _j<array_length(tlist); ++_j){ var tv = tlist[_j]; if (!is_undefined(flying_id) && is_real(tv) && tv == flying_id) { immune_flying = true; break; } }

        // Ability/item levitate check (conservative): if ability field equals 'levitate' or numeric id 26
        var has_levitate = false;
        try { if (variable_struct_exists(A, "ability")) { var ab = variable_struct_get(A, "ability"); if ((is_string(ab) && string_lower(string(ab)) == "levitate") || (is_real(ab) && floor(ab) == 26)) has_levitate = true; } } catch (e_lev) { has_levitate = false; }

        // If immunities present, skip hazards that damage or poison
        var skip_entry_damage = (immune_flying || has_levitate);

        // Apply Spikes
        try {
            if (variable_struct_exists(_B, "_side_spikes") && is_real(variable_struct_get(_B, "_side_spikes"))){
                var layers = variable_struct_get(_B, "_side_spikes");
                if (is_real(layers) && layers > 0 && !skip_entry_damage){
                    var hpmax = (variable_struct_exists(A, "hp_max") ? variable_struct_get(A, "hp_max") : (variable_struct_exists(A, "maxhp") ? variable_struct_get(A, "maxhp") : 0));
                    var frac_amt = 0.125;
                    if (layers == 2) frac_amt = 1.0/6.0; else if (layers >= 3) frac_amt = 0.25;
                    var dmg = max(1, floor(hpmax * frac_amt));
                    var _before_sp = __battle_hp_now(A);
                    __battle_apply_damage(_pid, _actor_index, dmg, 1.0);
                    var _after_sp = __battle_hp_now(A);
                    __battle_trigger_hit_effect(_pid, A, _before_sp, _after_sp, 1.0);
                    // Enqueue dialog
                    try {
                        var _aname_sp = (variable_struct_exists(A, "name") ? variable_struct_get(A, "name") : "The Pokémon");
                        if (!is_undefined(__status_request_dialog_for_mon)) __status_request_dialog_for_mon(A, string(_aname_sp) + " was hurt by the spikes!");
                    } catch (e_msg) {}
                    try { variable_struct_set(_B, "_meta_effect_applied", true); } catch (e) {}
                }
            }
        } catch (e_sp) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][hazards] spikes apply failed: " + string(e_sp)); }

        // Apply Toxic Spikes: single layer -> poison, double layer -> bad poison (try 'toxic' then 'poison')
        try {
            if (variable_struct_exists(_B, "_side_toxic_spikes") && is_real(variable_struct_get(_B, "_side_toxic_spikes"))){
                var tlay = variable_struct_get(_B, "_side_toxic_spikes");
                if (is_real(tlay) && tlay > 0 && !skip_entry_damage){
                    try {
                        if (tlay >= 2){ // attempt to apply 'toxic' (bad poison)
                            if (!is_undefined(status_system_apply_status)) { var ok = status_system_apply_status(A, "toxic", {}); if (!ok) status_system_apply_status(A, "poison", {}); }
                        } else {
                            if (!is_undefined(status_system_apply_status)) status_system_apply_status(A, "poison", {});
                        }
                    } catch (e_ts) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][hazards] toxic spikes apply failed: " + string(e_ts)); }
                    try { variable_struct_set(_B, "_meta_effect_applied", true); } catch (e) {}
                }
            }
        } catch (e_ts_outer) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][hazards] toxic spikes outer error: " + string(e_ts_outer)); }

        // Apply Stealth Rock: damage scales by Rock-type effectiveness vs the entrant
        try {
            if (variable_struct_exists(_B, "_side_stealth_rock") && variable_struct_get(_B, "_side_stealth_rock") == true){
                if (!skip_entry_damage){
                    var hpmax2 = (variable_struct_exists(A, "hp_max") ? variable_struct_get(A, "hp_max") : (variable_struct_exists(A, "maxhp") ? variable_struct_get(A, "maxhp") : 0));
                    var base_frac = 0.125; // gen3: 1/8 of max HP before type multiplier
                    var mult = 1.0;
                    // Attempt to compute type-effectiveness multiplier using BATTLE_TYPE_EFFICACY
                    try {
                        // determine rock type id from TYPE_ID_BY_NAME if available
                        var rock_id = undefined;
                        if (variable_global_exists("TYPE_ID_BY_NAME")){
                            try { var _tmp_type_by_name2 = variable_global_get("TYPE_ID_BY_NAME"); if (ds_exists(_tmp_type_by_name2, ds_type_map)) rock_id = ds_map_find_value(_tmp_type_by_name2, string_lower("rock")); } catch (e_rock) { rock_id = undefined; }
                        }
                        if (!is_undefined(rock_id) && is_real(rock_id) && variable_global_exists("BATTLE_TYPE_EFFICACY")){
                            var _tmp_bte = variable_global_get("BATTLE_TYPE_EFFICACY");
                            if (!is_undefined(_tmp_bte) && ds_exists(_tmp_bte, ds_type_map)){
                                // collect defender type ids
                                var dt = [];
                                if (variable_struct_exists(A, "types") && is_array(variable_struct_get(A, "types"))) for (var _ti2=0; _ti2<array_length(variable_struct_get(A, "types")); ++_ti2) array_push(dt, variable_struct_get(A, "types")[_ti2]);
                                if (variable_struct_exists(A, "type1") && is_real(variable_struct_get(A, "type1"))) array_push(dt, variable_struct_get(A, "type1"));
                                if (variable_struct_exists(A, "type2") && is_real(variable_struct_get(A, "type2"))) array_push(dt, variable_struct_get(A, "type2"));
                                // species-level fallback
                                if (variable_struct_exists(A, "mon") && is_struct(variable_struct_get(A, "mon"))){
                                    var _mi = variable_struct_get(A, "mon");
                                    if (variable_struct_exists(_mi, "species_id") && variable_global_exists("_species_types") && is_array(global._species_types)){
                                        var sid2 = variable_struct_get(_mi, "species_id");
                                        if (is_real(sid2) && sid2 >= 0 && sid2 < array_length(global._species_types)){
                                            var st2 = global._species_types[sid2]; if (is_array(st2)) for (var _zz=0; _zz<array_length(st2); ++_zz) array_push(dt, st2[_zz]);
                                        }
                                    }
                                }
                                // multiply efficacy for each defender type
                                var prod = 1.0;
                                for (var _k=0; _k<array_length(dt); ++_k){
                                    var def_t = dt[_k];
                                    if (!is_real(def_t)) continue;
                                    var key = string(rock_id) + ":" + string(def_t);
                                    if (ds_map_exists(_tmp_bte, key)){
                                        var mval = ds_map_find_value(_tmp_bte, key);
                                        if (is_real(mval)) prod *= mval;
                                    }
                                }
                                mult = prod;
                            }
                        }
                    } catch (e_tr) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][hazards] stealth rock type calc failed: " + string(e_tr)); }

                    var rawd = floor(hpmax2 * base_frac * max(0.0, mult));
                    var dmg2 = max(1, rawd);
                    var _before_sr = __battle_hp_now(A);
                    __battle_apply_damage(_pid, _actor_index, dmg2, 1.0);
                    var _after_sr = __battle_hp_now(A);
                    __battle_trigger_hit_effect(_pid, A, _before_sr, _after_sr, mult);
                    try { var _aname_sr = (variable_struct_exists(A, "name") ? variable_struct_get(A, "name") : "The Pokémon"); if (!is_undefined(__status_request_dialog_for_mon)) __status_request_dialog_for_mon(A, string(_aname_sr) + " was hurt by the stealth rock!"); } catch (e_msg2) {}
                    try { variable_struct_set(_B, "_meta_effect_applied", true); } catch (e) {}
                }
            }
        } catch (e_sr) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][hazards] stealth rock outer error: " + string(e_sr)); }

        // Apply Sticky Web: apply -1 Speed stage via stage machinery and request stat-change animation
        try {
            if (variable_struct_exists(_B, "_side_sticky_web") && variable_struct_get(_B, "_side_sticky_web") == true){
                try {
                    // Enqueue the sticky-web hit dialog first
                    try { var _aname_sw = (variable_struct_exists(A, "name") ? variable_struct_get(A, "name") : "The Pokémon"); if (!is_undefined(__status_request_dialog_for_mon)) __status_request_dialog_for_mon(A, string(_aname_sw) + " was caught in the sticky web!"); } catch (e_) {}

                    // Apply a -1 stage to Speed using the same stage storage as other stat changes
                    if (!variable_struct_exists(A, "_stages") || !is_struct(variable_struct_get(A, "_stages"))) variable_struct_set(A, "_stages", {});
                    var st_obj = variable_struct_get(A, "_stages");
                    var prev_s = (variable_struct_exists(st_obj, "spe") && is_real(variable_struct_get(st_obj, "spe"))) ? variable_struct_get(st_obj, "spe") : 0;
                    var next_s = clamp(prev_s - 1, -6, 6);
                    variable_struct_set(st_obj, "spe", next_s);
                    // Request stat-change animation
                    __battle_request_animation_safe(_pid, { type: "stat_change", target_index: _actor_index, stat: "spe", from: prev_s, to: next_s });
                    // Enqueue a concise stat message like other stat changes
                    var aname_sw = (variable_struct_exists(A, "name") ? variable_struct_get(A, "name") : "The Pokémon");
                    var applied_amt = next_s - prev_s; var sign_amt = (applied_amt > 0) ? ("+" + string(applied_amt)) : string(applied_amt);
                    var sc_msg_sw = "";
                    if (applied_amt == 0) sc_msg_sw = string(aname_sw) + "'s SPD won't go any lower!";
                    else sc_msg_sw = string(aname_sw) + " SPD " + sign_amt;
                    var _target_mon_ref_sw = A;
                    if (is_struct(A) && variable_struct_exists(A, "mon") && is_struct(variable_struct_get(A, "mon"))) _target_mon_ref_sw = variable_struct_get(A, "mon");
                    if (!is_undefined(__status_request_dialog_for_mon)) __status_request_dialog_for_mon(_target_mon_ref_sw, sc_msg_sw);
                    try { variable_struct_set(_B, "_meta_effect_applied", true); } catch (e) {}
                } catch (e_sw){ if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][hazards] sticky web apply failed: " + string(e_sw)); }
            }
        } catch (e_outer_sw) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][hazards] sticky web outer error: " + string(e_outer_sw)); }

        return true;
    } catch (e_all){ if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][hazards] apply entry hazards error: " + string(e_all)); }
    return false;
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
            _defeated_handle: undefined,
            // Common dynamic fields with conservative defaults to satisfy static analysis
            actor: [],
            turn_queue: [],
            phase_holds: {},
            theme: {},
            _meta_effect_applied: false,
            _last_crit: false,
            _pending_status_msgs: [],
            // Switch and UI defaults
            _switch_target_idx: undefined,
            _switch_opts: undefined,
            _cry_queued_from_switch: false,
            turn_action_player: undefined,
            _ui: undefined
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



// Additional guarded stubs for meta / weather / animation dispatcher helpers
// Provide small, direct implementations for commonly-used helpers so the
// static analyzer and runtime have sensible defaults. Real implementations
// may live elsewhere and can override these by redefining the symbols.
if (is_undefined(__battle_get_move_meta)){
    function __battle_get_move_meta(_move_id){
        try {
            if (variable_global_exists("_move_meta") && !is_undefined(global._move_meta)){
                if (is_array(global._move_meta) && is_real(_move_id) && _move_id >= 0 && _move_id < array_length(global._move_meta)) return global._move_meta[_move_id];
                if (is_struct(global._move_meta)){
                    var k = "" + string(_move_id);
                    try { if (!is_undefined(global._move_meta[k])) return global._move_meta[k]; } catch (e_k) {}
                }
            }
        } catch (e) {}
        return undefined;
    }
}

if (is_undefined(__battle_apply_move_meta_effects)){
    function __battle_apply_move_meta_effects(_pid, _step, _A, _D, _move_id, _dmg, _mm){
        // Default meta-effect handler: implement drain (Absorb/Drain) and
        // healing meta fields when present in move meta. This is conservative
        // and best-effort: CSV semantics may be percent-or-absolute; we treat
        // values <= 100 as percentages when appropriate.
        try {
            var _B = __battle_ensure_slot(_pid);
            if (is_struct(_B)) variable_struct_set(_B, "_meta_effect_applied", true);
        } catch (e) {}

        try {
            if (!is_struct(_mm)) return undefined;
            // attacker and defender guards
            if (!is_struct(_A) || !is_struct(_D)) return undefined;

            // Helper: resolve hp_now and maxhp fields for an entity
            var get_hp_now = function(ent){ try { if (variable_struct_exists(ent, "hp_now")) return variable_struct_get(ent, "hp_now"); if (variable_struct_exists(ent, "hp")) return variable_struct_get(ent, "hp"); if (variable_struct_exists(ent, "mon") && is_struct(variable_struct_get(ent, "mon"))){ var mi = variable_struct_get(ent, "mon"); if (variable_struct_exists(mi, "hp_now")) return variable_struct_get(mi, "hp_now"); if (variable_struct_exists(mi, "hp")) return variable_struct_get(mi, "hp"); } } catch (ee) {} return 0; };
            var get_hp_max = function(ent){ try { if (variable_struct_exists(ent, "hp_max")) return variable_struct_get(ent, "hp_max"); if (variable_struct_exists(ent, "maxhp")) return variable_struct_get(ent, "maxhp"); if (variable_struct_exists(ent, "mon") && is_struct(variable_struct_get(ent, "mon"))){ var mi2 = variable_struct_get(ent, "mon"); if (variable_struct_exists(mi2, "hp_max")) return variable_struct_get(mi2, "hp_max"); if (variable_struct_exists(mi2, "maxhp")) return variable_struct_get(mi2, "maxhp"); } } catch (ee) {} return 1; };

            var A_before = real(get_hp_now(_A));
            var A_max = max(1, real(get_hp_max(_A)));

            // Process drain (positive = heal attacker; negative = recoil to attacker)
            if (variable_struct_exists(_mm, "drain") && is_real(variable_struct_get(_mm, "drain"))){
                var drain_v = real(variable_struct_get(_mm, "drain"));
                // Use absolute damage magnitude: move implementations may pass negative deltas
                var dmg_abs = 0;
                if (is_real(_dmg)) dmg_abs = abs(_dmg);
                // Healing (Absorb/Drain style)
                if (dmg_abs > 0 && drain_v > 0){
                    var heal_amt = 0;
                    if (drain_v > 0 && drain_v <= 100){
                        heal_amt = floor(dmg_abs * drain_v / 100);
                    } else {
                        // treat as absolute
                        heal_amt = floor(drain_v);
                    }
                    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){
                        try { show_debug_message("[battle][meta][heal] move="+string(_move_id)+", dmg_abs="+string(dmg_abs)+", drain_v="+string(drain_v)+", heal_amt="+string(heal_amt)+", A_before="+string(A_before)+", A_max="+string(A_max)); } catch (e_dbg) {}
                    }
                    if (heal_amt > 0){
                        var newhp = min(A_max, A_before + heal_amt);
                        // Apply heal via canonical setter to ensure mirroring
                        try { __battle_set_hp_now(_A, newhp); } catch (e_hs) {}
                        // Start visual lerp on attacker
                        try {
                            variable_struct_set(_A, "_hp_lerp_from", A_before);
                            variable_struct_set(_A, "_hp_lerp_to", newhp);
                            variable_struct_set(_A, "_hp_lerp_start_ms", current_time);
                            variable_struct_set(_A, "_hp_lerp_dur", 400);
                            variable_struct_set(_A, "_hp_lerp_active", true);
                            if (variable_struct_exists(_A, "mon") && is_struct(variable_struct_get(_A, "mon"))){ var _mi = variable_struct_get(_A, "mon"); variable_struct_set(_mi, "_hp_lerp_from", A_before); variable_struct_set(_mi, "_hp_lerp_to", newhp); variable_struct_set(_mi, "_hp_lerp_start_ms", variable_struct_get(_A, "_hp_lerp_start_ms")); variable_struct_set(_mi, "_hp_lerp_dur", variable_struct_get(_A, "_hp_lerp_dur")); variable_struct_set(_mi, "_hp_lerp_active", true); }
                        } catch (e_l) {}
                        // Request a small heal animation on attacker
                        try { __battle_request_animation_safe(_A, { type: "heal", amount: heal_amt }); } catch (e_ra) {}
                    }
                }
                // Recoil (negative drain values): user takes damage equal to percent/absolute
                else if (dmg_abs > 0 && drain_v < 0){
                    var abs_v = abs(drain_v);
                    var recoil_amt = 0;
                    if (abs_v > 0 && abs_v <= 100) recoil_amt = floor(dmg_abs * abs_v / 100);
                    else recoil_amt = floor(abs_v);
                    if (recoil_amt > 0){
                        // Try to determine attacker actor index for __battle_apply_damage
                        var attacker_idx = undefined;
                        try { if (variable_struct_exists(_A, "actor_index")) attacker_idx = variable_struct_get(_A, "actor_index"); } catch (e_ai) { attacker_idx = undefined; }
                        try { if (!is_real(attacker_idx) && variable_struct_exists(_A, "slot")) attacker_idx = variable_struct_get(_A, "slot"); } catch (e_ai2) {}
                        // Fallback: search actor array for the matching struct reference
                        try {
                            if (!is_real(attacker_idx)){
                                var _Bcheck = __battle_ensure_slot(_pid);
                                if (is_struct(_Bcheck) && variable_struct_exists(_Bcheck, "actor") && is_array(variable_struct_get(_Bcheck, "actor"))){
                                    var __acts2 = variable_struct_get(_Bcheck, "actor");
                                        for (var _ai = 0; _ai < array_length(__acts2); ++_ai){
                                            if (is_struct(__acts2[_ai]) && __acts2[_ai] == _A){
                                                attacker_idx = _ai;
                                                break;
                                            }
                                        }
                                }
                            }
                        } catch (e_find) {}

                        // Apply recoil via canonical damage path so hit SFX/lerp run
                        try {
                            var before_rec = __battle_hp_now(_A);
                            if (is_real(attacker_idx)) __battle_apply_damage(_pid, attacker_idx, recoil_amt, 1.0);
                            else __battle_set_hp_now(_A, max(0, before_rec - recoil_amt));
                            var after_rec = __battle_hp_now(_A);
                            try { __battle_trigger_hit_effect(_pid, _A, before_rec, after_rec, 1.0); } catch (e_th) {}
                            // Request a recoil animation on the attacker
                            try { __battle_request_animation_safe(_A, { type: "recoil", amount: recoil_amt }); } catch (e_ra3) {}
                        } catch (e_rec) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][meta] recoil apply failed: " + string(e_rec)); }
                    }
                }

                    // Process status application (e.g., Sleep Powder, Poison Powder)
                    if (variable_struct_exists(_mm, "status") && string_length(string(variable_struct_get(_mm, "status"))) > 0){
                        var stid = string(variable_struct_get(_mm, "status"));
                        var stchance = (variable_struct_exists(_mm, "chance") && is_real(variable_struct_get(_mm, "chance"))) ? real(variable_struct_get(_mm, "chance")) : 100;
                        // clamp chance to 0..100
                        stchance = clamp(floor(stchance), 0, 100);
                        // If a status is present but chance is 0 (common CSV omission),
                        // treat it as 100% to match expected behavior for powders.
                        if (stchance <= 0){
                            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][meta] overriding zero chance to 100 for status=" + stid);
                            stchance = 100;
                        }
                        var roll = irandom(99);
                        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][meta] status apply attempt status=" + stid + ", chance=" + string(stchance) + ", roll=" + string(roll));
                        if (roll < stchance){
                            try {
                                    // Use status_system_apply_status on the defender
                                    if (!is_undefined(status_system_apply_status)){
                                        var opts = {};
                                        if (variable_struct_exists(_mm, "duration") && is_real(variable_struct_get(_mm, "duration"))) variable_struct_set(opts, "duration", variable_struct_get(_mm, "duration"));
                                        // source info useful for later (who applied)
                                        try { variable_struct_set(opts, "source", _A); } catch (e_src) {}
                                        // For trap-like statuses (Bind/Wrap/Clamp/Sand Tomb) ensure the
                                        // first tick doesn't immediately apply damage in the same turn
                                        // the move was used. The status system honors skip_first_tick.
                                        try { if (string(stid) == "trap") variable_struct_set(opts, "skip_first_tick", true); } catch (e_sft) {}
                                        var ok2 = status_system_apply_status(_D, stid, opts);
                                        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][meta] status_system_apply_status returned=" + string(ok2));
                                    }
                                } catch (e_stat) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][meta] status apply failed: " + string(e_stat)); }
                        }
                    }
                        // Imprison: prevent opposing Pokémon from using the same moves as the user
                                if (variable_struct_exists(_mm, "imprison") && variable_struct_get(_mm, "imprison") == true){
                                    try {
                                        var _Bslot = __battle_ensure_slot(_pid);
                                        if (is_struct(_Bslot)){
                                            // Build map of attacker's known moves (use _A.moves array if present)
                                            var known = {};
                                            var known_keys = [];
                                            if (variable_struct_exists(_A, "moves") && is_array(variable_struct_get(_A, "moves"))){
                                                var km = variable_struct_get(_A, "moves");
                                                for (var _mi = 0; _mi < array_length(km); _mi++){ if (is_real(km[_mi]) && km[_mi] > 0){ variable_struct_set(known, string(km[_mi]), true); array_push(known_keys, string(km[_mi])); } }
                                            }
                                            // fallback: if attacker has 'move_slots' or similar, try to find pps array paired with moves
                                            if (variable_struct_exists(_A, "move_slots") && is_array(variable_struct_get(_A, "move_slots"))){ var ms = variable_struct_get(_A, "move_slots"); for (var _mi2 = 0; _mi2 < array_length(ms); _mi2++){ if (is_real(ms[_mi2]) && ms[_mi2] > 0){ variable_struct_set(known, string(ms[_mi2]), true); array_push(known_keys, string(ms[_mi2])); } } }
                                            // attach keys array for later iteration
                                            variable_struct_set(known, "_keys", known_keys);
                                            // attach map on the target side (slot-level) so checks can be done during move selection
                                            if (!variable_struct_exists(_Bslot, "_imprisoned")) variable_struct_set(_Bslot, "_imprisoned", {});
                                            var imap = variable_struct_get(_Bslot, "_imprisoned");
                                            // Ensure consistent internal shapes: a string-keyed map (. _map) and a numeric id list (. _list)
                                            if (!variable_struct_exists(imap, "_map") || !is_struct(variable_struct_get(imap, "_map"))) variable_struct_set(imap, "_map", {});
                                            if (!variable_struct_exists(imap, "_list") || !is_array(variable_struct_get(imap, "_list"))) variable_struct_set(imap, "_list", []);
                                            var imap_map = variable_struct_get(imap, "_map");
                                            var imap_list = variable_struct_get(imap, "_list");
                                            // Mark each known move as imprisoned in both representations
                                            if (variable_struct_exists(known, "_keys") && is_array(variable_struct_get(known, "_keys"))){
                                                var _karr = variable_struct_get(known, "_keys");
                                                for (var _kk = 0; _kk < array_length(_karr); _kk++){
                                                    var mk = _karr[_kk];
                                                    if (string_length(mk) <= 0) continue;
                                                    // mark string-keyed map
                                                    variable_struct_set(imap_map, mk, true);
                                                    // also ensure numeric form in the list (if parseable)
                                                    var midnum = undefined;
                                                    try { midnum = real(mk); } catch (e_mid) { midnum = undefined; }
                                                    if (is_real(midnum)){
                                                        var found = false;
                                                        for (var _li = 0; _li < array_length(imap_list); _li++){ if (imap_list[_li] == midnum){ found = true; break; } }
                                                        if (!found) array_push(imap_list, midnum);
                                                    }
                                                }
                                            } else {
                                                // fallback: try common numeric indices or the known struct numeric keys
                                                for (var _ii = 0; _ii < 4; _ii++){
                                                    if (variable_struct_exists(known, string(_ii))){
                                                        var maybe = variable_struct_get(known, string(_ii));
                                                        if (is_real(maybe) && maybe > 0){ variable_struct_set(imap_map, string(maybe), true); var found2 = false; for (var _li2 = 0; _li2 < array_length(imap_list); _li2++){ if (imap_list[_li2] == maybe){ found2 = true; break; } } if (!found2) array_push(imap_list, maybe); }
                                                    }
                                                }
                                            }
                                            // write back normalized structures
                                            variable_struct_set(imap, "_map", imap_map);
                                            variable_struct_set(imap, "_list", imap_list);
                                            variable_struct_set(_Bslot, "_imprisoned", imap);
                                            // Optionally request a dialog
                                            try { __battle_request_animation_safe(_pid, { type: "imprison", actor: _A, target: _D }); } catch (e_im) {}
                                        }
                                    } catch (e_ip) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][meta] imprison apply failed: " + string(e_ip)); }
                        }
            }

            // Process explicit healing meta (e.g., Heal Pulse, Moonlight): applies to attacker
            if (variable_struct_exists(_mm, "healing") && is_real(variable_struct_get(_mm, "healing"))){
                var heal_v = real(variable_struct_get(_mm, "healing"));
                if (heal_v > 0){
                    var heal_amt2 = 0;
                    if (heal_v > 0 && heal_v <= 100){
                        heal_amt2 = floor(A_max * heal_v / 100);
                    } else {
                        heal_amt2 = floor(heal_v);
                    }
                    if (heal_amt2 > 0){
                        var newhp2 = min(A_max, A_before + heal_amt2);
                        try { __battle_set_hp_now(_A, newhp2); } catch (e_hs2) {}
                        try {
                            variable_struct_set(_A, "_hp_lerp_from", A_before);
                            variable_struct_set(_A, "_hp_lerp_to", newhp2);
                            variable_struct_set(_A, "_hp_lerp_start_ms", current_time);
                            variable_struct_set(_A, "_hp_lerp_dur", 400);
                            variable_struct_set(_A, "_hp_lerp_active", true);
                            if (variable_struct_exists(_A, "mon") && is_struct(variable_struct_get(_A, "mon"))){ var _mi2 = variable_struct_get(_A, "mon"); variable_struct_set(_mi2, "_hp_lerp_from", A_before); variable_struct_set(_mi2, "_hp_lerp_to", newhp2); variable_struct_set(_mi2, "_hp_lerp_start_ms", variable_struct_get(_A, "_hp_lerp_start_ms")); variable_struct_set(_mi2, "_hp_lerp_dur", variable_struct_get(_A, "_hp_lerp_dur")); variable_struct_set(_mi2, "_hp_lerp_active", true); }
                        } catch (e_l2) {}
                        try { __battle_request_animation_safe(_A, { type: "heal", amount: heal_amt2 }); } catch (e_ra2) {}
                    }
                }
            }

            // Process stat_changes entries (move_meta_stat_changes.csv)
            // Each entry in _mm.stat_changes is { stat_id, change }
            try {
                if (variable_struct_exists(_mm, "stat_changes") && is_array(variable_struct_get(_mm, "stat_changes"))){
                    var scs = variable_struct_get(_mm, "stat_changes");
                    for (var si = 0; si < array_length(scs); ++si){
                        var rec = scs[si];
                        if (!is_struct(rec)) continue;
                        var sid = (variable_struct_exists(rec, "stat_id") ? variable_struct_get(rec, "stat_id") : undefined);
                        var change = (variable_struct_exists(rec, "change") ? variable_struct_get(rec, "change") : undefined);
                        if (!is_real(sid) || !is_real(change)) continue;
                        // Map stat_id to internal stage key: 1=hp,2=atk,3=def,4=spa,5=spd,6=spe, 8=??(special cases)
                        function __stat_key_by_id(_id){ switch(floor(_id)){ case 1: return "hp"; case 2: return "atk"; case 3: return "def"; case 4: return "spa"; case 5: return "spd"; case 6: return "spe"; case 8: return "spa"; } return undefined; }
                        var sk = __stat_key_by_id(sid);
                        if (is_undefined(sk)) continue;
                        // Target stages stored on defender (_D)
                        if (!variable_struct_exists(_D, "_stages") || !is_struct(variable_struct_get(_D, "_stages"))) variable_struct_set(_D, "_stages", {});
                        var stobj = variable_struct_get(_D, "_stages");
                        var prev = (variable_struct_exists(stobj, sk) && is_real(variable_struct_get(stobj, sk))) ? variable_struct_get(stobj, sk) : 0;
                        var next = clamp(prev + floor(change), -6, 6);
                        variable_struct_set(stobj, sk, next);
                        // Write back
                        variable_struct_set(_D, "_stages", stobj);
                        // Request stat-change animation for defender
                        try { __battle_request_animation_safe(_pid, { type: "stat_change", target_index: variable_struct_exists(_D, "actor_index") ? variable_struct_get(_D, "actor_index") : (variable_struct_exists(_D, "slot") ? variable_struct_get(_D, "slot") : undefined), stat: sk, from: prev, to: next }); } catch (e_req) {}
                        // Enqueue concise stat message
                        try {
                            var aname = (variable_struct_exists(_D, "name") ? variable_struct_get(_D, "name") : "The Pokémon");
                            var applied_amt = next - prev; var sign_amt = (applied_amt > 0) ? ("+" + string(applied_amt)) : string(applied_amt);
                            var sc_msg = "";
                            if (applied_amt == 0) sc_msg = string(aname) + "'s " + string_upper(string(sk)) + " won't go any lower!";
                            else sc_msg = string(aname) + " " + string_upper(string(sk)) + " " + string(sign_amt);
                            var _target_mon_ref = _D; if (is_struct(_D) && variable_struct_exists(_D, "mon") && is_struct(variable_struct_get(_D, "mon"))) _target_mon_ref = variable_struct_get(_D, "mon");
                            if (!is_undefined(__status_request_dialog_for_mon)) __status_request_dialog_for_mon(_target_mon_ref, sc_msg);
                        } catch (e_msg) {}
                        try { var _B2 = __battle_ensure_slot(_pid); if (is_struct(_B2)) variable_struct_set(_B2, "_meta_effect_applied", true); } catch (e_b2) {}
                    }
                }
            } catch (e_scl) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][meta] stat_changes apply failed: " + string(e_scl)); }

        } catch (e_meta){ if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][meta] apply failed: " + string(e_meta)); }

        return undefined;
    }
}

if (is_undefined(__battle_get_weather)){
    function __battle_get_weather(_pid){ try { var _B = __battle_ensure_slot(_pid); return (is_struct(_B) && variable_struct_exists(_B, "_weather") ? variable_struct_get(_B, "_weather") : undefined); } catch (e) { return undefined; } }
}

if (is_undefined(__battle_clear_weather)){
    function __battle_clear_weather(_pid){ try { var _B = __battle_ensure_slot(_pid); if (is_struct(_B)) variable_struct_set(_B, "_weather", undefined); } catch (e) {} }
}

if (is_undefined(__battle_request_animation_safe)){
    function __battle_request_animation_safe(_pid_or_mon, _payload){
        try {
            if (is_real(_pid_or_mon)){
                var _B = __battle_ensure_slot(_pid_or_mon);
                if (is_struct(_B)){
                    if (!variable_struct_exists(_B, "_pending_anims") || !is_array(variable_struct_get(_B, "_pending_anims"))) variable_struct_set(_B, "_pending_anims", []);
                    var arr = variable_struct_get(_B, "_pending_anims"); array_push(arr, _payload);
                }
                return;
            }
            // If a mon struct is provided, attempt to enqueue a mon-specific dialog
            if (is_struct(_pid_or_mon)){
                try { if (!is_undefined(__status_request_dialog_for_mon)) __status_request_dialog_for_mon(_pid_or_mon, (is_struct(_payload) && variable_struct_exists(_payload, "msg") ? variable_struct_get(_payload, "msg") : undefined)); } catch (e) {}
            }
        } catch (e) {}
    }
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
        // No legacy fallback: if audio_create_stream is available we'll try that later
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

    // Optional gated debug dump for battle-open state (useful for hazard/move meta debugging)
    try {
        if (variable_global_exists("BATTLE_META_DEBUG") && global.BATTLE_META_DEBUG){
            try {
                show_debug_message("[battle][open][dbg] pid=" + string(_pid) + " created; initial state dump:");
                show_debug_message("[battle][open][dbg] phase=" + string(_B.phase) + ", phase_durs=" + string(_B.phase_durs));
                var sflags = "spikes=" + string((variable_struct_exists(_B, "_side_spikes") ? variable_struct_get(_B, "_side_spikes") : "<unset>")) + ", toxic=" + string((variable_struct_exists(_B, "_side_toxic_spikes") ? variable_struct_get(_B, "_side_toxic_spikes") : "<unset>")) + ", stealth=" + string((variable_struct_exists(_B, "_side_stealth_rock") ? variable_struct_get(_B, "_side_stealth_rock") : "<unset>")) + ", sticky=" + string((variable_struct_exists(_B, "_side_sticky_web") ? variable_struct_get(_B, "_side_sticky_web") : "<unset>"));
                show_debug_message("[battle][open][dbg] hazard_flags: " + sflags);
            } catch (e_dbgopen) { show_debug_message("[battle][open][dbg] dump failed: " + string(e_dbgopen)); }
        }
    } catch (e_bdbg) { /* non-fatal */ }

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
    // Guard access to mons (some analyzers complain about undeclared symbols);
    // ensure _mons is a valid array for subsequent loops.
    var _mons = (is_struct(_P) && variable_struct_exists(_P, "mons") && is_array(_P.mons)) ? _P.mons : [];
    var _first = 0;
    for (var _i=0; _i<array_length(_mons); ++_i){
        var _m = _mons[_i];
        if (!is_undefined(_m) && is_struct(_m) && variable_struct_exists(_m,"hp") && _m.hp > 0){ _first = _i; break; }
    }
    // Read the canonical persisted mon from the party model to avoid stale copies
    var _pm = party_model_get_mon(_pid, _first);
    if (is_undefined(_pm) || !is_struct(_pm)) _pm = _mons[_first];

    _B.actor = [];
    _B.actor[0] = __battle_actor_from_party_mon(_pm);
    // Debug: log moves on open to diagnose stale copies
    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){
        try {
            var dbg_pm = party_model_get_mon(_pid, _first);
            var dbg_pm_moves = (is_struct(dbg_pm) && variable_struct_exists(dbg_pm, "moves")) ? string(variable_struct_get(dbg_pm, "moves")) : "<no-moves>";
            var dbg_local_moves = (is_struct(_pm) && variable_struct_exists(_pm, "moves")) ? string(variable_struct_get(_pm, "moves")) : "<no-moves>";
            var dbg_actor_moves = (is_struct(_B.actor[0]) && variable_struct_exists(_B.actor[0], "moves")) ? string(variable_struct_get(_B.actor[0], "moves")) : "<no-moves>";
            show_debug_message("[battle_open][dbg_moves] pid=" + string(_pid) + ", slot=" + string(_first) + ", party_model_get_mon.moves=" + dbg_pm_moves + ", _pm.moves=" + dbg_local_moves + ", actor.moves=" + dbg_actor_moves);
        } catch (e_dbgm) { /* ignore */ }
    }

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
            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][audio] stopping battle_music resource: " + string(_bm_res));
            try { if (!is_undefined(audio_stop_sound)) audio_stop_sound(_bm_res); else __battle_audio_stop_handle(_bm_res); } catch (ee) {}
        }
        var _bdm = (variable_struct_exists(_B, "_battle_defeated_music") ? variable_struct_get(_B, "_battle_defeated_music") : undefined);
        if (!is_undefined(_bdm)){
            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][audio] stopping defeated_music resource: " + string(_bdm));
            try { if (!is_undefined(audio_stop_sound)) audio_stop_sound(_bdm); else __battle_audio_stop_handle(_bdm); } catch (ee2) {}
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

    // Centralized restore: stop any battle audio and restore previously playing audio.
    // If no previous audio was captured, fall back to playing the configured region music
    try {
        var _prev_audio_local = (variable_struct_exists(_B, "_prev_audio") ? variable_struct_get(_B, "_prev_audio") : undefined);
        try { __battle_restore_prev_audio(_pid); } catch (e_rr) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][audio] __battle_restore_prev_audio failed: " + string(e_rr)); }

        // If there was no previous audio to restore, attempt to play the region BGM if available.
        if (is_undefined(_prev_audio_local) || _prev_audio_local == undefined) {
            if (variable_global_exists("_REGIONMUSIC") && !is_undefined(global._REGIONMUSIC) && global._REGIONMUSIC != undefined) {
                try {
                    if (!is_undefined(audio_play_sound)) {
                        audio_play_sound(global._REGIONMUSIC, 1, true);
                        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][audio] played region music res=" + string(global._REGIONMUSIC));
                    }
                } catch (e_reg) {
                    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][audio] failed to play region music: " + string(e_reg));
                }
            }
        }
    } catch (e_rrall) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][audio] restore/fallback failed: " + string(e_rrall)); }
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
    try { if (variable_global_exists("DIALOG_DEBUG") && global.DIALOG_DEBUG){ show_debug_message("[battle][dialog] detected open pid=" + string(_pid) + ", page_idx=" + string(page) + ", phase=" + string(_B.phase)); } } catch(e){}
        return;
    }

    // If a dialog just closed
    if (variable_struct_exists(_B, "_dlg_active") && _B._dlg_active){
        var now3 = current_time;
        _B._dlg_active = false;
        _B._dlg_page_last = -1;
        try { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){ var _tq_len = (variable_struct_exists(_B, "turn_queue") && is_array(variable_struct_get(_B, "turn_queue")) ? string(array_length(variable_struct_get(_B, "turn_queue"))) : "<nil>"); show_debug_message("[battle][dialog] closed pid=" + string(_pid) + ", phase_before=" + string(_B.phase) + ", turn_i=" + string(_B.turn_i) + ", turn_queue_len=" + _tq_len); } } catch(e){}
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
                        var __pm_tmp = party_model_get_mon(_pid, idx);
                        if (is_undefined(__pm_tmp) || !is_struct(__pm_tmp)) __pm_tmp = P.mons[idx];
                        // Before replacing actor, capture reference to outgoing actor so we can
                        // clear any 'trap' status on the switching-out Pokémon (Gen3 behavior: switching
                        // frees trapped Pokémon).
                        var _outgoing = undefined;
                        try { if (is_struct(_B.actor[0])) _outgoing = _B.actor[0]; } catch (e_out) { _outgoing = undefined; }
                        _B.actor[0] = __battle_actor_from_party_mon(__pm_tmp);
                        // If auto_apply is enabled, also update the canonical party ordering
                        // so the party_model reflects the swap that visually occurred.
                        try {
                            if (auto_apply && !is_undefined(party_model_swap) && is_struct(_outgoing)){
                                // Attempt to locate the outgoing mon's index in the party by matching
                                // a stable identifier (prefer idno when available) or by reference.
                                var _found_idx = undefined;
                                try {
                                    var _mons_arr = party_model_get_mons(_pid);
                                    for (var _ii = 0; _ii < array_length(_mons_arr); ++_ii){
                                        var _cand = _mons_arr[_ii];
                                        if (!is_struct(_cand)) continue;
                                        // Prefer exact struct reference match when possible by checking inner .mon when available
                                        try {
                                            var _out_mon_ref = undefined;
                                            if (variable_struct_exists(_outgoing, "mon")) _out_mon_ref = variable_struct_get(_outgoing, "mon"); else _out_mon_ref = _outgoing;
                                            if (is_struct(_out_mon_ref) && _cand == _out_mon_ref){ _found_idx = _ii; break; }
                                        } catch (e_ref) { }
                                        // Fallback: match by idno when present
                                        try {
                                            if (variable_struct_exists(_cand, "idno") && variable_struct_exists(_outgoing, "idno") && variable_struct_get(_cand, "idno") == variable_struct_get(_outgoing, "idno")) { _found_idx = _ii; break; }
                                        } catch (ee){}
                                        // Fallback: match by species_id + name
                                        try {
                                            if (variable_struct_exists(_cand, "species_id") && variable_struct_exists(_outgoing, "species_id") && variable_struct_get(_cand, "species_id") == variable_struct_get(_outgoing, "species_id")){
                                                if (variable_struct_exists(_cand, "name") && variable_struct_exists(_outgoing, "name") && string(variable_struct_get(_cand, "name")) == string(variable_struct_get(_outgoing, "name"))){ _found_idx = _ii; break; }
                                            }
                                        } catch (ee2){}
                                    }
                                } catch (e_find) { _found_idx = undefined; }
                                if (is_real(_found_idx) && _found_idx >= 0 && _found_idx < array_length(P.mons) && _found_idx != idx){
                                    // Perform canonical swap and emit a debug trace so callers can observe the change
                                    try {
                                        party_model_swap(_pid, _found_idx, idx);
                                        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][switch_in][applied_swap] pid=" + string(_pid) + ", src=" + string(_found_idx) + ", dst=" + string(idx));
                                    } catch (e_swap_apply){ if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][switch_in] party_model_swap failed: " + string(e_swap_apply)); }
                                }
                            }
                        } catch (e_swap_safe) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][switch_in] swap-safe check failed: " + string(e_swap_safe)); }
                        // Do not mutate the canonical party ordering here. Instead,
                        // update the party selection so UI panels opened after the
                        // switch will focus the active Pokémon.
                        try {
                            var _P_up = party_ensure(_pid);
                            if (is_struct(_P_up) && is_real(idx)){
                                _P_up.sel = clamp(idx, 0, max(0, array_length(_P_up.mons) - 1));
                                // ensure scroll shows the selected slot
                                var _rows_local = 6;
                                _P_up.scroll = clamp(_P_up.sel, 0, max(0, array_length(_P_up.mons) - _rows_local));
                            }
                        } catch (e_sel) { /* non-fatal */ }
                        // If outgoing had a trap status, clear it (also try clearing inner .mon)
                        try {
                            if (!is_undefined(status_system_clear_status) && is_struct(_outgoing)){
                                // Prefer clearing on actor wrapper first
                                status_system_clear_status(_outgoing, "trap");
                                // Also try inner mon
                                if (variable_struct_exists(_outgoing, "mon") && is_struct(variable_struct_get(_outgoing, "mon"))) status_system_clear_status(variable_struct_get(_outgoing, "mon"), "trap");
                            }
                        } catch (e_cl) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][switch] failed clearing trap on outgoing: " + string(e_cl)); }
                        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){
                            try {
                                var dbg_p_moves = (is_struct(__pm_tmp) && variable_struct_exists(__pm_tmp, "moves")) ? string(variable_struct_get(__pm_tmp, "moves")) : "<no-moves>";
                                var dbg_arr_moves = (is_struct(P.mons[idx]) && variable_struct_exists(P.mons[idx], "moves")) ? string(variable_struct_get(P.mons[idx], "moves")) : "<no-moves>";
                                var dbg_act_moves = (is_struct(_B.actor[0]) && variable_struct_exists(_B.actor[0], "moves")) ? string(variable_struct_get(_B.actor[0], "moves")) : "<no-moves>";
                                show_debug_message("[battle][switch_in][dbg_moves] pid=" + string(_pid) + ", idx=" + string(idx) + ", party_model_get_mon.moves=" + dbg_p_moves + ", P.mons[idx].moves=" + dbg_arr_moves + ", actor.moves=" + dbg_act_moves);
                            } catch (e_dbg2) { /* ignore */ }
                        }
                        // Apply entry hazards (spikes/rocks/toxic/sticky web) to the newly switched-in mon
                        try { __battle_apply_entry_hazards(_pid, 0); } catch (e_eh) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][hazards] apply entry hazards error: " + string(e_eh)); }
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
                // Open the party UI while in battle so player can view/swaps.
                // party_open will set up the party state. party_input/party_draw
                // already include guards to prevent move edits while in battle.
                try {
                    if (!is_undefined(party_open)){
                        party_open(_pid);
                        // Mark party as opened from battle so party_input can enable submenu navigation
                        try {
                            if (!is_undefined(party_ensure)){
                                var __Ptmp = party_ensure(_pid);
                                if (is_struct(__Ptmp)){
                                    variable_struct_set(__Ptmp, "in_battle_view", true);
                                    // Lower the lock so the player can immediately navigate the submenu
                                    variable_struct_set(__Ptmp, "lock", 0);
                                }
                            }
                        } catch (e_tmp){}
                    } else {
                        __battle_stub_dialog(_pid, "You checked your party.\n(TODO: switch Pokémon)");
                    }
                } catch (e_party) {
                    __battle_stub_dialog(_pid, "You examined your party.");
                }
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

            // Debug: log chosen move vs actor's stored move for this slot
            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){
                var __moves_arr = (is_struct(A) && variable_struct_exists(A, "moves")) ? variable_struct_get(A, "moves") : [];
                var act_mv = (is_array(__moves_arr) && is_real(move_idx) && move_idx >= 0 && move_idx < array_length(__moves_arr)) ? __moves_arr[move_idx] : undefined;
                show_debug_message("[battle_select][fight] pid=" + string(_pid) + ", slot=" + string(move_idx) + ", mv_selected=" + string(mv) + ", actor.moves[slot]=" + string(act_mv));
            }

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

    // Determine order by move priority first, then Speed (tie-break: random)
    var spP = __battle_stat_get(_B.actor[0], "spd");
    var spE = __battle_stat_get(_B.actor[1], "spd");
    var firstEnemy = false;
    // Compute effective priority for each action (default 0). If an action isn't a move
    // (item use, undefined), it keeps priority 0. Higher priority acts first.
    var prP = 0; var prE = 0;
    try {
        if (is_struct(actP) && variable_struct_exists(actP, "move_id") && is_real(variable_struct_get(actP, "move_id"))){
            prP = scr_move_priority_by_id(variable_struct_get(actP, "move_id"));
        }
    } catch (e_prp) { prP = 0; }
    try {
        if (is_struct(actE) && variable_struct_exists(actE, "move_id") && is_real(variable_struct_get(actE, "move_id"))){
            prE = scr_move_priority_by_id(variable_struct_get(actE, "move_id"));
        }
    } catch (e_pre) { prE = 0; }

    if (prP > prE) firstEnemy = false;
    else if (prP < prE) firstEnemy = true;
    else {
        // Same priority: fall back to Speed (tie-break random when equal)
        firstEnemy = (spE > spP) || (spE == spP && choose(true,false));
    }

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
                                // DEVDEBUG: log identity when Protect is set so we can trace failures
                                try {
                                    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){
                                        var _aname_dbg = "unknown";
                                        if (variable_struct_exists(actRef, "name")) _aname_dbg = variable_struct_get(actRef, "name");
                                        else if (variable_struct_exists(actRef, "mon") && is_struct(variable_struct_get(actRef, "mon")) && variable_struct_exists(variable_struct_get(actRef, "mon"), "name")) _aname_dbg = variable_struct_get(variable_struct_get(actRef, "mon"), "name");
                                        show_debug_message("[battle][protect][set] actor_index=" + string(aidx) + " move_id=" + string(mid) + " name=" + string(_aname_dbg));
                                    }
                                } catch (e_dbg) {}
                            }
                        }
                    }
                }
            }
        }
    } catch (e_immed) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][build_actions] immediate-effect apply failed: " + string(e_immed)); }

    // DEVDEBUG: log the built action queue for this turn (pid + concise per-action info)
    try {
        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){
            var __dbg_actions = "[battle][build_turn_actions] pid=" + string(_pid) + ", actions_len=" + string(array_length(actions)) + ", entries=[";
            for (var __ai=0; __ai < array_length(actions); __ai++){
                var __act = actions[__ai];
                var __part = "nil";
                try {
                    if (is_struct(__act)){
                        var __aidx = (variable_struct_exists(__act, "actor_index") ? string(variable_struct_get(__act, "actor_index")) : "?");
                        var __tidx = (variable_struct_exists(__act, "target_index") ? string(variable_struct_get(__act, "target_index")) : "?");
                        var __mid = (variable_struct_exists(__act, "move_id") ? string(variable_struct_get(__act, "move_id")) : "");
                        var __iu = (variable_struct_exists(__act, "item_use") && variable_struct_get(__act, "item_use") == true) ? "item" : "move";
                        __part = "actor=" + __aidx + ",target=" + __tidx + ",type=" + __iu + (string_length(__mid)>0 ? ",move=" + __mid : "");
                    }
                } catch (e_dbg_act) { __part = "err"; }
                __dbg_actions += __part + ( (__ai < array_length(actions)-1) ? "," : "" );
            }
            __dbg_actions += "]";
            show_debug_message(__dbg_actions);
        }
    } catch (e_dbg) {}

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
            // show a short per-hit dialog with explicit target/move/count: "{Target} was hit by {Move} ({count} times)!"
            try {
                var tgt_name = (variable_struct_exists(Dact, "name") ? variable_struct_get(Dact, "name") : "The target");
                var mv_name_pm = (is_real(mov) ? __battle_move_name(mov) : "the move");
                // compute how many times this target has been hit so far in the sequence
                var total_hits = (variable_struct_exists(pm, "total_hits") ? variable_struct_get(pm, "total_hits") : undefined);
                var remaining_now = (variable_struct_exists(pm, "remaining") ? floor(variable_struct_get(pm, "remaining")) : 0);
                var hit_count = (is_real(total_hits) ? (total_hits - remaining_now) : 1);
                var times_txt = string(hit_count) + " time" + (hit_count == 1 ? "" : "s");
                var hitMsg = string(tgt_name) + " was hit by " + mv_name_pm + " (" + times_txt + ")!";
                __battle_stub_dialog(_pid, hitMsg);
            } catch (e_msg){
                // fallback to the generic message if anything goes wrong
                __battle_stub_dialog(_pid, "It hit!");
                if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][pending_hit] multi-hit dialog build failed: " + string(e_msg));
            }
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
// __battle_perform_action implementation has been moved to battle_moves_impls.gml (__battle_perform_action_impl).
// The thin delegating wrapper near the top of this file will call the impl when present.

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
function __battle_move_power(_code, _A, _D){
    if (is_real(_code) && _code >= 0){
        if (!is_undefined(scr_move_power_by_id)){
            var p = scr_move_power_by_id(_code);
            // If the data-layer returns a positive numeric power, use it.
            // If it returns 0 it usually means 'unspecified / variable power' in the dataset;
            // treat that the same as no value so the fallback applies instead of
            // causing the move to be treated as non-damaging.
            if (is_real(p) && p > 0) return max(0, real(p));
                    // Special-case: Fury Cutter (move id 210) scales with a per-attacker multiplier
                    // stored on the attacker struct as _fury_cutter_mul. If present, apply it.
                    try {
                        if (_code == 210 && is_struct(_A)){
                            var _mul = 1;
                            try { if (variable_struct_exists(_A, "_fury_cutter_mul") && is_real(variable_struct_get(_A, "_fury_cutter_mul"))) _mul = max(1, floor(variable_struct_get(_A, "_fury_cutter_mul"))); } catch (e_m) { _mul = 1; }
                            return max(0, real(p) * _mul);
                        }
                    } catch (e_fc) { }
            // If p is zero or unspecified, attempt known variable-power move calculations
            var vp = __battle_variable_move_power(_code, _A, _D);
            if (is_real(vp) && vp > 0) return vp;
            // If no explicit or variable power identified, treat as status/no-damage (0).
            return 0;
        }
    }
    return 0; // fallback to status/no-damage when move power is unspecified
}

// Read an entity's weight (kg) from actor/mon struct or from species table as fallback.
// Normalize and read an entity's weight (returns kg as real). Supports actor/mon structs and species table.
function __battle_entity_weight(_ent){
    try {
        if (!is_undefined(_ent) && is_struct(_ent)){
            // prefer direct weight field
            if (variable_struct_exists(_ent, "weight") && is_real(variable_struct_get(_ent, "weight"))){
                // Normalize stored weight to kilograms. The project's CSV stores
                // weights as integers (hectograms) by convention (e.g. Bulbasaur=69).
                // Convert to kg for engine formulas by dividing by 10.
                var raww = real(variable_struct_get(_ent, "weight"));
                return __battle_weight_to_kg(raww);
            }
            // inner mon fallback
            if (variable_struct_exists(_ent, "mon") && is_struct(variable_struct_get(_ent, "mon"))){
                var mi = variable_struct_get(_ent, "mon");
                if (variable_struct_exists(mi, "weight") && is_real(variable_struct_get(mi, "weight"))) return __battle_weight_to_kg(real(variable_struct_get(mi, "weight")));
                if (variable_struct_exists(mi, "species_id") && is_real(variable_struct_get(mi, "species_id"))){
                    var sid = variable_struct_get(mi, "species_id");
                    if (variable_global_exists("_pokemon") && is_array(global._pokemon) && sid >= 0 && sid < array_length(global._pokemon)){
                        var sp = global._pokemon[sid];
                        if (is_struct(sp) && variable_struct_exists(sp, "weight") && is_real(variable_struct_get(sp, "weight"))) return __battle_weight_to_kg(real(variable_struct_get(sp, "weight")));
                    }
                }
            }
        }
    } catch (e_wt){ }
    return 0;
}

// Convert a raw weight value from the data layer into kilograms.
// The project's CSV typically stores weight in hectograms (hg). This helper
// converts that to kg by dividing by 10. If the input is already small (< 100)
// it is likely already kg-ish, but we still divide by 10 for consistency with
// the data loader (which stores integers in hg). If that causes mismatch for
// your project, adjust this helper accordingly.
function __battle_weight_to_kg(_raw){
    if (!is_real(_raw)) return 0;
    var r = real(_raw);
    // Defensive: if value looks extremely small (<= 0) return 0
    if (r <= 0) return 0;
    // Most reliable dataset convention: weights stored in hectograms (hg).
    // Convert to kg.
    return r / 10.0;
}

// Compute variable move power for known weight-based moves using explicit contexts.
// Returns a positive integer power or 0 if not applicable.
function __battle_variable_move_power(_move_id, _A, _D){
    if (!is_real(_move_id)) return 0;
    var mid = floor(_move_id);
    // Extract weights (best-effort). The helper returns a raw weight value;
    // callers should normalize if species weights are in hectograms elsewhere.
    var aw = __battle_entity_weight(_A);
    var dw = __battle_entity_weight(_D);

    // If both weights missing, cannot compute here
    if ((aw <= 0 || is_undefined(aw)) && (dw <= 0 || is_undefined(dw))) return 0;

    // Low Kick / Grass Knot: power by defender weight (kg) thresholds
    if (mid == 67 || mid == 447){
        var w = dw;
        if (w <= 0) return 0;
        if (w < 10) return 20;
        else if (w < 25) return 40;
        else if (w < 50) return 60;
        else if (w < 100) return 80;
        else if (w < 200) return 100;
        else return 120;
    }

    // Heavy Slam / Heat Crash: power depends on attacker/defender weight ratio
    if (mid == 484 || mid == 535){
        if (aw <= 0 || dw <= 0) return 0;
        var ratio = aw / dw;
        if (ratio >= 2.0) return 120;
        else if (ratio >= 1.5) return 100;
        else if (ratio >= 1.0) return 80;
        else if (ratio >= 0.5) return 60;
        else if (ratio >= 0.25) return 40;
        else return 20;
    }

    // Gyro Ball: stronger when target is faster; dataset id 360
    if (mid == 360){
        // Need speeds from actors; fallback to 0
        var aspeed = 0; var dspeed = 0;
        try { if (is_struct(_A) && variable_struct_exists(_A, "spe")) aspeed = variable_struct_get(_A, "spe"); else if (is_struct(_A) && variable_struct_exists(_A, "speed")) aspeed = variable_struct_get(_A, "speed"); } catch (e) {}
        try { if (is_struct(_D) && variable_struct_exists(_D, "spe")) dspeed = variable_struct_get(_D, "spe"); else if (is_struct(_D) && variable_struct_exists(_D, "speed")) dspeed = variable_struct_get(_D, "speed"); } catch (e) {}
        if (aspeed <= 0 || dspeed <= 0) return 0;
        var ratio_sp = dspeed / max(1, aspeed);
        var power_g = floor(25 * ratio_sp);
        return clamp(power_g, 1, 150);
    }

    // Fixed/Level-based moves and special power moves (Gen3 / Emerald semantics)
    // Dragon Rage: fixed 40
    if (mid == 82) return 40;
    // Sonic Boom: fixed 20
    if (mid == 49) return 20;
    // Seismic Toss: damage equal to attacker's level
    if (mid == 69){ if (is_struct(_A) && variable_struct_exists(_A, "level") && is_real(variable_struct_get(_A, "level"))) return floor(variable_struct_get(_A, "level")); return 0; }
    // Night Shade: damage equal to attacker's level
    if (mid == 101){ if (is_struct(_A) && variable_struct_exists(_A, "level") && is_real(variable_struct_get(_A, "level"))) return floor(variable_struct_get(_A, "level")); return 0; }
    // Super Fang / similar special-case moves have their own damage semantics implemented in the damage application path.
    if (mid == 162) return 1; // placeholder positive value so the resolver will call the damage path
    // False Swipe: keep power but special effect handled after damage (we still allow data power to apply)
    if (mid == 206) return 40;

    // Electro Ball: power by speed ratio attacker/defender (id 486)
    if (mid == 486){
        var as2 = 0; var ds2 = 0;
        try { if (is_struct(_A) && variable_struct_exists(_A, "spe")) as2 = variable_struct_get(_A, "spe"); else if (is_struct(_A) && variable_struct_exists(_A, "speed")) as2 = variable_struct_get(_A, "speed"); } catch (e) {}
        try { if (is_struct(_D) && variable_struct_exists(_D, "spe")) ds2 = variable_struct_get(_D, "spe"); else if (is_struct(_D) && variable_struct_exists(_D, "speed")) ds2 = variable_struct_get(_D, "speed"); } catch (e) {}
        if (as2 <= 0 || ds2 <= 0) return 0;
        var r = as2 / ds2;
        if (r >= 4.0) return 150;
        else if (r >= 3.0) return 120;
        else if (r >= 2.0) return 80;
        else if (r >= 1.5) return 60;
        else if (r >= 1.0) return 40;
        else return 20;
    }

    // Crush Grip / Wring Out / Eruption / Flail / Reversal: power scales with target HP% or attacker's HP
    // Crush Grip (462) and Wring Out (378) — power increases as target's current HP decreases
    if (mid == 462 || mid == 378){
        try {
            var cur = 0; var mx = 1;
            if (is_struct(_D)){
                if (variable_struct_exists(_D, "hp_now")) cur = variable_struct_get(_D, "hp_now"); else if (variable_struct_exists(_D, "hp")) cur = variable_struct_get(_D, "hp");
                if (variable_struct_exists(_D, "hp_max")) mx = variable_struct_get(_D, "hp_max"); else if (is_struct(_D.mon) && variable_struct_exists(_D.mon, "hp_max")) mx = variable_struct_get(_D.mon, "hp_max");
            }
            if (mx <= 0) return 0;
            var pct = clamp(cur / mx, 0.0, 1.0);
            // Map to a simple linear scaling: min 1 -> max 200
            var power_c = floor(200 * (1.0 - pct));
            return clamp(power_c, 1, 200);
        } catch (e_cr) { return 0; }
    }

    // Eruption (284) and Flail (175) and Reversal (179) — power increases as attacker's HP decreases (Eruption reverse)
    if (mid == 284){
        // Eruption: power = floor(150 * (cur_hp / max_hp)) typical
        try {
            var curA = 0; var maxA = 1;
            if (is_struct(_A)){
                if (variable_struct_exists(_A, "hp_now")) curA = variable_struct_get(_A, "hp_now"); else if (variable_struct_exists(_A, "hp")) curA = variable_struct_get(_A, "hp");
                if (variable_struct_exists(_A, "hp_max")) maxA = variable_struct_get(_A, "hp_max"); else if (is_struct(_A.mon) && variable_struct_exists(_A.mon, "hp_max")) maxA = variable_struct_get(_A.mon, "hp_max");
            }
            if (maxA <= 0) return 0;
            var p = floor(150 * clamp(curA / maxA, 0.0, 1.0));
            return clamp(p, 1, 150);
        } catch (e_er) { return 0; }
    }
    if (mid == 175 || mid == 179){
        // Flail/Reversal: stronger as user's HP decreases
        try {
            var cA = 0; var mA = 1;
            if (is_struct(_A)){
                if (variable_struct_exists(_A, "hp_now")) cA = variable_struct_get(_A, "hp_now"); else if (variable_struct_exists(_A, "hp")) cA = variable_struct_get(_A, "hp");
                if (variable_struct_exists(_A, "hp_max")) mA = variable_struct_get(_A, "hp_max"); else if (is_struct(_A.mon) && variable_struct_exists(_A.mon, "hp_max")) mA = variable_struct_get(_A.mon, "hp_max");
            }
            if (mA <= 0) return 0;
            var pctA = clamp(cA / mA, 0.0, 1.0);
            // Use a tiered mapping similar to Gen3: lower HP gives higher power
            if (pctA <= 1/48) return 200;
            else if (pctA <= 1/16) return 150;
            else if (pctA <= 1/8) return 100;
            else if (pctA <= 1/4) return 80;
            else if (pctA <= 1/2) return 40;
            else return 20;
        } catch (e_fr) { return 0; }
    }

    // Magnitude: random magnitude level -> power mapping (id 222)
    if (mid == 222){
        // Classic Gen mapping: magnitude has levels 4..10 with powers roughly [10,30,50,70,90,110,150]
        var mag = irandom_range(4,10);
        switch (mag){
            case 4: return 10;
            case 5: return 30;
            case 6: return 50;
            case 7: return 70;
            case 8: return 90;
            case 9: return 110;
            case 10: return 150;
            default: return 10;
        }
    }

    // Beat Up (id 251): one hit per non-sent-out party member; approximate by using the attacker's party length
    if (mid == 251){
        // If attacker carries a party list, count its members and return a small per-member power.
        try {
            var count = 0;
            if (is_struct(_A) && variable_struct_exists(_A, "party") && is_array(variable_struct_get(_A, "party"))) count = array_length(variable_struct_get(_A, "party"));
            // Fallback: if inner mon has party info
            else if (is_struct(_A) && variable_struct_exists(_A, "mon") && is_struct(variable_struct_get(_A, "mon")) && variable_struct_exists(variable_struct_get(_A, "mon"), "party") && is_array(variable_struct_get(variable_struct_get(_A, "mon"), "party"))) count = array_length(variable_struct_get(variable_struct_get(_A, "mon"), "party"));
            if (count <= 0) count = 1;
            // Beat Up in older gens: each member deals a small hit, we approximate by scaling total power to count*10
            return clamp(count * 10, 10, 200);
        } catch (e_bu){ return 0; }
    }

    return 0;
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
    try { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){ show_debug_message("[battle][switch_to] pid=" + string(_pid) + ", party_idx=" + string(_party_idx) + ", opts=" + string(_opts)); } } catch(e){}
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

    // Copy relevant move arrays/fields out of the source mon into locals BEFORE mutating
    // the actor. This avoids corrupting the source when _A and m alias the same struct.
    var _mvArr_local = undefined;
    var _ppArr_local = undefined;
    if (is_struct(m) && variable_struct_exists(m, "moves") && is_array(variable_struct_get(m, "moves"))){
        var __tmp_mv = variable_struct_get(m, "moves");
        _mvArr_local = [];
        for (var __ci = 0; __ci < array_length(__tmp_mv); __ci++) array_push(_mvArr_local, __tmp_mv[__ci]);
    }
    if (is_struct(m) && variable_struct_exists(m, "pps") && is_array(variable_struct_get(m, "pps"))){
        var __tmp_pp = variable_struct_get(m, "pps");
        _ppArr_local = [];
        for (var __cj = 0; __cj < array_length(__tmp_pp); __cj++) array_push(_ppArr_local, __tmp_pp[__cj]);
    }

    // Initialize actor move/pp slots now that we have a local copy of the source data
    for (var i=0; i<4; ++i){ _A.moves[i] = -1; _A.pps[i] = 0; }

    // CASE 1: mon.moves array
    if (is_array(_mvArr_local)){
        var mvArr = _mvArr_local;
        var ppArr = (is_array(_ppArr_local)) ? _ppArr_local : undefined;

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
// Return a visual HP value for UI drawing that respects any active lerp animation.
function __battle_hp_visual(_ent){
    try {
        if (!is_struct(_ent)) return __battle_hp_now(_ent);
        var active = (variable_struct_exists(_ent, "_hp_lerp_active") && variable_struct_get(_ent, "_hp_lerp_active") == true);
        if (!active){
            // fall back to canonical hp_now
            return __battle_hp_now(_ent);
        }
        var from = variable_struct_exists(_ent, "_hp_lerp_from") ? variable_struct_get(_ent, "_hp_lerp_from") : __battle_hp_now(_ent);
        var to   = variable_struct_exists(_ent, "_hp_lerp_to")   ? variable_struct_get(_ent, "_hp_lerp_to")   : __battle_hp_now(_ent);
        var start = variable_struct_exists(_ent, "_hp_lerp_start_ms") ? variable_struct_get(_ent, "_hp_lerp_start_ms") : current_time;
        var dur = variable_struct_exists(_ent, "_hp_lerp_dur") ? variable_struct_get(_ent, "_hp_lerp_dur") : 400;
        var t = 0.0;
        if (is_real(dur) && dur > 0) t = clamp((current_time - start) / dur, 0, 1);
        var cur = floor(lerp(from, to, t));
        // If lerp completed, deactivate
        if (t >= 1.0){
            variable_struct_set(_ent, "_hp_lerp_active", false);
            // ensure canonical hp_now is up-to-date
            __battle_set_hp_now(_ent, to);
        }
        return cur;
    } catch (e_vis){ if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][hp_visual] error: " + string(e_vis)); return __battle_hp_now(_ent); }
}
// Play an impact sound using audio_play_sound (fallback to sound_play) and
// start the visual HP lerp on the provided entity. _mult is optional
// effectiveness multiplier (useful to choose Super/NotVery/Eff).
function __battle_trigger_hit_effect(_pid, _ent, _before, _after, _mult){
    try {
        if (!is_struct(_ent)) return;
        // Visible debug: report that the trigger was called and brief context
        try {
            var _ename = (variable_struct_exists(_ent, "name") ? string(variable_struct_get(_ent, "name")) : "<no-name>");
            show_debug_message("[battle][sound] hit-effect triggered for " + _ename + ", hp_before=" + string(_before) + ", hp_after=" + string(_after) + ", mult=" + string(_mult));
        } catch (ee) { /* ignore */ }
        var mult = (is_real(_mult) ? _mult : 1.0);
        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][sound] trigger mult=" + string(mult) + ", audio_play_sound?=" + string(!is_undefined(audio_play_sound)));
        // Directly call the imported sound resources by name as requested.
        try {
            if (!is_undefined(audio_play_sound)){
                if (mult > 1.0){
                    audio_play_sound(snd_SuperEffective, 1, false);
                    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][sound] played snd_SuperEffective");
                } else if (mult < 1.0 && mult > 0.0){
                    audio_play_sound(snd_NotVeryEffective, 1, false);
                    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][sound] played snd_NotVeryEffective");
                } else {
                    audio_play_sound(snd_Effective, 1, false);
                    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][sound] played snd_Effective");
                }
            } else {
                // If audio_play_sound isn't available, attempt the safe wrapper with the same resource variables
                if (mult > 1.0) __battle_sound_play_safe(snd_SuperEffective);
                else if (mult < 1.0 && mult > 0.0) __battle_sound_play_safe(snd_NotVeryEffective);
                else __battle_sound_play_safe(snd_Effective);
            }
        } catch (e_direct) {
            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][sound] direct play failed: " + string(e_direct));
            // fallback: try safe resolver with string names
            try {
                var _fallback_name = (mult > 1.0 ? "snd_SuperEffective" : (mult < 1.0 && mult > 0.0 ? "snd_NotVeryEffective" : "snd_Effective"));
                __battle_sound_play_safe(_fallback_name);
            } catch (e_fb) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][sound] fallback resolver failed: " + string(e_fb)); }
        }

        // Start visual lerp state on the entity and inner mon if present
        try {
            variable_struct_set(_ent, "_hp_lerp_from", (is_real(_before) ? floor(_before) : __battle_hp_now(_ent)));
            variable_struct_set(_ent, "_hp_lerp_to",   (is_real(_after) ? floor(_after) : __battle_hp_now(_ent)));
            variable_struct_set(_ent, "_hp_lerp_start_ms", current_time);
            variable_struct_set(_ent, "_hp_lerp_dur", 400);
            variable_struct_set(_ent, "_hp_lerp_active", true);
            if (variable_struct_exists(_ent, "mon") && is_struct(variable_struct_get(_ent, "mon"))){ var _mi = variable_struct_get(_ent, "mon"); variable_struct_set(_mi, "_hp_lerp_from", variable_struct_get(_ent, "_hp_lerp_from")); variable_struct_set(_mi, "_hp_lerp_to", variable_struct_get(_ent, "_hp_lerp_to")); variable_struct_set(_mi, "_hp_lerp_start_ms", variable_struct_get(_ent, "_hp_lerp_start_ms")); variable_struct_set(_mi, "_hp_lerp_dur", variable_struct_get(_ent, "_hp_lerp_dur")); variable_struct_set(_mi, "_hp_lerp_active", true); }
        } catch (e_l) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][lerp] trigger failed: " + string(e_l)); }
    } catch (e) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][trigger] failed: " + string(e)); }
}
// Backwards-compatible shim: apply a requested HP delta that callers expect
// to be handled via a "lerped" helper. Some move implementations call
// __battle_apply_damage_lerped(_pid, target, delta) or the impl registry name
// __battle_apply_damage_lerped_impl. Provide a safe implementation here that
// forwards to the canonical __battle_apply_damage path and starts the hit
// lerp/FX. Returns an array [delta, before, after] to match older stubbed
// return shapes used by the moves layer.
function __battle_apply_damage_lerped(_pid, _ent, _delta){
    try {
        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][lerped_shim] called pid=" + string(_pid) + ", ent=" + string(_ent) + ", delta=" + string(_delta));
        var _B = __battle_ensure_slot(_pid);
        var before = __battle_hp_now(_ent);

        // Resolve target index in the battle slot if possible
        var tidx = undefined;
        try {
            if (is_struct(_B) && variable_struct_exists(_B, "actor") && is_array(variable_struct_get(_B, "actor"))){
                var _acts = variable_struct_get(_B, "actor");
                for (var _ii = 0; _ii < array_length(_acts); ++_ii){
                    var _a = _acts[_ii];
                    if (is_struct(_a) && _a == _ent){ tidx = _ii; break; }
                    try { if (is_struct(_a) && variable_struct_exists(_a, "mon") && variable_struct_get(_a, "mon") == _ent){ tidx = _ii; break; } } catch (e) {}
                }
            }
        } catch (e_idx) { tidx = undefined; }

        // _delta semantics: moves layer often passes negative values for damage
        var applied = 0;
        if (is_real(_delta) && _delta < 0){
            var dmg = max(0, floor(abs(_delta)));
            if (is_real(tidx)) __battle_apply_damage(_pid, tidx, dmg, 1.0);
            else __battle_set_hp_now(_ent, max(0, before - dmg));
            applied = -dmg;
        } else {
            // positive delta -> heal
            var heal = (is_real(_delta) ? floor(_delta) : 0);
            var newv = max(0, floor(before + heal));
            __battle_set_hp_now(_ent, newv);
            applied = heal;
        }

    var after = __battle_hp_now(_ent);
    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][lerped_shim] applied=" + string(applied) + ", before=" + string(before) + ", after=" + string(after));
        // Trigger the usual visual lerp/sfx
        try { __battle_trigger_hit_effect(_pid, _ent, before, after, 1.0); } catch (e_fx) {}
        return [applied, before, after];
    } catch (e_all){
        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][lerped_shim] failed: " + string(e_all));
        return [_delta, 0, 0];
    }
}
// Ensure the lerped shim is available via the impl registry so move code
// that prefers `_battle_impls.__battle_apply_damage_lerped` will find it.
try {
    if (!variable_global_exists("_battle_impls") || !is_struct(variable_global_get("_battle_impls"))) variable_global_set("_battle_impls", {});
    var __regtmp = variable_global_get("_battle_impls");
    try { variable_struct_set(__regtmp, "__battle_apply_damage_lerped", __battle_apply_damage_lerped); } catch (e_r) {}
} catch (e_reg_l) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][reg][lerped] failed: " + string(e_reg_l)); }
function __battle_set_hp_now(_ent, _val){
    // Prefer registry impl if available
    try {
        if (variable_global_exists("_battle_impls") && is_struct(global._battle_impls) && variable_struct_exists(global._battle_impls, "__battle_set_hp_now_impl")){
            var _fn2 = variable_struct_get(global._battle_impls, "__battle_set_hp_now_impl");
            if (!is_undefined(_fn2)) return _fn2(_ent, _val);
        }
        if (!is_undefined(__battle_set_hp_now_impl)) return __battle_set_hp_now_impl(_ent, _val);
    } catch (e_reg2) {}
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
    try {
        if (variable_global_exists("_battle_impls") && is_struct(global._battle_impls) && variable_struct_exists(global._battle_impls, "__battle_is_fainted_impl")){
            var _fn3 = variable_struct_get(global._battle_impls, "__battle_is_fainted_impl");
            if (!is_undefined(_fn3)) return _fn3(_ent);
        }
        if (!is_undefined(__battle_is_fainted_impl)) return __battle_is_fainted_impl(_ent);
    } catch (e_reg3) {}
    return (__battle_hp_now(_ent) <= 0);
}
function __battle_clear_fainted_if_healed(_ent){
    try {
        if (variable_global_exists("_battle_impls") && is_struct(global._battle_impls) && variable_struct_exists(global._battle_impls, "__battle_clear_fainted_if_healed_impl")){
            var _fn4 = variable_struct_get(global._battle_impls, "__battle_clear_fainted_if_healed_impl");
            if (!is_undefined(_fn4)) return _fn4(_ent);
        }
        if (!is_undefined(__battle_clear_fainted_if_healed_impl)) return __battle_clear_fainted_if_healed_impl(_ent);
    } catch (e_reg4) {}
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
    try {
        if (variable_global_exists("_battle_impls") && is_struct(global._battle_impls) && variable_struct_exists(global._battle_impls, "__battle_calc_damage_impl")){
            var _fn5 = variable_struct_get(global._battle_impls, "__battle_calc_damage_impl");
            if (!is_undefined(_fn5)) return _fn5(_A, _D, _move_id, _power);
        }
        if (!is_undefined(__battle_calc_damage_impl)) return __battle_calc_damage_impl(_A, _D, _move_id, _power);
    } catch (e_reg5) {}
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
function __battle_apply_damage(_pid, _target_index, _dmg, _mult){
    try {
        if (variable_global_exists("_battle_impls") && is_struct(global._battle_impls) && variable_struct_exists(global._battle_impls, "__battle_apply_damage_impl")){
            var _fn6 = variable_struct_get(global._battle_impls, "__battle_apply_damage_impl");
            if (!is_undefined(_fn6)) return _fn6(_pid, _target_index, _dmg, _mult);
        }
        if (!is_undefined(__battle_apply_damage_impl)) return __battle_apply_damage_impl(_pid, _target_index, _dmg, _mult);
    } catch (e_reg6) {}
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
            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) {
                try {
                    var _tname_dbg = "unknown";
                    if (variable_struct_exists(T, "name")) _tname_dbg = variable_struct_get(T, "name");
                    else if (variable_struct_exists(T, "mon") && is_struct(variable_struct_get(T, "mon")) && variable_struct_exists(variable_struct_get(T, "mon"), "name")) _tname_dbg = variable_struct_get(variable_struct_get(T, "mon"), "name");
                    show_debug_message("[battle][protect][consumed] pid=" + string(_pid) + " target_index=" + string(_target_index) + " name=" + string(_tname_dbg) + " dmg=" + string(_dmg));
                } catch (e_dbg2) { show_debug_message("[battle][protect][consumed] target_index=" + string(_target_index) + " dmg=" + string(_dmg)); }
            }
            return;
        }
    } catch (e_prot){ if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][protect] guard error: " + string(e_prot)); }

    var cur_hp = __battle_hp_now(T);
    var newhp = max(0, cur_hp - max(0, _dmg));
    __battle_set_hp_now(T, newhp);
    // Trigger visual lerp and hit SFX for this applied damage
    try {
        if (is_real(cur_hp) && is_real(newhp) && cur_hp != newhp){
            // Use provided multiplier when available, otherwise default to 1.0
            var use_mult = (is_real(_mult) ? _mult : 1.0);
            try { __battle_trigger_hit_effect(_pid, T, cur_hp, newhp, use_mult); } catch (e_th) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][sound] trigger call failed: " + string(e_th)); }
        }
    } catch (e_any) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][sound] apply_damage trigger error: " + string(e_any)); }
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
                try { var _final_fn = (variable_global_exists("_battle_impls") && is_struct(global._battle_impls) && variable_struct_exists(global._battle_impls, "__battle_finalize_catch") ? variable_struct_get(global._battle_impls, "__battle_finalize_catch") : undefined); if (!is_undefined(_final_fn)) _final_fn(_B, _B._catch_anim ? _B._catch_anim.caught_struct : undefined); } catch (e_final) {}
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

