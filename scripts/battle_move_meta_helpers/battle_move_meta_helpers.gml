// Move meta helpers extracted from battle_system.gml to keep the main script lean.

if (is_undefined(__battle_meta_held_items_enabled)){
    function __battle_meta_held_items_enabled(_actor){
        if (!is_struct(_actor)) return false;
        if (is_undefined(status_system_has_status)) return true;
        try {
            if (status_system_has_status(_actor, "embargo")) return false;
        } catch (e_actor_embargo) {}
        try {
            if (variable_struct_exists(_actor, "mon") && is_struct(variable_struct_get(_actor, "mon")) && status_system_has_status(variable_struct_get(_actor, "mon"), "embargo")) return false;
        } catch (e_actor_embargo_mon) {}
        return true;
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
            var resolve_effect_target_index_safe = function(_pid_local, _attacker_local, _defender_local, _fallback_target_index_local){
                var _fallback_local = (is_real(_fallback_target_index_local) ? floor(_fallback_target_index_local) : _fallback_target_index_local);
                try {
                    if (variable_global_exists("_battle_impls") && is_struct(variable_global_get("_battle_impls"))){
                        var _impls_local = variable_global_get("_battle_impls");
                        if (variable_struct_exists(_impls_local, "__battle_resolve_effect_target_index")){
                            var _resolve_fn_local = variable_struct_get(_impls_local, "__battle_resolve_effect_target_index");
                            if (!is_undefined(_resolve_fn_local)) return _resolve_fn_local(_pid_local, _attacker_local, _defender_local, _fallback_local);
                        }
                    }
                } catch (e_resolve_registry_local) {}
                try {
                    if (!is_undefined(__battle_resolve_live_actor_index)){
                        var _resolved_local = __battle_resolve_live_actor_index(_pid_local, _defender_local, _fallback_local);
                        if (is_real(_resolved_local)) return _resolved_local;
                        var _attacker_idx_local = __battle_resolve_live_actor_index(_pid_local, _attacker_local, undefined);
                        if (is_real(_attacker_idx_local) && !is_undefined(__battle_get_default_target_index)) return __battle_get_default_target_index(_pid_local, _attacker_idx_local);
                    }
                } catch (e_resolve_fallback_local) {}
                return _fallback_local;
            };

            var A_before = real(get_hp_now(_A));
            var A_max = max(1, real(get_hp_max(_A)));
            var _move_rec_status = undefined;
            var _eid_status = undefined;
            var _is_swagger = false;
            var _called_swagger_self = false;
            try {
                if (variable_global_exists("_moves") && is_array(global._moves) && is_real(_move_id) && _move_id >= 0 && _move_id < array_length(global._moves)) _move_rec_status = global._moves[_move_id];
                if (is_struct(_move_rec_status) && variable_struct_exists(_move_rec_status, "effect_id") && is_real(variable_struct_get(_move_rec_status, "effect_id"))) _eid_status = variable_struct_get(_move_rec_status, "effect_id");
                var _ident_swagger = (is_struct(_move_rec_status) && variable_struct_exists(_move_rec_status, "identifier")) ? string_lower(string(variable_struct_get(_move_rec_status, "identifier"))) : "";
                if (_ident_swagger == "swagger" || (is_real(_move_id) && floor(_move_id) == 207) || (is_real(_eid_status) && floor(_eid_status) == 119)) _is_swagger = true;
                if (is_struct(_A) && variable_struct_exists(_A, "_called_move_active") && variable_struct_get(_A, "_called_move_active") == true){
                    if (_is_swagger) _called_swagger_self = true;
                }
            } catch (e_move_meta_effect) { _eid_status = undefined; }

            // Process drain (positive = heal attacker; negative = recoil to attacker)
            if (variable_struct_exists(_mm, "drain") && is_real(variable_struct_get(_mm, "drain"))){
                var drain_v = real(variable_struct_get(_mm, "drain"));
                // [central-behavior] Override drain from centralized resolver when available.
                try {
                    if (!is_undefined(__battle_move_behavior_drain)){
                        drain_v = __battle_move_behavior_drain(_move_id, drain_v);
                    }
                } catch (e_central_drain) {}
                // Healing (Absorb/Drain style)
                if (is_real(_dmg) && _dmg > 0 && drain_v > 0){
                    var heal_amt = 0;
                    if (drain_v > 0 && drain_v <= 100){
                        heal_amt = floor(_dmg * drain_v / 100);
                    } else {
                        // treat as absolute
                        heal_amt = floor(drain_v);
                    }
                    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){
                        try { show_debug_message("[battle][meta][heal] move="+string(_move_id)+", dmg="+string(_dmg)+", drain_v="+string(drain_v)+", heal_amt="+string(heal_amt)+", A_before="+string(A_before)+", A_max="+string(A_max)); } catch (e_dbg) {}
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
                else if (is_real(_dmg) && _dmg > 0 && drain_v < 0){
                    var abs_v = abs(drain_v);
                    var recoil_amt = 0;
                    if (abs_v > 0 && abs_v <= 100) recoil_amt = floor(_dmg * abs_v / 100);
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
                                        try { variable_global_set("__battle_apply_move_meta_effects", __battle_apply_move_meta_effects); } catch (e_set_meta_fn) { global.__battle_apply_move_meta_effects = __battle_apply_move_meta_effects; }
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

                    // Process random status families (e.g., newer moves such as Dire Claw).
                    if (variable_struct_exists(_mm, "random_statuses") && is_array(variable_struct_get(_mm, "random_statuses")) && !is_undefined(status_system_apply_status)){
                        var _status_choices = variable_struct_get(_mm, "random_statuses");
                        var _choice_count = array_length(_status_choices);
                        var _rs_chance = (variable_struct_exists(_mm, "chance") && is_real(variable_struct_get(_mm, "chance"))) ? real(variable_struct_get(_mm, "chance")) : 100;
                        _rs_chance = clamp(floor(_rs_chance), 0, 100);
                        if (!is_undefined(__status_dev_override_chance)) _rs_chance = __status_dev_override_chance("random_status", _rs_chance);
                        if (_choice_count > 0 && irandom(99) < _rs_chance){
                            var _picked_status = string(_status_choices[irandom(_choice_count - 1)]);
                            var _rs_opts = {};
                            try { variable_struct_set(_rs_opts, "source", _A); } catch (e_rs_src) {}
                            if (variable_struct_exists(_mm, "duration") && is_real(variable_struct_get(_mm, "duration"))) variable_struct_set(_rs_opts, "duration", variable_struct_get(_mm, "duration"));
                            try { status_system_apply_status(_D, _picked_status, _rs_opts); } catch (e_rs_apply) {}
                        }
                    }

                    // Process status application (e.g., Sleep Powder, Poison Powder)
                    if (variable_struct_exists(_mm, "status") && string_length(string(variable_struct_get(_mm, "status"))) > 0){
                        var stid = string(variable_struct_get(_mm, "status"));
                        var _stid_norm_global = string_lower(string(stid));
                        var stchance = (variable_struct_exists(_mm, "chance") && is_real(variable_struct_get(_mm, "chance"))) ? real(variable_struct_get(_mm, "chance")) : 100;
                        // clamp chance to 0..100
                        stchance = clamp(floor(stchance), 0, 100);
                        // If Water Pledge double-effect is active for attacker's side, double the chance
                        try {
                            var _Bslot_local2 = __battle_ensure_slot(_pid);
                            if (is_struct(_Bslot_local2) && variable_struct_exists(_Bslot_local2, "_pledge_flags") && is_struct(variable_struct_get(_Bslot_local2, "_pledge_flags"))){
                                var pf_local2 = variable_struct_get(_Bslot_local2, "_pledge_flags");
                                var atk_side = (variable_struct_exists(_A, "actor_index") && variable_struct_get(_A, "actor_index") == 0) ? 0 : 1;
                                var wk2 = "water_pledge_double_effect_side_" + string(atk_side);
                                if (variable_struct_exists(pf_local2, wk2) && is_real(variable_struct_get(pf_local2, wk2)) && variable_struct_get(pf_local2, wk2) > 0){
                                    stchance = min(100, floor(stchance * 2));
                                }
                            }
                        } catch (e_spc) {}
                        // If a status is present but chance is 0 (common CSV omission),
                        // treat it as 100% to match expected behavior for powders.
                        if (stchance <= 0){
                            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][meta] overriding zero chance to 100 for status=" + stid);
                            stchance = 100;
                        }
                        if (!is_undefined(__status_dev_override_chance)){
                            stchance = __status_dev_override_chance(string_lower(string(stid)), stchance);
                        }
                        var roll = irandom(99);
                        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][meta] status apply attempt status=" + stid + ", chance=" + string(stchance) + ", roll=" + string(roll));
                        if (roll < stchance){
                            try {
                                    // Use status_system_apply_status on the defender
                                    if (!is_undefined(status_system_apply_status)){
                                        if (is_real(_eid_status) && _eid_status == 115 && _stid_norm_global == "perish-song"){
                                            var _applied_perish = false;
                                            var _actors_perish = (is_struct(_B) && variable_struct_exists(_B, "actor") && is_array(variable_struct_get(_B, "actor"))) ? variable_struct_get(_B, "actor") : [];
                                            for (var _ps_i = 0; _ps_i < array_length(_actors_perish); ++_ps_i){
                                                var _ps_actor = _actors_perish[_ps_i];
                                                if (!is_struct(_ps_actor)) continue;
                                                var _ps_hp = 1;
                                                try { if (!is_undefined(__battle_hp_now)) _ps_hp = __battle_hp_now(_ps_actor); } catch (e_ps_hp) { _ps_hp = 1; }
                                                if (is_real(_ps_hp) && _ps_hp <= 0) continue;
                                                var _soundproof = false;
                                                try {
                                                    if (!is_undefined(__battle_actor_has_ability_named) && __battle_actor_has_ability_named(_ps_actor, "soundproof")) _soundproof = true;
                                                } catch (e_ps_ability) { _soundproof = false; }
                                                if (_soundproof) continue;
                                                var _perish_opts = { duration: 4 };
                                                try { variable_struct_set(_perish_opts, "source", _A); } catch (e_ps_src) {}
                                                var _ok_perish = status_system_apply_status(_ps_actor, "perish-song", _perish_opts);
                                                if (_ok_perish) _applied_perish = true;
                                            }
                                            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][meta] perish-song applied_any=" + string(_applied_perish));
                                            return undefined;
                                        }
                                        var _status_target = _D;
                                        try {
                                            var _stid_norm = _stid_norm_global;
                                            if (_stid_norm == "ingrain") _status_target = _A;
                                        } catch (e_st_tgt) { _status_target = _D; }
                                        var opts = {};
                                        if (variable_struct_exists(_mm, "duration") && is_real(variable_struct_get(_mm, "duration"))) variable_struct_set(opts, "duration", variable_struct_get(_mm, "duration"));
                                        // source info useful for later (who applied)
                                        try { variable_struct_set(opts, "source", _A); } catch (e_src) {}
                                        try {
                                            if (string(stid) == "trap") variable_struct_set(opts, "display_name", __battle_move_name(_move_id));
                                        } catch (e_trap_name) {}
                                        // For trap-like statuses (Bind/Wrap/Clamp/Sand Tomb) ensure the
                                        // first tick doesn't immediately apply damage in the same turn
                                        // the move was used. The status system honors skip_first_tick.
                                        try { if (string(stid) == "trap") variable_struct_set(opts, "skip_first_tick", true); } catch (e_sft) {}
                                        var _sleep_blocked = false;
                                        try {
                                            if (string_lower(string(stid)) == "sleep" && !is_undefined(__battle_slot_has_active_uproar) && __battle_slot_has_active_uproar(_pid)) _sleep_blocked = true;
                                        } catch (e_sleep_block) { _sleep_blocked = false; }
                                        var ok2 = (_sleep_blocked ? false : status_system_apply_status(_status_target, stid, opts));
                                        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][meta] status_system_apply_status returned=" + string(ok2));
                                            // If the status applied and it is sleep, spawn floating Z overlay
                                            try {
                                                if (ok2 && string(stid) == "sleep"){
                                                    var _tgt_idx_sleep = undefined;
                                                    try { if (is_struct(_status_target) && variable_struct_exists(_status_target, "actor_index")) _tgt_idx_sleep = variable_struct_get(_status_target, "actor_index"); } catch (e_ti) { _tgt_idx_sleep = undefined; }
                                                    var _offx_s = irandom_range(-6, 6);
                                                    var _offy_s = -18 + irandom_range(-4, 4);
                                                    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){ try { show_debug_message("[battle][sleep][meta-enqueue] pid=" + string(_pid) + ", tgt=" + string(_tgt_idx_sleep) + ", off=(" + string(_offx_s) + "," + string(_offy_s) + ")"); } catch (e_dbgs) {} }
                                                    try { __battle_request_animation_safe(_pid, { type: "sleep_effect", target_index: _tgt_idx_sleep, actor: _A, target: _status_target, sprite: spr_sleep, scale: 1.0, offset_x: _offx_s, offset_y: _offy_s, rise: 26, duration: 1200 }); } catch (e_req_sleep) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][sleep] enqueue failed: " + string(e_req_sleep)); }
                                                }
                                            } catch (e_sleep_all) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][sleep] enqueue outer failed: " + string(e_sleep_all)); }
                                    }
                                } catch (e_stat) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][meta] status apply failed: " + string(e_stat)); }
                        }
                    }
                    if (variable_struct_exists(_mm, "infatuation") && variable_struct_get(_mm, "infatuation") == true && !is_undefined(status_system_apply_status)){
                        var _gender_key = function(_ent){
                            var _scan = function(_obj){
                                if (!is_struct(_obj)) return "unknown";
                                if (variable_struct_exists(_obj, "gender")){
                                    var _g = string_lower(string(variable_struct_get(_obj, "gender")));
                                    if (_g == "m" || _g == "male") return "male";
                                    if (_g == "f" || _g == "female") return "female";
                                    if (_g == "genderless" || _g == "none" || _g == "unknown") return "genderless";
                                }
                                if (variable_struct_exists(_obj, "sex")){
                                    var _s = string_lower(string(variable_struct_get(_obj, "sex")));
                                    if (_s == "m" || _s == "male") return "male";
                                    if (_s == "f" || _s == "female") return "female";
                                    if (_s == "genderless" || _s == "none" || _s == "unknown") return "genderless";
                                }
                                if (variable_struct_exists(_obj, "is_female")) return (variable_struct_get(_obj, "is_female") == true) ? "female" : "male";
                                if (variable_struct_exists(_obj, "female")) return (variable_struct_get(_obj, "female") == true) ? "female" : "male";
                                if (variable_struct_exists(_obj, "male") && variable_struct_get(_obj, "male") == true) return "male";
                                var _name_fields = ["species", "identifier", "species_name"];
                                for (var _nf = 0; _nf < array_length(_name_fields); ++_nf){
                                    var _field = _name_fields[_nf];
                                    if (!variable_struct_exists(_obj, _field)) continue;
                                    var _txt = string_lower(string(variable_struct_get(_obj, _field)));
                                    if (string_pos("-male", _txt) > 0) return "male";
                                    if (string_pos("-female", _txt) > 0) return "female";
                                }
                                return "unknown";
                            };
                            var _res = _scan(_ent);
                            if (_res == "unknown" && is_struct(_ent) && variable_struct_exists(_ent, "mon") && is_struct(variable_struct_get(_ent, "mon"))) _res = _scan(variable_struct_get(_ent, "mon"));
                            return _res;
                        };
                        var _ag = _gender_key(_A);
                        var _dg = _gender_key(_D);
                        var _can_infatuate = true;
                        if (_ag == "genderless" || _dg == "genderless") _can_infatuate = false;
                        else if ((_ag == "male" || _ag == "female") && (_dg == "male" || _dg == "female")) _can_infatuate = (_ag != _dg);
                        if (_can_infatuate){
                            var _inf_opts = {};
                            try { variable_struct_set(_inf_opts, "source", _A); } catch (e_inf_src) {}
                            var _inf_ok = status_system_apply_status(_D, "infatuation", _inf_opts);
                            if (!_inf_ok) dialog_queue("But it failed!");
                        } else {
                            dialog_queue("But it failed!");
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
                var _weather_heal_amt = undefined;
                if (is_real(_eid_status) && floor(_eid_status) == 133){
                    try {
                        var _weather_heal = __battle_get_weather(_pid);
                        if (__battle_weather_is_active(_weather_heal)){
                            var _wid_heal = __battle_weather_get_normalized_id(_weather_heal);
                            if (_wid_heal == "sun" || _wid_heal == "harsh-sun"){
                                _weather_heal_amt = floor(A_max * 2 / 3);
                            } else if (_wid_heal == "rain" || _wid_heal == "hail" || _wid_heal == "snow" || _wid_heal == "sandstorm"){
                                _weather_heal_amt = floor(A_max / 4);
                            }
                        }
                    } catch (e_weather_heal) {
                        _weather_heal_amt = undefined;
                    }
                }
                if (heal_v > 0){
                    var heal_amt2 = 0;
                    if (is_real(_weather_heal_amt)){
                        heal_amt2 = max(1, floor(_weather_heal_amt));
                    } else if (heal_v > 0 && heal_v <= 100){
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
                        // Play explicit heal SFX (battle-safe wrapper preferred)
                        // Only play when an actual HP increase occurred
                        try { if (newhp2 > A_before) __battle_play_heal_once(snd_Heal); } catch (e_hsfx) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][sound] heal SFX failed: " + string(e_hsfx)); }
                    }
                }
            }

            // Process stat_changes entries (move_meta_stat_changes.csv)
            // Each entry in _mm.stat_changes is { stat_id, change }
            // Generalize multi-target stat-change effects (Flower Shield, Rototiller, Gear Up, Magnetic Flux, Electric Terrain, etc.)
            // Map known effect_ids to simple predicates and apply the move's stat_changes to matching actors.
            try {
                // Capture for nested helpers to avoid lint warnings about undeclared variables
                var _outer_pid = _pid;
                var _move_rec = undefined;
                if (variable_global_exists("_moves") && is_array(global._moves) && is_real(_move_id) && _move_id >= 0 && _move_id < array_length(global._moves)) _move_rec = global._moves[_move_id];
                var _eid = (is_struct(_move_rec) && variable_struct_exists(_move_rec, "effect_id") && is_real(variable_struct_get(_move_rec, "effect_id"))) ? variable_struct_get(_move_rec, "effect_id") : undefined;
                // Fallback: some CSV dumps lack effect_id headers or loaders; infer terrain by identifier if needed
                if (!is_real(_eid) && is_struct(_move_rec) && variable_struct_exists(_move_rec, "identifier")){
                    var _ident_mv = string_lower(string(variable_struct_get(_move_rec, "identifier")));
                    if (string_pos("electric-terrain", _ident_mv) > 0) _eid = 369; // Electric Terrain
                    else if (string_pos("grassy-terrain", _ident_mv) > 0) _eid = 352; // Grassy Terrain
                    else if (string_pos("misty-terrain", _ident_mv) > 0) _eid = 353;  // Misty Terrain
                    else if (string_pos("psychic-terrain", _ident_mv) > 0) _eid = 395; // Psychic Terrain
                }
                if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){
                    var _idtxt = (is_struct(_move_rec) && variable_struct_exists(_move_rec, "identifier") ? string(variable_struct_get(_move_rec, "identifier")) : "<no-ident>");
                    show_debug_message("[battle][meta][trace] move_id=" + string(_move_id) + ", ident=" + _idtxt + ", effect_id_resolved=" + string(_eid));
                }

                var _weather_target = "";
                if (is_struct(_mm) && variable_struct_exists(_mm, "weather")){
                    _weather_target = __battle_weather_normalize_id(variable_struct_get(_mm, "weather"));
                }
                if (string_length(_weather_target) <= 0 && is_struct(_move_rec) && variable_struct_exists(_move_rec, "identifier")){
                    var _ident_mv_weather = string_lower(string(variable_struct_get(_move_rec, "identifier")));
                    switch (_ident_mv_weather){
                        case "sunny-day": _weather_target = "sun"; break;
                        case "rain-dance": _weather_target = "rain"; break;
                        case "sandstorm": _weather_target = "sandstorm"; break;
                        case "hail": _weather_target = "hail"; break;
                        case "snowscape": _weather_target = "snow"; break;
                        case "fog": _weather_target = "fog"; break;
                    }
                }
                if (string_length(_weather_target) > 0){
                    var _wopts = { source: _A };
                    if (is_struct(_mm) && variable_struct_exists(_mm, "weather_duration") && is_real(variable_struct_get(_mm, "weather_duration"))) variable_struct_set(_wopts, "duration", variable_struct_get(_mm, "weather_duration"));
                    __battle_set_weather(_pid, _weather_target, _wopts);
                }

                if (is_real(_eid)){
                    if (_eid == 36 || _eid == 66){
                        try {
                            var _barrier_name = (_eid == 36) ? "light_screen" : "reflect";
                            var _barrier_label = (_eid == 36) ? "Light Screen" : "Reflect";
                            var _side_idx = 0;
                            try {
                                if (is_struct(_A) && variable_struct_exists(_A, "actor_index") && is_real(variable_struct_get(_A, "actor_index"))) _side_idx = __battle_field_side_index_for_actor(variable_struct_get(_A, "actor_index"));
                            } catch (e_side_bar) { _side_idx = 0; }
                            var _barrier_turns = 5;
                            var _has_light_clay = false;
                            try {
                                if (__battle_meta_held_items_enabled(_A) && variable_struct_exists(_A, "held_item_real_name")){
                                    var _nm_bar = string_lower(string(variable_struct_get(_A, "held_item_real_name")));
                                    if (string_pos("light clay", _nm_bar) > 0) _has_light_clay = true;
                                }
                                if (__battle_meta_held_items_enabled(_A) && !_has_light_clay && variable_struct_exists(_A, "held_item_id")){
                                    var _iid_bar = variable_struct_get(_A, "held_item_id");
                                    if (is_real(_iid_bar) && _iid_bar == 246) _has_light_clay = true;
                                    else if (is_real(_iid_bar) && _iid_bar > 0 && variable_global_exists("_items") && is_array(global._items) && _iid_bar < array_length(global._items)){
                                        var _it_bar = global._items[_iid_bar];
                                        if (is_struct(_it_bar)){
                                            var _ident_bar = (variable_struct_exists(_it_bar, "identifier") ? string_lower(string(variable_struct_get(_it_bar, "identifier"))) : "");
                                            var _name_bar = (variable_struct_exists(_it_bar, "name") ? string_lower(string(variable_struct_get(_it_bar, "name"))) : "");
                                            if (string_pos("light-clay", _ident_bar) > 0 || string_pos("light clay", _name_bar) > 0) _has_light_clay = true;
                                        }
                                    }
                                }
                            } catch (e_lc) { _has_light_clay = _has_light_clay; }
                            if (_has_light_clay) _barrier_turns = 8;
                            __battle_field_set_barrier(_pid, _side_idx, _barrier_name, _barrier_turns);
                            try { __battle_request_animation_safe(_pid, { type: "set_barrier", barrier: _barrier_name, actor: _A, target: _D }); } catch (e_bar_anim) {}
                            try { if (!is_undefined(__status_request_dialog_for_mon)) __status_request_dialog_for_mon(_A, _barrier_label + " protected the team!", false); } catch (e_bar_msg) {}
                            return undefined;
                        } catch (e_barrier_apply) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][meta] barrier apply failed: " + string(e_barrier_apply)); }
                    }

                    if (_eid == 47){
                        try {
                            var _mist_side = 0;
                            try {
                                if (is_struct(_A) && variable_struct_exists(_A, "actor_index") && is_real(variable_struct_get(_A, "actor_index"))) _mist_side = __battle_field_side_index_for_actor(variable_struct_get(_A, "actor_index"));
                            } catch (e_side_mist) { _mist_side = 0; }
                            __battle_field_set_side_status(_pid, _mist_side, "mist", 5);
                            try { __battle_request_animation_safe(_pid, { type: "mist", actor: _A, target: _D }); } catch (e_mist_anim) {}
                            try { if (!is_undefined(__status_request_dialog_for_mon)) __status_request_dialog_for_mon(_A, "Mist shrouded the team!", false); } catch (e_mist_msg) {}
                            return undefined;
                        } catch (e_mist_apply) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][meta] mist apply failed: " + string(e_mist_apply)); }
                    }

                    if (_eid == 125){
                        try {
                            var _safe_side = 0;
                            try {
                                if (is_struct(_A) && variable_struct_exists(_A, "actor_index") && is_real(variable_struct_get(_A, "actor_index"))) _safe_side = __battle_field_side_index_for_actor(variable_struct_get(_A, "actor_index"));
                            } catch (e_side_safe) { _safe_side = 0; }
                            __battle_field_set_side_status(_pid, _safe_side, "safeguard", 5);
                            try { __battle_request_animation_safe(_pid, { type: "safeguard", actor: _A, target: _D }); } catch (e_safe_anim) {}
                            try { if (!is_undefined(__status_request_dialog_for_mon)) __status_request_dialog_for_mon(_A, "Safeguard protected the team!", false); } catch (e_safe_msg) {}
                            return undefined;
                        } catch (e_safe_apply) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][meta] safeguard apply failed: " + string(e_safe_apply)); }
                    }

                    if (_eid == 26){
                        try {
                            var _B_haze = __battle_ensure_slot(_pid);
                            if (is_struct(_B_haze) && variable_struct_exists(_B_haze, "actor") && is_array(variable_struct_get(_B_haze, "actor"))){
                                var _acts_haze = variable_struct_get(_B_haze, "actor");
                                for (var _hz = 0; _hz < array_length(_acts_haze); ++_hz){
                                    var _act_haze = _acts_haze[_hz];
                                    if (!is_struct(_act_haze)) continue;
                                    if (variable_struct_exists(_act_haze, "_stages")) variable_struct_set(_act_haze, "_stages", {});
                                }
                            }
                            __battle_field_clear_side_status(_pid, 0, "mist");
                            __battle_field_clear_side_status(_pid, 1, "mist");
                            try { __battle_request_animation_safe(_pid, { type: "haze", actor: _A, target: _D }); } catch (e_haze_anim) {}
                            try { if (!is_undefined(__status_request_dialog_for_mon)) __status_request_dialog_for_mon(_A, "All stat changes were eliminated!", false); } catch (e_haze_msg) {}
                            return undefined;
                        } catch (e_haze_apply) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][meta] haze apply failed: " + string(e_haze_apply)); }
                    }
                }

                // Early terrain handling: apply even if no stat_changes array exists in move meta
                if (is_real(_eid)){
                    // Electric/Grassy/Misty Terrain
                    if (_eid == 369 || _eid == 352 || _eid == 353){
                        try {
                            var terr_name_early = ( _eid == 369 ? "electric" : ( _eid == 352 ? "grassy" : "misty" ) );
                            var terr_turns_early = 5;
                            var has_ext_early = false;
                            try {
                                if (__battle_meta_held_items_enabled(_A) && variable_struct_exists(_A, "held_item_real_name")){
                                    var _nm_e = string_lower(string(variable_struct_get(_A, "held_item_real_name")));
                                    if (string_pos("terrain extender", _nm_e) > 0) has_ext_early = true;
                                }
                                if (__battle_meta_held_items_enabled(_A) && !has_ext_early && variable_struct_exists(_A, "held_item_id")){
                                    var _iid_e = variable_struct_get(_A, "held_item_id");
                                    if (is_real(_iid_e) && _iid_e == 896) has_ext_early = true;
                                    else if (is_real(_iid_e) && _iid_e > 0 && variable_global_exists("_items") && is_array(global._items) && _iid_e < array_length(global._items)){
                                        var it_e = global._items[_iid_e];
                                        if (is_struct(it_e)){
                                            var _ident_e = (variable_struct_exists(it_e, "identifier") ? string_lower(string(variable_struct_get(it_e, "identifier"))) : "");
                                            var _namev_e = (variable_struct_exists(it_e, "name") ? string_lower(string(variable_struct_get(it_e, "name"))) : "");
                                            if (string_pos("terrain-extender", _ident_e) > 0 || string_pos("terrain extender", _namev_e) > 0) has_ext_early = true;
                                        }
                                    }
                                }
                            } catch (e_tex_e){ has_ext_early = has_ext_early; }
                            if (has_ext_early) terr_turns_early = 8;
                            var _terr_opts = { source: _A, turns: terr_turns_early };
                            __battle_field_set_terrain(_pid, terr_name_early, _terr_opts);
                            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){
                                try {
                                    var _an_set_e = (is_struct(_A) && variable_struct_exists(_A, "name") ? variable_struct_get(_A, "name") : "<actor>");
                                    show_debug_message("[battle][terrain] set=" + string(terr_name_early) + ", turns=" + string(terr_turns_early) + ", by=" + string(_an_set_e));
                                } catch (e_dbgterr_e) {}
                                if (has_ext_early) show_debug_message("[battle][terrain] Terrain Extender detected: duration set to 8 turns for " + terr_name_early);
                            }
                            // Request animation and enqueue dialog
                            try { __battle_request_animation_safe(_pid, { type: "set_terrain", terrain: terr_name_early, actor: _A, target: _D }); } catch (e_tr_e) {}
                            try {
                                var nmT_e = (variable_struct_exists(_A, "name") ? variable_struct_get(_A, "name") : "The Pokémon");
                                var disp_e = "";
                                if (terr_name_early == "electric") disp_e = "Electric Terrain";
                                else if (terr_name_early == "grassy") disp_e = "Grassy Terrain";
                                else if (terr_name_early == "misty") disp_e = "Misty Terrain";
                                else disp_e = string_upper(terr_name_early) + " Terrain";
                                if (!is_undefined(__status_request_dialog_for_mon)) __status_request_dialog_for_mon(_A, "The ground became " + disp_e + "!", false);
                            } catch (e_msgt_e) {}
                        } catch (e_terr_e) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][meta] terrain apply (early) failed: " + string(e_terr_e)); }
                        return undefined;
                    }
                        // Multi-hit style moves (some datasets use effect_id 30 for Comet Punch / multi-hit)
                        if (_eid == 30){
                            try {
                                var _tgt_idx_mh = undefined;
                                var _step_target_idx_mh = (is_struct(_step) && variable_struct_exists(_step, "target_index") && is_real(variable_struct_get(_step, "target_index"))) ? floor(variable_struct_get(_step, "target_index")) : undefined;
                                var _step_actor_idx_mh = (is_struct(_step) && variable_struct_exists(_step, "actor_index") && is_real(variable_struct_get(_step, "actor_index"))) ? floor(variable_struct_get(_step, "actor_index")) : undefined;
                                var _live_attacker_mh = _A;
                                var _live_defender_mh = _D;
                                var _act_idx_mh = _step_actor_idx_mh;
                                try { _tgt_idx_mh = (!is_undefined(__battle_resolve_effect_target_index) ? __battle_resolve_effect_target_index(_pid, _A, _D, _step_target_idx_mh) : _step_target_idx_mh); } catch (e_tim) { _tgt_idx_mh = _step_target_idx_mh; }
                                if (!is_real(_tgt_idx_mh)){
                                    try {
                                        var _act_idx_seed_mh = (!is_undefined(__battle_resolve_live_actor_index) ? __battle_resolve_live_actor_index(_pid, _A, _step_actor_idx_mh) : _step_actor_idx_mh);
                                        if (is_real(_act_idx_seed_mh) && !is_undefined(__battle_get_default_target_index)) _tgt_idx_mh = __battle_get_default_target_index(_pid, _act_idx_seed_mh);
                                    } catch (e_tim_fallback) { _tgt_idx_mh = _tgt_idx_mh; }
                                }
                                try {
                                    var _Banim_mh = __battle_ensure_slot(_pid);
                                    if (is_struct(_Banim_mh) && variable_struct_exists(_Banim_mh, "actor") && is_array(variable_struct_get(_Banim_mh, "actor"))){
                                        var _acts_anim_mh = variable_struct_get(_Banim_mh, "actor");
                                        if (!is_real(_act_idx_mh)) _act_idx_mh = (!is_undefined(__battle_resolve_live_actor_index) ? __battle_resolve_live_actor_index(_pid, _A, _step_actor_idx_mh) : _step_actor_idx_mh);
                                        if (is_real(_act_idx_mh) && _act_idx_mh >= 0 && _act_idx_mh < array_length(_acts_anim_mh) && is_struct(_acts_anim_mh[_act_idx_mh])) _live_attacker_mh = _acts_anim_mh[_act_idx_mh];
                                        if (is_real(_tgt_idx_mh) && _tgt_idx_mh >= 0 && _tgt_idx_mh < array_length(_acts_anim_mh) && is_struct(_acts_anim_mh[_tgt_idx_mh])) _live_defender_mh = _acts_anim_mh[_tgt_idx_mh];
                                    }
                                } catch (e_live_attacker_mh) { _live_attacker_mh = _A; }
                                // Determine hits: prefer explicit min_hits/max_hits from move meta
                                var _min_hits_m = (variable_struct_exists(_mm, "min_hits") && is_real(variable_struct_get(_mm, "min_hits"))) ? floor(variable_struct_get(_mm, "min_hits")) : 2;
                                var _max_hits_m = (variable_struct_exists(_mm, "max_hits") && is_real(variable_struct_get(_mm, "max_hits"))) ? floor(variable_struct_get(_mm, "max_hits")) : 5;
                                if (_max_hits_m < _min_hits_m) _max_hits_m = _min_hits_m;
                                var _hits_count_m = (_min_hits_m == _max_hits_m) ? _min_hits_m : irandom_range(_min_hits_m, _max_hits_m);
                                if (!is_real(_hits_count_m) || _hits_count_m < 1) _hits_count_m = 2;

                                // Frame mapping for common multi-hit moves (comet-punch uses frame 0)
                                var _frame_map_m = 0;
                                try { if (is_struct(_move_rec) && variable_struct_exists(_move_rec, "identifier")){
                                    var _ident_m = string_lower(string(variable_struct_get(_move_rec, "identifier")));
                                    switch(_ident_m){
                                        // Frame 0: Comet Punch, Arm Thrust
                                        case "comet-punch": case "comet_punch": case "arm-thrust": case "arm_thrust": case "armthrust":
                                            _frame_map_m = 0; break;
                                        // Frame 2: Fury Swipes, Fury Cutter, Bite
                                        case "fury-swipes": case "fury_swipes": case "fury-cutter": case "fury_cutter": case "bite":
                                            _frame_map_m = 2; break;
                                        // Frame 3: Double Kick, Peck
                                        case "double-kick": case "double_kick": case "doublekick": case "peck":
                                            _frame_map_m = 3; break;
                                        // Frame 4: Karate Chop, Cross Chop
                                        case "karate-chop": case "karate_chop": case "karatechop": case "cross-chop": case "cross_chop": case "crosschop":
                                            _frame_map_m = 4; break;
                                        default: _frame_map_m = 0; break;
                                    }
                                }} catch (e_fm_m) { _frame_map_m = 0; }

                                // Per-hit damage estimate
                                var _per_hit_dmg_m = 0;
                                if (is_real(_dmg) && _hits_count_m > 0) _per_hit_dmg_m = real(_dmg) / _hits_count_m;
                                var _tgt_max_h_total = 1;
                                try { if (variable_struct_exists(_live_defender_mh, "hp_max")) _tgt_max_h_total = max(1, real(variable_struct_get(_live_defender_mh, "hp_max"))); else if (variable_struct_exists(_live_defender_mh, "mon") && is_struct(variable_struct_get(_live_defender_mh, "mon")) && variable_struct_exists(variable_struct_get(_live_defender_mh, "mon"), "hp_max")) _tgt_max_h_total = max(1, real(variable_struct_get(variable_struct_get(_live_defender_mh, "mon"), "hp_max"))); } catch (e_tmp_total) { _tgt_max_h_total = 1; }
                                var _total_dmg_m = (is_real(_dmg) ? max(0, real(_dmg)) : max(0, _per_hit_dmg_m));
                                var _prop_total_m = clamp((_tgt_max_h_total > 0 ? (_total_dmg_m / _tgt_max_h_total) : 0), 0, 1);
                                var _nudge_mag_total_m = lerp(5, 18, _prop_total_m);

                                for (var _hi_m = 0; _hi_m < _hits_count_m; ++_hi_m){
                                    var _offx_m = irandom_range(-8, 8);
                                    var _offy_m = irandom_range(-6, 6);
                                    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){
                                        try { show_debug_message("[battle][multi-hit][meta-enqueue] pid=" + string(_pid) + ", tgt=" + string(_tgt_idx_mh) + ", frame=" + string(_frame_map_m) + ", off=(" + string(_offx_m) + "," + string(_offy_m) + ")"); } catch (e_dbgmh2) {}
                                    }
                                    try { __battle_request_animation_safe(_pid, { type: "hit_effect", target_index: _tgt_idx_mh, actor: _live_attacker_mh, target: _live_defender_mh, sprite: spr_multihit, scale: 1.0, frame: _frame_map_m, offset_x: _offx_m, offset_y: _offy_m, slide_mag: 6, duration: 140 }); } catch (e_reqm2) {}
                                    try { if (!is_undefined(battle_cam_shake)) battle_cam_shake(_pid, 3, 100, 10, 0.9); } catch (e_cam2) {}

                                    // small per-hit nudge
                                    try {
                                        var _nudge_mag_m = max(4, _nudge_mag_total_m);
                                        var _ndir_m = 0; var _act_idx_m = _act_idx_mh;
                                        if (is_real(_act_idx_m) && is_real(_tgt_idx_mh)) _ndir_m = sign(_tgt_idx_mh - _act_idx_m);
                                        // Attacker nudge
                                        try { if (is_struct(_live_attacker_mh)){ variable_struct_set(_live_attacker_mh, "_nudge_active", true); variable_struct_set(_live_attacker_mh, "_nudge_start_ms", current_time); variable_struct_set(_live_attacker_mh, "_nudge_dur", 220); variable_struct_set(_live_attacker_mh, "_nudge_mag", _nudge_mag_m); variable_struct_set(_live_attacker_mh, "_nudge_dir", _ndir_m); } } catch (e_an2_live) {}
                                        // Defender nudge
                                        try {
                                            var _dmag_m = max(3.5, _nudge_mag_m * 0.85);
                                            if (is_struct(_live_defender_mh)){ variable_struct_set(_live_defender_mh, "_nudge_active", true); variable_struct_set(_live_defender_mh, "_nudge_start_ms", current_time); variable_struct_set(_live_defender_mh, "_nudge_dur", 220); variable_struct_set(_live_defender_mh, "_nudge_mag", _dmag_m); variable_struct_set(_live_defender_mh, "_nudge_dir", -_ndir_m); }
                                        } catch (e_dn2) {}
                                    } catch (e_phn) {}
                                }
                                try { var _Btmp_m2 = __battle_ensure_slot(_pid); if (is_struct(_Btmp_m2)) variable_struct_set(_Btmp_m2, "_meta_effect_applied", true); } catch (e_btmpm) {}
                            } catch (e_mh_all) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][multi-hit][meta] failed: " + string(e_mh_all)); }
                            return undefined;
                        }
                    // Psychic Terrain
                    if (_eid == 395){
                        try {
                            var psy_turns_e = 5;
                            var has_ext_p = false;
                            try {
                                if (__battle_meta_held_items_enabled(_A) && variable_struct_exists(_A, "held_item_real_name")){
                                    var _nm2_e = string_lower(string(variable_struct_get(_A, "held_item_real_name")));
                                    if (string_pos("terrain extender", _nm2_e) > 0) has_ext_p = true;
                                }
                                if (__battle_meta_held_items_enabled(_A) && !has_ext_p && variable_struct_exists(_A, "held_item_id")){
                                    var _iid2_e = variable_struct_get(_A, "held_item_id");
                                    if (is_real(_iid2_e) && _iid2_e == 896) has_ext_p = true;
                                    else if (is_real(_iid2_e) && _iid2_e > 0 && variable_global_exists("_items") && is_array(global._items) && _iid2_e < array_length(global._items)){
                                        var it2_e = global._items[_iid2_e];
                                        if (is_struct(it2_e)){
                                            var _ident2_e = (variable_struct_exists(it2_e, "identifier") ? string_lower(string(variable_struct_get(it2_e, "identifier"))) : "");
                                            var _namev2_e = (variable_struct_exists(it2_e, "name") ? string_lower(string(variable_struct_get(it2_e, "name"))) : "");
                                            if (string_pos("terrain-extender", _ident2_e) > 0 || string_pos("terrain extender", _namev2_e) > 0) has_ext_p = true;
                                        }
                                    }
                                }
                            } catch (e_tex2_e) { has_ext_p = has_ext_p; }
                            if (has_ext_p) psy_turns_e = 8;
                            var _terr_opts_psy = { source: _A, turns: psy_turns_e };
                            __battle_field_set_terrain(_pid, "psychic", _terr_opts_psy);
                            if (has_ext_p && variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][terrain] Terrain Extender detected: duration set to 8 turns for psychic");
                            try { __battle_request_animation_safe(_pid, { type: "set_terrain", terrain: "psychic", actor: _A, target: _D }); } catch (e_pt_e) {}
                            try { if (!is_undefined(__status_request_dialog_for_mon)) __status_request_dialog_for_mon(_A, "The ground became Psychic Terrain!", false); } catch (e_msgp_e) {}
                        } catch (e_psy_e) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][meta] psychic terrain apply (early) failed: " + string(e_psy_e)); }
                        return undefined;
                    }
                }

                // Helper: map stat id -> stage key (same as later loop)
                function __stat_key_by_id_local(_id){ switch(floor(_id)){ case 1: return "hp"; case 2: return "atk"; case 3: return "def"; case 4: return "spa"; case 5: return "spd"; case 6: return "spe"; case 7: return "accuracy"; case 8: return "evasion"; } return undefined; }
                function __stat_label_by_key_local(_key){
                    switch(string_lower(string(_key))){
                        case "hp": return "HP";
                        case "atk": return "ATK";
                        case "def": return "DEF";
                        case "spa": return "SPA";
                        case "spd": return "SPD";
                        case "spe": return "SPE";
                        case "accuracy": return "ACCURACY";
                        case "evasion": return "EVASION";
                    }
                    return "STAT";
                }
                function __stat_target_ref_local(_actor){
                    if (is_struct(_actor) && variable_struct_exists(_actor, "mon") && is_struct(variable_struct_get(_actor, "mon"))) return variable_struct_get(_actor, "mon");
                    return _actor;
                }
                function __stat_actor_name_local(_actor){
                    var _target_ref = __stat_target_ref_local(_actor);
                    var _display_name = undefined;
                    try {
                        if (!is_undefined(__status_mon_display_name)){
                            var _display = __status_mon_display_name(_target_ref);
                            if (is_string(_display) && string_length(_display) > 0) _display_name = _display;
                        }
                    } catch (e_stat_name) {}
                    if (is_undefined(_display_name) && is_struct(_actor) && variable_struct_exists(_actor, "name") && is_string(variable_struct_get(_actor, "name")) && string_length(variable_struct_get(_actor, "name")) > 0) _display_name = variable_struct_get(_actor, "name");
                    if (is_undefined(_display_name) || !is_string(_display_name) || string_length(_display_name) <= 0) _display_name = "The Pokemon";
                    return _display_name;
                }
                function __stat_change_dialog_text_local(_actor, _stat_key, _applied_delta, _requested_delta){
                    var _actor_name = __stat_actor_name_local(_actor);
                    var _stat_label = __stat_label_by_key_local(_stat_key);
                    if (_applied_delta == 0){
                        var _blocked_lower = (is_real(_requested_delta) && _requested_delta < 0);
                        return string(_actor_name) + "'s " + string(_stat_label) + (_blocked_lower ? " won't go any lower!" : " won't go any higher!");
                    }
                    var _sign = (_applied_delta > 0) ? ("+" + string(_applied_delta)) : string(_applied_delta);
                    return string(_actor_name) + " " + string(_stat_label) + " " + string(_sign);
                }

                // Helper: apply a list of stat_changes (array of {stat_id,change}) to a single actor
                function __apply_stat_changes_to_actor(_pid_local, _actor, _actor_idx, _sc_array, _visual_actor = undefined, _visual_actor_idx = undefined){
                    if (!is_struct(_actor) || !is_array(_sc_array)) return;
                    if (!is_struct(_visual_actor)) _visual_actor = _actor;
                    if (!is_real(_visual_actor_idx)) _visual_actor_idx = _actor_idx;
                    var _overlay_changes = {};
                    var _overlay_any = false;
                        for (var _si2 = 0; _si2 < array_length(_sc_array); ++_si2){ var _rec2 = _sc_array[_si2]; if (!is_struct(_rec2)) continue; var _sid2 = (variable_struct_exists(_rec2, "stat_id") ? variable_struct_get(_rec2, "stat_id") : undefined); var _chg2 = (variable_struct_exists(_rec2, "change") ? variable_struct_get(_rec2, "change") : undefined); if (!is_real(_sid2) || !is_real(_chg2)) continue; var _sk2 = __stat_key_by_id_local(_sid2); if (is_undefined(_sk2)) continue; if (!variable_struct_exists(_actor, "_stages") || !is_struct(variable_struct_get(_actor, "_stages"))) variable_struct_set(_actor, "_stages", {}); var _stobj = variable_struct_get(_actor, "_stages"); var _prev = (variable_struct_exists(_stobj, _sk2) && is_real(variable_struct_get(_stobj, _sk2))) ? variable_struct_get(_stobj, _sk2) : 0; var _next = clamp(_prev + floor(_chg2), -6, 6); var _apply_change = true; if (_chg2 < 0){ try { var _mist_side_idx = __battle_field_side_index_for_actor(_actor_idx); var _mist_turns = __battle_field_get_side_status_or(_pid_local, _mist_side_idx, "mist", 0); if (is_real(_mist_turns) && _mist_turns > 0) { _apply_change = false; _next = _prev; } } catch (e_mist_block) { _apply_change = true; } } if (_chg2 > 0 && _sk2 == "evasion"){ try { if (variable_struct_exists(_actor, "_miracle_eye_active") && variable_struct_get(_actor, "_miracle_eye_active") == true) { _apply_change = false; _next = _prev; } } catch (e_miracle_block) { _apply_change = _apply_change; } } if (_apply_change) variable_struct_set(_stobj, _sk2, _next); variable_struct_set(_actor, "_stages", _stobj);
                        var _delta_stage = _next - _prev;
                        if (_delta_stage != 0){
                            variable_struct_set(_overlay_changes, _sk2, _delta_stage);
                            _overlay_any = true;
                        }
                        // Request animation and enqueue dialog for this actor (use pid param)
                        try { __battle_request_animation_safe(_pid_local, { type: "stat_change", target_index: _visual_actor_idx, stat: _sk2, from: _prev, to: _next }); } catch (e_reqg) {}
                        // Note: SFX for stat changes is played when the dialog is shown; do not play here.
                        try {
                            var _scm = __stat_change_dialog_text_local(_actor, _sk2, _delta_stage, _chg2);
                            var _tref = __stat_target_ref_local(_actor);
                            if (!is_undefined(__status_request_dialog_for_mon)) __status_request_dialog_for_mon(_tref, _scm, false);
                        } catch (e_msgg) {}
                        try { var _B3 = __battle_ensure_slot(_pid_local); if (is_struct(_B3)) variable_struct_set(_B3, "_meta_effect_applied", true); } catch (e_b3) {}
                    }
                    // If there are overlay changes, enqueue them onto the battle slot so
                    // they can be triggered when the dialog for those stat changes is shown.
                    if (_overlay_any){
                        try {
                            var _B3 = __battle_ensure_slot(_pid_local);
                            if (is_struct(_B3)){
                                if (!variable_struct_exists(_B3, "_pending_stat_overlays") || !is_array(variable_struct_get(_B3, "_pending_stat_overlays"))) variable_struct_set(_B3, "_pending_stat_overlays", []);
                                var _po = variable_struct_get(_B3, "_pending_stat_overlays");
                                array_push(_po, { actor: _actor, actor_idx: _actor_idx, overlay_changes: _overlay_changes });
                                // Keep the stat-change bubble on the visual caller, but anchor the overlay stencil to the battler whose stages changed.
                                try { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][stat_overlay] enqueued pid=" + string(_pid_local) + ", actor_idx=" + string(_actor_idx) + ", changes=" + string(_overlay_changes)); } catch (e_dbg) {}
                                variable_struct_set(_B3, "_pending_stat_overlays", _po);
                            }
                        } catch (e_po) {}
                    }
                }

                // Helper: type-check if an actor is of a given type id
                function __actor_has_type(_actor, _type_id){
                    if (!is_struct(_actor)) return false;
                    try {
                        // direct types array
                        if (variable_struct_exists(_actor, "types") && is_array(variable_struct_get(_actor, "types"))){ var _ta = variable_struct_get(_actor, "types"); for (var _tti=0; _tti<array_length(_ta); ++_tti) if (is_real(_ta[_tti]) && _ta[_tti] == _type_id) return true; }
                        if (variable_struct_exists(_actor, "type1") && is_real(variable_struct_get(_actor, "type1")) && variable_struct_get(_actor, "type1") == _type_id) return true;
                        if (variable_struct_exists(_actor, "type2") && is_real(variable_struct_get(_actor, "type2")) && variable_struct_get(_actor, "type2") == _type_id) return true;
                        // species-level fallback
                        if (variable_struct_exists(_actor, "mon") && is_struct(variable_struct_get(_actor, "mon"))){ var _mi = variable_struct_get(_actor, "mon"); if (variable_struct_exists(_mi, "species_id") && is_real(variable_struct_get(_mi, "species_id")) && variable_global_exists("_species_types") && is_array(global._species_types)){ var _sidx = variable_struct_get(_mi, "species_id"); if (is_real(_sidx) && _sidx >= 0 && _sidx < array_length(global._species_types)){ var _starr = global._species_types[_sidx]; if (is_array(_starr)) for (var _jj=0; _jj<array_length(_starr); ++_jj) if (is_real(_starr[_jj]) && _starr[_jj] == _type_id) return true; } }
                        }
                    } catch (e_at) {}
                    return false;
                }

                // Helper: is actor grounded (simplified: not flying-type and doesn't have levitate ability)
                function __actor_is_grounded(_actor){
                    if (!is_struct(_actor)) return false;
                    // If an explicit grounded flag is present, prefer it (kept up to date by factory/demo/actor-builders)
                    try { if (variable_struct_exists(_actor, "grounded") && is_bool(variable_struct_get(_actor, "grounded"))) return variable_struct_get(_actor, "grounded"); } catch (e_exp) {}
                    try {
                        var _gravity_pid = undefined;
                        if (!is_undefined(__battle_resolve_pid_for_actor)) _gravity_pid = __battle_resolve_pid_for_actor(_actor);
                        if (!is_undefined(_gravity_pid)){
                            var _gravity_turns = __battle_field_get_status_or(_gravity_pid, "gravity", 0);
                            if (is_real(_gravity_turns) && _gravity_turns > 0) return true;
                        }
                    } catch (e_gravity_grounded) {}
                    // Check for flying-type membership
                    var flying_id = undefined;
                    try { if (variable_global_exists("TYPE_ID_BY_NAME")){ var _tmp = variable_global_get("TYPE_ID_BY_NAME"); if (ds_exists(_tmp, ds_type_map)) flying_id = ds_map_find_value(_tmp, string_lower("flying")); } } catch (e) { flying_id = undefined; }
                    try {
                        if (!is_undefined(flying_id) && is_real(flying_id) && __actor_has_type(_actor, flying_id)) return false;
                        // ability check
                        if (variable_struct_exists(_actor, "ability")){
                            var _ab = variable_struct_get(_actor, "ability"); if ((is_string(_ab) && string_lower(string(_ab)) == "levitate") || (is_real(_ab) && floor(_ab) == 26)) return false;
                        }
                    } catch (e_) {}
                    return true;
                }
                try { variable_global_set("__actor_is_grounded", __actor_is_grounded); } catch (e_set_grounded_fn) { global.__actor_is_grounded = __actor_is_grounded; }

                // If we have an effect_id that should target multiple actors, handle it here
                if (is_real(_eid)){
                    // Quick: effect_id 1 -> basic hit visual (draw spr_hiteffect over defender)
                    if (_eid == 1){
                        try {
                            var _step_target_idx_he = (is_struct(_step) && variable_struct_exists(_step, "target_index") && is_real(variable_struct_get(_step, "target_index"))) ? floor(variable_struct_get(_step, "target_index")) : undefined;
                            var _step_actor_idx_he = (is_struct(_step) && variable_struct_exists(_step, "actor_index") && is_real(variable_struct_get(_step, "actor_index"))) ? floor(variable_struct_get(_step, "actor_index")) : undefined;
                            var _tgt_idx_he = undefined;
                            var _act_idx_he_live = _step_actor_idx_he;
                            var _live_attacker_he = _A;
                            var _live_defender_he = _D;
                            try { _tgt_idx_he = (!is_undefined(__battle_resolve_effect_target_index) ? __battle_resolve_effect_target_index(_pid, _A, _D, _step_target_idx_he) : _step_target_idx_he); } catch (e_ti) { _tgt_idx_he = _step_target_idx_he; }
                            try {
                                var _Bslot_he = __battle_ensure_slot(_pid);
                                if (is_struct(_Bslot_he) && variable_struct_exists(_Bslot_he, "actor") && is_array(variable_struct_get(_Bslot_he, "actor"))){
                                    var _actors_he = variable_struct_get(_Bslot_he, "actor");
                                    if (!is_real(_act_idx_he_live)) _act_idx_he_live = (!is_undefined(__battle_resolve_live_actor_index) ? __battle_resolve_live_actor_index(_pid, _A, _step_actor_idx_he) : _step_actor_idx_he);
                                    if (is_real(_act_idx_he_live) && _act_idx_he_live >= 0 && _act_idx_he_live < array_length(_actors_he) && is_struct(_actors_he[_act_idx_he_live])) _live_attacker_he = _actors_he[_act_idx_he_live];
                                    if (!is_real(_tgt_idx_he) && is_real(_act_idx_he_live) && !is_undefined(__battle_get_default_target_index)) _tgt_idx_he = __battle_get_default_target_index(_pid, _act_idx_he_live);
                                    if (is_real(_tgt_idx_he) && _tgt_idx_he >= 0 && _tgt_idx_he < array_length(_actors_he) && is_struct(_actors_he[_tgt_idx_he])) _live_defender_he = _actors_he[_tgt_idx_he];
                                }
                            } catch (e_live_he) { _live_attacker_he = _A; _live_defender_he = _D; }
                            // Enqueue visual overlay hit effect
                            try { __battle_request_animation_safe(_pid, { type: "hit_effect", target_index: _tgt_idx_he, actor: _live_attacker_he, target: _live_defender_he, sprite: spr_hiteffect, scale: 1.0 }); } catch (e_reqh) {}
                            // Compute damage-based nudge for attacker: proportion of target HP
                            try {
                                var _dval = 0;
                                if (is_real(_dmg)) _dval = real(_dmg);
                                else if (is_array(_dmg) && array_length(_dmg) > 0) _dval = real(_dmg[0]);
                                else if (is_struct(_dmg) && is_struct(_D)){
                                    try {
                                        var _aid = (is_real(_tgt_idx_he) ? string(_tgt_idx_he) : "0");
                                        if (variable_struct_exists(_dmg, _aid)) _dval = real(variable_struct_get(_dmg, _aid));
                                    } catch (e_dmap){}
                                }
                                // Resolve target max HP
                                var _tgt_max = 1;
                                try { if (variable_struct_exists(_live_defender_he, "hp_max")) _tgt_max = max(1, real(variable_struct_get(_live_defender_he, "hp_max"))); else if (variable_struct_exists(_live_defender_he, "mon") && is_struct(variable_struct_get(_live_defender_he, "mon")) && variable_struct_exists(variable_struct_get(_live_defender_he, "mon"), "hp_max")) _tgt_max = max(1, real(variable_struct_get(variable_struct_get(_live_defender_he, "mon"), "hp_max"))); } catch (e_tmh) { _tgt_max = 1; }
                                var _prop = clamp((_tgt_max > 0 ? (_dval / _tgt_max) : 0), 0, 1);
                                // map proportion to nudge magnitude (logical pixels): small->2, big->18
                                var _nudge_mag = lerp(2, 18, _prop);
                                // determine slide direction: attacker should move toward target
                                var _act_idx_local = _act_idx_he_live;
                                if (!is_real(_act_idx_local)) _act_idx_local = (variable_struct_exists(_live_attacker_he, "actor_index") ? variable_struct_get(_live_attacker_he, "actor_index") : undefined);
                                var _tidx_local = _tgt_idx_he;
                                var _ndir = 0;
                                if (is_real(_act_idx_local) && is_real(_tidx_local)) _ndir = sign(_tidx_local - _act_idx_local);
                                // Set nudge fields on attacker actor for battle_draw to pick up
                                try {
                                    if (is_struct(_live_attacker_he)){
                                        variable_struct_set(_live_attacker_he, "_nudge_active", true);
                                        variable_struct_set(_live_attacker_he, "_nudge_start_ms", current_time);
                                        variable_struct_set(_live_attacker_he, "_nudge_dur", 320);
                                        variable_struct_set(_live_attacker_he, "_nudge_mag", _nudge_mag);
                                        variable_struct_set(_live_attacker_he, "_nudge_dir", _ndir);
                                    }
                                    if (is_struct(_A) && _A != _live_attacker_he){
                                        variable_struct_set(_A, "_nudge_active", true);
                                        variable_struct_set(_A, "_nudge_start_ms", current_time);
                                        variable_struct_set(_A, "_nudge_dur", 320);
                                        variable_struct_set(_A, "_nudge_mag", _nudge_mag);
                                        variable_struct_set(_A, "_nudge_dir", _ndir);
                                    }
                                } catch (e_ns) {}

                                // Debug: report attacker nudge fields when enabled
                                if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){
                                    try {
                                        var _dbgA = "(no attacker)";
                                        if (is_struct(_live_attacker_he)){
                                            var _a_idx_dbg = (variable_struct_exists(_live_attacker_he, "actor_index") ? variable_struct_get(_live_attacker_he, "actor_index") : -1);
                                            var _a_mag_dbg = (variable_struct_exists(_live_attacker_he, "_nudge_mag") ? string(variable_struct_get(_live_attacker_he, "_nudge_mag")) : "nil");
                                            var _a_dir_dbg = (variable_struct_exists(_live_attacker_he, "_nudge_dir") ? string(variable_struct_get(_live_attacker_he, "_nudge_dir")) : "nil");
                                            _dbgA = "[A idx=" + string(_a_idx_dbg) + " mag=" + _a_mag_dbg + " dir=" + _a_dir_dbg + "]";
                                        }
                                        show_debug_message("[battle][meta] hit_effect nudge attacker: " + _dbgA);
                                    } catch (e_dbgA) {}
                                }

                                // Also nudge the defender slightly *away* from the attacker so it appears to recoil.
                                // Set it on both the provided _D struct and the active actor in the battle slot (if available),
                                // because _D may sometimes be an inner mon struct rather than the actor struct used by drawing.
                                try {
                                    var _d_nudge_mag = max(1, _nudge_mag * 0.75);
                                    if (is_struct(_live_defender_he)){
                                        variable_struct_set(_live_defender_he, "_nudge_active", true);
                                        variable_struct_set(_live_defender_he, "_nudge_start_ms", current_time);
                                        // shorter duration so defender snaps back sooner
                                        variable_struct_set(_live_defender_he, "_nudge_dur", 240);
                                        variable_struct_set(_live_defender_he, "_nudge_mag", _d_nudge_mag);
                                        variable_struct_set(_live_defender_he, "_nudge_dir", -_ndir);
                                    }
                                    if (is_struct(_D) && _D != _live_defender_he){
                                        variable_struct_set(_D, "_nudge_active", true);
                                        variable_struct_set(_D, "_nudge_start_ms", current_time);
                                        variable_struct_set(_D, "_nudge_dur", 240);
                                        variable_struct_set(_D, "_nudge_mag", _d_nudge_mag);
                                        variable_struct_set(_D, "_nudge_dir", -_ndir);
                                    }
                                    // Try to write the same fields onto the battle slot actor array entry (defender) so draw will pick it up
                                    try {
                                        var _Bslot_tmp = __battle_ensure_slot(_pid);
                                        if (is_struct(_Bslot_tmp) && variable_struct_exists(_Bslot_tmp, "actor") && is_array(variable_struct_get(_Bslot_tmp, "actor"))){
                                            var _actors_tmp = variable_struct_get(_Bslot_tmp, "actor");
                                            // Determine an effective target index to write into the actor array.
                                            var _target_idx_eff = undefined;
                                            if (is_real(_tgt_idx_he) && _tgt_idx_he >= 0 && _tgt_idx_he < array_length(_actors_tmp)){
                                                _target_idx_eff = _tgt_idx_he;
                                            } else {
                                                // Prefer explicit defender actor identity before any fallback.
                                                if (!is_undefined(__battle_resolve_live_actor_index)){
                                                    var _d_actor_idx = __battle_resolve_live_actor_index(_pid, _D, undefined);
                                                    if (_d_actor_idx >= 0 && _d_actor_idx < array_length(_actors_tmp)) _target_idx_eff = _d_actor_idx;
                                                }
                                                // If attacker index exists, resolve the live opposite-side target instead of hardcoding 0<->1.
                                                if (!is_real(_target_idx_eff) && is_real(_act_idx_local) && array_length(_actors_tmp) >= 2){
                                                    _target_idx_eff = __battle_get_default_target_index(_pid, _act_idx_local);
                                                } else {
                                                    // Fallback: try to match by inner mon identity (name/species) if available
                                                    if (is_struct(_D) && variable_struct_exists(_D, "mon")){
                                                        var _dmon = variable_struct_get(_D, "mon");
                                                        for (var _ai_tmp = 0; _ai_tmp < array_length(_actors_tmp); ++_ai_tmp){
                                                            var _cand = _actors_tmp[_ai_tmp];
                                                            if (!is_struct(_cand)) continue;
                                                            if (variable_struct_exists(_cand, "mon") && is_struct(variable_struct_get(_cand, "mon"))){
                                                                var _candm = variable_struct_get(_cand, "mon");
                                                                // compare by name if available
                                                                if (variable_struct_exists(_candm, "name") && variable_struct_exists(_dmon, "name") && string(variable_struct_get(_candm, "name")) == string(variable_struct_get(_dmon, "name"))){ _target_idx_eff = _ai_tmp; break; }
                                                                // compare by species id if available
                                                                if (variable_struct_exists(_candm, "species_id") && variable_struct_exists(_dmon, "species_id") && real(variable_struct_get(_candm, "species_id")) == real(variable_struct_get(_dmon, "species_id"))){ _target_idx_eff = _ai_tmp; break; }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                            if (is_real(_target_idx_eff) && _target_idx_eff >= 0 && _target_idx_eff < array_length(_actors_tmp)){
                                                var _def_actor = _actors_tmp[_target_idx_eff];
                                                if (is_struct(_def_actor)){
                                                    variable_struct_set(_def_actor, "_nudge_active", true);
                                                    variable_struct_set(_def_actor, "_nudge_start_ms", current_time);
                                                    variable_struct_set(_def_actor, "_nudge_dur", 240);
                                                    variable_struct_set(_def_actor, "_nudge_mag", _d_nudge_mag);
                                                    variable_struct_set(_def_actor, "_nudge_dir", -_ndir);
                                                }
                                            }
                                        }
                                    } catch (e_setslot) {}
                                } catch (e_nd2) {}

                                // Debug: report defender nudge fields (try both passed _D and actor[] slot)
                                if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){
                                    try {
                                        var _dbgD = "(no defender)";
                                        // attempt to read the actor slot using the target index
                                        try {
                                            var _Bslot_dbg = __battle_ensure_slot(_pid);
                                            if (is_struct(_Bslot_dbg) && variable_struct_exists(_Bslot_dbg, "actor") && is_array(variable_struct_get(_Bslot_dbg, "actor"))){
                                                var _actors_dbg = variable_struct_get(_Bslot_dbg, "actor");
                                                if (is_real(_tgt_idx_he) && _tgt_idx_he >= 0 && _tgt_idx_he < array_length(_actors_dbg)){
                                                    var _slot_def = _actors_dbg[_tgt_idx_he];
                                                    if (is_struct(_slot_def) && variable_struct_exists(_slot_def, "_nudge_mag")){
                                                        _dbgD = "[actor_slot idx=" + string(_tgt_idx_he) + " mag=" + string(variable_struct_get(_slot_def, "_nudge_mag")) + " dir=" + string(variable_struct_get(_slot_def, "_nudge_dir")) + "]";
                                                    }
                                                }
                                            }
                                        } catch (e_dbgslot) {}
                                        // fallback to the passed _D struct
                                        if (_dbgD == "(no defender)" && is_struct(_D) && variable_struct_exists(_D, "_nudge_mag")){
                                            _dbgD = "[passed _D mag=" + string(variable_struct_get(_D, "_nudge_mag")) + " dir=" + string(variable_struct_get(_D, "_nudge_dir")) + "]";
                                        }
                                        show_debug_message("[battle][meta] hit_effect nudge defender: " + _dbgD);
                                    } catch (e_dbgD) {}
                                }
                            } catch (e_nd) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][meta] hit_effect nudge compute failed: " + string(e_nd)); }
                            try { var _Btmp = __battle_ensure_slot(_pid); if (is_struct(_Btmp)) variable_struct_set(_Btmp, "_meta_effect_applied", true); } catch (e_btmp) {}
                        } catch (e_he) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][meta] hit_effect (eid=1) failed: " + string(e_he)); }
                        return undefined;
                    }

                        // Quick-style visual: effect id 104 -> attacker afterimages (replicate attacker sprite)
                        if (_eid == 104){
                            try {
                                var _tgt_idx_qa = undefined;
                                var _step_target_idx_qa = (is_struct(_step) && variable_struct_exists(_step, "target_index") && is_real(variable_struct_get(_step, "target_index"))) ? floor(variable_struct_get(_step, "target_index")) : undefined;
                                var _step_actor_idx_qa = (is_struct(_step) && variable_struct_exists(_step, "actor_index") && is_real(variable_struct_get(_step, "actor_index"))) ? floor(variable_struct_get(_step, "actor_index")) : undefined;
                                var _live_attacker_qa = _A;
                                var _live_defender_qa = _D;
                                var _act_idx_qa_live = _step_actor_idx_qa;
                                try { _tgt_idx_qa = (!is_undefined(__battle_resolve_effect_target_index) ? __battle_resolve_effect_target_index(_pid, _A, _D, _step_target_idx_qa) : _step_target_idx_qa); } catch (e_tiqa) { _tgt_idx_qa = _step_target_idx_qa; }
                                // Small random offset for placement
                                var _offx_qa = irandom_range(-6, 6);
                                var _offy_qa = irandom_range(-6, 6);
                                // Attempt to resolve attacker's visible art sprite and subimage
                                var _spr_att = undefined;
                                var _frame_att = 0;
                                try {
                                    try {
                                        var _Banim_qa = __battle_ensure_slot(_pid);
                                        if (is_struct(_Banim_qa) && variable_struct_exists(_Banim_qa, "actor") && is_array(variable_struct_get(_Banim_qa, "actor"))){
                                            var _acts_anim_qa = variable_struct_get(_Banim_qa, "actor");
                                            if (!is_real(_act_idx_qa_live)) _act_idx_qa_live = (!is_undefined(__battle_resolve_live_actor_index) ? __battle_resolve_live_actor_index(_pid, _A, _step_actor_idx_qa) : _step_actor_idx_qa);
                                            if (is_real(_act_idx_qa_live) && _act_idx_qa_live >= 0 && _act_idx_qa_live < array_length(_acts_anim_qa) && is_struct(_acts_anim_qa[_act_idx_qa_live])) _live_attacker_qa = _acts_anim_qa[_act_idx_qa_live];
                                            if (is_real(_tgt_idx_qa) && _tgt_idx_qa >= 0 && _tgt_idx_qa < array_length(_acts_anim_qa) && is_struct(_acts_anim_qa[_tgt_idx_qa])) _live_defender_qa = _acts_anim_qa[_tgt_idx_qa];
                                        }
                                    } catch (e_live_attacker_qa) { _live_attacker_qa = _A; }
                                    if (!is_real(_tgt_idx_qa) && is_real(_act_idx_qa_live) && !is_undefined(__battle_get_default_target_index)) _tgt_idx_qa = __battle_get_default_target_index(_pid, _act_idx_qa_live);
                                    var _att_mon = undefined;
                                    if (is_struct(_live_attacker_qa) && variable_struct_exists(_live_attacker_qa, "mon")) _att_mon = variable_struct_get(_live_attacker_qa, "mon"); else _att_mon = _live_attacker_qa;
                                    if (!is_undefined(pkicons_get_art96_by_mon) && !is_undefined(pkicons_get_art96_subimg_by_mon) && is_struct(_att_mon)){
                                        _spr_att = pkicons_get_art96_by_mon(_att_mon);
                                        // prefer back-facing image for player-side actors
                                        var _att_is_player = false;
                                        if (is_real(_act_idx_qa_live) && !is_undefined(__battle_actor_view_side_slot)){
                                            var _qa_view = __battle_actor_view_side_slot(_pid, _act_idx_qa_live);
                                            _att_is_player = (is_struct(_qa_view) && variable_struct_exists(_qa_view, "side") && variable_struct_get(_qa_view, "side") == 0);
                                        } else if (is_real(_act_idx_qa_live) && !is_undefined(__battle_actor_side)){
                                            _att_is_player = (__battle_actor_side(_act_idx_qa_live) == 0);
                                        } else if (is_struct(_live_attacker_qa) && variable_struct_exists(_live_attacker_qa, "actor_index") && !is_undefined(__battle_actor_view_side_slot)){
                                            var _qa_view_fallback = __battle_actor_view_side_slot(_pid, variable_struct_get(_live_attacker_qa, "actor_index"));
                                            _att_is_player = (is_struct(_qa_view_fallback) && variable_struct_exists(_qa_view_fallback, "side") && variable_struct_get(_qa_view_fallback, "side") == 0);
                                        } else if (is_struct(_live_attacker_qa) && variable_struct_exists(_live_attacker_qa, "actor_index") && !is_undefined(__battle_actor_side)){
                                            _att_is_player = (__battle_actor_side(variable_struct_get(_live_attacker_qa, "actor_index")) == 0);
                                        }
                                        try { _frame_att = pkicons_get_art96_subimg_by_mon(_att_mon, _att_is_player); } catch (e_fa) { _frame_att = 0; }
                                    }
                                } catch (e_res) { _spr_att = undefined; _frame_att = 0; }
                                // Fallback to generic multihit sprite if art unavailable
                                if (is_undefined(_spr_att) || !sprite_exists(_spr_att)){
                                    if (!is_undefined(spr_multihit) && sprite_exists(spr_multihit)) _spr_att = spr_multihit;
                                    else _spr_att = (variable_global_exists("spr_hiteffect") ? spr_hiteffect : undefined);
                                }
                                // Enqueue visual overlays anchored to the attacker to create a trailing afterimage
                                try {
                                    var _act_idx_qa = _act_idx_qa_live;
                                    // spawn several quick overlays with slight offsets to simulate a motion trail
                                    for (var _qi = 0; _qi < 3; ++_qi){
                                        var _stagger_off = (_qi * 8);
                                        var _offx_i = _offx_qa - (_stagger_off * (is_real(_act_idx_qa) && is_real(_tgt_idx_qa) ? sign(_tgt_idx_qa - _act_idx_qa) : 1));
                                        var _offy_i = _offy_qa + irandom_range(-2, 2);
                                        var _dur_i = 100 + (_qi * 40);
                                        // fade the afterimages progressively
                                        var _alpha_i = clamp(0.9 - (_qi * 0.25), 0.15, 0.9);
                                        try { __battle_request_animation_safe(_pid, { type: "hit_effect", target_index: _act_idx_qa, actor: _live_attacker_qa, use_actor_sprite: true, sprite: _spr_att, scale: 1.0, frame: _frame_att, offset_x: _offx_i, offset_y: _offy_i, slide_mag: 10, duration: _dur_i, alpha: _alpha_i }); } catch (e_reqqa_i) {}
                                    }
                                } catch (e_reqqa) {}

                                // Tackle-style nudge: make attacker lunge forward briefly and defender react
                                try {
                                    var _tgt_max = 1;
                                    try {
                                        if (variable_struct_exists(_D, "hp_max")) _tgt_max = max(1, real(variable_struct_get(_D, "hp_max")));
                                        else if (variable_struct_exists(_D, "mon") && is_struct(variable_struct_get(_D, "mon")) && variable_struct_exists(variable_struct_get(_D, "mon"), "hp_max")) _tgt_max = max(1, real(variable_struct_get(variable_struct_get(_D, "mon"), "hp_max")));
                                    } catch (e_tmp2) { _tgt_max = 1; }
                                    var _dval_q = (is_real(_dmg) ? real(_dmg) : 0);
                                    var _prop_q = clamp((_tgt_max > 0 ? (_dval_q / _tgt_max) : 0), 0, 1);
                                    // Slightly more punchy nudge for Quick Attack (fast, snappy)
                                    var _nudge_mag_q = lerp(6, 32, _prop_q);
                                    var _ndir_q = 0; var _act_idx_q = _act_idx_qa_live;
                                    if (is_real(_act_idx_q) && is_real(_tgt_idx_qa)) _ndir_q = sign(_tgt_idx_qa - _act_idx_q);

                                    // Attacker nudge (fast lunge)
                                    try {
                                        if (is_struct(_live_attacker_qa)){
                                                variable_struct_set(_live_attacker_qa, "_nudge_active", true);
                                                variable_struct_set(_live_attacker_qa, "_nudge_start_ms", current_time);
                                                variable_struct_set(_live_attacker_qa, "_nudge_dur", 260);
                                                variable_struct_set(_live_attacker_qa, "_nudge_mag", _nudge_mag_q);
                                                variable_struct_set(_live_attacker_qa, "_nudge_dir", _ndir_q);
                                            }
                                    } catch (e_an_q) {}

                                    // Defender nudge (shorter, recoil)
                                    try {
                                        var _dmag_q = max(1, _nudge_mag_q * 0.7);
                                        // schedule defender recoil to occur after the attacker's lunge (delay by ~180ms)
                                        if (is_struct(_live_defender_qa)){
                                            variable_struct_set(_live_defender_qa, "_nudge_active", true);
                                            variable_struct_set(_live_defender_qa, "_nudge_start_ms", current_time);
                                            variable_struct_set(_live_defender_qa, "_nudge_dur", 120);
                                            variable_struct_set(_live_defender_qa, "_nudge_mag", _dmag_q);
                                            variable_struct_set(_live_defender_qa, "_nudge_dir", -_ndir_q);
                                        }
                                    } catch (e_dn_q) {}
                                } catch (e_phn_q) {}

                                try { var _Btmp2 = __battle_ensure_slot(_pid); if (is_struct(_Btmp2)) variable_struct_set(_Btmp2, "_meta_effect_applied", true); } catch (e_btmp2) {}
                            } catch (e_qa_all) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][meta] quick-attack visual (eid=104) failed: " + string(e_qa_all)); }
                            return undefined;
                        }
                    // Retrieve stat_changes array from meta if present (otherwise nothing to apply)
                    var _scarr = (variable_struct_exists(_mm, "stat_changes") && is_array(variable_struct_get(_mm, "stat_changes"))) ? variable_struct_get(_mm, "stat_changes") : undefined;
                    if (is_array(_scarr)){
                        var _Bslot = __battle_ensure_slot(_pid);
                        var _actors = (is_struct(_Bslot) && variable_struct_exists(_Bslot, "actor") && is_array(variable_struct_get(_Bslot, "actor"))) ? variable_struct_get(_Bslot, "actor") : [];

                        // Choose predicate by effect id
                        if (_eid == 340 || _eid == 351){
                            // Rototiller / Flower Shield
                            // - Rototiller (340): affect grounded Grass-type only
                            // - Flower Shield (351): affect all Grass-type (no grounded requirement)
                            var grass_tid_local = 12;
                            for (var _ai2 = 0; _ai2 < array_length(_actors); ++_ai2){
                                var act2 = _actors[_ai2]; if (!is_struct(act2)) continue; if (!__actor_has_type(act2, grass_tid_local)) continue;
                                if (_eid == 340){ if (!__actor_is_grounded(act2)) continue; }
                                __apply_stat_changes_to_actor(_pid, act2, _ai2, _scarr);
                            }
                            return undefined;
                        }

                        // Sticky Web: effect_id 341 -> sets sticky web on the opponent's side
                        if (_eid == 341){
                            try {
                                var _att_idx_sw = (is_struct(_A) && variable_struct_exists(_A, "actor_index") ? variable_struct_get(_A, "actor_index") : 0);
                                var _target_side_sw = __battle_field_side_index_for_opponent(_att_idx_sw);
                                __battle_field_set_hazard(_pid, _target_side_sw, "sticky_web", true);
                                // Request animation and dialog
                                try { __battle_request_animation_safe(_pid, { type: "set_sticky_web", actor: _A, target: _D }); } catch (e_sw) {}
                                try { var nm = (variable_struct_exists(_A, "name") ? variable_struct_get(_A, "name") : "The Pokémon"); if (!is_undefined(__status_request_dialog_for_mon)) __status_request_dialog_for_mon(_A, string(nm) + " set up Sticky Web!", false); } catch (e_msg) {}
                                try { var _B3 = __battle_ensure_slot(_pid); if (is_struct(_B3)) variable_struct_set(_B3, "_meta_effect_applied", true); } catch (e_b3) {}
                            } catch (e_stw) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][meta] sticky-web apply failed: " + string(e_stw)); }
                            return undefined;
                        }

                        // Spikes: effect_id 113 -> add a layer of spikes to the target's side
                        if (_eid == 113){
                            try {
                                var _att_idx_sp = (is_struct(_A) && variable_struct_exists(_A, "actor_index") ? variable_struct_get(_A, "actor_index") : 0);
                                var _target_side_sp = __battle_field_side_index_for_opponent(_att_idx_sp);
                                __battle_field_increment_hazard(_pid, _target_side_sp, "spikes", 1);
                                try { __battle_request_animation_safe(_pid, { type: "set_spikes", actor: _A, target: _D }); } catch (e_spa) {}
                                try { var nm2 = (variable_struct_exists(_A, "name") ? variable_struct_get(_A, "name") : "The Pokémon"); if (!is_undefined(__status_request_dialog_for_mon)) __status_request_dialog_for_mon(_A, string(nm2) + " set up Spikes!", false); } catch (e_msg2) {}
                                try { var _B4 = __battle_ensure_slot(_pid); if (is_struct(_B4)) variable_struct_set(_B4, "_meta_effect_applied", true); } catch (e_b4) {}
                            } catch (e_sp) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][meta] spikes apply failed: " + string(e_sp)); }
                            return undefined;
                        }

                        // Toxic Spikes: effect_id 250 -> place toxic spikes (1 layer = poison, 2 layers = bad poison)
                        if (_eid == 250){
                            try {
                                var _att_idx_ts = (is_struct(_A) && variable_struct_exists(_A, "actor_index") ? variable_struct_get(_A, "actor_index") : 0);
                                var _target_side_ts = __battle_field_side_index_for_opponent(_att_idx_ts);
                                __battle_field_increment_hazard(_pid, _target_side_ts, "toxic_spikes", 1);
                                try { __battle_request_animation_safe(_pid, { type: "set_toxic_spikes", actor: _A, target: _D }); } catch (e_ts) {}
                                try { var nm3 = (variable_struct_exists(_A, "name") ? variable_struct_get(_A, "name") : "The Pokémon"); if (!is_undefined(__status_request_dialog_for_mon)) __status_request_dialog_for_mon(_A, string(nm3) + " set up Toxic Spikes!", false); } catch (e_msg3) {}
                                try { var _B5 = __battle_ensure_slot(_pid); if (is_struct(_B5)) variable_struct_set(_B5, "_meta_effect_applied", true); } catch (e_b5) {}
                            } catch (e_ts2) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][meta] toxic-spikes apply failed: " + string(e_ts2)); }
                            return undefined;
                        }

                        // Stealth Rock: effect_id 267 -> set stealth rock on the target side
                        if (_eid == 267){
                            try {
                                var _att_idx_sr = (is_struct(_A) && variable_struct_exists(_A, "actor_index") ? variable_struct_get(_A, "actor_index") : 0);
                                var _target_side_sr = __battle_field_side_index_for_opponent(_att_idx_sr);
                                __battle_field_set_hazard(_pid, _target_side_sr, "stealth_rock", true);
                                try { __battle_request_animation_safe(_pid, { type: "set_stealth_rock", actor: _A, target: _D }); } catch (e_sr) {}
                                try { var nm4 = (variable_struct_exists(_A, "name") ? variable_struct_get(_A, "name") : "The Pokémon"); if (!is_undefined(__status_request_dialog_for_mon)) __status_request_dialog_for_mon(_A, string(nm4) + " set up Stealth Rock!", false); } catch (e_msg4) {}
                                try { var _B6 = __battle_ensure_slot(_pid); if (is_struct(_B6)) variable_struct_set(_B6, "_meta_effect_applied", true); } catch (e_b6) {}
                            } catch (e_sr2) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][meta] stealth-rock apply failed: " + string(e_sr2)); }
                            return undefined;
                        }

                        // Guard Split: effect_id 280 -> averages Defense and Special Defense with the target
                        if (_eid == 280){
                            try {
                                // Helper to read unmodified base stat (def/spdef) for an actor
                                function __get_unmodified_def_stats(_actor){
                                    var out = { def: undefined, spd: undefined };
                                    try {
                                        // Prefer explicit base_stats on the actor or inner mon
                                        if (is_struct(_actor) && variable_struct_exists(_actor, "base_stats") && is_struct(variable_struct_get(_actor, "base_stats"))){ var bs = variable_struct_get(_actor, "base_stats"); if (variable_struct_exists(bs, "def")) out.def = variable_struct_get(bs, "def"); if (variable_struct_exists(bs, "spd")) out.spd = variable_struct_get(bs, "spd"); }
                                        // Check inner mon structure
                                        if ((is_undefined(out.def) || is_undefined(out.spd)) && is_struct(_actor) && variable_struct_exists(_actor, "mon") && is_struct(variable_struct_get(_actor, "mon"))){ var im = variable_struct_get(_actor, "mon"); if (variable_struct_exists(im, "base_stats") && is_struct(variable_struct_get(im, "base_stats"))){ var ibs = variable_struct_get(im, "base_stats"); if (variable_struct_exists(ibs, "def") && is_real(variable_struct_get(ibs, "def"))) out.def = variable_struct_get(ibs, "def"); if (variable_struct_exists(ibs, "spd") && is_real(variable_struct_get(ibs, "spd"))) out.spd = variable_struct_get(ibs, "spd"); } }
                                        // Last resort: attempt to derive from current effective stats (less accurate)
                                        if (is_undefined(out.def) || is_undefined(out.spd)){
                                            try {
                                                if (variable_struct_exists(_actor, "def") && is_real(variable_struct_get(_actor, "def")) && is_undefined(out.def)) out.def = variable_struct_get(_actor, "def");
                                                if (variable_struct_exists(_actor, "spd") && is_real(variable_struct_get(_actor, "spd")) && is_undefined(out.spd)) out.spd = variable_struct_get(_actor, "spd");
                                                // inner mon fallbacks
                                                if (is_undefined(out.def) && variable_struct_exists(_actor, "mon") && is_struct(variable_struct_get(_actor, "mon"))){ var _im2 = variable_struct_get(_actor, "mon"); if (variable_struct_exists(_im2, "def") && is_real(variable_struct_get(_im2, "def"))) out.def = variable_struct_get(_im2, "def"); if (variable_struct_exists(_im2, "spd") && is_real(variable_struct_get(_im2, "spd"))) out.spd = variable_struct_get(_im2, "spd"); }
                                            } catch (e_r) {}
                                        }
                                    } catch (e) {}
                                    return out;
                                }

                                // Retrieve unmodified values
                                var Avals = __get_unmodified_def_stats(_A);
                                var Dvals = __get_unmodified_def_stats(_D);
                                if ((is_undefined(Avals.def) || is_undefined(Avals.spd)) || (is_undefined(Dvals.def) || is_undefined(Dvals.spd))){
                                    // If we couldn't resolve both sides, fallback quietly
                                    return undefined;
                                }

                                var avg_def = floor((real(Avals.def) + real(Dvals.def)) / 2);
                                var avg_spd = floor((real(Avals.spd) + real(Dvals.spd)) / 2);

                                // Write averaged base stats back to both actors (prefer mon.base_stats)
                                try {
                                    if (is_struct(_A) && variable_struct_exists(_A, "mon") && is_struct(variable_struct_get(_A, "mon"))){ var _Am = variable_struct_get(_A, "mon"); if (!variable_struct_exists(_Am, "base_stats") || !is_struct(variable_struct_get(_Am, "base_stats"))) variable_struct_set(_Am, "base_stats", {}); var _abs = variable_struct_get(_Am, "base_stats"); variable_struct_set(_abs, "def", avg_def); variable_struct_set(_abs, "spd", avg_spd); variable_struct_set(_Am, "base_stats", _abs); variable_struct_set(_A, "mon", _Am); }
                                    if (is_struct(_D) && variable_struct_exists(_D, "mon") && is_struct(variable_struct_get(_D, "mon"))){ var _Dm = variable_struct_get(_D, "mon"); if (!variable_struct_exists(_Dm, "base_stats") || !is_struct(variable_struct_get(_Dm, "base_stats"))) variable_struct_set(_Dm, "base_stats", {}); var _dbs = variable_struct_get(_Dm, "base_stats"); variable_struct_set(_dbs, "def", avg_def); variable_struct_set(_dbs, "spd", avg_spd); variable_struct_set(_Dm, "base_stats", _dbs); variable_struct_set(_D, "mon", _Dm); }
                                } catch (e_w) {}

                                // Request a small animation and dialog
                                try { __battle_request_animation_safe(_pid, { type: "guard_split", actor: _A, target: _D }); } catch (e_a) {}
                                try { var nmA = (variable_struct_exists(_A, "name") ? variable_struct_get(_A, "name") : (variable_struct_exists(_A, "mon") && variable_struct_exists(variable_struct_get(_A, "mon"), "name") ? variable_struct_get(variable_struct_get(_A, "mon"), "name") : "The Pokémon")); var nmD = (variable_struct_exists(_D, "name") ? variable_struct_get(_D, "name") : (variable_struct_exists(_D, "mon") && variable_struct_exists(variable_struct_get(_D, "mon"), "name") ? variable_struct_get(variable_struct_get(_D, "mon"), "name") : "The Pokémon")); if (!is_undefined(__status_request_dialog_for_mon)) __status_request_dialog_for_mon(_A, string(nmA) + " and " + string(nmD) + " had their Defense and Sp. Def averaged!", false); } catch (e_m) {}
                                try { var _B3 = __battle_ensure_slot(_pid); if (is_struct(_B3)) variable_struct_set(_B3, "_meta_effect_applied", true); } catch (e_b3) {}
                            } catch (e_guard) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][meta] guard-split apply failed: " + string(e_guard)); }
                            return undefined;
                        }

                        // Pledge moves: effect_ids 325 (Grass), 326 (Water), 327 (Fire)
                        if (_eid == 325 || _eid == 326 || _eid == 327){
                            try {
                                // Determine pledge type name
                                var pledge_type = ( _eid == 325 ? "grass" : ( _eid == 326 ? "water" : "fire" ) );
                                var _Bslot_pled = __battle_ensure_slot(_pid);
                                if (is_struct(_Bslot_pled)){
                                    // Track which pledge types were used this turn by side. Use simple key 'player' / 'enemy'
                                    var sideKey = (variable_struct_exists(_A, "actor_index") && variable_struct_get(_A, "actor_index") == 0) ? "player" : "enemy";
                                    var pmap = (variable_struct_exists(_Bslot_pled, "_pledges_this_turn") && is_struct(variable_struct_get(_Bslot_pled, "_pledges_this_turn"))) ? variable_struct_get(_Bslot_pled, "_pledges_this_turn") : {};
                                    variable_struct_set(pmap, sideKey, pledge_type);
                                    variable_struct_set(_Bslot_pled, "_pledges_this_turn", pmap);
                                    // If the opposite side already used a pledge this turn, create a combo residual on the opposing side
                                    var otherSide = (sideKey == "player" ? "enemy" : "player");
                                    if (variable_struct_exists(pmap, otherSide)){
                                        var otherType = variable_struct_get(pmap, otherSide);
                                        // Determine combo effect based on combination of pledge_type and otherType
                                        // For simplicity, if both sides used the same pledge type, apply typical pairing effect (apply opponent-side residuals)
                                        var combo_effect = undefined;
                                        if (pledge_type == "grass" || otherType == "grass") combo_effect = { id: "pledge_grass_slow", turns: 4 };
                                        if (pledge_type == "water" || otherType == "water") combo_effect = { id: "pledge_water_boost_effect", turns: 4 };
                                        if (pledge_type == "fire" || otherType == "fire") combo_effect = { id: "pledge_fire_residual", turns: 4 };
                                        // Store combo effects to apply to the opposing side (store on slot as list)
                                        if (!is_undefined(combo_effect)){
                                            // attach target side so combo application knows who to affect
                                            combo_effect.side = otherSide;
                                            var ce = (variable_struct_exists(_Bslot_pled, "_pledge_combo_effects") && is_array(variable_struct_get(_Bslot_pled, "_pledge_combo_effects"))) ? variable_struct_get(_Bslot_pled, "_pledge_combo_effects") : [];
                                            array_push(ce, combo_effect);
                                            variable_struct_set(_Bslot_pled, "_pledge_combo_effects", ce);
                                            // Enqueue dialog/animation describing combo
                                            try { __battle_request_animation_safe(_pid, { type: "pledge_combo", actor: _A, target: _D, effect: combo_effect.id }); } catch (e_pc) {}
                                            try { var nmPled = (variable_struct_exists(_A, "name") ? variable_struct_get(_A, "name") : "The Pokémon"); if (!is_undefined(__status_request_dialog_for_mon)) __status_request_dialog_for_mon(_A, string(nmPled) + " triggered a Pledge combo: " + string_upper(combo_effect.id) + "!", false); } catch (e_msgp) {}
                                        }
                                    }
                                }
                            } catch (e_p) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][meta] pledge handling failed: " + string(e_p)); }
                            return undefined;
                        }

                        if (_eid == 392 || _eid == 367){
                            // Gear Up / Magnetic Flux: apply to all allies of the attacker (same team)
                            try {
                                // Ability-filtered: plus/minus - apply to friendly mons with ability 'plus' or 'minus'
                                for (var _ai3 = 0; _ai3 < array_length(_actors); ++_ai3){ var act3 = _actors[_ai3]; if (!is_struct(act3)) continue; var ok_act = false; try { if (variable_struct_exists(act3, "ability")){ var _abx = variable_struct_get(act3, "ability"); if ((is_string(_abx) && (string_lower(string(_abx)) == "plus" || string_lower(string(_abx)) == "minus")) || (is_real(_abx) && (floor(_abx) == global.ABILITY_PLUS || floor(_abx) == global.ABILITY_MINUS))) ok_act = true; } } catch (e_ab) {} if (ok_act) __apply_stat_changes_to_actor(_pid, act3, _ai3, _scarr); }
                            } catch (e_g) { }
                            return undefined;
                        }

                        // Electric/Grassy/Misty Terrain: set terrain flag on the battle slot
                        if (_eid == 369 || _eid == 352 || _eid == 353){
                            try {
                                var terr_name = ( _eid == 369 ? "electric" : ( _eid == 352 ? "grassy" : "misty" ) );
                                var terr_turns = 5;
                                var has_extender = false;
                                try {
                                    if (__battle_meta_held_items_enabled(_A) && variable_struct_exists(_A, "held_item_real_name")){
                                        var _nm = string_lower(string(variable_struct_get(_A, "held_item_real_name")));
                                        if (string_pos("terrain extender", _nm) > 0) has_extender = true;
                                    }
                                    if (__battle_meta_held_items_enabled(_A) && !has_extender && variable_struct_exists(_A, "held_item_id")){
                                        var _iid = variable_struct_get(_A, "held_item_id");
                                        if (is_real(_iid) && _iid == 896) has_extender = true;
                                        else if (is_real(_iid) && _iid > 0 && variable_global_exists("_items") && is_array(global._items) && _iid < array_length(global._items)){
                                            var it = global._items[_iid];
                                            if (is_struct(it)){
                                                var _ident = (variable_struct_exists(it, "identifier") ? string_lower(string(variable_struct_get(it, "identifier"))) : "");
                                                var _namev = (variable_struct_exists(it, "name") ? string_lower(string(variable_struct_get(it, "name"))) : "");
                                                if (string_pos("terrain-extender", _ident) > 0 || string_pos("terrain extender", _namev) > 0) has_extender = true;
                                            }
                                        }
                                    }
                                } catch (e_tex){ has_extender = has_extender; }
                                if (has_extender) terr_turns = 8;
                                __battle_field_set_terrain(_pid, terr_name, { source: _A, turns: terr_turns });
                                if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){
                                    try { var _an_set = (is_struct(_A) && variable_struct_exists(_A, "name") ? variable_struct_get(_A, "name") : "<actor>"); show_debug_message("[battle][terrain] set=" + string(terr_name) + ", turns=" + string(terr_turns) + ", by=" + string(_an_set)); } catch (e_dbgterr) {}
                                    if (has_extender) show_debug_message("[battle][terrain] Terrain Extender detected: duration set to 8 turns for " + terr_name);
                                }
                                // Request animation and enqueue dialog
                                try { __battle_request_animation_safe(_pid, { type: "set_terrain", terrain: terr_name, actor: _A, target: _D }); } catch (e_tr) {}
                                try {
                                    var nmT = (variable_struct_exists(_A, "name") ? variable_struct_get(_A, "name") : "The Pokémon");
                                    var disp = "";
                                    if (terr_name == "electric") disp = "Electric Terrain";
                                    else if (terr_name == "grassy") disp = "Grassy Terrain";
                                    else if (terr_name == "misty") disp = "Misty Terrain";
                                    else disp = string_upper(terr_name) + " Terrain";
                                    if (!is_undefined(__status_request_dialog_for_mon)) __status_request_dialog_for_mon(_A, "The ground became " + disp + "!", false);
                                } catch (e_msgt) {}
                                try { var _B7 = __battle_ensure_slot(_pid); if (is_struct(_B7)) variable_struct_set(_B7, "_meta_effect_applied", true); } catch (e_b7) {}
                            } catch (e_terr) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][meta] terrain apply failed: " + string(e_terr)); }
                            return undefined;
                        }

                        // Psychic Terrain: effect_id 395. Overrides other terrains.
                        if (_eid == 395){
                            try {
                                var psy_turns = 5;
                                var has_ext = false;
                                try {
                                    if (__battle_meta_held_items_enabled(_A) && variable_struct_exists(_A, "held_item_real_name")){
                                        var _nm2 = string_lower(string(variable_struct_get(_A, "held_item_real_name")));
                                        if (string_pos("terrain extender", _nm2) > 0) has_ext = true;
                                    }
                                    if (__battle_meta_held_items_enabled(_A) && !has_ext && variable_struct_exists(_A, "held_item_id")){
                                        var _iid2 = variable_struct_get(_A, "held_item_id");
                                        if (is_real(_iid2) && _iid2 == 896) has_ext = true;
                                        else if (is_real(_iid2) && _iid2 > 0 && variable_global_exists("_items") && is_array(global._items) && _iid2 < array_length(global._items)){
                                            var it2 = global._items[_iid2];
                                            if (is_struct(it2)){
                                                var _ident2 = (variable_struct_exists(it2, "identifier") ? string_lower(string(variable_struct_get(it2, "identifier"))) : "");
                                                var _namev2 = (variable_struct_exists(it2, "name") ? string_lower(string(variable_struct_get(it2, "name"))) : "");
                                                if (string_pos("terrain-extender", _ident2) > 0 || string_pos("terrain extender", _namev2) > 0) has_ext = true;
                                            }
                                        }
                                    }
                                } catch (e_tex2) { has_ext = has_ext; }
                                if (has_ext) psy_turns = 8;
                                __battle_field_set_terrain(_pid, "psychic", { source: _A, turns: psy_turns });
                                if (has_ext && variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][terrain] Terrain Extender detected: duration set to 8 turns for psychic");
                                try { __battle_request_animation_safe(_pid, { type: "set_terrain", terrain: "psychic", actor: _A, target: _D }); } catch (e_pt) {}
                                try { if (!is_undefined(__status_request_dialog_for_mon)) __status_request_dialog_for_mon(_A, "The ground became Psychic Terrain!", false); } catch (e_msgp) {}
                                try { var _B8 = __battle_ensure_slot(_pid); if (is_struct(_B8)) variable_struct_set(_B8, "_meta_effect_applied", true); } catch (e_b8) {}
                            } catch (e_psy) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][meta] psychic terrain apply failed: " + string(e_psy)); }
                            return undefined;
                        }

                        // Effect 415: change terrain to Psychic after inflicting damage
                        if (_eid == 415){
                            var _did_damage_any_415 = false;
                            try {
                                if (is_real(_dmg) && _dmg > 0) _did_damage_any_415 = true;
                                else if (is_array(_dmg)){
                                    for (var _di2 = 0; _di2 < array_length(_dmg); ++_di2){ var dv2 = _dmg[_di2]; if (is_real(dv2) && dv2 > 0){ _did_damage_any_415 = true; break; } }
                                } else if (is_struct(_dmg) && is_array(_actors)){
                                    for (var _ap = 0; _ap < array_length(_actors); ++_ap){ var _actp = _actors[_ap]; if (!is_struct(_actp)) continue; var _aidxp = (variable_struct_exists(_actp, "actor_index") ? string(variable_struct_get(_actp, "actor_index")) : string(_ap)); if (variable_struct_exists(_dmg, _aidxp)){ var vvv = variable_struct_get(_dmg, _aidxp); if (is_real(vvv) && vvv > 0){ _did_damage_any_415 = true; break; } } if (variable_struct_exists(_dmg, _ap)){ var v2 = variable_struct_get(_dmg, _ap); if (is_real(v2) && v2 > 0){ _did_damage_any_415 = true; break; } } }
                                }
                            } catch (e_415) { _did_damage_any_415 = false; }
                            if (_did_damage_any_415){
                                try {
                                    var psy_turns2 = 5;
                                    var has_ext3 = false;
                                    try {
                                        if (__battle_meta_held_items_enabled(_A) && variable_struct_exists(_A, "held_item_real_name")){
                                            var _nm3 = string_lower(string(variable_struct_get(_A, "held_item_real_name")));
                                            if (string_pos("terrain extender", _nm3) > 0) has_ext3 = true;
                                        }
                                        if (__battle_meta_held_items_enabled(_A) && !has_ext3 && variable_struct_exists(_A, "held_item_id")){
                                            var _iid3 = variable_struct_get(_A, "held_item_id");
                                            if (is_real(_iid3) && _iid3 == 896) has_ext3 = true;
                                            else if (is_real(_iid3) && _iid3 > 0 && variable_global_exists("_items") && is_array(global._items) && _iid3 < array_length(global._items)){
                                                var it3 = global._items[_iid3];
                                                if (is_struct(it3)){
                                                    var _ident3 = (variable_struct_exists(it3, "identifier") ? string_lower(string(variable_struct_get(it3, "identifier"))) : "");
                                                    var _namev3 = (variable_struct_exists(it3, "name") ? string_lower(string(variable_struct_get(it3, "name"))) : "");
                                                    if (string_pos("terrain-extender", _ident3) > 0 || string_pos("terrain extender", _namev3) > 0) has_ext3 = true;
                                                }
                                            }
                                        }
                                    } catch (e_tex3) { has_ext3 = has_ext3; }
                                    if (has_ext3) psy_turns2 = 8;
                                    __battle_field_set_terrain(_pid, "psychic", { source: _A, turns: psy_turns2 });
                                    if (has_ext3 && variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][terrain] Terrain Extender detected: duration set to 8 turns for psychic (effect 415)");
                                    try { __battle_request_animation_safe(_pid, { type: "set_terrain", terrain: "psychic", actor: _A, target: _D }); } catch (e_r415) {}
                                    try { if (!is_undefined(__status_request_dialog_for_mon)) __status_request_dialog_for_mon(_A, "The ground became Psychic Terrain!", false); } catch (e_msg415) {}
                                    try { var _B8 = __battle_ensure_slot(_pid); if (is_struct(_B8)) variable_struct_set(_B8, "_meta_effect_applied", true); } catch (e_b8415) {}
                                } catch (e_all) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][meta] effect_415 failed: " + string(e_all)); }
                            }
                            return undefined;
                        }

                        // Effect 418: inflicts damage and removes any terrain present on the battlefield (if damage occurred)
                        if (_eid == 418){
                            var _did_damage_any_418 = false;
                            try {
                                if (is_real(_dmg) && _dmg > 0) _did_damage_any_418 = true;
                                else if (is_array(_dmg)){
                                    for (var _di3 = 0; _di3 < array_length(_dmg); ++_di3){ var dv3 = _dmg[_di3]; if (is_real(dv3) && dv3 > 0){ _did_damage_any_418 = true; break; } }
                                } else if (is_struct(_dmg) && is_array(_actors)){
                                    for (var _ap2 = 0; _ap2 < array_length(_actors); ++_ap2){ var _actp2 = _actors[_ap2]; if (!is_struct(_actp2)) continue; var _aidxp2 = (variable_struct_exists(_actp2, "actor_index") ? string(variable_struct_get(_actp2, "actor_index")) : string(_ap2)); if (variable_struct_exists(_dmg, _aidxp2)){ var vvv2 = variable_struct_get(_dmg, _aidxp2); if (is_real(vvv2) && vvv2 > 0){ _did_damage_any_418 = true; break; } } if (variable_struct_exists(_dmg, _ap2)){ var v22 = variable_struct_get(_dmg, _ap2); if (is_real(v22) && v22 > 0){ _did_damage_any_418 = true; break; } } }
                                }
                            } catch (e_418) { _did_damage_any_418 = false; }
                            if (_did_damage_any_418){
                                try {
                                    __battle_field_clear_terrain(_pid);
                                    try { __battle_request_animation_safe(_pid, { type: "clear_terrain", actor: _A, target: _D }); } catch (e_r418) {}
                                    try { if (!is_undefined(__status_request_dialog_for_mon)) __status_request_dialog_for_mon(_A, "The terrain returned to normal!", false); } catch (e_msg418) {}
                                    try { var _B9 = __battle_ensure_slot(_pid); if (is_struct(_B9)) variable_struct_set(_B9, "_meta_effect_applied", true); } catch (e_b9418) {}
                                } catch (e_all2) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][meta] effect_418 failed: " + string(e_all2)); }
                            }
                            return undefined;
                        }

                        if (_eid == 421){
                            // Dynamax Cannon post-hit logic handled during damage application.
                            return undefined;
                        }

                        if (_eid == 422){
                            // Snipe Shot guard bypass handled in damage application path.
                            return undefined;
                        }

                        // Effect 423: apply Jaw Lock mutual trapping after inflicting damage
                        if (_eid == 423){
                            var _did_damage_any_423 = false;
                            try {
                                if (is_real(_dmg) && _dmg > 0) _did_damage_any_423 = true;
                                else if (is_array(_dmg)){
                                    for (var _di6 = 0; _di6 < array_length(_dmg); ++_di6){ var dv6 = _dmg[_di6]; if (is_real(dv6) && dv6 > 0){ _did_damage_any_423 = true; break; } }
                                } else if (is_struct(_dmg) && is_array(_actors)){
                                    for (var _ap5 = 0; _ap5 < array_length(_actors); ++_ap5){ var _actp5 = _actors[_ap5]; if (!is_struct(_actp5)) continue; var _aidxp5 = (variable_struct_exists(_actp5, "actor_index") ? string(variable_struct_get(_actp5, "actor_index")) : string(_ap5)); if (variable_struct_exists(_dmg, _aidxp5)){ var vvv5 = variable_struct_get(_dmg, _aidxp5); if (is_real(vvv5) && vvv5 > 0){ _did_damage_any_423 = true; break; } } if (variable_struct_exists(_dmg, _ap5)){ var v25 = variable_struct_get(_dmg, _ap5); if (is_real(v25) && v25 > 0){ _did_damage_any_423 = true; break; } } }
                                }
                            } catch (e_423) { _did_damage_any_423 = false; }
                            if (_did_damage_any_423){
                                try {
                                    if (!is_undefined(__battle_jaw_lock_bind) && is_struct(_A) && is_struct(_D)){
                                        __battle_jaw_lock_bind(_pid, _A, _D);
                                        try {
                                            var _an_jaw = (variable_struct_exists(_A, "name") ? variable_struct_get(_A, "name") : "The attacker");
                                            var _dn_jaw = (variable_struct_exists(_D, "name") ? variable_struct_get(_D, "name") : "the target");
                                            if (!is_undefined(__status_request_dialog_for_mon)) __status_request_dialog_for_mon(_A, string(_an_jaw) + " and " + string(_dn_jaw) + " can't escape now!", false);
                                        } catch (e_msgjaw) {}
                                        try { var _Bls = __battle_ensure_slot(_pid); if (is_struct(_Bls)) variable_struct_set(_Bls, "_meta_effect_applied", true); } catch (e_m3) {}
                                    }
                                } catch (e_all5) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][meta] effect_423 failed: " + string(e_all5)); }
                            }
                            return undefined;
                        }

                        // Effect 424: cure the user's party of major status after inflicting damage
                        if (_eid == 424){
                            var _did_damage_any_424 = false;
                            try {
                                if (is_real(_dmg) && _dmg > 0) _did_damage_any_424 = true;
                                else if (is_array(_dmg)){
                                    for (var _di7 = 0; _di7 < array_length(_dmg); ++_di7){ var dv7 = _dmg[_di7]; if (is_real(dv7) && dv7 > 0){ _did_damage_any_424 = true; break; } }
                                } else if (is_struct(_dmg) && is_array(_actors)){
                                    for (var _ap6 = 0; _ap6 < array_length(_actors); ++_ap6){ var _actp6 = _actors[_ap6]; if (!is_struct(_actp6)) continue; var _aidxp6 = (variable_struct_exists(_actp6, "actor_index") ? string(variable_struct_get(_actp6, "actor_index")) : string(_ap6)); if (variable_struct_exists(_dmg, _aidxp6)){ var vvv6 = variable_struct_get(_dmg, _aidxp6); if (is_real(vvv6) && vvv6 > 0){ _did_damage_any_424 = true; break; } } if (variable_struct_exists(_dmg, _ap6)){ var v26 = variable_struct_get(_dmg, _ap6); if (is_real(v26) && v26 > 0){ _did_damage_any_424 = true; break; } } }
                                }
                            } catch (e_424) { _did_damage_any_424 = false; }
                            if (_did_damage_any_424){
                                try {
                                    // Cure the user's party: iterate party via party_ensure? Use global.PARTY if present
                                    try {
                                        if (variable_global_exists("PARTY") && is_array(global.PARTY) && variable_struct_exists(_A, "party_id")){
                                            var pid_party = variable_struct_get(_A, "party_id");
                                            if (is_real(pid_party) && pid_party >= 0 && pid_party < array_length(global.PARTY)){
                                                var pstruct = global.PARTY[pid_party];
                                                if (is_struct(pstruct) && variable_struct_exists(pstruct, "mons") && is_array(variable_struct_get(pstruct, "mons"))){
                                                    var mons_arr = variable_struct_get(pstruct, "mons");
                                                    for (var _mi2 = 0; _mi2 < array_length(mons_arr); ++_mi2){ var mref = mons_arr[_mi2]; if (!is_struct(mref)) continue; try { if (variable_struct_exists(mref, "status")) variable_struct_set(mref, "status", ""); if (variable_struct_exists(mref, "major_status")) variable_struct_set(mref, "major_status", ""); } catch (e_mr) {} }
                                                }
                                            }
                                        }
                                    } catch (e_partyc) {}
                                    try { __battle_request_animation_safe(_pid, { type: "cure_party", actor: _A }); } catch (e_cure) {}
                                    try { var nmC2 = (variable_struct_exists(_A, "name") ? variable_struct_get(_A, "name") : "The Pokémon"); if (!is_undefined(__status_request_dialog_for_mon)) __status_request_dialog_for_mon(_A, string(nmC2) + " cured their party!", false); } catch (e_msgc) {}
                                    try { var _Bclr = __battle_ensure_slot(_pid); if (is_struct(_Bclr)) variable_struct_set(_Bclr, "_meta_effect_applied", true); } catch (e_m4) {}
                                } catch (e_all6) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][meta] effect_424 failed: " + string(e_all6)); }
                            }
                            return undefined;
                        }

                        if (_eid == 369 || _eid == 352 || _eid == 353){
                            // Terrain effects (Electric/Grassy/Misty): apply to all grounded Pokémon (apply to grounded actors)
                            for (var _ai4 = 0; _ai4 < array_length(_actors); ++_ai4){ var act4 = _actors[_ai4]; if (!is_struct(act4)) continue; if (!__actor_is_grounded(act4)) continue; __apply_stat_changes_to_actor(_pid, act4, _ai4, _scarr); }
                            return undefined;
                        }

                        var _generic_target_id = (is_struct(_move_rec) && variable_struct_exists(_move_rec, "target_id") && is_real(variable_struct_get(_move_rec, "target_id"))) ? floor(variable_struct_get(_move_rec, "target_id")) : undefined;
                        if (is_real(_generic_target_id)){
                            var _attacker_idx_generic = (is_struct(_A) && variable_struct_exists(_A, "actor_index") && is_real(variable_struct_get(_A, "actor_index"))) ? floor(variable_struct_get(_A, "actor_index")) : undefined;
                            var _generic_step_target_idx = (is_struct(_step) && variable_struct_exists(_step, "target_index") && is_real(variable_struct_get(_step, "target_index"))) ? floor(variable_struct_get(_step, "target_index")) : undefined;
                            var _attacker_side_generic = is_real(_attacker_idx_generic) ? __battle_field_side_index_for_actor(_attacker_idx_generic) : undefined;
                            var _generic_move_power = (is_struct(_move_rec) && variable_struct_exists(_move_rec, "power") && is_real(variable_struct_get(_move_rec, "power"))) ? floor(variable_struct_get(_move_rec, "power")) : 0;
                            var _generic_has_positive = false;
                            var _generic_has_negative = false;
                            for (var _gsi = 0; _gsi < array_length(_scarr); ++_gsi){
                                var _grec = _scarr[_gsi];
                                if (!is_struct(_grec) || !variable_struct_exists(_grec, "change")) continue;
                                var _gchange = variable_struct_get(_grec, "change");
                                if (!is_real(_gchange)) continue;
                                if (_gchange > 0) _generic_has_positive = true;
                                if (_gchange < 0) _generic_has_negative = true;
                            }
                            var _generic_targets_user = false;
                            if (_generic_move_power > 0 && _generic_has_positive && !_generic_has_negative) _generic_targets_user = true;
                            if (is_real(_eid)){
                                switch (floor(_eid)){
                                    case 183:
                                    case 205:
                                    case 219:
                                    case 230:
                                    case 335:
                                    case 360:
                                    case 405:
                                        _generic_targets_user = true;
                                        break;
                                }
                            }
                            if (_is_swagger) _generic_targets_user = true;
                            if (_called_swagger_self) _generic_targets_user = true;
                            if (_generic_targets_user){
                                __apply_stat_changes_to_actor(_pid, _A, _attacker_idx_generic, _scarr);
                                return undefined;
                            }

                            switch (_generic_target_id){
                                case 7:
                                    __apply_stat_changes_to_actor(_pid, _A, _attacker_idx_generic, _scarr);
                                    return undefined;

                                case 1:
                                case 2:
                                case 8:
                                case 10:
                                case 16:
                                    if (is_struct(_D)) __apply_stat_changes_to_actor(_pid, _D, resolve_effect_target_index_safe(_pid, _A, _D, _generic_step_target_idx), _scarr, _A, _attacker_idx_generic);
                                    return undefined;

                                case 11:
                                case 6:
                                    for (var _gt_i = 0; _gt_i < array_length(_actors); ++_gt_i){
                                        var _gt_actor = _actors[_gt_i];
                                        if (!is_struct(_gt_actor) || _gt_actor == _A) continue;
                                        if (is_real(_attacker_side_generic) && __battle_field_side_index_for_actor(_gt_i) == _attacker_side_generic) continue;
                                        __apply_stat_changes_to_actor(_pid, _gt_actor, _gt_i, _scarr, _A, _attacker_idx_generic);
                                    }
                                    return undefined;

                                case 13:
                                    for (var _ga_i = 0; _ga_i < array_length(_actors); ++_ga_i){
                                        var _ga_actor = _actors[_ga_i];
                                        if (!is_struct(_ga_actor)) continue;
                                        if (is_real(_attacker_side_generic) && __battle_field_side_index_for_actor(_ga_i) != _attacker_side_generic) continue;
                                        __apply_stat_changes_to_actor(_pid, _ga_actor, _ga_i, _scarr, _A, _attacker_idx_generic);
                                    }
                                    return undefined;

                                case 15:
                                    for (var _gal_i = 0; _gal_i < array_length(_actors); ++_gal_i){
                                        var _gal_actor = _actors[_gal_i];
                                        if (!is_struct(_gal_actor) || _gal_actor == _A) continue;
                                        if (is_real(_attacker_side_generic) && __battle_field_side_index_for_actor(_gal_i) != _attacker_side_generic) continue;
                                        __apply_stat_changes_to_actor(_pid, _gal_actor, _gal_i, _scarr, _A, _attacker_idx_generic);
                                    }
                                    return undefined;

                                case 9:
                                    for (var _go_i = 0; _go_i < array_length(_actors); ++_go_i){
                                        var _go_actor = _actors[_go_i];
                                        if (!is_struct(_go_actor) || _go_actor == _A) continue;
                                        __apply_stat_changes_to_actor(_pid, _go_actor, _go_i, _scarr, _A, _attacker_idx_generic);
                                    }
                                    return undefined;

                                case 5:
                                    if (is_struct(_D)) __apply_stat_changes_to_actor(_pid, _D, resolve_effect_target_index_safe(_pid, _A, _D, _generic_step_target_idx), _scarr, _A, _attacker_idx_generic);
                                    else __apply_stat_changes_to_actor(_pid, _A, _attacker_idx_generic, _scarr);
                                    return undefined;
                            }
                        }

                        // Some moves (effect_id 419) boost the user after damaging all opposing Pokémon.
                        // Implement a best-effort support: if effect_id==419 and stat_changes exist, apply stat_changes to the attacker (_A)
                        if (_eid == 419){
                            // Effect 419: user gets stat boosts only if the move damaged at least one opposing Pokémon.
                            var _did_damage_any = false;
                            try {
                                // _dmg can be a single real, an array of reals (per-target), or a struct mapping actor_index->damage
                                if (is_real(_dmg) && _dmg > 0) {
                                    _did_damage_any = true;
                                } else if (is_array(_dmg)){
                                    for (var _di = 0; _di < array_length(_dmg); ++_di){ var dv = _dmg[_di]; if (is_real(dv) && dv > 0){ _did_damage_any = true; break; } }
                                } else if (is_struct(_dmg)){
                                    // _dmg may be a struct keyed by actor index or slot; iterate known actors and probe for damage entries
                                    if (is_array(_actors)){
                                        for (var _aiProbe = 0; _aiProbe < array_length(_actors); ++_aiProbe){
                                            var _actProbe = _actors[_aiProbe];
                                            if (!is_struct(_actProbe)) continue;
                                            var _a_idx = (variable_struct_exists(_actProbe, "actor_index") ? string(variable_struct_get(_actProbe, "actor_index")) : string(_aiProbe));
                                            // try numeric and string keys
                                            if (variable_struct_exists(_dmg, _a_idx)){
                                                var _val = variable_struct_get(_dmg, _a_idx);
                                                if (is_real(_val) && _val > 0){ _did_damage_any = true; break; }
                                            }
                                            if (variable_struct_exists(_dmg, _aiProbe)){
                                                var _val2 = variable_struct_get(_dmg, _aiProbe);
                                                if (is_real(_val2) && _val2 > 0){ _did_damage_any = true; break; }
                                            }
                                        }
                                    }
                                }
                            } catch (e_dd) { _did_damage_any = false; }
                            if (_did_damage_any){
                                try {
                                    var _a_index = (variable_struct_exists(_A, "actor_index") ? variable_struct_get(_A, "actor_index") : undefined);
                                    var _boost_payload = _scarr;
                                    if (!is_array(_boost_payload) || array_length(_boost_payload) <= 0){
                                        _boost_payload = [];
                                        var _core_stats = [2,3,4,5,6];
                                        for (var _stat_i = 0; _stat_i < array_length(_core_stats); ++_stat_i){
                                            var _sid_local = _core_stats[_stat_i];
                                            _boost_payload[array_length(_boost_payload)] = { stat_id: _sid_local, change: 1 };
                                        }
                                    }
                                    __apply_stat_changes_to_actor(_pid, _A, _a_index, _boost_payload);
                                    // Ensure a single stat-change animation / SFX is requested for the user
                                    try { __battle_request_animation_safe(_pid, { type: "stat_change_group", actor_index: _a_index }); } catch (e_anim) {}
                                } catch (e_419) {}
                            }
                            return undefined;
                        }
                    }
                }
            } catch (e_multi) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][meta] multi-target stat apply failed: " + string(e_multi)); }


            // Fallback: apply stat_changes to the user (_A) for self-boosting moves like Harden
            try {
                if (variable_struct_exists(_mm, "stat_changes") && is_array(variable_struct_get(_mm, "stat_changes"))){
                    var scs = variable_struct_get(_mm, "stat_changes");
                    var _fallback_target = _A;
                    var _fallback_actor_idx = (is_struct(_A) && variable_struct_exists(_A, "actor_index") && is_real(variable_struct_get(_A, "actor_index"))) ? variable_struct_get(_A, "actor_index") : undefined;
                    var _fallback_visual_actor = _A;
                    var _fallback_visual_actor_idx = _fallback_actor_idx;
                    var _fallback_step_target_idx = (is_struct(_step) && variable_struct_exists(_step, "target_index") && is_real(variable_struct_get(_step, "target_index"))) ? floor(variable_struct_get(_step, "target_index")) : undefined;
                    var _fallback_move_rec = undefined;
                    if (variable_global_exists("_moves") && is_array(global._moves) && is_real(_move_id) && _move_id >= 0 && _move_id < array_length(global._moves)) _fallback_move_rec = global._moves[_move_id];
                    var _fallback_target_id = (is_struct(_fallback_move_rec) && variable_struct_exists(_fallback_move_rec, "target_id") && is_real(variable_struct_get(_fallback_move_rec, "target_id"))) ? floor(variable_struct_get(_fallback_move_rec, "target_id")) : undefined;
                    var _fallback_has_positive = false;
                    var _fallback_has_negative = false;
                    for (var _fsi = 0; _fsi < array_length(scs); ++_fsi){
                        var _frec = scs[_fsi];
                        if (!is_struct(_frec) || !variable_struct_exists(_frec, "change")) continue;
                        var _fchange = variable_struct_get(_frec, "change");
                        if (!is_real(_fchange)) continue;
                        if (_fchange > 0) _fallback_has_positive = true;
                        if (_fchange < 0) _fallback_has_negative = true;
                    }
                    if (_fallback_has_positive && !_fallback_has_negative){
                        _fallback_target = _A;
                        _fallback_actor_idx = (is_struct(_A) && variable_struct_exists(_A, "actor_index") && is_real(variable_struct_get(_A, "actor_index"))) ? variable_struct_get(_A, "actor_index") : _fallback_actor_idx;
                        _fallback_visual_actor = _fallback_target;
                        _fallback_visual_actor_idx = _fallback_actor_idx;
                    } else if (is_struct(_D) && is_real(_fallback_step_target_idx) && !is_real(_fallback_target_id) && _fallback_has_negative && !_fallback_has_positive){
                        var _attacker_idx_step = (is_struct(_A) && variable_struct_exists(_A, "actor_index") && is_real(variable_struct_get(_A, "actor_index"))) ? floor(variable_struct_get(_A, "actor_index")) : undefined;
                        if (!is_real(_attacker_idx_step) || _fallback_step_target_idx != _attacker_idx_step){
                            _fallback_target = _D;
                            _fallback_actor_idx = resolve_effect_target_index_safe(_pid, _A, _D, _fallback_step_target_idx);
                            _fallback_visual_actor = _fallback_target;
                            _fallback_visual_actor_idx = _fallback_actor_idx;
                        }
                    } else if (is_struct(_D) && is_real(_fallback_target_id) && _fallback_target_id != 7){
                        _fallback_target = _D;
                        _fallback_actor_idx = resolve_effect_target_index_safe(_pid, _A, _D, _fallback_step_target_idx);
                        _fallback_visual_actor = _fallback_target;
                        _fallback_visual_actor_idx = _fallback_actor_idx;
                    }
                    // Accumulate overlay changes so self-boosting moves (like Harden)
                    // also enqueue the stat overlay to be shown when the dialog appears.
                    var _fb_overlay_changes = {};
                    var _fb_overlay_any = false;
                    for (var si = 0; si < array_length(scs); ++si){
                        var rec = scs[si];
                        if (!is_struct(rec)) continue;
                        var sid = (variable_struct_exists(rec, "stat_id") ? variable_struct_get(rec, "stat_id") : undefined);
                        var change = (variable_struct_exists(rec, "change") ? variable_struct_get(rec, "change") : undefined);
                        if (!is_real(sid) || !is_real(change)) continue;
                        function __stat_key_by_id(_id){ switch(floor(_id)){ case 1: return "hp"; case 2: return "atk"; case 3: return "def"; case 4: return "spa"; case 5: return "spd"; case 6: return "spe"; case 7: return "accuracy"; case 8: return "evasion"; } return undefined; }
                        var sk = __stat_key_by_id(sid);
                        if (is_undefined(sk)) continue;
                        // Fallback target is self for self-target moves (target_id 7) and defender for opponent-target stat changes.
                        if (!variable_struct_exists(_fallback_target, "_stages") || !is_struct(variable_struct_get(_fallback_target, "_stages"))) variable_struct_set(_fallback_target, "_stages", {});
                        var stobj = variable_struct_get(_fallback_target, "_stages");
                        var prev = (variable_struct_exists(stobj, sk) && is_real(variable_struct_get(stobj, sk))) ? variable_struct_get(stobj, sk) : 0;
                        var next = clamp(prev + floor(change), -6, 6);
                        variable_struct_set(stobj, sk, next);
                        variable_struct_set(_fallback_target, "_stages", stobj);
                        // compute applied amount and record overlay change for later consumption at dialog-show time
                        var applied_amt = next - prev;
                        if (applied_amt != 0){
                            try { variable_struct_set(_fb_overlay_changes, sk, applied_amt); _fb_overlay_any = true; } catch (e_fb) {}
                        }
                        // Request stat-change animation for user
                        try { __battle_request_animation_safe(_pid, { type: "stat_change", target_index: _fallback_visual_actor_idx, stat: sk, from: prev, to: next }); } catch (e_req) {}
                        // Note: SFX for stat changes is played when the dialog is shown; do not play here.
                        try {
                            var sc_msg = __stat_change_dialog_text_local(_fallback_target, sk, applied_amt, change);
                            var _target_mon_ref = __stat_target_ref_local(_fallback_target);
                            if (!is_undefined(__status_request_dialog_for_mon)) __status_request_dialog_for_mon(_target_mon_ref, sc_msg, false);
                        } catch (e_msg) {}
                        try { var _B2 = __battle_ensure_slot(_pid); if (is_struct(_B2)) variable_struct_set(_B2, "_meta_effect_applied", true); } catch (e_b2) {}
                    }
                    // If we recorded overlay changes, enqueue them onto the battle slot
                    if (_fb_overlay_any){
                        try {
                            var _Bslot = __battle_ensure_slot(_pid);
                            if (is_struct(_Bslot)){
                                if (!variable_struct_exists(_Bslot, "_pending_stat_overlays") || !is_array(variable_struct_get(_Bslot, "_pending_stat_overlays"))) variable_struct_set(_Bslot, "_pending_stat_overlays", []);
                                var _po2 = variable_struct_get(_Bslot, "_pending_stat_overlays");
                                array_push(_po2, { actor: _fallback_target, actor_idx: _fallback_actor_idx, overlay_changes: _fb_overlay_changes });
                                try { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][stat_overlay] enqueued (fallback) pid=" + string(_pid) + ", actor_idx=" + string(is_real(_fallback_actor_idx) ? _fallback_actor_idx : -1) + ", target_id=" + string(_fallback_target_id) + ", changes=" + string(_fb_overlay_changes)); } catch (e_dbgf) {}
                                variable_struct_set(_Bslot, "_pending_stat_overlays", _po2);
                            }
                        } catch (e_pof) {}
                    }
                    // end fallback handling
                }
            } catch (e_scl) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][meta] stat_changes apply failed: " + string(e_scl)); }

            // Process flinch meta (if present): some moves may set mm.flinch=true and mm.flinch_chance
            try {
                var fl = (variable_struct_exists(_mm, "flinch") ? variable_struct_get(_mm, "flinch") : false);
                var flch = (variable_struct_exists(_mm, "flinch_chance") && is_real(variable_struct_get(_mm, "flinch_chance"))) ? floor(variable_struct_get(_mm, "flinch_chance")) : -1;
                // Fallbacks: mm.chance or move effect_chance may be used by loaders
                if ((flch <= 0) && variable_struct_exists(_mm, "chance") && is_real(variable_struct_get(_mm, "chance"))) flch = floor(variable_struct_get(_mm, "chance"));
                if ((flch <= 0) && variable_struct_exists(_mm, "effect_chance") && is_real(variable_struct_get(_mm, "effect_chance"))) flch = floor(variable_struct_get(_mm, "effect_chance"));
                    // If Water Pledge double-effect is active for attacker side, double flinch chance
                    try {
                        var _Bslot_local3 = __battle_ensure_slot(_pid);
                        if (is_struct(_Bslot_local3) && variable_struct_exists(_Bslot_local3, "_pledge_flags") && is_struct(variable_struct_get(_Bslot_local3, "_pledge_flags"))){
                            var pf_local3 = variable_struct_get(_Bslot_local3, "_pledge_flags");
                            var atk_side2 = (variable_struct_exists(_A, "actor_index") && variable_struct_get(_A, "actor_index") == 0) ? 0 : 1;
                            var wk3 = "water_pledge_double_effect_side_" + string(atk_side2);
                            if (variable_struct_exists(pf_local3, wk3) && is_real(variable_struct_get(pf_local3, wk3)) && variable_struct_get(pf_local3, wk3) > 0){
                                if (is_real(flch) && flch > 0) flch = min(100, floor(flch * 2));
                            }
                        }
                    } catch (e_pff) {}
                // Allow a developer override to force flinch chance for testing.
                // A value of -1 explicitly disables the override and restores
                // normal move-meta behavior; only apply when the global is a
                // real number and not -1.
                if (variable_global_exists("DEV_FORCE_FLINCH_CHANCE") && is_real(global.DEV_FORCE_FLINCH_CHANCE) && floor(global.DEV_FORCE_FLINCH_CHANCE) != -1){
                    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][meta] DEV_FORCE_FLINCH_CHANCE override in effect: " + string(global.DEV_FORCE_FLINCH_CHANCE));
                    flch = floor(global.DEV_FORCE_FLINCH_CHANCE);
                }
                // If a flinch_chance is present but the explicit `flinch` boolean
                // wasn't set in the meta, treat the presence of a positive
                // flinch_chance as an implicit enable for flinch behavior.
                if (!fl && is_real(flch) && flch > 0) fl = true;
                // Dev: if testing specific moves, print detailed flinch diagnostics
                if (is_real(_move_id) && ( _move_id == 23 || _move_id == 27 || _move_id == 29 ) && variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){
                    try { show_debug_message("[dev][flinch-check] move="+string(_move_id)+", mm="+string(_mm)+", fl="+string(fl)+", flch="+string(flch)+", dmg="+string(_dmg)+", target_present="+string(is_struct(_D))); } catch (e_dbgd) {}
                }
                if (fl && is_real(flch) && flch > 0){
                    // Only attempt flinch if the damage actually hit (dmg > 0) and defender is present
                    if (is_real(_dmg) && _dmg > 0 && is_struct(_D)){
                        var rollf = irandom(99);
                        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][meta] flinch attempt move=" + string(_move_id) + ", chance=" + string(flch) + ", roll=" + string(rollf));
                        if (rollf < flch){
                            // Mark defender as flinched (temporary per-turn flag). The action executor should honor this flag and skip the mon's next action.
                            try {
                                // If caller passed an actor wrapper, set on wrapper and inner mon
                                if (is_struct(_D)){
                                    try { variable_struct_set(_D, "_flinched", true); } catch (e_f) {}
                                    try {
                                        if (variable_struct_exists(_D, "mon") && is_struct(variable_struct_get(_D, "mon"))){
                                            var _inner = variable_struct_get(_D, "mon");
                                            try { variable_struct_set(_inner, "_flinched", true); } catch (e_f2) {}
                                        }
                                    } catch (e_inner) {}
                                } else {
                                    // If caller passed an inner mon, set flag there and attempt to find its actor wrapper
                                    try { variable_struct_set(_D, "_flinched", true); } catch (e_if) {}
                                    try {
                                        if (variable_global_exists("sys_battles") && is_array(global.sys_battles)){
                                            for (var _bi = 0; _bi < array_length(global.sys_battles); ++_bi){
                                                var _BB = global.sys_battles[_bi]; if (!is_struct(_BB) || !variable_struct_exists(_BB, "actor")) continue;
                                                var _acts = variable_struct_get(_BB, "actor"); if (!is_array(_acts)) continue;
                                                for (var _ai = 0; _ai < array_length(_acts); ++_ai){ var _act = _acts[_ai]; if (!is_struct(_act)) continue; if (variable_struct_exists(_act, "mon") && variable_struct_get(_act, "mon") == _D){ try { variable_struct_set(_act, "_flinched", true); } catch (e_wr) {} }
                                                }
                                            }
                                        }
                                    } catch (e_find) {}
                                }
                            } catch (e_f) {}
                            // Queue a small flinch dialog/animation so player sees the effect
                            try {
                                var _tname = (variable_struct_exists(_D, "name") ? variable_struct_get(_D, "name") : "The Pokémon");
                                try { dialog2p_show_now(_pid, string(_tname) + " flinched!"); } catch (e_dfl) { try { dialog2p_enqueue(_pid, string(_tname) + " flinched!"); } catch(e_){} }
                                __battle_request_animation_safe(_D, { type: "flinch" });
                            } catch (e_f2) { }
                            try { var _B2 = __battle_ensure_slot(_pid); if (is_struct(_B2)) variable_struct_set(_B2, "_meta_effect_applied", true); } catch (e_b2) {}
                        }
                    }
                }
            } catch (e_fa) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][meta] flinch apply failed: " + string(e_fa)); }

        } catch (e_meta){ if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][meta] apply failed: " + string(e_meta)); }

        return undefined;
    }
}

