// ============================================================================
// ControlSystem.gml  (FINAL — global-safe)
// - Use from objects: controls_down/pressed/released(pid,"Action"), controls_axes(pid)
// - Works with keyboard + gamepad, up to 2 players
// - Stores per-frame state reliably (now, prev, pressed, released)
// - Declares CTRL as a global symbol so it's always resolvable
// ============================================================================

globalvar CTRL;

// ---- Boot ------------------------------------------------------------------
function scr_controls(){
    // Create CTRL once
    if (!variable_global_exists("CTRL") || !is_struct(CTRL)) {
        CTRL = {
            max_players : 2,
            deadzone    : 0.25,
            pad_index   : [0, 1],  // physical pads used by pid 0/1
            bind : [
                __ctrl_default_bind_p1(),
                __ctrl_default_bind_p2()
            ],
            state : [
                { now: ds_map_create(), prev: ds_map_create(), pressed: ds_map_create(), released: ds_map_create(), rep: ds_map_create(), axis_x: 0, axis_y: 0 },
                { now: ds_map_create(), prev: ds_map_create(), pressed: ds_map_create(), released: ds_map_create(), rep: ds_map_create(), axis_x: 0, axis_y: 0 }
            ]
        };
    }

    // Load options (safe even if file/keys don't exist yet)
    controls_load();
}

// ---- Defaults --------------------------------------------------------------
function __ctrl_default_bind_p1(){
    return {
        MoveLeft : { k: vk_left,  gp: noone },
        MoveRight: { k: vk_right, gp: noone },
        MoveUp   : { k: vk_up,    gp: noone },
        MoveDown : { k: vk_down,  gp: noone },
        Interact : { k: ord("Z"), gp: gp_face1 },  // A/South
        Inventory: { k: ord("C"), gp: gp_face3 },  // Y/North
        Run      : { k: ord("X"), gp: gp_face2 },  // B/East
        Back     : { k: ord("X"), gp: gp_face2 },
        PageUp   : { k: ord("A"), gp: gp_shoulderl },
        PageDown : { k: ord("S"), gp: gp_shoulderr },
        Pause    : { k: vk_enter, gp: gp_start }
    };
}
function __ctrl_default_bind_p2(){
    return {
        MoveLeft : { k: ord("A"), gp: noone },
        MoveRight: { k: ord("D"), gp: noone },
        MoveUp   : { k: ord("W"), gp: noone },
        MoveDown : { k: ord("S"), gp: noone },
        Interact : { k: ord("N"), gp: gp_face1 },
        Inventory: { k: ord("B"), gp: gp_face3 },
        Run      : { k: ord("M"), gp: gp_face2 },
        Back     : { k: ord("M"), gp: gp_face2 },
        PageUp   : { k: ord("Q"), gp: gp_shoulderl },
        PageDown : { k: ord("E"), gp: gp_shoulderr },
        Pause    : { k: vk_tab,   gp: gp_start }
    };
}

function __ctrl_ensure_bind_shape(_bind, _defaults){
    if (!is_struct(_bind)) return _defaults;
    if (!is_struct(_defaults)) return _bind;
    var _actions = variable_struct_get_names(_defaults);
    for (var _i = 0; _i < array_length(_actions); ++_i){
        var _act = _actions[_i];
        if (!variable_struct_exists(_bind, _act) || !is_struct(variable_struct_get(_bind, _act))){
            variable_struct_set(_bind, _act, variable_struct_get(_defaults, _act));
            continue;
        }
        var _dst = variable_struct_get(_bind, _act);
        var _src = variable_struct_get(_defaults, _act);
        if (!variable_struct_exists(_dst, "k")) variable_struct_set(_dst, "k", variable_struct_get(_src, "k"));
        if (!variable_struct_exists(_dst, "gp")) variable_struct_set(_dst, "gp", variable_struct_get(_src, "gp"));
        variable_struct_set(_bind, _act, _dst);
    }
    return _bind;
}

