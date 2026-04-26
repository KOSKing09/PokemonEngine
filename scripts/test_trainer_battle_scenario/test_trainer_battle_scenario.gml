// Minimal trainer-battle test scenario helper
// Usage notes:
// - This script demonstrates two equivalent ways to open a trainer battle:
//   1) Use `pokemon_factory_create(species_id, level, opts)` to build party mons
//      and call `battle_open_trainer(pid, trainer_payload)` where `trainer_payload`
//      is a struct with keys: `trainer_name`, `sprite`, `sprite_index`, `party`,
//      `area_type`, and optional `trainer_reward`.
//   2) Alternatively you can call `battle_open(pid, level, opts)` with
//      `opts = { type: "trainer", enemy_party: [monStructs...], trainer_reward: N }`.
// - Important: `battle_update(pid)` must be called every Step and
//   `battle_draw_gui(pid)` must be called in Draw GUI for the battle to progress.
// - Example (from project comments):
//     var trainer_party = [ pokemon_factory_create(133,5,{}), pokemon_factory_create(10,5,{}), pokemon_factory_create(252,5,{}) ];
//     var trainer_payload = { trainer_name: "Bug Catcher Rick", sprite: spr_PokemonEmeraldTrainers, sprite_index: 12, party: trainer_party, area_type: "forest" };
//     battle_open_trainer(0, trainer_payload);
// - This helper is bound to F2 in `oPlayer/Step_1.gml` so it only runs when pressed.
function test_trainer_battle_scenario(){
    var trainer_party = [];
    if (!is_undefined(pokemon_factory_create)){
        trainer_party = [
            pokemon_factory_create(133, 5, {}),
            pokemon_factory_create(10, 5, {}),
            pokemon_factory_create(252, 5, {})
        ];
    } else {
        // Fallback minimal structs
        array_push(trainer_party, { species_id: 133, name: "Trainermon A", level: 5 });
        array_push(trainer_party, { species_id: 10, name: "Trainermon B", level: 5 });
        array_push(trainer_party, { species_id: 252, name: "Trainermon C", level: 5 });
    }
    var trainer_payload = {
        trainer_name: "Bug Catcher Rick",
        sprite: (variable_global_exists("spr_PokemonEmeraldTrainers") ? variable_global_get("spr_PokemonEmeraldTrainers") : undefined),
        sprite_index: 12,
        party: trainer_party,
        area_type: "forest",
        trainer_reward: 50
    };
    try { battle_open_trainer(0, trainer_payload); } catch (e) { show_debug_message("[test_trainer] battle_open_trainer failed: " + string(e)); }
}

function __dev_assign_moves_to_mon(_mon, _moves_array){
    if (!is_struct(_mon)) return false;
    var _moves_in = (is_array(_moves_array) ? _moves_array : []);
    if (!variable_struct_exists(_mon, "moves") || !is_array(variable_struct_get(_mon, "moves"))) variable_struct_set(_mon, "moves", [-1,-1,-1,-1]);
    if (!variable_struct_exists(_mon, "pps") || !is_array(variable_struct_get(_mon, "pps"))) variable_struct_set(_mon, "pps", [0,0,0,0]);
    var _moves = variable_struct_get(_mon, "moves");
    var _pps = variable_struct_get(_mon, "pps");
    for (var i = 0; i < 4; ++i){
        var _mid = -1;
        if (i < array_length(_moves_in) && is_real(_moves_in[i]) && _moves_in[i] > 0) _mid = floor(_moves_in[i]);
        _moves[i] = _mid;
        _pps[i] = (_mid > 0 && !is_undefined(__pfc_move_pp)) ? __pfc_move_pp(_mid) : ((_mid > 0) ? 10 : 0);
    }
    variable_struct_set(_mon, "moves", _moves);
    variable_struct_set(_mon, "pps", _pps);
    if (!variable_struct_exists(_mon, "seen_moves") || !is_array(variable_struct_get(_mon, "seen_moves"))) variable_struct_set(_mon, "seen_moves", []);
    var _seen = variable_struct_get(_mon, "seen_moves");
    for (var j = 0; j < array_length(_moves); ++j){
        var _seen_mid = _moves[j];
        if (!is_real(_seen_mid) || _seen_mid <= 0) continue;
        var _exists = false;
        for (var k = 0; k < array_length(_seen); ++k){ if (_seen[k] == _seen_mid) { _exists = true; break; } }
        if (!_exists) array_push(_seen, _seen_mid);
    }
    variable_struct_set(_mon, "seen_moves", _seen);
    return true;
}

function __status_smoke_hp_now(_actor){
    try {
        if (!is_undefined(__battle_hp_now)) return __battle_hp_now(_actor);
    } catch (e_hp_now) {}
    if (is_struct(_actor) && variable_struct_exists(_actor, "hp_now") && is_real(variable_struct_get(_actor, "hp_now"))) return variable_struct_get(_actor, "hp_now");
    if (is_struct(_actor) && variable_struct_exists(_actor, "hp") && is_real(variable_struct_get(_actor, "hp"))) return variable_struct_get(_actor, "hp");
    return -1;
}

function __status_smoke_log(_ok, _msg){
    show_debug_message("[smoke][status] " + string(_ok ? "PASS" : "FAIL") + " " + string(_msg));
}

function __status_smoke_finish(_pid, _state, _reason){
    var _tag = "status";
    var _global_name = "DEV_STATUS_SMOKE";
    var _auto_close = false;
    if (is_struct(_state)){
        if (variable_struct_exists(_state, "tag")) _tag = string(variable_struct_get(_state, "tag"));
        if (variable_struct_exists(_state, "global_name")) _global_name = string(variable_struct_get(_state, "global_name"));
        if (variable_struct_exists(_state, "auto_close")) _auto_close = (variable_struct_get(_state, "auto_close") == true);
        var _pass_n = (variable_struct_exists(_state, "pass_count") ? variable_struct_get(_state, "pass_count") : 0);
        var _fail_n = (variable_struct_exists(_state, "fail_count") ? variable_struct_get(_state, "fail_count") : 0);
        show_debug_message("[smoke][" + _tag + "] SUMMARY passes=" + string(_pass_n) + " fails=" + string(_fail_n) + " reason=" + string(_reason));
    }
    try { if (battle_is_open(_pid)) battle_close(_pid); } catch (e_close) {}
    try { if (string_length(_global_name) > 0 && variable_global_exists(_global_name)) variable_global_set(_global_name, undefined); } catch (e_clear) {}
    if (_auto_close) {
        show_debug_message("[smoke][" + _tag + "] auto-close requested; ending game after smoke completion");
        game_end();
    }
}

function __status_smoke_assert(_state, _ok, _msg){
    __status_smoke_log(_ok, _msg);
    if (!is_struct(_state)) return;
    if (_ok) variable_struct_set(_state, "pass_count", variable_struct_get(_state, "pass_count") + 1);
    else variable_struct_set(_state, "fail_count", variable_struct_get(_state, "fail_count") + 1);
}

function __status_smoke_find_slot(_actor, _move_id){
    if (!is_struct(_actor) || !variable_struct_exists(_actor, "moves") || !is_array(variable_struct_get(_actor, "moves"))) return -1;
    var _moves = variable_struct_get(_actor, "moves");
    for (var i = 0; i < array_length(_moves); ++i){
        if (_moves[i] == _move_id) return i;
    }
    return -1;
}

function __status_smoke_queue_turn(_pid, _player_slot, _enemy_move_id){
    var _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B) || !variable_struct_exists(_B, "actor") || !is_array(variable_struct_get(_B, "actor"))) return false;
    var _actors = variable_struct_get(_B, "actor");
    if (array_length(_actors) < 2) return false;
    var _player = _actors[0];
    var _enemy = _actors[1];
    if (!is_struct(_player) || !is_struct(_enemy)) return false;
    if (!is_real(_player_slot) || _player_slot < 0) return false;
    var _enemy_slot = __status_smoke_find_slot(_enemy, _enemy_move_id);
    if (_enemy_move_id > 0 && _enemy_slot < 0) return false;
    _B.turn_action_player = { slot: _player_slot, move_id: _player.moves[_player_slot], actor_index: 0, target_index: 1 };
    _B.turn_action_enemy = (_enemy_slot >= 0) ? { slot: _enemy_slot, move_id: _enemy_move_id, actor_index: 1, target_index: 0 } : undefined;
    _B.turn_queue = __battle_build_turn_actions(_pid);
    _B.turn_i = 0;
    try { variable_struct_set(_B, "_action_active", true); } catch (e_smoke_act) {}
    _B.phase = "turn";
    show_debug_message("[smoke][status] queued turn player_slot=" + string(_player_slot) + " enemy_move=" + string(_enemy_move_id));
    return true;
}

