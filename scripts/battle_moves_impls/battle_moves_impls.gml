<<<<<<< HEAD
﻿// Minimal, clean move resolver placeholder
// This file intentionally contains a small, syntactically-correct placeholder implementation
// for __battle_perform_action_impl so the project can compile while the full move resolver
// is being refactored. Replace with the full implementation when ready.

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
=======
﻿

// =======================================================================
// battle_moves_impls.gml — COMPLETE BUILD (v3.0 “All Moves Usable”)
// - Based on v2.0 stable core; adds special-move coverage and battle memory.
// - Self-contained; defensive guards; schema shims; no reserved-name collisions.
// =======================================================================

/* ------------------------------
   DEBUG
------------------------------ */
function __battle__dbg(_msg) {
    if (variable_global_exists("btl_debug") && global.btl_debug) {
        show_debug_message("[BATTLE] " + string(_msg));
    }
}

/* ------------------------------
   TYPE & DAMAGE-CLASS MAP
------------------------------ */
function __battle__type_id_from_ident(_ident) {
    var s = string_lower(string(_ident));
    if (s=="normal") return 1; if (s=="fighting") return 2; if (s=="flying") return 3; if (s=="poison") return 4; if (s=="ground") return 5;
    if (s=="rock") return 6; if (s=="bug") return 7; if (s=="ghost") return 8; if (s=="steel") return 9; if (s=="fire") return 10;
    if (s=="water") return 11; if (s=="grass") return 12; if (s=="electric") return 13; if (s=="psychic") return 14; if (s=="ice") return 15;
    if (s=="dragon") return 16; if (s=="dark") return 17; if (s=="fairy") return 18;
    return -1;
}
function __battle__damage_class_id_from_ident(_ident) {
    var s = string_lower(string(_ident));
    if (s=="status") return 1; if (s=="physical") return 2; if (s=="special") return 3;
    var n = real(_ident); if (is_real(n) && n>=1 && n<=3) return n; return 0;
}

/* ------------------------------
   BASIC UTILITIES
------------------------------ */
function __battle__has_ability(_E, _ident) {
    if (!is_struct(_E)) return false;
    var a = (variable_struct_exists(_E, "_ability") ? string_lower(string(_E._ability)) : "");
    return (a == string_lower(string(_ident)));
}
function __battle__has_type_id(_E, _typeId) {
    if (!is_struct(_E)) return false;
    if (!is_undefined(__battle__mon_types_array)) {
        var arr = __battle__mon_types_array(_E);
        if (is_array(arr)) { for (var i=0;i<array_length(arr);i++) if (arr[i]==_typeId) return true; }
    }
    return false;
}
function __battle__read_hp_max(_E){ if (!is_struct(_E)) return 1; if (!is_undefined(__battle__read_hp_max)) return __battle__read_hp_max(_E); if (variable_struct_exists(_E,"hp_max")) return max(1,_E.hp_max); return 1; }
function __battle__read_hp_now(_E){ if (!is_struct(_E)) return 0; if (!is_undefined(__battle__read_hp_now)) return __battle__read_hp_now(_E); if (variable_struct_exists(_E,"hp")) return max(0,_E.hp); return 0; }
function __battle__write_hp_now(_E,_v){ if (!is_struct(_E)) return; if (!is_undefined(__battle__write_hp_now)) { __battle__write_hp_now(_E,_v); return; } if (variable_struct_exists(_E,"hp")) _E.hp=max(0,_v); }
function __battle__is_grounded(_E){ if (!is_undefined(__battle__is_grounded)) return __battle__is_grounded(_E); return true; }
function __battle_is_fainted(_E){ if (!is_struct(_E)) return false; return (__battle__read_hp_now(_E)<=0); }
function __battle__entity_side_key(_E){ if (is_struct(_E) && variable_struct_exists(_E,"_side")) return _E._side; return 0; }

/* ------------------------------
   MOVE/META SHIMS (prevents undefined)
------------------------------ */
function __battle__normalize_move_record(_mv) {
    if (!is_struct(_mv)) return _mv;
    if (!variable_struct_exists(_mv, "identifier") && variable_struct_exists(_mv, "name")) _mv.identifier = string_lower(string(_mv.name));
    if (variable_struct_exists(_mv, "identifier")) _mv.identifier = string_lower(string(_mv.identifier));
    if (!variable_struct_exists(_mv, "type_id")) {
        var s = ""; if (variable_struct_exists(_mv, "type")) s = _mv.type; else if (variable_struct_exists(_mv, "type_name")) s = _mv.type_name;
        if (string_length(string(s))>0) _mv.type_id = __battle__type_id_from_ident(s);
    }
    if (!variable_struct_exists(_mv, "damage_class_id")) {
        var d = ""; if (variable_struct_exists(_mv, "damage_class")) d = _mv.damage_class; else if (variable_struct_exists(_mv, "category")) d = _mv.category;
        _mv.damage_class_id = __battle__damage_class_id_from_ident(d);
    }
    if (!variable_struct_exists(_mv, "power") || !is_real(_mv.power)) _mv.power = 0;
    return _mv;
}
function __battle__get_move_record_safe_SHIM(_moveId) {
    var mid = _moveId; if (!is_real(mid)) { var r=real(_moveId); if (is_real(r)) mid=r; }
    var mv = undefined;
    if (!is_undefined(__battle__get_move_record_safe)) mv = __battle__get_move_record_safe(mid);
    if (!is_struct(mv) && !is_undefined(__battle_get_move_record)) mv = __battle_get_move_record(mid);
    if (!is_struct(mv)) { __battle__dbg("move record missing id="+string(mid)); return undefined; }
    return __battle__normalize_move_record(mv);
}
function __battle_get_move_meta_SHIM(_moveId) {
    var mid = _moveId; if (!is_real(mid)) { var r=real(_moveId); if (is_real(r)) mid=r; }
    var meta = {}; if (!is_undefined(__battle_get_move_meta)) meta = __battle_get_move_meta(mid);
    if (!is_struct(meta)) meta = {};
    return meta;
}

/* ------------------------------
   HAZARDS (state & application)
------------------------------ */
function __battle__get_side_struct(_B, _entity) {
    if (is_struct(_B) && variable_struct_exists(_B, "sides") && is_array(_B.sides) && is_struct(_entity)) {
        var idx = (__battle__entity_side_key(_entity) == 0 ? 0 : 1);
        return _B.sides[idx];
    }
    return undefined;
}
function __battle__ensure_side(_B, _entity) {
    var side = __battle__get_side_struct(_B, _entity); if (!is_struct(side)) return undefined;
    if (!variable_struct_exists(side, "spikes_layers")) side.spikes_layers = 0;
    if (!variable_struct_exists(side, "toxic_spikes_layers")) side.toxic_spikes_layers = 0;
    if (!variable_struct_exists(side, "stealth_rock")) side.stealth_rock = false;
    if (!variable_struct_exists(side, "sticky_web")) side.sticky_web = false;
    if (!variable_struct_exists(side, "reflect_turns")) side.reflect_turns = 0;
    if (!variable_struct_exists(side, "light_screen_turns")) side.light_screen_turns = 0;
    if (!variable_struct_exists(side, "aurora_veil_turns")) side.aurora_veil_turns = 0;
    if (!variable_struct_exists(side, "safeguard_turns")) side.safeguard_turns = 0;
    return side;
}
function __battle__apply_switchin_hazards(_pid, _idx) {
    var _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B) || !is_array(_B.actor)) return;
    var Mon = _B.actor[_idx]; if (!is_struct(Mon)) return;
    var S = __battle__get_side_struct(_B, Mon); if (!is_struct(S)) return;
    var grounded = __battle__is_grounded(Mon);

    // Toxic Spikes absorption
    if (S.toxic_spikes_layers > 0) { if (__battle__has_type_id(Mon, 4) && grounded) { S.toxic_spikes_layers = 0; } }

    // Stealth Rock
    if (S.stealth_rock) {
        var mx = __battle__read_hp_max(Mon);
        var base = max(1, floor(mx / 8));
        var types = __battle__mon_types_array(Mon);
        var mult = 1;
        if (!is_undefined(__battle_type_multiplier)) { try { mult = __battle_type_multiplier(6, types); } catch (e) { mult = 1; } }
        var dmg = max(1, floor(base * mult));
        var now = __battle__read_hp_now(Mon);
        __battle__write_hp_now(Mon, max(0, now - dmg));
    }

    // Spikes
    if (grounded && S.spikes_layers > 0) {
        var mx2 = __battle__read_hp_max(Mon);
        var spikes_div = 16;
        if (S.spikes_layers == 1) spikes_div = 8;
        else if (S.spikes_layers == 2) spikes_div = 6;
        else if (S.spikes_layers >= 3) spikes_div = 4;
        var dmg2 = max(1, floor(mx2 / spikes_div));
        var now2 = __battle__read_hp_now(Mon);
        __battle__write_hp_now(Mon, max(0, now2 - dmg2));
    }

    // Toxic Spikes status
    if (grounded && S.toxic_spikes_layers > 0) {
        var isSteel = __battle__has_type_id(Mon, 9);
        var isPoison2 = __battle__has_type_id(Mon, 4);
        if (!isSteel && !isPoison2) {
            var sid = (S.toxic_spikes_layers >= 2 ? "toxic" : "poison");
            variable_struct_set(Mon, "_status", sid);
        }
    }

    // Sticky Web
    if (grounded && S.sticky_web) {
        if (variable_struct_exists(Mon, "_speed") && is_real(Mon._speed)) Mon._speed = max(1, floor(Mon._speed * 2/3));
        else if (variable_struct_exists(Mon, "speed") && is_real(Mon.speed)) Mon.speed = max(1, floor(Mon.speed * 2/3));
    }
}
function __battle__clear_hazards_on_side(_B, _entity, _what) {
    var S = __battle__ensure_side(_B, _entity); if (!is_struct(S)) return false;
    if (_what == "all" || _what == "entry" || is_undefined(_what)) { S.spikes_layers = 0; S.toxic_spikes_layers = 0; S.stealth_rock = false; S.sticky_web = false; }
    if (_what == "spikes") S.spikes_layers = 0;
    if (_what == "tspikes") S.toxic_spikes_layers = 0;
    if (_what == "rock") S.stealth_rock = false;
    if (_what == "web") S.sticky_web = false;
    return true;
}
function __battle__apply_hazards_from_meta(_B, _A, _mm) {
    if (!is_struct(_mm)) return false;
    if (!is_struct(_B) || !variable_struct_exists(_B, "sides") || !is_array(_B.sides)) return false;
    var oppIdx = (__battle__entity_side_key(_A) == 0 ? 1 : 0);
    var opp = _B.sides[oppIdx]; if (!is_struct(opp)) return false;
    if (!variable_struct_exists(opp, "spikes_layers")) opp.spikes_layers = 0;
    if (!variable_struct_exists(opp, "toxic_spikes_layers")) opp.toxic_spikes_layers = 0;
    if (!variable_struct_exists(opp, "stealth_rock")) opp.stealth_rock = false;
    if (!variable_struct_exists(opp, "sticky_web")) opp.sticky_web = false;
    var any=false;
    if (variable_struct_exists(_mm, "set_spikes") && _mm.set_spikes) { opp.spikes_layers = clamp(opp.spikes_layers + 1, 0, 3); any=true; }
    if (variable_struct_exists(_mm, "set_toxic_spikes") && _mm.set_toxic_spikes) { opp.toxic_spikes_layers = clamp(opp.toxic_spikes_layers + 1, 0, 2); any=true; }
    if (variable_struct_exists(_mm, "set_stealth_rock") && _mm.set_stealth_rock) { opp.stealth_rock = true; any=true; }
    if (variable_struct_exists(_mm, "set_sticky_web") && _mm.set_sticky_web) { opp.sticky_web = true; any=true; }
    return any;
}
function __battle__apply_rapid_spin_effects(_B, _A, _mm) {
    __battle__clear_hazards_on_side(_B, _A, "entry");
    if (is_struct(_A) && variable_struct_exists(_A, "_seeded_by")) variable_struct_set(_A, "_seeded_by", undefined);
    if (is_struct(_mm) && variable_struct_exists(_mm, "spin_speed_up") && _mm.spin_speed_up) {
        if (variable_struct_exists(_A, "_speed") && is_real(_A._speed)) _A._speed = floor(_A._speed * 1.5);
        else if (variable_struct_exists(_A, "speed") && is_real(_A.speed)) _A.speed = floor(_A.speed * 1.5);
    }
}
function __battle__apply_defog_effects(_B, _A, _D, _mm) {
    __battle__clear_hazards_on_side(_B, _D, "entry");
    var Sd = __battle__get_side_struct(_B, _D);
    if (is_struct(Sd)) { Sd.reflect_turns=0; Sd.light_screen_turns=0; Sd.aurora_veil_turns=0; Sd.safeguard_turns=0; }
    if (is_struct(_mm) && variable_struct_exists(_mm, "defog_clear_both") && _mm.defog_clear_both) {
        var Sa = __battle__get_side_struct(_B, _A);
        if (is_struct(Sa)) { Sa.reflect_turns=0; Sa.light_screen_turns=0; Sa.aurora_veil_turns=0; Sa.safeguard_turns=0; }
    }
}
function __battle__apply_court_change(_B) {
    if (!is_struct(_B) || !variable_struct_exists(_B, "sides") || !is_array(_B.sides) || array_length(_B.sides)<2) return false;
    var L=_B.sides[0], R=_B.sides[1]; if (!is_struct(L)||!is_struct(R)) return false;
    var fields = ["spikes_layers","toxic_spikes_layers","stealth_rock","sticky_web","reflect_turns","light_screen_turns","aurora_veil_turns","safeguard_turns"];
    for (var i=0;i<array_length(fields);i++) { var k=fields[i]; var tmp=(variable_struct_exists(L,k)?variable_struct_get(L,k):undefined); var valR=(variable_struct_exists(R,k)?variable_struct_get(R,k):undefined); variable_struct_set(L,k,valR); variable_struct_set(R,k,tmp); }
    return true;
}