// ---- INI load/save ---------------------------------------------------------
function controls_load(){
    var b = CTRL.bind;
    var _b0 = __ctrl_ensure_bind_shape(b[0], __ctrl_default_bind_p1());
    var _b1 = __ctrl_ensure_bind_shape(b[1], __ctrl_default_bind_p2());

    ini_open(working_directory + "/options.ini");

    // P1
    _b0.MoveLeft.k   = ini_read_real("P1","MoveLeft_k",  _b0.MoveLeft.k);
    _b0.MoveRight.k  = ini_read_real("P1","MoveRight_k", _b0.MoveRight.k);
    _b0.MoveUp.k     = ini_read_real("P1","MoveUp_k",    _b0.MoveUp.k);
    _b0.MoveDown.k   = ini_read_real("P1","MoveDown_k",  _b0.MoveDown.k);
    _b0.Interact.k   = ini_read_real("P1","Interact_k",  _b0.Interact.k);
    _b0.Inventory.k  = ini_read_real("P1","Inventory_k", _b0.Inventory.k);
    _b0.Run.k        = ini_read_real("P1","Run_k",       _b0.Run.k);
    _b0.Back.k       = ini_read_real("P1","Back_k",      _b0.Back.k);
    _b0.PageUp.k     = ini_read_real("P1","PageUp_k",    _b0.PageUp.k);
    _b0.PageDown.k   = ini_read_real("P1","PageDown_k",  _b0.PageDown.k);
    _b0.Pause.k      = ini_read_real("P1","Pause_k",     _b0.Pause.k);

    // P2
    _b1.MoveLeft.k   = ini_read_real("P2","MoveLeft_k",  _b1.MoveLeft.k);
    _b1.MoveRight.k  = ini_read_real("P2","MoveRight_k", _b1.MoveRight.k);
    _b1.MoveUp.k     = ini_read_real("P2","MoveUp_k",    _b1.MoveUp.k);
    _b1.MoveDown.k   = ini_read_real("P2","MoveDown_k",  _b1.MoveDown.k);
    _b1.Interact.k   = ini_read_real("P2","Interact_k",  _b1.Interact.k);
    _b1.Inventory.k  = ini_read_real("P2","Inventory_k", _b1.Inventory.k);
    _b1.Run.k        = ini_read_real("P2","Run_k",       _b1.Run.k);
    _b1.Back.k       = ini_read_real("P2","Back_k",      _b1.Back.k);
    _b1.PageUp.k     = ini_read_real("P2","PageUp_k",    _b1.PageUp.k);
    _b1.PageDown.k   = ini_read_real("P2","PageDown_k",  _b1.PageDown.k);
    _b1.Pause.k      = ini_read_real("P2","Pause_k",     _b1.Pause.k);

    b[0] = _b0;
    b[1] = _b1;
    CTRL.bind = b;

    // Dialog speed global (1 slow, 2 normal, 3 fast)
    global.DIALOG_SPEED = ini_read_real("Dialog","speed", 2);
    CTRL.deadzone = clamp(ini_read_real("Input", "deadzone", CTRL.deadzone), 0.05, 0.95);
    global.SPLITSCREEN_LAYOUT = ini_read_string("Display", "splitscreen_layout", "vertical");
    if (string_lower(string(global.SPLITSCREEN_LAYOUT)) != "horizontal") global.SPLITSCREEN_LAYOUT = "vertical";

    ini_close();
}

function controls_save(){
    var b = CTRL.bind;
    var _b0 = __ctrl_ensure_bind_shape(b[0], __ctrl_default_bind_p1());
    var _b1 = __ctrl_ensure_bind_shape(b[1], __ctrl_default_bind_p2());

    ini_open(working_directory + "/options.ini");

    // P1
    ini_write_real("P1","MoveLeft_k",  _b0.MoveLeft.k);
    ini_write_real("P1","MoveRight_k", _b0.MoveRight.k);
    ini_write_real("P1","MoveUp_k",    _b0.MoveUp.k);
    ini_write_real("P1","MoveDown_k",  _b0.MoveDown.k);
    ini_write_real("P1","Interact_k",  _b0.Interact.k);
    ini_write_real("P1","Inventory_k", _b0.Inventory.k);
    ini_write_real("P1","Run_k",       _b0.Run.k);
    ini_write_real("P1","Back_k",      _b0.Back.k);
    ini_write_real("P1","PageUp_k",    _b0.PageUp.k);
    ini_write_real("P1","PageDown_k",  _b0.PageDown.k);
    ini_write_real("P1","Pause_k",     _b0.Pause.k);

    // P2
    ini_write_real("P2","MoveLeft_k",  _b1.MoveLeft.k);
    ini_write_real("P2","MoveRight_k", _b1.MoveRight.k);
    ini_write_real("P2","MoveUp_k",    _b1.MoveUp.k);
    ini_write_real("P2","MoveDown_k",  _b1.MoveDown.k);
    ini_write_real("P2","Interact_k",  _b1.Interact.k);
    ini_write_real("P2","Inventory_k", _b1.Inventory.k);
    ini_write_real("P2","Run_k",       _b1.Run.k);
    ini_write_real("P2","Back_k",      _b1.Back.k);
    ini_write_real("P2","PageUp_k",    _b1.PageUp.k);
    ini_write_real("P2","PageDown_k",  _b1.PageDown.k);
    ini_write_real("P2","Pause_k",     _b1.Pause.k);

    // Dialog
    ini_write_real("Dialog","speed", global.DIALOG_SPEED);
    ini_write_real("Input","deadzone", CTRL.deadzone);
    if (!variable_global_exists("SPLITSCREEN_LAYOUT")) global.SPLITSCREEN_LAYOUT = "vertical";
    ini_write_string("Display", "splitscreen_layout", string(global.SPLITSCREEN_LAYOUT));

    ini_close();
}

