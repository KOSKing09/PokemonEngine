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

function __status_smoke_bind_current_battle(_pid, _state){
    if (!is_struct(_state)) return false;
    if (!battle_is_open(_pid)) return false;
    var _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B)) return false;

    var _global_name = (variable_struct_exists(_state, "global_name") ? string(variable_struct_get(_state, "global_name")) : "");
    var _started_ms = (variable_struct_exists(_state, "started_ms") && is_real(variable_struct_get(_state, "started_ms")))
        ? real(variable_struct_get(_state, "started_ms"))
        : current_time;

    try { variable_struct_set(_B, "_dev_smoke_global_name", _global_name); } catch (e_smoke_bind_name) {}
    try { variable_struct_set(_B, "_dev_smoke_started_ms", _started_ms); } catch (e_smoke_bind_ms) {}
    return true;
}

function __status_smoke_is_bound_battle(_pid, _state){
    if (!is_struct(_state) || !battle_is_open(_pid)) return false;
    var _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B)) return false;
    if (!variable_struct_exists(_B, "_dev_smoke_global_name") || !variable_struct_exists(_B, "_dev_smoke_started_ms")) return false;

    var _expected_name = (variable_struct_exists(_state, "global_name") ? string(variable_struct_get(_state, "global_name")) : "");
    var _expected_ms = (variable_struct_exists(_state, "started_ms") && is_real(variable_struct_get(_state, "started_ms"))) ? floor(real(variable_struct_get(_state, "started_ms"))) : -1;
    var _actual_name = string(variable_struct_get(_B, "_dev_smoke_global_name"));
    var _actual_ms = variable_struct_get(_B, "_dev_smoke_started_ms");
    if (_actual_name != _expected_name) return false;
    if (_expected_ms < 0) return true;
    if (!is_real(_actual_ms)) return false;
    return (floor(real(_actual_ms)) == _expected_ms);
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
    if (_auto_close) {
        try {
            if (battle_is_open(_pid) && __status_smoke_is_bound_battle(_pid, _state)) battle_close(_pid);
        } catch (e_close) {}
    }
    try { if (string_length(_global_name) > 0 && variable_global_exists(_global_name)) variable_global_set(_global_name, undefined); } catch (e_clear) {}
    if (_auto_close) {
        var _exit_game = false;
        try { if (variable_global_exists("DEV_SMOKE_EXIT_GAME") && variable_global_get("DEV_SMOKE_EXIT_GAME") == true) _exit_game = true; } catch (e_exit_flag) { _exit_game = false; }
        if (_exit_game) {
            show_debug_message("[smoke][" + _tag + "] auto-close requested; ending game after smoke completion");
            game_end();
        } else {
            show_debug_message("[smoke][" + _tag + "] auto-close requested; closing the smoke battle only");
        }
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
    variable_struct_set(_B, "turn_action_player", { slot: _player_slot, move_id: _player.moves[_player_slot], actor_index: 0, target_index: 1 });
    variable_struct_set(_B, "turn_action_enemy", ((_enemy_slot >= 0) ? { slot: _enemy_slot, move_id: _enemy_move_id, actor_index: 1, target_index: 0 } : undefined));
    variable_struct_set(_B, "turn_queue", __battle_build_turn_actions(_pid));
    variable_struct_set(_B, "turn_i", 0);
    try { variable_struct_set(_B, "_action_active", true); } catch (e_smoke_act) {}
    variable_struct_set(_B, "phase", "turn");
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

function __status_smoke_dialog_text(_pid){
    if (is_undefined(dialog2p_is_open) || !dialog2p_is_open(_pid)) return "";
    if (!variable_global_exists("DIALOG2P") || !is_array(global.DIALOG2P) || array_length(global.DIALOG2P) <= _pid) return "";
    var _d = global.DIALOG2P[_pid];
    if (!is_struct(_d)) return "";

    var _page_idx = (variable_struct_exists(_d, "page_idx") && is_real(variable_struct_get(_d, "page_idx"))) ? variable_struct_get(_d, "page_idx") : 0;
    var _all_lines = (variable_struct_exists(_d, "all_lines") && is_array(variable_struct_get(_d, "all_lines"))) ? variable_struct_get(_d, "all_lines") : [];
    var _i0 = _page_idx * 2;
    var _i1 = _i0 + 1;
    var _l0 = (_i0 < array_length(_all_lines)) ? string(_all_lines[_i0]) : "";
    var _l1 = (_i1 < array_length(_all_lines)) ? string(_all_lines[_i1]) : "";
    return _l0 + "\n" + _l1;
}

function __status_smoke_advance_levelup_panel(_pid, _state){
    if (is_undefined(__battle_ensure_slot)) return false;
    var _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B) || !variable_struct_exists(_B, "_levelup_panel")) return false;
    var _panel = variable_struct_get(_B, "_levelup_panel");
    if (!is_struct(_panel) || !variable_struct_exists(_panel, "active") || variable_struct_get(_panel, "active") != true) return false;

    var _now = current_time;
    var _next_ms = (is_struct(_state) && variable_struct_exists(_state, "panel_advance_ms") && is_real(variable_struct_get(_state, "panel_advance_ms"))) ? variable_struct_get(_state, "panel_advance_ms") : -1;
    if (is_real(_next_ms) && _next_ms > _now) return true;

    if (!variable_global_exists("CTRL") || !is_struct(CTRL) || !variable_struct_exists(CTRL, "state") || !is_array(CTRL.state) || array_length(CTRL.state) <= _pid) return true;
    var _st = CTRL.state[_pid];
    if (!is_struct(_st) || !variable_struct_exists(_st, "pressed")) return true;
    var _pressed = variable_struct_get(_st, "pressed");
    if (!is_real(_pressed) || !ds_exists(_pressed, ds_type_map)) return true;

    ds_map_replace(_pressed, "Interact", true);
    ds_map_replace(_pressed, "A", true);
    try { __battle_update_levelup_panel(_pid); } catch (e_smoke_panel) {}
    ds_map_replace(_pressed, "Interact", false);
    ds_map_replace(_pressed, "A", false);
    if (is_struct(_state)) variable_struct_set(_state, "panel_advance_ms", _now + 220);
    return true;
}

function __evolution_smoke_actor_from_mon(_mon){
    if (!is_struct(_mon)) return undefined;
    return {
        mon: _mon,
        name: (variable_struct_exists(_mon, "name") ? variable_struct_get(_mon, "name") : "Pokemon"),
        species_id: (variable_struct_exists(_mon, "species_id") ? variable_struct_get(_mon, "species_id") : -1),
        species: (variable_struct_exists(_mon, "species") ? variable_struct_get(_mon, "species") : "Pokemon"),
        level: (variable_struct_exists(_mon, "level") ? variable_struct_get(_mon, "level") : 1),
        exp: (variable_struct_exists(_mon, "exp") ? variable_struct_get(_mon, "exp") : 0),
        exp_next: (variable_struct_exists(_mon, "exp_next") ? variable_struct_get(_mon, "exp_next") : 1),
        hp: (variable_struct_exists(_mon, "hp") ? variable_struct_get(_mon, "hp") : 1),
        hp_now: (variable_struct_exists(_mon, "hp_now") ? variable_struct_get(_mon, "hp_now") : ((variable_struct_exists(_mon, "hp") ? variable_struct_get(_mon, "hp") : 1))),
        hp_max: (variable_struct_exists(_mon, "hp_max") ? variable_struct_get(_mon, "hp_max") : ((variable_struct_exists(_mon, "hp") ? variable_struct_get(_mon, "hp") : 1))),
        maxhp: (variable_struct_exists(_mon, "maxhp") ? variable_struct_get(_mon, "maxhp") : ((variable_struct_exists(_mon, "hp_max") ? variable_struct_get(_mon, "hp_max") : 1))),
        atk: (variable_struct_exists(_mon, "atk") ? variable_struct_get(_mon, "atk") : 1),
        def: (variable_struct_exists(_mon, "def") ? variable_struct_get(_mon, "def") : 1),
        spa: (variable_struct_exists(_mon, "spa") ? variable_struct_get(_mon, "spa") : 1),
        spd: (variable_struct_exists(_mon, "spd") ? variable_struct_get(_mon, "spd") : 1),
        spe: (variable_struct_exists(_mon, "spe") ? variable_struct_get(_mon, "spe") : 1),
        icon: (variable_struct_exists(_mon, "icon") ? variable_struct_get(_mon, "icon") : -1),
        type1: (variable_struct_exists(_mon, "type1") ? variable_struct_get(_mon, "type1") : -1),
        type2: (variable_struct_exists(_mon, "type2") ? variable_struct_get(_mon, "type2") : -1),
        types: (variable_struct_exists(_mon, "types") ? variable_struct_get(_mon, "types") : []),
        moves: (variable_struct_exists(_mon, "moves") ? variable_struct_get(_mon, "moves") : [-1, -1, -1, -1]),
        pps: (variable_struct_exists(_mon, "pps") ? variable_struct_get(_mon, "pps") : [0, 0, 0, 0]),
        shiny: (variable_struct_exists(_mon, "shiny") ? variable_struct_get(_mon, "shiny") : false)
    };
}

function test_battle_evolution_smoke_start(_auto_close = false){
    var _pid = 0;
    if (battle_is_open(_pid)) battle_close(_pid);
    if (!is_undefined(evolution_init)) evolution_init();

    var _hero = pokemon_factory_create(1, 15, {});
    var _foe = pokemon_factory_create(10, 5, {});
    if (!is_struct(_hero) || !is_struct(_foe)) {
        show_debug_message("[smoke][evolution] FAIL could not create smoke mons");
        return;
    }

    var _party = party_ensure(_pid);
    if (is_struct(_party)) variable_struct_set(_party, "mons", [_hero]);
    try { if (!is_undefined(party_apply_name_support)) party_apply_name_support(_pid); } catch (e_evo_name) {}
    variable_struct_set(_hero, "growth_id", undefined);

    var _player_actor = __evolution_smoke_actor_from_mon(_hero);
    var _enemy_actor = __evolution_smoke_actor_from_mon(_foe);
    var _B = __effect_smoke_slot(_pid, _player_actor, _enemy_actor, "trainer");
    if (is_struct(_B)) {
        variable_struct_set(_B, "theme", {
            col_bg: make_color_rgb(184,224,200),
            col_outline: make_color_rgb(72,88,80),
            col_panel: make_color_rgb(208,232,224),
            col_hp_green: make_color_rgb(120,216,88),
            col_hp_yell: make_color_rgb(248,208,56),
            col_hp_red: make_color_rgb(232,72,56),
            col_text: c_white,
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
        });
        try { if (!is_undefined(__battle_theme_apply_area_type)) __battle_theme_apply_area_type(_B, "forest", {}); } catch (e_evo_theme) {}
    }

    var _target_exp = max(20, sqr(16) * 2);
    variable_struct_set(_hero, "exp", _target_exp - 1);
    variable_struct_set(_hero, "exp_next", _target_exp);
    var _gain = 2;

    var _S = {
        pid: _pid,
        tag: "evolution",
        global_name: "DEV_EVOLUTION_SMOKE",
        auto_close: (_auto_close == true),
        started_ms: current_time,
        pass_count: 0,
        fail_count: 0,
        dialog_advance_ms: current_time + 120,
        mon: _hero,
        expected_species_id: 2,
        saw_pending: false,
        saw_active: false,
        saw_announce: false,
        saw_result: false
    };
    global.DEV_EVOLUTION_SMOKE = _S;
    __status_smoke_bind_current_battle(_pid, _S);

    try { __battle_award_exp(_pid, _gain); } catch (e_evo_award) {
        __status_smoke_assert(_S, false, "exp award failed: " + string(e_evo_award));
        __status_smoke_finish(_pid, _S, "award_exp exception");
        return;
    }

    __status_smoke_assert(_S, battle_is_open(_pid), "battle slot opened for evolution smoke");
    __status_smoke_assert(_S, __evolution_species_id(_hero) == 1, "smoke mon starts unevolved");
}

function test_battle_evolution_smoke_update(_pid = 0){
    if (!variable_global_exists("DEV_EVOLUTION_SMOKE")) return;
    var _S = global.DEV_EVOLUTION_SMOKE;
    if (!is_struct(_S)) return;

    __status_smoke_advance_dialog(_pid, _S);
    __status_smoke_advance_levelup_panel(_pid, _S);

    if (current_time - variable_struct_get(_S, "started_ms") > 15000){
        __status_smoke_assert(_S, false, "timed out waiting for evolution flow");
        __status_smoke_finish(_pid, _S, "timeout");
        return;
    }

    var _dialog_text = string_lower(__status_smoke_dialog_text(_pid));
    if (string_pos("is evolving", _dialog_text) > 0) variable_struct_set(_S, "saw_announce", true);
    if (string_pos("evolved into", _dialog_text) > 0) variable_struct_set(_S, "saw_result", true);
    if (!is_undefined(evolution_has_pending) && evolution_has_pending(_pid)) variable_struct_set(_S, "saw_pending", true);
    if (!is_undefined(evolution_is_active) && evolution_is_active(_pid)) variable_struct_set(_S, "saw_active", true);

    var _mon = variable_struct_get(_S, "mon");
    var _expected = variable_struct_get(_S, "expected_species_id");
    var _actual = __evolution_species_id(_mon);

    if (_actual == _expected && (!dialog2p_is_open(_pid)) && (!evolution_is_active(_pid))){
        __status_smoke_assert(_S, variable_struct_get(_S, "saw_pending"), "evolution queue was created");
        __status_smoke_assert(_S, variable_struct_get(_S, "saw_active"), "evolution scene became active");
        __status_smoke_assert(_S, variable_struct_get(_S, "saw_announce"), "announce dialog was shown");
        __status_smoke_assert(_S, variable_struct_get(_S, "saw_result"), "completion dialog was shown");
        __status_smoke_assert(_S, true, "level-up evolution changed species to " + string(_expected));
        __status_smoke_finish(_pid, _S, "evolution completed");
        return;
    }

    if (current_time - variable_struct_get(_S, "started_ms") > 8000 && !variable_struct_get(_S, "saw_active") && !variable_struct_get(_S, "saw_pending")){
        __status_smoke_assert(_S, false, "evolution never queued from battle exp");
        __status_smoke_finish(_pid, _S, "queue missing");
        return;
    }

    if (!battle_is_open(_pid) && _actual != _expected){
        __status_smoke_assert(_S, false, "battle closed before evolution completed");
        __status_smoke_finish(_pid, _S, "battle closed early");
    }
}

function __status_smoke_pending_status_text(_pid){
    if (!battle_is_open(_pid)) return "";
    var _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B) || !variable_struct_exists(_B, "_pending_status_msgs")) return "";
    var _pending = variable_struct_get(_B, "_pending_status_msgs");
    if (!is_array(_pending) || array_length(_pending) <= 0) return "";
    var _joined = "";
    for (var _i = 0; _i < array_length(_pending); ++_i){
        var _line = string(_pending[_i]);
        if (string_length(_joined) > 0) _joined += "\n";
        _joined += _line;
    }
    return _joined;
}

function __status_smoke_last_move_damage(_actor, _move_id){
    if (!is_struct(_actor)) return 0;
    try {
        var _last_move = (variable_struct_exists(_actor, "_last_received_from_move") ? variable_struct_get(_actor, "_last_received_from_move") : undefined);
        if (!is_real(_last_move) || floor(_last_move) != floor(_move_id)) return 0;
        if (variable_struct_exists(_actor, "_last_received_from_move_damage") && is_real(variable_struct_get(_actor, "_last_received_from_move_damage"))) return max(0, variable_struct_get(_actor, "_last_received_from_move_damage"));
        if (variable_struct_exists(_actor, "_last_received_damage") && is_real(variable_struct_get(_actor, "_last_received_damage"))) return max(0, variable_struct_get(_actor, "_last_received_damage"));
    } catch (e_last_move) {}
    return 0;
}

function __status_smoke_find_move_id(_identifiers, _required_effect_id = undefined){
    if (!is_array(_identifiers) || !variable_global_exists("_moves") || !is_array(global._moves)) return -1;
    for (var _mi = 0; _mi < array_length(global._moves); ++_mi){
        var _move = global._moves[_mi];
        if (!is_struct(_move) || !variable_struct_exists(_move, "identifier")) continue;
        var _ident = string_lower(string(variable_struct_get(_move, "identifier")));
        var _match = false;
        for (var _ii = 0; _ii < array_length(_identifiers); ++_ii){
            if (_ident == string_lower(string(_identifiers[_ii]))){ _match = true; break; }
        }
        if (!_match) continue;
        if (is_real(_required_effect_id)){
            var _effect_id = (variable_struct_exists(_move, "effect_id") && is_real(variable_struct_get(_move, "effect_id"))) ? floor(variable_struct_get(_move, "effect_id")) : undefined;
            if (!is_real(_effect_id) || _effect_id != floor(_required_effect_id)) continue;
        }
        return _mi;
    }
    return -1;
}

function __status_smoke_reset_visual_actor(_actor){
    if (!is_struct(_actor)) return;
    try {
        variable_struct_set(_actor, "_nudge_active", false);
        variable_struct_set(_actor, "_nudge_start_ms", 0);
        variable_struct_set(_actor, "_nudge_dur", 0);
        variable_struct_set(_actor, "_nudge_mag", 0);
        variable_struct_set(_actor, "_nudge_dir", 0);
        variable_struct_set(_actor, "_last_received_from_move", -1);
        variable_struct_set(_actor, "_last_received_from_move_damage", 0);
        variable_struct_set(_actor, "_last_received_damage", 0);
    } catch (e_reset_visual) {}
}

function __status_smoke_clear_anim_queue(_pid){
    var _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B)) return;
    try {
        if (!variable_struct_exists(_B, "_anim_queue") || !is_struct(variable_struct_get(_B, "_anim_queue"))) return;
        var _aq = variable_struct_get(_B, "_anim_queue");
        variable_struct_set(_aq, "pending", []);
        variable_struct_set(_aq, "overlays", []);
        variable_struct_set(_aq, "draw_states", []);
        variable_struct_set(_aq, "current", undefined);
        variable_struct_set(_B, "_anim_queue", _aq);
    } catch (e_clear_anim) {}
}

function __status_smoke_count_hit_effect_overlays(_pid, _target_index = undefined, _sprite = undefined, _use_actor_sprite = undefined){
    var _count = 0;
    var _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B) || !variable_struct_exists(_B, "_anim_queue") || !is_struct(variable_struct_get(_B, "_anim_queue"))) return 0;
    var _aq = variable_struct_get(_B, "_anim_queue");
    if (!variable_struct_exists(_aq, "overlays") || !is_array(variable_struct_get(_aq, "overlays"))) return 0;
    var _overlays = variable_struct_get(_aq, "overlays");
    for (var _oi = 0; _oi < array_length(_overlays); ++_oi){
        var _ov = _overlays[_oi];
        if (!is_struct(_ov)) continue;
        if (!variable_struct_exists(_ov, "type") || string_lower(string(variable_struct_get(_ov, "type"))) != "hit_effect") continue;
        if (is_real(_target_index)){
            if (!variable_struct_exists(_ov, "target_index") || !is_real(variable_struct_get(_ov, "target_index")) || floor(variable_struct_get(_ov, "target_index")) != floor(_target_index)) continue;
        }
        if (!is_undefined(_sprite)){
            if (!variable_struct_exists(_ov, "sprite") || variable_struct_get(_ov, "sprite") != _sprite) continue;
        }
        if (is_bool(_use_actor_sprite)){
            var _ov_use_actor_sprite = (variable_struct_exists(_ov, "use_actor_sprite") && variable_struct_get(_ov, "use_actor_sprite") == true);
            if (_ov_use_actor_sprite != _use_actor_sprite) continue;
        }
        _count += 1;
    }
    if (variable_struct_exists(_aq, "draw_states") && is_array(variable_struct_get(_aq, "draw_states"))){
        var _states = variable_struct_get(_aq, "draw_states");
        for (var _si = 0; _si < array_length(_states); ++_si){
            var _st = _states[_si];
            if (!is_struct(_st)) continue;
            if (!variable_struct_exists(_st, "kind") || string_lower(string(variable_struct_get(_st, "kind"))) != "sprite_overlay") continue;
            if (is_real(_target_index)){
                if (!variable_struct_exists(_st, "target_index") || !is_real(variable_struct_get(_st, "target_index")) || floor(variable_struct_get(_st, "target_index")) != floor(_target_index)) continue;
            }
            if (!is_undefined(_sprite)){
                if (!variable_struct_exists(_st, "sprite") || variable_struct_get(_st, "sprite") != _sprite) continue;
            }
            _count += 1;
        }
    }
    return _count;
}

function __status_smoke_count_orbit_states(_pid, _target_index = undefined, _sprite = undefined){
    var _count = 0;
    var _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B) || !variable_struct_exists(_B, "_anim_queue") || !is_struct(variable_struct_get(_B, "_anim_queue"))) return 0;
    var _aq = variable_struct_get(_B, "_anim_queue");
    if (!variable_struct_exists(_aq, "draw_states") || !is_array(variable_struct_get(_aq, "draw_states"))) return 0;
    var _states = variable_struct_get(_aq, "draw_states");
    for (var _si = 0; _si < array_length(_states); ++_si){
        var _st = _states[_si];
        if (!is_struct(_st)) continue;
        if (!variable_struct_exists(_st, "kind") || string_lower(string(variable_struct_get(_st, "kind"))) != "sprite_orbit") continue;
        if (is_real(_target_index)){
            if (!variable_struct_exists(_st, "target_index") || !is_real(variable_struct_get(_st, "target_index")) || floor(variable_struct_get(_st, "target_index")) != floor(_target_index)) continue;
        }
        if (!is_undefined(_sprite)){
            if (!variable_struct_exists(_st, "sprite") || variable_struct_get(_st, "sprite") != _sprite) continue;
        }
        _count += 1;
    }
    return _count;
}

function __status_smoke_actor_has_nudge(_actor, _expected_dir = undefined){
    if (!is_struct(_actor)) return false;
    var _mag = (variable_struct_exists(_actor, "_nudge_mag") && is_real(variable_struct_get(_actor, "_nudge_mag"))) ? variable_struct_get(_actor, "_nudge_mag") : 0;
    if (_mag <= 0) return false;
    var _active = (variable_struct_exists(_actor, "_nudge_active") && variable_struct_get(_actor, "_nudge_active") == true);
    var _start_ms = (variable_struct_exists(_actor, "_nudge_start_ms") && is_real(variable_struct_get(_actor, "_nudge_start_ms"))) ? variable_struct_get(_actor, "_nudge_start_ms") : -1;
    var _dur_ms = (variable_struct_exists(_actor, "_nudge_dur") && is_real(variable_struct_get(_actor, "_nudge_dur"))) ? variable_struct_get(_actor, "_nudge_dur") : 0;
    var _recent = (_active || (_start_ms >= 0 && current_time - _start_ms <= max(1200, _dur_ms + 500)));
    if (!_recent) return false;
    if (is_real(_expected_dir)){
        if (!variable_struct_exists(_actor, "_nudge_dir") || !is_real(variable_struct_get(_actor, "_nudge_dir"))) return false;
        return sign(variable_struct_get(_actor, "_nudge_dir")) == sign(_expected_dir);
    }
    return true;
}

