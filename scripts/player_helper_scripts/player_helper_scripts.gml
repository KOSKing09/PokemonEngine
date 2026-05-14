/// player_anim_update_basic(inst, moving, dir)  (v1.4)
/// dir: 0=up, 1=right, 2=down, 3=left  (caller can pass current physics dir; we persist our own)
/// Fields used on _inst: spriteUp, spriteRight, spriteDown, spriteLeft
function player_anim_update_basic(_inst, _moving, _dir)
{
    var _walk_speed = 0.8;
    var _run_mult   = 1.5;

    if (!instance_exists(_inst)) return;

    // ensure we have a persistent facing (default: down)
    if (!variable_instance_exists(_inst, "facing_dir")) variable_instance_set(_inst, "facing_dir", 2);

    var _pid = variable_instance_exists(_inst, "pid") ? variable_instance_get(_inst, "pid") : 0;
    // Decide facing. Prefer explicit movement dir when provided. Also
    // update facing when the player is holding a movement key even if
    // actual movement (_moving) is false (e.g., stopped by a wall).
    // Fallback: use held direction inputs to determine movement-facing
    var _hold_up     = controls_down(_pid, "MoveUp");
    var _hold_right  = controls_down(_pid, "MoveRight");
    var _hold_down   = controls_down(_pid, "MoveDown");
    var _hold_left   = controls_down(_pid, "MoveLeft");

    if (_moving) {
        // If caller provided a movement direction, use it directly.
        if (is_real(_dir)) {
            // normalize _dir to integer 0..3
            var nd = floor(_dir) mod 4;
            if (nd < 0) nd += 4;
            variable_instance_set(_inst, "facing_dir", nd);
        } else {
            if      (_hold_up)     variable_instance_set(_inst, "facing_dir", 0);
            else if (_hold_right)  variable_instance_set(_inst, "facing_dir", 1);
            else if (_hold_down)   variable_instance_set(_inst, "facing_dir", 2);
            else if (_hold_left)   variable_instance_set(_inst, "facing_dir", 3);
        }
    } else {
        // Not currently moving. But if the player is pressing a movement
        // key (for example, pushing against a wall), we still want to
        // face that direction.
        if      (_hold_up)     variable_instance_set(_inst, "facing_dir", 0);
        else if (_hold_right)  variable_instance_set(_inst, "facing_dir", 1);
        else if (_hold_down)   variable_instance_set(_inst, "facing_dir", 2);
        else if (_hold_left)   variable_instance_set(_inst, "facing_dir", 3);
    }

    // Choose sprite from persistent facing
    var facing = variable_instance_get(_inst, "facing_dir");
    var _target = -1;
    if (variable_instance_exists(_inst, "spriteDown")) _target = variable_instance_get(_inst, "spriteDown");
    switch (facing) {
        case 0: if (variable_instance_exists(_inst, "spriteUp"))    _target = variable_instance_get(_inst, "spriteUp");    break;
        case 1: if (variable_instance_exists(_inst, "spriteRight")) _target = variable_instance_get(_inst, "spriteRight"); break;
        case 2: if (variable_instance_exists(_inst, "spriteDown"))  _target = variable_instance_get(_inst, "spriteDown");  break;
        case 3: if (variable_instance_exists(_inst, "spriteLeft"))  _target = variable_instance_get(_inst, "spriteLeft");  break;
    }

    var cur_si = variable_instance_exists(_inst, "sprite_index") ? variable_instance_get(_inst, "sprite_index") : -1;
    if (cur_si != _target) variable_instance_set(_inst, "sprite_index", _target);

    // Animate only while actually moving; keep frame 0 when not moving
    var _run_held = controls_down(_pid, "Run");
    if (_moving) {
        variable_instance_set(_inst, "image_speed", _walk_speed * (_run_held ? _run_mult : 1.0));
    } else {
        variable_instance_set(_inst, "image_speed", 0);
        variable_instance_set(_inst, "image_index", 0);
    }
}

/// player_by_pid(pid) -> instance id or noone
function player_by_pid(_pid){
    var who = noone;
    with (oPlayer) {
        if (pid == _pid) who = id;
    }
    return who;
}

function multiplayer_ensure_state(){
    if (!variable_global_exists("MULTIPLAYER") || !is_struct(global.MULTIPLAYER)){
        global.MULTIPLAYER = {
            queue_mode: "solo",
            request_pid: 1,
            versus_format: "single"
        };
    }
    var _M = global.MULTIPLAYER;
    var _queue_mode = (variable_struct_exists(_M, "queue_mode") ? string_lower(string(variable_struct_get(_M, "queue_mode"))) : "solo");
    if (_queue_mode != "coop") _queue_mode = "solo";
    variable_struct_set(_M, "queue_mode", _queue_mode);

    var _request_pid = (variable_struct_exists(_M, "request_pid") && is_real(variable_struct_get(_M, "request_pid"))) ? floor(variable_struct_get(_M, "request_pid")) : 1;
    if (_request_pid != 0) _request_pid = 1;
    variable_struct_set(_M, "request_pid", _request_pid);

    var _versus_format = (variable_struct_exists(_M, "versus_format") ? string_lower(string(variable_struct_get(_M, "versus_format"))) : "single");
    if (_versus_format != "double") _versus_format = "single";
    variable_struct_set(_M, "versus_format", _versus_format);

    if (!variable_struct_exists(_M, "versus_request") || !is_struct(variable_struct_get(_M, "versus_request"))){
        variable_struct_set(_M, "versus_request", {
            active: false,
            requester_pid: -1,
            responder_pid: -1,
            prompt_shown: false,
            prompt_closed_ms: -1,
            response: "",
            battle_format: "single"
        });
    } else {
        var _VR = variable_struct_get(_M, "versus_request");
        if (!variable_struct_exists(_VR, "active")) variable_struct_set(_VR, "active", false);
        if (!variable_struct_exists(_VR, "requester_pid") || !is_real(variable_struct_get(_VR, "requester_pid"))) variable_struct_set(_VR, "requester_pid", -1);
        if (!variable_struct_exists(_VR, "responder_pid") || !is_real(variable_struct_get(_VR, "responder_pid"))) variable_struct_set(_VR, "responder_pid", -1);
        if (!variable_struct_exists(_VR, "prompt_shown")) variable_struct_set(_VR, "prompt_shown", false);
        if (!variable_struct_exists(_VR, "prompt_closed_ms") || !is_real(variable_struct_get(_VR, "prompt_closed_ms"))) variable_struct_set(_VR, "prompt_closed_ms", -1);
        if (!variable_struct_exists(_VR, "response")) variable_struct_set(_VR, "response", "");
        if (!variable_struct_exists(_VR, "battle_format")) variable_struct_set(_VR, "battle_format", "single");
        variable_struct_set(_M, "versus_request", _VR);
    }

    global.MULTIPLAYER = _M;
    if (!variable_global_exists("p2")) global.p2 = noone;
    return _M;
}

function __multiplayer_player_label(_pid){
    var _label = "PLAYER " + string(max(0, floor(_pid)) + 1);
    if (floor(_pid) == 0 && variable_global_exists("PLAYER_NAME")) _label = string(global.PLAYER_NAME);
    if (floor(_pid) == 1 && variable_global_exists("PLAYER2_NAME")) _label = string(global.PLAYER2_NAME);
    return _label;
}

function __multiplayer_versus_format_label(_format){
    return (string_lower(string(_format)) == "double") ? "DOUBLE" : "SINGLE";
}

function multiplayer_clear_versus_request(){
    var _M = multiplayer_ensure_state();
    variable_struct_set(_M, "versus_request", {
        active: false,
        requester_pid: -1,
        responder_pid: -1,
        prompt_shown: false,
        prompt_closed_ms: -1,
        response: "",
        battle_format: "single"
    });
    global.MULTIPLAYER = _M;
    return false;
}

function multiplayer_load_options(){
    var _M = multiplayer_ensure_state();
    try {
        ini_open(working_directory + "/options.ini");
        var _queue_mode = string_lower(ini_read_string("Multiplayer", "queue_mode", variable_struct_get(_M, "queue_mode")));
        var _request_pid = ini_read_real("Multiplayer", "request_pid", variable_struct_get(_M, "request_pid"));
        var _versus_format = string_lower(ini_read_string("Multiplayer", "versus_format", variable_struct_get(_M, "versus_format")));
        ini_close();

        if (_queue_mode != "coop") _queue_mode = "solo";
        if (_versus_format != "double") _versus_format = "single";
        if (_request_pid != 0) _request_pid = 1;

        variable_struct_set(_M, "queue_mode", _queue_mode);
        variable_struct_set(_M, "request_pid", _request_pid);
        variable_struct_set(_M, "versus_format", _versus_format);
    } catch (e_multi_load) {
        variable_struct_set(_M, "queue_mode", "solo");
        variable_struct_set(_M, "request_pid", 1);
        variable_struct_set(_M, "versus_format", "single");
    }
    global.MULTIPLAYER = _M;
    return _M;
}

function battle_xp_ensure_state(){
    if (!variable_global_exists("BATTLE_OPTIONS") || !is_struct(global.BATTLE_OPTIONS)){
        global.BATTLE_OPTIONS = {
            xp_mode: "active"
        };
    }
    var _B = global.BATTLE_OPTIONS;
    var _xp_mode = (variable_struct_exists(_B, "xp_mode") ? string_lower(string(variable_struct_get(_B, "xp_mode"))) : "active");
    if (_xp_mode == "shared") _xp_mode = "all";
    if (_xp_mode == "last") _xp_mode = "used";
    if (_xp_mode != "used" && _xp_mode != "all") _xp_mode = "active";
    variable_struct_set(_B, "xp_mode", _xp_mode);
    global.BATTLE_OPTIONS = _B;
    return _B;
}

function battle_xp_load_options(){
    var _B = battle_xp_ensure_state();
    try {
        ini_open(working_directory + "/options.ini");
        var _xp_mode = string_lower(ini_read_string("Battle", "xp_mode", variable_struct_get(_B, "xp_mode")));
        ini_close();

        if (_xp_mode == "shared") _xp_mode = "all";
        if (_xp_mode == "last") _xp_mode = "used";
        if (_xp_mode != "used" && _xp_mode != "all") _xp_mode = "active";
        variable_struct_set(_B, "xp_mode", _xp_mode);
    } catch (e_battle_load) {
        variable_struct_set(_B, "xp_mode", "active");
    }
    global.BATTLE_OPTIONS = _B;
    return _B;
}

function battle_xp_save_options(){
    var _B = battle_xp_ensure_state();
    try {
        ini_open(working_directory + "/options.ini");
        ini_write_string("Battle", "xp_mode", string(variable_struct_get(_B, "xp_mode")));
        ini_close();
    } catch (e_battle_save) {}
}

function battle_xp_mode(){
    var _B = battle_xp_ensure_state();
    return string(variable_struct_get(_B, "xp_mode"));
}

function battle_xp_set_mode(_mode){
    var _B = battle_xp_ensure_state();
    var _next = string_lower(string(_mode));
    if (_next == "shared") _next = "all";
    if (_next == "last") _next = "used";
    if (_next != "used" && _next != "all") _next = "active";
    variable_struct_set(_B, "xp_mode", _next);
    global.BATTLE_OPTIONS = _B;
    battle_xp_save_options();
    return _next;
}

function battle_xp_cycle_mode(_dir){
    var _modes = ["active", "used", "all"];
    var _current = battle_xp_mode();
    var _index = 0;
    for (var _i = 0; _i < array_length(_modes); ++_i){
        if (_modes[_i] == _current){
            _index = _i;
            break;
        }
    }
    var _step = (is_real(_dir) ? floor(_dir) : 1);
    if (_step == 0) _step = 1;
    _index = (_index + _step) mod array_length(_modes);
    if (_index < 0) _index += array_length(_modes);
    return battle_xp_set_mode(_modes[_index]);
}

function multiplayer_save_options(){
    var _M = multiplayer_ensure_state();
    try {
        ini_open(working_directory + "/options.ini");
        ini_write_string("Multiplayer", "queue_mode", string(variable_struct_get(_M, "queue_mode")));
        ini_write_real("Multiplayer", "request_pid", variable_struct_get(_M, "request_pid"));
        ini_write_string("Multiplayer", "versus_format", string(variable_struct_get(_M, "versus_format")));
        ini_close();
    } catch (e_multi_save) {}
}

function multiplayer_queue_mode(){
    var _M = multiplayer_ensure_state();
    return string(variable_struct_get(_M, "queue_mode"));
}

function multiplayer_set_queue_mode(_mode){
    var _M = multiplayer_ensure_state();
    var _next = string_lower(string(_mode));
    if (_next != "coop") _next = "solo";
    variable_struct_set(_M, "queue_mode", _next);
    global.MULTIPLAYER = _M;
    multiplayer_save_options();
    return _next;
}

function multiplayer_toggle_queue_mode(){
    return multiplayer_set_queue_mode(multiplayer_queue_mode() == "coop" ? "solo" : "coop");
}

function multiplayer_request_pid(){
    var _M = multiplayer_ensure_state();
    return floor(variable_struct_get(_M, "request_pid"));
}

function multiplayer_set_request_pid(_pid){
    var _M = multiplayer_ensure_state();
    var _next = (is_real(_pid) && floor(_pid) == 0) ? 0 : 1;
    variable_struct_set(_M, "request_pid", _next);
    global.MULTIPLAYER = _M;
    multiplayer_save_options();
    return _next;
}

function multiplayer_toggle_request_pid(){
    return multiplayer_set_request_pid(multiplayer_request_pid() == 0 ? 1 : 0);
}

function multiplayer_versus_format(){
    var _M = multiplayer_ensure_state();
    return string(variable_struct_get(_M, "versus_format"));
}

function multiplayer_set_versus_format(_format){
    var _M = multiplayer_ensure_state();
    var _next = string_lower(string(_format));
    if (_next != "double") _next = "single";
    variable_struct_set(_M, "versus_format", _next);
    global.MULTIPLAYER = _M;
    multiplayer_save_options();
    return _next;
}

function multiplayer_toggle_versus_format(){
    return multiplayer_set_versus_format(multiplayer_versus_format() == "double" ? "single" : "double");
}

function multiplayer_player_joined(_pid){
    return (player_by_pid(_pid) != noone);
}

function multiplayer_sync_runtime(){
    var _M = multiplayer_ensure_state();
    var _p1 = player_by_pid(0);
    var _p2 = player_by_pid(1);
    global.p1 = _p1;
    global.p2 = _p2;
    variable_struct_set(_M, "player_count", (_p2 != noone) ? 2 : 1);
    global.MULTIPLAYER = _M;
    global.PAUSE_PLAYERS_ACTIVE = variable_struct_get(_M, "player_count");
    try {
        with (oCamera){
            target1 = global.p1;
            target2 = global.p2;
        }
    } catch (e_multi_cam) {}
    if (!is_undefined(splitscreen_apply_gui_size)) splitscreen_apply_gui_size();
    return variable_struct_get(_M, "player_count");
}

function __multiplayer_spawn_x(){
    if (instance_exists(ospawn)) return ospawn.x + 8;
    var _p1 = player_by_pid(0);
    if (_p1 != noone) return _p1.x + 16;
    return 16;
}

function __multiplayer_spawn_y(){
    if (instance_exists(ospawn)) return ospawn.y + 8;
    var _p1 = player_by_pid(0);
    if (_p1 != noone) return _p1.y;
    return 16;
}

function multiplayer_seed_party_if_missing(_pid, _count = 6){
    var _target_pid = max(0, floor(_pid));
    var _mons = (!is_undefined(party_model_get_mons) ? party_model_get_mons(_target_pid) : []);
    if (is_array(_mons) && array_length(_mons) > 0) return array_length(_mons);

    if (!is_undefined(scr_party_debug_seed_random)){
        scr_party_debug_seed_random(_target_pid, max(1, floor(_count)));
        if (variable_global_exists("DEMO_FORCE_SPECIES") && is_array(global.DEMO_FORCE_SPECIES) && !is_undefined(scr_party_demo_apply_forced)){
            scr_party_demo_apply_forced(_target_pid);
        }
    }

    if (!is_undefined(party_apply_name_support)) party_apply_name_support(_target_pid);
    _mons = (!is_undefined(party_model_get_mons) ? party_model_get_mons(_target_pid) : []);
    return is_array(_mons) ? array_length(_mons) : 0;
}

