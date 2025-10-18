// [Battle] battle_moves_impls — minimal placeholder
// Small syntactically-correct placeholder for __battle_perform_action_impl
// to keep the project compiling while the full move resolver is worked on.

function __battle_perform_action_impl(_pid, _step){
    var _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B)) return "";
    var actor_idx = (variable_struct_exists(_step, "actor_index") ? variable_struct_get(_step, "actor_index") : 0);
    var target_idx = (variable_struct_exists(_step, "target_index") ? variable_struct_get(_step, "target_index") : 1);
    var A = undefined; var D = undefined;
    try {
        if (is_struct(_B) && variable_struct_exists(_B, "actor") && is_array(variable_struct_get(_B, "actor"))){
            var __acts = variable_struct_get(_B, "actor");
            if (is_real(actor_idx) && actor_idx >= 0 && actor_idx < array_length(__acts)) A = __acts[actor_idx];
            if (is_real(target_idx) && target_idx >= 0 && target_idx < array_length(__acts)) D = __acts[target_idx];
        }
    } catch (e_a) { A = undefined; D = undefined; }

    // item use shortcut (keeps prior behavior simple)
    if (is_struct(_step) && variable_struct_exists(_step, "item_use") && _step.item_use == true){
        var item_id = (variable_struct_exists(_step, "item_id") ? variable_struct_get(_step, "item_id") : undefined);
        variable_struct_set(_B, "_pending_item_use", { item_id: item_id });
        var disp = "item";
        if (!is_undefined(variable_global_exists) && variable_global_exists("_items") && is_array(global._items) && is_real(item_id) && item_id >= 0 && item_id < array_length(global._items)){
            var it = global._items[item_id]; if (is_struct(it) && variable_struct_exists(it, "name")) disp = string(variable_struct_get(it, "name"));
        }
        var trainer = (variable_global_exists("PLAYER_NAME") ? string(global.PLAYER_NAME) : "You");
        return string(trainer) + " used a " + string(disp) + ".";
    }

    var move_slot = (variable_struct_exists(_step, "slot") ? variable_struct_get(_step, "slot") : undefined);
    var move_id   = (variable_struct_exists(_step, "move_id") ? variable_struct_get(_step, "move_id") : undefined);

    // minimal status check to avoid crashes during refactor
    try {
        if (!is_undefined(status_system_has_status) && is_struct(A) && status_system_has_status(A, "sleep")){
            // Request blocked animation, but do NOT enqueue another dialog because
            // status_system_apply_status already queues the canonical 'fell asleep!'
            __battle_request_animation_safe(A, { type: "status_blocked", status: "sleep" });
            return "";
        }
    } catch (e) { }

    // check for Imprison on the target slot: if target slot has an _imprisoned map/list and it contains this move, fail
    try {
        var _slot_check = __battle_ensure_slot(_pid);
        if (is_struct(_slot_check) && variable_struct_exists(_slot_check, "_imprisoned")){
            var _imap = variable_struct_get(_slot_check, "_imprisoned");
            var imprisoned = false;
            // check string-keyed map at _map
            if (is_struct(_imap) && variable_struct_exists(_imap, "_map") && is_struct(variable_struct_get(_imap, "_map"))){
                var _smap = variable_struct_get(_imap, "_map");
                if (variable_struct_exists(_smap, string(move_id))) imprisoned = true;
            }
            // check numeric list at _list
            if (!imprisoned && is_struct(_imap) && variable_struct_exists(_imap, "_list") && is_array(variable_struct_get(_imap, "_list"))){
                var _slist = variable_struct_get(_imap, "_list");
                for (var _li = 0; _li < array_length(_slist); _li++){ if (is_real(_slist[_li]) && _slist[_li] == move_id){ imprisoned = true; break; } }
            }
            if (imprisoned){ try { __battle_request_animation_safe(A, { type: "blocked", reason: "imprison" }); } catch (e_blk2) {} return ""; }
        }
    } catch (e_ic) { }

    if (!__battle_consume_pp(A, move_slot)) return string((variable_struct_exists(A,"name")?variable_struct_get(A,"name"):"The user")) + " has no PP left!";

    var mv_name = (is_undefined(move_id) ? "the move" : __battle_move_name(move_id));
    var mv_power = 0;
    try { mv_power = __battle_move_power(move_id, A, D); } catch (e) { mv_power = 0; }

    // Generic two-turn move handling (charge then strike). This handles common
    // Gen3 two-turn moves like Razor Wind, SolarBeam, Skull Bash, Sky Attack,
    // Fly, Dig, Dive, Bounce, etc. First use sets a charging flag on the actor
    // (_charging_move) and returns; the second use with the same move_id clears
    // the flag and proceeds to actually perform the attack.
    try {
        if (is_real(move_id) && is_struct(A)){
            var two_ids = [13,76,130,143,19,91,291,340]; // razor-wind, solar-beam, skull-bash, sky-attack, fly, dig, dive, bounce
            var is_two = false;
            for (var _ti=0; _ti<array_length(two_ids); ++_ti) if (two_ids[_ti] == move_id) { is_two = true; break; }
            if (is_two){
                var charging = (variable_struct_exists(A, "_charging_move") ? variable_struct_get(A, "_charging_move") : undefined);
                // If actor is already charging this same move, consume the charge and continue
                if (is_struct(charging) && variable_struct_exists(charging, "move_id") && variable_struct_get(charging, "move_id") == move_id){
                    // Clear charging state and proceed with normal attack
                    variable_struct_set(A, "_charging_move", undefined);
                    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][two-turn] " + string(variable_struct_get(A, "name")) + " completes charge for move=" + string(move_id));
                } else {
                    // Start charging: store move and intended target index so the second
                    // turn can reference it. PP already consumed earlier.
                    variable_struct_set(A, "_charging_move", { move_id: move_id, target_index: target_idx });
                    // Request a charge animation if available and return the 'used' dialog
                    try { __battle_request_animation_safe(A, { type: "charge", move_id: move_id }); } catch (e_ch) {}
                    return string((variable_struct_exists(A,"name")?variable_struct_get(A,"name"):"The user")) + " used " + mv_name + "!";
                }
            }
        }
    } catch (e_two){ if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][two-turn] handler error: " + string(e_two)); }

    // Counter / Mirror Coat / Metal Burst: reflect last-received damage if appropriate
    try {
        if (is_real(move_id) && is_struct(A)){
            // Counter: physical counter (reflects double physical damage received)
            if (move_id == 68){
                var lastd = (variable_struct_exists(A, "_last_received_damage") ? variable_struct_get(A, "_last_received_damage") : 0);
                var lastclass = (variable_struct_exists(A, "_last_received_move_damage_class") ? variable_struct_get(A, "_last_received_move_damage_class") : undefined);
                // In Gen3, Counter only responds to physical moves; we check damage class == 2 (physical) when available
                if (is_real(lastd) && lastd > 0 && (is_undefined(lastclass) || lastclass == 2)){
                    var reflect = lastd * 2;
                    // Apply reflected damage to the original attacker if we can determine actor index
                    var atk_idx = (variable_struct_exists(A, "_last_received_from_actor_index") ? variable_struct_get(A, "_last_received_from_actor_index") : undefined);
                    var _Bslot2 = __battle_ensure_slot(_pid);
                    if (is_real(atk_idx) && is_struct(_Bslot2)){
                        __battle_apply_damage(_pid, atk_idx, reflect, 1.0);
                        try { __battle_request_animation_safe(A, { type: "counter", amount: reflect }); } catch (e_ca) {}
                        return string((variable_struct_exists(A,"name")?variable_struct_get(A,"name"):"The user")) + " used " + mv_name + "!";
                    }
                }
                // If nothing to reflect, play a blocked/miss animation
                try { __battle_request_animation_safe(A, { type: "blocked", reason: "counter_none" }); } catch (e_bn) {}
                return string((variable_struct_exists(A,"name")?variable_struct_get(A,"name"):"The user")) + " used " + mv_name + "!";
            }

            // Mirror Coat: reflects special moves (damage class 3) back at double damage
            if (move_id == 243){
                var lastd2 = (variable_struct_exists(A, "_last_received_damage") ? variable_struct_get(A, "_last_received_damage") : 0);
                var lastclass2 = (variable_struct_exists(A, "_last_received_move_damage_class") ? variable_struct_get(A, "_last_received_move_damage_class") : undefined);
                if (is_real(lastd2) && lastd2 > 0 && (is_undefined(lastclass2) || lastclass2 == 3)){
                    var reflect2 = lastd2 * 2;
                    var atk_idx2 = (variable_struct_exists(A, "_last_received_from_actor_index") ? variable_struct_get(A, "_last_received_from_actor_index") : undefined);
                    var _Bslot3 = __battle_ensure_slot(_pid);
                    if (is_real(atk_idx2) && is_struct(_Bslot3)){
                        __battle_apply_damage(_pid, atk_idx2, reflect2, 1.0);
                        try { __battle_request_animation_safe(A, { type: "mirror_coat", amount: reflect2 }); } catch (e_mc) {}
                        return string((variable_struct_exists(A,"name")?variable_struct_get(A,"name"):"The user")) + " used " + mv_name + "!";
                    }
                }
                try { __battle_request_animation_safe(A, { type: "blocked", reason: "mirror_none" }); } catch (e_bn2) {}
                return string((variable_struct_exists(A,"name")?variable_struct_get(A,"name"):"The user")) + " used " + mv_name + "!";
            }

            // Metal Burst (id 368): reflect 1.5x last received damage (phys or spec in Gen4+; in Gen3 returns 1.5x both?)
            if (move_id == 368){
                var lastd3 = (variable_struct_exists(A, "_last_received_damage") ? variable_struct_get(A, "_last_received_damage") : 0);
                if (is_real(lastd3) && lastd3 > 0){
                    var reflect3 = floor(lastd3 * 1.5);
                    var atk_idx3 = (variable_struct_exists(A, "_last_received_from_actor_index") ? variable_struct_get(A, "_last_received_from_actor_index") : undefined);
                    var _Bslot4 = __battle_ensure_slot(_pid);
                    if (is_real(atk_idx3) && is_struct(_Bslot4)){
                        __battle_apply_damage(_pid, atk_idx3, reflect3, 1.0);
                        try { __battle_request_animation_safe(A, { type: "metal_burst", amount: reflect3 }); } catch (e_mb) {}
                        return string((variable_struct_exists(A,"name")?variable_struct_get(A,"name"):"The user")) + " used " + mv_name + "!";
                    }
                }
                try { __battle_request_animation_safe(A, { type: "blocked", reason: "metal_none" }); } catch (e_mb2) {}
                return string((variable_struct_exists(A,"name")?variable_struct_get(A,"name"):"The user")) + " used " + mv_name + "!";
            }
        }
    } catch (e_cm) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][counter] handler error: " + string(e_cm)); }

    if (is_real(mv_power) && mv_power > 0 && is_struct(D)){
        // Detect multi-hit moves via move meta (min_hits/max_hits). If multi-hit,
        // apply first hit now and schedule remaining hits in _pending_multi_hit so
        // the engine can show per-hit dialogs between hits (Emerald style).
        var mm_local = undefined;
        try { mm_local = __battle_get_move_meta(move_id); } catch (e_mm) { mm_local = undefined; }
        var total_hits = 1;
        try {
            if (is_struct(mm_local)){
                var mh_min = (variable_struct_exists(mm_local, "min_hits") ? floor(variable_struct_get(mm_local, "min_hits")) : -1);
                var mh_max = (variable_struct_exists(mm_local, "max_hits") ? floor(variable_struct_get(mm_local, "max_hits")) : -1);
                if (is_real(mh_min) && mh_min > 0 && is_real(mh_max) && mh_max > 0){
                    if (mh_max > mh_min) total_hits = irandom_range(mh_min, mh_max);
                    else total_hits = mh_min;
                } else if (is_real(mh_min) && mh_min > 0) total_hits = mh_min;
                else if (is_real(mh_max) && mh_max > 0) total_hits = mh_max;
            }
        } catch (e_h) { total_hits = 1; }

        // Apply first hit now
        var resf = __battle_apply_move_damage(_pid, target_idx, A, D, move_id, mv_power);
        var dmgh = (is_array(resf) ? resf[0] : 0);
        try { __battle_apply_move_meta_effects(_pid, _step, A, D, move_id, dmgh, mm_local); } catch (e_meta) {}

        // Fury Cutter: if this move hit successfully, increment a per-attacker multiplier so
        // subsequent uses in the same battle become stronger. If the move missed, reset multiplier.
        try {
            if (is_real(move_id) && move_id == 210 && is_struct(A)){
                // A hit considered successful when dmgh > 0
                if (is_real(dmgh) && dmgh > 0){
                    var cur = (variable_struct_exists(A, "_fury_cutter_mul") && is_real(variable_struct_get(A, "_fury_cutter_mul"))) ? variable_struct_get(A, "_fury_cutter_mul") : 1;
                    // Double multiplier each successful hit, but cap to a reasonable value (e.g., 16x)
                    var nextm = min(cur * 2, 16);
                    variable_struct_set(A, "_fury_cutter_mul", nextm);
                    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][fury] hit: set _fury_cutter_mul=" + string(nextm));
                } else {
                    // Miss or zero damage resets multiplier
                    variable_struct_set(A, "_fury_cutter_mul", 1);
                    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][fury] miss/reset: set _fury_cutter_mul=1");
                }
            } else if (is_struct(A)){
                // Using any other move resets the Fury Cutter multiplier
                if (variable_struct_exists(A, "_fury_cutter_mul")) variable_struct_set(A, "_fury_cutter_mul", 1);
            }
        } catch (e_fc2) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][fury] multiplier update failed: " + string(e_fc2)); }

        // If multiple hits, schedule the rest into the battle slot for per-hit processing
        if (is_real(total_hits) && total_hits > 1){
            try {
                var _pm = { move_id: move_id, actor_index: actor_idx, target_index: target_idx, mv_power: mv_power, remaining: max(0, total_hits - 1), total_hits: total_hits };
                var _B = __battle_ensure_slot(_pid);
                if (is_struct(_B)) variable_struct_set(_B, "_pending_multi_hit", _pm);
            } catch (e_sched) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][multihit] scheduling failed: " + string(e_sched)); }
        }

        return string((variable_struct_exists(A,"name")?variable_struct_get(A,"name"):"The user")) + " used " + mv_name + "!";
    }

    try { __battle_apply_move_meta_effects(_pid, _step, A, D, move_id, 0, __battle_get_move_meta(move_id)); } catch (e) {}
    return string((variable_struct_exists(A,"name")?variable_struct_get(A,"name"):"The user")) + " used " + mv_name + "!";
}

// Ensure this impl is discoverable via the central registry
try {
    if (!variable_global_exists("_battle_impls") || !is_struct(variable_global_get("_battle_impls"))) variable_global_set("_battle_impls", {});
    try { variable_struct_set(variable_global_get("_battle_impls"), "__battle_perform_action_impl", __battle_perform_action_impl); } catch (e_reg) {}
} catch (e) {}

// Expose a small registration function to handle load-order: callers can invoke
// this to ensure the perform_action impl is present in the central registry.
function __battle_moves_impls_register(){
    try {
        if (!variable_global_exists("_battle_impls") || !is_struct(variable_global_get("_battle_impls"))) variable_global_set("_battle_impls", {});
        try { variable_struct_set(variable_global_get("_battle_impls"), "__battle_perform_action_impl", __battle_perform_action_impl); } catch (e_reg) {}
        // Also register the 'real' key the proxy checks for
        try { variable_struct_set(variable_global_get("_battle_impls"), "__battle_perform_action_impl_real", __battle_perform_action_impl); } catch (e_reg2) {}
    } catch (e) {}
}