function __status_smoke_advance_dialog(_pid, _state){
    if (!is_undefined(party_is_open) && party_is_open(_pid)) return false;
    if (is_undefined(dialog2p_is_open) || !dialog2p_is_open(_pid)) return false;
    if (!variable_global_exists("DIALOG2P") || !is_array(global.DIALOG2P) || array_length(global.DIALOG2P) <= _pid) return true;
    var _d = global.DIALOG2P[_pid];
    if (!is_struct(_d)) return true;

    var _now = current_time;
    var _next_ms = (is_struct(_state) && variable_struct_exists(_state, "dialog_advance_ms") && is_real(variable_struct_get(_state, "dialog_advance_ms"))) ? variable_struct_get(_state, "dialog_advance_ms") : -1;
    if (is_real(_next_ms) && _next_ms > _now) return true;

    var _page_idx = (variable_struct_exists(_d, "page_idx") && is_real(variable_struct_get(_d, "page_idx"))) ? variable_struct_get(_d, "page_idx") : 0;
    var _all_lines = (variable_struct_exists(_d, "all_lines") && is_array(variable_struct_get(_d, "all_lines"))) ? variable_struct_get(_d, "all_lines") : [];
    var _i0 = _page_idx * 2;
    var _i1 = _i0 + 1;
    var _l0 = (_i0 < array_length(_all_lines)) ? string(_all_lines[_i0]) : "";
    var _l1 = (_i1 < array_length(_all_lines)) ? string(_all_lines[_i1]) : "";
    var _page_len = string_length(_l0 + "\n" + _l1);
    var _char_idx = (variable_struct_exists(_d, "char_idx") && is_real(variable_struct_get(_d, "char_idx"))) ? variable_struct_get(_d, "char_idx") : 0;
    if (_char_idx < _page_len) return true;

    if (!variable_global_exists("CTRL") || !is_struct(CTRL) || !variable_struct_exists(CTRL, "state") || !is_array(CTRL.state) || array_length(CTRL.state) <= _pid) return true;
    var _st = CTRL.state[_pid];
    if (!is_struct(_st) || !variable_struct_exists(_st, "pressed")) return true;
    var _pressed = variable_struct_get(_st, "pressed");
    if (!is_real(_pressed) || !ds_exists(_pressed, ds_type_map)) return true;

    ds_map_replace(_pressed, "Interact", true);
    try { dialog2p_update(_pid); } catch (e_smoke_dialog) {}
    ds_map_replace(_pressed, "Interact", false);
    if (is_struct(_state)) variable_struct_set(_state, "dialog_advance_ms", _now + 250);
    return true;
}

function test_battle_status_smoke_start(_auto_close = false){
    var _pid = 0;
    if (battle_is_open(_pid)) battle_close(_pid);
    var _party = party_ensure(_pid);
    if (!is_struct(_party)){
        show_debug_message("[smoke][status] FAIL unable to ensure player party");
        return false;
    }

    var _hero = pokemon_factory_create(133, 20, {});
    __dev_assign_moves_to_mon(_hero, [275, 1, 150, -1]);
    var _hero_max = 1;
    if (variable_struct_exists(_hero, "hp_max") && is_real(variable_struct_get(_hero, "hp_max"))) _hero_max = max(1, variable_struct_get(_hero, "hp_max"));
    var _hero_start_hp = max(1, _hero_max - max(2, floor(_hero_max / 4)));
    variable_struct_set(_hero, "hp_now", _hero_start_hp);
    variable_struct_set(_hero, "hp", _hero_start_hp);
    variable_struct_set(_hero, "grounded", false);
    _party.mons[0] = _hero;
    global.PARTY[_pid] = _party;

    var _foe = pokemon_factory_create(10, 20, {});
    __dev_assign_moves_to_mon(_foe, [259, 150, -1, -1]);
    var _trainer_payload = {
        trainer_name: "Status Smoke",
        sprite: (variable_global_exists("spr_PokemonEmeraldTrainers") ? variable_global_get("spr_PokemonEmeraldTrainers") : undefined),
        sprite_index: 12,
        party: [_foe],
        area_type: "forest",
        trainer_reward: 0
    };

    global.DEV_STATUS_SMOKE = {
        pid: _pid,
        tag: "status",
        global_name: "DEV_STATUS_SMOKE",
        auto_close: (_auto_close == true),
        state: "opening",
        baseline_hp: _hero_start_hp,
        turn_counter: 0,
        pass_count: 0,
        fail_count: 0,
        repeat_enemy_hp: -1,
        repeat_pp: -1,
        started_ms: current_time
    };
    show_debug_message("[smoke][status] starting Ingrain/Torment smoke battle");
    battle_open_trainer(_pid, _trainer_payload);
    return true;
}

function test_battle_status_smoke_update(_pid = 0){
    if (!variable_global_exists("DEV_STATUS_SMOKE")) return;
    var _S = global.DEV_STATUS_SMOKE;
    if (!is_struct(_S)) return;
    if (_pid != variable_struct_get(_S, "pid")) return;
    variable_struct_set(_S, "turn_counter", variable_struct_get(_S, "turn_counter") + 1);
    if (variable_struct_get(_S, "turn_counter") > 3600){
        __status_smoke_assert(_S, false, "timed out waiting for smoke scenario to finish");
        __status_smoke_finish(_pid, _S, "timeout");
        return;
    }
    if (!battle_is_open(_pid)) return;
    if (__status_smoke_advance_dialog(_pid, _S)) return;

    var _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B) || !variable_struct_exists(_B, "actor") || !is_array(variable_struct_get(_B, "actor"))) return;
    var _actors = variable_struct_get(_B, "actor");
    if (array_length(_actors) < 2) return;
    var _hero = _actors[0];
    var _foe = _actors[1];
    if (!is_struct(_hero) || !is_struct(_foe)) return;
    if (!variable_struct_exists(_B, "phase") || variable_struct_get(_B, "phase") != "command") return;

    var _state = string(variable_struct_get(_S, "state"));
    switch (_state){
        case "opening":
            if (__status_smoke_queue_turn(_pid, 0, 150)) variable_struct_set(_S, "state", "await_ingrain");
            break;

        case "await_ingrain":
            var _hp_after_ingrain = __status_smoke_hp_now(_hero);
            var _has_ingrain = (!is_undefined(status_system_has_status) && status_system_has_status(_hero, "ingrain"));
            var _grounded = false;
            try { _grounded = (variable_struct_exists(_hero, "grounded") && variable_struct_get(_hero, "grounded") == true); } catch (e_grd) { _grounded = false; }
            __status_smoke_assert(_S, _has_ingrain, "Ingrain status applied to player");
            __status_smoke_assert(_S, _grounded, "Ingrain grounded the player");
            __status_smoke_assert(_S, _hp_after_ingrain > variable_struct_get(_S, "baseline_hp"), "Ingrain healed player above baseline HP");
            if (__status_smoke_queue_turn(_pid, 1, 259)) variable_struct_set(_S, "state", "await_torment");
            break;

        case "await_torment":
            var _tormented = (!is_undefined(status_system_has_status) && status_system_has_status(_hero, "torment"));
            __status_smoke_assert(_S, _tormented, "Torment status applied to player");
            variable_struct_set(_S, "repeat_enemy_hp", __status_smoke_hp_now(_foe));
            var _hero_pps = (variable_struct_exists(_hero, "pps") && is_array(variable_struct_get(_hero, "pps")) ? variable_struct_get(_hero, "pps") : []);
            variable_struct_set(_S, "repeat_pp", (array_length(_hero_pps) > 1 ? _hero_pps[1] : -1));
            if (__status_smoke_queue_turn(_pid, 1, 150)) variable_struct_set(_S, "state", "await_repeat_block");
            break;

        case "await_repeat_block":
            var _enemy_hp_after = __status_smoke_hp_now(_foe);
            var _hero_pps_after = (variable_struct_exists(_hero, "pps") && is_array(variable_struct_get(_hero, "pps")) ? variable_struct_get(_hero, "pps") : []);
            var _repeat_pp_after = (array_length(_hero_pps_after) > 1 ? _hero_pps_after[1] : -1);
            __status_smoke_assert(_S, _enemy_hp_after == variable_struct_get(_S, "repeat_enemy_hp"), "Torment prevented repeated Pound from damaging enemy");
            __status_smoke_assert(_S, _repeat_pp_after == variable_struct_get(_S, "repeat_pp"), "Torment prevented repeated Pound from consuming PP");
            __status_smoke_finish(_pid, _S, "completed");
            break;
    }
}

