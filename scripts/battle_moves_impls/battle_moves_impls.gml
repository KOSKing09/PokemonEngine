// [Battle] battle_moves_impls — Build v0.2.0 — Updated 2025-10-18

// Minimal, clean move resolver placeholder
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

    // Local helper to centralize the 'used' vs 'ohko miss' return message.
    // Accept explicit parameters to avoid closure/scope issues with the static analyser.
    function __battle_impl_return_used(_pid_in, _A_in, _mv_name_in){
        try {
            var _Bslot_rr = __battle_ensure_slot(_pid_in);
            if (is_struct(_Bslot_rr) && variable_struct_exists(_Bslot_rr, "_last_ohko_miss") && variable_struct_get(_Bslot_rr, "_last_ohko_miss") == true){
                // Log consumption explicitly so it stands out in noisy logs
                if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[OHKO] performer consuming _last_ohko_miss for pid=" + string(_pid_in) + " move=" + string(_mv_name_in));
                try { variable_struct_set(_Bslot_rr, "_last_ohko_miss", undefined); } catch (e_clr) {}
                return string((variable_struct_exists(_A_in,"name")?variable_struct_get(_A_in,"name"):"The user")) + "'s attack missed!";
            }
        } catch (e_ru) {}
        return string((variable_struct_exists(_A_in,"name")?variable_struct_get(_A_in,"name"):"The user")) + " used " + string(_mv_name_in) + "!";
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
            var namep = __battle_move_name(pick);
            var ret = __battle_impl_return_used(_pid, A, namep);
            // (removed temporary metronome debug)
            try { __battle_apply_move(_pid, A, D, pick); } catch (e_rp) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][metronome] apply failed: " + string(e_rp)); }
            try { variable_struct_set(A, "_suppress_last_move_record", false); } catch (e_sup2) {}
            return ret;
        }

        // ASSIST (274): pick a random move known by an ally (other actors in the same slot)
        if (is_real(move_id) && move_id == 274){
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
            if (array_length(ally_moves) == 0) return __battle_impl_return_used(_pid, A, __battle_move_name(move_id));
            var pick2 = ally_moves[irandom(array_length(ally_moves)-1)];
            try { variable_struct_set(A, "_suppress_last_move_record", true); } catch (e_sup3) {}
            try { __battle_apply_move(_pid, A, D, pick2); } catch (e_ap) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][assist] apply failed: " + string(e_ap)); }
            try { variable_struct_set(A, "_suppress_last_move_record", false); } catch (e_sup4) {}
            return __battle_impl_return_used(_pid, A, __battle_move_name(pick2));
        }

        // MIMIC (102): copy the last move used by the target (if valid)
        if (is_real(move_id) && move_id == 102){
            var cand = undefined;
            try {
                if (is_struct(D) && variable_struct_exists(D, "_last_moves") && is_array(variable_struct_get(D, "_last_moves"))){
                    var lr = variable_struct_get(D, "_last_moves");
                    for (var ii=array_length(lr)-1; ii>=0; --ii){ var rec = lr[ii]; if (!is_struct(rec) || !variable_struct_exists(rec, "move")) continue; var mv = rec.move; if (!is_real(mv)) continue; if (__is_meta_move_ignored(mv)) continue; cand = mv; break; }
                }
            } catch (e_mi) { cand = undefined; }
            if (!is_real(cand)) return __battle_impl_return_used(_pid, A, __battle_move_name(move_id));
            try { variable_struct_set(A, "_suppress_last_move_record", true); } catch (e_su) {}
            try { __battle_apply_move(_pid, A, D, cand); } catch (e_ca) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][mimic] failed: " + string(e_ca)); }
            try { variable_struct_set(A, "_suppress_last_move_record", false); } catch (e_su2) {}
            return __battle_impl_return_used(_pid, A, __battle_move_name(cand));
        }

        // MIRROR-MOVE (119): use the last move that targeted this user (if available)
        if (is_real(move_id) && move_id == 119){
            var cand2 = undefined;
            try {
                if (is_struct(A) && variable_struct_exists(A, "_last_moves") && is_array(variable_struct_get(A, "_last_moves"))){
                    var lr2 = variable_struct_get(A, "_last_moves");
                    for (var jj=array_length(lr2)-1; jj>=0; --jj){ var rec2 = lr2[jj]; if (!is_struct(rec2) || !variable_struct_exists(rec2, "move")) continue; var mv2 = rec2.move; if (!is_real(mv2)) continue; if (__is_meta_move_ignored(mv2)) continue; cand2 = mv2; break; }
                }
            } catch (e_mm2) { cand2 = undefined; }
            if (!is_real(cand2)) return __battle_impl_return_used(_pid, A, __battle_move_name(move_id));
            try { variable_struct_set(A, "_suppress_last_move_record", true); } catch (e_su3) {}
            try { __battle_apply_move(_pid, A, D, cand2); } catch (e_mr) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][mirror-move] failed: " + string(e_mr)); }
            try { variable_struct_set(A, "_suppress_last_move_record", false); } catch (e_su4) {}
            return __battle_impl_return_used(_pid, A, __battle_move_name(cand2));
        }

        // SKETCH (166): permanently replace the user's selected move slot with the target's last used move
        if (is_real(move_id) && move_id == 166){
            if (!is_struct(A) || !is_real(move_slot)) return __battle_impl_return_used(_pid, A, __battle_move_name(move_id));
            var sketch_cand = undefined;
            try {
                if (is_struct(D) && variable_struct_exists(D, "_last_moves") && is_array(variable_struct_get(D, "_last_moves"))){
                    var lr3 = variable_struct_get(D, "_last_moves");
                    for (var kk=array_length(lr3)-1; kk>=0; --kk){ var rec3 = lr3[kk]; if (!is_struct(rec3) || !variable_struct_exists(rec3, "move")) continue; var mv3 = rec3.move; if (!is_real(mv3)) continue; if (__is_meta_move_ignored(mv3)) continue; sketch_cand = mv3; break; }
                }
            } catch (e_sk) { sketch_cand = undefined; }
            if (!is_real(sketch_cand)) return __battle_impl_return_used(_pid, A, __battle_move_name(move_id));
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
            return __battle_impl_return_used(_pid, A, __battle_move_name(move_id));
        }

        // TRANSFORM (144): make the user copy the target's form/stats/moves roughly
        if (is_real(move_id) && move_id == 144){
            try {
                if (!is_struct(A) || !is_struct(D)) return __battle_impl_return_used(_pid, A, __battle_move_name(move_id));
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
            return __battle_impl_return_used(_pid, A, __battle_move_name(move_id));
        }

        // ME-FIRST (382): attempt to use the target's move immediately when it is a damaging move
        if (is_real(move_id) && move_id == 382){
            var mf = undefined;
            try {
                // Prefer to inspect target's _last_moves for their most recent chosen move
                if (is_struct(D) && variable_struct_exists(D, "_last_moves") && is_array(variable_struct_get(D, "_last_moves"))){
                    var lr4 = variable_struct_get(D, "_last_moves");
                    for (var zz=array_length(lr4)-1; zz>=0; --zz){ var r4 = lr4[zz]; if (!is_struct(r4) || !variable_struct_exists(r4, "move")) continue; var mv4 = r4.move; if (!is_real(mv4)) continue; if (__is_meta_move_ignored(mv4)) continue; mf = mv4; break; }
                }
            } catch (e_mf) { mf = undefined; }
            if (!is_real(mf)) return __battle_impl_return_used(_pid, A, __battle_move_name(move_id));
            try { variable_struct_set(A, "_suppress_last_move_record", true); } catch (e_su5) {}
            try { __battle_apply_move(_pid, A, D, mf); } catch (e_mf2) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][me-first] apply failed: " + string(e_mf2)); }
            try { variable_struct_set(A, "_suppress_last_move_record", false); } catch (e_su6) {}
            return __battle_impl_return_used(_pid, A, __battle_move_name(mf));
        }
    } catch (e_metaAll) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][meta_moves] handler error: " + string(e_metaAll)); }

    // Debug: log selection immediately so we can trace Horn Drill choices
    try {
        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){
            try { __battle_stub_dialog(_pid, "[battle_select][debug] pid=" + string(_pid) + ", slot=" + string(move_slot) + ", mv_selected=" + string(move_id) + ", actor.moves[slot]=" + string((is_struct(A) && is_array(variable_struct_get(A, "moves")) && is_real(move_slot) && move_slot >=0 && move_slot < array_length(variable_struct_get(A, "moves")) ? variable_struct_get(A, "moves")[move_slot] : "?")) ); } catch (e_sd) {}
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
            try { __battle_stub_dialog(_pid, string(variable_struct_exists(A,"name")?variable_struct_get(A,"name"):"The user") + " flinched!"); } catch (e_fd) {}
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
            // Special-case: Thrash / Rage-like behavior (lock for 2-3 turns then confuse)
            // Move id 37 => Thrash (Gen3 behavior: successful use locks user for 2-3 turns,
            // forcing repeated use of the same move; at the end the user becomes confused.)
            if (is_real(move_id) && move_id == 37){
                var _locked = (variable_struct_exists(A, "_locked_move") ? variable_struct_get(A, "_locked_move") : undefined);
                // If not previously locked, initialize lock state (2..3 turns inclusive)
                if (!is_struct(_locked) || !variable_struct_exists(_locked, "move_id") || variable_struct_get(_locked, "move_id") != 37){
                    var dur = irandom_range(2,3);
                    variable_struct_set(A, "_locked_move", { move_id: 37, remaining: dur, apply_confuse_on_end: true });
                }
            }
            if (is_two){
                var charging = (variable_struct_exists(A, "_charging_move") ? variable_struct_get(A, "_charging_move") : undefined);
                // If actor is already charging this same move, consume the charge and continue
                if (is_struct(charging) && variable_struct_exists(charging, "move_id") && variable_struct_get(charging, "move_id") == move_id){
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
                    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][two-turn] " + string(variable_struct_get(A, "name")) + " completes charge for move=" + string(move_id) + ", stored_target=" + string(_stored_tidx) + ", resolved_target_idx=" + string(target_idx));
                } else {
                    // Start charging: store move and intended target index so the second
                    // turn can reference it. PP already consumed earlier.
                        variable_struct_set(A, "_charging_move", { move_id: move_id, target_index: target_idx });
                        // If this is a semi-invulnerable two-turn move (fly/dig/dive/bounce/sky-attack),
                        // mark the actor so other move handlers can apply the special rules.
                        try {
                            var _phase = undefined;
                            if (move_id == 19) _phase = "fly";           // Fly
                            else if (move_id == 91) _phase = "dig";      // Dig
                            else if (move_id == 291) _phase = "dive";    // Dive
                            else if (move_id == 340) _phase = "bounce";  // Bounce
                            else if (move_id == 143) _phase = "fly";     // Sky Attack behaves like fly for interactions
                            if (!is_undefined(_phase)){
                                variable_struct_set(A, "_semi_invuln", _phase);
                                if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][two-turn] set _semi_invuln=" + string(_phase) + " for " + string(variable_struct_exists(A, "name") ? variable_struct_get(A, "name") : "?"));
                            }
                        } catch (e_si) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][two-turn] failed to set _semi_invuln: " + string(e_si)); }
                    // Request a charge animation if available and return the 'used' dialog
                    try { __battle_request_animation_safe(A, { type: "charge", move_id: move_id }); } catch (e_ch) {}
                    return __battle_impl_return_used(_pid, A, mv_name);
                }
            }
        }
    } catch (e_two){ if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][two-turn] handler error: " + string(e_two)); }

    // Thrash lock enforcement: if attacker is locked into Thrash (move 37), ensure
    // they must continue using the move until lock expires. If they attempt a
    // different move, block it and force the thrash move instead (consuming PP already).
    try {
        if (is_struct(A) && is_real(move_id) && move_id != 37){
            var _lm = (variable_struct_exists(A, "_locked_move") ? variable_struct_get(A, "_locked_move") : undefined);
            if (is_struct(_lm) && variable_struct_exists(_lm, "move_id") && variable_struct_get(_lm, "move_id") == 37 && is_real(variable_struct_get(_lm, "remaining")) && variable_struct_get(_lm, "remaining") > 0){
                // Block non-thrash selection: replace move_id with 37 and keep flow
                move_id = 37;
                mv_name = __battle_move_name(move_id);
                mv_power = __battle_move_power(move_id, A, D);
            }
        }
    } catch (e_tl) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][thrash] enforcement error: " + string(e_tl)); }

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
                return __battle_impl_return_used(_pid, A, mv_name);
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
                return __battle_impl_return_used(_pid, A, mv_name);
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

        // Apply first hit now (only if move has power or is OHKO)
        if ((is_real(mv_power) && mv_power > 0) || is_ohko_move){
    // If this is Thrash (id 37) mark that the actor executed the locked move
    try { if (is_real(move_id) && move_id == 37 && is_struct(A)) { variable_struct_set(A, "_locked_move_executed", true); } } catch (e_lf) {}
    var resf = __battle_apply_move_damage(_pid, target_idx, A, D, move_id, mv_power);
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
                            try { var nmC = (variable_struct_exists(A, "name") ? variable_struct_get(A, "name") : "The Pokémon"); if (!is_undefined(__status_request_dialog_for_mon)) __status_request_dialog_for_mon(A, string(nmC) + " removed entry hazards!"); } catch (e_msgc) {}
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
                            try { var nmD = (variable_struct_exists(A, "name") ? variable_struct_get(A, "name") : "The Pokémon"); if (!is_undefined(__status_request_dialog_for_mon)) __status_request_dialog_for_mon(A, string(nmD) + " cleared the field!"); } catch (e_msgd) {}
                        } catch (e_defc) {}
                    }
                    // Mark that a meta-effect change occurred so UI updates can run
                    try { variable_struct_set(_Bslot_rrr, "_meta_effect_applied", true); } catch (e_me) {}
                }
            }
        } catch (e_hclr) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][meta] hazard-clear failed: " + string(e_hclr)); }

        // Special-case: Jump Kick (id 26) — if the move missed (dmgh == 0) but the
        // attacker selected Jump Kick, apply miss recoil equal to 50% of attacker's max HP
        // (original Gen3 behavior). Ensure recoil uses canonical damage so animations run.
        try {
            if (is_real(move_id) && move_id == 26 && is_struct(A)){
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
                    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][jump-kick] miss recoil for " + string(variable_struct_exists(A,"name")?variable_struct_get(A,"name"):"?") + ", amt=" + string(recoil));
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
    return __battle_impl_return_used(_pid, A, mv_name);
    }
}

    try { __battle_apply_move_meta_effects(_pid, _step, A, D, move_id, 0, __battle_get_move_meta(move_id)); } catch (e) {}
    try {
        var _Bslot_rr2 = __battle_ensure_slot(_pid);
        if (is_struct(_Bslot_rr2) && variable_struct_exists(_Bslot_rr2, "_last_ohko_miss") && variable_struct_get(_Bslot_rr2, "_last_ohko_miss") == true){
            try { variable_struct_set(_Bslot_rr2, "_last_ohko_miss", undefined); } catch (e_clr2) {}
            return string((variable_struct_exists(A,"name")?variable_struct_get(A,"name"):"The user")) + "'s attack missed!";
        }
    } catch (e_rr2) {}
    return __battle_impl_return_used(_pid, A, mv_name);
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