if (!is_undefined(__battle_apply_move_meta_effects)){
    try { variable_global_set("__battle_apply_move_meta_effects", __battle_apply_move_meta_effects); }
    catch (e_set_meta_fn) { global.__battle_apply_move_meta_effects = __battle_apply_move_meta_effects; }
}

// [Battle Move Behavior] Centralized legacy/special move resolver — Build v1.0.0 — Updated 2026-05-12
// Success-rate self-check target: 100% patch verification.

if (is_undefined(__battle_move_identifier_safe)){
    function __battle_move_identifier_safe(_move_id){
        var _ident = "";
        try {
            if (variable_global_exists("_moves") && is_array(global._moves) && is_real(_move_id)){
                var _idx = floor(_move_id);
                if (_idx >= 0 && _idx < array_length(global._moves)){
                    var _move_rec = global._moves[_idx];
                    if (is_struct(_move_rec) && variable_struct_exists(_move_rec, "identifier")){
                        _ident = string_lower(string(variable_struct_get(_move_rec, "identifier")));
                    }
                }
            }
        } catch (e_ident) { _ident = ""; }
        return _ident;
    }
}

if (is_undefined(__battle_move_effect_id_safe)){
    function __battle_move_effect_id_safe(_move_id){
        var _effect_id = undefined;
        try {
            if (variable_global_exists("_moves") && is_array(global._moves) && is_real(_move_id)){
                var _idx = floor(_move_id);
                if (_idx >= 0 && _idx < array_length(global._moves)){
                    var _move_rec = global._moves[_idx];
                    if (is_struct(_move_rec) && variable_struct_exists(_move_rec, "effect_id") && is_real(variable_struct_get(_move_rec, "effect_id"))){
                        _effect_id = floor(variable_struct_get(_move_rec, "effect_id"));
                    }
                }
            }
        } catch (e_effect_id) { _effect_id = undefined; }

        if (!is_real(_effect_id)){
            try {
                if (!is_undefined(__battle_get_move_meta) && is_real(_move_id)){
                    var _mm = __battle_get_move_meta(_move_id);
                    if (is_struct(_mm) && variable_struct_exists(_mm, "effect_id") && is_real(variable_struct_get(_mm, "effect_id"))){
                        _effect_id = floor(variable_struct_get(_mm, "effect_id"));
                    }
                }
            } catch (e_meta_effect_id) { _effect_id = undefined; }
        }

        return _effect_id;
    }
}