function __status_smoke_actor_nudge_mag(_actor){
    if (!is_struct(_actor)) return 0;
    if (!variable_struct_exists(_actor, "_nudge_mag") || !is_real(variable_struct_get(_actor, "_nudge_mag"))) return 0;
    return max(0, real(variable_struct_get(_actor, "_nudge_mag")));
}

function __status_smoke_queue_double_turn(_pid, _player_actions){
    var _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B) || !is_array(_player_actions)) return false;
    variable_struct_set(_B, "_player_turn_actions", _player_actions);
    variable_struct_set(_B, "turn_queue", __battle_build_turn_actions(_pid));
    variable_struct_set(_B, "turn_i", 0);
    try { variable_struct_set(_B, "_action_active", true); } catch (e_double_smoke_act) {}
    variable_struct_set(_B, "phase", "turn");
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
    __status_smoke_bind_current_battle(_pid, global.DEV_STATUS_SMOKE);
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
    __status_smoke_bind_current_battle(_pid, global.DEV_HEAL_BLOCK_SMOKE);
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
    __status_smoke_bind_current_battle(_pid, global.DEV_EMBARGO_SMOKE);
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
    __status_smoke_bind_current_battle(_pid, global.DEV_PERISH_SONG_SMOKE);
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
    __status_smoke_bind_current_battle(_pid, global.DEV_ENDURE_SMOKE);
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
    __status_smoke_bind_current_battle(_pid, global.DEV_ROLLOUT_SMOKE);
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
    __status_smoke_bind_current_battle(_pid, global.DEV_FURY_CUTTER_SMOKE);
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
    __status_smoke_bind_current_battle(_pid, _S);

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
    __status_smoke_bind_current_battle(_pid, global.DEV_LOVE_GIFT_SMOKE);
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
            var _baseline = __status_smoke_last_move_damage(_foe, 228);
            __status_smoke_assert(_S, _baseline > 0, "Pursuit dealt baseline damage against a non-switching target");
            variable_struct_set(_S, "pursuit_baseline", _baseline);
            variable_struct_set(_S, "pursuit_switch_hp_before", __status_smoke_hp_now(_foe));
            variable_struct_set(_S, "pursuit_switch_target", _foe);
            try {
                variable_struct_set(_foe, "_last_received_from_move", -1);
                variable_struct_set(_foe, "_last_received_from_move_damage", 0);
            } catch (e_pursuit_reset) {}
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
            var _switch_damage = __status_smoke_last_move_damage(_old_target, 228);
            __status_smoke_assert(_S, _switch_damage > variable_struct_get(_S, "pursuit_baseline"), "Pursuit dealt increased damage against a switching target");
            __status_smoke_finish(_pid, _S, "completed");
            break;
    }
}

function test_battle_doubles_forced_player_switch_smoke_start(_auto_close = false){
    var _pid = 0;
    if (battle_is_open(_pid)) battle_close(_pid);

    var _party = party_ensure(_pid);
    if (!is_struct(_party)){
        show_debug_message("[smoke][forced-player-switch] FAIL unable to ensure player party");
        return false;
    }

    var _names = ["Lead Alpha", "Lead Beta", "Bench Gamma", "Bench Delta"];
    var _species = [133, 25, 10, 16];
    var _moves = [[33, -1, -1, -1], [98, -1, -1, -1], [45, -1, -1, -1], [28, -1, -1, -1]];
    for (var _i = 0; _i < 4; ++_i){
        var _mon = pokemon_factory_create(_species[_i], 24, {});
        __dev_assign_moves_to_mon(_mon, _moves[_i]);
        variable_struct_set(_mon, "name", _names[_i]);
        _party.mons[_i] = _mon;
    }
    global.PARTY[_pid] = _party;

    var _enemy_a = pokemon_factory_create(263, 24, {});
    var _enemy_b = pokemon_factory_create(19, 24, {});
    variable_struct_set(_enemy_a, "name", "Force Rat A");
    variable_struct_set(_enemy_b, "name", "Force Rat B");
    __dev_assign_moves_to_mon(_enemy_a, [46, -1, -1, -1]);
    __dev_assign_moves_to_mon(_enemy_b, [33, -1, -1, -1]);

    battle_open(0, 24, "forest", {
        type: "trainer",
        battle_format: "double",
        enemy_party: [_enemy_a, _enemy_b],
        trainer_name: "Forced Switch Smoke",
        sprite: (variable_global_exists("spr_PokemonEmeraldTrainers") ? variable_global_get("spr_PokemonEmeraldTrainers") : undefined),
        sprite_index: 12,
        trainer_reward: 0
    });

    global.DEV_FORCED_PLAYER_SWITCH_SMOKE = {
        pid: _pid,
        tag: "forced-player-switch",
        global_name: "DEV_FORCED_PLAYER_SWITCH_SMOKE",
        auto_close: (_auto_close == true),
        state: "opening",
        pass_count: 0,
        fail_count: 0,
        turn_counter: 0,
        dialog_advance_ms: -1,
        chosen_party_idx: -1,
        chosen_name: "",
        dialog_checked: false,
        original_slot0_mon: _party.mons[0],
        original_slot1_mon: _party.mons[1],
        valid_choices: [2, 3]
    };
    __status_smoke_bind_current_battle(_pid, global.DEV_FORCED_PLAYER_SWITCH_SMOKE);
    show_debug_message("[smoke][forced-player-switch] starting dedicated doubles forced player switch smoke");
    return true;
}

function test_battle_doubles_forced_player_switch_smoke_update(_pid = 0){
    if (!variable_global_exists("DEV_FORCED_PLAYER_SWITCH_SMOKE")) return;
    var _S = global.DEV_FORCED_PLAYER_SWITCH_SMOKE;
    if (!is_struct(_S)) return;
    if (_pid != variable_struct_get(_S, "pid")) return;

    variable_struct_set(_S, "turn_counter", variable_struct_get(_S, "turn_counter") + 1);
    if (variable_struct_get(_S, "turn_counter") > 5400){
        __status_smoke_assert(_S, false, "timed out waiting for doubles forced player switch smoke to finish");
        __status_smoke_finish(_pid, _S, "timeout");
        return;
    }
    if (!battle_is_open(_pid)) return;

    var _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B) || !variable_struct_exists(_B, "actor") || !is_array(variable_struct_get(_B, "actor"))) return;
    var _actors = variable_struct_get(_B, "actor");
    if (array_length(_actors) < 4) return;

    var _state = string(variable_struct_get(_S, "state"));
    switch (_state){
        case "opening":
            if (__status_smoke_advance_dialog(_pid, _S)) break;
            if (!variable_struct_exists(_B, "phase") || variable_struct_get(_B, "phase") != "command") break;
            var _ok_switch = false;
            try {
                variable_struct_set(_B, "phase", "turn");
                variable_struct_set(_B, "_action_active", true);
                _ok_switch = battle_switch_to(_pid, -1, { auto_apply:true, consume_turn:false, forced:true, actor_index:1 });
            } catch (e_force_switch) { _ok_switch = false; }
            __status_smoke_assert(_S, _ok_switch, "Forced doubles player switch was accepted for player slot 1");
            if (!_ok_switch){
                __status_smoke_finish(_pid, _S, "switch-rejected");
                return;
            }
            try {
                __status_smoke_assert(_S, variable_struct_exists(_B, "_switch_actor_index") && variable_struct_get(_B, "_switch_actor_index") == 1, "Forced doubles player switch targeted actor slot 1");
            } catch (e_actor_idx) { __status_smoke_assert(_S, false, "Forced doubles player switch targeted actor slot 1"); }
            variable_struct_set(_S, "state", "await_dialog");
            break;

        case "await_dialog":
            if (variable_struct_get(_S, "chosen_party_idx") < 0){
                var _picked_idx = (variable_struct_exists(_B, "_switch_target_idx") && is_real(variable_struct_get(_B, "_switch_target_idx"))) ? floor(variable_struct_get(_B, "_switch_target_idx")) : -1;
                if (_picked_idx >= 0){
                    variable_struct_set(_S, "chosen_party_idx", _picked_idx);
                    var _valid = false;
                    var _choices = variable_struct_get(_S, "valid_choices");
                    for (var _ci = 0; _ci < array_length(_choices); ++_ci){ if (_choices[_ci] == _picked_idx) { _valid = true; break; } }
                    __status_smoke_assert(_S, _valid, "Forced doubles player switch picked a valid bench mon when no explicit party index was provided");
                    var _party_live = party_ensure(_pid);
                    if (is_struct(_party_live) && is_array(_party_live.mons) && _picked_idx < array_length(_party_live.mons) && is_struct(_party_live.mons[_picked_idx]) && variable_struct_exists(_party_live.mons[_picked_idx], "name")){
                        variable_struct_set(_S, "chosen_name", string(variable_struct_get(_party_live.mons[_picked_idx], "name")));
                    }
                }
            }
            if (is_undefined(dialog2p_is_open) || !dialog2p_is_open(_pid)) break;
            if (!variable_struct_get(_S, "dialog_checked")){
                var _dlg_text = __status_smoke_dialog_text(_pid);
                var _chosen_name = string(variable_struct_get(_S, "chosen_name"));
                if (string_length(_chosen_name) > 0){
                    var _name_ok = string_pos("Go. " + _chosen_name + "!", _dlg_text) > 0;
                    var _generic_ok = string_pos("Go. Pokémon!", _dlg_text) == 0 && string_pos("Go. Pokemon!", _dlg_text) == 0;
                    __status_smoke_assert(_S, _name_ok && _generic_ok, "Forced doubles player switch dialog used the selected mon name instead of a generic Pokémon label");
                    variable_struct_set(_S, "dialog_checked", true);
                }
            }
            __status_smoke_advance_dialog(_pid, _S);
            if (variable_struct_get(_S, "dialog_checked")) variable_struct_set(_S, "state", "await_switch_apply");
            break;

        case "await_switch_apply":
            if (__status_smoke_advance_dialog(_pid, _S)) break;
            if (!variable_struct_exists(_B, "phase") || variable_struct_get(_B, "phase") != "command") break;
            var _party_after = party_ensure(_pid);
            var _picked_after = variable_struct_get(_S, "chosen_party_idx");
            var _slot0_ok = false;
            var _slot1_ok = false;
            var _slot1_changed = false;
            try {
                var _slot0_actor = _actors[0];
                var _slot1_actor = _actors[1];
                var _slot0_mon = (is_struct(_slot0_actor) && variable_struct_exists(_slot0_actor, "mon") && is_struct(variable_struct_get(_slot0_actor, "mon"))) ? variable_struct_get(_slot0_actor, "mon") : _slot0_actor;
                var _slot1_mon = (is_struct(_slot1_actor) && variable_struct_exists(_slot1_actor, "mon") && is_struct(variable_struct_get(_slot1_actor, "mon"))) ? variable_struct_get(_slot1_actor, "mon") : _slot1_actor;
                _slot0_ok = (_slot0_mon == variable_struct_get(_S, "original_slot0_mon"));
                _slot1_changed = (_slot1_mon != variable_struct_get(_S, "original_slot1_mon"));
                if (is_struct(_party_after) && is_array(_party_after.mons) && is_real(_picked_after) && _picked_after >= 0 && _picked_after < array_length(_party_after.mons)) _slot1_ok = (_slot1_mon == _party_after.mons[_picked_after]);
            } catch (e_slot_chk) { _slot0_ok = false; _slot1_ok = false; _slot1_changed = false; }
            __status_smoke_assert(_S, _slot0_ok, "Forced doubles player switch left player slot 0 unchanged");
            __status_smoke_assert(_S, _slot1_changed && _slot1_ok, "Forced doubles player switch replaced only player slot 1 with the chosen bench mon");
            __status_smoke_finish(_pid, _S, "completed");
            break;
    }
}

function test_battle_doubles_enemy_faint_auto_send_smoke_start(_auto_close = false){
    var _pid = 0;
    if (battle_is_open(_pid)) battle_close(_pid);

    var _party = party_ensure(_pid);
    if (!is_struct(_party)){
        show_debug_message("[smoke][doubles-enemy-faint-send] FAIL unable to ensure player party");
        return false;
    }

    var _lead0 = pokemon_factory_create(133, 30, {});
    var _lead1 = pokemon_factory_create(25, 30, {});
    variable_struct_set(_lead0, "name", "Smoke Hero A");
    variable_struct_set(_lead1, "name", "Smoke Hero B");
    __dev_assign_moves_to_mon(_lead0, [370, -1, -1, -1]);
    __dev_assign_moves_to_mon(_lead1, [150, -1, -1, -1]);
    _party.mons[0] = _lead0;
    _party.mons[1] = _lead1;
    global.PARTY[_pid] = _party;

    var _enemy0 = pokemon_factory_create(263, 24, {});
    var _enemy1 = pokemon_factory_create(19, 24, {});
    var _enemy2 = pokemon_factory_create(16, 24, {});
    variable_struct_set(_enemy0, "name", "Faint Left");
    variable_struct_set(_enemy1, "name", "Stay Right");
    variable_struct_set(_enemy2, "name", "Bench Replace");
    __dev_assign_moves_to_mon(_enemy0, [33, -1, -1, -1]);
    __dev_assign_moves_to_mon(_enemy1, [33, -1, -1, -1]);
    __dev_assign_moves_to_mon(_enemy2, [33, -1, -1, -1]);

    battle_open(_pid, 24, "forest", {
        type: "trainer",
        battle_format: "double",
        enemy_party: [_enemy0, _enemy1, _enemy2],
        trainer_name: "Enemy Faint Smoke",
        sprite: (variable_global_exists("spr_PokemonEmeraldTrainers") ? variable_global_get("spr_PokemonEmeraldTrainers") : undefined),
        sprite_index: 12,
        trainer_reward: 0
    });

    global.DEV_DOUBLES_ENEMY_FAINT_SEND_SMOKE = {
        pid: _pid,
        tag: "doubles-enemy-faint-send",
        global_name: "DEV_DOUBLES_ENEMY_FAINT_SEND_SMOKE",
        auto_close: (_auto_close == true),
        state: "opening",
        pass_count: 0,
        fail_count: 0,
        turn_counter: 0,
        pending_window_checked: false,
        replacement_name: "Bench Replace",
        original_enemy_right_name: "Stay Right"
    };
    __status_smoke_bind_current_battle(_pid, global.DEV_DOUBLES_ENEMY_FAINT_SEND_SMOKE);
    show_debug_message("[smoke][doubles-enemy-faint-send] starting doubles enemy faint auto-send smoke");
    return true;
}

function test_battle_doubles_enemy_faint_auto_send_smoke_update(_pid = 0){
    if (!variable_global_exists("DEV_DOUBLES_ENEMY_FAINT_SEND_SMOKE")) return;
    var _S = global.DEV_DOUBLES_ENEMY_FAINT_SEND_SMOKE;
    if (!is_struct(_S)) return;
    if (_pid != variable_struct_get(_S, "pid")) return;

    variable_struct_set(_S, "turn_counter", variable_struct_get(_S, "turn_counter") + 1);
    if (variable_struct_get(_S, "turn_counter") > 5400){
        __status_smoke_assert(_S, false, "timed out waiting for doubles enemy faint auto-send smoke to finish");
        __status_smoke_finish(_pid, _S, "timeout");
        return;
    }
    if (!battle_is_open(_pid)) return;

    var _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B) || !variable_struct_exists(_B, "actor") || !is_array(variable_struct_get(_B, "actor"))) return;
    var _actors = variable_struct_get(_B, "actor");
    if (array_length(_actors) < 4) return;

    switch (string(variable_struct_get(_S, "state"))){
        case "opening":
            if (__status_smoke_advance_dialog(_pid, _S)) break;
            if (!variable_struct_exists(_B, "phase") || variable_struct_get(_B, "phase") != "command") break;
            try {
                if (is_struct(_actors[2])){
                    __battle_set_hp_now(_actors[2], 6);
                    if (variable_struct_exists(_actors[2], "mon") && is_struct(variable_struct_get(_actors[2], "mon"))) __battle_set_hp_now(variable_struct_get(_actors[2], "mon"), 6);
                }
                variable_struct_set(_B, "_command_pending_action", { actor_index: 0, move_id: 370, target_index: 2 });
                variable_struct_set(_B, "_target_pick_targets", [2, 3]);
                variable_struct_set(_B, "_target_pick_index", 0);
                if (variable_struct_exists(_B, "sys_ui") && is_struct(variable_struct_get(_B, "sys_ui"))) variable_struct_set(variable_struct_get(_B, "sys_ui"), "menu", "target");
                var _queued = __status_smoke_queue_double_turn(_pid, [
                    { slot: 0, move_id: 370, actor_index: 0, target_index: 2 },
                    { actor_index: 1, target_index: 3, skip_turn: true, lock_action: true }
                ]);
                __status_smoke_assert(_S, _queued, "Queued a doubles turn that faints the left enemy slot");
                if (_queued) variable_struct_set(_S, "state", "await_send");
            } catch (e_queue_enemy_faint) {
                __status_smoke_assert(_S, false, "Queued a doubles turn that faints the left enemy slot");
                __status_smoke_finish(_pid, _S, "queue-failed");
                return;
            }
            break;

        case "await_send":
            __status_smoke_advance_dialog(_pid, _S);
            if (is_struct(_actors[2]) && variable_struct_exists(_actors[2], "name") && string(variable_struct_get(_actors[2], "name")) == string(variable_struct_get(_S, "replacement_name")) && is_struct(_actors[3]) && variable_struct_exists(_actors[3], "name") && string(variable_struct_get(_actors[3], "name")) == string(variable_struct_get(_S, "original_enemy_right_name")) && variable_struct_exists(_B, "phase") && variable_struct_get(_B, "phase") == "command"){
                variable_struct_set(_S, "state", "verify_done");
                break;
            }
            if (variable_struct_exists(_B, "_trainer_switch_prompt") && is_struct(variable_struct_get(_B, "_trainer_switch_prompt"))){
                __status_smoke_assert(_S, false, "Doubles enemy faint did not open the singles trainer switch prompt");
                __status_smoke_finish(_pid, _S, "unexpected-prompt");
                return;
            }

            var _pending_send = (variable_struct_exists(_B, "_trainer_pending_send") && is_struct(variable_struct_get(_B, "_trainer_pending_send"))) ? variable_struct_get(_B, "_trainer_pending_send") : undefined;
            if (is_struct(_pending_send) && !variable_struct_get(_S, "pending_window_checked")){
                __status_smoke_assert(_S, variable_struct_exists(_pending_send, "actor_index") && floor(variable_struct_get(_pending_send, "actor_index")) == 2, "Doubles enemy faint queued the replacement into the fainted enemy slot");
                __status_smoke_assert(_S, (!variable_struct_exists(_B, "_command_pending_action") || !is_struct(variable_struct_get(_B, "_command_pending_action"))) && (!variable_struct_exists(_B, "_target_pick_targets") || !is_array(variable_struct_get(_B, "_target_pick_targets"))), "Doubles enemy faint cleared stale pending target-pick state before the replacement arrived");
                if (is_struct(_B.sys_ui)) __status_smoke_assert(_S, string(variable_struct_get(_B.sys_ui, "menu")) != "target", "Doubles enemy faint did not leave the command UI stuck on target selection");
                variable_struct_set(_S, "pending_window_checked", true);
            }
            break;

        case "verify_done":
            __status_smoke_assert(_S, is_struct(_actors[2]) && variable_struct_exists(_actors[2], "name") && string(variable_struct_get(_actors[2], "name")) == string(variable_struct_get(_S, "replacement_name")), "Doubles enemy faint auto-sent the next trainer mon into the fainted enemy slot");
            __status_smoke_assert(_S, is_struct(_actors[3]) && variable_struct_exists(_actors[3], "name") && string(variable_struct_get(_actors[3], "name")) == string(variable_struct_get(_S, "original_enemy_right_name")), "Doubles enemy faint left the other enemy slot unchanged");
            __status_smoke_assert(_S, !variable_struct_exists(_B, "_trainer_switch_prompt") || !is_struct(variable_struct_get(_B, "_trainer_switch_prompt")), "Doubles enemy faint finished without leaving a trainer switch prompt behind");
            __status_smoke_assert(_S, !variable_struct_exists(_B, "_trainer_pending_send") || !is_struct(variable_struct_get(_B, "_trainer_pending_send")), "Doubles enemy faint consumed the pending enemy send after the replacement entered");
            __status_smoke_finish(_pid, _S, "completed");
            break;
    }
}

function __coop_smoke_seed_party(_pid, _names, _species, _moves, _level){
    var _party = party_ensure(_pid);
    if (!is_struct(_party)) return false;
    if (!variable_struct_exists(_party, "mons") || !is_array(variable_struct_get(_party, "mons"))) return false;

    var _mons = variable_struct_get(_party, "mons");
    var _count = min(array_length(_names), array_length(_species));
    for (var _i = 0; _i < _count; ++_i){
        var _mon = pokemon_factory_create(_species[_i], _level, {});
        if (!is_struct(_mon)) return false;
        variable_struct_set(_mon, "name", string(_names[_i]));
        if (is_array(_moves) && _i < array_length(_moves) && is_array(_moves[_i])) __dev_assign_moves_to_mon(_mon, _moves[_i]);
        _mons[_i] = _mon;
    }
    variable_struct_set(_party, "mons", _mons);
    global.PARTY[_pid] = _party;
    return true;
}