function multiplayer_spawn_player(_pid){
    var _target_pid = (is_real(_pid) ? floor(_pid) : 1);
    if (_target_pid != 1) return player_by_pid(_target_pid);
    var _existing = player_by_pid(_target_pid);
    if (_existing != noone){
        multiplayer_seed_party_if_missing(_target_pid);
        multiplayer_sync_runtime();
        return _existing;
    }
    var _spawned = instance_create_layer(__multiplayer_spawn_x(), __multiplayer_spawn_y(), "Instances", oPlayer);
    try { variable_instance_set(_spawned, "pid", _target_pid); } catch (e_multi_pid) {}
    try { variable_instance_set(_spawned, "_speed", 2); } catch (e_multi_speed) {}
    multiplayer_seed_party_if_missing(_target_pid);
    multiplayer_sync_runtime();
    return _spawned;
}

function multiplayer_drop_player(_pid){
    var _target_pid = (is_real(_pid) ? floor(_pid) : 1);
    if (_target_pid != 1) return false;
    var _inst = player_by_pid(_target_pid);
    if (_inst == noone) return false;
    with (_inst) instance_destroy();
    global.p2 = noone;
    multiplayer_sync_runtime();
    return true;
}

function multiplayer_should_start_coop_for_pid(_pid, _encounter_coop_enabled = true){
    if (_encounter_coop_enabled != true) return false;
    if (multiplayer_queue_mode() != "coop") return false;
    if (!multiplayer_player_joined(1)) return false;
    return (floor(_pid) == multiplayer_request_pid());
}

function multiplayer_battle_open(){
    if (variable_global_exists("sys_battles") && is_array(global.sys_battles)){
        for (var _bi = 0; _bi < array_length(global.sys_battles); ++_bi){
            var _slot = global.sys_battles[_bi];
            if (!is_struct(_slot)) continue;
            if (variable_struct_exists(_slot, "sys_open") && variable_struct_get(_slot, "sys_open") == true) return true;
        }
    }
    return false;
}

function multiplayer_request_versus_battle(_pid){
    var _requester_pid = max(0, floor(_pid));
    var _responder_pid = (_requester_pid == 0) ? 1 : 0;
    if (!multiplayer_player_joined(_responder_pid)) return false;
    if (multiplayer_battle_open()) return false;

    var _M = multiplayer_ensure_state();
    var _VR = variable_struct_get(_M, "versus_request");
    if (is_struct(_VR) && variable_struct_exists(_VR, "active") && variable_struct_get(_VR, "active") == true){
        if (!is_undefined(dialog2p_show_now)) dialog2p_show_now(_requester_pid, "A battle request is already pending.");
        return false;
    }

    var _format = multiplayer_versus_format();
    var _target_count = (_format == "double") ? 2 : 1;
    var _requester_party = __multiplayer_collect_versus_party(_requester_pid, _target_count);
    var _responder_party = __multiplayer_collect_versus_party(_responder_pid, _target_count);
    if (array_length(_requester_party) < _target_count){
        var _requester_need_msg = (_target_count > 1)
            ? (__multiplayer_player_label(_requester_pid) + " needs at least " + string(_target_count) + " usable pokemon for a " + __multiplayer_versus_format_label(_format) + " battle.")
            : (__multiplayer_player_label(_requester_pid) + " doesnt have pokemon");
        if (!is_undefined(dialog2p_show_now)) dialog2p_show_now(_requester_pid, _requester_need_msg);
        return false;
    }
    if (array_length(_responder_party) < _target_count){
        var _responder_need_msg = (_target_count > 1)
            ? (__multiplayer_player_label(_responder_pid) + " needs at least " + string(_target_count) + " usable pokemon for a " + __multiplayer_versus_format_label(_format) + " battle.")
            : (__multiplayer_player_label(_responder_pid) + " doesnt have pokemon");
        if (!is_undefined(dialog2p_show_now)) dialog2p_show_now(_requester_pid, _responder_need_msg);
        return false;
    }

    variable_struct_set(_VR, "active", true);
    variable_struct_set(_VR, "requester_pid", _requester_pid);
    variable_struct_set(_VR, "responder_pid", _responder_pid);
    variable_struct_set(_VR, "prompt_shown", false);
    variable_struct_set(_VR, "prompt_closed_ms", -1);
    variable_struct_set(_VR, "response", "");
    variable_struct_set(_VR, "battle_format", _format);
    variable_struct_set(_M, "versus_request", _VR);
    global.MULTIPLAYER = _M;

    if (!is_undefined(pause_is_open) && pause_is_open(_requester_pid)) pause_toggle(_requester_pid);
    if (!is_undefined(pause_is_open) && pause_is_open(_responder_pid)) pause_toggle(_responder_pid);
    if (!is_undefined(dialog2p_show_now)) dialog2p_show_now(_requester_pid, __multiplayer_versus_format_label(_format) + " battle request sent to " + __multiplayer_player_label(_responder_pid) + ".");
    return true;
}

function multiplayer_update_versus_request(_pid){
    var _self_pid = max(0, floor(_pid));
    var _M = multiplayer_ensure_state();
    var _VR = variable_struct_get(_M, "versus_request");
    if (!is_struct(_VR) || !variable_struct_exists(_VR, "active") || variable_struct_get(_VR, "active") != true) return false;

    var _requester_pid = max(0, floor(variable_struct_get(_VR, "requester_pid")));
    var _responder_pid = max(0, floor(variable_struct_get(_VR, "responder_pid")));
    var _battle_format = variable_struct_exists(_VR, "battle_format") ? string(variable_struct_get(_VR, "battle_format")) : multiplayer_versus_format();
    var _battle_label = __multiplayer_versus_format_label(_battle_format);
    if (!multiplayer_player_joined(_requester_pid) || !multiplayer_player_joined(_responder_pid) || multiplayer_battle_open()){
        multiplayer_clear_versus_request();
        return false;
    }
    if (_self_pid != _responder_pid) return false;

    if (!variable_struct_get(_VR, "prompt_shown")){
        if (!is_undefined(dialog2p_show_now)) dialog2p_show_now(_responder_pid, __multiplayer_player_label(_requester_pid) + " wants a " + _battle_label + " battle!\nPress Interact to accept.\nPress Back to decline.");
        variable_struct_set(_VR, "prompt_shown", true);
        variable_struct_set(_VR, "prompt_closed_ms", -1);
        variable_struct_set(_VR, "response", "");
        variable_struct_set(_M, "versus_request", _VR);
        global.MULTIPLAYER = _M;
        return true;
    }

    var _prompt_open = (!is_undefined(dialog2p_is_open) && dialog2p_is_open(_responder_pid));
    if (_prompt_open){
        if (controls_pressed(_responder_pid, "Interact")) variable_struct_set(_VR, "response", "accept");
        if (controls_pressed(_responder_pid, "Back")) variable_struct_set(_VR, "response", "decline");
        variable_struct_set(_VR, "prompt_closed_ms", -1);
        variable_struct_set(_M, "versus_request", _VR);
        global.MULTIPLAYER = _M;
        return true;
    }

    var _prompt_closed_ms = variable_struct_get(_VR, "prompt_closed_ms");
    if (!is_real(_prompt_closed_ms) || _prompt_closed_ms < 0){
        variable_struct_set(_VR, "prompt_closed_ms", (is_real(current_time) ? current_time + 150 : 150));
        variable_struct_set(_M, "versus_request", _VR);
        global.MULTIPLAYER = _M;
        return true;
    }
    if (is_real(current_time) && current_time < _prompt_closed_ms) return true;

    var _response = string_lower(string(variable_struct_get(_VR, "response")));
    if (_response == "accept"){
        if (!is_undefined(pause_is_open) && pause_is_open(0)) pause_toggle(0);
        if (!is_undefined(pause_is_open) && pause_is_open(1)) pause_toggle(1);
        var _started = multiplayer_start_versus_battle(_requester_pid, _battle_format);
        multiplayer_clear_versus_request();
        if (!_started && !is_undefined(dialog2p_show_now)) dialog2p_show_now(_responder_pid, "Battle could not be started.");
        return _started;
    }

    if (_response == "decline"){
        if (!is_undefined(dialog2p_show_now)) dialog2p_show_now(_requester_pid, __multiplayer_player_label(_responder_pid) + " has declined to battle in a " + _battle_label + " battle.");
        if (!is_undefined(dialog2p_show_now)) dialog2p_show_now(_responder_pid, _battle_label + " battle request declined.");
        multiplayer_clear_versus_request();
        return false;
    }

    return false;
}

function __multiplayer_collect_versus_party(_pid, _max_count){
    var _P = party_ensure(_pid);
    var _out = [];
    if (!is_struct(_P) || !variable_struct_exists(_P, "mons") || !is_array(variable_struct_get(_P, "mons"))) return _out;
    var _mons = variable_struct_get(_P, "mons");
    for (var _mi = 0; _mi < array_length(_mons) && array_length(_out) < _max_count; ++_mi){
        var _mon = _mons[_mi];
        if (!is_struct(_mon)) continue;
        if (__battle_hp_now(_mon) <= 0) continue;
        array_push(_out, _mon);
    }
    return _out;
}

function multiplayer_start_versus_battle(_pid, _format_override = undefined){
    if (!multiplayer_player_joined(1)) return false;
    if (multiplayer_battle_open()) return false;
    if (is_undefined(battle_open_trainer) || is_undefined(__battle_ensure_slot)) return false;

    var _format = is_undefined(_format_override) ? multiplayer_versus_format() : string_lower(string(_format_override));
    if (_format != "double") _format = "single";
    var _target_count = (_format == "double") ? 2 : 1;
    var _player_party = __multiplayer_collect_versus_party(0, _target_count);
    var _enemy_party = __multiplayer_collect_versus_party(1, _target_count);
    var _p2 = player_by_pid(1);
    var _p1_name = variable_global_exists("PLAYER_NAME") ? string(global.PLAYER_NAME) : "PLAYER 1";
    var _p2_name = variable_global_exists("PLAYER2_NAME") ? string(global.PLAYER2_NAME) : "PLAYER 2";
    var _trainer_sprite = (_p2 != noone && variable_instance_exists(_p2, "trainerSprite")) ? variable_instance_get(_p2, "trainerSprite") : undefined;
    var _trainer_subimg = (_p2 != noone && variable_instance_exists(_p2, "trainerSubimg")) ? variable_instance_get(_p2, "trainerSubimg") : 0;
    var _trainer_scale = (_p2 != noone && variable_instance_exists(_p2, "trainerScale")) ? variable_instance_get(_p2, "trainerScale") : 1;
    if (array_length(_player_party) < _target_count) return false;
    if (array_length(_enemy_party) < _target_count) return false;

    battle_open_trainer(0, {
        trainer_name: _p2_name,
        trainer_sprite: _trainer_sprite,
        sprite_index: _trainer_subimg,
        sprite_scale: _trainer_scale,
        enemy_party: _enemy_party,
        battle_format: _format,
        player_pids: [0, 1],
        area_type: "forest"
    });

    var _B = __battle_ensure_slot(0);
    if (!is_struct(_B)) return false;
    variable_struct_set(_B, "versus_enabled", true);
    variable_struct_set(_B, "_versus_trainer_names", [_p2_name, _p1_name]);
    variable_struct_set(_B, "player_pids", [0, 1]);
    variable_struct_set(_B, "coop_enabled", false);
    if (_format == "double") variable_struct_set(_B, "actor_owner_pid", [0, 0, 1, 1]);
    else variable_struct_set(_B, "actor_owner_pid", [0, 1, -1, -1]);
    if (!is_undefined(__battle_bind_shared_slot_aliases)) __battle_bind_shared_slot_aliases(_B, 0);
    if (!is_undefined(splitscreen_apply_gui_size)) splitscreen_apply_gui_size();
    return true;
}

function overworld_ensure_runtime(){
    if (!variable_global_exists("OVERWORLD_RUNTIME") || !is_struct(global.OVERWORLD_RUNTIME)){
        global.OVERWORLD_RUNTIME = {
            flags: {},
            quests: {}
        };
    }
    if (!variable_struct_exists(global.OVERWORLD_RUNTIME, "flags") || !is_struct(variable_struct_get(global.OVERWORLD_RUNTIME, "flags"))) variable_struct_set(global.OVERWORLD_RUNTIME, "flags", {});
    if (!variable_struct_exists(global.OVERWORLD_RUNTIME, "quests") || !is_struct(variable_struct_get(global.OVERWORLD_RUNTIME, "quests"))) variable_struct_set(global.OVERWORLD_RUNTIME, "quests", {});
    if (!variable_struct_exists(global.OVERWORLD_RUNTIME, "npc_pending") || !is_array(variable_struct_get(global.OVERWORLD_RUNTIME, "npc_pending"))) variable_struct_set(global.OVERWORLD_RUNTIME, "npc_pending", [undefined, undefined]);
    return global.OVERWORLD_RUNTIME;
}

function overworld_flag_get(_flag_id, _default_value = false){
    var _R = overworld_ensure_runtime();
    var _flags = variable_struct_get(_R, "flags");
    if (!variable_struct_exists(_flags, _flag_id)) return _default_value;
    return variable_struct_get(_flags, _flag_id);
}

function overworld_flag_set(_flag_id, _value){
    var _R = overworld_ensure_runtime();
    var _flags = variable_struct_get(_R, "flags");
    variable_struct_set(_flags, _flag_id, _value);
    variable_struct_set(_R, "flags", _flags);
    return _value;
}

function overworld_quest_get_state(_quest_id, _default_state = "none"){
    if (string_length(string(_quest_id)) <= 0) return _default_state;
    var _R = overworld_ensure_runtime();
    var _quests = variable_struct_get(_R, "quests");
    if (!variable_struct_exists(_quests, _quest_id)) return _default_state;
    return string(variable_struct_get(_quests, _quest_id));
}

function overworld_quest_set_state(_quest_id, _state){
    if (string_length(string(_quest_id)) <= 0) return "";
    var _R = overworld_ensure_runtime();
    var _quests = variable_struct_get(_R, "quests");
    variable_struct_set(_quests, _quest_id, string(_state));
    variable_struct_set(_R, "quests", _quests);
    return string(_state);
}