if (is_undefined(__battle_move_behavior)){
    function __battle_move_behavior(_move_id){
        var _ident = __battle_move_identifier_safe(_move_id);
        var _effect_id = __battle_move_effect_id_safe(_move_id);
        var _mm = undefined;

        try {
            if (!is_undefined(__battle_get_move_meta) && is_real(_move_id)) _mm = __battle_get_move_meta(_move_id);
        } catch (e_get_meta) { _mm = undefined; }

        var _behavior = {
            move_id: (is_real(_move_id) ? floor(_move_id) : -1),
            identifier: _ident,
            effect_id: _effect_id,
            drain: 0,
            healing: 0,
            recoil: 0,
            requires_target_status: "",
            fail_if_target_status_missing: false,
            spread_drain: false,
            drain_from_total_damage: false,
            power_double_if_user_statused: false,
            power_double_if_target_status: "",
            cure_target_status_after_damage: "",
            damage_double_if_target_dynamax: false,
            bypass_target_guard: false,
            recharge_after_damage: false,
            fail_after_first_active_turn: false,
            uproar_lock: false,
            focus_punch_gate: false,
            taunt_target: false,
            natural_gift_uses_berry: false,
            pluck_berry_after_damage: false,
            wake_target_after_damage: false,
            switch_user_after_damage: false,
            target_status_after_damage: "",
            target_status_chance_after_damage: 0,
            secret_power_after_damage: false,
            centralized: true
        };

        if (is_struct(_mm)){
            try {
                if (variable_struct_exists(_mm, "drain") && is_real(variable_struct_get(_mm, "drain"))){
                    variable_struct_set(_behavior, "drain", real(variable_struct_get(_mm, "drain")));
                }
            } catch (e_mm_drain) {}

            try {
                if (variable_struct_exists(_mm, "healing") && is_real(variable_struct_get(_mm, "healing"))){
                    variable_struct_set(_behavior, "healing", real(variable_struct_get(_mm, "healing")));
                }
            } catch (e_mm_healing) {}

            try {
                if (variable_struct_exists(_mm, "recoil") && is_real(variable_struct_get(_mm, "recoil"))){
                    variable_struct_set(_behavior, "recoil", real(variable_struct_get(_mm, "recoil")));
                }
            } catch (e_mm_recoil) {}
        }

        switch (_ident){
            case "absorb":
            case "mega-drain":
            case "leech-life":
            case "giga-drain":
            case "drain-punch":
            case "horn-leech":
                variable_struct_set(_behavior, "drain", 50);
                break;

            case "dream-eater":
                variable_struct_set(_behavior, "drain", 50);
                variable_struct_set(_behavior, "requires_target_status", "sleep");
                variable_struct_set(_behavior, "fail_if_target_status_missing", true);
                break;

            case "parabolic-charge":
                variable_struct_set(_behavior, "drain", 50);
                variable_struct_set(_behavior, "spread_drain", true);
                variable_struct_set(_behavior, "drain_from_total_damage", true);
                break;

            case "draining-kiss":
            case "oblivion-wing":
                variable_struct_set(_behavior, "drain", 75);
                break;

            case "bitter-blade":
            case "matcha-gotcha":
                variable_struct_set(_behavior, "drain", 50);
                break;
        }

        if (is_real(_effect_id)){
            switch (floor(_effect_id)){
                case 4:
                    if (real(variable_struct_get(_behavior, "drain")) <= 0) variable_struct_set(_behavior, "drain", 50);
                    break;
                case 9:
                    variable_struct_set(_behavior, "drain", 50);
                    variable_struct_set(_behavior, "requires_target_status", "sleep");
                    variable_struct_set(_behavior, "fail_if_target_status_missing", true);
                    break;
                case 346:
                    variable_struct_set(_behavior, "drain", 50);
                    variable_struct_set(_behavior, "spread_drain", true);
                    variable_struct_set(_behavior, "drain_from_total_damage", true);
                    break;
                case 349:
                    variable_struct_set(_behavior, "drain", 75);
                    break;
                case 81:
                    variable_struct_set(_behavior, "recharge_after_damage", true);
                    break;
                case 159:
                    variable_struct_set(_behavior, "fail_after_first_active_turn", true);
                    break;
                case 160:
                    variable_struct_set(_behavior, "uproar_lock", true);
                    break;
                case 170:
                    variable_struct_set(_behavior, "power_double_if_user_statused", true);
                    break;
                case 171:
                    variable_struct_set(_behavior, "focus_punch_gate", true);
                    break;
                case 172:
                    variable_struct_set(_behavior, "power_double_if_target_status", "paralysis");
                    variable_struct_set(_behavior, "cure_target_status_after_damage", "paralysis");
                    break;
                case 176:
                    variable_struct_set(_behavior, "taunt_target", true);
                    break;
                case 198:
                    variable_struct_set(_behavior, "secret_power_after_damage", true);
                    break;
                case 201:
                    variable_struct_set(_behavior, "target_status_after_damage", "burn");
                    variable_struct_set(_behavior, "target_status_chance_after_damage", 10);
                    break;
                case 203:
                    variable_struct_set(_behavior, "target_status_after_damage", "toxic");
                    variable_struct_set(_behavior, "target_status_chance_after_damage", 50);
                    break;
                case 210:
                    variable_struct_set(_behavior, "target_status_after_damage", "poison");
                    variable_struct_set(_behavior, "target_status_chance_after_damage", 10);
                    break;
                case 218:
                    variable_struct_set(_behavior, "wake_target_after_damage", true);
                    break;
                case 223:
                    variable_struct_set(_behavior, "natural_gift_uses_berry", true);
                    break;
                case 225:
                    variable_struct_set(_behavior, "pluck_berry_after_damage", true);
                    break;
                case 229:
                    variable_struct_set(_behavior, "switch_user_after_damage", true);
                    break;
                case 421:
                    variable_struct_set(_behavior, "damage_double_if_target_dynamax", true);
                    break;
                case 422:
                    variable_struct_set(_behavior, "bypass_target_guard", true);
                    break;
            }
        }

        if (is_real(_move_id)){
            switch (floor(_move_id)){
                case 891:
                case 902:
                    variable_struct_set(_behavior, "drain", 50);
                    break;
            }
        }

        return _behavior;
    }
}