/* ------------------------------
   STATUS CURES, HEAL BLOCK, REST/SLEEP TALK
------------------------------ */
function __battle__cure_status_major(_E) {
    if (!is_struct(_E)) return false;
    if (variable_struct_exists(_E, "_status") && string_length(string(_E._status)) > 0) {
        variable_struct_set(_E, "_status", "");
        if (variable_struct_exists(_E, "_sleep_turns")) _E._sleep_turns = 0;
        if (variable_struct_exists(_E, "_toxic_counter")) _E._toxic_counter = 0;
        return true;
    }
    return false;
}
function __battle__apply_team_cure(_B, _A) {
    if (!is_struct(_B) || !is_struct(_A) || !is_array(_B.actor)) return 0;
    var side = __battle__entity_side_key(_A); var count=0;
    for (var i=0;i<array_length(_B.actor);i++){ var E=_B.actor[i]; if (!is_struct(E)) continue; if (__battle__entity_side_key(E)==side) if(__battle__cure_status_major(E)) count++; }
    return count;
}
function __battle__apply_heal_block(_D, _turns) { if (!is_struct(_D)) return false; variable_struct_set(_D, "_heal_block_turns", max(1,_turns)); return true; }
function __battle__is_heal_blocked(_E) { return (is_struct(_E) && variable_struct_exists(_E,"_heal_block_turns") && _E._heal_block_turns>0); }
function __battle__apply_rest(_B, _A) {
    if (!is_struct(_A)) return "fail";
    if (__battle__uproar_active(_B)) return "uproar-block";
    if (__battle__is_heal_blocked(_A)) return "heal-block";
    variable_struct_set(_A, "_status", "sleep");
    variable_struct_set(_A, "_sleep_turns", 2);
    var mx = __battle__read_hp_max(_A);
    __battle__write_hp_now(_A, mx);
    return "ok";
}
function __battle__pick_sleep_talk_move(_A, _mv_sleep_talk_id) {
    if (!is_struct(_A) || !is_array(_A.moves)) return -1;
    var cand=[];
    for (var i=0;i<array_length(_A.moves);i++){
        var mid=_A.moves[i]; if (!is_real(mid) || mid<=0) continue; if (mid==_mv_sleep_talk_id) continue;
        var mvrec=__battle__get_move_record_safe_SHIM(mid);
        var idstr=(is_struct(mvrec)&&variable_struct_exists(mvrec,"identifier")?string_lower(string(mvrec.identifier)):"");
        if (idstr=="rest") continue;
        array_push(cand, mid);
    }
    if (array_length(cand)<=0) return -1;
    return cand[irandom(array_length(cand)-1)];
}

/* ------------------------------
   STATUS TYPE IMMUNITIES & APPLY
------------------------------ */
function __battle__status_type_immune(_E, _status_ident) {
    if (!is_struct(_E)) return false;
    var sid = string_lower(string(_status_ident));
    if (sid=="burn") return __battle__has_type_id(_E,10);
    if (sid=="paralysis" || sid=="paralyzed" || sid=="para") return __battle__has_type_id(_E,13);
    if (sid=="freeze" || sid=="frozen") return __battle__has_type_id(_E,15);
    if (sid=="poison" || sid=="toxic" || sid=="badly-poisoned") return (__battle__has_type_id(_E,4)||__battle__has_type_id(_E,9));
    return false;
}
function __battle__apply_status_if_any(_pid, _A, _D, _mid, _mm, _rng_roll) {
    if (!is_struct(_mm)) return false;
    var _B = __battle_ensure_slot(_pid); if (!is_struct(_B)) return false;

    // Magic Coat reflection for pure-status effects
    if (is_struct(_D) && variable_struct_exists(_D,"_magic_coat_turn") && _D._magic_coat_turn) {
        // reflect back to source (if status and not self-target)
        var power0 = !(variable_struct_exists(_mm,"power") && is_real(_mm.power) && _mm.power>0);
        var isStatusClass = (variable_struct_exists(_mm,"damage_class_id") ? _mm.damage_class_id : (variable_struct_exists(_mm,"damage_class")?__battle__damage_class_id_from_ident(_mm.damage_class):0)) == 1;
        if (power0 || isStatusClass) {
            var tmp = _A; _A = _D; _D = tmp; // swap
        }
    }

    if (__battle__side_has_safeguard(_B, _D)) return false;
    var _p=0;
    if (variable_struct_exists(_mm,"status_chance")&&is_real(_mm.status_chance)) _p=_mm.status_chance;
    else if (variable_struct_exists(_mm,"ailment_chance")&&is_real(_mm.ailment_chance)) _p=_mm.ailment_chance;
    else if (variable_struct_exists(_mm,"effect_chance")&&is_real(_mm.effect_chance)) _p=_mm.effect_chance;
    var _sid=(variable_struct_exists(_mm,"status_ident")?string(_mm.status_ident):"");
    var _sidL=string_lower(string(_sid)); if (string_length(string_trim(_sid))<=0) return false;
    if (_sidL=="sleep" && __battle__uproar_active(_B)) return false;
    if (__battle__status_type_immune(_D,_sidL)) return false;
    var _roll=is_real(_rng_roll)?_rng_roll:irandom(99); if (_p>0 && _roll>=_p) return false;
    if (is_struct(_D)) { variable_struct_set(_D,"_status",_sidL); if (_sidL=="sleep") variable_struct_set(_D,"_sleep_turns",2); if (_sidL=="toxic") variable_struct_set(_D,"_toxic_counter",1); return true; }
    return false;
}

/* ------------------------------
   HEALING WRAPPERS
------------------------------ */
function __battle__attempt_heal_hp(_Target, _amount) {
    if (!is_struct(_Target) || _amount<=0) return 0;
    if (__battle__is_heal_blocked(_Target)) return 0;
    var mx=__battle__read_hp_max(_Target), now=__battle__read_hp_now(_Target);
    var healed=min(mx-now,_amount); if (healed>0) __battle__write_hp_now(_Target, now+healed);
    return max(0,healed);
}
function __battle__shell_bell_heal_if_any(_A, _dmgTotal) {
    if (!is_struct(_A) || _dmgTotal<=0) return;
    var has=false; if (variable_struct_exists(_A,"_item")) has=(string_lower(string(_A._item))=="shell-bell");
    if (!has && variable_struct_exists(_A,"_has_shell_bell")) has=_A._has_shell_bell;
    if (!has) return; if (__battle__is_heal_blocked(_A)) return;
    var heal=max(1,floor(_dmgTotal/8)); __battle__attempt_heal_hp(_A, heal);
}