function overworld_npc_init(_inst){
    if (!instance_exists(_inst)) return false;
    if (!variable_instance_exists(_inst, "npc_id")) variable_instance_set(_inst, "npc_id", "npc_" + string(_inst));
    if (!variable_instance_exists(_inst, "interact_radius")) variable_instance_set(_inst, "interact_radius", 18);
    if (!variable_instance_exists(_inst, "dialog_text")) variable_instance_set(_inst, "dialog_text", "...");
    if (!variable_instance_exists(_inst, "dialog_active_text")) variable_instance_set(_inst, "dialog_active_text", "...");
    if (!variable_instance_exists(_inst, "dialog_completed_text")) variable_instance_set(_inst, "dialog_completed_text", "...");
    if (!variable_instance_exists(_inst, "give_item_id")) variable_instance_set(_inst, "give_item_id", -1);
    if (!variable_instance_exists(_inst, "give_item_qty")) variable_instance_set(_inst, "give_item_qty", 1);
    if (!variable_instance_exists(_inst, "reward_once")) variable_instance_set(_inst, "reward_once", true);
    if (!variable_instance_exists(_inst, "reward_given")) variable_instance_set(_inst, "reward_given", false);
    if (!variable_instance_exists(_inst, "reward_text")) variable_instance_set(_inst, "reward_text", "You received an item.");
    if (!variable_instance_exists(_inst, "quest_id")) variable_instance_set(_inst, "quest_id", "");
    if (!variable_instance_exists(_inst, "quest_state_on_interact")) variable_instance_set(_inst, "quest_state_on_interact", "offered");
    if (!variable_instance_exists(_inst, "quest_update_text")) variable_instance_set(_inst, "quest_update_text", "A new quest was added.");
    if (!variable_instance_exists(_inst, "wander_enabled")) variable_instance_set(_inst, "wander_enabled", false);
    if (!variable_instance_exists(_inst, "wander_radius")) variable_instance_set(_inst, "wander_radius", 24);
    if (!variable_instance_exists(_inst, "wander_speed")) variable_instance_set(_inst, "wander_speed", 0.4);
    if (!variable_instance_exists(_inst, "wander_pause_min")) variable_instance_set(_inst, "wander_pause_min", 30);
    if (!variable_instance_exists(_inst, "wander_pause_max")) variable_instance_set(_inst, "wander_pause_max", 90);
    if (!variable_instance_exists(_inst, "wander_pause")) variable_instance_set(_inst, "wander_pause", irandom_range(20, 60));
    if (!variable_instance_exists(_inst, "wander_origin_x")) variable_instance_set(_inst, "wander_origin_x", variable_instance_get(_inst, "x"));
    if (!variable_instance_exists(_inst, "wander_origin_y")) variable_instance_set(_inst, "wander_origin_y", variable_instance_get(_inst, "y"));
    if (!variable_instance_exists(_inst, "wander_target_x")) variable_instance_set(_inst, "wander_target_x", variable_instance_get(_inst, "x"));
    if (!variable_instance_exists(_inst, "wander_target_y")) variable_instance_set(_inst, "wander_target_y", variable_instance_get(_inst, "y"));
    if (!variable_instance_exists(_inst, "npc_sprite_base")) variable_instance_set(_inst, "npc_sprite_base", "");
    if (!variable_instance_exists(_inst, "npc_sprite_up")) variable_instance_set(_inst, "npc_sprite_up", -1);
    if (!variable_instance_exists(_inst, "npc_sprite_right")) variable_instance_set(_inst, "npc_sprite_right", -1);
    if (!variable_instance_exists(_inst, "npc_sprite_down")) variable_instance_set(_inst, "npc_sprite_down", -1);
    if (!variable_instance_exists(_inst, "npc_sprite_left")) variable_instance_set(_inst, "npc_sprite_left", -1);
    if (!variable_instance_exists(_inst, "npc_facing_dir")) variable_instance_set(_inst, "npc_facing_dir", 2);
    if (!variable_instance_exists(_inst, "npc_anim_speed")) variable_instance_set(_inst, "npc_anim_speed", 0.16);
    if (!variable_instance_exists(_inst, "npc_path_enabled")) variable_instance_set(_inst, "npc_path_enabled", false);
    if (!variable_instance_exists(_inst, "npc_path")) variable_instance_set(_inst, "npc_path", []);
    if (!variable_instance_exists(_inst, "npc_path_index")) variable_instance_set(_inst, "npc_path_index", 0);
    if (!variable_instance_exists(_inst, "npc_path_loop")) variable_instance_set(_inst, "npc_path_loop", true);
    if (!variable_instance_exists(_inst, "npc_path_pause")) variable_instance_set(_inst, "npc_path_pause", 0);
    if (!variable_instance_exists(_inst, "npc_path_pause_frames")) variable_instance_set(_inst, "npc_path_pause_frames", 24);
    if (!variable_instance_exists(_inst, "npc_path_speed")) variable_instance_set(_inst, "npc_path_speed", 0.75);
    if (!variable_instance_exists(_inst, "trainer_enabled")) variable_instance_set(_inst, "trainer_enabled", false);
    if (!variable_instance_exists(_inst, "trainer_defeated")) variable_instance_set(_inst, "trainer_defeated", false);
    if (!variable_instance_exists(_inst, "trainer_state")) variable_instance_set(_inst, "trainer_state", "idle");
    if (!variable_instance_exists(_inst, "trainer_name")) variable_instance_set(_inst, "trainer_name", "Trainer");
    if (!variable_instance_exists(_inst, "trainer_dialog")) variable_instance_set(_inst, "trainer_dialog", "I challenge you!");
    if (!variable_instance_exists(_inst, "trainer_after_dialog")) variable_instance_set(_inst, "trainer_after_dialog", "That was a good battle.");
    if (!variable_instance_exists(_inst, "trainer_reward")) variable_instance_set(_inst, "trainer_reward", 0);
    if (!variable_instance_exists(_inst, "trainer_party")) variable_instance_set(_inst, "trainer_party", []);
    if (!variable_instance_exists(_inst, "trainer_species")) variable_instance_set(_inst, "trainer_species", 10);
    if (!variable_instance_exists(_inst, "trainer_level")) variable_instance_set(_inst, "trainer_level", 5);
    if (!variable_instance_exists(_inst, "trainer_area_type")) variable_instance_set(_inst, "trainer_area_type", "forest");
    if (!variable_instance_exists(_inst, "trainer_battle_format")) variable_instance_set(_inst, "trainer_battle_format", "single");
    if (!variable_instance_exists(_inst, "trainer_coop_enabled")) variable_instance_set(_inst, "trainer_coop_enabled", true);
    if (!variable_instance_exists(_inst, "trainer_sight_range")) variable_instance_set(_inst, "trainer_sight_range", 96);
    if (!variable_instance_exists(_inst, "trainer_sight_width")) variable_instance_set(_inst, "trainer_sight_width", 18);
    if (!variable_instance_exists(_inst, "trainer_chase_speed")) variable_instance_set(_inst, "trainer_chase_speed", 1.25);
    if (!variable_instance_exists(_inst, "trainer_challenge_group")) variable_instance_set(_inst, "trainer_challenge_group", "");
    if (!variable_instance_exists(_inst, "trainer_group_radius")) variable_instance_set(_inst, "trainer_group_radius", 160);
    if (!variable_instance_exists(_inst, "trainer_target_pid")) variable_instance_set(_inst, "trainer_target_pid", -1);
    if (!variable_instance_exists(_inst, "trainer_approach_x")) variable_instance_set(_inst, "trainer_approach_x", variable_instance_get(_inst, "x"));
    if (!variable_instance_exists(_inst, "trainer_approach_y")) variable_instance_set(_inst, "trainer_approach_y", variable_instance_get(_inst, "y"));
    if (!variable_instance_exists(_inst, "trainer_battle_sprite")) variable_instance_set(_inst, "trainer_battle_sprite", -1);
    if (!variable_instance_exists(_inst, "trainer_battle_sprite_index")) variable_instance_set(_inst, "trainer_battle_sprite_index", 0);
    if (!variable_instance_exists(_inst, "trainer_battle_started")) variable_instance_set(_inst, "trainer_battle_started", false);
    if (!variable_instance_exists(_inst, "cutscene_on_interact")) variable_instance_set(_inst, "cutscene_on_interact", false);
    if (!variable_instance_exists(_inst, "cutscene_shared")) variable_instance_set(_inst, "cutscene_shared", true);
    if (!variable_instance_exists(_inst, "cutscene_lines")) variable_instance_set(_inst, "cutscene_lines", []);
    __overworld_npc_resolve_sprites(_inst);
    return true;
}

function overworld_find_interactable_npc(_player_inst, _max_dist = 18){
    if (!instance_exists(_player_inst)) return noone;
    var _px = variable_instance_get(_player_inst, "x");
    var _py = variable_instance_get(_player_inst, "y");
    var _facing = variable_instance_exists(_player_inst, "facing_dir") ? variable_instance_get(_player_inst, "facing_dir") : 2;
    var _fx = _px;
    var _fy = _py;
    switch (floor(_facing)){
        case 0: _fy -= 12; break;
        case 1: _fx += 12; break;
        case 2: _fy += 12; break;
        case 3: _fx -= 12; break;
    }
    var _npc = instance_nearest(_fx, _fy, oNpc);
    if (_npc == noone) return noone;
    if (variable_instance_exists(_npc, "encounter_pokemon") && variable_instance_get(_npc, "encounter_pokemon") == true) return noone;
    var _radius = variable_instance_exists(_npc, "interact_radius") ? variable_instance_get(_npc, "interact_radius") : _max_dist;
    if (point_distance(_fx, _fy, variable_instance_get(_npc, "x"), variable_instance_get(_npc, "y")) > max(_max_dist, _radius)) return noone;
    return _npc;
}

function overworld_npc_finalize_interaction(_inst, _pid){
    if (!instance_exists(_inst)) return false;
    var _granted = false;

    var _quest_id = (variable_instance_exists(_inst, "quest_id") ? string(variable_instance_get(_inst, "quest_id")) : "");
    if (string_length(_quest_id) > 0){
        var _quest_state = overworld_quest_get_state(_quest_id, "none");
        var _next_state = (variable_instance_exists(_inst, "quest_state_on_interact") ? string(variable_instance_get(_inst, "quest_state_on_interact")) : "offered");
        if (_quest_state != "completed" && _quest_state != _next_state){
            overworld_quest_set_state(_quest_id, _next_state);
            var _quest_text = (variable_instance_exists(_inst, "quest_update_text") ? string(variable_instance_get(_inst, "quest_update_text")) : "Quest updated.");
            if (!is_undefined(dialog2p_enqueue_text)) dialog2p_enqueue_text(_pid, _quest_text, _quest_text, "any");
            _granted = true;
        }
    }

    var _item_id = (variable_instance_exists(_inst, "give_item_id") ? variable_instance_get(_inst, "give_item_id") : -1);
    var _reward_once = (!variable_instance_exists(_inst, "reward_once") || variable_instance_get(_inst, "reward_once") == true);
    var _already_given = (variable_instance_exists(_inst, "reward_given") && variable_instance_get(_inst, "reward_given") == true);
    if (is_real(_item_id) && _item_id > 0 && (!_reward_once || !_already_given)){
        var _qty = (variable_instance_exists(_inst, "give_item_qty") && is_real(variable_instance_get(_inst, "give_item_qty"))) ? max(1, floor(variable_instance_get(_inst, "give_item_qty"))) : 1;
        if (!is_undefined(bag_inventory_add_item)) bag_inventory_add_item(_pid, floor(_item_id), _qty);
        variable_instance_set(_inst, "reward_given", true);
        var _reward_text = (variable_instance_exists(_inst, "reward_text") ? string(variable_instance_get(_inst, "reward_text")) : "You received an item.");
        if (!is_undefined(dialog2p_enqueue_text)) dialog2p_enqueue_text(_pid, _reward_text, _reward_text, "any");
        _granted = true;
    }

    return _granted;
}

function __overworld_npc_dialog_closed(_pid){
    var _R = overworld_ensure_runtime();
    var _pending = variable_struct_get(_R, "npc_pending");
    if (!is_array(_pending) || _pid < 0 || _pid >= array_length(_pending)) return false;
    var _entry = _pending[_pid];
    _pending[_pid] = undefined;
    variable_struct_set(_R, "npc_pending", _pending);
    if (!is_struct(_entry)) return false;
    if (!variable_struct_exists(_entry, "inst") || !is_real(variable_struct_get(_entry, "inst"))) return false;
    return overworld_npc_finalize_interaction(variable_struct_get(_entry, "inst"), _pid);
}

function __overworld_npc_dialog_closed_pid0(){
    return __overworld_npc_dialog_closed(0);
}

function __overworld_npc_dialog_closed_pid1(){
    return __overworld_npc_dialog_closed(1);
}

function __overworld_npc_asset_sprite(_name){
    var _n = string_trim(string(_name));
    if (string_length(_n) <= 0) return -1;
    var _idx = asset_get_index(_n);
    return sprite_exists(_idx) ? _idx : -1;
}

function __overworld_npc_direction_sprite_name(_base, _dir){
    var _b = string_trim(string(_base));
    if (string_length(_b) <= 0) return "";
    var _d = string_lower(string(_dir));
    var _suffix = "_" + _d;
    var _len = string_length(_b);
    var _slen = string_length(_suffix);
    if (_len > _slen && string_lower(string_copy(_b, _len - _slen + 1, _slen)) == _suffix) return _b;
    return _b + _suffix;
}

function __overworld_npc_resolve_sprites(_inst){
    if (!instance_exists(_inst)) return false;
    var _base = variable_instance_exists(_inst, "npc_sprite_base") ? string(variable_instance_get(_inst, "npc_sprite_base")) : "";
    if (string_length(_base) <= 0 && sprite_exists(variable_instance_get(_inst, "sprite_index"))){
        var _sprite_name = sprite_get_name(variable_instance_get(_inst, "sprite_index"));
        var _name_len = string_length(_sprite_name);
        if (_name_len > 5 && string_copy(_sprite_name, _name_len - 4, 5) == "_down") _base = string_copy(_sprite_name, 1, _name_len - 5);
        else if (_name_len > 3 && string_copy(_sprite_name, _name_len - 2, 3) == "_up") _base = string_copy(_sprite_name, 1, _name_len - 3);
        else if (_name_len > 5 && string_copy(_sprite_name, _name_len - 4, 5) == "_left") _base = string_copy(_sprite_name, 1, _name_len - 5);
        else if (_name_len > 6 && string_copy(_sprite_name, _name_len - 5, 6) == "_right") _base = string_copy(_sprite_name, 1, _name_len - 6);
        if (string_length(_base) > 0) variable_instance_set(_inst, "npc_sprite_base", _base);
    }
    if (string_length(_base) <= 0) return false;
    var _down = variable_instance_get(_inst, "npc_sprite_down");
    var _up = variable_instance_get(_inst, "npc_sprite_up");
    var _right = variable_instance_get(_inst, "npc_sprite_right");
    var _left = variable_instance_get(_inst, "npc_sprite_left");
    if (!sprite_exists(_down)) _down = __overworld_npc_asset_sprite(__overworld_npc_direction_sprite_name(_base, "down"));
    if (!sprite_exists(_up)) _up = __overworld_npc_asset_sprite(__overworld_npc_direction_sprite_name(_base, "up"));
    if (!sprite_exists(_right)) _right = __overworld_npc_asset_sprite(__overworld_npc_direction_sprite_name(_base, "right"));
    if (!sprite_exists(_left)) _left = __overworld_npc_asset_sprite(__overworld_npc_direction_sprite_name(_base, "left"));
    if (!sprite_exists(_down)) _down = __overworld_npc_asset_sprite(_base);
    if (!sprite_exists(_up)) _up = _down;
    if (!sprite_exists(_right)) _right = _down;
    if (!sprite_exists(_left)) _left = _down;
    variable_instance_set(_inst, "npc_sprite_down", _down);
    variable_instance_set(_inst, "npc_sprite_up", _up);
    variable_instance_set(_inst, "npc_sprite_right", _right);
    variable_instance_set(_inst, "npc_sprite_left", _left);
    if (sprite_exists(_down) && !sprite_exists(variable_instance_get(_inst, "sprite_index"))) variable_instance_set(_inst, "sprite_index", _down);
    return sprite_exists(_down) || sprite_exists(_up) || sprite_exists(_right) || sprite_exists(_left);
}

function __overworld_npc_start_cutscene(_inst, _pid){
    if (!instance_exists(_inst) || is_undefined(cutscene_play_overworld)) return false;
    var _lines = variable_instance_exists(_inst, "cutscene_lines") ? variable_instance_get(_inst, "cutscene_lines") : [];
    if (!is_array(_lines) || array_length(_lines) <= 0){
        _lines = [string(variable_instance_get(_inst, "dialog_text"))];
    }
    var _pids = [_pid];
    if (variable_instance_get(_inst, "cutscene_shared") == true && !is_undefined(multiplayer_player_joined) && multiplayer_player_joined(1)){
        _pids = [0, 1];
    }
    var _steps = [
        { action: "face_npc", inst: _inst, dir: 2 }
    ];
    for (var _i = 0; _i < array_length(_lines); ++_i){
        array_push(_steps, { action: "dialog", pid: _pid, text: string(_lines[_i]) });
    }
    array_push(_steps, { action: "wait", duration_ms: 180 });
    return cutscene_play_overworld(_pids, _steps, "npc_cutscene_" + string(variable_instance_get(_inst, "npc_id"))) != noone;
}

function __overworld_npc_anim_update(_inst, _moving, _dx = 0, _dy = 0){
    if (!instance_exists(_inst)) return false;
    __overworld_npc_resolve_sprites(_inst);
    var _facing = variable_instance_get(_inst, "npc_facing_dir");
    if (_moving){
        if (abs(_dx) > abs(_dy)) _facing = (_dx >= 0) ? 1 : 3;
        else if (abs(_dy) > 0) _facing = (_dy >= 0) ? 2 : 0;
        variable_instance_set(_inst, "npc_facing_dir", _facing);
    }
    var _target = variable_instance_get(_inst, "npc_sprite_down");
    switch (floor(_facing)){
        case 0: _target = variable_instance_get(_inst, "npc_sprite_up"); break;
        case 1: _target = variable_instance_get(_inst, "npc_sprite_right"); break;
        case 2: _target = variable_instance_get(_inst, "npc_sprite_down"); break;
        case 3: _target = variable_instance_get(_inst, "npc_sprite_left"); break;
    }
    if (!sprite_exists(_target)) _target = variable_instance_get(_inst, "npc_sprite_down");
    if (sprite_exists(_target) && variable_instance_get(_inst, "sprite_index") != _target) variable_instance_set(_inst, "sprite_index", _target);
    if (_moving){
        variable_instance_set(_inst, "image_speed", max(0.02, variable_instance_get(_inst, "npc_anim_speed")));
    } else {
        variable_instance_set(_inst, "image_speed", 0);
        variable_instance_set(_inst, "image_index", 0);
    }
    return true;
}