if (is_undefined(__battle_move_behavior_drain)){
    function __battle_move_behavior_drain(_move_id, _fallback_drain){
        var _drain_value = (is_real(_fallback_drain) ? real(_fallback_drain) : 0);
        try {
            var _behavior = __battle_move_behavior(_move_id);
            if (is_struct(_behavior) && variable_struct_exists(_behavior, "drain") && is_real(variable_struct_get(_behavior, "drain"))){
                _drain_value = real(variable_struct_get(_behavior, "drain"));
            }
        } catch (e_behavior_drain) {}
        return _drain_value;
    }
}

if (is_undefined(__battle_move_behavior_actor_has_status)){
    function __battle_move_behavior_actor_has_status(_actor, _status_id){
        if (!is_struct(_actor) || !is_string(_status_id) || string_length(_status_id) <= 0) return false;
        if (is_undefined(status_system_has_status)) return false;

        try {
            if (status_system_has_status(_actor, _status_id)) return true;
        } catch (e_status_outer) {}

        try {
            if (variable_struct_exists(_actor, "mon") && is_struct(variable_struct_get(_actor, "mon"))){
                if (status_system_has_status(variable_struct_get(_actor, "mon"), _status_id)) return true;
            }
        } catch (e_status_inner) {}

        return false;
    }
}