function test_battle_heal_block_smoke_start(_auto_close = false){
    var _pid = 0;
    if (battle_is_open(_pid)) battle_close(_pid);
    var _party = party_ensure(_pid);
    if (!is_struct(_party)){
        show_debug_message("[smoke][heal-block] FAIL unable to ensure player party");
        return false;
    }

    var _hero = pokemon_factory_create(133, 20, {});
    __dev_assign_moves_to_mon(_hero, [105, 156, 1, -1]);
    var _hero_max = max(1, (variable_struct_exists(_hero, "hp_max") && is_real(variable_struct_get(_hero, "hp_max")) ? variable_struct_get(_hero, "hp_max") : 1));
    var _hero_start_hp = max(1, _hero_max - max(8, floor(_hero_max / 3)));
    variable_struct_set(_hero, "hp_now", _hero_start_hp);
    variable_struct_set(_hero, "hp", _hero_start_hp);
    _party.mons[0] = _hero;
    global.PARTY[_pid] = _party;

    var _foe = pokemon_factory_create(10, 20, {});
    __dev_assign_moves_to_mon(_foe, [377, 150, -1, -1]);
    var _trainer_payload = {
        trainer_name: "Heal Block Smoke",
        sprite: (variable_global_exists("spr_PokemonEmeraldTrainers") ? variable_global_get("spr_PokemonEmeraldTrainers") : undefined),
        sprite_index: 12,
        party: [_foe],
        area_type: "forest",
        trainer_reward: 0
    };

    global.DEV_HEAL_BLOCK_SMOKE = {
        pid: _pid,
        tag: "heal-block",
        global_name: "DEV_HEAL_BLOCK_SMOKE",
        auto_close: (_auto_close == true),
        state: "opening",
        baseline_hp: _hero_start_hp,
        turn_counter: 0,
        pass_count: 0,
        fail_count: 0,
        recover_pp: -1,
        rest_pp: -1,
        started_ms: current_time
    };
    show_debug_message("[smoke][heal-block] starting Heal Block smoke battle");
    battle_open_trainer(_pid, _trainer_payload);
    return true;
}

function test_battle_heal_block_smoke_update(_pid = 0){
    if (!variable_global_exists("DEV_HEAL_BLOCK_SMOKE")) return;
    var _S = global.DEV_HEAL_BLOCK_SMOKE;
    if (!is_struct(_S)) return;
    if (_pid != variable_struct_get(_S, "pid")) return;
    variable_struct_set(_S, "turn_counter", variable_struct_get(_S, "turn_counter") + 1);
    if (variable_struct_get(_S, "turn_counter") > 3600){
        __status_smoke_assert(_S, false, "timed out waiting for smoke scenario to finish");
        __status_smoke_finish(_pid, _S, "timeout");
        return;
    }
    if (!battle_is_open(_pid)) return;
    if (__status_smoke_advance_dialog(_pid, _S)) return;

    var _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B) || !variable_struct_exists(_B, "actor") || !is_array(variable_struct_get(_B, "actor"))) return;
    var _actors = variable_struct_get(_B, "actor");
    if (array_length(_actors) < 2) return;
    var _hero = _actors[0];
    var _foe = _actors[1];
    if (!is_struct(_hero) || !is_struct(_foe)) return;
    if (!variable_struct_exists(_B, "phase") || variable_struct_get(_B, "phase") != "command") return;

    var _state = string(variable_struct_get(_S, "state"));
    switch (_state){
        case "opening":
            if (__status_smoke_queue_turn(_pid, 2, 377)) variable_struct_set(_S, "state", "await_heal_block");
            break;

        case "await_heal_block":
            var _has_hb = (!is_undefined(status_system_has_status) && status_system_has_status(_hero, "heal-block"));
            __status_smoke_log(_has_hb, "Heal Block status applied to player");
            if (_has_hb) variable_struct_set(_S, "pass_count", variable_struct_get(_S, "pass_count") + 1); else variable_struct_set(_S, "fail_count", variable_struct_get(_S, "fail_count") + 1);
            var _pps_now = (variable_struct_exists(_hero, "pps") && is_array(variable_struct_get(_hero, "pps")) ? variable_struct_get(_hero, "pps") : []);
            variable_struct_set(_S, "recover_pp", (array_length(_pps_now) > 0 ? _pps_now[0] : -1));
            if (__status_smoke_queue_turn(_pid, 0, 150)) variable_struct_set(_S, "state", "await_recover_block");
            break;

        case "await_recover_block":
            var _hp_after_recover = __status_smoke_hp_now(_hero);
            var _pps_after_recover = (variable_struct_exists(_hero, "pps") && is_array(variable_struct_get(_hero, "pps")) ? variable_struct_get(_hero, "pps") : []);
            var _recover_pp_after = (array_length(_pps_after_recover) > 0 ? _pps_after_recover[0] : -1);
            __status_smoke_log(_hp_after_recover == variable_struct_get(_S, "baseline_hp"), "Heal Block prevented Recover healing");
            if (_hp_after_recover == variable_struct_get(_S, "baseline_hp")) variable_struct_set(_S, "pass_count", variable_struct_get(_S, "pass_count") + 1); else variable_struct_set(_S, "fail_count", variable_struct_get(_S, "fail_count") + 1);
            __status_smoke_log(_recover_pp_after == variable_struct_get(_S, "recover_pp"), "Heal Block prevented Recover PP consumption");
            if (_recover_pp_after == variable_struct_get(_S, "recover_pp")) variable_struct_set(_S, "pass_count", variable_struct_get(_S, "pass_count") + 1); else variable_struct_set(_S, "fail_count", variable_struct_get(_S, "fail_count") + 1);
            variable_struct_set(_S, "rest_pp", (array_length(_pps_after_recover) > 1 ? _pps_after_recover[1] : -1));
            if (__status_smoke_queue_turn(_pid, 1, 150)) variable_struct_set(_S, "state", "await_rest_block");
            break;

        case "await_rest_block":
            var _hp_after_rest = __status_smoke_hp_now(_hero);
            var _pps_after_rest = (variable_struct_exists(_hero, "pps") && is_array(variable_struct_get(_hero, "pps")) ? variable_struct_get(_hero, "pps") : []);
            var _rest_pp_after = (array_length(_pps_after_rest) > 1 ? _pps_after_rest[1] : -1);
            __status_smoke_log(_hp_after_rest == variable_struct_get(_S, "baseline_hp"), "Heal Block prevented Rest healing");
            if (_hp_after_rest == variable_struct_get(_S, "baseline_hp")) variable_struct_set(_S, "pass_count", variable_struct_get(_S, "pass_count") + 1); else variable_struct_set(_S, "fail_count", variable_struct_get(_S, "fail_count") + 1);
            __status_smoke_log(_rest_pp_after == variable_struct_get(_S, "rest_pp"), "Heal Block prevented Rest PP consumption");
            if (_rest_pp_after == variable_struct_get(_S, "rest_pp")) variable_struct_set(_S, "pass_count", variable_struct_get(_S, "pass_count") + 1); else variable_struct_set(_S, "fail_count", variable_struct_get(_S, "fail_count") + 1);
            __status_smoke_finish(_pid, _S, "completed");
            break;
    }
}

function test_battle_embargo_smoke_start(_auto_close = false){
    var _pid = 0;
    if (battle_is_open(_pid)) battle_close(_pid);
    var _party = party_ensure(_pid);
    if (!is_struct(_party)){
        show_debug_message("[smoke][embargo] FAIL unable to ensure player party");
        return false;
    }

    var _hero = pokemon_factory_create(133, 20, {});
    __dev_assign_moves_to_mon(_hero, [113, 1, -1, -1]);
    variable_struct_set(_hero, "held_item_id", 246);
    variable_struct_set(_hero, "held_item_real_name", "light-clay");
    _party.mons[0] = _hero;
    global.PARTY[_pid] = _party;

    var _foe = pokemon_factory_create(10, 20, {});
    __dev_assign_moves_to_mon(_foe, [373, 150, -1, -1]);
    var _trainer_payload = {
        trainer_name: "Embargo Smoke",
        sprite: (variable_global_exists("spr_PokemonEmeraldTrainers") ? variable_global_get("spr_PokemonEmeraldTrainers") : undefined),
        sprite_index: 12,
        party: [_foe],
        area_type: "forest",
        trainer_reward: 0
    };

    global.DEV_EMBARGO_SMOKE = {
        pid: _pid,
        tag: "embargo",
        global_name: "DEV_EMBARGO_SMOKE",
        auto_close: (_auto_close == true),
        state: "opening",
        turn_counter: 0,
        pass_count: 0,
        fail_count: 0,
        started_ms: current_time
    };
    show_debug_message("[smoke][embargo] starting Embargo smoke battle");
    battle_open_trainer(_pid, _trainer_payload);
    return true;
}

