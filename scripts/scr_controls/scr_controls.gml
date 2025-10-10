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
                { now: ds_map_create(), prev: ds_map_create(), pressed: ds_map_create(), released: ds_map_create(), axis_x: 0, axis_y: 0 },
                { now: ds_map_create(), prev: ds_map_create(), pressed: ds_map_create(), released: ds_map_create(), axis_x: 0, axis_y: 0 }
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
        Pause    : { k: vk_tab,   gp: gp_start }
    };
}

// ---- INI load/save ---------------------------------------------------------
function controls_load(){
    var b = CTRL.bind;

    ini_open(working_directory + "/options.ini");

    // P1
    b[0].MoveLeft.k   = ini_read_real("P1","MoveLeft_k",  b[0].MoveLeft.k);
    b[0].MoveRight.k  = ini_read_real("P1","MoveRight_k", b[0].MoveRight.k);
    b[0].MoveUp.k     = ini_read_real("P1","MoveUp_k",    b[0].MoveUp.k);
    b[0].MoveDown.k   = ini_read_real("P1","MoveDown_k",  b[0].MoveDown.k);
    b[0].Interact.k   = ini_read_real("P1","Interact_k",  b[0].Interact.k);
    b[0].Inventory.k  = ini_read_real("P1","Inventory_k", b[0].Inventory.k);
    b[0].Run.k        = ini_read_real("P1","Run_k",       b[0].Run.k);
    b[0].Pause.k      = ini_read_real("P1","Pause_k",     b[0].Pause.k);

    // P2
    b[1].MoveLeft.k   = ini_read_real("P2","MoveLeft_k",  b[1].MoveLeft.k);
    b[1].MoveRight.k  = ini_read_real("P2","MoveRight_k", b[1].MoveRight.k);
    b[1].MoveUp.k     = ini_read_real("P2","MoveUp_k",    b[1].MoveUp.k);
    b[1].MoveDown.k   = ini_read_real("P2","MoveDown_k",  b[1].MoveDown.k);
    b[1].Interact.k   = ini_read_real("P2","Interact_k",  b[1].Interact.k);
    b[1].Inventory.k  = ini_read_real("P2","Inventory_k", b[1].Inventory.k);
    b[1].Run.k        = ini_read_real("P2","Run_k",       b[1].Run.k);
    b[1].Pause.k      = ini_read_real("P2","Pause_k",     b[1].Pause.k);

    // Dialog speed global (1 slow, 2 normal, 3 fast)
    global.DIALOG_SPEED = ini_read_real("Dialog","speed", 2);

    ini_close();
}

function controls_save(){
    var b = CTRL.bind;

    ini_open(working_directory + "/options.ini");

    // P1
    ini_write_real("P1","MoveLeft_k",  b[0].MoveLeft.k);
    ini_write_real("P1","MoveRight_k", b[0].MoveRight.k);
    ini_write_real("P1","MoveUp_k",    b[0].MoveUp.k);
    ini_write_real("P1","MoveDown_k",  b[0].MoveDown.k);
    ini_write_real("P1","Interact_k",  b[0].Interact.k);
    ini_write_real("P1","Inventory_k", b[0].Inventory.k);
    ini_write_real("P1","Run_k",       b[0].Run.k);
    ini_write_real("P1","Pause_k",     b[0].Pause.k);

    // P2
    ini_write_real("P2","MoveLeft_k",  b[1].MoveLeft.k);
    ini_write_real("P2","MoveRight_k", b[1].MoveRight.k);
    ini_write_real("P2","MoveUp_k",    b[1].MoveUp.k);
    ini_write_real("P2","MoveDown_k",  b[1].MoveDown.k);
    ini_write_real("P2","Interact_k",  b[1].Interact.k);
    ini_write_real("P2","Inventory_k", b[1].Inventory.k);
    ini_write_real("P2","Run_k",       b[1].Run.k);
    ini_write_real("P2","Pause_k",     b[1].Pause.k);

    // Dialog
    ini_write_real("Dialog","speed", global.DIALOG_SPEED);

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

        // rotate maps
        ds_map_copy(st.prev, st.now);
        ds_map_clear(st.now);
        ds_map_clear(st.pressed);
        ds_map_clear(st.released);

        // digital actions (keyboard OR gamepad)
        __ctrl_set(st, "Interact",  __k_down(bd.Interact.k)  || __gp_btn(CTRL.pad_index[pid], bd.Interact.gp));
        __ctrl_set(st, "Inventory", __k_down(bd.Inventory.k) || __gp_btn(CTRL.pad_index[pid], bd.Inventory.gp));
        __ctrl_set(st, "Run",       __k_down(bd.Run.k)       || __gp_btn(CTRL.pad_index[pid], bd.Run.gp));
        __ctrl_set(st, "Pause",     __k_down(bd.Pause.k)     || __gp_btn(CTRL.pad_index[pid], bd.Pause.gp));

        // axes (keyboard dpad + left stick)
        var ax = 0, ay = 0;
        if (__k_down(bd.MoveLeft.k))  ax -= 1;
        if (__k_down(bd.MoveRight.k)) ax += 1;
        if (__k_down(bd.MoveUp.k))    ay -= 1;
        if (__k_down(bd.MoveDown.k))  ay += 1;

        var pad = CTRL.pad_index[pid];
        if (gamepad_is_connected(pad)){
            var sx = gamepad_axis_value(pad, gp_axislh);
            var sy = gamepad_axis_value(pad, gp_axislv);
            if (abs(sx) < dead) sx = 0;
            if (abs(sy) < dead) sy = 0;
            ax += sx;
            ay += sy;
        }

        ax = clamp(ax, -1, 1);
        ay = clamp(ay, -1, 1);
        st.axis_x = ax;
        st.axis_y = ay;

        // synthesize 4-way booleans (grid/anim)
        __ctrl_set(st, "MoveLeft",  (ax < -dead) || __k_down(bd.MoveLeft.k));
        __ctrl_set(st, "MoveRight", (ax >  dead) || __k_down(bd.MoveRight.k));
        __ctrl_set(st, "MoveUp",    (ay < -dead) || __k_down(bd.MoveUp.k));
        __ctrl_set(st, "MoveDown",  (ay >  dead) || __k_down(bd.MoveDown.k));

        // pressed/released edges
        __ctrl_edges(st, "Interact");
        __ctrl_edges(st, "Inventory");
        __ctrl_edges(st, "Run");
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
function controls_actions(){ return ["MoveLeft","MoveRight","MoveUp","MoveDown","Interact","Inventory","Run","Pause"]; }
