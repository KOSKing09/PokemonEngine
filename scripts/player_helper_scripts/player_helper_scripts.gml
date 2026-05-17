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

function player_force_stand_still(_inst){
    if (!instance_exists(_inst)) return false;
    if (variable_instance_exists(_inst, "grid") && is_struct(variable_instance_get(_inst, "grid"))){
        var _g = variable_instance_get(_inst, "grid");
        variable_struct_set(_g, "state", "idle");
        variable_struct_set(_g, "tx", variable_instance_get(_inst, "x"));
        variable_struct_set(_g, "ty", variable_instance_get(_inst, "y"));
        variable_struct_set(_g, "buffer_dir", -1);
        variable_struct_set(_g, "buffer_ttl", 0);
        variable_instance_set(_inst, "grid", _g);
    }
    variable_instance_set(_inst, "image_speed", 0);
    variable_instance_set(_inst, "image_index", 0);
    return true;
}

function player_is_in_battle(_pid){
    if (is_undefined(battle_is_open)) return false;
    return battle_is_open(max(0, floor(_pid)));
}

function player_draw_battle_indicator(_inst){
    if (!instance_exists(_inst)) return false;
    var _pid = variable_instance_exists(_inst, "pid") ? variable_instance_get(_inst, "pid") : 0;
    if (!player_is_in_battle(_pid)) return false;

    var _x = variable_instance_get(_inst, "x");
    var _y = variable_instance_get(_inst, "y") - 34;
    var _w = 14;
    var _h = 12;
    draw_set_alpha(1);
    draw_set_color(c_white);
    draw_roundrect(_x - _w * 0.5, _y - _h, _x + _w * 0.5, _y, false);
    draw_triangle(_x - 3, _y - 1, _x + 3, _y - 1, _x, _y + 4, false);
    draw_set_color(c_black);
    draw_roundrect(_x - _w * 0.5, _y - _h, _x + _w * 0.5, _y, true);
    draw_line(_x - 3, _y - 1, _x, _y + 4);
    draw_line(_x + 3, _y - 1, _x, _y + 4);
    draw_set_halign(fa_center);
    draw_set_valign(fa_middle);
    draw_text(_x, _y - (_h * 0.5), "!");
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    return true;
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
            versus_format: "single",
            assistance_radius: 48
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

    var _assist_radius = (variable_struct_exists(_M, "assistance_radius") && is_real(variable_struct_get(_M, "assistance_radius"))) ? real(variable_struct_get(_M, "assistance_radius")) : 48;
    _assist_radius = max(8, _assist_radius);
    variable_struct_set(_M, "assistance_radius", _assist_radius);
    if (!variable_global_exists("MULTIPLAYER_ASSISTANCE_RADIUS")) global.MULTIPLAYER_ASSISTANCE_RADIUS = _assist_radius;

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

    if (!variable_struct_exists(_M, "wild_assist_request") || !is_struct(variable_struct_get(_M, "wild_assist_request"))){
        variable_struct_set(_M, "wild_assist_request", {
            active: false,
            requester_pid: -1,
            responder_pid: -1,
            prompt_shown: false,
            prompt_closed_ms: -1,
            response: "",
            choice_active: false,
            choice_sel: 0,
            open_level: 1,
            area_type: "forest",
            opts_single: undefined,
            opts_double: undefined,
            source_npc: noone,
            source_owner: noone
        });
    } else {
        var _WR = variable_struct_get(_M, "wild_assist_request");
        if (!variable_struct_exists(_WR, "active")) variable_struct_set(_WR, "active", false);
        if (!variable_struct_exists(_WR, "requester_pid") || !is_real(variable_struct_get(_WR, "requester_pid"))) variable_struct_set(_WR, "requester_pid", -1);
        if (!variable_struct_exists(_WR, "responder_pid") || !is_real(variable_struct_get(_WR, "responder_pid"))) variable_struct_set(_WR, "responder_pid", -1);
        if (!variable_struct_exists(_WR, "prompt_shown")) variable_struct_set(_WR, "prompt_shown", false);
        if (!variable_struct_exists(_WR, "prompt_closed_ms") || !is_real(variable_struct_get(_WR, "prompt_closed_ms"))) variable_struct_set(_WR, "prompt_closed_ms", -1);
        if (!variable_struct_exists(_WR, "response")) variable_struct_set(_WR, "response", "");
        if (!variable_struct_exists(_WR, "choice_active")) variable_struct_set(_WR, "choice_active", false);
        if (!variable_struct_exists(_WR, "choice_sel") || !is_real(variable_struct_get(_WR, "choice_sel"))) variable_struct_set(_WR, "choice_sel", 0);
        if (!variable_struct_exists(_WR, "open_level") || !is_real(variable_struct_get(_WR, "open_level"))) variable_struct_set(_WR, "open_level", 1);
        if (!variable_struct_exists(_WR, "area_type")) variable_struct_set(_WR, "area_type", "forest");
        if (!variable_struct_exists(_WR, "opts_single")) variable_struct_set(_WR, "opts_single", undefined);
        if (!variable_struct_exists(_WR, "opts_double")) variable_struct_set(_WR, "opts_double", undefined);
        if (!variable_struct_exists(_WR, "source_npc")) variable_struct_set(_WR, "source_npc", noone);
        if (!variable_struct_exists(_WR, "source_owner")) variable_struct_set(_WR, "source_owner", noone);
        variable_struct_set(_M, "wild_assist_request", _WR);
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
            xp_mode: "active",
            follower_enabled: false
        };
    }
    var _B = global.BATTLE_OPTIONS;
    var _xp_mode = (variable_struct_exists(_B, "xp_mode") ? string_lower(string(variable_struct_get(_B, "xp_mode"))) : "active");
    if (_xp_mode == "shared") _xp_mode = "all";
    if (_xp_mode == "last") _xp_mode = "used";
    if (_xp_mode != "used" && _xp_mode != "all") _xp_mode = "active";
    variable_struct_set(_B, "xp_mode", _xp_mode);
    if (!variable_struct_exists(_B, "follower_enabled")) variable_struct_set(_B, "follower_enabled", false);
    variable_struct_set(_B, "follower_enabled", variable_struct_get(_B, "follower_enabled") == true);
    global.BATTLE_OPTIONS = _B;
    return _B;
}

function battle_xp_load_options(){
    var _B = battle_xp_ensure_state();
    try {
        ini_open(working_directory + "/options.ini");
        var _xp_mode = string_lower(ini_read_string("Battle", "xp_mode", variable_struct_get(_B, "xp_mode")));
        var _follower_enabled = ini_read_real("Battle", "follower_enabled", variable_struct_get(_B, "follower_enabled") == true ? 1 : 0);
        ini_close();

        if (_xp_mode == "shared") _xp_mode = "all";
        if (_xp_mode == "last") _xp_mode = "used";
        if (_xp_mode != "used" && _xp_mode != "all") _xp_mode = "active";
        variable_struct_set(_B, "xp_mode", _xp_mode);
        variable_struct_set(_B, "follower_enabled", _follower_enabled >= 0.5);
    } catch (e_battle_load) {
        variable_struct_set(_B, "xp_mode", "active");
        variable_struct_set(_B, "follower_enabled", false);
    }
    global.BATTLE_OPTIONS = _B;
    return _B;
}

