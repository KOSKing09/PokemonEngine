// Battle action helpers (extracted from battle_system.gml)

function __battle_consume_pp(_A, _move_slot){
    if (!is_struct(_A)) return false;
    if (!is_array(_A.pps)) return false;
    if (!is_real(_move_slot) || _move_slot < 0 || _move_slot >= array_length(_A.pps)) return false;
    var cur = _A.pps[_move_slot];
    if (!is_real(cur) || cur <= 0) return false;
    _A.pps[_move_slot] = max(0, cur - 1);
    return true;
}

function __battle_roll_hit(_move_id, _A, _D){
    // If attacker and defender are provided, use the new stage-aware check
    try {
        if (!is_undefined(_A) && !is_undefined(_D) && !is_undefined(__battle_can_hit_target)){
            return __battle_can_hit_target(_A, _D, _move_id);
        }
    } catch (e) { /* fall back to simple check */ }
    var acc = __battle_move_accuracy(_move_id);
    return (irandom(99) < clamp(floor(acc), 0, 100));
}

/// Best-effort helper: locate the battle slot for either participant when _pid is missing.
function __battle_guess_pid_for_entities(_A, _D){
    var candidates = [];
    if (is_struct(_A)) array_push(candidates, _A);
    if (is_struct(_D) && _D != _A) array_push(candidates, _D);

    if (array_length(candidates) == 0) return undefined;

    try {
        if (!variable_global_exists("sys_battles") || !is_array(global.sys_battles)) return undefined;
        for (var _pid_iter = 0; _pid_iter < array_length(global.sys_battles); ++_pid_iter){
            var _slot = global.sys_battles[_pid_iter];
            if (!is_struct(_slot) || !variable_struct_exists(_slot, "actor")) continue;
            var _actors = variable_struct_get(_slot, "actor");
            if (!is_array(_actors)) continue;
            for (var _ai = 0; _ai < array_length(_actors); ++_ai){
                var _act = _actors[_ai];
                if (!is_struct(_act)) continue;
                for (var _ci = 0; _ci < array_length(candidates); ++_ci){
                    var _cand = candidates[_ci];
                    if (_act == _cand) return _pid_iter;
                    if (variable_struct_exists(_act, "mon") && variable_struct_get(_act, "mon") == _cand) return _pid_iter;
                }
            }
        }
    } catch (e_gp){ /* ignore and fall back */ }

    return undefined;
}

