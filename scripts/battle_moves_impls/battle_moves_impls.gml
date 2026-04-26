// [Battle] battle_moves_impls — Build v0.2.0 — Updated 2025-10-18

// Primary move resolver implementation.
// Handles move execution, including meta move reroutes, status gates, and delegates to
// battle_impl helpers for damage/effect application.

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

    if (is_struct(_step) && variable_struct_exists(_step, "switch_to")){
        var _switch_idx = variable_struct_get(_step, "switch_to");
        var _switch_msg = "But it failed!";
        try {
            if (!is_undefined(__battle_trainer_perform_switch_action)){
                _switch_msg = __battle_trainer_perform_switch_action(_pid, _switch_idx, _step);
            } else if (!is_undefined(battle_switch_to)){
                var _ok_switch = battle_switch_to(_pid, _switch_idx, { forced: true });
                _switch_msg = (_ok_switch ? "The opponent sent out a Pokémon!" : "But it failed!");
            }
        } catch (e_switch) {
            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][debug] switch action failed: " + string(e_switch));
        }
        return _switch_msg;
    }

    // Local helper to centralize the 'used' vs 'ohko miss' return message.
    // Also stamps the actor with last_move_dialog id/ts so other paths can de-dup their own messages.
    // Accept explicit parameters to avoid closure/scope issues with the static analyser.
    function __battle_impl_return_used(_pid_in, _A_in, _mv_name_in, _mid_in){
        try {
            var _Bslot_rr = __battle_ensure_slot(_pid_in);
            if (is_struct(_Bslot_rr) && variable_struct_exists(_Bslot_rr, "_last_ohko_miss") && variable_struct_get(_Bslot_rr, "_last_ohko_miss") == true){
                // Log consumption explicitly so it stands out in noisy logs
                if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[OHKO] performer consuming _last_ohko_miss for pid=" + string(_pid_in) + " move=" + string(_mv_name_in));
                try { variable_struct_set(_Bslot_rr, "_last_ohko_miss", undefined); } catch (e_clr) {}
                return string((variable_struct_exists(_A_in,"name")?variable_struct_get(_A_in,"name"):"The user")) + "'s attack missed!";
            }
        } catch (e_ru) {}
        // Best-effort: stamp last_move_dialog fields so inner enqueuers can skip duplicates
        try {
            if (is_struct(_A_in)){
                if (is_real(_mid_in)){
                    variable_struct_set(_A_in, "_last_move_dialog_id", _mid_in);
                    variable_struct_set(_A_in, "_last_move_dialog_ts", current_time);
                }
            }
        } catch (e_stamp) {}
        return string((variable_struct_exists(_A_in,"name")?variable_struct_get(_A_in,"name"):"The user")) + " used " + string(_mv_name_in) + "!";
    }

    function __battle_record_move_usage(_pid_in, _user_in, _target_in, _move_in, _skip_target_record){
        if (!is_real(_move_in)) return;
        try { global.lastMoveUsed_ID = _move_in; } catch (e_gl) {}
        var _suppress_target = false;
        if (is_struct(_user_in)){
            try {
                if (variable_struct_exists(_user_in, "_suppress_last_move_record") && variable_struct_get(_user_in, "_suppress_last_move_record") == true){
                    _suppress_target = true;
                }
            } catch (e_sup) {}
            try { variable_struct_set(_user_in, "sys_last_move_used", _move_in); } catch (e_lm1) {}
            try { variable_struct_set(_user_in, "sys_last_move_used_ts", current_time); } catch (e_lm2) {}
            var _user_hist = [];
            try {
                if (variable_struct_exists(_user_in, "_last_moves_used") && is_array(variable_struct_get(_user_in, "_last_moves_used"))){
                    _user_hist = variable_struct_get(_user_in, "_last_moves_used");
                }
            } catch (e_hist) {}
            var _t_idx = undefined;
            if (is_struct(_target_in)){
                if (variable_struct_exists(_target_in, "actor_index")) _t_idx = variable_struct_get(_target_in, "actor_index");
                else if (variable_struct_exists(_target_in, "slot")) _t_idx = variable_struct_get(_target_in, "slot");
            }
            array_push(_user_hist, { move: _move_in, target: _target_in, target_index: _t_idx, ts: current_time });
            if (array_length(_user_hist) > 8){
                var _trim_hist = [];
                var _start_hist = array_length(_user_hist) - 8;
                for (var _hi = _start_hist; _hi < array_length(_user_hist); ++_hi){ array_push(_trim_hist, _user_hist[_hi]); }
                _user_hist = _trim_hist;
            }
            try { variable_struct_set(_user_in, "_last_moves_used", _user_hist); } catch (e_setHist) {}
        }
        if (is_bool(_skip_target_record) && _skip_target_record) _suppress_target = true;
        if (_suppress_target) return;
        if (is_struct(_target_in)){
            var _target_hist = [];
            try {
                if (variable_struct_exists(_target_in, "_last_moves") && is_array(variable_struct_get(_target_in, "_last_moves"))){
                    _target_hist = variable_struct_get(_target_in, "_last_moves");
                }
            } catch (e_tHist) {}
            array_push(_target_hist, { move: _move_in, src: _user_in, ts: current_time });
            if (array_length(_target_hist) > 8){
                var _trim_target = [];
                var _start_target = array_length(_target_hist) - 8;
                for (var _ti = _start_target; _ti < array_length(_target_hist); ++_ti){ array_push(_trim_target, _target_hist[_ti]); }
                _target_hist = _trim_target;
            }
            try { variable_struct_set(_target_in, "_last_moves", _target_hist); } catch (e_setTarget) {}
        }
    }

    function __battle_no_pp_msg(_actor){
        var _name = "The user";
        try {
            if (is_struct(_actor) && variable_struct_exists(_actor, "name")){
                _name = string(variable_struct_get(_actor, "name"));
            }
        } catch (e_np) {}
        return string(_name) + " has no PP left!";
    }

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

    // Status gate: prevent acting when frozen/asleep/etc. before consuming PP or applying meta moves.
    if (is_struct(A) && !is_undefined(__battle_check_can_act)){
        var _can_act = true;
        try { _can_act = __battle_check_can_act(A, move_id); } catch (e_can_act) {
            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][status][gate] exception while checking actability: " + string(e_can_act));
            _can_act = true;
        }
        if (!_can_act){
            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){
                var _act_name = "actor";
                try { _act_name = string(__status_mon_display_name(A)); } catch (e_nm_gate) {}
                show_debug_message("[battle][status][gate] prevented action for " + _act_name + " (move_id=" + string(move_id) + ")");
            }
            return ""; // Message already queued by status system (freeze/sleep/etc.)
        }
    }

    var _is_protect_like = (is_real(move_id) && (move_id == 182 || move_id == 197));
    var _is_endure_like = (is_real(move_id) && move_id == 203);
    var _is_guard_like = (_is_protect_like || _is_endure_like);
    var _turn_now = 0;
    try {
        var _slot_turn = __battle_ensure_slot(_pid);
        if (is_struct(_slot_turn) && variable_struct_exists(_slot_turn, "turn_i")){
            _turn_now = max(0, floor(variable_struct_get(_slot_turn, "turn_i")));
        }
    } catch (e_turnp) { _turn_now = 0; }

    var _moveEntry = undefined;
    var _moveIdent = "";
    try {
        if (variable_global_exists("_moves") && is_array(global._moves) && is_real(move_id) && move_id >= 0 && move_id < array_length(global._moves)){
            _moveEntry = global._moves[move_id];
            if (is_struct(_moveEntry) && variable_struct_exists(_moveEntry, "identifier")){
                _moveIdent = string_lower(string(variable_struct_get(_moveEntry, "identifier")));
            }
        }
    } catch (e_moveIdent) { _moveEntry = undefined; _moveIdent = ""; }

    if (is_struct(A) && is_real(move_id) && !is_undefined(status_system_has_status)){
        try {
            if (status_system_has_status(A, "heal-block")){
                var _hb_blocks_move = (move_id == 156);
                if (!_hb_blocks_move && !is_undefined(__battle_get_move_meta)){
                    var _hb_mm = __battle_get_move_meta(move_id);
                    if (is_struct(_hb_mm)){
                        if (variable_struct_exists(_hb_mm, "healing") && is_real(variable_struct_get(_hb_mm, "healing")) && real(variable_struct_get(_hb_mm, "healing")) > 0) _hb_blocks_move = true;
                        if (!_hb_blocks_move && variable_struct_exists(_hb_mm, "drain") && is_real(variable_struct_get(_hb_mm, "drain")) && real(variable_struct_get(_hb_mm, "drain")) > 0) _hb_blocks_move = true;
                    }
                }
                if (_hb_blocks_move){
                    var _hb_name = (variable_struct_exists(A, "name") ? string(variable_struct_get(A, "name")) : "The Pokémon");
                    dialog_queue(_hb_name + " is prevented from using healing moves!");
                    return __battle_impl_return_used(_pid, A, __battle_move_name(move_id), move_id);
                }
            }
        } catch (e_heal_block_gate) {
            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][status][heal-block] gate failed: " + string(e_heal_block_gate));
        }
    }

    if (is_struct(A) && is_real(move_id) && !is_undefined(status_system_has_status)){
        try {
            if (status_system_has_status(A, "torment")){
                var _last_torment_move = undefined;
                if (variable_struct_exists(A, "sys_last_move_used")) _last_torment_move = variable_struct_get(A, "sys_last_move_used");
                if (!is_real(_last_torment_move) && variable_struct_exists(A, "_last_move_dialog_id")) _last_torment_move = variable_struct_get(A, "_last_move_dialog_id");
                if (!is_real(_last_torment_move) && variable_struct_exists(A, "mon") && is_struct(variable_struct_get(A, "mon"))){
                    var _Amon = variable_struct_get(A, "mon");
                    if (variable_struct_exists(_Amon, "sys_last_move_used")) _last_torment_move = variable_struct_get(_Amon, "sys_last_move_used");
                    if (!is_real(_last_torment_move) && variable_struct_exists(_Amon, "_last_move_dialog_id")) _last_torment_move = variable_struct_get(_Amon, "_last_move_dialog_id");
                }
                if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][status][torment] last_move=" + string(_last_torment_move) + ", attempted=" + string(move_id));
                if (is_real(_last_torment_move) && _last_torment_move == move_id){
                    var _torment_name = (variable_struct_exists(A, "name") ? string(variable_struct_get(A, "name")) : "The Pokémon");
                    var _torment_move_name = _moveIdent;
                    if (string_length(_torment_move_name) <= 0) _torment_move_name = "that move";
                    else _torment_move_name = string_replace_all(_torment_move_name, "-", " ");
                    dialog_queue(_torment_name + " can't use " + _torment_move_name + " again due to Torment!");
                    return "";
                }
            }
        } catch (e_torment_gate) {
            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][status][torment] gate failed: " + string(e_torment_gate));
        }
    }

    if (is_struct(A)){
        if (!_is_guard_like){
            try { variable_struct_set(A, "sys_protect_streak", 0); } catch (e_rstreakA) {}
        }
        try {
            var _prot_turn = (variable_struct_exists(A, "sys_protected_turn") ? variable_struct_get(A, "sys_protected_turn") : undefined);
            if (is_real(_prot_turn) && _turn_now > _prot_turn){
                variable_struct_set(A, "sys_protected", false);
                variable_struct_set(A, "_protected", false);
                variable_struct_set(A, "sys_protected_turn", undefined);
            }
        } catch (e_prot_clearA) {}
        try {
            var _endure_turn = (variable_struct_exists(A, "sys_endure_turn") ? variable_struct_get(A, "sys_endure_turn") : undefined);
            if (is_real(_endure_turn) && _turn_now > _endure_turn){
                variable_struct_set(A, "sys_enduring", false);
                variable_struct_set(A, "_enduring", false);
                variable_struct_set(A, "sys_endure_turn", undefined);
            }
        } catch (e_endure_clearA) {}

        var _disableExpireA = undefined;
        var _disableActiveA = false;
        var _disableNotifiedA = false;
        try { if (variable_struct_exists(A, "sys_disabledExpiresTurn")) _disableExpireA = variable_struct_get(A, "sys_disabledExpiresTurn"); } catch (e_expA) {}
        try { if (variable_struct_exists(A, "sys_disabledActive")) _disableActiveA = (variable_struct_get(A, "sys_disabledActive") == true); } catch (e_actA) { _disableActiveA = false; }
        try { if (variable_struct_exists(A, "sys_disabled_notified_clear")) _disableNotifiedA = (variable_struct_get(A, "sys_disabled_notified_clear") == true); } catch (e_notA) { _disableNotifiedA = false; }
        if (is_real(_disableExpireA) && _disableActiveA){
            if (_turn_now >= _disableExpireA){
                if (!_disableNotifiedA){
                    var _aname_clear = (variable_struct_exists(A, "name") ? string(variable_struct_get(A, "name")) : "The Pokémon");
                    dialog_queue(_aname_clear + " is no longer disabled!");
                }
                __battle_clear_disable(A);
            } else {
                var _remainingA = max(0, _disableExpireA - _turn_now);
                try { variable_struct_set(A, "sys_disabledTurns", _remainingA); } catch (e_remA) {}
                try { variable_struct_set(A, "sys_disabled_notified_clear", false); } catch (e_notResetA) {}
            }
        } else if (!_disableActiveA){
            __battle_clear_disable(A);
        }
    }

    // Sky Drop hold: actors being carried cannot act until the carrier releases them.
    try {
        if (is_struct(A) && variable_struct_exists(A, "_sky_drop_held") && variable_struct_get(A, "_sky_drop_held") == true){
            var _still_held = false;
            try {
                if (is_struct(_B) && variable_struct_exists(_B, "actor") && is_array(variable_struct_get(_B, "actor"))){
                    var _acts_sd = variable_struct_get(_B, "actor");
                    for (var _sdi = 0; _sdi < array_length(_acts_sd); ++_sdi){
                        var _carrier = _acts_sd[_sdi];
                        if (!is_struct(_carrier) || _carrier == A) continue;
                        if (!variable_struct_exists(_carrier, "_charging_move")) continue;
                        var _car_info = variable_struct_get(_carrier, "_charging_move");
                        if (!is_struct(_car_info)) continue;
                        if (!variable_struct_exists(_car_info, "sky_drop") || variable_struct_get(_car_info, "sky_drop") != true) continue;
                        var _tref_sd = undefined;
                        if (variable_struct_exists(_car_info, "target_actor")) _tref_sd = variable_struct_get(_car_info, "target_actor");
                        if (is_struct(_tref_sd) && _tref_sd == A){ _still_held = true; break; }
                        if (!is_struct(_tref_sd) && variable_struct_exists(_car_info, "target_index") && variable_struct_exists(A, "actor_index")){
                            var _ti_sd = variable_struct_get(_car_info, "target_index");
                            var _ai_sd = variable_struct_get(A, "actor_index");
                            if (is_real(_ti_sd) && is_real(_ai_sd) && _ti_sd == _ai_sd){ _still_held = true; break; }
                        }
                    }
                }
            } catch (e_sdchk) { _still_held = false; }
            if (!_still_held){
                try { variable_struct_set(A, "_sky_drop_held", undefined); } catch (e_sdclr1) {}
                try { if (variable_struct_exists(A, "_semi_invuln")) variable_struct_set(A, "_semi_invuln", undefined); } catch (e_sdclr2) {}
            } else {
                var _held_name = (variable_struct_exists(A, "name") ? string(variable_struct_get(A, "name")) : "The target");
                dialog_queue(_held_name + " is trapped in the air!");
                return "";
            }
        }
    } catch (e_sdh) {}

    // Helper: simple identifier-based ignore list used by metronome/assist/etc.
    function __is_meta_move_ignored(_mid){
        try {
            if (!is_real(_mid)) return true;
            if (!variable_global_exists("_moves") || !is_array(global._moves)) return true;
            var mv = global._moves[_mid];
            if (!is_struct(mv)) return true;
            var ident = "";
            if (variable_struct_exists(mv, "identifier")) ident = string(variable_struct_get(mv, "identifier"));
            ident = string_lower(ident);
            var ignore_ids = ["assist","metronome","sleep-talk","copycat","mimic","mirror-move","mirror-coat","sketch","me-first","protect","snatch","switcheroo","trick","struggle","encore","follow-me","quick-guard","feint","focus-punch","counter","covet","destiny-bond","detect","endure","chatter","helping-hand","thief","wide-guard","roar","whirlwind","uproar"];
            for (var ii=0; ii<array_length(ignore_ids); ++ii) if (string_lower(ignore_ids[ii]) == ident) return true;
            return false;
        } catch (e_i) { return true; }
    }

    // === META MOVES IMPLEMENTATION ===
    try {
    // METRONOME (118): select a random non-meta move from the global move list
        if (is_real(move_id) && move_id == 118){
            if (!__battle_consume_pp(A, move_slot)) return __battle_no_pp_msg(A);
            var candidates = [];
            if (variable_global_exists("_moves") && is_array(global._moves)){
                for (var mi=0; mi<array_length(global._moves); ++mi){
                    if (!is_struct(global._moves[mi])) continue;
                    // Skip invalid entries and our ignore list
                    if (__is_meta_move_ignored(mi)) continue;
                    // Skip moves the user already knows (Metronome must pick a move the user doesn't already have)
                    try {
                        if (is_struct(A) && variable_struct_exists(A, "moves") && is_array(variable_struct_get(A, "moves"))){
                            var _am = variable_struct_get(A, "moves");
                            var _known = false;
                            for (var _ki = 0; _ki < array_length(_am); ++_ki){ if (is_real(_am[_ki]) && _am[_ki] == mi) { _known = true; break; } }
                            if (_known) continue;
                        }
                    } catch (e_k) { /* defensive: ignore and continue */ }
                    // Skip moves with no identifier/name
                    var ok = true;
                    try { if (!variable_struct_exists(global._moves[mi], "identifier")) ok = false; } catch (e_ok) { ok = false; }
                    if (!ok) continue;
                    array_push(candidates, mi);
                }
            }
        if (array_length(candidates) == 0) return string((variable_struct_exists(A,"name")?variable_struct_get(A,"name"):"The user")) + " failed to use Metronome!";
            var pick = candidates[irandom(array_length(candidates)-1)];
            // Announce and replay the picked move
            try { variable_struct_set(A, "_suppress_last_move_record", true); } catch (e_sup) {}
            try { __battle_request_animation_safe(A, { type: "metronome" }); } catch (e_ma) {}
            // Apply the picked move and let the core apply path enqueue its own "used" message
            try { __battle_apply_move(_pid, A, D, pick); } catch (e_rp) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][metronome] apply failed: " + string(e_rp)); }
            try { variable_struct_set(A, "_suppress_last_move_record", false); } catch (e_sup2) {}
            return "";
        }

        // ASSIST (274): pick a random move known by an ally (other actors in the same slot)
    if (is_real(move_id) && move_id == 274){
        if (!__battle_consume_pp(A, move_slot)) return __battle_no_pp_msg(A);
            var _Bslot = __battle_ensure_slot(_pid);
            var ally_moves = [];
            try {
                if (is_struct(_Bslot) && variable_struct_exists(_Bslot, "actor") && is_array(variable_struct_get(_Bslot, "actor"))){
                    var acts = variable_struct_get(_Bslot, "actor");
                    for (var ai=0; ai<array_length(acts); ++ai){
                        var act = acts[ai];
                        if (!is_struct(act)) continue;
                        if (act == A) continue; // skip self
                        if (is_real(variable_struct_get(act, "hp_now")) && variable_struct_get(act, "hp_now") <= 0) continue; // fainted
                        if (!variable_struct_exists(act, "moves") || !is_array(variable_struct_get(act, "moves"))) continue;
                        var mlist = variable_struct_get(act, "moves");
                        for (var mi2=0; mi2<array_length(mlist); ++mi2){ var mv = mlist[mi2]; if (is_real(mv) && !__is_meta_move_ignored(mv)) array_push(ally_moves, mv); }
                    }
                }
            } catch (e_as) { ally_moves = []; }
            if (array_length(ally_moves) == 0) return __battle_impl_return_used(_pid, A, __battle_move_name(move_id), move_id);
            var pick2 = ally_moves[irandom(array_length(ally_moves)-1)];
        try { variable_struct_set(A, "_suppress_last_move_record", true); } catch (e_sup3) {}
            try { __battle_apply_move(_pid, A, D, pick2); } catch (e_ap) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][assist] apply failed: " + string(e_ap)); }
            try { variable_struct_set(A, "_suppress_last_move_record", false); } catch (e_sup4) {}
            return "";
        }

        // MIMIC (102): copy the last move used by the target (if valid)
    if (is_real(move_id) && move_id == 102){
        if (!__battle_consume_pp(A, move_slot)) return __battle_no_pp_msg(A);
            var cand = undefined;
            try {
                if (is_struct(D) && variable_struct_exists(D, "_last_moves") && is_array(variable_struct_get(D, "_last_moves"))){
                    var lr = variable_struct_get(D, "_last_moves");
                    for (var ii=array_length(lr)-1; ii>=0; --ii){ var rec = lr[ii]; if (!is_struct(rec) || !variable_struct_exists(rec, "move")) continue; var mv = rec.move; if (!is_real(mv)) continue; if (__is_meta_move_ignored(mv)) continue; cand = mv; break; }
                }
            } catch (e_mi) { cand = undefined; }
            if (!is_real(cand)) return __battle_impl_return_used(_pid, A, __battle_move_name(move_id), move_id);
            try { variable_struct_set(A, "_suppress_last_move_record", true); } catch (e_su) {}
            try { __battle_apply_move(_pid, A, D, cand); } catch (e_ca) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][mimic] failed: " + string(e_ca)); }
            try { variable_struct_set(A, "_suppress_last_move_record", false); } catch (e_su2) {}
            return "";
        }

        // MIRROR-MOVE (119): use the last move that targeted this user (if available)
    if (is_real(move_id) && move_id == 119){
            if (!__battle_consume_pp(A, move_slot)) return __battle_no_pp_msg(A);
            var cand2 = undefined;
            try {
                if (is_struct(A) && variable_struct_exists(A, "_last_moves") && is_array(variable_struct_get(A, "_last_moves"))){
                    var lr2 = variable_struct_get(A, "_last_moves");
                    for (var jj=array_length(lr2)-1; jj>=0; --jj){ var rec2 = lr2[jj]; if (!is_struct(rec2) || !variable_struct_exists(rec2, "move")) continue; var mv2 = rec2.move; if (!is_real(mv2)) continue; if (__is_meta_move_ignored(mv2)) continue; cand2 = mv2; break; }
                }
            } catch (e_mm2) { cand2 = undefined; }
            if (!is_real(cand2)) return __battle_impl_return_used(_pid, A, __battle_move_name(move_id), move_id);
            try { variable_struct_set(A, "_suppress_last_move_record", true); } catch (e_su3) {}
            try { __battle_apply_move(_pid, A, D, cand2); } catch (e_mr) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][mirror-move] failed: " + string(e_mr)); }
            try { variable_struct_set(A, "_suppress_last_move_record", false); } catch (e_su4) {}
            return "";
        }

        // SKETCH (166): permanently replace the user's selected move slot with the target's last used move
        if (is_real(move_id) && move_id == 166){
            if (!__battle_consume_pp(A, move_slot)) return __battle_no_pp_msg(A);
            if (!is_struct(A) || !is_real(move_slot)) return __battle_impl_return_used(_pid, A, __battle_move_name(move_id), move_id);
            var sketch_cand = undefined;
            try {
                if (is_struct(D) && variable_struct_exists(D, "_last_moves") && is_array(variable_struct_get(D, "_last_moves"))){
                    var lr3 = variable_struct_get(D, "_last_moves");
                    for (var kk=array_length(lr3)-1; kk>=0; --kk){ var rec3 = lr3[kk]; if (!is_struct(rec3) || !variable_struct_exists(rec3, "move")) continue; var mv3 = rec3.move; if (!is_real(mv3)) continue; if (__is_meta_move_ignored(mv3)) continue; sketch_cand = mv3; break; }
                }
            } catch (e_sk) { sketch_cand = undefined; }
            if (!is_real(sketch_cand)) return __battle_impl_return_used(_pid, A, __battle_move_name(move_id), move_id);
            // Replace the move in the user's moves array at slot
            try {
                if (!variable_struct_exists(A, "moves") || !is_array(variable_struct_get(A, "moves"))) variable_struct_set(A, "moves", []);
                var _alist = variable_struct_get(A, "moves");
                if (is_real(move_slot) && move_slot >= 0){
                    // Expand if necessary
                    while (array_length(_alist) <= move_slot) array_push(_alist, -1);
                    _alist[move_slot] = sketch_cand;
                    variable_struct_set(A, "moves", _alist);
                    try { __battle_request_animation_safe(A, { type: "sketch" }); } catch (e_sa) {}
                    return string((variable_struct_exists(A,"name")?variable_struct_get(A,"name"):"The user")) + " sketched " + __battle_move_name(sketch_cand) + "!";
                }
            } catch (e_rep) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][sketch] failed: " + string(e_rep)); }
            return __battle_impl_return_used(_pid, A, __battle_move_name(move_id), move_id);
        }

        // TRANSFORM (144): make the user copy the target's form/stats/moves roughly
        if (is_real(move_id) && move_id == 144){
            if (!__battle_consume_pp(A, move_slot)) return __battle_no_pp_msg(A);
            try {
                if (!is_struct(A) || !is_struct(D)) return __battle_impl_return_used(_pid, A, __battle_move_name(move_id), move_id);
                // Shallow copy of D.mon into A._transformed_mon so the renderer/logic can use it
                var srcmon = (variable_struct_exists(D, "mon") ? variable_struct_get(D, "mon") : undefined);
                if (is_struct(srcmon)){
                        // store original mon for revert if needed and assign transform mon reference
                        try { variable_struct_set(A, "_original_mon", (variable_struct_exists(A, "mon") ? variable_struct_get(A, "mon") : undefined)); } catch (e_om) {}
                        try { variable_struct_set(A, "mon", srcmon); } catch (e_setm) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][transform] warning: failed to set reference mon: " + string(e_setm)); }
                    variable_struct_set(A, "_transformed", true);
                    try { __battle_request_animation_safe(A, { type: "transform" }); } catch (e_tf) {}
                    return string((variable_struct_exists(A,"name")?variable_struct_get(A,"name"):"The user")) + " transformed into " + string(variable_struct_exists(D, "name") ? variable_struct_get(D, "name") : "the target") + "!";
                }
            } catch (e_t) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][transform] failed: " + string(e_t)); }
            return __battle_impl_return_used(_pid, A, __battle_move_name(move_id), move_id);
        }

        // ME-FIRST (382): attempt to use the target's move immediately when it is a damaging move
        if (is_real(move_id) && move_id == 382){
            if (!__battle_consume_pp(A, move_slot)) return __battle_no_pp_msg(A);
            var mf = undefined;
            try {
                // Prefer to inspect target's _last_moves for their most recent chosen move
                if (is_struct(D) && variable_struct_exists(D, "_last_moves") && is_array(variable_struct_get(D, "_last_moves"))){
                    var lr4 = variable_struct_get(D, "_last_moves");
                    for (var zz=array_length(lr4)-1; zz>=0; --zz){ var r4 = lr4[zz]; if (!is_struct(r4) || !variable_struct_exists(r4, "move")) continue; var mv4 = r4.move; if (!is_real(mv4)) continue; if (__is_meta_move_ignored(mv4)) continue; mf = mv4; break; }
                }
            } catch (e_mf) { mf = undefined; }
            if (!is_real(mf)) return __battle_impl_return_used(_pid, A, __battle_move_name(move_id), move_id);
            try { variable_struct_set(A, "_suppress_last_move_record", true); } catch (e_su5) {}
            try { __battle_apply_move(_pid, A, D, mf); } catch (e_mf2) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][me-first] apply failed: " + string(e_mf2)); }
            try { variable_struct_set(A, "_suppress_last_move_record", false); } catch (e_su6) {}
            return __battle_impl_return_used(_pid, A, __battle_move_name(mf), mf);
        }

        // COPYCAT (383): reuse the most recent move used in battle when available
        if (is_real(move_id) && move_id == 383){
            if (!__battle_consume_pp(A, move_slot)) return __battle_no_pp_msg(A);
            var _copied = __battle_find_copycat_candidate(_pid, A);
            if (is_real(_copied) && _copied == move_id) _copied = undefined;
            if (!is_real(_copied)){
                dialog_queue(string((variable_struct_exists(A,"name")?variable_struct_get(A,"name"):"The user")) + " failed to Copycat!");
                return __battle_impl_return_used(_pid, A, __battle_move_name(move_id), move_id);
            }
            try { variable_struct_set(A, "_suppress_last_move_record", true); } catch (e_surp) {}
            try { __battle_apply_move(_pid, A, D, _copied); } catch (e_cfail) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][copycat] replay failed: " + string(e_cfail)); }
            try { variable_struct_set(A, "_suppress_last_move_record", false); } catch (e_surp2) {}
            return "";
        }

        // SUBSTITUTE (164): spend 1/4 max HP to create a decoy that absorbs direct move damage
        if (is_real(move_id) && move_id == 164){
            if (!__battle_consume_pp(A, move_slot)) return __battle_no_pp_msg(A);
            __battle_record_move_usage(_pid, A, D, move_id, false);
            var _sub_used_msg = __battle_impl_return_used(_pid, A, __battle_move_name(move_id), move_id);
            if (!is_struct(A)) return _sub_used_msg;
            var _sub_hp_now = max(0, __battle_hp_now(A));
            var _sub_hp_max = max(1, __battle_hp_max(A));
            var _sub_cost = max(1, floor(_sub_hp_max / 4));
            var _already_sub = false;
            try { if (!is_undefined(status_system_has_status)) _already_sub = status_system_has_status(A, "substitute"); } catch (e_sub_has) { _already_sub = false; }
            if (_already_sub || _sub_hp_now <= _sub_cost){
                dialog_queue("But it failed!");
                return _sub_used_msg;
            }
            __battle_set_hp_now(A, _sub_hp_now - _sub_cost);
            var _sub_ok = false;
            try {
                if (!is_undefined(status_system_apply_status)) _sub_ok = status_system_apply_status(A, "substitute", { source: A });
                if (_sub_ok && !is_undefined(status_system_get)){
                    var _sub_inst = status_system_get(A, "substitute");
                    if (is_struct(_sub_inst)){
                        variable_struct_set(_sub_inst, "hp", _sub_cost);
                        variable_struct_set(_sub_inst, "hp_max", _sub_cost);
                    }
                }
            } catch (e_sub_apply) { _sub_ok = false; }
            if (_sub_ok){
                try { __battle_request_animation_safe(A, { type: "substitute" }); } catch (e_sub_anim) {}
                var _sub_name = (variable_struct_exists(A, "name") ? string(variable_struct_get(A, "name")) : "The user");
                dialog_queue(_sub_name + " made a substitute!");
            } else {
                __battle_set_hp_now(A, _sub_hp_now);
                dialog_queue("But it failed!");
            }
            return _sub_used_msg;
        }

        // HEAL BELL / AROMATHERAPY (effect 103): clear major status and confusion on the user's side party
        if (is_real(move_id) && (move_id == 215 || move_id == 312)){
            if (!__battle_consume_pp(A, move_slot)) return __battle_no_pp_msg(A);
            __battle_record_move_usage(_pid, A, D, move_id, false);
            var _heal_party_used_msg = __battle_impl_return_used(_pid, A, __battle_move_name(move_id), move_id);
            var _clear_ids = ["sleep", "freeze", "burn", "poison", "toxic", "paralysis", "paralyze", "confusion"];
            var _side_idx = 0;
            try {
                if (is_struct(A) && variable_struct_exists(A, "actor_index") && is_real(variable_struct_get(A, "actor_index"))) _side_idx = __battle_field_side_index_for_actor(variable_struct_get(A, "actor_index"));
            } catch (e_hpside) { _side_idx = 0; }
            var _cleared_any = false;
            var _clear_statuses_on_mon = function(_mon_ref){
                var _did_any = false;
                if (!is_struct(_mon_ref) || is_undefined(status_system_clear_status)) return false;
                for (var _ci = 0; _ci < array_length(_clear_ids); ++_ci){
                    try {
                        if (status_system_clear_status(_mon_ref, _clear_ids[_ci])) _did_any = true;
                    } catch (e_hclear) {}
                }
                return _did_any;
            };
            try {
                var _Bslot_hp = __battle_ensure_slot(_pid);
                if (is_struct(_Bslot_hp) && variable_struct_exists(_Bslot_hp, "actor") && is_array(variable_struct_get(_Bslot_hp, "actor"))){
                    var _acts_hp = variable_struct_get(_Bslot_hp, "actor");
                    for (var _ai_hp = 0; _ai_hp < array_length(_acts_hp); ++_ai_hp){
                        var _act_hp = _acts_hp[_ai_hp];
                        if (!is_struct(_act_hp)) continue;
                        var _act_side = __battle_field_side_index_for_actor(_ai_hp);
                        if (_act_side != _side_idx) continue;
                        if (_clear_statuses_on_mon(_act_hp)) _cleared_any = true;
                    }
                }
            } catch (e_hacts) {}
            try {
                if (_side_idx == 0){
                    var _party_mons = party_model_get_mons(_pid);
                    if (is_array(_party_mons)){
                        for (var _pm = 0; _pm < array_length(_party_mons); ++_pm){
                            if (_clear_statuses_on_mon(_party_mons[_pm])) _cleared_any = true;
                        }
                    }
                } else {
                    var _Bslot_enemy = __battle_ensure_slot(_pid);
                    if (is_struct(_Bslot_enemy) && variable_struct_exists(_Bslot_enemy, "_trainer_party") && is_array(variable_struct_get(_Bslot_enemy, "_trainer_party"))){
                        var _tparty = variable_struct_get(_Bslot_enemy, "_trainer_party");
                        for (var _tp = 0; _tp < array_length(_tparty); ++_tp){
                            if (_clear_statuses_on_mon(_tparty[_tp])) _cleared_any = true;
                        }
                    }
                }
            } catch (e_hparty) {}
            try {
                if (move_id == 215) dialog_queue("A bell chimed!");
                else dialog_queue("A soothing aroma wafted through the area!");
                if (_cleared_any) dialog_queue("The party's status was healed!");
            } catch (e_hmsg) {}
            return _heal_party_used_msg;
        }
    } catch (e_metaAll) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][meta_moves] handler error: " + string(e_metaAll)); }

    // Debug: log selection immediately so we can trace Horn Drill choices
    try {
        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){
            // Debug-only: log to console rather than opening a player dialog
            try { show_debug_message("[battle_select][debug] pid=" + string(_pid) + ", slot=" + string(move_slot) + ", mv_selected=" + string(move_id) + ", actor.moves[slot]=" + string((is_struct(A) && is_array(variable_struct_get(A, "moves")) && is_real(move_slot) && move_slot >=0 && move_slot < array_length(variable_struct_get(A, "moves")) ? variable_struct_get(A, "moves")[move_slot] : "?")) ); } catch (e_sd) {}
        }
    } catch (e_dbgsel) {}

    // Record per-target last-move for Copycat's reference. Some move impls
    // bypass __battle_apply_move; we therefore record here centrally so
    // Copycat can find moves regardless of which low-level path was used.
    try {
        var _suppress = false;
        try { if (is_struct(A) && variable_struct_exists(A, "_suppress_last_move_record") && variable_struct_get(A, "_suppress_last_move_record") == true) _suppress = true; } catch (e_sp) { _suppress = false; }
        // Only record when we have an attacker and defender, move_id is real,
        // it's not a Copycat meta-move, and suppression isn't active.
        if (!_suppress && is_struct(A) && is_struct(D) && is_real(move_id)){
            var skip_rec = false;
            try { if (is_array(global._moves) && is_struct(global._moves[move_id]) && variable_struct_exists(global._moves[move_id], "identifier") && string_lower(variable_struct_get(global._moves[move_id], "identifier")) == "copycat") skip_rec = true; } catch (e_sr) { skip_rec = false; }
            if (!skip_rec){
                try {
                    if (!variable_struct_exists(D, "_last_moves") || !is_array(variable_struct_get(D, "_last_moves"))) variable_struct_set(D, "_last_moves", []);
                    var _arr = variable_struct_get(D, "_last_moves");
                    array_push(_arr, { move: move_id, src: A, ts: current_time });
                    if (array_length(_arr) > 8){ var _start = array_length(_arr) - 8; var _new = []; for (var _k=_start; _k < array_length(_arr); ++_k) array_push(_new, _arr[_k]); _arr = _new; }
                    variable_struct_set(D, "_last_moves", _arr);
                    // Keep the global scalar in sync for the simple Copycat implementation
                    try { global.lastMoveUsed_ID = move_id; } catch (e_g) {}
                    if (variable_global_exists("DATA_DEBUG_VERBOSE") && global.DATA_DEBUG_VERBOSE) show_debug_message("[battle][record_last_move][impl] target=" + string(variable_struct_exists(D, "name") ? variable_struct_get(D, "name") : "?") + " move=" + string(move_id) + " src=" + string(variable_struct_exists(A, "name") ? variable_struct_get(A, "name") : "?") + " ts=" + string(current_time) + " (global.lastMoveUsed_ID set)");
                } catch (e_r) { if (variable_global_exists("DATA_DEBUG_VERBOSE") && global.DATA_DEBUG_VERBOSE) show_debug_message("[battle][record_last_move][impl] failed: " + string(e_r)); }
            }
        }
    } catch (e_allrec) { if (variable_global_exists("DATA_DEBUG_VERBOSE") && global.DATA_DEBUG_VERBOSE) show_debug_message("[battle][record_last_move][impl] outer error: " + string(e_allrec)); }

    // minimal status check to avoid crashes during refactor
    try {
        if (!is_undefined(status_system_has_status) && is_struct(A) && status_system_has_status(A, "sleep")){
            // Request blocked animation, but do NOT enqueue another dialog because
            // status_system_apply_status already queues the canonical 'fell asleep!'
            __battle_request_animation_safe(A, { type: "status_blocked", status: "sleep" });
            return "";
        }
    } catch (e) { }

    // flinch: if the actor was flinched by a previous hit, they lose their turn
    try {
        if (is_struct(A) && variable_struct_exists(A, "_flinched") && variable_struct_get(A, "_flinched") == true){
            // Debug: report pre-clear state
            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){
                try {
                    var _an = (variable_struct_exists(A,"name")?variable_struct_get(A,"name"):"<no-name>");
                    var _has_wrap = variable_struct_exists(A, "_flinched") && variable_struct_get(A, "_flinched") == true;
                    var _inner_has = false;
                    if (variable_struct_exists(A, "mon") && is_struct(variable_struct_get(A, "mon"))){
                        var _inner_m = variable_struct_get(A, "mon");
                        _inner_has = (variable_struct_exists(_inner_m, "_flinched") && variable_struct_get(_inner_m, "_flinched") == true);
                    }
                    show_debug_message("[battle][flinch][exec] pre-clear actor='"+string(_an)+"' wrapper_flag="+string(_has_wrap)+" inner_flag="+string(_inner_has));
                } catch (e_dbgp) {}
            }
            // clear the flag and show a flinch animation/dialog
            try { variable_struct_set(A, "_flinched", undefined); } catch (e_fclr) {}
            // also clear inner mon flag if present
            try {
                if (variable_struct_exists(A, "mon") && is_struct(variable_struct_get(A, "mon"))){
                    var _inner_m2 = variable_struct_get(A, "mon");
                    try { variable_struct_set(_inner_m2, "_flinched", undefined); } catch (e_ic) {}
                }
            } catch (e_in2) {}
            try { __battle_request_animation_safe(A, { type: "flinch" }); } catch (e_fa) {}
            try { dialog2p_show_now(_pid, string(variable_struct_exists(A,"name")?variable_struct_get(A,"name"):"The user") + " flinched!"); } catch (e_fd) {}
            // Debug: report post-clear state
            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){
                try {
                    var _an2 = (variable_struct_exists(A,"name")?variable_struct_get(A,"name"):"<no-name>");
                    var _has_wrap2 = (variable_struct_exists(A, "_flinched") && variable_struct_get(A, "_flinched") == true);
                    var _inner_has2 = false;
                    if (variable_struct_exists(A, "mon") && is_struct(variable_struct_get(A, "mon"))){
                        var _inner_m3 = variable_struct_get(A, "mon");
                        _inner_has2 = (variable_struct_exists(_inner_m3, "_flinched") && variable_struct_get(_inner_m3, "_flinched") == true);
                    }
                    show_debug_message("[battle][flinch][exec] post-clear actor='"+string(_an2)+"' wrapper_flag="+string(_has_wrap2)+" inner_flag="+string(_inner_has2));
                } catch (e_dbg2) {}
            }
            return "";
        }
    } catch (e_fl) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][flinch] check failed: " + string(e_fl)); }

    // Prevent the actor from selecting a move that is currently disabled.
    var _disabledMoveA = undefined;
    try { if (is_struct(A) && variable_struct_exists(A, "sys_disabledMove")) _disabledMoveA = variable_struct_get(A, "sys_disabledMove"); } catch (e_dmA) { _disabledMoveA = undefined; }
    if (is_real(_disabledMoveA) && is_real(move_id) && _disabledMoveA == move_id){
        var _aname_disable_block = (is_struct(A) && variable_struct_exists(A, "name") ? string(variable_struct_get(A, "name")) : "The user");
        dialog_queue(_aname_disable_block + " is disabled and can't use that move!");
        return "";
    }

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

    if (!__battle_consume_pp(A, move_slot)) return __battle_no_pp_msg(A);

    var mv_name = (is_undefined(move_id) ? "the move" : __battle_move_name(move_id));
    if (is_real(move_id) && move_id == 100){
        __battle_record_move_usage(_pid, A, D, move_id, false);
        var _teleport_used_msg = __battle_impl_return_used(_pid, A, mv_name, move_id);
        var _teleport_slot = __battle_ensure_slot(_pid);
        var _teleport_mode = "wild";
        try {
            if (is_struct(_teleport_slot) && variable_struct_exists(_teleport_slot, "_battle_mode")){
                _teleport_mode = string_lower(string(variable_struct_get(_teleport_slot, "_battle_mode")));
            }
        } catch (e_tp_mode) { _teleport_mode = "wild"; }
        if (_teleport_mode != "trainer"){
            try { variable_struct_set(_teleport_slot, "result", "escaped"); } catch (e_tp_result) {}
            try { variable_struct_set(_teleport_slot, "_pending_close", true); } catch (e_tp_close) {}
            dialog_queue("Got away safely!");
        } else {
            dialog_queue("But it failed!");
        }
        return _teleport_used_msg;
    }
    if (is_real(move_id) && move_id == 187){
        __battle_record_move_usage(_pid, A, D, move_id, false);
        var _belly_used_msg = __battle_impl_return_used(_pid, A, mv_name, move_id);
        var _belly_hp = __battle_hp_now(A);
        var _belly_max = max(1, __battle_hp_max(A));
        var _belly_cost = max(1, floor(_belly_max / 2));
        var _belly_stage = 0;
        try {
            if (is_struct(A) && variable_struct_exists(A, "_stages") && is_struct(variable_struct_get(A, "_stages"))){
                var _belly_stages_read = variable_struct_get(A, "_stages");
                if (variable_struct_exists(_belly_stages_read, "atk") && is_real(variable_struct_get(_belly_stages_read, "atk"))) _belly_stage = variable_struct_get(_belly_stages_read, "atk");
            }
        } catch (e_belly_read) { _belly_stage = 0; }
        if (_belly_hp <= _belly_cost || _belly_stage >= 6){
            dialog_queue("But it failed!");
            return _belly_used_msg;
        }
        if (!variable_struct_exists(A, "_stages") || !is_struct(variable_struct_get(A, "_stages"))) variable_struct_set(A, "_stages", {});
        var _belly_stages = variable_struct_get(A, "_stages");
        variable_struct_set(_belly_stages, "atk", 6);
        variable_struct_set(A, "_stages", _belly_stages);
        __battle_set_hp_now(A, max(1, _belly_hp - _belly_cost));
        try { __battle_request_animation_safe(A, { type: "stat_change", stat: "atk", change: 6 }); } catch (e_belly_anim) {}
        var _belly_name = (is_struct(A) && variable_struct_exists(A, "name")) ? string(variable_struct_get(A, "name")) : "The user";
        dialog_queue(_belly_name + " cut its HP and maximized its Attack!");
        return _belly_used_msg;
    }
    if (is_real(move_id) && move_id == 244){
        __battle_record_move_usage(_pid, A, D, move_id, false);
        var _psych_used_msg = __battle_impl_return_used(_pid, A, mv_name, move_id);
        if (is_struct(A) && is_struct(D)){
            var _copied_stages = {};
            try {
                if (variable_struct_exists(D, "_stages") && is_struct(variable_struct_get(D, "_stages"))){
                    _copied_stages = __battle_clone_stage_struct(variable_struct_get(D, "_stages"));
                }
            } catch (e_psych_clone) { _copied_stages = {}; }
            variable_struct_set(A, "_stages", _copied_stages);
            try { __battle_request_animation_safe(A, { type: "stat_change", stat: "all", change: 0 }); } catch (e_psych_anim) {}
            var _psych_name = (variable_struct_exists(A, "name") ? string(variable_struct_get(A, "name")) : "The user");
            dialog_queue(_psych_name + " copied the target's stat changes!");
        } else {
            dialog_queue("But it failed!");
        }
        return _psych_used_msg;
    }
    if (is_real(move_id) && move_id == 226){
        __battle_record_move_usage(_pid, A, D, move_id, false);
        var _bp_used_msg = __battle_impl_return_used(_pid, A, mv_name, move_id);
        var _bp_slot = __battle_ensure_slot(_pid);
        var _bp_stages = {};
        try {
            if (is_struct(A) && variable_struct_exists(A, "_stages") && is_struct(variable_struct_get(A, "_stages"))) _bp_stages = __battle_clone_stage_struct(variable_struct_get(A, "_stages"));
        } catch (e_bp_clone) { _bp_stages = {}; }
        if (is_struct(_bp_slot)) variable_struct_set(_bp_slot, "_baton_pass_pending", { actor_index: actor_idx, stages: _bp_stages });

        if (actor_idx == 0){
            var _P_bp = (is_undefined(party_ensure) ? undefined : party_ensure(_pid));
            var _can_pass = false;
            if (is_struct(_P_bp) && variable_struct_exists(_P_bp, "mons") && is_array(variable_struct_get(_P_bp, "mons"))){
                var _bp_mons = variable_struct_get(_P_bp, "mons");
                var _self_mon = (is_struct(A) && variable_struct_exists(A, "mon") && is_struct(variable_struct_get(A, "mon"))) ? variable_struct_get(A, "mon") : A;
                for (var _bp_i = 0; _bp_i < array_length(_bp_mons); ++_bp_i){
                    var _bp_mon = _bp_mons[_bp_i];
                    if (!is_struct(_bp_mon) || _bp_mon == _self_mon) continue;
                    var _bp_hp = __battle_hp_now(_bp_mon);
                    if (is_real(_bp_hp) && _bp_hp > 0){ _can_pass = true; break; }
                }
            }
            if (!_can_pass){
                dialog_queue("But it failed!");
                try { if (is_struct(_bp_slot)) variable_struct_set(_bp_slot, "_baton_pass_pending", undefined); } catch (e_bp_fail_clear) {}
                return _bp_used_msg;
            }
            if (!is_undefined(party_open) && is_struct(_P_bp)){
                party_open(_pid);
                try { if (!is_undefined(party_set_swap_mode_impl)) party_set_swap_mode_impl(_pid, true, false); } catch (e_bp_swap) {}
                try { variable_struct_set(_P_bp, "_battle_baton_pass_mode", true); } catch (e_bp_mode) {}
                try { variable_struct_set(_P_bp, "lock", 0); } catch (e_bp_lock) {}
            } else {
                dialog_queue("But it failed!");
                try { if (is_struct(_bp_slot)) variable_struct_set(_bp_slot, "_baton_pass_pending", undefined); } catch (e_bp_clear2) {}
            }
            return _bp_used_msg;
        }

        if (actor_idx == 1){
            var _next_bp = -1;
            try { _next_bp = __battle_trainer_next_alive_index(_bp_slot, (variable_struct_exists(_bp_slot, "_trainer_party_active_idx") ? variable_struct_get(_bp_slot, "_trainer_party_active_idx") : -1)); } catch (e_bp_next) { _next_bp = -1; }
            if (is_real(_next_bp) && _next_bp >= 0 && !is_undefined(__battle_trainer_perform_switch_action)){
                try { __battle_trainer_perform_switch_action(_pid, _next_bp, { move_id: move_id, baton_pass: true }); } catch (e_bp_enemy) { dialog_queue("But it failed!"); }
            } else {
                dialog_queue("But it failed!");
                try { if (is_struct(_bp_slot)) variable_struct_set(_bp_slot, "_baton_pass_pending", undefined); } catch (e_bp_clear3) {}
            }
            return _bp_used_msg;
        }
    }

    var mv_power = 0;
    try { mv_power = __battle_move_power(move_id, A, D); } catch (e) { mv_power = 0; }
    try {
        if (is_real(move_id) && move_id == 228 && is_struct(_step) && variable_struct_exists(_step, "pursuit_switching") && variable_struct_get(_step, "pursuit_switching") == true){
            mv_power = max(1, floor(mv_power * 2));
        }
    } catch (e_pursuit_power) {}

    if (_is_guard_like){
        __battle_record_move_usage(_pid, A, D, move_id, false);
        __battle_apply_status_move(_pid, A, D, move_id);
        return __battle_impl_return_used(_pid, A, mv_name, move_id);
    }

    var _is_disable_move = (is_real(move_id) && move_id == 50) || (_moveIdent == "disable");
    if (_is_disable_move){
        __battle_record_move_usage(_pid, A, D, move_id, false);
        var _disable_used_msg = __battle_impl_return_used(_pid, A, mv_name, move_id);
        var _disabled_success = __battle_apply_disable(_pid, A, D, move_id);
        if (_disabled_success){
            var _tname_disable = (is_struct(D) && variable_struct_exists(D, "name") ? string(variable_struct_get(D, "name")) : "The target");
            dialog_queue(_tname_disable + " was disabled!");
        } else {
            dialog_queue("But it failed!");
        }
        return _disable_used_msg;
    }

    if (is_real(move_id) && move_id == 116){
        if (!__battle_consume_pp(A, move_slot)) return __battle_no_pp_msg(A);
        __battle_record_move_usage(_pid, A, D, move_id, false);
        var _focus_used_msg = __battle_impl_return_used(_pid, A, mv_name, move_id);
        var _focus_applied = false;
        try {
            if (is_struct(A)){
                var _focus_level = (variable_struct_exists(A, "_focus_energy_level") && is_real(variable_struct_get(A, "_focus_energy_level"))) ? floor(variable_struct_get(A, "_focus_energy_level")) : 0;
                if (_focus_level <= 0){
                    variable_struct_set(A, "_focus_energy_level", 1);
                    _focus_applied = true;
                }
            }
        } catch (e_focus_set) { _focus_applied = false; }
        if (_focus_applied){
            try { __battle_request_animation_safe(A, { type: "focus_energy" }); } catch (e_focus_anim) {}
            var _focus_name = (is_struct(A) && variable_struct_exists(A, "name")) ? string(variable_struct_get(A, "name")) : "The user";
            dialog_queue(_focus_name + " is getting pumped!");
        } else {
            dialog_queue("But it failed!");
        }
        return _focus_used_msg;
    }

    if (is_real(move_id) && move_id == 156){
        if (!__battle_consume_pp(A, move_slot)) return __battle_no_pp_msg(A);
        __battle_record_move_usage(_pid, A, D, move_id, false);
        var _rest_used_msg = __battle_impl_return_used(_pid, A, mv_name, move_id);
        if (!is_struct(A)) return _rest_used_msg;
        var _rest_hp_now = __battle_hp_now(A);
        var _rest_hp_max = max(1, __battle_hp_max(A));
        var _rest_needs_heal = (_rest_hp_now < _rest_hp_max);
        var _rest_has_major = false;
        try {
            if (!is_undefined(status_system_has_status)){
                var _rest_major = ["poison", "toxic", "burn", "freeze", "paralysis", "paralyze"];
                for (var _rs = 0; _rs < array_length(_rest_major); ++_rs){
                    if (status_system_has_status(A, _rest_major[_rs])){ _rest_has_major = true; break; }
                }
            }
        } catch (e_rest_check) { _rest_has_major = false; }
        if (!_rest_needs_heal && !_rest_has_major){
            dialog_queue("But it failed!");
            return _rest_used_msg;
        }
        try {
            if (!is_undefined(status_system_clear_status)){
                var _rest_clear = ["poison", "toxic", "burn", "freeze", "paralysis", "paralyze"];
                for (var _rc = 0; _rc < array_length(_rest_clear); ++_rc){
                    status_system_clear_status(A, _rest_clear[_rc]);
                }
            }
        } catch (e_rest_clear) {}
        var _rest_sleep_ok = false;
        try {
            if (!is_undefined(status_system_apply_status)) _rest_sleep_ok = status_system_apply_status(A, "sleep", { duration: 2, source: A });
        } catch (e_rest_sleep) { _rest_sleep_ok = false; }
        if (!_rest_sleep_ok){
            dialog_queue("But it failed!");
            return _rest_used_msg;
        }
        var _rest_heal = max(0, _rest_hp_max - _rest_hp_now);
        if (_rest_heal > 0){
            try { __battle_set_hp_now(A, _rest_hp_max); } catch (e_rest_hp) {}
            try { __battle_clear_fainted_if_healed(A); } catch (e_rest_faint) {}
            try {
                variable_struct_set(A, "_hp_lerp_from", _rest_hp_now);
                variable_struct_set(A, "_hp_lerp_to", _rest_hp_max);
                variable_struct_set(A, "_hp_lerp_start_ms", current_time);
                variable_struct_set(A, "_hp_lerp_dur", 400);
                variable_struct_set(A, "_hp_lerp_active", true);
                if (variable_struct_exists(A, "mon") && is_struct(variable_struct_get(A, "mon"))){
                    var _rest_mon = variable_struct_get(A, "mon");
                    variable_struct_set(_rest_mon, "_hp_lerp_from", _rest_hp_now);
                    variable_struct_set(_rest_mon, "_hp_lerp_to", _rest_hp_max);
                    variable_struct_set(_rest_mon, "_hp_lerp_start_ms", variable_struct_get(A, "_hp_lerp_start_ms"));
                    variable_struct_set(_rest_mon, "_hp_lerp_dur", variable_struct_get(A, "_hp_lerp_dur"));
                    variable_struct_set(_rest_mon, "_hp_lerp_active", true);
                }
            } catch (e_rest_lerp) {}
            try { __battle_request_animation_safe(A, { type: "heal", amount: _rest_heal }); } catch (e_rest_anim) {}
        }
        var _rest_name = (variable_struct_exists(A, "name") ? string(variable_struct_get(A, "name")) : "The user");
        dialog_queue(_rest_name + " went to sleep and restored its health!");
        return _rest_used_msg;
    }

    // Generic two-turn move handling (charge then strike). This handles common
    // Gen3 two-turn moves like Razor Wind, SolarBeam, Skull Bash, Sky Attack,
    // Fly, Dig, Dive, Bounce, etc. First use sets a charging flag on the actor
    // (_charging_move) and returns; the second use with the same move_id clears
    // the flag and proceeds to actually perform the attack.
    try {
        if (is_real(move_id) && is_struct(A)){
            var two_ids = [13,19,76,91,130,143,291,340,467,507,566,669]; // razor-wind, fly, solar-beam, dig, skull-bash, sky-attack, dive, bounce, shadow-force, sky-drop, phantom-force, solar-blade
            var is_two = false;
            for (var _ti=0; _ti<array_length(two_ids); ++_ti) if (two_ids[_ti] == move_id) { is_two = true; break; }
            if (is_two && (move_id == 76 || move_id == 669)){
                try {
                    var _solar_weather = __battle_get_weather(_pid);
                    if (__battle_weather_is_active(_solar_weather)){
                        var _solar_wid = __battle_weather_get_normalized_id(_solar_weather);
                        if (_solar_wid == "sun" || _solar_wid == "harsh-sun") is_two = false;
                    }
                } catch (e_solar_weather) {}
            }
            // Special-case: Thrash / Rollout-like behavior using shared locked-move state.
            if (is_real(move_id) && move_id == 37){
                var _locked = (variable_struct_exists(A, "_locked_move") ? variable_struct_get(A, "_locked_move") : undefined);
                // If not previously locked, initialize lock state (2..3 turns inclusive)
                if (!is_struct(_locked) || !variable_struct_exists(_locked, "move_id") || variable_struct_get(_locked, "move_id") != 37){
                    var dur = irandom_range(2,3);
                    variable_struct_set(A, "_locked_move", { move_id: 37, remaining: dur, apply_confuse_on_end: true });
                }
            }
            if (is_real(move_id) && move_id == 205){
                var _locked_roll = (variable_struct_exists(A, "_locked_move") ? variable_struct_get(A, "_locked_move") : undefined);
                if (!is_struct(_locked_roll) || !variable_struct_exists(_locked_roll, "move_id") || variable_struct_get(_locked_roll, "move_id") != 205){
                    variable_struct_set(A, "_locked_move", { move_id: 205, remaining: 5, apply_confuse_on_end: false });
                    if (!variable_struct_exists(A, "_rollout_mul") || !is_real(variable_struct_get(A, "_rollout_mul"))) variable_struct_set(A, "_rollout_mul", 1);
                }
            }
            if (is_two){
                var charging = (variable_struct_exists(A, "_charging_move") ? variable_struct_get(A, "_charging_move") : undefined);
                // If actor is already charging this same move, consume the charge and continue
                if (is_struct(charging) && variable_struct_exists(charging, "move_id") && variable_struct_get(charging, "move_id") == move_id){
                    var _charge_info = charging;
                    // Use stored target_index from the charging record (defensive: override current target_idx)
                    try {
                        var _stored_tidx = (variable_struct_exists(charging, "target_index") ? variable_struct_get(charging, "target_index") : undefined);
                        if (is_real(_stored_tidx)){
                            target_idx = _stored_tidx;
                            // Recompute D from the actor array so subsequent code targets the correct defender
                            try {
                                if (is_array(__acts) && is_real(target_idx) && target_idx >= 0 && target_idx < array_length(__acts)){
                                    D = __acts[target_idx];
                                }
                            } catch (e_recomp) {}
                        }
                    } catch (e_st) {}

                    // Clear charging state and proceed with normal attack
                    variable_struct_set(A, "_charging_move", undefined);
                    // Clear semi-invulnerable phase now that the strike resolves
                    try { if (variable_struct_exists(A, "_semi_invuln")) variable_struct_set(A, "_semi_invuln", undefined); } catch (e_clrsi) {}
                    // Release any sky drop-held target so it can act again
                    try {
                        if (is_struct(_charge_info) && variable_struct_exists(_charge_info, "sky_drop") && variable_struct_get(_charge_info, "sky_drop") == true){
                            var _release_tgt = undefined;
                            if (variable_struct_exists(_charge_info, "target_actor") && is_struct(variable_struct_get(_charge_info, "target_actor"))){
                                _release_tgt = variable_struct_get(_charge_info, "target_actor");
                            } else if (variable_struct_exists(_charge_info, "target_index") && is_array(__acts)){
                                var _release_idx = variable_struct_get(_charge_info, "target_index");
                                if (is_real(_release_idx) && _release_idx >= 0 && _release_idx < array_length(__acts)){
                                    _release_tgt = __acts[_release_idx];
                                }
                            }
                            if (!is_struct(_release_tgt) && is_struct(D)) _release_tgt = D;
                            if (is_struct(_release_tgt)){
                                try { if (variable_struct_exists(_release_tgt, "_semi_invuln")) variable_struct_set(_release_tgt, "_semi_invuln", undefined); } catch (e_rel1) {}
                                try { if (variable_struct_exists(_release_tgt, "_sky_drop_held")) variable_struct_set(_release_tgt, "_sky_drop_held", undefined); } catch (e_rel2) {}
                            }
                        }
                    } catch (e_release) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][two-turn] failed to release sky-drop target: " + string(e_release)); }
                    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][two-turn] " + string(variable_struct_get(A, "name")) + " completes charge for move=" + string(move_id) + ", stored_target=" + string(_stored_tidx) + ", resolved_target_idx=" + string(target_idx));
                } else {
                    // Start charging: store move and intended target index so the second
                    // turn can reference it. PP already consumed earlier.
                        var _charge_rec = { move_id: move_id, target_index: target_idx };
                        if (move_id == 507){
                            try { variable_struct_set(_charge_rec, "sky_drop", true); } catch (e_sdflag) {}
                        }
                        if (is_struct(D)){
                            try { variable_struct_set(_charge_rec, "target_actor", D); } catch (e_tar) {}
                        }
                        variable_struct_set(A, "_charging_move", _charge_rec);
                        if (move_id == 130){
                            try {
                                if (!variable_struct_exists(A, "_stages") || !is_struct(variable_struct_get(A, "_stages"))) variable_struct_set(A, "_stages", {});
                                var _skull_stages = variable_struct_get(A, "_stages");
                                var _skull_prev = (variable_struct_exists(_skull_stages, "def") && is_real(variable_struct_get(_skull_stages, "def"))) ? variable_struct_get(_skull_stages, "def") : 0;
                                variable_struct_set(_skull_stages, "def", clamp(_skull_prev + 1, -6, 6));
                                variable_struct_set(A, "_stages", _skull_stages);
                                dialog_queue((variable_struct_exists(A, "name") ? string(variable_struct_get(A, "name")) : "The user") + "'s Defense rose!");
                            } catch (e_skull_def) {}
                        }
                        // If this is a semi-invulnerable two-turn move (fly/dig/dive/bounce/sky-attack),
                        // mark the actor so other move handlers can apply the special rules.
                        try {
                            var _phase = undefined;
                            if (move_id == 19) _phase = "fly";           // Fly
                            else if (move_id == 91) _phase = "dig";      // Dig
                            else if (move_id == 291) _phase = "dive";    // Dive
                            else if (move_id == 340) _phase = "bounce";  // Bounce
                            else if (move_id == 143) _phase = "fly";     // Sky Attack behaves like fly for interactions
                            else if (move_id == 467 || move_id == 566) _phase = "vanish"; // Shadow/Phantom Force vanish
                            else if (move_id == 507) _phase = "skydrop"; // Sky Drop lifts target
                            if (!is_undefined(_phase)){
                                variable_struct_set(A, "_semi_invuln", _phase);
                                if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][two-turn] set _semi_invuln=" + string(_phase) + " for " + string(variable_struct_exists(A, "name") ? variable_struct_get(A, "name") : "?"));
                                if (_phase == "skydrop" && is_struct(D)){
                                    try {
                                        variable_struct_set(D, "_semi_invuln", "skydrop");
                                        variable_struct_set(D, "_sky_drop_held", true);
                                    } catch (e_sdt) {}
                                }
                            }
                        } catch (e_si) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][two-turn] failed to set _semi_invuln: " + string(e_si)); }
                    // Request a charge animation if available and return the 'used' dialog
                    try { __battle_request_animation_safe(A, { type: "charge", move_id: move_id }); } catch (e_ch) {}
                    return __battle_impl_return_used(_pid, A, mv_name);
                }
            }
        }
    } catch (e_two){ if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][two-turn] handler error: " + string(e_two)); }

    // Locked-move enforcement: Thrash and Rollout both force repeated use while active.
    try {
        if (is_struct(A) && is_real(move_id) && move_id != 37 && move_id != 205){
            var _lm = (variable_struct_exists(A, "_locked_move") ? variable_struct_get(A, "_locked_move") : undefined);
            if (is_struct(_lm) && variable_struct_exists(_lm, "move_id") && is_real(variable_struct_get(_lm, "move_id")) && is_real(variable_struct_get(_lm, "remaining")) && variable_struct_get(_lm, "remaining") > 0){
                var _locked_move_id = variable_struct_get(_lm, "move_id");
                if (_locked_move_id == 37 || _locked_move_id == 205){
                    move_id = _locked_move_id;
                    mv_name = __battle_move_name(move_id);
                    mv_power = __battle_move_power(move_id, A, D);
                }
            }
        }
    } catch (e_tl) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][thrash] enforcement error: " + string(e_tl)); }

    // Fury Cutter resets when the user executes any other move, including status moves.
    try {
        if (is_struct(A) && is_real(move_id) && move_id != 210 && variable_struct_exists(A, "_fury_cutter_mul")){
            variable_struct_set(A, "_fury_cutter_mul", 1);
            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][fury] non-fury move reset: set _fury_cutter_mul=1");
        }
    } catch (e_fc_reset) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][fury] non-fury reset failed: " + string(e_fc_reset)); }

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
                        return __battle_impl_return_used(_pid, A, mv_name);
                    }
                }
                // If nothing to reflect, play a blocked/miss animation
                try { __battle_request_animation_safe(A, { type: "blocked", reason: "counter_none" }); } catch (e_bn) {}
                return __battle_impl_return_used(_pid, A, mv_name, move_id);
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
                        return __battle_impl_return_used(_pid, A, mv_name);
                    }
                }
                try { __battle_request_animation_safe(A, { type: "blocked", reason: "mirror_none" }); } catch (e_bn2) {}
                return __battle_impl_return_used(_pid, A, mv_name, move_id);
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
                        return __battle_impl_return_used(_pid, A, mv_name);
                    }
                }
                try { __battle_request_animation_safe(A, { type: "blocked", reason: "metal_none" }); } catch (e_mb2) {}
                return __battle_impl_return_used(_pid, A, mv_name);
            }
        }
    } catch (e_cm) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][counter] handler error: " + string(e_cm)); }

    // Allow moves with power > 0 OR explicit OHKO moves (e.g. Horn Drill) to proceed
    // to the damage application path. Some OHKO moves have no power value but
    // must still run the OHKO semantic branch in __battle_apply_move_damage.
    if (is_struct(D)){
        // Detect multi-hit moves via move meta (min_hits/max_hits). If multi-hit,
        // apply first hit now and schedule remaining hits in _pending_multi_hit so
        // the engine can show per-hit dialogs between hits (Emerald style).
        var mm_local = undefined;
        try { mm_local = __battle_get_move_meta(move_id); } catch (e_mm) { mm_local = undefined; }
        // Detect OHKO-type moves (explicit meta or classic Horn Drill id=32)
        var is_ohko_move = false;
        try {
            if (is_struct(mm_local) && variable_struct_exists(mm_local, "ohko") && variable_struct_get(mm_local, "ohko") == true) is_ohko_move = true;
            if (!is_ohko_move && is_real(move_id) && move_id == 32) is_ohko_move = true;
        } catch (e_o) { is_ohko_move = is_ohko_move; }
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

        // Apply first hit now (only if move has power, is OHKO, or uses a custom damage semantic like Present)
        if ((is_real(mv_power) && mv_power > 0) || is_ohko_move || (is_real(move_id) && move_id == 217)){
    // If this is a locked repeated move, mark that the actor executed it this turn.
    try { if (is_real(move_id) && (move_id == 37 || move_id == 205) && is_struct(A)) { variable_struct_set(A, "_locked_move_executed", true); } } catch (e_lf) {}
    var resf = __battle_apply_move_damage(_pid, target_idx, A, D, move_id, mv_power);
        var _semi_blocked = false;
        try {
            var _Bsemi_chk = __battle_ensure_slot(_pid);
            if (is_struct(_Bsemi_chk) && variable_struct_exists(_Bsemi_chk, "__semi_guard_blocked") && variable_struct_get(_Bsemi_chk, "__semi_guard_blocked") == true){
                _semi_blocked = true;
                variable_struct_set(_Bsemi_chk, "__semi_guard_blocked", false);
            }
        } catch (e_sflag) { _semi_blocked = false; }
        if (_semi_blocked){
            return "";
        }
        var dmgh = (is_array(resf) ? resf[0] : 0);
        try { __battle_apply_move_meta_effects(_pid, _step, A, D, move_id, dmgh, mm_local); } catch (e_meta) {}

        // Hazard removal moves: Rapid Spin (229) clears hazards on user's side;
        // Defog (432) clears hazards on the target's side. Implement here
        // to ensure flags set by meta handlers are removed immediately when used.
        try {
            if (is_real(move_id) && (move_id == 229 || move_id == 432)){
                var _Bslot_rrr = __battle_ensure_slot(_pid);
                if (is_struct(_Bslot_rrr)){
                    if (move_id == 229){
                        // Rapid Spin: clear hazards on user's side (slot-side of the user)
                        try {
                            variable_struct_set(_Bslot_rrr, "_side_spikes", 0);
                            variable_struct_set(_Bslot_rrr, "_side_toxic_spikes", 0);
                            variable_struct_set(_Bslot_rrr, "_side_stealth_rock", 0);
                            variable_struct_set(_Bslot_rrr, "_side_sticky_web", false);
                            // Request a clear-hazards animation and dialog
                            try { __battle_request_animation_safe(_pid, { type: "clear_hazards", actor: A, target: D }); } catch (e_anim) {}
                            try { var nmC = (variable_struct_exists(A, "name") ? variable_struct_get(A, "name") : "The Pokémon"); if (!is_undefined(__status_request_dialog_for_mon)) __status_request_dialog_for_mon(A, string(nmC) + " removed entry hazards!", false); } catch (e_msgc) {}
                        } catch (e_clr) {}
                    } else if (move_id == 432){
                        // Defog: clears hazards on the target's side. Attempt to determine
                        // which side the target occupies. If D is undefined, clear both.
                        try {
                            variable_struct_set(_Bslot_rrr, "_side_spikes", 0);
                            variable_struct_set(_Bslot_rrr, "_side_toxic_spikes", 0);
                            variable_struct_set(_Bslot_rrr, "_side_stealth_rock", 0);
                            variable_struct_set(_Bslot_rrr, "_side_sticky_web", false);
                            // Request a clear-hazards animation and dialog
                            try { __battle_request_animation_safe(_pid, { type: "clear_hazards", actor: A, target: D }); } catch (e_anim2) {}
                            try { var nmD = (variable_struct_exists(A, "name") ? variable_struct_get(A, "name") : "The Pokémon"); if (!is_undefined(__status_request_dialog_for_mon)) __status_request_dialog_for_mon(A, string(nmD) + " cleared the field!", false); } catch (e_msgd) {}
                        } catch (e_defc) {}
                    }
                    // Mark that a meta-effect change occurred so UI updates can run
                    try { variable_struct_set(_Bslot_rrr, "_meta_effect_applied", true); } catch (e_me) {}
                }
            }
        } catch (e_hclr) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][meta] hazard-clear failed: " + string(e_hclr)); }

        // Special-case: Jump Kick / High Jump Kick — if the move missed (dmgh == 0),
        // apply miss recoil equal to 50% of the attacker's max HP.
        try {
            if (is_real(move_id) && (move_id == 26 || move_id == 136) && is_struct(A)){
                if (!is_real(dmgh) || dmgh <= 0){
                    // attacker actor index discovery
                    var atk_idx = undefined;
                    try { if (variable_struct_exists(A, "actor_index")) atk_idx = variable_struct_get(A, "actor_index"); } catch (e_ai) {}
                    try { if (!is_real(atk_idx) && variable_struct_exists(A, "slot")) atk_idx = variable_struct_get(A, "slot"); } catch (e_ai2) {}
                    try {
                        if (!is_real(atk_idx)){
                            var _Bt = __battle_ensure_slot(_pid);
                            if (is_struct(_Bt) && variable_struct_exists(_Bt, "actor") && is_array(variable_struct_get(_Bt, "actor"))){ var __acts_t = variable_struct_get(_Bt, "actor"); for (var _ii=0; _ii<array_length(__acts_t); ++_ii) if (is_struct(__acts_t[_ii]) && __acts_t[_ii] == A){ atk_idx = _ii; break; } }
                        }
                    } catch (e_ad) {}
                    var ahpmax = (variable_struct_exists(A, "hp_max") ? variable_struct_get(A, "hp_max") : (variable_struct_exists(A, "maxhp") ? variable_struct_get(A, "maxhp") : (variable_struct_exists(A, "mon") && is_struct(variable_struct_get(A, "mon")) && variable_struct_exists(variable_struct_get(A, "mon"), "hp_max") ? variable_struct_get(variable_struct_get(A, "mon"), "hp_max") : 1)));
                    ahpmax = max(1, floor(real(ahpmax)));
                    var recoil = max(1, floor(ahpmax * 0.5));
                    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][jump-kick] miss recoil for " + string(variable_struct_exists(A,"name")?variable_struct_get(A,"name"):"?") + ", move_id=" + string(move_id) + ", amt=" + string(recoil));
                    try { if (is_real(atk_idx)) __battle_apply_damage(_pid, atk_idx, recoil, 1.0); else __battle_set_hp_now(A, max(0, __battle_hp_now(A) - recoil)); } catch (e_rk) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][jump-kick] recoil failed: " + string(e_rk)); }
                }
            }
        } catch (e_jk) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][jump-kick] handler error: " + string(e_jk)); }

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

        // Rollout: each successful hit doubles the next hit's power while the lock remains active.
        try {
            if (is_real(move_id) && move_id == 205 && is_struct(A)){
                if (is_real(dmgh) && dmgh > 0){
                    var cur_roll = (variable_struct_exists(A, "_rollout_mul") && is_real(variable_struct_get(A, "_rollout_mul"))) ? variable_struct_get(A, "_rollout_mul") : 1;
                    var next_roll = min(cur_roll * 2, 16);
                    variable_struct_set(A, "_rollout_mul", next_roll);
                    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][rollout] hit: set _rollout_mul=" + string(next_roll));
                } else {
                    variable_struct_set(A, "_rollout_mul", 1);
                    try { if (variable_struct_exists(A, "_locked_move")) variable_struct_set(A, "_locked_move", undefined); } catch (e_roll_clear) {}
                    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][rollout] miss/reset: cleared lock and reset _rollout_mul=1");
                }
            } else if (is_struct(A)){
                var _roll_lock = (variable_struct_exists(A, "_locked_move") ? variable_struct_get(A, "_locked_move") : undefined);
                var _roll_active = (is_struct(_roll_lock) && variable_struct_exists(_roll_lock, "move_id") && variable_struct_get(_roll_lock, "move_id") == 205 && is_real(variable_struct_get(_roll_lock, "remaining")) && variable_struct_get(_roll_lock, "remaining") > 0);
                if (!_roll_active && variable_struct_exists(A, "_rollout_mul")) variable_struct_set(A, "_rollout_mul", 1);
            }
        } catch (e_roll) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][rollout] multiplier update failed: " + string(e_roll)); }

        // If multiple hits, schedule the rest into the battle slot for per-hit processing
        if (is_real(total_hits) && total_hits > 1){
            try {
                var _pm = { move_id: move_id, actor_index: actor_idx, target_index: target_idx, mv_power: mv_power, remaining: max(0, total_hits - 1), total_hits: total_hits };
                var _B = __battle_ensure_slot(_pid);
                if (is_struct(_B)) variable_struct_set(_B, "_pending_multi_hit", _pm);
            } catch (e_sched) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][multihit] scheduling failed: " + string(e_sched)); }
        }

        // If the slot recorded an OHKO miss, present a miss message instead of generic 'used' text
        try {
            var _Bslot_rr = __battle_ensure_slot(_pid);
            if (is_struct(_Bslot_rr) && variable_struct_exists(_Bslot_rr, "_last_ohko_miss") && variable_struct_get(_Bslot_rr, "_last_ohko_miss") == true){
                // clear the marker and return a clearer miss message
                try { variable_struct_set(_Bslot_rr, "_last_ohko_miss", undefined); } catch (e_clr) {}
                return string((variable_struct_exists(A,"name")?variable_struct_get(A,"name"):"The user")) + "'s attack missed!";
            }
        } catch (e_rr) {}
        // For non-damaging/status moves (mv_power <= 0), ensure meta effects run here
        // before returning the generic 'used' dialog (e.g., terrains, weather, setup moves).
        if (!(is_real(mv_power) && mv_power > 0)){
            try {
                if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){
                    show_debug_message("[battle][impl] applying meta (status) for move_id=" + string(move_id));
                }
                __battle_apply_move_meta_effects(_pid, _step, A, D, move_id, 0, __battle_get_move_meta(move_id));
            } catch (e_meta_nd) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][impl] meta(status) error: " + string(e_meta_nd)); }
        }

        try {
            if (is_real(move_id) && (move_id == 120 || move_id == 153) && is_struct(A)){
                var _self_ko_hp = __battle_hp_now(A);
                if (is_real(_self_ko_hp) && _self_ko_hp > 0){
                    try { __battle_apply_damage(_pid, actor_idx, _self_ko_hp, 1.0); } catch (e_sdmg) { __battle_set_hp_now(A, 0); }
                }
            }
        } catch (e_self_ko) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][self-ko] handler error: " + string(e_self_ko)); }

        return __battle_impl_return_used(_pid, A, mv_name, move_id);
    }
}
    try { __battle_apply_move_meta_effects(_pid, _step, A, D, move_id, 0, __battle_get_move_meta(move_id)); } catch (e) {}
    try {
        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){
            show_debug_message("[battle][impl] applying meta for move_id=" + string(move_id) + ", power=" + string(mv_power));
        }
        __battle_apply_move_meta_effects(_pid, _step, A, D, move_id, 0, __battle_get_move_meta(move_id));
    } catch (e) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][impl] meta apply error: " + string(e)); }
    try {
        var _Bslot_rr2 = __battle_ensure_slot(_pid);
        if (is_struct(_Bslot_rr2) && variable_struct_exists(_Bslot_rr2, "_last_ohko_miss") && variable_struct_get(_Bslot_rr2, "_last_ohko_miss") == true){
            try { variable_struct_set(_Bslot_rr2, "_last_ohko_miss", undefined); } catch (e_clr2) {}
            return string((variable_struct_exists(A,"name")?variable_struct_get(A,"name"):"The user")) + "'s attack missed!";
        }
    } catch (e_rr2) {}
    return __battle_impl_return_used(_pid, A, mv_name, move_id);
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