/* ------------------------------
   STAGES, CRIT, SPEED
------------------------------ */
function __battle__get_stage(_E, _key) {
    if (!is_struct(_E)) return 0;
    var k="_stg_"+string_lower(string(_key));
    if (!variable_struct_exists(_E,k)) return 0;
    var v=variable_struct_get(_E,k); if (!is_real(v)) return 0;
    return clamp(floor(v),-6,6);
}
function __battle__set_stage(_E,_key,_val){ if(!is_struct(_E))return 0; var k="_stg_"+string_lower(string(_key)); var v=clamp(floor(_val),-6,6); variable_struct_set(_E,k,v); return v; }
function __battle__mod_stage(_E,_key,_delta){ if(!is_struct(_E))return 0; var now=__battle__get_stage(_E,_key); return __battle__set_stage(_E,_key,now+_delta); }
function __battle__stage_mult(_stage){ var s=clamp(floor(_stage),-6,6); if (s>=0) return (2+s)/2; return 2/(2-s); }
function __battle__get_speed(_E) {
    if (is_struct(_E)) {
        if (variable_struct_exists(_E, "_speed") && is_real(_E._speed)) return _E._speed;
        if (variable_struct_exists(_E, "speed") && is_real(_E.speed)) return _E.speed;
        if (variable_struct_exists(_E, "stats") && is_struct(_E.stats) && variable_struct_exists(_E.stats, "spe") && is_real(_E.stats.spe)) return _E.stats.spe;
    }
    return 1;
}
function __battle__effective_speed(_E) {
    var base = __battle__get_speed(_E);
    var mult = __battle__stage_mult(__battle__get_stage(_E,"spe"));
    var eff = floor(base * mult);
    if (is_struct(_E) && variable_struct_exists(_E,"_status")) {
        var sid=string_lower(string(_E._status));
        if (sid=="paralysis"||sid=="paralyzed"||sid=="para") eff=floor(eff*0.5);
    }
    if (eff<1) eff=1; return eff;
}
function battle_speed_compare(_pid,_idxA,_idxB){
    var _B=__battle_ensure_slot(_pid); if(!is_struct(_B)||!is_array(_B.actor))return 0; if(_idxA==_idxB) return 0;
    var A=_B.actor[_idxA], B=_B.actor[_idxB]; var sa=__battle__effective_speed(A), sb=__battle__effective_speed(B);
    var trick=(variable_struct_exists(_B,"trick_room_turns")&&_B.trick_room_turns>0);
    if (!trick){ if(sa>sb)return -1; if(sa<sb)return 1; return 0; } else { if(sa<sb)return -1; if(sa>sb)return 1; return 0; }
}
function __battle__adjust_damage_by_stages_and_burn(_A,_D,_dmgClassId,_isCrit,_dmg){
    var dmg=max(0,_dmg); if (dmg<=0) return 0;
    var atkKey=(_dmgClassId==2?"atk":(_dmgClassId==3?"spa":"")), defKey=(_dmgClassId==2?"def":(_dmgClassId==3?"spd":""));
    if (string_length(atkKey)>0 && string_length(defKey)>0) {
        var aStg=__battle__get_stage(_A,atkKey), dStg=__battle__get_stage(_D,defKey);
        if (_isCrit){ if (aStg<0) aStg=0; if (dStg>0) dStg=0; }
        var aMul=__battle__stage_mult(aStg), dMul=__battle__stage_mult(dStg);
        dmg=floor(dmg*(aMul/dMul));
        if (_dmgClassId==2 && is_struct(_A) && variable_struct_exists(_A,"_status") && string_lower(string(_A._status))=="burn") dmg=floor(dmg*0.5);
    }
    return max(0,dmg);
}
function __battle__get_crit_stage_base(_A) {
    if (!is_struct(_A)) return 0; var s=0;
    if (variable_struct_exists(_A,"_crit_stage")) s=max(s, clamp(floor(_A._crit_stage),0,3));
    if (__battle__has_ability(_A,"super-luck")) s+=1;
    if (variable_struct_exists(_A,"_item")) { var it=string_lower(string(_A._item)); if (it=="scope-lens"||it=="razor-claw") s+=1; }
    return clamp(s,0,3);
}
function __battle__crit_stage_from_move(_mv,_mm){ var add=0; if (is_struct(_mm)&&variable_struct_exists(_mm,"high_crit")&&_mm.high_crit) add+=1; return add; }
function __battle__roll_crit_exact(_A,_D,_mv,_mm){
    var stg=__battle__get_crit_stage_base(_A)+__battle__crit_stage_from_move(_mv,_mm); stg=clamp(stg,0,3);
    if (stg>=3) return true; var num=1, den=(stg==2?2:(stg==1?8:24));
    var roll=irandom(den-1); return (roll<num);
}

/* ------------------------------
   ABSORPTION & REDIRECTION ABILITIES
------------------------------ */
function __battle__dry_skin_fire_multiplier(_D){ if(!is_struct(_D))return 1; if(__battle__has_ability(_D,"dry-skin")) return 5/4; return 1; }
function __battle__apply_absorb_ability_effects(_A,_D,_typeId){
    if (!is_struct(_D)) return false;
    if (__battle__has_ability(_D,"lightning-rod") && _typeId==13) { __battle__mod_stage(_D,"spa",+1); return true; }
    if (__battle__has_ability(_D,"storm-drain") && _typeId==11) { __battle__mod_stage(_D,"spa",+1); return true; }
    if (__battle__has_ability(_D,"sap-sipper") && _typeId==12) { __battle__mod_stage(_D,"atk",+1); return true; }
    if (__battle__has_ability(_D,"dry-skin") && _typeId==11) { var mx=__battle__read_hp_max(_D), now=__battle__read_hp_now(_D); __battle__write_hp_now(_D, min(mx, now+max(1,floor(mx/4)))); return true; }
    if (__battle__has_ability(_D,"volt-absorb") && _typeId==13) { var mx2=__battle__read_hp_max(_D), now2=__battle__read_hp_now(_D); __battle__write_hp_now(_D, min(mx2, now2+max(1,floor(mx2/4)))); return true; }
    if (__battle__has_ability(_D,"water-absorb") && _typeId==11) { var mx3=__battle__read_hp_max(_D), now3=__battle__read_hp_now(_D); __battle__write_hp_now(_D, min(mx3, now3+max(1,floor(mx3/4)))); return true; }
    return false;
}
function __battle__absorber_for_type_on_side(_B,_actorIndex,_typeId){
    if (!is_struct(_B)||!is_array(_B.actor)) return -1;
    var oppSide=(__battle__entity_side_key(_B.actor[_actorIndex])==0?1:0);
    var need=""; if (_typeId==13) need="lightning-rod"; else if (_typeId==11) need="storm-drain"; else if (_typeId==12) need="sap-sipper"; else return -1;
    for (var i=0;i<array_length(_B.actor);i++){ var P=_B.actor[i]; if (!is_struct(P)) continue; if (__battle__entity_side_key(P)!=oppSide) continue; if (__battle__has_ability(P,need)) return i; }
    return -1;
}
function __battle__maybe_redirect_targets(_B,_actorIndex,_targets,_typeId){
    if (!is_array(_targets)||array_length(_targets)<=0) return _targets; if (array_length(_targets)>1) return _targets;
    var redir=__battle__absorber_for_type_on_side(_B,_actorIndex,_typeId); if (redir>=0) return [redir]; return _targets;
}

/* ------------------------------
   KO BOOSTS & REACTIONS
------------------------------ */
function __battle__on_knockout_boost(_A){
    if (!is_struct(_A)) return;
    if (__battle__has_ability(_A,"moxie")) { __battle__mod_stage(_A,"atk",+1); return; }
    if (__battle__has_ability(_A,"grim-neigh")) { __battle__mod_stage(_A,"spa",+1); return; }
    if (__battle__has_ability(_A,"beast-boost")) {
        var keys=["atk","def","spa","spd","spe"], best="atk", bestVal=-1;
        for (var i=0;i<array_length(keys);i++){ var k=keys[i]; var base=0; if (variable_struct_exists(_A,k)&&is_real(_A[?k])) base=_A[?k]; else if (variable_struct_exists(_A,"stats")&&is_struct(_A.stats)&&variable_struct_exists(_A.stats,k)&&is_real(_A.stats[?k])) base=_A.stats[?k]; if (base>bestVal){ bestVal=base; best=k; } }
        __battle__mod_stage(_A,best,+1); return;
    }
}
function __battle__on_hit_type_reactions(_Def,_typeId,_srcIndex){
    if (!is_struct(_Def)) return;
    if (__battle__has_ability(_Def,"rattled") && (_typeId==7 || _typeId==8 || _typeId==17)) __battle__mod_stage(_Def,"spe",+1);
    if (__battle__has_ability(_Def,"justified") && _typeId==17) __battle__mod_stage(_Def,"atk",+1);
}

/* ------------------------------
   SWITCH-IN/OUT & WEATHER ABILITIES
------------------------------ */
function __battle__clear_volatiles_on_switch_in(_E){
    if (!is_struct(_E)) return;
    var fields=["_flinch","_encore_turns","_taunt_turns","_torment_turns","_disable_turns","_disable_move","_protect_turns","_charging","_semi_invuln","_sub_hp","_seeded_by","_uproar_turns","_throat_chop_turns","_magic_coat_turn","_snatch_turn","_destiny_bond_turn"];
    for (var i=0;i<array_length(fields);i++){ var k=fields[i]; if (variable_struct_exists(_E,k)){ var v=variable_struct_get(_E,k); if (is_real(v)) variable_struct_set(_E,k,0); else variable_struct_set(_E,k,undefined);}}
    if (variable_struct_exists(_E,"_last_move_id")) _E._last_move_id=-1;
    if (variable_struct_exists(_E,"_last_move_failed")) _E._last_move_failed=false;
    if (variable_struct_exists(_E,"_choice_lock_move_id")) _E._choice_lock_move_id=-1;
}
function __battle__apply_stat_drop_with_reactions(_Source,_Target,_key,_delta,_no_reflect){
    if (!is_struct(_Target)) return false; var keyL=string_lower(string(_key));
    if (!(_no_reflect) && __battle__has_ability(_Target,"mirror-armor") && is_struct(_Source)) { __battle__apply_stat_drop_with_reactions(_Target,_Source,keyL,_delta,true); return false; }
    if (__battle__has_ability(_Target,"clear-body") || __battle__has_ability(_Target,"white-smoke") || __battle__has_ability(_Target,"full-metal-body")) return false;
    if (keyL=="atk" && __battle__has_ability(_Target,"hyper-cutter")) return false;
    var before=__battle__get_stage(_Target,keyL); var after=__battle__mod_stage(_Target,keyL,_delta); var lowered=(after<before);
    if (lowered){ if (__battle__has_ability(_Target,"defiant")) __battle__mod_stage(_Target,"atk",+2); if (__battle__has_ability(_Target,"competitive")) __battle__mod_stage(_Target,"spa",+2); }
    return lowered;
}
function __battle__apply_intimidate_on_switch_in(_B,_idx){
    if (!is_struct(_B)||!is_array(_B.actor)) return; var E=_B.actor[_idx]; if(!is_struct(E)||!__battle__has_ability(E,"intimidate")) return;
    for (var i=0;i<array_length(_B.actor);i++){ if(i==_idx) continue; var T=_B.actor[i]; if(!is_struct(T)) continue; if (__battle__entity_side_key(T)!=(__battle__entity_side_key(E)==0?1:0)) continue; __battle__apply_stat_drop_with_reactions(E,T,"atk",-1,false); }
}
function __battle__apply_weather_ability_on_switch_in(_B,_idx){
    if (!is_struct(_B)||!is_array(_B.actor)) return; var E=_B.actor[_idx]; if(!is_struct(E)) return;
    var abil=(variable_struct_exists(E,"_ability")?string_lower(string(E._ability)):""); if (string_length(abil)<=0) return;
    var ident=""; if(abil=="drought") ident="sun"; else if(abil=="drizzle") ident="rain"; else if(abil=="sand-stream") ident="sandstorm"; else if(abil=="snow-warning") ident="snow";
    if (string_length(ident)<=0) return; if (!variable_struct_exists(_B,"weather")||!is_struct(_B.weather)) _B.weather={ident:ident,turns_left:5}; else { _B.weather.ident=ident; _B.weather.turns_left=5; }
}
function battle_on_switch_in(_pid,_actor_index){
    __battle__apply_switchin_hazards(_pid,_actor_index);
    var _B=__battle_ensure_slot(_pid); if(!is_struct(_B)||!is_array(_B.actor)) return; var Mon=_B.actor[_actor_index]; if(!is_struct(Mon)) return;
    __battle__clear_volatiles_on_switch_in(Mon); __battle__apply_intimidate_on_switch_in(_B,_actor_index); __battle__apply_weather_ability_on_switch_in(_B,_actor_index);
    __battle__clear_damage_memory(Mon);
}
function battle_on_switch_out(_pid,_actor_index){
    var _B=__battle_ensure_slot(_pid); if(!is_struct(_B)||!is_array(_B.actor)) return; var Mon=_B.actor[_actor_index]; if(!is_struct(Mon)) return;
    if (variable_struct_exists(Mon,"_choice_lock_move_id")) Mon._choice_lock_move_id=-1;
    var fields=["_encore_turns","_taunt_turns","_torment_turns","_disable_turns","_disable_move","_seeded_by","_uproar_turns","_throat_chop_turns","_charging","_semi_invuln","_magic_coat_turn","_snatch_turn","_destiny_bond_turn","_perish_turns"];
    for (var i=0;i<array_length(fields);i++){ var k=fields[i]; if (variable_struct_exists(Mon,k)){ var v=variable_struct_get(Mon,k); if (is_real(v)) variable_struct_set(Mon,k,0); else variable_struct_set(Mon,k,undefined);}}
}