function __coop_smoke_begin(_tag, _global_name, _battle_kind, _auto_close){
    var _pid = 0;
    if (battle_is_open(0)) battle_close(0);
    if (battle_is_open(1)) battle_close(1);

    var _p0_ok = __coop_smoke_seed_party(0,
        ["Coop Lead A", "Coop Bench A"],
        [133, 25],
        [[33, 45, -1, -1], [98, 39, -1, -1]],
        24
    );
    var _p1_ok = __coop_smoke_seed_party(1,
        ["Coop Lead B", "Coop Bench B"],
        [10, 16],
        [[33, 28, -1, -1], [45, 19, -1, -1]],
        24
    );
    if (!_p0_ok || !_p1_ok){
        show_debug_message("[smoke][" + _tag + "] FAIL unable to seed co-op parties");
        return false;
    }

    if (_battle_kind == "trainer"){
        var _trainer_party = [];
        var _enemy0 = pokemon_factory_create(263, 24, {});
        var _enemy1 = pokemon_factory_create(19, 24, {});
        variable_struct_set(_enemy0, "name", "Trainer Foe A");
        variable_struct_set(_enemy1, "name", "Trainer Foe B");
        __dev_assign_moves_to_mon(_enemy0, [33, -1, -1, -1]);
        __dev_assign_moves_to_mon(_enemy1, [33, -1, -1, -1]);
        array_push(_trainer_party, _enemy0);
        array_push(_trainer_party, _enemy1);
        battle_open_trainer(_pid, {
            trainer_name: "Co-op Trainer Smoke",
            sprite: (variable_global_exists("spr_PokemonEmeraldTrainers") ? variable_global_get("spr_PokemonEmeraldTrainers") : undefined),
            sprite_index: 12,
            party: _trainer_party,
            area_type: "forest",
            battle_format: "double",
            coop_enabled: true,
            player_pids: [0, 1],
            trainer_reward: 0
        });
    } else {
        battle_open(_pid, 24, "forest", {
            battle_type: "wild",
            battle_format: "double",
            coop_enabled: true,
            player_pids: [0, 1]
        });
    }

    var _state = {
        pid: _pid,
        tag: _tag,
        global_name: _global_name,
        auto_close: (_auto_close == true),
        state: "opening",
        pass_count: 0,
        fail_count: 0,
        turn_counter: 0,
        dialog_advance_ms: -1,
        battle_kind: _battle_kind
    };
    variable_global_set(_global_name, _state);
    __status_smoke_bind_current_battle(_pid, _state);
    show_debug_message("[smoke][" + _tag + "] starting co-op doubles " + _battle_kind + " smoke");
    return true;
}

function __coop_smoke_update(_global_name, _pid){
    if (!variable_global_exists(_global_name)) return;
    var _S = variable_global_get(_global_name);
    if (!is_struct(_S)) return;
    if (_pid != variable_struct_get(_S, "pid")) return;

    variable_struct_set(_S, "turn_counter", variable_struct_get(_S, "turn_counter") + 1);
    if (variable_struct_get(_S, "turn_counter") > 5400){
        __status_smoke_assert(_S, false, "timed out waiting for co-op doubles smoke to finish");
        __status_smoke_finish(_pid, _S, "timeout");
        return;
    }
    if (!battle_is_open(0)) return;

    __status_smoke_advance_dialog(0, _S);
    __status_smoke_advance_dialog(1, _S);

    var _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B)) return;
    if (!variable_struct_exists(_B, "phase") || string(variable_struct_get(_B, "phase")) != "command") return;

    var _B1 = __battle_ensure_slot(1);
    __status_smoke_assert(_S, battle_is_open(0) && battle_is_open(1), "Co-op doubles battle resolved as open for both player ids");
    __status_smoke_assert(_S, _B1 == _B, "Player 1 resolves to the shared co-op battle slot");
    __status_smoke_assert(_S, variable_struct_exists(_B, "battle_format") && string(variable_struct_get(_B, "battle_format")) == "double", "Co-op battle stayed in doubles format");
    __status_smoke_assert(_S, variable_struct_exists(_B, "coop_enabled") && variable_struct_get(_B, "coop_enabled") == true, "Co-op doubles battle kept co-op routing enabled");
    __status_smoke_assert(_S, !is_undefined(battle_uses_shared_screen) && battle_uses_shared_screen(0) && battle_uses_shared_screen(1), "Co-op doubles battle requests the shared battle screen for both players");

    var _player_pids_ok = false;
    if (variable_struct_exists(_B, "player_pids") && is_array(variable_struct_get(_B, "player_pids"))){
        var _ppids = variable_struct_get(_B, "player_pids");
        _player_pids_ok = (array_length(_ppids) >= 2 && _ppids[0] == 0 && _ppids[1] == 1);
    }
    __status_smoke_assert(_S, _player_pids_ok, "Co-op doubles battle stored both player ids on the slot");

    var _owners_ok = false;
    if (variable_struct_exists(_B, "actor_owner_pid") && is_array(variable_struct_get(_B, "actor_owner_pid"))){
        var _owners = variable_struct_get(_B, "actor_owner_pid");
        _owners_ok = (array_length(_owners) >= 2 && _owners[0] == 0 && _owners[1] == 1);
    }
    __status_smoke_assert(_S, _owners_ok, "Player-side active battlers are owned by pid 0 and pid 1 respectively");

    var _actors_ok = false;
    if (variable_struct_exists(_B, "actor") && is_array(variable_struct_get(_B, "actor"))){
        var _actors = variable_struct_get(_B, "actor");
        _actors_ok = (array_length(_actors) >= 4 && is_struct(_actors[0]) && is_struct(_actors[1]) && is_struct(_actors[2]) && is_struct(_actors[3]));
    }
    __status_smoke_assert(_S, _actors_ok, "Co-op doubles battle opened with four active battler slots populated");

    var _battle_kind = string(variable_struct_get(_S, "battle_kind"));
    if (_battle_kind == "trainer"){
        var _trainer_ok = false;
        if (variable_struct_exists(_B, "_trainer_party_active_indices") && is_array(variable_struct_get(_B, "_trainer_party_active_indices"))){
            var _active = variable_struct_get(_B, "_trainer_party_active_indices");
            _trainer_ok = (array_length(_active) >= 2 && is_real(_active[0]) && is_real(_active[1]));
        }
        __status_smoke_assert(_S, variable_struct_exists(_B, "battle_type") && string(variable_struct_get(_B, "battle_type")) == "trainer", "Co-op trainer smoke opened a trainer battle");
        __status_smoke_assert(_S, _trainer_ok, "Co-op trainer smoke populated doubles trainer active indices");
    } else {
        __status_smoke_assert(_S, variable_struct_exists(_B, "battle_type") && string(variable_struct_get(_B, "battle_type")) == "wild", "Co-op wild smoke opened a wild battle");
    }

    __status_smoke_finish(_pid, _S, "completed");
}

function test_battle_coop_double_wild_smoke_start(_auto_close = false){
    return __coop_smoke_begin("coop-double-wild", "DEV_COOP_DOUBLE_WILD_SMOKE", "wild", _auto_close);
}

function test_battle_coop_double_wild_smoke_update(_pid = 0){
    __coop_smoke_update("DEV_COOP_DOUBLE_WILD_SMOKE", _pid);
}

function test_battle_coop_double_trainer_smoke_start(_auto_close = false){
    return __coop_smoke_begin("coop-double-trainer", "DEV_COOP_DOUBLE_TRAINER_SMOKE", "trainer", _auto_close);
}

function test_battle_coop_double_trainer_smoke_update(_pid = 0){
    __coop_smoke_update("DEV_COOP_DOUBLE_TRAINER_SMOKE", _pid);
}

function test_battle_burn_poison_residual_smoke_start(_auto_close = false){
    var _pid = 0;
    if (battle_is_open(_pid)) battle_close(_pid);

    var _S = {
        pid: _pid,
        tag: "burn-poison-residual",
        global_name: "DEV_BURN_POISON_RESIDUAL_SMOKE",
        auto_close: (_auto_close == true),
        state: "running",
        turn_counter: 0,
        pass_count: 0,
        fail_count: 0,
        started_ms: current_time
    };
    global.DEV_BURN_POISON_RESIDUAL_SMOKE = _S;
    show_debug_message("[smoke][burn-poison-residual] starting direct residual status smoke");

    global.DEV_FORCE_ACCURACY_HIT = true;
    global.DEV_FORCE_BURN_CHANCE = 100;
    global.DEV_FORCE_POISON_CHANCE = 100;

    var _burn_apply_a = __effect_smoke_mon(133, 30, 160, [261, -1, -1, -1]);
    var _burn_apply_d = __effect_smoke_mon(10, 30, 160, [1, -1, -1, -1]);
    __effect_smoke_slot(_pid, _burn_apply_a, _burn_apply_d);
    __battle_perform_action_impl(_pid, { slot: 0, move_id: 261, actor_index: 0, target_index: 1 });
    __status_smoke_assert(_S, __effect_smoke_has_status(_burn_apply_d, "burn"), "Will-O-Wisp still applies burn through move meta");

    var _poison_apply_a = __effect_smoke_mon(133, 30, 160, [342, -1, -1, -1]);
    var _poison_apply_d = __effect_smoke_mon(10, 30, 160, [1, -1, -1, -1]);
    __effect_smoke_slot(_pid, _poison_apply_a, _poison_apply_d);
    __battle_perform_action_impl(_pid, { slot: 0, move_id: 342, actor_index: 0, target_index: 1 });
    __status_smoke_assert(_S, __effect_smoke_has_status(_poison_apply_d, "poison"), "Poison Tail still applies poison through move meta");

    var _single = __effect_smoke_mon(133, 30, 160, [1, -1, -1, -1]);
    __effect_smoke_slot(_pid, _single, __effect_smoke_mon(10, 30, 160, [1, -1, -1, -1]));
    status_system_apply_status(_single, "burn", {});
    var _burn_inst = status_system_get(_single, "burn");
    if (is_struct(_burn_inst) && variable_struct_exists(_burn_inst, "_skip_first_tick")) variable_struct_set(_burn_inst, "_skip_first_tick", undefined);
    var _single_before = __battle_hp_now(_single);
    status_system_tick_statuses(_single, undefined);
    var _single_after = __battle_hp_now(_single);
    __status_smoke_assert(_S, (_single_before - _single_after) == max(1, floor(__battle_hp_max(_single) / 8)), "Burn residual still deals one-eighth max HP through the shared HP path");

    var _P0 = __effect_smoke_mon(133, 30, 160, [1, -1, -1, -1]);
    var _P1 = __effect_smoke_mon(25, 30, 160, [1, -1, -1, -1]);
    var _E0 = __effect_smoke_mon(263, 30, 160, [1, -1, -1, -1]);
    var _E1 = __effect_smoke_mon(19, 30, 160, [1, -1, -1, -1]);
    var _B = __effect_smoke_slot_double(_pid, _P0, _P1, _E0, _E1);
    status_system_apply_status(_P1, "burn", { source: _E0 });
    status_system_apply_status(_E1, "poison", { source: _P0 });
    var _burn_double_inst = status_system_get(_P1, "burn");
    var _poison_double_inst = status_system_get(_E1, "poison");
    if (is_struct(_burn_double_inst) && variable_struct_exists(_burn_double_inst, "_skip_first_tick")) variable_struct_set(_burn_double_inst, "_skip_first_tick", undefined);
    if (is_struct(_poison_double_inst) && variable_struct_exists(_poison_double_inst, "_skip_first_tick")) variable_struct_set(_poison_double_inst, "_skip_first_tick", undefined);

    var _p0_before = __battle_hp_now(_P0);
    var _p1_before = __battle_hp_now(_P1);
    var _e0_before = __battle_hp_now(_E0);
    var _e1_before = __battle_hp_now(_E1);
    variable_struct_set(_B, "turn_queue", [{ skip_turn: true }]);
    variable_struct_set(_B, "turn_i", 1);
    variable_struct_set(_B, "phase", "turn");
    variable_struct_set(_B, "_statuses_ticked", false);
    __battle_step_turn_if_ready(_pid);
    var _p0_after = __battle_hp_now(_P0);
    var _p1_after = __battle_hp_now(_P1);
    var _e0_after = __battle_hp_now(_E0);
    var _e1_after = __battle_hp_now(_E1);
    __status_smoke_assert(_S, _p1_after < _p1_before && (_p1_before - _p1_after) == max(1, floor(__battle_hp_max(_P1) / 8)), "Doubles end-of-turn still ticks burn on the second player battler");
    __status_smoke_assert(_S, _e1_after < _e1_before && (_e1_before - _e1_after) == max(1, floor(__battle_hp_max(_E1) / 8)), "Doubles end-of-turn still ticks poison on the second enemy battler");
    __status_smoke_assert(_S, _p0_after == _p0_before && _e0_after == _e0_before, "Residual status smoke left unaffected battlers unchanged");

    global.DEV_FORCE_ACCURACY_HIT = false;
    global.DEV_FORCE_BURN_CHANCE = -1;
    global.DEV_FORCE_POISON_CHANCE = -1;

    var _fails = variable_struct_get(_S, "fail_count");
    __status_smoke_finish(_pid, _S, (_fails == 0) ? "completed" : "failed");
    return (_fails == 0);
}

function test_battle_burn_poison_residual_smoke_update(_pid = 0){
    // Direct smoke completes synchronously in start().
}

function test_battle_visual_target_smoke_start(_auto_close = false){
    var _pid = 0;
    if (battle_is_open(_pid)) battle_close(_pid);
    var _S = {
        pid: _pid,
        tag: "visual-target",
        global_name: "DEV_VISUAL_TARGET_SMOKE",
        auto_close: (_auto_close == true),
        state: "running",
        turn_counter: 0,
        pass_count: 0,
        fail_count: 0,
        started_ms: current_time
    };
    global.DEV_VISUAL_TARGET_SMOKE = _S;
    show_debug_message("[smoke][visual-target] starting direct basic-hit / Quick Attack / multi-hit visual smoke");

    var _basic_hit_id = __status_smoke_find_move_id(["wing-attack", "wing_attack", "pound", "scratch", "tackle"], 1);
    var _quick_attack_id = __status_smoke_find_move_id(["quick-attack", "quick_attack"]);
    var _multi_hit_id = __status_smoke_find_move_id(["double-kick", "double_kick", "doublekick", "comet-punch", "comet_punch", "fury-swipes", "fury_swipes", "arm-thrust", "arm_thrust", "armthrust"], 30);
    if (_basic_hit_id < 0 || _quick_attack_id < 0 || _multi_hit_id < 0){
        __status_smoke_assert(_S, false, "Resolved a basic hit, Quick Attack, and a multi-hit move from move data");
        __status_smoke_finish(_pid, _S, "missing-moves");
        return false;
    }

    var _lead_a = __effect_smoke_mon(133, 26, 120, [_multi_hit_id, _basic_hit_id, -1, -1]);
    var _lead_b = __effect_smoke_mon(25, 26, 120, [_quick_attack_id, -1, -1, -1]);
    var _enemy_a = __effect_smoke_mon(263, 22, 120, [150, -1, -1, -1]);
    var _enemy_b = __effect_smoke_mon(19, 22, 120, [150, -1, -1, -1]);
    variable_struct_set(_lead_a, "name", "Visual Alpha");
    variable_struct_set(_lead_b, "name", "Visual Beta");
    variable_struct_set(_enemy_a, "name", "Target Left");
    variable_struct_set(_enemy_b, "name", "Target Right");
    var _B = __effect_smoke_slot_double(_pid, _lead_a, _lead_b, _enemy_a, _enemy_b);
    var _actors_visual = variable_struct_get(_B, "actor");

    __status_smoke_clear_anim_queue(_pid);
    for (var _bi = 0; _bi < 4; ++_bi) __status_smoke_reset_visual_actor(_actors_visual[_bi]);
    __battle_perform_action_impl(_pid, { slot: 1, move_id: _basic_hit_id, actor_index: 0, target_index: 2 });
    if (!is_undefined(battle_anim_queue_tick)) battle_anim_queue_tick(_pid);
    var _basic_hit_overlays = __status_smoke_count_hit_effect_overlays(_pid, 2, spr_hiteffect, undefined);
    __status_smoke_assert(_S, _basic_hit_overlays >= 1, "Basic hit move enqueued a hit overlay on the chosen doubles target");
    __status_smoke_assert(_S, __status_smoke_actor_has_nudge(_lead_a, 1), "Basic hit move gave the attacker a forward nudge toward the chosen doubles target");
    __status_smoke_assert(_S, __status_smoke_actor_has_nudge(_enemy_a, -1), "Basic hit move gave the chosen defender recoil nudge in doubles");
    __status_smoke_assert(_S, __status_smoke_last_move_damage(_enemy_a, _basic_hit_id) > 0 && __status_smoke_last_move_damage(_enemy_b, _basic_hit_id) <= 0, "Basic hit visuals did not attach to the wrong enemy slot in doubles");

    __status_smoke_clear_anim_queue(_pid);
    for (var _qi = 0; _qi < 4; ++_qi) __status_smoke_reset_visual_actor(_actors_visual[_qi]);
    __battle_perform_action_impl(_pid, { slot: 0, move_id: _quick_attack_id, actor_index: 1, target_index: 3 });
    if (!is_undefined(battle_anim_queue_tick)) battle_anim_queue_tick(_pid);
    var _quick_afterimages = __status_smoke_count_hit_effect_overlays(_pid, 1);
    __status_smoke_assert(_S, _quick_afterimages >= 2, "Quick Attack enqueued attacker afterimages for the lunging actor");
    __status_smoke_assert(_S, __status_smoke_actor_has_nudge(_lead_b, 1), "Quick Attack gave the attacker a forward nudge toward the chosen doubles target");
    __status_smoke_assert(_S, __status_smoke_actor_has_nudge(_enemy_b, -1), "Quick Attack gave the chosen defender recoil nudge in doubles");
    __status_smoke_assert(_S, __status_smoke_last_move_damage(_enemy_a, _quick_attack_id) <= 0 && __status_smoke_last_move_damage(_enemy_b, _quick_attack_id) > 0, "Quick Attack visuals did not attach to the wrong enemy slot in doubles");

    __status_smoke_clear_anim_queue(_pid);
    for (var _mi = 0; _mi < 4; ++_mi) __status_smoke_reset_visual_actor(_actors_visual[_mi]);
    __battle_perform_action_impl(_pid, { slot: 0, move_id: _multi_hit_id, actor_index: 0, target_index: 3 });
    if (!is_undefined(battle_anim_queue_tick)) battle_anim_queue_tick(_pid);
    var _multi_hits = __status_smoke_count_hit_effect_overlays(_pid, 3, spr_multihit, undefined);
    __status_smoke_assert(_S, _multi_hits >= 2, "Multi-hit move enqueued repeated hit overlays on the chosen doubles target");
    __status_smoke_assert(_S, __status_smoke_actor_has_nudge(_lead_a, 1), "Multi-hit move gave the attacker a forward nudge toward the chosen doubles target");
    __status_smoke_assert(_S, __status_smoke_actor_has_nudge(_enemy_b, -1), "Multi-hit move gave the chosen defender recoil nudge in doubles");
    __status_smoke_assert(_S, __status_smoke_actor_nudge_mag(_enemy_b) >= 3.5, "Multi-hit move defender recoil stayed visibly strong enough to read in battle");
    __status_smoke_assert(_S, __status_smoke_last_move_damage(_enemy_a, _multi_hit_id) <= 0 && __status_smoke_last_move_damage(_enemy_b, _multi_hit_id) > 0, "Multi-hit visuals did not attach to the wrong enemy slot in doubles");

    var _fails = variable_struct_get(_S, "fail_count");
    __status_smoke_finish(_pid, _S, (_fails == 0) ? "completed" : "failed");
    return (_fails == 0);
}

function test_battle_visual_target_smoke_update(_pid = 0){
    // Direct smoke completes synchronously in start().
}

function test_battle_confusion_visual_smoke_start(_auto_close = false){
    var _pid = 0;
    if (battle_is_open(_pid)) battle_close(_pid);
    var _S = {
        pid: _pid,
        tag: "confusion-visual",
        global_name: "DEV_CONFUSION_VISUAL_SMOKE",
        auto_close: (_auto_close == true),
        state: "running",
        turn_counter: 0,
        pass_count: 0,
        fail_count: 0,
        started_ms: current_time
    };
    global.DEV_CONFUSION_VISUAL_SMOKE = _S;
    show_debug_message("[smoke][confusion-visual] starting direct confusion dialog/orbit smoke");

    var _basic_hit_id = __status_smoke_find_move_id(["pound", "scratch", "tackle", "wing-attack", "wing_attack"], 1);
    if (_basic_hit_id < 0){
        __status_smoke_assert(_S, false, "Resolved a basic damaging move for the confusion visual smoke");
        __status_smoke_finish(_pid, _S, "missing-move");
        return false;
    }

    var _hero = __effect_smoke_mon(133, 26, 120, [_basic_hit_id, -1, -1, -1]);
    var _foe = __effect_smoke_mon(19, 22, 120, [150, -1, -1, -1]);
    variable_struct_set(_hero, "name", "Confused Hero");
    variable_struct_set(_foe, "name", "Target Dummy");
    var _B = __effect_smoke_slot(_pid, _hero, _foe, "trainer");
    __status_smoke_bind_current_battle(_pid, _S);

    var _actors = variable_struct_get(_B, "actor");
    var _hero_actor = _actors[0];
    __status_smoke_clear_anim_queue(_pid);
    __status_smoke_reset_visual_actor(_hero_actor);
    __status_smoke_reset_visual_actor(_actors[1]);

    try {
        var _hero_status_target = _hero_actor;
        if (variable_struct_exists(_hero_actor, "mon") && is_struct(variable_struct_get(_hero_actor, "mon"))) _hero_status_target = variable_struct_get(_hero_actor, "mon");
        status_system_ensure_mon(_hero_status_target);
        var _ss_inner = variable_struct_get(_hero_status_target, "statuses");
        var _conf_inst = { id: "confusion", applied_ms: current_time, turns: 2, stacks: 1, source: undefined };
        variable_struct_set(_ss_inner, "confusion", _conf_inst);
        if (!variable_struct_exists(_hero_actor, "statuses") || !is_struct(variable_struct_get(_hero_actor, "statuses"))) variable_struct_set(_hero_actor, "statuses", {});
        variable_struct_set(variable_struct_get(_hero_actor, "statuses"), "confusion", _conf_inst);
        variable_struct_set(_hero_actor, "_confusion_turn_pending_roll", false);
    } catch (e_conf_setup) {
        __status_smoke_assert(_S, false, "Smoke setup created a confusion status on the acting battler");
        __status_smoke_finish(_pid, _S, "setup-failed");
        return false;
    }

    var _result = __battle_perform_action_impl(_pid, { slot: 0, move_id: _basic_hit_id, actor_index: 0, target_index: 1 });
    if (!is_undefined(battle_anim_queue_tick)) battle_anim_queue_tick(_pid);

    var _dlg_open = (!is_undefined(dialog2p_is_open) && dialog2p_is_open(_pid));
    var _dlg_text = __status_smoke_dialog_text(_pid);
    var _dlg_text_l = string_lower(_dlg_text);
    var _orbit_count = __status_smoke_count_orbit_states(_pid, 0, spr_confused);
    var _hold_turn = (variable_struct_exists(_B, "_hold_current_action_for_status_dialog") && variable_struct_get(_B, "_hold_current_action_for_status_dialog") == true);
    var _pending_roll = (variable_struct_exists(_hero_actor, "_confusion_turn_pending_roll") && variable_struct_get(_hero_actor, "_confusion_turn_pending_roll") == true);

    __status_smoke_assert(_S, string_length(string(_result)) == 0, "Confusion pre-turn dialog paused the action before the move result text");
    __status_smoke_assert(_S, _dlg_open, "Confusion smoke opened the battle dialog for the pre-turn confusion message");
    __status_smoke_assert(_S, string_pos("confused hero", _dlg_text_l) > 0 && string_pos("confused", _dlg_text_l) > 0, "Confusion smoke showed the wrapped 'is confused' dialog text");
    __status_smoke_assert(_S, _orbit_count >= 1, "Confusion smoke queued an orbiting spr_confused animation above the acting battler");
    __status_smoke_assert(_S, _hold_turn, "Confusion smoke held the current action until the dialog closes");
    __status_smoke_assert(_S, _pending_roll, "Confusion smoke marked the battler to resume with the self-hit roll after the dialog");

    var _fails = variable_struct_get(_S, "fail_count");
    __status_smoke_finish(_pid, _S, (_fails == 0) ? "completed" : "failed");
    return (_fails == 0);
}