function test_battle_embargo_smoke_update(_pid = 0){
    if (!variable_global_exists("DEV_EMBARGO_SMOKE")) return;
    var _S = global.DEV_EMBARGO_SMOKE;
    if (!is_struct(_S)) return;
    if (_pid != variable_struct_get(_S, "pid")) return;
    variable_struct_set(_S, "turn_counter", variable_struct_get(_S, "turn_counter") + 1);
    if (variable_struct_get(_S, "turn_counter") > 3600){
        __status_smoke_assert(_S, false, "timed out waiting for smoke scenario to finish");
        __status_smoke_finish(_pid, _S, "timeout");
        return;
    }
    if (!battle_is_open(_pid)) return;
    if (__status_smoke_advance_dialog(_pid, _S)) return;

    var _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B) || !variable_struct_exists(_B, "actor") || !is_array(variable_struct_get(_B, "actor"))) return;
    var _actors = variable_struct_get(_B, "actor");
    if (array_length(_actors) < 2) return;
    var _hero = _actors[0];
    var _foe = _actors[1];
    if (!is_struct(_hero) || !is_struct(_foe)) return;
    if (!variable_struct_exists(_B, "phase") || variable_struct_get(_B, "phase") != "command") return;

    var _state = string(variable_struct_get(_S, "state"));
    switch (_state){
        case "opening":
            if (__status_smoke_queue_turn(_pid, 1, 373)) variable_struct_set(_S, "state", "await_embargo");
            break;

        case "await_embargo":
            var _has_embargo = (!is_undefined(status_system_has_status) && status_system_has_status(_hero, "embargo"));
            __status_smoke_log(_has_embargo, "Embargo status applied to player");
            if (_has_embargo) variable_struct_set(_S, "pass_count", variable_struct_get(_S, "pass_count") + 1); else variable_struct_set(_S, "fail_count", variable_struct_get(_S, "fail_count") + 1);
            var _held_items_blocked = (!is_undefined(__battle_meta_held_items_enabled) && __battle_meta_held_items_enabled(_hero) == false);
            __status_smoke_log(_held_items_blocked, "Embargo disabled held-item benefits for the player");
            if (_held_items_blocked) variable_struct_set(_S, "pass_count", variable_struct_get(_S, "pass_count") + 1); else variable_struct_set(_S, "fail_count", variable_struct_get(_S, "fail_count") + 1);
            var _item_block_msg = "";
            try {
                if (!is_undefined(bag__battle_item_target_block_reason)) _item_block_msg = string(bag__battle_item_target_block_reason(_pid, _hero, 17));
            } catch (e_item_block_check) { _item_block_msg = ""; }
            var _items_blocked = (string_length(_item_block_msg) > 0);
            __status_smoke_log(_items_blocked, "Embargo blocked battle item targeting on the player");
            if (_items_blocked) variable_struct_set(_S, "pass_count", variable_struct_get(_S, "pass_count") + 1); else variable_struct_set(_S, "fail_count", variable_struct_get(_S, "fail_count") + 1);
            if (__status_smoke_queue_turn(_pid, 0, 150)) variable_struct_set(_S, "state", "await_light_screen");
            break;

        case "await_light_screen":
            var _light_screen_turns = 0;
            try { _light_screen_turns = __battle_field_get_barrier_or(_pid, 0, "light_screen", 0); } catch (e_barrier_turns) { _light_screen_turns = 0; }
            __status_smoke_log(_light_screen_turns == 4, "Embargo prevented Light Clay from extending Light Screen (post-turn barrier=" + string(_light_screen_turns) + ")");
            if (_light_screen_turns == 4) variable_struct_set(_S, "pass_count", variable_struct_get(_S, "pass_count") + 1); else variable_struct_set(_S, "fail_count", variable_struct_get(_S, "fail_count") + 1);
            __status_smoke_finish(_pid, _S, "completed");
            break;
    }
}

function test_battle_perish_song_smoke_start(_auto_close = false){
    var _pid = 0;
    if (battle_is_open(_pid)) battle_close(_pid);
    var _party = party_ensure(_pid);
    if (!is_struct(_party)){
        show_debug_message("[smoke][perish-song] FAIL unable to ensure player party");
        return false;
    }

    var _hero = pokemon_factory_create(133, 20, {});
    __dev_assign_moves_to_mon(_hero, [150, -1, -1, -1]);
    var _backup = pokemon_factory_create(25, 20, {});
    __dev_assign_moves_to_mon(_backup, [150, -1, -1, -1]);
    _party.mons[0] = _hero;
    _party.mons[1] = _backup;
    global.PARTY[_pid] = _party;

    var _foe = pokemon_factory_create(10, 20, {});
    __dev_assign_moves_to_mon(_foe, [195, 150, -1, -1]);
    variable_struct_set(_foe, "ability", "soundproof");
    var _trainer_payload = {
        trainer_name: "Perish Song Smoke",
        sprite: (variable_global_exists("spr_PokemonEmeraldTrainers") ? variable_global_get("spr_PokemonEmeraldTrainers") : undefined),
        sprite_index: 12,
        party: [_foe],
        area_type: "forest",
        trainer_reward: 0
    };

    global.DEV_PERISH_SONG_SMOKE = {
        pid: _pid,
        tag: "perish-song",
        global_name: "DEV_PERISH_SONG_SMOKE",
        auto_close: (_auto_close == true),
        state: "opening",
        turn_counter: 0,
        pass_count: 0,
        fail_count: 0,
        started_ms: current_time
    };
    show_debug_message("[smoke][perish-song] starting Perish Song smoke battle");
    battle_open_trainer(_pid, _trainer_payload);
    return true;
}

function test_battle_perish_song_smoke_update(_pid = 0){
    if (!variable_global_exists("DEV_PERISH_SONG_SMOKE")) return;
    var _S = global.DEV_PERISH_SONG_SMOKE;
    if (!is_struct(_S)) return;
    if (_pid != variable_struct_get(_S, "pid")) return;
    variable_struct_set(_S, "turn_counter", variable_struct_get(_S, "turn_counter") + 1);
    if (variable_struct_get(_S, "turn_counter") > 3600){
        __status_smoke_assert(_S, false, "timed out waiting for smoke scenario to finish");
        __status_smoke_finish(_pid, _S, "timeout");
        return;
    }
    if (!battle_is_open(_pid)) return;
    if (__status_smoke_advance_dialog(_pid, _S)) return;

    var _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B) || !variable_struct_exists(_B, "actor") || !is_array(variable_struct_get(_B, "actor"))) return;
    var _actors = variable_struct_get(_B, "actor");
    if (array_length(_actors) < 2) return;
    var _hero = _actors[0];
    var _foe = _actors[1];
    if (!is_struct(_hero) || !is_struct(_foe)) return;
    if (!variable_struct_exists(_B, "phase") || variable_struct_get(_B, "phase") != "command") return;

    var _state = string(variable_struct_get(_S, "state"));
    var _hero_perish = (!is_undefined(status_system_get) ? status_system_get(_hero, "perish-song") : undefined);
    var _foe_perish = (!is_undefined(status_system_get) ? status_system_get(_foe, "perish-song") : undefined);
    var _hero_turns = (is_struct(_hero_perish) && variable_struct_exists(_hero_perish, "turns") && is_real(variable_struct_get(_hero_perish, "turns"))) ? variable_struct_get(_hero_perish, "turns") : -1;
    var _foe_turns = (is_struct(_foe_perish) && variable_struct_exists(_foe_perish, "turns") && is_real(variable_struct_get(_foe_perish, "turns"))) ? variable_struct_get(_foe_perish, "turns") : -1;
    switch (_state){
        case "opening":
            if (__status_smoke_queue_turn(_pid, 0, 195)) variable_struct_set(_S, "state", "await_count_3");
            break;

        case "await_count_3":
            __status_smoke_assert(_S, is_struct(_hero_perish), "Perish Song status applied to the player");
            __status_smoke_assert(_S, !is_struct(_foe_perish), "Soundproof prevented Perish Song on the user");
            __status_smoke_assert(_S, _hero_turns == 3, "Perish Song countdown reached 3 after the first turn");
            if (__status_smoke_queue_turn(_pid, 0, 150)) variable_struct_set(_S, "state", "await_count_2");
            break;

        case "await_count_2":
            __status_smoke_assert(_S, _hero_turns == 2, "Perish Song countdown reached 2 after the second turn");
            if (__status_smoke_queue_turn(_pid, 0, 150)) variable_struct_set(_S, "state", "await_count_1");
            break;

        case "await_count_1":
            __status_smoke_assert(_S, _hero_turns == 1, "Perish Song countdown reached 1 after the third turn");
            __status_smoke_finish(_pid, _S, "completed");
            break;
    }
}