/* ------------------------------
   END-OF-TURN & DAMAGE MEMORY / PERISH
------------------------------ */
function __battle__clear_damage_memory(_E){ if(!is_struct(_E))return; variable_struct_set(_E,"_took_damage_this_turn",false); variable_struct_set(_E,"_last_damage_amount",0); variable_struct_set(_E,"_last_damage_class",0); variable_struct_set(_E,"_last_damage_source_index",-1); }
function __battle__record_damage_from(_E, _amount, _classId, _source_index) {
    if (!is_struct(_E)) return;
    var amt = max(0, _amount);
    if (amt <= 0) return;
    variable_struct_set(_E, "_took_damage_this_turn", true);
    var prev = (variable_struct_exists(_E, "_last_damage_amount") ? max(0, _E._last_damage_amount) : 0);
    variable_struct_set(_E, "_last_damage_amount", prev + amt);
    if (is_real(_classId)) variable_struct_set(_E, "_last_damage_class", _classId);
    if (is_real(_source_index)) variable_struct_set(_E, "_last_damage_source_index", _source_index);
}
function battle_end_of_turn_update(_pid){
    var _B=__battle_ensure_slot(_pid); if(!is_struct(_B)) return;
    if (variable_struct_exists(_B,"actor")&&is_array(_B.actor)){
        var acts=_B.actor;
        for (var i=0;i<array_length(acts);i++){
            var E=acts[i]; if(!is_struct(E)) continue;
            if (variable_struct_exists(E,"_status") && string_lower(string(E._status))=="sleep"){
                var t=(variable_struct_exists(E,"_sleep_turns")?max(0,E._sleep_turns):0);
                if (t>0){ E._sleep_turns=t-1; if (E._sleep_turns<=0) variable_struct_set(E,"_status",""); }
            }
            if (variable_struct_exists(E,"_heal_block_turns") && E._heal_block_turns>0) E._heal_block_turns -= 1;
            if (variable_struct_exists(E,"_endure_this_turn") && E._endure_this_turn) E._endure_this_turn=false;
            // Perish Song
            if (variable_struct_exists(E,"_perish_turns") && E._perish_turns>0) {
                E._perish_turns -= 1;
                if (E._perish_turns<=0) { __battle__write_hp_now(E, 0); }
            }
            __battle__clear_damage_memory(E);
            // Clear one-turn flags
            if (variable_struct_exists(E,"_magic_coat_turn")) E._magic_coat_turn=false;
            if (variable_struct_exists(E,"_snatch_turn")) E._snatch_turn=false;
            if (variable_struct_exists(E,"_destiny_bond_turn")) E._destiny_bond_turn=false;
        }
    }
}

/* ------------------------------
   ENDURE & OHKO STRICTNESS
------------------------------ */
function __battle__apply_endure(_A){ if(!is_struct(_A)) return false; variable_struct_set(_A,"_endure_this_turn",true); return true; }
function __battle__tweak_endure_damage(_D,_incomingDamage){ if(!is_struct(_D)) return _incomingDamage; if(!(variable_struct_exists(_D,"_endure_this_turn")&&_D._endure_this_turn)) return _incomingDamage; var hpNow=__battle__read_hp_now(_D); var dmg=max(0,_incomingDamage); if(dmg>=hpNow) return max(0,hpNow-1); return dmg; }
function __battle__ohko_damage_value(_D){ if(!is_struct(_D)) return 99999; var mx=__battle__read_hp_max(_D); return max(1, mx*20); }
function __battle__ohko_allowed_vs_target(_A,_D,_mvIdent){
    if (!is_struct(_A)||!is_struct(_D)) return false;
    if (__battle__has_ability(_D,"sturdy")) return false;
    var idL=string_lower(string(_mvIdent));
    if (idL=="sheer-cold" && __battle__has_type_id(_D,15)) return false; // Ice
    var lvA=(variable_struct_exists(_A,"level")&&is_real(_A.level)?_A.level:100);
    var lvD=(variable_struct_exists(_D,"level")&&is_real(_D.level)?_D.level:100);
    if (lvD>lvA) return false;
    return true;
}
function __battle__ohko_hits_roll(_A,_D,_mvIdent){
    if (__battle__has_ability(_A,"no-guard") || __battle__has_ability(_D,"no-guard")) return true;
    var lvA=(variable_struct_exists(_A,"level")&&is_real(_A.level)?_A.level:100);
    var lvD=(variable_struct_exists(_D,"level")&&is_real(_D.level)?_D.level:100);
    var acc=clamp(30+(lvA-lvD),1,100); var roll=irandom(99); return (roll<acc);
}

/* ------------------------------
   METAL BURST TARGET HELPER
------------------------------ */
function __battle__pick_metal_burst_target(_B,_Aindex,_fallbackIndex){
    if (!is_struct(_B)||!is_array(_B.actor)) return _fallbackIndex;
    var fb=_fallbackIndex; if (is_real(fb)){ var FBm=_B.actor[fb]; if (is_struct(FBm)&&__battle__entity_side_key(FBm)!=__battle__entity_side_key(_B.actor[_Aindex])) return fb; }
    for (var i=0;i<array_length(_B.actor);i++){ if(i==_Aindex) continue; var M=_B.actor[i]; if(!is_struct(M)) continue; if (__battle__entity_side_key(M)!=__battle__entity_side_key(_B.actor[_Aindex])) return i; }
    return _fallbackIndex;
}

/* ------------------------------
   SPECIAL MOVE SUPPORT (Copycat, Mirror Move, Metronome*, Assist*, Sketch, Transform,
                         Encore/Taunt/Torment/Disable/Imprison, Trick Room,
                         Perish Song, Destiny Bond, Magic Coat, Future Sight, Roar/Whirlwind)
------------------------------ */
function __battle__last_used_move_global(_B){
    if (!is_struct(_B)) return -1;
    if (!variable_struct_exists(_B,"_move_history") || !is_array(_B._move_history)) _B._move_history = [];
    // Return most recent legal move id
    for (var i=array_length(_B._move_history)-1; i>=0; i--) {
        var rec = _B._move_history[i];
        if (is_array(rec) && array_length(rec)>=2) {
            var mid = rec[1];
            var mv = __battle__get_move_record_safe_SHIM(mid);
            var idstr = (is_struct(mv)&&variable_struct_exists(mv,"identifier")?string_lower(string(mv.identifier)):"");
            if (idstr!="copycat" && idstr!="assist" && idstr!="metronome" && idstr!="mirror-move" && idstr!="sketch" && idstr!="struggle") {
                return mid;
            }
        }
    }
    return -1;
}
function __battle__record_move_history(_B, _actorIndex, _moveId, _succeeded){
    if (!is_struct(_B)) return;
    if (!variable_struct_exists(_B,"_move_history") || !is_array(_B._move_history)) _B._move_history = [];
    if (_succeeded) array_push(_B._move_history, [_actorIndex, _moveId]);
}
function __battle__mirror_move_pick(_Target){
    if (!is_struct(_Target)) return -1;
    var last = (variable_struct_exists(_Target,"_last_move_id_success")?_Target._last_move_id_success:-1);
    return last;
}
function __battle__random_legal_move_id(){
    // Best-effort: try a wide range and pick first valid
    var tries = 200;
    for (var i=0;i<tries;i++){
        var mid = irandom_range(1, 900); // adjust if your DB bigger
        var mv = __battle__get_move_record_safe_SHIM(mid);
        if (is_struct(mv)) {
            var idstr=(variable_struct_exists(mv,"identifier")?string_lower(string(mv.identifier)):"");
            if (idstr!="copycat" && idstr!="assist" && idstr!="metronome" && idstr!="mirror-move" && idstr!="sketch" && idstr!="struggle") {
                return mid;
            }
        }
    }
    return -1;
}
function __battle__assist_pick_from_party(_B, _A){
    if (!is_struct(_B)||!is_struct(_A)||!is_array(_B.actor)) return -1;
    var side = __battle__entity_side_key(_A);
    var pool = [];
    for (var i=0;i<array_length(_B.actor);i++){
        var E=_B.actor[i]; if (!is_struct(E)) continue; if (__battle__entity_side_key(E)!=side) continue; if (E===_A) continue;
        if (is_array(E.moves)){
            for (var j=0;j<array_length(E.moves);j++){
                var mid=E.moves[j]; if (!is_real(mid)) continue;
                var mv=__battle__get_move_record_safe_SHIM(mid); if (!is_struct(mv)) continue;
                var idstr=(variable_struct_exists(mv,"identifier")?string_lower(string(mv.identifier)):"");
                if (idstr!="copycat" && idstr!="assist" && idstr!="metronome" && idstr!="mirror-move" && idstr!="sketch" && idstr!="struggle") array_push(pool, mid);
            }
        }
    }
    if (array_length(pool)<=0) return -1;
    return pool[irandom(array_length(pool)-1)];
}
function __battle__apply_transform_simple(_A, _Target){
    if (!is_struct(_A) || !is_struct(_Target)) return false;
    variable_struct_set(_A,"_transformed_from", _Target);
    variable_struct_set(_A,"_transformed", true);
    // Copy types if helper exists
    if (!is_undefined(__battle__copy_types_from_to)) __battle__copy_types_from_to(_Target, _A);
    // Copy stages (not HP)
    var keys=["atk","def","spa","spd","spe"];
    for (var i=0;i<array_length(keys);i++){ var k=keys[i]; __battle__set_stage(_A,k,__battle__get_stage(_Target,k)); }
    // Copy moves into a volatile list (does not overwrite permanent moves)
    if (is_array(_Target.moves)) variable_struct_set(_A,"_transformed_moves", array_create(array_length(_Target.moves), -1));
    if (is_array(_Target.moves)) for (var j=0;j<array_length(_Target.moves);j++) _A._transformed_moves[j]=_Target.moves[j];
    return true;
}