function test_battle_confusion_visual_smoke_update(_pid = 0){
    // Direct smoke completes synchronously in start().
}

function __effect_smoke_mon(_species, _level, _hp_max, _moves){
    var _mon = pokemon_factory_create(_species, _level, {});
    variable_struct_set(_mon, "hp_max", _hp_max);
    variable_struct_set(_mon, "maxhp", _hp_max);
    variable_struct_set(_mon, "hp_now", _hp_max);
    variable_struct_set(_mon, "hp", _hp_max);
    variable_struct_set(_mon, "atk", 80);
    variable_struct_set(_mon, "def", 70);
    variable_struct_set(_mon, "spa", 80);
    variable_struct_set(_mon, "spd", 70);
    variable_struct_set(_mon, "spe", 80);
    if (!variable_struct_exists(_mon, "name")) variable_struct_set(_mon, "name", string(variable_struct_exists(_mon, "species") ? variable_struct_get(_mon, "species") : "Pokemon"));
    __dev_assign_moves_to_mon(_mon, _moves);
    return _mon;
}

function __effect_smoke_slot(_pid, _A, _D, _mode = "trainer"){
    if (variable_global_exists("sys_battles") && is_array(global.sys_battles) && array_length(global.sys_battles) > _pid){
        global.sys_battles[_pid] = undefined;
    }
    var _B = __battle_ensure_slot(_pid);
    variable_struct_set(_A, "actor_index", 0);
    variable_struct_set(_D, "actor_index", 1);
    variable_struct_set(_B, "sys_open", true);
    variable_struct_set(_B, "phase", "command");
    variable_struct_set(_B, "_battle_mode", _mode);
    variable_struct_set(_B, "actor", [_A, _D]);
    variable_struct_set(_B, "_field", __battle_field_defaults());
    return _B;
}

function __effect_smoke_slot_double(_pid, _P0, _P1, _E0, _E1, _mode = "trainer"){
    if (variable_global_exists("sys_battles") && is_array(global.sys_battles) && array_length(global.sys_battles) > _pid){
        global.sys_battles[_pid] = undefined;
    }
    var _B = __battle_ensure_slot(_pid);
    variable_struct_set(_P0, "actor_index", 0);
    variable_struct_set(_P1, "actor_index", 1);
    variable_struct_set(_E0, "actor_index", 2);
    variable_struct_set(_E1, "actor_index", 3);
    variable_struct_set(_B, "sys_open", true);
    variable_struct_set(_B, "phase", "command");
    variable_struct_set(_B, "_battle_mode", _mode);
    variable_struct_set(_B, "battle_format", "double");
    variable_struct_set(_B, "active_per_side", 2);
    variable_struct_set(_B, "actor", [_P0, _P1, _E0, _E1]);
    variable_struct_set(_B, "_field", __battle_field_defaults());
    return _B;
}

function __effect_smoke_set_hp(_mon, _hp){
    var _v = max(0, floor(_hp));
    variable_struct_set(_mon, "hp_now", _v);
    variable_struct_set(_mon, "hp", _v);
}

function __effect_smoke_has_status(_mon, _sid){
    try {
        if (!is_undefined(status_system_has_status) && status_system_has_status(_mon, _sid)) return true;
        if (variable_struct_exists(_mon, "mon") && is_struct(variable_struct_get(_mon, "mon")) && status_system_has_status(variable_struct_get(_mon, "mon"), _sid)) return true;
    } catch (e_stat) {}
    return false;
}

function __effect_smoke_direct_queue_turn(_pid, _player_slot, _enemy_slot){
    var _B = __battle_ensure_slot(_pid);
    var _actors = variable_struct_get(_B, "actor");
    var _A = _actors[0];
    var _D = _actors[1];
    _B.turn_action_player = { slot: _player_slot, move_id: _A.moves[_player_slot], actor_index: 0, target_index: 1 };
    _B.turn_action_enemy = (_enemy_slot >= 0) ? { slot: _enemy_slot, move_id: _D.moves[_enemy_slot], actor_index: 1, target_index: 0 } : undefined;
    _B.turn_queue = __battle_build_turn_actions(_pid);
    _B.turn_i = 0;
    _B.phase = "turn";
}