function __overworld_npc_move_towards(_inst, _tx, _ty, _speed){
    if (!instance_exists(_inst)) return false;
    var _x = variable_instance_get(_inst, "x");
    var _y = variable_instance_get(_inst, "y");
    var _dist = point_distance(_x, _y, _tx, _ty);
    if (_dist <= max(0.05, _speed)){
        variable_instance_set(_inst, "x", _tx);
        variable_instance_set(_inst, "y", _ty);
        __overworld_npc_anim_update(_inst, false, 0, 0);
        return false;
    }
    var _ang = point_direction(_x, _y, _tx, _ty);
    var _dx = lengthdir_x(_speed, _ang);
    var _dy = lengthdir_y(_speed, _ang);
    variable_instance_set(_inst, "x", _x + _dx);
    variable_instance_set(_inst, "y", _y + _dy);
    __overworld_npc_anim_update(_inst, true, _dx, _dy);
    return true;
}

function __overworld_npc_path_point(_path, _index){
    if (!is_array(_path) || array_length(_path) <= 0) return undefined;
    var _i = clamp(floor(_index), 0, array_length(_path) - 1);
    var _p = _path[_i];
    if (is_struct(_p) && variable_struct_exists(_p, "x") && variable_struct_exists(_p, "y")) return { x: real(_p.x), y: real(_p.y) };
    if (is_array(_p) && array_length(_p) >= 2) return { x: real(_p[0]), y: real(_p[1]) };
    return undefined;
}

function __overworld_npc_path_step(_inst){
    var _path = variable_instance_get(_inst, "npc_path");
    if (!is_array(_path) || array_length(_path) <= 0) return false;
    var _pause = variable_instance_get(_inst, "npc_path_pause");
    if (_pause > 0){
        variable_instance_set(_inst, "npc_path_pause", _pause - 1);
        __overworld_npc_anim_update(_inst, false, 0, 0);
        return true;
    }
    var _idx = floor(variable_instance_get(_inst, "npc_path_index"));
    var _pt = __overworld_npc_path_point(_path, _idx);
    if (!is_struct(_pt)) return false;
    var _moving = __overworld_npc_move_towards(_inst, _pt.x, _pt.y, max(0.1, variable_instance_get(_inst, "npc_path_speed")));
    if (!_moving){
        _idx += 1;
        if (_idx >= array_length(_path)){
            if (variable_instance_get(_inst, "npc_path_loop") == true) _idx = 0;
            else {
                _idx = array_length(_path) - 1;
                variable_instance_set(_inst, "npc_path_enabled", false);
            }
        }
        variable_instance_set(_inst, "npc_path_index", _idx);
        variable_instance_set(_inst, "npc_path_pause", max(0, floor(variable_instance_get(_inst, "npc_path_pause_frames"))));
    }
    return true;
}

function __overworld_trainer_player_in_sight(_inst){
    if (!instance_exists(_inst)) return -1;
    if (variable_instance_get(_inst, "trainer_defeated") == true) return -1;
    if (!is_undefined(multiplayer_battle_open) && multiplayer_battle_open()) return -1;
    var _ix = variable_instance_get(_inst, "x") + 16;
    var _iy = variable_instance_get(_inst, "y") + 16;
    var _range = max(16, variable_instance_get(_inst, "trainer_sight_range"));
    var _width = max(8, variable_instance_get(_inst, "trainer_sight_width"));
    var _face = floor(variable_instance_get(_inst, "npc_facing_dir"));
    for (var _pid = 0; _pid < 2; ++_pid){
        var _pl = player_by_pid(_pid);
        if (_pl == noone) continue;
        if (_pid == 1 && !multiplayer_player_joined(1)) continue;
        if (!is_undefined(dialog2p_is_open) && dialog2p_is_open(_pid)) continue;
        var _px = variable_instance_get(_pl, "x") + 8;
        var _py = variable_instance_get(_pl, "y") + 8;
        var _dx = _px - _ix;
        var _dy = _py - _iy;
        switch (_face){
            case 0: if (_dy < 0 && abs(_dx) <= _width && abs(_dy) <= _range) return _pid; break;
            case 1: if (_dx > 0 && abs(_dy) <= _width && abs(_dx) <= _range) return _pid; break;
            case 2: if (_dy > 0 && abs(_dx) <= _width && abs(_dy) <= _range) return _pid; break;
            case 3: if (_dx < 0 && abs(_dy) <= _width && abs(_dx) <= _range) return _pid; break;
        }
    }
    return -1;
}

function __overworld_trainer_set_approach_target(_inst, _pid){
    var _pl = player_by_pid(_pid);
    if (_pl == noone) return false;
    var _face = floor(variable_instance_get(_inst, "npc_facing_dir"));
    var _tx = variable_instance_get(_pl, "x");
    var _ty = variable_instance_get(_pl, "y");
    var _tile = 16;
    switch (_face){
        case 0: _ty += _tile; break;
        case 1: _tx -= _tile; break;
        case 2: _ty -= _tile; break;
        case 3: _tx += _tile; break;
    }
    variable_instance_set(_inst, "trainer_approach_x", _tx);
    variable_instance_set(_inst, "trainer_approach_y", _ty);
    variable_instance_set(_inst, "trainer_target_pid", _pid);
    variable_instance_set(_inst, "trainer_state", "approach");
    return true;
}

function __overworld_trainer_collect_group(_leader){
    var _out = [_leader];
    var _group = string(variable_instance_get(_leader, "trainer_challenge_group"));
    if (string_length(_group) <= 0) return _out;
    var _radius = max(16, variable_instance_get(_leader, "trainer_group_radius"));
    var _lx = variable_instance_get(_leader, "x");
    var _ly = variable_instance_get(_leader, "y");
    for (var _i = 0; _i < instance_number(oNpc); ++_i){
        var _npc = instance_find(oNpc, _i);
        if (_npc == noone || _npc == _leader) continue;
        overworld_npc_init(_npc);
        if (variable_instance_get(_npc, "trainer_enabled") != true) continue;
        if (variable_instance_get(_npc, "trainer_defeated") == true) continue;
        if (string(variable_instance_get(_npc, "trainer_challenge_group")) != _group) continue;
        if (point_distance(_lx, _ly, variable_instance_get(_npc, "x"), variable_instance_get(_npc, "y")) > _radius) continue;
        array_push(_out, _npc);
    }
    return _out;
}

function __overworld_trainer_party_from_npc(_npc){
    var _party = variable_instance_get(_npc, "trainer_party");
    if (is_array(_party) && array_length(_party) > 0) return _party;
    var _species = variable_instance_get(_npc, "trainer_species");
    var _level = max(1, floor(variable_instance_get(_npc, "trainer_level")));
    if (!is_undefined(pokemon_factory_create)) return [pokemon_factory_create(_species, _level, {})];
    return [{ species:_species, level:_level }];
}

function __overworld_trainer_pending_set(_pid, _entry){
    var _R = overworld_ensure_runtime();
    if (!variable_struct_exists(_R, "trainer_pending") || !is_array(variable_struct_get(_R, "trainer_pending"))) variable_struct_set(_R, "trainer_pending", [undefined, undefined]);
    var _pending = variable_struct_get(_R, "trainer_pending");
    if (array_length(_pending) <= _pid) array_resize(_pending, _pid + 1);
    _pending[_pid] = _entry;
    variable_struct_set(_R, "trainer_pending", _pending);
}

function __overworld_trainer_pending_get(_pid){
    var _R = overworld_ensure_runtime();
    if (!variable_struct_exists(_R, "trainer_pending") || !is_array(variable_struct_get(_R, "trainer_pending"))) return undefined;
    var _pending = variable_struct_get(_R, "trainer_pending");
    if (_pid < 0 || _pid >= array_length(_pending)) return undefined;
    return _pending[_pid];
}

function __overworld_trainer_show_dialog(_pid){
    var _entry = __overworld_trainer_pending_get(_pid);
    if (!is_struct(_entry)) return false;
    var _dialogs = variable_struct_get(_entry, "dialogs");
    var _index = variable_struct_get(_entry, "index");
    if (!is_array(_dialogs) || _index >= array_length(_dialogs)) return __overworld_trainer_open_pending_battle(_pid);
    dialog2p_show_now(_pid, {
        text: string(_dialogs[_index]),
        key: "trainer_challenge_" + string(_index),
        gate: "any",
        on_close: (_pid == 1) ? __overworld_trainer_dialog_closed_pid1 : __overworld_trainer_dialog_closed_pid0
    });
    return true;
}

function __overworld_trainer_dialog_closed(_pid){
    var _entry = __overworld_trainer_pending_get(_pid);
    if (!is_struct(_entry)) return false;
    variable_struct_set(_entry, "index", variable_struct_get(_entry, "index") + 1);
    __overworld_trainer_pending_set(_pid, _entry);
    return __overworld_trainer_show_dialog(_pid);
}

function __overworld_trainer_dialog_closed_pid0(){
    return __overworld_trainer_dialog_closed(0);
}

function __overworld_trainer_dialog_closed_pid1(){
    return __overworld_trainer_dialog_closed(1);
}

function __overworld_trainer_open_pending_battle(_pid){
    var _entry = __overworld_trainer_pending_get(_pid);
    __overworld_trainer_pending_set(_pid, undefined);
    if (!is_struct(_entry)) return false;
    if (is_undefined(battle_open_trainer)) return false;
    var _trainers = variable_struct_get(_entry, "trainers");
    for (var _i = 0; _i < array_length(_trainers); ++_i){
        var _npc = _trainers[_i];
        if (!instance_exists(_npc)) continue;
        variable_instance_set(_npc, "trainer_battle_started", true);
        variable_instance_set(_npc, "trainer_defeated", true);
        variable_instance_set(_npc, "trainer_state", "idle");
    }
    var _payload = variable_struct_get(_entry, "payload");
    var _battle_pid = (variable_struct_exists(_entry, "battle_pid") && is_real(variable_struct_get(_entry, "battle_pid"))) ? floor(variable_struct_get(_entry, "battle_pid")) : _pid;
    battle_open_trainer(_battle_pid, _payload);
    return true;
}

function __overworld_trainer_begin_dialog(_leader, _pid){
    if (!instance_exists(_leader)) return false;
    if (is_undefined(dialog2p_show_now)) return false;
    var _trainers = __overworld_trainer_collect_group(_leader);
    var _dialogs = [];
    var _party = [];
    var _reward = 0;
    var _names = [];
    for (var _i = 0; _i < array_length(_trainers); ++_i){
        var _npc = _trainers[_i];
        if (!instance_exists(_npc)) continue;
        variable_instance_set(_npc, "trainer_state", "dialog");
        var _name = string(variable_instance_get(_npc, "trainer_name"));
        array_push(_names, _name);
        var _text = string(variable_instance_get(_npc, "trainer_dialog"));
        if (string_length(_text) <= 0) _text = string(variable_instance_get(_npc, "dialog_text"));
        array_push(_dialogs, _name + ": " + _text);
        var _npc_party = __overworld_trainer_party_from_npc(_npc);
        for (var _pi = 0; _pi < array_length(_npc_party); ++_pi) array_push(_party, _npc_party[_pi]);
        var _npc_reward = variable_instance_get(_npc, "trainer_reward");
        if (is_real(_npc_reward)) _reward += max(0, floor(_npc_reward));
    }
    var _format = string_lower(string(variable_instance_get(_leader, "trainer_battle_format")));
    if (array_length(_trainers) > 1) _format = "double";
    var _coop = (variable_instance_get(_leader, "trainer_coop_enabled") == true && multiplayer_queue_mode() == "coop" && multiplayer_player_joined(1));
    if (_coop) _format = "double";
    var _battle_pid = _coop ? 0 : _pid;
    var _player_pids = _coop ? [0, 1] : [_pid];
    var _battle_sprite = variable_instance_get(_leader, "trainer_battle_sprite");
    var _payload = {
        trainer_name: (array_length(_names) > 1) ? "Double Trainers" : string(variable_instance_get(_leader, "trainer_name")),
        party: _party,
        area_type: string(variable_instance_get(_leader, "trainer_area_type")),
        battle_format: _format,
        coop_enabled: _coop,
        player_pids: _player_pids,
        trainer_reward: _reward,
        trainer_sprite: _battle_sprite,
        sprite_index: variable_instance_get(_leader, "trainer_battle_sprite_index")
    };
    var _entry = { index: 0, trainers: _trainers, dialogs: _dialogs, payload: _payload, battle_pid: _battle_pid };
    __overworld_trainer_pending_set(_pid, _entry);
    return __overworld_trainer_show_dialog(_pid);
}

function __overworld_trainer_step(_inst){
    if (variable_instance_get(_inst, "trainer_enabled") != true) return false;
    if (variable_instance_get(_inst, "trainer_defeated") == true){
        __overworld_npc_anim_update(_inst, false, 0, 0);
        return false;
    }
    var _state = string(variable_instance_get(_inst, "trainer_state"));
    if (_state == "approach"){
        var _pid = floor(variable_instance_get(_inst, "trainer_target_pid"));
        __overworld_trainer_set_approach_target(_inst, _pid);
        var _moving = __overworld_npc_move_towards(
            _inst,
            variable_instance_get(_inst, "trainer_approach_x"),
            variable_instance_get(_inst, "trainer_approach_y"),
            max(0.1, variable_instance_get(_inst, "trainer_chase_speed"))
        );
        if (!_moving) return __overworld_trainer_begin_dialog(_inst, _pid);
        return true;
    }
    if (_state == "dialog") return true;
    var _seen_pid = __overworld_trainer_player_in_sight(_inst);
    if (_seen_pid >= 0) return __overworld_trainer_set_approach_target(_inst, _seen_pid);
    if (variable_instance_get(_inst, "npc_path_enabled") == true) return __overworld_npc_path_step(_inst);
    return false;
}

function overworld_npc_interact(_inst, _pid){
    if (!instance_exists(_inst)) return false;
    overworld_npc_init(_inst);
    if (variable_instance_exists(_inst, "encounter_pokemon") && variable_instance_get(_inst, "encounter_pokemon") == true) return false;
    if (is_undefined(dialog2p_show_now)) return false;

    if (variable_instance_get(_inst, "trainer_enabled") == true){
        if (variable_instance_get(_inst, "trainer_defeated") != true) return __overworld_trainer_begin_dialog(_inst, _pid);
        if (variable_instance_exists(_inst, "trainer_after_dialog")) variable_instance_set(_inst, "dialog_text", string(variable_instance_get(_inst, "trainer_after_dialog")));
    }

    if (variable_instance_get(_inst, "cutscene_on_interact") == true){
        return __overworld_npc_start_cutscene(_inst, _pid);
    }

    var _text = string(variable_instance_get(_inst, "dialog_text"));
    var _quest_id = string(variable_instance_get(_inst, "quest_id"));
    if (string_length(_quest_id) > 0){
        var _quest_state = overworld_quest_get_state(_quest_id, "none");
        if (_quest_state == "active" && variable_instance_exists(_inst, "dialog_active_text")) _text = string(variable_instance_get(_inst, "dialog_active_text"));
        else if (_quest_state == "completed" && variable_instance_exists(_inst, "dialog_completed_text")) _text = string(variable_instance_get(_inst, "dialog_completed_text"));
    }

    var _R = overworld_ensure_runtime();
    var _pending = variable_struct_get(_R, "npc_pending");
    if (!is_array(_pending)) _pending = [undefined, undefined];
    if (array_length(_pending) <= _pid) array_resize(_pending, _pid + 1);
    _pending[_pid] = { inst: _inst };
    variable_struct_set(_R, "npc_pending", _pending);
    dialog2p_show_now(_pid, {
        text: _text,
        key: string(variable_instance_get(_inst, "npc_id")),
        gate: "any",
        on_close: (_pid == 1) ? __overworld_npc_dialog_closed_pid1 : __overworld_npc_dialog_closed_pid0
    });
    return true;
}