function test_battle_endure_smoke_start(_auto_close = false){
    var _pid = 0;
    if (battle_is_open(_pid)) battle_close(_pid);
    var _party = party_ensure(_pid);
    if (!is_struct(_party)){
        show_debug_message("[smoke][endure] FAIL unable to ensure player party");
        return false;
    }

    var _hero = pokemon_factory_create(133, 20, {});
    __dev_assign_moves_to_mon(_hero, [203, 150, -1, -1]);
    variable_struct_set(_hero, "hp_now", 2);
    variable_struct_set(_hero, "hp", 2);
    _party.mons[0] = _hero;
    global.PARTY[_pid] = _party;

    var _foe = pokemon_factory_create(10, 20, {});
    __dev_assign_moves_to_mon(_foe, [1, 150, -1, -1]);
    var _trainer_payload = {
        trainer_name: "Endure Smoke",
        sprite: (variable_global_exists("spr_PokemonEmeraldTrainers") ? variable_global_get("spr_PokemonEmeraldTrainers") : undefined),
        sprite_index: 12,
        party: [_foe],
        area_type: "forest",
        trainer_reward: 0
    };

    global.DEV_ENDURE_SMOKE = {
        pid: _pid,
        tag: "endure",
        global_name: "DEV_ENDURE_SMOKE",
        auto_close: (_auto_close == true),
        state: "opening",
        turn_counter: 0,
        pass_count: 0,
        fail_count: 0,
        started_ms: current_time
    };
    show_debug_message("[smoke][endure] starting Endure smoke battle");
    battle_open_trainer(_pid, _trainer_payload);
    return true;
}

function test_battle_endure_smoke_update(_pid = 0){
    if (!variable_global_exists("DEV_ENDURE_SMOKE")) return;
    var _S = global.DEV_ENDURE_SMOKE;
    if (!is_struct(_S)) return;
    if (_pid != variable_struct_get(_S, "pid")) return;
    variable_struct_set(_S, "turn_counter", variable_struct_get(_S, "turn_counter") + 1);
    if (variable_struct_get(_S, "turn_counter") > 3600){
        __status_smoke_assert(_S, false, "timed out waiting for smoke scenario to finish");
        __status_smoke_finish(_pid, _S, "timeout");
        return;
    }
    if (!battle_is_open(_pid)) return;
    if (__status_smoke_advance_dialog(_pid, _S)) return;

    var _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B) || !variable_struct_exists(_B, "actor") || !is_array(variable_struct_get(_B, "actor"))) return;
    var _actors = variable_struct_get(_B, "actor");
    if (array_length(_actors) < 2) return;
    var _hero = _actors[0];
    var _foe = _actors[1];
    if (!is_struct(_hero) || !is_struct(_foe)) return;
    if (!variable_struct_exists(_B, "phase") || variable_struct_get(_B, "phase") != "command") return;

    var _state = string(variable_struct_get(_S, "state"));
    switch (_state){
        case "opening":
            if (__status_smoke_queue_turn(_pid, 0, 1)) variable_struct_set(_S, "state", "await_endure");
            break;

        case "await_endure":
            var _hero_hp = __status_smoke_hp_now(_hero);
            var _is_enduring = false;
            try { _is_enduring = (variable_struct_exists(_hero, "_enduring") && variable_struct_get(_hero, "_enduring") == true); } catch (e_endure_flag) { _is_enduring = false; }
            __status_smoke_assert(_S, _hero_hp == 1, "Endure left the player at 1 HP after a lethal hit");
            __status_smoke_assert(_S, _is_enduring, "Endure flag remained active through the protected turn");
            __status_smoke_finish(_pid, _S, "completed");
            break;
    }
}

function test_battle_rollout_smoke_start(_auto_close = false){
    var _pid = 0;
    if (battle_is_open(_pid)) battle_close(_pid);
    var _party = party_ensure(_pid);
    if (!is_struct(_party)){
        show_debug_message("[smoke][rollout] FAIL unable to ensure player party");
        return false;
    }

    var _hero = pokemon_factory_create(133, 20, {});
    __dev_assign_moves_to_mon(_hero, [205, 150, -1, -1]);
    _party.mons[0] = _hero;
    global.PARTY[_pid] = _party;

    var _foe = pokemon_factory_create(10, 20, {});
    __dev_assign_moves_to_mon(_foe, [150, -1, -1, -1]);
    var _trainer_payload = {
        trainer_name: "Rollout Smoke",
        sprite: (variable_global_exists("spr_PokemonEmeraldTrainers") ? variable_global_get("spr_PokemonEmeraldTrainers") : undefined),
        sprite_index: 12,
        party: [_foe],
        area_type: "forest",
        trainer_reward: 0
    };

    global.DEV_ROLLOUT_SMOKE = {
        pid: _pid,
        tag: "rollout",
        global_name: "DEV_ROLLOUT_SMOKE",
        auto_close: (_auto_close == true),
        state: "opening",
        turn_counter: 0,
        pass_count: 0,
        fail_count: 0,
        foe_baseline_hp: 0,
        foe_hp_after_first: 0,
        first_damage: 0,
        started_ms: current_time
    };
    show_debug_message("[smoke][rollout] starting Rollout smoke battle");
    battle_open_trainer(_pid, _trainer_payload);
    return true;
}

function test_battle_rollout_smoke_update(_pid = 0){
    if (!variable_global_exists("DEV_ROLLOUT_SMOKE")) return;
    var _S = global.DEV_ROLLOUT_SMOKE;
    if (!is_struct(_S)) return;
    if (_pid != variable_struct_get(_S, "pid")) return;
    variable_struct_set(_S, "turn_counter", variable_struct_get(_S, "turn_counter") + 1);
    if (variable_struct_get(_S, "turn_counter") > 3600){
        __status_smoke_assert(_S, false, "timed out waiting for smoke scenario to finish");
        __status_smoke_finish(_pid, _S, "timeout");
        return;
    }
    if (!battle_is_open(_pid)) return;
    if (__status_smoke_advance_dialog(_pid, _S)) return;

    var _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B) || !variable_struct_exists(_B, "actor") || !is_array(variable_struct_get(_B, "actor"))) return;
    var _actors = variable_struct_get(_B, "actor");
    if (array_length(_actors) < 2) return;
    var _hero = _actors[0];
    var _foe = _actors[1];
    if (!is_struct(_hero) || !is_struct(_foe)) return;
    if (!variable_struct_exists(_B, "phase") || variable_struct_get(_B, "phase") != "command") return;

    var _state = string(variable_struct_get(_S, "state"));
    switch (_state){
        case "opening":
            variable_struct_set(_S, "foe_baseline_hp", __status_smoke_hp_now(_foe));
            if (__status_smoke_queue_turn(_pid, 0, 150)) variable_struct_set(_S, "state", "await_first_hit");
            break;

        case "await_first_hit":
            var _foe_hp_1 = __status_smoke_hp_now(_foe);
            var _first_damage = max(0, variable_struct_get(_S, "foe_baseline_hp") - _foe_hp_1);
            var _lock = (variable_struct_exists(_hero, "_locked_move") ? variable_struct_get(_hero, "_locked_move") : undefined);
            var _rollout_locked = (is_struct(_lock) && variable_struct_exists(_lock, "move_id") && variable_struct_get(_lock, "move_id") == 205);
            var _rollout_mul = (variable_struct_exists(_hero, "_rollout_mul") && is_real(variable_struct_get(_hero, "_rollout_mul"))) ? variable_struct_get(_hero, "_rollout_mul") : -1;
            __status_smoke_assert(_S, _rollout_locked, "Rollout locked the player into repeated use");
            __status_smoke_assert(_S, _rollout_mul == 2, "Rollout doubled its stored multiplier after the first hit");
            variable_struct_set(_S, "foe_hp_after_first", _foe_hp_1);
            variable_struct_set(_S, "first_damage", _first_damage);
            if (__status_smoke_queue_turn(_pid, 1, 150)) variable_struct_set(_S, "state", "await_second_hit");
            break;

        case "await_second_hit":
            var _foe_hp_2 = __status_smoke_hp_now(_foe);
            var _second_damage = max(0, variable_struct_get(_S, "foe_hp_after_first") - _foe_hp_2);
            __status_smoke_assert(_S, _second_damage > variable_struct_get(_S, "first_damage"), "Rollout's second forced hit dealt more damage than the first");
            __status_smoke_finish(_pid, _S, "completed");
            break;
    }
}