// ---- Queries for objects ---------------------------------------------------
function controls_down(_pid, _act){
    var st = CTRL.state[_pid];
    return ds_map_exists(st.now, _act) ? st.now[? _act] : false;
}
function controls_pressed(_pid, _act){
    var st = CTRL.state[_pid];
    return ds_map_exists(st.pressed, _act) ? st.pressed[? _act] : false;
}
function controls_released(_pid, _act){
    var st = CTRL.state[_pid];
    return ds_map_exists(st.released, _act) ? st.released[? _act] : false;
}
function controls_axes(_pid){
    var st = CTRL.state[_pid];
    return { x: st.axis_x, y: st.axis_y };
}

// ---- Per-frame build -------------------------------------------------------
function controls_update(){
    var dead = CTRL.deadzone;

    for (var pid = 0; pid < CTRL.max_players; pid++){
        var st = CTRL.state[pid];
        var bd = CTRL.bind[pid];
        var _move_left = variable_struct_get(bd, "MoveLeft");
        var _move_right = variable_struct_get(bd, "MoveRight");
        var _move_up = variable_struct_get(bd, "MoveUp");
        var _move_down = variable_struct_get(bd, "MoveDown");
        var _interact = variable_struct_get(bd, "Interact");
        var _inventory = variable_struct_get(bd, "Inventory");
        var _run = variable_struct_get(bd, "Run");
        var _back = variable_struct_get(bd, "Back");
        var _page_up = variable_struct_get(bd, "PageUp");
        var _page_down = variable_struct_get(bd, "PageDown");
        var _pause = variable_struct_get(bd, "Pause");

        // rotate maps
        ds_map_copy(st.prev, st.now);
        ds_map_clear(st.now);
        ds_map_clear(st.pressed);
        ds_map_clear(st.released);

        // digital actions (keyboard OR gamepad)
        __ctrl_set(st, "Interact",  __k_down(variable_struct_get(_interact, "k"))  || __gp_btn(CTRL.pad_index[pid], variable_struct_get(_interact, "gp")));
        __ctrl_set(st, "Inventory", __k_down(variable_struct_get(_inventory, "k")) || __gp_btn(CTRL.pad_index[pid], variable_struct_get(_inventory, "gp")));
        __ctrl_set(st, "Run",       __k_down(variable_struct_get(_run, "k"))       || __gp_btn(CTRL.pad_index[pid], variable_struct_get(_run, "gp")));
        __ctrl_set(st, "Back",      __k_down(variable_struct_get(_back, "k"))      || __gp_btn(CTRL.pad_index[pid], variable_struct_get(_back, "gp")));
        __ctrl_set(st, "PageUp",    __k_down(variable_struct_get(_page_up, "k"))   || __gp_btn(CTRL.pad_index[pid], variable_struct_get(_page_up, "gp")));
        __ctrl_set(st, "PageDown",  __k_down(variable_struct_get(_page_down, "k")) || __gp_btn(CTRL.pad_index[pid], variable_struct_get(_page_down, "gp")));
        __ctrl_set(st, "Pause",     __k_down(variable_struct_get(_pause, "k"))     || __gp_btn(CTRL.pad_index[pid], variable_struct_get(_pause, "gp")));

        // axes (keyboard dpad + left stick)
        var ax = 0, ay = 0;
        if (__k_down(variable_struct_get(_move_left, "k")))  ax -= 1;
        if (__k_down(variable_struct_get(_move_right, "k"))) ax += 1;
        if (__k_down(variable_struct_get(_move_up, "k")))    ay -= 1;
        if (__k_down(variable_struct_get(_move_down, "k")))  ay += 1;

        var pad = CTRL.pad_index[pid];
        if (gamepad_is_connected(pad)){
            var sx = gamepad_axis_value(pad, gp_axislh);
            var sy = gamepad_axis_value(pad, gp_axislv);
            if (abs(sx) < dead) sx = 0;
            if (abs(sy) < dead) sy = 0;
            if (gamepad_button_check(pad, gp_padl)) sx = -1;
            else if (gamepad_button_check(pad, gp_padr)) sx = 1;
            if (gamepad_button_check(pad, gp_padu)) sy = -1;
            else if (gamepad_button_check(pad, gp_padd)) sy = 1;
            ax += sx;
            ay += sy;
        }

        ax = clamp(ax, -1, 1);
        ay = clamp(ay, -1, 1);
        st.axis_x = ax;
        st.axis_y = ay;

        // synthesize 4-way booleans (grid/anim)
        __ctrl_set(st, "MoveLeft",  (ax < -dead) || __k_down(variable_struct_get(_move_left, "k")));
        __ctrl_set(st, "MoveRight", (ax >  dead) || __k_down(variable_struct_get(_move_right, "k")));
        __ctrl_set(st, "MoveUp",    (ay < -dead) || __k_down(variable_struct_get(_move_up, "k")));
        __ctrl_set(st, "MoveDown",  (ay >  dead) || __k_down(variable_struct_get(_move_down, "k")));

        // pressed/released edges
        __ctrl_edges(st, "Interact");
        __ctrl_edges(st, "Inventory");
        __ctrl_edges(st, "Run");
        __ctrl_edges(st, "Back");
        __ctrl_edges(st, "PageUp");
        __ctrl_edges(st, "PageDown");
        __ctrl_edges(st, "Pause");
        __ctrl_edges(st, "MoveLeft");
        __ctrl_edges(st, "MoveRight");
        __ctrl_edges(st, "MoveUp");
        __ctrl_edges(st, "MoveDown");
    }
}