function overworld_npc_step(_inst){
    if (!instance_exists(_inst)) return false;
    overworld_npc_init(_inst);
    if (variable_instance_exists(_inst, "encounter_pokemon") && variable_instance_get(_inst, "encounter_pokemon") == true){
        return overworld_encounter_pokemon_npc_step(_inst);
    }
    if (variable_instance_get(_inst, "trainer_enabled") == true && __overworld_trainer_step(_inst)) return true;
    if (variable_instance_get(_inst, "npc_path_enabled") == true) return __overworld_npc_path_step(_inst);
    if (variable_instance_get(_inst, "wander_enabled") != true) return false;

    var _pause = variable_instance_get(_inst, "wander_pause");
    if (_pause > 0){
        variable_instance_set(_inst, "wander_pause", _pause - 1);
        __overworld_npc_anim_update(_inst, false, 0, 0);
        return false;
    }

    var _x = variable_instance_get(_inst, "x");
    var _y = variable_instance_get(_inst, "y");
    var _tx = variable_instance_get(_inst, "wander_target_x");
    var _ty = variable_instance_get(_inst, "wander_target_y");
    var _speed = max(0.1, variable_instance_get(_inst, "wander_speed"));
    var _dist = point_distance(_x, _y, _tx, _ty);
    if (_dist <= _speed){
        variable_instance_set(_inst, "x", _tx);
        variable_instance_set(_inst, "y", _ty);
        var _origin_x = variable_instance_get(_inst, "wander_origin_x");
        var _origin_y = variable_instance_get(_inst, "wander_origin_y");
        var _radius = max(4, variable_instance_get(_inst, "wander_radius"));
        var _dir = irandom(3);
        var _step = choose(8, 16);
        var _next_x = _origin_x;
        var _next_y = _origin_y;
        switch (_dir){
            case 0: _next_y -= _step; break;
            case 1: _next_x += _step; break;
            case 2: _next_y += _step; break;
            case 3: _next_x -= _step; break;
        }
        _next_x = clamp(_next_x, _origin_x - _radius, _origin_x + _radius);
        _next_y = clamp(_next_y, _origin_y - _radius, _origin_y + _radius);
        variable_instance_set(_inst, "wander_target_x", _next_x);
        variable_instance_set(_inst, "wander_target_y", _next_y);
        variable_instance_set(_inst, "wander_pause", irandom_range(variable_instance_get(_inst, "wander_pause_min"), variable_instance_get(_inst, "wander_pause_max")));
        __overworld_npc_anim_update(_inst, false, 0, 0);
        return true;
    }

    var _ang = point_direction(_x, _y, _tx, _ty);
    var _dx = lengthdir_x(_speed, _ang);
    var _dy = lengthdir_y(_speed, _ang);
    variable_instance_set(_inst, "x", _x + _dx);
    variable_instance_set(_inst, "y", _y + _dy);
    __overworld_npc_anim_update(_inst, true, _dx, _dy);
    return true;
}

function overworld_encounter_init(_inst){
    if (!instance_exists(_inst)) return false;
    if (!variable_global_exists("OVERWORLD_ENCOUNTER_MODE")) global.OVERWORLD_ENCOUNTER_MODE = "old";
    if (!variable_global_exists("OVERWORLD_SHINY_CHANCE")) global.OVERWORLD_SHINY_CHANCE = 1 / 4096;
    if (!variable_global_exists("OVERWORLD_VISIBLE_MAX_ACTIVE")) global.OVERWORLD_VISIBLE_MAX_ACTIVE = 16;
    if (!variable_global_exists("OVERWORLD_VISIBLE_PATCH_DENSITY")) global.OVERWORLD_VISIBLE_PATCH_DENSITY = 4;
    if (!variable_global_exists("OVERWORLD_VISIBLE_PATCH_MAX")) global.OVERWORLD_VISIBLE_PATCH_MAX = 8;
    if (!variable_global_exists("OVERWORLD_ENCOUNTER_GRACE_MS")) global.OVERWORLD_ENCOUNTER_GRACE_MS = 1500;
    if (!variable_global_exists("OVERWORLD_ENCOUNTER_BLOCK_UNTIL_MS")) global.OVERWORLD_ENCOUNTER_BLOCK_UNTIL_MS = 0;
    if (!variable_instance_exists(_inst, "encounter_enabled")) variable_instance_set(_inst, "encounter_enabled", true);
    if (!variable_instance_exists(_inst, "encounter_mode")) variable_instance_set(_inst, "encounter_mode", "global");
    if (!variable_instance_exists(_inst, "encounter_radius")) variable_instance_set(_inst, "encounter_radius", 14);
    if (!variable_instance_exists(_inst, "encounter_chance")) variable_instance_set(_inst, "encounter_chance", 1 / 180);
    if (!variable_instance_exists(_inst, "encounter_level_min")) variable_instance_set(_inst, "encounter_level_min", 4);
    if (!variable_instance_exists(_inst, "encounter_level_max")) variable_instance_set(_inst, "encounter_level_max", 8);
    if (!variable_instance_exists(_inst, "encounter_area_type")) variable_instance_set(_inst, "encounter_area_type", "forest");
    if (!variable_instance_exists(_inst, "encounter_region_key")) variable_instance_set(_inst, "encounter_region_key", "demo_route_1");
    if (!variable_instance_exists(_inst, "encounter_habitat")) variable_instance_set(_inst, "encounter_habitat", "grass");
    if (!variable_instance_exists(_inst, "encounter_battle_format")) variable_instance_set(_inst, "encounter_battle_format", "single");
    if (!variable_instance_exists(_inst, "encounter_double_chance")) variable_instance_set(_inst, "encounter_double_chance", 0);
    if (!variable_instance_exists(_inst, "encounter_coop_enabled")) variable_instance_set(_inst, "encounter_coop_enabled", false);
    if (!variable_instance_exists(_inst, "encounter_cooldown")) variable_instance_set(_inst, "encounter_cooldown", 0);
    if (!variable_instance_exists(_inst, "encounter_cooldown_frames")) variable_instance_set(_inst, "encounter_cooldown_frames", 45);
    if (!variable_instance_exists(_inst, "encounter_shiny_chance")) variable_instance_set(_inst, "encounter_shiny_chance", global.OVERWORLD_SHINY_CHANCE);
    if (!variable_instance_exists(_inst, "encounter_visible_spawn_min")) variable_instance_set(_inst, "encounter_visible_spawn_min", 180);
    if (!variable_instance_exists(_inst, "encounter_visible_spawn_max")) variable_instance_set(_inst, "encounter_visible_spawn_max", 420);
    if (!variable_instance_exists(_inst, "encounter_visible_lifetime_min")) variable_instance_set(_inst, "encounter_visible_lifetime_min", 360);
    if (!variable_instance_exists(_inst, "encounter_visible_lifetime_max")) variable_instance_set(_inst, "encounter_visible_lifetime_max", 900);
    if (!variable_instance_exists(_inst, "encounter_visible_speed")) variable_instance_set(_inst, "encounter_visible_speed", 0.85);
    if (!variable_instance_exists(_inst, "encounter_visible_pause_min")) variable_instance_set(_inst, "encounter_visible_pause_min", 20);
    if (!variable_instance_exists(_inst, "encounter_visible_pause_max")) variable_instance_set(_inst, "encounter_visible_pause_max", 70);
    if (!variable_instance_exists(_inst, "encounter_visible_camera_only")) variable_instance_set(_inst, "encounter_visible_camera_only", true);
    if (!variable_instance_exists(_inst, "encounter_visible_grid_size")) variable_instance_set(_inst, "encounter_visible_grid_size", 16);
    if (!variable_instance_exists(_inst, "encounter_visible_max_active")) variable_instance_set(_inst, "encounter_visible_max_active", -1);
    if (!variable_instance_exists(_inst, "encounter_visible_shiny_chance")) variable_instance_set(_inst, "encounter_visible_shiny_chance", variable_instance_get(_inst, "encounter_shiny_chance"));
    if (!variable_instance_exists(_inst, "_encounter_visible")) variable_instance_set(_inst, "_encounter_visible", undefined);
    if (!variable_instance_exists(_inst, "_encounter_visible_npc")) variable_instance_set(_inst, "_encounter_visible_npc", noone);
    if (!variable_instance_exists(_inst, "_encounter_visible_npcs")) variable_instance_set(_inst, "_encounter_visible_npcs", []);
    if (!variable_instance_exists(_inst, "_encounter_visible_timer")) variable_instance_set(_inst, "_encounter_visible_timer", irandom_range(variable_instance_get(_inst, "encounter_visible_spawn_min"), variable_instance_get(_inst, "encounter_visible_spawn_max")));
    if (!variable_instance_exists(_inst, "_encounter_inside_pids")) variable_instance_set(_inst, "_encounter_inside_pids", [false, false]);
    return true;
}

function __overworld_encounter_mode_for(_inst){
    var _mode = "old";
    try {
        _mode = string_lower(string(variable_instance_get(_inst, "encounter_mode")));
        if (_mode == "global" || string_length(_mode) <= 0){
            _mode = variable_global_exists("OVERWORLD_ENCOUNTER_MODE") ? string_lower(string(global.OVERWORLD_ENCOUNTER_MODE)) : "old";
        }
    } catch (e_mode) { _mode = "old"; }
    if (_mode != "new" && _mode != "visible") _mode = "old";
    return _mode;
}

function __overworld_encounter_bounds(_inst){
    var _radius = variable_instance_exists(_inst, "encounter_radius") ? variable_instance_get(_inst, "encounter_radius") : 14;
    var _left = variable_instance_exists(_inst, "bbox_left") ? variable_instance_get(_inst, "bbox_left") : (variable_instance_get(_inst, "x") - _radius);
    var _top = variable_instance_exists(_inst, "bbox_top") ? variable_instance_get(_inst, "bbox_top") : (variable_instance_get(_inst, "y") - _radius);
    var _right = variable_instance_exists(_inst, "bbox_right") ? variable_instance_get(_inst, "bbox_right") : (variable_instance_get(_inst, "x") + _radius);
    var _bottom = variable_instance_exists(_inst, "bbox_bottom") ? variable_instance_get(_inst, "bbox_bottom") : (variable_instance_get(_inst, "y") + _radius);
    var _grid = variable_instance_exists(_inst, "encounter_visible_grid_size") ? max(1, floor(variable_instance_get(_inst, "encounter_visible_grid_size"))) : 16;
    var _changed = true;
    var _passes = 0;
    while (_changed && _passes < 8){
        _changed = false;
        _passes += 1;
        var _n = instance_number(obush);
        for (var _i = 0; _i < _n; ++_i){
            var _bush = instance_find(obush, _i);
            if (_bush == noone) continue;
            var _bl = variable_instance_exists(_bush, "bbox_left") ? variable_instance_get(_bush, "bbox_left") : variable_instance_get(_bush, "x");
            var _bt = variable_instance_exists(_bush, "bbox_top") ? variable_instance_get(_bush, "bbox_top") : variable_instance_get(_bush, "y");
            var _br = variable_instance_exists(_bush, "bbox_right") ? variable_instance_get(_bush, "bbox_right") : (_bl + _grid);
            var _bb = variable_instance_exists(_bush, "bbox_bottom") ? variable_instance_get(_bush, "bbox_bottom") : (_bt + _grid);
            if (!__overworld_rects_intersect(_left - _grid, _top - _grid, _right + _grid, _bottom + _grid, _bl, _bt, _br, _bb)) continue;
            var _nl = min(_left, _bl);
            var _nt = min(_top, _bt);
            var _nr = max(_right, _br);
            var _nb = max(_bottom, _bb);
            if (_nl != _left || _nt != _top || _nr != _right || _nb != _bottom){
                _left = _nl;
                _top = _nt;
                _right = _nr;
                _bottom = _nb;
                _changed = true;
            }
        }
    }
    return { left:_left, top:_top, right:_right + 1, bottom:_bottom + 1 };
}

function __overworld_rects_intersect(_a_left, _a_top, _a_right, _a_bottom, _b_left, _b_top, _b_right, _b_bottom){
    return (_a_right >= _b_left && _a_left <= _b_right && _a_bottom >= _b_top && _a_top <= _b_bottom);
}

function __overworld_encounter_is_area_anchor(_inst){
    if (!instance_exists(_inst)) return false;
    var _area = __overworld_encounter_bounds(_inst);
    var _sx = variable_instance_get(_inst, "x");
    var _sy = variable_instance_get(_inst, "y");
    var _sid = _inst;
    var _n = instance_number(obush);
    for (var _i = 0; _i < _n; ++_i){
        var _bush = instance_find(obush, _i);
        if (_bush == noone) continue;
        var _bx = variable_instance_get(_bush, "x");
        var _by = variable_instance_get(_bush, "y");
        if (!point_in_rectangle(_bx, _by, _area.left, _area.top, _area.right, _area.bottom)) continue;
        if (_by < _sy || (_by == _sy && _bx < _sx) || (_by == _sy && _bx == _sx && _bush < _sid)) return false;
    }
    return true;
}

function __overworld_encounter_area_bush_count(_inst){
    if (!instance_exists(_inst)) return 0;
    var _area = __overworld_encounter_bounds(_inst);
    var _count = 0;
    var _n = instance_number(obush);
    for (var _i = 0; _i < _n; ++_i){
        var _bush = instance_find(obush, _i);
        if (_bush == noone) continue;
        var _bx = variable_instance_get(_bush, "x");
        var _by = variable_instance_get(_bush, "y");
        if (point_in_rectangle(_bx, _by, _area.left, _area.top, _area.right, _area.bottom)) _count += 1;
    }
    return _count;
}

function __overworld_encounter_patch_max_active(_inst){
    if (!instance_exists(_inst)) return 1;
    var _manual = variable_instance_exists(_inst, "encounter_visible_max_active") ? floor(variable_instance_get(_inst, "encounter_visible_max_active")) : -1;
    if (_manual > 0) return _manual;

    var _bush_count = max(1, __overworld_encounter_area_bush_count(_inst));
    var _density = variable_global_exists("OVERWORLD_VISIBLE_PATCH_DENSITY") ? max(1, floor(global.OVERWORLD_VISIBLE_PATCH_DENSITY)) : 4;
    var _patch_max_limit = variable_global_exists("OVERWORLD_VISIBLE_PATCH_MAX") ? max(1, floor(global.OVERWORLD_VISIBLE_PATCH_MAX)) : 8;
    var _auto = ceil(_bush_count / _density);
    if (_bush_count >= _density) _auto = max(2, _auto);
    return clamp(_auto, 1, _patch_max_limit);
}

function __overworld_encounter_in_camera(_inst, _pad = 0){
    if (!instance_exists(_inst)) return false;
    var _b = __overworld_encounter_bounds(_inst);
    var _padv = is_real(_pad) ? real(_pad) : 0;
    for (var _vi = 0; _vi < 2; ++_vi){
        if (!view_visible[_vi]) continue;
        var _cam = view_camera[_vi];
        if (_cam == -1) continue;
        var _cx = camera_get_view_x(_cam);
        var _cy = camera_get_view_y(_cam);
        var _cw = camera_get_view_width(_cam);
        var _ch = camera_get_view_height(_cam);
        if (__overworld_rects_intersect(_b.left, _b.top, _b.right, _b.bottom, _cx - _padv, _cy - _padv, _cx + _cw + _padv, _cy + _ch + _padv)) return true;
    }
    return false;
}

function __overworld_encounter_active_visible_count(){
    var _count = 0;
    var _n = instance_number(oNpc);
    for (var _i = 0; _i < _n; ++_i){
        var _npc = instance_find(oNpc, _i);
        if (_npc != noone && variable_instance_exists(_npc, "encounter_pokemon") && variable_instance_get(_npc, "encounter_pokemon") == true) _count += 1;
    }
    return _count;
}

function __overworld_encounter_random_point(_inst){
    var _b = __overworld_encounter_bounds(_inst);
    var _grid = variable_instance_exists(_inst, "encounter_visible_grid_size") ? max(1, floor(variable_instance_get(_inst, "encounter_visible_grid_size"))) : 16;
    var _size = 32;
    var _min_x = floor(_b.left / _grid) * _grid;
    var _min_y = floor(_b.top / _grid) * _grid;
    var _max_x = floor(max(_min_x, _b.right - _size) / _grid) * _grid;
    var _max_y = floor(max(_min_y, _b.bottom - _size) / _grid) * _grid;
    _min_x = clamp(_min_x, _b.left, max(_b.left, _b.right - _size));
    _min_y = clamp(_min_y, _b.top, max(_b.top, _b.bottom - _size));
    _max_x = clamp(_max_x, _min_x, max(_min_x, _b.right - _size));
    _max_y = clamp(_max_y, _min_y, max(_min_y, _b.bottom - _size));
    var _cells_x = max(0, floor((_max_x - _min_x) / _grid));
    var _cells_y = max(0, floor((_max_y - _min_y) / _grid));
    return {
        x: _min_x + irandom(_cells_x) * _grid,
        y: _min_y + irandom(_cells_y) * _grid
    };
}