/* ------------------------------
   EXECUTOR (full, with special moves)
------------------------------ */
function __battle_perform_action_impl(_pid,_step){
    var _B=__battle_ensure_slot(_pid); if(!is_struct(_B)) return "no-battle-slot";

    var _actorIndex=(variable_struct_exists(_step,"actor_index")?variable_struct_get(_step,"actor_index"):0);
    var _targetIndex=(variable_struct_exists(_step,"target_index")?variable_struct_get(_step,"target_index"):1);
    var _A=undefined, _D=undefined; try { if (variable_struct_exists(_B,"actor")&&is_array(_B.actor)) { var _acts=_B.actor; _A=_acts[_actorIndex]; _D=_acts[_targetIndex]; } } catch (e) {}
    if (!is_struct(_A)) return "invalid-actors";

    // Encore enforcement
    if (variable_struct_exists(_A,"_encore_turns") && _A._encore_turns>0 && variable_struct_exists(_A,"_encore_move_id")) {
        variable_struct_set(_step,"move_id", _A._encore_move_id);
    }
    // Taunt enforcement (prevents status moves)
    var taunted = (variable_struct_exists(_A,"_taunt_turns") && _A._taunt_turns>0);

    // Sleep gate
    if (variable_struct_exists(_A,"_status") && string_lower(string(_A._status))=="sleep"){
        var mvIdChk=(variable_struct_exists(_step,"move_id")?_step.move_id:-1);
        var mvRecChk=__battle__get_move_record_safe_SHIM(mvIdChk);
        var idchk=(is_struct(mvRecChk)&&variable_struct_exists(mvRecChk,"identifier")?string_lower(string(mvRecChk.identifier)):"");
        if (idchk!="sleep-talk") return "asleep";
    }

    var _moveId=(variable_struct_exists(_step,"move_id")?variable_struct_get(_step,"move_id"):-1);
    var _mm=__battle_get_move_meta_SHIM(_moveId);
    var _mv=__battle__get_move_record_safe_SHIM(_moveId);
    if (!is_struct(_mv)) { variable_struct_set(_A,"_last_move_failed",true); return "no-move"; }
    var idstr=(variable_struct_exists(_mv,"identifier")?string_lower(string(_mv.identifier)):"");

    var _dmgClass=(variable_struct_exists(_mv,"damage_class_id")?_mv.damage_class_id:0);
    var _typeId=(variable_struct_exists(_mv,"type_id")?_mv.type_id:-1);
    var _power=(variable_struct_exists(_mv,"power")&&is_real(_mv.power)?max(0,_mv.power):0);

    // Disable/Torment checks
    if (variable_struct_exists(_A,"_disable_turns") && _A._disable_turns>0 && variable_struct_exists(_A,"_disable_move") && _A._disable_move==_moveId) { variable_struct_set(_A,"_last_move_failed",true); return "disabled"; }
    if (variable_struct_exists(_A,"_torment_turns") && _A._torment_turns>0 && variable_struct_exists(_A,"_last_move_id") && _A._last_move_id==_moveId) { variable_struct_set(_A,"_last_move_failed",true); return "tormented"; }
    if (taunted && _dmgClass==1) { variable_struct_set(_A,"_last_move_failed",true); return "taunted"; }

    // Crit hook optional
    if (!is_undefined(__battle__set_crit_roll_fn_hook)) { __battle__set_crit_roll_fn_hook(function(_AA,_DD,_m,_meta){ return __battle__roll_crit_exact(_AA,_DD,_m,_meta); }); }

    // Field setters & hazards
    __battle__apply_hazards_from_meta(_B,_A,_mm);

    // ===== Special moves (pre) =====
    if (idstr=="copycat"){
        var mimic = __battle__last_used_move_global(_B);
        if (mimic>0){ variable_struct_set(_step,"move_id", mimic); _moveId=mimic; _mv=__battle__get_move_record_safe_SHIM(_moveId); _mm=__battle_get_move_meta_SHIM(_moveId); idstr=(variable_struct_exists(_mv,"identifier")?string_lower(string(_mv.identifier)):""); _dmgClass=(variable_struct_exists(_mv,"damage_class_id")?_mv.damage_class_id:0); _typeId=(variable_struct_exists(_mv,"type_id")?_mv.type_id:-1); _power=(variable_struct_exists(_mv,"power")&&is_real(_mv.power)?max(0,_mv.power):0); }
        else { variable_struct_set(_A,"_last_move_failed",true); return "fail"; }
    }
    if (idstr=="mirror-move"){
        var mmid = __battle__mirror_move_pick(_D);
        if (mmid>0){ variable_struct_set(_step,"move_id", mmid); _moveId=mmid; _mv=__battle__get_move_record_safe_SHIM(_moveId); _mm=__battle_get_move_meta_SHIM(_moveId); idstr=(variable_struct_exists(_mv,"identifier")?string_lower(string(_mv.identifier)):""); _dmgClass=(variable_struct_exists(_mv,"damage_class_id")?_mv.damage_class_id:0); _typeId=(variable_struct_exists(_mv,"type_id")?_mv.type_id:-1); _power=(variable_struct_exists(_mv,"power")&&is_real(_mv.power)?max(0,_mv.power):0); }
        else { variable_struct_set(_A,"_last_move_failed",true); return "fail"; }
    }
    if (idstr=="metronome"){
        var rnd = __battle__random_legal_move_id();
        if (rnd>0){ variable_struct_set(_step,"move_id", rnd); _moveId=rnd; _mv=__battle__get_move_record_safe_SHIM(_moveId); _mm=__battle_get_move_meta_SHIM(_moveId); idstr=(variable_struct_exists(_mv,"identifier")?string_lower(string(_mv.identifier)):""); _dmgClass=(variable_struct_exists(_mv,"damage_class_id")?_mv.damage_class_id:0); _typeId=(variable_struct_exists(_mv,"type_id")?_mv.type_id:-1); _power=(variable_struct_exists(_mv,"power")&&is_real(_mv.power)?max(0,_mv.power):0); }
        else { variable_struct_set(_A,"_last_move_failed",true); return "fail"; }
    }
    if (idstr=="assist"){
        var aid = __battle__assist_pick_from_party(_B,_A);
        if (aid>0){ variable_struct_set(_step,"move_id", aid); _moveId=aid; _mv=__battle__get_move_record_safe_SHIM(_moveId); _mm=__battle_get_move_meta_SHIM(_moveId); idstr=(variable_struct_exists(_mv,"identifier")?string_lower(string(_mv.identifier)):""); _dmgClass=(variable_struct_exists(_mv,"damage_class_id")?_mv.damage_class_id:0); _typeId=(variable_struct_exists(_mv,"type_id")?_mv.type_id:-1); _power=(variable_struct_exists(_mv,"power")&&is_real(_mv.power)?max(0,_mv.power):0); }
        else { variable_struct_set(_A,"_last_move_failed",true); return "fail"; }
    }
    if (idstr=="sketch"){
        // Copy target's last successful move into an empty slot (or first slot)
        var sk = (variable_struct_exists(_D,"_last_move_id_success")?_D._last_move_id_success:-1);
        if (sk>0 && is_array(_A.moves)){
            var placed=false;
            for (var si=0; si<array_length(_A.moves); si++){ if (!is_real(_A.moves[si]) || _A.moves[si]<=0){ _A.moves[si]=sk; placed=true; break; } }
            if (!placed) _A.moves[0]=sk;
            return "ok";
        } else { variable_struct_set(_A,"_last_move_failed",true); return "fail"; }
    }
    if (idstr=="transform"){
        if (__battle__apply_transform_simple(_A,_D)) return "ok"; else { variable_struct_set(_A,"_last_move_failed",true); return "fail"; }
    }
    if (idstr=="trick-room"){ _B.trick_room_turns = 5; return "ok"; }
    if (idstr=="perish-song"){ // set 3 on all active
        if (is_array(_B.actor)) for (var pi=0; pi<array_length(_B.actor); pi++){ var P=_B.actor[pi]; if (is_struct(P)) variable_struct_set(P,"_perish_turns",3); }
        return "ok";
    }
    if (idstr=="destiny-bond"){ variable_struct_set(_A,"_destiny_bond_turn", true); return "ok"; }
    if (idstr=="magic-coat"){ variable_struct_set(_A,"_magic_coat_turn", true); return "ok"; }
    if (idstr=="encore"){
        if (is_struct(_D) && variable_struct_exists(_D,"_last_move_id_success") && _D._last_move_id_success>0){
            _D._encore_move_id = _D._last_move_id_success; _D._encore_turns = 3; return "ok";
        } else { variable_struct_set(_A,"_last_move_failed",true); return "fail"; }
    }
    if (idstr=="torment"){ if (is_struct(_D)){ _D._torment_turns = 3; return "ok"; } }
    if (idstr=="taunt"){ if (is_struct(_D)){ _D._taunt_turns = 3; return "ok"; } }
    if (idstr=="disable"){
        if (is_struct(_D) && variable_struct_exists(_D,"_last_move_id_success") && _D._last_move_id_success>0){
            _D._disable_move = _D._last_move_id_success; _D._disable_turns = 4; return "ok";
        } else { variable_struct_set(_A,"_last_move_failed",true); return "fail"; }
    }
    if (idstr=="imprison"){ // block opponent from using moves user knows
        if (is_array(_A.moves)) variable_struct_set(_A,"_imprison_active", true); return "ok";
    }
    if (idstr=="future-sight" || idstr=="doom-desire"){
        // Simplified: store a delayed hit on target after 2 turns
        if (!variable_struct_exists(_B,"_delayed_hits") || !is_array(_B._delayed_hits)) _B._delayed_hits = [];
        array_push(_B._delayed_hits, {turns:2, source:_actorIndex, target:_targetIndex, move:_moveId});
        return "ok";
    }
    if (idstr=="roar" || idstr=="whirlwind"){
        if (is_struct(_D)) variable_struct_set(_D,"_force_switch", true);
        return "ok";
    }
    if (idstr=="snatch"){ variable_struct_set(_A,"_snatch_turn", true); return "ok"; }

    // ===== Normal & reactive moves =====

    // Endure activation
    if (is_struct(_mm) && variable_struct_exists(_mm,"endure_self") && _mm.endure_self) { __battle__apply_endure(_A); return "ok"; }

    // Reactive moves: Counter / Mirror Coat / Metal Burst
    var isCounter=(idstr=="counter");
    var isMirror =(idstr=="mirror-coat");
    var isBurst  =(idstr=="metal-burst");
    if (isCounter || isMirror || isBurst){
        var dmgTaken=(variable_struct_exists(_A,"_last_damage_amount")?max(0,_A._last_damage_amount):0);
        var clsTaken=(variable_struct_exists(_A,"_last_damage_class")?_A._last_damage_class:0);
        var srcIdx  =(variable_struct_exists(_A,"_last_damage_source_index")?_A._last_damage_source_index:-1);
        if (dmgTaken<=0) { variable_struct_set(_A,"_last_move_failed",true); return "no-damage-to-retaliate"; }
        var targetIndex=_targetIndex;
        if (srcIdx>=0) targetIndex=srcIdx; else if (isBurst) targetIndex=__battle__pick_metal_burst_target(_B,_actorIndex,_targetIndex);
        var Dcur=_B.actor[targetIndex]; if (!is_struct(Dcur)) { variable_struct_set(_A,"_last_move_failed",true); return "no-valid-target"; }
        var mult=0; if (isCounter && clsTaken==2) mult=2; else if (isMirror && clsTaken==3) mult=2; else if (isBurst) mult=3/2;
        if (mult<=0) { variable_struct_set(_A,"_last_move_failed",true); return "wrong-damage-class"; }
        var dmgOut=floor(dmgTaken*mult);
        var applied=0;
        if (!is_undefined(__battle__apply_damage_with_substitute_v09)) applied=__battle__apply_damage_with_substitute_v09(Dcur,dmgOut,false);
        else if (!is_undefined(__battle__apply_damage_with_substitute)) applied=__battle__apply_damage_with_substitute(Dcur,dmgOut);
        else applied=__battle_apply_damage(Dcur,dmgOut);
        if (__battle_is_fainted(Dcur)) {
            // Destiny Bond check
            if (variable_struct_exists(Dcur,"_destiny_bond_turn") && Dcur._destiny_bond_turn) {
                var atk = _A; __battle__write_hp_now(atk, 0);
            }
            __battle__on_knockout_boost(_A);
            __battle__record_move_history(_B,_actorIndex,_moveId,true);
            variable_struct_set(_A,"_last_move_id_success", _moveId);
            variable_struct_set(_A,"_last_move_id", _moveId);
            return "fainted";
        }
        __battle__record_move_history(_B,_actorIndex,_moveId,true);
        variable_struct_set(_A,"_last_move_id_success", _moveId);
        variable_struct_set(_A,"_last_move_id", _moveId);
        return "ok";
    }

    // OHKO strict handling
    var isOHKO=(idstr=="sheer-cold"||idstr=="fissure"||idstr=="horn-drill"||idstr=="guillotine");
    if (isOHKO){
        var _targetsOH=__battle__list_targets(_B,_actorIndex,_targetIndex,"selected-opponent"); var anyHit=false;
        for (var ti=0;ti<array_length(_targetsOH);ti++){
            var tIndex=_targetsOH[ti]; var Dcur2=_B.actor[tIndex]; if(!is_struct(Dcur2)) continue;
            if (!__battle__ohko_allowed_vs_target(_A,Dcur2,idstr)) continue;
            if (!__battle__ohko_hits_roll(_A,Dcur2,idstr)) continue;
            var dmgHuge=__battle__ohko_damage_value(Dcur2); dmgHuge=__battle__tweak_endure_damage(Dcur2,dmgHuge);
            var applied2=0;
            if (!is_undefined(__battle__apply_damage_with_substitute_v09)) applied2=__battle__apply_damage_with_substitute_v09(Dcur2,dmgHuge,false);
            else if (!is_undefined(__battle__apply_damage_with_substitute)) applied2=__battle__apply_damage_with_substitute(Dcur2,dmgHuge);
            else applied2=__battle_apply_damage(Dcur2,dmgHuge);
            anyHit=true; if (__battle_is_fainted(Dcur2)) {
                // Destiny Bond check
                if (variable_struct_exists(Dcur2,"_destiny_bond_turn") && Dcur2._destiny_bond_turn) __battle__write_hp_now(_A, 0);
                __battle__on_knockout_boost(_A); __battle__record_move_history(_B,_actorIndex,_moveId,true); variable_struct_set(_A,"_last_move_id_success", _moveId); variable_struct_set(_A,"_last_move_id", _moveId);
                return "fainted";
            }
        }
        if (!anyHit) { variable_struct_set(_A,"_last_move_failed",true); return "miss"; }
        __battle__record_move_history(_B,_actorIndex,_moveId,true); variable_struct_set(_A,"_last_move_id_success", _moveId); variable_struct_set(_A,"_last_move_id", _moveId);
        return "ok";
    }

    // Targets (with absorber redirection)
    var _tIdent=(is_struct(_mm)&&variable_struct_exists(_mm,"target_ident")?_mm.target_ident:"selected-opponent");
    var _targets=__battle__list_targets(_B,_actorIndex,_targetIndex,_tIdent);
    _targets=__battle__maybe_redirect_targets(_B,_actorIndex,_targets,_typeId);

    var _dmgAccumAll=0;
    for (var tj=0;tj<array_length(_targets);tj++){
        var tIdx=_targets[tj]; var Dcur3=_B.actor[tIdx]; if (!is_struct(Dcur3)) continue;

        var totalHits=1;
        if (is_struct(_mm) && variable_struct_exists(_mm,"multi_hit_min")) {
            var mn=max(1,_mm.multi_hit_min); var mx=(variable_struct_exists(_mm,"multi_hit_max")?max(mn,_mm.multi_hit_max):mn);
            totalHits=irandom_range(mn,mx);
        }

        var dmgAccum=0;
        for (var h=0;h<totalHits;h++){
            var dmg=0; var absorbed=false;
            if (_power>0){
                absorbed=__battle__apply_absorb_ability_effects(_A,Dcur3,_typeId);
                if (!absorbed){
                    dmg=__battle_calc_damage(_A,Dcur3,_moveId,_power);
                    if (_typeId==10) { var multDS=__battle__dry_skin_fire_multiplier(Dcur3); if (multDS!=1) dmg=floor(dmg*multDS); }
                    var isCrit=false; if (!is_undefined(__battle__roll_crit_exact)) isCrit=__battle__roll_crit_exact(_A,Dcur3,_mv,_mm); else if (!is_undefined(__battle__roll_crit)) isCrit=__battle__roll_crit(_A,Dcur3,_mv,_mm);
                    dmg=__battle__adjust_damage_by_stages_and_burn(_A,Dcur3,_dmgClass,isCrit,dmg);
                    dmg=__battle__tweak_endure_damage(Dcur3,dmg);
                }
            }

            var applied=0;
            if (!is_undefined(__battle__apply_damage_with_substitute_v09)) applied=__battle__apply_damage_with_substitute_v09(Dcur3,dmg,false);
            else if (!is_undefined(__battle__apply_damage_with_substitute)) applied=__battle__apply_damage_with_substitute(Dcur3,dmg);
            else applied=__battle_apply_damage(Dcur3,dmg);

            dmgAccum += max(0, applied);
            _dmgAccumAll += max(0, applied);

            if (applied>0 || absorbed) __battle__on_hit_type_reactions(Dcur3,_typeId,_actorIndex);

            __battle__record_damage_from(Dcur3, applied, _dmgClass, _actorIndex);

            // Reflect status via Magic Coat handled earlier in __battle__apply_status_if_any

            __battle_trigger_hit_effect(_pid, _step, _A, Dcur3, _moveId, h, totalHits, dmg);
            if (__battle_is_fainted(Dcur3)) {
                // Destiny Bond check
                if (variable_struct_exists(Dcur3,"_destiny_bond_turn") && Dcur3._destiny_bond_turn) __battle__write_hp_now(_A, 0);
                __battle__on_knockout_boost(_A); break;
            }
        }

        if (__battle_is_fainted(Dcur3)) { __battle__record_move_history(_B,_actorIndex,_moveId,true); variable_struct_set(_A,"_last_move_id_success", _moveId); variable_struct_set(_A,"_last_move_id", _moveId); return "fainted"; }
    }

    if (!is_undefined(__battle__life_orb_recoil_if_any)) __battle__life_orb_recoil_if_any(_A, _dmgAccumAll);
    if (!is_undefined(__battle__shell_bell_heal_if_any)) __battle__shell_bell_heal_if_any(_A, _dmgAccumAll);

    if (is_struct(_mm) && variable_struct_exists(_mm,"is_rapid_spin") && _mm.is_rapid_spin) __battle__apply_rapid_spin_effects(_B,_A,_mm);
    if (is_struct(_mm) && variable_struct_exists(_mm,"is_defog") && _mm.is_defog) __battle__apply_defog_effects(_B,_A,_D,_mm);
    if (is_struct(_mm) && variable_struct_exists(_mm,"is_court_change") && _mm.is_court_change) __battle__apply_court_change(_B);

    // Post success memory
    __battle__record_move_history(_B,_actorIndex,_moveId,true);
    variable_struct_set(_A,"_last_move_id_success", _moveId);
    variable_struct_set(_A,"_last_move_id", _moveId);

    return "ok";
}