function battle_xp_save_options(){
    var _B = battle_xp_ensure_state();
    try {
        ini_open(working_directory + "/options.ini");
        ini_write_string("Battle", "xp_mode", string(variable_struct_get(_B, "xp_mode")));
        ini_write_real("Battle", "follower_enabled", variable_struct_get(_B, "follower_enabled") == true ? 1 : 0);
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

function battle_followers_enabled(){
    var _B = battle_xp_ensure_state();
    return variable_struct_get(_B, "follower_enabled") == true;
}

function battle_followers_set_enabled(_enabled){
    var _B = battle_xp_ensure_state();
    variable_struct_set(_B, "follower_enabled", _enabled == true);
    global.BATTLE_OPTIONS = _B;
    battle_xp_save_options();
    if (!battle_followers_enabled() && !is_undefined(pokemon_followers_clear_all)) pokemon_followers_clear_all();
    return battle_followers_enabled();
}

function battle_followers_toggle(){
    return battle_followers_set_enabled(!battle_followers_enabled());
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

function multiplayer_assistance_radius(){
    var _M = multiplayer_ensure_state();
    var _radius = variable_struct_exists(_M, "assistance_radius") ? real(variable_struct_get(_M, "assistance_radius")) : 48;
    if (variable_global_exists("MULTIPLAYER_ASSISTANCE_RADIUS") && is_real(global.MULTIPLAYER_ASSISTANCE_RADIUS)) _radius = real(global.MULTIPLAYER_ASSISTANCE_RADIUS);
    return max(8, _radius);
}

function multiplayer_find_nearby_assist_pid(_trigger_pid, _radius = undefined){
    if (multiplayer_queue_mode() != "coop") return -1;
    var _leader_pid = max(0, floor(_trigger_pid));
    var _assist_pid = (_leader_pid == 0) ? 1 : 0;
    if (!multiplayer_player_joined(_assist_pid)) return -1;

    var _leader = player_by_pid(_leader_pid);
    var _assist = player_by_pid(_assist_pid);
    if (_leader == noone || _assist == noone) return -1;

    var _r = is_undefined(_radius) ? multiplayer_assistance_radius() : max(8, real(_radius));
    var _dist = point_distance(
        variable_instance_get(_leader, "x"),
        variable_instance_get(_leader, "y"),
        variable_instance_get(_assist, "x"),
        variable_instance_get(_assist, "y")
    );
    if (_dist > _r) return -1;
    if (!overworld_encounter_can_start(_assist_pid)) return -1;
    return _assist_pid;
}

function multiplayer_find_joined_assist_pid(_trigger_pid){
    if (multiplayer_queue_mode() != "coop") return -1;
    var _leader_pid = max(0, floor(_trigger_pid));
    var _assist_pid = (_leader_pid == 0) ? 1 : 0;
    if (!multiplayer_player_joined(_assist_pid)) return -1;
    if (!overworld_encounter_can_start(_assist_pid)) return -1;
    return _assist_pid;
}

function multiplayer_clear_wild_assist_request(){
    var _M = multiplayer_ensure_state();
    var _WR = variable_struct_get(_M, "wild_assist_request");
    if (is_struct(_WR) && variable_struct_exists(_WR, "source_npc")){
        var _npc = variable_struct_get(_WR, "source_npc");
        if (_npc != noone && instance_exists(_npc)){
            try { variable_instance_set(_npc, "encounter_request_pending", false); } catch (e_req_npc_clear) {}
        }
    }
    variable_struct_set(_M, "wild_assist_request", {
        active: false,
        requester_pid: -1,
        responder_pid: -1,
        prompt_shown: false,
        prompt_closed_ms: -1,
        response: "",
        choice_active: false,
        choice_sel: 0,
        open_level: 1,
        area_type: "forest",
        opts_single: undefined,
        opts_double: undefined,
        source_npc: noone,
        source_owner: noone
    });
    global.MULTIPLAYER = _M;
    return false;
}

function multiplayer_trainer_team_select_active(){
    var _M = multiplayer_ensure_state();
    return (variable_struct_exists(_M, "trainer_team_select") && is_struct(variable_struct_get(_M, "trainer_team_select")) && variable_struct_get(variable_struct_get(_M, "trainer_team_select"), "active") == true);
}

function __multiplayer_party_usable_indexes(_pid){
    var _out = [];
    var _P = party_ensure(_pid);
    if (!is_struct(_P) || !variable_struct_exists(_P, "mons") || !is_array(variable_struct_get(_P, "mons"))) return _out;
    var _mons = variable_struct_get(_P, "mons");
    for (var _i = 0; _i < array_length(_mons); ++_i){
        var _mon = _mons[_i];
        if (!is_struct(_mon)) continue;
        if (__battle_hp_now(_mon) <= 0) continue;
        array_push(_out, _i);
    }
    return _out;
}

function __multiplayer_default_team_indexes(_pid, _count){
    var _usable = __multiplayer_party_usable_indexes(_pid);
    var _out = [];
    var _P = party_ensure(_pid);
    var _selected = -1;
    if (is_struct(_P) && variable_struct_exists(_P, "sel") && is_real(variable_struct_get(_P, "sel"))){
        _selected = floor(variable_struct_get(_P, "sel"));
        try {
            if (!is_undefined(__party_visible_to_real_index)) _selected = __party_visible_to_real_index(_pid, _selected);
        } catch (e_default_team_visible) {}
    }
    if (_selected >= 0 && __multiplayer_team_has_index(_usable, _selected)) array_push(_out, _selected);
    for (var _i = 0; _i < array_length(_usable) && array_length(_out) < _count; ++_i){
        if (__multiplayer_team_has_index(_out, _usable[_i])) continue;
        array_push(_out, _usable[_i]);
    }
    return _out;
}

function __multiplayer_team_has_index(_arr, _idx){
    if (!is_array(_arr)) return false;
    for (var _i = 0; _i < array_length(_arr); ++_i) if (_arr[_i] == _idx) return true;
    return false;
}

function __multiplayer_team_toggle_index(_arr, _idx, _max_count){
    var _out = [];
    var _removed = false;
    if (is_array(_arr)){
        for (var _i = 0; _i < array_length(_arr); ++_i){
            if (_arr[_i] == _idx){ _removed = true; continue; }
            array_push(_out, _arr[_i]);
        }
    }
    if (!_removed && array_length(_out) < _max_count) array_push(_out, _idx);
    return _out;
}

function __multiplayer_team_add_index(_arr, _idx, _max_count){
    var _out = [];
    if (is_array(_arr)){
        for (var _i = 0; _i < array_length(_arr); ++_i){
            if (_arr[_i] == _idx) return _arr;
            array_push(_out, _arr[_i]);
        }
    }
    if (array_length(_out) < _max_count) array_push(_out, _idx);
    return _out;
}

function multiplayer_begin_trainer_team_select(_requester_pid, _responder_pid, _open_level, _area_type, _opts, _source_npc = noone, _source_owner = noone){
    if (!is_struct(_opts)) return false;
    var _req = max(0, floor(_requester_pid));
    var _res = max(0, floor(_responder_pid));
    var _battle_kind = "wild";
    try {
        if (variable_struct_exists(_opts, "battle_type")) _battle_kind = string_lower(string(variable_struct_get(_opts, "battle_type")));
        else if (variable_struct_exists(_opts, "type")) _battle_kind = string_lower(string(variable_struct_get(_opts, "type")));
    } catch (e_team_kind) { _battle_kind = "wild"; }
    var _M = multiplayer_ensure_state();
    variable_struct_set(_M, "trainer_team_select", {
        active: true,
        battle_kind: _battle_kind,
        requester_pid: _req,
        responder_pid: _res,
        open_level: max(1, floor(_open_level)),
        area_type: string(_area_type),
        opts: _opts,
        source_npc: _source_npc,
        source_owner: _source_owner,
        cursor: [0, 0],
        ready: [false, false],
        selected: [__multiplayer_default_team_indexes(_req, 3), __multiplayer_default_team_indexes(_res, 3)]
    });
    global.MULTIPLAYER = _M;
    return true;
}

function multiplayer_finish_trainer_team_select(){
    var _M = multiplayer_ensure_state();
    var _TS = variable_struct_exists(_M, "trainer_team_select") ? variable_struct_get(_M, "trainer_team_select") : undefined;
    if (!is_struct(_TS) || variable_struct_get(_TS, "active") != true) return false;
    var _req = max(0, floor(variable_struct_get(_TS, "requester_pid")));
    var _res = max(0, floor(variable_struct_get(_TS, "responder_pid")));
    var _opts = variable_struct_get(_TS, "opts");
    if (!is_struct(_opts)) return false;
    var _battle_kind = variable_struct_exists(_TS, "battle_kind") ? string_lower(string(variable_struct_get(_TS, "battle_kind"))) : "wild";
    var _sel = variable_struct_get(_TS, "selected");
    var _team_req = (is_array(_sel) && array_length(_sel) > 0 && is_array(_sel[0])) ? _sel[0] : __multiplayer_default_team_indexes(_req, 3);
    var _team_res = (is_array(_sel) && array_length(_sel) > 1 && is_array(_sel[1])) ? _sel[1] : __multiplayer_default_team_indexes(_res, 3);
    if (array_length(_team_req) <= 0) _team_req = __multiplayer_default_team_indexes(_req, 3);
    if (array_length(_team_res) <= 0) _team_res = __multiplayer_default_team_indexes(_res, 3);
    variable_struct_set(_opts, "player_party_indexes", [_team_req, _team_res]);
    variable_struct_set(_opts, "player_party_limit", 3);
    variable_struct_set(_opts, "coop_enabled", true);
    variable_struct_set(_opts, "player_pids", [_req, _res]);
    variable_struct_set(_opts, "battle_format", "double");
    variable_struct_set(_TS, "active", false);
    variable_struct_set(_M, "trainer_team_select", _TS);
    global.MULTIPLAYER = _M;
    if (_battle_kind == "trainer" && !is_undefined(battle_open_trainer)) battle_open_trainer(_req, _opts);
    else battle_open(_req, max(1, floor(variable_struct_get(_TS, "open_level"))), string(variable_struct_get(_TS, "area_type")), _opts);
    if (!is_undefined(battle_is_open) && battle_is_open(_req)){
        var _src_npc = variable_struct_exists(_TS, "source_npc") ? variable_struct_get(_TS, "source_npc") : noone;
        var _src_owner = variable_struct_exists(_TS, "source_owner") ? variable_struct_get(_TS, "source_owner") : noone;
        if (_src_npc != noone || _src_owner != noone) __multiplayer_cleanup_wild_assist_source({ source_npc: _src_npc, source_owner: _src_owner });
    }
    if (!is_undefined(splitscreen_apply_gui_size)) splitscreen_apply_gui_size();
    return true;
}

function multiplayer_update_trainer_team_select(_pid){
    var _self = max(0, floor(_pid));
    var _M = multiplayer_ensure_state();
    var _TS = variable_struct_exists(_M, "trainer_team_select") ? variable_struct_get(_M, "trainer_team_select") : undefined;
    if (!is_struct(_TS) || variable_struct_get(_TS, "active") != true) return false;
    var _req = max(0, floor(variable_struct_get(_TS, "requester_pid")));
    var _res = max(0, floor(variable_struct_get(_TS, "responder_pid")));
    var _slot = (_self == _req) ? 0 : ((_self == _res) ? 1 : -1);
    if (_slot < 0) return false;
    if (!is_undefined(dialog2p_is_open) && dialog2p_is_open(_self)) return true;
    var _cursor = variable_struct_get(_TS, "cursor");
    var _ready = variable_struct_get(_TS, "ready");
    var _selected = variable_struct_get(_TS, "selected");
    if (!is_array(_cursor)) _cursor = [0, 0];
    if (!is_array(_ready)) _ready = [false, false];
    if (!is_array(_selected)) _selected = [[], []];
    var _usable = __multiplayer_party_usable_indexes(_self);
    var _max_cursor = max(0, array_length(_usable) - 1);
    if (array_length(_cursor) <= _slot) array_resize(_cursor, _slot + 1);
    if (array_length(_ready) <= _slot) array_resize(_ready, _slot + 1);
    if (array_length(_selected) <= _slot) array_resize(_selected, _slot + 1);
    if (!is_array(_selected[_slot])) _selected[_slot] = [];
    _cursor[_slot] = clamp(floor(_cursor[_slot]), 0, _max_cursor);
    var _old_cursor_slot = _cursor[_slot];
    if (controls_pressed(_self, "MoveUp")) _cursor[_slot] = max(0, _cursor[_slot] - 1);
    if (controls_pressed(_self, "MoveDown")) _cursor[_slot] = min(_max_cursor, _cursor[_slot] + 1);
    if (_old_cursor_slot != _cursor[_slot] && !is_undefined(ui_play_select_sound)) ui_play_select_sound();
    if (controls_pressed(_self, "Interact") && array_length(_usable) > 0){
        _selected[_slot] = __multiplayer_team_add_index(_selected[_slot], _usable[_cursor[_slot]], 3);
        _ready[_slot] = false;
    }
    if (controls_pressed(_self, "Back")){
        _ready[_slot] = false;
        if (array_length(_selected[_slot]) > 0) _selected[_slot] = array_delete(_selected[_slot], array_length(_selected[_slot]) - 1, 1);
    }
    if (controls_pressed(_self, "Pause") || controls_pressed(_self, "Inventory")){
        if (array_length(_selected[_slot]) > 0) _ready[_slot] = true;
    }
    variable_struct_set(_TS, "cursor", _cursor);
    variable_struct_set(_TS, "ready", _ready);
    variable_struct_set(_TS, "selected", _selected);
    variable_struct_set(_M, "trainer_team_select", _TS);
    global.MULTIPLAYER = _M;
    if (_ready[0] == true && _ready[1] == true) return multiplayer_finish_trainer_team_select();
    return true;
}

function multiplayer_draw_trainer_team_select_rect(_pid, _rx, _ry, _rw, _rh){
    var _M = multiplayer_ensure_state();
    var _TS = variable_struct_exists(_M, "trainer_team_select") ? variable_struct_get(_M, "trainer_team_select") : undefined;
    if (!is_struct(_TS) || variable_struct_get(_TS, "active") != true) return false;
    var _self = max(0, floor(_pid));
    var _req = max(0, floor(variable_struct_get(_TS, "requester_pid")));
    var _res = max(0, floor(variable_struct_get(_TS, "responder_pid")));
    var _slot = (_self == _req) ? 0 : ((_self == _res) ? 1 : -1);
    if (_slot < 0) return false;
    var _cursor = variable_struct_get(_TS, "cursor");
    var _ready = variable_struct_get(_TS, "ready");
    var _selected = variable_struct_get(_TS, "selected");
    var _usable = __multiplayer_party_usable_indexes(_self);
    var _cur = (is_array(_cursor) && array_length(_cursor) > _slot && is_real(_cursor[_slot])) ? floor(_cursor[_slot]) : 0;
    var _sel = (is_array(_selected) && array_length(_selected) > _slot && is_array(_selected[_slot])) ? _selected[_slot] : [];
    var _is_ready = (is_array(_ready) && array_length(_ready) > _slot && _ready[_slot] == true);
    draw_set_alpha(0.86);
    draw_set_color(make_color_rgb(28, 44, 56));
    draw_rectangle(_rx + 8, _ry + 8, _rx + _rw - 8, _ry + _rh - 8, false);
    draw_set_alpha(1);
    draw_set_color(make_color_rgb(222, 238, 232));
    draw_rectangle(_rx + 11, _ry + 11, _rx + _rw - 11, _ry + _rh - 11, false);
    var _font_small = variable_global_exists("FNT_POKEMON_SMALL") ? global.FNT_POKEMON_SMALL : (variable_global_exists("FNT_POKEMON") ? global.FNT_POKEMON : -1);
    if (_font_small != -1) draw_set_font(_font_small);
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_set_color(make_color_rgb(28, 44, 56));
    draw_text(_rx + 18, _ry + 21, "TAG BATTLE TEAM  " + string(array_length(_sel)) + "/3");
    var _P = party_ensure(_self);
    var _mons = (is_struct(_P) && variable_struct_exists(_P, "mons") && is_array(variable_struct_get(_P, "mons"))) ? variable_struct_get(_P, "mons") : [];
    var _row_y = _ry + 46;
    var _footer_y = _ry + _rh - 20;
    var _row_h_team = 15;
    var _max_rows_fit = max(0, floor((_footer_y - _row_y - 4) / _row_h_team));
    var _draw_rows = min(array_length(_usable), min(6, _max_rows_fit));
    for (var _i = 0; _i < _draw_rows; ++_i){
        var _idx = _usable[_i];
        var _mon = (_idx >= 0 && _idx < array_length(_mons)) ? _mons[_idx] : undefined;
        var _name = is_struct(_mon) && variable_struct_exists(_mon, "name") ? string(variable_struct_get(_mon, "name")) : ("Pokemon " + string(_idx + 1));
        var _picked = __multiplayer_team_has_index(_sel, _idx);
        var _y = _row_y + _i * _row_h_team;
        if (_i == _cur){
            draw_set_color(make_color_rgb(72, 88, 80));
            draw_rectangle(_rx + 16, _y - 1, _rx + _rw - 16, _y + 12, false);
        }
        draw_set_color((_i == _cur) ? make_color_rgb(222, 238, 232) : make_color_rgb(28, 44, 56));
        draw_text(_rx + 20, _y, (_picked ? "* " : "  ") + _name);
    }
    draw_set_color(make_color_rgb(222, 238, 232));
    draw_rectangle(_rx + 12, _footer_y - 2, _rx + _rw - 12, _ry + _rh - 12, false);
    draw_set_color(make_color_rgb(28, 44, 56));
    draw_text(_rx + 18, _footer_y, _is_ready ? "READY" : "Z/N: pick   C/B removes   Start/Tab ready");
    draw_set_alpha(1);
    draw_set_color(c_white);
    return true;
}

function multiplayer_wild_assist_request_active(){
    var _M = multiplayer_ensure_state();
    var _WR = variable_struct_get(_M, "wild_assist_request");
    return (is_struct(_WR) && variable_struct_exists(_WR, "active") && variable_struct_get(_WR, "active") == true);
}

function multiplayer_request_wild_assist_battle(_requester_pid, _responder_pid, _open_level, _area_type, _opts_single, _opts_double, _source_npc = noone, _source_owner = noone){
    var _req = max(0, floor(_requester_pid));
    var _res = max(0, floor(_responder_pid));
    if (_req == _res) return false;
    if (!multiplayer_player_joined(_res)) return false;
    if (multiplayer_battle_open()) return false;

    var _M = multiplayer_ensure_state();
    var _WR_existing = variable_struct_get(_M, "wild_assist_request");
    if (is_struct(_WR_existing) && variable_struct_exists(_WR_existing, "active") && variable_struct_get(_WR_existing, "active") == true) return false;

    if (_source_npc != noone && instance_exists(_source_npc)){
        try { variable_instance_set(_source_npc, "encounter_request_pending", true); } catch (e_req_npc_mark) {}
    }
    variable_struct_set(_M, "wild_assist_request", {
        active: true,
        requester_pid: _req,
        responder_pid: _res,
        prompt_shown: false,
        prompt_closed_ms: -1,
        response: "",
        choice_active: false,
        choice_sel: 0,
        open_level: max(1, floor(_open_level)),
        area_type: string(_area_type),
        opts_single: _opts_single,
        opts_double: _opts_double,
        source_npc: _source_npc,
        source_owner: _source_owner
    });
    global.MULTIPLAYER = _M;

    var _req_player = player_by_pid(_req);
    if (_req_player != noone && !is_undefined(player_force_stand_still)) player_force_stand_still(_req_player);
    var _res_player = player_by_pid(_res);
    if (_res_player != noone && !is_undefined(player_force_stand_still)) player_force_stand_still(_res_player);
    return true;
}

function __multiplayer_battle_opts_clone(_opts){
    var _out = {};
    if (!is_struct(_opts)) return _out;
    var _keys = variable_struct_get_names(_opts);
    for (var _i = 0; _i < array_length(_keys); ++_i){
        var _key = _keys[_i];
        variable_struct_set(_out, _key, variable_struct_get(_opts, _key));
    }
    return _out;
}

function __multiplayer_declined_assist_opts(_opts, _requester_pid){
    var _out = __multiplayer_battle_opts_clone(_opts);
    var _req = max(0, floor(_requester_pid));
    variable_struct_set(_out, "coop_enabled", false);
    variable_struct_set(_out, "battle_format", "single");
    variable_struct_set(_out, "player_pids", [_req]);
    try { if (variable_struct_exists(_out, "player_party_indexes")) variable_struct_remove(_out, "player_party_indexes"); } catch (e_decline_party_indexes) {}
    try { if (variable_struct_exists(_out, "player_party_limit")) variable_struct_remove(_out, "player_party_limit"); } catch (e_decline_party_limit) {}
    return _out;
}

function __multiplayer_cleanup_wild_assist_source(_WR){
    if (!is_struct(_WR)) return;
    var _npc = variable_struct_exists(_WR, "source_npc") ? variable_struct_get(_WR, "source_npc") : noone;
    var _owner = variable_struct_exists(_WR, "source_owner") ? variable_struct_get(_WR, "source_owner") : noone;
    if (_npc != noone && instance_exists(_npc)){
        if (_owner != noone && instance_exists(_owner) && !is_undefined(__overworld_encounter_remove_visible_npc)){
            try { __overworld_encounter_remove_visible_npc(_owner, _npc, true); } catch (e_req_remove_npc) {}
        }
        try { instance_destroy(_npc); } catch (e_req_destroy_npc) {}
    }
    if (_owner != noone && instance_exists(_owner)){
        try {
            variable_instance_set(_owner, "encounter_cooldown", variable_instance_get(_owner, "encounter_cooldown_frames"));
        } catch (e_req_owner_cd) {}
    }
}

function multiplayer_start_wild_assist_battle(_accepted){
    var _M = multiplayer_ensure_state();
    var _WR = variable_struct_get(_M, "wild_assist_request");
    if (!is_struct(_WR) || !variable_struct_exists(_WR, "active") || variable_struct_get(_WR, "active") != true) return false;

    var _requester_pid = max(0, floor(variable_struct_get(_WR, "requester_pid")));
    var _responder_pid = max(0, floor(variable_struct_get(_WR, "responder_pid")));
    var _accepted_bool = (_accepted == true);
    var _opts = _accepted_bool ? __multiplayer_battle_opts_clone(variable_struct_get(_WR, "opts_double")) : __multiplayer_declined_assist_opts(variable_struct_get(_WR, "opts_single"), _requester_pid);
    if (!is_struct(_opts)) _opts = { battle_type: "wild", battle_format: "single" };

    if (_accepted_bool){
        if (!multiplayer_player_joined(_responder_pid)){
            _accepted_bool = false;
            _opts = __multiplayer_declined_assist_opts(variable_struct_get(_WR, "opts_single"), _requester_pid);
        } else {
            variable_struct_set(_opts, "coop_enabled", true);
            variable_struct_set(_opts, "player_pids", [_requester_pid, _responder_pid]);
            variable_struct_set(_opts, "battle_format", "double");
        }
    } else {
        _opts = __multiplayer_declined_assist_opts(_opts, _requester_pid);
    }

    var _req_player = player_by_pid(_requester_pid);
    if (_req_player != noone && !is_undefined(player_force_stand_still)) player_force_stand_still(_req_player);
    if (_accepted_bool){
        var _res_player = player_by_pid(_responder_pid);
        if (_res_player != noone && !is_undefined(player_force_stand_still)) player_force_stand_still(_res_player);
    }

    var _level = max(1, floor(variable_struct_get(_WR, "open_level")));
    var _area = string(variable_struct_get(_WR, "area_type"));
    var _is_trainer_assist = false;
    try {
        _is_trainer_assist = (is_struct(_opts)
            && ((variable_struct_exists(_opts, "battle_type") && string_lower(string(variable_struct_get(_opts, "battle_type"))) == "trainer")
                || (variable_struct_exists(_opts, "type") && string_lower(string(variable_struct_get(_opts, "type"))) == "trainer")));
    } catch (e_assist_type) { _is_trainer_assist = false; }
    if (_accepted_bool){
        var _source_npc_ts = variable_struct_exists(_WR, "source_npc") ? variable_struct_get(_WR, "source_npc") : noone;
        var _source_owner_ts = variable_struct_exists(_WR, "source_owner") ? variable_struct_get(_WR, "source_owner") : noone;
        multiplayer_clear_wild_assist_request();
        return multiplayer_begin_trainer_team_select(_requester_pid, _responder_pid, _level, _area, _opts, _source_npc_ts, _source_owner_ts);
    } else if (_is_trainer_assist && !is_undefined(battle_open_trainer)) battle_open_trainer(_requester_pid, _opts);
    else battle_open(_requester_pid, _level, _area, _opts);
    var _opened = (!is_undefined(battle_is_open) && battle_is_open(_requester_pid));
    if (_opened) __multiplayer_cleanup_wild_assist_source(_WR);
    multiplayer_clear_wild_assist_request();
    if (!_opened){
        var _E_unlock_req = overworld_encounter_tables_init();
        variable_struct_set(_E_unlock_req, "pending", false);
        global.OVERWORLD_ENCOUNTERS = _E_unlock_req;
    }
    return _opened;
}

function multiplayer_update_wild_assist_request(_pid){
    var _self_pid = max(0, floor(_pid));
    var _M = multiplayer_ensure_state();
    var _WR = variable_struct_get(_M, "wild_assist_request");
    if (!is_struct(_WR) || !variable_struct_exists(_WR, "active") || variable_struct_get(_WR, "active") != true) return false;

    var _requester_pid = max(0, floor(variable_struct_get(_WR, "requester_pid")));
    var _responder_pid = max(0, floor(variable_struct_get(_WR, "responder_pid")));
    if (multiplayer_battle_open()){
        multiplayer_clear_wild_assist_request();
        return false;
    }
    if (_self_pid != _responder_pid) return false;

    if (!variable_struct_get(_WR, "prompt_shown")){
        if (!is_undefined(dialog2p_show_now)) dialog2p_show_now(_responder_pid, __multiplayer_player_label(_requester_pid) + " needs help!\nHelp in battle?");
        variable_struct_set(_WR, "prompt_shown", true);
        variable_struct_set(_WR, "prompt_closed_ms", -1);
        variable_struct_set(_WR, "response", "");
        variable_struct_set(_WR, "choice_active", false);
        variable_struct_set(_WR, "choice_sel", 0);
        variable_struct_set(_M, "wild_assist_request", _WR);
        global.MULTIPLAYER = _M;
        return true;
    }

    var _prompt_open = (!is_undefined(dialog2p_is_open) && dialog2p_is_open(_responder_pid));
    if (_prompt_open){
        variable_struct_set(_WR, "prompt_closed_ms", -1);
        variable_struct_set(_M, "wild_assist_request", _WR);
        global.MULTIPLAYER = _M;
        return true;
    }

    var _prompt_closed_ms = variable_struct_get(_WR, "prompt_closed_ms");
    if (!is_real(_prompt_closed_ms) || _prompt_closed_ms < 0){
        variable_struct_set(_WR, "prompt_closed_ms", (is_real(current_time) ? current_time + 150 : 150));
        variable_struct_set(_M, "wild_assist_request", _WR);
        global.MULTIPLAYER = _M;
        return true;
    }
    if (is_real(current_time) && current_time < _prompt_closed_ms) return true;

    var _choice_active = (variable_struct_exists(_WR, "choice_active") && variable_struct_get(_WR, "choice_active") == true);
    var _response_now = string_lower(string(variable_struct_get(_WR, "response")));
    if (!_choice_active && string_length(_response_now) <= 0){
        variable_struct_set(_WR, "choice_active", true);
        variable_struct_set(_WR, "choice_sel", 0);
        variable_struct_set(_M, "wild_assist_request", _WR);
        global.MULTIPLAYER = _M;
        return true;
    }
    if (_choice_active){
        var _sel = (variable_struct_exists(_WR, "choice_sel") && is_real(variable_struct_get(_WR, "choice_sel"))) ? floor(variable_struct_get(_WR, "choice_sel")) : 0;
        _sel = clamp(_sel, 0, 1);
        if (controls_pressed(_responder_pid, "MoveUp") || controls_pressed(_responder_pid, "MoveDown")){
            _sel = 1 - _sel;
            if (!is_undefined(ui_play_select_sound)) ui_play_select_sound();
            variable_struct_set(_WR, "choice_sel", _sel);
            variable_struct_set(_M, "wild_assist_request", _WR);
            global.MULTIPLAYER = _M;
            return true;
        }
        if (controls_pressed(_responder_pid, "Back")){
            variable_struct_set(_WR, "response", "decline");
            variable_struct_set(_WR, "choice_active", false);
            variable_struct_set(_M, "wild_assist_request", _WR);
            global.MULTIPLAYER = _M;
            return multiplayer_start_wild_assist_battle(false);
        }
        if (controls_pressed(_responder_pid, "Interact")){
            var _accepted_choice = (_sel == 0);
            variable_struct_set(_WR, "response", _accepted_choice ? "accept" : "decline");
            variable_struct_set(_WR, "choice_active", false);
            variable_struct_set(_M, "wild_assist_request", _WR);
            global.MULTIPLAYER = _M;
            return multiplayer_start_wild_assist_battle(_accepted_choice);
        }
        return true;
    }

    var _response = string_lower(string(variable_struct_get(_WR, "response")));
    return multiplayer_start_wild_assist_battle(_response == "accept");
}

function multiplayer_draw_wild_assist_choice_rect(_pid, _rx, _ry, _rw, _rh){
    var _M = multiplayer_ensure_state();
    var _WR = variable_struct_get(_M, "wild_assist_request");
    if (!is_struct(_WR) || !variable_struct_exists(_WR, "active") || variable_struct_get(_WR, "active") != true) return false;
    var _responder_pid = max(0, floor(variable_struct_get(_WR, "responder_pid")));
    if (floor(_pid) != _responder_pid) return false;
    if (!variable_struct_exists(_WR, "choice_active") || variable_struct_get(_WR, "choice_active") != true) return false;
    if (!is_undefined(dialog2p_is_open) && dialog2p_is_open(_pid)) return false;

    var _sel = (variable_struct_exists(_WR, "choice_sel") && is_real(variable_struct_get(_WR, "choice_sel"))) ? floor(variable_struct_get(_WR, "choice_sel")) : 0;
    _sel = clamp(_sel, 0, 1);
    var _x = _rx + _rw - 64;
    var _y = _ry + _rh - 74;
    var _w = 52;
    var _h = 34;
    var _scale_x = max(1, _rw / 240);
    var _scale_y = max(1, _rh / 160);
    _w *= _scale_x;
    _h *= _scale_y;

    draw_set_alpha(0.2);
    draw_set_color(c_black);
    draw_rectangle(_x + 2, _y + 2, _x + _w + 2, _y + _h + 2, false);
    draw_set_alpha(1);
    draw_set_color(make_color_rgb(72, 88, 80));
    draw_rectangle(_x, _y, _x + _w, _y + _h, false);
    draw_set_color(make_color_rgb(208, 232, 224));
    draw_rectangle(_x + 1, _y + 1, _x + _w - 1, _y + _h - 1, false);

    var _font_small = variable_global_exists("FNT_POKEMON_SMALL") ? global.FNT_POKEMON_SMALL : (variable_global_exists("FNT_POKEMON") ? global.FNT_POKEMON : -1);
    if (_font_small != -1) draw_set_font(_font_small);
    var _opts = ["YES", "NO"];
    var _row_h = 11 * _scale_y;
    var _gap = 3 * _scale_y;
    var _row_x1 = _x + 4 * _scale_x;
    var _row_x2 = _x + _w - 4 * _scale_x;
    var _row_y0 = _y + 4 * _scale_y;
    draw_set_halign(fa_center);
    draw_set_valign(fa_top);
    for (var _i = 0; _i < 2; ++_i){
        var _row_y = _row_y0 + (_i * (_row_h + _gap));
        var _hilite = (_i == _sel);
        if (_hilite){
            draw_set_color(make_color_rgb(72, 88, 80));
            draw_rectangle(_row_x1, _row_y, _row_x2, _row_y + _row_h, false);
        }
        draw_set_color(_hilite ? make_color_rgb(208, 232, 224) : make_color_rgb(36, 52, 40));
        draw_text((_row_x1 + _row_x2) * 0.5, _row_y + 2 * _scale_y + 3, _opts[_i]);
    }
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_set_alpha(1);
    return true;
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

function world_init(){
    if (!variable_global_exists("WORLD") || !is_struct(global.WORLD)){
        global.WORLD = {
            current_room: room,
            previous_room: noone,
            current_music: noone,
            current_music_asset: noone,
            room_info: {},
            pending_warp: undefined,
            route_bar: { active:false, text:"", start_ms:0, duration_ms:2200 }
        };
    }
    if (!variable_struct_exists(global.WORLD, "room_info") || !is_struct(variable_struct_get(global.WORLD, "room_info"))) variable_struct_set(global.WORLD, "room_info", {});
    if (!variable_struct_exists(global.WORLD, "pending_warp")) variable_struct_set(global.WORLD, "pending_warp", undefined);
    if (!variable_struct_exists(global.WORLD, "route_bar") || !is_struct(variable_struct_get(global.WORLD, "route_bar"))) variable_struct_set(global.WORLD, "route_bar", { active:false, text:"", start_ms:0, duration_ms:2200 });
    if (!variable_struct_exists(global.WORLD, "current_music")) variable_struct_set(global.WORLD, "current_music", noone);
    if (!variable_struct_exists(global.WORLD, "current_music_asset")) variable_struct_set(global.WORLD, "current_music_asset", noone);
    if (!variable_struct_exists(global.WORLD, "current_room")) variable_struct_set(global.WORLD, "current_room", room);
    if (!variable_struct_exists(global.WORLD, "previous_room")) variable_struct_set(global.WORLD, "previous_room", noone);
    return global.WORLD;
}

function world_room_key(_room_id){
    if (is_real(_room_id) && _room_id != noone){
        try { return room_get_name(_room_id); } catch (e_room_name) {}
    }
    return string(_room_id);
}

function world_room_display_from_name(_room_name){
    var _s = string_replace_all(string(_room_name), "_", " ");
    return string_trim(_s);
}

function world_room_name_is_indoor(_room_name){
    var _s = string_lower(string(_room_name));
    return (string_pos("house", _s) > 0 || string_pos("building", _s) > 0 || string_pos("interior", _s) > 0 || string_pos("center", _s) > 0 || string_pos("mart", _s) > 0 || string_pos("gym", _s) > 0);
}

function world_room_register(_room_id, _display_name = undefined, _music = undefined, _indoor = false){
    var _W = world_init();
    var _info = variable_struct_get(_W, "room_info");
    var _key = world_room_key(_room_id);
    var _display = is_undefined(_display_name) ? world_room_display_from_name(_key) : string(_display_name);
    variable_struct_set(_info, _key, {
        room_id: _room_id,
        display_name: _display,
        music: is_undefined(_music) ? noone : _music,
        indoor: (_indoor == true)
    });
    variable_struct_set(_W, "room_info", _info);
    global.WORLD = _W;
    return true;
}

function world_room_info(_room_id){
    var _W = world_init();
    var _info = variable_struct_get(_W, "room_info");
    var _key = world_room_key(_room_id);
    if (is_struct(_info) && variable_struct_exists(_info, _key)) return variable_struct_get(_info, _key);
    return {
        room_id: _room_id,
        display_name: world_room_display_from_name(_key),
        music: (variable_global_exists("_REGIONMUSIC") ? global._REGIONMUSIC : noone),
        indoor: world_room_name_is_indoor(_key)
    };
}

function world_show_route_bar(_text, _duration_ms = 2200){
    var _W = world_init();
    variable_struct_set(_W, "route_bar", {
        active: true,
        text: string(_text),
        start_ms: current_time,
        duration_ms: max(300, real(_duration_ms))
    });
    global.WORLD = _W;
}

function world_play_music(_snd, _loop = true){
    var _W = world_init();
    if (is_undefined(_snd) || _snd == noone || _snd == -1){
        return world_stop_room_music();
    }

    var _current_asset = variable_struct_exists(_W, "current_music_asset") ? variable_struct_get(_W, "current_music_asset") : noone;
    var _current_handle = variable_struct_exists(_W, "current_music") ? variable_struct_get(_W, "current_music") : noone;
    if (_current_asset == _snd && is_real(_current_handle) && _current_handle != noone) return true;

    world_stop_room_music();
    var _handle = noone;
    try { audio_stop_sound(_snd); } catch (e_world_stop_duplicate_music) {}
    try { _handle = audio_play_sound(_snd, 1, _loop == true); } catch (e_world_play_music) { return false; }

    _W = world_init();
    variable_struct_set(_W, "current_music", _handle);
    variable_struct_set(_W, "current_music_asset", _snd);
    global.WORLD = _W;
    return true;
}

function world_set_room_music(_room_id, _music = noone){
    var _info = world_room_info(_room_id);
    var _display = is_struct(_info) && variable_struct_exists(_info, "display_name") ? variable_struct_get(_info, "display_name") : world_room_display_from_name(world_room_key(_room_id));
    var _indoor = is_struct(_info) && variable_struct_exists(_info, "indoor") && variable_struct_get(_info, "indoor") == true;
    return world_room_register(_room_id, _display, _music, _indoor);
}

function world_stop_room_music(){
    var _W = world_init();
    var _current = variable_struct_exists(_W, "current_music") ? variable_struct_get(_W, "current_music") : noone;
    var _current_asset = variable_struct_exists(_W, "current_music_asset") ? variable_struct_get(_W, "current_music_asset") : noone;
    try { if (is_real(_current) && _current != noone) audio_stop_sound(_current); } catch (e_stop_room_music) {}
    try { if (!is_undefined(_current_asset) && _current_asset != noone && _current_asset != -1) audio_stop_sound(_current_asset); } catch (e_stop_room_music_asset) {}
    variable_struct_set(_W, "current_music", noone);
    variable_struct_set(_W, "current_music_asset", noone);
    global.WORLD = _W;
    return true;
}

function world_apply_room_music(_room_id, _override_music = undefined, _override_set = false){
    var _W = world_init();
    var _snd = noone;
    var _explicit_silence = false;

    if (_override_set == true){
        _snd = _override_music;
        _explicit_silence = (_snd == -1 || _snd == noone);
    } else {
        var _info = world_room_info(_room_id);
        _snd = (is_struct(_info) && variable_struct_exists(_info, "music")) ? variable_struct_get(_info, "music") : noone;
        if (_snd == -1) _explicit_silence = true;
        else if (_snd == noone && variable_global_exists("_REGIONMUSIC")) _snd = global._REGIONMUSIC;
    }

    if (_explicit_silence || is_undefined(_snd) || _snd == noone){
        world_stop_room_music();
        return true;
    }

    var _current_asset = variable_struct_exists(_W, "current_music_asset") ? variable_struct_get(_W, "current_music_asset") : noone;
    var _current_handle = variable_struct_exists(_W, "current_music") ? variable_struct_get(_W, "current_music") : noone;
    if (_current_asset == _snd && is_real(_current_handle) && _current_handle != noone) return true;

    world_stop_room_music();
    var _handle = noone;
    try { audio_stop_sound(_snd); } catch (e_apply_stop_duplicate_music) {}
    try { _handle = audio_play_sound(_snd, 1, true); } catch (e_play_room_music) { return false; }

    _W = world_init();
    variable_struct_set(_W, "current_music", _handle);
    variable_struct_set(_W, "current_music_asset", _snd);
    global.WORLD = _W;
    return true;
}

function world_place_player_after_warp(_pid, _x, _y, _facing = undefined){
    var _pl = player_by_pid(_pid);
    if (_pl == noone) return false;
    variable_instance_set(_pl, "x", real(_x));
    variable_instance_set(_pl, "y", real(_y));
    if (!is_undefined(_facing) && is_real(_facing)) variable_instance_set(_pl, "facing_dir", floor(_facing) mod 4);
    if (variable_instance_exists(_pl, "grid") && is_struct(variable_instance_get(_pl, "grid"))){
        var _g = variable_instance_get(_pl, "grid");
        variable_struct_set(_g, "state", "idle");
        variable_struct_set(_g, "tx", real(_x));
        variable_struct_set(_g, "ty", real(_y));
        variable_struct_set(_g, "buffer_dir", -1);
        variable_struct_set(_g, "buffer_ttl", 0);
        variable_instance_set(_pl, "grid", _g);
    }
    if (!is_undefined(player_anim_update_basic)) player_anim_update_basic(_pl, false, variable_instance_exists(_pl, "facing_dir") ? variable_instance_get(_pl, "facing_dir") : 2);
    return true;
}

function __overworld_find_npc_by_id(_npc_id){
    var _target = string(_npc_id);
    if (string_length(_target) <= 0) return noone;
    for (var _i = 0; _i < instance_number(oNpc); ++_i){
        var _npc = instance_find(oNpc, _i);
        if (_npc == noone) continue;
        if (!variable_instance_exists(_npc, "npc_id")) continue;
        if (string(variable_instance_get(_npc, "npc_id")) == _target) return _npc;
    }
    return noone;
}

function overworld_field_interaction_blocked(_pid){
    if (!is_real(_pid)) _pid = 0;
    _pid = max(0, floor(_pid));
    if (!is_undefined(bag_is_open) && bag_is_open(_pid)) return true;
    if (!is_undefined(pause_is_open) && pause_is_open(_pid)) return true;
    if (!is_undefined(party_is_open) && party_is_open(_pid)) return true;
    if (!is_undefined(pc_is_open) && pc_is_open(_pid)) return true;
    if (!is_undefined(poke_index_is_open) && poke_index_is_open(_pid)) return true;
    if (variable_global_exists("VKEYBOARD") && is_array(global.VKEYBOARD) && _pid < array_length(global.VKEYBOARD)){
        var _vk = global.VKEYBOARD[_pid];
        if (is_struct(_vk) && variable_struct_exists(_vk, "open") && variable_struct_get(_vk, "open") == true) return true;
    }
    if (!is_undefined(multiplayer_trainer_team_select_active) && multiplayer_trainer_team_select_active()) return true;
    if (!is_undefined(battle_is_open) && battle_is_open(_pid)) return true;
    if (!is_undefined(battle_any_open) && battle_any_open()) return true;
    return false;
}

function __world_room_ensure_room1_cutscene_npc(){
    if (room != Room1) return false;
    if (__overworld_find_npc_by_id("room1_bugcatcher_cutscene_test") != noone) return true;
    var _npc = instance_create_layer(208, 240, "Instances", oNpc);
    if (_npc == noone) return false;
    variable_instance_set(_npc, "npc_id", "room1_bugcatcher_cutscene_test");
    variable_instance_set(_npc, "npc_sprite_base", "spr_bugcatcher");
    variable_instance_set(_npc, "npc_facing_dir", 2);
    variable_instance_set(_npc, "trainer_enabled", false);
    variable_instance_set(_npc, "cutscene_on_interact", true);
    variable_instance_set(_npc, "cutscene_shared", true);
    variable_instance_set(_npc, "cutscene_lines", [
        "This is an overworld cutscene test.",
        "If player two is joined, both players are locked until I finish talking."
    ]);
    variable_instance_set(_npc, "dialog_text", "Talk to me to test overworld cutscenes.");
    if (!is_undefined(overworld_npc_init)) overworld_npc_init(_npc);
    return true;
}

function world_room_ensure_npcs(){
    __world_room_ensure_room1_cutscene_npc();
    for (var _i = 0; _i < instance_number(oNpc); ++_i){
        var _npc = instance_find(oNpc, _i);
        if (_npc == noone) continue;
        overworld_npc_init(_npc);
    }
    return true;
}

function world_room_apply(){
    var _W = world_init();
    var _prev = variable_struct_exists(_W, "current_room") ? variable_struct_get(_W, "current_room") : noone;
    var _pending = variable_struct_exists(_W, "pending_warp") ? variable_struct_get(_W, "pending_warp") : undefined;
    var _pending_music_override = undefined;
    var _pending_music_override_set = false;
    variable_struct_set(_W, "previous_room", _prev);
    variable_struct_set(_W, "current_room", room);
    global.WORLD = _W;

    if (is_struct(_pending)){
        var _target_room = variable_struct_exists(_pending, "room") ? variable_struct_get(_pending, "room") : noone;
        if (_target_room == room){
            var _spawn_x = variable_struct_exists(_pending, "x") ? variable_struct_get(_pending, "x") : 16;
            var _spawn_y = variable_struct_exists(_pending, "y") ? variable_struct_get(_pending, "y") : 16;
            var _facing = variable_struct_exists(_pending, "facing") ? variable_struct_get(_pending, "facing") : undefined;
            var _p2_offset_x = variable_struct_exists(_pending, "p2_offset_x") ? variable_struct_get(_pending, "p2_offset_x") : 16;
            var _p2_offset_y = variable_struct_exists(_pending, "p2_offset_y") ? variable_struct_get(_pending, "p2_offset_y") : 0;
            world_place_player_after_warp(0, _spawn_x, _spawn_y, _facing);
            if (multiplayer_player_joined(1)){
                world_place_player_after_warp(1, _spawn_x + _p2_offset_x, _spawn_y + _p2_offset_y, _facing);
            }
            _pending_music_override_set = variable_struct_exists(_pending, "music_override_set") && variable_struct_get(_pending, "music_override_set") == true;
            if (_pending_music_override_set) _pending_music_override = variable_struct_get(_pending, "music_override");
            variable_struct_set(_W, "pending_warp", undefined);
            global.WORLD = _W;
        }
    }

    if (!is_undefined(multiplayer_sync_runtime)) multiplayer_sync_runtime();
    world_room_ensure_npcs();

    world_apply_room_music(room, _pending_music_override, _pending_music_override_set);

    var _cur_info = world_room_info(room);
    var _prev_info = (_prev != noone) ? world_room_info(_prev) : undefined;
    var _show_route = false;
    if (is_struct(_pending) && variable_struct_exists(_pending, "show_route") && variable_struct_get(_pending, "show_route") == true) _show_route = true;
    if (is_struct(_cur_info) && variable_struct_get(_cur_info, "indoor") != true && is_struct(_prev_info) && variable_struct_get(_prev_info, "indoor") == true) _show_route = true;
    if (_show_route && is_struct(_cur_info)) world_show_route_bar(variable_struct_get(_cur_info, "display_name"));
    return true;
}

function world_warp_to_transition(_room_id, _spawn_x, _spawn_y, _opts = undefined, _style = undefined, _duration_ms = undefined){
    var _W = world_init();
    if (is_struct(_W) && variable_struct_exists(_W, "pending_warp") && is_struct(variable_struct_get(_W, "pending_warp"))) return true;
    if (!is_undefined(transition_is_blocking) && transition_is_blocking()) return true;
    var _facing = is_struct(_opts) && variable_struct_exists(_opts, "facing") ? variable_struct_get(_opts, "facing") : undefined;
    var _show_route = is_struct(_opts) && variable_struct_exists(_opts, "show_route") ? (variable_struct_get(_opts, "show_route") == true) : false;
    var _p2_offset_x = is_struct(_opts) && variable_struct_exists(_opts, "p2_offset_x") ? real(variable_struct_get(_opts, "p2_offset_x")) : 16;
    var _p2_offset_y = is_struct(_opts) && variable_struct_exists(_opts, "p2_offset_y") ? real(variable_struct_get(_opts, "p2_offset_y")) : 0;
    var _transition_style = is_struct(_opts) && variable_struct_exists(_opts, "transition_style") ? variable_struct_get(_opts, "transition_style") : _style;
    var _transition_duration = is_struct(_opts) && variable_struct_exists(_opts, "transition_duration_ms") ? variable_struct_get(_opts, "transition_duration_ms") : _duration_ms;
    var _music_override_set = is_struct(_opts) && variable_struct_exists(_opts, "room_music");
    var _music_override = _music_override_set ? variable_struct_get(_opts, "room_music") : undefined;
    variable_struct_set(_W, "pending_warp", {
        room: _room_id,
        x: real(_spawn_x),
        y: real(_spawn_y),
        facing: _facing,
        p2_offset_x: _p2_offset_x,
        p2_offset_y: _p2_offset_y,
        show_route: _show_route,
        music_override_set: _music_override_set,
        music_override: _music_override,
        from_room: room
    });
    global.WORLD = _W;
    world_stop_room_music();
    if (!is_undefined(transition_room_goto)) transition_room_goto(_room_id, _transition_style, _transition_duration);
    else room_goto(_room_id);
    return true;
}

function world_warp_to(_room_id, _spawn_x, _spawn_y, _opts = undefined){
    return world_warp_to_transition(_room_id, _spawn_x, _spawn_y, _opts);
}

function world_warp_player_if_in_rect(_pid, _x1, _y1, _x2, _y2, _room_id, _spawn_x, _spawn_y, _opts = undefined){
    var _pl = player_by_pid(_pid);
    if (_pl == noone) return false;
    var _left = min(_x1, _x2);
    var _top = min(_y1, _y2);
    var _right = max(_x1, _x2);
    var _bottom = max(_y1, _y2);
    var _pl_left = variable_instance_get(_pl, "bbox_left");
    var _pl_top = variable_instance_get(_pl, "bbox_top");
    var _pl_right = variable_instance_get(_pl, "bbox_right");
    var _pl_bottom = variable_instance_get(_pl, "bbox_bottom");
    if (_pl_right < _left || _pl_left > _right || _pl_bottom < _top || _pl_top > _bottom) return false;
    return world_warp_to(_room_id, _spawn_x, _spawn_y, _opts);
}

function world_draw_route_bar(){
    var _W = world_init();
    var _bar = variable_struct_get(_W, "route_bar");
    if (!is_struct(_bar) || variable_struct_get(_bar, "active") != true) return false;
    var _dur = max(1, real(variable_struct_get(_bar, "duration_ms")));
    var _p = clamp((current_time - real(variable_struct_get(_bar, "start_ms"))) / _dur, 0, 1);
    if (_p >= 1){
        variable_struct_set(_bar, "active", false);
        variable_struct_set(_W, "route_bar", _bar);
        global.WORLD = _W;
        return false;
    }
    var _gw = display_get_gui_width();
    var _text = string(variable_struct_get(_bar, "text"));
    var _alpha = (_p < 0.12) ? (_p / 0.12) : ((_p > 0.82) ? (1 - ((_p - 0.82) / 0.18)) : 1);
    var _w = min(_gw - 24, 156);
    var _h = 22;
    var _x = (_gw - _w) * 0.5;
    var _y = 10;
    draw_set_alpha(0.84 * _alpha);
    draw_set_color(c_black);
    draw_roundrect(_x + 2, _y + 2, _x + _w + 2, _y + _h + 2, false);
    draw_set_color(c_white);
    draw_roundrect(_x, _y, _x + _w, _y + _h, false);
    draw_set_alpha(_alpha);
    draw_set_color(c_black);
    draw_roundrect(_x, _y, _x + _w, _y + _h, true);
    if (variable_global_exists("FNT_POKEMON")) draw_set_font(global.FNT_POKEMON);
    draw_set_halign(fa_center);
    draw_set_valign(fa_middle);
    draw_text(_x + _w * 0.5, _y + _h * 0.5, _text);
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_set_alpha(1);
    return true;
}

function pokemon_followers_ensure_state(){
    if (!variable_global_exists("POKEMON_FOLLOWERS") || !is_struct(global.POKEMON_FOLLOWERS)){
        global.POKEMON_FOLLOWERS = {
            slots: [undefined, undefined]
        };
    }
    if (!variable_struct_exists(global.POKEMON_FOLLOWERS, "slots") || !is_array(variable_struct_get(global.POKEMON_FOLLOWERS, "slots"))){
        variable_struct_set(global.POKEMON_FOLLOWERS, "slots", [undefined, undefined]);
    }
    var _slots = variable_struct_get(global.POKEMON_FOLLOWERS, "slots");
    if (array_length(_slots) < 2) array_resize(_slots, 2);
    variable_struct_set(global.POKEMON_FOLLOWERS, "slots", _slots);
    return global.POKEMON_FOLLOWERS;
}

function pokemon_followers_clear_all(){
    if (variable_global_exists("POKEMON_FOLLOWERS") && is_struct(global.POKEMON_FOLLOWERS) && variable_struct_exists(global.POKEMON_FOLLOWERS, "slots")){
        var _slots = variable_struct_get(global.POKEMON_FOLLOWERS, "slots");
        if (is_array(_slots)){
            for (var _i = 0; _i < array_length(_slots); ++_i){
                var _inst = _slots[_i];
                if (instance_exists(_inst)) instance_destroy(_inst);
                _slots[_i] = undefined;
            }
            variable_struct_set(global.POKEMON_FOLLOWERS, "slots", _slots);
        }
    }
    return true;
}

function pokemon_follower_mon_for_pid(_pid){
    var _target_pid = max(0, floor(_pid));
    if (_target_pid == 1 && !multiplayer_player_joined(1)) return undefined;
    if (is_undefined(party_model_get_mon)) return undefined;
    return party_model_get_mon(_target_pid, 0);
}

function pokemon_follower_species_id(_mon){
    if (!is_struct(_mon)) return -1;
    if (!is_undefined(party_model_resolve_species_id)){
        var _sid = party_model_resolve_species_id(_mon);
        if (is_real(_sid) && _sid >= 0) return _sid;
    }
    if (variable_struct_exists(_mon, "species_id")) return variable_struct_get(_mon, "species_id");
    if (variable_struct_exists(_mon, "species")) return variable_struct_get(_mon, "species");
    if (variable_struct_exists(_mon, "idno")) return variable_struct_get(_mon, "idno");
    return -1;
}

function pokemon_follower_mon_name(_mon){
    if (is_struct(_mon) && !is_undefined(__party_impl_mon_display_name)){
        var _display = string(__party_impl_mon_display_name(_mon));
        if (string_length(_display) > 0 && _display != "???") return _display;
    }
    var _sid = pokemon_follower_species_id(_mon);
    if (is_real(_sid) && _sid >= 0 && !is_undefined(scr_poke_name_by_id)){
        var _name = string(scr_poke_name_by_id(_sid));
        if (string_length(_name) > 0) return _name;
    }
    return "POKEMON";
}

function pokemon_follower_player_tile(_pl){
    if (instance_exists(_pl) && variable_instance_exists(_pl, "grid") && is_struct(variable_instance_get(_pl, "grid"))){
        var _g = variable_instance_get(_pl, "grid");
        if (variable_struct_exists(_g, "tile")) return max(1, real(variable_struct_get(_g, "tile")));
    }
    return 8;
}

function pokemon_follower_player_speed(_pl){
    if (instance_exists(_pl) && variable_instance_exists(_pl, "grid") && is_struct(variable_instance_get(_pl, "grid"))){
        var _g = variable_instance_get(_pl, "grid");
        if (variable_struct_exists(_g, "walk_speed")) return max(0.1, real(variable_struct_get(_g, "walk_speed")));
    }
    return 2;
}

function pokemon_follower_spawn_point(_pl){
    var _tile = pokemon_follower_player_tile(_pl);
    var _x = variable_instance_get(_pl, "x");
    var _y = variable_instance_get(_pl, "y");
    var _face = variable_instance_exists(_pl, "facing_dir") ? floor(variable_instance_get(_pl, "facing_dir")) : 2;
    switch (_face mod 4){
        case 0: _y += _tile * 2; break;
        case 1: _x -= _tile * 2; break;
        case 2: _y -= _tile * 2; break;
        case 3: _x += _tile * 2; break;
    }
    return { x: __overworld_npc_snap_value(_x, _tile), y: __overworld_npc_snap_value(_y, _tile) };
}

function pokemon_follower_dir_string(_dir){
    switch (floor(_dir) mod 4){
        case 0: return "UP";
        case 1: return "RIGHT";
        case 3: return "LEFT";
    }
    return "DOWN";
}

function pokemon_follower_sprite_update(_inst, _moving){
    if (!instance_exists(_inst)) return false;
    var _mon = variable_instance_exists(_inst, "follower_mon") ? variable_instance_get(_inst, "follower_mon") : undefined;
    var _species_id = pokemon_follower_species_id(_mon);
    var _shiny = (is_struct(_mon) && variable_struct_exists(_mon, "shiny") && variable_struct_get(_mon, "shiny") == true);
    var _dir = pokemon_follower_dir_string(variable_instance_exists(_inst, "npc_facing_dir") ? variable_instance_get(_inst, "npc_facing_dir") : 2);
    var _draw_mon = { species_id: _species_id, shiny: _shiny };
    var _spr = -1;
    if (!is_undefined(pkicons_get_overworld_dir_by_mon)) _spr = pkicons_get_overworld_dir_by_mon(_draw_mon, _dir);
    else if (!is_undefined(pkicons_get_icon32_dir_by_mon)) _spr = pkicons_get_icon32_dir_by_mon(_draw_mon, _dir);
    if (!sprite_exists(_spr)){
        if (!is_undefined(pkicons_init)) pkicons_init();
        if (variable_global_exists("PKICONS") && is_struct(global.PKICONS) && variable_struct_exists(global.PKICONS, "missing_icon32")) _spr = variable_struct_get(global.PKICONS, "missing_icon32");
        if (!sprite_exists(_spr)) _spr = asset_get_index("spr_mon_icon_placeholder");
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
    return true;
}

function pokemon_follower_create(_pid, _mon){
    var _pl = player_by_pid(_pid);
    if (_pl == noone || !is_struct(_mon)) return noone;
    var _spawn = pokemon_follower_spawn_point(_pl);
    var _npc = instance_create_layer(_spawn.x, _spawn.y, "Instances", oNpc);
    if (_npc == noone) return noone;
    variable_instance_set(_npc, "follower_pokemon", true);
    variable_instance_set(_npc, "world_solid", false);
    variable_instance_set(_npc, "follower_pid", max(0, floor(_pid)));
    variable_instance_set(_npc, "follower_mon", _mon);
    variable_instance_set(_npc, "follower_species_id", pokemon_follower_species_id(_mon));
    variable_instance_set(_npc, "follower_last_player_x", variable_instance_get(_pl, "x"));
    variable_instance_set(_npc, "follower_last_player_y", variable_instance_get(_pl, "y"));
    variable_instance_set(_npc, "follower_trail", []);
    variable_instance_set(_npc, "npc_id", "pokemon_follower_" + string(_pid));
    variable_instance_set(_npc, "interact_radius", 18);
    variable_instance_set(_npc, "npc_tile_size", pokemon_follower_player_tile(_pl));
    variable_instance_set(_npc, "npc_anim_speed", 0.18);
    variable_instance_set(_npc, "wander_enabled", false);
    variable_instance_set(_npc, "trainer_enabled", false);
    variable_instance_set(_npc, "npc_facing_dir", variable_instance_exists(_pl, "facing_dir") ? variable_instance_get(_pl, "facing_dir") : 2);
    pokemon_follower_sprite_update(_npc, false);
    return _npc;
}

function pokemon_follower_record_player(_inst, _pl){
    var _tile = pokemon_follower_player_tile(_pl);
    var _px = __overworld_npc_snap_value(variable_instance_get(_pl, "x"), _tile);
    var _py = __overworld_npc_snap_value(variable_instance_get(_pl, "y"), _tile);
    var _last_x = variable_instance_exists(_inst, "follower_last_player_x") ? variable_instance_get(_inst, "follower_last_player_x") : _px;
    var _last_y = variable_instance_exists(_inst, "follower_last_player_y") ? variable_instance_get(_inst, "follower_last_player_y") : _py;
    var _trail = variable_instance_exists(_inst, "follower_trail") ? variable_instance_get(_inst, "follower_trail") : [];
    if (!is_array(_trail)) _trail = [];
    if (point_distance(_last_x, _last_y, _px, _py) >= _tile * 0.75){
        array_push(_trail, {
            x: _last_x,
            y: _last_y,
            dir: variable_instance_exists(_pl, "facing_dir") ? variable_instance_get(_pl, "facing_dir") : 2
        });
        while (array_length(_trail) > 28) array_delete(_trail, 0, 1);
        variable_instance_set(_inst, "follower_last_player_x", _px);
        variable_instance_set(_inst, "follower_last_player_y", _py);
    }
    variable_instance_set(_inst, "follower_trail", _trail);
    return _trail;
}

function pokemon_follower_step(_inst){
    if (!instance_exists(_inst)) return false;
    var _pid = variable_instance_exists(_inst, "follower_pid") ? max(0, floor(variable_instance_get(_inst, "follower_pid"))) : 0;
    var _pl = player_by_pid(_pid);
    var _mon = pokemon_follower_mon_for_pid(_pid);
    if (!battle_followers_enabled() || _pl == noone || !is_struct(_mon)){
        instance_destroy(_inst);
        return true;
    }

    variable_instance_set(_inst, "follower_mon", _mon);
    var _sid = pokemon_follower_species_id(_mon);
    if (!variable_instance_exists(_inst, "follower_species_id") || variable_instance_get(_inst, "follower_species_id") != _sid){
        variable_instance_set(_inst, "follower_species_id", _sid);
        variable_instance_set(_inst, "image_index", 0);
    }
    variable_instance_set(_inst, "npc_tile_size", pokemon_follower_player_tile(_pl));

    var _tile = pokemon_follower_player_tile(_pl);
    if (point_distance(variable_instance_get(_inst, "x"), variable_instance_get(_inst, "y"), variable_instance_get(_pl, "x"), variable_instance_get(_pl, "y")) > _tile * 12){
        var _spawn = pokemon_follower_spawn_point(_pl);
        variable_instance_set(_inst, "x", _spawn.x);
        variable_instance_set(_inst, "y", _spawn.y);
        variable_instance_set(_inst, "follower_trail", []);
        variable_instance_set(_inst, "follower_last_player_x", variable_instance_get(_pl, "x"));
        variable_instance_set(_inst, "follower_last_player_y", variable_instance_get(_pl, "y"));
        pokemon_follower_sprite_update(_inst, false);
        return true;
    }

    var _trail = pokemon_follower_record_player(_inst, _pl);
    var _follow_gap = 2;
    if (array_length(_trail) < _follow_gap){
        pokemon_follower_sprite_update(_inst, false);
        return true;
    }

    var _target_index = max(0, array_length(_trail) - _follow_gap);
    var _target = _trail[_target_index];
    var _moving = false;
    if (is_struct(_target)){
        _moving = __overworld_npc_move_towards(_inst, _target.x, _target.y, pokemon_follower_player_speed(_pl));
        if (!_moving && array_length(_trail) > _follow_gap) array_delete(_trail, 0, 1);
        variable_instance_set(_inst, "follower_trail", _trail);
    }
    pokemon_follower_sprite_update(_inst, _moving);
    return true;
}

function pokemon_followers_update_all(){
    var _R = pokemon_followers_ensure_state();
    var _slots = variable_struct_get(_R, "slots");
    if (!battle_followers_enabled()){
        pokemon_followers_clear_all();
        return false;
    }
    for (var _pid = 0; _pid < 2; ++_pid){
        if (_pid == 1 && !multiplayer_player_joined(1)){
            if (instance_exists(_slots[_pid])) instance_destroy(_slots[_pid]);
            _slots[_pid] = undefined;
            continue;
        }
        var _mon = pokemon_follower_mon_for_pid(_pid);
        var _pl = player_by_pid(_pid);
        if (_pl == noone || !is_struct(_mon)){
            if (instance_exists(_slots[_pid])) instance_destroy(_slots[_pid]);
            _slots[_pid] = undefined;
            continue;
        }
        if (!instance_exists(_slots[_pid])){
            _slots[_pid] = pokemon_follower_create(_pid, _mon);
        }
    }
    variable_struct_set(_R, "slots", _slots);
    global.POKEMON_FOLLOWERS = _R;
    return true;
}

function pokemon_follower_talk(_inst, _pid){
    if (!instance_exists(_inst) || is_undefined(dialog2p_show_now)) return false;
    var _mon = variable_instance_exists(_inst, "follower_mon") ? variable_instance_get(_inst, "follower_mon") : pokemon_follower_mon_for_pid(_pid);
    var _name = string_upper(pokemon_follower_mon_name(_mon));
    if (!is_undefined(pkicons_play_cry_by_mon) && is_struct(_mon)) pkicons_play_cry_by_mon(_mon);
    dialog2p_show_now(_pid, {
        text: _name + ": " + _name + "!",
        key: "pokemon_follower_talk_" + string(_pid),
        gate: "any"
    });
    return true;
}

function pokemon_center_ensure_state(){
    if (!variable_global_exists("POKEMON_CENTER") || !is_struct(global.POKEMON_CENTER)){
        global.POKEMON_CENTER = {
            active: false,
            pid: 0,
            npc: noone,
            tray: noone,
            phase: "idle",
            choice_sel: 0,
            next_ms: 0,
            party_count: 0,
            ball_index: 0
        };
    }
    return global.POKEMON_CENTER;
}

function pokemon_center_party_count(_pid){
    var _mons = (!is_undefined(party_model_get_mons) ? party_model_get_mons(_pid) : []);
    if (!is_array(_mons) && !is_undefined(party_ensure)){
        var _P = party_ensure(_pid);
        if (is_struct(_P) && variable_struct_exists(_P, "mons") && is_array(variable_struct_get(_P, "mons"))) _mons = variable_struct_get(_P, "mons");
    }
    if (!is_array(_mons)) return 0;
    var _count = 0;
    for (var _i = 0; _i < array_length(_mons); ++_i){
        if (is_struct(_mons[_i])) _count += 1;
    }
    return clamp(_count, 0, 6);
}

function pokemon_center_find_tray(_npc){
    if (!instance_exists(_npc)) return noone;
    var _best = noone;
    var _best_d = 1000000;
    for (var _i = 0; _i < instance_number(opokeballtray); ++_i){
        var _tray = instance_find(opokeballtray, _i);
        if (_tray == noone) continue;
        var _d = point_distance(variable_instance_get(_npc, "x"), variable_instance_get(_npc, "y"), variable_instance_get(_tray, "x"), variable_instance_get(_tray, "y"));
        if (_d < _best_d){
            _best = _tray;
            _best_d = _d;
        }
    }
    return (_best_d <= 96) ? _best : noone;
}

function pokemon_center_set_tray_index(_tray, _index){
    if (!instance_exists(_tray)) return false;
    variable_instance_set(_tray, "image_speed", 0);
    variable_instance_set(_tray, "image_index", clamp(floor(_index), 0, max(0, sprite_get_number(variable_instance_get(_tray, "sprite_index")) - 1)));
    return true;
}

function pokemon_center_set_nurse_pose(_npc, _pose){
    if (!instance_exists(_npc)) return false;
    var _spr = -1;
    switch (string_lower(string(_pose))){
        case "up": _spr = asset_get_index("spr_nursejoy_up"); break;
        case "left": _spr = asset_get_index("spr_nursejoy_left"); break;
        case "bow": _spr = asset_get_index("spr_nursejoy_bow"); break;
        default: _spr = asset_get_index("spr_nursejoy_down"); break;
    }
    if (sprite_exists(_spr)){
        variable_instance_set(_npc, "sprite_index", _spr);
        variable_instance_set(_npc, "image_index", 0);
        variable_instance_set(_npc, "image_speed", 0);
    }
    return true;
}

function pokemon_center_finish(_exit_dialog = false){
    var _C = pokemon_center_ensure_state();
    if (instance_exists(_C.tray)) pokemon_center_set_tray_index(_C.tray, 0);
    if (instance_exists(_C.npc)) pokemon_center_set_nurse_pose(_C.npc, "down");
    variable_struct_set(_C, "active", false);
    variable_struct_set(_C, "phase", "idle");
    global.POKEMON_CENTER = _C;
    return true;
}

function pokemon_center_final_dialog_closed_pid0(){ pokemon_center_finish(); }
function pokemon_center_final_dialog_closed_pid1(){ pokemon_center_finish(); }

function pokemon_center_prompt_closed_pid0(){ pokemon_center_prompt_closed(0); }
function pokemon_center_prompt_closed_pid1(){ pokemon_center_prompt_closed(1); }
function pokemon_center_accept_dialog_closed_pid0(){ pokemon_center_start_heal(0); }
function pokemon_center_accept_dialog_closed_pid1(){ pokemon_center_start_heal(1); }

function pokemon_center_prompt_closed(_pid){
    var _C = pokemon_center_ensure_state();
    if (_C.active != true || floor(_C.pid) != floor(_pid)) return false;
    variable_struct_set(_C, "phase", "choice");
    variable_struct_set(_C, "choice_sel", 0);
    variable_struct_set(_C, "next_ms", current_time + 120);
    global.POKEMON_CENTER = _C;
    return true;
}

function pokemon_center_show_final(_pid, _accepted){
    var _C = pokemon_center_ensure_state();
    if (instance_exists(_C.npc)) pokemon_center_set_nurse_pose(_C.npc, "bow");
    var _text = (_accepted == true)
        ? "Thank you for waiting.\nWe've restored your Pokemon to full health.\nWe hope to see you again!"
        : "We hope to see you again!";
    variable_struct_set(_C, "phase", "final_dialog");
    global.POKEMON_CENTER = _C;
    if (!is_undefined(dialog2p_show_now)){
        dialog2p_show_now(_pid, {
            text: _text,
            key: "pokemon_center_final_" + string(_pid),
            gate: "any",
            on_close: (_pid == 1) ? pokemon_center_final_dialog_closed_pid1 : pokemon_center_final_dialog_closed_pid0
        });
    } else pokemon_center_finish();
    return true;
}

function pokemon_center_heal_party(_pid){
    if (!is_undefined(__battle_heal_party_full)) return __battle_heal_party_full(_pid);
    if (is_undefined(party_model_get_mons)) return false;
    var _mons = party_model_get_mons(_pid);
    for (var _i = 0; _i < array_length(_mons); ++_i){
        var _mon = _mons[_i];
        if (!is_struct(_mon)) continue;
        var _max_hp = 1;
        if (variable_struct_exists(_mon, "hp_max") && is_real(variable_struct_get(_mon, "hp_max"))) _max_hp = max(_max_hp, real(variable_struct_get(_mon, "hp_max")));
        if (variable_struct_exists(_mon, "maxhp") && is_real(variable_struct_get(_mon, "maxhp"))) _max_hp = max(_max_hp, real(variable_struct_get(_mon, "maxhp")));
        variable_struct_set(_mon, "hp_now", _max_hp);
        variable_struct_set(_mon, "hp", _max_hp);
        if (variable_struct_exists(_mon, "_fainted")) variable_struct_set(_mon, "_fainted", false);
        if (variable_struct_exists(_mon, "status_id")) variable_struct_set(_mon, "status_id", 0);
        if (variable_struct_exists(_mon, "statuses")) variable_struct_set(_mon, "statuses", {});
    }
    return true;
}

function pokemon_center_start_heal(_pid){
    var _C = pokemon_center_ensure_state();
    variable_struct_set(_C, "phase", "healing");
    variable_struct_set(_C, "ball_index", 0);
    variable_struct_set(_C, "party_count", pokemon_center_party_count(_pid));
    variable_struct_set(_C, "next_ms", current_time + 160);
    if (instance_exists(_C.npc)) pokemon_center_set_nurse_pose(_C.npc, "left");
    if (instance_exists(_C.tray)) pokemon_center_set_tray_index(_C.tray, 0);
    global.POKEMON_CENTER = _C;
    return true;
}

function pokemon_center_decline(_pid){
    return pokemon_center_show_final(_pid, false);
}

function pokemon_center_accept(_pid){
    var _C = pokemon_center_ensure_state();
    variable_struct_set(_C, "phase", "accept_dialog");
    global.POKEMON_CENTER = _C;
    if (!is_undefined(dialog2p_show_now)){
        dialog2p_show_now(_pid, {
            text: "Okay, I'll take your Pokemon for a few seconds.",
            key: "pokemon_center_accept_" + string(_pid),
            gate: "any",
            on_close: (_pid == 1) ? pokemon_center_accept_dialog_closed_pid1 : pokemon_center_accept_dialog_closed_pid0
        });
    } else pokemon_center_start_heal(_pid);
    return true;
}

function pokemon_center_update(_pid){
    var _C = pokemon_center_ensure_state();
    if (_C.active != true || floor(_C.pid) != floor(_pid)) return false;
    if (!instance_exists(_C.npc)){
        pokemon_center_finish();
        return false;
    }
    var _phase = string(_C.phase);
    if (_phase == "choice"){
        if (is_real(current_time) && current_time < real(_C.next_ms)) return true;
        if (controls_pressed(_pid, "MoveUp") || controls_pressed(_pid, "MoveDown")){
            variable_struct_set(_C, "choice_sel", 1 - clamp(floor(_C.choice_sel), 0, 1));
            global.POKEMON_CENTER = _C;
            return true;
        }
        if (controls_pressed(_pid, "Back")){
            variable_struct_set(_C, "phase", "final_dialog");
            global.POKEMON_CENTER = _C;
            return pokemon_center_decline(_pid);
        }
        if (controls_pressed(_pid, "Interact")){
            if (clamp(floor(_C.choice_sel), 0, 1) == 0) return pokemon_center_accept(_pid);
            return pokemon_center_decline(_pid);
        }
        return true;
    }
    if (_phase == "healing"){
        if (is_real(current_time) && current_time < real(_C.next_ms)) return true;
        var _idx = max(0, floor(_C.ball_index)) + 1;
        var _count = max(0, floor(_C.party_count));
        if (_idx <= _count){
            if (instance_exists(_C.tray)) pokemon_center_set_tray_index(_C.tray, _idx);
            variable_struct_set(_C, "ball_index", _idx);
            variable_struct_set(_C, "next_ms", current_time + 180);
            global.POKEMON_CENTER = _C;
            return true;
        }
        pokemon_center_heal_party(_pid);
        if (instance_exists(_C.tray)) pokemon_center_set_tray_index(_C.tray, 0);
        return pokemon_center_show_final(_pid, true);
    }
    return true;
}

function pokemon_center_draw_yesno_rect(_pid, _rx, _ry, _rw, _rh){
    var _C = pokemon_center_ensure_state();
    if (_C.active != true || floor(_C.pid) != floor(_pid) || string(_C.phase) != "choice") return false;
    if (!is_undefined(dialog2p_is_open) && dialog2p_is_open(_pid)) return false;

    var _sel = clamp(floor(_C.choice_sel), 0, 1);
    var _scale_x = max(1, _rw / 240);
    var _scale_y = max(1, _rh / 160);
    var _w = 52 * _scale_x;
    var _h = 34 * _scale_y;
    var _x = _rx + _rw - _w - 12 * _scale_x;
    var _y = _ry + _rh - _h - 40 * _scale_y;
    draw_set_alpha(0.2);
    draw_set_color(c_black);
    draw_rectangle(_x + 2, _y + 2, _x + _w + 2, _y + _h + 2, false);
    draw_set_alpha(1);
    draw_set_color(make_color_rgb(72, 88, 80));
    draw_rectangle(_x, _y, _x + _w, _y + _h, false);
    draw_set_color(make_color_rgb(208, 232, 224));
    draw_rectangle(_x + 1, _y + 1, _x + _w - 1, _y + _h - 1, false);
    var _font_small = variable_global_exists("FNT_POKEMON_SMALL") ? global.FNT_POKEMON_SMALL : (variable_global_exists("FNT_POKEMON") ? global.FNT_POKEMON : -1);
    if (_font_small != -1) draw_set_font(_font_small);
    draw_set_halign(fa_center);
    draw_set_valign(fa_top);
    var _opts = ["YES", "NO"];
    var _row_h = 11 * _scale_y;
    var _gap = 3 * _scale_y;
    var _row_x1 = _x + 4 * _scale_x;
    var _row_x2 = _x + _w - 4 * _scale_x;
    for (var _i = 0; _i < 2; ++_i){
        var _row_y = _y + 4 * _scale_y + (_i * (_row_h + _gap));
        var _hilite = (_i == _sel);
        if (_hilite){
            draw_set_color(make_color_rgb(72, 88, 80));
            draw_rectangle(_row_x1, _row_y, _row_x2, _row_y + _row_h, false);
        }
        draw_set_color(_hilite ? make_color_rgb(208, 232, 224) : make_color_rgb(36, 52, 40));
        draw_text((_row_x1 + _row_x2) * 0.5, _row_y + 2 * _scale_y + 3, _opts[_i]);
    }
    draw_set_halign(fa_left);
    draw_set_valign(fa_top);
    draw_set_alpha(1);
    return true;
}

function pokemon_center_active_for_pid(_pid){
    var _C = pokemon_center_ensure_state();
    return (_C.active == true && floor(_C.pid) == floor(_pid));
}

function pokemon_center_nurse_start(_inst, _pid){
    if (!instance_exists(_inst) || is_undefined(dialog2p_show_now)) return false;
    var _C = pokemon_center_ensure_state();
    if (_C.active == true) return true;
    var _tray = pokemon_center_find_tray(_inst);
    if (instance_exists(_tray)) pokemon_center_set_tray_index(_tray, 0);
    pokemon_center_set_nurse_pose(_inst, "down");
    variable_struct_set(_C, "active", true);
    variable_struct_set(_C, "pid", max(0, floor(_pid)));
    variable_struct_set(_C, "npc", _inst);
    variable_struct_set(_C, "tray", _tray);
    variable_struct_set(_C, "phase", "prompt_dialog");
    variable_struct_set(_C, "choice_sel", 0);
    variable_struct_set(_C, "party_count", pokemon_center_party_count(_pid));
    variable_struct_set(_C, "ball_index", 0);
    global.POKEMON_CENTER = _C;
    dialog2p_show_now(_pid, {
        text: "Hello, and welcome to the Pokemon Center.\nWould you like to rest your Pokemon?",
        key: "pokemon_center_prompt_" + string(_pid),
        gate: "any",
        on_close: (_pid == 1) ? pokemon_center_prompt_closed_pid1 : pokemon_center_prompt_closed_pid0
    });
    return true;
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
    var _nurse_down = asset_get_index("spr_nursejoy_down");
    if (!variable_instance_exists(_inst, "pokemon_center_nurse")){
        variable_instance_set(_inst, "pokemon_center_nurse", sprite_exists(_nurse_down) && variable_instance_exists(_inst, "sprite_index") && variable_instance_get(_inst, "sprite_index") == _nurse_down);
    }
    if (variable_instance_get(_inst, "pokemon_center_nurse") == true){
        if (sprite_exists(_nurse_down) && variable_instance_get(_inst, "npc_sprite_down") == -1) variable_instance_set(_inst, "npc_sprite_down", _nurse_down);
        var _nurse_up = asset_get_index("spr_nursejoy_up");
        var _nurse_left = asset_get_index("spr_nursejoy_left");
        if (sprite_exists(_nurse_up) && variable_instance_get(_inst, "npc_sprite_up") == -1) variable_instance_set(_inst, "npc_sprite_up", _nurse_up);
        if (sprite_exists(_nurse_left) && variable_instance_get(_inst, "npc_sprite_left") == -1) variable_instance_set(_inst, "npc_sprite_left", _nurse_left);
        if (sprite_exists(_nurse_left) && variable_instance_get(_inst, "npc_sprite_right") == -1) variable_instance_set(_inst, "npc_sprite_right", _nurse_left);
        variable_instance_set(_inst, "interact_radius", max(40, variable_instance_get(_inst, "interact_radius")));
        variable_instance_set(_inst, "wander_enabled", false);
        variable_instance_set(_inst, "trainer_enabled", false);
        var _nurse_bow = asset_get_index("spr_nursejoy_bow");
        var _current_nurse_sprite = variable_instance_exists(_inst, "sprite_index") ? variable_instance_get(_inst, "sprite_index") : -1;
        var _has_nurse_pose = (_current_nurse_sprite == _nurse_down)
            || (_current_nurse_sprite == _nurse_up)
            || (_current_nurse_sprite == _nurse_left)
            || (_current_nurse_sprite == _nurse_bow);
        if (!_has_nurse_pose) pokemon_center_set_nurse_pose(_inst, "down");
    }
    if (!variable_instance_exists(_inst, "npc_facing_dir")) variable_instance_set(_inst, "npc_facing_dir", 2);
    if (!variable_instance_exists(_inst, "npc_anim_speed")) variable_instance_set(_inst, "npc_anim_speed", 0.16);
    if (!variable_instance_exists(_inst, "npc_tile_size")) variable_instance_set(_inst, "npc_tile_size", 16);
    if (!variable_instance_exists(_inst, "npc_grid_target_x")) variable_instance_set(_inst, "npc_grid_target_x", variable_instance_get(_inst, "x"));
    if (!variable_instance_exists(_inst, "npc_grid_target_y")) variable_instance_set(_inst, "npc_grid_target_y", variable_instance_get(_inst, "y"));
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
    if (!variable_instance_exists(_inst, "trainer_approach_face")) variable_instance_set(_inst, "trainer_approach_face", variable_instance_get(_inst, "npc_facing_dir"));
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
    if (!is_undefined(oitem)){
        var _item_pickup = instance_nearest(_fx, _fy, oitem);
        if (_item_pickup != noone && (_npc == noone || point_distance(_fx, _fy, variable_instance_get(_item_pickup, "x"), variable_instance_get(_item_pickup, "y")) < point_distance(_fx, _fy, variable_instance_get(_npc, "x"), variable_instance_get(_npc, "y")))){
            _npc = _item_pickup;
        }
    }
    if (!is_undefined(oFieldMoveProp)){
        var _field_prop = instance_nearest(_fx, _fy, oFieldMoveProp);
        if (_field_prop != noone && (_npc == noone || point_distance(_fx, _fy, variable_instance_get(_field_prop, "x"), variable_instance_get(_field_prop, "y")) < point_distance(_fx, _fy, variable_instance_get(_npc, "x"), variable_instance_get(_npc, "y")))){
            _npc = _field_prop;
        }
    }
    if (_npc == noone) return noone;
    if (variable_instance_exists(_npc, "encounter_pokemon") && variable_instance_get(_npc, "encounter_pokemon") == true) return noone;
    var _radius = variable_instance_exists(_npc, "interact_radius") ? variable_instance_get(_npc, "interact_radius") : _max_dist;
    if (point_distance(_fx, _fy, variable_instance_get(_npc, "x"), variable_instance_get(_npc, "y")) > max(_max_dist, _radius)) return noone;
    return _npc;
}

function sfx_play_safe(_sound_res, _priority = 1){
    if (is_undefined(_sound_res) || _sound_res == noone || _sound_res == -1) return false;
    try {
        if (!is_undefined(sound_exists) && !sound_exists(_sound_res)) return false;
    } catch (e_sfx_exists) {}
    try {
        if (!is_undefined(audio_play_sound)){
            audio_play_sound(_sound_res, _priority, false);
            return true;
        }
    } catch (e_sfx_play) {}
    return false;
}

function ui_play_select_sound(){
    return sfx_play_safe(snd_select, 1);
}

function ui_play_confirm_sound(){
    return sfx_play_safe(snd_success_small, 1);
}

function __overworld_item_is_hm(_item_id, _it){
    var _txt = "";
    if (is_struct(_it)){
        if (variable_struct_exists(_it, "identifier")) _txt += " " + string_lower(string(variable_struct_get(_it, "identifier")));
        if (variable_struct_exists(_it, "name")) _txt += " " + string_lower(string(variable_struct_get(_it, "name")));
    }
    return (string_pos("hm", _txt) > 0 || string_pos("hidden-machine", _txt) > 0);
}

function overworld_item_pickup_interact(_inst, _pid){
    if (!instance_exists(_inst)) return false;
    if (variable_instance_exists(_inst, "item_taken") && variable_instance_get(_inst, "item_taken") == true) return false;

    var _item_id = (variable_instance_exists(_inst, "item_id") && is_real(variable_instance_get(_inst, "item_id"))) ? floor(variable_instance_get(_inst, "item_id")) : -1;
    var _qty = (variable_instance_exists(_inst, "item_qty") && is_real(variable_instance_get(_inst, "item_qty"))) ? max(1, floor(variable_instance_get(_inst, "item_qty"))) : 1;
    if (_item_id <= 0) return false;

    var _it = undefined;
    if (variable_global_exists("_items") && is_array(global._items) && _item_id < array_length(global._items)) _it = global._items[_item_id];
    var _name = "ITEM";
    try {
        if (!is_undefined(bag__item_display_name)) _name = string(bag__item_display_name(_item_id, undefined, _it));
        else if (is_struct(_it) && variable_struct_exists(_it, "name")) _name = string(variable_struct_get(_it, "name"));
    } catch (e_pickup_name) { _name = "ITEM"; }

    if (!is_undefined(bag_inventory_add_item)) bag_inventory_add_item(_pid, _item_id, _qty);
    try { if (!is_undefined(bags_seed_from_items)) bags_seed_from_items(_pid); } catch (e_pickup_seed) {}
    variable_instance_set(_inst, "item_taken", true);

    if (__overworld_item_is_hm(_item_id, _it)) sfx_play_safe(snd_Receive_HM, 1);
    else sfx_play_safe(snd_Receive_Item, 1);

    var _prefix = (variable_global_exists("PLAYER_NAME") ? string(global.PLAYER_NAME) : "PLAYER");
    var _msg = variable_instance_exists(_inst, "item_message") ? string(variable_instance_get(_inst, "item_message")) : "";
    if (string_length(string_trim(_msg)) <= 0){
        _msg = (_qty > 1)
            ? (_prefix + " found " + string(_qty) + " " + string(_name) + "!")
            : (_prefix + " found one " + string(_name) + "!");
    }
    try {
        if (!is_undefined(dialog2p_show_now)) dialog2p_show_now(_pid, _msg);
        else if (!is_undefined(dialog2p_show)) dialog2p_show(_pid, _msg);
    } catch (e_pickup_dialog) {}

    if (!variable_instance_exists(_inst, "item_pickup_once") || variable_instance_get(_inst, "item_pickup_once") == true){
        try { instance_destroy(_inst); } catch (e_pickup_destroy) {
            variable_instance_set(_inst, "visible", false);
            variable_instance_set(_inst, "world_solid", false);
        }
    }
    return true;
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

function __overworld_npc_snap_value(_v, _tile){
    return round(real(_v) / max(1, real(_tile))) * max(1, real(_tile));
}

function __overworld_npc_can_stand_at(_inst, _x, _y){
    if (!instance_exists(_inst)) return false;
    if (!is_undefined(wc_collides_at) && wc_collides_at(_inst, real(_x), real(_y), _inst)) return false;
    var _dx = real(_x) - variable_instance_get(_inst, "x");
    var _dy = real(_y) - variable_instance_get(_inst, "y");
    var _l = _inst.bbox_left + _dx;
    var _r = _inst.bbox_right + _dx;
    var _t = _inst.bbox_top + _dy;
    var _b = _inst.bbox_bottom + _dy;
    for (var _pid = 0; _pid < 2; ++_pid){
        if (_pid == 1 && !is_undefined(multiplayer_player_joined) && !multiplayer_player_joined(1)) continue;
        var _pl = player_by_pid(_pid);
        if (_pl == noone) continue;
        if (_l < _pl.bbox_right && _r > _pl.bbox_left && _t < _pl.bbox_bottom && _b > _pl.bbox_top) return false;
    }
    return true;
}

function __overworld_npc_line_clear(_inst, _x1, _y1, _x2, _y2){
    if (!instance_exists(_inst)) return false;
    var _tile = variable_instance_exists(_inst, "npc_tile_size") ? max(1, real(variable_instance_get(_inst, "npc_tile_size"))) : 16;
    var _steps = max(1, ceil(point_distance(_x1, _y1, _x2, _y2) / _tile));
    for (var _i = 1; _i <= _steps; ++_i){
        var _px = lerp(_x1, _x2, _i / _steps);
        var _py = lerp(_y1, _y2, _i / _steps);
        var _dx = _px - variable_instance_get(_inst, "x");
        var _dy = _py - variable_instance_get(_inst, "y");
        var _l = _inst.bbox_left + _dx;
        var _r = _inst.bbox_right + _dx;
        var _t = _inst.bbox_top + _dy;
        var _b = _inst.bbox_bottom + _dy;
        if (!is_undefined(wc_tiles_hit_rect) && wc_tiles_hit_rect(_l, _t, _r, _b)) return false;
        if (_i < _steps && !is_undefined(wc_objects_hit_rect) && wc_objects_hit_rect(_l, _t, _r, _b, _inst)) return false;
    }
    return true;
}

function __overworld_npc_stop(_inst){
    if (!instance_exists(_inst)) return false;
    var _tile = variable_instance_exists(_inst, "npc_tile_size") ? max(1, real(variable_instance_get(_inst, "npc_tile_size"))) : 16;
    var _sx = __overworld_npc_snap_value(variable_instance_get(_inst, "x"), _tile);
    var _sy = __overworld_npc_snap_value(variable_instance_get(_inst, "y"), _tile);
    if (__overworld_npc_can_stand_at(_inst, _sx, _sy)){
        variable_instance_set(_inst, "x", _sx);
        variable_instance_set(_inst, "y", _sy);
    }
    variable_instance_set(_inst, "npc_grid_target_x", variable_instance_get(_inst, "x"));
    variable_instance_set(_inst, "npc_grid_target_y", variable_instance_get(_inst, "y"));
    __overworld_npc_anim_update(_inst, false, 0, 0);
    return true;
}

function __overworld_npc_move_towards(_inst, _tx, _ty, _speed){
    if (!instance_exists(_inst)) return false;
    var _x = variable_instance_get(_inst, "x");
    var _y = variable_instance_get(_inst, "y");
    var _tile = variable_instance_exists(_inst, "npc_tile_size") ? max(1, real(variable_instance_get(_inst, "npc_tile_size"))) : 16;
    var _target_x = __overworld_npc_snap_value(_tx, _tile);
    var _target_y = __overworld_npc_snap_value(_ty, _tile);
    var _dx_total = _target_x - _x;
    var _dy_total = _target_y - _y;
    if (abs(_dx_total) <= 0.05 && abs(_dy_total) <= 0.05){
        variable_instance_set(_inst, "x", _target_x);
        variable_instance_set(_inst, "y", _target_y);
        __overworld_npc_anim_update(_inst, false, 0, 0);
        return false;
    }
    var _move_x = (abs(_dx_total) > 0.05 && (abs(_dx_total) >= abs(_dy_total) || abs(_dy_total) <= 0.05));
    var _step = min(max(0.1, real(_speed)), _tile);
    var _dx = _move_x ? clamp(_dx_total, -_step, _step) : 0;
    var _dy = _move_x ? 0 : clamp(_dy_total, -_step, _step);
    var _nx = _x + _dx;
    var _ny = _y + _dy;
    if (!__overworld_npc_can_stand_at(_inst, _nx, _ny)){
        __overworld_npc_stop(_inst);
        return false;
    }
    variable_instance_set(_inst, "x", _nx);
    variable_instance_set(_inst, "y", _ny);
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
        if (!is_undefined(overworld_field_interaction_blocked) && overworld_field_interaction_blocked(_pid)) continue;
        if (!is_undefined(dialog2p_is_open) && dialog2p_is_open(_pid)) continue;
        var _px = variable_instance_get(_pl, "x") + 8;
        var _py = variable_instance_get(_pl, "y") + 8;
        var _dx = _px - _ix;
        var _dy = _py - _iy;
        switch (_face){
            case 0: if (_dy < 0 && abs(_dx) <= _width && abs(_dy) <= _range && __overworld_npc_line_clear(_inst, _ix, _iy, _px, _py)) return _pid; break;
            case 1: if (_dx > 0 && abs(_dy) <= _width && abs(_dx) <= _range && __overworld_npc_line_clear(_inst, _ix, _iy, _px, _py)) return _pid; break;
            case 2: if (_dy > 0 && abs(_dx) <= _width && abs(_dy) <= _range && __overworld_npc_line_clear(_inst, _ix, _iy, _px, _py)) return _pid; break;
            case 3: if (_dx < 0 && abs(_dy) <= _width && abs(_dx) <= _range && __overworld_npc_line_clear(_inst, _ix, _iy, _px, _py)) return _pid; break;
        }
    }
    return -1;
}

function __overworld_trainer_set_approach_target(_inst, _pid){
    var _pl = player_by_pid(_pid);
    if (_pl == noone) return false;
    var _trainer_cx = variable_instance_get(_inst, "x") + 8;
    var _trainer_cy = variable_instance_get(_inst, "y") + 8;
    var _player_cx = variable_instance_get(_pl, "x") + 8;
    var _player_cy = variable_instance_get(_pl, "y") + 8;
    var _delta_x = _player_cx - _trainer_cx;
    var _delta_y = _player_cy - _trainer_cy;
    if (point_distance(_trainer_cx, _trainer_cy, _player_cx, _player_cy) <= 20){
        var _face_now = variable_instance_get(_inst, "npc_facing_dir");
        if (abs(_delta_x) > abs(_delta_y)) _face_now = (_delta_x >= 0) ? 1 : 3;
        else if (abs(_delta_y) > 0) _face_now = (_delta_y >= 0) ? 2 : 0;
        variable_instance_set(_inst, "npc_facing_dir", _face_now);
        variable_instance_set(_inst, "trainer_approach_face", _face_now);
        variable_instance_set(_inst, "trainer_approach_x", __overworld_npc_snap_value(variable_instance_get(_inst, "x"), 16));
        variable_instance_set(_inst, "trainer_approach_y", __overworld_npc_snap_value(variable_instance_get(_inst, "y"), 16));
        variable_instance_set(_inst, "trainer_target_pid", _pid);
        variable_instance_set(_inst, "trainer_state", "approach");
        __overworld_npc_anim_update(_inst, false, 0, 0);
        return true;
    }
    var _face = floor(variable_instance_get(_inst, "npc_facing_dir"));
    variable_instance_set(_inst, "trainer_approach_face", _face);
    var _tx = variable_instance_get(_pl, "x");
    var _ty = variable_instance_get(_pl, "y");
    var _tile = 16;
    switch (_face){
        case 0: _ty += _tile; break;
        case 1: _tx -= _tile; break;
        case 2: _ty -= _tile; break;
        case 3: _tx += _tile; break;
    }
    _tx = __overworld_npc_snap_value(_tx, _tile);
    _ty = __overworld_npc_snap_value(_ty, _tile);
    if (!__overworld_npc_can_stand_at(_inst, _tx, _ty)){
        __overworld_npc_anim_update(_inst, false, 0, 0);
        return false;
    }
    variable_instance_set(_inst, "trainer_approach_x", _tx);
    variable_instance_set(_inst, "trainer_approach_y", _ty);
    variable_instance_set(_inst, "trainer_target_pid", _pid);
    variable_instance_set(_inst, "trainer_state", "approach");
    return true;
}

function __overworld_trainer_at_approach_target(_inst){
    if (!instance_exists(_inst)) return false;
    var _tx = variable_instance_exists(_inst, "trainer_approach_x") ? real(variable_instance_get(_inst, "trainer_approach_x")) : real(variable_instance_get(_inst, "x"));
    var _ty = variable_instance_exists(_inst, "trainer_approach_y") ? real(variable_instance_get(_inst, "trainer_approach_y")) : real(variable_instance_get(_inst, "y"));
    return point_distance(variable_instance_get(_inst, "x"), variable_instance_get(_inst, "y"), _tx, _ty) <= 1;
}

function __overworld_trainer_face_target_player(_inst, _pid){
    var _pl = player_by_pid(_pid);
    if (_pl == noone || !instance_exists(_inst)) return false;
    var _trainer_cx = variable_instance_get(_inst, "x") + 8;
    var _trainer_cy = variable_instance_get(_inst, "y") + 8;
    var _player_cx = variable_instance_get(_pl, "x") + 8;
    var _player_cy = variable_instance_get(_pl, "y") + 8;
    var _dx = _player_cx - _trainer_cx;
    var _dy = _player_cy - _trainer_cy;
    var _face = variable_instance_exists(_inst, "trainer_approach_face") ? floor(variable_instance_get(_inst, "trainer_approach_face")) : floor(variable_instance_get(_inst, "npc_facing_dir"));
    if (abs(_dx) > abs(_dy)) _face = (_dx >= 0) ? 1 : 3;
    else if (abs(_dy) > 0) _face = (_dy >= 0) ? 2 : 0;
    variable_instance_set(_inst, "npc_facing_dir", _face);
    __overworld_npc_anim_update(_inst, false, 0, 0);
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

function __overworld_trainer_random_species_id(_fallback_species){
    var _fallback = is_real(_fallback_species) ? floor(_fallback_species) : 1;
    if (variable_global_exists("_pokemon") && is_array(global._pokemon)){
        for (var _try = 0; _try < 32; ++_try){
            var _sid = irandom(max(1, array_length(global._pokemon) - 1));
            if (_sid > 0 && _sid < array_length(global._pokemon) && is_struct(global._pokemon[_sid])) return _sid;
        }
    }
    return max(1, _fallback);
}

function __overworld_trainer_ensure_double_party(_party, _leader){
    var _out = [];
    if (is_array(_party)){
        for (var _i = 0; _i < array_length(_party); ++_i) array_push(_out, _party[_i]);
    }
    if (array_length(_out) >= 2) return _out;
    var _base_level = 5;
    var _base_species = 1;
    if (array_length(_out) > 0 && is_struct(_out[0])){
        if (variable_struct_exists(_out[0], "level") && is_real(variable_struct_get(_out[0], "level"))) _base_level = max(1, floor(variable_struct_get(_out[0], "level")));
        else if (variable_struct_exists(_out[0], "lvl") && is_real(variable_struct_get(_out[0], "lvl"))) _base_level = max(1, floor(variable_struct_get(_out[0], "lvl")));
        if (variable_struct_exists(_out[0], "species_id") && is_real(variable_struct_get(_out[0], "species_id"))) _base_species = floor(variable_struct_get(_out[0], "species_id"));
        else if (variable_struct_exists(_out[0], "species") && is_real(variable_struct_get(_out[0], "species"))) _base_species = floor(variable_struct_get(_out[0], "species"));
    } else if (instance_exists(_leader)){
        if (variable_instance_exists(_leader, "trainer_level")) _base_level = max(1, floor(variable_instance_get(_leader, "trainer_level")));
        if (variable_instance_exists(_leader, "trainer_species")) _base_species = floor(variable_instance_get(_leader, "trainer_species"));
    }
    var _sid = __overworld_trainer_random_species_id(_base_species);
    if (!is_undefined(pokemon_factory_create)) array_push(_out, pokemon_factory_create(_sid, _base_level, {}));
    else array_push(_out, { species:_sid, level:_base_level });
    return _out;
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
        variable_instance_set(_npc, "trainer_state", "battle");
    }
    var _payload = variable_struct_get(_entry, "payload");
    var _battle_pid = (variable_struct_exists(_entry, "battle_pid") && is_real(variable_struct_get(_entry, "battle_pid"))) ? floor(variable_struct_get(_entry, "battle_pid")) : _pid;
    if (variable_struct_exists(_entry, "assist_responder_pid") && is_real(variable_struct_get(_entry, "assist_responder_pid"))){
        var _assist_pid = floor(variable_struct_get(_entry, "assist_responder_pid"));
        var _payload_single = (variable_struct_exists(_entry, "payload_single") && is_struct(variable_struct_get(_entry, "payload_single"))) ? variable_struct_get(_entry, "payload_single") : _payload;
        var _payload_double = (variable_struct_exists(_entry, "payload_double") && is_struct(variable_struct_get(_entry, "payload_double"))) ? variable_struct_get(_entry, "payload_double") : _payload;
        var _open_level = (variable_struct_exists(_entry, "open_level") && is_real(variable_struct_get(_entry, "open_level"))) ? max(1, floor(variable_struct_get(_entry, "open_level"))) : 5;
        var _area_type = (variable_struct_exists(_entry, "area_type")) ? string(variable_struct_get(_entry, "area_type")) : "forest";
        if (!is_undefined(multiplayer_request_wild_assist_battle) && multiplayer_request_wild_assist_battle(_battle_pid, _assist_pid, _open_level, _area_type, _payload_single, _payload_double)){
            return true;
        }
        _payload = _payload_single;
    }
    battle_open_trainer(_battle_pid, _payload);
    return true;
}

function __overworld_trainer_payload_clone(_payload){
    var _out = {};
    if (!is_struct(_payload)) return _out;
    var _keys = variable_struct_get_names(_payload);
    for (var _i = 0; _i < array_length(_keys); ++_i){
        var _key = _keys[_i];
        variable_struct_set(_out, _key, variable_struct_get(_payload, _key));
    }
    return _out;
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
    var _trainer_count = array_length(_trainers);
    var _forced_double_trainers = (_trainer_count > 1);
    if (_forced_double_trainers) _format = "double";
    var _assist_pid = -1;
    if (!_forced_double_trainers && variable_instance_get(_leader, "trainer_coop_enabled") == true && multiplayer_queue_mode() == "coop"){
        _assist_pid = (_pid == 0) ? 1 : 0;
        if (!multiplayer_player_joined(_assist_pid)) _assist_pid = -1;
    }
    var _battle_pid = _pid;
    var _player_pids = [_pid];
    var _battle_sprite = variable_instance_get(_leader, "trainer_battle_sprite");
    var _payload = {
        trainer_name: (array_length(_names) > 1) ? "Double Trainers" : string(variable_instance_get(_leader, "trainer_name")),
        party: _party,
        battle_type: "trainer",
        type: "trainer",
        area_type: string(variable_instance_get(_leader, "trainer_area_type")),
        battle_format: _format,
        coop_enabled: false,
        player_pids: _player_pids,
        trainer_reward: _reward,
        trainer_sprite: _battle_sprite,
        sprite_index: variable_instance_get(_leader, "trainer_battle_sprite_index")
    };
    var _entry = { index: 0, trainers: _trainers, dialogs: _dialogs, payload: _payload, battle_pid: _battle_pid };
    if (_assist_pid >= 0){
        var _payload_single = __overworld_trainer_payload_clone(_payload);
        variable_struct_set(_payload_single, "battle_format", "single");
        variable_struct_set(_payload_single, "coop_enabled", false);
        variable_struct_set(_payload_single, "player_pids", [_pid]);
        var _payload_double = __overworld_trainer_payload_clone(_payload);
        var _double_party = __overworld_trainer_ensure_double_party(_party, _leader);
        variable_struct_set(_payload_double, "battle_format", "double");
        variable_struct_set(_payload_double, "coop_enabled", true);
        variable_struct_set(_payload_double, "player_pids", [_pid, _assist_pid]);
        variable_struct_set(_payload_double, "party", _double_party);
        variable_struct_set(_payload_double, "enemy_party", _double_party);
        var _open_level = 5;
        if (array_length(_party) > 0 && is_struct(_party[0])){
            if (variable_struct_exists(_party[0], "level") && is_real(variable_struct_get(_party[0], "level"))) _open_level = max(1, floor(variable_struct_get(_party[0], "level")));
            else if (variable_struct_exists(_party[0], "lvl") && is_real(variable_struct_get(_party[0], "lvl"))) _open_level = max(1, floor(variable_struct_get(_party[0], "lvl")));
        }
        variable_struct_set(_entry, "assist_responder_pid", _assist_pid);
        variable_struct_set(_entry, "payload_single", _payload_single);
        variable_struct_set(_entry, "payload_double", _payload_double);
        variable_struct_set(_entry, "open_level", _open_level);
        variable_struct_set(_entry, "area_type", string(variable_instance_get(_leader, "trainer_area_type")));
    }
    __overworld_trainer_pending_set(_pid, _entry);
    return __overworld_trainer_show_dialog(_pid);
}

function __overworld_trainer_step(_inst){
    if (variable_instance_get(_inst, "trainer_enabled") != true) return false;
    var _state = string(variable_instance_get(_inst, "trainer_state"));
    if (_state == "battle" || _state == "battle_wait"){
        var _battle_live = (!is_undefined(battle_any_open) && battle_any_open())
            || (!is_undefined(multiplayer_wild_assist_request_active) && multiplayer_wild_assist_request_active());
        if (_battle_live){
            __overworld_npc_anim_update(_inst, false, 0, 0);
            return true;
        }
        variable_instance_set(_inst, "trainer_state", "idle");
        _state = "idle";
    }
    if (variable_instance_get(_inst, "trainer_defeated") == true){
        if (variable_instance_get(_inst, "npc_path_enabled") == true) return __overworld_npc_path_step(_inst);
        if (variable_instance_get(_inst, "wander_enabled") == true) return false;
        __overworld_npc_anim_update(_inst, false, 0, 0);
        return false;
    }
    if (_state == "approach"){
        var _pid = floor(variable_instance_get(_inst, "trainer_target_pid"));
        if (!is_undefined(overworld_field_interaction_blocked) && overworld_field_interaction_blocked(_pid)){
            var _battle_block = (!is_undefined(battle_any_open) && battle_any_open())
                || (!is_undefined(multiplayer_wild_assist_request_active) && multiplayer_wild_assist_request_active());
            variable_instance_set(_inst, "trainer_state", _battle_block ? "battle_wait" : "idle");
            __overworld_npc_anim_update(_inst, false, 0, 0);
            return _battle_block;
        }
        var _moving = __overworld_npc_move_towards(
            _inst,
            variable_instance_get(_inst, "trainer_approach_x"),
            variable_instance_get(_inst, "trainer_approach_y"),
            max(0.1, variable_instance_get(_inst, "trainer_chase_speed"))
        );
        if (!_moving){
            if (__overworld_trainer_at_approach_target(_inst)){
                __overworld_trainer_face_target_player(_inst, _pid);
                return __overworld_trainer_begin_dialog(_inst, _pid);
            }
            __overworld_npc_anim_update(_inst, false, 0, 0);
            return __overworld_trainer_set_approach_target(_inst, _pid);
        }
        return true;
    }
    if (_state == "dialog") return true;
    var _seen_pid = __overworld_trainer_player_in_sight(_inst);
    if (_seen_pid >= 0) return __overworld_trainer_set_approach_target(_inst, _seen_pid);
    if (variable_instance_get(_inst, "npc_path_enabled") == true) return __overworld_npc_path_step(_inst);
    return false;
}

function overworld_player_locked_by_npc(_pid){
    var _target_pid = max(0, floor(_pid));
    if (!is_undefined(pokemon_center_active_for_pid) && pokemon_center_active_for_pid(_target_pid)) return true;
    var _R = overworld_ensure_runtime();
    if (variable_struct_exists(_R, "trainer_pending")){
        var _pending = variable_struct_get(_R, "trainer_pending");
        if (is_array(_pending) && _target_pid < array_length(_pending) && is_struct(_pending[_target_pid])) return true;
    }
    for (var _i = 0; _i < instance_number(oNpc); ++_i){
        var _npc = instance_find(oNpc, _i);
        if (_npc == noone) continue;
        if (variable_instance_exists(_npc, "encounter_pokemon") && variable_instance_get(_npc, "encounter_pokemon") == true) continue;
        overworld_npc_init(_npc);
        if (variable_instance_get(_npc, "trainer_enabled") != true) continue;
        var _state = string(variable_instance_get(_npc, "trainer_state"));
        if ((_state == "approach" || _state == "dialog" || _state == "battle" || _state == "battle_wait") && floor(variable_instance_get(_npc, "trainer_target_pid")) == _target_pid) return true;
    }
    return false;
}

function overworld_npc_interact(_inst, _pid){
    if (!instance_exists(_inst)) return false;
    if (!is_undefined(oitem) && _inst.object_index == oitem && !is_undefined(overworld_item_pickup_interact)){
        return overworld_item_pickup_interact(_inst, _pid);
    }
    overworld_npc_init(_inst);
    if (!is_undefined(overworld_field_interaction_blocked) && overworld_field_interaction_blocked(_pid)) return false;
    if (variable_instance_exists(_inst, "encounter_pokemon") && variable_instance_get(_inst, "encounter_pokemon") == true) return false;
    if (variable_instance_exists(_inst, "field_move_required") && string_length(string(variable_instance_get(_inst, "field_move_required"))) > 0 && !is_undefined(field_move_prop_interact)){
        return field_move_prop_interact(_inst, _pid);
    }
    if (variable_instance_exists(_inst, "follower_pokemon") && variable_instance_get(_inst, "follower_pokemon") == true) return pokemon_follower_talk(_inst, _pid);
    if (variable_instance_exists(_inst, "pokemon_center_nurse") && variable_instance_get(_inst, "pokemon_center_nurse") == true) return pokemon_center_nurse_start(_inst, _pid);
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
    if (variable_instance_exists(_inst, "follower_pokemon") && variable_instance_get(_inst, "follower_pokemon") == true){
        return pokemon_follower_step(_inst);
    }
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
        var _tile = variable_instance_exists(_inst, "npc_tile_size") ? max(1, real(variable_instance_get(_inst, "npc_tile_size"))) : 16;
        var _next_x = variable_instance_get(_inst, "x");
        var _next_y = variable_instance_get(_inst, "y");
        for (var _try_w = 0; _try_w < 8; ++_try_w){
            var _dir = irandom(3);
            var _cand_x = __overworld_npc_snap_value(variable_instance_get(_inst, "x"), _tile);
            var _cand_y = __overworld_npc_snap_value(variable_instance_get(_inst, "y"), _tile);
            switch (_dir){
                case 0: _cand_y -= _tile; break;
                case 1: _cand_x += _tile; break;
                case 2: _cand_y += _tile; break;
                case 3: _cand_x -= _tile; break;
            }
            _cand_x = clamp(_cand_x, __overworld_npc_snap_value(_origin_x - _radius, _tile), __overworld_npc_snap_value(_origin_x + _radius, _tile));
            _cand_y = clamp(_cand_y, __overworld_npc_snap_value(_origin_y - _radius, _tile), __overworld_npc_snap_value(_origin_y + _radius, _tile));
            if (__overworld_npc_can_stand_at(_inst, _cand_x, _cand_y)){
                _next_x = _cand_x;
                _next_y = _cand_y;
                break;
            }
        }
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
    variable_instance_set(_npc, "world_solid", false);
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

function __overworld_encounter_pokemon_npc_find_clear_point(_owner, _npc, _preferred_x = undefined, _preferred_y = undefined, _tries = 24){
    if (!instance_exists(_owner) || !instance_exists(_npc)) return undefined;

    if (is_real(_preferred_x) && is_real(_preferred_y) && __overworld_encounter_pokemon_npc_rect_clear(_npc, real(_preferred_x), real(_preferred_y))){
        return { x: real(_preferred_x), y: real(_preferred_y) };
    }

    var _attempts = max(1, floor(_tries));
    for (var _try = 0; _try < _attempts; ++_try){
        var _cand = __overworld_encounter_random_point(_owner);
        if (!is_struct(_cand)) continue;
        var _cand_x = real(variable_struct_get(_cand, "x"));
        var _cand_y = real(variable_struct_get(_cand, "y"));
        if (__overworld_encounter_pokemon_npc_rect_clear(_npc, _cand_x, _cand_y)) return { x: _cand_x, y: _cand_y };
    }
    return undefined;
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

    var _coop_requested_vis = (multiplayer_queue_mode() == "coop");
    var _assist_pid_vis = _coop_requested_vis ? multiplayer_find_joined_assist_pid(_trigger_pid) : -1;
    var _coop_vis = (_assist_pid_vis >= 0);

    var _battle_format_vis = string(variable_instance_get(_owner, "encounter_battle_format"));
    if (_battle_format_vis != "double") _battle_format_vis = "single";
    var _double_chance_vis = variable_instance_exists(_owner, "encounter_double_chance") ? real(variable_instance_get(_owner, "encounter_double_chance")) : 0;
    if (_battle_format_vis != "double" && _double_chance_vis > 0 && random(1) < _double_chance_vis) _battle_format_vis = "double";
    if (_coop_requested_vis) _battle_format_vis = _coop_vis ? "double" : "single";

    var _level_min_vis = max(1, floor(variable_instance_get(_owner, "encounter_level_min")));
    var _level_max_vis = max(_level_min_vis, floor(variable_instance_get(_owner, "encounter_level_max")));
    var _species_vis = variable_instance_get(_inst, "encounter_species_id");
    var _levels_vis = variable_instance_get(_inst, "encounter_level");
    var _shinies_vis = variable_instance_exists(_inst, "encounter_shiny") && variable_instance_get(_inst, "encounter_shiny") == true;
    var _species_single_vis = _species_vis;
    var _levels_single_vis = _levels_vis;
    var _shinies_single_vis = _shinies_vis;

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
    var _opts_single_vis = {
        battle_type: "wild",
        battle_format: "single",
        enemy_species: _species_single_vis,
        enemy_levels: _levels_single_vis,
        enemy_shiny: _shinies_single_vis,
        encounter_region_key: string(variable_instance_get(_owner, "encounter_region_key")),
        encounter_habitat: string(variable_instance_get(_owner, "encounter_habitat")),
        encounter_source: "visible_bush_npc"
    };
    if (_coop_vis){
        _opts_vis.coop_enabled = true;
        _opts_vis.player_pids = [_trigger_pid, _assist_pid_vis];
    }

    var _open_level_vis = is_array(_levels_vis) ? _levels_vis[0] : _levels_vis;
    var _trigger_player_vis = player_by_pid(_trigger_pid);
    if (_trigger_player_vis != noone && !is_undefined(player_force_stand_still)) player_force_stand_still(_trigger_player_vis);
    if (_coop_vis){
        var _assist_player_vis = player_by_pid(_assist_pid_vis);
        if (_assist_player_vis != noone && !is_undefined(player_force_stand_still)) player_force_stand_still(_assist_player_vis);
        if (multiplayer_request_wild_assist_battle(_trigger_pid, _assist_pid_vis, _open_level_vis, string(variable_instance_get(_owner, "encounter_area_type")), _opts_single_vis, _opts_vis, _inst, _owner)) return true;
        _opts_vis = _opts_single_vis;
        _battle_format_vis = "single";
    }
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
    if (variable_instance_exists(_inst, "encounter_request_pending") && variable_instance_get(_inst, "encounter_request_pending") == true){
        __overworld_encounter_pokemon_npc_sprite_update(_inst, false);
        return false;
    }

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

    var _cur_x = variable_instance_get(_inst, "x");
    var _cur_y = variable_instance_get(_inst, "y");
    if (!__overworld_encounter_pokemon_npc_rect_clear(_inst, _cur_x, _cur_y)){
        var _unstick = __overworld_encounter_pokemon_npc_find_clear_point(_owner, _inst, undefined, undefined, 24);
        if (!is_struct(_unstick)){
            __overworld_encounter_remove_visible_npc(_owner, _inst, true);
            instance_destroy(_inst);
            return false;
        }
        variable_instance_set(_inst, "x", real(variable_struct_get(_unstick, "x")));
        variable_instance_set(_inst, "y", real(variable_struct_get(_unstick, "y")));
        variable_instance_set(_inst, "wander_target_x", real(variable_struct_get(_unstick, "x")));
        variable_instance_set(_inst, "wander_target_y", real(variable_struct_get(_unstick, "y")));
        __overworld_encounter_pokemon_npc_pick_target(_inst);
        __overworld_encounter_pokemon_npc_sprite_update(_inst, false);
        return true;
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
    if (!is_undefined(multiplayer_wild_assist_request_active) && multiplayer_wild_assist_request_active()) return false;
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
    if (!is_undefined(overworld_field_interaction_blocked) && overworld_field_interaction_blocked(_pid)) return false;
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

    var _p0 = player_by_pid(0);
    var _p1 = player_by_pid(1);
    if (_p0 == noone) return false;

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

    var _coop_requested = (multiplayer_queue_mode() == "coop");
    var _assist_pid = _coop_requested ? multiplayer_find_nearby_assist_pid(_trigger_pid) : -1;
    var _coop = (_assist_pid >= 0);

    var _E_lock = overworld_encounter_tables_init();
    variable_struct_set(_E_lock, "pending", true);
    global.OVERWORLD_ENCOUNTERS = _E_lock;
    variable_instance_set(_inst, "encounter_cooldown", variable_instance_get(_inst, "encounter_cooldown_frames"));
    var _level_min = max(1, floor(variable_instance_get(_inst, "encounter_level_min")));
    var _level_max = max(_level_min, floor(variable_instance_get(_inst, "encounter_level_max")));
    var _battle_format = string(variable_instance_get(_inst, "encounter_battle_format"));
    var _double_chance = variable_instance_exists(_inst, "encounter_double_chance") ? real(variable_instance_get(_inst, "encounter_double_chance")) : 0;
    if (_battle_format != "double" && _double_chance > 0 && random(1) < _double_chance) _battle_format = "double";
    if (_coop_requested) _battle_format = _coop ? "double" : "single";
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
    var _opts_single = {
        battle_type: "wild",
        battle_format: "single",
        encounter_region_key: string(variable_instance_get(_inst, "encounter_region_key")),
        encounter_habitat: string(variable_instance_get(_inst, "encounter_habitat"))
    };
    if (is_struct(_encounter_roll)){
        var _single_species = variable_struct_get(_encounter_roll, "species");
        if (is_array(_single_species) && array_length(_single_species) > 0) _single_species = _single_species[0];
        var _single_levels = variable_struct_get(_encounter_roll, "levels");
        if (is_array(_single_levels) && array_length(_single_levels) > 0) _single_levels = _single_levels[0];
        variable_struct_set(_opts_single, "enemy_species", _single_species);
        variable_struct_set(_opts_single, "enemy_levels", _single_levels);
        if (variable_struct_exists(_opts, "enemy_shiny")){
            var _single_shiny = variable_struct_get(_opts, "enemy_shiny");
            if (is_array(_single_shiny) && array_length(_single_shiny) > 0) _single_shiny = _single_shiny[0];
            variable_struct_set(_opts_single, "enemy_shiny", _single_shiny);
        }
        if (is_real(_single_levels)) _open_level = max(1, floor(_single_levels));
    }
    if (_coop){
        _opts.coop_enabled = true;
        _opts.player_pids = [_trigger_pid, _assist_pid];
    }
    var _trigger_player = player_by_pid(_trigger_pid);
    if (_trigger_player != noone && !is_undefined(player_force_stand_still)) player_force_stand_still(_trigger_player);
    if (_coop){
        var _assist_player = player_by_pid(_assist_pid);
        if (_assist_player != noone && !is_undefined(player_force_stand_still)) player_force_stand_still(_assist_player);
        if (multiplayer_request_wild_assist_battle(_trigger_pid, _assist_pid, _open_level, string(variable_instance_get(_inst, "encounter_area_type")), _opts_single, _opts)) return true;
        _opts = _opts_single;
        _battle_format = "single";
    }
    battle_open(_trigger_pid, _open_level, string(variable_instance_get(_inst, "encounter_area_type")), _opts);
    if (!is_undefined(battle_is_open) && battle_is_open(_trigger_pid)) return true;

    var _E_unlock = overworld_encounter_tables_init();
    variable_struct_set(_E_unlock, "pending", false);
    global.OVERWORLD_ENCOUNTERS = _E_unlock;
    return false;
}
