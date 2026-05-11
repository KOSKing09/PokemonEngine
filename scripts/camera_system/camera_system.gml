function CameraSystem(){

}

/// Split-screen presentation helpers.
/// "vertical" means a vertical divider: P1 left, P2 right.
/// "horizontal" means a horizontal divider: P1 top, P2 bottom.
function splitscreen_get_layout(){
    if (!variable_global_exists("SPLITSCREEN_LAYOUT")) global.SPLITSCREEN_LAYOUT = "vertical";
    var _layout = string_lower(string(global.SPLITSCREEN_LAYOUT));
    if (_layout != "horizontal") _layout = "vertical";
    global.SPLITSCREEN_LAYOUT = _layout;
    return _layout;
}

function splitscreen_set_layout(_layout){
    var _next = string_lower(string(_layout));
    if (_next != "horizontal") _next = "vertical";
    global.SPLITSCREEN_LAYOUT = _next;
    if (!is_undefined(controls_save)) controls_save();
    splitscreen_apply_gui_size();
}

function splitscreen_toggle_layout(){
    splitscreen_set_layout(splitscreen_get_layout() == "vertical" ? "horizontal" : "vertical");
}

function splitscreen_load_options(){
    if (!variable_global_exists("SPLITSCREEN_LAYOUT")) global.SPLITSCREEN_LAYOUT = "vertical";
    try {
        ini_open(working_directory + "/options.ini");
        var _saved = ini_read_string("Display", "splitscreen_layout", global.SPLITSCREEN_LAYOUT);
        ini_close();
        global.SPLITSCREEN_LAYOUT = (string_lower(string(_saved)) == "horizontal") ? "horizontal" : "vertical";
    } catch (e_split_load) {
        global.SPLITSCREEN_LAYOUT = "vertical";
    }
}

function battle_uses_shared_screen(_pid){
    if (is_undefined(__battle_ensure_slot)) return false;
    var _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B)) return false;
    if (!variable_struct_exists(_B, "sys_open") || variable_struct_get(_B, "sys_open") != true) return false;
    var _fmt = variable_struct_exists(_B, "battle_format") ? string_lower(string(variable_struct_get(_B, "battle_format"))) : "single";
    var _coop = variable_struct_exists(_B, "coop_enabled") && variable_struct_get(_B, "coop_enabled") == true;
    return (_fmt == "double" && _coop);
}

function splitscreen_should_use_shared_screen(){
    return (!is_undefined(battle_uses_shared_screen) && (battle_uses_shared_screen(0) || battle_uses_shared_screen(1)));
}

function splitscreen_active(){
    return (instance_number(oPlayer) > 1 && !splitscreen_should_use_shared_screen());
}

function splitscreen_apply_gui_size(){
    if (splitscreen_should_use_shared_screen() || instance_number(oPlayer) <= 1){
        display_set_gui_size(240, 160);
        return;
    }
    if (splitscreen_get_layout() == "horizontal") display_set_gui_size(240, 320);
    else display_set_gui_size(480, 160);
}

function splitscreen_get_gui_rect(_pid){
    splitscreen_apply_gui_size();
    if (instance_number(oPlayer) <= 1 || splitscreen_should_use_shared_screen()) return [0, 0, 240, 160];
    if (splitscreen_get_layout() == "horizontal") return [0, (_pid == 1 ? 160 : 0), 240, 160];
    return [(_pid == 1 ? 240 : 0), 0, 240, 160];
}

function splitscreen_layout_label(){
    return (splitscreen_get_layout() == "horizontal") ? "SPLIT HORIZ" : "SPLIT VERT";
}

/// scr_cam_shake.gml
/// Small camera shake helper: create → start → update.
/// USAGE:
///   shake = cam_shake_create();
///   cam_shake_start(shake, 8, 18, 24, 0.9); // amp, frames, freqHz-ish, decay [0..1]
///   var ofs = cam_shake_update(shake);  // returns {x, y}

function cam_shake_create(){
    return {
        amp      : 0,      // current amplitude (pixels)
        time     : 0,      // frames remaining
        base_amp : 0,      // starting amplitude (for decay)
        freq     : 24,     // oscillations per second-ish (frame-based)
        phase_x  : irandom_range(0, 100000),
        phase_y  : irandom_range(0, 100000),
        decay    : 0.9,    // per-frame decay multiplier (0..1)
        offx     : 0,
        offy     : 0
    };
}

function cam_shake_start(sh, amplitude, duration_frames, freq_hz, decay_mul){
    sh.amp      = max(0, amplitude);
    sh.base_amp = sh.amp;
    sh.time     = max(0, duration_frames);
    sh.freq     = max(0.001, freq_hz);
    sh.decay    = clamp(decay_mul, 0, 1);
    // randomize phases so X/Y don’t match
    sh.phase_x  = irandom_range(0, 100000);
    sh.phase_y  = irandom_range(0, 100000);
}

function cam_shake_update(sh){
    if (sh.time > 0){
        // advance phases (frame-based; if you use delta, multiply by delta seconds)
        sh.phase_x += sh.freq * 0.1047; // ~2π/60 ≈ 0.1047 per “hz” unit
        sh.phase_y += sh.freq * 0.1047 * 1.37;

        // decaying sine offsets in a rough circle/ellipse
        var ax = sh.amp * sin(sh.phase_x);
        var ay = sh.amp * cos(sh.phase_y);

        // small random jitter so repeated hits feel varied
        ax += random_range(-0.35, 0.35);
        ay += random_range(-0.35, 0.35);

        sh.offx = ax;
        sh.offy = ay;

        // decay + countdown
        sh.amp  *= sh.decay;
        sh.time -= 1;
        if (sh.time <= 0){ sh.offx = 0; sh.offy = 0; sh.amp = 0; }
    } else {
        sh.offx = 0; sh.offy = 0;
    }
    return { x: sh.offx, y: sh.offy };
}