function test_battle_fury_cutter_smoke_start(_auto_close = false){
    var _pid = 0;
    if (battle_is_open(_pid)) battle_close(_pid);
    var _party = party_ensure(_pid);
    if (!is_struct(_party)){
        show_debug_message("[smoke][fury-cutter] FAIL unable to ensure player party");
        return false;
    }

    var _hero = pokemon_factory_create(133, 20, {});
    __dev_assign_moves_to_mon(_hero, [210, 150, -1, -1]);
    _party.mons[0] = _hero;
    global.PARTY[_pid] = _party;

    var _foe = pokemon_factory_create(10, 20, {});
    __dev_assign_moves_to_mon(_foe, [150, -1, -1, -1]);
    var _trainer_payload = {
        trainer_name: "Fury Cutter Smoke",
        sprite: (variable_global_exists("spr_PokemonEmeraldTrainers") ? variable_global_get("spr_PokemonEmeraldTrainers") : undefined),
        sprite_index: 12,
        party: [_foe],
        area_type: "forest",
        trainer_reward: 0
    };

    global.DEV_FURY_CUTTER_SMOKE = {
        pid: _pid,
        tag: "fury-cutter",
        global_name: "DEV_FURY_CUTTER_SMOKE",
        auto_close: (_auto_close == true),
        state: "opening",
        turn_counter: 0,
        pass_count: 0,
        fail_count: 0,
        foe_baseline_hp: 0,
        foe_hp_after_first: 0,
        first_damage: 0,
        started_ms: current_time
    };
    show_debug_message("[smoke][fury-cutter] starting Fury Cutter smoke battle");
    battle_open_trainer(_pid, _trainer_payload);
    return true;
}

function test_battle_fury_cutter_smoke_update(_pid = 0){
    if (!variable_global_exists("DEV_FURY_CUTTER_SMOKE")) return;
    var _S = global.DEV_FURY_CUTTER_SMOKE;
    if (!is_struct(_S)) return;
    if (_pid != variable_struct_get(_S, "pid")) return;
    variable_struct_set(_S, "turn_counter", variable_struct_get(_S, "turn_counter") + 1);
    if (variable_struct_get(_S, "turn_counter") > 3600){
        __status_smoke_assert(_S, false, "timed out waiting for smoke scenario to finish");
        __status_smoke_finish(_pid, _S, "timeout");
        return;
    }
    if (!battle_is_open(_pid)) return;
    if (__status_smoke_advance_dialog(_pid, _S)) return;

    var _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B) || !variable_struct_exists(_B, "actor") || !is_array(variable_struct_get(_B, "actor"))) return;
    var _actors = variable_struct_get(_B, "actor");
    if (array_length(_actors) < 2) return;
    var _hero = _actors[0];
    var _foe = _actors[1];
    if (!is_struct(_hero) || !is_struct(_foe)) return;
    if (!variable_struct_exists(_B, "phase") || variable_struct_get(_B, "phase") != "command") return;

    var _state = string(variable_struct_get(_S, "state"));
    switch (_state){
        case "opening":
            variable_struct_set(_S, "foe_baseline_hp", __status_smoke_hp_now(_foe));
            if (__status_smoke_queue_turn(_pid, 0, 150)) variable_struct_set(_S, "state", "await_first_hit");
            break;

        case "await_first_hit":
            var _foe_hp_1 = __status_smoke_hp_now(_foe);
            var _first_damage = max(0, variable_struct_get(_S, "foe_baseline_hp") - _foe_hp_1);
            var _fury_mul_1 = (variable_struct_exists(_hero, "_fury_cutter_mul") && is_real(variable_struct_get(_hero, "_fury_cutter_mul"))) ? variable_struct_get(_hero, "_fury_cutter_mul") : -1;
            __status_smoke_assert(_S, _first_damage > 0, "Fury Cutter dealt damage on its first hit");
            __status_smoke_assert(_S, _fury_mul_1 == 2, "Fury Cutter doubled its stored multiplier after the first hit");
            variable_struct_set(_S, "foe_hp_after_first", _foe_hp_1);
            variable_struct_set(_S, "first_damage", _first_damage);
            if (__status_smoke_queue_turn(_pid, 0, 150)) variable_struct_set(_S, "state", "await_second_hit");
            break;

        case "await_second_hit":
            var _foe_hp_2 = __status_smoke_hp_now(_foe);
            var _second_damage = max(0, variable_struct_get(_S, "foe_hp_after_first") - _foe_hp_2);
            var _fury_mul_2 = (variable_struct_exists(_hero, "_fury_cutter_mul") && is_real(variable_struct_get(_hero, "_fury_cutter_mul"))) ? variable_struct_get(_hero, "_fury_cutter_mul") : -1;
            __status_smoke_assert(_S, _second_damage > variable_struct_get(_S, "first_damage"), "Fury Cutter's second consecutive hit dealt more damage than the first");
            __status_smoke_assert(_S, _fury_mul_2 == 4, "Fury Cutter doubled its stored multiplier again after the second hit");
            if (__status_smoke_queue_turn(_pid, 1, 150)) variable_struct_set(_S, "state", "await_reset");
            break;

        case "await_reset":
            var _fury_mul_reset = (variable_struct_exists(_hero, "_fury_cutter_mul") && is_real(variable_struct_get(_hero, "_fury_cutter_mul"))) ? variable_struct_get(_hero, "_fury_cutter_mul") : -1;
            __status_smoke_assert(_S, _fury_mul_reset == 1, "Using a different move reset the Fury Cutter multiplier");
            __status_smoke_finish(_pid, _S, "completed");
            break;
    }
}

function test_battle_love_gift_smoke_start(_auto_close = false){
    var _pid = 0;
    if (battle_is_open(_pid)) battle_close(_pid);
    var _party = party_ensure(_pid);
    if (!is_struct(_party)){
        show_debug_message("[smoke][love-gift] FAIL unable to ensure player party");
        return false;
    }

    var _hero = pokemon_factory_create(133, 20, {});
    __dev_assign_moves_to_mon(_hero, [213, 216, 217, 218]);
    variable_struct_set(_hero, "gender", "male");
    variable_struct_set(_hero, "happiness", 255);
    variable_struct_set(_hero, "friendship", 255);
    _party.mons[0] = _hero;
    global.PARTY[_pid] = _party;

    var _foe = pokemon_factory_create(10, 20, {});
    __dev_assign_moves_to_mon(_foe, [1, 150, -1, -1]);
    variable_struct_set(_foe, "gender", "female");
    variable_struct_set(_foe, "hp_max", 220);
    variable_struct_set(_foe, "hp_now", 220);
    variable_struct_set(_foe, "hp", 220);
    var _trainer_payload = {
        trainer_name: "Love Gift Smoke",
        sprite: (variable_global_exists("spr_PokemonEmeraldTrainers") ? variable_global_get("spr_PokemonEmeraldTrainers") : undefined),
        sprite_index: 12,
        party: [_foe],
        area_type: "forest",
        trainer_reward: 0
    };

    global.DEV_LOVE_GIFT_SMOKE = {
        pid: _pid,
        tag: "love-gift",
        global_name: "DEV_LOVE_GIFT_SMOKE",
        auto_close: (_auto_close == true),
        state: "opening",
        turn_counter: 0,
        pass_count: 0,
        fail_count: 0,
        hero_baseline_hp: 0,
        hero_hp_before_return: 0,
        foe_hp_before_return: 0,
        return_damage: 0,
        foe_hp_before_present: 0,
        started_ms: current_time
    };
    show_debug_message("[smoke][love-gift] starting Attract/Return/Present/Frustration smoke battle");
    battle_open_trainer(_pid, _trainer_payload);
    return true;
}