if (is_undefined(__battle_move_behavior_has_major_status)){
    function __battle_move_behavior_has_major_status(_actor){
        if (!is_struct(_actor) || is_undefined(status_system_has_status)) return false;
        var _statuses = ["burn", "poison", "toxic", "paralysis", "paralyze", "sleep", "freeze"];
        for (var _i = 0; _i < array_length(_statuses); ++_i){
            try {
                if (status_system_has_status(_actor, _statuses[_i])) return true;
                if (variable_struct_exists(_actor, "mon") && is_struct(variable_struct_get(_actor, "mon")) && status_system_has_status(variable_struct_get(_actor, "mon"), _statuses[_i])) return true;
            } catch (e_major_status) {}
        }
        return false;
    }
}

if (is_undefined(__battle_move_behavior_power_multiplier)){
    function __battle_move_behavior_power_multiplier(_move_id, _A, _D){
        var _mult = 1.0;
        try {
            var _behavior = __battle_move_behavior(_move_id);
            if (!is_struct(_behavior)) return _mult;

            if (variable_struct_exists(_behavior, "power_double_if_user_statused") && variable_struct_get(_behavior, "power_double_if_user_statused") == true){
                if (__battle_move_behavior_has_major_status(_A)) _mult *= 2;
            }

            if (variable_struct_exists(_behavior, "power_double_if_target_status")){
                var _target_status = string(variable_struct_get(_behavior, "power_double_if_target_status"));
                if (string_length(_target_status) > 0 && __battle_move_behavior_actor_has_status(_D, _target_status)) _mult *= 2;
            }
        } catch (e_power_mult) {}
        return _mult;
    }
}

