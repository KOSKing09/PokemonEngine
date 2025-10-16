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

function __battle_roll_hit(_move_id){
    var acc = __battle_move_accuracy(_move_id);
    return (irandom(99) < clamp(floor(acc), 0, 100));
}

// Applies damage and returns [dmg, beforeHP, afterHP]
function __battle_apply_move_damage(_pid, _target_index, _A, _D, _move_id, _mv_power){
    var dmg = __battle_calc_damage(_A, _D, _move_id, _mv_power);
    var before = __battle_hp_now(_D);

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

    // Apply damage (this will update hp_now). Pass effectiveness multiplier so SFX choice can match.
    __battle_apply_damage(_pid, _target_index, dmg, mult);
    var after = __battle_hp_now(_D);

    // Play an impact sound. The type-effectiveness multiplier `mult` is best-effort
    // but has been unreliable; prefer an observed damage-based heuristic when
    // multiplier looks neutral. We compute the actual hp delta and a percent of
    // the target's max HP and use thresholds to choose the SFX.
    try {
        var actual_delta = max(0, before - after);
        // Determine defender max HP
        var def_hp_max = 1;
        if (variable_struct_exists(_D, "hp_max")) def_hp_max = variable_struct_get(_D, "hp_max");
        else if (variable_struct_exists(_D, "maxhp")) def_hp_max = variable_struct_get(_D, "maxhp");
        else if (variable_struct_exists(_D, "mon") && is_struct(variable_struct_get(_D, "mon"))){ var _m2 = variable_struct_get(_D, "mon"); if (variable_struct_exists(_m2, "hp_max")) def_hp_max = variable_struct_get(_m2, "hp_max"); }
        def_hp_max = max(1, def_hp_max);

        var pct = (def_hp_max > 0) ? (actual_delta / def_hp_max) : 0;
        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][sound] move dmg play attempt mult=" + string(mult) + ", delta=" + string(actual_delta) + ", hp_max=" + string(def_hp_max) + ", pct=" + string(pct));

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
                if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][sound] move played via audio_play_sound (direct resource) chosen_super=" + string(use_super) + ", chosen_notvery=" + string(use_notvery));
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