function __overworld_encounter_roll_shiny(_inst){
    var _chance = variable_instance_exists(_inst, "encounter_shiny_chance") ? real(variable_instance_get(_inst, "encounter_shiny_chance")) : 0;
    if (variable_instance_exists(_inst, "encounter_visible_shiny_chance")) _chance = real(variable_instance_get(_inst, "encounter_visible_shiny_chance"));
    return (_chance > 0 && random(1) < _chance);
}

function __overworld_encounter_visible_reset_timer(_inst){
    var _min_t = max(1, floor(variable_instance_get(_inst, "encounter_visible_spawn_min")));
    var _max_t = max(_min_t, floor(variable_instance_get(_inst, "encounter_visible_spawn_max")));
    variable_instance_set(_inst, "_encounter_visible_timer", irandom_range(_min_t, _max_t));
}

function __overworld_encounter_visible_reset_timer_quick(_inst){
    var _min_t = max(1, floor(variable_instance_get(_inst, "encounter_visible_spawn_min") / 3));
    var _max_t = max(_min_t, floor(variable_instance_get(_inst, "encounter_visible_spawn_max") / 3));
    variable_instance_set(_inst, "_encounter_visible_timer", irandom_range(_min_t, _max_t));
}

function __overworld_encounter_visible_npc_alive(_inst){
    if (!instance_exists(_inst)) return false;
    return (__overworld_encounter_visible_npc_count(_inst) > 0);
}

function __overworld_encounter_visible_npc_count(_inst){
    if (!instance_exists(_inst)) return 0;
    var _live = [];
    if (variable_instance_exists(_inst, "_encounter_visible_npcs") && is_array(variable_instance_get(_inst, "_encounter_visible_npcs"))){
        var _arr = variable_instance_get(_inst, "_encounter_visible_npcs");
        for (var _i = 0; _i < array_length(_arr); ++_i){
            var _npc = _arr[_i];
            if (_npc != noone && instance_exists(_npc)) array_push(_live, _npc);
        }
    }
    if (variable_instance_exists(_inst, "_encounter_visible_npc")){
        var _legacy = variable_instance_get(_inst, "_encounter_visible_npc");
        if (_legacy != noone && instance_exists(_legacy)){
            var _found = false;
            for (var _j = 0; _j < array_length(_live); ++_j){
                if (_live[_j] == _legacy){
                    _found = true;
                    break;
                }
            }
            if (!_found) array_push(_live, _legacy);
        }
    }
    variable_instance_set(_inst, "_encounter_visible_npcs", _live);
    variable_instance_set(_inst, "_encounter_visible_npc", (array_length(_live) > 0) ? _live[0] : noone);
    return array_length(_live);
}

function __overworld_encounter_clear_visible_npc(_inst, _reset_timer = true){
    if (!instance_exists(_inst)) return false;
    variable_instance_set(_inst, "_encounter_visible_npc", noone);
    variable_instance_set(_inst, "_encounter_visible_npcs", []);
    variable_instance_set(_inst, "_encounter_visible", undefined);
    if (_reset_timer) __overworld_encounter_visible_reset_timer(_inst);
    return true;
}

function __overworld_encounter_remove_visible_npc(_inst, _npc, _reset_timer = true){
    if (!instance_exists(_inst)) return false;
    var _live = [];
    if (variable_instance_exists(_inst, "_encounter_visible_npcs") && is_array(variable_instance_get(_inst, "_encounter_visible_npcs"))){
        var _arr = variable_instance_get(_inst, "_encounter_visible_npcs");
        for (var _i = 0; _i < array_length(_arr); ++_i){
            var _other = _arr[_i];
            if (_other == _npc) continue;
            if (_other != noone && instance_exists(_other)) array_push(_live, _other);
        }
    }
    variable_instance_set(_inst, "_encounter_visible_npcs", _live);
    variable_instance_set(_inst, "_encounter_visible_npc", (array_length(_live) > 0) ? _live[0] : noone);
    variable_instance_set(_inst, "_encounter_visible", undefined);
    if (_reset_timer) __overworld_encounter_visible_reset_timer(_inst);
    return true;
}

function __overworld_encounter_visible_spawn(_inst){
    var _patch_count = __overworld_encounter_visible_npc_count(_inst);
    var _patch_max = __overworld_encounter_patch_max_active(_inst);
    if (_patch_count >= _patch_max) return false;
    if (variable_instance_exists(_inst, "encounter_visible_camera_only") && variable_instance_get(_inst, "encounter_visible_camera_only") == true && !__overworld_encounter_in_camera(_inst, 8)){
        __overworld_encounter_visible_reset_timer(_inst);
        return false;
    }
    var _max_active = variable_global_exists("OVERWORLD_VISIBLE_MAX_ACTIVE") ? max(0, floor(global.OVERWORLD_VISIBLE_MAX_ACTIVE)) : 16;
    if (_max_active > 0 && __overworld_encounter_active_visible_count() >= _max_active){
        __overworld_encounter_visible_reset_timer(_inst);
        return false;
    }
    var _level_min = max(1, floor(variable_instance_get(_inst, "encounter_level_min")));
    var _level_max = max(_level_min, floor(variable_instance_get(_inst, "encounter_level_max")));
    var _table = undefined;
    if (variable_instance_exists(_inst, "encounter_table") && is_array(variable_instance_get(_inst, "encounter_table"))) _table = variable_instance_get(_inst, "encounter_table");
    else _table = __overworld_encounter_table_for(variable_instance_get(_inst, "encounter_region_key"), variable_instance_get(_inst, "encounter_habitat"));
    var _pick = __overworld_encounter_pick_from_table(_table, _level_min, _level_max);
    if (!is_struct(_pick)){
        __overworld_encounter_visible_reset_timer(_inst);
        return false;
    }

    var _p = __overworld_encounter_random_point(_inst);
    var _life_min = max(1, floor(variable_instance_get(_inst, "encounter_visible_lifetime_min")));
    var _life_max = max(_life_min, floor(variable_instance_get(_inst, "encounter_visible_lifetime_max")));
    var _target = __overworld_encounter_random_point(_inst);
    var _b = __overworld_encounter_bounds(_inst);
    var _bound_left = _b.left;
    var _bound_top = _b.top;
    var _bound_right = max(_bound_left, _b.right - 32);
    var _bound_bottom = max(_bound_top, _b.bottom - 32);

    var _npc = instance_create_layer(_p.x, _p.y, "Instances", oNpc);
    if (_npc == noone){
        __overworld_encounter_visible_reset_timer(_inst);
        return false;
    }

    variable_instance_set(_npc, "encounter_pokemon", true);
    variable_instance_set(_npc, "encounter_owner", _inst);
    variable_instance_set(_npc, "encounter_species_id", variable_struct_get(_pick, "species_id"));
    variable_instance_set(_npc, "encounter_level", variable_struct_get(_pick, "level"));
    variable_instance_set(_npc, "encounter_shiny", __overworld_encounter_roll_shiny(_inst));
    variable_instance_set(_npc, "encounter_lifetime", irandom_range(_life_min, _life_max));
    variable_instance_set(_npc, "encounter_fade_frames", 45);
    variable_instance_set(_npc, "encounter_dir", "DOWN");
    variable_instance_set(_npc, "encounter_bounds_left", _bound_left);
    variable_instance_set(_npc, "encounter_bounds_top", _bound_top);
    variable_instance_set(_npc, "encounter_bounds_right", _bound_right);
    variable_instance_set(_npc, "encounter_bounds_bottom", _bound_bottom);
    variable_instance_set(_npc, "encounter_grid_size", variable_instance_get(_inst, "encounter_visible_grid_size"));
    variable_instance_set(_npc, "wander_enabled", true);
    variable_instance_set(_npc, "wander_speed", max(0.05, real(variable_instance_get(_inst, "encounter_visible_speed"))));
    variable_instance_set(_npc, "wander_pause_min", variable_instance_get(_inst, "encounter_visible_pause_min"));
    variable_instance_set(_npc, "wander_pause_max", variable_instance_get(_inst, "encounter_visible_pause_max"));
    variable_instance_set(_npc, "wander_pause", 0);
    variable_instance_set(_npc, "wander_target_x", _target.x);
    variable_instance_set(_npc, "wander_target_y", _target.y);
    variable_instance_set(_npc, "interact_radius", 0);
    variable_instance_set(_npc, "dialog_text", "");
    variable_instance_set(_npc, "image_speed", 0);
    variable_instance_set(_npc, "image_alpha", 1);
    variable_instance_set(_npc, "image_xscale", 0.67);
    variable_instance_set(_npc, "image_yscale", 0.67);
    variable_instance_set(_npc, "depth", -(_p.y + 16));
    var _arr_live = [];
    if (variable_instance_exists(_inst, "_encounter_visible_npcs") && is_array(variable_instance_get(_inst, "_encounter_visible_npcs"))) _arr_live = variable_instance_get(_inst, "_encounter_visible_npcs");
    array_push(_arr_live, _npc);
    variable_instance_set(_inst, "_encounter_visible_npcs", _arr_live);
    variable_instance_set(_inst, "_encounter_visible_npc", _arr_live[0]);
    variable_instance_set(_inst, "_encounter_visible", undefined);
    __overworld_encounter_pokemon_npc_pick_target(_npc);
    __overworld_encounter_pokemon_npc_sprite_update(_npc, false);
    if (__overworld_encounter_visible_npc_count(_inst) < _patch_max) __overworld_encounter_visible_reset_timer_quick(_inst);
    return true;
}

function __overworld_encounter_pokemon_npc_bounds(_inst, _x, _y){
    var _spr = variable_instance_exists(_inst, "sprite_index") ? variable_instance_get(_inst, "sprite_index") : -1;
    var _sx = variable_instance_exists(_inst, "image_xscale") ? real(variable_instance_get(_inst, "image_xscale")) : 0.67;
    var _sy = variable_instance_exists(_inst, "image_yscale") ? real(variable_instance_get(_inst, "image_yscale")) : 0.67;
    if (sprite_exists(_spr)){
        var _ox = sprite_get_xoffset(_spr);
        var _oy = sprite_get_yoffset(_spr);
        var _bl = sprite_get_bbox_left(_spr);
        var _bt = sprite_get_bbox_top(_spr);
        var _br = sprite_get_bbox_right(_spr) + 1;
        var _bb = sprite_get_bbox_bottom(_spr) + 1;
        return {
            left: _x + (_bl - _ox) * _sx,
            top: _y + (_bt - _oy) * _sy,
            right: _x + (_br - _ox) * _sx,
            bottom: _y + (_bb - _oy) * _sy
        };
    }
    return { left: _x, top: _y, right: _x + 16, bottom: _y + 16 };
}

function __overworld_encounter_visible_player_hit(_npc, _pl){
    if (!instance_exists(_npc) || !instance_exists(_pl)) return false;
    var _mx = variable_instance_get(_npc, "x");
    var _my = variable_instance_get(_npc, "y");
    var _npc_bounds = __overworld_encounter_pokemon_npc_bounds(_npc, _mx, _my);
    if (variable_instance_exists(_pl, "bbox_left") && variable_instance_exists(_pl, "bbox_top") && variable_instance_exists(_pl, "bbox_right") && variable_instance_exists(_pl, "bbox_bottom")){
        return __overworld_rects_intersect(_npc_bounds.left, _npc_bounds.top, _npc_bounds.right, _npc_bounds.bottom,
            variable_instance_get(_pl, "bbox_left"),
            variable_instance_get(_pl, "bbox_top"),
            variable_instance_get(_pl, "bbox_right"),
            variable_instance_get(_pl, "bbox_bottom"));
    }
    return point_in_rectangle(variable_instance_get(_pl, "x"), variable_instance_get(_pl, "y"), _npc_bounds.left, _npc_bounds.top, _npc_bounds.right, _npc_bounds.bottom);
}

function __overworld_encounter_pokemon_npc_sprite_update(_inst, _moving){
    var _dir = variable_instance_exists(_inst, "encounter_dir") ? string(variable_instance_get(_inst, "encounter_dir")) : "DOWN";
    var _species_id = variable_instance_get(_inst, "encounter_species_id");
    var _shiny = (variable_instance_exists(_inst, "encounter_shiny") && variable_instance_get(_inst, "encounter_shiny") == true);
    var _mon = {
        species_id: _species_id,
        shiny: _shiny
    };
    var _spr = -1;
    var _has_sheet = true;
    if (!is_undefined(pkicons_has_icon32)) _has_sheet = pkicons_has_icon32(_species_id, _shiny) || (_shiny && pkicons_has_icon32(_species_id, false));
    if (_has_sheet && !is_undefined(pkicons_get_overworld_dir_by_mon)) _spr = pkicons_get_overworld_dir_by_mon(_mon, _dir);
    else if (_has_sheet && !is_undefined(pkicons_get_icon32_dir_by_mon)) _spr = pkicons_get_icon32_dir_by_mon(_mon, _dir);
    if (!sprite_exists(_spr)){
        pkicons_init();
        if (variable_global_exists("PKICONS") && is_struct(global.PKICONS) && variable_struct_exists(global.PKICONS, "missing_icon32")) _spr = variable_struct_get(global.PKICONS, "missing_icon32");
        if (!sprite_exists(_spr)) _spr = asset_get_index("spr_mon_icon_placeholder");
        if (!variable_instance_exists(_inst, "encounter_skin_warned")){
            variable_instance_set(_inst, "encounter_skin_warned", true);
            var _base_msg = "";
            if (variable_global_exists("PKICONS") && is_struct(global.PKICONS) && variable_struct_exists(global.PKICONS, "icon32_base")) _base_msg = string(variable_struct_get(global.PKICONS, "icon32_base"));
            show_debug_message("[overworld encounter] Missing overworld skin for species " + string(_species_id) + " in " + _base_msg + "; using placeholder.");
        }
    }

    if (sprite_exists(_spr)){
        var _old_spr = variable_instance_exists(_inst, "sprite_index") ? variable_instance_get(_inst, "sprite_index") : -1;
        variable_instance_set(_inst, "sprite_index", _spr);
        if (_old_spr != _spr) variable_instance_set(_inst, "image_index", 0);
        variable_instance_set(_inst, "image_speed", _moving ? 0.18 : 0);
        if (!_moving) variable_instance_set(_inst, "image_index", 0);
        variable_instance_set(_inst, "image_xscale", 0.67);
        variable_instance_set(_inst, "image_yscale", 0.67);
        variable_instance_set(_inst, "mask_index", _spr);
    }
    variable_instance_set(_inst, "depth", -(variable_instance_get(_inst, "y") + 16));
}

function __overworld_encounter_pokemon_npc_rect_clear(_inst, _x, _y){
    if (!instance_exists(_inst)) return false;
    var _owner = variable_instance_exists(_inst, "encounter_owner") ? variable_instance_get(_inst, "encounter_owner") : noone;
    var _arr = [];
    if (instance_exists(_owner) && variable_instance_exists(_owner, "_encounter_visible_npcs") && is_array(variable_instance_get(_owner, "_encounter_visible_npcs"))){
        _arr = variable_instance_get(_owner, "_encounter_visible_npcs");
    }

    for (var _i = 0; _i < array_length(_arr); ++_i){
        var _other = _arr[_i];
        if (_other == noone || _other == _inst || !instance_exists(_other)) continue;
        var _probe = __overworld_encounter_pokemon_npc_bounds(_inst, _x, _y);
        var _other_bounds = __overworld_encounter_pokemon_npc_bounds(_other, variable_instance_get(_other, "x"), variable_instance_get(_other, "y"));
        if (__overworld_rects_intersect(_probe.left, _probe.top, _probe.right, _probe.bottom, _other_bounds.left, _other_bounds.top, _other_bounds.right, _other_bounds.bottom)) return false;
    }
    return true;
}

function __overworld_encounter_pokemon_npc_pick_target(_inst){
    var _left = variable_instance_get(_inst, "encounter_bounds_left");
    var _top = variable_instance_get(_inst, "encounter_bounds_top");
    var _right = max(_left, variable_instance_get(_inst, "encounter_bounds_right"));
    var _bottom = max(_top, variable_instance_get(_inst, "encounter_bounds_bottom"));
    var _grid = variable_instance_exists(_inst, "encounter_grid_size") ? max(1, floor(variable_instance_get(_inst, "encounter_grid_size"))) : 32;
    var _cells_x = max(0, floor((_right - _left) / _grid));
    var _cells_y = max(0, floor((_bottom - _top) / _grid));
    var _cur_x = variable_instance_get(_inst, "x");
    var _cur_y = variable_instance_get(_inst, "y");
    var _next_x = _left;
    var _next_y = _top;
    for (var _try = 0; _try < 16; ++_try){
        _next_x = _left + irandom(_cells_x) * _grid;
        _next_y = _top + irandom(_cells_y) * _grid;
        if (_cells_x <= 0 && _cells_y <= 0) break;
        if ((_next_x != _cur_x || _next_y != _cur_y) && __overworld_encounter_pokemon_npc_rect_clear(_inst, _next_x, _next_y)) break;
    }
    if (!__overworld_encounter_pokemon_npc_rect_clear(_inst, _next_x, _next_y)){
        _next_x = _cur_x;
        _next_y = _cur_y;
    }
    variable_instance_set(_inst, "wander_target_x", _next_x);
    variable_instance_set(_inst, "wander_target_y", _next_y);
}

