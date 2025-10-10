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
