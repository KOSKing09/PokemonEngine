// [System]: battle_system — Build v0.1.35 — Updated 2025-10-31
// [Battle] PokemonBattleSystem � Build v0.1.35 (rewards & flow)
// Updated 2025-10-11
// - NEW: Rewards � EXP on victory (b * L / 7), simple level-up (stubbed stat bumps)
// - NEW: Escape formula � probability scales with Speed and repeated attempts
// - NEW: Catch flow stub � success scales with foe HP% (for later Bag integration)
// -----------------------------------------------------------------------------
// - Keeps: wrap ellipsis, switch-in midpoint apply, cry-trigger grow, PID-aware input, no built-in `id` collisions
// -----------------------------------------------------------------------------
// Ensure helper scripts register their globals when this module is loaded.
if (!variable_global_exists("__battle_apply_move_meta_effects")){
    var _scr_meta = asset_get_index("battle_move_meta_helpers");
    if (_scr_meta != -1) script_execute(_scr_meta);
}
if (!variable_global_exists("__battle_apply_entry_hazards")){
    var _scr_haz = asset_get_index("battle_entry_hazard_helpers");
    if (_scr_haz != -1) script_execute(_scr_haz);
}
if (!variable_global_exists("__battle_jaw_lock_release")){
    var _scr_jaw = asset_get_index("battle_jaw_lock_helpers");
    if (_scr_jaw != -1) script_execute(_scr_jaw);
}
if (!variable_global_exists("__battle_get_terrain_state")){
    var _scr_terr = asset_get_index("battle_terrain_helpers");
    if (_scr_terr != -1) script_execute(_scr_terr);
}
if (is_undefined(__battle_weather_particles_draw)){
    var _scr_weather_particles = asset_get_index("battle_weather_particles");
    if (_scr_weather_particles != -1) script_execute(_scr_weather_particles);
}
if (!variable_global_exists("__battle_trigger_stat_overlay")){
    var _scr_stat_overlay = asset_get_index("battle_state_overlay");
    if (_scr_stat_overlay != -1) script_execute(_scr_stat_overlay);
}
if (!variable_global_exists("_battle_impls") || !is_struct(variable_global_get("_battle_impls")) || !variable_struct_exists(variable_global_get("_battle_impls"), "__battle_perform_action_impl_real")){
    var _scr_moves_impl = asset_get_index("battle_moves_impls");
    if (_scr_moves_impl != -1) script_execute(_scr_moves_impl);
    try { if (!is_undefined(__battle_moves_impls_register)) __battle_moves_impls_register(); } catch (e_moves_impl_register_boot) {}
}

// Stat overlay trigger is provided by `battle_state_overlay` script when available.
// If that script isn't present, no fallback is registered by default.

function __battle_perform_action_minimal_fallback(_pid, _step){
    if (!is_struct(_step)) return "";
    if (variable_struct_exists(_step, "item_use") && variable_struct_get(_step, "item_use") == true) return "";
    if (variable_struct_exists(_step, "switch_to")) return "";

    var _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B) || !variable_struct_exists(_B, "actor") || !is_array(variable_struct_get(_B, "actor"))) return "";

    var _actors = variable_struct_get(_B, "actor");
    var _actor_idx = (variable_struct_exists(_step, "actor_index") && is_real(variable_struct_get(_step, "actor_index"))) ? floor(variable_struct_get(_step, "actor_index")) : 0;
    var _target_idx = (variable_struct_exists(_step, "target_index") && is_real(variable_struct_get(_step, "target_index"))) ? floor(variable_struct_get(_step, "target_index")) : 1;
    var _move_id = (variable_struct_exists(_step, "move_id") && is_real(variable_struct_get(_step, "move_id"))) ? floor(variable_struct_get(_step, "move_id")) : -1;
    if (_move_id < 0 || _actor_idx < 0 || _actor_idx >= array_length(_actors) || !is_struct(_actors[_actor_idx])) return "";

    if (_target_idx < 0 || _target_idx >= array_length(_actors) || !is_struct(_actors[_target_idx])){
        try { _target_idx = __battle_resolve_live_target_index(_pid, _actor_idx, _target_idx, _move_id); } catch (e_fallback_target) {}
    }
    if (_target_idx < 0 || _target_idx >= array_length(_actors) || !is_struct(_actors[_target_idx])) return "";

    var _A = _actors[_actor_idx];
    var _D = _actors[_target_idx];
    var _move_name = "the move";
    try { _move_name = __battle_move_name(_move_id); } catch (e_fallback_name) {}

    try { __battle_request_animation_safe(_pid, { type: "move", actor: _A, target: _D, user: _A, move_id: _move_id }); } catch (e_fallback_anim) {}

    var _power = 0;
    try { _power = __battle_move_power(_move_id, _A, _D); } catch (e_fallback_power) { _power = 0; }
    var _damage = 0;
    if (is_real(_power) && _power > 0 && variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){
        show_debug_message("[battle][resolver-fallback] skipped damage for move_id=" + string(_move_id) + " because full resolver was unavailable");
    }

    try {
        if (!(is_real(_power) && _power > 0) && !is_undefined(__battle_apply_move_meta_effects)){
            var _mm = undefined;
            try { if (!is_undefined(__battle_get_move_meta)) _mm = __battle_get_move_meta(_move_id); } catch (e_fallback_meta_lookup) { _mm = undefined; }
            __battle_apply_move_meta_effects(_pid, _step, _A, _D, _move_id, _damage, _mm);
        }
    } catch (e_fallback_meta) {
        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][resolver-fallback] meta failed: " + string(e_fallback_meta));
    }

    var _actor_name = "The user";
    try {
        if (is_struct(_A) && variable_struct_exists(_A, "name") && string_length(string(variable_struct_get(_A, "name"))) > 0) _actor_name = string(variable_struct_get(_A, "name"));
        if (!is_undefined(__battle_actor_side) && __battle_actor_side(_actor_idx) == 1 && string_copy(_actor_name, 1, 4) != "Foe ") _actor_name = "Foe " + _actor_name;
    } catch (e_fallback_actor_name) {}
    return _actor_name + " used " + string(_move_name) + "!";
}

// -----------------------------------------------------------------------------
// CALLS you�ll use in objects:
//   battle_open(pid, wild_level[, area_type_or_opts[, opts]]);
//       // e.g., battle_open(0, irandom_range(5,18));
//       //       battle_open(0, 12, "rocks a");
//       //       battle_open(0, 18, "river", { type:"trainer" });
//   battle_update(pid);                // Step Event
//   battle_draw_gui(pid);              // Draw GUI Event
//   battle_close(pid);                 // when done
//   battle_switch_to(pid, party_index);// switch active mon with visuals (midpoint swap)
// -----------------------------------------------------------------------------
if (is_undefined(__battle_perform_action)){
    function __battle_perform_action(_pid, _step){
        var _attempted_full_resolver = false;
        try {
            if (!variable_global_exists("_battle_impls") || !is_struct(variable_global_get("_battle_impls")) || !variable_struct_exists(variable_global_get("_battle_impls"), "__battle_perform_action_impl_real")){
                var _scr_moves_impl_runtime = asset_get_index("battle_moves_impls");
                if (_scr_moves_impl_runtime != -1) script_execute(_scr_moves_impl_runtime);
                if (!is_undefined(__battle_moves_impls_register)) __battle_moves_impls_register();
            }
        } catch (e_runtime_impl_load) {}
        try {
            if (variable_global_exists("_battle_impls")){
                var _impls = variable_global_get("_battle_impls");
                if (is_struct(_impls) && variable_struct_exists(_impls, "__battle_perform_action_impl_real")){
                    var fn_impl = variable_struct_get(_impls, "__battle_perform_action_impl_real");
                    if (!is_undefined(fn_impl)){
                        _attempted_full_resolver = true;
                        return fn_impl(_pid, _step);
                    }
                }
            }
        } catch (e_reg) {
            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][resolver] registered impl failed: " + string(e_reg));
            try { show_debug_message("[battle][resolver] registered impl failed: " + string(e_reg)); } catch (e_show_reg) {}
            if (_attempted_full_resolver) return "";
        }
        try {
            if (!variable_global_exists("_battle_impls") || !is_struct(variable_global_get("_battle_impls")) || !variable_struct_exists(variable_global_get("_battle_impls"), "__battle_perform_action_impl_real")){
                var _scr_moves_impl_retry = asset_get_index("battle_moves_impls");
                if (_scr_moves_impl_retry != -1) script_execute(_scr_moves_impl_retry);
                if (!is_undefined(__battle_moves_impls_register)) __battle_moves_impls_register();
            }
            if (variable_global_exists("_battle_impls")){
                var _impls_retry = variable_global_get("_battle_impls");
                if (is_struct(_impls_retry) && variable_struct_exists(_impls_retry, "__battle_perform_action_impl_real")){
                    var _fn_retry = variable_struct_get(_impls_retry, "__battle_perform_action_impl_real");
                    if (!is_undefined(_fn_retry)){
                        _attempted_full_resolver = true;
                        return _fn_retry(_pid, _step);
                    }
                }
            }
        } catch (e_reg_retry) {
            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][resolver] registered impl retry failed: " + string(e_reg_retry));
            try { show_debug_message("[battle][resolver] registered impl retry failed: " + string(e_reg_retry)); } catch (e_show_reg_retry) {}
            if (_attempted_full_resolver) return "";
        }
        try {
            if (!is_undefined(__battle_perform_action_impl)){
                _attempted_full_resolver = true;
                return __battle_perform_action_impl(_pid, _step);
            }
        } catch (e_direct) {
            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][resolver] direct impl failed: " + string(e_direct));
            try { show_debug_message("[battle][resolver] direct impl failed: " + string(e_direct)); } catch (e_show_direct) {}
            if (_attempted_full_resolver) return "";
        }

        return __battle_perform_action_minimal_fallback(_pid, _step);
    }
}

// Entry hazard helpers now live in battle_entry_hazard_helpers.gml

/// Ensure and return the per-player battle slot.
/// Params:
///  - _pid: player id (int)
/// Returns: struct _B (battle state for this player). Creates and initializes if missing.
/// Notes: Public helper used by most battle_* functions; do not mutate shape outside documented fields.
function __battle_ensure_slot(_pid){
    if (!variable_global_exists("sys_battles") || !is_array(global.sys_battles)) global.sys_battles = [];
    if (array_length(global.sys_battles) <= _pid) array_resize(global.sys_battles, _pid + 1);
    var _B = global.sys_battles[_pid];
    if (is_struct(_B) && variable_struct_exists(_B, "sys_open") && variable_struct_get(_B, "sys_open") == true) return _B;
    for (var _si = 0; _si < array_length(global.sys_battles); ++_si){
        var _shared = global.sys_battles[_si];
        if (!is_struct(_shared)) continue;
        if (!variable_struct_exists(_shared, "sys_open") || variable_struct_get(_shared, "sys_open") != true) continue;
        var _fmt_shared = variable_struct_exists(_shared, "battle_format") ? string_lower(string(variable_struct_get(_shared, "battle_format"))) : "single";
        var _coop_shared = variable_struct_exists(_shared, "coop_enabled") && variable_struct_get(_shared, "coop_enabled") == true;
        var _versus_shared = variable_struct_exists(_shared, "versus_enabled") && variable_struct_get(_shared, "versus_enabled") == true;
        if (!((_fmt_shared == "double" && _coop_shared) || _versus_shared)) continue;
        var _ppids = variable_struct_exists(_shared, "player_pids") ? variable_struct_get(_shared, "player_pids") : [];
        if (!is_array(_ppids)) continue;
        for (var _pi_shared = 0; _pi_shared < array_length(_ppids); ++_pi_shared){
            if (is_real(_ppids[_pi_shared]) && floor(_ppids[_pi_shared]) == floor(_pid)) return _shared;
        }
    }
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
            _field: undefined,
            result: "",
            battle_type: "wild",
            battle_format: "single",
            active_per_side: 1,
            coop_enabled: false,
            actor_owner_pid: [0, 0, -1, -1],
            player_pids: [0, 0],
            // Switch and UI defaults
            _switch_target_idx: undefined,
            _switch_opts: undefined,
            _cry_queued_from_switch: false,
            turn_action_player: undefined,
            _player_turn_actions: [],
            _command_actor_index: 0,
            _command_pending_action: undefined,
            _target_pick_targets: undefined,
            _ui: undefined
        };
        // store back into global container
        global.sys_battles[_pid] = _B;
    }
    return _B;
}

function __battle_reference_slot(){
    if (variable_global_exists("sys_battles") && is_array(global.sys_battles)){
        for (var _i = 0; _i < array_length(global.sys_battles); ++_i){
            var _slot = global.sys_battles[_i];
            if (is_struct(_slot) && variable_struct_exists(_slot, "sys_open") && variable_struct_get(_slot, "sys_open")) return _slot;
        }
        if (array_length(global.sys_battles) > 0 && is_struct(global.sys_battles[0])) return global.sys_battles[0];
    }
    return __battle_ensure_slot(0);
}

function __battle_bind_shared_slot_aliases(_B, _owner_pid){
    if (!is_struct(_B)) return;
    if (!variable_global_exists("sys_battles") || !is_array(global.sys_battles)) global.sys_battles = [];
    var _owner = max(0, floor(_owner_pid));
    if (array_length(global.sys_battles) <= _owner) array_resize(global.sys_battles, _owner + 1);
    global.sys_battles[_owner] = _B;
    if (!variable_struct_exists(_B, "player_pids") || !is_array(variable_struct_get(_B, "player_pids"))) return;
    var _player_pids = variable_struct_get(_B, "player_pids");
    for (var _ppi = 0; _ppi < array_length(_player_pids); ++_ppi){
        var _ppid = _player_pids[_ppi];
        if (!is_real(_ppid)) continue;
        _ppid = max(0, floor(_ppid));
        if (array_length(global.sys_battles) <= _ppid) array_resize(global.sys_battles, _ppid + 1);
        global.sys_battles[_ppid] = _B;
    }
}

function __battle_is_local_versus_slot(_B){
    return is_struct(_B) && variable_struct_exists(_B, "versus_enabled") && variable_struct_get(_B, "versus_enabled") == true;
}

function __battle_uses_split_command_ui(_B){
    if (!is_struct(_B)) return false;
    if (__battle_is_local_versus_slot(_B)) return true;
    var _fmt = variable_struct_exists(_B, "battle_format") ? string_lower(string(variable_struct_get(_B, "battle_format"))) : "single";
    if (_fmt != "double") return false;
    if (!variable_struct_exists(_B, "coop_enabled") || variable_struct_get(_B, "coop_enabled") != true) return false;
    return (variable_struct_exists(_B, "player_pids") && is_array(variable_struct_get(_B, "player_pids")));
}

function __battle_any_player_party_open(_pid){
    var _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B)) return false;
    if (!__battle_uses_split_command_ui(_B)) return (is_undefined(party_is_open) ? false : party_is_open(_pid) || (!is_undefined(pc_is_open) && pc_is_open(_pid)));
    if (!variable_struct_exists(_B, "player_pids") || !is_array(variable_struct_get(_B, "player_pids"))) return false;
    if (is_undefined(party_is_open)) return false;
    var _player_pids = variable_struct_get(_B, "player_pids");
    for (var _ppi = 0; _ppi < array_length(_player_pids); ++_ppi){
        var _ppid = _player_pids[_ppi];
        if (!is_real(_ppid)) continue;
        if (party_is_open(max(0, floor(_ppid)))) return true;
    }
    return false;
}

function __battle_has_forced_switch_lock(_pid){
    var _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B)) return false;
    if (variable_struct_exists(_B, "_pending_open_party") && variable_struct_get(_B, "_pending_open_party") == true) return true;
    if (__battle_any_player_party_open(_pid)) return true;
    if (!variable_struct_exists(_B, "player_pids") || !is_array(variable_struct_get(_B, "player_pids")) || is_undefined(party_ensure)) return false;
    var _player_pids = variable_struct_get(_B, "player_pids");
    for (var _ppi = 0; _ppi < array_length(_player_pids); ++_ppi){
        var _ppid = _player_pids[_ppi];
        if (!is_real(_ppid)) continue;
        var _Plock = party_ensure(max(0, floor(_ppid)));
        if (!is_struct(_Plock)) continue;
        if (variable_struct_exists(_Plock, "_battle_swap_mode_forced") && variable_struct_get(_Plock, "_battle_swap_mode_forced") == true) return true;
    }
    return false;
}

function __battle_any_player_dialog_open(_pid){
    if (is_undefined(dialog2p_is_open)) return false;
    var _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B) || !__battle_uses_split_command_ui(_B)) return dialog2p_is_open(_pid);
    var _pids = (variable_struct_exists(_B, "player_pids") && is_array(variable_struct_get(_B, "player_pids"))) ? variable_struct_get(_B, "player_pids") : [_pid];
    for (var _i = 0; _i < array_length(_pids); ++_i){
        var _p = _pids[_i];
        if (!is_real(_p)) continue;
        if (dialog2p_is_open(floor(_p))) return true;
    }
    return false;
}

function __battle_flush_caught_nickname_requests(_B, _fallback_pid){
    if (!is_struct(_B) || !variable_struct_exists(_B, "_pending_caught_nicknames")) return false;
    var _queue = variable_struct_get(_B, "_pending_caught_nicknames");
    if (!is_array(_queue) || array_length(_queue) <= 0) return false;
    if (is_undefined(virtual_keyboard_request_caught_nickname)) {
        variable_struct_set(_B, "_pending_caught_nicknames", []);
        return false;
    }
    for (var _i = 0; _i < array_length(_queue); ++_i){
        var _entry = _queue[_i];
        if (!is_struct(_entry)) continue;
        var _npid = (variable_struct_exists(_entry, "pid") && is_real(variable_struct_get(_entry, "pid"))) ? max(0, floor(variable_struct_get(_entry, "pid"))) : max(0, floor(_fallback_pid));
        var _store = variable_struct_exists(_entry, "store") ? variable_struct_get(_entry, "store") : undefined;
        var _species_name = variable_struct_exists(_entry, "species_name") ? string(variable_struct_get(_entry, "species_name")) : "Pokemon";
        try { virtual_keyboard_request_caught_nickname(_npid, _store, _species_name); } catch (e_nick_request) {}
    }
    variable_struct_set(_B, "_pending_caught_nicknames", []);
    return true;
}

function __battle_finish_local_versus_defeat(_pid, _loser_pid, _loser_actor_index){
    var _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B) || !__battle_is_local_versus_slot(_B) || !is_real(_loser_pid)) return false;
    _loser_pid = max(0, floor(_loser_pid));
    if (variable_struct_exists(_B, "_local_versus_end_handled") && variable_struct_get(_B, "_local_versus_end_handled") == true) return true;

    var _winner_pid = -1;
    if (variable_struct_exists(_B, "actor") && is_array(variable_struct_get(_B, "actor"))){
        var _actors_vs = variable_struct_get(_B, "actor");
        for (var _ai_vs = 0; _ai_vs < array_length(_actors_vs); ++_ai_vs){
            if (_ai_vs == _loser_actor_index) continue;
            var _cand_vs = _actors_vs[_ai_vs];
            if (!is_struct(_cand_vs)) continue;
            var _cand_owner_vs = __battle_actor_owner_pid(_pid, _ai_vs);
            var _cand_hp_vs = __battle_hp_now(_cand_vs);
            if (is_real(_cand_owner_vs) && floor(_cand_owner_vs) != _loser_pid && is_real(_cand_hp_vs) && _cand_hp_vs > 0){
                _winner_pid = max(0, floor(_cand_owner_vs));
                break;
            }
        }
    }
    if (_winner_pid < 0 && variable_struct_exists(_B, "player_pids") && is_array(variable_struct_get(_B, "player_pids"))){
        var _ppids_vs = variable_struct_get(_B, "player_pids");
        for (var _ppi_vs = 0; _ppi_vs < array_length(_ppids_vs); ++_ppi_vs){
            var _ppid_vs = _ppids_vs[_ppi_vs];
            if (is_real(_ppid_vs) && floor(_ppid_vs) != _loser_pid){
                _winner_pid = max(0, floor(_ppid_vs));
                break;
            }
        }
    }
    if (_winner_pid < 0) _winner_pid = max(0, floor(_pid));

    var _reward_vs = 0;
    if (variable_struct_exists(_B, "_trainer_reward") && is_real(variable_struct_get(_B, "_trainer_reward"))){
        _reward_vs = max(0, floor(variable_struct_get(_B, "_trainer_reward")));
    }
    var _reward_mult_vs = 1.0;
    try { _reward_mult_vs = __battle_trainer_reward_multiplier(_winner_pid); } catch (e_vs_reward_mult) { _reward_mult_vs = 1.0; }
    if (_reward_vs > 0 && is_real(_reward_mult_vs) && _reward_mult_vs > 1) _reward_vs = max(1, floor(_reward_vs * _reward_mult_vs));
    var _reward_paid_vs = (variable_struct_exists(_B, "_trainer_reward_paid") && variable_struct_get(_B, "_trainer_reward_paid") == true);
    if (!_reward_paid_vs && _reward_vs > 0){
        if (!is_undefined(currency_add)) currency_add(_reward_vs);
        else {
            if (!variable_global_exists("PLAYER_MONEY") || !is_real(global.PLAYER_MONEY)) global.PLAYER_MONEY = 0;
            global.PLAYER_MONEY = max(0, floor(global.PLAYER_MONEY)) + _reward_vs;
        }
    }

    var _loser_label_vs = "PLAYER " + string(_loser_pid + 1);
    var _pend_vs = (variable_struct_exists(_B, "_pending_status_msgs") ? variable_struct_get(_B, "_pending_status_msgs") : []);
    if (!is_array(_pend_vs)) _pend_vs = [];
    array_push(_pend_vs, { pid:_winner_pid, text:_loser_label_vs + " was defeated!" });
    if (_reward_vs > 0) array_push(_pend_vs, { pid:_winner_pid, text:"You got $" + string(_reward_vs) + " for winning!" });
    array_push(_pend_vs, { pid:_winner_pid, text:"You won the battle!" });
    array_push(_pend_vs, { pid:_loser_pid, text:"You're out of usable Pok\u00e9mon!" });
    array_push(_pend_vs, { pid:_loser_pid, text:_loser_label_vs + " has whited out!" });
    variable_struct_set(_B, "_pending_status_msgs", _pend_vs);

    try { variable_struct_set(_B, "_trainer_reward_paid", true); } catch (e_vs_paid) {}
    try { variable_struct_set(_B, "_local_versus_end_handled", true); } catch (e_vs_handled) {}
    try { variable_struct_set(_B, "_local_versus_winner_pid", _winner_pid); } catch (e_vs_winner) {}
    try { variable_struct_set(_B, "_local_versus_loser_pid", _loser_pid); } catch (e_vs_loser) {}
    try { variable_struct_set(_B, "_end_result_dialog_shown", true); } catch (e_vs_enddlg) {}
    try { variable_struct_set(_B, "_pending_open_party", false); } catch (e_vs_pop) {}
    try { variable_struct_set(_B, "_pending_open_party_pid", undefined); } catch (e_vs_poppid) {}
    try { variable_struct_set(_B, "_pending_open_party_fainted_actor_index", undefined); } catch (e_vs_popactor) {}
    try { variable_struct_set(_B, "_action_active", false); } catch (e_vs_act) {}
    try { variable_struct_set(_B, "_faint_pending", false); } catch (e_vs_faint) {}
    try { if (variable_struct_exists(_B, "_trainer_pending_send")) variable_struct_remove(_B, "_trainer_pending_send"); } catch (e_vs_pending_send) {}
    try { if (!is_undefined(__battle_play_defeated_music_once)) __battle_play_defeated_music_once(_B); } catch (e_vs_music) {}
    _B.result = "win";
    _B._pending_close = true;
    _B.phase = "command";
    return true;
}

function __battle_command_ui_state(_B, _pid){
    if (!is_struct(_B)) return undefined;
    if (!variable_struct_exists(_B, "sys_ui") || !is_struct(variable_struct_get(_B, "sys_ui"))) _B.sys_ui = { menu:"root", selX:0, selY:0, msg_list:undefined };
    if (!__battle_uses_split_command_ui(_B)) return _B.sys_ui;

    if (!variable_struct_exists(_B, "_versus_ui") || !is_array(variable_struct_get(_B, "_versus_ui")) || array_length(variable_struct_get(_B, "_versus_ui")) < 2){
        variable_struct_set(_B, "_versus_ui", [
            { menu:"root", selX:0, selY:0, command_actor_index:0, command_pending_action:undefined, target_pick_targets:undefined, target_pick_index:0 },
            { menu:"root", selX:0, selY:0, command_actor_index:0, command_pending_action:undefined, target_pick_targets:undefined, target_pick_index:0 }
        ]);
    }

    var _ui_list = variable_struct_get(_B, "_versus_ui");
    var _ui_index = clamp(floor(_pid), 0, 1);
    var _ui = _ui_list[_ui_index];
    if (!is_struct(_ui)) _ui = { menu:"root", selX:0, selY:0, command_actor_index:0, command_pending_action:undefined, target_pick_targets:undefined, target_pick_index:0 };
    if (!variable_struct_exists(_ui, "menu") || string_length(string(variable_struct_get(_ui, "menu"))) <= 0) variable_struct_set(_ui, "menu", "root");
    if (!variable_struct_exists(_ui, "selX") || !is_real(variable_struct_get(_ui, "selX"))) variable_struct_set(_ui, "selX", 0);
    if (!variable_struct_exists(_ui, "selY") || !is_real(variable_struct_get(_ui, "selY"))) variable_struct_set(_ui, "selY", 0);
    if (!variable_struct_exists(_ui, "command_actor_index") || !is_real(variable_struct_get(_ui, "command_actor_index"))) variable_struct_set(_ui, "command_actor_index", 0);
    if (!variable_struct_exists(_ui, "target_pick_index") || !is_real(variable_struct_get(_ui, "target_pick_index"))) variable_struct_set(_ui, "target_pick_index", 0);
    _ui_list[_ui_index] = _ui;
    variable_struct_set(_B, "_versus_ui", _ui_list);
    return _ui;
}

function __battle_actor_side(_actorIndex){
    if (!is_real(_actorIndex)) return -1;
    var _idx = floor(_actorIndex);
    var _slot = __battle_reference_slot();
    var _format = (is_struct(_slot) && variable_struct_exists(_slot, "battle_format")) ? string(variable_struct_get(_slot, "battle_format")) : "single";
    if (_format == "double"){
        if (_idx < 0 || _idx > 3) return -1;
        return (_idx < 2) ? 0 : 1;
    }
    if (_idx == 0) return 0;
    if (_idx == 1) return 1;
    return -1;
}

function __battle_actor_slot(_actorIndex){
    if (!is_real(_actorIndex)) return -1;
    var _idx = floor(_actorIndex);
    var _slot = __battle_reference_slot();
    var _format = (is_struct(_slot) && variable_struct_exists(_slot, "battle_format")) ? string(variable_struct_get(_slot, "battle_format")) : "single";
    if (_format == "double"){
        if (_idx < 0 || _idx > 3) return -1;
        return (_idx < 2) ? _idx : (_idx - 2);
    }
    if (_idx == 0 || _idx == 1) return 0;
    return -1;
}

function __battle_actor_view_side_slot(_pid, _actorIndex){
    var _side = __battle_actor_side(_actorIndex);
    var _slot = __battle_actor_slot(_actorIndex);
    var _B = __battle_ensure_slot(_pid);
    if (!__battle_is_local_versus_slot(_B) || !is_real(_actorIndex)) return { side:_side, slot:_slot };

    var _owner_pid = __battle_actor_owner_pid(_pid, _actorIndex);
    if (!is_real(_owner_pid) || _owner_pid < 0) return { side:_side, slot:_slot };

    var _pid_use = max(0, floor(_pid));
    var _view_side = (floor(_owner_pid) == _pid_use) ? 0 : 1;
    var _view_slot = 0;
    if (is_struct(_B) && variable_struct_exists(_B, "actor") && is_array(variable_struct_get(_B, "actor"))){
        var _actors = variable_struct_get(_B, "actor");
        var _target_idx = floor(_actorIndex);
        var _count = 0;
        for (var _i = 0; _i < array_length(_actors); ++_i){
            var _candidate_owner = __battle_actor_owner_pid(_pid_use, _i);
            var _candidate_side = (is_real(_candidate_owner) && floor(_candidate_owner) == _pid_use) ? 0 : 1;
            if (_candidate_side != _view_side) continue;
            if (_i == _target_idx){
                _view_slot = _count;
                break;
            }
            _count += 1;
        }
    }
    return { side:_view_side, slot:_view_slot };
}

function __battle_is_ally_index(_aIndex, _bIndex){
    if (!is_real(_aIndex) || !is_real(_bIndex)) return false;
    return (__battle_actor_side(_aIndex) == __battle_actor_side(_bIndex));
}

function __battle_is_enemy_index(_aIndex, _bIndex){
    if (!is_real(_aIndex) || !is_real(_bIndex)) return false;
    var _sa = __battle_actor_side(_aIndex);
    var _sb = __battle_actor_side(_bIndex);
    return (_sa >= 0 && _sb >= 0 && _sa != _sb);
}

function __battle_actor_index_for_side_slot(_pid, _side, _slot){
    var _B = __battle_ensure_slot(_pid);
    if (__battle_is_local_versus_slot(_B) && is_struct(_B) && variable_struct_exists(_B, "actor") && is_array(variable_struct_get(_B, "actor"))){
        var _actors = variable_struct_get(_B, "actor");
        var _side_use_local = max(0, floor(_side));
        var _slot_use_local = max(0, floor(_slot));
        for (var _i_local = 0; _i_local < array_length(_actors); ++_i_local){
            var _view = __battle_actor_view_side_slot(_pid, _i_local);
            if (!is_struct(_view)) continue;
            var _view_side = variable_struct_exists(_view, "side") ? variable_struct_get(_view, "side") : -1;
            var _view_slot = variable_struct_exists(_view, "slot") ? variable_struct_get(_view, "slot") : -1;
            if (_view_side == _side_use_local && _view_slot == _slot_use_local) return _i_local;
        }
        return -1;
    }
    var _format = (is_struct(_B) && variable_struct_exists(_B, "battle_format")) ? string(variable_struct_get(_B, "battle_format")) : "single";
    var _side_use = max(0, floor(_side));
    var _slot_use = max(0, floor(_slot));
    if (_format == "double"){
        if (_side_use == 0) return min(1, _slot_use);
        return 2 + min(1, _slot_use);
    }
    if (_slot_use > 0) return -1;
    return (_side_use == 0) ? 0 : 1;
}

function __battle_get_side_actor(_pid, _side, _slot){
    var _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B) || !is_array(_B.actor)) return undefined;
    var _idx = __battle_actor_index_for_side_slot(_pid, _side, _slot);
    if (!is_real(_idx) || _idx < 0 || _idx >= array_length(_B.actor)) return undefined;
    return _B.actor[_idx];
}

function __battle_actor_index_alive(_pid, _actorIndex){
    var _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B) || !is_array(_B.actor) || !is_real(_actorIndex)) return false;
    var _idx = floor(_actorIndex);
    if (_idx < 0 || _idx >= array_length(_B.actor)) return false;
    var _A = _B.actor[_idx];
    if (!is_struct(_A)) return false;
    return (__battle_hp_now(_A) > 0);
}

function __battle_get_default_target_index(_pid, _actorIndex){
    var _B = __battle_ensure_slot(_pid);
    var _format = (is_struct(_B) && variable_struct_exists(_B, "battle_format")) ? string(variable_struct_get(_B, "battle_format")) : "single";
    var _idx = floor(_actorIndex);
    if (_format != "double"){
        if (_idx == 0) return 1;
        return 0;
    }
    switch (_idx){
        case 0: return __battle_actor_index_alive(_pid, 2) ? 2 : 3;
        case 1: return __battle_actor_index_alive(_pid, 3) ? 3 : 2;
        case 2: return __battle_actor_index_alive(_pid, 0) ? 0 : 1;
        case 3: return __battle_actor_index_alive(_pid, 1) ? 1 : 0;
    }
    return (__battle_actor_side(_idx) == 0)
        ? (__battle_actor_index_alive(_pid, 2) ? 2 : 3)
        : (__battle_actor_index_alive(_pid, 0) ? 0 : 1);
}

function __battle_find_pending_enemy_faint_actor(_pid){
    var _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B) || !is_array(_B.actor)) return undefined;
    for (var _i = 0; _i < array_length(_B.actor); ++_i){
        if (__battle_actor_side(_i) != 1) continue;
        var _actor = _B.actor[_i];
        if (!is_struct(_actor)) continue;
        var _hp = __battle_hp_now(_actor);
        var _processed = (variable_struct_exists(_actor, "_faint_awarded_enemy") && variable_struct_get(_actor, "_faint_awarded_enemy") == true);
        if (is_real(_hp) && _hp <= 0 && !_processed) return _actor;
    }
    return undefined;
}

function __battle_actor_owner_pid(_pid, _actorIndex){
    var _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B) || !is_real(_actorIndex)) return -1;
    if (variable_struct_exists(_B, "actor_owner_pid") && is_array(variable_struct_get(_B, "actor_owner_pid"))){
        var _owners = variable_struct_get(_B, "actor_owner_pid");
        var _idx = floor(_actorIndex);
        if (_idx >= 0 && _idx < array_length(_owners) && is_real(_owners[_idx])) return _owners[_idx];
    }
    return (__battle_actor_side(_actorIndex) == 0) ? _pid : -1;
}

function __battle_actor_control_pid(_pid, _actorIndex){
    return __battle_actor_owner_pid(_pid, _actorIndex);
}

function __battle_enemy_lead_index(_pid){
    var _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B) || !is_array(_B.actor)) return __battle_actor_index_for_side_slot(_pid, 1, 0);
    var _lead = __battle_actor_index_for_side_slot(_pid, 1, 0);
    if (is_real(_lead) && _lead >= 0 && _lead < array_length(_B.actor) && is_struct(_B.actor[_lead])) return _lead;
    for (var _i = 0; _i < array_length(_B.actor); ++_i){
        if (__battle_actor_side(_i) != 1) continue;
        if (is_struct(_B.actor[_i])) return _i;
    }
    return __battle_actor_index_for_side_slot(_pid, 1, 0);
}

function __battle_collect_opening_party_indexes(_pid, _limit, _prefer_selected){
    var _out = [];
    var _P = party_ensure(_pid);
    if (!is_struct(_P) || !is_array(_P.mons)) return _out;
    var _want = max(1, floor(_limit));
    var _selected = -1;
    if (_prefer_selected && variable_struct_exists(_P, "sel") && is_real(variable_struct_get(_P, "sel"))) _selected = floor(variable_struct_get(_P, "sel"));
    if (_selected >= 0 && _selected < array_length(_P.mons) && __battle_party_index_is_usable(_pid, _selected)) array_push(_out, _selected);
    for (var _i = 0; _i < array_length(_P.mons) && array_length(_out) < _want; ++_i){
        if (!__battle_party_index_is_usable(_pid, _i)) continue;
        var _dup = false;
        for (var _j = 0; _j < array_length(_out); ++_j){
            if (_out[_j] == _i){ _dup = true; break; }
        }
        if (!_dup) array_push(_out, _i);
    }
    return _out;
}

function __battle_party_index_is_usable(_pid, _partyIndex){
    var _mon = party_model_get_mon(_pid, _partyIndex);
    if (!is_struct(_mon)){
        var _P = party_ensure(_pid);
        if (!is_struct(_P) || !is_array(_P.mons) || _partyIndex < 0 || _partyIndex >= array_length(_P.mons)) return false;
        _mon = _P.mons[_partyIndex];
    }
    return (is_struct(_mon) && __battle_hp_now(_mon) > 0);
}

function __battle_set_actor_runtime_fields(_actor, _actorIndex, _ownerPid, _partyPid, _partyIndex){
    if (!is_struct(_actor)) return;
    try { variable_struct_set(_actor, "actor_index", _actorIndex); } catch (e_ai_set) {}
    try { variable_struct_set(_actor, "owner_pid", _ownerPid); } catch (e_owner_set) {}
    try { variable_struct_set(_actor, "control_pid", _ownerPid); } catch (e_ctrl_set) {}
    try { variable_struct_set(_actor, "party_pid", _partyPid); } catch (e_party_pid) {}
    try { variable_struct_set(_actor, "party_index", _partyIndex); } catch (e_party_idx) {}
    try { variable_struct_set(_actor, "_last_moves", []); } catch (e_last_set) {}
}

function __battle_mark_exp_participant(_B, _actor){
    if (!is_struct(_B) || !is_struct(_actor)) return;
    if (!variable_struct_exists(_actor, "party_pid") || !is_real(variable_struct_get(_actor, "party_pid"))) return;
    if (!variable_struct_exists(_actor, "party_index") || !is_real(variable_struct_get(_actor, "party_index"))) return;
    var _party_pid = floor(variable_struct_get(_actor, "party_pid"));
    var _party_index = floor(variable_struct_get(_actor, "party_index"));
    if (_party_pid < 0 || _party_index < 0) return;
    if (!variable_struct_exists(_B, "_exp_participants") || !is_array(variable_struct_get(_B, "_exp_participants"))) variable_struct_set(_B, "_exp_participants", []);
    var _participants = variable_struct_get(_B, "_exp_participants");
    for (var _i = 0; _i < array_length(_participants); ++_i){
        var _entry = _participants[_i];
        if (!is_struct(_entry)) continue;
        if (variable_struct_exists(_entry, "party_pid") && variable_struct_exists(_entry, "party_index") && floor(variable_struct_get(_entry, "party_pid")) == _party_pid && floor(variable_struct_get(_entry, "party_index")) == _party_index) return;
    }
    array_push(_participants, { party_pid: _party_pid, party_index: _party_index });
    variable_struct_set(_B, "_exp_participants", _participants);
}

function __battle_opening_actor_from_party(_partyPid, _partyIndex, _actorIndex, _ownerPid){
    var _P = party_ensure(_partyPid);
    var _pm = party_model_get_mon(_partyPid, _partyIndex);
    if (!is_struct(_pm) && is_struct(_P) && is_array(_P.mons) && _partyIndex >= 0 && _partyIndex < array_length(_P.mons)) _pm = _P.mons[_partyIndex];
    if (!is_struct(_pm)) return undefined;
    var _actor = __battle_actor_from_party_mon(_pm);
    __battle_set_actor_runtime_fields(_actor, _actorIndex, _ownerPid, _partyPid, _partyIndex);
    return _actor;
}

function __battle_opening_actor_from_wild(_actorIndex, _level, _species_override = undefined){
    var _sp = irandom_range(1, 901);
    if (is_real(_species_override)) _sp = max(1, floor(_species_override));
    var _actor = __battle_actor_from_species_level(_sp, _level);
    __battle_set_actor_runtime_fields(_actor, _actorIndex, -1, -1, -1);
    return _actor;
}

function __battle_set_wild_actor_shiny(_actor, _shiny){
    if (!is_struct(_actor)) return _actor;
    var _is_shiny = (_shiny == true);
    try { variable_struct_set(_actor, "shiny", _is_shiny); } catch (e_actor_shiny) {}
    try {
        if (variable_struct_exists(_actor, "mon") && is_struct(variable_struct_get(_actor, "mon"))){
            variable_struct_set(variable_struct_get(_actor, "mon"), "shiny", _is_shiny);
        }
    } catch (e_mon_shiny) {}
    return _actor;
}

function __battle_clear_jaw_lock_party_flags(_partyPid){
    var __fn_jaw_release = undefined;
    if (variable_global_exists("__battle_jaw_lock_release")) __fn_jaw_release = variable_global_get("__battle_jaw_lock_release");
    if (is_undefined(__fn_jaw_release)) return;

    var _party = party_ensure(_partyPid);
    try {
        if (is_struct(_party) && variable_struct_exists(_party, "mons") && is_array(_party.mons)){
            for (var __jl = 0; __jl < array_length(_party.mons); ++__jl){
                var __mon = _party.mons[__jl];
                if (is_struct(__mon)) __fn_jaw_release(__mon);
            }
        }
    } catch (e_jaw_player) {
        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][jaw_lock] failed clearing party flags pid=" + string(_partyPid) + ": " + string(e_jaw_player));
    }
}

function __battle_action_effective_priority(_actor, _act){
    var _prio = 0;
    if (!is_struct(_act)) return _prio;
    var _move_id = undefined;
    try { if (variable_struct_exists(_act, "move_id") && is_real(variable_struct_get(_act, "move_id"))) _move_id = variable_struct_get(_act, "move_id"); } catch (e_prio_mid) {}
    if (!is_real(_move_id)) return _prio;
    try { _prio = scr_move_priority_by_id(_move_id); } catch (e_base_prio) { _prio = 0; }
    try {
        if (is_struct(_actor) && !is_undefined(__battle_actor_ability_actions)){
            var _actions = __battle_actor_ability_actions(_actor, "priority_calc");
            for (var _i = 0; _i < array_length(_actions); ++_i){
                var _pa = _actions[_i];
                if (!is_struct(_pa)) continue;
                var _kind = variable_struct_exists(_pa, "kind") ? string_lower(string(variable_struct_get(_pa, "kind"))) : "";
                var _data = (variable_struct_exists(_pa, "data") && is_struct(variable_struct_get(_pa, "data"))) ? variable_struct_get(_pa, "data") : {};
                var _bonus = (variable_struct_exists(_data, "bonus") && is_real(variable_struct_get(_data, "bonus"))) ? variable_struct_get(_data, "bonus") : 0;
                if (_bonus == 0) continue;
                if (_kind == "status_priority_bonus"){
                    var _dc = 0;
                    try { if (!is_undefined(scr_move_damage_class_by_id)) _dc = scr_move_damage_class_by_id(_move_id); } catch (e_dc_prio) { _dc = 0; }
                    if (_dc == 1) _prio += _bonus;
                } else if (_kind == "type_priority_bonus"){
                    var _want_type = variable_struct_exists(_data, "type") ? string_lower(string(variable_struct_get(_data, "type"))) : "";
                    var _full_hp_only = variable_struct_exists(_data, "full_hp_only") && variable_struct_get(_data, "full_hp_only") == true;
                    if (_full_hp_only && __battle_hp_now(_actor) < __battle_hp_max(_actor)) continue;
                    var _type_name = "";
                    try {
                        var _type_id = (!is_undefined(scr_move_type_id_by_id)) ? scr_move_type_id_by_id(_move_id, _actor) : -1;
                        if (!is_undefined(__battle_type_name_by_id_safe)) _type_name = string_lower(string(__battle_type_name_by_id_safe(_type_id)));
                    } catch (e_type_prio) { _type_name = ""; }
                    if (_type_name == _want_type) _prio += _bonus;
                } else if (_kind == "healing_priority_bonus"){
                    var _is_heal = false;
                    try {
                        if (!is_undefined(__battle_get_move_meta)){
                            var _mm = __battle_get_move_meta(_move_id);
                            if (is_struct(_mm) && variable_struct_exists(_mm, "healing") && is_real(variable_struct_get(_mm, "healing")) && variable_struct_get(_mm, "healing") > 0) _is_heal = true;
                        }
                    } catch (e_heal_prio) { _is_heal = false; }
                    if (_is_heal) _prio += _bonus;
                } else if (_kind == "move_first_chance"){
                    var _chance_first = (variable_struct_exists(_data, "chance") && is_real(variable_struct_get(_data, "chance"))) ? variable_struct_get(_data, "chance") : 50;
                    if (irandom(99) < _chance_first) _prio += max(1, _bonus);
                } else if (_kind == "move_last_in_priority_bracket"){
                    _prio -= 100;
                }
            }
        }
    } catch (e_ability_priority) {}
    try {
        if (is_struct(_actor) && variable_struct_exists(_actor, "_held_next_priority") && variable_struct_get(_actor, "_held_next_priority") == true){
            _prio += 0.5;
        }
    } catch (e_custap_priority) {}
    try {
        if (is_struct(_actor) && !is_undefined(item_runtime_actor_held_actions)){
            var _item_prio_actions = item_runtime_actor_held_actions(_actor, "move_select");
            for (var _ipi = 0; _ipi < array_length(_item_prio_actions); ++_ipi){
                var _ipact = _item_prio_actions[_ipi];
                if (!is_struct(_ipact)) continue;
                var _ipkind = variable_struct_exists(_ipact, "kind") ? string_lower(string(variable_struct_get(_ipact, "kind"))) : "";
                var _ipdata = (variable_struct_exists(_ipact, "data") && is_struct(variable_struct_get(_ipact, "data"))) ? variable_struct_get(_ipact, "data") : {};
                if (_ipkind == "move_first_chance"){
                    var _ipchance = (variable_struct_exists(_ipdata, "chance") && is_real(variable_struct_get(_ipdata, "chance"))) ? clamp(floor(variable_struct_get(_ipdata, "chance")), 0, 100) : 20;
                    var _ipbonus = (variable_struct_exists(_ipdata, "bonus") && is_real(variable_struct_get(_ipdata, "bonus"))) ? real(variable_struct_get(_ipdata, "bonus")) : 0.5;
                    var _ip_roll = false;
                    if (variable_struct_exists(_act, "_held_move_first_roll")) {
                        _ip_roll = variable_struct_get(_act, "_held_move_first_roll") == true;
                    } else {
                        _ip_roll = (irandom(99) < _ipchance);
                        variable_struct_set(_act, "_held_move_first_roll", _ip_roll);
                    }
                    if (_ip_roll){
                        _prio += _ipbonus;
                    }
                } else if (_ipkind == "move_last_in_priority_bracket"){
                    _prio -= 0.5;
                }
            }
        }
    } catch (e_item_priority) {}
    return _prio;
}

function __battle_append_ordered_action(_pid, _actions, _act){
    if (!is_struct(_act)) return _actions;
    var _B = __battle_ensure_slot(_pid);
    var _prio_new = 0;
    var _spd_new = 0;
    try {
        var _actor_new_prio = variable_struct_get(_B, "actor")[floor(variable_struct_get(_act, "actor_index"))];
        _prio_new = __battle_action_effective_priority(_actor_new_prio, _act);
    } catch (e_prio_new) { _prio_new = 0; }
    try {
        var _actor_new = variable_struct_get(_B, "actor")[floor(variable_struct_get(_act, "actor_index"))];
        _spd_new = __battle_stat_get(_actor_new, "spd");
    } catch (e_spd_new) { _spd_new = 0; }
    var _insert_at = array_length(_actions);
    for (var _i = 0; _i < array_length(_actions); ++_i){
        var _cur = _actions[_i];
        if (!is_struct(_cur)) continue;
        var _prio_cur = 0;
        var _spd_cur = 0;
        try {
            var _actor_cur_prio = variable_struct_get(_B, "actor")[floor(variable_struct_get(_cur, "actor_index"))];
            _prio_cur = __battle_action_effective_priority(_actor_cur_prio, _cur);
        } catch (e_prio_cur) { _prio_cur = 0; }
        try {
            var _actor_cur = variable_struct_get(_B, "actor")[floor(variable_struct_get(_cur, "actor_index"))];
            _spd_cur = __battle_stat_get(_actor_cur, "spd");
        } catch (e_spd_cur) { _spd_cur = 0; }
        var _goes_before = false;
        if (_prio_new > _prio_cur) _goes_before = true;
        else if (_prio_new == _prio_cur){
            if (_spd_new > _spd_cur) _goes_before = true;
            else if (_spd_new == _spd_cur) _goes_before = choose(true, false);
        }
        if (_goes_before){
            _insert_at = _i;
            break;
        }
    }
    array_push(_actions, _act);
    for (var _j = array_length(_actions) - 1; _j > _insert_at; --_j) _actions[_j] = _actions[_j - 1];
    _actions[_insert_at] = _act;
    return _actions;
}

function battle_difficulty(){
    if (!variable_global_exists("BATTLE_DIFFICULTY")) global.BATTLE_DIFFICULTY = "normal";
    var _d = string_lower(string(global.BATTLE_DIFFICULTY));
    if (_d != "easy" && _d != "normal" && _d != "hard" && _d != "very_hard") _d = "normal";
    global.BATTLE_DIFFICULTY = _d;
    return _d;
}

function battle_difficulty_rank(){
    switch (battle_difficulty()){
        case "easy": return 0;
        case "hard": return 2;
        case "very_hard": return 3;
    }
    return 1;
}

function battle_difficulty_cycle(_dir){
    var _modes = ["easy", "normal", "hard", "very_hard"];
    var _cur = battle_difficulty();
    var _idx = 1;
    for (var _i = 0; _i < array_length(_modes); ++_i){
        if (_modes[_i] == _cur){ _idx = _i; break; }
    }
    var _step = (is_real(_dir) && _dir < 0) ? -1 : 1;
    _idx = (_idx + _step + array_length(_modes)) mod array_length(_modes);
    global.BATTLE_DIFFICULTY = _modes[_idx];
    try {
        ini_open("settings.ini");
        ini_write_string("Battle", "difficulty", global.BATTLE_DIFFICULTY);
        ini_close();
    } catch (e_diff_save) {}
    return global.BATTLE_DIFFICULTY;
}

function __battle_enemy_move_score(_pid, _actorIndex, _slot, _move_id, _targetIndex, _rank){
    var _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B) || !is_array(_B.actor)) return 0;
    var _A = (_actorIndex >= 0 && _actorIndex < array_length(_B.actor)) ? _B.actor[_actorIndex] : undefined;
    var _D = (_targetIndex >= 0 && _targetIndex < array_length(_B.actor)) ? _B.actor[_targetIndex] : undefined;
    if (!is_struct(_A) || !is_struct(_D)) return 0;
    var _power = 0;
    try { _power = __battle_move_power(_move_id, _A, _D); } catch (e_ai_power) { _power = 0; }
    var _score = 0;
    if (is_real(_power) && _power > 0){
        try { _score = __battle_calc_damage(_A, _D, _move_id, _power); } catch (e_ai_damage) { _score = _power; }
        var _hp = __battle_hp_now(_D);
        if (is_real(_hp) && _hp > 0 && _score >= _hp) _score += 1000;
        if (_rank >= 3){
            try {
                var _def_hp_max = __battle_hp_max(_D);
                if (is_real(_def_hp_max) && _def_hp_max > 0) _score += floor((_score / _def_hp_max) * 30);
            } catch (e_ai_vh_hp) {}
        }
    } else {
        _score = 8 + irandom(10);
        try {
            var _meta = __battle_get_move_meta(_move_id);
            var _target_mode = (is_struct(_meta) && variable_struct_exists(_meta, "target")) ? string_lower(string(variable_struct_get(_meta, "target"))) : "";
            if (string_pos("user", _target_mode) > 0 || string_pos("self", _target_mode) > 0) _score += (_rank >= 2 ? 8 : 0);
        } catch (e_ai_status_meta) {}
    }
    return _score + irandom(max(1, 8 - (_rank * 2)));
}

function __battle_choose_action_for_actor(_pid, _actorIndex, _randomize){
    var _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B) || !is_array(_B.actor) || !is_real(_actorIndex)) return undefined;
    var _idx = floor(_actorIndex);
    if (_idx < 0 || _idx >= array_length(_B.actor)) return undefined;
    var _A = _B.actor[_idx];
    if (!is_struct(_A) || __battle_is_fainted(_A)) return undefined;
    var _choices = [];
    for (var _i = 0; _i < 4; ++_i){
        var _mv = (variable_struct_exists(_A, "moves") && is_array(variable_struct_get(_A, "moves")) && _i < array_length(variable_struct_get(_A, "moves"))) ? variable_struct_get(_A, "moves")[_i] : -1;
        var _pp = (variable_struct_exists(_A, "pps") && is_array(variable_struct_get(_A, "pps")) && _i < array_length(variable_struct_get(_A, "pps"))) ? variable_struct_get(_A, "pps")[_i] : 0;
        if (is_real(_mv) && _mv >= 0 && is_real(_pp) && _pp > 0) array_push(_choices, _i);
    }
    if (array_length(_choices) <= 0) return __battle_make_struggle_action(_pid, _idx);
    var _pick = _choices[0];
    var _target_pick = __battle_get_default_target_index(_pid, _idx);
    var _rank = battle_difficulty_rank();
    if (_randomize && array_length(_choices) > 1){
        if (_rank <= 1){
            _pick = _choices[irandom(array_length(_choices) - 1)];
            if (_rank == 0 && random(1) < 0.65){
                var _weak_score = 999999;
                for (var _ei = 0; _ei < array_length(_choices); ++_ei){
                    var _weak_slot = _choices[_ei];
                    var _weak_mv = _A.moves[_weak_slot];
                    var _weak_targets = __battle_target_candidates(_pid, _idx, _weak_mv);
                    if (!is_array(_weak_targets) || array_length(_weak_targets) <= 0) _weak_targets = [__battle_get_default_target_index(_pid, _idx)];
                    var _weak_target = _weak_targets[0];
                    var _weak_val = __battle_enemy_move_score(_pid, _idx, _weak_slot, _weak_mv, _weak_target, _rank);
                    if (_weak_val < _weak_score){
                        _weak_score = _weak_val;
                        _pick = _weak_slot;
                        _target_pick = _weak_target;
                    }
                }
            }
        } else {
            var _best_score = -999999;
            for (var _bi = 0; _bi < array_length(_choices); ++_bi){
                var _slot = _choices[_bi];
                var _mv_ai = _A.moves[_slot];
                var _targets_ai = __battle_target_candidates(_pid, _idx, _mv_ai);
                if (!is_array(_targets_ai) || array_length(_targets_ai) <= 0) _targets_ai = [__battle_get_default_target_index(_pid, _idx)];
                for (var _ti = 0; _ti < array_length(_targets_ai); ++_ti){
                    var _target_ai = _targets_ai[_ti];
                    var _score_ai = __battle_enemy_move_score(_pid, _idx, _slot, _mv_ai, _target_ai, _rank);
                    if (_score_ai > _best_score){
                        _best_score = _score_ai;
                        _pick = _slot;
                        _target_pick = _target_ai;
                    }
                }
            }
        }
    }
    return {
        actor_index: _idx,
        slot: _pick,
        move_id: _A.moves[_pick],
        target_index: _target_pick
    };
}

function __battle_actor_has_usable_pp(_actor){
    if (!is_struct(_actor)) return false;
    var _moves = (variable_struct_exists(_actor, "moves") && is_array(variable_struct_get(_actor, "moves"))) ? variable_struct_get(_actor, "moves") : [];
    var _pps = (variable_struct_exists(_actor, "pps") && is_array(variable_struct_get(_actor, "pps"))) ? variable_struct_get(_actor, "pps") : [];
    for (var _i = 0; _i < 4; ++_i){
        var _mv = (_i < array_length(_moves)) ? _moves[_i] : -1;
        var _pp = (_i < array_length(_pps)) ? _pps[_i] : 0;
        if (is_real(_mv) && _mv >= 0 && is_real(_pp) && _pp > 0) return true;
    }
    return false;
}

function __battle_close_transition_style(_B){
    if (is_struct(_B)){
        if (variable_struct_exists(_B, "result") && string(variable_struct_get(_B, "result")) == "lose") return "emerald_fade_white";
        if (variable_struct_exists(_B, "_close_transition_style")) return string(variable_struct_get(_B, "_close_transition_style"));
    }
    return "emerald_fade_black";
}

function __battle_begin_close_transition(_B, _now_ms){
    if (!is_struct(_B)) return false;
    variable_struct_set(_B, "_close_start_ms", _now_ms);
    variable_struct_set(_B, "_close_dur_ms", 600);
    variable_struct_set(_B, "_close_transition_style", __battle_close_transition_style(_B));
    variable_struct_set(_B, "_closing", true);
    return true;
}

function __battle_make_struggle_action(_pid, _actorIndex){
    var _idx = is_real(_actorIndex) ? floor(_actorIndex) : 0;
    return {
        actor_index: _idx,
        slot: -1,
        move_id: -1,
        target_index: __battle_get_default_target_index(_pid, _idx),
        struggle: true
    };
}

/// Check if a battle is currently open for the given player id.
/// Params: _pid (int)
/// Returns: bool
function battle_is_open(_pid){
    var _B = __battle_ensure_slot(_pid);
    return (_B.sys_open == true);
}

function battle_any_open(){
    if (!variable_global_exists("sys_battles") || !is_array(global.sys_battles)) return false;
    for (var _bi = 0; _bi < array_length(global.sys_battles); ++_bi){
        var _slot = global.sys_battles[_bi];
        if (!is_struct(_slot)) continue;
        if (variable_struct_exists(_slot, "sys_open") && variable_struct_get(_slot, "sys_open") == true) return true;
    }
    return false;
}

/// Centralized per-frame battle controller update.
/// Steps every open battle slot exactly once per frame from a single owner.
function battle_controller_update_all(){
    if (!variable_global_exists("sys_battles") || !is_array(global.sys_battles)) return;
    for (var _pid = 0; _pid < array_length(global.sys_battles); ++_pid){
        var _slot = global.sys_battles[_pid];
        if (!is_struct(_slot)) continue;
        if (!variable_struct_exists(_slot, "sys_open") || variable_struct_get(_slot, "sys_open") != true) continue;
        var _duplicate_slot = false;
        for (var _prev_pid = 0; _prev_pid < _pid; ++_prev_pid){
            if (global.sys_battles[_prev_pid] == _slot){
                _duplicate_slot = true;
                break;
            }
        }
        if (_duplicate_slot) continue;
        battle_update(_pid);
        var _fmt = variable_struct_exists(_slot, "battle_format") ? string_lower(string(variable_struct_get(_slot, "battle_format"))) : "single";
        var _coop = variable_struct_exists(_slot, "coop_enabled") && variable_struct_get(_slot, "coop_enabled") == true;
        var _versus = variable_struct_exists(_slot, "versus_enabled") && variable_struct_get(_slot, "versus_enabled") == true;
        if (((_fmt == "double" && _coop) || _versus) && variable_struct_exists(_slot, "player_pids") && is_array(variable_struct_get(_slot, "player_pids"))){
            var _ppids = variable_struct_get(_slot, "player_pids");
            for (var _cpi = 0; _cpi < array_length(_ppids); ++_cpi){
                var _cpid = _ppids[_cpi];
                if (!is_real(_cpid) || floor(_cpid) == _pid) continue;
                if (variable_struct_exists(_slot, "phase") && string(variable_struct_get(_slot, "phase")) == "command"){
                    __battle_process_input(floor(_cpid));
                }
            }
        }
    }
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

// Guarded stub for scr_compute_grounded_flag to satisfy the static analyzer when
// battle_system references it before the factory script is processed.
// Note: scr_compute_grounded_flag is defined in pokemon_factory.gml.
// Do not define a fallback here to avoid duplicate script name errors in GameMaker.

// Move meta helpers now live in battle_move_meta_helpers.gml

if (is_undefined(__battle_actor_is_dynamax)){
    function __battle_actor_is_dynamax(_actor){
        if (!is_struct(_actor)) return false;
        var base = _actor;
        if (variable_struct_exists(_actor, "mon") && is_struct(variable_struct_get(_actor, "mon"))) base = variable_struct_get(_actor, "mon");
        var flags = ["is_dynamax", "_is_dynamax", "dynamax", "gigantamax", "maxed", "is_max" ];
        for (var i = 0; i < array_length(flags); ++i){
            var key = flags[i];
            if (variable_struct_exists(_actor, key)){
                var v = variable_struct_get(_actor, key);
                if (is_bool(v) && v) return true;
                if (is_real(v) && v > 0) return true;
            }
            if (variable_struct_exists(base, key)){
                var vb = variable_struct_get(base, key);
                if (is_bool(vb) && vb) return true;
                if (is_real(vb) && vb > 0) return true;
            }
        }
        try {
            if (variable_struct_exists(_actor, "form") && is_string(variable_struct_get(_actor, "form"))){
                var f = string_lower(string(variable_struct_get(_actor, "form")));
                if (string_pos("max", f) > 0) return true;
            }
        } catch (e_forma) {}
        try {
            if (variable_struct_exists(base, "form") && is_string(variable_struct_get(base, "form"))){
                var f2 = string_lower(string(variable_struct_get(base, "form")));
                if (string_pos("max", f2) > 0) return true;
            }
        } catch (e_formb) {}
        try {
            if (!is_undefined(status_system_has_status)){
                if (status_system_has_status(_actor, "dynamax")) return true;
                if (status_system_has_status(base, "dynamax")) return true;
            }
        } catch (e_stat) {}
        return false;
    }
}

// Jaw Lock helpers now live in battle_jaw_lock_helpers.gml

// Terrain helpers now live in battle_terrain_helpers.gml

// Weather helpers (__battle_get_weather, __battle_clear_weather, etc.) now reside in battle_weather_helpers.gml

if (is_undefined(__battle_resolve_pid_for_actor)){
    function __battle_resolve_pid_for_actor(_actor){
        try {
            if (!variable_global_exists("sys_battles") || !is_array(global.sys_battles)) return 0;
            for (var ii = 0; ii < array_length(global.sys_battles); ++ii){
                var slot = global.sys_battles[ii];
                if (!is_struct(slot)) continue;
                if (!variable_struct_exists(slot, "actor") || !is_array(variable_struct_get(slot, "actor"))) continue;
                var arr = variable_struct_get(slot, "actor");
                for (var jj = 0; jj < array_length(arr); ++jj){
                    if (is_struct(arr[jj]) && arr[jj] == _actor) return ii;
                }
            }
        } catch (e_pid) {}
        return 0;
    }
}

// Weather effect application helpers now reside in battle_weather_helpers.gml

if (is_undefined(__battle_request_animation_safe)){
    function __battle_request_animation_safe(_pid_or_mon, _payload){
        try {
            if (is_real(_pid_or_mon)){
                var _pid_val = floor(_pid_or_mon);
                var _slot = __battle_ensure_slot(_pid_val);
                if (is_struct(_slot)){
                    var _queued = false;
                    if (!is_undefined(battle_anim_queue_enqueue)){
                        _queued = battle_anim_queue_enqueue(_pid_val, _payload);
                    }
                    if (!_queued){
                        if (!variable_struct_exists(_slot, "_pending_anims") || !is_array(variable_struct_get(_slot, "_pending_anims"))) variable_struct_set(_slot, "_pending_anims", []);
                        var _arr = variable_struct_get(_slot, "_pending_anims"); array_push(_arr, _payload);
                    }
                }
                return;
            }
            if (is_struct(_pid_or_mon)){
                var _pid_guess = undefined;
                if (!is_undefined(__status_find_battle_pid)) _pid_guess = __status_find_battle_pid(_pid_or_mon);
                if (is_undefined(_pid_guess) && !is_undefined(__battle_anim_queue_find_pid_for_actor)) _pid_guess = __battle_anim_queue_find_pid_for_actor(_pid_or_mon);
                if (is_real(_pid_guess)){
                    if (!is_undefined(battle_anim_queue_enqueue)) battle_anim_queue_enqueue(_pid_guess, _payload);
                }
                try { if (!is_undefined(__status_request_dialog_for_mon)) __status_request_dialog_for_mon(_pid_or_mon, (is_struct(_payload) && variable_struct_exists(_payload, "msg") ? variable_struct_get(_payload, "msg") : undefined), false); } catch (e_msg) {}
            }
        } catch (e_any) {}
    }
}



// Safe audio handle stop helper: try to stop a channel handle, otherwise fall back
// Stop an audio handle/channel safely. Falls back to global stop if needed.
function __battle_audio_stop_handle(_h){
    try {
        if (!is_undefined(audio_stop_sound) && !is_undefined(_h)){
            audio_stop_sound(_h);
            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][audio] stopped handle=" + string(_h));
        }
    } catch (e) {
        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][audio] stop_handle error: " + string(e));
    }
}

// Safe wrapper to play a sound resource using the best available runtime API.
// Returns an audio channel/handle when possible, otherwise undefined.
// Play a sound resource using the best runtime API available. Returns
// an audio handle/channel when possible, otherwise undefined.
function __battle_sound_play_safe(_res, _loop = false){
    try {
        if (is_undefined(_res)) return undefined;
        // Prefer audio_play_sound (modern runtime) which may return a channel id.
        if (!is_undefined(audio_play_sound)){
            var _ret = undefined;
            try { _ret = audio_play_sound(_res, 1, _loop); } catch (e_ap) { _ret = undefined; }
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
                try { ch = audio_play_sound(stream, 1, _loop); } catch (e_ch) { ch = undefined; }
                if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][audio] audio_create_stream+play returned " + string(ch));
                return ch;
            }
        }
    } catch (e) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][audio] __battle_sound_play_safe error: " + string(e)); }
    return undefined;
}

function __battle_stop_bgm_for_slot(_B){
    if (!is_struct(_B)) return;
    try {
        var _bgm_handle = variable_struct_exists(_B, "_bgm_handle") ? variable_struct_get(_B, "_bgm_handle") : undefined;
        if (!is_undefined(_bgm_handle)) __battle_audio_stop_handle(_bgm_handle);
    } catch (e_stop_bgm_slot) {}
    try { variable_struct_set(_B, "_bgm_handle", undefined); } catch (e_clear_bgm_slot) {}
    try { variable_struct_set(_B, "_battle_bgm_playing", false); } catch (e_flag_bgm_slot) {}
}

function __battle_start_bgm_once(_B){
    if (!is_struct(_B)) return undefined;
    var _already = false;
    try { _already = (variable_struct_exists(_B, "_battle_bgm_playing") && variable_struct_get(_B, "_battle_bgm_playing") == true); } catch (e_already_bgm) { _already = false; }
    if (_already) return variable_struct_exists(_B, "_bgm_handle") ? variable_struct_get(_B, "_bgm_handle") : undefined;

    var _music = variable_struct_exists(_B, "_battle_music") ? variable_struct_get(_B, "_battle_music") : undefined;
    if (is_undefined(_music)) return undefined;
    var _handle = undefined;
    try { _handle = __battle_sound_play_safe(_music, true); } catch (e_play_bgm_once) { _handle = undefined; }
    try { variable_struct_set(_B, "_bgm_handle", _handle); } catch (e_set_bgm_once) {}
    try { variable_struct_set(_B, "_battle_bgm_playing", true); } catch (e_flag_bgm_once) {}
    return _handle;
}

function __battle_play_defeated_music_once(_B){
    if (!is_struct(_B)) return undefined;
    var _already = false;
    try { _already = (variable_struct_exists(_B, "_defeated_music_playing") && variable_struct_get(_B, "_defeated_music_playing") == true); } catch (e_already_def) { _already = false; }
    if (_already) return variable_struct_exists(_B, "_defeated_handle") ? variable_struct_get(_B, "_defeated_handle") : undefined;

    __battle_stop_bgm_for_slot(_B);
    var _def_res = variable_struct_exists(_B, "_battle_defeated_music") ? variable_struct_get(_B, "_battle_defeated_music") : undefined;
    if (is_undefined(_def_res)) return undefined;
    var _handle = undefined;
    try { _handle = __battle_sound_play_safe(_def_res, true); } catch (e_play_def_once) { _handle = undefined; }
    try { variable_struct_set(_B, "_defeated_handle", _handle); } catch (e_set_def_once) {}
    try { variable_struct_set(_B, "_defeated_music_playing", true); } catch (e_flag_def_once) {}
    return _handle;
}

// Command queue and target-pick helpers live in battle_command_helpers.gml.
// Play a sound once (non-looping). Prefer audio_play_sound with loop=false when
// available; otherwise fall back to __battle_sound_play_safe. Returns true when
// a play was attempted.
// Play a sound once (non-looping). Returns true if a play was attempted.
function __battle_play_one_shot(_res){
    try {
        if (is_undefined(_res)) return false;
        if (!is_undefined(audio_play_sound)){
            try { audio_play_sound(_res, 1, false); return true; } catch (e_ap) { /* fallthrough to fallback */ }
        }
        if (!is_undefined(__battle_sound_play_safe)){
            try { __battle_sound_play_safe(_res); return true; } catch (e_bs) { /* ignore */ }
        }
    } catch (e) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][audio] __battle_play_one_shot failed: " + string(e)); }
    return false;
}

// Play heal SFX but deduplicate repeated plays within a short timeframe
// so items/multi-target heals don't trigger multiple overlapping sounds.
// Play a heal SFX but deduplicate repeats within a short timeframe.
function __battle_play_heal_once(_res){
    try {
        var now = (is_undefined(current_time) ? undefined : current_time);
        if (is_undefined(now)) now = date_current_datetime();
        var last = (variable_global_exists("_last_heal_play_ms") ? global._last_heal_play_ms : undefined);
        if (is_undefined(last) || last == undefined) last = -99999999;
        var delta = 99999999;
        try { delta = real(now) - real(last); } catch (e) { delta = 99999999; }
        // If a heal sound played recently (within 300ms), suppress this one
        if (is_real(delta) && delta >= 0 && delta < 300) return false;
        // Attempt one-shot play
        var ok = __battle_play_one_shot(_res);
        try { global._last_heal_play_ms = now; } catch (e2) {}
        return ok;
    } catch (e) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][audio] __battle_play_heal_once failed: " + string(e)); }
    return false;
}

function __battle_ability_actor_has_status_from_list(_actor, _statuses){
    if (!is_struct(_actor) || is_undefined(status_system_has_status)) return false;
    if (!is_array(_statuses)) _statuses = [string(_statuses)];
    for (var _i = 0; _i < array_length(_statuses); ++_i){
        var _sid = string_lower(string(_statuses[_i]));
        try {
            if (status_system_has_status(_actor, _sid)) return true;
            if (variable_struct_exists(_actor, "mon") && is_struct(variable_struct_get(_actor, "mon")) && status_system_has_status(variable_struct_get(_actor, "mon"), _sid)) return true;
        } catch (e_status_has) {}
    }
    return false;
}

function __battle_ability_clear_major_status(_actor){
    if (!is_struct(_actor) || is_undefined(status_system_clear_status)) return false;
    var _ids = ["burn", "poison", "toxic", "paralysis", "paralyze", "sleep", "freeze"];
    var _did = false;
    for (var _i = 0; _i < array_length(_ids); ++_i){
        try { if (status_system_clear_status(_actor, _ids[_i])) _did = true; } catch (e_clear_actor) {}
        try {
            if (variable_struct_exists(_actor, "mon") && is_struct(variable_struct_get(_actor, "mon"))){
                if (status_system_clear_status(variable_struct_get(_actor, "mon"), _ids[_i])) _did = true;
            }
        } catch (e_clear_mon) {}
    }
    return _did;
}

function __battle_ability_weather_matches(_pid, _weather_list){
    try {
        if (is_undefined(__battle_get_weather) || is_undefined(__battle_weather_is_active) || is_undefined(__battle_weather_get_normalized_id)) return false;
        if (!is_array(_weather_list)) _weather_list = [string(_weather_list)];
        if (!is_undefined(__battle_weather_suppressed_by_ability) && __battle_weather_suppressed_by_ability(_pid)) return false;
        var _w = __battle_get_weather(_pid);
        if (!__battle_weather_is_active(_w)) return false;
        var _wid = __battle_weather_get_normalized_id(_w);
        for (var _i = 0; _i < array_length(_weather_list); ++_i){
            if (string_lower(string(_weather_list[_i])) == _wid) return true;
        }
    } catch (e_wmatch) {}
    return false;
}

function __battle_apply_end_turn_ability_actions(_pid){
    var _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B) || !variable_struct_exists(_B, "actor") || !is_array(variable_struct_get(_B, "actor"))) return false;
    var _actors = variable_struct_get(_B, "actor");
    var _did = false;
    for (var _ai = 0; _ai < array_length(_actors); ++_ai){
        var _actor = _actors[_ai];
        if (!is_struct(_actor) || __battle_hp_now(_actor) <= 0) continue;
        try {
            var _reuse_id_any = (variable_struct_exists(_actor, "_reuse_berry_next_turn_id") && is_real(variable_struct_get(_actor, "_reuse_berry_next_turn_id"))) ? floor(variable_struct_get(_actor, "_reuse_berry_next_turn_id")) : -1;
            if (_reuse_id_any > 0 && !is_undefined(scr_apply_item_effects)){
                variable_struct_set(_actor, "_reuse_berry_next_turn_id", -1);
                variable_struct_set(_actor, "_reusing_berry_from_ability", true);
                try {
                    var _reuse_any_res = scr_apply_item_effects(_reuse_id_any, (variable_struct_exists(_actor, "mon") ? variable_struct_get(_actor, "mon") : undefined), _actor);
                } catch (e_reuse_any) {}
                variable_struct_set(_actor, "_reusing_berry_from_ability", false);
                var _reuse_actions_any = __battle_actor_ability_actions(_actor, "after_item_consumed");
                for (var _rai = 0; _rai < array_length(_reuse_actions_any); ++_rai){
                    var _reuse_act_any = _reuse_actions_any[_rai];
                    if (!is_struct(_reuse_act_any)) continue;
                    var _reuse_kind_any = variable_struct_exists(_reuse_act_any, "kind") ? string_lower(string(variable_struct_get(_reuse_act_any, "kind"))) : "";
                    if (_reuse_kind_any == "reuse_berry_next_turn"){
                        try { __battle_queue_ability_action_dialog(_actor, _reuse_act_any, _actor, {}); } catch (e_reuse_any_dialog) {}
                        break;
                    }
                }
                _did = true;
            }
            try {
                var _stage_event_end_actions = __battle_actor_ability_actions(_actor, "stage_event_check");
                for (var _sea = 0; _sea < array_length(_stage_event_end_actions); ++_sea){
                    var _seact_end = _stage_event_end_actions[_sea];
                    if (!is_struct(_seact_end)) continue;
                    var _sekind_end = variable_struct_exists(_seact_end, "kind") ? string_lower(string(variable_struct_get(_seact_end, "kind"))) : "";
                    if (_sekind_end != "conditional_stage_event") continue;
                    var _ab_end = (!is_undefined(__battle_actor_ability_name_lc)) ? __battle_actor_ability_name_lc(_actor) : "";
                    if (_ab_end == "moody"){
                        var _moody_stats = ["atk","def","spa","spd","spe"];
                        var _raise_i = irandom(array_length(_moody_stats) - 1);
                        var _lower_i = irandom(array_length(_moody_stats) - 1);
                        if (array_length(_moody_stats) > 1){
                            var _guard_moody = 0;
                            while (_lower_i == _raise_i && _guard_moody < 12){ _lower_i = irandom(array_length(_moody_stats) - 1); _guard_moody += 1; }
                        }
                        var _moody_did = false;
                        if (!is_undefined(__battle_ability_change_stage)){
                            if (__battle_ability_change_stage(_actor, _moody_stats[_raise_i], 2)) _moody_did = true;
                            if (__battle_ability_change_stage(_actor, _moody_stats[_lower_i], -1)) _moody_did = true;
                        }
                        if (_moody_did){
                            try { __battle_queue_ability_action_dialog(_actor, _seact_end, _actor, {}); } catch (e_moody_dialog) {}
                            _did = true;
                        }
                    }
                }
            } catch (e_stage_event_end) {}
            var _actions = __battle_actor_ability_actions(_actor, "end_turn");
            for (var _ei = 0; _ei < array_length(_actions); ++_ei){
                var _act = _actions[_ei];
                if (!is_struct(_act)) continue;
                var _kind = variable_struct_exists(_act, "kind") ? string_lower(string(variable_struct_get(_act, "kind"))) : "";
                var _data = (variable_struct_exists(_act, "data") && is_struct(variable_struct_get(_act, "data"))) ? variable_struct_get(_act, "data") : {};
                if (_kind == "self_stage_change"){
                    if (!is_undefined(__battle_ability_apply_self_stage_action) && __battle_ability_apply_self_stage_action(_actor, _act)) _did = true;
                } else if (_kind == "weather_fraction_heal"){
                    var _wheal_list = variable_struct_exists(_data, "weather") ? variable_struct_get(_data, "weather") : [];
                    if (!__battle_ability_weather_matches(_pid, _wheal_list)) continue;
                    var _hfrac = (variable_struct_exists(_data, "fraction") && is_real(variable_struct_get(_data, "fraction"))) ? variable_struct_get(_data, "fraction") : 0.0625;
                    var _before_h = __battle_hp_now(_actor);
                    var _max_h = max(1, __battle_hp_max(_actor));
                    var _heal = max(1, floor(_max_h * _hfrac));
                    var _after_h = min(_max_h, _before_h + _heal);
                    if (_after_h > _before_h){
                        __battle_set_hp_now(_actor, _after_h);
                        try { __battle_clear_fainted_if_healed(_actor); } catch (e_heal_clear) {}
                        try { __battle_request_animation_safe(_pid, { type:"heal", actor:_actor, target_index:_ai, amount:(_after_h - _before_h) }); } catch (e_heal_anim) {}
                        try { __battle_queue_ability_action_dialog(_actor, _act, _actor, {}); } catch (e_heal_dialog) {}
                        _did = true;
                    }
                } else if (_kind == "heal_when_status"){
                    var _status_list = variable_struct_exists(_data, "status") ? variable_struct_get(_data, "status") : ["poison","toxic"];
                    if (!__battle_ability_actor_has_status_from_list(_actor, _status_list)) continue;
                    var _sfrac = (variable_struct_exists(_data, "fraction") && is_real(variable_struct_get(_data, "fraction"))) ? variable_struct_get(_data, "fraction") : 0.125;
                    var _sbefore = __battle_hp_now(_actor);
                    var _smax = max(1, __battle_hp_max(_actor));
                    var _safter = min(_smax, _sbefore + max(1, floor(_smax * _sfrac)));
                    if (_safter > _sbefore){
                        __battle_set_hp_now(_actor, _safter);
                        try { __battle_request_animation_safe(_pid, { type:"heal", actor:_actor, target_index:_ai, amount:(_safter - _sbefore) }); } catch (e_status_heal_anim) {}
                        try { __battle_queue_ability_action_dialog(_actor, _act, _actor, {}); } catch (e_status_heal_dialog) {}
                        _did = true;
                    }
                } else if (_kind == "weather_fraction_damage"){
                    var _wdmg_list = variable_struct_exists(_data, "weather") ? variable_struct_get(_data, "weather") : [];
                    if (!__battle_ability_weather_matches(_pid, _wdmg_list)) continue;
                    var _dfrac = (variable_struct_exists(_data, "fraction") && is_real(variable_struct_get(_data, "fraction"))) ? variable_struct_get(_data, "fraction") : 0.125;
                    var _dmg = max(1, floor(max(1, __battle_hp_max(_actor)) * _dfrac));
                    try { __battle_queue_ability_action_dialog(_actor, _act, _actor, {}); } catch (e_weather_dmg_dialog) {}
                    __battle_apply_damage(_pid, _ai, _dmg, 1.0);
                    _did = true;
                } else if (_kind == "cure_major_status_chance"){
                    var _chance = (variable_struct_exists(_data, "chance") && is_real(variable_struct_get(_data, "chance"))) ? variable_struct_get(_data, "chance") : 30;
                    if (irandom(99) < _chance && __battle_ability_clear_major_status(_actor)){
                        try { __battle_queue_ability_action_dialog(_actor, _act, _actor, {}); } catch (e_cure_dialog) {}
                        _did = true;
                    }
                } else if (_kind == "cure_major_status_in_weather"){
                    var _cw_list = variable_struct_exists(_data, "weather") ? variable_struct_get(_data, "weather") : [];
                    if (__battle_ability_weather_matches(_pid, _cw_list) && __battle_ability_clear_major_status(_actor)){
                        try { __battle_queue_ability_action_dialog(_actor, _act, _actor, {}); } catch (e_wcure_dialog) {}
                        _did = true;
                    }
                } else if (_kind == "damage_sleeping_opponents_fraction"){
                    var _side = (!is_undefined(__battle_actor_side) ? __battle_actor_side(_ai) : ((_ai <= 1) ? 0 : 1));
                    var _frac_sleep = (variable_struct_exists(_data, "fraction") && is_real(variable_struct_get(_data, "fraction"))) ? variable_struct_get(_data, "fraction") : 0.125;
                    for (var _oi = 0; _oi < array_length(_actors); ++_oi){
                        if (_oi == _ai || !is_struct(_actors[_oi]) || __battle_hp_now(_actors[_oi]) <= 0) continue;
                        var _oside = (!is_undefined(__battle_actor_side) ? __battle_actor_side(_oi) : ((_oi <= 1) ? 0 : 1));
                        if (_oside == _side || !__battle_ability_actor_has_status_from_list(_actors[_oi], ["sleep"])) continue;
                        var _sdmg = max(1, floor(max(1, __battle_hp_max(_actors[_oi])) * _frac_sleep));
                        try { __battle_queue_ability_action_dialog(_actor, _act, _actors[_oi], {}); } catch (e_bad_dreams_dialog) {}
                        __battle_apply_damage(_pid, _oi, _sdmg, 1.0);
                        _did = true;
                    }
                } else if (_kind == "restore_consumed_berry_chance"){
                    var _held_now = (variable_struct_exists(_actor, "held_item_id") && is_real(variable_struct_get(_actor, "held_item_id"))) ? floor(variable_struct_get(_actor, "held_item_id")) : -1;
                    var _restore_id = (variable_struct_exists(_actor, "_last_consumed_berry_id") && is_real(variable_struct_get(_actor, "_last_consumed_berry_id"))) ? floor(variable_struct_get(_actor, "_last_consumed_berry_id")) : -1;
                    if (_held_now <= 0 && _restore_id > 0 && !is_undefined(__battle_ability_item_is_berry) && __battle_ability_item_is_berry(_restore_id)){
                        var _chance_restore = (variable_struct_exists(_data, "chance") && is_real(variable_struct_get(_data, "chance"))) ? variable_struct_get(_data, "chance") : 50;
                        var _sun_chance = (variable_struct_exists(_data, "sun_chance") && is_real(variable_struct_get(_data, "sun_chance"))) ? variable_struct_get(_data, "sun_chance") : _chance_restore;
                        if (__battle_ability_weather_matches(_pid, ["sun","harsh-sun"])) _chance_restore = _sun_chance;
                        if (irandom(99) < _chance_restore){
                            var _restore_name = (!is_undefined(__battle_ability_item_name_by_id)) ? __battle_ability_item_name_by_id(_restore_id) : "";
                            variable_struct_set(_actor, "held_item_id", _restore_id);
                            variable_struct_set(_actor, "held_item_real_name", _restore_name);
                            if (variable_struct_exists(_actor, "mon") && is_struct(variable_struct_get(_actor, "mon"))){
                                var _restore_mon = variable_struct_get(_actor, "mon");
                                variable_struct_set(_restore_mon, "held_item_id", _restore_id);
                                variable_struct_set(_restore_mon, "held_item_real_name", _restore_name);
                            }
                            try { __battle_queue_ability_action_dialog(_actor, _act, _actor, {}); } catch (e_harvest_dialog) {}
                            _did = true;
                        }
                    }
                } else if (_kind == "reuse_berry_next_turn"){
                    var _reuse_id = (variable_struct_exists(_actor, "_reuse_berry_next_turn_id") && is_real(variable_struct_get(_actor, "_reuse_berry_next_turn_id"))) ? floor(variable_struct_get(_actor, "_reuse_berry_next_turn_id")) : -1;
                    if (_reuse_id > 0 && !is_undefined(scr_apply_item_effects)){
                        variable_struct_set(_actor, "_reuse_berry_next_turn_id", -1);
                        variable_struct_set(_actor, "_reusing_berry_from_ability", true);
                        var _reuse_res = scr_apply_item_effects(_reuse_id, (variable_struct_exists(_actor, "mon") ? variable_struct_get(_actor, "mon") : undefined), _actor);
                        variable_struct_set(_actor, "_reusing_berry_from_ability", false);
                        try { __battle_queue_ability_action_dialog(_actor, _act, _actor, {}); } catch (e_reuse_dialog) {}
                        _did = true;
                    }
                }
            }
            if (!is_undefined(item_runtime_actor_held_actions)){
                var _item_end_actions = item_runtime_actor_held_actions(_actor, "end_turn");
                for (var _iei = 0; _iei < array_length(_item_end_actions); ++_iei){
                    var _iact_end = _item_end_actions[_iei];
                    if (!is_struct(_iact_end)) continue;
                    var _ikind_end = variable_struct_exists(_iact_end, "kind") ? string_lower(string(variable_struct_get(_iact_end, "kind"))) : "";
                    var _idata_end = (variable_struct_exists(_iact_end, "data") && is_struct(variable_struct_get(_iact_end, "data"))) ? variable_struct_get(_iact_end, "data") : {};
                    var _num_end = (variable_struct_exists(_idata_end, "numerator") && is_real(variable_struct_get(_idata_end, "numerator"))) ? variable_struct_get(_idata_end, "numerator") : 1;
                    var _den_end = (variable_struct_exists(_idata_end, "denominator") && is_real(variable_struct_get(_idata_end, "denominator"))) ? max(1, variable_struct_get(_idata_end, "denominator")) : 16;
                    var _amt_end = max(1, floor(max(1, __battle_hp_max(_actor)) * _num_end / _den_end));
                    if (_ikind_end == "heal_max_hp_fraction"){
                        var _before_end_h = __battle_hp_now(_actor);
                        var _after_end_h = min(max(1, __battle_hp_max(_actor)), _before_end_h + _amt_end);
                        if (_after_end_h > _before_end_h){
                            __battle_set_hp_now(_actor, _after_end_h);
                            try { __battle_clear_fainted_if_healed(_actor); } catch (e_item_end_heal_clear) {}
                            try { __battle_request_animation_safe(_pid, { type:"heal", actor:_actor, target_index:_ai, amount:(_after_end_h - _before_end_h) }); } catch (e_item_end_heal_anim) {}
                            try { dialog_queue(__battle_ability_actor_name(_actor, "The Pokemon") + " restored HP using its " + __battle_held_item_label(_actor) + "!"); } catch (e_item_end_heal_dialog) {}
                            _did = true;
                        }
                    } else if (_ikind_end == "poison_heal_else_damage_fraction"){
                        var _is_poison_type = false;
                        try { _is_poison_type = __battle_actor_has_type_name_runtime(_actor, "poison"); } catch (e_item_poison_type) { _is_poison_type = false; }
                        if (_is_poison_type){
                            var _before_bs_h = __battle_hp_now(_actor);
                            var _after_bs_h = min(max(1, __battle_hp_max(_actor)), _before_bs_h + _amt_end);
                            if (_after_bs_h > _before_bs_h){
                                __battle_set_hp_now(_actor, _after_bs_h);
                                try { __battle_request_animation_safe(_pid, { type:"heal", actor:_actor, target_index:_ai, amount:(_after_bs_h - _before_bs_h) }); } catch (e_black_sludge_heal_anim) {}
                                try { dialog_queue(__battle_ability_actor_name(_actor, "The Pokemon") + " restored HP using its " + __battle_held_item_label(_actor) + "!"); } catch (e_black_sludge_heal_dialog) {}
                                _did = true;
                            }
                        } else {
                            try { dialog_queue(__battle_ability_actor_name(_actor, "The Pokemon") + " was hurt by its " + __battle_held_item_label(_actor) + "!"); } catch (e_black_sludge_dmg_dialog) {}
                            __battle_apply_damage(_pid, _ai, _amt_end, 1.0);
                            _did = true;
                        }
                    }
                }
            }
            try {
                if (!is_undefined(__battle_try_auto_use_held_berry)){
                    if (__battle_try_auto_use_held_berry(_pid, _ai, _actor, undefined, undefined, undefined, 1.0, "end_turn")) _did = true;
                }
            } catch (e_end_turn_berry_runtime) {}
        } catch (e_end_ability_actor) {}
    }
    return _did;
}

// Attempt to restore any previously saved audio for the battle slot.
// This is defensive: many platforms won't have previous audio captured; the
// function should silently no-op when no previous audio exists.
// Attempt to restore previously saved audio for a battle slot (defensive no-op).
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
function __battle_normalize_trainer_entry(_entry, _opts, _default_level){
    if (is_undefined(_entry)) return undefined;
    var level_hint = (is_real(_default_level) ? max(1, floor(_default_level)) : 5);
    if (is_struct(_opts)){
        if (variable_struct_exists(_opts, "enemy_level") && is_real(variable_struct_get(_opts, "enemy_level"))){
            level_hint = max(1, floor(variable_struct_get(_opts, "enemy_level")));
        } else if (variable_struct_exists(_opts, "level") && is_real(variable_struct_get(_opts, "level"))){
            level_hint = max(1, floor(variable_struct_get(_opts, "level")));
        }
    }
    var spawn_from_species = function(_sid, _lvl){
        var sid = (is_real(_sid) ? max(0, floor(_sid)) : -1);
        var lvl = (is_real(_lvl) ? max(1, floor(_lvl)) : level_hint);
        if (sid < 0) sid = 0;
        if (!is_undefined(pokemon_factory_create)){
            try {
                var mon_seed = pokemon_factory_create(sid, lvl, {});
                if (is_struct(mon_seed)){
                    if (!variable_struct_exists(mon_seed, "mon") || mon_seed.mon != mon_seed) mon_seed.mon = mon_seed;
                    return mon_seed;
                }
            } catch (e_pf) {}
        }
        var actor_seed = __battle_actor_from_species_level(sid, lvl);
        if (is_struct(actor_seed)){
            if (variable_struct_exists(actor_seed, "mon") && is_struct(actor_seed.mon)){
                var actor_mon = actor_seed.mon;
                if (!variable_struct_exists(actor_mon, "mon") || actor_mon.mon != actor_mon) actor_mon.mon = actor_mon;
                return actor_mon;
            }
            if (!variable_struct_exists(actor_seed, "mon") || actor_seed.mon != actor_seed) actor_seed.mon = actor_seed;
            return actor_seed;
        }
    var hp_base = max(1, 20 + lvl * 2);
    var fallback_mon = { species_id:sid, id:sid, species:sid, level:lvl, lvl:lvl, hp:hp_base, hp_max:hp_base, maxhp:hp_base, moves:[-1,-1,-1,-1], pps:[0,0,0,0] };
    fallback_mon.mon = fallback_mon;
    return fallback_mon;
    };
    if (is_real(_entry)){
        return spawn_from_species(_entry, level_hint);
    }
    if (is_array(_entry)){
        var sid_arr = -1;
        var lvl_arr = level_hint;
        if (array_length(_entry) >= 1 && is_real(_entry[0])) sid_arr = _entry[0];
        if (array_length(_entry) >= 2 && is_real(_entry[1])) lvl_arr = _entry[1];
        return spawn_from_species(sid_arr, lvl_arr);
    }
    if (is_struct(_entry)){
        var mon_struct = _entry;
        if (variable_struct_exists(mon_struct, "mon") && is_struct(mon_struct.mon) && mon_struct.mon != mon_struct){
            mon_struct = mon_struct.mon;
        }
        var sid_struct = -1;
        if (variable_struct_exists(mon_struct, "species_id") && is_real(mon_struct.species_id)) sid_struct = mon_struct.species_id;
        else if (variable_struct_exists(mon_struct, "id") && is_real(mon_struct.id)) sid_struct = mon_struct.id;
        else if (variable_struct_exists(mon_struct, "species") && is_real(mon_struct.species)) sid_struct = mon_struct.species;
        else if (variable_struct_exists(mon_struct, "dex_id") && is_real(mon_struct.dex_id)) sid_struct = mon_struct.dex_id;
        if (!is_struct(mon_struct) || sid_struct < 0){
            return spawn_from_species(sid_struct, level_hint);
        }
        if (!variable_struct_exists(mon_struct, "species_id") || !is_real(mon_struct.species_id)) mon_struct.species_id = sid_struct;
        if (!variable_struct_exists(mon_struct, "id") || !is_real(mon_struct.id)) mon_struct.id = sid_struct;
        if (!variable_struct_exists(mon_struct, "species") || !is_real(mon_struct.species)) mon_struct.species = sid_struct;
        var lvl_struct = level_hint;
        if (variable_struct_exists(mon_struct, "level") && is_real(mon_struct.level)) lvl_struct = mon_struct.level;
        else if (variable_struct_exists(mon_struct, "lvl") && is_real(mon_struct.lvl)) lvl_struct = mon_struct.lvl;
        lvl_struct = max(1, floor(lvl_struct));
        mon_struct.level = lvl_struct;
        mon_struct.lvl = lvl_struct;
        if (!variable_struct_exists(mon_struct, "name") || string_length(string(mon_struct.name)) <= 0){
            if (!is_undefined(scr_poke_name_by_id) && sid_struct >= 0){
                try { mon_struct.name = scr_poke_name_by_id(sid_struct); } catch (e_nm) {}
            }
        }
        var hp_now = __battle_hp_now(mon_struct);
        if (!is_real(hp_now) || hp_now <= 0){
            var hp_seed = 0;
            if (variable_struct_exists(mon_struct, "hp_max") && is_real(mon_struct.hp_max)) hp_seed = mon_struct.hp_max;
            else if (variable_struct_exists(mon_struct, "maxhp") && is_real(mon_struct.maxhp)) hp_seed = mon_struct.maxhp;
            else if (variable_struct_exists(mon_struct, "hp") && is_real(mon_struct.hp)) hp_seed = mon_struct.hp;
            else if (!is_undefined(pokemon_factory_create)){
                try {
                    var probe = pokemon_factory_create(sid_struct, lvl_struct, {});
                    hp_seed = __battle_hp_now(probe);
                } catch (e_probe) {}
            }
            if (!is_real(hp_seed) || hp_seed <= 0) hp_seed = max(1, 20 + lvl_struct * 2);
            __battle_set_hp_now(mon_struct, max(1, hp_seed));
        }
        if (!variable_struct_exists(mon_struct, "hp_max") || !is_real(mon_struct.hp_max)) mon_struct.hp_max = __battle_hp_now(mon_struct);
        if (!variable_struct_exists(mon_struct, "maxhp") || !is_real(mon_struct.maxhp)) mon_struct.maxhp = __battle_hp_now(mon_struct);
        if (!variable_struct_exists(mon_struct, "moves") || !is_array(mon_struct.moves)) mon_struct.moves = [-1,-1,-1,-1];
        if (!variable_struct_exists(mon_struct, "pps") || !is_array(mon_struct.pps)) mon_struct.pps = [0,0,0,0];
        if (!variable_struct_exists(mon_struct, "mon") || mon_struct.mon != mon_struct) mon_struct.mon = mon_struct;
        return mon_struct;
    }
    return spawn_from_species(_entry, level_hint);
}

/// @function battle_open(pid_or_level?, wild_level?, area_or_opts?, opts?)
/// @desc Opens a wild or trainer battle for the given player slot. When only one argument is
/// supplied it is treated as a wild level for PID 0. With two arguments the first is the player
/// id and the second the wild level. The optional third and fourth parameters can be an
/// `area_type` string/number and/or an options struct (supports `{ type:"trainer", enemy_party:[...] }`).
/// @remarks Always pair this with `battle_update(pid)` in Step and `battle_draw_gui(pid)` in Draw GUI.
/// Area presets ("grassy", "rocks a", etc.) update the theme colors and platform indices automatically.
/// Overloads:
/// - `battle_open(wild_level)` opens a wild battle for player 0.
/// - `battle_open(pid, wild_level)` opens a wild battle for that player.
/// - `battle_open(pid, wild_level, area_type)` opens with a specific battlefield theme.
/// - `battle_open(pid, wild_level, opts)` opens with options such as battle type or enemy party.
/// - `battle_open(pid, wild_level, area_type, opts)` combines both.
/// @example battle_open(0, 12);               // wild encounter for player 0 at level 12
/// @example battle_open(0, 14, "river");      // wild encounter using the river battlefield theme
/// @example battle_open(0, 18, { type:"trainer", enemy_party: trainerMons });
function battle_open(pid_or_level = undefined, wild_level = undefined, area_or_opts = undefined, opts = undefined){
    var _pid = 0;
    var _wildLevel = 5;
    if (argument_count >= 2){
        _pid = max(0, real(pid_or_level));
        _wildLevel = max(1, real(wild_level));
    } else if (argument_count == 1){
        _pid = 0;
        _wildLevel = max(1, real(pid_or_level));
    }
    var _caller = noone;
    if (!is_undefined(player_by_pid)) {
        _caller = player_by_pid(_pid);
        if (_caller == noone) _caller = noone;
    }

    var _opts = undefined;
    var _area_type = undefined;
    if (argument_count >= 3){
        var _extra_args = [area_or_opts, opts];
        for (var _ai = 0; _ai < array_length(_extra_args); ++_ai){
            var _val = _extra_args[_ai];
        if (is_undefined(_val)) continue;
        if (is_struct(_val)){
            _opts = _val;
            continue;
        }
        if (is_undefined(_area_type)){
            if (is_string(_val) || is_real(_val)) _area_type = _val;
        }
    }
    }

    var _B = __battle_ensure_slot(_pid);
    if (_B.sys_open) return;

    __battle_clear_weather(_pid);

    var _battle_type = "wild";
    if (is_struct(_opts)){
        if (variable_struct_exists(_opts, "battle_type")) _battle_type = string_lower(string(variable_struct_get(_opts, "battle_type")));
        else if (variable_struct_exists(_opts, "type")) _battle_type = string_lower(string(variable_struct_get(_opts, "type")));
    }
    var _battle_format = "single";
    if (is_struct(_opts) && variable_struct_exists(_opts, "battle_format")) _battle_format = string_lower(string(variable_struct_get(_opts, "battle_format")));
    if (_battle_format != "double") _battle_format = "single";
    var _coop_enabled = false;
    if (is_struct(_opts) && variable_struct_exists(_opts, "coop_enabled")) _coop_enabled = (variable_struct_get(_opts, "coop_enabled") == true);
    var _player_pids = [_pid, _pid];
    if (is_struct(_opts) && variable_struct_exists(_opts, "player_pids") && is_array(variable_struct_get(_opts, "player_pids"))){
        var _raw_player_pids = variable_struct_get(_opts, "player_pids");
        if (array_length(_raw_player_pids) > 0 && is_real(_raw_player_pids[0])) _player_pids[0] = max(0, floor(_raw_player_pids[0]));
        if (array_length(_raw_player_pids) > 1 && is_real(_raw_player_pids[1])) _player_pids[1] = max(0, floor(_raw_player_pids[1]));
    } else if (_coop_enabled){
        _player_pids[1] = max(0, _pid + 1);
    }
    if (!_coop_enabled && _battle_format == "single"){
        _player_pids[0] = _pid;
        _player_pids[1] = _pid;
    }
    try { variable_struct_set(_B, "battle_type", _battle_type); } catch (e_btype_store) {}
    try { variable_struct_set(_B, "_battle_mode", _battle_type); } catch (e_bmode) {}
    try { variable_struct_set(_B, "battle_format", _battle_format); } catch (e_bformat_store) {}
    try { variable_struct_set(_B, "active_per_side", (_battle_format == "double") ? 2 : 1); } catch (e_active_store) {}
    try { variable_struct_set(_B, "coop_enabled", _coop_enabled); } catch (e_coop_store) {}
    try { variable_struct_set(_B, "player_pids", _player_pids); } catch (e_ppid_store) {}
    if (is_struct(_opts)){
        try { variable_struct_set(_B, "_battle_opts", _opts); } catch (e_opt) {}
    }
    if (!is_undefined(_area_type)){
        try { variable_struct_set(_B, "_area_type", _area_type); } catch (e_area_store) {}
    } else if (is_struct(_opts)){
        try {
            if (variable_struct_exists(_opts, "area_type")) variable_struct_set(_B, "_area_type", variable_struct_get(_opts, "area_type"));
            else if (variable_struct_exists(_opts, "theme")){
                var _theme_opts = variable_struct_get(_opts, "theme");
                if (is_struct(_theme_opts) && variable_struct_exists(_theme_opts, "area_type")) variable_struct_set(_B, "_area_type", variable_struct_get(_theme_opts, "area_type"));
            }
        } catch (e_area_extract) {}
    }

    _B.sys_open = true;
    _B.phase    = "transition_in";
    var _battle_transition_style = (!is_undefined(transition_battle_style)) ? transition_battle_style() : "emerald_fade_black";
    if (is_struct(_opts) && variable_struct_exists(_opts, "transition_style") && !is_undefined(transition_normalize_style)){
        _battle_transition_style = transition_normalize_style(variable_struct_get(_opts, "transition_style"));
    }
    _B.transition_style = _battle_transition_style;
    _B.turn     = 0;
    _B.result   = "ongoing";
    _B.sys_rng  = random_get_seed();

    _B.sys_ui   = { menu:"root", selX:0, selY:0, msg_list:ds_list_create() };
    _B.sys_anim = { active:[], current: undefined };
    _B._anim_queue = { pending: [], current: undefined, overlays: [], draw_states: [] };
    _B._cam_frame = { offset_x: 0, offset_y: 0, fade_alpha: 0, fade_color: c_black };

// Field helpers now live in battle_field_helpers.gml
    _B.phase_start_ms = current_time;
    var _battle_transition_ms = (variable_global_exists("TRANSITION_BATTLE_DURATION_MS") && is_real(global.TRANSITION_BATTLE_DURATION_MS)) ? max(1, real(global.TRANSITION_BATTLE_DURATION_MS)) : 620;
    _B.phase_durs = { transition: _battle_transition_ms, enemy: 400, call: 700, player: 400, switch_in: 600 };
    _B._intro_completed = false;

    // Optional gated debug dump for battle-open state (useful for hazard/move meta debugging)
    try {
        if (variable_global_exists("BATTLE_META_DEBUG") && global.BATTLE_META_DEBUG){
            try {
                show_debug_message("[battle][open][dbg] pid=" + string(_pid) + " created; initial state dump:");
                show_debug_message("[battle][open][dbg] phase=" + string(_B.phase) + ", phase_durs=" + string(_B.phase_durs));
                var __dbg_h = function(_side, _name){ var hv = __battle_field_get_hazard(_pid, _side, _name); return is_undefined(hv) ? "<unset>" : string(hv); };
                var sflags = "player_side:" + " spikes=" + __dbg_h(0, "spikes") + ", toxic=" + __dbg_h(0, "toxic_spikes") + ", stealth=" + __dbg_h(0, "stealth_rock") + ", sticky=" + __dbg_h(0, "sticky_web")
                    + " | enemy_side:" + " spikes=" + __dbg_h(1, "spikes") + ", toxic=" + __dbg_h(1, "toxic_spikes") + ", stealth=" + __dbg_h(1, "stealth_rock") + ", sticky=" + __dbg_h(1, "sticky_web");
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
    _B._battle_bgm_playing = false;
    _B._defeated_music_playing = false;
    // Preserve any previously playing audio so we can restore it after the battle
    // NOTE: calling `audio_get_playing()` at early runtime (for example during
    // oPlayer Step) can trigger errors on some targets. Capture would be nice
    // but is non-critical; avoid calling it to prevent crashes and leave
    // previous-audio unset.
    _B._prev_audio = undefined;

    // Stop the configured region music before battle music starts, but avoid a
    // global audio stop so one-shot SFX and unrelated channels are left alone.
    try {
        if (!is_undefined(world_stop_room_music)) {
            world_stop_room_music();
        } else if (variable_global_exists("_REGIONMUSIC") && !is_undefined(global._REGIONMUSIC) && !is_undefined(audio_stop_sound)) {
            audio_stop_sound(global._REGIONMUSIC);
            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][audio] stopped region music before battle start");
        }
    } catch (e_stop_region) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][audio] region music stop failed: " + string(e_stop_region)); }

    // Start background battle music (looped) if available
    if (!is_undefined(_B._battle_music)){
        try {
            var _bh = __battle_start_bgm_once(_B);
            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][audio] played bgm="+string(_B._battle_music)+" handle="+string(_bh));
        } catch (e) { variable_struct_set(_B, "_bgm_handle", undefined); if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][audio] failed to play bgm="+string(_B._battle_music)); }
    }

    // Clear any leftover catch animation state from previous battles
    if (variable_struct_exists(_B, "_catch_anim")) _B._catch_anim = undefined;
    if (variable_struct_exists(_B, "_queued_catch")) _B._queued_catch = undefined;

    // Cry/switch state & turn queue
    _B._cry_played_enemy = false;
    _B._cry_played_enemy2 = false;
    _B._cry_played_player = false;
    _B._cry_played_player2 = false;
    _B._cry_play_start_ms_enemy = undefined;
    _B._cry_play_start_ms_player = undefined;
    _B._switch_target_idx = undefined;
    _B._switch_opts = undefined;
    _B._switch_applied = false;
    _B.phase_holds = { call: 3000 };
    _B._pending_close = false;

    if (_battle_type == "trainer"){
        var _trainer_reward = 0;
        if (is_struct(_opts)){
            if (variable_struct_exists(_opts, "trainer_reward") && is_real(variable_struct_get(_opts, "trainer_reward"))){
                _trainer_reward = max(0, floor(variable_struct_get(_opts, "trainer_reward")));
            } else if (variable_struct_exists(_opts, "reward") && is_real(variable_struct_get(_opts, "reward"))){
                _trainer_reward = max(0, floor(variable_struct_get(_opts, "reward")));
            } else if (variable_struct_exists(_opts, "payout") && is_real(variable_struct_get(_opts, "payout"))){
                _trainer_reward = max(0, floor(variable_struct_get(_opts, "payout")));
            }
        }
        try { variable_struct_set(_B, "_trainer_reward", _trainer_reward); } catch (e_tr) {}
        try { variable_struct_set(_B, "_trainer_reward_paid", false); } catch (e_trp) {}
    } else {
        try { variable_struct_set(_B, "_trainer_reward", 0); } catch (e_trclr) {}
        try { variable_struct_set(_B, "_trainer_reward_paid", false); } catch (e_trpclr) {}
    }
    try {
        if (variable_struct_exists(_B, "_trainer_pending_send")) variable_struct_remove(_B, "_trainer_pending_send");
    } catch (e_trpend) {}
    try { variable_struct_set(_B, "_trainer_switch_prompt", undefined); } catch (e_trprompt_clear) {}

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
        col_text:     c_white,
        col_dialog_text: make_color_rgb(36, 52, 40),
        col_ui_text: make_color_rgb(36, 52, 40),
        col_ui_highlight: make_color_rgb(72, 88, 80),
        platform_enemy_sprite: spr_opponentplatform,
        platform_enemy_index: 3,
        platform_enemy_scale: 1,
        platform_enemy_offset: { x: 0, y: 0 },
        platform_player_sprite: spr_playerplatform,
        platform_player_index: 3,
        platform_player_scale: 1,
        platform_player_offset: { x: 0, y: -28 }
    };

    __battle_theme_apply_area_type(_B, _area_type, _opts);
    __battle_theme_apply_platform_opts(_B, _opts);

    // Player actor from party
    var _P = party_ensure(_player_pids[0]);
    // Clear residual Jaw Lock flags on the player's party so traps do not persist across battles
    __battle_clear_jaw_lock_party_flags(_player_pids[0]);
    if (_coop_enabled && _player_pids[1] != _player_pids[0]) __battle_clear_jaw_lock_party_flags(_player_pids[1]);

    var _player0_candidates = __battle_collect_opening_party_indexes(_player_pids[0], 2, false);
    var _player1_candidates = __battle_collect_opening_party_indexes(_player_pids[1], 1, false);
    var _player_party_limit = 6;
    if (is_struct(_opts) && variable_struct_exists(_opts, "player_party_limit") && is_real(variable_struct_get(_opts, "player_party_limit"))) _player_party_limit = max(1, floor(variable_struct_get(_opts, "player_party_limit")));
    var _allowed_party_indexes = [undefined, undefined];
    if (is_struct(_opts) && variable_struct_exists(_opts, "player_party_indexes") && is_array(variable_struct_get(_opts, "player_party_indexes"))){
        var _ppi = variable_struct_get(_opts, "player_party_indexes");
        if (array_length(_ppi) > 0 && is_array(_ppi[0])){
            _player0_candidates = [];
            for (var _p0i = 0; _p0i < array_length(_ppi[0]) && array_length(_player0_candidates) < _player_party_limit; ++_p0i){
                var _idx0 = _ppi[0][_p0i];
                if (is_real(_idx0) && __battle_party_index_is_usable(_player_pids[0], floor(_idx0))) array_push(_player0_candidates, floor(_idx0));
            }
            _allowed_party_indexes[0] = _player0_candidates;
        }
        if (array_length(_ppi) > 1 && is_array(_ppi[1])){
            _player1_candidates = [];
            for (var _p1i = 0; _p1i < array_length(_ppi[1]) && array_length(_player1_candidates) < _player_party_limit; ++_p1i){
                var _idx1 = _ppi[1][_p1i];
                if (is_real(_idx1) && __battle_party_index_is_usable(_player_pids[1], floor(_idx1))) array_push(_player1_candidates, floor(_idx1));
            }
            _allowed_party_indexes[1] = _player1_candidates;
        }
    }
    if (array_length(_player0_candidates) <= 0) array_push(_player0_candidates, 0);

    var _requested_double = (_battle_format == "double");
    var _use_double = _requested_double;
    var _use_coop = (_requested_double && _coop_enabled);
    if (_requested_double){
        if (_use_coop){
            if (array_length(_player1_candidates) <= 0){
                _use_coop = false;
            }
        }
    }
    if (!_use_double){
        _battle_format = "single";
        _coop_enabled = false;
        _player_pids[1] = _player_pids[0];
        _B.battle_format = "single";
        _B.active_per_side = 1;
        _B.coop_enabled = false;
    } else {
        _B.battle_format = "double";
        _B.active_per_side = 2;
        _B.coop_enabled = _use_coop;
    }
    _B.player_pids = _player_pids;
    _B.player_party_limit = _player_party_limit;
    _B.player_party_indexes = _allowed_party_indexes;

    if (_B.active_per_side > 1){
        _B.phase_durs.call = max(_B.phase_durs.call, 700 * _B.active_per_side);
        _B.phase_durs.player = max(_B.phase_durs.player, 400 * _B.active_per_side);
    }

    var _owners = [_player_pids[0], _player_pids[0], -1, -1];
    var _lead_party_idx = _player0_candidates[0];
    var _pm = party_model_get_mon(_player_pids[0], _lead_party_idx);
    if (!is_struct(_pm) && is_struct(_P) && is_array(_P.mons) && _lead_party_idx >= 0 && _lead_party_idx < array_length(_P.mons)) _pm = _P.mons[_lead_party_idx];

    _B.actor = [];
    _B.actor[0] = __battle_opening_actor_from_party(_player_pids[0], _lead_party_idx, 0, _player_pids[0]);
    try { __battle_mark_exp_participant(_B, _B.actor[0]); } catch (e_exp_open_0) {}
    if (_use_double){
        if (_use_coop){
            _owners[1] = _player_pids[1];
            _B.actor[1] = __battle_opening_actor_from_party(_player_pids[1], _player1_candidates[0], 1, _player_pids[1]);
            try { __battle_mark_exp_participant(_B, _B.actor[1]); } catch (e_exp_open_1) {}
        } else {
            if (array_length(_player0_candidates) > 1){
                _owners[1] = _player_pids[0];
                _B.actor[1] = __battle_opening_actor_from_party(_player_pids[0], _player0_candidates[1], 1, _player_pids[0]);
                try { __battle_mark_exp_participant(_B, _B.actor[1]); } catch (e_exp_open_2) {}
            } else {
                _owners[1] = -1;
                _B.actor[1] = undefined;
            }
        }
    }
    if (!_use_double) _owners[1] = -1;
    _B.actor_owner_pid = _owners;

    // Debug: print grounded snapshot for actors at open
    try {
        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){
            var g0 = (is_struct(_B.actor[0]) && variable_struct_exists(_B.actor[0], "grounded")) ? string(variable_struct_get(_B.actor[0], "grounded")) : "<unset>";
            var a0 = (is_struct(_B.actor[0]) && variable_struct_exists(_B.actor[0], "ability")) ? string(variable_struct_get(_B.actor[0], "ability")) : "<none>";
            var p0_dbg_name = (is_struct(_B.actor[0]) && variable_struct_exists(_B.actor[0], "name")) ? string(variable_struct_get(_B.actor[0], "name")) : "Pokemon";
            show_debug_message("[battle_open][grounded] player=" + p0_dbg_name + ", grounded=" + g0 + ", ability=" + a0);
        }
    } catch (e_dbg0) {}
    // Debug: log moves on open to diagnose stale copies
    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){
        try {
            var dbg_pm = party_model_get_mon(_player_pids[0], _lead_party_idx);
            var dbg_pm_moves = (is_struct(dbg_pm) && variable_struct_exists(dbg_pm, "moves")) ? string(variable_struct_get(dbg_pm, "moves")) : "<no-moves>";
            var dbg_local_moves = (is_struct(_pm) && variable_struct_exists(_pm, "moves")) ? string(variable_struct_get(_pm, "moves")) : "<no-moves>";
            var dbg_actor_moves = (is_struct(_B.actor[0]) && variable_struct_exists(_B.actor[0], "moves")) ? string(variable_struct_get(_B.actor[0], "moves")) : "<no-moves>";
            show_debug_message("[battle_open][dbg_moves] pid=" + string(_player_pids[0]) + ", slot=" + string(_lead_party_idx) + ", party_model_get_mon.moves=" + dbg_pm_moves + ", _pm.moves=" + dbg_local_moves + ", actor.moves=" + dbg_actor_moves);
        } catch (e_dbgm) { /* ignore */ }
    }

    // Enemy actor (wild default or trainer-provided)
    var _trainer_party = [];
    var _trainer_active_idx = -1;
    var _enemy_actor = undefined;
    if (_battle_type == "trainer" && is_struct(_opts)){
        if (variable_struct_exists(_opts, "enemy_party")){
            var __party_src = variable_struct_get(_opts, "enemy_party");
            if (is_array(__party_src)){
                for (var __pi = 0; __pi < array_length(__party_src); ++__pi){
                    var __raw_entry = __party_src[__pi];
                    _trainer_party[__pi] = __battle_normalize_trainer_entry(__raw_entry, _opts, _wildLevel);
                }
                if (variable_global_exists("__battle_jaw_lock_release")){
                    var __fn_jaw_release_trainer = variable_global_get("__battle_jaw_lock_release");
                    try {
                        for (var __jl_en = 0; __jl_en < array_length(_trainer_party); ++__jl_en){
                            var __tp_mon = _trainer_party[__jl_en];
                            if (is_struct(__tp_mon)) __fn_jaw_release_trainer(__tp_mon);
                        }
                    } catch (e_jaw_trainer) {
                        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][jaw_lock] failed clearing trainer flags: " + string(e_jaw_trainer));
                    }
                }
                for (var __pj = 0; __pj < array_length(_trainer_party); ++__pj){
                    var __cand = _trainer_party[__pj];
                    if (is_struct(__cand)){
                        var __hp = __battle_hp_now(__cand);
                        if (!is_real(__hp)) __hp = 0;
                        if (__hp > 0){
                            _trainer_active_idx = __pj;
                            break;
                        }
                    }
                }
            }
        }
        if (_use_double){
            var _trainer_active_indices = [];
            for (var __td = 0; __td < array_length(_trainer_party) && array_length(_trainer_active_indices) < 2; ++__td){
                var __td_mon = _trainer_party[__td];
                if (is_struct(__td_mon) && __battle_hp_now(__td_mon) > 0) array_push(_trainer_active_indices, __td);
            }
            if (array_length(_trainer_active_indices) >= 2){
                _B.actor[2] = __battle_actor_from_party_mon(_trainer_party[_trainer_active_indices[0]]);
                _B.actor[3] = __battle_actor_from_party_mon(_trainer_party[_trainer_active_indices[1]]);
                __battle_set_actor_runtime_fields(_B.actor[2], 2, -1, -1, _trainer_active_indices[0]);
                __battle_set_actor_runtime_fields(_B.actor[3], 3, -1, -1, _trainer_active_indices[1]);
                _enemy_actor = _B.actor[2];
                _trainer_active_idx = _trainer_active_indices[0];
                try { variable_struct_set(_B, "_trainer_party_active_indices", _trainer_active_indices); } catch (e_taidxs) {}
            } else {
                _use_double = false;
                _battle_format = "single";
                _B.battle_format = "single";
                _B.active_per_side = 1;
                _B.coop_enabled = false;
            }
        }
        if (is_undefined(_enemy_actor) && variable_struct_exists(_opts, "enemy_mon")){
            var __cand2 = variable_struct_get(_opts, "enemy_mon");
            if (is_struct(__cand2)) _enemy_actor = __battle_actor_from_party_mon(__cand2);
        }
        if (is_undefined(_enemy_actor) && variable_struct_exists(_opts, "enemy_species")){
            var __esp = variable_struct_get(_opts, "enemy_species");
            if (is_array(__esp) && array_length(__esp) > 0 && is_real(__esp[0])) __esp = __esp[0];
            if (is_real(__esp)){
                var __lvl = _wildLevel;
                if (variable_struct_exists(_opts, "enemy_levels") && is_array(variable_struct_get(_opts, "enemy_levels")) && array_length(variable_struct_get(_opts, "enemy_levels")) > 0 && is_real(variable_struct_get(_opts, "enemy_levels")[0])){
                    __lvl = max(1, real(variable_struct_get(_opts, "enemy_levels")[0]));
                } else if (variable_struct_exists(_opts, "enemy_level") && is_real(variable_struct_get(_opts, "enemy_level"))){
                    __lvl = max(1, real(variable_struct_get(_opts, "enemy_level")));
                }
                _enemy_actor = __battle_actor_from_species_level(real(__esp), __lvl);
            }
        }
    }
    if (_battle_type == "wild" && _use_double){
        var _wild_species_pair = (is_struct(_opts) && variable_struct_exists(_opts, "enemy_species")) ? variable_struct_get(_opts, "enemy_species") : undefined;
        var _wild_level_pair = (is_struct(_opts) && variable_struct_exists(_opts, "enemy_levels")) ? variable_struct_get(_opts, "enemy_levels") : undefined;
        var _wild_shiny_pair = (is_struct(_opts) && variable_struct_exists(_opts, "enemy_shiny")) ? variable_struct_get(_opts, "enemy_shiny") : undefined;
        var _wild_species_a = undefined;
        var _wild_species_b = undefined;
        var _wild_level_a = _wildLevel;
        var _wild_level_b = _wildLevel;
        var _wild_shiny_a = false;
        var _wild_shiny_b = false;
        if (is_array(_wild_species_pair)){
            if (array_length(_wild_species_pair) > 0 && is_real(_wild_species_pair[0])) _wild_species_a = _wild_species_pair[0];
            if (array_length(_wild_species_pair) > 1 && is_real(_wild_species_pair[1])) _wild_species_b = _wild_species_pair[1];
        }
        if (is_array(_wild_level_pair)){
            if (array_length(_wild_level_pair) > 0 && is_real(_wild_level_pair[0])) _wild_level_a = max(1, floor(_wild_level_pair[0]));
            if (array_length(_wild_level_pair) > 1 && is_real(_wild_level_pair[1])) _wild_level_b = max(1, floor(_wild_level_pair[1]));
        }
        if (is_array(_wild_shiny_pair)){
            if (array_length(_wild_shiny_pair) > 0) _wild_shiny_a = (_wild_shiny_pair[0] == true);
            if (array_length(_wild_shiny_pair) > 1) _wild_shiny_b = (_wild_shiny_pair[1] == true);
        } else if (_wild_shiny_pair == true){
            _wild_shiny_a = true;
        }
        _B.actor[2] = __battle_opening_actor_from_wild(2, _wild_level_a, _wild_species_a);
        _B.actor[3] = __battle_opening_actor_from_wild(3, _wild_level_b, _wild_species_b);
        __battle_set_wild_actor_shiny(_B.actor[2], _wild_shiny_a);
        __battle_set_wild_actor_shiny(_B.actor[3], _wild_shiny_b);
        _enemy_actor = _B.actor[2];
    }
    if (is_undefined(_enemy_actor)){
        if (_battle_type == "wild"){
            var _wild_single_species = undefined;
            var _wild_single_level = _wildLevel;
            if (is_struct(_opts) && variable_struct_exists(_opts, "enemy_species")){
                var _wild_enemy_species = variable_struct_get(_opts, "enemy_species");
                if (is_array(_wild_enemy_species) && array_length(_wild_enemy_species) > 0 && is_real(_wild_enemy_species[0])) _wild_single_species = _wild_enemy_species[0];
                else if (is_real(_wild_enemy_species)) _wild_single_species = _wild_enemy_species;
            }
            if (is_struct(_opts) && variable_struct_exists(_opts, "enemy_levels")){
                var _wild_enemy_levels = variable_struct_get(_opts, "enemy_levels");
                if (is_array(_wild_enemy_levels) && array_length(_wild_enemy_levels) > 0 && is_real(_wild_enemy_levels[0])) _wild_single_level = max(1, floor(_wild_enemy_levels[0]));
                else if (is_real(_wild_enemy_levels)) _wild_single_level = max(1, floor(_wild_enemy_levels));
            }
            var _wild_single_shiny = false;
            if (is_struct(_opts) && variable_struct_exists(_opts, "enemy_shiny")){
                var _wild_enemy_shiny = variable_struct_get(_opts, "enemy_shiny");
                if (is_array(_wild_enemy_shiny) && array_length(_wild_enemy_shiny) > 0) _wild_single_shiny = (_wild_enemy_shiny[0] == true);
                else _wild_single_shiny = (_wild_enemy_shiny == true);
            }
            _enemy_actor = __battle_opening_actor_from_wild(1, _wild_single_level, _wild_single_species);
            __battle_set_wild_actor_shiny(_enemy_actor, _wild_single_shiny);
        }
        else if (array_length(_trainer_party) > 0){
            var __cand_default = _trainer_party[0];
            if (is_struct(__cand_default)) _enemy_actor = __battle_actor_from_party_mon(__cand_default);
        }
    }
    if (!_use_double){
        _B.actor[1] = _enemy_actor;
        __battle_set_actor_runtime_fields(_B.actor[1], 1, -1, -1, _trainer_active_idx);
        _B.actor_owner_pid = [_player_pids[0], -1, -1, -1];
    }
    if (_battle_type == "trainer" && array_length(_trainer_party) > 0){
        try { variable_struct_set(_B, "_trainer_party", _trainer_party); } catch (e_tp) {}
        if (_trainer_active_idx < 0 && is_struct(_enemy_actor)){
            for (var __seek = 0; __seek < array_length(_trainer_party); ++__seek){
                if (_trainer_party[__seek] == _enemy_actor){
                    _trainer_active_idx = __seek;
                    break;
                }
            }
        }
        if (_trainer_active_idx < 0) _trainer_active_idx = 0;
        try { variable_struct_set(_B, "_trainer_party_active_idx", _trainer_active_idx); } catch (e_taidx) {}
    }
    try {
        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){
            var _enemy_lead = __battle_get_side_actor(_pid, 1, 0);
            var g1 = (is_struct(_enemy_lead) && variable_struct_exists(_enemy_lead, "grounded")) ? string(variable_struct_get(_enemy_lead, "grounded")) : "<unset>";
            var a1 = (is_struct(_enemy_lead) && variable_struct_exists(_enemy_lead, "ability")) ? string(variable_struct_get(_enemy_lead, "ability")) : "<none>";
            var _enemy_dbg_name = (is_struct(_enemy_lead) && variable_struct_exists(_enemy_lead, "name")) ? string(variable_struct_get(_enemy_lead, "name")) : "Enemy";
            show_debug_message("[battle_open][grounded] enemy=" + _enemy_dbg_name + ", grounded=" + g1 + ", ability=" + a1);
        }
    } catch (e_dbg1) {}
    try {
        if (!is_undefined(poke_index_mark_mon_seen)){
            var _seen_indices = (_battle_format == "double") ? [2, 3] : [1];
            for (var _seen_i = 0; _seen_i < array_length(_seen_indices); ++_seen_i){
                var _seen_idx = _seen_indices[_seen_i];
                if (is_array(_B.actor) && _seen_idx < array_length(_B.actor) && is_struct(_B.actor[_seen_idx])){
                    poke_index_mark_mon_seen(_player_pids[0], _B.actor[_seen_idx]);
                    if (_coop_enabled && _player_pids[1] != _player_pids[0]) poke_index_mark_mon_seen(_player_pids[1], _B.actor[_seen_idx]);
                }
            }
        }
    } catch (e_poke_index_seen) {}

    try {
        if (!is_undefined(__battle_apply_entry_abilities)){
            for (var _entry_ai = 0; _entry_ai < array_length(_B.actor); ++_entry_ai){
                if (is_struct(_B.actor[_entry_ai])) __battle_apply_entry_abilities(_pid, _entry_ai);
            }
        }
    } catch (e_entry_abilities_open) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][ability] open entry ability failed: " + string(e_entry_abilities_open)); }

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

    if (_battle_type != "trainer"){
        // Use CutsceneSystem for the wild-intro when available so intro flow can be
        // composed/reused as a cutscene. Fall back to the legacy immediate dialog
        // show/enqueue when the cutscene system isn't present.
        if (!is_undefined(cutscene_play_now) && !is_undefined(dialog2p_enqueue)){
            var _enemy_lead_name = __battle_get_side_actor(_pid, 1, 0);
            var _mon_name = is_struct(_enemy_lead_name) && variable_struct_exists(_enemy_lead_name, "name") ? string(variable_struct_get(_enemy_lead_name, "name")) : "Pokemon";
            var _key = "wild_intro:" + string(_mon_name) + ":" + string(current_time);
            var _payload = {
                key: _key,
                gate: "any",
                // allow the battle's intro phase timing to continue while this cutscene
                // is active so the fade-in and sprite intros can progress.
                allow_battle_progress: true,
                // on_start: enqueue the dialog item so the dialog system can open it
                on_start: function(_p, _it){
                    try {
                        // mark bookkeeping on the cutscene item so on_update can detect open/close
                        try { variable_struct_set(_it, "_seen_dialog", false); } catch (e_set) {}
                        // Resolve actor names at runtime from the battle slot to avoid closure capture issues
                        try {
                            var _txt_mon = "";
                            var _txt_player = "";
                            var _txt_mon2 = "";
                            var _txt_player2 = "";
                            var _fmt = "single";
                            if (variable_global_exists("sys_battles") && is_array(global.sys_battles) && array_length(global.sys_battles) > _p){
                                var _Bb = global.sys_battles[_p];
                                if (is_struct(_Bb) && variable_struct_exists(_Bb, "actor")){
                                    if (variable_struct_exists(_Bb, "battle_format")) _fmt = string(variable_struct_get(_Bb, "battle_format"));
                                    var _enemy_open_idx = (_fmt == "double") ? 2 : 1;
                                    try { if (is_struct(variable_struct_get(_Bb, "actor")[_enemy_open_idx]) && variable_struct_exists(variable_struct_get(_Bb, "actor")[_enemy_open_idx], "name")) _txt_mon = string(variable_struct_get(variable_struct_get(_Bb, "actor")[_enemy_open_idx], "name")); } catch(e1){}
                                    try { if (is_struct(variable_struct_get(_Bb, "actor")[0]) && variable_struct_exists(variable_struct_get(_Bb, "actor")[0], "name")) _txt_player = string(variable_struct_get(variable_struct_get(_Bb, "actor")[0], "name")); } catch(e2){}
                                    if (_fmt == "double"){
                                        try { if (is_struct(variable_struct_get(_Bb, "actor")[3]) && variable_struct_exists(variable_struct_get(_Bb, "actor")[3], "name")) _txt_mon2 = string(variable_struct_get(variable_struct_get(_Bb, "actor")[3], "name")); } catch(e3){}
                                        try { if (is_struct(variable_struct_get(_Bb, "actor")[1]) && variable_struct_exists(variable_struct_get(_Bb, "actor")[1], "name")) _txt_player2 = string(variable_struct_get(variable_struct_get(_Bb, "actor")[1], "name")); } catch(e4){}
                                    }
                                }
                            }
                            var _dlg_text = "A wild " + _txt_mon + " has appeared!\n\nGo. " + _txt_player + "!";
                            if (_fmt == "double" && string_length(_txt_mon2) > 0 && string_length(_txt_player2) > 0) _dlg_text = "Wild " + _txt_mon + " and " + _txt_mon2 + " appeared!\n\nGo. " + _txt_player + " and " + _txt_player2 + "!";
                            var _dlg = { text: _dlg_text, key: _it.key + ":dlg", gate: "any" };
                            try { if (!is_undefined(dialog2p_show_now)) dialog2p_show_now(_p, _dlg); else dialog2p_enqueue(_p, _dlg); } catch (e_sh) { try { dialog2p_enqueue(_p, _dlg); } catch (e2){} }
                        } catch (e_r) { /* ignore name-resolve failures */ }
                    } catch (e_on) { /* ignore dialog enqueue failures */ }
                },
                // on_update: wait until the dialog is opened then closed, then finish
                on_update: function(_p, _it, _elapsed){
                    try {
                        // If dialog is currently open, mark that we've seen it
                        if (!is_undefined(dialog2p_is_open) && dialog2p_is_open(_p)){
                            try { variable_struct_set(_it, "_seen_dialog", true); } catch (e_s) {}
                            return false;
                        }
                        // If we have seen it open at least once and it's now closed, we're done
                        try { if (variable_struct_exists(_it, "_seen_dialog") && variable_struct_get(_it, "_seen_dialog")) return true; } catch (e_g) {}
                        // Otherwise keep waiting (dialog may still be queued)
                        return false;
                    } catch (e_u){ return true; }
                }
            };
            try { cutscene_play_now(_pid, _payload); } catch (e_cpn) { /* fallback below */ }
            _B._dlg_active = true;
            _B._dlg_page_last = -1;
        } else if (!is_undefined(dialog2p_show_now)){
            var _enemy_lead_open = __battle_get_side_actor(_pid, 1, 0);
            var _enemy_tail_open = __battle_get_side_actor(_pid, 1, 1);
            var _player_tail_open = __battle_get_side_actor(_pid, 0, 1);
            var _enemy_lead_open_name = (is_struct(_enemy_lead_open) && variable_struct_exists(_enemy_lead_open, "name")) ? string(variable_struct_get(_enemy_lead_open, "name")) : "Pokemon";
            var _enemy_tail_open_name = (is_struct(_enemy_tail_open) && variable_struct_exists(_enemy_tail_open, "name")) ? string(variable_struct_get(_enemy_tail_open, "name")) : "Pokemon";
            var _player_tail_open_name = (is_struct(_player_tail_open) && variable_struct_exists(_player_tail_open, "name")) ? string(variable_struct_get(_player_tail_open, "name")) : "Pokemon";
            var _player_lead_open_name = (is_struct(_B.actor[0]) && variable_struct_exists(_B.actor[0], "name")) ? string(variable_struct_get(_B.actor[0], "name")) : "Pokemon";
            var dlg_txt = "A wild " + _enemy_lead_open_name + " has appeared!\n\nGo. " + _player_lead_open_name + "!";
            if (_battle_format == "double" && is_struct(_enemy_tail_open) && is_struct(_player_tail_open)) dlg_txt = "Wild " + _enemy_lead_open_name + " and " + _enemy_tail_open_name + " appeared!\n\nGo. " + _player_lead_open_name + " and " + _player_tail_open_name + "!";
            try { dialog2p_show_now(_pid, dlg_txt); } catch (e_dlgopen) { try { dialog2p_enqueue(_pid, dlg_txt); } catch(e_){} }
            _B._dlg_active = true;
            _B._dlg_page_last = -1;
        } else {
            _B._dlg_active = false;
            _B._dlg_page_last = -1;
        }
    } else {
        _B._dlg_active = false;
        _B._dlg_page_last = -1;
    }

    if (is_struct(_B.actor[0])) __battle_apply_party_moves(_B.actor[0]);
    if (_battle_format == "double" && is_struct(_B.actor[1])) __battle_apply_party_moves(_B.actor[1]);
    if (_battle_type == "trainer"){
        var _enemy_apply_indices = (_battle_format == "double") ? [2, 3] : [1];
        for (var _ea = 0; _ea < array_length(_enemy_apply_indices); ++_ea){
            var _enemy_idx_apply = _enemy_apply_indices[_ea];
            if (is_array(_B.actor) && _enemy_idx_apply < array_length(_B.actor) && is_struct(_B.actor[_enemy_idx_apply])) __battle_apply_party_moves(_B.actor[_enemy_idx_apply]);
        }
    } else {
        var _wild_apply_indices = (_battle_format == "double") ? [2, 3] : [1];
        for (var _wa = 0; _wa < array_length(_wild_apply_indices); ++_wa){
            var _wild_idx_apply = _wild_apply_indices[_wa];
            if (is_array(_B.actor) && _wild_idx_apply < array_length(_B.actor) && is_struct(_B.actor[_wild_idx_apply])) __battle_ensure_moves_from_levelup(_B.actor[_wild_idx_apply]);
        }
    }

    global.sys_battles[_pid] = _B;
}

// Theme and platform helpers live in battle_theme_helpers.gml.

/// Close the current battle for a player.
/// Params: _pid (int)
/// Behavior: Cleans UI lists, stops/restore audio, heals on loss, and clears sys_open flag.
function battle_close(_pid){
    var _B = __battle_ensure_slot(_pid);
    try { if (!is_undefined(pc_breeding_on_battle_complete)) pc_breeding_on_battle_complete(_pid); } catch (e_breed_battle_tick) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[breeding] battle tick failed: " + string(e_breed_battle_tick)); }
    try {
        if (is_struct(_B) && variable_struct_exists(_B, "actor") && is_array(variable_struct_get(_B, "actor"))){
            var _close_actors = variable_struct_get(_B, "actor");
            for (var _cta = 0; _cta < array_length(_close_actors); ++_cta){
                var _ct_actor = _close_actors[_cta];
                if (is_struct(_ct_actor) && variable_struct_exists(_ct_actor, "_battle_transform_original") && is_struct(variable_struct_get(_ct_actor, "_battle_transform_original"))){
                    __battle_transform_restore_actor(_ct_actor, variable_struct_get(_ct_actor, "_battle_transform_original"));
                    variable_struct_set(_ct_actor, "_battle_mega", false);
                    variable_struct_set(_ct_actor, "_battle_dynamax", false);
                    variable_struct_set(_ct_actor, "_battle_transform_original", undefined);
                }
            }
        }
    } catch (e_transform_close_restore) {}
    if (is_struct(_B.sys_ui) && variable_struct_exists(_B.sys_ui, "msg_list")){
        if (ds_exists(_B.sys_ui.msg_list, ds_type_list)){
            ds_list_destroy(_B.sys_ui.msg_list);
        }
    }
    // Reset dialog/cutscene state so fresh battles don't replay intro messaging.
    try {
        if (variable_global_exists("DIALOG2P") && is_array(global.DIALOG2P) && array_length(global.DIALOG2P) > _pid){
            if (!is_undefined(__dlg_make_session)) global.DIALOG2P[_pid] = __dlg_make_session();
            else if (!is_undefined(dialog2p_init)) { dialog2p_init(); }
        }
        if (variable_global_exists("DIALOG2P_Q") && is_array(global.DIALOG2P_Q) && array_length(global.DIALOG2P_Q) > _pid){
            global.DIALOG2P_Q[_pid] = [];
        }
        if (!is_undefined(cutscene_interrupt)) cutscene_interrupt(_pid);
        if (variable_global_exists("CUTSCENE") && is_array(global.CUTSCENE) && array_length(global.CUTSCENE) > _pid){
            var _sess = global.CUTSCENE[_pid];
            if (is_struct(_sess)){
                _sess.open = false;
                try { variable_struct_set(_sess, "_current_item", noone); } catch (e_cs1) {}
                try { variable_struct_set(_sess, "_on_complete_callbacks", []); } catch (e_cs2) {}
                try { variable_struct_set(_sess, "_start_time", 0); } catch (e_cs3) {}
                try { variable_struct_set(_sess, "_elapsed_ms", 0); } catch (e_cs4) {}
            } else {
                global.CUTSCENE[_pid] = { open:false, _current_item:noone, _on_complete_callbacks:[] };
            }
        }
        if (variable_global_exists("CUTSCENE_Q") && is_array(global.CUTSCENE_Q) && array_length(global.CUTSCENE_Q) > _pid){
            global.CUTSCENE_Q[_pid] = [];
        }
        try { variable_struct_set(_B, "_dlg_active", false); } catch (e_da) {}
        try { variable_struct_set(_B, "_dlg_page_last", -1); } catch (e_dp) {}
    } catch (e_reset) {}
    // Clear transient animation state to avoid bleed into subsequent battles
    if (variable_struct_exists(_B, "_catch_anim")) _B._catch_anim = undefined;
    if (variable_struct_exists(_B, "_queued_catch")) _B._queued_catch = undefined;
    try { variable_struct_set(_B, "_trainer_victory_slide", undefined); } catch (e_tv_clear) {}
    try { variable_struct_set(_B, "_faint_dialog_active", false); variable_struct_set(_B, "_faint_dialog_key", undefined); } catch (e_fdclear) {}
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
        variable_struct_set(_B, "_bgm_handle", undefined);
        variable_struct_set(_B, "_defeated_handle", undefined);
        variable_struct_set(_B, "_battle_bgm_playing", false);
        variable_struct_set(_B, "_defeated_music_playing", false);
    } catch (e_audio_flags_clear) {}
    try {
        var _bm_res = (variable_struct_exists(_B, "_battle_music") ? variable_struct_get(_B, "_battle_music") : undefined);
        if (!is_undefined(_bm_res) && variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][audio] battle_music resource configured: " + string(_bm_res));
        var _bdm = (variable_struct_exists(_B, "_battle_defeated_music") ? variable_struct_get(_B, "_battle_defeated_music") : undefined);
        if (!is_undefined(_bdm) && variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][audio] defeated_music resource configured: " + string(_bdm));
    } catch (e3) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][audio] failed to call sound_stop: " + string(e3)); }
    _B.sys_open = false;
    try {
        variable_struct_set(_B, "sys_anim", { active:[], current: undefined });
        variable_struct_set(_B, "_anim_queue", { pending: [], current: undefined, overlays: [], draw_states: [] });
    } catch (e_battle_anim_clear_close) {}
    if (variable_global_exists("sys_battles") && is_array(global.sys_battles)){
        for (var _alias_pid = 0; _alias_pid < array_length(global.sys_battles); ++_alias_pid){
            if (_alias_pid == _pid) continue;
            if (global.sys_battles[_alias_pid] == _B) global.sys_battles[_alias_pid] = undefined;
        }
    }
    try {
        if (!battle_any_open() && variable_global_exists("OVERWORLD_ENCOUNTERS") && is_struct(global.OVERWORLD_ENCOUNTERS)) {
            variable_struct_set(global.OVERWORLD_ENCOUNTERS, "pending", false);
        }
        if (!variable_global_exists("OVERWORLD_ENCOUNTER_GRACE_MS")) global.OVERWORLD_ENCOUNTER_GRACE_MS = 1500;
        if (!variable_global_exists("OVERWORLD_ENCOUNTER_BLOCK_UNTIL_MS")) global.OVERWORLD_ENCOUNTER_BLOCK_UNTIL_MS = 0;
        global.OVERWORLD_ENCOUNTER_BLOCK_UNTIL_MS = max(global.OVERWORLD_ENCOUNTER_BLOCK_UNTIL_MS, current_time + max(0, floor(global.OVERWORLD_ENCOUNTER_GRACE_MS)));
    } catch (e_overworld_pending_clear) {}
    try { variable_struct_set(_B, "_area_type", undefined); } catch (e_area_clear) {}

    // Clear global last-move so Copycat cannot use a move from a previous battle
    try { if (variable_global_exists("lastMoveUsed_ID")) global.lastMoveUsed_ID = -1; } catch (e_lm) {}

    // Clear any temporary in-battle stat stages to ensure they don't persist
    try {
        if (is_array(_B.actor)){
            for (var _ai = 0; _ai < array_length(_B.actor); ++_ai){
                var _act = _B.actor[_ai];
                if (is_struct(_act) && variable_struct_exists(_act, "_stages")) variable_struct_set(_act, "_stages", undefined);
            }
        }
    } catch (e_clear) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][close] failed clearing stages: " + string(e_clear)); }

    // Clear transient per-actor draw state so positions/temporary timers do not bleed into
    // subsequent battles or repeated cutscenes (fixes sprites appearing in wrong places).
    try {
        if (is_array(_B.actor)){
            for (var _ai2 = 0; _ai2 < array_length(_B.actor); ++_ai2){
                var _act2 = _B.actor[_ai2];
                if (!is_struct(_act2)) continue;
                // Common transient draw/timer fields used across draw/update code
                var _transient_keys = ["_faint_draw_start_ms","_nudge_active","_nudge_start_ms","_nudge_dur","_nudge_mag","_nudge_dir","_intro_draw_x","_intro_draw_y","_intro_anchor_x"];
                for (var _k = 0; _k < array_length(_transient_keys); ++_k){
                    var _key = _transient_keys[_k];
                    if (variable_struct_exists(_act2, _key)) variable_struct_set(_act2, _key, undefined);
                }
            }
        }
    } catch (e_act_clear) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][close] failed clearing actor transient fields: " + string(e_act_clear)); }

    // Clear any trainer intro state so repeated cutscenes don't reuse previous intro anchors
    try { if (variable_struct_exists(_B, "_trainer_intro")) variable_struct_set(_B, "_trainer_intro", undefined); } catch (e_ti) {}

    // Clear any temporary per-battle weather state
    try { if (variable_struct_exists(_B, "_weather")) variable_struct_set(_B, "_weather", undefined); } catch (e_w) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][close] failed clearing weather: " + string(e_w)); }

    // Temporary defeat handling: if the player lost, fully heal the party in-place
    // (until Pok�mon Centers are implemented). This restores HP to max and clears
    // all status effects but does not change the player's location.
    try {
        if (__battle_is_local_versus_slot(_B) && variable_struct_exists(_B, "_local_versus_loser_pid") && is_real(variable_struct_get(_B, "_local_versus_loser_pid"))){
            var _loser_pid_close = max(0, floor(variable_struct_get(_B, "_local_versus_loser_pid")));
            if (!__battle_party_has_usable_mon(_loser_pid_close) && !is_undefined(__battle_heal_party_full)) __battle_heal_party_full(_loser_pid_close);
        } else if (variable_struct_exists(_B, "result") && string(_B.result) == "lose"){
            if (!__battle_party_has_usable_mon(_pid) && !is_undefined(__battle_heal_party_full)) __battle_heal_party_full(_pid);
        }
    } catch (e_healclose) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][close] heal-on-lose failed: " + string(e_healclose)); }

    // Ensure the battle music (bgm) is stopped (use stored resource when possible)
    try {
        var _stop_bgm_res_local = (variable_struct_exists(_B, "_battle_music") ? variable_struct_get(_B, "_battle_music") : undefined);
        var _bh_local2 = (variable_struct_exists(_B, "_bgm_handle") ? variable_struct_get(_B, "_bgm_handle") : undefined);
        if (!is_undefined(_stop_bgm_res_local)){
            try {
                if (!is_undefined(_bh_local2)){
                    __battle_audio_stop_handle(_bh_local2);
                    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][audio] __battle_audio_stop_handle called on bgm_handle=" + string(_bh_local2));
                }
            } catch (e_stop_b) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][audio] failed stopping battle music: " + string(e_stop_b)); }
        }
    } catch (e_b_all) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][audio] error while attempting to stop battle music: " + string(e_b_all)); }

    // Ensure the defeated/victory music is stopped (use stored resource when possible)
    try {
    var _stop_res = (variable_struct_exists(_B, "_battle_defeated_music") ? variable_struct_get(_B, "_battle_defeated_music") : undefined);
        if (!is_undefined(_stop_res)){
            try {
                if (!is_undefined(_def_handle_local)){
                    __battle_audio_stop_handle(_def_handle_local);
                    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][audio] __battle_audio_stop_handle called on defeated_handle=" + string(_def_handle_local));
                }
            } catch (e_stop_d) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][audio] failed stopping defeated music: " + string(e_stop_d)); }
        }
    } catch (e_all_stop) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][audio] error while attempting to stop defeated music: " + string(e_all_stop)); }

    // Restore overworld audio only after every active battle has closed.
    // In split-screen singles, the other player's battle music should keep
    // ownership of the music layer until their battle also finishes.
    if (!battle_any_open()){
        try {
            var _prev_audio_local = (variable_struct_exists(_B, "_prev_audio") ? variable_struct_get(_B, "_prev_audio") : undefined);
            try { __battle_restore_prev_audio(_pid); } catch (e_rr) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][audio] __battle_restore_prev_audio failed: " + string(e_rr)); }

            // If there was no previous audio to restore, re-apply the current room's music policy.
            if (is_undefined(_prev_audio_local) || _prev_audio_local == undefined) {
                if (!is_undefined(world_apply_room_music)) {
                    try {
                        world_apply_room_music(room);
                    } catch (e_reg) {
                        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][audio] failed to reapply room music: " + string(e_reg));
                    }
                } else if (variable_global_exists("_REGIONMUSIC") && !is_undefined(global._REGIONMUSIC) && global._REGIONMUSIC != undefined) {
                    try {
                        if (!is_undefined(world_play_music)) world_play_music(global._REGIONMUSIC, true);
                        else if (!is_undefined(audio_play_sound)) audio_play_sound(global._REGIONMUSIC, 1, true);
                    } catch (e_reg_fallback) {
                        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][audio] failed region fallback: " + string(e_reg_fallback));
                    }
                }
            }
        } catch (e_rrall) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][audio] restore/fallback failed: " + string(e_rrall)); }
    } else if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) {
        show_debug_message("[battle][audio] skipped overworld restore because another battle is still open");
    }
    try { __battle_flush_caught_nickname_requests(_B, _pid); } catch (e_flush_caught_nicknames) {}
}

// ===== Intro animation extension hooks =====
/// battle_intro_set_handlers(pid, update_fn, draw_fn)
/// Allows external code to register intro sprite animation handlers.
/// Handlers will be called during intro phases: transition_in, intro_enemy, intro_call, intro_player.
/// Register per-battle intro animation handlers.
/// Params:
///  - _pid (int): player id
///  - _update_fn (fn|undefined): function(pid, B) called during intro phases (update)
///  - _draw_fn (fn|undefined): function(pid, B) called during intro phases (draw)
/// Returns: none
function battle_intro_set_handlers(_pid, _update_fn, _draw_fn){
    var _B = __battle_ensure_slot(_pid);
    try { variable_struct_set(_B, "_intro_update_fn", _update_fn); } catch (e1) {}
    try { variable_struct_set(_B, "_intro_draw_fn", _draw_fn); } catch (e2) {}
}

/// Internal: update hook for intro animations (safe no-op by default)
function __battle_intro_update(_pid){
    var _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B)) return;
    if (variable_struct_exists(_B, "_intro_update_fn")){
        var _fn = variable_struct_get(_B, "_intro_update_fn");
        if (!is_undefined(_fn)){
            try { _fn(_pid, _B); } catch (e_upd) {}
        }
    }
}

/// Internal: draw hook for intro animations (safe no-op by default)
function __battle_intro_draw(_pid, _B){
    if (!is_struct(_B)) return;
    if (variable_struct_exists(_B, "_intro_draw_fn")){
        var _fn = variable_struct_get(_B, "_intro_draw_fn");
        if (!is_undefined(_fn)){
            try { _fn(_pid, _B); } catch (e_dr) {}
        }
    }
}

function __battle_dialog_debug_enabled(){
    var enabled = false;
    try {
        if (variable_global_exists("DATA_DEBUG_DIALOG")) enabled = (global.DATA_DEBUG_DIALOG == true);
        else if (variable_global_exists("DATA_DEBUG")) enabled = (global.DATA_DEBUG == true);
    } catch (e_flag) { enabled = false; }
    return enabled;
}

function __battle_fetch_global_function(_name){
    var fn = undefined;
    try {
        if (variable_global_exists(_name)) fn = variable_global_get(_name);
    } catch (e_fn) { fn = undefined; }
    if (!is_undefined(fn) && is_method(fn)) return fn;
    return undefined;
}

function __battle_try_enqueue_faint_dialog(_pid, _B, _text, _key){
    var slot = _B;
    if (!is_struct(slot)) slot = __battle_ensure_slot(_pid);
    if (!is_struct(slot)) return false;

    var key_use = string(_key);
    var active = false;
    var last_key = "";
    if (variable_struct_exists(slot, "_faint_dialog_active")){
        try { active = (variable_struct_get(slot, "_faint_dialog_active") == true); } catch (e_flag) { active = false; }
    }
    if (variable_struct_exists(slot, "_faint_dialog_key")){
        try { last_key = string(variable_struct_get(slot, "_faint_dialog_key")); } catch (e_key) { last_key = ""; }
    }

    var dbg = __battle_dialog_debug_enabled();
    if (dbg){
        show_debug_message("[battle][dialog] faint enqueue request pid=" + string(_pid) + ", key=" + key_use + ", active=" + string(active) + ", last=" + last_key);
    }
    if (active){
        if (last_key == key_use){
            if (dbg) show_debug_message("[battle][dialog] faint enqueue skipped (duplicate key) pid=" + string(_pid) + ", key=" + key_use);
            return false;
        }
    }

    try {
        if (!is_undefined(dialog2p_enqueue)) dialog2p_enqueue(_pid, { text: _text, key: key_use, gate: "faint" });
        else if (!is_undefined(dialog2p_show_now)) dialog2p_show_now(_pid, _text);
    } catch (e_dlg) {}

    if (dbg) show_debug_message("[battle][dialog] faint dialog enqueued pid=" + string(_pid) + ", key=" + key_use + ", text=" + string(_text));

    try { variable_struct_set(slot, "_faint_dialog_key", key_use); } catch (e_setk) {}
    try { variable_struct_set(slot, "_faint_dialog_active", true); } catch (e_seta) {}
    return true;
}

// ===== Update / Draw =====
/// Advance battle state for a player. Call from Step every frame.
/// Params: _pid (int)
/// Behavior:
///  - Updates catch/animations, dialog, intro/switch timings, input, and turn resolution.
///  - Handles defeat/victory flows, fade-to-close, and queued messages ordering.
function battle_update(_pid){
    if (!battle_is_open(_pid)) return;
    var _B = __battle_ensure_slot(_pid);

    var __vict_fn = __battle_fetch_global_function("__battle_trainer_victory_update");
    if (!is_undefined(__vict_fn)) __vict_fn(_pid, _B);

    // If the bag enqueued a catch request, process it here so the call stays inside battle code
    if (variable_struct_exists(_B, "_queued_catch")){
        var _q = variable_struct_get(_B, "_queued_catch");
        if (is_struct(_q) && variable_struct_exists(_q, "ball_mult")){
            if (!is_undefined(__battle_try_catch)){
                // Quiet: remove verbose queued-catch debug spam. Enable only when explicitly asked via DATA_DEBUG_VERBOSE.
                if (variable_global_exists("DATA_DEBUG_VERBOSE") && global.DATA_DEBUG_VERBOSE) show_debug_message("[battle][debug] processing queued catch pid=" + string(_pid) + ", iid=" + string((variable_struct_exists(_q, "item_id") ? variable_struct_get(_q, "item_id") : -1)) + ", mult=" + string(variable_struct_get(_q, "ball_mult")));
                __battle_try_catch(_pid, variable_struct_get(_q, "ball_mult"), (variable_struct_exists(_q, "item_id") ? variable_struct_get(_q, "item_id") : undefined), (variable_struct_exists(_q, "target_index") ? variable_struct_get(_q, "target_index") : undefined), (variable_struct_exists(_q, "owner_pid") ? variable_struct_get(_q, "owner_pid") : _pid));
            }
        }
        _B._queued_catch = undefined;
    }

    // Advance any active slot animations (catch animation, etc.)
    if (!is_undefined(__battle_update_animations)) __battle_update_animations(_pid);
    __battle_recover_stuck_catch_if_needed(_pid);
    var _levelup_panel_active = false;
    if (!is_undefined(__battle_update_levelup_panel)) _levelup_panel_active = __battle_update_levelup_panel(_pid);
    if (!is_undefined(evolution_is_active) && evolution_is_active(_pid)) return;

    // If the Bag UI is open for this player, or a catch animation is active,
    // pause battle progression (turn resolution/input processing) so the
    // battle doesn't continue while the player is navigating the bag or
    // while a ball throw/impact/shake animation is underway.
    // Note: __battle_update_animations has already been called above so
    // catch animations will still advance.
    var _bag_open_here = (is_undefined(bag_is_open) ? false : bag_is_open(_pid) || (!is_undefined(pc_is_open) && pc_is_open(_pid)));
    var _party_open_here = (is_undefined(party_is_open) ? false : party_is_open(_pid) || (!is_undefined(pc_is_open) && pc_is_open(_pid)));
    if (_bag_open_here || _party_open_here) return;
    if (__battle_any_player_party_open(_pid)) return;
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

    var _trainer_switch_active = false;
    try {
        if (!is_undefined(__battle_trainer_update_switch_anim)) _trainer_switch_active = __battle_trainer_update_switch_anim(_pid);
    } catch (e_tswitch) { _trainer_switch_active = false; }

    // Cutscene system: allow queued cutscenes to start and pause battle progression
    // when a cutscene is active. This mirrors how the Bag UI and catch animations
    // temporarily suspend battle logic.
    try {
        if (!is_undefined(cutscene_step)) cutscene_step(_pid);
        if (!is_undefined(cutscene_update)) cutscene_update(_pid);
        if (!is_undefined(cutscene_is_playing) && cutscene_is_playing(_pid)){
            // A cutscene is active. By default we pause battle logic while a
            // cutscene runs. However individual cutscene items may opt-in to
            // allow certain battle progression (for example: fade-in during
            // wild-intro). If the current cutscene item has
            // `allow_battle_progress == true` then let the update continue.
            var _allow_progress = false;
            try {
                if (variable_global_exists("CUTSCENE") && is_array(global.CUTSCENE) && array_length(global.CUTSCENE) > _pid){
                    var _sess = global.CUTSCENE[_pid];
                    if (is_struct(_sess) && variable_struct_exists(_sess, "_current_item")){
                        var _ci = variable_struct_get(_sess, "_current_item");
                        if (is_struct(_ci) && variable_struct_exists(_ci, "allow_battle_progress") && variable_struct_get(_ci, "allow_battle_progress") == true) _allow_progress = true;
                    }
                }
            } catch (e_ap) { _allow_progress = false; }
            if (!_allow_progress) return;
        }
    } catch (e_cs) { /* ignore if CutsceneSystem not present or errors; continue */ }

    if (!is_undefined(__battle_trainer_update_switch_prompt)) __battle_trainer_update_switch_prompt(_pid);

    if (!is_undefined(__battle_trainer_apply_pending_send)){
        var __mode_for_trainer = "wild";
        try {
            if (variable_struct_exists(_B, "_battle_mode")) __mode_for_trainer = string_lower(string(variable_struct_get(_B, "_battle_mode")));
        } catch (e_mode_check) {}
        if (__mode_for_trainer == "trainer") __battle_trainer_apply_pending_send(_pid);
    }

    // Detect phase entry and run on-enter actions once
    var _curr_phase = (variable_struct_exists(_B, "phase") ? string(_B.phase) : "");
    if (!variable_struct_exists(_B, "_last_phase") || string(_B._last_phase) != _curr_phase){
        if (!is_undefined(__battle_on_phase_enter)) __battle_on_phase_enter(_pid, _curr_phase);
        _B._last_phase = _curr_phase;
    }

    // Intro sprite animation hook: allow custom per-battle intro animation logic to update
    if (!is_undefined(__battle_intro_update)){
        var _phname_upd = (variable_struct_exists(_B, "phase") ? string(_B.phase) : "");
        if (_phname_upd == "transition_in" || _phname_upd == "intro_enemy" || _phname_upd == "intro_call" || _phname_upd == "intro_player"){
            __battle_intro_update(_pid);
        }
    }

    // (Do not pause update here during closing; we handle closing below so the fade can complete and then close.)

    var _dialog_pids = [_pid];
    if (is_struct(_B) && variable_struct_exists(_B, "player_pids") && is_array(variable_struct_get(_B, "player_pids"))){
        var _battle_dialog_pids = variable_struct_get(_B, "player_pids");
        for (var _bdpi = 0; _bdpi < array_length(_battle_dialog_pids); ++_bdpi){
            var _bdp = _battle_dialog_pids[_bdpi];
            if (!is_real(_bdp)) continue;
            _bdp = floor(_bdp);
            var _bdp_seen = false;
            for (var _bdps = 0; _bdps < array_length(_dialog_pids); ++_bdps){
                if (_dialog_pids[_bdps] == _bdp){ _bdp_seen = true; break; }
            }
            if (!_bdp_seen) array_push(_dialog_pids, _bdp);
        }
    }
    var _dialog_pid_open = -1;
    var _dialog_pid_primary = -1;
    for (var _bdpo = 0; _bdpo < array_length(_dialog_pids); ++_bdpo){
        var _dialog_pid_probe = _dialog_pids[_bdpo];
        if (!is_real(_dialog_pid_probe)) continue;
        if (!is_undefined(dialog2p_step)) dialog2p_step(_dialog_pid_probe);
        if (!is_undefined(dialog2p_is_open) && dialog2p_is_open(_dialog_pid_probe)){
            if (_dialog_pid_open < 0) _dialog_pid_open = _dialog_pid_probe;
            if (_dialog_pid_probe == _pid) _dialog_pid_primary = _dialog_pid_probe;
        }
    }
    if (_dialog_pid_primary < 0) _dialog_pid_primary = _dialog_pid_open;
    var dlg_open = (_dialog_pid_open >= 0);
    if (dlg_open){
        if (!is_undefined(dialog2p_update)){
            for (var _dui = 0; _dui < array_length(_dialog_pids); ++_dui){
                var _dialog_pid_update = _dialog_pids[_dui];
                if (!is_real(_dialog_pid_update)) continue;
                if (!is_undefined(dialog2p_is_open) && dialog2p_is_open(_dialog_pid_update)) dialog2p_update(_dialog_pid_update);
            }
        }
    var d = (_dialog_pid_primary >= 0)
        ? ((!is_undefined(dialog2p_ensure_pid)) ? dialog2p_ensure_pid(_dialog_pid_primary) : global.DIALOG2P[_dialog_pid_primary])
        : undefined;
    var page = 0;
    if (is_struct(d) && variable_struct_exists(d, "page_idx")) page = variable_struct_get(d, "page_idx");

        if (!variable_struct_exists(_B, "_dlg_page_last")) _B._dlg_page_last = -1;
        if (page != _B._dlg_page_last){
            var now = current_time;
            if (!variable_struct_exists(_B, "_intro_completed") || !_B._intro_completed){
                // Do not skip the fade-in: let transition_in complete based on its timer.
                // We only advance to intro_call on page==1; intro_enemy is entered when transition_in finishes.
                if (page == 1){
                    _B.phase = "intro_call"; _B.phase_start_ms = now;
                }
            }
            _B._dlg_page_last = page;
        }

        var now2 = current_time;
        // While dialog is open, keep the fade-in progression if we're still in transition_in
        if (string(_B.phase) == "transition_in"){
            var dur_t = _B.phase_durs.transition;
            var elapsed_t = now2 - (variable_struct_exists(_B,"phase_start_ms") ? _B.phase_start_ms : now2);
            _B.phase_progress = max(0, min(1, elapsed_t / max(1, dur_t)));
            if (elapsed_t >= dur_t){ _B.phase = "intro_enemy"; _B.phase_start_ms = now2; }
        } else if (string(_B.phase) == "intro_enemy"){
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
        return;
    }

    if (_trainer_switch_active) return;

    // If a dialog just closed
    if (variable_struct_exists(_B, "_dlg_active") && _B._dlg_active){
        var now3 = current_time;
    var _faint_active_flag = false;
    try { if (variable_struct_exists(_B, "_faint_dialog_active") && variable_struct_get(_B, "_faint_dialog_active")) _faint_active_flag = true; } catch (e_fa) { _faint_active_flag = false; }
    var _faint_queue_flag = false;
    try {
        if (!is_undefined(dialog2p_queue_has_faint)){
            for (var _fqpi = 0; _fqpi < array_length(_dialog_pids); ++_fqpi){
                if (dialog2p_queue_has_faint(_dialog_pids[_fqpi])){ _faint_queue_flag = true; break; }
            }
        }
    } catch (e_fq) { _faint_queue_flag = false; }
        if (_faint_active_flag || _faint_queue_flag){
            _B._dlg_active = true;
            return;
        }
        _B._dlg_active = false;
        // If a party open was scheduled due to a faint, perform it now BUT
        // only after a small delay marker (to allow the faint dialog to render)
        // and only if the dialog system is no longer actively open. This
        // prevents the party UI from opening before the faint message is
        // visually presented.
        try {
                if (variable_struct_exists(_B, "_pending_open_party") && variable_struct_get(_B, "_pending_open_party")){
                    try { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle_system] pending_open_party detected pid=" + string(_pid)); } catch (e_dbgp) {}
                // Check delay marker
                var _delay_ok = true;
                try {
                    if (variable_struct_exists(_B, "_pending_open_party_delay_until")){
                        var _du = variable_struct_get(_B, "_pending_open_party_delay_until");
                        if (is_real(_du) && current_time < _du) _delay_ok = false;
                    }
                } catch (e_do) { _delay_ok = true; }
                    try { if (! _delay_ok && variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle_system] pending_open_party delay not yet expired pid=" + string(_pid) + ", until=" + string(variable_struct_get(_B, "_pending_open_party_delay_until"))); } catch(e_dbgd) {}
                // If the dialog system still reports open, wait (it will call
                // this handler again when it closes). Otherwise, and if the
                // delay has expired, open the party UI now.
                var _dlg_open_now = false;
                if (!is_undefined(dialog2p_is_open)){
                    for (var _dnow_i = 0; _dnow_i < array_length(_dialog_pids); ++_dnow_i){
                        if (dialog2p_is_open(_dialog_pids[_dnow_i])){ _dlg_open_now = true; break; }
                    }
                }
                    try { if (_dlg_open_now && variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle_system] pending_open_party waiting for dialog to close pid=" + string(_pid)); } catch(e_dbgg) {}
                if (_delay_ok && !_dlg_open_now){
                    var _pending_party_pid = _pid;
                    try {
                        if (variable_struct_exists(_B, "_pending_open_party_pid") && is_real(variable_struct_get(_B, "_pending_open_party_pid"))) _pending_party_pid = floor(variable_struct_get(_B, "_pending_open_party_pid"));
                    } catch (e_pending_party_pid) { _pending_party_pid = _pid; }
                    try {
                        if (variable_struct_exists(_B, "_pending_open_party_fainted_actor_index") && is_real(variable_struct_get(_B, "_pending_open_party_fainted_actor_index"))){
                            var _pending_fainted_actor = floor(variable_struct_get(_B, "_pending_open_party_fainted_actor_index"));
                            var _pending_owner_pid = __battle_actor_owner_pid(_pid, _pending_fainted_actor);
                            if (is_real(_pending_owner_pid) && _pending_owner_pid >= 0){
                                _pending_party_pid = floor(_pending_owner_pid);
                                variable_struct_set(_B, "_pending_open_party_pid", _pending_party_pid);
                            }
                        }
                    } catch (e_pending_party_owner) {}
                    var __isLoss = false;
                    try { if (variable_struct_exists(_B, "result")) __isLoss = (string(variable_struct_get(_B, "result")) == "lose"); } catch (e_rl) { __isLoss = false; }
                    var __idxAlive = -1;
                    try { __idxAlive = __party_find_next_alive(_pending_party_pid); } catch (e_fn) { __idxAlive = -1; }
                    if (__isLoss || __idxAlive < 0){
                        try { variable_struct_set(_B, "_pending_open_party", false); } catch (e_clx) {}
                        try { variable_struct_set(_B, "_pending_open_party_next_mon_ref", undefined); } catch (e_clx2) {}
                        try { variable_struct_set(_B, "_pending_open_party_pid", undefined); } catch (e_clx3) {}
                    } else {
                        if (!is_undefined(party_open) && !is_undefined(party_ensure)){
                            party_open(_pending_party_pid);
                            var _Ptmp2 = party_ensure(_pending_party_pid);
                            try {
                                if (is_struct(_Ptmp2)){
                                    try {
                                        if (!is_undefined(party_set_swap_mode_impl)) party_set_swap_mode_impl(_pending_party_pid, true, true);
                                        else {
                                            try { variable_struct_set(_Ptmp2, "_battle_swap_mode", true); } catch (e_f1) {}
                                            try { variable_struct_set(_Ptmp2, "_battle_swap_mode_forced", true); } catch (e_f2) {}
                                        }
                                    } catch (e_h) {
                                        try { variable_struct_set(_Ptmp2, "_battle_swap_mode", true); variable_struct_set(_Ptmp2, "_battle_swap_mode_forced", true); } catch (e2) {}
                                    }
                                    try {
                                        if (variable_struct_exists(_B, "_pending_open_party_fainted_actor_index") && is_real(variable_struct_get(_B, "_pending_open_party_fainted_actor_index"))) variable_struct_set(_Ptmp2, "_battle_swap_actor_index", floor(variable_struct_get(_B, "_pending_open_party_fainted_actor_index")));
                                    } catch (e_swap_actor_pending) {}
                                    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){
                                        show_debug_message("[battle_system] pending_open_party -> pid=" + string(_pending_party_pid) + ", set _battle_swap_mode=true, _battle_swap_mode_forced=true");
                                    }
                                    variable_struct_set(_Ptmp2, "lock", 0);
                                    try {
                                        if (variable_struct_exists(_B, "_pending_open_party_next_mon_ref")){
                                            var _mref2 = variable_struct_get(_B, "_pending_open_party_next_mon_ref");
                                            if (is_struct(_mref2)){
                                                var _mons2 = party_model_get_mons(_pending_party_pid);
                                                for (var _ii2 = 0; _ii2 < array_length(_mons2); ++_ii2){
                                                    if (is_struct(_mons2[_ii2]) && (_mons2[_ii2] == _mref2)){
                                                        _Ptmp2.sel = _ii2;
                                                        break;
                                                    }
                                                }
                                            }
                                        }
                                    } catch (e_map2) {}
                                    try { if (!is_undefined(party_model_reorder_fainted_to_bottom)) party_model_reorder_fainted_to_bottom(_pending_party_pid); } catch (e_reord2) {}
                                }
                            } catch (e_bt2) {}
                        } else {
                            if (!is_undefined(__battle_try_enqueue_faint_dialog)) __battle_try_enqueue_faint_dialog(_pending_party_pid, _B, "(Unknown) fainted!\n(TODO) Switch to another Pok\u00e9mon.", "(Unknown) fainted!");
                        }
                        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][faint] executing scheduled party_open for pid=" + string(_pending_party_pid));
                        try { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle_system] party_open called pid=" + string(_pending_party_pid)); } catch(e_dbgop) {}
                        try { variable_struct_set(_B, "_pending_open_party", false); } catch (e_cl) {}
                        try { variable_struct_set(_B, "_pending_open_party_next_mon_ref", undefined); } catch (e_cl2) {}
                        try { variable_struct_set(_B, "_pending_open_party_pid", undefined); } catch (e_cl3) {}
                    }
                }
            }
        } catch (e_pending_open) {}

        // Clear faint pending now that we've handled (or scheduled) the party open
    try { variable_struct_set(_B, "_faint_pending", false); } catch (e_fp_clear) {}
        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][faint] _faint_pending cleared for pid=" + string(_pid));
        _B._dlg_page_last = -1;
        // If code requested we wait-for-dialog-close before showing UI,
        // convert that request into a short suppression window now that
        // the dialog has actually closed. This prevents a visible flash
        // between the intro/dialog and the command UI appearing.
        try {
            if (variable_struct_exists(_B, "_suppress_wait_for_dialog_close") && variable_struct_get(_B, "_suppress_wait_for_dialog_close")){
                variable_struct_set(_B, "_suppress_wait_for_dialog_close", false);
                var _now_s = (is_real(current_time) ? current_time : 0);
                var _short = 220; // ms; short suppression after dialog close
                var _cur_sup2 = (variable_struct_exists(_B, "_suppress_sys_ui_until") ? variable_struct_get(_B, "_suppress_sys_ui_until") : -1);
                var _desired2 = _now_s + _short;
                if (!is_real(_cur_sup2) || _cur_sup2 < _desired2) variable_struct_set(_B, "_suppress_sys_ui_until", _desired2);
            }
        } catch (e_swdc) {}
        // Small input-grace window: suppress accidental buffered inputs that
        // occurred while the dialog was open (e.g. the same button that
        // advanced/closed the dialog). This prevents immediate re-selection
        // of UI options right after dialog close.
        if (is_real(now3)) variable_struct_set(_B, "_input_grace_until", now3 + 180);
        if (_B.phase == "intro_call"){
            _B.phase = "intro_player"; _B.phase_start_ms = now3;
        } else if (variable_struct_exists(_B, "_pending_close") && variable_struct_get(_B, "_pending_close")){
            if (!is_undefined(virtual_keyboard_blocks_input) && virtual_keyboard_blocks_input(_pid)){
                try { variable_struct_set(_B, "_closing", false); } catch (e_close_hold_vk1) {}
                try { variable_struct_set(_B, "_close_start_ms", undefined); } catch (e_close_hold_vk2) {}
                return;
            }
            if (__battle_has_active_exp_sequence(_B)){
                try { variable_struct_set(_B, "_closing", false); } catch (e_close_hold1) {}
                try { variable_struct_set(_B, "_close_start_ms", undefined); } catch (e_close_hold2) {}
                return;
            }
            // If there are queued end-of-battle messages (e.g., defeat pages), show them BEFORE starting the fade
            // so they are not skipped by the close flow.
            try {
                var _dlg_now_c = (is_undefined(dialog2p_is_open) ? false : dialog2p_is_open(_pid));
                var _has_msgs_c = (variable_struct_exists(_B, "_pending_status_msgs") && is_array(variable_struct_get(_B, "_pending_status_msgs")) && array_length(variable_struct_get(_B, "_pending_status_msgs")) > 0);
                var _fainting_c = (variable_struct_exists(_B, "_faint_pending") && variable_struct_get(_B, "_faint_pending"));
                var _ph_c = (variable_struct_exists(_B, "phase") ? string(_B.phase) : "");
                var _skip_c = (_ph_c == "transition_in" || _ph_c == "intro_enemy" || _ph_c == "intro_call" || _ph_c == "intro_player" || _ph_c == "switch_in");
                if (_has_msgs_c && !_fainting_c && !_dlg_now_c && !_skip_c){
                    var _pack_c = (is_undefined(__battle_coalesce_head_stat_msgs) ? undefined : __battle_coalesce_head_stat_msgs(_B));
                    var _text_c = undefined;
                    var _cons_c = 1;
                    if (is_struct(_pack_c) && variable_struct_exists(_pack_c, "text")){
                        _text_c = variable_struct_get(_pack_c, "text");
                        if (variable_struct_exists(_pack_c, "consumed") && is_real(variable_struct_get(_pack_c, "consumed"))) _cons_c = max(1, floor(variable_struct_get(_pack_c, "consumed")));
                    } else {
                        var _arr_c = variable_struct_get(_B, "_pending_status_msgs");
                        _text_c = __battle_pending_msg_text(_arr_c[0]);
                        _cons_c = 1;
                    }
                    var _first_msg_c_arr = variable_struct_get(_B, "_pending_status_msgs");
                    var _msg_pid_c = (is_struct(_pack_c) && variable_struct_exists(_pack_c, "pid") && is_real(variable_struct_get(_pack_c, "pid"))) ? max(0, floor(variable_struct_get(_pack_c, "pid"))) : __battle_pending_msg_pid(_first_msg_c_arr[0], _pid);
                    // If we've already shown a 'used' line this turn and this pending
                    // message is exactly that same line, drop it instead of showing again.
                    try {
                        var _lus_shown_c = (variable_struct_exists(_B, "_last_used_dialog_shown") && variable_struct_get(_B, "_last_used_dialog_shown"));
                        var _lus_text_c  = (variable_struct_exists(_B, "_last_used_dialog_text") ? string(variable_struct_get(_B, "_last_used_dialog_text")) : "");
                        if (_lus_shown_c && string(_text_c) == _lus_text_c){
                            var _old_drop_c = variable_struct_get(_B, "_pending_status_msgs");
                            var _new_drop_c = [];
                            for (var _ii_dc = _cons_c; _ii_dc < array_length(_old_drop_c); ++_ii_dc) _new_drop_c[array_length(_new_drop_c)] = _old_drop_c[_ii_dc];
                            variable_struct_set(_B, "_pending_status_msgs", _new_drop_c);
                            return;
                        }
                    } catch (e_dupc) {}
                    var _old_c = variable_struct_get(_B, "_pending_status_msgs");
                    var _new_c = [];
                    for (var _ii_c = _cons_c; _ii_c < array_length(_old_c); ++_ii_c) _new_c[array_length(_new_c)] = _old_c[_ii_c];
                    variable_struct_set(_B, "_pending_status_msgs", _new_c);
                    try { dialog2p_show_now(_msg_pid_c, _text_c); } catch (e_msgc) { try { dialog2p_enqueue(_msg_pid_c, _text_c); } catch(e_){} }
                    return;
                }
            } catch (e_preclose_msg) {}
            // If the dialog queue has items (e.g., a faint line enqueued to show last),
            // drain it before starting the fade-to-close.
            try {
                if (variable_global_exists("DIALOG2P_Q") && is_array(global.DIALOG2P_Q) && array_length(global.DIALOG2P_Q) > _pid){
                    var _q = global.DIALOG2P_Q[_pid];
                    if (is_array(_q) && array_length(_q) > 0){
                        if (!is_undefined(dialog2p_step)) dialog2p_step(_pid);
                        return;
                    }
                }
            } catch (e_qdrain) {}
            // Start or progress the battle close transition before closing the battle.
            var nowc = current_time;
            var _has_start = (variable_struct_exists(_B, "_close_start_ms") && is_real(variable_struct_get(_B, "_close_start_ms")));
            if (!_has_start){
                __battle_begin_close_transition(_B, nowc);
                return;
            } else {
                var _st = (is_real(variable_struct_get(_B, "_close_start_ms")) ? variable_struct_get(_B, "_close_start_ms") : nowc);
                var elapsed_close = nowc - _st;
                var _durv = (variable_struct_exists(_B, "_close_dur_ms") && is_real(variable_struct_get(_B, "_close_dur_ms")) ? variable_struct_get(_B, "_close_dur_ms") : 600);
                var dur_close = _durv;
                if (elapsed_close >= dur_close){
                    variable_struct_set(_B, "_closing", false);
                    variable_struct_set(_B, "_pending_close", false);
                    battle_close(_pid);
                    return;
                } else {
                    // keep fading; defer close until duration elapses
                    return;
                }
            }
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
    }

    // Global closing handler: if a close is pending or an active closing fade is in progress,
    // run the fade timer here and close when done. This covers cases where we scheduled close
    // without a dialog closing event on the exact frame.
    try {
        var __isPendingClose = (variable_struct_exists(_B, "_pending_close") && variable_struct_get(_B, "_pending_close"));
        var __isClosing = (variable_struct_exists(_B, "_closing") && variable_struct_get(_B, "_closing"));
        if (__isPendingClose || __isClosing){
            if (__battle_has_active_exp_sequence(_B)){
                try { variable_struct_set(_B, "_closing", false); } catch (e_close_hold3) {}
                try { variable_struct_set(_B, "_close_start_ms", undefined); } catch (e_close_hold4) {}
                return;
            }
            // If we owe the player queued messages (e.g., defeat text), surface them before starting/resuming the fade
            try {
                var _dlg_now_g = (is_undefined(dialog2p_is_open) ? false : dialog2p_is_open(_pid));
                var _has_msgs_g = (variable_struct_exists(_B, "_pending_status_msgs") && is_array(variable_struct_get(_B, "_pending_status_msgs")) && array_length(variable_struct_get(_B, "_pending_status_msgs")) > 0);
                var _fainting_g = (variable_struct_exists(_B, "_faint_pending") && variable_struct_get(_B, "_faint_pending"));
                var _ph_g = (variable_struct_exists(_B, "phase") ? string(_B.phase) : "");
                var _skip_g = (_ph_g == "transition_in" || _ph_g == "intro_enemy" || _ph_g == "intro_call" || _ph_g == "intro_player" || _ph_g == "switch_in");
                if (_has_msgs_g && !_fainting_g && !_dlg_now_g && !_skip_g){
                    var _pack_g = (is_undefined(__battle_coalesce_head_stat_msgs) ? undefined : __battle_coalesce_head_stat_msgs(_B));
                    var _text_g = undefined;
                    var _cons_g = 1;
                    if (is_struct(_pack_g) && variable_struct_exists(_pack_g, "text")){
                        _text_g = variable_struct_get(_pack_g, "text");
                        if (variable_struct_exists(_pack_g, "consumed") && is_real(variable_struct_get(_pack_g, "consumed"))) _cons_g = max(1, floor(variable_struct_get(_pack_g, "consumed")));
                    } else {
                        var _arr_g = variable_struct_get(_B, "_pending_status_msgs");
                        _text_g = __battle_pending_msg_text(_arr_g[0]);
                        _cons_g = 1;
                    }
                    var _first_msg_g_arr = variable_struct_get(_B, "_pending_status_msgs");
                    var _msg_pid_g = (is_struct(_pack_g) && variable_struct_exists(_pack_g, "pid") && is_real(variable_struct_get(_pack_g, "pid"))) ? max(0, floor(variable_struct_get(_pack_g, "pid"))) : __battle_pending_msg_pid(_first_msg_g_arr[0], _pid);
                    // Drop duplicate 'used' message if it was already shown earlier.
                    try {
                        var _lus_shown_g = (variable_struct_exists(_B, "_last_used_dialog_shown") && variable_struct_get(_B, "_last_used_dialog_shown"));
                        var _lus_text_g  = (variable_struct_exists(_B, "_last_used_dialog_text") ? string(variable_struct_get(_B, "_last_used_dialog_text")) : "");
                        if (_lus_shown_g && string(_text_g) == _lus_text_g){
                            var _old_drop_g = variable_struct_get(_B, "_pending_status_msgs");
                            var _new_drop_g = [];
                            for (var _ii_dg = _cons_g; _ii_dg < array_length(_old_drop_g); ++_ii_dg) _new_drop_g[array_length(_new_drop_g)] = _old_drop_g[_ii_dg];
                            variable_struct_set(_B, "_pending_status_msgs", _new_drop_g);
                            return;
                        }
                    } catch (e_dupg) {}
                    var _old_g = variable_struct_get(_B, "_pending_status_msgs");
                    var _new_g = [];
                    for (var _ii_g = _cons_g; _ii_g < array_length(_old_g); ++_ii_g) _new_g[array_length(_new_g)] = _old_g[_ii_g];
                    variable_struct_set(_B, "_pending_status_msgs", _new_g);
                    try { if (!is_undefined(dialog2p_show_now)) dialog2p_show_now(_msg_pid_g, _text_g); else if (!is_undefined(dialog2p_enqueue_text)) dialog2p_enqueue_text(_msg_pid_g, _text_g, _text_g, "any"); } catch (e_msgg) {}
                    return;
                }
            } catch (e_preclose_msg_g) {}
            // Drain dialog queue (e.g., faint line) before or while fading
            try {
                if (variable_global_exists("DIALOG2P_Q") && is_array(global.DIALOG2P_Q) && array_length(global.DIALOG2P_Q) > _pid){
                    var _q2 = global.DIALOG2P_Q[_pid];
                    if (is_array(_q2) && array_length(_q2) > 0){
                        if (!is_undefined(dialog2p_step)) dialog2p_step(_pid);
                        // If fade hasn't started, defer starting it until after queue drains
                        var hasStart2_check = (variable_struct_exists(_B, "_close_start_ms") && is_real(variable_struct_get(_B, "_close_start_ms")));
                        if (!hasStart2_check) return;
                    }
                }
            } catch (e_qdrain2) {}
            var nowc2 = current_time;
            var hasStart2 = (variable_struct_exists(_B, "_close_start_ms") && is_real(variable_struct_get(_B, "_close_start_ms")));
            if (!hasStart2){
                __battle_begin_close_transition(_B, nowc2);
                return;
            } else {
                var st2 = (is_real(variable_struct_get(_B, "_close_start_ms")) ? variable_struct_get(_B, "_close_start_ms") : nowc2);
                var dur2 = (variable_struct_exists(_B, "_close_dur_ms") && is_real(variable_struct_get(_B, "_close_dur_ms")) ? variable_struct_get(_B, "_close_dur_ms") : 600);
                var el2 = nowc2 - st2;
                if (el2 >= dur2){
                    variable_struct_set(_B, "_closing", false);
                    variable_struct_set(_B, "_pending_close", false);
                    battle_close(_pid);
                    return;
                } else {
                    return;
                }
            }
        }
    } catch (e_closeflow) {}
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
            // If a faint is pending, do not surface pending status messages yet.
            if (!_skip_pending_show && ( !variable_struct_exists(_B, "_faint_pending") || !variable_struct_get(_B, "_faint_pending") ) && variable_struct_exists(_B, "_pending_status_msgs") && is_array(variable_struct_get(_B, "_pending_status_msgs"))){
                var _ps = variable_struct_get(_B, "_pending_status_msgs");
                if (array_length(_ps) > 0){
                    // Coalesce consecutive stat-change messages into one page
                    var pack = __battle_coalesce_head_stat_msgs(_B);
                    var _text_to_show = undefined;
                    var _consume_n = 1;
                    if (is_struct(pack) && variable_struct_exists(pack, "text")){
                        _text_to_show = variable_struct_get(pack, "text");
                        if (variable_struct_exists(pack, "consumed") && is_real(variable_struct_get(pack, "consumed"))) _consume_n = max(1, floor(variable_struct_get(pack, "consumed")));
                    } else {
                        _text_to_show = __battle_pending_msg_text(_ps[0]);
                        _consume_n = 1;
                    }
                    var _msg_pid_show = (is_struct(pack) && variable_struct_exists(pack, "pid") && is_real(variable_struct_get(pack, "pid"))) ? max(0, floor(variable_struct_get(pack, "pid"))) : __battle_pending_msg_pid(_ps[0], _pid);
                    // If duplicate of an already-shown 'used' line, drop it silently.
                    try {
                        var _lus_shown = (variable_struct_exists(_B, "_last_used_dialog_shown") && variable_struct_get(_B, "_last_used_dialog_shown"));
                        var _lus_text  = (variable_struct_exists(_B, "_last_used_dialog_text") ? string(variable_struct_get(_B, "_last_used_dialog_text")) : "");
                        if (_lus_shown && string(_text_to_show) == _lus_text){
                            var _new_drop = [];
                            for (var _ii_d = _consume_n; _ii_d < array_length(_ps); ++_ii_d) _new_drop[array_length(_new_drop)] = _ps[_ii_d];
                            variable_struct_set(_B, "_pending_status_msgs", _new_drop);
                            return;
                        }
                    } catch (e_dud) {}
                    // pop consumed items
                    var _new = [];
                    for (var _ii = _consume_n; _ii < array_length(_ps); ++_ii) _new[array_length(_new)] = _ps[_ii];
                    variable_struct_set(_B, "_pending_status_msgs", _new);
                    try {
                        // If this is a stat-change dialog, play the appropriate SFX when the dialog shows.
                        try {
                            var _tmp_text_play = string(_text_to_show);
                            if (!is_undefined(__battle_is_stat_status_line) && __battle_is_stat_status_line(_tmp_text_play)){
                                // Prefer raise if any '+' appears; otherwise if '-' appears play lower.
                                var _psnd = undefined;
                                if (string_pos("+", _tmp_text_play) > 0) _psnd = snd_Stat_Raise;
                                else if (string_pos("-", _tmp_text_play) > 0) _psnd = snd_Stat_Lower;
                                if (!is_undefined(_psnd) && !is_undefined(__battle_play_one_shot)){
                                    try { __battle_play_one_shot(_psnd); } catch (e_pst) {}
                                }
                            }
                            var _tmp_text_lower = string_lower(_tmp_text_play);
                            if (!is_undefined(__battle_play_one_shot)){
                                if (string_pos("super effective", _tmp_text_lower) > 0) try { __battle_play_one_shot(snd_SuperEffective); } catch (e_sfx_super) {}
                                else if (string_pos("not very effective", _tmp_text_lower) > 0) try { __battle_play_one_shot(snd_NotVeryEffective); } catch (e_sfx_notvery) {}
                                else if (string_pos("had no effect", _tmp_text_lower) > 0 || string_pos("doesn't affect", _tmp_text_lower) > 0) try { __battle_play_one_shot(snd_NotVeryEffective); } catch (e_sfx_noeffect) {}
                                else if (string_pos("restored", _tmp_text_lower) > 0 || string_pos("regained", _tmp_text_lower) > 0 || string_pos("healed", _tmp_text_lower) > 0) try { __battle_play_one_shot(snd_Heal); } catch (e_sfx_heal) {}
                            }
                            // Also, if there are any pending stat overlays queued at apply-time,
                            // consume and trigger them now so the tiled overlay animates together
                            // with the dialog being shown.
                            try {
                                var _B_now = __battle_ensure_slot(_pid);
                                if (is_struct(_B_now) && variable_struct_exists(_B_now, "_pending_stat_overlays") && is_array(variable_struct_get(_B_now, "_pending_stat_overlays"))){
                                    var _po_arr = variable_struct_get(_B_now, "_pending_stat_overlays");
                                    var _to_consume = (is_struct(pack) && variable_struct_exists(pack, "consumed") && is_real(variable_struct_get(pack, "consumed"))) ? max(1, floor(variable_struct_get(pack, "consumed"))) : 1;
                                    // Debug: report how many pending overlays exist and how many we will consume
                                    try { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][stat_overlay] pending count=" + string(array_length(_po_arr)) + ", consuming=" + string(_to_consume)); } catch (e_dbg2) {}
                                    // Consume up to _to_consume entries. If a doubles move lowered/raised both battlers,
                                    // trigger a single multi-target stencil so both Pokemon get cut out together.
                                    var _new_po = [];
                                    var _overlay_batch = [];
                                    for (var _pi = 0; _pi < array_length(_po_arr); ++_pi){
                                        if (_pi < _to_consume){
                                            var _ent = _po_arr[_pi];
                                            array_push(_overlay_batch, _ent);
                                        } else {
                                            _new_po[array_length(_new_po)] = _po_arr[_pi];
                                        }
                                    }
                                    try {
                                        if (array_length(_overlay_batch) > 1 && !is_undefined(__battle_trigger_stat_overlay_multi)){
                                            __battle_trigger_stat_overlay_multi(_msg_pid_show, _overlay_batch);
                                            try { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][stat_overlay] triggered multi pid=" + string(_msg_pid_show) + ", count=" + string(array_length(_overlay_batch))); } catch(e_dbg_multi) {}
                                        } else if (array_length(_overlay_batch) == 1 && !is_undefined(__battle_trigger_stat_overlay)){
                                            var _ent_single = _overlay_batch[0];
                                            __battle_trigger_stat_overlay(_msg_pid_show, _ent_single.actor, _ent_single.overlay_changes, _ent_single.actor_idx);
                                            try { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][stat_overlay] triggered for pid=" + string(_msg_pid_show) + ", actor_idx=" + string(_ent_single.actor_idx) + ", changes=" + string(_ent_single.overlay_changes)); } catch(e_dbg3) {}
                                        }
                                    } catch (e_tr_outer) {}
                                    variable_struct_set(_B_now, "_pending_stat_overlays", _new_po);
                                }
                            } catch (e_po_cons) {}
                        } catch (e_pp) {}
                        dialog2p_show_now(_msg_pid_show, _text_to_show);
                    } catch (e_p) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][pending_status] failed to show: " + string(e_p)); }
                    return;
                }
            }
        // If a pending item use was queued while the dialog was open (e.g. "You used a Poke Ball!"),
        // start the catch animation now that the dialog has closed.
        if (variable_struct_exists(_B, "_pending_item_use") && is_struct(variable_struct_get(_B, "_pending_item_use"))){
            var _pi_temp = variable_struct_get(_B, "_pending_item_use");
            var _iid_temp = (variable_struct_exists(_pi_temp, "item_id") ? variable_struct_get(_pi_temp, "item_id") : undefined);
            var _mult_temp = (variable_struct_exists(_pi_temp, "ball_mult") ? variable_struct_get(_pi_temp, "ball_mult") : undefined);
            var _target_temp = (variable_struct_exists(_pi_temp, "target_index") ? variable_struct_get(_pi_temp, "target_index") : undefined);
            var _owner_temp = (variable_struct_exists(_pi_temp, "owner_pid") ? variable_struct_get(_pi_temp, "owner_pid") : _pid);
            if (!is_undefined(__battle_try_catch)) __battle_try_catch(_pid, _mult_temp, _iid_temp, _target_temp, _owner_temp);
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

    if (_levelup_panel_active) return;


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
            if (elapsed4 >= dur4){
                // If a switch was requested, enter switch_in now instead of returning to command
                if (variable_struct_exists(_B, "_pending_switch_after_intro") && _B._pending_switch_after_intro){
                    _B._pending_switch_after_intro = false;
                    _B.phase = "switch_in";
                    _B.phase_start_ms = now4;
                    _B.phase_progress = 0;
                } else {
                    // Enter command, but suppress the system UI briefly so the
                    // command/menu box doesn't flash immediately after the
                    // 'Go.' intro/dialog. This mirrors the suppression used
                    // during switch animations.
                    try {
                        var _buf = 400; // ms buffer after intro
                        var _desired_sup = now4 + _buf;
                        var _cur_sup = (variable_struct_exists(_B, "_suppress_sys_ui_until") ? variable_struct_get(_B, "_suppress_sys_ui_until") : -1);
                        if (!is_real(_cur_sup) || _cur_sup < _desired_sup) variable_struct_set(_B, "_suppress_sys_ui_until", _desired_sup);
                    } catch (e_sup) {}
                    // If a dialog is currently open (for example a lingering 'Go.'
                    // dialog), wait for it to close before showing the system UI.
                    // We set a small flag which the dialog-close handler will
                    // convert into a short visual suppression when the dialog
                    // actually closes. This avoids timing races where the UI
                    // briefly flashes between intro end and dialog close.
                    try {
                        var _dlg_now = (is_undefined(dialog2p_is_open) ? false : dialog2p_is_open(_pid));
                        if (_dlg_now) variable_struct_set(_B, "_suppress_wait_for_dialog_close", true);
                    } catch (e_swd) {}
                    _B.phase = "command"; _B._intro_completed = true;
                }
            } else return;
        } else if (stage == "switch_in"){
            var dur5 = (_B.phase_durs.switch_in || 400);
            var elapsed5 = now4 - start;
            _B.phase_progress = max(0, min(1, elapsed5 / max(1,dur5)));
            // Ensure we suppress the command UI for the duration of the switch animation
            // plus a small buffer so the command box doesn't reappear immediately after
            // any switch-related dialogs. This flag is read by the UI draw helpers.
            try {
                var _supp_until = (variable_struct_exists(_B, "_suppress_sys_ui_until") ? variable_struct_get(_B, "_suppress_sys_ui_until") : -1);
                var _desired = start + dur5 + 400; // 400ms buffer after animation
                if (!is_real(_supp_until) || _supp_until < _desired) variable_struct_set(_B, "_suppress_sys_ui_until", _desired);
            } catch (e_supp) {}
            if (_B.phase_progress >= 0.5 && (!variable_struct_exists(_B, "_switch_applied") || !_B._switch_applied)){
                var idx = (variable_struct_exists(_B, "_switch_target_idx") ? _B._switch_target_idx : undefined);
                var opts = (variable_struct_exists(_B, "_switch_opts") ? _B._switch_opts : undefined);
                // Defensive: ensure opts is a struct before calling variable_struct_* helpers
                var auto_apply = true;
                if (is_struct(opts)){
                    if (variable_struct_exists(opts, "auto_apply") && variable_struct_get(opts, "auto_apply") == false) auto_apply = false;
                }
                    if (auto_apply && !is_undefined(party_ensure) && !is_undefined(idx) && is_real(idx)){
                    var _switch_party_pid_apply = (variable_struct_exists(_B, "_switch_party_pid") && is_real(variable_struct_get(_B, "_switch_party_pid"))) ? floor(variable_struct_get(_B, "_switch_party_pid")) : _pid;
                    var P = party_ensure(_switch_party_pid_apply);
                    if (is_array(P.mons) && idx >= 0 && idx < array_length(P.mons)){
                        var __pm_tmp = party_model_get_mon(_switch_party_pid_apply, idx);
                        if (is_undefined(__pm_tmp) || !is_struct(__pm_tmp)) __pm_tmp = P.mons[idx];
                        // Before replacing actor, capture reference to outgoing actor so we can
                        // clear any 'trap' status on the switching-out Pok�mon (Gen3 behavior: switching
                        // frees trapped Pok�mon).
                        var _apply_actor_index = (variable_struct_exists(_B, "_switch_actor_index") && is_real(variable_struct_get(_B, "_switch_actor_index"))) ? floor(variable_struct_get(_B, "_switch_actor_index")) : 0;
                        var _outgoing = undefined;
                        try { if (is_struct(_B.actor[_apply_actor_index])) _outgoing = _B.actor[_apply_actor_index]; } catch (e_out) { _outgoing = undefined; }
                        _B.actor[_apply_actor_index] = __battle_actor_from_party_mon(__pm_tmp);
                        try {
                            var _switch_owner_pid_apply = (!is_undefined(__battle_actor_owner_pid) ? __battle_actor_owner_pid(_pid, _apply_actor_index) : _switch_party_pid_apply);
                            __battle_set_actor_runtime_fields(_B.actor[_apply_actor_index], _apply_actor_index, _switch_owner_pid_apply, _switch_party_pid_apply, idx);
                            __battle_mark_exp_participant(_B, _B.actor[_apply_actor_index]);
                            if (variable_struct_exists(_B, "actor_owner_pid") && is_array(variable_struct_get(_B, "actor_owner_pid"))){
                                var _owners_apply = variable_struct_get(_B, "actor_owner_pid");
                                if (_apply_actor_index >= 0 && _apply_actor_index < array_length(_owners_apply)) _owners_apply[_apply_actor_index] = _switch_owner_pid_apply;
                                variable_struct_set(_B, "actor_owner_pid", _owners_apply);
                            }
                        } catch (e_runtime_switch_fields) {}
                        try { if (is_struct(_B.actor[_apply_actor_index])) variable_struct_set(_B.actor[_apply_actor_index], "_last_moves", []); } catch (e_hc_switch) {}
                        try { if (is_struct(_B.actor[_apply_actor_index])) variable_struct_set(_B.actor[_apply_actor_index], "_switched_in_turn", (variable_struct_exists(_B, "turn_i") && is_real(variable_struct_get(_B, "turn_i"))) ? floor(variable_struct_get(_B, "turn_i")) : 0); } catch (e_stake_switch_turn) {}
                        // Ensure actor_index is set so debug logs and targeting can find the correct slot
                        try { if (is_struct(_B.actor[_apply_actor_index])) variable_struct_set(_B.actor[_apply_actor_index], "actor_index", _apply_actor_index); } catch (e_ai_sw) {}
                        try { if (is_struct(_B.actor[_apply_actor_index])) __battle_apply_baton_pass_payload(_B, _B.actor[_apply_actor_index], _apply_actor_index); } catch (e_bp_apply_player) {}
                        // If outgoing had a trap status, clear it (also try clearing inner .mon)
                        try {
                            if (!is_undefined(status_system_clear_status) && is_struct(_outgoing)){
                                // Prefer clearing on actor wrapper first
                                status_system_clear_status(_outgoing, "trap");
                                status_system_clear_status(_outgoing, "perish-song");
                                status_system_clear_status(_outgoing, "infatuation");
                                // Also try inner mon
                                if (variable_struct_exists(_outgoing, "mon") && is_struct(variable_struct_get(_outgoing, "mon"))){
                                    status_system_clear_status(variable_struct_get(_outgoing, "mon"), "trap");
                                    status_system_clear_status(variable_struct_get(_outgoing, "mon"), "perish-song");
                                    status_system_clear_status(variable_struct_get(_outgoing, "mon"), "infatuation");
                                }
                                if (!is_undefined(status_system_has_status) && !is_undefined(status_system_get) && variable_struct_exists(_B, "actor") && is_array(variable_struct_get(_B, "actor"))){
                                    var _acts_inf = variable_struct_get(_B, "actor");
                                    var _out_mon = (variable_struct_exists(_outgoing, "mon") && is_struct(variable_struct_get(_outgoing, "mon")) ? variable_struct_get(_outgoing, "mon") : undefined);
                                    for (var _ii_inf = 0; _ii_inf < array_length(_acts_inf); ++_ii_inf){
                                        var _cand_inf = _acts_inf[_ii_inf];
                                        if (!is_struct(_cand_inf) || _cand_inf == _outgoing) continue;
                                        if (!status_system_has_status(_cand_inf, "infatuation")) continue;
                                        var _inf_inst = status_system_get(_cand_inf, "infatuation");
                                        var _inf_src = (is_struct(_inf_inst) && variable_struct_exists(_inf_inst, "source") ? variable_struct_get(_inf_inst, "source") : undefined);
                                        var _clear_inf = (_inf_src == _outgoing) || (!is_undefined(_out_mon) && _inf_src == _out_mon);
                                        if (!_clear_inf && is_struct(_inf_src) && variable_struct_exists(_inf_src, "mon") && !is_undefined(_out_mon)) _clear_inf = (variable_struct_get(_inf_src, "mon") == _out_mon);
                                        if (_clear_inf){
                                            status_system_clear_status(_cand_inf, "infatuation");
                                            if (variable_struct_exists(_cand_inf, "mon") && is_struct(variable_struct_get(_cand_inf, "mon"))) status_system_clear_status(variable_struct_get(_cand_inf, "mon"), "infatuation");
                                        }
                                    }
                                }
                            }
                        } catch (e_cl) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][switch] failed clearing trap on outgoing: " + string(e_cl)); }
                        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){
                            try {
                                var dbg_p_moves = (is_struct(__pm_tmp) && variable_struct_exists(__pm_tmp, "moves")) ? string(variable_struct_get(__pm_tmp, "moves")) : "<no-moves>";
                                var dbg_arr_moves = (is_struct(P.mons[idx]) && variable_struct_exists(P.mons[idx], "moves")) ? string(variable_struct_get(P.mons[idx], "moves")) : "<no-moves>";
                                var dbg_act_moves = (is_struct(_B.actor[_apply_actor_index]) && variable_struct_exists(_B.actor[_apply_actor_index], "moves")) ? string(variable_struct_get(_B.actor[_apply_actor_index], "moves")) : "<no-moves>";
                                show_debug_message("[battle][switch_in][dbg_moves] pid=" + string(_pid) + ", idx=" + string(idx) + ", party_model_get_mon.moves=" + dbg_p_moves + ", P.mons[idx].moves=" + dbg_arr_moves + ", actor.moves=" + dbg_act_moves);
                            } catch (e_dbg2) { /* ignore */ }
                        }
                        // Apply entry hazards (spikes/rocks/toxic/sticky web) to the newly switched-in mon
                        try {
                            var __fn_entry_haz_player = undefined;
                            if (variable_global_exists("__battle_apply_entry_hazards")){
                                __fn_entry_haz_player = variable_global_get("__battle_apply_entry_hazards");
                            }
                            if (!is_undefined(__fn_entry_haz_player)) __fn_entry_haz_player(_pid, _apply_actor_index);
                        } catch (e_eh) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][hazards] apply entry hazards error: " + string(e_eh)); }
                        try { __battle_apply_pending_healing_wish_to_actor(_pid, _apply_actor_index, _B.actor[_apply_actor_index]); } catch (e_hw_player) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][healing-wish] player apply failed: " + string(e_hw_player)); }
                        try { if (!is_undefined(__battle_apply_entry_abilities)) __battle_apply_entry_abilities(_pid, _apply_actor_index); } catch (e_ability_entry_player) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][ability] player switch-in ability failed: " + string(e_ability_entry_player)); }
                    }
                }
                _B._switch_applied = true;
            }
            if (!is_undefined(__battle_check_play_cries)) __battle_check_play_cries(_pid);
            if (elapsed5 >= dur5){
                // Switch-in completed. Decide whether this swap consumed the player's action.
                var opts_local = (variable_struct_exists(_B, "_switch_opts") ? _B._switch_opts : {});
                var _switch_party_pid_done = (variable_struct_exists(_B, "_switch_party_pid") && is_real(variable_struct_get(_B, "_switch_party_pid"))) ? floor(variable_struct_get(_B, "_switch_party_pid")) : _pid;
                var _switch_actor_index_done = (variable_struct_exists(_B, "_switch_actor_index") && is_real(variable_struct_get(_B, "_switch_actor_index"))) ? floor(variable_struct_get(_B, "_switch_actor_index")) : 0;
                var consume_turn = true;
                try { if (variable_struct_exists(opts_local, "consume_turn")) consume_turn = variable_struct_get(opts_local, "consume_turn"); } catch (e_ct) { consume_turn = true; }
                if (consume_turn){
                    try {
                        if (!is_undefined(party_set_swap_mode_impl)) party_set_swap_mode_impl(_switch_party_pid_done, false, false);
                        else if (!is_undefined(party_ensure)){
                            var _Pclear_consume = party_ensure(_switch_party_pid_done);
                            if (is_struct(_Pclear_consume)){
                                if (variable_struct_exists(_Pclear_consume, "_battle_swap_mode")) variable_struct_set(_Pclear_consume, "_battle_swap_mode", false);
                                if (variable_struct_exists(_Pclear_consume, "_battle_swap_mode_forced")) variable_struct_set(_Pclear_consume, "_battle_swap_mode_forced", false);
                                if (variable_struct_exists(_Pclear_consume, "_battle_swap_actor_index")) variable_struct_set(_Pclear_consume, "_battle_swap_actor_index", undefined);
                            }
                        }
                    } catch (e_clear_swap_consume) {}
                    try { variable_struct_set(_B, "_pending_open_party", false); } catch (e_clear_pending_consume) {}
                    try { variable_struct_set(_B, "_pending_open_party_next_mon_ref", undefined); } catch (e_clear_pending_ref_consume) {}
                    try { variable_struct_set(_B, "_pending_open_party_fainted_actor_index", undefined); } catch (e_clear_pending_actor_consume) {}
                    var _is_double_switch = (variable_struct_exists(_B, "battle_format") && string(variable_struct_get(_B, "battle_format")) == "double");
                    if (_is_double_switch && __battle_actor_side(_switch_actor_index_done) == 0){
                        var _queued_switch = {
                            actor_index: _switch_actor_index_done,
                            target_index: __battle_get_default_target_index(_pid, _switch_actor_index_done),
                            skip_turn: true,
                            swapped: true,
                            lock_action: true
                        };
                        __battle_store_player_turn_action(_B, _queued_switch);
                        var _next_actor_after_switch = __battle_next_command_actor_index(_pid, _switch_actor_index_done);
                        if (_next_actor_after_switch >= 0){
                            try { variable_struct_set(_B, "_preserve_player_turn_actions_once", true); } catch (e_keep_actions) {}
                            variable_struct_set(_B, "_command_actor_index", _next_actor_after_switch);
                            _B.phase = "command";
                            if (!is_undefined(__battle_on_phase_enter)) __battle_on_phase_enter(_pid, "command");
                            try { variable_struct_set(_B, "_last_phase", "command"); } catch (e_last_phase_switch) {}
                            try { variable_struct_set(_B, "_action_active", false); } catch (e_switch_action_clear) {}
                            try { variable_struct_set(_B, "_suppress_wait_for_dialog_close", false); } catch (e_switch_wait_clear) {}
                            try { variable_struct_set(_B, "_suppress_sys_ui_until", undefined); } catch (e_switch_ui_clear) {}
                            if (is_struct(_B.sys_ui)){
                                _B.sys_ui.menu = "root";
                                _B.sys_ui.selX = 0;
                                _B.sys_ui.selY = 0;
                                variable_struct_set(_B.sys_ui, "_prev_root_selX", 0);
                                variable_struct_set(_B.sys_ui, "_prev_root_selY", 0);
                            }
                        } else {
                            _B.turn_action_player = undefined;
                            _B.turn_action_enemy = __battle_enemy_choose_action(_pid);
                            _B.turn_queue = __battle_build_turn_actions(_pid);
                            try { variable_struct_set(_B, "_player_turn_actions", []); } catch (e_switch_turn_queue_actions) {}
                            try { variable_struct_set(_B, "_preserve_player_turn_actions_once", false); } catch (e_switch_turn_queue_preserve) {}
                            _B.turn_i = 0;
                            try { variable_struct_set(_B, "_action_active", true); } catch (e_aa) {}
                            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){
                                try { show_debug_message("[battle][dbg]_action_active set=true (switch_in) pid=" + string(_pid)); } catch (e_dbg_aa) {}
                            }
                            _B.phase = "turn";
                        }
                    } else {
                        // Treat the swap as the player's action: queue an enemy response.
                        _B.turn_action_player = undefined;
                        _B.turn_action_enemy = __battle_enemy_choose_action(_pid);
                        _B.turn_queue = __battle_build_turn_actions(_pid);
                        try { variable_struct_set(_B, "_player_turn_actions", []); } catch (e_switch_single_turn_queue_actions) {}
                        try { variable_struct_set(_B, "_preserve_player_turn_actions_once", false); } catch (e_switch_single_turn_queue_preserve) {}
                        _B.turn_i = 0;
                        // Mark that an action sequence is active so UI remains hidden
                        try { variable_struct_set(_B, "_action_active", true); } catch (e_aa) {}
                        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){
                            try { show_debug_message("[battle][dbg]_action_active set=true (switch_in) pid=" + string(_pid)); } catch (e_dbg_aa) {}
                        }
                        _B.phase = "turn";
                    }
                } else {
                    // Forced swap: return to command so the player can choose an action.
                    _B.phase = "command";
                    // Restore previously-saved UI menu/selection if this forced swap stored it.
                    // If the saved menu was the Fight submenu, prefer returning to "root"
                    // so the UI does not immediately reopen the Fight menu after a forced swap.
                    try {
                        if (variable_struct_exists(_B, "_pending_open_party_prev_menu")){
                            var _pmenu = variable_struct_get(_B, "_pending_open_party_prev_menu");
                            // Defensive: if a faint interrupted a submenu or target pick,
                            // always return to the main command block instead of reopening
                            // stale action-selection UI.
                            if (string(_pmenu) == "fight" || string(_pmenu) == "target"){
                                _B.sys_ui.menu = "root";
                                if (is_struct(_B.sys_ui) && variable_struct_exists(_B.sys_ui, "_prev_root_selX") && variable_struct_exists(_B.sys_ui, "_prev_root_selY")){
                                    _B.sys_ui.selX = variable_struct_get(_B.sys_ui, "_prev_root_selX");
                                    _B.sys_ui.selY = variable_struct_get(_B.sys_ui, "_prev_root_selY");
                                } else { _B.sys_ui.selX = 0; _B.sys_ui.selY = 0; }
                            } else {
                                _B.sys_ui.menu = string(_pmenu);
                                if (variable_struct_exists(_B, "_pending_open_party_prev_selX")) _B.sys_ui.selX = variable_struct_get(_B, "_pending_open_party_prev_selX");
                                if (variable_struct_exists(_B, "_pending_open_party_prev_selY")) _B.sys_ui.selY = variable_struct_get(_B, "_pending_open_party_prev_selY");
                            }
                        } else {
                            // Fallback to root
                            _B.sys_ui.menu = "root";
                            if (is_struct(_B.sys_ui) && variable_struct_exists(_B.sys_ui, "_prev_root_selX") && variable_struct_exists(_B.sys_ui, "_prev_root_selY")){
                                _B.sys_ui.selX = variable_struct_get(_B.sys_ui, "_prev_root_selX");
                                _B.sys_ui.selY = variable_struct_get(_B.sys_ui, "_prev_root_selY");
                            } else { _B.sys_ui.selX = 0; _B.sys_ui.selY = 0; }
                        }
                    } catch (e_ui_set) { }
                    try { variable_struct_set(_B, "_command_pending_action", undefined); } catch (e_clear_pending_action_forced) {}
                    try { variable_struct_set(_B, "_target_pick_targets", undefined); } catch (e_clear_target_list_forced) {}
                    try { variable_struct_set(_B, "_target_pick_index", 0); } catch (e_clear_target_index_forced) {}
                    // Defensive: ensure any forced-swap party overlay is fully closed now that the replacement resolved.
                    try {
                        if (!is_undefined(party_is_open) && party_is_open(_switch_party_pid_done) && !is_undefined(party_close)) party_close(_switch_party_pid_done);
                    } catch (e_party_close) {}
                    try {
                        if (!is_undefined(party_set_swap_mode_impl)) party_set_swap_mode_impl(_switch_party_pid_done, false, false);
                        else if (!is_undefined(party_ensure)){
                            var _Pclear = party_ensure(_switch_party_pid_done);
                            if (is_struct(_Pclear)){
                                if (variable_struct_exists(_Pclear, "_battle_swap_mode")) variable_struct_set(_Pclear, "_battle_swap_mode", false);
                                if (variable_struct_exists(_Pclear, "_battle_swap_mode_forced")) variable_struct_set(_Pclear, "_battle_swap_mode_forced", false);
                                if (variable_struct_exists(_Pclear, "_battle_swap_actor_index")) variable_struct_set(_Pclear, "_battle_swap_actor_index", undefined);
                            }
                        }
                    } catch (e_clear_sw) {}
                    try { variable_struct_set(_B, "_pending_open_party", false); } catch (e_clr_pending) {}
                    try { variable_struct_set(_B, "_pending_open_party_next_mon_ref", undefined); } catch (e_clr_next) {}
                    try { variable_struct_set(_B, "_pending_open_party_fainted_actor_index", undefined); } catch (e_clr_fainted_actor) {}
                    // Clear saved UI restore fields now that we've applied them
                    try { variable_struct_set(_B, "_pending_open_party_prev_menu", undefined); variable_struct_set(_B, "_pending_open_party_prev_selX", undefined); variable_struct_set(_B, "_pending_open_party_prev_selY", undefined); } catch (e_clr) {}
                }
                try { variable_struct_set(_B, "_switch_actor_index", undefined); } catch (e_clr_switch_actor) {}
                try { variable_struct_set(_B, "_switch_party_pid", undefined); } catch (e_clr_switch_party_pid) {}
                return;
            } else return;
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

/// Draw the battle GUI using the player's viewport. Call from Draw GUI.
/// Params: _pid (int)
/// Behavior: Computes viewport and calls battle_draw_gui_rect.
function battle_draw_gui(_pid){
    var _rect = __battle_view_rect_for_pid(_pid);
    if (is_array(_rect) && array_length(_rect) >= 4) {
        battle_draw_gui_rect(_pid, _rect[0], _rect[1], _rect[2], _rect[3]);
    }
}

/// Draw the battle GUI into a specific GUI rectangle.
/// Params:
///  - _pid (int)
///  - _rx, _ry, _rw, _rh (int): GUI-space rect to letterbox into the 240x160 logical canvas
/// Behavior: Draws panels, command UI, battlers, overlays, and fade effects.
function battle_draw_gui_rect(_pid, _rx, _ry, _rw, _rh){
    if (!battle_is_open(_pid)) return;
    var _B = __battle_ensure_slot(_pid);
    var _UI = __battle_command_ui_state(_B, _pid);

    var _S  = max(1, min(floor(_rw / 240), floor(_rh / 160)));
    var _OX = _rx + (_rw - 240 * _S) div 2;
    var _OY = _ry + (_rh - 160 * _S) div 2;

    __bui_begin(_pid, _OX, _OY, 240*_S, 160*_S);

    if (variable_global_exists("FNT_POKEMON")) draw_set_font(global.FNT_POKEMON); else draw_set_font(-1);
    draw_set_color(c_white);

    draw_set_color(_B.theme.col_bg);
    draw_rectangle(__bxu(_pid,0), __byu(_pid,0), __bxu(_pid,240), __byu(_pid,160), false);

    __battle_draw_battlers(_pid, _B);
    if (!is_undefined(__battle_weather_particles_draw)) __battle_weather_particles_draw(_pid, _B);
    // (moved) animation-queue overlays are drawn after UI so they appear on top
    // Optional intro sprite animations hook: draw during intro phases
    if (!is_undefined(__battle_intro_draw)){
        var _phname = (variable_struct_exists(_B, "phase") ? string(_B.phase) : "");
        if (_phname == "transition_in" || _phname == "intro_enemy" || _phname == "intro_call" || _phname == "intro_player"){
            __battle_intro_draw(_pid, _B);
        }
    }

    // Draw queued animation states under the UI panels so effect sprites appear beneath UI
    if (!is_undefined(battle_anim_queue_get_states) && !is_undefined(__battle_anim_queue_draw_states)){
        try {
            var __aq_states_under = battle_anim_queue_get_states(_pid);
            __battle_anim_queue_draw_states(_pid, __aq_states_under);
        } catch (e_drawaq_under) {}
    }

    var _draw_enemy_panel = true;
    if (variable_struct_exists(_B, "_battle_mode") && string(variable_struct_get(_B, "_battle_mode")) == "trainer"){
        if (variable_struct_exists(_B, "_trainer_intro") && is_struct(variable_struct_get(_B, "_trainer_intro"))){
            _draw_enemy_panel = false;
        }
    }

    var _is_double = (variable_struct_exists(_B, "battle_format") && string(variable_struct_get(_B, "battle_format")) == "double");
    if (_draw_enemy_panel){
        if (_is_double){
            __battle_enemy_box_rect(_pid, 4, 6, 100, 28, __battle_get_side_actor(_pid, 1, 0), "F1", true);
            __battle_enemy_box_rect(_pid, 4, 36, 100, 28, __battle_get_side_actor(_pid, 1, 1), "F2", true);
        } else {
            __battle_enemy_box_rect(_pid, 16,16,112,40, __battle_get_side_actor(_pid, 1, 0), "", false);
        }
    }
    if (_is_double){
        var _ally_label = "P2";
        var _ally_actor = __battle_get_side_actor(_pid, 0, 1);
        if (is_struct(_ally_actor)){
            var _ally_owner = __battle_actor_owner_pid(_pid, 1);
            if (is_real(_ally_owner)) _ally_label = "P" + string(_ally_owner + 1);
        }
        __battle_player_box_rect(_pid, 140, 78, 100, 28, __battle_get_side_actor(_pid, 0, 1), _ally_label, true);
        __battle_player_box_rect(_pid, 140, 108, 100, 28, __battle_get_side_actor(_pid, 0, 0), "P1", true);
    } else {
        __battle_player_box_rect(_pid,112,104,128,48, __battle_get_side_actor(_pid, 0, 0), "", false);
    }
    __battle_cmd_box_rect(_pid,   8,136,224,24,   variable_struct_get(_UI, "selX"), variable_struct_get(_UI, "selY"));
    if (!is_undefined(__battle_draw_levelup_panel)) __battle_draw_levelup_panel(_pid);

    // Draw any active battle animations (status icons, damage popups)
    if (!is_undefined(__battle_anim_draw)) __battle_anim_draw(_pid);
    __battle_draw_transform_flash(_pid, _B);
    

    if (string(_B.phase) == "transition_in"){
        var p = (variable_struct_exists(_B,"phase_progress") ? _B.phase_progress : 0);
        var _tr_style = (variable_struct_exists(_B, "transition_style")) ? string(variable_struct_get(_B, "transition_style")) : "emerald_fade_black";
        if (!is_undefined(transition_draw_battle_cover)){
            transition_draw_battle_cover(_tr_style, p, __bxu(_pid, 0), __byu(_pid, 0), 240 * _S, 160 * _S);
        } else {
            var alpha = 1 - max(0, min(1, p));
            draw_set_color(c_black);
            draw_set_alpha(alpha);
            draw_rectangle(__bxu(_pid,0), __byu(_pid,0), __bxu(_pid,240), __byu(_pid,160), false);
            draw_set_alpha(1);
        }
    }

    // Draw any overlays that should appear above the UI (pok�ball during catch animation)
    if (!is_undefined(__battle_draw_ball_overlay)) __battle_draw_ball_overlay(_pid, _B);

    if (!is_undefined(battle_cam_get_draw_state)){
        var _cam_d = battle_cam_get_draw_state(_pid);
        if (is_struct(_cam_d)){
            var _cam_alpha = 0;
            if (variable_struct_exists(_cam_d, "fade_alpha") && is_real(_cam_d.fade_alpha)) _cam_alpha = clamp(_cam_d.fade_alpha, 0, 1);
            if (_cam_alpha > 0){
                var _cam_col = c_black;
                if (variable_struct_exists(_cam_d, "fade_color") && is_real(_cam_d.fade_color)) _cam_col = _cam_d.fade_color;
                draw_set_color(_cam_col);
                draw_set_alpha(_cam_alpha);
                draw_rectangle(__bxu(_pid,0), __byu(_pid,0), __bxu(_pid,240), __byu(_pid,160), false);
                draw_set_alpha(1);
                draw_set_color(c_white);
            }
        }
    }

    // Battle close overlay. Losses whiteout; other endings use the normal black fade.
    if (variable_struct_exists(_B, "_closing") && variable_struct_get(_B, "_closing")){
        var start_ms = current_time;
        if (variable_struct_exists(_B, "_close_start_ms")){
            var __tmp_s = variable_struct_get(_B, "_close_start_ms");
            if (is_real(__tmp_s)) start_ms = __tmp_s;
        }
        var dur_ms = 600;
        if (variable_struct_exists(_B, "_close_dur_ms")){
            var __tmp_d = variable_struct_get(_B, "_close_dur_ms");
            if (is_real(__tmp_d)) dur_ms = __tmp_d;
        }
        var tnow     = current_time;
        var prog     = clamp((tnow - start_ms) / max(1, dur_ms), 0, 1);
        var _close_style = __battle_close_transition_style(_B);
        if (!is_undefined(transition_draw_cover_rect)){
            transition_draw_cover_rect(_close_style, prog, __bxu(_pid,0), __byu(_pid,0), __bxu(_pid,240) - __bxu(_pid,0), __byu(_pid,160) - __byu(_pid,0));
        } else {
            draw_set_color((_close_style == "emerald_fade_white") ? c_white : c_black);
            draw_set_alpha(prog);
            draw_rectangle(__bxu(_pid,0), __byu(_pid,0), __bxu(_pid,240), __byu(_pid,160), false);
            draw_set_alpha(1);
        }
    }

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
/// Process player input on the command UI and enqueue selected actions.
/// Params: _pid (int)
/// Behavior: Reads controls via scr_controls API; updates _B.sys_ui and turn intents.
function __battle_process_input(_pid){
    var _B = __battle_ensure_slot(_pid);
    var _UI = __battle_command_ui_state(_B, _pid);
    // If the Bag or Party UI is open for this player, block battle input
    if ((is_undefined(bag_is_open) ? false : bag_is_open(_pid) || (!is_undefined(pc_is_open) && pc_is_open(_pid)))) return;
    if ((is_undefined(party_is_open) ? false : party_is_open(_pid) || (!is_undefined(pc_is_open) && pc_is_open(_pid)))) return;
    if (string(_B.phase) != "command") return;

    try {
        if (variable_struct_exists(_B, "_intro_completed") && !variable_struct_get(_B, "_intro_completed")) return;
        if (variable_struct_exists(_B, "_suppress_wait_for_dialog_close") && variable_struct_get(_B, "_suppress_wait_for_dialog_close")) return;
        if (variable_struct_exists(_B, "_action_active") && variable_struct_get(_B, "_action_active")) return;
        if (variable_struct_exists(_B, "_closing") && variable_struct_get(_B, "_closing")) return;
        if (variable_struct_exists(_B, "_suppress_sys_ui_until")){
            var _input_suppress_until = variable_struct_get(_B, "_suppress_sys_ui_until");
            if (is_real(_input_suppress_until) && current_time < _input_suppress_until) return;
            if (is_real(_input_suppress_until) && current_time >= _input_suppress_until) variable_struct_set(_B, "_suppress_sys_ui_until", undefined);
        }
    } catch (e_cmd_hidden_guard) {}
    if (__battle_has_forced_switch_lock(_pid)) return;

    // Defensive: ensure sys_ui exists and is a struct before processing input
    if (!is_struct(_UI)) return;

    // Ensure core UI fields exist to avoid undefined access during forced swaps
    if (!variable_struct_exists(_UI, "selX") || !is_real(variable_struct_get(_UI, "selX"))) variable_struct_set(_UI, "selX", 0);
    if (!variable_struct_exists(_UI, "selY") || !is_real(variable_struct_get(_UI, "selY"))) variable_struct_set(_UI, "selY", 0);
    if (!variable_struct_exists(_UI, "menu") || string_length(string(variable_struct_get(_UI, "menu"))) == 0) variable_struct_set(_UI, "menu", "root");

    var _is_double = (variable_struct_exists(_B, "battle_format") && string(variable_struct_get(_B, "battle_format")) == "double");
    var _versus = (variable_struct_exists(_B, "versus_enabled") && variable_struct_get(_B, "versus_enabled") == true);
    var _split_command_ui = __battle_uses_split_command_ui(_B);
    var _command_mode = (_is_double || _versus);
    if (_command_mode){
        if (!variable_struct_exists(_B, "_player_turn_actions") || !is_array(variable_struct_get(_B, "_player_turn_actions"))) variable_struct_set(_B, "_player_turn_actions", []);
        if (_split_command_ui){
            if (!variable_struct_exists(_UI, "command_actor_index") || !is_real(variable_struct_get(_UI, "command_actor_index"))){
                variable_struct_set(_UI, "command_actor_index", 0);
            }
        } else if (!variable_struct_exists(_B, "_command_actor_index") || !is_real(variable_struct_get(_B, "_command_actor_index"))){
            var _first_actor = __battle_next_command_actor_index(_pid, -1);
            variable_struct_set(_B, "_command_actor_index", (_first_actor >= 0) ? _first_actor : 0);
        }
        var _cur_actor_for_pid = _split_command_ui ? floor(variable_struct_get(_UI, "command_actor_index")) : floor(variable_struct_get(_B, "_command_actor_index"));
        var _cur_owner_for_pid = __battle_actor_control_pid(_pid, _cur_actor_for_pid);
        var _cur_ready_for_pid = is_struct(__battle_find_player_turn_action(_B, _cur_actor_for_pid));
        if (is_real(_cur_owner_for_pid) && _cur_owner_for_pid != _pid && !_cur_ready_for_pid) return;
        if (!is_real(_cur_owner_for_pid) || _cur_ready_for_pid){
            var _next_for_pid = __battle_next_command_actor_index(_pid, -1);
            if (_next_for_pid < 0) return;
            if (_split_command_ui) variable_struct_set(_UI, "command_actor_index", _next_for_pid);
            else variable_struct_set(_B, "_command_actor_index", _next_for_pid);
            variable_struct_set(_UI, "menu", "root");
            variable_struct_set(_UI, "selX", 0);
            variable_struct_set(_UI, "selY", 0);
        }
    }

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

    if (is_struct(_B) && variable_struct_exists(_B, "_trainer_switch_prompt")){
        var _tprompt = variable_struct_get(_B, "_trainer_switch_prompt");
        if (is_struct(_tprompt) && variable_struct_exists(_tprompt, "active") && _tprompt.active){
            var _tphase = (variable_struct_exists(_tprompt, "phase") ? string(variable_struct_get(_tprompt, "phase")) : "prompt");
            if (_tphase == "prompt"){
                if (_u || _d){
                    var _sel_prompt = (variable_struct_exists(_tprompt, "sel") && is_real(variable_struct_get(_tprompt, "sel"))) ? floor(variable_struct_get(_tprompt, "sel")) : 1;
                    _sel_prompt = 1 - clamp(_sel_prompt, 0, 1);
                    variable_struct_set(_tprompt, "sel", _sel_prompt);
                    variable_struct_set(_B, "_trainer_switch_prompt", _tprompt);
                    if (!is_undefined(ui_play_select_sound)) ui_play_select_sound();
                }
                if (_b){
                    variable_struct_set(_tprompt, "player_choice", "no");
                    variable_struct_set(_tprompt, "player_switch_idx", -1);
                    variable_struct_set(_tprompt, "phase", "queue_enemy_send");
                    variable_struct_set(_B, "_trainer_switch_prompt", _tprompt);
                } else if (_a){
                    var _sel_confirm = (variable_struct_exists(_tprompt, "sel") && is_real(variable_struct_get(_tprompt, "sel"))) ? floor(variable_struct_get(_tprompt, "sel")) : 1;
                    if (_sel_confirm == 0){
                        variable_struct_set(_tprompt, "player_choice", "yes");
                        variable_struct_set(_tprompt, "player_switch_idx", -1);
                        variable_struct_set(_tprompt, "phase", "await_party");
                        variable_struct_set(_B, "_trainer_switch_prompt", _tprompt);
                        if (!__battle_trainer_open_switch_party(_pid)){
                            variable_struct_set(_tprompt, "player_choice", "no");
                            variable_struct_set(_tprompt, "phase", "queue_enemy_send");
                            variable_struct_set(_B, "_trainer_switch_prompt", _tprompt);
                        }
                    } else {
                        variable_struct_set(_tprompt, "player_choice", "no");
                        variable_struct_set(_tprompt, "player_switch_idx", -1);
                        variable_struct_set(_tprompt, "phase", "queue_enemy_send");
                        variable_struct_set(_B, "_trainer_switch_prompt", _tprompt);
                    }
                }
            }
            return;
        }
    }

    var _trainer_send_pending = (variable_struct_exists(_B, "_trainer_pending_send") && is_struct(variable_struct_get(_B, "_trainer_pending_send")));
    var _trainer_switch_anim_active = (variable_struct_exists(_B, "_trainer_switch") && is_struct(variable_struct_get(_B, "_trainer_switch")));
    if (_trainer_send_pending || _trainer_switch_anim_active){
        try { variable_struct_set(_B, "_command_pending_action", undefined); } catch (e_cmd_pending_trainer) {}
        try { variable_struct_set(_B, "_target_pick_targets", undefined); } catch (e_target_pending_trainer) {}
        try { variable_struct_set(_B, "_target_pick_index", 0); } catch (e_target_idx_trainer) {}
        try {
            variable_struct_set(_UI, "command_pending_action", undefined);
            variable_struct_set(_UI, "target_pick_targets", undefined);
            variable_struct_set(_UI, "target_pick_index", 0);
            variable_struct_set(_UI, "menu", "root");
            variable_struct_set(_UI, "selX", 0);
            variable_struct_set(_UI, "selY", 0);
        } catch (e_sys_ui_trainer) {}
        return;
    }

    var menu = string(variable_struct_get(_UI, "menu"));
    var _nav_old_selx = variable_struct_get(_UI, "selX");
    var _nav_old_sely = variable_struct_get(_UI, "selY");
    var _nav_old_target_idx = (menu == "target") ? (_split_command_ui ? variable_struct_get(_UI, "target_pick_index") : __battle_target_pick_index(_B)) : -1;
    var _command_actor_index = 0;
    if (_command_mode){
        if (_split_command_ui) _command_actor_index = floor(variable_struct_get(_UI, "command_actor_index"));
        else if (variable_struct_exists(_B, "_command_actor_index") && is_real(variable_struct_get(_B, "_command_actor_index"))) _command_actor_index = floor(variable_struct_get(_B, "_command_actor_index"));
    }

    if (menu == "target"){
        var _targets_nav = _split_command_ui ? variable_struct_get(_UI, "target_pick_targets") : (variable_struct_exists(_B, "_target_pick_targets") ? variable_struct_get(_B, "_target_pick_targets") : undefined);
        if (is_array(_targets_nav) && array_length(_targets_nav) > 0){
            var _pick_idx = min(array_length(_targets_nav) - 1, (_split_command_ui ? variable_struct_get(_UI, "target_pick_index") : __battle_target_pick_index(_B)));
            if (_l || _u) _pick_idx = (_pick_idx - 1 + array_length(_targets_nav)) mod array_length(_targets_nav);
            if (_r || _d) _pick_idx = (_pick_idx + 1) mod array_length(_targets_nav);
            if (_split_command_ui) variable_struct_set(_UI, "target_pick_index", _pick_idx);
            else variable_struct_set(_B, "_target_pick_index", _pick_idx);
            variable_struct_set(_UI, "selX", _pick_idx mod 2);
            variable_struct_set(_UI, "selY", _pick_idx div 2);
        }
    } else {
        if (_l) variable_struct_set(_UI, "selX", max(0, variable_struct_get(_UI, "selX") - 1));
        if (_r) variable_struct_set(_UI, "selX", min(1, variable_struct_get(_UI, "selX") + 1));
        if (_u) variable_struct_set(_UI, "selY", max(0, variable_struct_get(_UI, "selY") - 1));
        if (_d) variable_struct_set(_UI, "selY", min(1, variable_struct_get(_UI, "selY") + 1));
    }

    var idx = (menu == "target") ? (_split_command_ui ? variable_struct_get(_UI, "target_pick_index") : __battle_target_pick_index(_B)) : (max(0, variable_struct_get(_UI, "selX")) + max(0, variable_struct_get(_UI, "selY")) * 2);
    var _nav_new_target_idx = (menu == "target") ? (_split_command_ui ? variable_struct_get(_UI, "target_pick_index") : __battle_target_pick_index(_B)) : -1;
    if ((_nav_old_selx != variable_struct_get(_UI, "selX") || _nav_old_sely != variable_struct_get(_UI, "selY") || _nav_old_target_idx != _nav_new_target_idx) && !is_undefined(ui_play_select_sound)) ui_play_select_sound();

    if (_b){
        if (menu == "fight"){
            if (_command_mode){
                var _prev_actor = __battle_previous_command_actor_index(_pid, _command_actor_index);
                if (_prev_actor >= 0){
                    __battle_remove_player_turn_action(_B, _prev_actor);
                    if (_split_command_ui) variable_struct_set(_UI, "command_actor_index", _prev_actor);
                    else variable_struct_set(_B, "_command_actor_index", _prev_actor);
                    variable_struct_set(_UI, "menu", "fight");
                    variable_struct_set(_UI, "selX", 0);
                    variable_struct_set(_UI, "selY", 0);
                } else {
                    variable_struct_set(_UI, "menu", "root");
                    if (variable_struct_exists(_UI, "_prev_root_selX") && variable_struct_exists(_UI, "_prev_root_selY")){
                        variable_struct_set(_UI, "selX", variable_struct_get(_UI, "_prev_root_selX"));
                        variable_struct_set(_UI, "selY", variable_struct_get(_UI, "_prev_root_selY"));
                    } else {
                        variable_struct_set(_UI, "selX", 0); variable_struct_set(_UI, "selY", 0);
                    }
                }
            } else {
                // Return to root menu and restore previous root selection if available
                variable_struct_set(_UI, "menu", "root");
                if (variable_struct_exists(_UI, "_prev_root_selX") && variable_struct_exists(_UI, "_prev_root_selY")){
                    variable_struct_set(_UI, "selX", variable_struct_get(_UI, "_prev_root_selX"));
                    variable_struct_set(_UI, "selY", variable_struct_get(_UI, "_prev_root_selY"));
                } else {
                    variable_struct_set(_UI, "selX", 0); variable_struct_set(_UI, "selY", 0);
                }
            }
        } else if (menu == "target"){
            var _pending = _split_command_ui ? variable_struct_get(_UI, "command_pending_action") : (variable_struct_exists(_B, "_command_pending_action") ? variable_struct_get(_B, "_command_pending_action") : undefined);
            var _return_to_bag = false;
            if (is_struct(_pending) && variable_struct_exists(_pending, "item_use") && variable_struct_get(_pending, "item_use") == true && variable_struct_exists(_pending, "bag_return_state")){
                var _bag_state = variable_struct_get(_pending, "bag_return_state");
                if (is_struct(_bag_state) && !is_undefined(bag_open_for_battle) && !is_undefined(bag_inventory_ensure)){
                    bag_open_for_battle(_pid);
                    var _bag = bag_inventory_ensure(_pid);
                    if (is_struct(_bag)){
                        if (variable_struct_exists(_bag_state, "page") && is_real(variable_struct_get(_bag_state, "page"))) variable_struct_set(_bag, "page", floor(variable_struct_get(_bag_state, "page")));
                        if (variable_struct_exists(_bag_state, "sel") && is_real(variable_struct_get(_bag_state, "sel"))) variable_struct_set(_bag, "sel", floor(variable_struct_get(_bag_state, "sel")));
                        if (variable_struct_exists(_bag_state, "scroll") && is_real(variable_struct_get(_bag_state, "scroll"))) variable_struct_set(_bag, "scroll", floor(variable_struct_get(_bag_state, "scroll")));
                        if (variable_struct_exists(_bag_state, "item_menu_row") && is_real(variable_struct_get(_bag_state, "item_menu_row"))) variable_struct_set(_bag, "item_menu_row", floor(variable_struct_get(_bag_state, "item_menu_row")));
                        variable_struct_set(_bag, "item_menu_open", true);
                        variable_struct_set(_bag, "item_menu_sel", 0);
                        variable_struct_set(_bag, "lock", 6);
                    }
                    _return_to_bag = true;
                }
            }
            variable_struct_set(_UI, "menu", (_return_to_bag ? "root" : "fight"));
            if (_split_command_ui){
                variable_struct_set(_UI, "target_pick_targets", undefined);
                variable_struct_set(_UI, "command_pending_action", undefined);
                variable_struct_set(_UI, "target_pick_index", 0);
            } else {
                variable_struct_set(_B, "_target_pick_targets", undefined);
                variable_struct_set(_B, "_command_pending_action", undefined);
                variable_struct_set(_B, "_target_pick_index", 0);
            }
            if (!_return_to_bag && is_struct(_pending) && variable_struct_exists(_pending, "slot") && is_real(variable_struct_get(_pending, "slot"))){
                var _slot_prev = floor(variable_struct_get(_pending, "slot"));
                variable_struct_set(_UI, "selX", _slot_prev mod 2);
                variable_struct_set(_UI, "selY", _slot_prev div 2);
            }
        }
    }

    if (menu == "fight"){
        var _burst_pressed = false;
        try {
            if (!is_undefined(controls_pressed)) _burst_pressed = controls_pressed(_pid, "PageDown");
            else _burst_pressed = keyboard_check_pressed(ord("S"));
        } catch (e_burst_input) { _burst_pressed = false; }
        try {
            if (!_burst_pressed){
                var _burst_pad = floor(_pid);
                if (variable_global_exists("CTRL") && is_struct(CTRL) && variable_struct_exists(CTRL, "pad_index") && is_array(CTRL.pad_index) && _pid >= 0 && _pid < array_length(CTRL.pad_index)){
                    _burst_pad = CTRL.pad_index[_pid];
                }
                if (is_real(_burst_pad) && _burst_pad >= 0 && gamepad_is_connected(_burst_pad) && gamepad_button_check_pressed(_burst_pad, gp_shoulderr)) _burst_pressed = true;
            }
        } catch (e_burst_pad) {}
        try {
            if (!_burst_pressed && is_undefined(controls_pressed)) _burst_pressed = keyboard_check_pressed(ord("E"));
        } catch (e_burst_key_e) {}
        if (_burst_pressed){
            var _burst_mode = __battle_transform_cycle_selected(_pid, _command_actor_index);
            if (string_length(_burst_mode) > 0){
                try { dialog2p_show_now(_pid, __battle_transform_mode_label(_burst_mode) + " is ready!"); } catch(e_burst_msg) {}
            } else {
                try { dialog2p_show_now(_pid, "No burst transformation is ready."); } catch(e_burst_none) {}
            }
            exit;
        }
    }

    if (_a){
        if (menu == "root"){
            // Save the current root selection so we can restore it when returning
            variable_struct_set(_UI, "_prev_root_selX", variable_struct_get(_UI, "selX"));
            variable_struct_set(_UI, "_prev_root_selY", variable_struct_get(_UI, "selY"));
            if (idx == 0){
                // Enter Fight submenu
                variable_struct_set(_UI, "menu", "fight");
                variable_struct_set(_UI, "selX", 0); variable_struct_set(_UI, "selY", 0);
            }
            else if (idx == 1){
                // Open the bag UI for battle if available
                if (!is_undefined(bag_open_for_battle)) bag_open_for_battle(_pid);
                else try { dialog2p_show_now(_pid, "You checked your bag.\n(TODO: bag in battle)"); } catch(e_sb) { try { dialog2p_enqueue(_pid, "You checked your bag.\n(TODO: bag in battle)"); } catch(e_){} }
            }
            else if (idx == 2){
                // Open the party UI in battle context so the player can choose a Pok�mon to swap in.
                if (is_undefined(party_open) || is_undefined(party_ensure)){
                    try { dialog2p_show_now(_pid, "You checked your party.\n(TODO: switch Pok\u00e9mon)"); } catch(e_sp) { try { dialog2p_enqueue(_pid, "You checked your party.\n(TODO: switch Pok\u00e9mon)"); } catch(e_){} }
                } else {
                    party_open(_pid);
                    var _Ptmp = party_ensure(_pid);
                    try {
                        try {
                            if (!is_undefined(party_set_swap_mode_impl)) party_set_swap_mode_impl(_pid, true, false);
                            else if (is_struct(_Ptmp)) variable_struct_set(_Ptmp, "_battle_swap_mode", true);
                        } catch (e_h2) { if (is_struct(_Ptmp)) try { variable_struct_set(_Ptmp, "_battle_swap_mode", true); } catch (e2) {} }
                        if (is_struct(_Ptmp)) variable_struct_set(_Ptmp, "_battle_swap_actor_index", _command_actor_index);
                        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){
                            show_debug_message("[battle_system] menu_switch -> pid=" + string(_pid) + ", set _battle_swap_mode=true");
                        }
                    } catch (e_bt) {}
                }
            }
            else if (idx == 3){
                __battle_try_escape(_pid);
            }
        }
        else if (menu == "fight"){
            var move_idx = idx;
            var A = _B.actor[_command_actor_index];
            var moves_arr = [];
            if (is_struct(A) && variable_struct_exists(A, "moves") && is_array(variable_struct_get(A, "moves"))){
                moves_arr = variable_struct_get(A, "moves");
            }
            var mv = -1;
            if (is_array(moves_arr) && move_idx >= 0 && move_idx < array_length(moves_arr)) mv = moves_arr[move_idx];
            var pps_arr = [];
            if (is_struct(A) && variable_struct_exists(A, "pps") && is_array(variable_struct_get(A, "pps"))) pps_arr = variable_struct_get(A, "pps");
            var pp = 0;
            if (is_array(pps_arr) && move_idx >= 0 && move_idx < array_length(pps_arr)) pp = pps_arr[move_idx];
            if (!is_real(pp)) pp = 0;

            // Debug: log chosen move vs actor's stored move for this slot
            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){
                var __moves_arr = (is_struct(A) && variable_struct_exists(A, "moves")) ? variable_struct_get(A, "moves") : [];
                var act_mv = (is_array(__moves_arr) && is_real(move_idx) && move_idx >= 0 && move_idx < array_length(__moves_arr)) ? __moves_arr[move_idx] : undefined;
                var __mv_name = "";
                try { __mv_name = (is_undefined(move_get_name) ? __battle_move_name_impl(mv) : move_get_name(mv)); } catch (e_mn) { __mv_name = (is_undefined(__battle_move_name_impl) ? string(mv) : __battle_move_name_impl(mv)); }
                show_debug_message("[battle_select][fight] pid=" + string(_pid) + ", slot=" + string(move_idx) + ", mv_selected=" + string(mv) + " (" + string(__mv_name) + "), actor.moves[slot]=" + string(act_mv));
            }

            if (!is_real(mv) || mv < 0){
                try { dialog2p_show_now(_pid, "No move registered there.\n(Try another slot.)"); } catch(e_nm) { try { dialog2p_enqueue(_pid, "No move registered there.\n(Try another slot.)"); } catch(e_){} }
            } else if (pp <= 0){
                if (!__battle_actor_has_usable_pp(A)){
                    var _struggle_action = __battle_make_struggle_action(_pid, _command_actor_index);
                    __battle_commit_player_action(_pid, _struggle_action);
                } else {
                    try { dialog2p_show_now(_pid, "There's no PP left for that move!"); } catch(e_pp) { try { dialog2p_enqueue(_pid, "There's no PP left for that move!"); } catch(e_){} }
                }
            } else {
                var _choice_blocked = false;
                try {
                    if (!is_undefined(item_runtime_actor_held_actions)){
                        var _choice_actions = item_runtime_actor_held_actions(A, "move_select");
                        var _has_choice_lock = false;
                        for (var _cai = 0; _cai < array_length(_choice_actions); ++_cai){
                            var _cact = _choice_actions[_cai];
                            if (!is_struct(_cact)) continue;
                            var _ckind = variable_struct_exists(_cact, "kind") ? string_lower(string(variable_struct_get(_cact, "kind"))) : "";
                            if (_ckind == "lock_first_move"){ _has_choice_lock = true; break; }
                        }
                        if (_has_choice_lock){
                            var _locked_mv = (variable_struct_exists(A, "_choice_locked_move_id") && is_real(variable_struct_get(A, "_choice_locked_move_id"))) ? floor(variable_struct_get(A, "_choice_locked_move_id")) : -1;
                            if (_locked_mv >= 0 && _locked_mv != mv){
                                _choice_blocked = true;
                                try { dialog2p_show_now(_pid, __battle_dialog_actor_name(A, "The Pokemon") + " can only use " + __battle_move_name(_locked_mv) + "!"); } catch(e_choice_msg) { try { dialog2p_enqueue(_pid, __battle_dialog_actor_name(A, "The Pokemon") + " can only use " + string(_locked_mv) + "!"); } catch(e_){} }
                            }
                        }
                    }
                } catch (e_choice_select) { _choice_blocked = false; }
                if (_choice_blocked) exit;
                var _action = { slot: move_idx, move_id: mv, actor_index: _command_actor_index, target_index: __battle_get_default_target_index(_pid, _command_actor_index) };
                var _selected_transform_mode = __battle_transform_selected_mode(_B, _command_actor_index);
                if (string_length(_selected_transform_mode) > 0){
                    variable_struct_set(_action, "transform_mode", _selected_transform_mode);
                    variable_struct_set(_B, "_transform_mode_" + string(_command_actor_index), "");
                }
                var _targets = __battle_target_candidates(_pid, _command_actor_index, mv);
                if (is_array(_targets) && array_length(_targets) > 1){
                    _targets = __battle_sort_target_candidates(_pid, _command_actor_index, _targets);
                    if (_split_command_ui){
                        variable_struct_set(_UI, "command_pending_action", _action);
                        variable_struct_set(_UI, "target_pick_targets", _targets);
                        variable_struct_set(_UI, "menu", "target");
                    } else {
                        variable_struct_set(_B, "_command_pending_action", _action);
                        variable_struct_set(_B, "_target_pick_targets", _targets);
                        _B.sys_ui.menu = "target";
                    }
                    var _default_target = __battle_get_default_target_index(_pid, _command_actor_index);
                    var _sel_idx = __battle_target_candidate_select_index(_targets, _default_target);
                    if (_split_command_ui) variable_struct_set(_UI, "target_pick_index", _sel_idx);
                    else variable_struct_set(_B, "_target_pick_index", _sel_idx);
                    variable_struct_set(_UI, "selX", _sel_idx mod 2);
                    variable_struct_set(_UI, "selY", _sel_idx div 2);
                } else {
                    if (is_array(_targets) && array_length(_targets) > 0) variable_struct_set(_action, "target_index", _targets[0]);
                    __battle_commit_player_action(_pid, _action);
                }
            }
        }
        else if (menu == "target"){
            var _targets_commit = _split_command_ui ? variable_struct_get(_UI, "target_pick_targets") : (variable_struct_exists(_B, "_target_pick_targets") ? variable_struct_get(_B, "_target_pick_targets") : undefined);
            var _pending_commit = _split_command_ui ? variable_struct_get(_UI, "command_pending_action") : (variable_struct_exists(_B, "_command_pending_action") ? variable_struct_get(_B, "_command_pending_action") : undefined);
            if (is_array(_targets_commit) && is_struct(_pending_commit) && idx >= 0 && idx < array_length(_targets_commit)){
                variable_struct_set(_pending_commit, "target_index", _targets_commit[idx]);
                __battle_commit_player_action(_pid, _pending_commit);
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
    var _versus = (variable_struct_exists(_B, "versus_enabled") && variable_struct_get(_B, "versus_enabled") == true);

    var _format = (variable_struct_exists(_B, "battle_format") ? string(variable_struct_get(_B, "battle_format")) : "single");
    if (_format == "double"){
        var _queued_players = (variable_struct_exists(_B, "_player_turn_actions") && is_array(variable_struct_get(_B, "_player_turn_actions"))) ? variable_struct_get(_B, "_player_turn_actions") : [];
        for (var _pi = 0; _pi < array_length(_queued_players); ++_pi){
            var _pact = _queued_players[_pi];
            if (!is_struct(_pact)) continue;
            actions = __battle_append_ordered_action(_pid, actions, _pact);
        }
        for (var _enemy_ai_idx = 2; _enemy_ai_idx <= 3; ++_enemy_ai_idx){
            if (!__battle_actor_index_alive(_pid, _enemy_ai_idx)) continue;
            var _enemy_owner = __battle_actor_control_pid(_pid, _enemy_ai_idx);
            if (_versus && is_real(_enemy_owner) && floor(_enemy_owner) >= 0) continue;
            actions = __battle_append_ordered_action(_pid, actions, __battle_choose_action_for_actor(_pid, _enemy_ai_idx, true));
        }

        try {
            if (is_array(actions)){
                for (var _di = 0; _di < array_length(actions); ++_di){
                    var _dact = actions[_di];
                    if (is_struct(_dact) && (!variable_struct_exists(_dact, "target_index") || !is_real(variable_struct_get(_dact, "target_index")))) variable_struct_set(_dact, "target_index", __battle_get_default_target_index(_pid, variable_struct_get(_dact, "actor_index")));
                }
            }
        } catch (e_double_targets) {}
    } else if (_versus) {
        var _queued_vs = (variable_struct_exists(_B, "_player_turn_actions") && is_array(variable_struct_get(_B, "_player_turn_actions"))) ? variable_struct_get(_B, "_player_turn_actions") : [];
        for (var _vsi = 0; _vsi < array_length(_queued_vs); ++_vsi){
            var _vsact = _queued_vs[_vsi];
            if (!is_struct(_vsact)) continue;
            if (!variable_struct_exists(_vsact, "actor_index") || !is_real(variable_struct_get(_vsact, "actor_index"))) continue;
            if (!variable_struct_exists(_vsact, "target_index") || !is_real(variable_struct_get(_vsact, "target_index"))) variable_struct_set(_vsact, "target_index", __battle_get_default_target_index(_pid, variable_struct_get(_vsact, "actor_index")));
            actions = __battle_append_ordered_action(_pid, actions, _vsact);
        }
    } else {

    // If an enemy action wasn't preselected (some input paths may not set it), pick one now so
    // the CPU doesn't become inert when the player mis-presses unavailable options.
    if (!is_struct(actE)){
        actE = __battle_enemy_choose_action(_pid);
        // store back so subsequent logic or UI can inspect it if needed
        _B.turn_action_enemy = actE;
    }

    // Default targets: single-target to the opposite side
    if (is_struct(actP)){
        variable_struct_set(actP, "actor_index", 0);
        if (!variable_struct_exists(actP, "target_index") || !is_real(variable_struct_get(actP, "target_index"))) variable_struct_set(actP, "target_index", 1);
    }
    if (is_struct(actE)){
        variable_struct_set(actE, "actor_index", 1);
        if (!variable_struct_exists(actE, "target_index") || !is_real(variable_struct_get(actE, "target_index"))) variable_struct_set(actE, "target_index", 0);
    }

    // Determine order by move priority first, then Speed (tie-break: random)
    var spP = __battle_stat_get(_B.actor[0], "spd");
    var spE = __battle_stat_get(_B.actor[1], "spd");
    var firstEnemy = false;
    // Compute effective priority for each action (default 0). If an action isn't a move
    // (item use, undefined), it keeps priority 0. Higher priority acts first.
    var prP = 0; var prE = 0;
    try {
        if (is_struct(actP) && variable_struct_exists(actP, "move_id") && is_real(variable_struct_get(actP, "move_id"))){
            prP = __battle_action_effective_priority(_B.actor[0], actP);
        }
    } catch (e_prp) { prP = 0; }
    try {
        if (is_struct(actE) && variable_struct_exists(actE, "move_id") && is_real(variable_struct_get(actE, "move_id"))){
            prE = __battle_action_effective_priority(_B.actor[1], actE);
        }
    } catch (e_pre) { prE = 0; }

    if (prP > prE) firstEnemy = false;
    else if (prP < prE) firstEnemy = true;
    else {
        // Same priority: fall back to Speed (tie-break random when equal)
        firstEnemy = (spE > spP) || (spE == spP && choose(true,false));
    }

    // If the player's action is an item_use (Pok� Ball), force the player to act first
    // so the catch animation can run before the enemy acts. This allows the animation
    // to resolve (caught/escape) before enemy actions proceed.
    if (is_struct(actP) && variable_struct_exists(actP, "item_use") && variable_struct_get(actP, "item_use") == true){
        firstEnemy = false;
    }

    // Pursuit: if one battler is using Pursuit while the other is taking a queued switch action,
    // let Pursuit resolve first and mark it for its doubled switch damage.
    try {
        var _player_switching = (is_struct(actP) && variable_struct_exists(actP, "switch_to") && is_real(variable_struct_get(actP, "switch_to")));
        var _enemy_switching = (is_struct(actE) && variable_struct_exists(actE, "switch_to") && is_real(variable_struct_get(actE, "switch_to")));
        var _player_pursuit = (is_struct(actP) && variable_struct_exists(actP, "move_id") && is_real(variable_struct_get(actP, "move_id")) && variable_struct_get(actP, "move_id") == 228);
        var _enemy_pursuit = (is_struct(actE) && variable_struct_exists(actE, "move_id") && is_real(variable_struct_get(actE, "move_id")) && variable_struct_get(actE, "move_id") == 228);
        if (_player_pursuit && _enemy_switching){
            variable_struct_set(actP, "pursuit_switching", true);
            firstEnemy = false;
        }
        if (_enemy_pursuit && _player_switching){
            variable_struct_set(actE, "pursuit_switching", true);
            firstEnemy = true;
        }
    } catch (e_pursuit_order) {}

    if (is_struct(actP) && is_struct(actE)){
        if (firstEnemy){ actions[0] = actE; actions[1] = actP; }
        else           { actions[0] = actP; actions[1] = actE; }
    } else if (is_struct(actP)){
        actions[0] = actP;
    } else if (is_struct(actE)){
        actions[0] = actE;
    }
    }

    try {
        if (is_array(_B.actor)){
            for (var _mla = 0; _mla < array_length(_B.actor); ++_mla){
                if (is_struct(_B.actor[_mla])) variable_struct_set(_B.actor[_mla], "_will_move_last_this_turn", false);
            }
        }
        if (is_array(actions) && array_length(actions) > 0){
            var _last_move_actor_idx = -1;
            var _move_action_count = 0;
            for (var _mli = array_length(actions) - 1; _mli >= 0; --_mli){
                var _mlact = actions[_mli];
                if (!is_struct(_mlact) || !variable_struct_exists(_mlact, "move_id") || !is_real(variable_struct_get(_mlact, "move_id"))) continue;
                _move_action_count += 1;
                if (_last_move_actor_idx < 0 && variable_struct_exists(_mlact, "actor_index") && is_real(variable_struct_get(_mlact, "actor_index"))) _last_move_actor_idx = floor(variable_struct_get(_mlact, "actor_index"));
            }
            if (_move_action_count >= 2 && _last_move_actor_idx >= 0 && _last_move_actor_idx < array_length(_B.actor) && is_struct(_B.actor[_last_move_actor_idx])){
                variable_struct_set(_B.actor[_last_move_actor_idx], "_will_move_last_this_turn", true);
            }
        }
    } catch (e_mark_last_move) {}

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
                if (!(is_struct(mmq) && variable_struct_exists(mmq, "protect") && variable_struct_get(mmq, "protect") == true)) continue;

                // Resolve actor ref safely (actor_index or slot) and set protection flags
                var aidx = undefined;
                try { if (variable_struct_exists(act, "actor_index") && is_real(variable_struct_get(act, "actor_index"))) aidx = variable_struct_get(act, "actor_index"); } catch (e_ai) { aidx = undefined; }
                try { if (!is_real(aidx) && variable_struct_exists(act, "slot") && is_real(variable_struct_get(act, "slot"))) aidx = variable_struct_get(act, "slot"); } catch (e_ai2) { /* ignore */ }
                var actRef = undefined;
                try { if (variable_struct_exists(_B, "actor") && is_array(variable_struct_get(_B, "actor"))){ var _arr = variable_struct_get(_B, "actor"); if (is_real(aidx) && aidx >= 0 && aidx < array_length(_arr)) actRef = _arr[aidx]; } } catch (e_ar) { actRef = undefined; }
                if (!is_struct(actRef)) continue;
                try { variable_struct_set(actRef, "_protected", true); } catch (e_ps) {}
                try { variable_struct_set(actRef, "_protected_announce_shown", false); } catch (e_pa) {}
                if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){
                    try {
                        var _aname_dbg = "unknown";
                        if (variable_struct_exists(actRef, "name")) _aname_dbg = variable_struct_get(actRef, "name");
                        else if (variable_struct_exists(actRef, "mon") && is_struct(variable_struct_get(actRef, "mon")) && variable_struct_exists(variable_struct_get(actRef, "mon"), "name")) _aname_dbg = variable_struct_get(variable_struct_get(actRef, "mon"), "name");
                        show_debug_message("[battle][protect][set] actor_index=" + string(aidx) + " move_id=" + string(mid) + " name=" + string(_aname_dbg));
                    } catch (e_dbg2) {}
                }
            }
        }
    } catch (e_immed) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][build_actions] immediate-effect apply failed: " + string(e_immed)); }

    return actions;
}
/// If a turn queue is ready, step through resolution (actions, damage, dialogs, statuses).
/// Params: _pid (int)
/// Side effects: Mutates _B.turn_queue/_B.turn_i, applies damage/status, opens dialogs as needed.
function __battle_step_turn_if_ready(_pid){
    var _B = __battle_ensure_slot(_pid);
    // DEBUG: report basic turn/actor state when stepping, but only when phase or turn_i changes
    // (debug removed)
    if (!is_struct(_B)) return;

    // If dialog is open, wait
    if (__battle_any_player_dialog_open(_pid)) return;
    if (( !variable_struct_exists(_B, "_faint_pending") || !variable_struct_get(_B, "_faint_pending") ) && variable_struct_exists(_B, "_pending_status_msgs") && is_array(variable_struct_get(_B, "_pending_status_msgs"))){
        var _pre_action_msgs = variable_struct_get(_B, "_pending_status_msgs");
        if (array_length(_pre_action_msgs) > 0){
            var _pre_pack = __battle_coalesce_head_stat_msgs(_B);
            var _pre_text = undefined;
            var _pre_consume = 1;
            if (is_struct(_pre_pack) && variable_struct_exists(_pre_pack, "text")){
                _pre_text = variable_struct_get(_pre_pack, "text");
                if (variable_struct_exists(_pre_pack, "consumed") && is_real(variable_struct_get(_pre_pack, "consumed"))) _pre_consume = max(1, floor(variable_struct_get(_pre_pack, "consumed")));
            } else {
                _pre_text = __battle_pending_msg_text(_pre_action_msgs[0]);
            }
            var _pre_msg_pid = (is_struct(_pre_pack) && variable_struct_exists(_pre_pack, "pid") && is_real(variable_struct_get(_pre_pack, "pid"))) ? max(0, floor(variable_struct_get(_pre_pack, "pid"))) : __battle_pending_msg_pid(_pre_action_msgs[0], _pid);
            var _pre_next = [];
            for (var _pre_i = _pre_consume; _pre_i < array_length(_pre_action_msgs); ++_pre_i) array_push(_pre_next, _pre_action_msgs[_pre_i]);
            variable_struct_set(_B, "_pending_status_msgs", _pre_next);
            try { if (!is_undefined(dialog2p_show_now)) dialog2p_show_now(_pre_msg_pid, _pre_text); else if (!is_undefined(dialog2p_enqueue_text)) dialog2p_enqueue_text(_pre_msg_pid, _pre_text, _pre_text, "any"); } catch (e_pre_action_msg) {}
            return;
        }
    }

    // If a multi-hit sequence is pending (we showed the initial 'used' dialog),
    // process exactly one additional hit and show a short dialog, then return so
    // the player can close it before the next hit. This creates the Emerald-style
    // per-hit dramatic effect.
    // If a faint is pending, avoid showing per-hit dialogs until the faint flow
    // has completed (faint dialogs must take priority).
    if (( !variable_struct_exists(_B, "_faint_pending") || !variable_struct_get(_B, "_faint_pending") ) && variable_struct_exists(_B, "_pending_multi_hit") && is_struct(variable_struct_get(_B, "_pending_multi_hit"))){
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
            try {
                var __fn_meta_apply = undefined;
                if (variable_global_exists("__battle_apply_move_meta_effects")){
                    __fn_meta_apply = variable_global_get("__battle_apply_move_meta_effects");
                }
                if (!is_undefined(__fn_meta_apply)){
                    var mm_all = undefined;
                    try { mm_all = __battle_get_move_meta(mov); } catch (e_meta_lookup) { mm_all = undefined; }
                    __fn_meta_apply(_pid, {}, Aact, Dact, mov, dmg, mm_all);
                }
            } catch (e_mh){ if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][pending_hit] meta error: " + string(e_mh)); }
            // show a short per-hit dialog with explicit target/move/count: "{Target} was hit by {Move} ({count} times)!"
            try {
                var tgt_name = (variable_struct_exists(Dact, "name") ? variable_struct_get(Dact, "name") : "The target");
                var mv_name_pm = (is_real(mov) ? __battle_move_name(mov) : "the move");
                // compute how many times this target has been hit so far in the sequence
                var total_hits = (variable_struct_exists(pm, "total_hits") ? variable_struct_get(pm, "total_hits") : undefined);
                var remaining_now = (variable_struct_exists(pm, "remaining") ? floor(variable_struct_get(pm, "remaining")) : 0);
                // Include the initial hit already applied when computing the per-hit count
                var hit_count = (is_real(total_hits) ? (total_hits - remaining_now + 1) : 1);
                var times_txt = string(hit_count) + " time" + (hit_count == 1 ? "" : "s");
                var hitMsg = string(tgt_name) + " was hit by " + mv_name_pm + " (" + times_txt + ")!";
                try { dialog2p_show_now(_pid, hitMsg); } catch(e_hm) { try { dialog2p_enqueue(_pid, hitMsg); } catch(e_){} }
            } catch (e_msg){
                // fallback to the generic message if anything goes wrong
                try { dialog2p_show_now(_pid, "It hit!"); } catch(e_ih) { try { dialog2p_enqueue(_pid, "It hit!"); } catch(e_){} }
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
        // No actions active -> clear action flag so UI can reappear
        try { _B.turn_action_player = undefined; _B.turn_action_enemy = undefined; variable_struct_set(_B, "_player_turn_actions", []); } catch (e_turn_clear_empty) {}
        try { variable_struct_set(_B, "_preserve_player_turn_actions_once", false); } catch (e_turn_preserve_empty) {}
        try { variable_struct_set(_B, "_action_active", false); } catch (e_cla) {}
        try { variable_struct_set(_B, "_suppress_wait_for_dialog_close", false); } catch (e_turn_wait_empty) {}
        try { variable_struct_set(_B, "_suppress_sys_ui_until", undefined); } catch (e_turn_ui_empty) {}
        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){ try { show_debug_message("[battle][dbg]_action_active set=false (turn_queue empty) pid=" + string(_pid)); } catch (e_dbg_cla) {} }
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
        try { variable_struct_set(_B, "_last_phase", "command"); } catch (e_last_phase_cmd_empty) {}
        if (!is_undefined(__battle_on_phase_enter)) __battle_on_phase_enter(_pid, "command");
        return;
    }

    // All actions processed?
    if (_B.turn_i >= array_length(_B.turn_queue)){
        try { _B.turn_action_player = undefined; _B.turn_action_enemy = undefined; variable_struct_set(_B, "_player_turn_actions", []); } catch (e_turn_clear_done) {}
        try { variable_struct_set(_B, "_preserve_player_turn_actions_once", false); } catch (e_turn_preserve_done) {}
        // After the turn, tick statuses and then check win/lose.
        // Residuals must cover every live battler, not just the lead pair.
        var A0 = undefined;
        var A1 = undefined;
        var _acts_tmp = [];
        if (variable_struct_exists(_B, "actor") && is_array(variable_struct_get(_B, "actor"))){
            _acts_tmp = variable_struct_get(_B, "actor");
            if (array_length(_acts_tmp) > 0) A0 = _acts_tmp[0];
            A1 = __battle_find_pending_enemy_faint_actor(_pid);
            if (!is_struct(A1)){
                var _enemy_endturn_index = __battle_enemy_lead_index(_pid);
                if (is_real(_enemy_endturn_index) && _enemy_endturn_index >= 0 && _enemy_endturn_index < array_length(_acts_tmp)) A1 = _acts_tmp[_enemy_endturn_index];
                else if (array_length(_acts_tmp) > 1) A1 = _acts_tmp[1];
            }
        }
        try {
            // Only tick statuses once for this end-of-turn. The battle loop may remain
            // in the 'end-of-turn' state while dialogs are shown, so without a guard
            // we would repeatedly apply status ticks each frame. Use a per-battle flag
            // so we apply ticks exactly once until the battle progresses.
            var _already = (variable_struct_exists(_B, "_statuses_ticked") ? variable_struct_get(_B, "_statuses_ticked") : false);
            if (!_already){
                try { __battle_tick_delayed_hits(_pid); } catch (e_delayed_hits) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][delayed_hit] tick failed: " + string(e_delayed_hits)); }
                // Tick statuses on every live actor if status system is available.
                if (!is_undefined(status_system_tick_statuses)){
                    for (var _ti = 0; _ti < array_length(_acts_tmp); ++_ti){
                        var _tick_actor = _acts_tmp[_ti];
                        if (!is_struct(_tick_actor)) continue;
                        var _fainted_tick = false;
                        try {
                            _fainted_tick = (__battle_hp_now(_tick_actor) <= 0);
                            if (!_fainted_tick && variable_struct_exists(_tick_actor, "_fainted") && variable_struct_get(_tick_actor, "_fainted") == true) _fainted_tick = true;
                            if (!_fainted_tick && variable_struct_exists(_tick_actor, "mon") && is_struct(variable_struct_get(_tick_actor, "mon"))){
                                var _tick_mon = variable_struct_get(_tick_actor, "mon");
                                if (variable_struct_exists(_tick_mon, "_fainted") && variable_struct_get(_tick_mon, "_fainted") == true) _fainted_tick = true;
                            }
                        } catch (e_tick_fainted) { _fainted_tick = false; }
                        if (_fainted_tick) continue;
                        status_system_tick_statuses(_tick_actor, undefined);
                    }
                }
                try { __battle_apply_end_turn_ability_actions(_pid); } catch (e_end_turn_abilities) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][ability][end_turn] failed: " + string(e_end_turn_abilities)); }
                try { __battle_tick_dynamax_runtime(_pid); } catch (e_dynamax_tick) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][dynamax][end_turn] failed: " + string(e_dynamax_tick)); }
                // Terrain end-of-turn effects (e.g., Grassy Terrain heal) and duration decrement
                try {
                    var __fn_terrain_state = undefined;
                    if (variable_global_exists("__battle_get_terrain_state")){
                        __fn_terrain_state = variable_global_get("__battle_get_terrain_state");
                    }
                    var terr_struct = undefined;
                    if (!is_undefined(__fn_terrain_state)) terr_struct = __fn_terrain_state(_pid);
                    var terr_name = "";
                    var terr_turns = 0;
                    var terr_infinite = false;
                    if (is_struct(terr_struct)){
                        if (variable_struct_exists(terr_struct, "id")) terr_name = string_lower(string(variable_struct_get(terr_struct, "id")));
                        if (variable_struct_exists(terr_struct, "turns") && is_real(variable_struct_get(terr_struct, "turns"))) terr_turns = variable_struct_get(terr_struct, "turns");
                        terr_infinite = (variable_struct_exists(terr_struct, "infinite") && variable_struct_get(terr_struct, "infinite") == true);
                    }
                    if (string_length(terr_name) > 0){
                        // Apply Grassy Terrain heal: 1/16 max HP to grounded Pok�mon on the field
                        if (terr_name == "grassy"){
                            try {
                                var _acts = (variable_struct_exists(_B, "actor") && is_array(variable_struct_get(_B, "actor"))) ? variable_struct_get(_B, "actor") : [];
                                var healed_any = false;
                                for (var gi = 0; gi < array_length(_acts); ++gi){
                                    var actg = _acts[gi]; if (!is_struct(actg)) continue;
                                    var grounded_ok = true;
                                    try {
                                        var __fn_actor_grounded = undefined;
                                        if (variable_global_exists("__actor_is_grounded")){
                                            __fn_actor_grounded = variable_global_get("__actor_is_grounded");
                                        }
                                        if (!is_undefined(__fn_actor_grounded)) grounded_ok = __fn_actor_grounded(actg);
                                    } catch (e_g) {}
                                    if (!grounded_ok) continue;
                                    // Do not heal fainted actors; keep them at 0 HP so trainer win logic can resolve.
                                    try {
                                        if (variable_struct_exists(actg, "_fainted") && variable_struct_get(actg, "_fainted") == true) continue;
                                        if (variable_struct_exists(actg, "mon") && is_struct(variable_struct_get(actg, "mon"))){
                                            var _mi_fainted = variable_struct_get(actg, "mon");
                                            if (variable_struct_exists(_mi_fainted, "_fainted") && variable_struct_get(_mi_fainted, "_fainted") == true) continue;
                                        }
                                    } catch (e_fstate) {}
                                    // Resolve max HP robustly (supports hp_max/maxhp on actor or inner mon)
                                    var maxhp_local = 1;
                                    try {
                                        if (!is_undefined(__battle_hp_max)) maxhp_local = __battle_hp_max(actg);
                                        else {
                                            if (variable_struct_exists(actg, "hp_max")) maxhp_local = variable_struct_get(actg, "hp_max");
                                            else if (variable_struct_exists(actg, "maxhp")) maxhp_local = variable_struct_get(actg, "maxhp");
                                            else if (variable_struct_exists(actg, "mon") && is_struct(variable_struct_get(actg, "mon"))){
                                                var _mi_h = variable_struct_get(actg, "mon");
                                                if (variable_struct_exists(_mi_h, "hp_max")) maxhp_local = variable_struct_get(_mi_h, "hp_max");
                                                else if (variable_struct_exists(_mi_h, "maxhp")) maxhp_local = variable_struct_get(_mi_h, "maxhp");
                                            }
                                        }
                                    } catch (e_mh) { maxhp_local = 1; }
                                    var heal_amt = max(1, floor(real(maxhp_local) / 16));
                                    var curhp = __battle_hp_now(actg);
                                    if (!is_real(curhp) || curhp <= 0) continue;
                                    var newhp = min(maxhp_local, curhp + heal_amt);
                                    if (newhp > curhp){
                                        healed_any = true;
                                        // Apply the heal canonically
                                        __battle_set_hp_now(actg, newhp);
                                        // Start HP lerp on the healed actor (and inner mon)
                                        try {
                                            variable_struct_set(actg, "_hp_lerp_from", curhp);
                                            variable_struct_set(actg, "_hp_lerp_to", newhp);
                                            variable_struct_set(actg, "_hp_lerp_start_ms", current_time);
                                            variable_struct_set(actg, "_hp_lerp_dur", 400);
                                            variable_struct_set(actg, "_hp_lerp_active", true);
                                            if (variable_struct_exists(actg, "mon") && is_struct(variable_struct_get(actg, "mon"))){
                                                var __mi = variable_struct_get(actg, "mon");
                                                variable_struct_set(__mi, "_hp_lerp_from", curhp);
                                                variable_struct_set(__mi, "_hp_lerp_to", newhp);
                                                variable_struct_set(__mi, "_hp_lerp_start_ms", variable_struct_get(actg, "_hp_lerp_start_ms"));
                                                variable_struct_set(__mi, "_hp_lerp_dur", variable_struct_get(actg, "_hp_lerp_dur"));
                                                variable_struct_set(__mi, "_hp_lerp_active", true);
                                            }
                                        } catch (e_ll) {}
                                        // Request a heal animation cue for this actor index
                                        try { __battle_request_animation_safe(_pid, { type: "heal", target_index: gi, amount: heal_amt }); } catch (e_anim) {}
                                    }
                                }
                                // Only show dialog and play SFX if at least one actor healed
                                if (healed_any){
                                    try { dialog2p_show_now(_pid, "The Grassy Terrain restored HP!"); } catch (e_d) { try { dialog2p_enqueue(_pid, "The Grassy Terrain restored HP!"); } catch(e_){} }
                                    try { __battle_play_heal_once(snd_Heal); } catch (e_hfx) {}
                                }
                            } catch (e_heal) { }
                        }
                        // Decrement terrain turns and clear when expired
                        if (!terr_infinite){
                            if (is_real(terr_turns) && terr_turns > 0){
                                var terr_turns_next = terr_turns - 1;
                                if (is_struct(terr_struct)) variable_struct_set(terr_struct, "turns", terr_turns_next);
                                if (terr_turns_next <= 0){
                                    var __fn_clear_terrain = undefined;
                                    if (variable_global_exists("__battle_field_clear_terrain")){
                                        __fn_clear_terrain = variable_global_get("__battle_field_clear_terrain");
                                    }
                                    if (!is_undefined(__fn_clear_terrain)) __fn_clear_terrain(_pid);
                                    try { dialog2p_show_now(_pid, "The terrain returned to normal!"); } catch (e_td) { try { dialog2p_enqueue(_pid, "The terrain returned to normal!"); } catch(e_){} }
                                }
                            } else if (is_struct(terr_struct) && (!is_real(terr_turns) || terr_turns <= 0)){
                                var __fn_clear_terrain_now = undefined;
                                if (variable_global_exists("__battle_field_clear_terrain")){
                                    __fn_clear_terrain_now = variable_global_get("__battle_field_clear_terrain");
                                }
                                if (!is_undefined(__fn_clear_terrain_now)) __fn_clear_terrain_now(_pid);
                            }
                        }
                    }
                } catch (e_te) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][terrain] end-of-turn tick failed: " + string(e_te)); }
                try {
                    for (var _side_tick = 0; _side_tick < 2; ++_side_tick){
                        var _barrier_keys = ["light_screen", "reflect", "aurora_veil"];
                        for (var _bk = 0; _bk < array_length(_barrier_keys); ++_bk){
                            var _bkey = _barrier_keys[_bk];
                            var _bturns = __battle_field_get_barrier_or(_pid, _side_tick, _bkey, 0);
                            if (!is_real(_bturns) || _bturns <= 0) continue;
                            var _bnext = _bturns - 1;
                            if (_bnext > 0) __battle_field_set_barrier(_pid, _side_tick, _bkey, _bnext);
                            else __battle_field_clear_barrier(_pid, _side_tick, _bkey);
                        }
                        var _side_status_keys = ["mist", "safeguard", "tailwind"];
                        for (var _ssk = 0; _ssk < array_length(_side_status_keys); ++_ssk){
                            var _skey = _side_status_keys[_ssk];
                            var _sturns = __battle_field_get_side_status_or(_pid, _side_tick, _skey, 0);
                            if (!(is_real(_sturns) && _sturns > 0)) continue;
                            var _snext = _sturns - 1;
                            if (_snext > 0) __battle_field_set_side_status(_pid, _side_tick, _skey, _snext);
                            else __battle_field_clear_side_status(_pid, _side_tick, _skey);
                        }
                    }
                    var _mud_turns = __battle_field_get_status_or(_pid, "mud_sport", 0);
                    if (is_real(_mud_turns) && _mud_turns > 0){
                        var _mud_next = _mud_turns - 1;
                        if (_mud_next > 0) __battle_field_set_status(_pid, "mud_sport", _mud_next);
                        else __battle_field_clear_status(_pid, "mud_sport");
                    }
                    var _water_turns = __battle_field_get_status_or(_pid, "water_sport", 0);
                    if (is_real(_water_turns) && _water_turns > 0){
                        var _water_next = _water_turns - 1;
                        if (_water_next > 0) __battle_field_set_status(_pid, "water_sport", _water_next);
                        else __battle_field_clear_status(_pid, "water_sport");
                    }
                    var _gravity_turns_tick = __battle_field_get_status_or(_pid, "gravity", 0);
                    if (is_real(_gravity_turns_tick) && _gravity_turns_tick > 0){
                        var _gravity_next = _gravity_turns_tick - 1;
                        if (_gravity_next > 0) __battle_field_set_status(_pid, "gravity", _gravity_next);
                        else {
                            __battle_field_clear_status(_pid, "gravity");
                            try { dialog2p_show_now(_pid, "Gravity returned to normal!"); } catch (e_gravity_msg) { try { dialog2p_enqueue(_pid, "Gravity returned to normal!"); } catch (e_gravity_msg2) {} }
                        }
                    }
                    if (variable_struct_exists(_B, "_pending_wishes") && is_array(variable_struct_get(_B, "_pending_wishes"))){
                        var _wish_arr_tick = variable_struct_get(_B, "_pending_wishes");
                        var _wish_next_arr = [];
                        for (var _wi = 0; _wi < array_length(_wish_arr_tick); ++_wi){
                            var _wish_entry = _wish_arr_tick[_wi];
                            if (!is_struct(_wish_entry)) continue;
                            var _wish_remaining = (variable_struct_exists(_wish_entry, "remaining") && is_real(variable_struct_get(_wish_entry, "remaining"))) ? floor(variable_struct_get(_wish_entry, "remaining")) - 1 : 0;
                            var _wish_side_tick = (variable_struct_exists(_wish_entry, "side") && is_real(variable_struct_get(_wish_entry, "side"))) ? floor(variable_struct_get(_wish_entry, "side")) : 0;
                            if (_wish_remaining > 0){
                                variable_struct_set(_wish_entry, "remaining", _wish_remaining);
                                array_push(_wish_next_arr, _wish_entry);
                                continue;
                            }
                            var _wish_target = undefined;
                            if (variable_struct_exists(_B, "actor") && is_array(variable_struct_get(_B, "actor"))){
                                var _wish_actors = variable_struct_get(_B, "actor");
                                for (var _wa = 0; _wa < array_length(_wish_actors); ++_wa){
                                    var _wish_actor = _wish_actors[_wa];
                                    if (!is_struct(_wish_actor)) continue;
                                    if (__battle_field_side_index_for_actor(_wa) != _wish_side_tick) continue;
                                    _wish_target = _wish_actor;
                                    break;
                                }
                            }
                            if (is_struct(_wish_target)){
                                var _wish_before = __battle_hp_now(_wish_target);
                                var _wish_max = max(1, __battle_hp_max(_wish_target));
                                var _wish_amount = (variable_struct_exists(_wish_entry, "amount") && is_real(variable_struct_get(_wish_entry, "amount"))) ? max(1, floor(variable_struct_get(_wish_entry, "amount"))) : floor(_wish_max * 0.5);
                                var _wish_after = min(_wish_max, _wish_before + _wish_amount);
                                if (_wish_after > _wish_before){
                                    __battle_set_hp_now(_wish_target, _wish_after);
                                    try { __battle_clear_fainted_if_healed(_wish_target); } catch (e_wish_clear) {}
                                    try {
                                        variable_struct_set(_wish_target, "_hp_lerp_from", _wish_before);
                                        variable_struct_set(_wish_target, "_hp_lerp_to", _wish_after);
                                        variable_struct_set(_wish_target, "_hp_lerp_start_ms", current_time);
                                        variable_struct_set(_wish_target, "_hp_lerp_dur", 400);
                                        variable_struct_set(_wish_target, "_hp_lerp_active", true);
                                    } catch (e_wish_lerp) {}
                                    try { __battle_request_animation_safe(_pid, { type: "heal", actor: _wish_target, target_index: (variable_struct_exists(_wish_target, "actor_index") ? variable_struct_get(_wish_target, "actor_index") : _wish_side_tick), amount: (_wish_after - _wish_before) }); } catch (e_wish_anim) {}
                                    try { dialog2p_show_now(_pid, (variable_struct_exists(_wish_target, "name") ? string(variable_struct_get(_wish_target, "name")) : "The target") + "'s wish came true!"); } catch (e_wish_msg) { try { dialog2p_enqueue(_pid, (variable_struct_exists(_wish_target, "name") ? string(variable_struct_get(_wish_target, "name")) : "The target") + "'s wish came true!"); } catch (e_wish_msg2) {} }
                                }
                            }
                        }
                        variable_struct_set(_B, "_pending_wishes", _wish_next_arr);
                    }
                } catch (e_side_tick) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][field] side-state tick failed: " + string(e_side_tick)); }
                // mark that we've ticked statuses for this end-of-turn so we don't repeat
                try { variable_struct_set(_B, "_statuses_ticked", true); } catch (e_st) {}
            }
        } catch (e_tick) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][status_tick] error: " + string(e_tick)); }

        // Apply any pledge combo residuals queued this turn (e.g., Fire Pledge residual damage, Grass speed halving)
        try {
            var pce = (variable_struct_exists(_B, "_pledge_combo_effects") && is_array(variable_struct_get(_B, "_pledge_combo_effects"))) ? variable_struct_get(_B, "_pledge_combo_effects") : [];
            if (is_array(pce) && array_length(pce) > 0){
                // For each queued combo effect, apply its per-turn behavior and track durations
                var new_reverts = (variable_struct_exists(_B, "_pledge_reverts") && is_array(variable_struct_get(_B, "_pledge_reverts"))) ? variable_struct_get(_B, "_pledge_reverts") : [];
                for (var _pi = 0; _pi < array_length(pce); ++_pi){
                    var pec = pce[_pi];
                    // Accept either a struct with {id,turns,side} or a plain string id
                    if (!is_struct(pec) && !is_string(pec)) continue;
                    var peid = undefined;
                    if (is_struct(pec) && variable_struct_exists(pec, "id")) peid = variable_struct_get(pec, "id");
                    else if (is_string(pec)) peid = pec;
                    var pturns = (is_struct(pec) && variable_struct_exists(pec, "turns")) ? variable_struct_get(pec, "turns") : 4;
                    var targetSide = (is_struct(pec) && variable_struct_exists(pec, "side")) ? variable_struct_get(pec, "side") : 1; // default to opponent side
                    switch(string(peid)){
                        case "pledge_fire_residual":
                            // Damage chosen side Pok�mon for 1/8 max HP
                            try {
                                var actors_arr = (variable_struct_exists(_B, "actor") && is_array(variable_struct_get(_B, "actor"))) ? variable_struct_get(_B, "actor") : [];
                                for (var _ai=0; _ai<array_length(actors_arr); ++_ai){ var act = actors_arr[_ai]; if (!is_struct(act)) continue;
                                    var applyTo = (targetSide == 0) ? (_ai == 0) : (_ai > 0);
                                    if (!applyTo) continue;
                                    try {
                                        var maxhp_local = (variable_struct_exists(act, "hp_max") ? variable_struct_get(act, "hp_max") : (variable_struct_exists(act, "mon") && variable_struct_exists(variable_struct_get(act, "mon"), "hp_max") ? variable_struct_get(variable_struct_get(act, "mon"), "hp_max") : 1));
                                        var dmg_amt = max(1, floor(real(maxhp_local) / 8));
                                        // Attempt canonical damage apply
                                        if (variable_struct_exists(act, "actor_index")) __battle_apply_damage(_pid, variable_struct_get(act, "actor_index"), dmg_amt, 1.0);
                                        else __battle_set_hp_now(act, max(0, __battle_hp_now(act) - dmg_amt));
                                    } catch (e_fire) {}
                                }
                                try { __battle_request_animation_safe(_pid, { type: "pledge_fire_tick" }); } catch (e_a) {}
                                try { dialog2p_show_now(_pid, "The affected Pok�mon are hurt by the Pledge fire!"); } catch (e_d) { try { dialog2p_enqueue(_pid, "The affected Pok�mon are hurt by the Pledge fire!"); } catch(e_){} }
                            } catch (e_pfr) {}
                        break;
                        case "pledge_grass_slow":
                            // Halve Speed for chosen side Pok�mon for pturns (we'll implement as -6 stages clamp to -6)
                            try {
                                var actors_arr2 = (variable_struct_exists(_B, "actor") && is_array(variable_struct_get(_B, "actor"))) ? variable_struct_get(_B, "actor") : [];
                                for (var _ai2=0; _ai2<array_length(actors_arr2); ++_ai2){
                                    var act2 = actors_arr2[_ai2];
                                    if (!is_struct(act2)) continue;
                                    var applyTo2 = (targetSide == 0) ? (_ai2 == 0) : (_ai2 > 0);
                                    if (!applyTo2) continue;
                                    if (!variable_struct_exists(act2, "_stages") || !is_struct(variable_struct_get(act2, "_stages"))) variable_struct_set(act2, "_stages", {});
                                    var st = variable_struct_get(act2, "_stages");
                                    var prevs = (variable_struct_exists(st, "spe") && is_real(variable_struct_get(st, "spe"))) ? variable_struct_get(st, "spe") : 0;
                                    var target = -6;
                                    variable_struct_set(st, "spe", target);
                                    variable_struct_set(act2, "_stages", st);
                                    try { __battle_request_animation_safe(_pid, { type: "pledge_grass_apply", target_index: _ai2 }); } catch (e_pa) {}
                                    // Note: SFX for stat changes is played when the dialog is shown; do not play here.
                                    // queue a revert entry that restores this actor's prior speed stage
                                    array_push(new_reverts, { id: "pledge_grass_slow", turns: pturns, side: targetSide, target_actor_index: _ai2, prev_spe: prevs });
                                }
                                try { dialog2p_show_now(_pid, "Affected Pok�mon's Speed was sharply cut by the Pledge!"); } catch (e_d2) { try { dialog2p_enqueue(_pid, "Affected Pok�mon's Speed was sharply cut by the Pledge!"); } catch(e_){} }
                            } catch (e_pgs) {}
                        break;
                        case "pledge_water_boost_effect":
                            // Mark a flag that doubles effect chance for friendly Pok�mon on targetSide for pturns
                            try {
                                var pflags = (variable_struct_exists(_B, "_pledge_flags") && is_struct(variable_struct_get(_B, "_pledge_flags"))) ? variable_struct_get(_B, "_pledge_flags") : {};
                                var key = "water_pledge_double_effect_side_" + string(targetSide);
                                variable_struct_set(pflags, key, pturns);
                                variable_struct_set(_B, "_pledge_flags", pflags);
                                try { __battle_request_animation_safe(_pid, { type: "pledge_water_apply" }); } catch (e_pw) {}
                                try { dialog2p_show_now(_pid, "Allies on the side are boosted: friendly moves have increased effect chance due to the Pledge!"); } catch (e_pd) { try { dialog2p_enqueue(_pid, "Allies on the side are boosted: friendly moves have increased effect chance due to the Pledge!"); } catch(e_){} }
                            } catch (e_pw2) {}
                            array_push(new_reverts, { id: "pledge_water_boost_effect", turns: pturns, side: targetSide });
                        break;
                    }
                }
                // Persist reverts for ticking next turns
                variable_struct_set(_B, "_pledge_reverts", new_reverts);
                // Clear the queued combos after applying
                variable_struct_set(_B, "_pledge_combo_effects", undefined);
            }
        } catch (e_papply) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][pledge] apply error: " + string(e_papply)); }

        // Decrement pledge flags per-side and process pending reverts (expiration)
        try {
            // Decrement water pledge flags for known sides (0 and 1)
            if (variable_struct_exists(_B, "_pledge_flags") && is_struct(variable_struct_get(_B, "_pledge_flags"))){
                var pf = variable_struct_get(_B, "_pledge_flags");
                for (var scheck = 0; scheck <= 1; ++scheck){
                    var kname = "water_pledge_double_effect_side_" + string(scheck);
                    if (variable_struct_exists(pf, kname) && is_real(variable_struct_get(pf, kname))){
                        var v = max(0, variable_struct_get(pf, kname) - 1);
                        if (v <= 0) variable_struct_set(pf, kname, undefined);
                        else variable_struct_set(pf, kname, v);
                    }
                }
                variable_struct_set(_B, "_pledge_flags", pf);
            }

            // Process pledge reverts: decrement turns and revert effects when expired
            if (variable_struct_exists(_B, "_pledge_reverts") && is_array(variable_struct_get(_B, "_pledge_reverts"))){
                var reverts = variable_struct_get(_B, "_pledge_reverts");
                var keep = [];
                for (var ri = 0; ri < array_length(reverts); ++ri){
                    var rv = reverts[ri];
                    if (!is_struct(rv)) continue;
                    rv.turns = (variable_struct_exists(rv, "turns") ? max(0, variable_struct_get(rv, "turns") - 1) : 0);
                    if (rv.turns <= 0){
                        // revert based on id
                        switch (variable_struct_get(rv, "id")){
                            case "pledge_grass_slow":
                                var side = (variable_struct_exists(rv, "side") ? variable_struct_get(rv, "side") : 1);
                                var actors_arr3 = (variable_struct_exists(_B, "actor") && is_array(variable_struct_get(_B, "actor"))) ? variable_struct_get(_B, "actor") : [];
                                for (var _ai3 = 0; _ai3 < array_length(actors_arr3); ++_ai3){
                                    var a3 = actors_arr3[_ai3];
                                    if (!is_struct(a3)) continue;
                                    var applyTo3 = (side == 0) ? (_ai3 == 0) : (_ai3 > 0);
                                    if (!applyTo3) continue;
                                    if (!variable_struct_exists(a3, "_stages") || !is_struct(variable_struct_get(a3, "_stages"))) continue;
                                    var st3 = variable_struct_get(a3, "_stages");
                                    // Try to find a matching revert entry that targets this actor to restore exact previous spe
                                    var restored = false;
                                    try {
                                        if (variable_struct_exists(rv, "target_actor_index") && is_real(variable_struct_get(rv, "target_actor_index"))){
                                            var idx = variable_struct_get(rv, "target_actor_index");
                                            if (idx == _ai3 && variable_struct_exists(rv, "prev_spe")){
                                                variable_struct_set(st3, "spe", variable_struct_get(rv, "prev_spe"));
                                                restored = true;
                                            }
                                        } else if (variable_struct_exists(rv, "prev_spe")){
                                            variable_struct_set(st3, "spe", variable_struct_get(rv, "prev_spe"));
                                            restored = true;
                                        }
                                    } catch (e_rs) {}
                                    if (!restored) variable_struct_set(st3, "spe", 0);
                                    variable_struct_set(a3, "_stages", st3);
                                    try {
                                        var nm = (variable_struct_exists(a3, "name") ? variable_struct_get(a3, "name") : (variable_struct_exists(a3, "mon") && variable_struct_exists(variable_struct_get(a3, "mon"), "name") ? variable_struct_get(variable_struct_get(a3, "mon"), "name") : "The Pok�mon"));
                                        __status_request_dialog_for_mon(a3, string(nm) + "'s Speed returned to normal as Pledge effect faded.", false);
                                    } catch (e_rmsg) {}
                                }
                                break;
                            case "pledge_water_boost_effect":
                                // Clear the water pledge flag for that side
                                var side2 = (variable_struct_exists(rv, "side") ? variable_struct_get(rv, "side") : undefined);
                                if (!is_undefined(side2) && variable_struct_exists(_B, "_pledge_flags") && is_struct(variable_struct_get(_B, "_pledge_flags"))){
                                    var pf2 = variable_struct_get(_B, "_pledge_flags");
                                    var kn = "water_pledge_double_effect_side_" + string(side2);
                                    if (variable_struct_exists(pf2, kn)) variable_struct_set(pf2, kn, undefined);
                                    variable_struct_set(_B, "_pledge_flags", pf2);
                                }
                                break;
                        }
                    } else {
                        array_push(keep, rv);
                    }
                }
                variable_struct_set(_B, "_pledge_reverts", keep);
            }
        } catch (e_pend) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][pledge] revert tick error: " + string(e_pend)); }

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

        // Post-turn: manage per-actor locked-move states such as Thrash (id 37).
        try {
            if (variable_struct_exists(_B, "actor") && is_array(variable_struct_get(_B, "actor"))){
                var _acts_for_locked = variable_struct_get(_B, "actor");
                for (var _li=0; _li<array_length(_acts_for_locked); ++_li){
                    var _a_locked = _acts_for_locked[_li];
                    if (!is_struct(_a_locked)) continue;
                    try {
                        var _lm = (variable_struct_exists(_a_locked, "_locked_move") ? variable_struct_get(_a_locked, "_locked_move") : undefined);
                        if (is_struct(_lm) && variable_struct_exists(_lm, "force_reuse") && variable_struct_get(_lm, "force_reuse") == true && variable_struct_exists(_lm, "move_id") && is_real(variable_struct_get(_lm, "remaining"))){
                            var rem = floor(variable_struct_get(_lm, "remaining"));
                            // Only decrement the lock if the actor actually executed the locked move this turn
                            var executed = false;
                            try { executed = (variable_struct_exists(_a_locked, "_locked_move_executed") && variable_struct_get(_a_locked, "_locked_move_executed") == true); } catch (e_ex) { executed = false; }
                            if (executed){
                                // decrement by 1 if > 0
                                if (rem > 0) rem = max(0, rem - 1);
                                // clear execution flag for next turn
                                try { variable_struct_set(_a_locked, "_locked_move_executed", undefined); } catch (e_ce) {}
                            }
                            // persist remaining even if not decremented
                            variable_struct_set(_lm, "remaining", rem);
                            variable_struct_set(_a_locked, "_locked_move", _lm);
                            // optional: debug suppressed for thrash/rollout; use DATA_DEBUG_VERBOSE elsewhere if needed
                            if (rem == 0){
                                if (variable_struct_exists(_lm, "apply_confuse_on_end") && variable_struct_get(_lm, "apply_confuse_on_end") == true){
                                    try {
                                        if (!is_undefined(status_system_apply_status)){
                                            status_system_apply_status(_a_locked, "confusion", {});
                                        }
                                    } catch (e_conf) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][thrash] apply confusion failed: " + string(e_conf)); }
                                }
                                variable_struct_set(_a_locked, "_locked_move", undefined);
                                try { if (variable_struct_exists(_a_locked, "_rollout_mul")) variable_struct_set(_a_locked, "_rollout_mul", 1); } catch (e_roll_reset) {}
                            }
                        }
                        try {
                            if (variable_struct_exists(_a_locked, "active_turns") && is_real(variable_struct_get(_a_locked, "active_turns"))) variable_struct_set(_a_locked, "active_turns", max(0, floor(variable_struct_get(_a_locked, "active_turns")) + 1));
                            else variable_struct_set(_a_locked, "active_turns", 1);
                        } catch (e_active_turns) {}
                        var _enc = (variable_struct_exists(_a_locked, "_encore_state") ? variable_struct_get(_a_locked, "_encore_state") : undefined);
                        if (is_struct(_enc) && variable_struct_exists(_enc, "remaining") && is_real(variable_struct_get(_enc, "remaining"))){
                            var _enc_rem = max(0, floor(variable_struct_get(_enc, "remaining")) - 1);
                            if (_enc_rem <= 0) variable_struct_set(_a_locked, "_encore_state", undefined);
                            else {
                                variable_struct_set(_enc, "remaining", _enc_rem);
                                variable_struct_set(_a_locked, "_encore_state", _enc);
                            }
                        }
                        var _taunt = (variable_struct_exists(_a_locked, "_taunt_state") ? variable_struct_get(_a_locked, "_taunt_state") : undefined);
                        if (is_struct(_taunt) && variable_struct_exists(_taunt, "remaining") && is_real(variable_struct_get(_taunt, "remaining"))){
                            var _taunt_rem = max(0, floor(variable_struct_get(_taunt, "remaining")) - 1);
                            if (_taunt_rem <= 0) variable_struct_set(_a_locked, "_taunt_state", undefined);
                            else {
                                variable_struct_set(_taunt, "remaining", _taunt_rem);
                                variable_struct_set(_a_locked, "_taunt_state", _taunt);
                            }
                        }
                    } catch (e_lm) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][thrash] locked processing failed: " + string(e_lm)); }
                }
            }
        } catch (e_pl) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][thrash] post-turn locked handling failed: " + string(e_pl)); }

    try {
        var _uproar_active = __battle_slot_has_active_uproar(_pid);
        variable_struct_set(_B, "_uproar_active", _uproar_active);
        if (_uproar_active && variable_struct_exists(_B, "actor") && is_array(variable_struct_get(_B, "actor")) && !is_undefined(status_system_has_status) && !is_undefined(status_system_clear_status)){
            var _uproar_actors = variable_struct_get(_B, "actor");
            for (var _uproar_i = 0; _uproar_i < array_length(_uproar_actors); ++_uproar_i){
                var _uproar_actor = _uproar_actors[_uproar_i];
                if (!is_struct(_uproar_actor)) continue;
                if (status_system_has_status(_uproar_actor, "sleep")) status_system_clear_status(_uproar_actor, "sleep");
            }
        }
    } catch (e_uproar_tick) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][uproar] post-turn handling failed: " + string(e_uproar_tick)); }

    // After ticking/animations, decrement per-turn weather durations and expire when necessary
    try {
        var _wt = __battle_get_weather(_pid);
        if (__battle_weather_is_active(_wt)){
            __battle_weather_apply_end_of_turn(_pid, _wt);
            if (!__battle_weather_is_infinite(_wt)){
                var rem_before = __battle_weather_remaining_turns_struct(_wt);
                var rem_after = max(0, rem_before - 1);
                __battle_weather_set_remaining_turns_struct(_wt, rem_after);
                if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][weather] ticked weather=" + string(__battle_weather_get_normalized_id(_wt)) + " remaining=" + string(rem_after));
                if (rem_after <= 0){
                    var wid = __battle_weather_get_normalized_id(_wt);
                    __battle_clear_weather(_pid);
                    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][weather] weather " + string(wid) + " expired and cleared");
                    __battle_request_animation_safe(_pid, { type: "weather_end", id: wid });
                    var endMsg = "";
                    switch (string(wid)){
                        case "sun": endMsg = "The sunlight faded."; break;
                        case "harsh-sun": endMsg = "The harsh sunlight subsided."; break;
                        case "rain": endMsg = "The rain stopped."; break;
                        case "sandstorm": endMsg = "The sandstorm subsided."; break;
                        case "hail": endMsg = "The hail stopped."; break;
                        case "snow": endMsg = "The snow stopped."; break;
                        case "fog": endMsg = "The fog lifted."; break;
                        default: endMsg = "The field returned to normal."; break;
                    }
                    try { if (!is_undefined(dialog2p_show_now)) dialog2p_show_now(_pid, endMsg); else if (!is_undefined(dialog2p_enqueue_text)) dialog2p_enqueue_text(_pid, endMsg, endMsg, "any"); } catch (e_msg) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][weather] failed to show end dialog: " + string(e_msg)); }
                }
            }
        }
    } catch (e_wt) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][weather] tick error: " + string(e_wt)); }

    // After ticking/animations, show any deferred status messages (applied during the turn)
    // before proceeding to win/lose checks. This ensures 'fell asleep!' / 'was poisoned!'
    // messages applied mid-turn are presented to the player at the end of the turn.
    try {
        // Only show pending status messages at end-of-turn if a faint is NOT pending.
        // When a faint is pending, dialogs should be deferred until the faint flow
        // completes; attempting to pop+show while _faint_pending is true causes
        // dialog2p_open_text to re-queue the message and can lead to a spam loop.
        if (( !variable_struct_exists(_B, "_faint_pending") || !variable_struct_get(_B, "_faint_pending") ) && variable_struct_exists(_B, "_pending_status_msgs") && is_array(variable_struct_get(_B, "_pending_status_msgs"))){
            var _psend = variable_struct_get(_B, "_pending_status_msgs");
            if (array_length(_psend) > 0){
                // Coalesce consecutive stat-change messages into one page at end-of-turn as well
                var pack2 = __battle_coalesce_head_stat_msgs(_B);
                var _text_to_show2 = undefined;
                var _consume_n2 = 1;
                if (is_struct(pack2) && variable_struct_exists(pack2, "text")){
                    _text_to_show2 = variable_struct_get(pack2, "text");
                    if (variable_struct_exists(pack2, "consumed") && is_real(variable_struct_get(pack2, "consumed"))) _consume_n2 = max(1, floor(variable_struct_get(pack2, "consumed")));
                } else {
                    _text_to_show2 = __battle_pending_msg_text(_psend[0]);
                    _consume_n2 = 1;
                }
                var _msg_pid2 = (is_struct(pack2) && variable_struct_exists(pack2, "pid") && is_real(variable_struct_get(pack2, "pid"))) ? max(0, floor(variable_struct_get(pack2, "pid"))) : __battle_pending_msg_pid(_psend[0], _pid);
                var _new = [];
                for (var _ii = _consume_n2; _ii < array_length(_psend); ++_ii) _new[array_length(_new)] = _psend[_ii];
                variable_struct_set(_B, "_pending_status_msgs", _new);
                try { if (!is_undefined(dialog2p_show_now)) dialog2p_show_now(_msg_pid2, _text_to_show2); else if (!is_undefined(dialog2p_enqueue_text)) dialog2p_enqueue_text(_msg_pid2, _text_to_show2, _text_to_show2, "any"); } catch (e_pend) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][pending_status_endturn] failed to show: " + string(e_pend)); }
                return;
            }
        }
    } catch (e_ps) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][pending_status_endturn] error: " + string(e_ps)); }

    // After ticking/animations, check win/lose

    var hp_enemy_now = __battle_hp_now(A1);
    if (is_struct(A1) && is_real(hp_enemy_now) && hp_enemy_now <= 0){
    var battle_mode_enemy = "wild";
    try {
        if (variable_struct_exists(_B, "_battle_mode")) battle_mode_enemy = string_lower(string(variable_struct_get(_B, "_battle_mode")));
    } catch (e_mode) {}
    var is_trainer_battle = (battle_mode_enemy == "trainer");
    var _enemy_processed = (variable_struct_exists(A1, "_faint_awarded_enemy") && variable_struct_get(A1, "_faint_awarded_enemy") == true);

    show_debug_message("[battle][trainer][win-check] pid=" + string(_pid) + " is_trainer=" + string(is_trainer_battle) + " enemy_processed=" + string(_enemy_processed));

    if (_enemy_processed && is_trainer_battle){
        show_debug_message("[battle][trainer][post-faint] entered win-check pid=" + string(_pid));
        var party_ep = (variable_struct_exists(_B, "_trainer_party") ? variable_struct_get(_B, "_trainer_party") : undefined);
        var trainer_has_other_alive = __battle_trainer_has_alive_except(_B, A1);
        show_debug_message("[battle][trainer][post-faint] trainer_has_other_alive=" + string(trainer_has_other_alive));
        if (variable_struct_exists(_B, "_trainer_pending_send") && is_struct(variable_struct_get(_B, "_trainer_pending_send"))){
            var pending_ep = variable_struct_get(_B, "_trainer_pending_send");
            var pending_alive = false;
            var pending_idx = (is_struct(pending_ep) && variable_struct_exists(pending_ep, "idx")) ? pending_ep.idx : -1;
            if (is_array(party_ep) && is_real(pending_idx) && pending_idx >= 0 && pending_idx < array_length(party_ep)){
                var pending_mon = party_ep[pending_idx];
                if (is_struct(pending_mon)){
                    var pending_hp = __battle_hp_now(pending_mon);
                    var pending_fainted = false;
                    try { if (variable_struct_exists(pending_mon, "_fainted") && variable_struct_get(pending_mon, "_fainted")) pending_fainted = true; } catch (e_pf) { pending_fainted = false; }
                    pending_alive = (is_real(pending_hp) && pending_hp > 0 && !pending_fainted);
                    show_debug_message("[battle][trainer][post-faint] pending idx=" + string(pending_idx) + " hp=" + string(pending_hp) + " faint_flag=" + string(pending_fainted));
                }
            }
            if (!pending_alive){
                try {
                    if (variable_struct_exists(_B, "_trainer_pending_send")) variable_struct_remove(_B, "_trainer_pending_send");
                } catch (e_drop_pending) {
                    try { variable_struct_set(_B, "_trainer_pending_send", undefined); } catch (e_drop_pending2) {}
                }
                trainer_has_other_alive = false;
            } else if (trainer_has_other_alive){
                return;
            }
        }
        if (!trainer_has_other_alive){
            try { variable_struct_set(A1, "_faint_awarded_enemy", false); } catch (e_reset_flag_ep) {}
            _enemy_processed = false;
        } else if (is_array(party_ep)){
            var active_ep = (variable_struct_exists(_B, "_trainer_party_active_idx") ? variable_struct_get(_B, "_trainer_party_active_idx") : -1);
            var next_ep = __battle_trainer_next_alive_index(_B, active_ep);
            if (next_ep < 0){
                if (__battle_side_has_alive_actor(_pid, 1)){
                    try { variable_struct_set(_B, "_pending_close", false); } catch (e_ep_stay_pc) {}
                    try { variable_struct_set(_B, "_action_active", false); } catch (e_ep_stay_act) {}
                    _B.result = "ongoing";
                    _B.phase = "command";
                    return;
                }
                if (__battle_is_local_versus_slot(_B)){
                    var _fainted_enemy_actor_index_ep = (is_struct(A1) && variable_struct_exists(A1, "actor_index") && is_real(variable_struct_get(A1, "actor_index"))) ? floor(variable_struct_get(A1, "actor_index")) : __battle_enemy_lead_index(_pid);
                    if (__battle_finish_local_versus_defeat(_pid, __battle_actor_owner_pid(_pid, _fainted_enemy_actor_index_ep), _fainted_enemy_actor_index_ep)) return;
                }
                __battle_trainer_handle_defeat(_pid);
                try { variable_struct_set(A1, "_faint_awarded_enemy", true); } catch (e_flag_ep) {}
                _B.result = "win";
                try { if (!is_undefined(__battle_play_defeated_music_once)) __battle_play_defeated_music_once(_B); } catch (e_play_ep) {}
                try { variable_struct_set(_B, "_pending_open_party", false); } catch (e_po_ep) {}
                try {
                    if (variable_struct_exists(_B, "_trainer_pending_send")) variable_struct_remove(_B, "_trainer_pending_send");
                } catch (e_ps_ep) {}
                _B._pending_close = true;
                try { variable_struct_set(_B, "_action_active", false); } catch (e_act_ep) {}
                _B.phase = "command";
                try { if (is_struct(_B) && is_array(_B.actor) && array_length(_B.actor) > 1) _B.actor[1] = undefined; } catch (e_clear_ep) {}
                try { variable_struct_set(_B, "_trainer_party_active_idx", -1); } catch (e_idx_ep) {}
                return;
            }
            return;
        }
    }

    if (!_enemy_processed){
    // Handle simultaneous-faint cases: if both actors are at <=0 HP, we need
    // a deterministic tie-breaker. Make this behavior configurable via
    // global.BATTLE_TIE_BEHAVIOR. Supported values:
    //  - "player_win"  (default): treat enemy faint as victory even if player also fainted
    //  - "player_lose" : treat player's faint as loss when both faint
    //  - "draw"        : mark as draw (no win/lose) and close
    var _both_fainted = false;
    var hp_player_now = __battle_hp_now(A0);
    try { if (is_struct(A0) && is_real(hp_player_now) && hp_player_now <= 0) _both_fainted = true; } catch (e_bf) { _both_fainted = false; }
    var _tie_behavior = "player_win";
    try { if (variable_global_exists("BATTLE_TIE_BEHAVIOR") && !is_undefined(global.BATTLE_TIE_BEHAVIOR)) _tie_behavior = string(global.BATTLE_TIE_BEHAVIOR); } catch (e_tb) {}

    if (_both_fainted){
        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][tie] simultaneous faint detected; behavior=" + string(_tie_behavior));
        if (_tie_behavior == "player_lose"){
            _B.result = "lose";
            _B._pending_close = true;
            try { variable_struct_set(_B, "_pending_open_party", false); } catch (e_po) {}
            _B.phase = "command";
            return;
        }
        else if (_tie_behavior == "draw"){
            _B.result = "draw";
            _B._pending_close = true;
            try { variable_struct_set(_B, "_pending_open_party", false); } catch (e_po2) {}
            _B.phase = "command";
            return;
        }
    }

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
    if (!is_struct(ev_yield)) ev_yield = { hp:0, atk:1, def:0, spa:0, spd:0, spe:0 };

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
        var At = (is_struct(_B.actor[0]) && variable_struct_exists(_B.actor[0], "mon") && is_struct(_B.actor[0].mon)) ? _B.actor[0].mon : _B.actor[0];
        if (is_struct(At)) array_push(recipients, At);
    }

    var _ri = 0;
    while (_ri < array_length(recipients)){
        var rmon = recipients[_ri];
        if (!is_undefined(scr_award_ev_to_mon)){
            scr_award_ev_to_mon(rmon, ev_yield);
        }
        _ri += 1;
    }
    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][ev] awarded EVs to " + string(array_length(recipients)) + " recipients");

    try { variable_struct_set(A1, "_faint_awarded_enemy", true); } catch (e_flag) {}
    show_debug_message("[battle][trainer][award] set _faint_awarded_enemy=true pid=" + string(_pid));

    var _dbg_trainer = false;
    try {
        if (variable_global_exists("DATA_DEBUG_TRAINER")) _dbg_trainer = (global.DATA_DEBUG_TRAINER == true);
        else if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) _dbg_trainer = true;
    } catch (e_dbgflag) { _dbg_trainer = false; }

    if (_dbg_trainer){
        try { show_debug_message("[battle][trainer][faint] pid=" + string(_pid) + ", enemy_mon=" + string((is_struct(A1) && variable_struct_exists(A1, "name")) ? variable_struct_get(A1, "name") : "<unknown>")); } catch (e_dbg_faint) {}
    }

    show_debug_message("[battle][trainer][award] entering trainer faint handling pid=" + string(_pid));

    var should_close_battle = true;
    if (is_trainer_battle){
        var trainer_party = (variable_struct_exists(_B, "_trainer_party") ? variable_struct_get(_B, "_trainer_party") : undefined);
        if (is_array(trainer_party)){
            var _is_double_enemy_replace = (variable_struct_exists(_B, "battle_format") && string(variable_struct_get(_B, "battle_format")) == "double");
            var _fainted_enemy_actor_index = (is_struct(A1) && variable_struct_exists(A1, "actor_index") && is_real(variable_struct_get(A1, "actor_index"))) ? floor(variable_struct_get(A1, "actor_index")) : __battle_enemy_lead_index(_pid);
            var active_idx = __battle_trainer_active_party_index_for_actor(_B, _fainted_enemy_actor_index);
            if ((!is_real(active_idx) || active_idx < 0 || active_idx >= array_length(trainer_party)) && !_is_double_enemy_replace){
                for (var __seek = 0; __seek < array_length(trainer_party); ++__seek){
                    if (trainer_party[__seek] == A1){
                        active_idx = __seek;
                        break;
                    }
                }
            }
            if (is_real(active_idx)){
                try { variable_struct_set(_B, "_trainer_party_active_idx", active_idx); } catch (e_set_idx) {}
            }
            if (_dbg_trainer){
                try { show_debug_message("[battle][trainer] active_idx=" + string(active_idx) + ", party_len=" + string(array_length(trainer_party))); } catch (e_dbg_active) {}
            }
            show_debug_message("[battle][trainer][post-faint] active_idx=" + string(active_idx));
            var next_idx = -1;
            if (_is_double_enemy_replace){
                var _active_indices_replace = (variable_struct_exists(_B, "_trainer_party_active_indices") && is_array(variable_struct_get(_B, "_trainer_party_active_indices"))) ? variable_struct_get(_B, "_trainer_party_active_indices") : [];
                next_idx = __battle_trainer_next_alive_index_excluding(_B, _active_indices_replace, active_idx);
            } else {
                next_idx = __battle_trainer_next_alive_index(_B, active_idx);
            }
            if (_dbg_trainer){
                try { show_debug_message("[battle][trainer] next_idx=" + string(next_idx)); } catch (e_dbg_next) {}
            }
            show_debug_message("[battle][trainer][post-faint] next_idx=" + string(next_idx));
            if (next_idx >= 0){
                if (_is_double_enemy_replace){
                    if (__battle_trainer_schedule_next_mon(_pid, next_idx, _fainted_enemy_actor_index)){
                        try { variable_struct_set(_B, "_trainer_switch_prompt", undefined); } catch (e_clear_trprompt_double) {}
                        try { variable_struct_set(_B, "_command_pending_action", undefined); } catch (e_clear_pending_double) {}
                        try { variable_struct_set(_B, "_target_pick_targets", undefined); } catch (e_clear_targets_double) {}
                        try { variable_struct_set(_B, "_target_pick_index", 0); } catch (e_clear_pick_double) {}
                        try {
                            if (is_struct(_B.sys_ui) && string(variable_struct_get(_B.sys_ui, "menu")) == "target"){
                                variable_struct_set(_B.sys_ui, "menu", "root");
                                variable_struct_set(_B.sys_ui, "selX", 0);
                                variable_struct_set(_B.sys_ui, "selY", 0);
                            }
                        } catch (e_clear_menu_double) {}
                        should_close_battle = false;
                    }
                } else if (__battle_trainer_begin_switch_prompt(_pid, next_idx)){
                    if (_dbg_trainer){
                        try { show_debug_message("[battle][trainer] prompt next mon idx=" + string(next_idx)); } catch (e_dbg_sched) {}
                    }
                    should_close_battle = false;
                }
            } else {
                var _double_enemy_still_alive = false;
                try { _double_enemy_still_alive = (_is_double_enemy_replace && __battle_side_has_alive_actor(_pid, 1)); } catch (e_double_alive) { _double_enemy_still_alive = false; }
                if (_double_enemy_still_alive){
                    should_close_battle = false;
                } else {
                    if (!__battle_is_local_versus_slot(_B)) __battle_trainer_handle_defeat(_pid);
                    if (_dbg_trainer){
                        try { show_debug_message("[battle][trainer] no mons remain; closing battle"); } catch (e_dbg_no) {}
                    }
                    try {
                        if (variable_struct_exists(_B, "_trainer_pending_send")) variable_struct_remove(_B, "_trainer_pending_send");
                    } catch (e_clrp) {}
                    should_close_battle = true;
                }
            }
        } else {
            if (!__battle_is_local_versus_slot(_B)) __battle_trainer_handle_defeat(_pid);
            if (_dbg_trainer){
                try { show_debug_message("[battle][trainer] trainer_party missing; closing battle"); } catch (e_dbg_party) {}
            }
            try {
                if (variable_struct_exists(_B, "_trainer_pending_send")) variable_struct_remove(_B, "_trainer_pending_send");
            } catch (e_clrp2) {}
            should_close_battle = true;
        }
    }

    if (!should_close_battle){
        try { variable_struct_set(_B, "_pending_close", false); } catch (e_pc) {}
        try { variable_struct_set(_B, "_action_active", false); } catch (e_act) {}
        _B.result = "ongoing";
        _B.phase = "command";
        return;
    }

    if (__battle_is_local_versus_slot(_B)){
        var _fainted_enemy_actor_index_vs = (is_struct(A1) && variable_struct_exists(A1, "actor_index") && is_real(variable_struct_get(A1, "actor_index"))) ? floor(variable_struct_get(A1, "actor_index")) : __battle_enemy_lead_index(_pid);
        var _enemy_owner_pid_vs = __battle_actor_owner_pid(_pid, _fainted_enemy_actor_index_vs);
        if (is_real(_enemy_owner_pid_vs) && _enemy_owner_pid_vs >= 0){
            var _enemy_next_idx_vs = __party_find_next_alive(_enemy_owner_pid_vs);
            if (_enemy_next_idx_vs >= 0){
                var _enemy_name_vs = (is_struct(A1) && variable_struct_exists(A1, "name")) ? string(variable_struct_get(A1, "name")) : "Pok�mon";
                try { variable_struct_set(_B, "_faint_pending", true); } catch (e_vs_fp) {}
                if (!is_undefined(__battle_try_enqueue_faint_dialog)) __battle_try_enqueue_faint_dialog(_enemy_owner_pid_vs, _B, _enemy_name_vs + " fainted!", _enemy_name_vs + " fainted!");
                if (!is_undefined(__battle_two_player_begin_switch_prompt) && __battle_two_player_begin_switch_prompt(_pid, _enemy_owner_pid_vs, _fainted_enemy_actor_index_vs, _enemy_next_idx_vs)){
                    try { variable_struct_set(_B, "_pending_open_party", false); } catch (e_vs_pop_prompt) {}
                    try { variable_struct_set(_B, "_pending_open_party_pid", undefined); } catch (e_vs_poppid_prompt) {}
                    try { variable_struct_set(_B, "_pending_open_party_fainted_actor_index", undefined); } catch (e_vs_popactor_prompt) {}
                } else {
                    try { variable_struct_set(_B, "_pending_open_party", true); } catch (e_vs_pop) {}
                    try { variable_struct_set(_B, "_pending_open_party_pid", _enemy_owner_pid_vs); } catch (e_vs_poppid) {}
                    try { variable_struct_set(_B, "_pending_open_party_fainted_actor_index", _fainted_enemy_actor_index_vs); } catch (e_vs_popactor) {}
                }
                try { variable_struct_set(_B, "_pending_close", false); } catch (e_vs_pc) {}
                try { variable_struct_set(_B, "_action_active", false); } catch (e_vs_act) {}
                _B.result = "ongoing";
                _B.phase = "command";
                return;
            }
            if (__battle_finish_local_versus_defeat(_pid, _enemy_owner_pid_vs, _fainted_enemy_actor_index_vs)) return;
        }
    }

    if (!is_trainer_battle){
        if (__battle_side_has_alive_actor(_pid, 1)){
            try { variable_struct_set(_B, "_pending_close", false); } catch (e_pc_wild) {}
            try { variable_struct_set(_B, "_pending_open_party", false); } catch (e_po_continue) {}
            try { variable_struct_set(_B, "_pending_open_party_pid", undefined); } catch (e_po_pid_continue) {}
            try { variable_struct_set(_B, "_action_active", false); } catch (e_act_continue) {}
            _B.result = "ongoing";
            _B.phase = "command";
            return;
        }
        _B.result = "win";
        _B._pending_close = true;
        try { variable_struct_set(_B, "_pending_open_party", false); } catch (e_po_wild) {}
        try { variable_struct_set(_B, "_pending_open_party_pid", undefined); } catch (e_po_pid_wild) {}
        try { variable_struct_set(_B, "_action_active", false); } catch (e_act_wild) {}
        _B.phase = "command";
        return;
    }

    _B.result = "win";
    try { if (!is_undefined(__battle_play_defeated_music_once)) __battle_play_defeated_music_once(_B); } catch (e_def_once) {}

    try { variable_struct_set(_B, "_pending_open_party", false); } catch (e_clp) {}
    _B._pending_close = true;
    try { variable_struct_set(_B, "_action_active", false); } catch (e_cla2) {}
    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){ try { show_debug_message("[battle][dbg]_action_active set=false (post-turn) pid=" + string(_pid)); } catch (e_dbg_cla2) {} }
    _B.phase = "command";
    try { if (is_struct(_B) && is_array(_B.actor) && array_length(_B.actor) > 1) _B.actor[1] = undefined; } catch (e_clear_enemy) {}
    try { variable_struct_set(_B, "_trainer_party_active_idx", -1); } catch (e_reset_idx) {}
    var __vict_start = __battle_fetch_global_function("__battle_trainer_start_victory_slide");
    if (!is_undefined(__vict_start)) __vict_start(_pid);
    return;
    }
}


        // If the active actor is fainted or a faint was scheduled, open party for forced swap
            var _player_faint_state = __battle_player_active_faint_state(_pid);
            var _any_player_fainted = (is_struct(_player_faint_state) && variable_struct_exists(_player_faint_state, "any_fainted") && variable_struct_get(_player_faint_state, "any_fainted"));
            var _all_player_fainted = (is_struct(_player_faint_state) && variable_struct_exists(_player_faint_state, "all_fainted") && variable_struct_get(_player_faint_state, "all_fainted"));
            var _fainted_player_actor_index = (is_struct(_player_faint_state) && variable_struct_exists(_player_faint_state, "fainted_actor_index") && is_real(variable_struct_get(_player_faint_state, "fainted_actor_index"))) ? floor(variable_struct_get(_player_faint_state, "fainted_actor_index")) : -1;
            var _fainted_player_owner_pid = _pid;
            try {
                if (_fainted_player_actor_index >= 0){
                    var _owner_from_actor = __battle_actor_owner_pid(_pid, _fainted_player_actor_index);
                    if (is_real(_owner_from_actor) && _owner_from_actor >= 0) _fainted_player_owner_pid = floor(_owner_from_actor);
                }
            } catch (e_faint_owner_pid) { _fainted_player_owner_pid = _pid; }
            if (_any_player_fainted || (variable_struct_exists(_B, "_pending_open_party") && variable_struct_get(_B, "_pending_open_party") == true)){
            // Try to find another alive mon in party
            var idxNext = __party_find_next_alive(_fainted_player_owner_pid);
                if (_all_player_fainted && idxNext < 0){
                    var _name0b = (variable_struct_exists(A0, "name") ? variable_struct_get(A0, "name") : "Pok�mon");
                    try { variable_struct_set(_B, "_faint_pending", true); } catch (e_fp3) {}
                    if (!is_undefined(__battle_try_enqueue_faint_dialog)) __battle_try_enqueue_faint_dialog(_fainted_player_owner_pid, _B, string(_name0b) + " fainted!", string(_name0b) + " fainted!");
                    var trainer_name = (variable_global_exists("PLAYER_NAME") ? string(global.PLAYER_NAME) : "You");
                    var pend = (variable_struct_exists(_B, "_pending_status_msgs") ? variable_struct_get(_B, "_pending_status_msgs") : []);
                    if (!is_array(pend)) pend = [];
                    array_push(pend, "You're out of usable Pok�mon!");
                    array_push(pend, string(trainer_name) + " has whited out!");
                    variable_struct_set(_B, "_pending_status_msgs", pend);
                    try { variable_struct_set(_B, "_pending_open_party", false); } catch (e_clpop) {}
                    _B.result = "lose";
                    _B._pending_close = true;
                    try { variable_struct_set(_B, "_defeat_queued", true); } catch (e_dq) {}
                    try { _B.turn_action_player = undefined; _B.turn_action_enemy = undefined; variable_struct_set(_B, "_player_turn_actions", []); } catch (e_ta) {}
                    try { _B.turn_queue = []; _B.turn_i = 0; } catch (e_tq) {}
                    try { variable_struct_set(_B, "_action_active", false); } catch (e_aa2) {}
                } else if (idxNext >= 0){
                var _name0 = (variable_struct_exists(A0, "name") ? variable_struct_get(A0, "name") : "Pok�mon");
                // Open the party in forced-swap mode so the player may choose a replacement.
                // Forced swaps should NOT consume the player's action (enemy does not immediately act).
                if (!is_undefined(party_open) && !is_undefined(party_ensure)){
                        // Mark faint as a high-priority dialog flow so other
                        // transient battle messages (multi-hit / status) do not
                        // overwrite it while we show the faint text.
                        try { variable_struct_set(_B, "_faint_pending", true); } catch (e_fp) {}
                        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][faint] _faint_pending set for pid=" + string(_fainted_player_owner_pid));
                        // Show an explicit faint dialog so the player sees which
                        // Pok�mon fainted. Do NOT open the party UI immediately here �
                        // instead schedule it to open after the dialog closes so the
                        // faint message remains visible and cannot be overwritten by
                        // immediate UI-driven dialog calls.
                        if (!is_undefined(__battle_try_enqueue_faint_dialog)) __battle_try_enqueue_faint_dialog(_fainted_player_owner_pid, _B, string(_name0) + " fainted!", string(_name0) + " fainted!");
                        // Schedule the party open for after dialogs close. The main
                        // loop checks _pending_open_party and will perform the actual
                        // party_open when dialogs are no longer active.
                        try { variable_struct_set(_B, "_pending_open_party", true); } catch (e_sch) {}
                        try { variable_struct_set(_B, "_pending_open_party_pid", _fainted_player_owner_pid); } catch (e_sch_pid) {}
                        try { if (_fainted_player_actor_index >= 0) variable_struct_set(_B, "_pending_open_party_fainted_actor_index", _fainted_player_actor_index); } catch (e_sch_actor) {}
                        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][faint] scheduled _pending_open_party for pid=" + string(_fainted_player_owner_pid));
                        // Preserve optional next-mon ref if present; leave any reordering
                        // or sel adjustments to the actual open handler to avoid
                        // racing with dialog state.
                } else {
                    // Fallback: show a simple dialog if party UI isn't available
                    try { variable_struct_set(_B, "_faint_pending", true); } catch (e_fp2) {}
                    if (!is_undefined(__battle_try_enqueue_faint_dialog)) __battle_try_enqueue_faint_dialog(_pid, _B, string(_name0) + " fainted!\n(TODO) Switch to another Pok�mon.", string(_name0) + " fainted!");
                }
                // You can call battle_switch_to here automatically if desired:
                // battle_switch_to(_pid, idxNext, {});
            } else if (_any_player_fainted) {
                // No replacement is available, but another active ally is still alive.
                // Leave the slot empty and continue the battle with the remaining battler.
                if (_fainted_player_actor_index >= 0 && is_array(_B.actor) && _fainted_player_actor_index < array_length(_B.actor)){
                    try { _B.actor[_fainted_player_actor_index] = undefined; } catch (e_clear_fainted_slot) {}
                }
                try { variable_struct_set(_B, "_pending_open_party", false); } catch (e_clpop_partial) {}
                try { variable_struct_set(_B, "_pending_open_party_pid", undefined); } catch (e_clpop_partial_pid) {}
                try { variable_struct_set(_B, "_pending_open_party_fainted_actor_index", undefined); } catch (e_clpop_partial_actor) {}
                try { variable_struct_set(_B, "_faint_pending", false); } catch (e_clpop_partial_faint) {}
            } else {
                var _name0b = (variable_struct_exists(A0, "name") ? variable_struct_get(A0, "name") : "Pok�mon");
                try { variable_struct_set(_B, "_faint_pending", true); } catch (e_fp3) {}
                // First page: the active Pok�mon fainted
                if (!is_undefined(__battle_try_enqueue_faint_dialog)) __battle_try_enqueue_faint_dialog(_pid, _B, string(_name0b) + " fainted!", string(_name0b) + " fainted!");
                // Queue defeat sequence messages so they show as separate pages
                var trainer_name = (variable_global_exists("PLAYER_NAME") ? string(global.PLAYER_NAME) : "You");
                var pend = (variable_struct_exists(_B, "_pending_status_msgs") ? variable_struct_get(_B, "_pending_status_msgs") : []);
                if (!is_array(pend)) pend = [];
                array_push(pend, "You're out of usable Pok�mon!");
                array_push(pend, string(trainer_name) + " has whited out!");
                variable_struct_set(_B, "_pending_status_msgs", pend);
                // Ensure we won't open the party UI: clear any pending flag defensively
                try { variable_struct_set(_B, "_pending_open_party", false); } catch (e_clpop) {}
                try { variable_struct_set(_B, "_pending_open_party_pid", undefined); } catch (e_clpop_pid) {}
                // Mark loss and schedule close after messages are shown
                _B.result = "lose";
                _B._pending_close = true;
                // Prevent double-queueing defeat flow and stop any remaining turn actions
                try { variable_struct_set(_B, "_defeat_queued", true); } catch (e_dq) {}
                // Clear any in-flight turn actions so the enemy doesn't get another move
                try { _B.turn_action_player = undefined; _B.turn_action_enemy = undefined; variable_struct_set(_B, "_player_turn_actions", []); } catch (e_ta) {}
                try { _B.turn_queue = []; _B.turn_i = 0; } catch (e_tq) {}
                try { variable_struct_set(_B, "_action_active", false); } catch (e_aa2) {}
            }
            try { variable_struct_set(_B, "_action_active", false); } catch (e_turn_done_action2) {}
            try { variable_struct_set(_B, "_suppress_wait_for_dialog_close", false); } catch (e_turn_done_wait2) {}
            try { variable_struct_set(_B, "_suppress_sys_ui_until", undefined); } catch (e_turn_done_ui2) {}
            _B.phase = "command";
            try { variable_struct_set(_B, "_last_phase", "command"); } catch (e_turn_last_phase2) {}
            if (!is_undefined(__battle_on_phase_enter)) __battle_on_phase_enter(_pid, "command");
            return;
                            }

        // Neither side fainted: back to command
                    // clear pending flag so we don't reopen repeatedly
                    try { variable_struct_set(_B, "_pending_open_party", false); } catch (e_cl) {}
        try { variable_struct_set(_B, "_action_active", false); } catch (e_turn_done_action) {}
        try { variable_struct_set(_B, "_suppress_wait_for_dialog_close", false); } catch (e_turn_done_wait) {}
        try { variable_struct_set(_B, "_suppress_sys_ui_until", undefined); } catch (e_turn_done_ui) {}
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

    // If the player has already lost, do not process further turn logic
    try {
        if (variable_struct_exists(_B, "result") && string(variable_struct_get(_B, "result")) == "lose") return;
    } catch (e_resguard) {}

    // Hard guard: if the active player Pok�mon is fainted and there are no usable replacements,
    // immediately queue the defeat sequence if it hasn't been queued yet and stop processing.
    try {
        var _A0_chk = (is_array(_B.actor) ? _B.actor[0] : undefined);
        var _player_state_hard = __battle_player_active_faint_state(_pid);
        var _all_player_fainted_hard = (is_struct(_player_state_hard) && variable_struct_exists(_player_state_hard, "all_fainted") && variable_struct_get(_player_state_hard, "all_fainted"));
        if (_all_player_fainted_hard){
            var _idxAlive2 = __party_find_next_alive(_pid);
            if (_idxAlive2 < 0){
                var _alreadyQueued = (variable_struct_exists(_B, "_defeat_queued") && variable_struct_get(_B, "_defeat_queued"));
                if (!_alreadyQueued){
                    var _name_act = (is_struct(_A0_chk) && variable_struct_exists(_A0_chk, "name") ? string(variable_struct_get(_A0_chk, "name")) : "Pok�mon");
                    // Show immediate faint, then queue out-of-usable + whited out
                    if (!is_undefined(__battle_try_enqueue_faint_dialog)) __battle_try_enqueue_faint_dialog(_pid, _B, _name_act + " fainted!", _name_act + " fainted!");
                    var _trainer = (variable_global_exists("PLAYER_NAME") ? string(global.PLAYER_NAME) : "You");
                    var _pend2 = (variable_struct_exists(_B, "_pending_status_msgs") ? variable_struct_get(_B, "_pending_status_msgs") : []);
                    if (!is_array(_pend2)) _pend2 = [];
                    array_push(_pend2, "You're out of usable Pok�mon!");
                    array_push(_pend2, _trainer + " has whited out!");
                    variable_struct_set(_B, "_pending_status_msgs", _pend2);
                    try { variable_struct_set(_B, "_pending_open_party", false); } catch (e_clp3) {}
                    try { variable_struct_set(_B, "_pending_open_party_pid", undefined); } catch (e_clp3_pid) {}
                    _B.result = "lose";
                    _B._pending_close = true;
                    variable_struct_set(_B, "_defeat_queued", true);
                    // Stop any remaining turn processing immediately
                    try { _B.turn_action_player = undefined; _B.turn_action_enemy = undefined; variable_struct_set(_B, "_player_turn_actions", []); } catch (e_ta2) {}
                    try { _B.turn_queue = []; _B.turn_i = 0; } catch (e_tq2) {}
                    try { variable_struct_set(_B, "_action_active", false); } catch (e_aa3) {}
                    _B.phase = "command";
                }
                return;
            }
        }
    } catch (e_lossguard) {}

    // Skip actions by fainted actors
    var step = _B.turn_queue[_B.turn_i];
    if (!is_struct(step)){ _B.turn_i += 1; return; }

    // If we're at the start of a new turn (turn index 0), clear the status-tick guard
    // so statuses will be ticked at that turn's end. This ensures ticks happen once
    // per full turn rather than being suppressed across rounds.
    try {
        if (is_real(_B.turn_i) && _B.turn_i == 0) {
            variable_struct_set(_B, "_statuses_ticked", false);
            if (variable_struct_exists(_B, "actor") && is_array(variable_struct_get(_B, "actor"))){
                var _turn_actors = variable_struct_get(_B, "actor");
                for (var _turn_ai = 0; _turn_ai < array_length(_turn_actors); ++_turn_ai){
                    var _turn_actor = _turn_actors[_turn_ai];
                    if (!is_struct(_turn_actor)) continue;
                    variable_struct_set(_turn_actor, "_was_hit_this_turn", false);
                }
            }
        }
    } catch (e_stres) {}
    // Also clear any per-turn pledge tracking at the start of a new turn
    try { if (is_real(_B.turn_i) && _B.turn_i == 0) { variable_struct_set(_B, "_pledges_this_turn", undefined); variable_struct_set(_B, "_pledge_combo_effects", undefined); variable_struct_set(_B, "_pledge_reverts", undefined); } } catch (e_ptc) {}

    var actor_idx  = step.actor_index;
    var target_idx = step.target_index;

    if (is_struct(step) && variable_struct_exists(step, "skip_turn") && variable_struct_get(step, "skip_turn") == true){
        _B.turn_i += 1;
        __battle_step_turn_if_ready(_pid);
        return;
    }

    if (!is_array(_B.actor) || actor_idx < 0 || actor_idx >= array_length(_B.actor)){
        _B.turn_i += 1; return;
    }

    if (!is_real(target_idx) || target_idx < 0 || target_idx >= array_length(_B.actor) || !__battle_actor_index_alive(_pid, target_idx)){
        target_idx = __battle_resolve_live_target_index(_pid, actor_idx, target_idx, (variable_struct_exists(step, "move_id") ? variable_struct_get(step, "move_id") : -1));
    }
    if (!is_real(target_idx) || target_idx < 0 || target_idx >= array_length(_B.actor)){
        _B.turn_i += 1; return;
    }

    var A = _B.actor[actor_idx];
    var D = _B.actor[target_idx];

    if (!is_struct(A) || !is_struct(D)){
        _B.turn_i += 1; return;
    }

    // If acting Pok�mon fainted already, skip (use canonical helper)
    if (__battle_is_fainted(A)){ _B.turn_i += 1; __battle_step_turn_if_ready(_pid); return; }

    try {
        if (__battle_actor_side(actor_idx) == 0 && variable_struct_exists(step, "move_id") && is_real(variable_struct_get(step, "move_id")) && variable_struct_get(step, "move_id") >= 0){
            variable_struct_set(_B, "_last_exp_actor_index", actor_idx);
            if (variable_struct_exists(A, "party_pid") && is_real(variable_struct_get(A, "party_pid"))) variable_struct_set(_B, "_last_exp_party_pid", floor(variable_struct_get(A, "party_pid")));
            if (variable_struct_exists(A, "party_index") && is_real(variable_struct_get(A, "party_index"))) variable_struct_set(_B, "_last_exp_party_index", floor(variable_struct_get(A, "party_index")));
        }
    } catch (e_last_exp) {}

    // Perform the action -> returns a dialog string
    try {
        if (variable_struct_exists(step, "move_id") && is_real(variable_struct_get(step, "move_id")) && variable_struct_get(step, "move_id") >= 0 && !is_undefined(item_runtime_actor_held_actions)){
            var _choice_move_actions = item_runtime_actor_held_actions(A, "move_select");
            for (var _cmi = 0; _cmi < array_length(_choice_move_actions); ++_cmi){
                var _cmact = _choice_move_actions[_cmi];
                if (!is_struct(_cmact)) continue;
                var _cmkind = variable_struct_exists(_cmact, "kind") ? string_lower(string(variable_struct_get(_cmact, "kind"))) : "";
                if (_cmkind != "lock_first_move") continue;
                var _chosen_move_id = floor(variable_struct_get(step, "move_id"));
                var _locked_choice_move = (variable_struct_exists(A, "_choice_locked_move_id") && is_real(variable_struct_get(A, "_choice_locked_move_id"))) ? floor(variable_struct_get(A, "_choice_locked_move_id")) : -1;
                if (_locked_choice_move < 0){
                    variable_struct_set(A, "_choice_locked_move_id", _chosen_move_id);
                    if (variable_struct_exists(A, "mon") && is_struct(variable_struct_get(A, "mon"))) variable_struct_set(variable_struct_get(A, "mon"), "_choice_locked_move_id", _chosen_move_id);
                } else if (_locked_choice_move != _chosen_move_id){
                    variable_struct_set(step, "move_id", _locked_choice_move);
                    if (variable_struct_exists(A, "moves") && is_array(variable_struct_get(A, "moves"))){
                        var _cmoves = variable_struct_get(A, "moves");
                        for (var _cms = 0; _cms < array_length(_cmoves); ++_cms){
                            if (is_real(_cmoves[_cms]) && floor(_cmoves[_cms]) == _locked_choice_move){ variable_struct_set(step, "slot", _cms); break; }
                        }
                    }
                }
                break;
            }
        }
    } catch (e_choice_runtime_lock) {}
    try {
        if (variable_struct_exists(A, "_held_next_priority") && variable_struct_get(A, "_held_next_priority") == true){
            variable_struct_set(A, "_held_next_priority", false);
            if (variable_struct_exists(A, "mon") && is_struct(variable_struct_get(A, "mon"))) variable_struct_set(variable_struct_get(A, "mon"), "_held_next_priority", false);
        }
    } catch (e_clear_custap_priority) {}
    try {
        if (variable_struct_exists(step, "transform_mode")){
            var _tf_msg = __battle_apply_transformation_action(_pid, step, actor_idx, A);
            if (string_length(_tf_msg) > 0) dialog_queue(_tf_msg);
        }
    } catch (e_transform_action) {
        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][transform] action failed: " + string(e_transform_action));
    }
    var out_msg = __battle_perform_action(_pid, step);

    // If the action was an item_use (e.g., Pok� Ball) and it started a catch animation,
    // wait here until the animation resolves instead of advancing to the next action.
    if (is_struct(step) && variable_struct_exists(step, "item_use") && step.item_use == true){
        if (variable_struct_exists(_B, "_catch_anim")){
            var _ca = variable_struct_get(_B, "_catch_anim");
            if (is_struct(_ca) && variable_struct_exists(_ca, "active") && _ca.active){
                var _cphase = (variable_struct_exists(_ca, "phase") ? string(_ca.phase) : "");
                var _persist = (variable_struct_exists(_ca, "persistent") && _ca.persistent);
                if (!(_cphase == "caught" && _persist)){
                    // Mark the item action as consumed before pausing on the catch animation.
                    // Otherwise the same step will execute again once the animation clears.
                    _B.turn_i += 1;
                    return;
                }
            }
        }
    }

    if (string_length(out_msg) <= 0){
        try {
            if (variable_struct_exists(_B, "_hold_current_action_for_status_dialog") && variable_struct_get(_B, "_hold_current_action_for_status_dialog")){
                variable_struct_set(_B, "_hold_current_action_for_status_dialog", false);
                return;
            }
        } catch (e_hold_status_dialog) {}
        // No text? move on silently
        _B.turn_i += 1;
        __battle_step_turn_if_ready(_pid);
        return;
    }

    // Show the message; after dialog closes we'll continue with the next step
    try { if (!is_undefined(dialog2p_show_now)) dialog2p_show_now(_pid, out_msg); else if (!is_undefined(dialog2p_enqueue_text)) dialog2p_enqueue_text(_pid, out_msg, out_msg, "any"); } catch (e_dlg) {}
    _B.turn_i += 1;
}
// __battle_perform_action implementation has been moved to battle_moves_impls.gml (__battle_perform_action_impl).
// The thin delegating wrapper near the top of this file will call the impl when present.

// Animation implementation intentionally provided by scripts/battle_animations/battle_animations.gml
// Keep a single canonical implementation there. Do not define __battle_anim_update here to avoid duplicate script names.
function __battle_enemy_choose_action(_pid){
    var _B = __battle_ensure_slot(_pid);
    var _enemy_idx = __battle_enemy_lead_index(_pid);
    var A = (is_array(_B.actor) && _enemy_idx >= 0 && _enemy_idx < array_length(_B.actor)) ? _B.actor[_enemy_idx] : undefined;
    if (!is_struct(A)) return undefined;

    if (variable_global_exists("__debug_trainer_switch_request")){
        var _req = global.__debug_trainer_switch_request;
        if (is_struct(_req)){
            var _req_pid = -1;
            try { if (variable_struct_exists(_req, "pid")) _req_pid = variable_struct_get(_req, "pid"); } catch (e_rpid) { _req_pid = -1; }
            if (_req_pid == _pid){
                var _force_ok = false;
                try { _force_ok = __battle_trainer_debug_force_switch(_pid); } catch (e_force) { _force_ok = false; }
                var _reason_dbg = undefined;
                try { if (variable_struct_exists(_B, "_debug_trainer_force_switch_reason")) _reason_dbg = variable_struct_get(_B, "_debug_trainer_force_switch_reason"); } catch (e_reason) { _reason_dbg = undefined; }
                if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){
                    if (_force_ok) show_debug_message("[battle][debug] Trainer switch request queued via F2 for pid=" + string(_pid));
                    else {
                        var _msg_fail = "[battle][debug] Trainer switch request could not be queued (pid=" + string(_pid) + ")";
                        if (is_string(_reason_dbg)){
                            if (_reason_dbg == "trap" || _reason_dbg == "jaw_lock") _msg_fail += " � enemy is trapped";
                            else if (_reason_dbg == "no_next") _msg_fail += " � no alternate Pok�mon";
                            else if (_reason_dbg == "same_idx") _msg_fail += " � already using that Pok�mon";
                        }
                        show_debug_message(_msg_fail);
                    }
                }
                try { variable_struct_set(_B, "_debug_trainer_force_switch_reason", undefined); } catch (e_reason_clear) {}
                global.__debug_trainer_switch_request = undefined;
            }
        } else {
            global.__debug_trainer_switch_request = undefined;
        }
    }

    var forced_idx = -1;
    var forced_from = undefined;
    var forced_to = undefined;
    try {
        if (variable_struct_exists(_B, "_debug_trainer_force_switch_idx") && is_real(variable_struct_get(_B, "_debug_trainer_force_switch_idx"))){
            forced_idx = floor(variable_struct_get(_B, "_debug_trainer_force_switch_idx"));
            if (variable_struct_exists(_B, "_debug_trainer_force_switch_from")) forced_from = variable_struct_get(_B, "_debug_trainer_force_switch_from");
            if (variable_struct_exists(_B, "_debug_trainer_force_switch_to")) forced_to = variable_struct_get(_B, "_debug_trainer_force_switch_to");
            variable_struct_set(_B, "_debug_trainer_force_switch_idx", undefined);
            variable_struct_set(_B, "_debug_trainer_force_switch_from", undefined);
            variable_struct_set(_B, "_debug_trainer_force_switch_to", undefined);
        }
    } catch (e_forced) { forced_idx = -1; }
    if (forced_idx >= 0) return { actor_index: _enemy_idx, target_index: __battle_get_default_target_index(_pid, _enemy_idx), switch_to: forced_idx, debug_from: forced_from, debug_to: forced_to };
    return __battle_choose_action_for_actor(_pid, _enemy_idx, true);
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
function __battle_queue_delayed_hit(_pid, _packet){
    var _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B) || !is_struct(_packet)) return false;
    var _queued = (variable_struct_exists(_B, "_pending_delayed_hits") && is_array(variable_struct_get(_B, "_pending_delayed_hits"))) ? variable_struct_get(_B, "_pending_delayed_hits") : [];
    var _next = [];
    var _pkt_move = (variable_struct_exists(_packet, "move_id") ? variable_struct_get(_packet, "move_id") : undefined);
    var _pkt_side = (variable_struct_exists(_packet, "source_side") ? variable_struct_get(_packet, "source_side") : undefined);
    for (var _qi = 0; _qi < array_length(_queued); ++_qi){
        var _old = _queued[_qi];
        if (!is_struct(_old)) continue;
        var _old_move = (variable_struct_exists(_old, "move_id") ? variable_struct_get(_old, "move_id") : undefined);
        var _old_side = (variable_struct_exists(_old, "source_side") ? variable_struct_get(_old, "source_side") : undefined);
        if (is_real(_pkt_move) && is_real(_old_move) && is_real(_pkt_side) && is_real(_old_side) && _pkt_move == _old_move && _pkt_side == _old_side) continue;
        array_push(_next, _old);
    }
    array_push(_next, _packet);
    variable_struct_set(_B, "_pending_delayed_hits", _next);
    return true;
}
function __battle_tick_delayed_hits(_pid){
    var _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B)) return false;
    var _queued = (variable_struct_exists(_B, "_pending_delayed_hits") && is_array(variable_struct_get(_B, "_pending_delayed_hits"))) ? variable_struct_get(_B, "_pending_delayed_hits") : [];
    if (!is_array(_queued) || array_length(_queued) <= 0) return false;
    var _next = [];
    var _triggered = false;
    for (var _qi = 0; _qi < array_length(_queued); ++_qi){
        var _pkt = _queued[_qi];
        if (!is_struct(_pkt)) continue;
        var _rem = (variable_struct_exists(_pkt, "turns_remaining") && is_real(variable_struct_get(_pkt, "turns_remaining"))) ? floor(variable_struct_get(_pkt, "turns_remaining")) - 1 : 0;
        if (_rem > 0){
            variable_struct_set(_pkt, "turns_remaining", _rem);
            array_push(_next, _pkt);
            continue;
        }
        var _tidx = (variable_struct_exists(_pkt, "target_index") ? variable_struct_get(_pkt, "target_index") : 1);
        var _dmg = (variable_struct_exists(_pkt, "damage") && is_real(variable_struct_get(_pkt, "damage"))) ? max(1, floor(variable_struct_get(_pkt, "damage"))) : 0;
        var _move_id = (variable_struct_exists(_pkt, "move_id") ? variable_struct_get(_pkt, "move_id") : undefined);
        var _target = (variable_struct_exists(_B, "actor") && is_array(variable_struct_get(_B, "actor")) && is_real(_tidx) && _tidx >= 0 && _tidx < array_length(variable_struct_get(_B, "actor"))) ? variable_struct_get(_B, "actor")[_tidx] : undefined;
        if (!is_struct(_target) || !is_real(_dmg) || _dmg <= 0 || __battle_hp_now(_target) <= 0) continue;
        _triggered = true;
        var _move_name = (is_real(_move_id) ? __battle_move_name(_move_id) : "The delayed attack");
        var _target_name = (variable_struct_exists(_target, "name") ? string(variable_struct_get(_target, "name")) : "the target");
        try { dialog2p_show_now(_pid, _move_name + " struck " + _target_name + "!"); } catch (e_dh_msg) { try { dialog2p_enqueue(_pid, _move_name + " struck " + _target_name + "!"); } catch (e_dh_q) {} }
        try { __battle_request_animation_safe(_pid, { type: "move_hit", target_index: _tidx, move_id: _move_id }); } catch (e_dh_anim) {}
        try { __battle_apply_damage(_pid, _tidx, _dmg, 1.0); } catch (e_dh_apply) {}
    }
    variable_struct_set(_B, "_pending_delayed_hits", (array_length(_next) > 0) ? _next : undefined);
    return _triggered;
}
function __battle_move_power(_code, _A, _D){
    try {
        if (variable_global_exists("_battle_impls") && is_struct(global._battle_impls) && variable_struct_exists(global._battle_impls, "__battle_move_power_impl")){
            var _impl_power = variable_struct_get(global._battle_impls, "__battle_move_power_impl");
            if (!is_undefined(_impl_power)) return _impl_power(_code, _A, _D);
        }
    } catch (e_impl_power) {}
    if (is_real(_code) && _code >= 0){
        if (!is_undefined(scr_move_power_by_id)){
            if (_code == 237){
                var _hp_power = __battle_variable_move_power(_code, _A, _D);
                if (is_real(_hp_power) && _hp_power > 0) return _hp_power;
            }
            if (_code == 363 && !is_undefined(__battle_get_natural_gift_profile)){
                var _gift_profile = __battle_get_natural_gift_profile(_A);
                if (is_struct(_gift_profile) && variable_struct_exists(_gift_profile, "power") && is_real(variable_struct_get(_gift_profile, "power"))) return variable_struct_get(_gift_profile, "power");
            }
            var p = scr_move_power_by_id(_code);
            // If the data-layer returns a positive numeric power, use it.
            // If it returns 0 it usually means 'unspecified / variable power' in the dataset;
            // treat that the same as no value so the fallback applies instead of
            // causing the move to be treated as non-damaging.
            if (is_real(p) && p > 0){
                var _mul_live = 1;
                try {
                    if (_code == 210 && is_struct(_A) && variable_struct_exists(_A, "_fury_cutter_mul") && is_real(variable_struct_get(_A, "_fury_cutter_mul"))) _mul_live = max(1, floor(variable_struct_get(_A, "_fury_cutter_mul")));
                    if (_code == 205 && is_struct(_A) && variable_struct_exists(_A, "_rollout_mul") && is_real(variable_struct_get(_A, "_rollout_mul"))) _mul_live = max(1, floor(variable_struct_get(_A, "_rollout_mul")));
                } catch (e_m_live) { _mul_live = 1; }
                return max(0, real(p) * _mul_live);
            }
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
    var _move_entry = undefined;
    var _effect_id = undefined;
    try {
        if (variable_global_exists("_moves") && is_array(global._moves) && mid >= 0 && mid < array_length(global._moves)){
            _move_entry = global._moves[mid];
        }
        if (!is_undefined(__battle_move_effect_id_safe)) _effect_id = __battle_move_effect_id_safe(mid);
        else if (is_struct(_move_entry) && variable_struct_exists(_move_entry, "effect_id") && is_real(variable_struct_get(_move_entry, "effect_id"))) _effect_id = floor(variable_struct_get(_move_entry, "effect_id"));
    } catch (e_move_lookup) { _move_entry = undefined; _effect_id = undefined; }
    var _friendship_value = function(_actor){
        var _scan = function(_ent){
            if (!is_struct(_ent)) return undefined;
            var _fields = ["happiness", "friendship", "friendliness", "affection"];
            for (var _fi = 0; _fi < array_length(_fields); ++_fi){
                var _fname = _fields[_fi];
                if (variable_struct_exists(_ent, _fname) && is_real(variable_struct_get(_ent, _fname))) return clamp(floor(variable_struct_get(_ent, _fname)), 0, 255);
            }
            return undefined;
        };
        var _val = _scan(_actor);
        if (!is_real(_val) && is_struct(_actor) && variable_struct_exists(_actor, "mon") && is_struct(variable_struct_get(_actor, "mon"))) _val = _scan(variable_struct_get(_actor, "mon"));
        if (!is_real(_val)) _val = 70;
        return clamp(floor(_val), 0, 255);
    };
    // Extract weights (best-effort). The helper returns a raw weight value;
    // callers should normalize if species weights are in hectograms elsewhere.
    var aw = __battle_entity_weight(_A);
    var dw = __battle_entity_weight(_D);

    // Beat Up (id 251): approximate one strike per usable party member by
    // scaling the per-hit power to the attacker's available party count.
    if (mid == 251){
        try {
            var count = 0;
            if (is_struct(_A) && variable_struct_exists(_A, "party") && is_array(variable_struct_get(_A, "party"))) count = array_length(variable_struct_get(_A, "party"));
            else if (is_struct(_A) && variable_struct_exists(_A, "mon") && is_struct(variable_struct_get(_A, "mon")) && variable_struct_exists(variable_struct_get(_A, "mon"), "party") && is_array(variable_struct_get(variable_struct_get(_A, "mon"), "party"))) count = array_length(variable_struct_get(variable_struct_get(_A, "mon"), "party"));
            if (count <= 0) count = 1;
            return clamp(count * 10, 10, 200);
        } catch (e_bu_early){ return 10; }
    }

    if (mid == 237){
        try {
            var _iv_src = undefined;
            if (is_struct(_A) && variable_struct_exists(_A, "iv") && is_struct(variable_struct_get(_A, "iv"))) _iv_src = variable_struct_get(_A, "iv");
            else if (is_struct(_A) && variable_struct_exists(_A, "mon") && is_struct(variable_struct_get(_A, "mon")) && variable_struct_exists(variable_struct_get(_A, "mon"), "iv") && is_struct(variable_struct_get(variable_struct_get(_A, "mon"), "iv"))) _iv_src = variable_struct_get(variable_struct_get(_A, "mon"), "iv");
            if (!is_struct(_iv_src)) return 60;
            var _iv_hp = (variable_struct_exists(_iv_src, "hp") && is_real(variable_struct_get(_iv_src, "hp"))) ? floor(variable_struct_get(_iv_src, "hp")) : 0;
            var _iv_atk = (variable_struct_exists(_iv_src, "atk") && is_real(variable_struct_get(_iv_src, "atk"))) ? floor(variable_struct_get(_iv_src, "atk")) : 0;
            var _iv_def = (variable_struct_exists(_iv_src, "def") && is_real(variable_struct_get(_iv_src, "def"))) ? floor(variable_struct_get(_iv_src, "def")) : 0;
            var _iv_spe = (variable_struct_exists(_iv_src, "spe") && is_real(variable_struct_get(_iv_src, "spe"))) ? floor(variable_struct_get(_iv_src, "spe")) : 0;
            var _iv_spa = (variable_struct_exists(_iv_src, "spa") && is_real(variable_struct_get(_iv_src, "spa"))) ? floor(variable_struct_get(_iv_src, "spa")) : 0;
            var _iv_spd = (variable_struct_exists(_iv_src, "spd") && is_real(variable_struct_get(_iv_src, "spd"))) ? floor(variable_struct_get(_iv_src, "spd")) : 0;
            var _power_value = ((_iv_hp & 2) >> 1) + (((_iv_atk & 2) >> 1) << 1) + (((_iv_def & 2) >> 1) << 2) + (((_iv_spe & 2) >> 1) << 3) + (((_iv_spa & 2) >> 1) << 4) + (((_iv_spd & 2) >> 1) << 5);
            return 30 + floor(_power_value * 40 / 63);
        } catch (e_hidden_power) { return 60; }
    }

    // Flail/Reversal: stronger as the user's HP gets lower.
    if (mid == 175 || mid == 179){
        try {
            var cA_early = 0; var mA_early = 1;
            if (is_struct(_A)){
                if (variable_struct_exists(_A, "hp_now")) cA_early = variable_struct_get(_A, "hp_now"); else if (variable_struct_exists(_A, "hp")) cA_early = variable_struct_get(_A, "hp");
                if (variable_struct_exists(_A, "hp_max")) mA_early = variable_struct_get(_A, "hp_max"); else if (variable_struct_exists(_A, "maxhp")) mA_early = variable_struct_get(_A, "maxhp"); else if (variable_struct_exists(_A, "mon") && is_struct(variable_struct_get(_A, "mon")) && variable_struct_exists(variable_struct_get(_A, "mon"), "hp_max")) mA_early = variable_struct_get(variable_struct_get(_A, "mon"), "hp_max");
            }
            if (mA_early <= 0) return 0;
            var pctA_early = clamp(cA_early / mA_early, 0.0, 1.0);
            if (pctA_early <= 1/48) return 200;
            else if (pctA_early <= 1/16) return 150;
            else if (pctA_early <= 1/8) return 100;
            else if (pctA_early <= 1/4) return 80;
            else if (pctA_early <= 1/2) return 40;
            else return 20;
        } catch (e_fr_early) { return 0; }
    }

    // Eruption / Water Spout: power scales with the user's current HP.
    if (is_real(_effect_id) && _effect_id == 191){
        try {
            var cA_hp = 0;
            var mA_hp = 1;
            if (is_struct(_A)){
                if (variable_struct_exists(_A, "hp_now")) cA_hp = variable_struct_get(_A, "hp_now");
                else if (variable_struct_exists(_A, "hp")) cA_hp = variable_struct_get(_A, "hp");
                if (variable_struct_exists(_A, "hp_max")) mA_hp = variable_struct_get(_A, "hp_max");
                else if (variable_struct_exists(_A, "maxhp")) mA_hp = variable_struct_get(_A, "maxhp");
                else if (variable_struct_exists(_A, "mon") && is_struct(variable_struct_get(_A, "mon"))){
                    var _Amon_hp = variable_struct_get(_A, "mon");
                    if (variable_struct_exists(_Amon_hp, "hp_now")) cA_hp = variable_struct_get(_Amon_hp, "hp_now");
                    else if (variable_struct_exists(_Amon_hp, "hp")) cA_hp = variable_struct_get(_Amon_hp, "hp");
                    if (variable_struct_exists(_Amon_hp, "hp_max")) mA_hp = variable_struct_get(_Amon_hp, "hp_max");
                    else if (variable_struct_exists(_Amon_hp, "maxhp")) mA_hp = variable_struct_get(_Amon_hp, "maxhp");
                }
            }
            cA_hp = max(0, real(cA_hp));
            mA_hp = max(1, real(mA_hp));
            if (cA_hp <= 0) return 1;
            return max(1, floor((150 * cA_hp) / mA_hp));
        } catch (e_eruption) { return 1; }
    }

    // Weather Ball: doubles in power while weather is active.
    if (mid == 311 || (is_real(_effect_id) && _effect_id == 204)){
        try {
            var _pid_wb = undefined;
            if (!is_undefined(__status_find_battle_pid)) _pid_wb = __status_find_battle_pid(_A);
            if (is_real(_pid_wb) && !is_undefined(__battle_get_weather)){
                var _wb_weather = __battle_get_weather(_pid_wb);
                if (is_struct(_wb_weather) && variable_struct_exists(_wb_weather, "active") && variable_struct_get(_wb_weather, "active") == true){
                    var _wb_id = "";
                    if (variable_struct_exists(_wb_weather, "id")) _wb_id = string_lower(string(variable_struct_get(_wb_weather, "id")));
                    if (string_length(_wb_id) > 0) return 100;
                }
            }
        } catch (e_weather_ball_power) {}
        return 50;
    }

    // Wake-Up Slap: doubles power against sleeping targets.
    if (mid == 358 || (is_real(_effect_id) && _effect_id == 218)){
        var _wake_asleep = false;
        try {
            if (!is_undefined(status_system_has_status) && is_struct(_D)){
                _wake_asleep = status_system_has_status(_D, "sleep");
                if (!_wake_asleep && variable_struct_exists(_D, "mon") && is_struct(variable_struct_get(_D, "mon"))) _wake_asleep = status_system_has_status(variable_struct_get(_D, "mon"), "sleep");
            }
        } catch (e_wake_power) { _wake_asleep = false; }
        return (_wake_asleep ? 120 : 60);
    }

    // Brine: doubles power against targets at half HP or lower.
    if (mid == 362 || (is_real(_effect_id) && _effect_id == 222)){
        try {
            var _d_hp = max(0, real(__battle_hp_now(_D)));
            var _d_max = max(1, real(__battle_hp_max(_D)));
            if ((_d_hp * 2) <= _d_max) return 130;
        } catch (e_brine_power) {}
        return 65;
    }

    // Revenge: double power if the user was damaged by the target this turn.
    if (is_real(_effect_id) && _effect_id == 186){
        try {
            var _revenge_hit = false;
            var _revenge_from = undefined;
            if (is_struct(_A)){
                _revenge_hit = variable_struct_exists(_A, "_was_hit_this_turn") && variable_struct_get(_A, "_was_hit_this_turn") == true;
                if (_revenge_hit && variable_struct_exists(_A, "_last_received_damage") && is_real(variable_struct_get(_A, "_last_received_damage"))) _revenge_hit = variable_struct_get(_A, "_last_received_damage") > 0;
                if (variable_struct_exists(_A, "_last_received_from_actor_index")) _revenge_from = variable_struct_get(_A, "_last_received_from_actor_index");
            }
            var _target_idx = (!is_undefined(__battle_actor_index_of) ? __battle_actor_index_of(_D) : undefined);
            if (_revenge_hit && is_real(_revenge_from) && is_real(_target_idx) && floor(_revenge_from) == floor(_target_idx)) return 120;
        } catch (e_revenge) {}
        return 60;
    }

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
    // Psywave uses custom fixed-damage semantics in the damage application path.
    if (mid == 149) return 1;
    // Super Fang / Nature's Madness have their own damage semantics implemented in the damage application path.
    if (mid == 162 || mid == 717) return 1; // placeholder positive value so the resolver will call the damage path
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

    // Return / Frustration: power scales with friendship/happiness.
    if (mid == 216){
        var _happy_return = _friendship_value(_A);
        return clamp(floor(_happy_return * 2 / 5), 1, 102);
    }
    if (mid == 218){
        var _happy_frustration = _friendship_value(_A);
        return clamp(floor((255 - _happy_frustration) * 2 / 5), 1, 102);
    }

    // Crush Grip / Wring Out / Eruption / Flail / Reversal: power scales with target HP% or attacker's HP
    // Crush Grip (462) and Wring Out (378) � power increases as target's current HP decreases
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

    // Eruption (284) and Flail (175) and Reversal (179) � power increases as attacker's HP decreases (Eruption reverse)
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

    // Bide: releasing strike uses stored incoming damage and doubles it.
    if (mid == 117){
        try {
            if (is_struct(_A) && variable_struct_exists(_A, "_bide_state") && is_struct(variable_struct_get(_A, "_bide_state"))){
                var _bide_state = variable_struct_get(_A, "_bide_state");
                var _bide_damage = (variable_struct_exists(_bide_state, "damage") && is_real(variable_struct_get(_bide_state, "damage"))) ? floor(variable_struct_get(_bide_state, "damage")) : 0;
                if (_bide_damage > 0) return max(1, _bide_damage * 2);
            }
        } catch (e_bide_power) {}
        return 1;
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

function __battle_ability_action_list_contains(_list, _value){
    var _want = string_lower(string(_value));
    if (!is_array(_list)) _list = [string(_list)];
    for (var _i = 0; _i < array_length(_list); ++_i){
        if (string_lower(string(_list[_i])) == _want) return true;
    }
    return false;
}

function __battle_actor_has_type_name_for_ability(_actor, _type_name){
    try {
        var _tid = __battle_type_id_by_name_safe(_type_name);
        var _types = __battle_actor_type_ids(_actor);
        for (var _i = 0; _i < array_length(_types); ++_i){
            if (is_real(_types[_i]) && floor(_types[_i]) == floor(_tid)) return true;
        }
    } catch (e_type_match) {}
    return false;
}

function __battle_ability_blocks_switch(_pid, _switch_actor_index, _is_forced){
    if (_is_forced) return false;
    var _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B) || !variable_struct_exists(_B, "actor") || !is_array(variable_struct_get(_B, "actor"))) return false;
    var _actors = variable_struct_get(_B, "actor");
    if (!is_real(_switch_actor_index) || _switch_actor_index < 0 || _switch_actor_index >= array_length(_actors)) return false;
    var _leaver = _actors[_switch_actor_index];
    if (!is_struct(_leaver)) return false;
    var _leaver_side = __battle_actor_side(_switch_actor_index);
    for (var _i = 0; _i < array_length(_actors); ++_i){
        if (_i == _switch_actor_index) continue;
        var _holder = _actors[_i];
        if (!is_struct(_holder) || __battle_hp_now(_holder) <= 0) continue;
        if (__battle_actor_side(_i) == _leaver_side) continue;
        var _actions = [];
        try { _actions = __battle_actor_ability_actions(_holder, "switch_check"); } catch (e_switch_actions) { _actions = []; }
        for (var _ai = 0; _ai < array_length(_actions); ++_ai){
            var _act = _actions[_ai];
            if (!is_struct(_act)) continue;
            var _kind = variable_struct_exists(_act, "kind") ? string_lower(string(variable_struct_get(_act, "kind"))) : "";
            var _data = (variable_struct_exists(_act, "data") && is_struct(variable_struct_get(_act, "data"))) ? variable_struct_get(_act, "data") : {};
            var _blocked = false;
            if (_kind == "trap_opponents"){
                _blocked = true;
            } else if (_kind == "trap_grounded_opponents"){
                var _grounded = true;
                try {
                    var __fn_grounded = undefined;
                    if (variable_global_exists("__actor_is_grounded")) __fn_grounded = variable_global_get("__actor_is_grounded");
                    if (!is_undefined(__fn_grounded)) _grounded = __fn_grounded(_leaver);
                } catch (e_grounded_switch) { _grounded = true; }
                _blocked = _grounded;
            } else if (_kind == "trap_type_opponents"){
                var _trap_type = variable_struct_exists(_data, "type") ? string_lower(string(variable_struct_get(_data, "type"))) : "";
                _blocked = __battle_actor_has_type_name_for_ability(_leaver, _trap_type);
            }
            if (_blocked){
                try { __battle_queue_ability_action_dialog(_holder, _act, _leaver, {}); } catch (e_switch_dialog) {}
                return true;
            }
        }
    }
    return false;
}

function __battle_apply_switch_out_ability_actions(_pid, _actor_index, _actor){
    if (!is_struct(_actor)) return false;
    var _did = false;
    try {
        var _actions = __battle_actor_ability_actions(_actor, "on_switch_out");
        for (var _ai = 0; _ai < array_length(_actions); ++_ai){
            var _act = _actions[_ai];
            if (!is_struct(_act)) continue;
            var _kind = variable_struct_exists(_act, "kind") ? string_lower(string(variable_struct_get(_act, "kind"))) : "";
            var _data = (variable_struct_exists(_act, "data") && is_struct(variable_struct_get(_act, "data"))) ? variable_struct_get(_act, "data") : {};
            if (_kind == "cure_major_status"){
                if (__battle_ability_clear_major_status(_actor)){
                    try { __battle_queue_ability_action_dialog(_actor, _act, _actor, {}); } catch (e_switch_cure_dialog) {}
                    _did = true;
                }
            } else if (_kind == "heal_fraction"){
                var _frac = (variable_struct_exists(_data, "fraction") && is_real(variable_struct_get(_data, "fraction"))) ? variable_struct_get(_data, "fraction") : 0.333333;
                var _before = __battle_hp_now(_actor);
                var _maxhp = max(1, __battle_hp_max(_actor));
                if (_before > 0 && _before < _maxhp){
                    var _after = min(_maxhp, _before + max(1, floor(_maxhp * _frac)));
                    if (_after > _before){
                        __battle_set_hp_now(_actor, _after);
                        try { __battle_clear_fainted_if_healed(_actor); } catch (e_switch_heal_clear) {}
                        try { __battle_queue_ability_action_dialog(_actor, _act, _actor, {}); } catch (e_switch_heal_dialog) {}
                        _did = true;
                    }
                }
            }
        }
    } catch (e_switch_ability) {}
    return _did;
}

function __battle_ability_accuracy_multiplier(_actor, _target, _move_id, _is_attacker){
    var _out = 1.0;
    try {
        if (!is_struct(_actor) || is_undefined(__battle_actor_ability_actions)) return _out;
        var _pid_acc = __battle_resolve_pid_for_actor(_actor);
        var _move_dc = 0;
        try { if (!is_undefined(scr_move_damage_class_by_id)) _move_dc = scr_move_damage_class_by_id(_move_id); } catch (e_dc_acc) { _move_dc = 0; }
        var _move_type_name = "";
        try {
            var _type_id_acc = (!is_undefined(scr_move_type_id_by_id)) ? scr_move_type_id_by_id(_move_id, _actor) : -1;
            if (!is_undefined(__battle_type_name_by_id_safe)) _move_type_name = string_lower(string(__battle_type_name_by_id_safe(_type_id_acc)));
        } catch (e_type_acc) { _move_type_name = ""; }
        var _weather_id = "";
        try {
            if (__battle_weather_is_active(__battle_get_weather(_pid_acc)) && (is_undefined(__battle_weather_suppressed_by_ability) || !__battle_weather_suppressed_by_ability(_pid_acc))){
                _weather_id = __battle_weather_get_normalized_id(__battle_get_weather(_pid_acc));
            }
        } catch (e_weather_acc_ability) {}
        var _terrain_id = "";
        try {
            var __fn_terr_acc = undefined;
            if (variable_global_exists("__battle_get_terrain_state")) __fn_terr_acc = variable_global_get("__battle_get_terrain_state");
            var _terr_acc = (!is_undefined(__fn_terr_acc)) ? __fn_terr_acc(_pid_acc) : undefined;
            if (is_struct(_terr_acc) && variable_struct_exists(_terr_acc, "id")) _terrain_id = string_lower(string(variable_struct_get(_terr_acc, "id")));
        } catch (e_terr_acc) {}
        var _actions = __battle_actor_ability_actions(_actor, "accuracy_check");
        for (var _ai = 0; _ai < array_length(_actions); ++_ai){
            var _act = _actions[_ai];
            if (!is_struct(_act)) continue;
            var _kind = variable_struct_exists(_act, "kind") ? string_lower(string(variable_struct_get(_act, "kind"))) : "";
            var _data = (variable_struct_exists(_act, "data") && is_struct(variable_struct_get(_act, "data"))) ? variable_struct_get(_act, "data") : {};
            if (_is_attacker){
                if (_kind == "accuracy_multiplier"){
                    _out *= (variable_struct_exists(_data, "mult") && is_real(variable_struct_get(_data, "mult"))) ? variable_struct_get(_data, "mult") : 1;
                } else if (_kind == "physical_accuracy_multiplier" && is_real(_move_dc) && floor(_move_dc) == 2){
                    _out *= (variable_struct_exists(_data, "mult") && is_real(variable_struct_get(_data, "mult"))) ? variable_struct_get(_data, "mult") : 1;
                } else if (_kind == "no_guard"){
                    return 999;
                }
            } else {
                if (_kind == "weather_evasion_multiplier"){
                    var _wlist = variable_struct_exists(_data, "weather") ? variable_struct_get(_data, "weather") : [];
                    if (string_length(_weather_id) > 0 && __battle_ability_action_list_contains(_wlist, _weather_id)){
                        _out *= (variable_struct_exists(_data, "opponent_accuracy_mult") && is_real(variable_struct_get(_data, "opponent_accuracy_mult"))) ? variable_struct_get(_data, "opponent_accuracy_mult") : 1;
                    }
                } else if (_kind == "terrain_evasion_multiplier"){
                    var _tlist = variable_struct_exists(_data, "terrain") ? variable_struct_get(_data, "terrain") : [];
                    if (string_length(_terrain_id) > 0 && __battle_ability_action_list_contains(_tlist, _terrain_id)){
                        _out *= (variable_struct_exists(_data, "opponent_accuracy_mult") && is_real(variable_struct_get(_data, "opponent_accuracy_mult"))) ? variable_struct_get(_data, "opponent_accuracy_mult") : 1;
                    }
                } else if (_kind == "evasion_when_confused_multiplier"){
                    var _confused = false;
                    try {
                        if (!is_undefined(status_system_has_status)){
                            _confused = status_system_has_status(_actor, "confusion");
                            if (!_confused && variable_struct_exists(_actor, "mon") && is_struct(variable_struct_get(_actor, "mon"))) _confused = status_system_has_status(variable_struct_get(_actor, "mon"), "confusion");
                        }
                    } catch (e_conf_acc) { _confused = false; }
                    if (_confused) _out *= (variable_struct_exists(_data, "opponent_accuracy_mult") && is_real(variable_struct_get(_data, "opponent_accuracy_mult"))) ? variable_struct_get(_data, "opponent_accuracy_mult") : 1;
                }
            }
        }
    } catch (e_acc_ability) {}
    return _out;
}

// Determine whether a move hits considering accuracy/evasion stages
function __battle_can_hit_target(_A, _D, _move_id){
    try {
        if (variable_global_exists("DEV_FORCE_ACCURACY_HIT") && global.DEV_FORCE_ACCURACY_HIT == true) return true;
        if (!is_undefined(__battle_should_ignore_accuracy)){
            if (__battle_should_ignore_accuracy(_A, _D, _move_id)) return true;
        }
        var base_acc = __battle_move_accuracy(_move_id);
        // Read stages (if present) and compute multiplier using same stage table
        var acc_stage = 0; var eva_stage = 0;
        try {
            if (is_struct(_A) && variable_struct_exists(_A, "_stages") && is_struct(variable_struct_get(_A, "_stages"))){ var sA = variable_struct_get(_A, "_stages"); if (variable_struct_exists(sA, "accuracy")) acc_stage = variable_struct_get(sA, "accuracy"); }
        } catch (e_accA) { acc_stage = 0; }
        try {
            if (is_struct(_D) && variable_struct_exists(_D, "_stages") && is_struct(variable_struct_get(_D, "_stages"))){ var sD = variable_struct_get(_D, "_stages"); if (variable_struct_exists(sD, "evasion")) eva_stage = variable_struct_get(sD, "evasion"); }
        } catch (e_accD) { eva_stage = 0; }
        // Convert stages to multiplier using same stage formula
        var acc_mul = __battle_stage_multiplier(is_real(acc_stage) ? acc_stage : 0);
        var eva_mul = __battle_stage_multiplier(is_real(eva_stage) ? eva_stage : 0);
        // Effective accuracy = base_acc * (acc_mul / eva_mul)
        var eff_acc = base_acc * (acc_mul / max(0.0001, eva_mul));
        eff_acc = clamp(floor(eff_acc), 0, 100);
        try {
            var _atk_acc_mult = __battle_ability_accuracy_multiplier(_A, _D, _move_id, true);
            if (_atk_acc_mult >= 999) return true;
            var _def_acc_mult = __battle_ability_accuracy_multiplier(_D, _A, _move_id, false);
            eff_acc = clamp(floor(eff_acc * _atk_acc_mult * _def_acc_mult), 0, 100);
        } catch (e_acc_ability_apply) {}
        var _pid_weather = __battle_resolve_pid_for_actor(_A);
        try {
            var _gravity_turns = __battle_field_get_status_or(_pid_weather, "gravity", 0);
            if (is_real(_gravity_turns) && _gravity_turns > 0) eff_acc = clamp(floor(eff_acc * 5 / 3), 0, 100);
        } catch (e_gravity_acc) {}
        var _weather_acc = __battle_get_weather(_pid_weather);
        if (__battle_weather_is_active(_weather_acc)){
            var _wid_acc = __battle_weather_get_normalized_id(_weather_acc);
            if (is_real(_move_id) && floor(_move_id) == 87){
                if (_wid_acc == "rain") eff_acc = 100;
                else if (_wid_acc == "sun" || _wid_acc == "harsh-sun") eff_acc = 50;
            }
            if (_wid_acc == "fog") eff_acc = clamp(floor(eff_acc * 0.6), 0, 100);
        }
        try {
            if (is_struct(_A) && variable_struct_exists(_A, "_held_next_accuracy_multiplier") && is_real(variable_struct_get(_A, "_held_next_accuracy_multiplier"))){
                eff_acc = clamp(floor(eff_acc * real(variable_struct_get(_A, "_held_next_accuracy_multiplier"))), 0, 100);
                variable_struct_set(_A, "_held_next_accuracy_multiplier", undefined);
                if (variable_struct_exists(_A, "mon") && is_struct(variable_struct_get(_A, "mon"))) variable_struct_set(variable_struct_get(_A, "mon"), "_held_next_accuracy_multiplier", undefined);
            }
        } catch (e_micle_acc) {}
        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][accuracy] base=" + string(base_acc) + ", acc_stage=" + string(acc_stage) + ", eva_stage=" + string(eva_stage) + ", eff=" + string(eff_acc));
        var roll = irandom(99);
        return (roll < eff_acc);
    } catch (e) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][accuracy] compute failed: " + string(e)); return true; }
}
// (action helpers moved to battle_actions.gml)


function __battle_try_escape(_pid){
    var _B = __battle_ensure_slot(_pid);
    var _battle_type = (is_struct(_B) && variable_struct_exists(_B, "battle_type")) ? string(variable_struct_get(_B, "battle_type")) : "";
    var _versus = (is_struct(_B) && variable_struct_exists(_B, "versus_enabled") && variable_struct_get(_B, "versus_enabled") == true);
    if (_versus || _battle_type == "trainer"){
        try {
            if (!is_undefined(dialog2p_show_now)) dialog2p_show_now(_pid, "No! There's no running\nfrom a Trainer battle!");
            else if (!is_undefined(dialog2p_enqueue_text)) dialog2p_enqueue_text(_pid, "No! There's no running\nfrom a Trainer battle!", "No! There's no running\nfrom a Trainer battle!", "any");
        } catch (e_no_run) {}
        try { variable_struct_set(_B, "phase", "command"); } catch (e_no_run_phase) {}
        return;
    }
    var A0 = __battle_get_side_actor(_pid, 0, 0);
    var A1 = __battle_get_side_actor(_pid, 1, 0);
    if (!is_struct(A0) || !is_struct(A1)){
        _B.result = "escaped"; try { if (!is_undefined(dialog2p_show_now)) dialog2p_show_now(_pid, "Got away safely!"); else if (!is_undefined(dialog2p_enqueue_text)) dialog2p_enqueue_text(_pid, "Got away safely!", "Got away safely!", "any"); } catch (e_) {} _B._pending_close = true; return;
    }
    if (!variable_struct_exists(_B, "run_tries")) _B.run_tries = 0;
    // Use the stat getter to safely retrieve Speed (handles missing fields and fallbacks)
    var s0 = max(1, is_real(__battle_stat_get(A0, "spd")) ? __battle_stat_get(A0, "spd") : 30);
    var s1 = max(1, is_real(__battle_stat_get(A1, "spd")) ? __battle_stat_get(A1, "spd") : 30);
    var chance = clamp(floor((s0 * 128) / s1) + (30 * _B.run_tries), 0, 255);
    var roll = irandom(255);
    if (roll < chance){
        _B.result = "escaped";
        try { if (!is_undefined(dialog2p_show_now)) dialog2p_show_now(_pid, "Got away safely!\n"); else if (!is_undefined(dialog2p_enqueue_text)) dialog2p_enqueue_text(_pid, "Got away safely!\n", "Got away safely!\n", "any"); } catch (e_) {}
        _B._pending_close = true;
    } else {
        _B.run_tries += 1;
        // Failed escape: count as player's turn (player attempted to run),
        // queue enemy action so opponent still acts this turn.
    try { if (!is_undefined(dialog2p_show_now)) dialog2p_show_now(_pid, "Can't escape!"); else if (!is_undefined(dialog2p_enqueue_text)) dialog2p_enqueue_text(_pid, "Can't escape!", "Can't escape!", "any"); } catch (e_) {}
        _B.turn_action_player = undefined;
        _B.turn_action_enemy  = __battle_enemy_choose_action(_pid);
        _B.turn_queue = __battle_build_turn_actions(_pid);
        _B.turn_i = 0;
        _B.phase = "turn";
    }
}

// __battle_stub_dialog removed: dialog dispatch is handled by the DialogSystem APIs
// Use dialog2p_show_now(_pid, text) or dialog2p_enqueue_text/_enqueue for queued/gated messages.
function __battle_apply_pending_healing_wish_to_actor(_pid, _side_index, _actor){
    if (!is_struct(_actor)) return false;
    var _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B) || !variable_struct_exists(_B, "_pending_healing_wishes")) return false;
    var _pending = variable_struct_get(_B, "_pending_healing_wishes");
    if (!is_array(_pending) || array_length(_pending) <= 0) return false;

    var _side = floor(_side_index);
    var _keep = [];
    var _applied = false;
    for (var _hwi = 0; _hwi < array_length(_pending); ++_hwi){
        var _entry = _pending[_hwi];
        if (!is_struct(_entry)) continue;
        var _entry_side = (variable_struct_exists(_entry, "side") && is_real(variable_struct_get(_entry, "side"))) ? floor(variable_struct_get(_entry, "side")) : 0;
        if (!_applied && _entry_side == _side){
            var _before = max(0, __battle_hp_now(_actor));
            var _max = max(1, __battle_hp_max(_actor));
            __battle_set_hp_now(_actor, _max);
            try { __battle_clear_fainted_if_healed(_actor); } catch (e_hw_clear) {}
            try {
                if (!is_undefined(status_system_clear_status)){
                    var _clear_ids = ["poison", "toxic", "burn", "freeze", "paralysis", "paralyze", "sleep", "nightmare", "yawn", "confusion"];
                    for (var _hws = 0; _hws < array_length(_clear_ids); ++_hws){
                        var _sid = _clear_ids[_hws];
                        status_system_clear_status(_actor, _sid);
                        if (variable_struct_exists(_actor, "mon") && is_struct(variable_struct_get(_actor, "mon"))) status_system_clear_status(variable_struct_get(_actor, "mon"), _sid);
                    }
                }
            } catch (e_hw_status) {}
            try { __battle_request_animation_safe(_pid, { type: "heal", actor: _actor, target_index: _side, amount: max(0, _max - _before) }); } catch (e_hw_anim) {}
            try {
                var _hw_name = (variable_struct_exists(_actor, "name") ? string(variable_struct_get(_actor, "name")) : "The Pokemon");
                if (!is_undefined(dialog2p_enqueue)) dialog2p_enqueue(_pid, _hw_name + " was restored by Healing Wish!");
                else if (!is_undefined(dialog2p_enqueue_text)) dialog2p_enqueue_text(_pid, _hw_name + " was restored by Healing Wish!", _hw_name + " was restored by Healing Wish!", "any");
            } catch (e_hw_msg) {}
            _applied = true;
            continue;
        }
        array_push(_keep, _entry);
    }

    variable_struct_set(_B, "_pending_healing_wishes", _keep);
    return _applied;
}

function __battle_play_switch_in(_pid){
    var _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B) || !_B.sys_open) return;
    if (variable_struct_exists(_B, "_catch_anim")) _B._catch_anim = undefined;
    _B.phase = "switch_in";
    _B.phase_start_ms = current_time;
    _B.phase_progress = 0;
}

// Phase enter hook: you can add SFX here if needed
function __battle_on_phase_enter(_pid, _phase){
    var _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B)) return;
    if (string(_phase) == "command"){
        var _preserve_actions = false;
        try { _preserve_actions = (variable_struct_exists(_B, "_preserve_player_turn_actions_once") && variable_struct_get(_B, "_preserve_player_turn_actions_once") == true); } catch (e_cmd_preserve) { _preserve_actions = false; }
        if (!_preserve_actions) try { variable_struct_set(_B, "_player_turn_actions", []); } catch (e_cmd_actions) {}
        try { variable_struct_set(_B, "_command_pending_action", undefined); } catch (e_cmd_pending) {}
        try { variable_struct_set(_B, "_target_pick_targets", undefined); } catch (e_cmd_targets) {}
        try {
            if (variable_struct_exists(_B, "sys_ui") && is_struct(variable_struct_get(_B, "sys_ui"))){
                var _sys_ui = variable_struct_get(_B, "sys_ui");
                variable_struct_set(_sys_ui, "menu", "root");
                if (!_preserve_actions || !variable_struct_exists(_sys_ui, "selX") || !is_real(variable_struct_get(_sys_ui, "selX"))) variable_struct_set(_sys_ui, "selX", 0);
                if (!_preserve_actions || !variable_struct_exists(_sys_ui, "selY") || !is_real(variable_struct_get(_sys_ui, "selY"))) variable_struct_set(_sys_ui, "selY", 0);
            }
        } catch (e_cmd_sys_ui) {}
        try {
            if (__battle_uses_split_command_ui(_B)){
                var _player_pids_cmd = (variable_struct_exists(_B, "player_pids") && is_array(variable_struct_get(_B, "player_pids"))) ? variable_struct_get(_B, "player_pids") : [0, 1];
                if (!variable_struct_exists(_B, "_versus_ui") || !is_array(variable_struct_get(_B, "_versus_ui")) || array_length(variable_struct_get(_B, "_versus_ui")) < 2){
                    variable_struct_set(_B, "_versus_ui", [
                        { menu:"root", selX:0, selY:0, command_actor_index:0, command_pending_action:undefined, target_pick_targets:undefined, target_pick_index:0 },
                        { menu:"root", selX:0, selY:0, command_actor_index:0, command_pending_action:undefined, target_pick_targets:undefined, target_pick_index:0 }
                    ]);
                }
                var _vs_ui_cmd = variable_struct_get(_B, "_versus_ui");
                for (var _uii = 0; _uii < min(2, array_length(_vs_ui_cmd)); ++_uii){
                    var _ui_cmd = _vs_ui_cmd[_uii];
                    if (!is_struct(_ui_cmd)) _ui_cmd = { menu:"root", selX:0, selY:0, command_actor_index:0, command_pending_action:undefined, target_pick_targets:undefined, target_pick_index:0 };
                    variable_struct_set(_ui_cmd, "menu", "root");
                    variable_struct_set(_ui_cmd, "command_pending_action", undefined);
                    variable_struct_set(_ui_cmd, "target_pick_targets", undefined);
                    variable_struct_set(_ui_cmd, "target_pick_index", 0);
                    if (!_preserve_actions){
                        variable_struct_set(_ui_cmd, "selX", 0);
                        variable_struct_set(_ui_cmd, "selY", 0);
                    }
                    if (!_preserve_actions || !variable_struct_exists(_ui_cmd, "command_actor_index") || !is_real(variable_struct_get(_ui_cmd, "command_actor_index"))){
                        var _ui_pid = (_uii < array_length(_player_pids_cmd) && is_real(_player_pids_cmd[_uii])) ? floor(_player_pids_cmd[_uii]) : _uii;
                        var _first_ui_actor = __battle_next_command_actor_index(_ui_pid, -1);
                        variable_struct_set(_ui_cmd, "command_actor_index", (_first_ui_actor >= 0) ? _first_ui_actor : 0);
                    }
                    _vs_ui_cmd[_uii] = _ui_cmd;
                }
                variable_struct_set(_B, "_versus_ui", _vs_ui_cmd);
            }
        } catch (e_cmd_vs_ui) {}
        try {
            if (!_preserve_actions || !variable_struct_exists(_B, "_command_actor_index") || !is_real(variable_struct_get(_B, "_command_actor_index"))){
                var _first_actor = __battle_next_command_actor_index(_pid, -1);
                variable_struct_set(_B, "_command_actor_index", (_first_actor >= 0) ? _first_actor : 0);
            }
        } catch (e_cmd_actor) {}
        try { variable_struct_set(_B, "_preserve_player_turn_actions_once", false); } catch (e_cmd_preserve_clear) {}
    }
    return;
}

function __battle_queue_result_dialog_if_needed(_pid){
    var _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B)) return false;
    if (variable_struct_exists(_B, "_end_result_dialog_shown") && variable_struct_get(_B, "_end_result_dialog_shown")) return false;
    if (variable_struct_exists(_B, "_pending_status_msgs") && is_array(variable_struct_get(_B, "_pending_status_msgs")) && array_length(variable_struct_get(_B, "_pending_status_msgs")) > 0) return false;

    var _result = (variable_struct_exists(_B, "result") ? string(variable_struct_get(_B, "result")) : "");
    var _msg = "";
    switch (_result){
        case "win":
            _msg = "You won the battle!";
            break;
        case "lose":
            _msg = "You lost the battle!";
            break;
        case "draw":
            _msg = "The battle ended in a draw.";
            break;
    }
    if (string_length(_msg) <= 0) return false;

    var _pend = (variable_struct_exists(_B, "_pending_status_msgs") ? variable_struct_get(_B, "_pending_status_msgs") : []);
    if (!is_array(_pend)) _pend = [];
    array_push(_pend, _msg);
    variable_struct_set(_B, "_pending_status_msgs", _pend);
    variable_struct_set(_B, "_end_result_dialog_shown", true);
    return true;
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
            var _enemy_lead = __battle_get_side_actor(_pid, 1, 0);
            if (!is_undefined(pkicons_play_cry_by_mon) && is_struct(_enemy_lead) && variable_struct_exists(_enemy_lead, "mon")){
                var _aud_e = pkicons_play_cry_by_mon(variable_struct_get(_enemy_lead, "mon"));
                if (is_real(_aud_e) && _aud_e >= 0) { }
            }
            _B._cry_played_enemy = true;
        }
        if (p >= 1 && variable_struct_exists(_B, "battle_format") && string(variable_struct_get(_B, "battle_format")) == "double" && (!variable_struct_exists(_B, "_cry_played_enemy2") || !_B._cry_played_enemy2)){
            var _enemy_tail = __battle_get_side_actor(_pid, 1, 1);
            if (!is_undefined(pkicons_play_cry_by_mon) && is_struct(_enemy_tail) && variable_struct_exists(_enemy_tail, "mon")){
                var _aud_e2 = pkicons_play_cry_by_mon(variable_struct_get(_enemy_tail, "mon"));
                if (is_real(_aud_e2) && _aud_e2 >= 0) { }
            }
            _B._cry_played_enemy2 = true;
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
        if (p2 >= 1 && variable_struct_exists(_B, "battle_format") && string(variable_struct_get(_B, "battle_format")) == "double" && (!variable_struct_exists(_B, "_cry_played_player2") || !_B._cry_played_player2)){
            var _player_tail = __battle_get_side_actor(_pid, 0, 1);
            if (!is_undefined(pkicons_play_cry_by_mon) && is_struct(_player_tail) && variable_struct_exists(_player_tail, "mon")){
                var _aud_p2 = pkicons_play_cry_by_mon(variable_struct_get(_player_tail, "mon"));
                if (is_real(_aud_p2) && _aud_p2 >= 0) { }
            }
            _B._cry_played_player2 = true;
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

// API: switch the player's active Pok�mon to the party index with visuals
/// Switch the active player Pok�mon to a party index with visuals.
/// Params:
///  - _pid (int)
///  - _party_idx (int): target party index
///  - _opts (struct): { consume_turn?:bool=true, auto_apply?:bool=true }
/// Behavior: Plays switch_out/in animation, applies hazards on entry, may consume the player's turn.
function battle_switch_to(_pid, _party_idx, _opts){
    var _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B) || !variable_struct_exists(_B, "sys_open") || !variable_struct_get(_B, "sys_open")){
        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle_switch_to] rejected: no valid battle slot or sys_open=false (pid=" + string(_pid) + ")");
        return false;
    }
    var _phase_val = (variable_struct_exists(_B, "phase") ? string(variable_struct_get(_B, "phase")) : "<none>");
    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){
        show_debug_message("[battle_switch_to] pid=" + string(_pid) + ", party_idx=" + string(_party_idx) + ", sys_open=" + string(variable_struct_get(_B, "sys_open")) + ", phase=" + _phase_val);
    }
    // Allow forced swaps (e.g. replacement after faint) to bypass the 'command'
    // phase restriction so the player's replacement choice can be triggered
    // even if the battle is currently in a non-command phase.
    var _is_forced_switch = (is_struct(_opts) && variable_struct_exists(_opts, "forced") && variable_struct_get(_opts, "forced") == true);
    var _is_baton_pass_switch = (is_struct(_opts) && variable_struct_exists(_opts, "baton_pass") && variable_struct_get(_opts, "baton_pass") == true);
    if (_phase_val != "command" && !_is_forced_switch && !_is_baton_pass_switch){
        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle_switch_to] rejected: phase not 'command' (pid=" + string(_pid) + ", phase=" + _phase_val + ")");
        return false;
    } else if (_is_forced_switch || _is_baton_pass_switch){
        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle_switch_to] accepted forced switch while phase=" + _phase_val + " (pid=" + string(_pid) + ")");
    }

    var _switch_actor_index = 0;
    if (is_struct(_opts) && variable_struct_exists(_opts, "actor_index") && is_real(variable_struct_get(_opts, "actor_index"))){
        _switch_actor_index = floor(variable_struct_get(_opts, "actor_index"));
    } else if (variable_struct_exists(_B, "_pending_open_party_fainted_actor_index") && is_real(variable_struct_get(_B, "_pending_open_party_fainted_actor_index"))){
        _switch_actor_index = floor(variable_struct_get(_B, "_pending_open_party_fainted_actor_index"));
    } else if (__battle_uses_split_command_ui(_B)){
        var _switch_ui = __battle_command_ui_state(_B, _pid);
        if (is_struct(_switch_ui) && variable_struct_exists(_switch_ui, "command_actor_index") && is_real(variable_struct_get(_switch_ui, "command_actor_index"))) _switch_actor_index = floor(variable_struct_get(_switch_ui, "command_actor_index"));
    } else if (variable_struct_exists(_B, "_command_actor_index") && is_real(variable_struct_get(_B, "_command_actor_index"))){
        _switch_actor_index = floor(variable_struct_get(_B, "_command_actor_index"));
    }
    var _switch_actor_valid = (variable_struct_exists(_B, "actor") && is_array(variable_struct_get(_B, "actor")) && _switch_actor_index >= 0 && _switch_actor_index < array_length(variable_struct_get(_B, "actor")));
    if (_switch_actor_valid){
        if (__battle_uses_split_command_ui(_B)){
            _switch_actor_valid = (__battle_actor_owner_pid(_pid, _switch_actor_index) == _pid);
        } else {
            _switch_actor_valid = (__battle_actor_side(_switch_actor_index) == 0);
        }
    }
    if (!_switch_actor_valid){
        _switch_actor_index = __battle_actor_index_for_side_slot(_pid, 0, 0);
        if (!is_real(_switch_actor_index) || _switch_actor_index < 0) _switch_actor_index = 0;
    }

    var _requested_party_idx = (is_real(_party_idx) ? floor(_party_idx) : -1);
    if (_is_forced_switch && (_requested_party_idx < 0 || !__battle_party_index_is_usable(_pid, _requested_party_idx) || __battle_is_player_party_index_active(_pid, _requested_party_idx))){
        _requested_party_idx = __battle_pick_random_switchable_party_index(_pid, _switch_actor_index);
    }
    if (!is_real(_requested_party_idx) || _requested_party_idx < 0) return false;

    if (!_is_forced_switch){
        var __fn_jaw_block = undefined;
        if (variable_global_exists("__battle_jaw_lock_is_blocked")){
            __fn_jaw_block = variable_global_get("__battle_jaw_lock_is_blocked");
        }
        if (!is_undefined(__fn_jaw_block)){
            var _active_actor = undefined;
            if (variable_struct_exists(_B, "actor") && is_array(_B.actor) && _switch_actor_index >= 0 && _switch_actor_index < array_length(_B.actor)){
                _active_actor = _B.actor[_switch_actor_index];
            }
            if (is_struct(_active_actor) && __fn_jaw_block(_active_actor)){
                if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle_switch_to] rejected: Jaw Lock trap active (pid=" + string(_pid) + ")");
                if (!is_undefined(__status_request_dialog_for_mon)){
                    var _dialog_target = _active_actor;
                    if (is_struct(_dialog_target) && variable_struct_exists(_dialog_target, "mon") && is_struct(variable_struct_get(_dialog_target, "mon"))){
                        _dialog_target = variable_struct_get(_dialog_target, "mon");
                    }
                    var _nm_jl = "The Pok\u00e9mon";
                    if (is_struct(_dialog_target) && variable_struct_exists(_dialog_target, "name")){
                        _nm_jl = variable_struct_get(_dialog_target, "name");
                    } else if (is_struct(_active_actor) && variable_struct_exists(_active_actor, "name")){
                        _nm_jl = variable_struct_get(_active_actor, "name");
                    }
                    try { __status_request_dialog_for_mon(_dialog_target, string(_nm_jl) + " is locked in Jaw Lock and can't be switched out!", false); } catch (e_jdlg) {}
                }
                return false;
            }
        }
        var _active_actor_trap = undefined;
        if (variable_struct_exists(_B, "actor") && is_array(_B.actor) && _switch_actor_index >= 0 && _switch_actor_index < array_length(_B.actor)){
            _active_actor_trap = _B.actor[_switch_actor_index];
        }
        var _trap_active = false;
        if (!is_undefined(status_system_has_status) && is_struct(_active_actor_trap)){
            _trap_active = status_system_has_status(_active_actor_trap, "trap");
            if (!_trap_active && variable_struct_exists(_active_actor_trap, "mon") && is_struct(variable_struct_get(_active_actor_trap, "mon"))){
                _trap_active = status_system_has_status(variable_struct_get(_active_actor_trap, "mon"), "trap");
            }
        }
        if (_trap_active){
            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle_switch_to] rejected: trap active (pid=" + string(_pid) + ")");
            if (!is_undefined(__status_request_dialog_for_mon)){
                var _dialog_target_trap = _active_actor_trap;
                if (is_struct(_dialog_target_trap) && variable_struct_exists(_dialog_target_trap, "mon") && is_struct(variable_struct_get(_dialog_target_trap, "mon"))){
                    _dialog_target_trap = variable_struct_get(_dialog_target_trap, "mon");
                }
                var _nm_trap = "The Pokemon";
                if (is_struct(_dialog_target_trap) && variable_struct_exists(_dialog_target_trap, "name")){
                    _nm_trap = variable_struct_get(_dialog_target_trap, "name");
                } else if (is_struct(_active_actor_trap) && variable_struct_exists(_active_actor_trap, "name")){
                    _nm_trap = variable_struct_get(_active_actor_trap, "name");
                }
                try { __status_request_dialog_for_mon(_dialog_target_trap, string(_nm_trap) + " is trapped and can't be switched out!", false); } catch (e_tdlg) {}
            }
            return false;
        }
        if (__battle_ability_blocks_switch(_pid, _switch_actor_index, false)){
            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle_switch_to] rejected: ability trap active (pid=" + string(_pid) + ")");
            return false;
        }
    }
    try {
        var _switching_out_actor = undefined;
        if (variable_struct_exists(_B, "actor") && is_array(_B.actor) && _switch_actor_index >= 0 && _switch_actor_index < array_length(_B.actor)){
            _switching_out_actor = _B.actor[_switch_actor_index];
        }
        if (is_struct(_switching_out_actor)) __battle_apply_switch_out_ability_actions(_pid, _switch_actor_index, _switching_out_actor);
    } catch (e_switch_out_ability_player) {}

    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){
        show_debug_message("[battle_switch_to] pid=" + string(_pid) + ", party_idx=" + string(_requested_party_idx));
    }

    var _active_party_idx = __battle_find_player_party_active_index(_pid, _switch_actor_index);
    if (__battle_is_player_party_index_active(_pid, _requested_party_idx) || (is_real(_active_party_idx) && floor(_active_party_idx) == floor(_requested_party_idx))){
        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle_switch_to] rejected: target already active pid=" + string(_pid) + ", idx=" + string(_requested_party_idx));
        return false;
    }

    if (is_undefined(_opts)) _opts = {};
    if (variable_struct_exists(_B, "_catch_anim")) _B._catch_anim = undefined;
    _B._switch_target_idx = _requested_party_idx;
    _B._switch_opts = _opts;
    _B._switch_actor_index = _switch_actor_index;
    _B._switch_party_pid = _pid;
    // Start an intro sequence so trainer/pokemon "Go" animation and dialog can play.
    // After intro_player completes we'll transition into switch_in where the actual swap occurs.
    _B.phase = "intro_call";
    _B.phase_start_ms = current_time;
    _B.phase_progress = 0;
    // Prepare for a fresh switch: mark not yet applied so switch_in visuals can apply it mid-animation
    _B._switch_applied = false;
    _B._cry_played_player = false;
    _B._cry_queued_from_switch = true;
    // Mark that we want to enter switch_in immediately after the intro sequence completes
    variable_struct_set(_B, "_pending_switch_after_intro", true);
    // Ensure we have a battleAnim to render trainer/pok�mon intro during switch
    if (variable_global_exists("battleAnim") && sprite_exists(variable_global_get("battleAnim"))){
        _B.caller_battleAnim = variable_global_get("battleAnim");
    }
    // Optionally open a dialog now (dialog system will be handled during intro phases).
    try {
        var _Ptmp = party_ensure(_pid);
        var _incoming = undefined;
        if (is_struct(_Ptmp) && variable_struct_exists(_Ptmp, "mons") && is_array(_Ptmp.mons) && _requested_party_idx >= 0 && _requested_party_idx < array_length(_Ptmp.mons)) _incoming = _Ptmp.mons[_requested_party_idx];
        var incoming_name = "Pok\u00e9mon";
        if (is_struct(_incoming) && variable_struct_exists(_incoming, "name")) incoming_name = string(variable_struct_get(_incoming, "name"));
    var dlg_text = "Go. " + incoming_name + "!";
    if (!is_undefined(dialog2p_show_now)) { try { dialog2p_show_now(_pid, dlg_text); } catch(e_) { try { dialog2p_enqueue(_pid, dlg_text); } catch(e2){} }
        // Ensure dialog doesn't immediately advance from the same input press
        try {
            if (!is_undefined(dialog2p_is_open) && dialog2p_is_open(_pid) && variable_global_exists("DIALOG2P")){
                var _sess = (!is_undefined(dialog2p_ensure_pid)) ? dialog2p_ensure_pid(_pid) : global.DIALOG2P[_pid];
                if (is_struct(_sess)) variable_struct_set(_sess, "_open_grace_until", current_time + 300);
            }
        } catch (e_g) {}
        _B._dlg_active = true; }
    } catch (e_sw) {}
    return true;
}

// Ellipsize helper (uses current font)
function __battle_text_fit_ellipsis(_pid, _str, _max_px){
    var s = string(_str);
    if (string_width(s) <= _max_px) return s;
    var ell = "�";
    var n = string_length(s);
    while (n > 1){
        n -= 1;
        var cand = string_copy(s, 1, n) + ell;
        if (string_width(cand) <= _max_px) return cand;
    }
    return ell;
}

// Heal the player's party fully and clear all status effects (temporary defeat behavior).
function __battle_heal_party_full(_pid){
    var _P = (is_undefined(party_ensure) ? undefined : party_ensure(_pid));
    if (!is_struct(_P) || !variable_struct_exists(_P, "mons") || !is_array(_P.mons)) return false;
    var mlist = _P.mons;
    for (var i = 0; i < array_length(mlist); ++i){
        var M = mlist[i];
        if (!is_struct(M)) continue;
        // Determine max HP using common aliases
        var mh = 0;
        try {
            if (variable_struct_exists(M, "hp_max") && is_real(variable_struct_get(M, "hp_max"))) mh = max(mh, real(variable_struct_get(M, "hp_max")));
            if (variable_struct_exists(M, "maxhp") && is_real(variable_struct_get(M, "maxhp"))) mh = max(mh, real(variable_struct_get(M, "maxhp")));
            if (mh <= 0){
                // Fallback to current hp or a small default
                var cur = __battle_hp_now(M);
                if (is_real(cur) && cur > 0) mh = cur; else mh = 20;
            }
        } catch (e_hp) { mh = max(1, __battle_hp_now(M)); }
        // Set HP now to max and clear fainted flags
        __battle_set_hp_now(M, mh);
        if (!is_undefined(__battle_clear_fainted_if_healed)) __battle_clear_fainted_if_healed(M);
        // Clear primary status fields
        try { if (variable_struct_exists(M, "status_id")) variable_struct_set(M, "status_id", 0); } catch (e_sid) {}
        try { if (variable_struct_exists(M, "statuses")) variable_struct_set(M, "statuses", {}); } catch (e_ss) {}
        // Also try to clear actor-wrapper if present
        try {
            var _B = __battle_ensure_slot(_pid);
            if (is_struct(_B) && variable_struct_exists(_B, "actor") && is_array(variable_struct_get(_B, "actor"))){
                var acts = variable_struct_get(_B, "actor");
                for (var ai = 0; ai < array_length(acts); ++ai){
                    var act = acts[ai]; if (!is_struct(act)) continue;
                    if (variable_struct_exists(act, "mon") && variable_struct_get(act, "mon") == M){
                        if (variable_struct_exists(act, "statuses")) variable_struct_set(act, "statuses", {});
                        // Mirror HP on wrapper too
                        __battle_set_hp_now(act, mh);
                        if (!is_undefined(__battle_clear_fainted_if_healed)) __battle_clear_fainted_if_healed(act);
                    }
                }
            }
        } catch (e_aw) {}
    }
    return true;
}

function __battle_clone_stage_struct(_src){
    var _out = {};
    if (!is_struct(_src)) return _out;
    var _keys = variable_struct_get_names(_src);
    for (var _ki = 0; _ki < array_length(_keys); ++_ki){
        var _key = _keys[_ki];
        if (!variable_struct_exists(_src, _key)) continue;
        variable_struct_set(_out, _key, variable_struct_get(_src, _key));
    }
    return _out;
}

function __battle_apply_baton_pass_payload(_B, _actor, _actor_index){
    if (!is_struct(_B) || !is_struct(_actor)) return false;
    if (!variable_struct_exists(_B, "_baton_pass_pending")) return false;
    var _payload = variable_struct_get(_B, "_baton_pass_pending");
    if (!is_struct(_payload)) return false;
    var _owner = (variable_struct_exists(_payload, "actor_index") ? variable_struct_get(_payload, "actor_index") : undefined);
    if (!is_real(_owner) || _owner != _actor_index) return false;
    var _stages = (variable_struct_exists(_payload, "stages") ? variable_struct_get(_payload, "stages") : undefined);
    if (is_struct(_stages)) variable_struct_set(_actor, "_stages", __battle_clone_stage_struct(_stages));
    try { variable_struct_set(_B, "_baton_pass_pending", undefined); } catch (e_bp_clear) {}
    return true;
}

// Detect if a status message line looks like a stat stage change (e.g., "NAME ATK +1").
function __battle_is_stat_status_line(_s){
    var _txt = _s;
    if (is_struct(_s) && variable_struct_exists(_s, "text")) _txt = variable_struct_get(_s, "text");
    var t = string_upper(string_trim(string(_txt)));
    if (string_length(t) <= 0) return false;
    // Treat typical stat tokens as indicators; include ACCURACY/EVASION.
    var tokens = [" ATK ", " DEF ", " SPA ", " SPD ", " SPE ", " ACCURACY", " EVASION"];
    for (var i = 0; i < array_length(tokens); ++i){ if (string_pos(tokens[i], t) > 0) return true; }
    return false;
}

function __battle_pending_msg_text(_msg){
    if (is_struct(_msg) && variable_struct_exists(_msg, "text")) return string(variable_struct_get(_msg, "text"));
    return string(_msg);
}

function __battle_pending_msg_pid(_msg, _fallback_pid){
    if (is_struct(_msg) && variable_struct_exists(_msg, "pid") && is_real(variable_struct_get(_msg, "pid"))) return max(0, floor(variable_struct_get(_msg, "pid")));
    return _fallback_pid;
}

// From the head of _B._pending_status_msgs, coalesce consecutive stat lines into a single multi-line string.
// Returns a struct { text: <string>, consumed: <int> } or undefined if nothing to show.
function __battle_coalesce_head_stat_msgs(_B){
    if (!is_struct(_B) || !variable_struct_exists(_B, "_pending_status_msgs")) return undefined;
    var arr = variable_struct_get(_B, "_pending_status_msgs");
    if (!is_array(arr) || array_length(arr) <= 0) return undefined;
    var first = arr[0];
    if (!__battle_is_stat_status_line(first)){
        return { text: __battle_pending_msg_text(first), consumed: 1, pid: (is_struct(first) && variable_struct_exists(first, "pid") ? variable_struct_get(first, "pid") : undefined) };
    }
    var first_pid = __battle_pending_msg_pid(first, undefined);
    var lines = [];
    var consumed = 0;
    for (var i = 0; i < array_length(arr); ++i){
        var _line = arr[i];
        var _line_pid = __battle_pending_msg_pid(_line, first_pid);
        if (__battle_is_stat_status_line(_line) && (is_undefined(first_pid) || _line_pid == first_pid)){
            lines[array_length(lines)] = string_trim(__battle_pending_msg_text(_line));
            consumed += 1;
        } else break;
    }
    var combined = "";
    for (var j = 0; j < array_length(lines); ++j){
        if (j > 0) combined += "\n";
        combined += lines[j];
    }
    return { text: combined, consumed: max(1, consumed), pid: first_pid };
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

        if (!is_undefined(party_model_ensure_species_id)) A = party_model_ensure_species_id(A);
        if (!is_undefined(party_model_normalize_hp_fields)) A = party_model_normalize_hp_fields(A);

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

        try {
            if ((!variable_struct_exists(A, "ability_id") || !is_real(A.ability_id)) && variable_struct_exists(A, "species_id") && is_real(A.species_id) && !is_undefined(scr_poke_pick_ability)){
                var _party_ability_id = scr_poke_pick_ability(A.species_id, A.species_id * 1000 + (is_real(A.level) ? A.level : _lvl));
                if (is_real(_party_ability_id) && _party_ability_id > 0){
                    A.ability_id = _party_ability_id;
                    if (!is_undefined(scr_ability_name_by_id)) A.ability = scr_ability_name_by_id(_party_ability_id);
                }
            } else if (variable_struct_exists(A, "ability_id") && is_real(A.ability_id) && (!variable_struct_exists(A, "ability") || string_length(string(A.ability)) <= 0) && !is_undefined(scr_ability_name_by_id)){
                A.ability = scr_ability_name_by_id(A.ability_id);
            }
        } catch (e_party_ability) {}

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
        if (!variable_struct_exists(A, "active_turns") || !is_real(variable_struct_get(A, "active_turns"))) variable_struct_set(A, "active_turns", 0);
        if (!variable_struct_exists(A, "_was_hit_this_turn")) variable_struct_set(A, "_was_hit_this_turn", false);

        // Ensure `species` is the numeric id used by lookup tables. If a name string was stored in
        // `species`, prefer the numeric `species_id` when available to avoid runtime conversion errors.
        if (variable_struct_exists(A, "species_id") && is_real(A.species_id)){
            A.species = A.species_id;
        } else if (!variable_struct_exists(A, "species") && variable_struct_exists(A, "species_id")){
            A.species = A.species_id;
        }

    // Compute/refresh grounded snapshot on actor (and inner mon) if helper exists
    try {
        if (!is_undefined(scr_compute_grounded_flag)){
            var g = scr_compute_grounded_flag(A);
            variable_struct_set(A, "grounded", g);
            if (variable_struct_exists(A, "mon") && is_struct(variable_struct_get(A, "mon"))) variable_struct_set(variable_struct_get(A, "mon"), "grounded", g);
        }
    } catch (e_gac) { /* ignore */ }

    // Give actor a persistent UID for identification across lookups
    try { if (!variable_struct_exists(A, "_uid") || !is_real(A._uid)) { if (!variable_global_exists("_B_actor_uid_counter")) global._B_actor_uid_counter = 1; A._uid = global._B_actor_uid_counter; global._B_actor_uid_counter += 1; } } catch (e_uid) {}
    // Clear any residual copycat history on this actor when created
    try { variable_struct_set(A, "_last_moves", []); } catch (e_cl) {}
    try { variable_struct_set(A, "_last_moves_used", []); } catch (e_clu) {}
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

function __battle_slot_has_active_uproar(_pid){
    try {
        var _B = __battle_ensure_slot(_pid);
        if (!is_struct(_B) || !variable_struct_exists(_B, "actor") || !is_array(variable_struct_get(_B, "actor"))) return false;
        var _actors = variable_struct_get(_B, "actor");
        for (var _ai = 0; _ai < array_length(_actors); ++_ai){
            var _actor = _actors[_ai];
            if (!is_struct(_actor) || !variable_struct_exists(_actor, "_locked_move")) continue;
            var _lock = variable_struct_get(_actor, "_locked_move");
            if (!is_struct(_lock)) continue;
            if (variable_struct_exists(_lock, "wake_field_sleepers") && variable_struct_get(_lock, "wake_field_sleepers") == true && variable_struct_exists(_lock, "remaining") && is_real(variable_struct_get(_lock, "remaining")) && variable_struct_get(_lock, "remaining") > 0) return true;
        }
    } catch (e_uproar_scan) {}
    return false;
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

    try {
        if (!is_undefined(scr_poke_pick_ability)){
            var _wild_ability_id = scr_poke_pick_ability(_sp, _sp * 1000 + _lvl);
            if (is_real(_wild_ability_id) && _wild_ability_id > 0){
                _actor.ability_id = _wild_ability_id;
                if (!is_undefined(scr_ability_name_by_id)) _actor.ability = scr_ability_name_by_id(_wild_ability_id);
                _actor.mon.ability_id = _wild_ability_id;
                _actor.mon.ability = _actor.ability;
            }
        }
    } catch (e_wild_ability) {}

    // Ensure the wild mon has canonical fields so downstream code can query growth/exp reliably
    // Provide numeric species aliases
    _actor.species = _sp;
    if (!variable_struct_exists(_actor.mon, "species_id") || !is_real(_actor.mon.species_id)) _actor.mon.species_id = _sp;

    // Compute grounded snapshot for wild actor (based on type; ability may be unknown)
    try {
        if (!is_undefined(scr_compute_grounded_flag)){
            var g = scr_compute_grounded_flag(_actor);
            variable_struct_set(_actor, "grounded", g);
            if (variable_struct_exists(_actor, "mon") && is_struct(variable_struct_get(_actor, "mon"))) variable_struct_set(variable_struct_get(_actor, "mon"), "grounded", g);
        }
    } catch (e_gwild) { /* ignore */ }
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
    function __battle_stat_apply_speed_field_mod(_actor, _speed_value){
        var _spd_out = _speed_value;
        try {
            if (!is_struct(_actor) || !is_real(_spd_out)) return _spd_out;
            var _pid_speed = undefined;
            if (!is_undefined(__status_find_battle_pid)) _pid_speed = __status_find_battle_pid(_actor);
            if (!is_real(_pid_speed)) return _spd_out;
            try {
                if (!is_undefined(__battle_actor_has_any_ability) && !is_undefined(__battle_get_weather) && !is_undefined(__battle_weather_is_active)){
                    var _weather_speed = __battle_get_weather(_pid_speed);
                    var _weather_speed_suppressed = false;
                    try { if (!is_undefined(__battle_weather_suppressed_by_ability)) _weather_speed_suppressed = __battle_weather_suppressed_by_ability(_pid_speed); } catch (e_speed_suppress) { _weather_speed_suppressed = false; }
                    if (!_weather_speed_suppressed && __battle_weather_is_active(_weather_speed)){
                        var _wid_speed = __battle_weather_get_normalized_id(_weather_speed);
                        var _used_weather_speed_action = false;
                        if (!is_undefined(__battle_actor_ability_actions)){
                            var _speed_actions = __battle_actor_ability_actions(_actor, "speed_calc");
                            for (var _sai = 0; _sai < array_length(_speed_actions); ++_sai){
                                var _sact = _speed_actions[_sai];
                                if (!is_struct(_sact)) continue;
                                var _skind = variable_struct_exists(_sact, "kind") ? string_lower(string(variable_struct_get(_sact, "kind"))) : "";
                                if (_skind != "weather_speed_multiplier") continue;
                                var _sdata = (variable_struct_exists(_sact, "data") && is_struct(variable_struct_get(_sact, "data"))) ? variable_struct_get(_sact, "data") : {};
                                var _weather_list = variable_struct_exists(_sdata, "weather") ? variable_struct_get(_sdata, "weather") : [];
                                if (!is_array(_weather_list)) _weather_list = [string(_weather_list)];
                                var _match_weather = false;
                                for (var _wi = 0; _wi < array_length(_weather_list); ++_wi){
                                    if (string_lower(string(_weather_list[_wi])) == _wid_speed){ _match_weather = true; break; }
                                }
                                if (_match_weather){
                                    var _smult = (variable_struct_exists(_sdata, "mult") && is_real(variable_struct_get(_sdata, "mult"))) ? variable_struct_get(_sdata, "mult") : 1;
                                    _spd_out *= _smult;
                                    _used_weather_speed_action = true;
                                }
                            }
                        }
                        if (!_used_weather_speed_action){
                            if (_wid_speed == "rain" && __battle_actor_has_any_ability(_actor, ["swift-swim"])) _spd_out *= 2;
                            if ((_wid_speed == "sun" || _wid_speed == "harsh-sun") && __battle_actor_has_any_ability(_actor, ["chlorophyll"])) _spd_out *= 2;
                            if (_wid_speed == "sandstorm" && __battle_actor_has_any_ability(_actor, ["sand-rush"])) _spd_out *= 2;
                            if ((_wid_speed == "hail" || _wid_speed == "snow") && __battle_actor_has_any_ability(_actor, ["slush-rush"])) _spd_out *= 2;
                        }
                    }
                }
            } catch (e_speed_ability) {}
            try {
                if (!is_undefined(__battle_actor_ability_actions)){
                    var _status_speed_actions = __battle_actor_ability_actions(_actor, "speed_calc");
                    for (var _qfi = 0; _qfi < array_length(_status_speed_actions); ++_qfi){
                        var _qfact = _status_speed_actions[_qfi];
                        if (!is_struct(_qfact)) continue;
                        var _qfkind = variable_struct_exists(_qfact, "kind") ? string_lower(string(variable_struct_get(_qfact, "kind"))) : "";
                        if (_qfkind != "speed_when_status_multiplier") continue;
                        if (!is_undefined(__battle_actor_has_major_status) && !__battle_actor_has_major_status(_actor)) continue;
                        var _qfdata = (variable_struct_exists(_qfact, "data") && is_struct(variable_struct_get(_qfact, "data"))) ? variable_struct_get(_qfact, "data") : {};
                        var _qfmult = (variable_struct_exists(_qfdata, "mult") && is_real(variable_struct_get(_qfdata, "mult"))) ? variable_struct_get(_qfdata, "mult") : 1;
                        _spd_out *= _qfmult;
                    }
                }
            } catch (e_status_speed_ability) {}
            try {
                if (!is_undefined(__battle_actor_ability_actions)){
                    var _generic_speed_actions = __battle_actor_ability_actions(_actor, "speed_calc");
                    var _terrain_id_speed = "";
                    try {
                        var __fn_terrain_speed = undefined;
                        if (variable_global_exists("__battle_get_terrain_state")) __fn_terrain_speed = variable_global_get("__battle_get_terrain_state");
                        var _terr_speed = (!is_undefined(__fn_terrain_speed)) ? __fn_terrain_speed(_pid_speed) : undefined;
                        if (is_struct(_terr_speed) && variable_struct_exists(_terr_speed, "id")) _terrain_id_speed = string_lower(string(variable_struct_get(_terr_speed, "id")));
                    } catch (e_terrain_speed_read) {}
                    for (var _gsi = 0; _gsi < array_length(_generic_speed_actions); ++_gsi){
                        var _gsact = _generic_speed_actions[_gsi];
                        if (!is_struct(_gsact)) continue;
                        var _gskind = variable_struct_exists(_gsact, "kind") ? string_lower(string(variable_struct_get(_gsact, "kind"))) : "";
                        var _gsdata = (variable_struct_exists(_gsact, "data") && is_struct(variable_struct_get(_gsact, "data"))) ? variable_struct_get(_gsact, "data") : {};
                        if (_gskind == "speed_after_item_loss_multiplier"){
                            var _lost = false;
                            try { _lost = (variable_struct_exists(_actor, "_consumed_item") || variable_struct_exists(_actor, "_item_lost") || (variable_struct_exists(_actor, "item_lost") && variable_struct_get(_actor, "item_lost") == true)); } catch (e_lost) { _lost = false; }
                            if (_lost){
                                var _lost_mult = (variable_struct_exists(_gsdata, "mult") && is_real(variable_struct_get(_gsdata, "mult"))) ? variable_struct_get(_gsdata, "mult") : 2;
                                _spd_out *= _lost_mult;
                            }
                        } else if (_gskind == "early_turn_attack_speed_multiplier"){
                            var _limit_speed_turns = (variable_struct_exists(_gsdata, "turns") && is_real(variable_struct_get(_gsdata, "turns"))) ? variable_struct_get(_gsdata, "turns") : 5;
                            var _actor_active_turns = (variable_struct_exists(_actor, "active_turns") && is_real(variable_struct_get(_actor, "active_turns"))) ? variable_struct_get(_actor, "active_turns") : 0;
                            if (_actor_active_turns < _limit_speed_turns){
                                var _early_speed_mult = (variable_struct_exists(_gsdata, "speed_mult") && is_real(variable_struct_get(_gsdata, "speed_mult"))) ? variable_struct_get(_gsdata, "speed_mult") : 0.5;
                                _spd_out *= _early_speed_mult;
                            }
                        } else if (_gskind == "terrain_speed_multiplier"){
                            var _terr_list = variable_struct_exists(_gsdata, "terrain") ? variable_struct_get(_gsdata, "terrain") : [];
                            if (!is_array(_terr_list)) _terr_list = [string(_terr_list)];
                            var _terr_match = false;
                            for (var _tri = 0; _tri < array_length(_terr_list); ++_tri){
                                if (string_lower(string(_terr_list[_tri])) == _terrain_id_speed){ _terr_match = true; break; }
                            }
                            if (_terr_match){
                                var _terr_mult = (variable_struct_exists(_gsdata, "mult") && is_real(variable_struct_get(_gsdata, "mult"))) ? variable_struct_get(_gsdata, "mult") : 1;
                                _spd_out *= _terr_mult;
                            }
                        }
                    }
                }
            } catch (e_generic_speed_ability) {}
            var _side_speed = 0;
            if (variable_struct_exists(_actor, "actor_index") && is_real(variable_struct_get(_actor, "actor_index"))) _side_speed = __battle_field_side_index_for_actor(variable_struct_get(_actor, "actor_index"));
            var _tailwind_turns = __battle_field_get_side_status_or(_pid_speed, _side_speed, "tailwind", 0);
            if (is_real(_tailwind_turns) && _tailwind_turns > 0) _spd_out *= 2;
        } catch (e_speed_field) {}
        return _spd_out;
    }

    // Pull from mon if present, else derive from level
    var lvl = (is_struct(_A) && is_real(_A.level)) ? _A.level : 5;
    function __battle_stat_raw_value(_ent, _want){
        if (!is_struct(_ent)) return undefined;
        if (_want == "atk"){
            if (variable_struct_exists(_ent, "atk") && is_real(variable_struct_get(_ent, "atk"))) return variable_struct_get(_ent, "atk");
            if (variable_struct_exists(_ent, "attack") && is_real(variable_struct_get(_ent, "attack"))) return variable_struct_get(_ent, "attack");
        } else if (_want == "def"){
            if (variable_struct_exists(_ent, "def") && is_real(variable_struct_get(_ent, "def"))) return variable_struct_get(_ent, "def");
            if (variable_struct_exists(_ent, "defense") && is_real(variable_struct_get(_ent, "defense"))) return variable_struct_get(_ent, "defense");
        } else if (_want == "spa"){
            if (variable_struct_exists(_ent, "spa") && is_real(variable_struct_get(_ent, "spa"))) return variable_struct_get(_ent, "spa");
            if (variable_struct_exists(_ent, "spatk") && is_real(variable_struct_get(_ent, "spatk"))) return variable_struct_get(_ent, "spatk");
            if (variable_struct_exists(_ent, "sp_atk") && is_real(variable_struct_get(_ent, "sp_atk"))) return variable_struct_get(_ent, "sp_atk");
            if (variable_struct_exists(_ent, "special_attack") && is_real(variable_struct_get(_ent, "special_attack"))) return variable_struct_get(_ent, "special_attack");
        } else if (_want == "spdef"){
            if (variable_struct_exists(_ent, "spd") && is_real(variable_struct_get(_ent, "spd"))) return variable_struct_get(_ent, "spd");
            if (variable_struct_exists(_ent, "spdef") && is_real(variable_struct_get(_ent, "spdef"))) return variable_struct_get(_ent, "spdef");
            if (variable_struct_exists(_ent, "sp_def") && is_real(variable_struct_get(_ent, "sp_def"))) return variable_struct_get(_ent, "sp_def");
            if (variable_struct_exists(_ent, "special_defense") && is_real(variable_struct_get(_ent, "special_defense"))) return variable_struct_get(_ent, "special_defense");
        } else if (_want == "spd" || _want == "spe"){
            if (variable_struct_exists(_ent, "spe") && is_real(variable_struct_get(_ent, "spe"))) return variable_struct_get(_ent, "spe");
            if (variable_struct_exists(_ent, "speed") && is_real(variable_struct_get(_ent, "speed"))) return variable_struct_get(_ent, "speed");
        }
        if (variable_struct_exists(_ent, "mon") && is_struct(variable_struct_get(_ent, "mon"))) return __battle_stat_raw_value(variable_struct_get(_ent, "mon"), _want);
        return undefined;
    }
    try {
        if (is_struct(_A) && variable_struct_exists(_A, "_stages") && is_struct(variable_struct_get(_A, "_stages"))){
            var _stage_key_top = undefined;
            if (_stat == "atk") _stage_key_top = "atk";
            else if (_stat == "def") _stage_key_top = "def";
            else if (_stat == "spa") _stage_key_top = "spa";
            else if (_stat == "spdef") _stage_key_top = "spd";
            else if (_stat == "spd" || _stat == "spe") _stage_key_top = "spe";
            var _stages_top = variable_struct_get(_A, "_stages");
            if (!is_undefined(_stage_key_top) && variable_struct_exists(_stages_top, _stage_key_top) && is_real(variable_struct_get(_stages_top, _stage_key_top))){
                var _raw_top = __battle_stat_raw_value(_A, _stat);
                if (is_real(_raw_top) && _raw_top > 0){
                    var _stage_val_top = floor(_raw_top * __battle_stage_multiplier(variable_struct_get(_stages_top, _stage_key_top)));
                    if (_stat == "spd" || _stat == "spe"){
                        try {
                            if (!is_undefined(status_system_has_status)){
                                if (status_system_has_status(_A, "paralysis") || status_system_has_status(_A, "paralyze")) _stage_val_top = floor(_stage_val_top / 2);
                                else if (variable_struct_exists(_A, "mon") && is_struct(variable_struct_get(_A, "mon")) && (status_system_has_status(variable_struct_get(_A, "mon"), "paralysis") || status_system_has_status(variable_struct_get(_A, "mon"), "paralyze"))) _stage_val_top = floor(_stage_val_top / 2);
                            }
                        } catch (e_stage_speed_status) {}
                        _stage_val_top = __battle_stat_apply_speed_field_mod(_A, _stage_val_top);
                    }
                    return max(1, _stage_val_top);
                }
            }
        }
    } catch (e_stage_top) {}
    // Only check exact assigned fields. For speed, use `spe` only (actor then mon).
    if (is_struct(_A)){
        if (_stat == "spd"){
            if (variable_struct_exists(_A, "spe") && is_real(_A.spe)){
                var _val = _A.spe;
                // paralysis halves Speed (accept both canonical 'paralysis' and legacy 'paralyze')
                try {
                    if (!is_undefined(status_system_has_status)){
                        if (status_system_has_status(_A, "paralysis") || status_system_has_status(_A, "paralyze")) _val = floor(_val / 2);
                        else {
                            // also check inner mon if actor wrapper provided
                            var _inner = (variable_struct_exists(_A, "mon") ? variable_struct_get(_A, "mon") : undefined);
                            if (!is_undefined(_inner) && status_system_has_status(_inner, "paralysis")) _val = floor(_val / 2);
                        }
                    }
                } catch (e_p) {}
                _val = __battle_stat_apply_speed_field_mod(_A, _val);
                return _val;
            }
        } else if (_stat == "atk"){
            if (variable_struct_exists(_A, "atk") && is_real(_A.atk)) return _A.atk;
        } else if (_stat == "def"){
            if (variable_struct_exists(_A, "def") && is_real(_A.def)) return _A.def;
        } else if (_stat == "spa"){
            if (variable_struct_exists(_A, "spa") && is_real(_A.spa)) return _A.spa;
            if (variable_struct_exists(_A, "spatk") && is_real(_A.spatk)) return _A.spatk;
        } else if (_stat == "spdef"){
            if (variable_struct_exists(_A, "spd") && is_real(_A.spd)) return _A.spd;
            if (variable_struct_exists(_A, "spdef") && is_real(_A.spdef)) return _A.spdef;
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
        if (_stat=="spa"){
            if (variable_struct_exists(m,"spa") && is_real(m.spa)) return m.spa;
            if (variable_struct_exists(m,"spatk") && is_real(m.spatk)) return m.spatk;
            if (variable_struct_exists(m,"sp_atk") && is_real(m.sp_atk)) return m.sp_atk;
        }
        if (_stat=="spdef"){
            if (variable_struct_exists(m,"spd") && is_real(m.spd)) return m.spd;
            if (variable_struct_exists(m,"spdef") && is_real(m.spdef)) return m.spdef;
            if (variable_struct_exists(m,"sp_def") && is_real(m.sp_def)) return m.sp_def;
        }
        if (_stat=="spd"){
            if (variable_struct_exists(m,"spe") && is_real(m.spe)){
                var _spv = m.spe;
                try {
                    if (!is_undefined(status_system_has_status)){
                        if (status_system_has_status(m, "paralysis") || status_system_has_status(m, "paralyze")) _spv = floor(_spv / 2);
                    }
                } catch (e_p2) {}
                _spv = __battle_stat_apply_speed_field_mod(_A, _spv);
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
        if (_stat=="spa"){
            if (variable_struct_exists(m,"special_attack") && is_real(m.special_attack)) return m.special_attack;
            if (variable_struct_exists(m,"sp_attack") && is_real(m.sp_attack)) return m.sp_attack;
        }
        if (_stat=="spdef"){
            if (variable_struct_exists(m,"special_defense") && is_real(m.special_defense)) return m.special_defense;
            if (variable_struct_exists(m,"sp_defense") && is_real(m.sp_defense)) return m.sp_defense;
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
            if (basev > 0){
                var _staged_val = floor(basev * mult);
                if (_stat == "spd" || _stat == "spe") _staged_val = __battle_stat_apply_speed_field_mod(_A, _staged_val);
                return _staged_val;
            }
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
// Canonical HP/faint helpers � read/write helpers that understand both
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
// Resolve an entity's maximum HP, supporting both actor and inner mon shapes
function __battle_hp_max(_ent){
    try {
        if (is_struct(_ent)){
            // Prefer actor-level hp_max, then maxhp
            if (variable_struct_exists(_ent, "hp_max") && is_real(variable_struct_get(_ent, "hp_max"))) return floor(variable_struct_get(_ent, "hp_max"));
            if (variable_struct_exists(_ent, "maxhp") && is_real(variable_struct_get(_ent, "maxhp"))) return floor(variable_struct_get(_ent, "maxhp"));
            // Fallback to inner mon
            if (variable_struct_exists(_ent, "mon") && is_struct(variable_struct_get(_ent, "mon"))){
                var m = variable_struct_get(_ent, "mon");
                if (variable_struct_exists(m, "hp_max") && is_real(variable_struct_get(m, "hp_max"))) return floor(variable_struct_get(m, "hp_max"));
                if (variable_struct_exists(m, "maxhp") && is_real(variable_struct_get(m, "maxhp"))) return floor(variable_struct_get(m, "maxhp"));
            }
        }
    } catch (e_hpm) {}
    return 1;
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
            if (variable_global_exists("DATA_DEBUG_VERBOSE") && global.DATA_DEBUG_VERBOSE) show_debug_message("[battle][sound] hit-effect triggered for " + _ename + ", hp_before=" + string(_before) + ", hp_after=" + string(_after) + ", mult=" + string(_mult));
        } catch (ee) { /* ignore */ }
        var mult = (is_real(_mult) ? _mult : 1.0);
    if (variable_global_exists("DATA_DEBUG_VERBOSE") && global.DATA_DEBUG_VERBOSE) show_debug_message("[battle][sound] trigger mult=" + string(mult) + ", audio_play_sound?=" + string(!is_undefined(audio_play_sound)));
        // Directly call the imported sound resources by name as requested.
        try {
            if (!is_undefined(audio_play_sound)){
                if (mult > 1.0){
                    audio_play_sound(snd_SuperEffective, 1, false);
                    if (variable_global_exists("DATA_DEBUG_VERBOSE") && global.DATA_DEBUG_VERBOSE) show_debug_message("[battle][sound] played snd_SuperEffective");
                } else if (mult < 1.0 && mult > 0.0){
                    audio_play_sound(snd_NotVeryEffective, 1, false);
                    if (variable_global_exists("DATA_DEBUG_VERBOSE") && global.DATA_DEBUG_VERBOSE) show_debug_message("[battle][sound] played snd_NotVeryEffective");
                } else {
                    audio_play_sound(snd_Effective, 1, false);
                    if (variable_global_exists("DATA_DEBUG_VERBOSE") && global.DATA_DEBUG_VERBOSE) show_debug_message("[battle][sound] played snd_Effective");
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

    // base formula (Pok�mon-like, simplified)
    var base = floor( (((2*L/5 + 2) * _power * Atk) / max(1,Def)) / 50 ) + 2;

    // variance 0.85..1.00
    var variance = 0.85 + random(0.15);
    var dmg = floor(base * variance);

    var _crit_stage = 0;
    try {
        var _crit_eid = undefined;
        if (!is_undefined(__battle_move_effect_id_safe)) _crit_eid = __battle_move_effect_id_safe(_move_id);
        if (is_real(_crit_eid) && (_crit_eid == 44 || _crit_eid == 201 || _crit_eid == 210)) _crit_stage += 1;
        if (is_struct(_A) && variable_struct_exists(_A, "_focus_energy_level") && is_real(variable_struct_get(_A, "_focus_energy_level"))) _crit_stage += max(0, floor(variable_struct_get(_A, "_focus_energy_level")) + 1);
    } catch (e_crit_stage) { _crit_stage = 0; }
    _crit_stage = clamp(_crit_stage, 0, 3);
    var _crit_table = [4.167, 12.5, 50, 100];
    var _crit_chance = _crit_table[_crit_stage];
    var _crit_roll = random(100);
    try {
        if (variable_global_exists("DEV_FORCE_CRIT_ROLL_100") && is_real(global.DEV_FORCE_CRIT_ROLL_100) && global.DEV_FORCE_CRIT_ROLL_100 >= 0){
            _crit_roll = real(global.DEV_FORCE_CRIT_ROLL_100);
        }
    } catch (e_crit_force) {}
    var crit = (_crit_roll < _crit_chance);
    var critMul = crit ? 1.5 : 1.0;
    dmg = floor(dmg * critMul);
    try {
        if (is_struct(_A) && variable_struct_exists(_A, "actor_index") && __battle_actor_side(variable_struct_get(_A, "actor_index")) == 1){
            var _diff_dmg = battle_difficulty();
            if (_diff_dmg == "easy") dmg = floor(dmg * 0.85);
            else if (_diff_dmg == "very_hard") dmg = floor(dmg * 1.15);
        }
    } catch (e_diff_dmg) {}

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
    try {
        if (is_real(cur_hp) && cur_hp > 0 && is_real(newhp) && newhp <= 0 && variable_struct_exists(T, "_enduring") && variable_struct_get(T, "_enduring") == true){
            newhp = 1;
            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){
                var _tname_endure = variable_struct_exists(T, "name") ? string(variable_struct_get(T, "name")) : "target";
                show_debug_message("[battle][endure] " + _tname_endure + " endured the hit at 1 HP");
            }
        }
    } catch (e_endure_guard) { if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][endure] damage guard failed: " + string(e_endure_guard)); }
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
/// Return the next alive party index for a player, excluding the active slot.
/// Params: _pid (int)
/// Returns: int index >= 0 if found, else -1 when no usable Pok�mon remain.
function __party_find_next_alive(_pid){
    if (is_undefined(party_ensure)) return -1;
    var P = party_ensure(_pid);
    if (!is_struct(P) || !is_array(P.mons)) return -1;
    var B = __battle_ensure_slot(_pid);
    var A0 = (is_struct(B) && is_array(B.actor)) ? B.actor[0] : undefined;
    var A1 = (is_struct(B) && is_array(B.actor) && array_length(B.actor) > 1) ? B.actor[1] : undefined;
    for (var i=0;i<array_length(P.mons);++i){
        var m = P.mons[i];
        if (!is_struct(m)) continue;
        // Prefer canonical hp_now when available; fall back to hp. Use battle helper to normalize.
        var mhp = __battle_hp_now(m);
        if (is_real(mhp) && mhp > 0){
            // skip if this is already the current actor's mon
            try { if (is_struct(A0) && variable_struct_exists(A0, "mon") && variable_struct_get(A0, "mon") == m) continue; } catch (e_cmp) {}
            try { if (is_struct(A1) && variable_struct_exists(A1, "mon") && variable_struct_get(A1, "mon") == m) continue; } catch (e_cmp2) {}
            return i;
        }
    }
    return -1;
}

function __battle_party_has_usable_mon(_pid){
    if (is_undefined(party_ensure)) return false;
    var _P = party_ensure(_pid);
    if (!is_struct(_P) || !is_array(_P.mons)) return false;
    for (var _i = 0; _i < array_length(_P.mons); ++_i){
        var _mon = _P.mons[_i];
        if (!is_struct(_mon)) continue;
        var _hp = __battle_hp_now(_mon);
        if (is_real(_hp) && _hp > 0) return true;
    }
    return false;
}

function __battle_player_active_faint_state(_pid){
    var _B = __battle_ensure_slot(_pid);
    var _indices = [];
    var _is_double = (is_struct(_B) && variable_struct_exists(_B, "battle_format") && string(variable_struct_get(_B, "battle_format")) == "double");
    var _lead_idx = __battle_actor_index_for_side_slot(_pid, 0, 0);
    if (is_real(_lead_idx) && _lead_idx >= 0) array_push(_indices, floor(_lead_idx));
    if (_is_double){
        var _ally_idx = __battle_actor_index_for_side_slot(_pid, 0, 1);
        if (is_real(_ally_idx) && _ally_idx >= 0 && _ally_idx != _lead_idx) array_push(_indices, floor(_ally_idx));
    }
    var _any_alive = false;
    var _any_fainted = false;
    var _first_fainted_actor_index = -1;
    for (var _i = 0; _i < array_length(_indices); ++_i){
        var _idx = _indices[_i];
        if (!is_array(_B.actor) || _idx < 0 || _idx >= array_length(_B.actor)) continue;
        var _actor = _B.actor[_idx];
        if (!is_struct(_actor)) continue;
        var _hp = __battle_hp_now(_actor);
        if (is_real(_hp) && _hp > 0) _any_alive = true;
        else {
            _any_fainted = true;
            if (_first_fainted_actor_index < 0) _first_fainted_actor_index = _idx;
        }
    }
    return { any_alive: _any_alive, any_fainted: _any_fainted, all_fainted: (_any_fainted && !_any_alive), fainted_actor_index: _first_fainted_actor_index };
}

// Trainer party/send/switch helpers live in battle_trainer.gml.

// ===== Rect pipeline (PID-aware, GUI-only) =====
// (moved to battle_ui.gml)

// ===== Panels & HUD =====
// (moved to `battle_ui.gml`)

// ===== GUI Letterbox rect =====
// (moved to battle_ui.gml)

// (battle draw helpers moved to battle_draw_helpers.gml)
// (battlers drawing moved to battle_draw.gml)

// ===== Rewards: EXP & Level-Up (simple placeholders) =====
function __battle_transform_species_id(_ent){
    if (!is_struct(_ent)) return -1;
    if (variable_struct_exists(_ent, "species_id") && is_real(variable_struct_get(_ent, "species_id"))) return floor(variable_struct_get(_ent, "species_id"));
    if (variable_struct_exists(_ent, "species") && is_real(variable_struct_get(_ent, "species"))) return floor(variable_struct_get(_ent, "species"));
    if (variable_struct_exists(_ent, "id") && is_real(variable_struct_get(_ent, "id"))) return floor(variable_struct_get(_ent, "id"));
    if (variable_struct_exists(_ent, "mon") && is_struct(variable_struct_get(_ent, "mon"))) return __battle_transform_species_id(variable_struct_get(_ent, "mon"));
    return -1;
}

function __battle_transform_pokemon_identifier(_pokemon_id){
    if (!is_real(_pokemon_id) || !variable_global_exists("_pokemon") || !is_array(global._pokemon)) return "";
    var _pid = floor(_pokemon_id);
    if (_pid < 0 || _pid >= array_length(global._pokemon)) return "";
    var _rec = global._pokemon[_pid];
    if (is_struct(_rec) && variable_struct_exists(_rec, "identifier")) return string_lower(string(variable_struct_get(_rec, "identifier")));
    return "";
}

function __battle_transform_find_form(_base_species_id, _mode, _hint){
    if (!is_real(_base_species_id) || !variable_global_exists("_pokemon") || !is_array(global._pokemon)) return -1;
    var _base = floor(_base_species_id);
    var _want = string_lower(string(_mode));
    var _hint_id = string_lower(string(_hint));
    var _best = -1;
    for (var _i = 0; _i < array_length(global._pokemon); ++_i){
        var _rec = global._pokemon[_i];
        if (!is_struct(_rec)) continue;
        var _species = -1;
        if (variable_struct_exists(_rec, "species_id") && is_real(variable_struct_get(_rec, "species_id"))) _species = floor(variable_struct_get(_rec, "species_id"));
        if (_species != _base) continue;
        var _ident = variable_struct_exists(_rec, "identifier") ? string_lower(string(variable_struct_get(_rec, "identifier"))) : "";
        if (_want == "mega"){
            if (string_pos("-mega", _ident) <= 0 && string_pos("primal", _ident) <= 0 && string_pos("ultra", _ident) <= 0) continue;
            if (_hint_id == "red-orb" && _ident != "groudon-primal") continue;
            if (_hint_id == "blue-orb" && _ident != "kyogre-primal") continue;
            if (string_pos("-x", _hint_id) > 0 && string_pos("-x", _ident) <= 0) continue;
            if (string_pos("-y", _hint_id) > 0 && string_pos("-y", _ident) <= 0) continue;
            return _i;
        } else if (_want == "dynamax"){
            if (string_pos("-gmax", _ident) > 0) return _i;
        }
        if (_best < 0) _best = _i;
    }
    return -1;
}

function __battle_transform_art_ready(_species_id){
    if (!is_real(_species_id) || _species_id < 0) return false;
    try {
        if (!is_undefined(pkicons_has_art96)) return pkicons_has_art96(floor(_species_id));
        if (!is_undefined(pkicons_get_art96)){
            var _spr = pkicons_get_art96(floor(_species_id));
            if (!sprite_exists(_spr)) return false;
            if (variable_global_exists("PKICONS") && is_struct(global.PKICONS) && variable_struct_exists(global.PKICONS, "missing_art96") && _spr == global.PKICONS.missing_art96) return false;
            return true;
        }
    } catch (e_tf_art_ready) {}
    return false;
}

function __battle_transform_held_identifier(_actor){
    var _item_id = -1;
    try { if (!is_undefined(item_runtime_actor_held_item_id)) _item_id = item_runtime_actor_held_item_id(_actor); } catch (e_held_ident_id) { _item_id = -1; }
    if (!is_real(_item_id) || _item_id <= 0) return "";
    try {
        if (variable_global_exists("_items") && is_array(global._items) && _item_id < array_length(global._items)){
            var _it = global._items[_item_id];
            if (is_struct(_it) && variable_struct_exists(_it, "identifier")) return string_lower(string(variable_struct_get(_it, "identifier")));
        }
    } catch (e_held_ident) {}
    return "";
}

function __battle_transform_actor_has_item_group(_actor, _group){
    try {
        if (!is_undefined(item_runtime_actor_has_held_group) && item_runtime_actor_has_held_group(_actor, _group)) return true;
    } catch (e_has_group) {}
    return false;
}

function __battle_transform_available_modes(_pid, _actor_index){
    var _modes = [];
    var _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B) || !variable_struct_exists(_B, "actor") || !is_array(variable_struct_get(_B, "actor"))) return _modes;
    var _actors = variable_struct_get(_B, "actor");
    if (!is_real(_actor_index) || _actor_index < 0 || _actor_index >= array_length(_actors)) return _modes;
    var _actor = _actors[floor(_actor_index)];
    if (!is_struct(_actor)) return _modes;
    var _side_key = "__battle_transform_used_side_" + string(__battle_actor_side(_actor_index));
    if (variable_struct_exists(_B, _side_key) && variable_struct_get(_B, _side_key) == true) return _modes;

    var _sid = __battle_transform_species_id(_actor);
    var _held_ident = __battle_transform_held_identifier(_actor);
    if (!variable_struct_exists(_actor, "_battle_mega") || variable_struct_get(_actor, "_battle_mega") != true){
        if (__battle_transform_actor_has_item_group(_actor, "mega_stone") || _held_ident == "red-orb" || _held_ident == "blue-orb"){
            var _mega_form_ready = __battle_transform_find_form(_sid, "mega", _held_ident);
            if (_mega_form_ready > 0 && __battle_transform_art_ready(_mega_form_ready)) array_push(_modes, "mega");
        }
    }
    if (!variable_struct_exists(_actor, "_battle_z_used") || variable_struct_get(_actor, "_battle_z_used") != true){
        if (__battle_transform_actor_has_item_group(_actor, "z_crystal")) array_push(_modes, "z");
    }
    if (!variable_struct_exists(_actor, "_battle_dynamax") || variable_struct_get(_actor, "_battle_dynamax") != true){
        array_push(_modes, "dynamax");
    }
    return _modes;
}

function __battle_transform_mode_label(_mode){
    var _m = string_lower(string(_mode));
    if (_m == "mega") return "MEGA";
    if (_m == "z") return "Z-POWER";
    if (_m == "dynamax") return "DYNAMAX";
    return "";
}

function __battle_transform_selected_mode(_B, _actor_index){
    if (!is_struct(_B) || !is_real(_actor_index)) return "";
    var _key = "_transform_mode_" + string(floor(_actor_index));
    if (variable_struct_exists(_B, _key)) return string_lower(string(variable_struct_get(_B, _key)));
    return "";
}

function __battle_transform_cycle_selected(_pid, _actor_index){
    var _B = __battle_ensure_slot(_pid);
    var _modes = __battle_transform_available_modes(_pid, _actor_index);
    if (!is_array(_modes) || array_length(_modes) <= 0) return "";
    var _current = __battle_transform_selected_mode(_B, _actor_index);
    var _next_index = 0;
    for (var _i = 0; _i < array_length(_modes); ++_i){
        if (_modes[_i] == _current){ _next_index = (_i + 1) mod array_length(_modes); break; }
    }
    var _next = _modes[_next_index];
    variable_struct_set(_B, "_transform_mode_" + string(floor(_actor_index)), _next);
    return _next;
}

function __battle_transform_recalc_actor_for_species(_actor, _species_id, _hp_multiplier){
    if (!is_struct(_actor) || !is_real(_species_id)) return false;
    var _sid = floor(_species_id);
    var _old_max = max(1, __battle_hp_max(_actor));
    var _old_now = clamp(__battle_hp_now(_actor), 0, _old_max);
    var _hp_frac = _old_now / _old_max;
    var _level = (variable_struct_exists(_actor, "level") && is_real(variable_struct_get(_actor, "level"))) ? floor(variable_struct_get(_actor, "level")) : 50;
    var _iv = (variable_struct_exists(_actor, "iv") && is_struct(variable_struct_get(_actor, "iv"))) ? variable_struct_get(_actor, "iv") : {};
    var _ev = (variable_struct_exists(_actor, "ev") && is_struct(variable_struct_get(_actor, "ev"))) ? variable_struct_get(_actor, "ev") : {};
    var _base = (variable_global_exists("_poke_stats") && is_array(global._poke_stats) && _sid >= 0 && _sid < array_length(global._poke_stats)) ? global._poke_stats[_sid] : undefined;
    if (is_struct(_base) && !is_undefined(scr_compute_stat)){
        var _iv_hp = (variable_struct_exists(_iv, "hp") && is_real(variable_struct_get(_iv, "hp"))) ? variable_struct_get(_iv, "hp") : 0;
        var _iv_atk = (variable_struct_exists(_iv, "atk") && is_real(variable_struct_get(_iv, "atk"))) ? variable_struct_get(_iv, "atk") : 0;
        var _iv_def = (variable_struct_exists(_iv, "def") && is_real(variable_struct_get(_iv, "def"))) ? variable_struct_get(_iv, "def") : 0;
        var _iv_spa = (variable_struct_exists(_iv, "spa") && is_real(variable_struct_get(_iv, "spa"))) ? variable_struct_get(_iv, "spa") : 0;
        var _iv_spd = (variable_struct_exists(_iv, "spd") && is_real(variable_struct_get(_iv, "spd"))) ? variable_struct_get(_iv, "spd") : 0;
        var _iv_spe = (variable_struct_exists(_iv, "spe") && is_real(variable_struct_get(_iv, "spe"))) ? variable_struct_get(_iv, "spe") : 0;
        var _ev_hp = (variable_struct_exists(_ev, "hp") && is_real(variable_struct_get(_ev, "hp"))) ? variable_struct_get(_ev, "hp") : 0;
        var _ev_atk = (variable_struct_exists(_ev, "atk") && is_real(variable_struct_get(_ev, "atk"))) ? variable_struct_get(_ev, "atk") : 0;
        var _ev_def = (variable_struct_exists(_ev, "def") && is_real(variable_struct_get(_ev, "def"))) ? variable_struct_get(_ev, "def") : 0;
        var _ev_spa = (variable_struct_exists(_ev, "spa") && is_real(variable_struct_get(_ev, "spa"))) ? variable_struct_get(_ev, "spa") : 0;
        var _ev_spd = (variable_struct_exists(_ev, "spd") && is_real(variable_struct_get(_ev, "spd"))) ? variable_struct_get(_ev, "spd") : 0;
        var _ev_spe = (variable_struct_exists(_ev, "spe") && is_real(variable_struct_get(_ev, "spe"))) ? variable_struct_get(_ev, "spe") : 0;
        var _new_hp = scr_compute_stat(variable_struct_get(_base, "hp"), _iv_hp, _ev_hp, _level, true);
        variable_struct_set(_actor, "hp_max", max(1, floor(_new_hp * max(1, real(_hp_multiplier)))));
        variable_struct_set(_actor, "maxhp", variable_struct_get(_actor, "hp_max"));
        variable_struct_set(_actor, "atk", scr_compute_stat(variable_struct_get(_base, "atk"), _iv_atk, _ev_atk, _level, false));
        variable_struct_set(_actor, "def", scr_compute_stat(variable_struct_get(_base, "def"), _iv_def, _ev_def, _level, false));
        variable_struct_set(_actor, "spa", scr_compute_stat(variable_struct_get(_base, "spa"), _iv_spa, _ev_spa, _level, false));
        variable_struct_set(_actor, "spd", scr_compute_stat(variable_struct_get(_base, "spd"), _iv_spd, _ev_spd, _level, false));
        variable_struct_set(_actor, "spe", scr_compute_stat(variable_struct_get(_base, "spe"), _iv_spe, _ev_spe, _level, false));
    } else if (_hp_multiplier != 1){
        variable_struct_set(_actor, "hp_max", max(1, floor(_old_max * real(_hp_multiplier))));
        variable_struct_set(_actor, "maxhp", variable_struct_get(_actor, "hp_max"));
    }
    variable_struct_set(_actor, "species_id", _sid);
    variable_struct_set(_actor, "species", _sid);
    variable_struct_set(_actor, "id", _sid);
    try { variable_struct_set(_actor, "name", scr_poke_name_by_id(_sid)); } catch (e_tf_name) {}
    if (variable_global_exists("_species_types") && is_array(global._species_types) && _sid >= 0 && _sid < array_length(global._species_types) && is_array(global._species_types[_sid])){
        variable_struct_set(_actor, "types", global._species_types[_sid]);
        if (array_length(global._species_types[_sid]) > 0) variable_struct_set(_actor, "type1", global._species_types[_sid][0]);
        if (array_length(global._species_types[_sid]) > 1) variable_struct_set(_actor, "type2", global._species_types[_sid][1]);
    }
    __battle_set_hp_now(_actor, clamp(floor(max(1, __battle_hp_max(_actor)) * _hp_frac), 1, max(1, __battle_hp_max(_actor))));
    return true;
}

function __battle_transform_snapshot_actor(_actor){
    if (!is_struct(_actor)) return {};
    return {
        species_id:__battle_transform_species_id(_actor),
        name:(variable_struct_exists(_actor, "name") ? variable_struct_get(_actor, "name") : ""),
        hp_max:__battle_hp_max(_actor),
        hp_now:__battle_hp_now(_actor),
        atk:(variable_struct_exists(_actor, "atk") ? variable_struct_get(_actor, "atk") : undefined),
        def:(variable_struct_exists(_actor, "def") ? variable_struct_get(_actor, "def") : undefined),
        spa:(variable_struct_exists(_actor, "spa") ? variable_struct_get(_actor, "spa") : undefined),
        spd:(variable_struct_exists(_actor, "spd") ? variable_struct_get(_actor, "spd") : undefined),
        spe:(variable_struct_exists(_actor, "spe") ? variable_struct_get(_actor, "spe") : undefined),
        types:(variable_struct_exists(_actor, "types") ? variable_struct_get(_actor, "types") : undefined),
        type1:(variable_struct_exists(_actor, "type1") ? variable_struct_get(_actor, "type1") : undefined),
        type2:(variable_struct_exists(_actor, "type2") ? variable_struct_get(_actor, "type2") : undefined)
    };
}

function __battle_transform_restore_actor(_actor, _snap){
    if (!is_struct(_actor) || !is_struct(_snap)) return false;
    var _old_now = clamp(__battle_hp_now(_actor), 0, max(1, __battle_hp_max(_actor)));
    var _old_max = max(1, __battle_hp_max(_actor));
    var _frac = _old_now / _old_max;
    var _sid = variable_struct_exists(_snap, "species_id") ? variable_struct_get(_snap, "species_id") : -1;
    if (is_real(_sid)){
        variable_struct_set(_actor, "species_id", _sid);
        variable_struct_set(_actor, "species", _sid);
        variable_struct_set(_actor, "id", _sid);
    }
    var _fields = ["name","atk","def","spa","spd","spe","types","type1","type2"];
    for (var _i = 0; _i < array_length(_fields); ++_i){
        var _k = _fields[_i];
        if (variable_struct_exists(_snap, _k)) variable_struct_set(_actor, _k, variable_struct_get(_snap, _k));
    }
    if (variable_struct_exists(_snap, "hp_max") && is_real(variable_struct_get(_snap, "hp_max"))){
        variable_struct_set(_actor, "hp_max", variable_struct_get(_snap, "hp_max"));
        variable_struct_set(_actor, "maxhp", variable_struct_get(_snap, "hp_max"));
    }
    __battle_set_hp_now(_actor, clamp(floor(max(1, __battle_hp_max(_actor)) * _frac), 1, max(1, __battle_hp_max(_actor))));
    return true;
}

function __battle_apply_transformation_action(_pid, _step, _actor_index, _actor){
    if (!is_struct(_step) || !is_struct(_actor) || !variable_struct_exists(_step, "transform_mode")) return "";
    var _B = __battle_ensure_slot(_pid);
    var _mode = string_lower(string(variable_struct_get(_step, "transform_mode")));
    var _side_key = "__battle_transform_used_side_" + string(__battle_actor_side(_actor_index));
    if (variable_struct_exists(_B, _side_key) && variable_struct_get(_B, _side_key) == true) return "";
    var _name = __battle_dialog_actor_name(_actor, "The Pokemon");
    if (_mode == "mega"){
        var _held_ident = __battle_transform_held_identifier(_actor);
        var _target_form = __battle_transform_find_form(__battle_transform_species_id(_actor), "mega", _held_ident);
        if (_target_form > 0 && __battle_transform_art_ready(_target_form)){
            variable_struct_set(_actor, "_battle_transform_original", __battle_transform_snapshot_actor(_actor));
            __battle_transform_recalc_actor_for_species(_actor, _target_form, 1);
            variable_struct_set(_actor, "_battle_mega", true);
            variable_struct_set(_B, _side_key, true);
            variable_struct_set(_B, "_transform_flash", { mode:"mega", actor_index:_actor_index, start_ms:current_time, dur_ms:1120, color_a:make_color_rgb(255, 64, 184), color_b:make_color_rgb(64, 224, 255), label:"MEGA EVOLUTION" });
            if (!is_undefined(sfx_play_safe)) sfx_play_safe(snd_MegaEvolution, 1);
            return _name + "'s Mega Evolution awakened!";
        }
        return _name + " hasn't been fully added yet!";
    } else if (_mode == "z"){
        variable_struct_set(_actor, "_battle_z_used", true);
        variable_struct_set(_actor, "_battle_z_power_move_id", variable_struct_get(_step, "move_id"));
        variable_struct_set(_B, _side_key, true);
        variable_struct_set(_B, "_transform_flash", { mode:"z", actor_index:_actor_index, start_ms:current_time, dur_ms:980, color_a:make_color_rgb(255, 236, 48), color_b:make_color_rgb(255, 108, 32), label:"Z-POWER" });
        return _name + " surrounded itself with its Z-Power!";
    } else if (_mode == "dynamax"){
        var _gmax_form = __battle_transform_find_form(__battle_transform_species_id(_actor), "dynamax", "");
        if (_gmax_form > 0 && !__battle_transform_art_ready(_gmax_form)) return _name + " hasn't been fully added yet!";
        variable_struct_set(_actor, "_battle_transform_original", __battle_transform_snapshot_actor(_actor));
        if (_gmax_form > 0) __battle_transform_recalc_actor_for_species(_actor, _gmax_form, 2);
        else __battle_transform_recalc_actor_for_species(_actor, __battle_transform_species_id(_actor), 2);
        variable_struct_set(_actor, "_battle_dynamax", true);
        variable_struct_set(_actor, "_battle_dynamax_turns", 3);
        variable_struct_set(_B, _side_key, true);
        variable_struct_set(_B, "_transform_flash", { mode:"dynamax", actor_index:_actor_index, start_ms:current_time, dur_ms:1240, color_a:make_color_rgb(208, 36, 72), color_b:make_color_rgb(128, 32, 255), label:((_gmax_form > 0) ? "GIGANTAMAX" : "DYNAMAX") });
        return _name + " grew gigantic!";
    }
    return "";
}

function __battle_tick_dynamax_runtime(_pid){
    var _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B) || !variable_struct_exists(_B, "actor") || !is_array(variable_struct_get(_B, "actor"))) return;
    var _actors = variable_struct_get(_B, "actor");
    for (var _ai = 0; _ai < array_length(_actors); ++_ai){
        var _actor = _actors[_ai];
        if (!is_struct(_actor) || !variable_struct_exists(_actor, "_battle_dynamax") || variable_struct_get(_actor, "_battle_dynamax") != true) continue;
        var _turns = (variable_struct_exists(_actor, "_battle_dynamax_turns") && is_real(variable_struct_get(_actor, "_battle_dynamax_turns"))) ? floor(variable_struct_get(_actor, "_battle_dynamax_turns")) : 0;
        _turns -= 1;
        variable_struct_set(_actor, "_battle_dynamax_turns", _turns);
        if (_turns <= 0){
            if (variable_struct_exists(_actor, "_battle_transform_original") && is_struct(variable_struct_get(_actor, "_battle_transform_original"))) __battle_transform_restore_actor(_actor, variable_struct_get(_actor, "_battle_transform_original"));
            variable_struct_set(_actor, "_battle_dynamax", false);
            dialog_queue(__battle_dialog_actor_name(_actor, "The Pokemon") + " returned to normal!");
        }
    }
}

function __battle_draw_transform_flash(_pid, _B){
    if (!is_struct(_B) || !variable_struct_exists(_B, "_transform_flash") || !is_struct(variable_struct_get(_B, "_transform_flash"))) return;
    var _F = variable_struct_get(_B, "_transform_flash");
    var _start = variable_struct_exists(_F, "start_ms") ? variable_struct_get(_F, "start_ms") : current_time;
    var _dur = variable_struct_exists(_F, "dur_ms") ? max(1, variable_struct_get(_F, "dur_ms")) : 1000;
    var _t = clamp((current_time - _start) / _dur, 0, 1);
    if (_t >= 1){ variable_struct_set(_B, "_transform_flash", undefined); return; }
    var _col_a = variable_struct_exists(_F, "color_a") ? variable_struct_get(_F, "color_a") : c_white;
    var _col_b = variable_struct_exists(_F, "color_b") ? variable_struct_get(_F, "color_b") : c_aqua;
    var _pulse = 0.5 + 0.5 * sin(current_time / 34);
    draw_set_alpha((1 - _t) * 0.58);
    draw_set_color(merge_color(_col_a, _col_b, _pulse));
    draw_rectangle(__bxu(_pid,0), __byu(_pid,0), __bxu(_pid,240), __byu(_pid,160), false);
    var _cx = __bxu(_pid,120);
    var _cy = __byu(_pid,72);
    draw_set_alpha((1 - _t) * 0.82);
    draw_circle(_cx, _cy, __bwu(_pid, 22 + 58 * _t), false);
    draw_circle(_cx, _cy, __bwu(_pid, 10 + 42 * _t), false);
    draw_set_alpha(1);
    if (variable_global_exists("FNT_POKEMON")) draw_set_font(global.FNT_POKEMON);
    draw_set_color(c_white);
    var _label = variable_struct_exists(_F, "label") ? string(variable_struct_get(_F, "label")) : "BURST";
    draw_text(__bxu(_pid, 80), __byu(_pid, 18), _label);
}

function __battle_exp_mode(){
    if (!is_undefined(battle_xp_mode)) return string_lower(string(battle_xp_mode()));
    return "active";
}

function __battle_reward_target_holds_identifier(_target, _identifier){
    if (!is_struct(_target)) return false;
    var _want = string_lower(string(_identifier));
    try {
        if (!is_undefined(item_runtime_actor_held_actions)){
            var _acts = item_runtime_actor_held_actions(_target, "reward_calc");
            for (var _ai = 0; _ai < array_length(_acts); ++_ai){
                var _act = _acts[_ai];
                if (!is_struct(_act)) continue;
                var _data = (variable_struct_exists(_act, "data") && is_struct(variable_struct_get(_act, "data"))) ? variable_struct_get(_act, "data") : {};
                var _id = variable_struct_exists(_data, "identifier") ? string_lower(string(variable_struct_get(_data, "identifier"))) : "";
                if (_id == _want) return true;
            }
        }
    } catch (e_reward_runtime) {}
    return false;
}

function __battle_party_has_reward_identifier(_pid, _identifiers){
    if (!is_array(_identifiers)) _identifiers = [_identifiers];
    if (!is_undefined(party_ensure)){
        var _P = party_ensure(_pid);
        if (is_struct(_P) && is_array(_P.mons)){
            for (var _mi = 0; _mi < array_length(_P.mons); ++_mi){
                var _mon = _P.mons[_mi];
                if (!is_struct(_mon)) continue;
                for (var _ii = 0; _ii < array_length(_identifiers); ++_ii){
                    if (__battle_reward_target_holds_identifier(_mon, _identifiers[_ii])) return true;
                }
            }
        }
    }
    return false;
}

function __battle_exp_reward_multiplier(_target){
    var _mult = 1.0;
    if (__battle_reward_target_holds_identifier(_target, "lucky-egg")) _mult *= 1.5;
    return _mult;
}

function __battle_trainer_reward_multiplier(_pid){
    var _mult = 1.0;
    if (__battle_party_has_reward_identifier(_pid, ["amulet-coin","luck-incense"])) _mult *= 2.0;
    return _mult;
}

function __battle_exp_add_target(_targets, _target){
    if (!is_array(_targets) || !is_struct(_target)) return _targets;
    for (var _i = 0; _i < array_length(_targets); ++_i){
        if (_targets[_i] == _target) return _targets;
    }
    array_push(_targets, _target);
    return _targets;
}

function __battle_exp_target_from_party(_partyPid, _partyIndex){
    if (!is_real(_partyPid) || !is_real(_partyIndex)) return undefined;
    var _pid_int = floor(_partyPid);
    var _idx_int = floor(_partyIndex);
    if (!is_undefined(party_model_get_mon)){
        var _mon = party_model_get_mon(_pid_int, _idx_int);
        if (is_struct(_mon)) return _mon;
    }
    if (!is_undefined(party_ensure)){
        var _P = party_ensure(_pid_int);
        if (is_struct(_P) && is_array(_P.mons) && _idx_int >= 0 && _idx_int < array_length(_P.mons)) return _P.mons[_idx_int];
    }
    return undefined;
}

function __battle_exp_targets(_pid, _B){
    var _targets = [];
    var _mode = __battle_exp_mode();
    if (_mode == "all"){
        if (!is_undefined(party_ensure)){
            var _Pall = party_ensure(_pid);
            if (is_struct(_Pall) && is_array(_Pall.mons)){
                for (var _mi = 0; _mi < array_length(_Pall.mons); ++_mi){
                    if (is_struct(_Pall.mons[_mi])) __battle_exp_add_target(_targets, _Pall.mons[_mi]);
                }
            }
        }
        return _targets;
    }

    if (_mode == "used"){
        if (is_struct(_B) && variable_struct_exists(_B, "_exp_participants") && is_array(variable_struct_get(_B, "_exp_participants"))){
            var _participants = variable_struct_get(_B, "_exp_participants");
            for (var _pi = 0; _pi < array_length(_participants); ++_pi){
                var _entry = _participants[_pi];
                if (!is_struct(_entry) || !variable_struct_exists(_entry, "party_pid") || !variable_struct_exists(_entry, "party_index")) continue;
                if (!is_real(variable_struct_get(_entry, "party_pid")) || floor(variable_struct_get(_entry, "party_pid")) != floor(_pid)) continue;
                var _usedMon = __battle_exp_target_from_party(variable_struct_get(_entry, "party_pid"), variable_struct_get(_entry, "party_index"));
                if (is_struct(_usedMon)) __battle_exp_add_target(_targets, _usedMon);
            }
        }
        if (array_length(_targets) > 0) return _targets;
    }

    if (!is_undefined(party_ensure)){
        var _Pshare = party_ensure(_pid);
        if (is_struct(_Pshare) && is_array(_Pshare.mons)){
            for (var _si = 0; _si < array_length(_Pshare.mons); ++_si){
                var _share_mon = _Pshare.mons[_si];
                if (is_struct(_share_mon) && __battle_reward_target_holds_identifier(_share_mon, "exp-share")) __battle_exp_add_target(_targets, _share_mon);
            }
        }
    }

    if (is_struct(_B) && is_array(_B.actor) && array_length(_B.actor) > 0){
        for (var _ai = 0; _ai < array_length(_B.actor); ++_ai){
            var _actor = _B.actor[_ai];
            if (!is_struct(_actor)) continue;
            if (!variable_struct_exists(_actor, "party_pid") || !is_real(variable_struct_get(_actor, "party_pid"))) continue;
            if (floor(variable_struct_get(_actor, "party_pid")) != floor(_pid)) continue;
            var _activeTarget = (variable_struct_exists(_actor, "mon") && is_struct(variable_struct_get(_actor, "mon"))) ? variable_struct_get(_actor, "mon") : _actor;
            __battle_exp_add_target(_targets, _activeTarget);
        }
    }
    return _targets;
}

function __battle_award_exp_single(_pid, _B, _amount, _target, _show_visuals){
    if (!is_struct(_target)) return;
    var A0 = _target;
    var _gain = max(0, floor(real(_amount) * __battle_exp_reward_multiplier(_target)));
    var T = (is_struct(A0) && variable_struct_exists(A0, "mon") && is_struct(A0.mon)) ? A0.mon : A0;

    if (_show_visuals) variable_struct_set(_B, "_level_stat_bumps_queue", []);

    if (!variable_struct_exists(T, "exp") || !is_real(T.exp)) T.exp = 0;
    if (!variable_struct_exists(T, "exp_next") || !is_real(T.exp_next)) T.exp_next = max(20, (is_real(T.level) ? T.level : (is_real(A0.level) ? A0.level : 1)) * (is_real(T.level) ? T.level : (is_real(A0.level) ? A0.level : 1)) * 2);

    var _prev_exp = (variable_struct_exists(T, "exp") && is_real(variable_struct_get(T, "exp"))) ? real(variable_struct_get(T, "exp")) : 0;
    var _prev_exp_next = (variable_struct_exists(T, "exp_next") && is_real(variable_struct_get(T, "exp_next"))) ? real(variable_struct_get(T, "exp_next")) : max(20, (is_real(T.level) ? T.level : (is_real(A0.level) ? A0.level : 1)) * (is_real(T.level) ? T.level : (is_real(A0.level) ? A0.level : 1)) * 2);
    T.exp = max(0, real(T.exp)) + _gain;

    var _ups = 0;
    while (_ups < 10){
        if (!is_real(T.level)) T.level = 1;
        if (T.level >= 100){
            if (is_real(T.exp_next)) T.exp = min(T.exp, T.exp_next - 1);
            break;
        }

        var nextThresh = -1;
        var gid_probe = undefined;
        if (variable_struct_exists(T, "growth_id") && is_real(T.growth_id)) gid_probe = T.growth_id;
        else if (variable_struct_exists(T, "growth") && is_real(T.growth)) gid_probe = T.growth;
        else if (variable_struct_exists(T, "growth_rate_id") && is_real(T.growth_rate_id)) gid_probe = T.growth_rate_id;

        if (!is_undefined(gid_probe) && is_real(gid_probe) && !is_undefined(scr_get_exp_for_level)) nextThresh = scr_get_exp_for_level(gid_probe, T.level + 1);
        if (!is_real(nextThresh) || nextThresh <= 0) nextThresh = max(20, (T.level + 1) * (T.level + 1) * 2);

        if (is_real(T.exp) && T.exp >= nextThresh){
            T.exp = T.exp - nextThresh;
            T.level += 1;
            _ups += 1;

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

            var iv = (variable_struct_exists(T, "iv") && is_struct(variable_struct_get(T, "iv"))) ? variable_struct_get(T, "iv") : ((variable_struct_exists(A0, "mon") && is_struct(A0.mon) && variable_struct_exists(A0.mon, "iv")) ? variable_struct_get(A0.mon, "iv") : undefined);
            var ev = (variable_struct_exists(T, "ev") && is_struct(variable_struct_get(T, "ev"))) ? variable_struct_get(T, "ev") : ((variable_struct_exists(A0, "mon") && is_struct(A0.mon) && variable_struct_exists(A0.mon, "ev")) ? variable_struct_get(A0.mon, "ev") : undefined);

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

            variable_struct_set(T, "hp_max", max(1, new_hp));
            variable_struct_set(T, "atk", max(1, new_atk));
            variable_struct_set(T, "def", max(1, new_def));
            variable_struct_set(T, "spa", max(1, new_spa));
            variable_struct_set(T, "spd", max(1, new_spd));
            variable_struct_set(T, "spe", max(1, new_spe));

            var cur_hp_now = (variable_struct_exists(T, "hp_now") && is_real(variable_struct_get(T, "hp_now"))) ? real(variable_struct_get(T, "hp_now")) : variable_struct_get(T, "hp_max");
            variable_struct_set(T, "hp_now", min(variable_struct_get(T, "hp_max"), cur_hp_now + 3));

            if (_show_visuals){
                var _deltas = [];
                var dh = variable_struct_get(T, "hp_max") - old_hp; if (dh > 0) array_push(_deltas, ["HP", dh]);
                var da = (variable_struct_get(T, "atk") - old_atk); if (da > 0) array_push(_deltas, ["ATK", da]);
                var dd = (variable_struct_get(T, "def") - old_def); if (dd > 0) array_push(_deltas, ["DEF", dd]);
                var dsp = (variable_struct_get(T, "spa") - old_spa); if (dsp > 0) array_push(_deltas, ["SPATK", dsp]);
                var dsd = (variable_struct_get(T, "spd") - old_spd); if (dsd > 0) array_push(_deltas, ["SPDEF", dsd]);
                var dspc = (variable_struct_get(T, "spe") - old_spe); if (dspc > 0) array_push(_deltas, ["SPEED", dspc]);
                if (!variable_struct_exists(_B, "_level_stat_bumps_queue")) variable_struct_set(_B, "_level_stat_bumps_queue", []);
                var _step_rows = [
                    { label: "HP", from: old_hp, to: variable_struct_get(T, "hp_max") },
                    { label: "ATTACK", from: old_atk, to: variable_struct_get(T, "atk") },
                    { label: "DEFENSE", from: old_def, to: variable_struct_get(T, "def") },
                    { label: "SP.ATK", from: old_spa, to: variable_struct_get(T, "spa") },
                    { label: "SP.DEF", from: old_spd, to: variable_struct_get(T, "spd") },
                    { label: "SPEED", from: old_spe, to: variable_struct_get(T, "spe") }
                ];
                var _level_name = variable_struct_exists(T, "name") ? string(variable_struct_get(T, "name")) : "Pokemon";
                array_push(variable_struct_get(_B, "_level_stat_bumps_queue"), { level: T.level, deltas: _deltas, rows: _step_rows, mon_name: _level_name });
            }

            if (!is_undefined(gid_probe) && is_real(gid_probe) && !is_undefined(scr_get_exp_for_level)){
                var nxt = scr_get_exp_for_level(gid_probe, min(100, T.level + 1));
                if (is_real(nxt) && nxt > 0) T.exp_next = nxt;
                else T.exp_next = max(20, T.level * T.level * 2);
            } else {
                T.exp_next = max(20, T.level * T.level * 2);
            }

            if (T.level >= 100){ T.exp_next = $1e12; break; }
            continue;
        }

        T.exp_next = nextThresh;
        break;
    }

    if (is_struct(A0)){
        if (variable_struct_exists(T, "exp")) A0.exp = T.exp;
        if (variable_struct_exists(T, "exp_next")) A0.exp_next = T.exp_next;
        if (variable_struct_exists(T, "level")) A0.level = T.level;
        if (variable_struct_exists(T, "hp_now") || variable_struct_exists(T, "hp")) __battle_set_hp_now(A0, __battle_hp_now(T));
        if (variable_struct_exists(T, "hp_max")) A0.hp_max = T.hp_max;
        if (variable_struct_exists(T, "name")) A0.name = T.name;
    }

    if (_ups > 0 && !is_undefined(evolution_enqueue_levelup)) {
        try { evolution_enqueue_levelup(_pid, T, A0); } catch (e_evolution_queue) {}
    }

    if (_show_visuals){
        var _msg = string(_gain) + " EXP gained!";
        try { if (!is_undefined(dialog2p_show_now)) dialog2p_show_now(_pid, _msg); else if (!is_undefined(dialog2p_enqueue_text)) dialog2p_enqueue_text(_pid, _msg, _msg, "any"); } catch (e_) {}

        try {
            var _actorMon = (is_struct(A0) && variable_struct_exists(A0, "mon") && is_struct(A0.mon)) ? A0.mon : A0;
            if (is_struct(_actorMon) && variable_struct_exists(_actorMon, "exp") && variable_struct_exists(_actorMon, "exp_next") && is_real(variable_struct_get(_actorMon, "exp_next")) && variable_struct_get(_actorMon, "exp_next") > 0){
                var _final_exp = real(variable_struct_get(_actorMon, "exp"));
                var _final_next = real(variable_struct_get(_actorMon, "exp_next"));
                var _curNorm = (is_real(_prev_exp_next) && _prev_exp_next > 0) ? max(0, min(1, _prev_exp / _prev_exp_next)) : 0;
                var _queue = [];
                var _levels = (variable_struct_exists(_B, "_level_stat_bumps_queue") ? variable_struct_get(_B, "_level_stat_bumps_queue") : []);
                var _li = 0;
                while (_li < array_length(_levels)){
                    array_push(_queue, { from: _curNorm, to: 1.0, dur: 700, type: "to_full" });
                    _curNorm = 0.0;
                    _li += 1;
                }
                var _finalNorm = (is_real(_final_next) && _final_next > 0) ? max(0, min(1, _final_exp / _final_next)) : 0;
                if (!(_li > 0 && _finalNorm == 0)) array_push(_queue, { from: _curNorm, to: _finalNorm, dur: 700, type: "remainder" });
                variable_struct_set(_B, "_exp_anim", { active: true, queue: _queue, playing_index: 0, cur: (array_length(_queue) > 0 ? _queue[0].from : _curNorm), start_ms: current_time });
            }
        } catch (e_ea) { }
    }
}

function __battle_award_exp(_pid, _amount){
    var _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B)) return;
    var _targets = __battle_exp_targets(_pid, _B);
    if (!is_array(_targets) || array_length(_targets) <= 0) return;
    for (var _ti = 0; _ti < array_length(_targets); ++_ti){
        __battle_award_exp_single(_pid, _B, _amount, _targets[_ti], (_ti == 0));
    }
}


function __battle_catch_species_id(_ent){
    try {
        if (is_struct(_ent)){
            if (variable_struct_exists(_ent, "species_id") && is_real(variable_struct_get(_ent, "species_id"))) return floor(variable_struct_get(_ent, "species_id"));
            if (variable_struct_exists(_ent, "species") && is_real(variable_struct_get(_ent, "species"))) return floor(variable_struct_get(_ent, "species"));
            if (variable_struct_exists(_ent, "id") && is_real(variable_struct_get(_ent, "id"))) return floor(variable_struct_get(_ent, "id"));
            if (variable_struct_exists(_ent, "mon") && is_struct(variable_struct_get(_ent, "mon"))) return __battle_catch_species_id(variable_struct_get(_ent, "mon"));
        }
    } catch (e_catch_sid) {}
    return -1;
}

function __battle_catch_level(_ent){
    try {
        if (is_struct(_ent)){
            if (variable_struct_exists(_ent, "level") && is_real(variable_struct_get(_ent, "level"))) return max(1, floor(variable_struct_get(_ent, "level")));
            if (variable_struct_exists(_ent, "mon") && is_struct(variable_struct_get(_ent, "mon"))) return __battle_catch_level(variable_struct_get(_ent, "mon"));
        }
    } catch (e_catch_level) {}
    return 1;
}

function __battle_catch_item_identifier(_item_id){
    if (!is_real(_item_id)) return "";
    var _iid = floor(_item_id);
    try {
        if (variable_global_exists("_items") && is_array(global._items) && _iid >= 0 && _iid < array_length(global._items)){
            var _it = global._items[_iid];
            if (is_struct(_it)){
                if (variable_struct_exists(_it, "identifier") && string_length(string(variable_struct_get(_it, "identifier"))) > 0) return string_lower(string(variable_struct_get(_it, "identifier")));
                if (variable_struct_exists(_it, "name") && string_length(string(variable_struct_get(_it, "name"))) > 0) return string_lower(string_replace_all(string(variable_struct_get(_it, "name")), " ", "-"));
            }
        }
    } catch (e_catch_ident) {}
    return "";
}

function __battle_catch_has_type(_actor, _type_name){
    try {
        if (!is_undefined(__battle_actor_has_type_name_runtime)) return __battle_actor_has_type_name_runtime(_actor, _type_name);
        if (!is_undefined(__battle_actor_has_type_name_for_ability)) return __battle_actor_has_type_name_for_ability(_actor, _type_name);
    } catch (e_catch_type) {}
    return false;
}

function __battle_catch_status_bonus(_actor){
    try {
        if (!is_undefined(status_system_has_status)){
            var _sleep = status_system_has_status(_actor, "sleep");
            var _freeze = status_system_has_status(_actor, "freeze");
            if (!_sleep && variable_struct_exists(_actor, "mon") && is_struct(variable_struct_get(_actor, "mon"))) _sleep = status_system_has_status(variable_struct_get(_actor, "mon"), "sleep");
            if (!_freeze && variable_struct_exists(_actor, "mon") && is_struct(variable_struct_get(_actor, "mon"))) _freeze = status_system_has_status(variable_struct_get(_actor, "mon"), "freeze");
            if (_sleep || _freeze) return 2.5;

            var _major = ["paralysis", "paralyze", "burn", "poison", "toxic"];
            for (var _i = 0; _i < array_length(_major); ++_i){
                if (status_system_has_status(_actor, _major[_i])) return 1.5;
                if (variable_struct_exists(_actor, "mon") && is_struct(variable_struct_get(_actor, "mon")) && status_system_has_status(variable_struct_get(_actor, "mon"), _major[_i])) return 1.5;
            }
        }
    } catch (e_catch_status) {}
    return 1.0;
}

function __battle_catch_rate_for_actor(_actor){
    var _sid = __battle_catch_species_id(_actor);
    try {
        if (is_struct(_actor)){
            if (variable_struct_exists(_actor, "capture_rate") && is_real(variable_struct_get(_actor, "capture_rate"))) return clamp(floor(variable_struct_get(_actor, "capture_rate")), 1, 255);
            if (variable_struct_exists(_actor, "catch_rate") && is_real(variable_struct_get(_actor, "catch_rate"))) return clamp(floor(variable_struct_get(_actor, "catch_rate")), 1, 255);
            if (variable_struct_exists(_actor, "mon") && is_struct(variable_struct_get(_actor, "mon"))){
                var _mon = variable_struct_get(_actor, "mon");
                if (variable_struct_exists(_mon, "capture_rate") && is_real(variable_struct_get(_mon, "capture_rate"))) return clamp(floor(variable_struct_get(_mon, "capture_rate")), 1, 255);
                if (variable_struct_exists(_mon, "catch_rate") && is_real(variable_struct_get(_mon, "catch_rate"))) return clamp(floor(variable_struct_get(_mon, "catch_rate")), 1, 255);
            }
        }
        if (_sid >= 0 && variable_global_exists("_species_capture_rates") && is_array(global._species_capture_rates) && _sid < array_length(global._species_capture_rates) && is_real(global._species_capture_rates[_sid])){
            return clamp(floor(global._species_capture_rates[_sid]), 1, 255);
        }
    } catch (e_catch_rate) {}
    return 45;
}

function __battle_catch_actor_base_speed(_actor){
    try {
        if (is_struct(_actor)){
            if (variable_struct_exists(_actor, "spe") && is_real(variable_struct_get(_actor, "spe"))) return floor(variable_struct_get(_actor, "spe"));
            if (variable_struct_exists(_actor, "spd") && is_real(variable_struct_get(_actor, "spd"))) return floor(variable_struct_get(_actor, "spd"));
            if (variable_struct_exists(_actor, "mon") && is_struct(variable_struct_get(_actor, "mon"))) return __battle_catch_actor_base_speed(variable_struct_get(_actor, "mon"));
        }
        var _sid = __battle_catch_species_id(_actor);
        if (_sid >= 0 && !is_undefined(scr_poke_stats)){
            var _stats = scr_poke_stats(_sid);
            if (is_struct(_stats) && variable_struct_exists(_stats, "spe") && is_real(variable_struct_get(_stats, "spe"))) return floor(variable_struct_get(_stats, "spe"));
        }
    } catch (e_catch_speed) {}
    return 0;
}

function __battle_catch_actor_weight_kg(_actor){
    try {
        if (!is_undefined(__battle_entity_weight_impl)) return max(0, real(__battle_entity_weight_impl(_actor)));
        if (is_struct(_actor)){
            if (variable_struct_exists(_actor, "weight_kg") && is_real(variable_struct_get(_actor, "weight_kg"))) return real(variable_struct_get(_actor, "weight_kg"));
            if (variable_struct_exists(_actor, "weight") && is_real(variable_struct_get(_actor, "weight"))) return real(variable_struct_get(_actor, "weight")) / 10;
            if (variable_struct_exists(_actor, "mon") && is_struct(variable_struct_get(_actor, "mon"))) return __battle_catch_actor_weight_kg(variable_struct_get(_actor, "mon"));
        }
        var _sid = __battle_catch_species_id(_actor);
        if (_sid >= 0 && variable_global_exists("_pokemon") && is_array(global._pokemon) && _sid < array_length(global._pokemon)){
            var _rec = global._pokemon[_sid];
            if (is_struct(_rec) && variable_struct_exists(_rec, "weight") && is_real(variable_struct_get(_rec, "weight"))) return real(variable_struct_get(_rec, "weight")) / 10;
        }
    } catch (e_catch_weight) {}
    return 0;
}

function __battle_catch_sex_value(_actor){
    try {
        if (is_struct(_actor)){
            if (variable_struct_exists(_actor, "sex")) return string_lower(string(variable_struct_get(_actor, "sex")));
            if (variable_struct_exists(_actor, "gender")) return string_lower(string(variable_struct_get(_actor, "gender")));
            if (variable_struct_exists(_actor, "mon") && is_struct(variable_struct_get(_actor, "mon"))) return __battle_catch_sex_value(variable_struct_get(_actor, "mon"));
        }
    } catch (e_catch_sex) {}
    return "";
}

function __battle_catch_same_species_opposite_sex(_a, _b){
    var _sa = __battle_catch_species_id(_a);
    var _sb = __battle_catch_species_id(_b);
    if (_sa <= 0 || _sb <= 0 || _sa != _sb) return false;
    var _ga = __battle_catch_sex_value(_a);
    var _gb = __battle_catch_sex_value(_b);
    var _am = (_ga == "m" || _ga == "male" || _ga == "1");
    var _af = (_ga == "f" || _ga == "female" || _ga == "2");
    var _bm = (_gb == "m" || _gb == "male" || _gb == "1");
    var _bf = (_gb == "f" || _gb == "female" || _gb == "2");
    return ((_am && _bf) || (_af && _bm));
}

function __battle_catch_player_has_species(_pid, _sid){
    if (!is_real(_sid) || _sid <= 0) return false;
    var _target_sid = floor(_sid);
    try {
        if (!is_undefined(party_model_get_mons)){
            var _mons = party_model_get_mons(_pid);
            if (is_array(_mons)){
                for (var _mi = 0; _mi < array_length(_mons); ++_mi){
                    if (__battle_catch_species_id(_mons[_mi]) == _target_sid) return true;
                }
            }
        }
        if (variable_global_exists("PC_STORAGE") && is_array(global.PC_STORAGE) && _pid >= 0 && _pid < array_length(global.PC_STORAGE)){
            var _pc = global.PC_STORAGE[_pid];
            if (is_struct(_pc) && variable_struct_exists(_pc, "boxes") && is_array(variable_struct_get(_pc, "boxes"))){
                var _boxes = variable_struct_get(_pc, "boxes");
                for (var _bi = 0; _bi < array_length(_boxes); ++_bi){
                    var _box = _boxes[_bi];
                    if (!is_struct(_box) || !variable_struct_exists(_box, "mons") || !is_array(variable_struct_get(_box, "mons"))) continue;
                    var _box_mons = variable_struct_get(_box, "mons");
                    for (var _bmi = 0; _bmi < array_length(_box_mons); ++_bmi){
                        if (__battle_catch_species_id(_box_mons[_bmi]) == _target_sid) return true;
                    }
                }
            }
        }
        if (variable_global_exists("SYS_PC") && is_array(global.SYS_PC) && _pid >= 0 && _pid < array_length(global.SYS_PC)){
            var _sys_pc = global.SYS_PC[_pid];
            if (is_struct(_sys_pc) && variable_struct_exists(_sys_pc, "boxes") && is_array(variable_struct_get(_sys_pc, "boxes"))){
                var _sboxes = variable_struct_get(_sys_pc, "boxes");
                for (var _sbi = 0; _sbi < array_length(_sboxes); ++_sbi){
                    var _sbox = _sboxes[_sbi];
                    if (!is_struct(_sbox) || !variable_struct_exists(_sbox, "mons") || !is_array(variable_struct_get(_sbox, "mons"))) continue;
                    var _smons = variable_struct_get(_sbox, "mons");
                    for (var _smi = 0; _smi < array_length(_smons); ++_smi){
                        if (__battle_catch_species_id(_smons[_smi]) == _target_sid) return true;
                    }
                }
            }
        }
    } catch (e_catch_seen) {}
    return false;
}

function __battle_catch_ball_profile(_pid, _B, _item_id, _target_actor, _target_index, _owner_pid, _fallback_mult){
    var _ident = __battle_catch_item_identifier(_item_id);
    var _profile = { multiplier:1.0, catch_rate_bonus:0, guaranteed:false, post:"" };
    if (is_real(_fallback_mult)) _profile.multiplier = max(0.01, real(_fallback_mult));

    var _target_level = __battle_catch_level(_target_actor);
    var _target_sid = __battle_catch_species_id(_target_actor);
    var _turns = 1;
    try {
        if (is_struct(_B)){
            if (variable_struct_exists(_B, "turn_counter") && is_real(variable_struct_get(_B, "turn_counter"))) _turns = max(1, floor(variable_struct_get(_B, "turn_counter")) + 1);
            else if (variable_struct_exists(_B, "turn_index") && is_real(variable_struct_get(_B, "turn_index"))) _turns = max(1, floor(variable_struct_get(_B, "turn_index")) + 1);
        }
    } catch (e_catch_turns) {}

    var _actor = undefined;
    try {
        if (is_struct(_B) && variable_struct_exists(_B, "actor") && is_array(variable_struct_get(_B, "actor"))){
            var _actors = variable_struct_get(_B, "actor");
            var _ai = 0;
            if (is_real(_owner_pid)) _ai = 0;
            if (_ai >= 0 && _ai < array_length(_actors)) _actor = _actors[_ai];
        }
    } catch (e_catch_actor) {}

    switch (_ident){
        case "master-ball":
        case "park-ball":
        case "laorigin-ball":
        case "origin-ball":
            _profile.guaranteed = true;
            break;
        case "ultra-ball":
        case "laultra-ball":
            _profile.multiplier = 2.0;
            break;
        case "great-ball":
        case "lagreat-ball":
            _profile.multiplier = 1.5;
            break;
        case "safari-ball":
        case "sport-ball":
            _profile.multiplier = 1.5;
            break;
        case "net-ball":
            _profile.multiplier = (__battle_catch_has_type(_target_actor, "water") || __battle_catch_has_type(_target_actor, "bug")) ? 3.5 : 1.0;
            break;
        case "dive-ball":
            _profile.multiplier = 3.5;
            try {
                if (is_struct(_B) && variable_struct_exists(_B, "arena_type")){
                    var _arena = string_lower(string(variable_struct_get(_B, "arena_type")));
                    if (string_pos("water", _arena) <= 0 && string_pos("surf", _arena) <= 0 && string_pos("underwater", _arena) <= 0 && string_pos("fish", _arena) <= 0) _profile.multiplier = 1.0;
                }
            } catch (e_dive_arena) {}
            break;
        case "nest-ball":
            _profile.multiplier = max(1.0, (41 - _target_level) / 10);
            break;
        case "repeat-ball":
            _profile.multiplier = __battle_catch_player_has_species(_owner_pid, _target_sid) ? 3.5 : 1.0;
            break;
        case "timer-ball":
            _profile.multiplier = min(4.0, 1.0 + (_turns * 0.3));
            break;
        case "dusk-ball":
            _profile.multiplier = 1.0;
            try {
                var _is_dark = false;
                if (is_struct(_B) && variable_struct_exists(_B, "arena_type")){
                    var _arena2 = string_lower(string(variable_struct_get(_B, "arena_type")));
                    _is_dark = (string_pos("cave", _arena2) > 0 || string_pos("night", _arena2) > 0 || string_pos("dark", _arena2) > 0);
                }
                var _hour = date_get_hour(date_current_datetime());
                if (_hour >= 20 || _hour < 4) _is_dark = true;
                _profile.multiplier = _is_dark ? 3.5 : 1.0;
            } catch (e_dusk) {}
            break;
        case "quick-ball":
            _profile.multiplier = (_turns <= 1) ? 5.0 : 1.0;
            break;
        case "dream-ball":
            _profile.multiplier = (__battle_catch_status_bonus(_target_actor) >= 2.5) ? 4.0 : 1.0;
            break;
        case "beast-ball":
            _profile.multiplier = 0.1;
            try {
                if (is_struct(_target_actor) && variable_struct_exists(_target_actor, "is_ultra_beast") && variable_struct_get(_target_actor, "is_ultra_beast")) _profile.multiplier = 5.0;
                else if (is_struct(_target_actor) && variable_struct_exists(_target_actor, "mon") && is_struct(variable_struct_get(_target_actor, "mon")) && variable_struct_exists(variable_struct_get(_target_actor, "mon"), "is_ultra_beast") && variable_struct_get(variable_struct_get(_target_actor, "mon"), "is_ultra_beast")) _profile.multiplier = 5.0;
            } catch (e_beast) {}
            break;
        case "lure-ball":
            _profile.multiplier = 1.0;
            try {
                if (is_struct(_B) && variable_struct_exists(_B, "arena_type")){
                    var _arena3 = string_lower(string(variable_struct_get(_B, "arena_type")));
                    if (string_pos("fish", _arena3) > 0 || string_pos("rod", _arena3) > 0) _profile.multiplier = 3.0;
                }
            } catch (e_lure) {}
            break;
        case "level-ball":
            var _al = __battle_catch_level(_actor);
            if (_al >= _target_level * 4) _profile.multiplier = 8.0;
            else if (_al >= _target_level * 2) _profile.multiplier = 4.0;
            else if (_al > _target_level) _profile.multiplier = 2.0;
            else _profile.multiplier = 1.0;
            break;
        case "moon-ball":
            _profile.multiplier = 1.0;
            try {
                if (variable_global_exists("_pokemon_evolutions") && is_array(global._pokemon_evolutions)){
                    for (var _evi = 0; _evi < array_length(global._pokemon_evolutions); ++_evi){
                        var _ev = global._pokemon_evolutions[_evi];
                        if (is_struct(_ev) && variable_struct_exists(_ev, "source_species_id") && variable_struct_exists(_ev, "trigger_item_id") && floor(variable_struct_get(_ev, "source_species_id")) == _target_sid && floor(variable_struct_get(_ev, "trigger_item_id")) == 81){
                            _profile.multiplier = 4.0;
                            break;
                        }
                    }
                }
            } catch (e_moon) {}
            break;
        case "heavy-ball":
        case "laheavy-ball":
        case "laleaden-ball":
        case "lagigaton-ball":
            var _kg = __battle_catch_actor_weight_kg(_target_actor);
            if (_kg < 100) _profile.catch_rate_bonus = -20;
            else if (_kg < 200) _profile.catch_rate_bonus = 0;
            else if (_kg < 300) _profile.catch_rate_bonus = 20;
            else _profile.catch_rate_bonus = 30;
            if (_ident == "laleaden-ball") _profile.multiplier = 1.25;
            if (_ident == "lagigaton-ball") _profile.multiplier = 1.5;
            break;
        case "fast-ball":
        case "lafeather-ball":
        case "lawing-ball":
        case "lajet-ball":
            _profile.multiplier = (__battle_catch_actor_base_speed(_target_actor) >= 100) ? 4.0 : 1.0;
            if (_ident == "lawing-ball") _profile.multiplier = max(_profile.multiplier, 1.25);
            if (_ident == "lajet-ball") _profile.multiplier = max(_profile.multiplier, 1.5);
            break;
        case "love-ball":
            _profile.multiplier = __battle_catch_same_species_opposite_sex(_actor, _target_actor) ? 8.0 : 1.0;
            break;
        case "luxury-ball":
            _profile.multiplier = 1.0;
            _profile.post = "luxury";
            break;
        case "friend-ball":
            _profile.multiplier = 1.0;
            _profile.post = "friend";
            break;
        case "heal-ball":
            _profile.multiplier = 1.0;
            _profile.post = "heal";
            break;
        default:
            if (string_length(_ident) <= 0) _profile.multiplier = max(0.01, _profile.multiplier);
            break;
    }
    return _profile;
}

function __battle_catch_apply_ball_post_effects(_caught, _actor, _profile, _item_id){
    if (!is_struct(_caught) || !is_struct(_profile)) return;
    try {
        if (is_real(_item_id) && _item_id > 0){
            variable_struct_set(_caught, "pokeball_item_id", floor(_item_id));
            variable_struct_set(_caught, "capture_ball_item_id", floor(_item_id));
        }
        var _post = variable_struct_exists(_profile, "post") ? string_lower(string(variable_struct_get(_profile, "post"))) : "";
        if (_post == "heal"){
            var _maxhp = __battle_hp_max(_caught);
            if (_maxhp <= 1) _maxhp = __battle_hp_max(_actor);
            if (_maxhp > 0){
                variable_struct_set(_caught, "hp", _maxhp);
                variable_struct_set(_caught, "hp_now", _maxhp);
                variable_struct_set(_caught, "hp_max", _maxhp);
            }
            if (!is_undefined(status_system_clear_status)){
                var _statuses = ["burn", "poison", "toxic", "paralysis", "paralyze", "sleep", "freeze", "confusion"];
                for (var _si = 0; _si < array_length(_statuses); ++_si){
                    try { status_system_clear_status(_caught, _statuses[_si]); } catch (e_clear_caught) {}
                    try { status_system_clear_status(_actor, _statuses[_si]); } catch (e_clear_actor) {}
                }
            }
            if (variable_struct_exists(_caught, "status")) variable_struct_set(_caught, "status", 0);
            if (variable_struct_exists(_caught, "status_id")) variable_struct_set(_caught, "status_id", 0);
            variable_struct_set(_caught, "statuses", {});
        } else if (_post == "friend" || _post == "luxury"){
            variable_struct_set(_caught, "friendship", 200);
            variable_struct_set(_caught, "happiness", 200);
            if (_post == "luxury") variable_struct_set(_caught, "luxury_ball_bonus", true);
        }
    } catch (e_post_catch) {}
}

// ===== Catch Flow: species catch rate + ball-specific modifiers =====
function __battle_try_catch(_pid, _ball_mult, _item_id, _target_index, _owner_pid = undefined){
    var _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B)) return false;
    var _catch_owner_pid = (is_real(_owner_pid) ? max(0, floor(_owner_pid)) : max(0, floor(_pid)));

    // Block capture attempts outright during trainer battles. This guard covers any
    // code path that bypasses the bag validation and calls into the catch logic
    // directly (e.g. debug helpers or legacy flows).
    var battle_mode = "wild";
    if (variable_struct_exists(_B, "_battle_mode")) battle_mode = string_lower(string(variable_struct_get(_B, "_battle_mode")));
    if (battle_mode == "trainer"){
        var now_block = current_time;
        var last_block = (variable_struct_exists(_B, "_trainer_block_feedback_ms") ? variable_struct_get(_B, "_trainer_block_feedback_ms") : -1000);
        if (now_block - last_block >= 400){
            var block_msg = "The opposing Trainer blocked the Ball! Don't be a thief!";
            try {
                if (!is_undefined(dialog2p_enqueue_text)) dialog2p_enqueue_text(_pid, block_msg, block_msg, "any");
                else if (!is_undefined(dialog2p_show_now)) dialog2p_show_now(_pid, block_msg);
                else if (!is_undefined(dialog2p_show)) dialog2p_show(_pid, block_msg);
            } catch (e_msg) {}
            try { variable_struct_set(_B, "_trainer_block_feedback_ms", now_block); } catch (e_set) {}
        }
        if (variable_struct_exists(_B, "_catch_anim")) variable_struct_set(_B, "_catch_anim", undefined);
        return false;
    }

    var target_idx = -1;
    if (is_real(_target_index)) target_idx = floor(_target_index);
    if (!is_array(_B.actor)) return false;
    if (target_idx < 0 || target_idx >= array_length(_B.actor) || !__battle_actor_index_alive(_pid, target_idx) || __battle_actor_side(target_idx) != 1){
        target_idx = __battle_get_default_target_index(_pid, 0);
    }
    if (!is_real(target_idx) || target_idx < 0 || target_idx >= array_length(_B.actor) || __battle_actor_side(target_idx) != 1) return false;

    var A1 = _B.actor[target_idx];
    if (!is_struct(A1)) return false;
    // compute chance as before but defer dialog/resolution to animation
    var catch_profile = __battle_catch_ball_profile(_pid, _B, _item_id, A1, target_idx, _catch_owner_pid, _ball_mult);
    var max_hp_catch = max(1, __battle_hp_max(A1));
    var hp_now_catch = clamp(__battle_hp_now(A1), 1, max_hp_catch);
    var species_catch_rate = __battle_catch_rate_for_actor(A1);
    var catch_rate_bonus = (is_struct(catch_profile) && variable_struct_exists(catch_profile, "catch_rate_bonus") && is_real(catch_profile.catch_rate_bonus)) ? floor(catch_profile.catch_rate_bonus) : 0;
    var ball_bonus = (is_struct(catch_profile) && variable_struct_exists(catch_profile, "multiplier") && is_real(catch_profile.multiplier)) ? max(0.01, real(catch_profile.multiplier)) : 1.0;
    var status_bonus = __battle_catch_status_bonus(A1);
    species_catch_rate = clamp(species_catch_rate + catch_rate_bonus, 1, 255);
    var modified_rate = floor((((3 * max_hp_catch - 2 * hp_now_catch) * species_catch_rate * ball_bonus) / (3 * max_hp_catch)) * status_bonus);
    modified_rate = clamp(modified_rate, 1, 255);
    var guaranteed = (is_struct(catch_profile) && variable_struct_exists(catch_profile, "guaranteed") && catch_profile.guaranteed);
    var success = guaranteed || (modified_rate >= 255);
    var break_hop_from_checks = 0;
    if (!success){
        var shake_threshold = floor(65536 / power(255 / modified_rate, 0.1875));
        shake_threshold = clamp(shake_threshold, 1, 65535);
        var passed_shakes = 0;
        for (var _shake_i = 0; _shake_i < 4; ++_shake_i){
            if (irandom(65535) < shake_threshold) passed_shakes += 1;
            else break;
        }
        success = (passed_shakes >= 4);
        if (!success) break_hop_from_checks = clamp(passed_shakes + 1, 1, 3);
    }
    var hpPct = 0;
    var baseChance = clamp(floor((1 - hpPct) * 70) + 20, 5, 95); // 20�90% typical
    var mult = ball_bonus;
    var chance = modified_rate;

    // Prepare captured mon data when success to reuse later
    var caught = undefined;
    if (variable_struct_exists(A1, "mon") && is_struct(A1.mon)) caught = A1.mon;
    else if (is_struct(A1)) caught = A1;
    if (success && is_struct(caught)) __battle_catch_apply_ball_post_effects(caught, A1, catch_profile, _item_id);

    // create an animation state on the battle slot so the draw/update code can render it
    // durations in ms
    var now = current_time;
    var ball_spr = undefined;
    if (!is_undefined(pkicons_get_capture_ball_icon_by_id) && is_real(_item_id) && _item_id > 0){
        try { var s_try = pkicons_get_capture_ball_icon_by_id(floor(_item_id)); if (!is_undefined(s_try) && sprite_exists(s_try)) ball_spr = s_try; } catch (e) { ball_spr = undefined; }
    } else if (!is_undefined(pkicons_get_item_icon_by_id) && is_real(_item_id) && _item_id > 0){
        try { var s_fallback = pkicons_get_item_icon_by_id(floor(_item_id)); if (!is_undefined(s_fallback) && sprite_exists(s_fallback)) ball_spr = s_fallback; } catch (e_fallback) { ball_spr = undefined; }
    }

    var land_x = undefined;
    var land_y = undefined;
    try {
        if (!is_undefined(__battle_get_actor_scene_anchor)){
            var _anchor = __battle_get_actor_scene_anchor(_pid, _B, target_idx);
            if (is_struct(_anchor) && variable_struct_exists(_anchor, "battler")){
                var _pt = variable_struct_get(_anchor, "battler");
                if (is_array(_pt) && array_length(_pt) >= 2){
                    var _ui_s = 1;
                    if (variable_struct_exists(_B, "_ui")){
                        var _ui = variable_struct_get(_B, "_ui");
                        if (is_struct(_ui) && variable_struct_exists(_ui, "s") && is_real(variable_struct_get(_ui, "s"))) _ui_s = real(variable_struct_get(_ui, "s"));
                    }
                    var _spr_target = undefined;
                    if (!is_undefined(pkicons_get_art96_by_mon) && is_struct(A1) && variable_struct_exists(A1, "mon")) _spr_target = pkicons_get_art96_by_mon(variable_struct_get(A1, "mon"));
                    var _w = 64;
                    var _h = 64;
                    if (!is_undefined(_spr_target) && sprite_exists(_spr_target)){
                        _w = sprite_get_width(_spr_target);
                        _h = sprite_get_height(_spr_target);
                    }
                    var _scale_mult = (variable_struct_exists(_anchor, "scale_mult") && is_real(variable_struct_get(_anchor, "scale_mult"))) ? real(variable_struct_get(_anchor, "scale_mult")) : 1;
                    var _draw_scale = _scale_mult * _ui_s;
                    var _platform_bottom = _pt[1] + (_h * _draw_scale) * 0.5;
                    var _shadow_h = max(2, floor((_w * _draw_scale) * 0.12));
                    land_x = floor(_pt[0]);
                    land_y = floor(_platform_bottom + _shadow_h * 0.8 + floor(15 * _ui_s));
                }
            }
        }
    } catch (e_land_calc) {}

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
        break_hop = (break_hop_from_checks > 0) ? break_hop_from_checks : (irandom(hop_total - 1) + 1); // irandom(n-1)+1 => 1..hop_total
    }

    // Delegate creation to modular animation helper
    if (!is_undefined(__battle_anim_create_catch)){
        __battle_anim_create_catch(_B, _item_id, caught, { hop_total: hop_total, success: success, break_hop: break_hop, throw_dur:380, impact_dur:220, hop_dur:700, hop_pause:350, target_actor_index: target_idx, owner_pid: _catch_owner_pid, land_x: land_x, land_y: land_y });
        if (variable_struct_exists(_B, "_catch_anim") && is_struct(variable_struct_get(_B, "_catch_anim"))){
            var _catch_anim_owner = variable_struct_get(_B, "_catch_anim");
            variable_struct_set(_catch_anim_owner, "owner_pid", _catch_owner_pid);
            variable_struct_set(_B, "_catch_anim", _catch_anim_owner);
        }
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
            ball_sprite: ball_spr,
            ball_frame: 0,
            start_x: undefined,
            start_y: undefined,
            target_x: undefined,
            target_y: undefined,
            enemy_orig_scale: undefined,
            enemy_scale_now: undefined,
            caught_struct: caught,
            target_actor_index: target_idx,
            owner_pid: _catch_owner_pid,
            land_x: land_x,
            land_y: land_y
        };
    }

    // mark that the battle slot has a pending non-dialog resolution; dialog will be opened by animation end
    if (variable_global_exists("DATA_DEBUG_VERBOSE") && global.DATA_DEBUG_VERBOSE) show_debug_message("[battle][debug] _catch_anim created pid=" + string(_pid) + ", outcome=" + string(success));
    // don't immediately change _B.result here; do it after animation resolves.
    return true;
}

function __battle_catch_owner_pid(_B, _fallback_pid){
    var _owner = is_real(_fallback_pid) ? max(0, floor(_fallback_pid)) : 0;
    try {
        if (is_struct(_B) && variable_struct_exists(_B, "_catch_anim") && is_struct(variable_struct_get(_B, "_catch_anim"))){
            var _ca_owner = variable_struct_get(_B, "_catch_anim");
            if (variable_struct_exists(_ca_owner, "owner_pid") && is_real(variable_struct_get(_ca_owner, "owner_pid"))) _owner = max(0, floor(variable_struct_get(_ca_owner, "owner_pid")));
        }
    } catch (e_catch_owner) {}
    return _owner;
}

function __battle_catch_anim_expected_ms(_ca){
    if (!is_struct(_ca)) return 5000;
    var _throw = (variable_struct_exists(_ca, "throw_dur") && is_real(variable_struct_get(_ca, "throw_dur"))) ? max(1, real(variable_struct_get(_ca, "throw_dur"))) : 380;
    var _impact = (variable_struct_exists(_ca, "impact_dur") && is_real(variable_struct_get(_ca, "impact_dur"))) ? max(1, real(variable_struct_get(_ca, "impact_dur"))) : 220;
    var _hop_total = (variable_struct_exists(_ca, "hop_total") && is_real(variable_struct_get(_ca, "hop_total"))) ? clamp(floor(variable_struct_get(_ca, "hop_total")), 1, 8) : 3;
    var _hop = (variable_struct_exists(_ca, "hop_dur") && is_real(variable_struct_get(_ca, "hop_dur"))) ? max(1, real(variable_struct_get(_ca, "hop_dur"))) : 700;
    var _pause = (variable_struct_exists(_ca, "hop_pause") && is_real(variable_struct_get(_ca, "hop_pause"))) ? max(0, real(variable_struct_get(_ca, "hop_pause"))) : 350;
    var _escape = (variable_struct_exists(_ca, "escape_dur") && is_real(variable_struct_get(_ca, "escape_dur"))) ? max(1, real(variable_struct_get(_ca, "escape_dur"))) : 320;
    return clamp(_throw + _impact + (_hop_total * (_hop + _pause)) + _escape + 1200, 2500, 5500);
}

function __battle_normalize_catch_anim(_ca){
    if (!is_struct(_ca)) return _ca;
    var _now = current_time;
    if (!variable_struct_exists(_ca, "active")) variable_struct_set(_ca, "active", true);
    if (!variable_struct_exists(_ca, "phase") || string_length(string(variable_struct_get(_ca, "phase"))) <= 0) variable_struct_set(_ca, "phase", "throw");
    if (!variable_struct_exists(_ca, "start_ms") || !is_real(variable_struct_get(_ca, "start_ms")) || real(variable_struct_get(_ca, "start_ms")) > _now + 100) variable_struct_set(_ca, "start_ms", _now);
    if (!variable_struct_exists(_ca, "phase_start") || !is_real(variable_struct_get(_ca, "phase_start")) || real(variable_struct_get(_ca, "phase_start")) > _now + 100) variable_struct_set(_ca, "phase_start", _now);
    if (!variable_struct_exists(_ca, "throw_dur") || !is_real(variable_struct_get(_ca, "throw_dur")) || real(variable_struct_get(_ca, "throw_dur")) <= 0) variable_struct_set(_ca, "throw_dur", 380);
    if (!variable_struct_exists(_ca, "impact_dur") || !is_real(variable_struct_get(_ca, "impact_dur")) || real(variable_struct_get(_ca, "impact_dur")) <= 0) variable_struct_set(_ca, "impact_dur", 220);
    if (!variable_struct_exists(_ca, "hop_total") || !is_real(variable_struct_get(_ca, "hop_total")) || real(variable_struct_get(_ca, "hop_total")) <= 0) variable_struct_set(_ca, "hop_total", 3);
    if (!variable_struct_exists(_ca, "hop_index") || !is_real(variable_struct_get(_ca, "hop_index")) || real(variable_struct_get(_ca, "hop_index")) < 0) variable_struct_set(_ca, "hop_index", 0);
    if (!variable_struct_exists(_ca, "hop_dur") || !is_real(variable_struct_get(_ca, "hop_dur")) || real(variable_struct_get(_ca, "hop_dur")) <= 0) variable_struct_set(_ca, "hop_dur", 700);
    if (!variable_struct_exists(_ca, "hop_pause") || !is_real(variable_struct_get(_ca, "hop_pause")) || real(variable_struct_get(_ca, "hop_pause")) < 0) variable_struct_set(_ca, "hop_pause", 350);
    if (!variable_struct_exists(_ca, "escape_dur") || !is_real(variable_struct_get(_ca, "escape_dur")) || real(variable_struct_get(_ca, "escape_dur")) <= 0) variable_struct_set(_ca, "escape_dur", 320);
    return _ca;
}

function __battle_recover_stuck_catch_if_needed(_pid){
    var _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B) || !variable_struct_exists(_B, "_catch_anim")) return false;
    var _ca = variable_struct_get(_B, "_catch_anim");
    if (!is_struct(_ca) || !variable_struct_exists(_ca, "active") || _ca.active != true) return false;
    _ca = __battle_normalize_catch_anim(_ca);
    variable_struct_set(_B, "_catch_anim", _ca);
    var _phase_recover = variable_struct_exists(_ca, "phase") ? string(variable_struct_get(_ca, "phase")) : "";
    var _persist_recover = variable_struct_exists(_ca, "persistent") && variable_struct_get(_ca, "persistent") == true;
    var _finalized_recover = variable_struct_exists(_ca, "_finalized") && variable_struct_get(_ca, "_finalized") == true;
    if (_finalized_recover || (_phase_recover == "caught" && _persist_recover)) return false;
    var _start = variable_struct_exists(_ca, "start_ms") ? variable_struct_get(_ca, "start_ms") : undefined;
    if (!is_real(_start)) {
        variable_struct_set(_ca, "start_ms", current_time);
        variable_struct_set(_B, "_catch_anim", _ca);
        return false;
    }
    var _elapsed = current_time - _start;
    if (_elapsed < __battle_catch_anim_expected_ms(_ca)) return false;

    var _owner = __battle_catch_owner_pid(_B, _pid);
    var _outcome = (variable_struct_exists(_ca, "outcome") && variable_struct_get(_ca, "outcome") == true);
    if (_outcome){
        var _caught = variable_struct_exists(_ca, "caught_struct") ? variable_struct_get(_ca, "caught_struct") : undefined;
        try {
            var _final_fn = (variable_global_exists("_battle_impls") && is_struct(global._battle_impls) && variable_struct_exists(global._battle_impls, "__battle_finalize_catch") ? variable_struct_get(global._battle_impls, "__battle_finalize_catch") : undefined);
            if (!is_undefined(_final_fn)) _final_fn(_B, _caught);
            else {
                variable_struct_set(_B, "result", "caught");
                variable_struct_set(_B, "_pending_close", true);
                variable_struct_set(_ca, "phase", "caught");
                variable_struct_set(_ca, "persistent", true);
                variable_struct_set(_ca, "_finalized", true);
                variable_struct_set(_B, "_catch_anim", _ca);
            }
        } catch (e_catch_recover_success) {
            variable_struct_set(_B, "result", "caught");
            variable_struct_set(_B, "_pending_close", true);
            variable_struct_set(_ca, "_finalized", true);
            variable_struct_set(_B, "_catch_anim", _ca);
        }
    } else {
        try {
            if (!is_undefined(dialog2p_show_now)) dialog2p_show_now(_owner, "Oh no! The Pokemon broke free!");
            else if (!is_undefined(dialog2p_enqueue_text)) dialog2p_enqueue_text(_owner, "Oh no! The Pokemon broke free!", "Oh no! The Pokemon broke free!", "any");
        } catch (e_catch_recover_msg) {}
        variable_struct_set(_B, "_catch_anim", undefined);
        try { variable_struct_set(_B, "_action_active", false); } catch (e_catch_recover_act) {}
    }
    try { variable_struct_set(_B, "_input_grace_until", current_time - 1); } catch (e_catch_recover_grace) {}
    if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][catch] recovered stuck catch animation pid=" + string(_pid) + ", owner=" + string(_owner));
    return true;
}

// Progress and resolve per-slot animations (catch sequence)
function __battle_update_animations(_pid){
    var _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B)) return;
    if (!is_undefined(battle_anim_queue_tick)) battle_anim_queue_tick(_pid);
    if (!is_undefined(battle_cam_update)){
        var __cam_frame = battle_cam_update(_pid);
        if (is_struct(__cam_frame)){
            try { variable_struct_set(_B, "_cam_frame", __cam_frame); } catch (e_camframe) {}
        }
    }
    // Progress catch animation if present - delegate to animation module when available
    if (!is_undefined(__battle_anim_update)){
        var __anim_res = __battle_anim_update(_B);
        if (is_struct(__anim_res) && variable_struct_exists(__anim_res, "resolved") && variable_struct_get(__anim_res, "resolved")){
            var __anim_action = (variable_struct_exists(__anim_res, "action") ? variable_struct_get(__anim_res, "action") : undefined);
            if (!is_undefined(__anim_action) && __anim_action == "caught"){
                // finalize capture
                try { var _final_fn = (variable_global_exists("_battle_impls") && is_struct(global._battle_impls) && variable_struct_exists(global._battle_impls, "__battle_finalize_catch") ? variable_struct_get(global._battle_impls, "__battle_finalize_catch") : undefined); if (!is_undefined(_final_fn)) _final_fn(_B, _B._catch_anim ? _B._catch_anim.caught_struct : undefined); } catch (e_final) {}
            } else if (!is_undefined(__anim_action) && __anim_action == "broke"){
                // broke free - play a pok�ball-break sound if available, but do NOT play
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
                            // Clear any input grace so the player's selection press is accepted immediately
                            try { variable_struct_set(_B, "_input_grace_until", current_time - 1); } catch (e_igc) {}
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
                    // If this step was a 'to_full' (level up), show the side panel and pause progression.
                    if (variable_struct_exists(step, "type") && string(step.type) == "to_full"){
                        // Pop the corresponding per-level bumps and prepare the level-up panel.
                        var _lvlq = (variable_struct_exists(_B, "_level_stat_bumps_queue") ? variable_struct_get(_B, "_level_stat_bumps_queue") : []);
                        if (array_length(_lvlq) > 0){
                            var _entry = _lvlq[0];
                            // Remove the head entry
                            var _newlvlq = [];
                            for (var _jj = 1; _jj < array_length(_lvlq); ++_jj) array_push(_newlvlq, _lvlq[_jj]);
                            variable_struct_set(_B, "_level_stat_bumps_queue", _newlvlq);

                            __battle_begin_levelup_panel(_pid, _entry);
                            variable_struct_set(E, "waiting_for_panel", true);
                            variable_struct_set(_B, "_exp_anim", E);
                            // Do not advance playing_index here; we'll advance it when the panel finishes.
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
    A = __battle_normalize_catch_anim(A);
    variable_struct_set(_B, "_catch_anim", A);

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
        var hop_total = (variable_struct_exists(A, "hop_total") && is_real(A.hop_total)) ? max(1, floor(A.hop_total)) : 3;
        if (A.hop_index > hop_total){
            A.phase = (variable_struct_exists(A, "outcome") && A.outcome) ? "resolve" : "escape";
            A.phase_start = now;
            variable_struct_set(_B, "_catch_anim", A);
            return;
        }

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
                if (A.hop_index < hop_total){
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
            // Route the final catch result through the shared finalize hook so the
            // current battle flow and any future catch entry points use the same
            // party/PC persistence logic.
            var _final_fn_legacy = (variable_global_exists("_battle_impls") && is_struct(global._battle_impls) && variable_struct_exists(global._battle_impls, "__battle_finalize_catch") ? variable_struct_get(global._battle_impls, "__battle_finalize_catch") : undefined);
            if (!is_undefined(_final_fn_legacy)) _final_fn_legacy(_B, caught);
            else {
                _B._pending_close = true;
                A.phase = "caught";
                A.phase_start = now;
                A.persistent = true;
            }
        } else {
            // failed capture: transition to escape phase where the Pok�mon regrows and ball fades
            A.phase = "escape";
            A.phase_start = now;
            A.escape_dur = 320;
            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle][debug] catch phase -> escape (pid=" + string(_pid) + ")");
        }
    } else if (string(A.phase) == "escape"){
        var e5 = now - (variable_struct_exists(A, "phase_start") ? A.phase_start : now);
        if (e5 >= (is_real(A.escape_dur) ? A.escape_dur : 320)){
            // end escape: show broke free dialog and clear animation
            var _catch_msg_pid = __battle_catch_owner_pid(_B, _pid);
            try { if (!is_undefined(dialog2p_show_now)) dialog2p_show_now(_catch_msg_pid, "Oh no! The Pokemon broke free!"); else if (!is_undefined(dialog2p_enqueue_text)) dialog2p_enqueue_text(_catch_msg_pid, "Oh no! The Pokemon broke free!", "Oh no! The Pokemon broke free!", "any"); } catch (e_) {}
            A.active = false;
            _B._catch_anim = undefined;
        }
    }
}