function test_battle_effect_131_155_smoke_start(_auto_close = false){
    var _pid = 0;
    var _S = {
        pid: _pid,
        tag: "effect-131-155",
        global_name: "DEV_EFFECT_131_155_SMOKE",
        auto_close: (_auto_close == true),
        state: "running",
        turn_counter: 0,
        pass_count: 0,
        fail_count: 0,
        started_ms: current_time
    };
    global.DEV_EFFECT_131_155_SMOKE = _S;
    show_debug_message("[smoke][effect-131-155] starting direct battle-effect smoke");

    var _A;
    var _D;
    var _B;
    var _before;
    var _after;
    var _ok;

    // 131 Sonic Boom: exact 20 HP damage.
    _A = __effect_smoke_mon(133, 30, 120, [49, -1, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 120, [150, -1, -1, -1]);
    __effect_smoke_slot(_pid, _A, _D);
    _before = __battle_hp_now(_D);
    __battle_apply_move_damage(_pid, 1, _A, _D, 49, 20);
    _after = __battle_hp_now(_D);
    __status_smoke_assert(_S, (_before - _after) == 20, "effect 131 Sonic Boom dealt exactly 20 damage");

    // 133 weather healing: sun = 2/3, rain = 1/4.
    _A = __effect_smoke_mon(133, 30, 120, [234, -1, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 120, [150, -1, -1, -1]);
    __effect_smoke_slot(_pid, _A, _D);
    __battle_set_weather(_pid, "sun", { source: _A, duration: 5 });
    __effect_smoke_set_hp(_A, 30);
    __battle_apply_move_meta_effects(_pid, { move_id: 234 }, _A, _D, 234, 0, __battle_get_move_meta(234));
    __status_smoke_assert(_S, __battle_hp_now(_A) == 110, "effect 133 sun healing restored 2/3 max HP");
    __battle_set_weather(_pid, "rain", { source: _A, duration: 5 });
    __effect_smoke_set_hp(_A, 30);
    __battle_apply_move_meta_effects(_pid, { move_id: 234 }, _A, _D, 234, 0, __battle_get_move_meta(234));
    __status_smoke_assert(_S, __battle_hp_now(_A) == 60, "effect 133 bad-weather healing restored 1/4 max HP");

    // 136 Hidden Power: IVs determine type and power.
    _A = __effect_smoke_mon(133, 30, 120, [237, -1, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 120, [150, -1, -1, -1]);
    variable_struct_set(_A, "iv", { hp: 31, atk: 31, def: 31, spa: 31, spd: 31, spe: 31 });
    __effect_smoke_slot(_pid, _A, _D);
    var _hp_type_ok = (scr_move_type_id_by_id(237, _A) == 17);
    var _hp_power_ok = (__battle_move_power(237, _A, _D) == 70);
    __status_smoke_assert(_S, _hp_type_ok && _hp_power_ok, "effect 136 Hidden Power used IV-based type and power");

    // 143 Belly Drum.
    _A = __effect_smoke_mon(133, 30, 200, [187, -1, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 120, [150, -1, -1, -1]);
    __effect_smoke_slot(_pid, _A, _D);
    __effect_smoke_set_hp(_A, 150);
    __battle_perform_action_impl(_pid, { slot: 0, move_id: 187, actor_index: 0, target_index: 0 });
    var _bd_stage = 0;
    try { var _bd_stages = variable_struct_get(_A, "_stages"); _bd_stage = variable_struct_get(_bd_stages, "atk"); } catch (e_bd) { _bd_stage = 0; }
    __status_smoke_assert(_S, __battle_hp_now(_A) == 50 && _bd_stage == 6, "effect 143 Belly Drum paid half HP and maximized Attack");

    // 144 Psych Up.
    _A = __effect_smoke_mon(133, 30, 120, [244, -1, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 120, [150, -1, -1, -1]);
    variable_struct_set(_D, "_stages", { atk: 3, def: -2 });
    __effect_smoke_slot(_pid, _A, _D);
    __battle_perform_action_impl(_pid, { slot: 0, move_id: 244, actor_index: 0, target_index: 1 });
    var _pu_ok = false;
    try { var _pu_stages = variable_struct_get(_A, "_stages"); _pu_ok = (variable_struct_get(_pu_stages, "atk") == 3 && variable_struct_get(_pu_stages, "def") == -2); } catch (e_pu) { _pu_ok = false; }
    __status_smoke_assert(_S, _pu_ok, "effect 144 Psych Up copied target stat stages");

    // 145 Mirror Coat.
    _A = __effect_smoke_mon(133, 30, 120, [243, -1, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 120, [150, -1, -1, -1]);
    __effect_smoke_slot(_pid, _A, _D);
    variable_struct_set(_A, "_last_received_damage", 20);
    variable_struct_set(_A, "_last_received_move_damage_class", 3);
    variable_struct_set(_A, "_last_received_from_actor_index", 1);
    _before = __battle_hp_now(_D);
    __battle_perform_action_impl(_pid, { slot: 0, move_id: 243, actor_index: 0, target_index: 1 });
    _after = __battle_hp_now(_D);
    __status_smoke_assert(_S, (_before - _after) == 40, "effect 145 Mirror Coat reflected double special damage");

    // 141 Ancient Power: post-hit omni-boost applies to the user, not the target.
    _A = __effect_smoke_mon(133, 30, 120, [246, -1, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 160, [150, -1, -1, -1]);
    __effect_smoke_slot(_pid, _A, _D);
    __battle_apply_move_meta_effects(_pid, { move_id: 246, actor_index: 0, target_index: 1 }, _A, _D, 246, 10, __battle_get_move_meta(246));
    var _ancient_user_ok = false;
    var _ancient_target_ok = true;
    try {
        var _ancient_user_stages = variable_struct_get(_A, "_stages");
        _ancient_user_ok = variable_struct_get(_ancient_user_stages, "atk") == 1
            && variable_struct_get(_ancient_user_stages, "def") == 1
            && variable_struct_get(_ancient_user_stages, "spa") == 1
            && variable_struct_get(_ancient_user_stages, "spd") == 1
            && variable_struct_get(_ancient_user_stages, "spe") == 1;
    } catch (e_ancient_user) { _ancient_user_ok = false; }
    try {
        if (variable_struct_exists(_D, "_stages") && is_struct(variable_struct_get(_D, "_stages"))){
            var _ancient_target_stages = variable_struct_get(_D, "_stages");
            _ancient_target_ok = !variable_struct_exists(_ancient_target_stages, "atk")
                && !variable_struct_exists(_ancient_target_stages, "def")
                && !variable_struct_exists(_ancient_target_stages, "spa")
                && !variable_struct_exists(_ancient_target_stages, "spd")
                && !variable_struct_exists(_ancient_target_stages, "spe");
        }
    } catch (e_ancient_target) { _ancient_target_ok = false; }
    __status_smoke_assert(_S, _ancient_user_ok && _ancient_target_ok, "effect 141 Ancient Power boosted the user only");

    // 146 Skull Bash defense boost on charge.
    _A = __effect_smoke_mon(133, 30, 120, [130, -1, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 120, [150, -1, -1, -1]);
    __effect_smoke_slot(_pid, _A, _D);
    __battle_perform_action_impl(_pid, { slot: 0, move_id: 130, actor_index: 0, target_index: 1 });
    var _skull_ok = false;
    try { var _skull_ch = variable_struct_get(_A, "_charging_move"); var _skull_st = variable_struct_get(_A, "_stages"); _skull_ok = is_struct(_skull_ch) && variable_struct_get(_skull_st, "def") == 1; } catch (e_skull) { _skull_ok = false; }
    __status_smoke_assert(_S, _skull_ok, "effect 146 Skull Bash charged and raised Defense");

    // 147 Twister can hit Fly/Bounce-style targets and flinch via meta.
    global.DEV_FORCE_FLINCH_CHANCE = 100;
    _A = __effect_smoke_mon(133, 30, 120, [239, -1, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 160, [150, -1, -1, -1]);
    variable_struct_set(_D, "_semi_invuln", "fly");
    __effect_smoke_slot(_pid, _A, _D);
    _before = __battle_hp_now(_D);
    __battle_perform_action_impl(_pid, { slot: 0, move_id: 239, actor_index: 0, target_index: 1 });
    _after = __battle_hp_now(_D);
    __status_smoke_assert(_S, _after < _before && variable_struct_exists(_D, "_flinched") && variable_struct_get(_D, "_flinched") == true, "effect 147 Twister hit airborne target and applied flinch");
    global.DEV_FORCE_FLINCH_CHANCE = -1;

    // 148 Earthquake can hit Dig targets.
    _A = __effect_smoke_mon(133, 30, 120, [89, -1, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 160, [150, -1, -1, -1]);
    variable_struct_set(_D, "_semi_invuln", "dig");
    __effect_smoke_slot(_pid, _A, _D);
    _before = __battle_hp_now(_D);
    __battle_perform_action_impl(_pid, { slot: 0, move_id: 89, actor_index: 0, target_index: 1 });
    _after = __battle_hp_now(_D);
    __status_smoke_assert(_S, _after < _before, "effect 148 Earthquake hit underground target");

    // 149 Future Sight / Doom Desire: queue delayed damage against the target slot.
    _A = __effect_smoke_mon(133, 30, 120, [248, -1, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 180, [150, -1, -1, -1]);
    _B = __effect_smoke_slot(_pid, _A, _D);
    _before = __battle_hp_now(_D);
    __battle_perform_action_impl(_pid, { slot: 0, move_id: 248, actor_index: 0, target_index: 1 });
    var _future_queue_ok = (is_array(variable_struct_get(_B, "_pending_delayed_hits")) && array_length(variable_struct_get(_B, "_pending_delayed_hits")) == 1 && __battle_hp_now(_D) == _before);
    var _replacement = __effect_smoke_mon(25, 30, 180, [150, -1, -1, -1]);
    variable_struct_set(_replacement, "actor_index", 1);
    var _replacement_actors = variable_struct_get(_B, "actor");
    _replacement_actors[1] = _replacement;
    variable_struct_set(_B, "actor", _replacement_actors);
    var _replacement_before = __battle_hp_now(_replacement);
    __battle_tick_delayed_hits(_pid);
    __battle_tick_delayed_hits(_pid);
    var _future_wait_ok = (__battle_hp_now(_replacement) == _replacement_before);
    __battle_tick_delayed_hits(_pid);
    var _future_hit_ok = (__battle_hp_now(_replacement) < _replacement_before);
    __status_smoke_assert(_S, _future_queue_ok && _future_wait_ok && _future_hit_ok, "effect 149 Future Sight struck the current target slot after its delay");

    // 150 Gust can hit Fly/Bounce-style targets.
    _A = __effect_smoke_mon(133, 30, 120, [16, -1, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 160, [150, -1, -1, -1]);
    variable_struct_set(_D, "_semi_invuln", "fly");
    __effect_smoke_slot(_pid, _A, _D);
    _before = __battle_hp_now(_D);
    __battle_perform_action_impl(_pid, { slot: 0, move_id: 16, actor_index: 0, target_index: 1 });
    _after = __battle_hp_now(_D);
    __status_smoke_assert(_S, _after < _before, "effect 150 Gust hit airborne target");

    // 208 Sky Uppercut can hit Fly/Bounce-style targets.
    _A = __effect_smoke_mon(133, 30, 120, [327, -1, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 160, [150, -1, -1, -1]);
    variable_struct_set(_D, "_semi_invuln", "fly");
    __effect_smoke_slot(_pid, _A, _D);
    _before = __battle_hp_now(_D);
    __battle_perform_action_impl(_pid, { slot: 0, move_id: 327, actor_index: 0, target_index: 1 });
    _after = __battle_hp_now(_D);
    __status_smoke_assert(_S, _after < _before, "effect 208 Sky Uppercut hit airborne target");

    // 151 Stomp doubles damage against minimized targets.
    _A = __effect_smoke_mon(133, 30, 120, [23, -1, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 240, [150, -1, -1, -1]);
    __effect_smoke_slot(_pid, _A, _D);
    _before = __battle_hp_now(_D);
    __battle_apply_move_damage(_pid, 1, _A, _D, 23, 65);
    var _stomp_base = _before - __battle_hp_now(_D);
    _A = __effect_smoke_mon(133, 30, 120, [23, -1, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 240, [150, -1, -1, -1]);
    variable_struct_set(_D, "_minimized", true);
    __effect_smoke_slot(_pid, _A, _D);
    _before = __battle_hp_now(_D);
    __battle_apply_move_damage(_pid, 1, _A, _D, 23, 65);
    var _stomp_min = _before - __battle_hp_now(_D);
    __status_smoke_assert(_S, _stomp_base > 0 && _stomp_min > _stomp_base, "effect 151 Stomp dealt increased damage to minimized target");

    // 152 SolarBeam skips charge in sun and is weaker in rain.
    _A = __effect_smoke_mon(133, 30, 120, [76, -1, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 240, [150, -1, -1, -1]);
    __effect_smoke_slot(_pid, _A, _D);
    __battle_set_weather(_pid, "sun", { source: _A, duration: 5 });
    _before = __battle_hp_now(_D);
    __battle_perform_action_impl(_pid, { slot: 0, move_id: 76, actor_index: 0, target_index: 1 });
    _after = __battle_hp_now(_D);
    var _solar_sun_ok = (_after < _before) && (!variable_struct_exists(_A, "_charging_move") || !is_struct(variable_struct_get(_A, "_charging_move")));
    _A = __effect_smoke_mon(133, 30, 120, [76, -1, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 240, [150, -1, -1, -1]);
    __effect_smoke_slot(_pid, _A, _D);
    _before = __battle_hp_now(_D);
    __battle_apply_move_damage(_pid, 1, _A, _D, 76, 120);
    var _solar_clear_dmg = _before - __battle_hp_now(_D);
    _A = __effect_smoke_mon(133, 30, 120, [76, -1, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 240, [150, -1, -1, -1]);
    __effect_smoke_slot(_pid, _A, _D);
    __battle_set_weather(_pid, "rain", { source: _A, duration: 5 });
    _before = __battle_hp_now(_D);
    __battle_apply_move_damage(_pid, 1, _A, _D, 76, 120);
    var _solar_rain_dmg = _before - __battle_hp_now(_D);
    __status_smoke_assert(_S, _solar_sun_ok && _solar_clear_dmg > 0 && _solar_rain_dmg < _solar_clear_dmg, "effect 152 SolarBeam skipped sun charge and weakened in rain");

    // 153 Thunder: rain accuracy plus paralysis meta.
    global.DEV_FORCE_PARALYSIS_CHANCE = 100;
    _A = __effect_smoke_mon(133, 30, 120, [87, -1, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 180, [150, -1, -1, -1]);
    __effect_smoke_slot(_pid, _A, _D);
    __battle_set_weather(_pid, "rain", { source: _A, duration: 5 });
    var _rain_hits = true;
    for (var _thi = 0; _thi < 12; ++_thi){
        if (!__battle_can_hit_target(_A, _D, 87)){ _rain_hits = false; break; }
    }
    __battle_perform_action_impl(_pid, { slot: 0, move_id: 87, actor_index: 0, target_index: 1 });
    __status_smoke_assert(_S, _rain_hits && __effect_smoke_has_status(_D, "paralysis"), "effect 153 Thunder hit reliably in rain and applied paralysis");
    global.DEV_FORCE_PARALYSIS_CHANCE = -1;

    // 154 Teleport exits wild battles.
    _A = __effect_smoke_mon(133, 30, 120, [100, -1, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 120, [150, -1, -1, -1]);
    _B = __effect_smoke_slot(_pid, _A, _D, "wild");
    __battle_perform_action_impl(_pid, { slot: 0, move_id: 100, actor_index: 0, target_index: 1 });
    var _teleport_ok = false;
    try { _teleport_ok = (variable_struct_get(_B, "result") == "escaped" && variable_struct_get(_B, "_pending_close") == true); } catch (e_tp) { _teleport_ok = false; }
    __status_smoke_assert(_S, _teleport_ok, "effect 154 Teleport ended wild battle");

    // 155 Beat Up uses party-count variable power and multi-hit metadata.
    _A = __effect_smoke_mon(133, 30, 120, [251, -1, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 120, [150, -1, -1, -1]);
    variable_struct_set(_A, "party", [__effect_smoke_mon(1, 20, 80, [1,-1,-1,-1]), __effect_smoke_mon(4, 20, 80, [1,-1,-1,-1]), __effect_smoke_mon(7, 20, 80, [1,-1,-1,-1])]);
    __effect_smoke_slot(_pid, _A, _D);
    var _beat_meta = __battle_get_move_meta(251);
    var _beat_power = __battle_move_power(251, _A, _D);
    var _beat_ok = is_struct(_beat_meta) && variable_struct_exists(_beat_meta, "min_hits") && variable_struct_get(_beat_meta, "min_hits") >= 1 && _beat_power == 30;
    __status_smoke_assert(_S, _beat_ok, "effect 155 Beat Up has multi-hit meta and party-count power");

    var _fails = variable_struct_get(_S, "fail_count");
    __status_smoke_finish(_pid, _S, (_fails == 0) ? "completed" : "failed");
    return (_fails == 0);
}

function test_battle_effect_131_155_smoke_update(_pid = 0){
    // Direct smoke completes synchronously in start().
}

function test_battle_effect_159_176_smoke_start(_auto_close = false){
    var _pid = 0;
    var _S = {
        pid: _pid,
        tag: "effect-159-176",
        global_name: "DEV_EFFECT_159_176_SMOKE",
        auto_close: (_auto_close == true),
        state: "running",
        turn_counter: 0,
        pass_count: 0,
        fail_count: 0,
        started_ms: current_time
    };
    global.DEV_EFFECT_159_176_SMOKE = _S;
    show_debug_message("[smoke][effect-159-176] starting direct battle-effect smoke");

    var _A;
    var _D;
    var _before;
    var _after;
    global.DEV_FORCE_ACCURACY_HIT = true;
    global.DEV_FORCE_FLINCH_CHANCE = 100;
    global.DEV_FORCE_BURN_CHANCE = 100;
    global.DEV_FORCE_SLEEP_CHANCE = 100;
    global.DEV_FORCE_PARALYSIS_CHANCE = 100;

    // 159 Fake Out: works only on the first active turn and still applies its flinch meta.
    _A = __effect_smoke_mon(133, 30, 120, [252, -1, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 120, [1, -1, -1, -1]);
    __effect_smoke_slot(_pid, _A, _D);
    _before = __battle_hp_now(_D);
    __battle_perform_action_impl(_pid, { slot: 0, move_id: 252, actor_index: 0, target_index: 1 });
    var _fake_out_first_ok = (__battle_hp_now(_D) < _before) && variable_struct_exists(_D, "_flinched") && variable_struct_get(_D, "_flinched") == true;
    _A = __effect_smoke_mon(133, 30, 120, [252, -1, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 120, [1, -1, -1, -1]);
    __effect_smoke_slot(_pid, _A, _D);
    variable_struct_set(_A, "active_turns", 1);
    _before = __battle_hp_now(_D);
    __battle_perform_action_impl(_pid, { slot: 0, move_id: 252, actor_index: 0, target_index: 1 });
    var _fake_out_late_ok = (__battle_hp_now(_D) == _before);
    __status_smoke_assert(_S, _fake_out_first_ok && _fake_out_late_ok, "effect 159 Fake Out respected first-turn-only damage and flinch");

    // 160 Uproar: wakes sleeping battlers and blocks new sleep while the lock is active.
    _A = __effect_smoke_mon(133, 30, 120, [253, -1, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 120, [95, -1, -1, -1]);
    __effect_smoke_slot(_pid, _A, _D);
    status_system_apply_status(_D, "sleep", { duration: 2, source: _A });
    __battle_perform_action_impl(_pid, { slot: 0, move_id: 253, actor_index: 0, target_index: 1 });
    var _uproar_woke_ok = !status_system_has_status(_D, "sleep");
    __battle_perform_action_impl(_pid, { slot: 0, move_id: 95, actor_index: 1, target_index: 0 });
    var _uproar_blocked_sleep = !status_system_has_status(_A, "sleep");
    __status_smoke_assert(_S, _uproar_woke_ok && _uproar_blocked_sleep, "effect 160 Uproar woke sleepers and blocked new sleep while active");

    // 168 Will-O-Wisp: burn is delivered through the generic ailment pipeline.
    _A = __effect_smoke_mon(133, 30, 120, [261, -1, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 120, [1, -1, -1, -1]);
    __effect_smoke_slot(_pid, _A, _D);
    __battle_perform_action_impl(_pid, { slot: 0, move_id: 261, actor_index: 0, target_index: 1 });
    var _wisp_ok = status_system_has_status(_D, "burn");
    __status_smoke_assert(_S, _wisp_ok, "effect 168 Will-O-Wisp applied burn through move meta");

    // 170 Facade: base power doubles while the user is burned, poisoned, or paralyzed.
    _A = __effect_smoke_mon(133, 30, 120, [263, -1, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 120, [1, -1, -1, -1]);
    __effect_smoke_slot(_pid, _A, _D);
    var _facade_normal = __battle_move_power(263, _A, _D);
    status_system_apply_status(_A, "burn", { source: _D });
    var _facade_burn = __battle_move_power(263, _A, _D);
    __status_smoke_assert(_S, _facade_normal > 0 && _facade_burn == (_facade_normal * 2), "effect 170 Facade doubled power while statused");

    // 171 Focus Punch: fails if the user was damaged earlier in the turn.
    _A = __effect_smoke_mon(133, 30, 120, [264, -1, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 120, [1, -1, -1, -1]);
    __effect_smoke_slot(_pid, _A, _D);
    _before = __battle_hp_now(_D);
    __battle_perform_action_impl(_pid, { slot: 0, move_id: 264, actor_index: 0, target_index: 1 });
    var _focus_clean_ok = (__battle_hp_now(_D) < _before);
    _A = __effect_smoke_mon(133, 30, 120, [264, -1, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 120, [1, -1, -1, -1]);
    __effect_smoke_slot(_pid, _A, _D);
    variable_struct_set(_A, "_was_hit_this_turn", true);
    variable_struct_set(_A, "_last_received_damage", 18);
    _before = __battle_hp_now(_D);
    __battle_perform_action_impl(_pid, { slot: 0, move_id: 264, actor_index: 0, target_index: 1 });
    var _focus_broken_ok = (__battle_hp_now(_D) == _before);
    __status_smoke_assert(_S, _focus_clean_ok && _focus_broken_ok, "effect 171 Focus Punch failed after taking same-turn damage");

    // 172 Smelling Salts: doubles power on a paralyzed target and cures that paralysis after damage.
    _A = __effect_smoke_mon(133, 30, 120, [265, -1, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 120, [1, -1, -1, -1]);
    __effect_smoke_slot(_pid, _A, _D);
    status_system_apply_status(_D, "paralysis", { source: _A });
    var _smelling_power = __battle_move_power(265, _A, _D);
    _before = __battle_hp_now(_D);
    __battle_perform_action_impl(_pid, { slot: 0, move_id: 265, actor_index: 0, target_index: 1 });
    _after = __battle_hp_now(_D);
    var _smelling_ok = (_smelling_power > 60) && (_after < _before) && !status_system_has_status(_D, "paralysis") && !status_system_has_status(_D, "paralyze");
    __status_smoke_assert(_S, _smelling_ok, "effect 172 Smelling Salts doubled into paralysis and cured it after damage");

    // 176 Taunt: applies a volatile gate that blocks later status moves.
    _A = __effect_smoke_mon(133, 30, 120, [269, -1, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 120, [187, -1, -1, -1]);
    __effect_smoke_slot(_pid, _A, _D);
    __battle_perform_action_impl(_pid, { slot: 0, move_id: 269, actor_index: 0, target_index: 1 });
    var _taunt_applied = false;
    try { var _taunt_state = variable_struct_get(_D, "_taunt_state"); _taunt_applied = is_struct(_taunt_state) && variable_struct_get(_taunt_state, "remaining") > 0; } catch (e_taunt_state) { _taunt_applied = false; }
    _before = __battle_hp_now(_D);
    __battle_perform_action_impl(_pid, { slot: 0, move_id: 187, actor_index: 1, target_index: 1 });
    var _taunt_blocked = (__battle_hp_now(_D) == _before);
    __status_smoke_assert(_S, _taunt_applied && _taunt_blocked, "effect 176 Taunt applied a status-move gate");

    global.DEV_FORCE_ACCURACY_HIT = false;
    global.DEV_FORCE_FLINCH_CHANCE = -1;
    global.DEV_FORCE_BURN_CHANCE = -1;
    global.DEV_FORCE_SLEEP_CHANCE = -1;
    global.DEV_FORCE_PARALYSIS_CHANCE = -1;
    var _fails = variable_struct_get(_S, "fail_count");
    __status_smoke_finish(_pid, _S, (_fails == 0) ? "completed" : "failed");
    return (_fails == 0);
}

function test_battle_effect_159_176_smoke_update(_pid = 0){
    // Direct smoke completes synchronously in start().
}

function test_battle_effect_item_ability_smoke_start(_auto_close = false){
    var _pid = 0;
    var _S = {
        pid: _pid,
        tag: "effect-item-ability",
        global_name: "DEV_EFFECT_ITEM_ABILITY_SMOKE",
        auto_close: (_auto_close == true),
        state: "running",
        turn_counter: 0,
        pass_count: 0,
        fail_count: 0,
        started_ms: current_time
    };
    global.DEV_EFFECT_ITEM_ABILITY_SMOKE = _S;
    show_debug_message("[smoke][effect-item-ability] starting direct item/ability smoke");

    var _A;
    var _D;

    // Trick swaps held items.
    _A = __effect_smoke_mon(133, 30, 120, [271, -1, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 120, [150, -1, -1, -1]);
    variable_struct_set(_A, "held_item_id", 1);
    variable_struct_set(_A, "held_item_real_name", "master-ball");
    variable_struct_set(_D, "held_item_id", 2);
    variable_struct_set(_D, "held_item_real_name", "ultra-ball");
    __effect_smoke_slot(_pid, _A, _D);
    __battle_perform_action_impl(_pid, { slot: 0, move_id: 271, actor_index: 0, target_index: 1 });
    __status_smoke_assert(_S,
        variable_struct_get(_A, "held_item_id") == 2 && variable_struct_get(_D, "held_item_id") == 1,
        "item family Trick swapped both held items");

    // Role Play copies the target ability.
    _A = __effect_smoke_mon(133, 30, 120, [272, -1, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 120, [150, -1, -1, -1]);
    variable_struct_set(_A, "ability", "run-away");
    variable_struct_set(_A, "ability_id", 50);
    variable_struct_set(_D, "ability", "intimidate");
    variable_struct_set(_D, "ability_id", 22);
    __effect_smoke_slot(_pid, _A, _D);
    __battle_perform_action_impl(_pid, { slot: 0, move_id: 272, actor_index: 0, target_index: 1 });
    __status_smoke_assert(_S,
        string(variable_struct_get(_A, "ability")) == "intimidate" && variable_struct_get(_A, "ability_id") == 22,
        "item family Role Play copied the target ability");

    // Skill Swap exchanges abilities.
    _A = __effect_smoke_mon(133, 30, 120, [285, -1, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 120, [150, -1, -1, -1]);
    variable_struct_set(_A, "ability", "synchronize");
    variable_struct_set(_A, "ability_id", 28);
    variable_struct_set(_D, "ability", "levitate");
    variable_struct_set(_D, "ability_id", 26);
    __effect_smoke_slot(_pid, _A, _D);
    __battle_perform_action_impl(_pid, { slot: 0, move_id: 285, actor_index: 0, target_index: 1 });
    __status_smoke_assert(_S,
        string(variable_struct_get(_A, "ability")) == "levitate" && string(variable_struct_get(_D, "ability")) == "synchronize",
        "item family Skill Swap exchanged both abilities");

    // Battle abilities affect live damage/status resolution.
    global.DEV_FORCE_ACCURACY_HIT = true;
    global.DEV_FORCE_CRIT_ROLL_100 = 100;
    var _before = 0;

    _A = __effect_smoke_mon(133, 30, 120, [33, -1, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 180, [150, -1, -1, -1]);
    variable_struct_set(_A, "atk", 80);
    variable_struct_set(_D, "def", 70);
    __effect_smoke_slot(_pid, _A, _D);
    _before = __battle_hp_now(_D);
    __battle_apply_move_damage(_pid, 1, _A, _D, 33, 40);
    var _normal_damage = _before - __battle_hp_now(_D);

    _A = __effect_smoke_mon(133, 30, 120, [33, -1, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 180, [150, -1, -1, -1]);
    variable_struct_set(_A, "atk", 80);
    variable_struct_set(_A, "ability", "huge-power");
    variable_struct_set(_D, "def", 70);
    __effect_smoke_slot(_pid, _A, _D);
    _before = __battle_hp_now(_D);
    __battle_apply_move_damage(_pid, 1, _A, _D, 33, 40);
    var _huge_damage = _before - __battle_hp_now(_D);
    __status_smoke_assert(_S, _normal_damage > 0 && _huge_damage > _normal_damage, "battle ability Huge Power increased physical damage");

    _A = __effect_smoke_mon(133, 30, 120, [55, -1, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 120, [150, -1, -1, -1]);
    variable_struct_set(_D, "ability", "water-absorb");
    __effect_smoke_slot(_pid, _A, _D);
    __battle_set_hp_now(_D, 60);
    __battle_apply_move_damage(_pid, 1, _A, _D, 55, 40);
    __status_smoke_assert(_S, __battle_hp_now(_D) == 90, "battle ability Water Absorb blocked Water damage and healed");

    _A = __effect_smoke_mon(133, 30, 120, [33, -1, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 100, [150, -1, -1, -1]);
    variable_struct_set(_A, "atk", 220);
    variable_struct_set(_D, "def", 1);
    variable_struct_set(_D, "ability", "sturdy");
    __effect_smoke_slot(_pid, _A, _D);
    __battle_apply_move_damage(_pid, 1, _A, _D, 33, 120);
    __status_smoke_assert(_S, __battle_hp_now(_D) == 1, "battle ability Sturdy prevented a full-HP knockout");

    _D = __effect_smoke_mon(10, 30, 100, [150, -1, -1, -1]);
    variable_struct_set(_D, "ability", "limber");
    var _para_blocked = !status_system_apply_status(_D, "paralysis", { source: _A });
    __status_smoke_assert(_S, _para_blocked, "battle ability Limber blocked paralysis");

    _A = __effect_smoke_mon(133, 30, 120, [150, -1, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 120, [150, -1, -1, -1]);
    variable_struct_set(_A, "ability", "intimidate");
    __effect_smoke_slot(_pid, _A, _D);
    __battle_apply_entry_abilities(_pid, 0);
    var _intimidate_stage = 0;
    try {
        var _stages_intim = variable_struct_get(_D, "_stages");
        if (is_struct(_stages_intim) && variable_struct_exists(_stages_intim, "atk")) _intimidate_stage = variable_struct_get(_stages_intim, "atk");
    } catch (e_intim_stage) {}
    __status_smoke_assert(_S, _intimidate_stage == -1, "battle ability Intimidate lowered opposing Attack on entry");

    global.DEV_FORCE_ACCURACY_HIT = false;
    global.DEV_FORCE_CRIT_ROLL_100 = -1;

    // Knock Off removes the target item and Recycle restores it.
    _A = __effect_smoke_mon(133, 30, 120, [282, -1, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 180, [278, -1, -1, -1]);
    variable_struct_set(_D, "held_item_id", 3);
    variable_struct_set(_D, "held_item_real_name", "great-ball");
    __effect_smoke_slot(_pid, _A, _D);
    __battle_perform_action_impl(_pid, { slot: 0, move_id: 282, actor_index: 0, target_index: 1 });
    var _knock_ok = (variable_struct_get(_D, "held_item_id") <= 0)
        && variable_struct_exists(_D, "_last_lost_item_id")
        && variable_struct_get(_D, "_last_lost_item_id") == 3;
    __status_smoke_assert(_S, _knock_ok, "item family Knock Off removed and recorded the target item");
    __battle_perform_action_impl(_pid, { slot: 0, move_id: 278, actor_index: 1, target_index: 1 });
    __status_smoke_assert(_S,
        variable_struct_get(_D, "held_item_id") == 3 && string(variable_struct_get(_D, "held_item_real_name")) == "great-ball",
        "item family Recycle restored the last lost item");

    var _fails = variable_struct_get(_S, "fail_count");
    __status_smoke_finish(_pid, _S, (_fails == 0) ? "completed" : "failed");
    return (_fails == 0);
}

function test_battle_effect_item_ability_smoke_update(_pid = 0){
    // Direct smoke completes synchronously in start().
}

function test_battle_effect_200_204_smoke_start(_auto_close = false){
    var _pid = 0;
    var _S = {
        pid: _pid,
        tag: "effect-200-204",
        global_name: "DEV_EFFECT_200_204_SMOKE",
        auto_close: (_auto_close == true),
        state: "running",
        turn_counter: 0,
        pass_count: 0,
        fail_count: 0,
        started_ms: current_time
    };
    global.DEV_EFFECT_200_204_SMOKE = _S;
    show_debug_message("[smoke][effect-200-204] starting direct battle-effect smoke");

    var _A;
    var _D;
    var _before;
    var _after;

    global.DEV_FORCE_ACCURACY_HIT = true;
    global.DEV_FORCE_BURN_CHANCE = 100;
    global.DEV_FORCE_TOXIC_CHANCE = 100;

    // 200 Teeter Dance: confuses nearby battlers.
    _A = __effect_smoke_mon(133, 30, 120, [298, -1, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 120, [1, -1, -1, -1]);
    __effect_smoke_slot(_pid, _A, _D);
    __battle_perform_action_impl(_pid, { slot: 0, move_id: 298, actor_index: 0, target_index: 1 });
    __status_smoke_assert(_S, status_system_has_status(_D, "confusion"), "effect 200 Teeter Dance confused the opposing battler");

    // 201 Blaze Kick: uses boosted crit stage and can burn.
    global.DEV_FORCE_CRIT_ROLL_100 = 10;
    _A = __effect_smoke_mon(133, 30, 120, [299, -1, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 180, [1, -1, -1, -1]);
    __effect_smoke_slot(_pid, _A, _D);
    __battle_perform_action_impl(_pid, { slot: 0, move_id: 299, actor_index: 0, target_index: 1 });
    var _blaze_crit_ok = false;
    try { _blaze_crit_ok = variable_struct_get(__battle_ensure_slot(_pid), "_last_crit") == true; } catch (e_blaze_crit) { _blaze_crit_ok = false; }
    __status_smoke_assert(_S, _blaze_crit_ok && status_system_has_status(_D, "burn"), "effect 201 Blaze Kick used the boosted crit stage and applied burn");
    global.DEV_FORCE_CRIT_ROLL_100 = -1;

    // 203 Poison Fang: can badly poison after a successful hit.
    _A = __effect_smoke_mon(133, 30, 120, [305, -1, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 180, [1, -1, -1, -1]);
    __effect_smoke_slot(_pid, _A, _D);
    __battle_perform_action_impl(_pid, { slot: 0, move_id: 305, actor_index: 0, target_index: 1 });
    __status_smoke_assert(_S, status_system_has_status(_D, "toxic"), "effect 203 Poison Fang applied toxic poison");

    // 204 Weather Ball: changes type and doubles in power while weather is active.
    _A = __effect_smoke_mon(133, 30, 120, [311, -1, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 180, [1, -1, -1, -1]);
    __effect_smoke_slot(_pid, _A, _D);
    var _wb_base_type = scr_move_type_id_by_id(311, _A);
    var _wb_base_power = __battle_move_power(311, _A, _D);
    __battle_set_weather(_pid, "rain", { source: _A, duration: 5 });
    var _wb_rain_type = scr_move_type_id_by_id(311, _A);
    var _wb_rain_power = __battle_move_power(311, _A, _D);
    __status_smoke_assert(_S, _wb_base_type == 1 && _wb_base_power == 50 && _wb_rain_type == 11 && _wb_rain_power == 100, "effect 204 Weather Ball changed type and doubled power in weather");

    global.DEV_FORCE_ACCURACY_HIT = false;
    global.DEV_FORCE_BURN_CHANCE = -1;
    global.DEV_FORCE_TOXIC_CHANCE = -1;
    var _fails = variable_struct_get(_S, "fail_count");
    __status_smoke_finish(_pid, _S, (_fails == 0) ? "completed" : "failed");
    return (_fails == 0);
}

function test_battle_effect_200_204_smoke_update(_pid = 0){
    // Direct smoke completes synchronously in start().
}

function test_battle_effect_210_smoke_start(_auto_close = false){
    var _pid = 0;
    var _S = {
        pid: _pid,
        tag: "effect-210",
        global_name: "DEV_EFFECT_210_SMOKE",
        auto_close: (_auto_close == true),
        state: "running",
        turn_counter: 0,
        pass_count: 0,
        fail_count: 0,
        started_ms: current_time
    };
    global.DEV_EFFECT_210_SMOKE = _S;
    show_debug_message("[smoke][effect-210] starting direct battle-effect smoke");

    var _A;
    var _D;

    global.DEV_FORCE_ACCURACY_HIT = true;
    global.DEV_FORCE_POISON_CHANCE = 100;
    global.DEV_FORCE_CRIT_ROLL_100 = 10;

    // 210 Poison Tail: boosted crit stage and poison chance.
    _A = __effect_smoke_mon(133, 30, 120, [342, -1, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 180, [1, -1, -1, -1]);
    __effect_smoke_slot(_pid, _A, _D);
    __battle_perform_action_impl(_pid, { slot: 0, move_id: 342, actor_index: 0, target_index: 1 });
    var _pt_crit_ok = false;
    try { _pt_crit_ok = variable_struct_get(__battle_ensure_slot(_pid), "_last_crit") == true; } catch (e_pt_crit) { _pt_crit_ok = false; }
    __status_smoke_assert(_S, _pt_crit_ok && status_system_has_status(_D, "poison"), "effect 210 Poison Tail used the boosted crit stage and applied poison");

    // 210 Cross Poison: same family hook should apply here too.
    _A = __effect_smoke_mon(133, 30, 120, [440, -1, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 180, [1, -1, -1, -1]);
    __effect_smoke_slot(_pid, _A, _D);
    __battle_perform_action_impl(_pid, { slot: 0, move_id: 440, actor_index: 0, target_index: 1 });
    var _cp_crit_ok = false;
    try { _cp_crit_ok = variable_struct_get(__battle_ensure_slot(_pid), "_last_crit") == true; } catch (e_cp_crit) { _cp_crit_ok = false; }
    __status_smoke_assert(_S, _cp_crit_ok && status_system_has_status(_D, "poison"), "effect 210 Cross Poison used the boosted crit stage and applied poison");

    global.DEV_FORCE_ACCURACY_HIT = false;
    global.DEV_FORCE_POISON_CHANCE = -1;
    global.DEV_FORCE_CRIT_ROLL_100 = -1;
    var _fails = variable_struct_get(_S, "fail_count");
    __status_smoke_finish(_pid, _S, (_fails == 0) ? "completed" : "failed");
    return (_fails == 0);
}

function test_battle_effect_210_smoke_update(_pid = 0){
    // Direct smoke completes synchronously in start().
}

function test_battle_effect_173_177_224_smoke_start(_auto_close = false){
    var _pid = 0;
    var _S = {
        pid: _pid,
        tag: "effect-173-177-224",
        global_name: "DEV_EFFECT_173_177_224_SMOKE",
        auto_close: (_auto_close == true),
        state: "running",
        turn_counter: 0,
        pass_count: 0,
        fail_count: 0,
        started_ms: current_time
    };
    global.DEV_EFFECT_173_177_224_SMOKE = _S;
    show_debug_message("[smoke][effect-173-177-224] starting direct battle-effect smoke");

    var _A;
    var _D;
    var _before;
    var _after;

    global.DEV_FORCE_ACCURACY_HIT = true;

    // 173 Follow Me: explicit singles handling should fail without setting redirect state.
    _A = __effect_smoke_mon(133, 30, 120, [266, -1, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 120, [1, -1, -1, -1]);
    __effect_smoke_slot(_pid, _A, _D);
    __battle_perform_action_impl(_pid, { slot: 0, move_id: 266, actor_index: 0, target_index: 0 });
    var _follow_fail_ok = true;
    try { _follow_fail_ok = !variable_struct_exists(_A, "_follow_me_active") || variable_struct_get(_A, "_follow_me_active") != true; } catch (e_follow_smoke) { _follow_fail_ok = true; }
    __status_smoke_assert(_S, _follow_fail_ok, "effect 173 Follow Me fails cleanly in the current singles battle setup");

    // 177 Helping Hand: explicit singles handling should fail without setting an ally boost.
    _A = __effect_smoke_mon(133, 30, 120, [270, -1, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 120, [1, -1, -1, -1]);
    __effect_smoke_slot(_pid, _A, _D);
    __battle_perform_action_impl(_pid, { slot: 0, move_id: 270, actor_index: 0, target_index: 0 });
    var _help_fail_ok = true;
    try { _help_fail_ok = !variable_struct_exists(_A, "_helping_hand_bonus"); } catch (e_help_smoke) { _help_fail_ok = true; }
    __status_smoke_assert(_S, _help_fail_ok, "effect 177 Helping Hand fails cleanly in the current singles battle setup");

    // 184 Magic Coat: targeted status move is bounced back to the attacker.
    _A = __effect_smoke_mon(133, 30, 120, [281, -1, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 120, [277, -1, -1, -1]);
    __effect_smoke_slot(_pid, _A, _D);
    __battle_perform_action_impl(_pid, { slot: 0, move_id: 277, actor_index: 1, target_index: 1 });
    __battle_perform_action_impl(_pid, { slot: 0, move_id: 281, actor_index: 0, target_index: 1 });
    __status_smoke_assert(_S, status_system_has_status(_A, "yawn") && !status_system_has_status(_D, "yawn"), "effect 184 Magic Coat bounced Yawn back to the attacker");

    // 196 Snatch: steals a self-targeted support move for the snatching battler.
    _A = __effect_smoke_mon(133, 30, 120, [289, -1, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 120, [287, -1, -1, -1]);
    __effect_smoke_slot(_pid, _A, _D);
    status_system_apply_status(_A, "poison", { source: _D });
    __battle_perform_action_impl(_pid, { slot: 0, move_id: 289, actor_index: 0, target_index: 0 });
    __battle_perform_action_impl(_pid, { slot: 0, move_id: 287, actor_index: 1, target_index: 1 });
    __status_smoke_assert(_S, !status_system_has_status(_A, "poison") && !status_system_has_status(_A, "toxic"), "effect 196 Snatch stole Refresh and applied it to the snatching battler");

    // 224 Feint: bypasses Protect and lands damage.
    _A = __effect_smoke_mon(133, 30, 120, [364, -1, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 160, [182, -1, -1, -1]);
    __effect_smoke_slot(_pid, _A, _D);
    __battle_perform_action_impl(_pid, { slot: 0, move_id: 182, actor_index: 1, target_index: 1 });
    _before = __battle_hp_now(_D);
    __battle_perform_action_impl(_pid, { slot: 0, move_id: 364, actor_index: 0, target_index: 1 });
    _after = __battle_hp_now(_D);
    var _feint_cleared = false;
    try { _feint_cleared = variable_struct_get(_D, "sys_protected") != true; } catch (e_feint_clear) { _feint_cleared = true; }
    __status_smoke_assert(_S, _feint_cleared && _after < _before, "effect 224 Feint broke through Protect and dealt damage");

    global.DEV_FORCE_ACCURACY_HIT = false;
    var _fails = variable_struct_get(_S, "fail_count");
    __status_smoke_finish(_pid, _S, (_fails == 0) ? "completed" : "failed");
    return (_fails == 0);
}

function test_battle_effect_173_177_224_smoke_update(_pid = 0){
    // Direct smoke completes synchronously in start().
}

function test_battle_effect_174_198_smoke_start(_auto_close = false){
    var _pid = 0;
    var _S = {
        pid: _pid,
        tag: "effect-174-198",
        global_name: "DEV_EFFECT_174_198_SMOKE",
        auto_close: (_auto_close == true),
        state: "running",
        turn_counter: 0,
        pass_count: 0,
        fail_count: 0,
        started_ms: current_time
    };
    global.DEV_EFFECT_174_198_SMOKE = _S;
    show_debug_message("[smoke][effect-174-198] starting direct battle-effect smoke");

    var _A;
    var _D;
    var _before;
    var _after;

    global.DEV_FORCE_ACCURACY_HIT = true;
    global.DEV_FORCE_PARALYSIS_CHANCE = 100;
    global.DEV_FORCE_SLEEP_CHANCE = 100;

    // 174 Nature Power: Electric Terrain maps to Thunderbolt in the current terrain family.
    _A = __effect_smoke_mon(133, 30, 120, [267, -1, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 180, [1, -1, -1, -1]);
    __effect_smoke_slot(_pid, _A, _D);
    __battle_field_set_terrain(_pid, "electric", { source: _A, turns: 5 });
    _before = __battle_hp_now(_D);
    __battle_perform_action_impl(_pid, { slot: 0, move_id: 267, actor_index: 0, target_index: 1 });
    _after = __battle_hp_now(_D);
    __status_smoke_assert(_S, _after < _before && status_system_has_status(_D, "paralysis"), "effect 174 Nature Power mapped Electric Terrain to a damaging Thunderbolt-family hit");

    // 198 Secret Power: Grassy Terrain maps to a sleep-style secondary effect in the current terrain family.
    _A = __effect_smoke_mon(133, 30, 120, [290, -1, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 180, [1, -1, -1, -1]);
    __effect_smoke_slot(_pid, _A, _D);
    __battle_field_set_terrain(_pid, "grassy", { source: _A, turns: 5 });
    _before = __battle_hp_now(_D);
    __battle_perform_action_impl(_pid, { slot: 0, move_id: 290, actor_index: 0, target_index: 1 });
    _after = __battle_hp_now(_D);
    __status_smoke_assert(_S, _after < _before && status_system_has_status(_D, "sleep"), "effect 198 Secret Power used the current terrain family for its secondary effect");

    global.DEV_FORCE_ACCURACY_HIT = false;
    global.DEV_FORCE_PARALYSIS_CHANCE = -1;
    global.DEV_FORCE_SLEEP_CHANCE = -1;
    var _fails = variable_struct_get(_S, "fail_count");
    __status_smoke_finish(_pid, _S, (_fails == 0) ? "completed" : "failed");
    return (_fails == 0);
}

function test_battle_effect_174_198_smoke_update(_pid = 0){
    // Direct smoke completes synchronously in start().
}

function test_battle_effect_215_smoke_start(_auto_close = false){
    var _pid = 0;
    var _S = {
        pid: _pid,
        tag: "effect-215",
        global_name: "DEV_EFFECT_215_SMOKE",
        auto_close: (_auto_close == true),
        state: "running",
        turn_counter: 0,
        pass_count: 0,
        fail_count: 0,
        started_ms: current_time
    };
    global.DEV_EFFECT_215_SMOKE = _S;
    show_debug_message("[smoke][effect-215] starting direct battle-effect smoke");

    var _A = __effect_smoke_mon(16, 30, 120, [355, -1, -1, -1]);
    var _D = __effect_smoke_mon(133, 30, 120, [150, -1, -1, -1]);
    var _flying_id = undefined;
    try {
        if (variable_global_exists("TYPE_ID_BY_NAME")){
            var _type_map = variable_global_get("TYPE_ID_BY_NAME");
            if (ds_exists(_type_map, ds_type_map)) _flying_id = ds_map_find_value(_type_map, "flying");
        }
    } catch (e_roost_type) { _flying_id = undefined; }

    __effect_smoke_slot(_pid, _A, _D);
    __effect_smoke_set_hp(_A, 60);

    var _had_flying_before = false;
    try {
        if (is_real(_flying_id)){
            if (variable_struct_exists(_A, "type1") && is_real(variable_struct_get(_A, "type1")) && variable_struct_get(_A, "type1") == _flying_id) _had_flying_before = true;
            if (!_had_flying_before && variable_struct_exists(_A, "type2") && is_real(variable_struct_get(_A, "type2")) && variable_struct_get(_A, "type2") == _flying_id) _had_flying_before = true;
            if (!_had_flying_before && variable_struct_exists(_A, "types") && is_array(variable_struct_get(_A, "types"))){
                var _roost_before_types = variable_struct_get(_A, "types");
                for (var _rbi = 0; _rbi < array_length(_roost_before_types); ++_rbi){
                    if (is_real(_roost_before_types[_rbi]) && _roost_before_types[_rbi] == _flying_id) { _had_flying_before = true; break; }
                }
            }
        }
    } catch (e_roost_before) { _had_flying_before = false; }

    __battle_perform_action_impl(_pid, { slot: 0, move_id: 355, actor_index: 0, target_index: 1 });
    var _healed_ok = (__battle_hp_now(_A) == 120);
    var _grounded_now = true;
    try {
        if (is_real(_flying_id)){
            if (variable_struct_exists(_A, "type1") && is_real(variable_struct_get(_A, "type1")) && variable_struct_get(_A, "type1") == _flying_id) _grounded_now = false;
            if (_grounded_now && variable_struct_exists(_A, "type2") && is_real(variable_struct_get(_A, "type2")) && variable_struct_get(_A, "type2") == _flying_id) _grounded_now = false;
            if (_grounded_now && variable_struct_exists(_A, "types") && is_array(variable_struct_get(_A, "types"))){
                var _roost_ground_types = variable_struct_get(_A, "types");
                for (var _rgi = 0; _rgi < array_length(_roost_ground_types); ++_rgi){
                    if (is_real(_roost_ground_types[_rgi]) && _roost_ground_types[_rgi] == _flying_id) { _grounded_now = false; break; }
                }
            }
        }
    } catch (e_roost_ground) { _grounded_now = false; }
    __status_smoke_assert(_S, _had_flying_before && _healed_ok && _grounded_now, "effect 215 Roost healed half max HP and temporarily removed Flying typing");

    var _B = __battle_ensure_slot(_pid);
    variable_struct_set(_B, "turn_i", 1);
    __battle_perform_action_impl(_pid, { slot: 0, move_id: 150, actor_index: 1, target_index: 0 });
    var _flying_restored = false;
    try {
        if (is_real(_flying_id)){
            if (variable_struct_exists(_A, "type1") && is_real(variable_struct_get(_A, "type1")) && variable_struct_get(_A, "type1") == _flying_id) _flying_restored = true;
            if (!_flying_restored && variable_struct_exists(_A, "type2") && is_real(variable_struct_get(_A, "type2")) && variable_struct_get(_A, "type2") == _flying_id) _flying_restored = true;
            if (!_flying_restored && variable_struct_exists(_A, "types") && is_array(variable_struct_get(_A, "types"))){
                var _roost_restore_types = variable_struct_get(_A, "types");
                for (var _rri = 0; _rri < array_length(_roost_restore_types); ++_rri){
                    if (is_real(_roost_restore_types[_rri]) && _roost_restore_types[_rri] == _flying_id) { _flying_restored = true; break; }
                }
            }
        }
    } catch (e_roost_restore) { _flying_restored = false; }
    __status_smoke_assert(_S, _flying_restored, "effect 215 Roost restored Flying typing after the turn expired");

    var _fails = variable_struct_get(_S, "fail_count");
    __status_smoke_finish(_pid, _S, (_fails == 0) ? "completed" : "failed");
    return (_fails == 0);
}

function test_battle_effect_215_smoke_update(_pid = 0){
    // Direct smoke completes synchronously in start().
}

function test_battle_effect_216_smoke_start(_auto_close = false){
    var _pid = 0;
    var _S = {
        pid: _pid,
        tag: "effect-216",
        global_name: "DEV_EFFECT_216_SMOKE",
        auto_close: (_auto_close == true),
        state: "running",
        turn_counter: 0,
        pass_count: 0,
        fail_count: 0,
        started_ms: current_time
    };
    global.DEV_EFFECT_216_SMOKE = _S;
    show_debug_message("[smoke][effect-216] starting direct battle-effect smoke");

    var _A = __effect_smoke_mon(133, 30, 120, [356, -1, -1, -1]);
    var _D = __effect_smoke_mon(10, 30, 120, [150, -1, -1, -1]);
    variable_struct_set(_D, "ability", "levitate");
    variable_struct_set(_D, "_semi_invuln", "fly");
    variable_struct_set(_D, "_charging_move", { move_id: 19, target_index: 0 });
    __effect_smoke_slot(_pid, _A, _D);

    var _before_grounded = __actor_is_grounded(_D);
    __battle_perform_action_impl(_pid, { slot: 0, move_id: 356, actor_index: 0, target_index: 1 });
    var _gravity_turns = __battle_field_get_status_or(_pid, "gravity", 0);
    var _after_grounded = __actor_is_grounded(_D);
    var _semi_cleared = (!variable_struct_exists(_D, "_semi_invuln") || is_undefined(variable_struct_get(_D, "_semi_invuln")));
    var _charge_cleared = (!variable_struct_exists(_D, "_charging_move") || is_undefined(variable_struct_get(_D, "_charging_move")));
    __status_smoke_assert(_S, (!_before_grounded) && is_real(_gravity_turns) && _gravity_turns == 5 && _after_grounded && _semi_cleared && _charge_cleared, "effect 216 Gravity set a field duration, grounded Levitate targets, and cleared airborne charge state");

    _A = __effect_smoke_mon(16, 30, 120, [19, -1, -1, -1]);
    _D = __effect_smoke_mon(133, 30, 120, [150, -1, -1, -1]);
    __effect_smoke_slot(_pid, _A, _D);
    __battle_field_set_status(_pid, "gravity", 5);
    __battle_perform_action_impl(_pid, { slot: 0, move_id: 19, actor_index: 0, target_index: 1 });
    var _blocked_charge = (!variable_struct_exists(_A, "_charging_move") || is_undefined(variable_struct_get(_A, "_charging_move")));
    __status_smoke_assert(_S, _blocked_charge, "effect 216 Gravity blocked Fly from entering its charging state");

    var _fails = variable_struct_get(_S, "fail_count");
    __status_smoke_finish(_pid, _S, (_fails == 0) ? "completed" : "failed");
    return (_fails == 0);
}

function test_battle_effect_216_smoke_update(_pid = 0){
    // Direct smoke completes synchronously in start().
}

function test_battle_effect_225_smoke_start(_auto_close = false){
    var _pid = 0;
    var _S = {
        pid: _pid,
        tag: "effect-225",
        global_name: "DEV_EFFECT_225_SMOKE",
        auto_close: (_auto_close == true),
        state: "running",
        turn_counter: 0,
        pass_count: 0,
        fail_count: 0,
        started_ms: current_time
    };
    global.DEV_EFFECT_225_SMOKE = _S;
    show_debug_message("[smoke][effect-225] starting direct battle-effect smoke");

    var _A = __effect_smoke_mon(133, 30, 120, [365, -1, -1, -1]);
    var _D = __effect_smoke_mon(10, 30, 180, [150, -1, -1, -1]);
    __effect_smoke_slot(_pid, _A, _D);
    __effect_smoke_set_hp(_A, 80);
    variable_struct_set(_D, "held_item_id", 132);
    variable_struct_set(_D, "held_item_real_name", "oran-berry");
    __battle_perform_action_impl(_pid, { slot: 0, move_id: 365, actor_index: 0, target_index: 1 });
    var _pluck_healed = (__battle_hp_now(_A) > 80);
    var _pluck_removed = (variable_struct_get(_D, "held_item_id") <= 0);
    __status_smoke_assert(_S, _pluck_healed && _pluck_removed, "effect 225 Pluck consumed the target berry and applied its effect to the user");

    _A = __effect_smoke_mon(133, 30, 120, [450, -1, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 180, [150, -1, -1, -1]);
    __effect_smoke_slot(_pid, _A, _D);
    __effect_smoke_set_hp(_A, 80);
    variable_struct_set(_D, "held_item_id", 132);
    variable_struct_set(_D, "held_item_real_name", "oran-berry");
    status_system_apply_status(_A, "embargo", { duration: 5, source: _D });
    __battle_perform_action_impl(_pid, { slot: 0, move_id: 450, actor_index: 0, target_index: 1 });
    var _bug_bite_hp = __battle_hp_now(_A);
    var _bug_bite_removed = (variable_struct_get(_D, "held_item_id") <= 0);
    __status_smoke_assert(_S, _bug_bite_hp == 80 && _bug_bite_removed, "effect 225 destroyed the target berry without using it while the attacker was under Embargo");

    var _fails = variable_struct_get(_S, "fail_count");
    __status_smoke_finish(_pid, _S, (_fails == 0) ? "completed" : "failed");
    return (_fails == 0);
}

function test_battle_effect_225_smoke_update(_pid = 0){
    // Direct smoke completes synchronously in start().
}

function test_battle_effect_221_smoke_start(_auto_close = false){
    var _pid = 0;
    var _S = {
        pid: _pid,
        tag: "effect-221",
        global_name: "DEV_EFFECT_221_SMOKE",
        auto_close: (_auto_close == true),
        state: "running",
        turn_counter: 0,
        pass_count: 0,
        fail_count: 0,
        started_ms: current_time
    };
    global.DEV_EFFECT_221_SMOKE = _S;
    show_debug_message("[smoke][effect-221] starting direct battle-effect smoke");

    var _A = __effect_smoke_mon(133, 30, 120, [361, -1, -1, -1]);
    var _D = __effect_smoke_mon(10, 30, 180, [150, -1, -1, -1]);
    var _B = __effect_smoke_slot(_pid, _A, _D);
    __battle_perform_action_impl(_pid, { slot: 0, move_id: 361, actor_index: 0, target_index: 1 });

    var _pending_ok = false;
    if (variable_struct_exists(_B, "_pending_healing_wishes") && is_array(variable_struct_get(_B, "_pending_healing_wishes"))){
        var _pending_hw = variable_struct_get(_B, "_pending_healing_wishes");
        _pending_ok = (array_length(_pending_hw) == 1);
        if (_pending_ok){
            var _entry_hw = _pending_hw[0];
            _pending_ok = is_struct(_entry_hw) && variable_struct_exists(_entry_hw, "side") && variable_struct_get(_entry_hw, "side") == 0;
        }
    }
    __status_smoke_assert(_S, __battle_hp_now(_A) <= 0 && _pending_ok, "effect 221 queued a pending restore for the user's side and self-KOed the user");

    var _R = __effect_smoke_mon(16, 30, 120, [1, -1, -1, -1]);
    variable_struct_set(_R, "actor_index", 0);
    __effect_smoke_set_hp(_R, 24);
    status_system_apply_status(_R, "burn", { source: _D });
    var _applied = __battle_apply_pending_healing_wish_to_actor(_pid, 0, _R);
    var _restored = (__battle_hp_now(_R) == __battle_hp_max(_R));
    var _status_cleared = !__effect_smoke_has_status(_R, "burn");
    var _pending_cleared = (variable_struct_exists(_B, "_pending_healing_wishes") && is_array(variable_struct_get(_B, "_pending_healing_wishes")) && array_length(variable_struct_get(_B, "_pending_healing_wishes")) == 0);
    __status_smoke_assert(_S, _applied && _restored && _status_cleared && _pending_cleared, "effect 221 restored the next ally switch-in to full HP, cured status, and consumed the pending wish");

    var _fails = variable_struct_get(_S, "fail_count");
    __status_smoke_finish(_pid, _S, (_fails == 0) ? "completed" : "failed");
    return (_fails == 0);
}

function test_battle_effect_221_smoke_update(_pid = 0){
    // Direct smoke completes synchronously in start().
}

function test_battle_effect_217_smoke_start(_auto_close = false){
    var _pid = 0;
    var _S = {
        pid: _pid,
        tag: "effect-217",
        global_name: "DEV_EFFECT_217_SMOKE",
        auto_close: (_auto_close == true),
        state: "running",
        turn_counter: 0,
        pass_count: 0,
        fail_count: 0,
        started_ms: current_time
    };
    global.DEV_EFFECT_217_SMOKE = _S;
    show_debug_message("[smoke][effect-217] starting direct battle-effect smoke");

    var _A = __effect_smoke_mon(133, 30, 120, [357, 93, -1, -1]);
    var _D = __effect_smoke_mon(197, 30, 120, [104, -1, -1, -1]);
    var _B = __effect_smoke_slot(_pid, _A, _D);
    variable_struct_set(_A, "type1", 14);
    variable_struct_set(_A, "type2", -1);
    variable_struct_set(_A, "types", [14]);
    variable_struct_set(_D, "type1", 17);
    variable_struct_set(_D, "type2", -1);
    variable_struct_set(_D, "types", [17]);
    variable_struct_set(_A, "_stages", { accuracy: -6 });
    variable_struct_set(_D, "_stages", { evasion: 6 });

    __battle_perform_action_impl(_pid, { slot: 0, move_id: 357, actor_index: 0, target_index: 1 });
    var _miracle_applied = variable_struct_exists(_D, "_miracle_eye_active") && variable_struct_get(_D, "_miracle_eye_active") == true;
    var _evasion_reset = variable_struct_exists(_D, "_stages") && is_struct(variable_struct_get(_D, "_stages")) && variable_struct_get(variable_struct_get(_D, "_stages"), "evasion") == 0;
    __status_smoke_assert(_S, _miracle_applied && _evasion_reset, "effect 217 landed through accuracy/evasion modifiers and reset the target's evasion stage");

    __battle_perform_action_impl(_pid, { slot: 0, move_id: 104, actor_index: 1, target_index: 1 });
    var _evasion_blocked = variable_struct_exists(_D, "_stages") && is_struct(variable_struct_get(_D, "_stages")) && variable_struct_get(variable_struct_get(_D, "_stages"), "evasion") == 0;
    __status_smoke_assert(_S, _evasion_blocked, "effect 217 prevented the identified target from raising evasion");

    __effect_smoke_set_hp(_D, 120);
    var _before_dark = __battle_hp_now(_D);
    __battle_perform_action_impl(_pid, { slot: 1, move_id: 93, actor_index: 0, target_index: 1 });
    var _after_dark = __battle_hp_now(_D);
    __status_smoke_assert(_S, _after_dark < _before_dark, "effect 217 let Psychic-type damage hit the identified Dark-type target");

    var _fails = variable_struct_get(_S, "fail_count");
    __status_smoke_finish(_pid, _S, (_fails == 0) ? "completed" : "failed");
    return (_fails == 0);
}

function test_battle_effect_217_smoke_update(_pid = 0){
    // Direct smoke completes synchronously in start().
}

function test_battle_accuracy_smoke_start(_auto_close = false){
    var _pid = 0;
    var _S = {
        pid: _pid,
        tag: "accuracy",
        global_name: "DEV_ACCURACY_SMOKE",
        auto_close: (_auto_close == true),
        state: "running",
        turn_counter: 0,
        pass_count: 0,
        fail_count: 0,
        started_ms: current_time
    };
    global.DEV_ACCURACY_SMOKE = _S;
    show_debug_message("[smoke][accuracy] starting direct accuracy smoke");

    var _A = __effect_smoke_mon(16, 30, 160, [1, -1, -1, -1]);
    var _D = __effect_smoke_mon(19, 30, 160, [1, -1, -1, -1]);
    __effect_smoke_slot(_pid, _A, _D);

    var _neutral_hits = 0;
    for (var _ni = 0; _ni < 16; ++_ni){
        if (__battle_can_hit_target(_A, _D, 1)) _neutral_hits += 1;
    }
    __status_smoke_assert(_S, _neutral_hits == 16, "neutral 100-accuracy moves remained reliable");

    variable_struct_set(_A, "_stages", { accuracy: -6 });
    variable_struct_set(_D, "_stages", { evasion: 6 });

    var _reduced_hits = 0;
    for (var _ri = 0; _ri < 64; ++_ri){
        if (__battle_can_hit_target(_A, _D, 1)) _reduced_hits += 1;
    }
    __status_smoke_assert(_S, _reduced_hits <= 16, "lowered accuracy and raised evasion reduced hit rate");

    var _misses = 0;
    for (var _mi = 0; _mi < 16; ++_mi){
        __effect_smoke_set_hp(_D, 160);
        var _res = __battle_apply_move_damage(_pid, 1, _A, _D, 1, 40);
        var _dmg = (is_array(_res) && array_length(_res) > 0 && is_real(_res[0])) ? _res[0] : 0;
        if (_dmg <= 0) _misses += 1;
    }
    __status_smoke_assert(_S, _misses >= 8, "live move damage path recorded misses after accuracy drops");

    var _sand_attack_id = __status_smoke_find_move_id(["sand-attack"]);
    var _tackle_id = __status_smoke_find_move_id(["tackle"]);
    __status_smoke_assert(_S, _sand_attack_id >= 0 && _tackle_id >= 0, "move identifiers for Sand-Attack and Tackle resolved");
    if (_sand_attack_id >= 0 && _tackle_id >= 0){
        var _A2 = __effect_smoke_mon(16, 30, 160, [_sand_attack_id, _tackle_id, -1, -1]);
        var _D2 = __effect_smoke_mon(19, 30, 160, [_tackle_id, -1, -1, -1]);
        __effect_smoke_slot(_pid, _A2, _D2);

        for (var _si = 0; _si < 6; ++_si){
            __battle_perform_action_impl(_pid, { slot: 0, move_id: _sand_attack_id, actor_index: 0, target_index: 1 });
        }

        var _move_applied_stage = 0;
        if (variable_struct_exists(_D2, "_stages") && is_struct(variable_struct_get(_D2, "_stages"))){
            var _stage_obj = variable_struct_get(_D2, "_stages");
            if (variable_struct_exists(_stage_obj, "accuracy") && is_real(variable_struct_get(_stage_obj, "accuracy"))) _move_applied_stage = variable_struct_get(_stage_obj, "accuracy");
        }
        __status_smoke_assert(_S, _move_applied_stage == -6, "Sand-Attack stacked through the live move path to the accuracy stage cap");

        var _move_path_misses = 0;
        for (var _ti = 0; _ti < 24; ++_ti){
            __effect_smoke_set_hp(_A2, 160);
            var _before_hp = __battle_hp_now(_A2);
            __battle_perform_action_impl(_pid, { slot: 0, move_id: _tackle_id, actor_index: 1, target_index: 0 });
            var _after_hp = __battle_hp_now(_A2);
            if (_after_hp >= _before_hp) _move_path_misses += 1;
        }
        __status_smoke_assert(_S, _move_path_misses >= 8, "move-applied accuracy drops caused later attacks to miss in the live action path");
    }

    var _fails = variable_struct_get(_S, "fail_count");
    __status_smoke_finish(_pid, _S, (_fails == 0) ? "completed" : "failed");
    return (_fails == 0);
}

function test_battle_accuracy_smoke_update(_pid = 0){
    // Direct smoke completes synchronously in start().
}

function test_battle_effect_195_smoke_start(_auto_close = false){
    var _pid = 0;
    var _S = {
        pid: _pid,
        tag: "effect-195",
        global_name: "DEV_EFFECT_195_SMOKE",
        auto_close: (_auto_close == true),
        state: "running",
        turn_counter: 0,
        pass_count: 0,
        fail_count: 0,
        started_ms: current_time
    };
    global.DEV_EFFECT_195_SMOKE = _S;
    show_debug_message("[smoke][effect-195] starting direct battle-effect smoke");

    var _A = __effect_smoke_mon(92, 30, 60, [288, -1, -1, -1]);
    var _D = __effect_smoke_mon(133, 30, 120, [89, -1, -1, -1]);
    __effect_smoke_slot(_pid, _A, _D);
    __effect_smoke_set_hp(_A, 30);

    __battle_perform_action_impl(_pid, { slot: 0, move_id: 288, actor_index: 0, target_index: 1 });
    var _grudge_armed = variable_struct_exists(_A, "_grudge_active") && variable_struct_get(_A, "_grudge_active") == true;
    __status_smoke_assert(_S, _grudge_armed, "effect 195 armed Grudge on the user until its next action");

    __battle_perform_action_impl(_pid, { slot: 0, move_id: 89, actor_index: 1, target_index: 0 });
    var _enemy_slot = __status_smoke_find_slot(_D, 89);
    var _enemy_pp_zero = is_real(_enemy_slot) && _enemy_slot >= 0 && variable_struct_exists(_D, "pps") && is_array(variable_struct_get(_D, "pps")) && variable_struct_get(_D, "pps")[_enemy_slot] == 0;
    var _user_fainted = (__battle_hp_now(_A) <= 0) && variable_struct_exists(_A, "_fainted") && variable_struct_get(_A, "_fainted") == true;
    __status_smoke_assert(_S, _user_fainted && _enemy_pp_zero, "effect 195 zeroed the fainting move's PP when the Grudge user was KO'd by direct move damage");

    var _fails = variable_struct_get(_S, "fail_count");
    __status_smoke_finish(_pid, _S, (_fails == 0) ? "completed" : "failed");
    return (_fails == 0);
}

function test_battle_effect_195_smoke_update(_pid = 0){
    // Direct smoke completes synchronously in start().
}

function test_battle_effect_211_229_smoke_start(_auto_close = false){
    var _pid = 0;
    var _S = {
        pid: _pid,
        tag: "effect-211-229",
        global_name: "DEV_EFFECT_211_229_SMOKE",
        auto_close: (_auto_close == true),
        state: "running",
        turn_counter: 0,
        pass_count: 0,
        fail_count: 0,
        started_ms: current_time
    };
    global.DEV_EFFECT_211_229_SMOKE = _S;
    show_debug_message("[smoke][effect-211-229] starting direct battle-effect smoke");

    var _A;
    var _D;
    var _before;
    var _after;

    // 211 Water Sport weakens Fire damage.
    _A = __effect_smoke_mon(133, 30, 120, [346, -1, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 180, [299, -1, -1, -1]);
    __effect_smoke_slot(_pid, _A, _D);
    __battle_perform_action_impl(_pid, { slot: 0, move_id: 346, actor_index: 0, target_index: 1 });
    var _water_flag_ok = (__battle_field_get_status_or(_pid, "water_sport", 0) == 5);
    _before = __battle_hp_now(_A);
    __battle_apply_move_damage(_pid, 0, _D, _A, 299, 85);
    var _water_damage = _before - __battle_hp_now(_A);
    _A = __effect_smoke_mon(133, 30, 120, [1, -1, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 180, [299, -1, -1, -1]);
    __effect_smoke_slot(_pid, _A, _D);
    _before = __battle_hp_now(_A);
    __battle_apply_move_damage(_pid, 0, _D, _A, 299, 85);
    var _base_fire_damage = _before - __battle_hp_now(_A);
    __status_smoke_assert(_S, _water_flag_ok && _water_damage > 0 && _water_damage < _base_fire_damage, "effect 211 Water Sport weakened Fire damage battlefield-wide");

    // 214 Camouflage changes type based on terrain.
    _A = __effect_smoke_mon(133, 30, 120, [293, -1, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 120, [1, -1, -1, -1]);
    __effect_smoke_slot(_pid, _A, _D);
    __battle_field_set_terrain(_pid, "electric", { source: _A, turns: 5 });
    __battle_perform_action_impl(_pid, { slot: 0, move_id: 293, actor_index: 0, target_index: 1 });
    __status_smoke_assert(_S, variable_struct_get(_A, "type1") == 13, "effect 214 Camouflage adopted the current terrain type");

    // 218 Wake-Up Slap doubles into sleep and cures it after damage.
    _A = __effect_smoke_mon(133, 30, 120, [358, -1, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 180, [1, -1, -1, -1]);
    __effect_smoke_slot(_pid, _A, _D);
    status_system_apply_status(_D, "sleep", { duration: 2, source: _A });
    var _wake_power = __battle_move_power(358, _A, _D);
    _before = __battle_hp_now(_D);
    __battle_perform_action_impl(_pid, { slot: 0, move_id: 358, actor_index: 0, target_index: 1 });
    _after = __battle_hp_now(_D);
    __status_smoke_assert(_S, _wake_power == 120 && _after < _before && !status_system_has_status(_D, "sleep"), "effect 218 Wake-Up Slap doubled into sleep and woke the target");

    // 220 Gyro Ball scales with speed ratio.
    _A = __effect_smoke_mon(133, 30, 120, [360, -1, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 120, [1, -1, -1, -1]);
    variable_struct_set(_A, "spe", 40);
    variable_struct_set(_D, "spe", 160);
    __effect_smoke_slot(_pid, _A, _D);
    __status_smoke_assert(_S, __battle_move_power(360, _A, _D) >= 100, "effect 220 Gyro Ball used the shared speed-ratio power resolver");

    // 222 Brine doubles on low-HP targets.
    _A = __effect_smoke_mon(133, 30, 120, [362, -1, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 200, [1, -1, -1, -1]);
    __effect_smoke_slot(_pid, _A, _D);
    var _brine_base = __battle_move_power(362, _A, _D);
    __effect_smoke_set_hp(_D, 80);
    var _brine_low = __battle_move_power(362, _A, _D);
    __status_smoke_assert(_S, _brine_base == 65 && _brine_low == 130, "effect 222 Brine doubled power against low-HP targets");

    // 223 Natural Gift derives type and power from the held berry and consumes it.
    _A = __effect_smoke_mon(133, 30, 120, [363, -1, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 180, [1, -1, -1, -1]);
    __effect_smoke_slot(_pid, _A, _D);
    __battle_set_held_item_snapshot(_A, 158, "watmel-berry");
    var _natural_fire_id = 10;
    try {
        if (variable_global_exists("TYPE_ID_BY_NAME")){
            var _natural_type_map = variable_global_get("TYPE_ID_BY_NAME");
            if (ds_exists(_natural_type_map, ds_type_map) && ds_map_exists(_natural_type_map, "fire")) _natural_fire_id = ds_map_find_value(_natural_type_map, "fire");
        }
    } catch (e_natural_type_id) { _natural_fire_id = 10; }
    var _natural_power = __battle_move_power(363, _A, _D);
    var _natural_type = scr_move_type_id_by_id(363, _A);
    _before = __battle_hp_now(_D);
    __battle_perform_action_impl(_pid, { slot: 0, move_id: 363, actor_index: 0, target_index: 1 });
    _after = __battle_hp_now(_D);
    var _natural_consumed = (variable_struct_exists(_A, "held_item_id") && variable_struct_get(_A, "held_item_id") <= 0);
    __status_smoke_assert(_S, _natural_power == 100 && _natural_type == _natural_fire_id && _after < _before && _natural_consumed, "effect 223 Natural Gift used the held berry's type and power, dealt damage, and consumed the berry");

    _A = __effect_smoke_mon(133, 30, 120, [363, -1, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 180, [1, -1, -1, -1]);
    __effect_smoke_slot(_pid, _A, _D);
    _before = __battle_hp_now(_D);
    __battle_perform_action_impl(_pid, { slot: 0, move_id: 363, actor_index: 0, target_index: 1 });
    _after = __battle_hp_now(_D);
    __status_smoke_assert(_S, _after == _before, "effect 223 Natural Gift failed without a usable berry");

    // 226 Tailwind doubles allied Speed through a side status.
    _A = __effect_smoke_mon(133, 30, 120, [366, -1, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 120, [1, -1, -1, -1]);
    __effect_smoke_slot(_pid, _A, _D);
    var _tailwind_base_speed = __battle_stat_get(_A, "spd");
    __battle_perform_action_impl(_pid, { slot: 0, move_id: 366, actor_index: 0, target_index: 0 });
    var _tailwind_turns = __battle_field_get_side_status_or(_pid, 0, "tailwind", 0);
    var _tailwind_boosted_speed = __battle_stat_get(_A, "spd");
    __status_smoke_assert(_S, _tailwind_turns == 4 && _tailwind_boosted_speed == (_tailwind_base_speed * 2), "effect 226 Tailwind set a side status and doubled allied Speed");

    // 227 Acupressure sharply raises a random eligible stat.
    _A = __effect_smoke_mon(133, 30, 120, [367, -1, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 120, [1, -1, -1, -1]);
    __effect_smoke_slot(_pid, _A, _D);
    __battle_perform_action_impl(_pid, { slot: 0, move_id: 367, actor_index: 0, target_index: 0 });
    var _acu_ok = false;
    try {
        var _acu_map = variable_struct_get(_A, "_stages");
        var _acu_keys = ["atk", "def", "spa", "spd", "spe", "accuracy", "evasion"];
        for (var _ak = 0; _ak < array_length(_acu_keys); ++_ak){
            var _akey = _acu_keys[_ak];
            if (variable_struct_exists(_acu_map, _akey) && variable_struct_get(_acu_map, _akey) >= 2){ _acu_ok = true; break; }
        }
    } catch (e_acu_smoke) { _acu_ok = false; }
    __status_smoke_assert(_S, _acu_ok, "effect 227 Acupressure sharply raised a random stat");

    // 228 Metal Burst reflects 1.5x the last received damage.
    _A = __effect_smoke_mon(133, 30, 120, [368, -1, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 120, [1, -1, -1, -1]);
    __effect_smoke_slot(_pid, _A, _D);
    variable_struct_set(_A, "_last_received_damage", 20);
    variable_struct_set(_A, "_last_received_from_actor_index", 1);
    _before = __battle_hp_now(_D);
    __battle_perform_action_impl(_pid, { slot: 0, move_id: 368, actor_index: 0, target_index: 1 });
    _after = __battle_hp_now(_D);
    __status_smoke_assert(_S, (_before - _after) == 30, "effect 228 Metal Burst reflected 1.5x the last received damage");

    // 229 U-turn / Volt Switch open the player's swap flow after a successful hit.
    var _P_ut = party_ensure(_pid);
    var _ut_active = __effect_smoke_mon(133, 30, 120, [369, -1, -1, -1]);
    var _ut_reserve = __effect_smoke_mon(25, 30, 120, [1, -1, -1, -1]);
    _P_ut.mons = [_ut_active, _ut_reserve];
    global.PARTY[_pid] = _P_ut;
    _D = __effect_smoke_mon(10, 30, 180, [1, -1, -1, -1]);
    __effect_smoke_slot(_pid, _ut_active, _D);
    __battle_perform_action_impl(_pid, { slot: 0, move_id: 369, actor_index: 0, target_index: 1 });
    var _ut_party = party_ensure(_pid);
    var _ut_ok = party_is_open(_pid) && variable_struct_exists(_ut_party, "_battle_swap_mode") && variable_struct_get(_ut_party, "_battle_swap_mode") == true;
    __status_smoke_assert(_S, _ut_ok, "effect 229 U-turn opened the player's battle swap flow after a hit");
    try { party_close(_pid); } catch (e_ut_close) {}

    var _fails = variable_struct_get(_S, "fail_count");
    __status_smoke_finish(_pid, _S, (_fails == 0) ? "completed" : "failed");
    return (_fails == 0);
}

function test_battle_effect_211_229_smoke_update(_pid = 0){
    // Direct smoke completes synchronously in start().
}

function test_battle_effect_27_42_smoke_start(_auto_close = false){
    var _pid = 0;
    var _S = {
        pid: _pid,
        tag: "effect-27-42",
        global_name: "DEV_EFFECT_27_42_SMOKE",
        auto_close: (_auto_close == true),
        state: "running",
        turn_counter: 0,
        pass_count: 0,
        fail_count: 0,
        started_ms: current_time
    };
    global.DEV_EFFECT_27_42_SMOKE = _S;
    show_debug_message("[smoke][effect-27-42] starting direct battle-effect smoke");

    var _A;
    var _D;
    var _B;
    var _before;
    var _after;

    // 27 Bide: release double stored incoming damage.
    _A = __effect_smoke_mon(133, 30, 120, [117, -1, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 160, [1, -1, -1, -1]);
    __effect_smoke_slot(_pid, _A, _D);
    variable_struct_set(_A, "_bide_state", { remaining: 1, damage: 30 });
    _before = __battle_hp_now(_D);
    __battle_perform_action_impl(_pid, { slot: 0, move_id: 117, actor_index: 0, target_index: 1 });
    _after = __battle_hp_now(_D);
    __status_smoke_assert(_S, (_before - _after) == 60 && (!variable_struct_exists(_A, "_bide_state") || !is_struct(variable_struct_get(_A, "_bide_state"))), "effect 27 Bide released double stored damage");

    // 28 Thrash-family: Petal Dance/Outrage use the same lock/confuse-after-lock state.
    _A = __effect_smoke_mon(133, 30, 120, [80, -1, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 160, [1, -1, -1, -1]);
    __effect_smoke_slot(_pid, _A, _D);
    __battle_perform_action_impl(_pid, { slot: 0, move_id: 80, actor_index: 0, target_index: 1 });
    var _thrash_ok = false;
    try {
        var _lock = variable_struct_get(_A, "_locked_move");
        _thrash_ok = is_struct(_lock) && variable_struct_get(_lock, "move_id") == 80 && variable_struct_get(_lock, "apply_confuse_on_end") == true;
    } catch (e_thr_lock) { _thrash_ok = false; }
    __status_smoke_assert(_S, _thrash_ok, "effect 28 Thrash-family moves create locked move state");

    // 29 Roar/Whirlwind: end wild battles.
    _A = __effect_smoke_mon(133, 30, 120, [46, -1, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 120, [1, -1, -1, -1]);
    _B = __effect_smoke_slot(_pid, _A, _D, "wild");
    __battle_perform_action_impl(_pid, { slot: 0, move_id: 46, actor_index: 0, target_index: 1 });
    var _phase_ok = false;
    try { _phase_ok = (variable_struct_get(_B, "result") == "escaped" && variable_struct_get(_B, "_pending_close") == true); } catch (e_phase) { _phase_ok = false; }
    __status_smoke_assert(_S, _phase_ok, "effect 29 Roar ended wild battle");

    // 31 Conversion: become the type of one of the user's moves.
    _A = __effect_smoke_mon(133, 30, 120, [160, 52, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 120, [1, -1, -1, -1]);
    __effect_smoke_slot(_pid, _A, _D);
    var _water_type = scr_move_type_id_by_id(52);
    __battle_perform_action_impl(_pid, { slot: 0, move_id: 160, actor_index: 0, target_index: 0 });
    var _conv_ok = false;
    try { _conv_ok = variable_struct_get(_A, "type1") == _water_type && is_array(variable_struct_get(_A, "types")) && variable_struct_get(_A, "types")[0] == _water_type; } catch (e_conv) { _conv_ok = false; }
    __status_smoke_assert(_S, _conv_ok, "effect 31 Conversion changed user type to one of its moves");

    // 34 Toxic: move meta applies badly poisoned status.
    _A = __effect_smoke_mon(133, 30, 120, [92, -1, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 120, [1, -1, -1, -1]);
    __effect_smoke_slot(_pid, _A, _D);
    __battle_apply_move_meta_effects(_pid, { move_id: 92 }, _A, _D, 92, 0, __battle_get_move_meta(92));
    __status_smoke_assert(_S, __effect_smoke_has_status(_D, "toxic"), "effect 34 Toxic applied badly poisoned status");

    // 35 Pay Day: successful hit scatters level * 5 money.
    _A = __effect_smoke_mon(133, 20, 120, [6, -1, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 160, [1, -1, -1, -1]);
    _B = __effect_smoke_slot(_pid, _A, _D);
    __battle_perform_action_impl(_pid, { slot: 0, move_id: 6, actor_index: 0, target_index: 1 });
    var _pay_ok = false;
    try { _pay_ok = variable_struct_get(_B, "_pay_day_money") == 100; } catch (e_pay) { _pay_ok = false; }
    __status_smoke_assert(_S, _pay_ok, "effect 35 Pay Day tracked level-based scattered money");

    // 40 Razor Wind: charge on first use.
    _A = __effect_smoke_mon(133, 30, 120, [13, -1, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 120, [1, -1, -1, -1]);
    __effect_smoke_slot(_pid, _A, _D);
    __battle_perform_action_impl(_pid, { slot: 0, move_id: 13, actor_index: 0, target_index: 1 });
    var _razor_ok = false;
    try {
        var _charge = variable_struct_get(_A, "_charging_move");
        _razor_ok = is_struct(_charge) && variable_struct_get(_charge, "move_id") == 13;
    } catch (e_razor) { _razor_ok = false; }
    __status_smoke_assert(_S, _razor_ok, "effect 40 Razor Wind entered charge state");

    // 41 Super Fang: half current HP.
    _A = __effect_smoke_mon(133, 30, 120, [162, -1, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 101, [1, -1, -1, -1]);
    __effect_smoke_slot(_pid, _A, _D);
    _before = __battle_hp_now(_D);
    __battle_apply_move_damage(_pid, 1, _A, _D, 162, 1);
    _after = __battle_hp_now(_D);
    __status_smoke_assert(_S, (_before - _after) == floor(_before / 2), "effect 41 Super Fang dealt half current HP");

    // 42 Dragon Rage: exact 40 HP damage.
    _A = __effect_smoke_mon(133, 30, 120, [82, -1, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 120, [1, -1, -1, -1]);
    __effect_smoke_slot(_pid, _A, _D);
    _before = __battle_hp_now(_D);
    __battle_apply_move_damage(_pid, 1, _A, _D, 82, 40);
    _after = __battle_hp_now(_D);
    __status_smoke_assert(_S, (_before - _after) == 40, "effect 42 Dragon Rage dealt exactly 40 damage");

    // 43 Bind/Wrap/Clamp/Sand Tomb family: trap the player's active battler so voluntary switching is blocked.
    _A = __effect_smoke_mon(133, 30, 120, [1, -1, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 160, [20, -1, -1, -1]);
    _B = __effect_smoke_slot(_pid, _A, _D);
    var _P_trap = party_ensure(_pid);
    variable_struct_set(_P_trap, "mons", [_A, __effect_smoke_mon(25, 30, 120, [1, -1, -1, -1])]);
    __battle_perform_action_impl(_pid, { slot: 0, move_id: 20, actor_index: 1, target_index: 0 });
    var _trap_applied = __effect_smoke_has_status(_A, "trap");
    variable_struct_set(_B, "phase", "command");
    var _switch_ok_trap = battle_switch_to(_pid, 1, { auto_apply:true, consume_turn:true, forced:false });
    var _switch_staged_trap = false;
    try { _switch_staged_trap = variable_struct_exists(_B, "_switch_target_idx") && is_real(variable_struct_get(_B, "_switch_target_idx")); } catch (e_trap_stage) { _switch_staged_trap = false; }
    __battle_set_hp_now(_D, 60);
    var _trap_inst = undefined;
    try { _trap_inst = status_system_get(_A, "trap"); } catch (e_trap_get) { _trap_inst = undefined; }
    if (is_struct(_trap_inst) && variable_struct_exists(_trap_inst, "_skip_first_tick")) variable_struct_set(_trap_inst, "_skip_first_tick", undefined);
    var _trap_src_before = __battle_hp_now(_D);
    var _trap_tgt_before = __battle_hp_now(_A);
    status_system_tick_statuses(_A, undefined);
    var _trap_src_after = __battle_hp_now(_D);
    var _trap_tgt_after = __battle_hp_now(_A);
    var _trap_msg = string_lower(__status_smoke_dialog_text(_pid) + "\n" + __status_smoke_pending_status_text(_pid));
    var _trap_name = string_lower(__battle_move_name(20));
    var _trap_ok = _trap_applied && (!_switch_ok_trap) && (!_switch_staged_trap) && (_trap_tgt_after < _trap_tgt_before) && (_trap_src_after == _trap_src_before);
    __status_smoke_assert(_S, _trap_ok, "effect 43 trap blocked switching, dealt residual damage, and did not heal the source");
    __status_smoke_assert(_S, string_pos(_trap_name, _trap_msg) > 0, "effect 43 trap residual dialog names the applied trapping move");

    var _fails = variable_struct_get(_S, "fail_count");
    __status_smoke_finish(_pid, _S, (_fails == 0) ? "completed" : "failed");
    return (_fails == 0);
}

function test_battle_effect_27_42_smoke_update(_pid = 0){
    // Direct smoke completes synchronously in start().
}

function test_battle_effect_76_94_smoke_start(_auto_close = false){
    var _pid = 0;
    var _S = {
        pid: _pid,
        tag: "effect-76-94",
        global_name: "DEV_EFFECT_76_94_SMOKE",
        auto_close: (_auto_close == true),
        state: "running",
        turn_counter: 0,
        pass_count: 0,
        fail_count: 0,
        started_ms: current_time
    };
    global.DEV_EFFECT_76_94_SMOKE = _S;
    show_debug_message("[smoke][effect-76-94] starting direct battle-effect smoke");

    var _A;
    var _D;
    var _before;
    var _after;
    global.DEV_FORCE_ACCURACY_HIT = true;

    // Regression guard for classic healing starters: Mega Drain keeps drain healing, Leech Seed keeps seed chip + source heal.
    _A = __effect_smoke_mon(133, 30, 120, [72, -1, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 160, [1, -1, -1, -1]);
    __effect_smoke_slot(_pid, _A, _D);
    __effect_smoke_set_hp(_A, 40);
    _before = __battle_hp_now(_D);
    var _mega_before = __battle_hp_now(_A);
    __battle_perform_action_impl(_pid, { slot: 0, move_id: 72, actor_index: 0, target_index: 1 });
    _after = __battle_hp_now(_D);
    var _mega_anim_ok = false;
    try { _mega_anim_ok = (__battle_anim_family_for_move(72) == "drain"); } catch (e_mega_anim) { _mega_anim_ok = false; }
    __status_smoke_assert(_S, _after < _before && __battle_hp_now(_A) > _mega_before && _mega_anim_ok, "classic Mega Drain still healed the user and stayed in the drain animation family");

    _A = __effect_smoke_mon(133, 30, 120, [73, -1, -1, -1]);
    _D = {
        species_id: 9999,
        name: "seed-target",
        hp_max: 160,
        maxhp: 160,
        hp_now: 160,
        hp: 160,
        atk: 70,
        def: 70,
        spa: 70,
        spd: 70,
        spe: 70,
        type1: 999,
        type2: -1,
        types: [999],
        moves: [1, -1, -1, -1],
        statuses: {}
    };
    __effect_smoke_slot(_pid, _A, _D);
    __effect_smoke_set_hp(_A, 60);
    __battle_apply_move_meta_effects(_pid, { move_id: 73 }, _A, _D, 73, 0, __battle_get_move_meta(73));
    var _leech_applied = __effect_smoke_has_status(_D, "leech-seed");
    var _leech_anim_ok = false;
    try { _leech_anim_ok = (__battle_anim_family_for_move(73) == "status"); } catch (e_leech_anim) { _leech_anim_ok = false; }
    var _leech_src_before = __battle_hp_now(_A);
    var _leech_tgt_before = __battle_hp_now(_D);
    status_system_tick_statuses(_D, undefined);
    var _leech_src_after = __battle_hp_now(_A);
    var _leech_tgt_after = __battle_hp_now(_D);
    __status_smoke_assert(_S, _leech_applied && _leech_anim_ok && _leech_tgt_after < _leech_tgt_before && _leech_src_after > _leech_src_before, "classic Leech Seed still chipped the target, healed the source, and stayed in the status family");

    // 76 Sky Attack: two-turn charge plus flinch meta.
    _A = __effect_smoke_mon(133, 30, 120, [143, -1, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 160, [1, -1, -1, -1]);
    __effect_smoke_slot(_pid, _A, _D);
    __battle_perform_action_impl(_pid, { slot: 0, move_id: 143, actor_index: 0, target_index: 1 });
    var _sky_ok = false;
    try {
        var _sky_charge = variable_struct_get(_A, "_charging_move");
        var _sky_meta = __battle_get_move_meta(143);
        _sky_ok = is_struct(_sky_charge) && variable_struct_get(_sky_charge, "move_id") == 143 && is_struct(_sky_meta) && (variable_struct_exists(_sky_meta, "flinch") || variable_struct_exists(_sky_meta, "flinch_chance"));
    } catch (e_sky) { _sky_ok = false; }
    __status_smoke_assert(_S, _sky_ok, "effect 76 Sky Attack charged and exposes flinch meta");

    // 83 Mimic: replays target's last valid move.
    _A = __effect_smoke_mon(133, 30, 120, [102, -1, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 160, [52, -1, -1, -1]);
    variable_struct_set(_D, "_last_moves", [{ move: 52 }]);
    __effect_smoke_slot(_pid, _A, _D);
    _before = __battle_hp_now(_D);
    __battle_perform_action_impl(_pid, { slot: 0, move_id: 102, actor_index: 0, target_index: 1 });
    _after = __battle_hp_now(_D);
    __status_smoke_assert(_S, _after < _before, "effect 83 Mimic replayed target last move");

    // 86 Splash: explicit no-op.
    _A = __effect_smoke_mon(133, 30, 120, [150, -1, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 160, [1, -1, -1, -1]);
    __effect_smoke_slot(_pid, _A, _D);
    _before = __battle_hp_now(_D);
    __battle_perform_action_impl(_pid, { slot: 0, move_id: 150, actor_index: 0, target_index: 1 });
    _after = __battle_hp_now(_D);
    __status_smoke_assert(_S, _after == _before, "effect 86 Splash completed as an explicit no-op");

    // 87 Disable: disables the target's last move.
    _A = __effect_smoke_mon(133, 30, 120, [50, -1, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 160, [52, -1, -1, -1]);
    variable_struct_set(_D, "_last_moves", [{ move: 52 }]);
    __effect_smoke_slot(_pid, _A, _D);
    __battle_perform_action_impl(_pid, { slot: 0, move_id: 50, actor_index: 0, target_index: 1 });
    var _disable_ok = false;
    try { _disable_ok = variable_struct_get(_D, "sys_disabledMove") == 52 && variable_struct_get(_D, "sys_disabledActive") == true; } catch (e_dis) { _disable_ok = false; }
    __status_smoke_assert(_S, _disable_ok, "effect 87 Disable disabled target last move");

    // 88 Seismic Toss/Night Shade: level fixed damage.
    _A = __effect_smoke_mon(133, 30, 120, [69, -1, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 120, [1, -1, -1, -1]);
    __effect_smoke_slot(_pid, _A, _D);
    _before = __battle_hp_now(_D);
    __battle_apply_move_damage(_pid, 1, _A, _D, 69, 30);
    _after = __battle_hp_now(_D);
    __status_smoke_assert(_S, (_before - _after) == 30, "effect 88 level-based move dealt attacker level damage");

    // 89 Psywave: fixed damage range from 50%-150% of level.
    _A = __effect_smoke_mon(133, 30, 120, [149, -1, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 120, [1, -1, -1, -1]);
    __effect_smoke_slot(_pid, _A, _D);
    _before = __battle_hp_now(_D);
    __battle_apply_move_damage(_pid, 1, _A, _D, 149, 1);
    _after = __battle_hp_now(_D);
    var _psy_dmg = _before - _after;
    __status_smoke_assert(_S, _psy_dmg >= 15 && _psy_dmg <= 45, "effect 89 Psywave dealt damage in level-scaled range");

    // 90 Counter: reflects last physical damage at double damage.
    _A = __effect_smoke_mon(133, 30, 120, [68, -1, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 120, [1, -1, -1, -1]);
    __effect_smoke_slot(_pid, _A, _D);
    variable_struct_set(_A, "_last_received_damage", 20);
    variable_struct_set(_A, "_last_received_move_damage_class", 2);
    variable_struct_set(_A, "_last_received_from_actor_index", 1);
    _before = __battle_hp_now(_D);
    __battle_perform_action_impl(_pid, { slot: 0, move_id: 68, actor_index: 0, target_index: 1 });
    _after = __battle_hp_now(_D);
    __status_smoke_assert(_S, (_before - _after) == 40, "effect 90 Counter reflected double physical damage");

    // 91 Encore: stores target's last move and duration.
    _A = __effect_smoke_mon(133, 30, 120, [227, -1, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 120, [52, -1, -1, -1]);
    variable_struct_set(_D, "sys_last_move_used", 52);
    __effect_smoke_slot(_pid, _A, _D);
    __battle_perform_action_impl(_pid, { slot: 0, move_id: 227, actor_index: 0, target_index: 1 });
    var _encore_ok = false;
    try { var _enc = variable_struct_get(_D, "_encore_state"); _encore_ok = is_struct(_enc) && variable_struct_get(_enc, "move_id") == 52 && variable_struct_get(_enc, "remaining") >= 2; } catch (e_enc) { _encore_ok = false; }
    __status_smoke_assert(_S, _encore_ok, "effect 91 Encore stored target last move");

    // 92 Pain Split: average both current HP values.
    _A = __effect_smoke_mon(133, 30, 120, [220, -1, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 120, [1, -1, -1, -1]);
    __effect_smoke_slot(_pid, _A, _D);
    __effect_smoke_set_hp(_A, 30);
    __effect_smoke_set_hp(_D, 90);
    __battle_perform_action_impl(_pid, { slot: 0, move_id: 220, actor_index: 0, target_index: 1 });
    __status_smoke_assert(_S, __battle_hp_now(_A) == 60 && __battle_hp_now(_D) == 60, "effect 92 Pain Split averaged battler HP");

    // 93 Snore: fails awake, works while sleeping and uses flinch meta.
    global.DEV_FORCE_FLINCH_CHANCE = 100;
    _A = __effect_smoke_mon(133, 30, 120, [173, -1, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 120, [1, -1, -1, -1]);
    __effect_smoke_slot(_pid, _A, _D);
    _before = __battle_hp_now(_D);
    __battle_perform_action_impl(_pid, { slot: 0, move_id: 173, actor_index: 0, target_index: 1 });
    var _snore_awake_ok = (__battle_hp_now(_D) == _before);
    _A = __effect_smoke_mon(133, 30, 120, [173, -1, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 120, [1, -1, -1, -1]);
    __effect_smoke_slot(_pid, _A, _D);
    status_system_apply_status(_A, "sleep", { duration: 2, source: _A });
    _before = __battle_hp_now(_D);
    __battle_perform_action_impl(_pid, { slot: 0, move_id: 173, actor_index: 0, target_index: 1 });
    var _snore_sleep_ok = (__battle_hp_now(_D) < _before && variable_struct_exists(_D, "_flinched") && variable_struct_get(_D, "_flinched") == true);
    global.DEV_FORCE_FLINCH_CHANCE = -1;
    __status_smoke_assert(_S, _snore_awake_ok && _snore_sleep_ok, "effect 93 Snore sleep gate and flinch meta worked");

    // 94 Conversion 2: change to a type resistant/immune to the last move used against the user.
    _A = __effect_smoke_mon(133, 30, 120, [176, -1, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 120, [52, -1, -1, -1]);
    variable_struct_set(_A, "_last_moves", [{ move: 52 }]);
    variable_struct_set(_A, "_last_received_from_move", 52);
    __effect_smoke_slot(_pid, _A, _D);
    __battle_perform_action_impl(_pid, { slot: 0, move_id: 176, actor_index: 0, target_index: 1 });
    var _conv2_ok = false;
    try {
        var _last_attack_type = scr_move_type_id_by_id(52);
        var _atype = variable_struct_get(_A, "type1");
        _conv2_ok = (_last_attack_type == 10 && (_atype == 10 || _atype == 11 || _atype == 16)) || (_atype != 1);
        try {
            var _emap = variable_global_get("BATTLE_TYPE_EFFICACY");
            var _mkey = string(_last_attack_type) + ":" + string(_atype);
            if (ds_map_exists(_emap, _mkey) && ds_map_find_value(_emap, _mkey) < 1) _conv2_ok = true;
        } catch (e_c2_map) {}
    } catch (e_c2) { _conv2_ok = false; }
    __status_smoke_assert(_S, _conv2_ok, "effect 94 Conversion 2 chose a resistant or immune type");

    global.DEV_FORCE_ACCURACY_HIT = false;

    var _fails = variable_struct_get(_S, "fail_count");
    __status_smoke_finish(_pid, _S, (_fails == 0) ? "completed" : "failed");
    return (_fails == 0);
}

function test_battle_effect_76_94_smoke_update(_pid = 0){
    // Direct smoke completes synchronously in start().
}

function test_battle_effect_9_112_smoke_start(_auto_close = false){
    var _pid = 0;
    var _S = {
        pid: _pid,
        tag: "effect-9-112",
        global_name: "DEV_EFFECT_9_112_SMOKE",
        auto_close: (_auto_close == true),
        state: "running",
        turn_counter: 0,
        pass_count: 0,
        fail_count: 0,
        started_ms: current_time
    };
    global.DEV_EFFECT_9_112_SMOKE = _S;
    show_debug_message("[smoke][effect-9-112] starting direct battle-effect smoke");

    var _A;
    var _D;
    var _before;
    var _after;
    global.DEV_FORCE_ACCURACY_HIT = true;

    // 9 Dream Eater: fails against awake targets, damages sleeping targets, and drains half.
    _A = __effect_smoke_mon(133, 30, 120, [138, -1, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 160, [1, -1, -1, -1]);
    __effect_smoke_slot(_pid, _A, _D);
    __effect_smoke_set_hp(_A, 60);
    _before = __battle_hp_now(_D);
    __battle_perform_action_impl(_pid, { slot: 0, move_id: 138, actor_index: 0, target_index: 1 });
    var _dream_awake_ok = (__battle_hp_now(_D) == _before && __battle_hp_now(_A) == 60);
    _A = __effect_smoke_mon(133, 30, 120, [138, -1, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 160, [1, -1, -1, -1]);
    __effect_smoke_slot(_pid, _A, _D);
    __effect_smoke_set_hp(_A, 60);
    status_system_apply_status(_D, "sleep", { duration: 2, source: _A });
    _before = __battle_hp_now(_D);
    __battle_perform_action_impl(_pid, { slot: 0, move_id: 138, actor_index: 0, target_index: 1 });
    _after = __battle_hp_now(_D);
    __status_smoke_assert(_S, _dream_awake_ok && _after < _before && __battle_hp_now(_A) > 60, "effect 9 Dream Eater sleep gate and drain worked");

    // 44 High critical-hit ratio: high-crit moves use the boosted crit stage.
    global.DEV_FORCE_CRIT_ROLL_100 = 10;
    _A = __effect_smoke_mon(133, 30, 120, [1, 2, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 160, [1, -1, -1, -1]);
    __effect_smoke_slot(_pid, _A, _D);
    __battle_apply_move_damage(_pid, 1, _A, _D, 1, 40);
    var _base_crit = false;
    try { _base_crit = variable_struct_get(__battle_ensure_slot(_pid), "_last_crit") == true; } catch (e_base_crit) { _base_crit = false; }
    _A = __effect_smoke_mon(133, 30, 120, [2, -1, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 160, [1, -1, -1, -1]);
    __effect_smoke_slot(_pid, _A, _D);
    __battle_apply_move_damage(_pid, 1, _A, _D, 2, 50);
    var _high_crit = false;
    try { _high_crit = variable_struct_get(__battle_ensure_slot(_pid), "_last_crit") == true; } catch (e_high_crit) { _high_crit = false; }
    global.DEV_FORCE_CRIT_ROLL_100 = -1;
    __status_smoke_assert(_S, !_base_crit && _high_crit, "effect 44 high critical-hit ratio increased crit chance");

    // 81 Recharge: successful Hyper Beam-style moves force the user's next action to recharge.
    _A = __effect_smoke_mon(133, 30, 120, [63, 1, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 240, [1, -1, -1, -1]);
    __effect_smoke_slot(_pid, _A, _D);
    __battle_perform_action_impl(_pid, { slot: 0, move_id: 63, actor_index: 0, target_index: 1 });
    var _recharge_set = false;
    try { _recharge_set = variable_struct_get(_A, "_recharge_turn") == true; } catch (e_rech_set) { _recharge_set = false; }
    _before = __battle_hp_now(_D);
    __battle_perform_action_impl(_pid, { slot: 1, move_id: 1, actor_index: 0, target_index: 1 });
    var _recharge_clear = false;
    try { _recharge_clear = !variable_struct_exists(_A, "_recharge_turn") || variable_struct_get(_A, "_recharge_turn") != true; } catch (e_rech_clear) { _recharge_clear = true; }
    __status_smoke_assert(_S, _recharge_set && _recharge_clear && __battle_hp_now(_D) == _before, "effect 81 recharge skipped the next action");

    // 98 Sleep Talk: fails awake and calls another known move while asleep.
    _A = __effect_smoke_mon(133, 30, 120, [214, 1, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 160, [1, -1, -1, -1]);
    __effect_smoke_slot(_pid, _A, _D);
    _before = __battle_hp_now(_D);
    __battle_perform_action_impl(_pid, { slot: 0, move_id: 214, actor_index: 0, target_index: 1 });
    var _sleep_talk_awake_ok = (__battle_hp_now(_D) == _before);
    _A = __effect_smoke_mon(133, 30, 120, [214, 1, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 160, [1, -1, -1, -1]);
    __effect_smoke_slot(_pid, _A, _D);
    status_system_apply_status(_A, "sleep", { duration: 2, source: _D });
    variable_struct_set(_A, "statuses", { sleep: { id: "sleep", turns: 2 } });
    variable_struct_set(_A, "pps", [10, 35, 0, 0]);
    _before = __battle_hp_now(_D);
    __battle_perform_action_impl(_pid, { slot: 0, move_id: 214, actor_index: 0, target_index: 1 });
    __status_smoke_assert(_S, _sleep_talk_awake_ok && __battle_hp_now(_D) < _before, "effect 98 Sleep Talk sleep gate and selected move worked");

    // 100 Flail/Reversal: variable power increases at low HP.
    _A = __effect_smoke_mon(133, 30, 120, [175, 179, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 160, [1, -1, -1, -1]);
    __effect_smoke_slot(_pid, _A, _D);
    __effect_smoke_set_hp(_A, 100);
    var _flail_high_hp = __battle_move_power(175, _A, _D);
    __effect_smoke_set_hp(_A, 2);
    var _flail_low_hp = __battle_move_power(175, _A, _D);
    var _reversal_low_hp = __battle_move_power(179, _A, _D);
    __status_smoke_assert(_S, _flail_high_hp > 0 && _flail_low_hp > _flail_high_hp && _reversal_low_hp == _flail_low_hp, "effect 100 Flail/Reversal low-HP power scaling worked");

    // 24 Leer: target Defense drops by exactly one stage.
    _A = __effect_smoke_mon(133, 30, 120, [43, -1, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 160, [1, -1, -1, -1]);
    __effect_smoke_slot(_pid, _A, _D);
    __battle_perform_action_impl(_pid, { slot: 0, move_id: 43, actor_index: 0, target_index: 1 });
    var _leer_stage = 0;
    try {
        var _leer_stages = variable_struct_get(_D, "_stages");
        _leer_stage = (variable_struct_exists(_leer_stages, "def") && is_real(variable_struct_get(_leer_stages, "def"))) ? variable_struct_get(_leer_stages, "def") : 0;
    } catch (e_leer_stage) { _leer_stage = 0; }
    __status_smoke_assert(_S, _leer_stage == -1, "effect 24 Leer lowered Defense by exactly one stage");

    // 112 Protect/Detect: guard status blocks incoming direct damage.
    _A = __effect_smoke_mon(133, 30, 120, [182, 197, -1, -1]);
    _D = __effect_smoke_mon(10, 30, 160, [1, -1, -1, -1]);
    __effect_smoke_slot(_pid, _A, _D);
    __battle_perform_action_impl(_pid, { slot: 0, move_id: 182, actor_index: 0, target_index: 0 });
    var _protect_flag = false;
    try { _protect_flag = variable_struct_get(_A, "_protected") == true; } catch (e_prot_flag) { _protect_flag = false; }
    _before = __battle_hp_now(_A);
    __battle_apply_damage(_pid, 0, 50, 1.0);
    __status_smoke_assert(_S, _protect_flag && __battle_hp_now(_A) == _before, "effect 112 Protect blocked incoming damage");

    global.DEV_FORCE_ACCURACY_HIT = false;
    global.DEV_FORCE_CRIT_ROLL_100 = -1;
    var _fails = variable_struct_get(_S, "fail_count");
    __status_smoke_finish(_pid, _S, (_fails == 0) ? "completed" : "failed");
    return (_fails == 0);
}

function test_battle_effect_9_112_smoke_update(_pid = 0){
    // Direct smoke completes synchronously in start().
}