// ---- v3.1 additions (appended, last-wins) ----



// =======================================================================
// v3.1 PATCH — Two-turn & Semi-Invulnerable Moves (Fly/Dig/Dive/Bounce/etc.)
// Append this AFTER v3.0 so these definitions win last.
// =======================================================================

// Helper: Begin charge with optional semi-inv tag
function __battle__begin_charge(_A, _moveId, _targetIndex, _semi_tag, _turns){
    if (!is_struct(_A)) return false;
    variable_struct_set(_A, "_charging", true);
    variable_struct_set(_A, "_charging_move_id", _moveId);
    variable_struct_set(_A, "_charging_target_index", _targetIndex);
    variable_struct_set(_A, "_charge_turns_left", max(1, _turns));
    if (is_string(_semi_tag) && string_length(_semi_tag)>0){
        variable_struct_set(_A, "_semi_invuln", string_lower(_semi_tag)); // e.g., "fly","dig","dive","bounce","phantom"
        variable_struct_set(_A, "_semi_invuln_source_move", _moveId);
    }
    return true;
}

// Helper: Resolve charging state; return true if this call should execute the stored move
function __battle__advance_or_consume_charge(_B, _A){
    if (!is_struct(_A)) return false;
    if (!(variable_struct_exists(_A,"_charging") && _A._charging)) return false;
    var t = (variable_struct_exists(_A,"_charge_turns_left")?_A._charge_turns_left:1);
    t -= 1;
    if (t > 0){
        _A._charge_turns_left = t;
        return false; // still charging
    }
    // Consume
    _A._charging = false;
    _A._charge_turns_left = 0;
    // Semi-inv ends right BEFORE the move hits
    if (variable_struct_exists(_A,"_semi_invuln")) _A._semi_invuln = "";
    return true;
}

// Helper: Can a move hit a semi-inv target?
function __battle__can_hit_semi_inv(_B, _A, _D, _mm_attacker){
    if (!is_struct(_D)) return true;
    var tag = (variable_struct_exists(_D,"_semi_invuln") ? string_lower(string(_D._semi_invuln)) : "");
    if (string_length(tag)<=0) return true;

    // Gravity bypass
    if (is_struct(_B) && variable_struct_exists(_B,"gravity_turns") && _B.gravity_turns>0) return true;
    // No Guard bypass
    if (__battle__has_ability(_A,"no-guard") || __battle__has_ability(_D,"no-guard")) return true;

    // Check meta allowance
    if (is_struct(_mm_attacker) && variable_struct_exists(_mm_attacker,"hits_semi_inv")){
        var allowed = _mm_attacker.hits_semi_inv; // array or string
        if (is_array(allowed)){
            for (var i=0;i<array_length(allowed);i++){
                if (string_lower(string(allowed[i])) == tag) return true;
            }
        } else if (is_string(allowed)){
            if (string_lower(string(allowed)) == tag) return true;
            if (string_lower(string(allowed)) == "any") return true;
        }
    }
    // Otherwise, can't hit
    return false;
}

