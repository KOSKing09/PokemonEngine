// Entry hazard helpers extracted from battle_system.gml to keep the main script lean.

if (is_undefined(__battle_apply_entry_hazards)){
    function __battle_apply_entry_hazards(_pid, _actor_index){
        try {
            var _B = __battle_ensure_slot(_pid);
            if (!is_struct(_B)) return false;
            if (!is_real(_actor_index)) return false;

            var actors = (variable_struct_exists(_B, "actor") ? variable_struct_get(_B, "actor") : []);
            var A = undefined;
            if (is_array(actors) && _actor_index >= 0 && _actor_index < array_length(actors)) A = actors[_actor_index];
            if (!is_struct(A)) return false;

            var field = __battle_field_ensure(_pid);
            if (!is_struct(field)) return false;

            var hazard_side = __battle_field_side_index_for_opponent(_actor_index);

            // Collect defender types for later checks
            var tlist = [];
            try {
                if (variable_struct_exists(A, "types") && is_array(variable_struct_get(A, "types"))){
                    var types_arr = variable_struct_get(A, "types");
                    for (var ti = 0; ti < array_length(types_arr); ++ti) array_push(tlist, types_arr[ti]);
                }
                if (variable_struct_exists(A, "type1") && is_real(variable_struct_get(A, "type1"))) array_push(tlist, variable_struct_get(A, "type1"));
                if (variable_struct_exists(A, "type2") && is_real(variable_struct_get(A, "type2"))) array_push(tlist, variable_struct_get(A, "type2"));
                if (variable_struct_exists(A, "mon") && is_struct(variable_struct_get(A, "mon"))){
                    var mon_struct = variable_struct_get(A, "mon");
                    if (variable_struct_exists(mon_struct, "types") && is_array(variable_struct_get(mon_struct, "types"))){
                        var mon_types = variable_struct_get(mon_struct, "types");
                        for (var mi = 0; mi < array_length(mon_types); ++mi) array_push(tlist, mon_types[mi]);
                    }
                    if (variable_struct_exists(mon_struct, "type1") && is_real(variable_struct_get(mon_struct, "type1"))) array_push(tlist, variable_struct_get(mon_struct, "type1"));
                    if (variable_struct_exists(mon_struct, "type2") && is_real(variable_struct_get(mon_struct, "type2"))) array_push(tlist, variable_struct_get(mon_struct, "type2"));
                    if (variable_struct_exists(mon_struct, "species_id") && variable_global_exists("_species_types") && is_array(global._species_types)){
                        var sid = variable_struct_get(mon_struct, "species_id");
                        if (is_real(sid) && sid >= 0 && sid < array_length(global._species_types)){
                            var species_types = global._species_types[sid];
                            if (is_array(species_types)) for (var si = 0; si < array_length(species_types); ++si) array_push(tlist, species_types[si]);
                        }
                    }
                }
            } catch (e_tcollect) {}

            var flying_id = undefined;
            var poison_id = undefined;
            var steel_id = undefined;
            var rock_id_global = undefined;
            if (variable_global_exists("TYPE_ID_BY_NAME")){
                try {
                    var type_map = variable_global_get("TYPE_ID_BY_NAME");
                    if (ds_exists(type_map, ds_type_map)){
                        flying_id = ds_map_find_value(type_map, "flying");
                        poison_id = ds_map_find_value(type_map, "poison");
                        steel_id  = ds_map_find_value(type_map, "steel");
                        rock_id_global = ds_map_find_value(type_map, "rock");
                    }
                } catch (e_type_map) {}
            }

            var has_levitate = false;
            var has_magic_guard = false;
            try {
                if (variable_struct_exists(A, "ability")){
                    var ability_val = variable_struct_get(A, "ability");
                    var ability_txt = string_lower(string(ability_val));
                    if (ability_txt == "levitate") has_levitate = true;
                    if (ability_txt == "magic guard") has_magic_guard = true;
                    if (is_real(ability_val)){
                        var ability_idx = floor(ability_val);
                        if (ability_idx == 26) has_levitate = true;
                        try {
                            if (variable_global_exists("ABILITY_MAGIC_GUARD") && ability_idx == global.ABILITY_MAGIC_GUARD) has_magic_guard = true;
                        } catch (e_magic_id) {}
                    }
                }
            } catch (e_ability) {}
            if (!has_magic_guard){
                try {
                    if (variable_struct_exists(A, "mon") && is_struct(variable_struct_get(A, "mon"))){
                        var mon_struct2 = variable_struct_get(A, "mon");
                        if (variable_struct_exists(mon_struct2, "ability")){
                            var mon_ability_txt = string_lower(string(variable_struct_get(mon_struct2, "ability")));
                            if (mon_ability_txt == "magic guard") has_magic_guard = true;
                        }
                    }
                } catch (e_monability) {}
            }

            var is_poison_type = false;
            var is_steel_type = false;
            for (var ti2 = 0; ti2 < array_length(tlist); ++ti2){
                var tval = tlist[ti2];
                if (!is_real(tval)) continue;
                if (!is_undefined(poison_id) && is_real(poison_id) && tval == poison_id) is_poison_type = true;
                if (!is_undefined(steel_id) && is_real(steel_id) && tval == steel_id) is_steel_type = true;
            }

            var is_grounded = true;
            try {
                if (!is_undefined(__actor_is_grounded)) is_grounded = __actor_is_grounded(A);
                else {
                    var has_flying_type = false;
                    if (!is_undefined(flying_id) && is_real(flying_id)){
                        for (var fi = 0; fi < array_length(tlist); ++fi){
                            var ft = tlist[fi];
                            if (is_real(ft) && ft == flying_id){ has_flying_type = true; break; }
                        }
                    }
                    is_grounded = !(has_flying_type || has_levitate);
                }
            } catch (e_ground) { is_grounded = !(has_levitate); }

            var skip_grounded_hazards = !is_grounded;

            // Apply Spikes damage (layers based)
            try {
                var spikes_layers = __battle_field_get_hazard_or(_pid, hazard_side, "spikes", 0);
                if (is_real(spikes_layers) && spikes_layers > 0 && !skip_grounded_hazards){
                    if (!has_magic_guard){
                        var hpmax = 0;
                        if (variable_struct_exists(A, "hp_max")) hpmax = variable_struct_get(A, "hp_max");
                        else if (variable_struct_exists(A, "maxhp")) hpmax = variable_struct_get(A, "maxhp");
                        var frac_amt = 0.125;
                        if (spikes_layers == 2) frac_amt = 1.0 / 6.0;
                        else if (spikes_layers >= 3) frac_amt = 0.25;
                        var dmg = max(1, floor(hpmax * frac_amt));
                        var before_sp = __battle_hp_now(A);
                        __battle_apply_damage(_pid, _actor_index, dmg, 1.0);
                        var after_sp = __battle_hp_now(A);
                        __battle_trigger_hit_effect(_pid, A, before_sp, after_sp, 1.0);
                        try {
                            var aname_sp = (variable_struct_exists(A, "name") ? variable_struct_get(A, "name") : "The Pokemon");
                            if (!is_undefined(__status_request_dialog_for_mon)) __status_request_dialog_for_mon(A, string(aname_sp) + " was hurt by the spikes!", false);
                        } catch (e_sp_msg) {}
                        try { variable_struct_set(_B, "_meta_effect_applied", true); } catch (e_sp_meta) {}
                    }
                }
            } catch (e_sp) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][hazards] spikes apply failed: " + string(e_sp)); }

            // Apply Toxic Spikes status
            try {
                var tlay = __battle_field_get_hazard_or(_pid, hazard_side, "toxic_spikes", 0);
                if (is_real(tlay) && tlay > 0){
                    if (!skip_grounded_hazards){
                        if (is_poison_type){
                            __battle_field_clear_hazard(_pid, hazard_side, "toxic_spikes");
                            try {
                                var aname_abs = (variable_struct_exists(A, "name") ? variable_struct_get(A, "name") : "The Pokemon");
                                if (!is_undefined(__status_request_dialog_for_mon)) __status_request_dialog_for_mon(A, string(aname_abs) + " absorbed the Toxic Spikes!", false);
                            } catch (e_msgabs) {}
                        } else if (!is_steel_type){
                            try {
                                if (tlay >= 2){
                                    if (!is_undefined(status_system_apply_status)){
                                        var ok_ts = status_system_apply_status(A, "toxic", {});
                                        if (!ok_ts && !is_undefined(status_system_apply_status)) status_system_apply_status(A, "poison", {});
                                    }
                                } else {
                                    if (!is_undefined(status_system_apply_status)) status_system_apply_status(A, "poison", {});
                                }
                            } catch (e_ts) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][hazards] toxic spikes apply failed: " + string(e_ts)); }
                            try { variable_struct_set(_B, "_meta_effect_applied", true); } catch (e_ts_meta) {}
                        }
                    }
                }
            } catch (e_ts_outer) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][hazards] toxic spikes outer error: " + string(e_ts_outer)); }

            // Apply Stealth Rock damage scaled by type effectiveness
            try {
                if (__battle_field_get_hazard_or(_pid, hazard_side, "stealth_rock", 0) != 0){
                    if (!has_magic_guard){
                        var hpmax2 = (variable_struct_exists(A, "hp_max") ? variable_struct_get(A, "hp_max") : (variable_struct_exists(A, "maxhp") ? variable_struct_get(A, "maxhp") : 0));
                        var base_frac = 0.125;
                        var mult = 1.0;
                        try {
                            var rock_id = rock_id_global;
                            if (!is_undefined(rock_id) && is_real(rock_id) && variable_global_exists("BATTLE_TYPE_EFFICACY")){
                                var type_map_bte = variable_global_get("BATTLE_TYPE_EFFICACY");
                                if (!is_undefined(type_map_bte) && ds_exists(type_map_bte, ds_type_map)){
                                    var dt = [];
                                    if (variable_struct_exists(A, "types") && is_array(variable_struct_get(A, "types"))) for (var ti3 = 0; ti3 < array_length(variable_struct_get(A, "types")); ++ti3) array_push(dt, variable_struct_get(A, "types")[ti3]);
                                    if (variable_struct_exists(A, "type1") && is_real(variable_struct_get(A, "type1"))) array_push(dt, variable_struct_get(A, "type1"));
                                    if (variable_struct_exists(A, "type2") && is_real(variable_struct_get(A, "type2"))) array_push(dt, variable_struct_get(A, "type2"));
                                    if (variable_struct_exists(A, "mon") && is_struct(variable_struct_get(A, "mon"))){
                                        var mon2 = variable_struct_get(A, "mon");
                                        if (variable_struct_exists(mon2, "species_id") && variable_global_exists("_species_types") && is_array(global._species_types)){
                                            var sid2 = variable_struct_get(mon2, "species_id");
                                            if (is_real(sid2) && sid2 >= 0 && sid2 < array_length(global._species_types)){
                                                var st2 = global._species_types[sid2];
                                                if (is_array(st2)) for (var z = 0; z < array_length(st2); ++z) array_push(dt, st2[z]);
                                            }
                                        }
                                    }
                                    var prod = 1.0;
                                    for (var k = 0; k < array_length(dt); ++k){
                                        var def_t = dt[k];
                                        if (!is_real(def_t)) continue;
                                        var key = string(rock_id) + ":" + string(def_t);
                                        if (ds_map_exists(type_map_bte, key)){
                                            var mval = ds_map_find_value(type_map_bte, key);
                                            if (is_real(mval)) prod *= mval;
                                        }
                                    }
                                    mult = prod;
                                }
                            }
                        } catch (e_tr) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][hazards] stealth rock type calc failed: " + string(e_tr)); }

                        var rawd = floor(hpmax2 * base_frac * max(0.0, mult));
                        if (rawd > 0){
                            var dmg2 = rawd;
                            var before_sr = __battle_hp_now(A);
                            __battle_apply_damage(_pid, _actor_index, dmg2, 1.0);
                            var after_sr = __battle_hp_now(A);
                            __battle_trigger_hit_effect(_pid, A, before_sr, after_sr, mult);
                            try {
                                var aname_sr = (variable_struct_exists(A, "name") ? variable_struct_get(A, "name") : "The Pokemon");
                                if (!is_undefined(__status_request_dialog_for_mon)) __status_request_dialog_for_mon(A, string(aname_sr) + " was hurt by the stealth rock!", false);
                            } catch (e_msg_sr) {}
                            try { variable_struct_set(_B, "_meta_effect_applied", true); } catch (e_sr_meta) {}
                        }
                    }
                }
            } catch (e_sr) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][hazards] stealth rock outer error: " + string(e_sr)); }

            // Apply Sticky Web stage drop
            try {
                var sticky_web = __battle_field_get_hazard_or(_pid, hazard_side, "sticky_web", false);
                if (sticky_web == true){
                    if (!skip_grounded_hazards){
                        var block_drop = false;
                        var contrary = false;
                        try {
                            if (variable_struct_exists(A, "ability")){
                                var abn = string_lower(string(variable_struct_get(A, "ability")));
                                if (abn == "clear body" || abn == "white smoke" || abn == "full metal body") block_drop = true;
                                if (abn == "contrary") contrary = true;
                            }
                        } catch (e_ab) {}
                        if (block_drop){
                            try { var aname_sw0 = (variable_struct_exists(A, "name") ? variable_struct_get(A, "name") : "The Pokemon"); if (!is_undefined(__status_request_dialog_for_mon)) __status_request_dialog_for_mon(A, string(aname_sw0) + " wasn't affected by the sticky web!", false); } catch (e_msg0) {}
                        } else {
                            try { var aname_sw = (variable_struct_exists(A, "name") ? variable_struct_get(A, "name") : "The Pokemon"); if (!is_undefined(__status_request_dialog_for_mon)) __status_request_dialog_for_mon(A, string(aname_sw) + " was caught in the sticky web!", false); } catch (e_msg_sw) {}

                            if (!variable_struct_exists(A, "_stages") || !is_struct(variable_struct_get(A, "_stages"))) variable_struct_set(A, "_stages", {});
                            var st_obj = variable_struct_get(A, "_stages");
                            var prev_s = (variable_struct_exists(st_obj, "spe") && is_real(variable_struct_get(st_obj, "spe"))) ? variable_struct_get(st_obj, "spe") : 0;
                            var delta = (contrary ? 1 : -1);
                            var next_s = clamp(prev_s + delta, -6, 6);
                            variable_struct_set(st_obj, "spe", next_s);
                            __battle_request_animation_safe(_pid, { type: "stat_change", target_index: _actor_index, stat: "spe", from: prev_s, to: next_s });
                            // Note: SFX for stat changes is played when the dialog is shown; do not play here.
                            var aname_sw2 = (variable_struct_exists(A, "name") ? variable_struct_get(A, "name") : "The Pokemon");
                            var applied_amt = next_s - prev_s;
                            var sign_amt = (applied_amt > 0) ? ("+" + string(applied_amt)) : string(applied_amt);
                            var sc_msg_sw = (applied_amt == 0) ? (string(aname_sw2) + "'s SPD won't go any lower!") : (string(aname_sw2) + " SPD " + sign_amt);
                            var target_mon_ref_sw = A;
                            if (is_struct(A) && variable_struct_exists(A, "mon") && is_struct(variable_struct_get(A, "mon"))) target_mon_ref_sw = variable_struct_get(A, "mon");
                            if (!is_undefined(__status_request_dialog_for_mon)) __status_request_dialog_for_mon(target_mon_ref_sw, sc_msg_sw, false);
                            try { variable_struct_set(_B, "_meta_effect_applied", true); } catch (e_sw_meta) {}
                        }
                    }
                }
            } catch (e_outer_sw) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][hazards] sticky web outer error: " + string(e_outer_sw)); }

            return true;
        } catch (e_all){
            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][hazards] apply entry hazards error: " + string(e_all));
        }
        return false;
    }
    try { variable_global_set("__battle_apply_entry_hazards", __battle_apply_entry_hazards); } catch (e_set_entry_haz) { global.__battle_apply_entry_hazards = __battle_apply_entry_hazards; }
}
