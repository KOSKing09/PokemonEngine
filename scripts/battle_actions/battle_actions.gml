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

// Applies damage and returns [dmg, beforeHP, afterHP]
function __battle_apply_move_damage(_pid, _target_index, _A, _D, _move_id, _mv_power){
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
        // Super Fang (id 162) deals damage equal to half the target's current HP
        if (is_real(_move_id) && _move_id == 162){
            var curhp_sf = __battle_hp_now(_D);
            var sf_dmg = max(0, floor(curhp_sf / 2));
            dmg = sf_dmg;
            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][move_special] Super Fang computed dmg=" + string(dmg) + ", target_hp=" + string(curhp_sf));
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

    // Apply damage (this will update hp_now). Pass effectiveness multiplier so SFX choice can match.
    __battle_apply_damage(_pid, _target_index, dmg, mult);
    var after = __battle_hp_now(_D);

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