// Applies damage and returns [dmg, beforeHP, afterHP]
function __battle_apply_move_damage(_pid, _target_index, _A, _D, _move_id, _mv_power){
    // Ensure we have a valid battle slot reference before performing slot-dependent work.
    var _pid_local = _pid;
    if (!is_real(_pid_local)) _pid_local = __battle_guess_pid_for_entities(_A, _D);
    if (!is_real(_pid_local)){
        if (variable_global_exists("sys_battles") && is_array(global.sys_battles) && array_length(global.sys_battles) > 0){
            _pid_local = 0;
        } else {
            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){
                show_debug_message("[guard][apply_move_damage] no battle slot resolved for move_id=" + string(_move_id));
            }
            return [0, __battle_hp_now(_D), __battle_hp_now(_D)];
        }
    }
    _pid = _pid_local;

    var _move_rec = undefined;
    var _eid = undefined;
    try {
        if (variable_global_exists("_moves") && is_array(global._moves) && is_real(_move_id) && _move_id >= 0 && _move_id < array_length(global._moves)){
            _move_rec = global._moves[_move_id];
            if (is_struct(_move_rec) && variable_struct_exists(_move_rec, "effect_id") && is_real(variable_struct_get(_move_rec, "effect_id"))){
                _eid = variable_struct_get(_move_rec, "effect_id");
            }
        }
    } catch (e_eid) { _eid = _eid; }
    if (!is_real(_eid)){
        try {
            if (!is_undefined(__battle_get_move_meta) && is_real(_move_id)){
                var _mm_e = __battle_get_move_meta(_move_id);
                if (is_struct(_mm_e) && variable_struct_exists(_mm_e, "effect_id") && is_real(variable_struct_get(_mm_e, "effect_id"))) _eid = variable_struct_get(_mm_e, "effect_id");
            }
        } catch (e_eid2) { _eid = _eid; }
    }

    var _is_dynamax_cannon = (is_real(_eid) && floor(_eid) == 421);
    var _is_snipe_shot = (is_real(_eid) && floor(_eid) == 422);
    var _snipe_bypassed_guard = false;
    if (_is_snipe_shot && is_struct(_D)){
        var guard_fields = ["_protected", "_quick_guard", "_wide_guard", "_mat_block"];
        for (var _gf = 0; _gf < array_length(guard_fields); ++_gf){
            var gkey = guard_fields[_gf];
            if (variable_struct_exists(_D, gkey) && variable_struct_get(_D, gkey) == true){
                try { variable_struct_set(_D, gkey, false); } catch (e_gf) {}
                _snipe_bypassed_guard = true;
            }
        }
    }

    // Semi-invulnerable guard: prevent damage unless the attacking move is one of the
    // explicit counters (e.g., Gust vs Fly, Earthquake vs Dig). When the counter move
    // connects, it should deal amplified damage just like the mainline games.
    var _semi_mult = 1.0;
    try {
        if (is_struct(_D) && variable_struct_exists(_D, "_semi_invuln") && !is_undefined(variable_struct_get(_D, "_semi_invuln"))){
            var _phase_raw = variable_struct_get(_D, "_semi_invuln");
            var _phase = string_lower(string(_phase_raw));
            var _move_name_lower = "";
            if (is_real(_move_id)){
                try {
                    if (!is_undefined(scr_move_name_by_id)) _move_name_lower = string_lower(string(scr_move_name_by_id(_move_id)));
                } catch (e_mn) { _move_name_lower = ""; }
                if (string_length(_move_name_lower) <= 0){
                    try {
                        if (variable_global_exists("_moves") && is_array(global._moves) && _move_id >= 0 && _move_id < array_length(global._moves)){
                            var _mref = global._moves[_move_id];
                            if (is_struct(_mref) && variable_struct_exists(_mref, "identifier")){
                                _move_name_lower = string_lower(string(variable_struct_get(_mref, "identifier")));
                            }
                        }
                    } catch (e_mid) { _move_name_lower = ""; }
                }
            }
            var _target_name = (variable_struct_exists(_D, "name") ? string(variable_struct_get(_D, "name")) : "The target");
            var _attacker_name = (is_struct(_A) && variable_struct_exists(_A, "name") ? string(variable_struct_get(_A, "name")) : "The attacker");
            var _state_msg = "";
            var _allow_hit = false;

            if (_phase == "fly" || _phase == "bounce" || _phase == "skydrop"){
                if (string_pos("gust", _move_name_lower) > 0 || string_pos("twister", _move_name_lower) > 0){
                    _allow_hit = true;
                    _semi_mult = 2.0;
                }
                _state_msg = _target_name + " is high in the sky!";
            } else if (_phase == "dig"){
                if (string_pos("earthquake", _move_name_lower) > 0 || string_pos("magnitude", _move_name_lower) > 0){
                    _allow_hit = true;
                    _semi_mult = 2.0;
                }
                _state_msg = _target_name + " is underground!";
            } else if (_phase == "dive"){
                if (string_pos("surf", _move_name_lower) > 0 || string_pos("whirlpool", _move_name_lower) > 0){
                    _allow_hit = true;
                    _semi_mult = 2.0;
                }
                _state_msg = _target_name + " is deep underwater!";
            } else if (_phase == "vanish"){
                _allow_hit = false;
                _state_msg = _target_name + " vanished instantly!";
            }

            if (!_allow_hit){
                if (string_length(_state_msg) > 0){
                    if (!is_undefined(dialog_queue)) dialog_queue(_state_msg);
                    else if (!is_undefined(dialog2p_show_now)) try { dialog2p_show_now(_pid, _state_msg); } catch (e_msg1) {}
                }
                var _miss_msg = _attacker_name + "'s attack missed!";
                if (!is_undefined(dialog_queue)) dialog_queue(_miss_msg);
                else if (!is_undefined(dialog2p_show_now)) try { dialog2p_show_now(_pid, _miss_msg); } catch (e_msg2) {}
                try {
                    var _Bsemi_flag = __battle_ensure_slot(_pid);
                    if (is_struct(_Bsemi_flag)) variable_struct_set(_Bsemi_flag, "__semi_guard_blocked", true);
                } catch (e_flag) {}
                var _hp_guard = __battle_hp_now(_D);
                return [0, _hp_guard, _hp_guard];
            }
        }
    } catch (e_semi_guard){ if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][semi] guard apply_damage failed: " + string(e_semi_guard)); }

    // Check for OHKO (one-hit KO) move meta first. This implements Sheer Cold / Fissure / Guillotine/Horn Drill style behavior.
    try {
        var oh = undefined;
        if (!is_undefined(__battle_get_move_meta) && is_real(_move_id)){
            try { oh = __battle_get_move_meta(_move_id); } catch (e_gm) { oh = undefined; }
        }
    // Treat explicit meta or classic Horn Drill id (32) as OHKO
    if ((is_struct(oh) && variable_struct_exists(oh, "ohko") && variable_struct_get(oh, "ohko") == true) || (is_real(_move_id) && _move_id == 32)){
            // OHKO move: accuracy is 30 + (user.level - target.level). If user.level < target.level the move fails.
            var ulevel = (is_struct(_A) && variable_struct_exists(_A, "level") && is_real(variable_struct_get(_A, "level"))) ? floor(variable_struct_get(_A, "level")) : 0;
            var tlevel = (is_struct(_D) && variable_struct_exists(_D, "level") && is_real(variable_struct_get(_D, "level"))) ? floor(variable_struct_get(_D, "level")) : 0;
            var acc_base = 30;
            var acc = acc_base + max(0, ulevel - tlevel);
            if (variable_global_exists("DATA_DEBUG_VERBOSE") && global.DATA_DEBUG_VERBOSE) show_debug_message("[battle][ohko] attempt move_id=" + string(_move_id) + ", ulevel=" + string(ulevel) + ", tlevel=" + string(tlevel) + ", acc=" + string(acc));
            // If user is lower level, OHKO fails.
            var _Bslot_oh = __battle_ensure_slot(_pid);
            // If user level < target level, OHKO fails
            if (ulevel < tlevel){
                if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][ohko] failed: user level < target level (" + string(ulevel) + " < " + string(tlevel) + ")");
                try { if (is_struct(_Bslot_oh)) variable_struct_set(_Bslot_oh, "_last_ohko_miss", true); } catch (e_ohf) {}
                // Visible single-line OHKO tag for noisy logs
                if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[OHKO] OHKO failed (level) pid=" + string(_pid) + " move=" + string(_move_id) + " attacker_lvl=" + string(ulevel) + " target_lvl=" + string(tlevel));
                return [0, __battle_hp_now(_D), __battle_hp_now(_D)];
            }
            // Roll against computed accuracy
            var roll = irandom(99);
            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][ohko] acc=" + string(acc) + ", roll=" + string(roll));
            if (roll < clamp(floor(acc), 0, 100)){
                // Success: deal damage equal to target's max HP (attempt to read hp_max/maxhp)
                var target_max = 1;
                try { if (variable_struct_exists(_D, "hp_max")) target_max = variable_struct_get(_D, "hp_max"); else if (variable_struct_exists(_D, "maxhp")) target_max = variable_struct_get(_D, "maxhp"); else if (variable_struct_exists(_D, "mon") && is_struct(variable_struct_get(_D, "mon")) && variable_struct_exists(variable_struct_get(_D, "mon"), "hp_max")) target_max = variable_struct_get(variable_struct_get(_D, "mon"), "hp_max"); } catch (e_mx) { target_max = 1; }
                target_max = max(1, floor(target_max));
                // Apply damage via canonical path so Protect/lerp/etc. run
                __battle_apply_damage(_pid, _target_index, target_max, 1.0);
                var after = __battle_hp_now(_D);
                return [target_max, max(0, __battle_hp_now(_D) + target_max - target_max), after];
            } else {
                // Miss
                if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][ohko] missed (acc roll)");
                try { if (is_struct(_Bslot_oh)) variable_struct_set(_Bslot_oh, "_last_ohko_miss", true); } catch (e_ohm) {}
                if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[OHKO] OHKO missed (acc roll) pid=" + string(_pid) + " move=" + string(_move_id) + " roll=" + string(roll) + " need<" + string(acc));
                if (variable_global_exists("DATA_DEBUG_VERBOSE") && global.DATA_DEBUG_VERBOSE) show_debug_message("[battle][ohko] marked _last_ohko_miss due to acc roll for pid=" + string(_pid) + ", roll=" + string(roll) + ", needed<" + string(acc));
                return [0, __battle_hp_now(_D), __battle_hp_now(_D)];
            }
        }
    } catch (e_oh) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][ohko] handler error: " + string(e_oh)); }

    var dmg = __battle_calc_damage(_A, _D, _move_id, _mv_power);
    var before = __battle_hp_now(_D);
    // Temporary debug: print attacker/defender and indices to trace mis-targeting
    try {
        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){
            var aname_dbg = (is_struct(_A) && variable_struct_exists(_A, "name")) ? variable_struct_get(_A, "name") : (is_struct(_A) && variable_struct_exists(_A, "mon") && is_struct(variable_struct_get(_A, "mon")) && variable_struct_exists(variable_struct_get(_A, "mon"), "name") ? variable_struct_get(variable_struct_get(_A, "mon"), "name") : "<attacker?>");
            var dname_dbg = (is_struct(_D) && variable_struct_exists(_D, "name")) ? variable_struct_get(_D, "name") : (is_struct(_D) && variable_struct_exists(_D, "mon") && is_struct(variable_struct_get(_D, "mon")) && variable_struct_exists(variable_struct_get(_D, "mon"), "name") ? variable_struct_get(variable_struct_get(_D, "mon"), "name") : "<defender?>");
            var a_idx_dbg = (is_struct(_A) && variable_struct_exists(_A, "actor_index") ? string(variable_struct_get(_A, "actor_index")) : (variable_struct_exists(_A, "slot") ? string(variable_struct_get(_A, "slot")) : "?"));
            var d_idx_dbg = (is_struct(_D) && variable_struct_exists(_D, "actor_index") ? string(variable_struct_get(_D, "actor_index")) : (variable_struct_exists(_D, "slot") ? string(variable_struct_get(_D, "slot")) : "?"));
            show_debug_message("[dbg][apply_move_damage] pid=" + string(_pid) + ", target_idx_param=" + string(_target_index) + ", move=" + string(_move_id) + ", mv_power=" + string(_mv_power) + ", attacker=[" + string(aname_dbg) + ", idx=" + string(a_idx_dbg) + "], defender=[" + string(dname_dbg) + ", idx=" + string(d_idx_dbg) + "], computed_dmg=" + string(dmg) + ", defender_beforeHP=" + string(before));
        }
    } catch (e_dbgd) { }

    // Compute type-effectiveness multiplier (best-effort) so we can pick a hit sound
    var mult = 1.0;
    try {
        var atk_type = -1;
        if (!is_undefined(scr_move_type_id_by_id)) atk_type = scr_move_type_id_by_id(_move_id);
        if (is_real(atk_type) && atk_type >= 0 && variable_global_exists("BATTLE_TYPE_EFFICACY")){
            var _tmp_bte = variable_global_get("BATTLE_TYPE_EFFICACY");
            var dt = [];
            // Collect defender type ids from wrapper or inner mon
            if (variable_struct_exists(_D, "types") && is_array(variable_struct_get(_D, "types"))) for (var _ti=0; _ti<array_length(variable_struct_get(_D, "types")); ++_ti) array_push(dt, variable_struct_get(_D, "types")[_ti]);
            if (variable_struct_exists(_D, "type1") && is_real(variable_struct_get(_D, "type1"))) array_push(dt, variable_struct_get(_D, "type1"));
            if (variable_struct_exists(_D, "type2") && is_real(variable_struct_get(_D, "type2"))) array_push(dt, variable_struct_get(_D, "type2"));
            if (variable_struct_exists(_D, "mon") && is_struct(variable_struct_get(_D, "mon"))){
                var _mi = variable_struct_get(_D, "mon");
                if (variable_struct_exists(_mi, "types") && is_array(variable_struct_get(_mi, "types"))) for (var _ti2=0; _ti2<array_length(variable_struct_get(_mi, "types")); ++_ti2) array_push(dt, variable_struct_get(_mi, "types")[_ti2]);
                if (variable_struct_exists(_mi, "type1") && is_real(variable_struct_get(_mi, "type1"))) array_push(dt, variable_struct_get(_mi, "type1"));
                if (variable_struct_exists(_mi, "type2") && is_real(variable_struct_get(_mi, "type2"))) array_push(dt, variable_struct_get(_mi, "type2"));
                // species-level fallback via global._species_types
                if (variable_struct_exists(_mi, "species_id") && variable_global_exists("_species_types")){
                    var sid2 = variable_struct_get(_mi, "species_id");
                    if (is_real(sid2) && sid2 >= 0 && sid2 < array_length(global._species_types)){
                        var st2 = global._species_types[sid2]; if (is_array(st2)) for (var _zz=0; _zz<array_length(st2); ++_zz) array_push(dt, st2[_zz]);
                    }
                }
            }
            var prod = 1.0;
            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){
                show_debug_message("[battle][eff_debug] atk_type=" + string(atk_type) + ", defender_types=" + string(dt) + ", map_exists=" + string(!is_undefined(_tmp_bte)) );
            }
            for (var _k=0; _k<array_length(dt); ++_k){
                var def_t = dt[_k];
                if (!is_real(def_t)) continue;
                var key = string(atk_type) + ":" + string(def_t);
                if (ds_map_exists(_tmp_bte, key)){
                    var mval = ds_map_find_value(_tmp_bte, key);
                    if (is_real(mval)){
                        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][eff_debug] found key=" + string(key) + ", mval=" + string(mval));
                        prod *= mval;
                    }
                } else {
                    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][eff_debug] missing key=" + string(key));
                }
            }
            mult = prod;
        }
    } catch (e_mult) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][sound] type mult calc failed: " + string(e_mult)); }

    // Special-case move semantics that alter computed damage before application
    try {
        // Apply move-specific multipliers prior to special fixed-damage overrides
        if (_is_dynamax_cannon){
            var _target_is_dmax = false;
            try {
                if (!is_undefined(__battle_actor_is_dynamax)) _target_is_dmax = __battle_actor_is_dynamax(_D);
            } catch (e_dmx) { _target_is_dmax = false; }
            if (_target_is_dmax && is_real(dmg) && dmg > 0){
                dmg = max(0, round(dmg * 2));
                if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][move_special] Dynamax Cannon 2x damage applied");
            }
        }

        // Sonic Boom: fixed 20 HP damage (classic behavior). Ensure this
        // move deals a flat 20 HP and does not use the normal damage formula.
        if (is_real(_move_id) && _move_id == 49){
            var sb_flat = 20;
            dmg = sb_flat;
            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][move_special] Sonic Boom applied flat dmg=" + string(dmg));
        }
        // Dragon Rage: fixed 40 (classic)
        if (is_real(_move_id) && _move_id == 82){
            dmg = 40;
            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][move_special] Dragon Rage flat dmg=40");
        }

        // Super Fang (id 162) deals damage equal to half the target's current HP
        if (is_real(_move_id) && _move_id == 162){
            var curhp_sf = __battle_hp_now(_D);
            var sf_dmg = max(0, floor(curhp_sf / 2));
            dmg = sf_dmg;
            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][move_special] Super Fang computed dmg=" + string(dmg) + ", target_hp=" + string(curhp_sf));
        }

        // Seismic Toss and Night Shade: damage equal to attacker's level (classic)
        if (is_real(_move_id) && (_move_id == 69 || _move_id == 101)){
            try {
                var atk_level_flat = (is_struct(_A) && variable_struct_exists(_A, "level") && is_real(variable_struct_get(_A, "level"))) ? floor(variable_struct_get(_A, "level")) : 1;
                dmg = max(0, atk_level_flat);
                if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][move_special] level-based move applied move="+string(_move_id)+", dmg="+string(dmg));
            } catch (e_lvl) { }
        }

        // False Swipe (id 206) must not reduce the target below 1 HP (can't OHKO)
        if (is_real(_move_id) && _move_id == 206 && is_real(dmg) && dmg > 0){
            var before_hp_fs = before;
            var intended_after_fs = max(0, before_hp_fs - dmg);
            if (intended_after_fs < 1){
                var new_dmg_fs = max(0, before_hp_fs - 1);
                if (new_dmg_fs != dmg){
                    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][move_special] False Swipe adjusted dmg from " + string(dmg) + " to " + string(new_dmg_fs) + " (before=" + string(before_hp_fs) + ")");
                    dmg = new_dmg_fs;
                }
            }
        }
        // Terrain effects: adjust damage or cancel based on battlefield terrain
        try {
            var terr = "";
            var _Bterr = __battle_ensure_slot(_pid);
            if (is_struct(_Bterr)){
                if (variable_struct_exists(_Bterr, "_field")){
                    var _fld = variable_struct_get(_Bterr, "_field");
                    if (is_struct(_fld) && variable_struct_exists(_fld, "terrain")){
                        var _terr_struct = variable_struct_get(_fld, "terrain");
                        if (is_struct(_terr_struct) && variable_struct_exists(_terr_struct, "id")) terr = string_lower(string(variable_struct_get(_terr_struct, "id")));
                    }
                } else if (variable_struct_exists(_Bterr, "_terrain")){
                    terr = string_lower(string(variable_struct_get(_Bterr, "_terrain")));
                }
            }
            if (string_length(terr) > 0){
                // Helper: grounded checks (reuse __actor_is_grounded if present)
                var A_grounded = true; var D_grounded = true;
                try { if (!is_undefined(__actor_is_grounded)) { A_grounded = __actor_is_grounded(_A); D_grounded = __actor_is_grounded(_D); } } catch (e_gr) {}
                // Move type id when available
                var mv_type = -1;
                try { if (!is_undefined(scr_move_type_id_by_id) && is_real(_move_id)) mv_type = scr_move_type_id_by_id(_move_id); } catch (e_mt) { mv_type = -1; }
                // Psychic Terrain: block priority moves against grounded targets, and boost Psychic-type moves (grounded attacker)
                if (terr == "psychic"){
                    var priority_val = 0;
                    try {
                        if (!is_undefined(__battle_get_move_meta) && is_real(_move_id)){
                            var _mm_pt = __battle_get_move_meta(_move_id);
                            if (is_struct(_mm_pt) && variable_struct_exists(_mm_pt, "priority") && is_real(variable_struct_get(_mm_pt, "priority"))) priority_val = variable_struct_get(_mm_pt, "priority");
                        }
                    } catch (e_pr) { priority_val = 0; }
                    if (is_real(priority_val) && priority_val > 0 && D_grounded){
                        // Cancel the move's damage application
                        try { var _dnm = (is_struct(_D) && variable_struct_exists(_D, "name") ? variable_struct_get(_D, "name") : "The target"); try { dialog2p_show_now(_pid, string(_dnm) + " was protected by the terrain!"); } catch (e_msg) { try { dialog2p_enqueue(_pid, string(_dnm) + " was protected by the terrain!"); } catch(e_){} } } catch (e_msg) {}
                        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){
                            var _an_dbg = (is_struct(_A) && variable_struct_exists(_A, "name") ? variable_struct_get(_A, "name") : "<att>");
                            show_debug_message("[battle][terrain] Psychic Terrain blocked priority move id=" + string(_move_id) + " from attacker=" + string(_an_dbg));
                        }
                        return [0, before, before];
                    }
                    // Boost Psychic-type moves by 1.3x for grounded users
                    var psy_id = -1;
                    try { if (variable_global_exists("TYPE_ID_BY_NAME")) { var _tmap_psy = variable_global_get("TYPE_ID_BY_NAME"); if (ds_exists(_tmap_psy, ds_type_map)) psy_id = ds_map_find_value(_tmap_psy, "psychic"); } } catch (e_tp) { psy_id = -1; }
                    if (is_real(psy_id) && mv_type == psy_id && A_grounded){
                        dmg = floor(dmg * 1.3);
                        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][terrain] Psychic Terrain 1.3x boost applied to Psychic move id=" + string(_move_id));
                    }
                }
                // Electric Terrain: boost Electric-type moves used by grounded attacker (x1.3)
                if (terr == "electric" && is_real(mv_type)){
                    var ele_id = -1;
                    try { if (variable_global_exists("TYPE_ID_BY_NAME")){ var _tmap = variable_global_get("TYPE_ID_BY_NAME"); if (ds_exists(_tmap, ds_type_map)) ele_id = ds_map_find_value(_tmap, "electric"); } } catch (e_te) { ele_id = -1; }
                    if (is_real(ele_id) && mv_type == ele_id && A_grounded){ dmg = floor(dmg * 1.3); if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][terrain] Electric Terrain 1.3x boost applied to Electric move id=" + string(_move_id)); }
                }
                // Grassy Terrain: halve EQ/Bulldoze/Magnitude damage; boost Grass-type moves for grounded attackers
                if (terr == "grassy"){
                    // Identify EQ/Bulldoze/Magnitude by identifier or name
                    var iden = "";
                    try { if (variable_global_exists("_moves") && is_array(global._moves) && is_real(_move_id) && _move_id >= 0 && _move_id < array_length(global._moves)){ var mv = global._moves[_move_id]; if (is_struct(mv) && variable_struct_exists(mv, "identifier")) iden = string_lower(string(variable_struct_get(mv, "identifier"))); } } catch (e_id) { iden = ""; }
                    if (string_length(iden) > 0){ if (string_pos("earthquake", iden) > 0 || string_pos("bulldoze", iden) > 0 || string_pos("magnitude", iden) > 0){ dmg = floor(dmg * 0.5); if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][terrain] Grassy Terrain halved ground-type quake-like move id=" + string(_move_id)); } }
                    // Boost Grass-type moves by 1.3x for grounded users
                    var grass_id = -1;
                    try { if (variable_global_exists("TYPE_ID_BY_NAME")){ var _tmap3 = variable_global_get("TYPE_ID_BY_NAME"); if (ds_exists(_tmap3, ds_type_map)) grass_id = ds_map_find_value(_tmap3, "grass"); } } catch (e_tg) { grass_id = -1; }
                    if (is_real(grass_id) && mv_type == grass_id && A_grounded){ dmg = floor(dmg * 1.3); if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][terrain] Grassy Terrain 1.3x boost applied to Grass move id=" + string(_move_id)); }
                }
                // Misty Terrain: halve Dragon-type move damage against grounded targets
                if (terr == "misty" && is_real(mv_type) && D_grounded){
                    var drag_id = -1;
                    try { if (variable_global_exists("TYPE_ID_BY_NAME")){ var _tmap2 = variable_global_get("TYPE_ID_BY_NAME"); if (ds_exists(_tmap2, ds_type_map)) drag_id = ds_map_find_value(_tmap2, "dragon"); } } catch (e_td) { drag_id = -1; }
                    if (is_real(drag_id) && mv_type == drag_id){ dmg = floor(dmg * 0.5); if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][terrain] Misty Terrain halved Dragon move id=" + string(_move_id)); }
                }
            }
        } catch (e_terr) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][terrain] damage adjust failed: " + string(e_terr)); }
    } catch (e_ms) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][move_special] handler error: " + string(e_ms)); }

    // Defensive guard: prevent accidental self-hits when target == attacker and move is not a self-targeting move
    try {
        var _att_idx_chk = undefined;
        if (is_struct(_A) && variable_struct_exists(_A, "actor_index") && is_real(variable_struct_get(_A, "actor_index"))) _att_idx_chk = variable_struct_get(_A, "actor_index");
        else if (is_struct(_A) && variable_struct_exists(_A, "slot") && is_real(variable_struct_get(_A, "slot"))) _att_idx_chk = variable_struct_get(_A, "slot");
        var _is_self_target_allowed = false;
        // Try move meta first
        try {
            if (!is_undefined(__battle_get_move_meta) && is_real(_move_id)){
                var _mm_local = __battle_get_move_meta(_move_id);
                if (is_struct(_mm_local) && variable_struct_exists(_mm_local, "target")){
                    var _tstr = string(variable_struct_get(_mm_local, "target"));
                    _tstr = string_lower(_tstr);
                    if (string_pos("self", _tstr) > 0 || string_pos("user", _tstr) > 0 || string_pos("own", _tstr) > 0 || string_pos("ally", _tstr) > 0) _is_self_target_allowed = true;
                }
            }
        } catch (e_mmeta) {}
        // Fallback: check global._moves entry if available
        try {
            if (!_is_self_target_allowed && variable_global_exists("_moves") && is_array(global._moves) && is_real(_move_id) && _move_id >= 0 && _move_id < array_length(global._moves)){
                var _mEntry = global._moves[_move_id];
                if (is_struct(_mEntry) && variable_struct_exists(_mEntry, "target")){
                    var _t2 = string(variable_struct_get(_mEntry, "target")); _t2 = string_lower(_t2);
                    if (string_pos("self", _t2) > 0 || string_pos("user", _t2) > 0 || string_pos("own", _t2) > 0 || string_pos("ally", _t2) > 0) _is_self_target_allowed = true;
                }
            }
        } catch (e_mf) {}
        if (is_real(_att_idx_chk) && is_real(_target_index) && _att_idx_chk == _target_index && !_is_self_target_allowed){
            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) {
                var _an = (is_struct(_A) && variable_struct_exists(_A, "name") ? variable_struct_get(_A, "name") : "<att?>");
                var _dn = (is_struct(_D) && variable_struct_exists(_D, "name") ? variable_struct_get(_D, "name") : "<def?>");
                show_debug_message("[guard][apply_move_damage] prevented accidental self-hit: pid=" + string(_pid) + ", move=" + string(_move_id) + ", attacker=" + string(_an) + ", idx=" + string(_att_idx_chk) + ", defender=" + string(_dn) + ", idx=" + string(_target_index) + ", meta_allows_self=" + string(_is_self_target_allowed));
            }
            return [0, before, before];
        }
    } catch (e_guard) { /* silently continue to apply damage if guard fails */ }

    // Apply any semi-invulnerable hit multiplier after all move-specific overrides.
    try {
            var _has_tmp_mult = false;
            try {
                if (is_struct(_A) && variable_struct_exists(_A, "__semi_mult_tmp") && !is_undefined(variable_struct_get(_A, "__semi_mult_tmp"))){
                    _has_tmp_mult = true;
                }
            } catch (e_chk) { _has_tmp_mult = false; }
            if (!_has_tmp_mult){
                if (is_real(_semi_mult) && _semi_mult > 1.0 && is_real(dmg) && dmg > 0){
                    dmg = round(dmg * _semi_mult);
                }
            }
    } catch (e_semimul) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][semi] multiplier apply failed: " + string(e_semimul)); }

    // Apply damage (this will update hp_now). Pass effectiveness multiplier so SFX choice can match.
    __battle_apply_damage(_pid, _target_index, dmg, mult);
    var after = __battle_hp_now(_D);

    if (_snipe_bypassed_guard && is_struct(_D)){
        try {
            var _msg_target = "The target";
            if (!is_undefined(__status_mon_display_name)) _msg_target = __status_mon_display_name(_D);
            else if (variable_struct_exists(_D, "name")) _msg_target = string(variable_struct_get(_D, "name"));
            if (!is_undefined(__status_request_dialog_for_mon)) __status_request_dialog_for_mon(_D, string(_msg_target) + " couldn't block the shot!");
        } catch (e_msg_guard) {}
    }

    // Play an impact sound. The type-effectiveness multiplier `mult` is best-effort
    // but has been unreliable; prefer an observed damage-based heuristic when
    // multiplier looks neutral. We compute the actual hp delta and a percent of
    // the target's max HP and use thresholds to choose the SFX.
    try {
        var actual_delta = max(0, before - after);
        // Record last-received damage on the defender so counter-moves can reference it
        try {
            if (is_struct(_D) && is_real(actual_delta) && actual_delta > 0){
                // store last received damage and move context
                variable_struct_set(_D, "_last_received_damage", actual_delta);
                try { variable_struct_set(_D, "_last_received_from_move", _move_id); } catch (ee) {}
                // store damage class (physical/special) if data-layer helper exists
                try { if (!is_undefined(scr_move_damage_class_by_id) && is_real(_move_id)) variable_struct_set(_D, "_last_received_move_damage_class", scr_move_damage_class_by_id(_move_id)); } catch (ee2) {}
                // store attacker actor index when discoverable
                try {
                    var atk_idx = undefined;
                    var _Btmp = __battle_ensure_slot(_pid);
                    if (is_struct(_Btmp) && variable_struct_exists(_Btmp, "actor") && is_array(variable_struct_get(_Btmp, "actor"))){
                        var __acts_tmp = variable_struct_get(_Btmp, "actor");
                        for (var _ai_tmp = 0; _ai_tmp < array_length(__acts_tmp); ++_ai_tmp){ if (is_struct(__acts_tmp[_ai_tmp]) && __acts_tmp[_ai_tmp] == _A){ atk_idx = _ai_tmp; break; } }
                    }
                    if (is_real(atk_idx)) variable_struct_set(_D, "_last_received_from_actor_index", atk_idx);
                } catch (ee3) {}
            }
        } catch (e_lr){ if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][meta] last-received record failed: " + string(e_lr)); }
        // Determine defender max HP
        var def_hp_max = 1;
        if (variable_struct_exists(_D, "hp_max")) def_hp_max = variable_struct_get(_D, "hp_max");
        else if (variable_struct_exists(_D, "maxhp")) def_hp_max = variable_struct_get(_D, "maxhp");
        else if (variable_struct_exists(_D, "mon") && is_struct(variable_struct_get(_D, "mon"))){ var _m2 = variable_struct_get(_D, "mon"); if (variable_struct_exists(_m2, "hp_max")) def_hp_max = variable_struct_get(_m2, "hp_max"); }
        def_hp_max = max(1, def_hp_max);

        var pct = (def_hp_max > 0) ? (actual_delta / def_hp_max) : 0;
    if (variable_global_exists("DATA_DEBUG_VERBOSE") && global.DATA_DEBUG_VERBOSE) show_debug_message("[battle][sound] move dmg play attempt mult=" + string(mult) + ", delta=" + string(actual_delta) + ", hp_max=" + string(def_hp_max) + ", pct=" + string(pct));

        // Heuristic thresholds (tunable):
        // - pct >= 0.25 => loud/super-effective
        // - pct <= 0.10 => quiet/not-very-effective
        // Otherwise neutral.
        var use_super = false; var use_notvery = false;
        if (pct >= 0.25) use_super = true;
        else if (pct <= 0.10 && actual_delta > 0) use_notvery = true;

        // Allow explicit multiplier to override/augment the heuristic when it is present
        if (is_real(mult) && mult > 1.0) use_super = true;
        if (is_real(mult) && mult < 1.0 && mult > 0.0) use_notvery = true;

        if (!is_undefined(audio_play_sound)){
            try {
                if (use_super) audio_play_sound(snd_SuperEffective, 1, false);
                else if (use_notvery) audio_play_sound(snd_NotVeryEffective, 1, false);
                else audio_play_sound(snd_Effective, 1, false);
                if (variable_global_exists("DATA_DEBUG_VERBOSE") && global.DATA_DEBUG_VERBOSE) show_debug_message("[battle][sound] move played via audio_play_sound (direct resource) chosen_super=" + string(use_super) + ", chosen_notvery=" + string(use_notvery));
            } catch (e_ap2) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][sound] audio_play_sound failed: " + string(e_ap2)); }
        } else {
            try {
                if (use_super) __battle_sound_play_safe(snd_SuperEffective);
                else if (use_notvery) __battle_sound_play_safe(snd_NotVeryEffective);
                else __battle_sound_play_safe(snd_Effective);
            } catch (e_spf3) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][sound] fallback move play failed: " + string(e_spf3)); }
        }
    } catch (e_snd){ if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][sound] play failed: " + string(e_snd)); }

    // Start a visual HP lerp on the defender so the UI animates from before->after
    try {
        if (is_struct(_D)){
            variable_struct_set(_D, "_hp_lerp_from", before);
            variable_struct_set(_D, "_hp_lerp_to", after);
            variable_struct_set(_D, "_hp_lerp_start_ms", current_time);
            variable_struct_set(_D, "_hp_lerp_dur", 400); // ms
            variable_struct_set(_D, "_hp_lerp_active", true);
            // mirror to inner mon if present
            if (variable_struct_exists(_D, "mon") && is_struct(variable_struct_get(_D, "mon"))){ var _m = variable_struct_get(_D, "mon"); variable_struct_set(_m, "_hp_lerp_from", before); variable_struct_set(_m, "_hp_lerp_to", after); variable_struct_set(_m, "_hp_lerp_start_ms", current_time); variable_struct_set(_m, "_hp_lerp_dur", 400); variable_struct_set(_m, "_hp_lerp_active", true); }
        }
    } catch (e_lerp){ if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][lerp] start failed: " + string(e_lerp)); }

    return [dmg, before, after];
}