// Helper: Optional power multiplier when hitting semi-inv target
function __battle__semi_inv_hit_power_mult(_mm_attacker, _D){
    if (!is_struct(_D)) return 1;
    var tag = (variable_struct_exists(_D,"_semi_invuln") ? string_lower(string(_D._semi_invuln)) : "");
    if (string_length(tag)<=0) return 1;
    if (is_struct(_mm_attacker) && variable_struct_exists(_mm_attacker,"semi_inv_power_mult")){
        var meta = _mm_attacker.semi_inv_power_mult; // could be real or map {tag:mult}
        if (is_real(meta) && meta>0) return meta;
        if (is_struct(meta) && variable_struct_exists(meta, tag) && is_real(meta[? tag])) return max(0.01, meta[? tag]);
    }
    return 1;
}

// Ensure flags clear on end of turn & switch (already mostly done, but add safety)
function battle_end_of_turn_update(_pid){
    // call original if captured
    if (!is_undefined(battle_end_of_turn_update_prev)) battle_end_of_turn_update_prev(_pid);

    var _B=__battle_ensure_slot(_pid); if(!is_struct(_B)) return;
    if (variable_struct_exists(_B,"actor")&&is_array(_B.actor)){
        for (var i=0;i<array_length(_B.actor);i++){
            var E=_B.actor[i]; if (!is_struct(E)) continue;
            if (variable_struct_exists(E,"_semi_invuln")) {
                // If still charging, keep; otherwise clear residual
                var keep = (variable_struct_exists(E,"_charging") && E._charging);
                if (!keep) E._semi_invuln = "";
            }
        }
    }
}
if (is_undefined(battle_end_of_turn_update_prev) && !is_undefined(battle_end_of_turn_update)) {
    battle_end_of_turn_update_prev = battle_end_of_turn_update;
}

// Override executor with charge/semi-inv logic
function __battle_perform_action_impl(_pid,_step){
    var _B=__battle_ensure_slot(_pid); if(!is_struct(_B)) return "no-battle-slot";

    var _actorIndex=(variable_struct_exists(_step,"actor_index")?variable_struct_get(_step,"actor_index"):0);
    var _targetIndex=(variable_struct_exists(_step,"target_index")?variable_struct_get(_step,"target_index"):1);
    var _A=undefined, _D=undefined; try { if (variable_struct_exists(_B,"actor")&&is_array(_B.actor)) { var _acts=_B.actor; _A=_acts[_actorIndex]; _D=_acts[_targetIndex]; } } catch (e) {}
    if (!is_struct(_A)) return "invalid-actors";

    // If currently charging a move and player selected the same move: resolve this turn
    var isCharging = (variable_struct_exists(_A,"_charging") && _A._charging);
    var selectedId = (variable_struct_exists(_step,"move_id")?variable_struct_get(_step,"move_id"):-1);
    if (isCharging && variable_struct_exists(_A,"_charging_move_id") && _A._charging_move_id == selectedId){
        // Advance timer; if not done, we just "charge"
        if (!__battle__advance_or_consume_charge(_B,_A)){
            // still charging
            return "charging";
        }
        // else: proceed to execute the stored move as normal below
    }

    // Fetch move
    var _moveId=selectedId;
    var _mm=__battle_get_move_meta_SHIM(_moveId);
    var _mv=__battle__get_move_record_safe_SHIM(_moveId);
    if (!is_struct(_mv)) { variable_struct_set(_A,"_last_move_failed",true); return "no-move"; }
    var idstr=(variable_struct_exists(_mv,"identifier")?string_lower(string(_mv.identifier)):"");

    var _dmgClass=(variable_struct_exists(_mv,"damage_class_id")?_mv.damage_class_id:0);
    var _typeId=(variable_struct_exists(_mv,"type_id")?_mv.type_id:-1);
    var _power=(variable_struct_exists(_mv,"power")&&is_real(_mv.power)?max(0,_mv.power):0);

    // Two-turn charge detection from meta
    var needsCharge = (is_struct(_mm) && variable_struct_exists(_mm,"two_turn_charge") && _mm.two_turn_charge);
    var semiTag = (is_struct(_mm) && variable_struct_exists(_mm,"semi_invuln_tag") ? string_lower(string(_mm.semi_invuln_tag)) : "");

    // If this move needs a charge and we are not already executing the second turn, begin charge
    if (needsCharge && !(isCharging && _A._charging_move_id==_moveId)){
        var turns = (variable_struct_exists(_mm,"charge_turns") && is_real(_mm.charge_turns) ? max(1,_mm.charge_turns) : 1);
        __battle__begin_charge(_A, _moveId, _targetIndex, semiTag, turns);
        return "charging";
    }

    // ===== All the normal v3.0 processing is now delegated to the original executor =====
    // We must ensure semi-inv hit checking & multipliers are applied. We'll wrap the key hooks.

    // Capture original damage calc if not yet
    if (is_undefined(__battle_calc_damage_prev) && !is_undefined(__battle_calc_damage)) __battle_calc_damage_prev = __battle_calc_damage;

    // Wrap __battle_calc_damage to inject semi-inv power multiplier when appropriate
    function __battle_calc_damage(_A2,_D2,_moveId2,_power2){
        var base = 0;
        if (!is_undefined(__battle_calc_damage_prev)) base = __battle_calc_damage_prev(_A2,_D2,_moveId2,_power2);
        else base = __battle_apply_damage(_D2, 0); // fallback no-op base (should not be used)
        var mm = __battle_get_move_meta_SHIM(_moveId2);
        var mult = __battle__semi_inv_hit_power_mult(mm, _D2);
        return floor(max(0, base * mult));
    }

    // Pre-hit guard: if defender is semi-inv and this move cannot hit, mark miss/fail
    if (!__battle__can_hit_semi_inv(_B, _A, _D, _mm)){
        // Allow status moves that target self even while foe is semi-inv
        if (!(_dmgClass==1 && __battle__entity_side_key(_A)==__battle__entity_side_key(_D))){
            variable_struct_set(_A,"_last_move_failed",true);
            // Update last move memory so Copycat/Encore logic still sees it as used (but failed)
            if (is_struct(_B)) {
                if (!variable_struct_exists(_B,"_move_history") || !is_array(_B._move_history)) _B._move_history = [];
                array_push(_B._move_history, [_actorIndex, _moveId]);
            }
            variable_struct_set(_A,"_last_move_id", _moveId);
            return "miss";
        }
    }

    // Delegate fully to the original v3.0 executor for damage, effects, etc.
    if (!is_undefined(__battle_perform_action_impl_prev_v31) && __battle_perform_action_impl_prev_v31 != __battle_perform_action_impl){
        return __battle_perform_action_impl_prev_v31(_pid,_step);
    } else if (!is_undefined(__battle_perform_action_impl_prev)){
        return __battle_perform_action_impl_prev(_pid,_step);
    } else {
        // If no previous executor captured (unexpected), treat as success
        return "ok";
    }
}

// Capture previous executor once
if (is_undefined(__battle_perform_action_impl_prev_v31) && !is_undefined(__battle_perform_action_impl)) {
    __battle_perform_action_impl_prev_v31 = __battle_perform_action_impl;
}

// End patch


// ---- v3.1.1 reliability wrapper appended ----



// =======================================================================
// v3.1.1 — Reliability Wrapper for Move Memory (Copycat & Disable fixes)
// - Records EVERY move use in battle history (even when it fails/misses).
// - Sets _last_move_id on the user every action.
// - Sets _last_move_id_success only when the move truly executed (ok/fainted/charging/miss).
// Append after v3.1 full.
// =======================================================================

function __battle__record_move_use(_B, _A, _actorIndex, _moveId, _as_success){
    if (!is_struct(_B) || !is_struct(_A)) return;
    if (!variable_struct_exists(_B,"_move_history") || !is_array(_B._move_history)) _B._move_history = [];
    array_push(_B._move_history, [_actorIndex, _moveId]);
    variable_struct_set(_A,"_last_move_id", _moveId);
    if (_as_success){
        variable_struct_set(_A,"_last_move_id_success", _moveId);
    }
}

// Wrap the previous executor
if (is_undefined(__battle_perform_action_impl_prev_v311) && !is_undefined(__battle_perform_action_impl)) {
    __battle_perform_action_impl_prev_v311 = __battle_perform_action_impl;
}

function __battle_perform_action_impl(_pid,_step){
    var _B=__battle_ensure_slot(_pid);
    if (!is_struct(_B)) return "no-battle-slot";
    var _actorIndex=(variable_struct_exists(_step,"actor_index")?variable_struct_get(_step,"actor_index"):0);
    var _A=undefined;
    if (variable_struct_exists(_B,"actor")&&is_array(_B.actor)) _A=_B.actor[_actorIndex];
    var _moveId=(variable_struct_exists(_step,"move_id")?variable_struct_get(_step,"move_id"):-1);

    var result = "ok";
    if (!is_undefined(__battle_perform_action_impl_prev_v311)) {
        result = __battle_perform_action_impl_prev_v311(_pid,_step);
    }

    // Determine success-ness for last_move_id_success semantics
    var res = string_lower(string(result));
    var success = (res=="ok" || res=="fainted" || res=="charging" || res=="miss"); // counts as used successfully
    __battle__record_move_use(_B, _A, _actorIndex, _moveId, success);

    return result;
}

// ---- v3.1.2 Copycat/Disable integrated (no patches needed) ----



// =======================================================================
// v3.1.2 — Copycat & Disable Resolution Micro-Fix (append last)
// -----------------------------------------------------------------------
// Strengthens how we locate the "last move" so Copycat/Disable are reliable
// even with unusual fail/miss paths or doubles turn ordering.
// =======================================================================

// --- Helpers: last successful move (overall & per-actor) ---
function __battle__last_success_move_overall(_B){
    if (!is_struct(_B)) return -1;
    if (!variable_struct_exists(_B,"_move_history") || !is_array(_B._move_history)) return -1;
    // Walk from newest to oldest; prefer success marks if we tracked them inline
    // Fallback: any recorded entry, filtering forbidden mimics.
    for (var i=array_length(_B._move_history)-1; i>=0; i--){
        var rec = _B._move_history[i];
        if (!is_array(rec) || array_length(rec) < 2) continue;
        var mid = rec[1];
        var mv = __battle__get_move_record_safe_SHIM(mid);
        var idstr = (is_struct(mv) && variable_struct_exists(mv,"identifier") ? string_lower(string(mv.identifier)) : "");
        if (idstr=="copycat" || idstr=="assist" || idstr=="metronome" || idstr=="mirror-move" || idstr=="sketch" || idstr=="struggle") continue;
        return mid;
    }
    return -1;
}
function __battle__last_success_move_for_actor(_B, _actorIndex){
    if (!is_struct(_B) || !is_real(_actorIndex)) return -1;
    if (!variable_struct_exists(_B,"_move_history") || !is_array(_B._move_history)) return -1;
    for (var i=array_length(_B._move_history)-1; i>=0; i--){
        var rec = _B._move_history[i];
        if (!is_array(rec) || array_length(rec) < 2) continue;
        if (rec[0] != _actorIndex) continue;
        var mid = rec[1];
        var mv = __battle__get_move_record_safe_SHIM(mid);
        var idstr = (is_struct(mv) && variable_struct_exists(mv,"identifier") ? string_lower(string(mv.identifier)) : "");
        if (idstr=="copycat" || idstr=="assist" || idstr=="metronome" || idstr=="mirror-move" || idstr=="sketch" || idstr=="struggle") continue;
        return mid;
    }
    return -1;
}