function __overworld_encounter_pokemon_npc_start_battle(_inst, _trigger_pid){
    if (!instance_exists(_inst)) return false;
    if (!overworld_encounter_can_start(_trigger_pid)) return false;

    var _owner = variable_instance_exists(_inst, "encounter_owner") ? variable_instance_get(_inst, "encounter_owner") : noone;
    if (!instance_exists(_owner)) return false;
    overworld_encounter_init(_owner);

    var _p1_vis = player_by_pid(1);
    var _inst_coop_vis = (variable_instance_exists(_owner, "encounter_coop_enabled") && variable_instance_get(_owner, "encounter_coop_enabled") == true);
    var _coop_vis = multiplayer_should_start_coop_for_pid(_trigger_pid, _inst_coop_vis);
    if (_coop_vis && _p1_vis == noone) _coop_vis = false;
    if (_coop_vis && (!overworld_encounter_can_start(0) || !overworld_encounter_can_start(1))) return false;

    var _battle_format_vis = string(variable_instance_get(_owner, "encounter_battle_format"));
    if (_battle_format_vis != "double") _battle_format_vis = "single";
    var _double_chance_vis = variable_instance_exists(_owner, "encounter_double_chance") ? real(variable_instance_get(_owner, "encounter_double_chance")) : 0;
    if (_battle_format_vis != "double" && _double_chance_vis > 0 && random(1) < _double_chance_vis) _battle_format_vis = "double";

    var _level_min_vis = max(1, floor(variable_instance_get(_owner, "encounter_level_min")));
    var _level_max_vis = max(_level_min_vis, floor(variable_instance_get(_owner, "encounter_level_max")));
    var _species_vis = variable_instance_get(_inst, "encounter_species_id");
    var _levels_vis = variable_instance_get(_inst, "encounter_level");
    var _shinies_vis = variable_instance_exists(_inst, "encounter_shiny") && variable_instance_get(_inst, "encounter_shiny") == true;

    if (_battle_format_vis == "double"){
        var _second = __overworld_encounter_roll(_owner, "single", _level_min_vis, _level_max_vis);
        var _species_b = _species_vis;
        var _level_b = _levels_vis;
        var _shiny_b = __overworld_encounter_roll_shiny(_owner);
        if (is_struct(_second)){
            var _second_species = variable_struct_get(_second, "species");
            var _second_levels = variable_struct_get(_second, "levels");
            if (is_real(_second_species)) _species_b = _second_species;
            if (is_real(_second_levels)) _level_b = _second_levels;
        }
        _species_vis = [_species_vis, _species_b];
        _levels_vis = [_levels_vis, _level_b];
        _shinies_vis = [_shinies_vis, _shiny_b];
    }

    var _E_lock_vis = overworld_encounter_tables_init();
    variable_struct_set(_E_lock_vis, "pending", true);
    global.OVERWORLD_ENCOUNTERS = _E_lock_vis;

    var _opts_vis = {
        battle_type: "wild",
        battle_format: _battle_format_vis,
        enemy_species: _species_vis,
        enemy_levels: _levels_vis,
        enemy_shiny: _shinies_vis,
        encounter_region_key: string(variable_instance_get(_owner, "encounter_region_key")),
        encounter_habitat: string(variable_instance_get(_owner, "encounter_habitat")),
        encounter_source: "visible_bush_npc"
    };
    if (_coop_vis){
        _opts_vis.coop_enabled = true;
        _opts_vis.player_pids = [0, 1];
        _trigger_pid = 0;
    }

    var _open_level_vis = is_array(_levels_vis) ? _levels_vis[0] : _levels_vis;
    battle_open(_trigger_pid, _open_level_vis, string(variable_instance_get(_owner, "encounter_area_type")), _opts_vis);
    if (!is_undefined(battle_is_open) && !battle_is_open(_trigger_pid)){
        var _E_unlock_vis = overworld_encounter_tables_init();
        variable_struct_set(_E_unlock_vis, "pending", false);
        global.OVERWORLD_ENCOUNTERS = _E_unlock_vis;
        return false;
    }

    __overworld_encounter_remove_visible_npc(_owner, _inst, true);
    variable_instance_set(_owner, "encounter_cooldown", variable_instance_get(_owner, "encounter_cooldown_frames"));
    instance_destroy(_inst);
    return true;
}

function overworld_encounter_pokemon_npc_step(_inst){
    if (!instance_exists(_inst)) return false;

    var _owner = variable_instance_exists(_inst, "encounter_owner") ? variable_instance_get(_inst, "encounter_owner") : noone;
    if (!instance_exists(_owner)){
        instance_destroy(_inst);
        return false;
    }
    if (variable_instance_exists(_owner, "encounter_visible_camera_only") && variable_instance_get(_owner, "encounter_visible_camera_only") == true && !__overworld_encounter_in_camera(_owner, 48)){
        __overworld_encounter_remove_visible_npc(_owner, _inst, true);
        instance_destroy(_inst);
        return false;
    }

    var _life = variable_instance_exists(_inst, "encounter_lifetime") ? floor(variable_instance_get(_inst, "encounter_lifetime")) : 0;
    _life -= 1;
    variable_instance_set(_inst, "encounter_lifetime", _life);
    var _fade = variable_instance_exists(_inst, "encounter_fade_frames") ? max(1, floor(variable_instance_get(_inst, "encounter_fade_frames"))) : 45;
    variable_instance_set(_inst, "image_alpha", clamp(_life / _fade, 0, 1));
    if (_life <= 0){
        __overworld_encounter_remove_visible_npc(_owner, _inst, true);
        instance_destroy(_inst);
        return false;
    }

    var _p0_vis = player_by_pid(0);
    var _p1_vis = player_by_pid(1);
    var _players_vis = [_p0_vis, _p1_vis];
    for (var _vi = 0; _vi < array_length(_players_vis); ++_vi){
        var _pl_vis = _players_vis[_vi];
        if (_pl_vis == noone) continue;
        var _pid_vis = variable_instance_exists(_pl_vis, "pid") ? variable_instance_get(_pl_vis, "pid") : _vi;
        if (__overworld_encounter_visible_player_hit(_inst, _pl_vis)){
            if (__overworld_encounter_pokemon_npc_start_battle(_inst, _pid_vis)) return true;
        }
    }

    var _pause = variable_instance_exists(_inst, "wander_pause") ? floor(variable_instance_get(_inst, "wander_pause")) : 0;
    if (_pause > 0){
        variable_instance_set(_inst, "wander_pause", _pause - 1);
        __overworld_encounter_pokemon_npc_sprite_update(_inst, false);
        return false;
    }

    var _x = variable_instance_get(_inst, "x");
    var _y = variable_instance_get(_inst, "y");
    var _tx = variable_instance_exists(_inst, "wander_target_x") ? variable_instance_get(_inst, "wander_target_x") : _x;
    var _ty = variable_instance_exists(_inst, "wander_target_y") ? variable_instance_get(_inst, "wander_target_y") : _y;
    var _speed = variable_instance_exists(_inst, "wander_speed") ? max(0.05, real(variable_instance_get(_inst, "wander_speed"))) : 0.35;
    var _dist = point_distance(_x, _y, _tx, _ty);
    if (_dist <= _speed){
        variable_instance_set(_inst, "x", _tx);
        variable_instance_set(_inst, "y", _ty);
        __overworld_encounter_pokemon_npc_pick_target(_inst);
        var _min_pause = variable_instance_exists(_inst, "wander_pause_min") ? floor(variable_instance_get(_inst, "wander_pause_min")) : 20;
        var _max_pause = variable_instance_exists(_inst, "wander_pause_max") ? max(_min_pause, floor(variable_instance_get(_inst, "wander_pause_max"))) : 70;
        variable_instance_set(_inst, "wander_pause", irandom_range(_min_pause, _max_pause));
        __overworld_encounter_pokemon_npc_sprite_update(_inst, false);
        return true;
    }

    var _ang = point_direction(_x, _y, _tx, _ty);
    var _nx = _x + lengthdir_x(_speed, _ang);
    var _ny = _y + lengthdir_y(_speed, _ang);
    var _left = variable_instance_get(_inst, "encounter_bounds_left");
    var _top = variable_instance_get(_inst, "encounter_bounds_top");
    var _right = max(_left, variable_instance_get(_inst, "encounter_bounds_right"));
    var _bottom = max(_top, variable_instance_get(_inst, "encounter_bounds_bottom"));
    _nx = clamp(_nx, _left, _right);
    _ny = clamp(_ny, _top, _bottom);
    if (!__overworld_encounter_pokemon_npc_rect_clear(_inst, _nx, _ny)){
        __overworld_encounter_pokemon_npc_pick_target(_inst);
        var _block_min_pause = variable_instance_exists(_inst, "wander_pause_min") ? floor(variable_instance_get(_inst, "wander_pause_min")) : 20;
        var _block_max_pause = variable_instance_exists(_inst, "wander_pause_max") ? max(_block_min_pause, floor(variable_instance_get(_inst, "wander_pause_max"))) : 70;
        variable_instance_set(_inst, "wander_pause", irandom_range(max(4, _block_min_pause div 2), max(4, _block_max_pause div 2)));
        __overworld_encounter_pokemon_npc_sprite_update(_inst, false);
        return false;
    }
    variable_instance_set(_inst, "x", _nx);
    variable_instance_set(_inst, "y", _ny);
    if (abs(lengthdir_x(1, _ang)) > abs(lengthdir_y(1, _ang))) variable_instance_set(_inst, "encounter_dir", (lengthdir_x(1, _ang) < 0) ? "LEFT" : "RIGHT");
    else variable_instance_set(_inst, "encounter_dir", (lengthdir_y(1, _ang) < 0) ? "UP" : "DOWN");
    __overworld_encounter_pokemon_npc_sprite_update(_inst, true);
    return true;
}

function overworld_encounter_draw(_inst){
    if (!instance_exists(_inst)) return false;
    if (__overworld_encounter_mode_for(_inst) == "old") return false;
    if (!variable_instance_exists(_inst, "_encounter_visible")) return false;
    var _mon = variable_instance_get(_inst, "_encounter_visible");
    if (!is_struct(_mon)) return false;

    var _draw_mon = {
        species_id: variable_struct_get(_mon, "species_id"),
        shiny: (variable_struct_exists(_mon, "shiny") && variable_struct_get(_mon, "shiny") == true)
    };
    var _dir = variable_struct_exists(_mon, "dir") ? string(variable_struct_get(_mon, "dir")) : "DOWN";
    var _spr = -1;
    if (!is_undefined(pkicons_get_overworld_dir_by_mon)) _spr = pkicons_get_overworld_dir_by_mon(_draw_mon, _dir);
    else if (!is_undefined(pkicons_get_icon32_dir_by_mon)) _spr = pkicons_get_icon32_dir_by_mon(_draw_mon, _dir);
    var _sub = variable_struct_exists(_mon, "anim") && is_real(variable_struct_get(_mon, "anim")) ? floor(variable_struct_get(_mon, "anim")) : 0;
    var _x = real(variable_struct_get(_mon, "x"));
    var _y = real(variable_struct_get(_mon, "y"));
    draw_set_alpha(0.25);
    draw_ellipse_color(_x - 7, _y + 6, _x + 7, _y + 10, c_black, c_black, false);
    draw_set_alpha(1);
    if (sprite_exists(_spr)){
        draw_sprite_ext(_spr, _sub mod max(1, sprite_get_number(_spr)), _x - 16, _y - 24, 0.67, 0.67, 0, c_white, 1);
    } else {
        draw_set_color(c_white);
        draw_rectangle(_x - 6, _y - 11, _x + 6, _y, false);
    }
    return true;
}

function __overworld_encounter_player_inside(_inst, _pl){
    if (!instance_exists(_inst) || !instance_exists(_pl)) return false;

    var _px = variable_instance_get(_pl, "x");
    var _py = variable_instance_get(_pl, "y");
    var _left = variable_instance_exists(_inst, "bbox_left") ? variable_instance_get(_inst, "bbox_left") : (variable_instance_get(_inst, "x") - variable_instance_get(_inst, "encounter_radius"));
    var _top = variable_instance_exists(_inst, "bbox_top") ? variable_instance_get(_inst, "bbox_top") : (variable_instance_get(_inst, "y") - variable_instance_get(_inst, "encounter_radius"));
    var _right = variable_instance_exists(_inst, "bbox_right") ? variable_instance_get(_inst, "bbox_right") : (variable_instance_get(_inst, "x") + variable_instance_get(_inst, "encounter_radius"));
    var _bottom = variable_instance_exists(_inst, "bbox_bottom") ? variable_instance_get(_inst, "bbox_bottom") : (variable_instance_get(_inst, "y") + variable_instance_get(_inst, "encounter_radius"));

    if (variable_instance_exists(_pl, "bbox_left") && variable_instance_exists(_pl, "bbox_top") && variable_instance_exists(_pl, "bbox_right") && variable_instance_exists(_pl, "bbox_bottom")){
        var _pl_left = variable_instance_get(_pl, "bbox_left");
        var _pl_top = variable_instance_get(_pl, "bbox_top");
        var _pl_right = variable_instance_get(_pl, "bbox_right");
        var _pl_bottom = variable_instance_get(_pl, "bbox_bottom");
        if (_pl_right >= _left && _pl_left <= _right && _pl_bottom >= _top && _pl_top <= _bottom) return true;
        return false;
    }

    if (point_in_rectangle(_px, _py, _left, _top, _right, _bottom)) return true;
    return point_distance(_px, _py, variable_instance_get(_inst, "x"), variable_instance_get(_inst, "y")) <= variable_instance_get(_inst, "encounter_radius");
}

function overworld_encounter_tables_init(){
    if (!variable_global_exists("OVERWORLD_ENCOUNTERS") || !is_struct(global.OVERWORLD_ENCOUNTERS)){
        global.OVERWORLD_ENCOUNTERS = {
            tables: {},
            defaults_seeded: false,
            pending: false
        };
    }

    var _E = global.OVERWORLD_ENCOUNTERS;
    if (!variable_struct_exists(_E, "tables") || !is_struct(variable_struct_get(_E, "tables"))) variable_struct_set(_E, "tables", {});
    if (!variable_struct_exists(_E, "defaults_seeded")) variable_struct_set(_E, "defaults_seeded", false);
    if (!variable_struct_exists(_E, "pending")) variable_struct_set(_E, "pending", false);

    if (!variable_struct_get(_E, "defaults_seeded")){
        var _tables_seed = variable_struct_get(_E, "tables");
        var _demo_route_1 = variable_struct_exists(_tables_seed, "demo_route_1") ? variable_struct_get(_tables_seed, "demo_route_1") : {};
        if (!is_struct(_demo_route_1)) _demo_route_1 = {};

        variable_struct_set(_demo_route_1, "grass", [
            { species_id: 17,  weight: 30, min_level: 3, max_level: 6 },
            { species_id: 188, weight: 25, min_level: 4, max_level: 7 },
            { species_id: 268, weight: 20, min_level: 4, max_level: 8 },
            { species_id: 559, weight: 15, min_level: 5, max_level: 8 },
            { species_id: 471, weight: 10, min_level: 6, max_level: 9 }
        ]);
        variable_struct_set(_demo_route_1, "bush", [
            { species_id: 17,  weight: 26, min_level: 3, max_level: 6 },
            { species_id: 188, weight: 28, min_level: 4, max_level: 7 },
            { species_id: 268, weight: 24, min_level: 4, max_level: 8 },
            { species_id: 559, weight: 14, min_level: 5, max_level: 8 },
            { species_id: 471, weight: 8,  min_level: 6, max_level: 9 }
        ]);

        variable_struct_set(_tables_seed, "demo_route_1", _demo_route_1);
        variable_struct_set(_E, "tables", _tables_seed);
        variable_struct_set(_E, "defaults_seeded", true);
    }

    global.OVERWORLD_ENCOUNTERS = _E;
    return _E;
}

