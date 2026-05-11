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

    global.MULTIPLAYER = _M;
    if (!variable_global_exists("p2")) global.p2 = noone;
    return _M;
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

function multiplayer_spawn_player(_pid){
    var _target_pid = (is_real(_pid) ? floor(_pid) : 1);
    if (_target_pid != 1) return player_by_pid(_target_pid);
    var _existing = player_by_pid(_target_pid);
    if (_existing != noone){
        multiplayer_sync_runtime();
        return _existing;
    }
    var _spawned = instance_create_layer(__multiplayer_spawn_x(), __multiplayer_spawn_y(), "Instances", oPlayer);
    try { variable_instance_set(_spawned, "pid", _target_pid); } catch (e_multi_pid) {}
    try { variable_instance_set(_spawned, "_speed", 2); } catch (e_multi_speed) {}
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

function multiplayer_start_versus_battle(_pid){
    if (!multiplayer_player_joined(1)) return false;
    if (multiplayer_battle_open()) return false;
    if (is_undefined(battle_open_trainer) || is_undefined(__battle_ensure_slot)) return false;

    var _format = multiplayer_versus_format();
    var _target_count = (_format == "double") ? 2 : 1;
    var _enemy_party = __multiplayer_collect_versus_party(1, _target_count);
    var _p2 = player_by_pid(1);
    var _trainer_sprite = (_p2 != noone && variable_instance_exists(_p2, "trainerSprite")) ? variable_instance_get(_p2, "trainerSprite") : undefined;
    var _trainer_subimg = (_p2 != noone && variable_instance_exists(_p2, "trainerSubimg")) ? variable_instance_get(_p2, "trainerSubimg") : 0;
    var _trainer_scale = (_p2 != noone && variable_instance_exists(_p2, "trainerScale")) ? variable_instance_get(_p2, "trainerScale") : 1;
    if (array_length(_enemy_party) <= 0) return false;

    battle_open_trainer(0, {
        trainer_name: "PLAYER 2",
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
    variable_struct_set(_B, "player_pids", [0, 1]);
    variable_struct_set(_B, "coop_enabled", false);
    if (_format == "double") variable_struct_set(_B, "actor_owner_pid", [0, 0, 1, 1]);
    else variable_struct_set(_B, "actor_owner_pid", [0, 1, -1, -1]);
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

function overworld_npc_interact(_inst, _pid){
    if (!instance_exists(_inst)) return false;
    overworld_npc_init(_inst);
    if (is_undefined(dialog2p_show_now)) return false;

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
    if (variable_instance_get(_inst, "wander_enabled") != true) return false;

    var _pause = variable_instance_get(_inst, "wander_pause");
    if (_pause > 0){
        variable_instance_set(_inst, "wander_pause", _pause - 1);
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
        return true;
    }

    var _ang = point_direction(_x, _y, _tx, _ty);
    variable_instance_set(_inst, "x", _x + lengthdir_x(_speed, _ang));
    variable_instance_set(_inst, "y", _y + lengthdir_y(_speed, _ang));
    return true;
}

function overworld_encounter_init(_inst){
    if (!instance_exists(_inst)) return false;
    if (!variable_instance_exists(_inst, "encounter_enabled")) variable_instance_set(_inst, "encounter_enabled", true);
    if (!variable_instance_exists(_inst, "encounter_radius")) variable_instance_set(_inst, "encounter_radius", 14);
    if (!variable_instance_exists(_inst, "encounter_chance")) variable_instance_set(_inst, "encounter_chance", 1 / 180);
    if (!variable_instance_exists(_inst, "encounter_level_min")) variable_instance_set(_inst, "encounter_level_min", 4);
    if (!variable_instance_exists(_inst, "encounter_level_max")) variable_instance_set(_inst, "encounter_level_max", 8);
    if (!variable_instance_exists(_inst, "encounter_area_type")) variable_instance_set(_inst, "encounter_area_type", "forest");
    if (!variable_instance_exists(_inst, "encounter_battle_format")) variable_instance_set(_inst, "encounter_battle_format", "single");
    if (!variable_instance_exists(_inst, "encounter_coop_enabled")) variable_instance_set(_inst, "encounter_coop_enabled", false);
    if (!variable_instance_exists(_inst, "encounter_cooldown")) variable_instance_set(_inst, "encounter_cooldown", 0);
    if (!variable_instance_exists(_inst, "encounter_cooldown_frames")) variable_instance_set(_inst, "encounter_cooldown_frames", 45);
    return true;
}

function overworld_encounter_can_start(_pid){
    if (!is_undefined(dialog2p_is_open) && dialog2p_is_open(_pid)) return false;
    if (variable_global_exists("sys_battles") && is_array(global.sys_battles)){
        for (var _bi = 0; _bi < array_length(global.sys_battles); ++_bi){
            var _slot = global.sys_battles[_bi];
            if (!is_struct(_slot)) continue;
            if (variable_struct_exists(_slot, "sys_open") && variable_struct_get(_slot, "sys_open") == true) return false;
        }
    }
    if (!is_undefined(bag_is_open) && bag_is_open(_pid)) return false;
    if (!is_undefined(pause_is_open) && pause_is_open(_pid)) return false;
    if (!is_undefined(party_is_open) && party_is_open(_pid)) return false;
    return true;
}

function overworld_encounter_step(_inst){
    if (!instance_exists(_inst)) return false;
    overworld_encounter_init(_inst);
    if (variable_instance_get(_inst, "encounter_enabled") != true) return false;

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
    var _can_trigger = false;
    var _trigger_pid = 0;
    for (var _i = 0; _i < array_length(_players); ++_i){
        var _pl = _players[_i];
        if (_pl == noone) continue;
        var _pid = variable_instance_exists(_pl, "pid") ? variable_instance_get(_pl, "pid") : _i;
        if (!_coop && _pid != 0 && !overworld_encounter_can_start(_pid)) continue;
        if (_coop && !overworld_encounter_can_start(_pid)) continue;
        if (!variable_instance_exists(_pl, "grid") || !is_struct(variable_instance_get(_pl, "grid"))) continue;
        var _grid = variable_instance_get(_pl, "grid");
        if (!variable_struct_exists(_grid, "state") || string(variable_struct_get(_grid, "state")) != "move") continue;
        if (point_distance(variable_instance_get(_pl, "x"), variable_instance_get(_pl, "y"), variable_instance_get(_inst, "x"), variable_instance_get(_inst, "y")) > variable_instance_get(_inst, "encounter_radius")) continue;
        _can_trigger = true;
        _trigger_pid = _pid;
        break;
    }
    if (!_can_trigger) return false;
    if (random(1) > variable_instance_get(_inst, "encounter_chance")) return false;

    _coop = multiplayer_should_start_coop_for_pid(_trigger_pid, _inst_coop);
    if (_coop && _p1 == noone) _coop = false;
    if (_coop && (!overworld_encounter_can_start(0) || !overworld_encounter_can_start(1))) return false;

    variable_instance_set(_inst, "encounter_cooldown", variable_instance_get(_inst, "encounter_cooldown_frames"));
    var _level_min = max(1, floor(variable_instance_get(_inst, "encounter_level_min")));
    var _level_max = max(_level_min, floor(variable_instance_get(_inst, "encounter_level_max")));
    var _opts = {
        battle_type: "wild",
        battle_format: string(variable_instance_get(_inst, "encounter_battle_format"))
    };
    if (_coop){
        _opts.coop_enabled = true;
        _opts.player_pids = [0, 1];
        _trigger_pid = 0;
    }
    battle_open(_trigger_pid, irandom_range(_level_min, _level_max), string(variable_instance_get(_inst, "encounter_area_type")), _opts);
    return true;
}
