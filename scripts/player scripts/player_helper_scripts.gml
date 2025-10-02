/// player_anim_update_basic(inst, moving, dir)  (v1.4)
/// dir: 0=up, 1=right, 2=down, 3=left  (caller can pass current physics dir; we persist our own)
/// Fields used on _inst: spriteUp, spriteRight, spriteDown, spriteLeft
function player_anim_update_basic(_inst, _moving, _dir)
{
    var _walk_speed = 0.8;
    var _run_mult   = 1.5;

    // ensure we have a persistent facing (default: down)
    if (!variable_instance_exists(_inst, "facing_dir")) _inst.facing_dir = 2;

    var _pid = variable_instance_exists(_inst,"pid") ? _inst.pid : 0;

    // Input snapshot
    var _press_up    = controls_pressed(_pid, "MoveUp");
    var _press_right = controls_pressed(_pid, "MoveRight");
    var _press_down  = controls_pressed(_pid, "MoveDown");
    var _press_left  = controls_pressed(_pid, "MoveLeft");

    var _hold_up     = controls_down(_pid, "MoveUp");
    var _hold_right  = controls_down(_pid, "MoveRight");
    var _hold_down   = controls_down(_pid, "MoveDown");
    var _hold_left   = controls_down(_pid, "MoveLeft");

    // 1) If a direction was PRESSED this frame -> update facing immediately.
    if      (_press_up)    _inst.facing_dir = 0;
    else if (_press_right) _inst.facing_dir = 1;
    else if (_press_down)  _inst.facing_dir = 2;
    else if (_press_left)  _inst.facing_dir = 3;
    // 2) Otherwise, if any direction is HELD, prefer that (keeps facing while holding even if blocked).
    else if (_hold_up)     _inst.facing_dir = 0;
    else if (_hold_right)  _inst.facing_dir = 1;
    else if (_hold_down)   _inst.facing_dir = 2;
    else if (_hold_left)   _inst.facing_dir = 3;
    // 3) Otherwise keep last facing_dir (don’t fall back to _dir).

    // Choose sprite from persistent facing
    var _target = _inst.spriteDown;
    switch (_inst.facing_dir) {
        case 0: _target = _inst.spriteUp;    break;
        case 1: _target = _inst.spriteRight; break;
        case 2: _target = _inst.spriteDown;  break;
        case 3: _target = _inst.spriteLeft;  break;
    }
    if (_inst.sprite_index != _target) _inst.sprite_index = _target;

    // Animate only while actually moving; keep frame 0 when not moving
    var _run_held = controls_down(_pid, "Run");
    if (_moving) {
        _inst.image_speed = _walk_speed * (_run_held ? _run_mult : 1.0);
    } else {
        _inst.image_speed = 0;
        _inst.image_index = 0;
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