function test_battle_love_gift_smoke_update(_pid = 0){
    if (!variable_global_exists("DEV_LOVE_GIFT_SMOKE")) return;
    var _S = global.DEV_LOVE_GIFT_SMOKE;
    if (!is_struct(_S)) return;
    if (_pid != variable_struct_get(_S, "pid")) return;
    variable_struct_set(_S, "turn_counter", variable_struct_get(_S, "turn_counter") + 1);
    if (variable_struct_get(_S, "turn_counter") > 3600){
        __status_smoke_assert(_S, false, "timed out waiting for smoke scenario to finish");
        __status_smoke_finish(_pid, _S, "timeout");
        return;
    }
    if (!battle_is_open(_pid)) return;
    if (__status_smoke_advance_dialog(_pid, _S)) return;

    var _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B) || !variable_struct_exists(_B, "actor") || !is_array(variable_struct_get(_B, "actor"))) return;
    var _actors = variable_struct_get(_B, "actor");
    if (array_length(_actors) < 2) return;
    var _hero = _actors[0];
    var _foe = _actors[1];
    if (!is_struct(_hero) || !is_struct(_foe)) return;
    if (!variable_struct_exists(_B, "phase") || variable_struct_get(_B, "phase") != "command") return;

    var _state = string(variable_struct_get(_S, "state"));
    switch (_state){
        case "opening":
            variable_struct_set(_S, "hero_baseline_hp", __status_smoke_hp_now(_hero));
            if (__status_smoke_queue_turn(_pid, 0, 1)) variable_struct_set(_S, "state", "await_attract");
            break;

        case "await_attract":
            var _inf = (!is_undefined(status_system_get) ? status_system_get(_foe, "infatuation") : undefined);
            __status_smoke_assert(_S, is_struct(_inf), "Attract applied infatuation to the target");
            if (is_struct(_inf)){
                try { variable_struct_set(_inf, "_force_skip_next_move", true); } catch (e_inf_force) {}
            }
            variable_struct_set(_S, "hero_hp_before_return", __status_smoke_hp_now(_hero));
            variable_struct_set(_S, "foe_hp_before_return", __status_smoke_hp_now(_foe));
            if (__status_smoke_queue_turn(_pid, 1, 1)) variable_struct_set(_S, "state", "await_return");
            break;

        case "await_return":
            var _hero_hp_after_return = __status_smoke_hp_now(_hero);
            var _foe_hp_after_return = __status_smoke_hp_now(_foe);
            var _return_damage = max(0, variable_struct_get(_S, "foe_hp_before_return") - _foe_hp_after_return);
            __status_smoke_assert(_S, _hero_hp_after_return == variable_struct_get(_S, "hero_hp_before_return"), "Infatuation blocked the foe's next move");
            __status_smoke_assert(_S, _return_damage > 0, "Return dealt damage with high friendship");
            variable_struct_set(_S, "return_damage", _return_damage);
            try {
                variable_struct_set(_hero, "happiness", 0);
                variable_struct_set(_hero, "friendship", 0);
                if (variable_struct_exists(_hero, "mon") && is_struct(variable_struct_get(_hero, "mon"))){
                    var _hm = variable_struct_get(_hero, "mon");
                    variable_struct_set(_hm, "happiness", 0);
                    variable_struct_set(_hm, "friendship", 0);
                }
            } catch (e_hset) {}
            if (__status_smoke_queue_turn(_pid, 3, 1)) variable_struct_set(_S, "state", "await_frustration");
            break;

        case "await_frustration":
            var _foe_hp_after_frustration = __status_smoke_hp_now(_foe);
            var _frustration_damage = max(0, variable_struct_get(_S, "foe_hp_before_return") - variable_struct_get(_S, "return_damage") - _foe_hp_after_frustration);
            __status_smoke_assert(_S, _frustration_damage > 0, "Frustration dealt damage with low friendship");
            variable_struct_set(_S, "foe_hp_before_present", _foe_hp_after_frustration);
            if (__status_smoke_queue_turn(_pid, 2, 1)) variable_struct_set(_S, "state", "await_present");
            break;

        case "await_present":
            var _foe_hp_after_present = __status_smoke_hp_now(_foe);
            __status_smoke_assert(_S, _foe_hp_after_present != variable_struct_get(_S, "foe_hp_before_present"), "Present changed the target's HP via its random branch");
            __status_smoke_finish(_pid, _S, "completed");
            break;
    }
}

function test_battle_field_switch_smoke_start(_auto_close = false){
    var _pid = 0;
    if (battle_is_open(_pid)) battle_close(_pid);
    var _party = party_ensure(_pid);
    if (!is_struct(_party)){
        show_debug_message("[smoke][field-switch] FAIL unable to ensure player party");
        return false;
    }

    var _hero_a = pokemon_factory_create(133, 24, {});
    __dev_assign_moves_to_mon(_hero_a, [219, 172, 226, -1]);
    variable_struct_set(_hero_a, "hp_max", 220);
    variable_struct_set(_hero_a, "hp_now", 220);
    variable_struct_set(_hero_a, "hp", 220);
    variable_struct_set(_hero_a, "spe", 160);

    var _hero_b = pokemon_factory_create(25, 24, {});
    __dev_assign_moves_to_mon(_hero_b, [222, 228, -1, -1]);
    variable_struct_set(_hero_b, "hp_max", 220);
    variable_struct_set(_hero_b, "hp_now", 220);
    variable_struct_set(_hero_b, "hp", 220);
    variable_struct_set(_hero_b, "spe", 170);

    _party.mons[0] = _hero_a;
    _party.mons[1] = _hero_b;
    global.PARTY[_pid] = _party;

    var _foe_a = pokemon_factory_create(10, 24, {});
    __dev_assign_moves_to_mon(_foe_a, [77, 150, -1, -1]);
    variable_struct_set(_foe_a, "hp_max", 280);
    variable_struct_set(_foe_a, "hp_now", 280);
    variable_struct_set(_foe_a, "hp", 280);
    variable_struct_set(_foe_a, "spe", 20);

    var _foe_b = pokemon_factory_create(133, 24, {});
    __dev_assign_moves_to_mon(_foe_b, [150, -1, -1, -1]);
    variable_struct_set(_foe_b, "hp_max", 220);
    variable_struct_set(_foe_b, "hp_now", 220);
    variable_struct_set(_foe_b, "hp", 220);
    variable_struct_set(_foe_b, "spe", 20);

    var _trainer_payload = {
        trainer_name: "Field Switch Smoke",
        sprite: (variable_global_exists("spr_PokemonEmeraldTrainers") ? variable_global_get("spr_PokemonEmeraldTrainers") : undefined),
        sprite_index: 12,
        party: [_foe_a, _foe_b],
        area_type: "forest",
        trainer_reward: 0
    };

    global.DEV_FIELD_SWITCH_SMOKE = {
        pid: _pid,
        tag: "field-switch",
        global_name: "DEV_FIELD_SWITCH_SMOKE",
        auto_close: (_auto_close == true),
        state: "opening",
        turn_counter: 0,
        pass_count: 0,
        fail_count: 0,
        foe_hp_before_flame: 0,
        foe_hp_before_magnitude: 0,
        foe_hp_before_pursuit: 0,
        pursuit_baseline: 0,
        pursuit_switch_hp_before: 0,
        pursuit_switch_target: undefined,
        started_ms: current_time
    };
    show_debug_message("[smoke][field-switch] starting Safeguard/Flame Wheel/Magnitude/Baton Pass/Pursuit smoke battle");
    battle_open_trainer(_pid, _trainer_payload);
    return true;
}