function overworld_encounter_register_table(_region_key, _habitat_key, _entries){
    var _E = overworld_encounter_tables_init();
    var _tables = variable_struct_get(_E, "tables");
    var _region = string_lower(string(_region_key));
    var _habitat = string_lower(string(_habitat_key));
    if (string_length(_region) <= 0) _region = "default";
    if (string_length(_habitat) <= 0) _habitat = "grass";

    var _region_tables = variable_struct_exists(_tables, _region) ? variable_struct_get(_tables, _region) : {};
    if (!is_struct(_region_tables)) _region_tables = {};
    variable_struct_set(_region_tables, _habitat, is_array(_entries) ? _entries : []);
    variable_struct_set(_tables, _region, _region_tables);
    variable_struct_set(_E, "tables", _tables);
    global.OVERWORLD_ENCOUNTERS = _E;
    return _entries;
}

function __overworld_encounter_table_for(_region_key, _habitat_key){
    var _E = overworld_encounter_tables_init();
    var _tables = variable_struct_get(_E, "tables");
    var _region = string_lower(string(_region_key));
    var _habitat = string_lower(string(_habitat_key));
    if (string_length(_region) <= 0) _region = "default";
    if (string_length(_habitat) <= 0) _habitat = "grass";

    var _region_tables = variable_struct_exists(_tables, _region) ? variable_struct_get(_tables, _region) : undefined;
    if (!is_struct(_region_tables) && _region != "default") _region_tables = variable_struct_exists(_tables, "default") ? variable_struct_get(_tables, "default") : undefined;
    if (!is_struct(_region_tables)) return [];

    var _table = variable_struct_exists(_region_tables, _habitat) ? variable_struct_get(_region_tables, _habitat) : undefined;
    if (!is_array(_table) && _habitat != "grass" && variable_struct_exists(_region_tables, "grass")) _table = variable_struct_get(_region_tables, "grass");
    return is_array(_table) ? _table : [];
}

function __overworld_encounter_pick_from_table(_table, _level_min, _level_max){
    if (!is_array(_table) || array_length(_table) <= 0) return undefined;

    var _total_weight = 0;
    for (var _wi = 0; _wi < array_length(_table); ++_wi){
        var _entry_weight = _table[_wi];
        if (!is_struct(_entry_weight)) continue;
        var _weight = (variable_struct_exists(_entry_weight, "weight") && is_real(variable_struct_get(_entry_weight, "weight"))) ? max(0, floor(variable_struct_get(_entry_weight, "weight"))) : 1;
        _total_weight += _weight;
    }
    if (_total_weight <= 0) return undefined;

    var _roll = irandom(max(0, _total_weight - 1));
    var _chosen = undefined;
    for (var _ci = 0; _ci < array_length(_table); ++_ci){
        var _entry = _table[_ci];
        if (!is_struct(_entry)) continue;
        var _entry_weight_pick = (variable_struct_exists(_entry, "weight") && is_real(variable_struct_get(_entry, "weight"))) ? max(0, floor(variable_struct_get(_entry, "weight"))) : 1;
        if (_roll < _entry_weight_pick){
            _chosen = _entry;
            break;
        }
        _roll -= _entry_weight_pick;
    }
    if (!is_struct(_chosen)) return undefined;

    var _species_id = -1;
    if (variable_struct_exists(_chosen, "species_id") && is_real(variable_struct_get(_chosen, "species_id"))) _species_id = floor(variable_struct_get(_chosen, "species_id"));
    else if (variable_struct_exists(_chosen, "id") && is_real(variable_struct_get(_chosen, "id"))) _species_id = floor(variable_struct_get(_chosen, "id"));
    else if (variable_struct_exists(_chosen, "species") && is_real(variable_struct_get(_chosen, "species"))) _species_id = floor(variable_struct_get(_chosen, "species"));
    if (_species_id < 0) return undefined;

    var _entry_level_min = (variable_struct_exists(_chosen, "min_level") && is_real(variable_struct_get(_chosen, "min_level"))) ? max(1, floor(variable_struct_get(_chosen, "min_level"))) : max(1, floor(_level_min));
    var _entry_level_max = (variable_struct_exists(_chosen, "max_level") && is_real(variable_struct_get(_chosen, "max_level"))) ? max(_entry_level_min, floor(variable_struct_get(_chosen, "max_level"))) : max(_entry_level_min, floor(_level_max));
    _entry_level_min = max(_entry_level_min, max(1, floor(_level_min)));
    _entry_level_max = min(_entry_level_max, max(_entry_level_min, floor(_level_max)));

    return {
        species_id: _species_id,
        level: irandom_range(_entry_level_min, _entry_level_max)
    };
}

function __overworld_encounter_roll(_inst, _battle_format, _level_min, _level_max){
    if (!instance_exists(_inst)) return undefined;

    var _table = undefined;
    if (variable_instance_exists(_inst, "encounter_table") && is_array(variable_instance_get(_inst, "encounter_table"))) _table = variable_instance_get(_inst, "encounter_table");
    else _table = __overworld_encounter_table_for(variable_instance_get(_inst, "encounter_region_key"), variable_instance_get(_inst, "encounter_habitat"));
    if (!is_array(_table) || array_length(_table) <= 0) return undefined;

    var _count = (string_lower(string(_battle_format)) == "double") ? 2 : 1;
    var _species = [];
    var _levels = [];
    for (var _ri = 0; _ri < _count; ++_ri){
        var _pick = __overworld_encounter_pick_from_table(_table, _level_min, _level_max);
        if (!is_struct(_pick)) return undefined;
        array_push(_species, variable_struct_get(_pick, "species_id"));
        array_push(_levels, variable_struct_get(_pick, "level"));
    }

    return {
        species: (_count == 1) ? _species[0] : _species,
        levels: (_count == 1) ? _levels[0] : _levels
    };
}

function overworld_encounter_can_start(_pid){
    if (!variable_global_exists("OVERWORLD_ENCOUNTER_GRACE_MS")) global.OVERWORLD_ENCOUNTER_GRACE_MS = 1500;
    if (!variable_global_exists("OVERWORLD_ENCOUNTER_BLOCK_UNTIL_MS")) global.OVERWORLD_ENCOUNTER_BLOCK_UNTIL_MS = 0;
    if (current_time < global.OVERWORLD_ENCOUNTER_BLOCK_UNTIL_MS) return false;
    if (!is_undefined(dialog2p_is_open) && dialog2p_is_open(_pid)) return false;
    var _E = overworld_encounter_tables_init();
    if (variable_struct_exists(_E, "pending") && variable_struct_get(_E, "pending") == true){
        if (!is_undefined(battle_any_open) && battle_any_open()) return false;
        variable_struct_set(_E, "pending", false);
        global.OVERWORLD_ENCOUNTERS = _E;
    }
    if (variable_global_exists("sys_battles") && is_array(global.sys_battles)){
        for (var _bi = 0; _bi < array_length(global.sys_battles); ++_bi){
            var _slot = global.sys_battles[_bi];
            if (!is_struct(_slot)) continue;
            if (variable_struct_exists(_slot, "sys_open") && variable_struct_get(_slot, "sys_open") == true) return false;
        }
    }
    if (!is_undefined(bag_is_open) && bag_is_open(_pid)) return false;
    if (!is_undefined(poke_index_is_open) && poke_index_is_open(_pid)) return false;
    if (!is_undefined(pause_is_open) && pause_is_open(_pid)) return false;
    if (!is_undefined(party_is_open) && party_is_open(_pid)) return false;
    if (!is_undefined(pc_is_open) && pc_is_open(_pid)) return false;
    return true;
}

function overworld_encounter_step(_inst){
    if (!instance_exists(_inst)) return false;
    overworld_encounter_init(_inst);
    if (variable_instance_get(_inst, "encounter_enabled") != true) return false;

    if (__overworld_encounter_mode_for(_inst) != "old"){
        if (!__overworld_encounter_is_area_anchor(_inst)){
            if (__overworld_encounter_visible_npc_alive(_inst)){
                var _non_anchor_npcs = variable_instance_get(_inst, "_encounter_visible_npcs");
                __overworld_encounter_clear_visible_npc(_inst, true);
                for (var _na = 0; _na < array_length(_non_anchor_npcs); ++_na){
                    if (instance_exists(_non_anchor_npcs[_na])) instance_destroy(_non_anchor_npcs[_na]);
                }
            }
            return false;
        }
        if (variable_instance_exists(_inst, "encounter_visible_camera_only") && variable_instance_get(_inst, "encounter_visible_camera_only") == true && !__overworld_encounter_in_camera(_inst, 8)){
            if (__overworld_encounter_visible_npc_alive(_inst)){
                var _off_npcs = variable_instance_get(_inst, "_encounter_visible_npcs");
                __overworld_encounter_clear_visible_npc(_inst, true);
                for (var _oa = 0; _oa < array_length(_off_npcs); ++_oa){
                    if (instance_exists(_off_npcs[_oa])) instance_destroy(_off_npcs[_oa]);
                }
            }
            return false;
        }

        __overworld_encounter_visible_npc_count(_inst);

        var _spawn_timer = variable_instance_get(_inst, "_encounter_visible_timer");
        if (_spawn_timer > 0){
            variable_instance_set(_inst, "_encounter_visible_timer", _spawn_timer - 1);
        } else {
            __overworld_encounter_visible_spawn(_inst);
        }
        return false;
    }

    var _cooldown = variable_instance_get(_inst, "encounter_cooldown");
    if (_cooldown > 0){
        variable_instance_set(_inst, "encounter_cooldown", _cooldown - 1);
        return false;
    }

    var _inst_coop = (variable_instance_exists(_inst, "encounter_coop_enabled") && variable_instance_get(_inst, "encounter_coop_enabled") == true);
    var _p0 = player_by_pid(0);
    var _p1 = player_by_pid(1);
    if (_p0 == noone) return false;
    var _coop = false;

    var _players = [_p0, _p1];
    var _inside_states = variable_instance_get(_inst, "_encounter_inside_pids");
    if (!is_array(_inside_states) || array_length(_inside_states) < 2) _inside_states = [false, false];
    var _can_trigger = false;
    var _trigger_pid = 0;
    for (var _i = 0; _i < array_length(_players); ++_i){
        var _pl = _players[_i];
        if (_pl == noone){
            if (_i < array_length(_inside_states)) _inside_states[_i] = false;
            continue;
        }
        var _pid = variable_instance_exists(_pl, "pid") ? variable_instance_get(_pl, "pid") : _i;
        var _inside_now = __overworld_encounter_player_inside(_inst, _pl);
        var _was_inside = (_i < array_length(_inside_states)) ? (_inside_states[_i] == true) : false;
        if (_i < array_length(_inside_states)) _inside_states[_i] = _inside_now;
        if (!overworld_encounter_can_start(_pid)) continue;
        if (!variable_instance_exists(_pl, "grid") || !is_struct(variable_instance_get(_pl, "grid"))) continue;
        var _grid = variable_instance_get(_pl, "grid");
        if (!variable_struct_exists(_grid, "state") || string(variable_struct_get(_grid, "state")) != "move") continue;
        if (!_inside_now || _was_inside) continue;
        _can_trigger = true;
        _trigger_pid = _pid;
        break;
    }
    variable_instance_set(_inst, "_encounter_inside_pids", _inside_states);
    if (!_can_trigger) return false;
    var _chance = variable_instance_get(_inst, "encounter_chance");
    if (variable_global_exists("BAG_FIELD_EFFECTS") && is_array(global.BAG_FIELD_EFFECTS) && _trigger_pid >= 0 && _trigger_pid < array_length(global.BAG_FIELD_EFFECTS)){
        var _field_fx = global.BAG_FIELD_EFFECTS[_trigger_pid];
        if (is_struct(_field_fx)){
            if (variable_struct_exists(_field_fx, "repel_steps") && is_real(variable_struct_get(_field_fx, "repel_steps")) && variable_struct_get(_field_fx, "repel_steps") > 0){
                variable_struct_set(_field_fx, "repel_steps", max(0, floor(variable_struct_get(_field_fx, "repel_steps")) - 1));
                global.BAG_FIELD_EFFECTS[_trigger_pid] = _field_fx;
                return false;
            }
            if (variable_struct_exists(_field_fx, "encounter_rate_steps") && is_real(variable_struct_get(_field_fx, "encounter_rate_steps")) && variable_struct_get(_field_fx, "encounter_rate_steps") > 0){
                var _mult = (variable_struct_exists(_field_fx, "encounter_rate_multiplier") && is_real(variable_struct_get(_field_fx, "encounter_rate_multiplier"))) ? real(variable_struct_get(_field_fx, "encounter_rate_multiplier")) : 1;
                _chance *= max(0, _mult);
                variable_struct_set(_field_fx, "encounter_rate_steps", max(0, floor(variable_struct_get(_field_fx, "encounter_rate_steps")) - 1));
                global.BAG_FIELD_EFFECTS[_trigger_pid] = _field_fx;
            }
        }
    }
    if (random(1) > _chance) return false;

    _coop = multiplayer_should_start_coop_for_pid(_trigger_pid, _inst_coop);
    if (_coop && _p1 == noone) _coop = false;
    if (_coop && (!overworld_encounter_can_start(0) || !overworld_encounter_can_start(1))) return false;

    var _E_lock = overworld_encounter_tables_init();
    variable_struct_set(_E_lock, "pending", true);
    global.OVERWORLD_ENCOUNTERS = _E_lock;
    variable_instance_set(_inst, "encounter_cooldown", variable_instance_get(_inst, "encounter_cooldown_frames"));
    var _level_min = max(1, floor(variable_instance_get(_inst, "encounter_level_min")));
    var _level_max = max(_level_min, floor(variable_instance_get(_inst, "encounter_level_max")));
    var _battle_format = string(variable_instance_get(_inst, "encounter_battle_format"));
    var _double_chance = variable_instance_exists(_inst, "encounter_double_chance") ? real(variable_instance_get(_inst, "encounter_double_chance")) : 0;
    if (_battle_format != "double" && _double_chance > 0 && random(1) < _double_chance) _battle_format = "double";
    var _encounter_roll = __overworld_encounter_roll(_inst, _battle_format, _level_min, _level_max);
    var _opts = {
        battle_type: "wild",
        battle_format: _battle_format,
        encounter_region_key: string(variable_instance_get(_inst, "encounter_region_key")),
        encounter_habitat: string(variable_instance_get(_inst, "encounter_habitat"))
    };
    var _open_level = irandom_range(_level_min, _level_max);
    if (is_struct(_encounter_roll)){
        variable_struct_set(_opts, "enemy_species", variable_struct_get(_encounter_roll, "species"));
        variable_struct_set(_opts, "enemy_levels", variable_struct_get(_encounter_roll, "levels"));
        var _old_shiny_chance = variable_instance_exists(_inst, "encounter_shiny_chance") ? real(variable_instance_get(_inst, "encounter_shiny_chance")) : 0;
        if (variable_instance_exists(_inst, "encounter_visible_shiny_chance")) _old_shiny_chance = real(variable_instance_get(_inst, "encounter_visible_shiny_chance"));
        if (_old_shiny_chance > 0){
            var _old_species = variable_struct_get(_encounter_roll, "species");
            if (is_array(_old_species)){
                var _old_shinies = [];
                for (var _oshi = 0; _oshi < array_length(_old_species); ++_oshi) array_push(_old_shinies, random(1) < _old_shiny_chance);
                variable_struct_set(_opts, "enemy_shiny", _old_shinies);
            } else {
                variable_struct_set(_opts, "enemy_shiny", random(1) < _old_shiny_chance);
            }
        }
        if (!is_array(variable_struct_get(_encounter_roll, "levels")) && is_real(variable_struct_get(_encounter_roll, "levels"))) _open_level = max(1, floor(variable_struct_get(_encounter_roll, "levels")));
    }
    if (_coop){
        _opts.coop_enabled = true;
        _opts.player_pids = [0, 1];
        _trigger_pid = 0;
    }
    battle_open(_trigger_pid, _open_level, string(variable_instance_get(_inst, "encounter_area_type")), _opts);
    if (!is_undefined(battle_is_open) && battle_is_open(_trigger_pid)) return true;

    var _E_unlock = overworld_encounter_tables_init();
    variable_struct_set(_E_unlock, "pending", false);
    global.OVERWORLD_ENCOUNTERS = _E_unlock;
    return false;
}