// [Battle Move Behavior] Phase 2 fixed/recoil/healing categories - Build v1.0.0 - Updated 2026-05-12
//
// These helpers extend __battle_move_behavior without replacing the Phase 1 resolver.
// They keep fixed-damage, OHKO, recoil, and healing expectations centralized.

if (is_undefined(__battle_move_behavior_phase2_apply)){
    function __battle_move_behavior_phase2_apply(_behavior, _move_id){
        if (!is_struct(_behavior)) return _behavior;

        if (!variable_struct_exists(_behavior, "fixed_damage")) variable_struct_set(_behavior, "fixed_damage", undefined);
        if (!variable_struct_exists(_behavior, "level_damage")) variable_struct_set(_behavior, "level_damage", false);
        if (!variable_struct_exists(_behavior, "half_current_hp_damage")) variable_struct_set(_behavior, "half_current_hp_damage", false);
        if (!variable_struct_exists(_behavior, "ohko")) variable_struct_set(_behavior, "ohko", false);
        if (!variable_struct_exists(_behavior, "self_ko_after_damage")) variable_struct_set(_behavior, "self_ko_after_damage", false);
        // [central-behavior] Phase 2 self_ko alias for smoke/future callers.
        if (!variable_struct_exists(_behavior, "self_ko")) variable_struct_set(_behavior, "self_ko", false);
        if (!variable_struct_exists(_behavior, "recoil_percent")) variable_struct_set(_behavior, "recoil_percent", 0);

        var _ident = "";
        try { if (variable_struct_exists(_behavior, "identifier")) _ident = string_lower(string(variable_struct_get(_behavior, "identifier"))); } catch (e_phase2_ident) {}
        var _effect_id = undefined;
        try { if (variable_struct_exists(_behavior, "effect_id") && is_real(variable_struct_get(_behavior, "effect_id"))) _effect_id = floor(variable_struct_get(_behavior, "effect_id")); } catch (e_phase2_eid) {}

        switch (_ident){
            case "sonic-boom":
                variable_struct_set(_behavior, "fixed_damage", 20);
                break;

            case "dragon-rage":
                variable_struct_set(_behavior, "fixed_damage", 40);
                break;

            case "seismic-toss":
            case "night-shade":
                variable_struct_set(_behavior, "level_damage", true);
                break;

            case "super-fang":
            case "natures-madness":
            case "nature's-madness":
                variable_struct_set(_behavior, "half_current_hp_damage", true);
                break;

            case "guillotine":
            case "horn-drill":
            case "fissure":
            case "sheer-cold":
                variable_struct_set(_behavior, "ohko", true);
                break;

            case "self-destruct":
            case "explosion":
                variable_struct_set(_behavior, "self_ko_after_damage", true);
                variable_struct_set(_behavior, "self_ko", true);
                break;
        }

        if (is_real(_effect_id)){
            switch (floor(_effect_id)){
                case 8:  // user faints after damage
                    variable_struct_set(_behavior, "self_ko_after_damage", true);
                    variable_struct_set(_behavior, "self_ko", true);
                    break;

                case 39: // OHKO
                    variable_struct_set(_behavior, "ohko", true);
                    break;

                case 41: // half current HP damage
                    variable_struct_set(_behavior, "half_current_hp_damage", true);
                    break;

                case 42: // fixed 40 damage
                    variable_struct_set(_behavior, "fixed_damage", 40);
                    break;
            }
        }

        if (is_real(_move_id)){
            switch (floor(_move_id)){
                case 49:  // sonic-boom
                    variable_struct_set(_behavior, "fixed_damage", 20);
                    break;

                case 82:  // dragon-rage
                    variable_struct_set(_behavior, "fixed_damage", 40);
                    break;

                case 69:  // seismic-toss
                case 101: // night-shade
                    variable_struct_set(_behavior, "level_damage", true);
                    break;

                case 162: // super-fang
                case 717: // nature's-madness
                    variable_struct_set(_behavior, "half_current_hp_damage", true);
                    break;

                case 12:  // guillotine
                case 32:  // horn-drill
                case 90:  // fissure
                case 329: // sheer-cold
                    variable_struct_set(_behavior, "ohko", true);
                    break;
            }
        }

        return _behavior;
    }
}