// --- Patch Copycat branch in executor by wrapping/overriding behavior ---
if (is_undefined(__battle_perform_action_impl_prev_v312) && !is_undefined(__battle_perform_action_impl)) {
    __battle_perform_action_impl_prev_v312 = __battle_perform_action_impl;
}

function __battle_perform_action_impl(_pid,_step){
    var _B=__battle_ensure_slot(_pid); if(!is_struct(_B)) return "no-battle-slot";
    var _actorIndex=(variable_struct_exists(_step,"actor_index")?variable_struct_get(_step,"actor_index"):0);
    var _targetIndex=(variable_struct_exists(_step,"target_index")?variable_struct_get(_step,"target_index"):1);

    var res = "ok";
    // Peek selected move
    var _moveId=(variable_struct_exists(_step,"move_id")?variable_struct_get(_step,"move_id"):-1);
    var _mv=__battle__get_move_record_safe_SHIM(_moveId);
    var idstr=(is_struct(_mv)&&variable_struct_exists(_mv,"identifier")?string_lower(string(_mv.identifier)):"");

    // Strengthened Copycat: choose the best available last move
    if (idstr=="copycat"){
        var mimic = __battle__last_success_move_overall(_B);
        if (mimic <= 0) {
            // Fallback: last used (even if miss) overall
            mimic = __battle__last_used_move_global(_B);
        }
        if (mimic <= 0) {
            // Fallback: try target's last successful
            var _acts = (variable_struct_exists(_B,"actor") && is_array(_B.actor) ? _B.actor : []);
            if (is_array(_acts) && _targetIndex >= 0 && _targetIndex < array_length(_acts)) {
                mimic = __battle__last_success_move_for_actor(_B, _targetIndex);
            }
        }
        if (mimic > 0){
            variable_struct_set(_step,"move_id", mimic);
            __battle__dbg("Copycat resolved to move id="+string(mimic));
        } else {
            __battle__dbg("Copycat failed to find previous move");
        }
    }

    // Run the original executor
    res = __battle_perform_action_impl_prev_v312(_pid,_step);

    // Strengthened Disable: if target had no _last_move_id_success, fallback to history
    var _A=undefined, _D=undefined;
    if (variable_struct_exists(_B,"actor")&&is_array(_B.actor)) { _A=_B.actor[_actorIndex]; if (_targetIndex>=0 && _targetIndex<array_length(_B.actor)) _D=_B.actor[_targetIndex]; }
    if (is_struct(_A) && is_struct(_D)){
        var mv_after = __battle__get_move_record_safe_SHIM(variable_struct_exists(_step,"move_id")?variable_struct_get(_step,"move_id"):-1);
        var id_after=(is_struct(mv_after)&&variable_struct_exists(mv_after,"identifier")?string_lower(string(mv_after.identifier)):"");
        if (id_after=="disable"){
            if (!(variable_struct_exists(_D,"_last_move_id_success") && is_real(_D._last_move_id_success) && _D._last_move_id_success>0)){
                var fallback = __battle__last_success_move_for_actor(_B, _targetIndex);
                if (fallback>0){
                    _D._disable_move = fallback;
                    if (!variable_struct_exists(_D,"_disable_turns") || !is_real(_D._disable_turns) || _D._disable_turns<=0) _D._disable_turns = 4;
                    __battle__dbg("Disable fallback set to target's last success move id="+string(fallback));
                } else {
                    __battle__dbg("Disable fallback could not find a last success move for target");
                }
            }
        }
    }

    return res;
}



// ---- v3.1.3 hardened executor appended ----


// =======================================================================
// v3.1.3 — Finalized Copycat & Disable executor override (append last)
// =======================================================================

// Helper: last any move overall (not just success)
function __battle__last_any_move_overall(_B){
    if (!is_struct(_B)) return -1;
    if (!variable_struct_exists(_B,"_move_history") || !is_array(_B._move_history)) return -1;
    for (var i=array_length(_B._move_history)-1; i>=0; i--){
        var rec = _B._move_history[i];
        if (!is_array(rec) || array_length(rec) < 2) continue;
        var mid = rec[1];
        var mv = __battle__get_move_record_safe_SHIM(mid);
        var idstr = (is_struct(mv) && variable_struct_exists(mv,"identifier") ? string_lower(string(mv.identifier)) : "");
        if (idstr=="copycat" || idstr=="assist" || idstr=="metronome" || idstr=="mirror-move" || idstr=="sketch" || idstr=="struggle") continue;
        return mid;
    }
    return -1;
}
function __battle__last_any_move_for_actor(_B, _actorIndex){
    if (!is_struct(_B) || !is_real(_actorIndex)) return -1;
    if (!variable_struct_exists(_B,"_move_history") || !is_array(_B._move_history)) return -1;
    for (var i=array_length(_B._move_history)-1; i>=0; i--){
        var rec = _B._move_history[i];
        if (!is_array(rec) || array_length(rec) < 2) continue;
        if (rec[0] != _actorIndex) continue;
        var mid = rec[1];
        var mv = __battle__get_move_record_safe_SHIM(mid);
        var idstr = (is_struct(mv) && variable_struct_exists(mv,"identifier") ? string_lower(string(mv.identifier)) : "");
        if (idstr=="copycat" || idstr=="assist" || idstr=="metronome" || idstr=="mirror-move" || idstr=="sketch" || idstr=="struggle") continue;
        return mid;
    }
    return -1;
}

// Capture previous executor once
if (is_undefined(__battle_perform_action_impl_prev_v313) && !is_undefined(__battle_perform_action_impl)) {
    __battle_perform_action_impl_prev_v313 = __battle_perform_action_impl;
}

function __battle_perform_action_impl(_pid,_step){
    var _B=__battle_ensure_slot(_pid); if(!is_struct(_B)) return "no-battle-slot";
    var _actorIndex=(variable_struct_exists(_step,"actor_index")?variable_struct_get(_step,"actor_index"):0);
    var _targetIndex=(variable_struct_exists(_step,"target_index")?variable_struct_get(_step,"target_index"):1);

    var _moveId = (variable_struct_exists(_step,"move_id")?variable_struct_get(_step,"move_id"):-1);
    var _mv = __battle__get_move_record_safe_SHIM(_moveId);
    var idstr=(is_struct(_mv)&&variable_struct_exists(_mv,"identifier")?string_lower(string(_mv.identifier)):"");

    // Robust Copycat resolve (before executing)
    if (idstr=="copycat"){
        var picked = -1;
        // 1) last successful overall
        picked = __battle__last_success_move_overall(_B);
        // 2) last ANY overall
        if (picked<=0) picked = __battle__last_any_move_overall(_B);
        // 3) target's last successful
        if (picked<=0) picked = __battle__last_success_move_for_actor(_B, _targetIndex);
        // 4) target's last ANY
        if (picked<=0) picked = __battle__last_any_move_for_actor(_B, _targetIndex);
        // 5) last successful from anyone not on user's side (opponent)
        if (picked<=0 && variable_struct_exists(_B,"actor") && is_array(_B.actor)){
            var mySide = 0;
            var Aref=_B.actor[_actorIndex]; if (is_struct(Aref) && variable_struct_exists(Aref,"_side")) mySide=Aref._side;
            for (var i=array_length(_B._move_history)-1; i>=0; i--){
                var rec = _B._move_history[i];
                if (!is_array(rec) || array_length(rec) < 2) continue;
                var idx = rec[0];
                if (!is_real(idx) || idx<0 || idx>=array_length(_B.actor)) continue;
                var P=_B.actor[idx]; if (!is_struct(P) || !variable_struct_exists(P,"_side")) continue;
                if (P._side==mySide) continue;
                var mid=rec[1];
                var mv=__battle__get_move_record_safe_SHIM(mid); if (!is_struct(mv)) continue;
                var ii=(variable_struct_exists(mv,"identifier")?string_lower(string(mv.identifier)):"");
                if (ii=="copycat" || ii=="assist" || ii=="metronome" || ii=="mirror-move" || ii=="sketch" || ii=="struggle") continue;
                picked = mid; break;
            }
        }
        // Fallback to user's own last successful (rarely useful but safe)
        if (picked<=0) picked = __battle__last_success_move_for_actor(_B, _actorIndex);
        if (picked<=0) picked = __battle__last_any_move_for_actor(_B, _actorIndex);

        if (picked>0){
            variable_struct_set(_step,"move_id", picked);
            __battle__dbg("Copycat resolved to id="+string(picked));
        } else {
            __battle__dbg("Copycat: no source move found; will fail as per rules.");
        }
    }

    // Execute underlying logic
    var res = "ok";
    if (!is_undefined(__battle_perform_action_impl_prev_v313)) res = __battle_perform_action_impl_prev_v313(_pid,_step);

    // Harden Disable: if target didn't have a last success move, fallback to history
    var _A=undefined, _D=undefined;
    if (variable_struct_exists(_B,"actor")&&is_array(_B.actor)) { _A=_B.actor[_actorIndex]; if (_targetIndex>=0 && _targetIndex<array_length(_B.actor)) _D=_B.actor[_targetIndex]; }
    if (is_struct(_A) && is_struct(_D)){
        var mv_after = __battle__get_move_record_safe_SHIM(variable_struct_exists(_step,"move_id")?variable_struct_get(_step,"move_id"):-1);
        var id_after=(is_struct(mv_after)&&variable_struct_exists(mv_after,"identifier")?string_lower(string(mv_after.identifier)):"");
        if (id_after=="disable"){
            if (!(variable_struct_exists(_D,"_last_move_id_success") && is_real(_D._last_move_id_success) && _D._last_move_id_success>0)){
                var fallback = __battle__last_success_move_for_actor(_B, _targetIndex);
                if (fallback<=0) fallback = __battle__last_any_move_for_actor(_B, _targetIndex);
                if (fallback>0){
                    _D._disable_move = fallback;
                    if (!variable_struct_exists(_D,"_disable_turns") || !is_real(_D._disable_turns) || _D._disable_turns<=0) _D._disable_turns = 4;
                    __battle__dbg("Disable fallback -> id="+string(fallback));
                } else {
                    __battle__dbg("Disable fallback: no candidate found");
                }
            }
        }
    }

    return res;
>>>>>>> 0794a7a3ae684c41e3c5007f89acf639e0e65395
}