function test_battle_field_switch_smoke_update(_pid = 0){
    if (!variable_global_exists("DEV_FIELD_SWITCH_SMOKE")) return;
    var _S = global.DEV_FIELD_SWITCH_SMOKE;
    if (!is_struct(_S)) return;
    if (_pid != variable_struct_get(_S, "pid")) return;
    variable_struct_set(_S, "turn_counter", variable_struct_get(_S, "turn_counter") + 1);
    if (variable_struct_get(_S, "turn_counter") > 5400){
        __status_smoke_assert(_S, false, "timed out waiting for field-switch smoke scenario to finish");
        __status_smoke_finish(_pid, _S, "timeout");
        return;
    }
    if (!battle_is_open(_pid)) return;
    if (__status_smoke_advance_dialog(_pid, _S)) return;

    var _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B) || !variable_struct_exists(_B, "actor") || !is_array(variable_struct_get(_B, "actor"))) return;
    var _actors = variable_struct_get(_B, "actor");
    if (array_length(_actors) < 2) return;
    var _hero = _actors[0];
    var _foe = _actors[1];
    if (!is_struct(_hero) || !is_struct(_foe)) return;

    var _state = string(variable_struct_get(_S, "state"));
    switch (_state){
        case "opening":
            if (variable_struct_exists(_B, "phase") && variable_struct_get(_B, "phase") == "command"){
                if (__status_smoke_queue_turn(_pid, 0, 77)) variable_struct_set(_S, "state", "await_safeguard");
            }
            break;

        case "await_safeguard":
            if (!variable_struct_exists(_B, "phase") || variable_struct_get(_B, "phase") != "command") break;
            var _guard_ok = true;
            try {
                _guard_ok = !status_system_has_status(_hero, "poison") && !status_system_has_status(_hero, "toxic");
                if (is_struct(_hero) && variable_struct_exists(_hero, "mon") && is_struct(variable_struct_get(_hero, "mon"))) _guard_ok = _guard_ok && !status_system_has_status(variable_struct_get(_hero, "mon"), "poison") && !status_system_has_status(variable_struct_get(_hero, "mon"), "toxic");
            } catch (e_guard_ok) { _guard_ok = false; }
            __status_smoke_assert(_S, _guard_ok, "Safeguard blocked opposing Poison Powder");
            try { status_system_apply_status(_hero, "freeze", { source: _foe }); } catch (e_freeze_apply) {}
            variable_struct_set(_S, "foe_hp_before_flame", __status_smoke_hp_now(_foe));
            if (__status_smoke_queue_turn(_pid, 1, 150)) variable_struct_set(_S, "state", "await_flame_wheel");
            break;

        case "await_flame_wheel":
            if (!variable_struct_exists(_B, "phase") || variable_struct_get(_B, "phase") != "command") break;
            var _thawed = true;
            try {
                _thawed = !status_system_has_status(_hero, "freeze");
                if (is_struct(_hero) && variable_struct_exists(_hero, "mon") && is_struct(variable_struct_get(_hero, "mon"))) _thawed = _thawed && !status_system_has_status(variable_struct_get(_hero, "mon"), "freeze");
            } catch (e_thaw_chk) { _thawed = false; }
            __status_smoke_assert(_S, _thawed, "Flame Wheel thawed the frozen user on use");
            __status_smoke_assert(_S, __status_smoke_hp_now(_foe) < variable_struct_get(_S, "foe_hp_before_flame"), "Flame Wheel still executed after thawing");
            try {
                if (!variable_struct_exists(_hero, "_stages") || !is_struct(variable_struct_get(_hero, "_stages"))) variable_struct_set(_hero, "_stages", {});
                var _hst = variable_struct_get(_hero, "_stages");
                variable_struct_set(_hst, "atk", 2);
                variable_struct_set(_hero, "_stages", _hst);
            } catch (e_stage_set) {}
            if (__status_smoke_queue_turn(_pid, 2, 150)) variable_struct_set(_S, "state", "await_baton_party");
            break;

        case "await_baton_party":
            var _party_open = (is_undefined(party_is_open) ? false : party_is_open(_pid));
            var _switch_pending = (variable_struct_exists(_B, "_switch_target_idx") && is_real(variable_struct_get(_B, "_switch_target_idx")) && variable_struct_get(_B, "_switch_target_idx") == 1);
            var _bp_pending = (variable_struct_exists(_B, "_baton_pass_pending") && is_struct(variable_struct_get(_B, "_baton_pass_pending")));
            if (_party_open || _switch_pending || _bp_pending || (variable_struct_exists(_B, "phase") && (variable_struct_get(_B, "phase") == "intro_call" || variable_struct_get(_B, "phase") == "switch_in"))){
                __status_smoke_assert(_S, _bp_pending || _switch_pending, "Baton Pass entered its replacement flow");
                if (_party_open && !_switch_pending){
                    try {
                        var _P_sel = party_ensure(_pid);
                        if (is_struct(_P_sel)) variable_struct_set(_P_sel, "sel", 1);
                    } catch (e_bp_sel) {}
                    var _switch_ok = false;
                    try { _switch_ok = battle_switch_to(_pid, 1, { auto_apply:true, consume_turn:true, forced:false, baton_pass:true }); } catch (e_bp_switch) { _switch_ok = false; }
                    __status_smoke_assert(_S, _switch_ok, "Baton Pass accepted the mid-turn recipient switch");
                    if (_switch_ok){
                        try { if (!is_undefined(party_close)) party_close(_pid); } catch (e_bp_close) {}
                    }
                } else {
                    __status_smoke_assert(_S, true, "Baton Pass accepted the mid-turn recipient switch");
                }
                variable_struct_set(_S, "state", "await_baton_switch");
            }
            break;

        case "await_baton_switch":
            if (!variable_struct_exists(_B, "phase") || variable_struct_get(_B, "phase") != "command") break;
            if (!is_struct(_hero)) break;
            var _stage_passed = false;
            try {
                if (variable_struct_exists(_hero, "_stages") && is_struct(variable_struct_get(_hero, "_stages"))){
                    var _hst2 = variable_struct_get(_hero, "_stages");
                    _stage_passed = (variable_struct_exists(_hst2, "atk") && variable_struct_get(_hst2, "atk") == 2);
                }
            } catch (e_stage_chk) { _stage_passed = false; }
            __status_smoke_assert(_S, _stage_passed, "Baton Pass transferred stat stages to the replacement");
            variable_struct_set(_S, "foe_hp_before_magnitude", __status_smoke_hp_now(_foe));
            if (__status_smoke_queue_turn(_pid, 0, 150)) variable_struct_set(_S, "state", "await_magnitude");
            break;

        case "await_magnitude":
            if (!variable_struct_exists(_B, "phase") || variable_struct_get(_B, "phase") != "command") break;
            var _magnitude_damage = max(0, variable_struct_get(_S, "foe_hp_before_magnitude") - __status_smoke_hp_now(_foe));
            __status_smoke_assert(_S, _magnitude_damage > 0, "Magnitude dealt damage using its variable-power path");
            variable_struct_set(_S, "foe_hp_before_pursuit", __status_smoke_hp_now(_foe));
            if (__status_smoke_queue_turn(_pid, 1, 150)) variable_struct_set(_S, "state", "await_pursuit_baseline");
            break;

        case "await_pursuit_baseline":
            if (!variable_struct_exists(_B, "phase") || variable_struct_get(_B, "phase") != "command") break;
            var _baseline = max(0, variable_struct_get(_S, "foe_hp_before_pursuit") - __status_smoke_hp_now(_foe));
            __status_smoke_assert(_S, _baseline > 0, "Pursuit dealt baseline damage against a non-switching target");
            variable_struct_set(_S, "pursuit_baseline", _baseline);
            variable_struct_set(_S, "pursuit_switch_hp_before", __status_smoke_hp_now(_foe));
            variable_struct_set(_S, "pursuit_switch_target", _foe);
            _B.turn_action_player = { slot: 1, move_id: 228, actor_index: 0, target_index: 1 };
            _B.turn_action_enemy = { switch_to: 1, actor_index: 1, target_index: 0, debug_from: "Switch Target", debug_to: "Bench Target" };
            _B.turn_queue = __battle_build_turn_actions(_pid);
            _B.turn_i = 0;
            try { variable_struct_set(_B, "_action_active", true); } catch (e_switch_act) {}
            _B.phase = "turn";
            variable_struct_set(_S, "state", "await_pursuit_switch");
            show_debug_message("[smoke][field-switch] queued pursuit-vs-switch turn");
            break;

        case "await_pursuit_switch":
            if (!variable_struct_exists(_B, "phase") || variable_struct_get(_B, "phase") != "command") break;
            var _old_target = variable_struct_get(_S, "pursuit_switch_target");
            var _switch_damage = max(0, variable_struct_get(_S, "pursuit_switch_hp_before") - __status_smoke_hp_now(_old_target));
            __status_smoke_assert(_S, _switch_damage > variable_struct_get(_S, "pursuit_baseline"), "Pursuit dealt increased damage against a switching target");
            __status_smoke_finish(_pid, _S, "completed");
            break;
    }
}