if (is_undefined(__battle_move_behavior_full)){
    function __battle_move_behavior_full(_move_id){
        var _behavior = undefined;
        try {
            if (!is_undefined(__battle_move_behavior)) _behavior = __battle_move_behavior(_move_id);
        } catch (e_behavior_base) { _behavior = undefined; }

        if (!is_struct(_behavior)){
            _behavior = {
                move_id: (is_real(_move_id) ? floor(_move_id) : -1),
                identifier: "",
                effect_id: undefined,
                drain: 0,
                healing: 0,
                recoil: 0,
                centralized: true
            };
        }

        return __battle_move_behavior_phase2_apply(_behavior, _move_id);
    }
}

if (is_undefined(__battle_move_behavior_fixed_damage)){
    function __battle_move_behavior_fixed_damage(_move_id, _A, _D){
        var _behavior = __battle_move_behavior_full(_move_id);

        try {
            if (is_struct(_behavior) && variable_struct_exists(_behavior, "fixed_damage") && is_real(variable_struct_get(_behavior, "fixed_damage"))){
                return max(0, floor(variable_struct_get(_behavior, "fixed_damage")));
            }
        } catch (e_fixed_damage) {}

        try {
            if (is_struct(_behavior) && variable_struct_exists(_behavior, "level_damage") && variable_struct_get(_behavior, "level_damage") == true){
                var _level = 1;
                if (is_struct(_A) && variable_struct_exists(_A, "level") && is_real(variable_struct_get(_A, "level"))) _level = floor(variable_struct_get(_A, "level"));
                else if (is_struct(_A) && variable_struct_exists(_A, "mon") && is_struct(variable_struct_get(_A, "mon"))){
                    var _mon = variable_struct_get(_A, "mon");
                    if (variable_struct_exists(_mon, "level") && is_real(variable_struct_get(_mon, "level"))) _level = floor(variable_struct_get(_mon, "level"));
                }
                return max(1, _level);
            }
        } catch (e_level_damage) {}

        try {
            if (is_struct(_behavior) && variable_struct_exists(_behavior, "half_current_hp_damage") && variable_struct_get(_behavior, "half_current_hp_damage") == true){
                var _hp_now = 0;
                if (!is_undefined(__battle_hp_now)) _hp_now = __battle_hp_now(_D);
                else if (is_struct(_D) && variable_struct_exists(_D, "hp_now") && is_real(variable_struct_get(_D, "hp_now"))) _hp_now = variable_struct_get(_D, "hp_now");
                return max(0, floor(_hp_now / 2));
            }
        } catch (e_half_damage) {}

        return undefined;
    }
}