// ---- Small internals -------------------------------------------------------
function __k_down(_vk){ return keyboard_check(_vk); }
function __gp_btn(_pad, _btn){
    return (_btn != noone) && gamepad_is_connected(_pad) && gamepad_button_check(_pad, _btn);
}
function __ctrl_set(_st, _act, _is_down){ ds_map_replace(_st.now, _act, _is_down); }
function __ctrl_edges(_st, _act){
    var n = (ds_map_exists(_st.now,  _act) ? _st.now[? _act]  : false);
    var p = (ds_map_exists(_st.prev, _act) ? _st.prev[? _act] : false);
    ds_map_replace(_st.pressed,  _act, ( n && !p));
    ds_map_replace(_st.released, _act, (!n && p));
}

// ---- List of actions (for UI/rebinding tools) ------------------------------
function controls_actions(){ return ["MoveLeft","MoveRight","MoveUp","MoveDown","Interact","Inventory","Run","Back","PageUp","PageDown","Pause"]; }

// Repeat helper: returns true on initial press and then repeatedly while held
// using an initial delay and then a repeat interval (both in frames).
function controls_repeat(_pid, _act, _initial_delay, _repeat_interval){
    var st = CTRL.state[_pid];
    var init = (is_undefined(_initial_delay) ? 12 : _initial_delay);
    var interval = (is_undefined(_repeat_interval) ? 4 : _repeat_interval);

    // On edge-press: fire immediately and initialize the timer
    if (controls_pressed(_pid, _act)){
        ds_map_replace(st.rep, _act, init);
        return true;
    }

    // While held: decrement timer and fire when it reaches zero, then reset to interval
    if (controls_down(_pid, _act)){
        var has = ds_map_exists(st.rep, _act);
        var cur = has ? st.rep[? _act] : init;
        cur -= 1;
        if (cur <= 0){
            ds_map_replace(st.rep, _act, interval);
            return true;
        } else {
            ds_map_replace(st.rep, _act, cur);
            return false;
        }
    }

    // Not held: clear any repeat state and return false
    if (ds_map_exists(st.rep, _act)) ds_map_delete(st.rep, _act);
    return false;
}
