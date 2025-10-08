// [Party System]: party_system — Build v4.39.0 — Updated 2025-10-05
// Notes:
// - Controller + Keyboard only (no mouse use)
// - Unified description box: Pokemon flavor text (summary_profile) or Move text (summary_moves/forget)
// - Inventory+Arrows to scroll description
// - "Run/B" navigation: list <-> profile <-> moves <-> forget (back one level)
// - Interact-hold no longer moves selection
// - Color highlighting (first occurrence only): damage class + effect words + all types
// - Tunable art position via macros below
// - Scrollbar: brown fill + thin black outline, shifted 6px to the right
//   Use false in your player/controller code to suppress movement.

globalvar PARTY;
globalvar sys_party_desc_scroll_req;

#macro PARTY_ICON_H_UI 20
#macro PARTY_ROW_PAD_UI 2
#macro PARTY_HILITE_COL make_color_rgb(255,255,255)
#macro PARTY_HILITE_EDGE make_color_rgb(136,100,36)
#macro PARTY_HILITE_ALPHA 0.20

// Summary art offsets inside left panel
#macro PARTY_SUMMARY_ART_OFFSET_Y  8   // +down, -up (tweak as needed)
#macro PARTY_SUMMARY_ART_OFFSET_X  0   // +right, -left
#macro PARTY_SUMMARY_ART_MARGIN    2   // min gap above description

// Shiny sparkle tuning (icon list)
#macro PARTY_SHINY_SPARKLE_BASE_R    4   // base radius in UI pixels (scaled by _S)
#macro PARTY_SHINY_SPARKLE_ROT_SPEED 180 // deg/sec
#macro PARTY_SHINY_SPARKLE_PULSE_HZ  5   // pulse frequency

function __party_draw_shiny_sparkle(_x,_y,_S,_seed){
    // Stable animated sparkle (diamond + cross) that rotates & pulses.
    var t_ms = current_time;
    var t    = t_ms / 1000;
    var rot  = (t * PARTY_SHINY_SPARKLE_ROT_SPEED + _seed * 37) mod 360;
    var pulse = 0.55 + 0.45 * sin(t * PARTY_SHINY_SPARKLE_PULSE_HZ + _seed);
    var r  = PARTY_SHINY_SPARKLE_BASE_R * _S * pulse;
    var r2 = r * 0.55;

    // Outer glow diamond (two filled triangles)
    draw_set_alpha(0.80 * pulse);
    draw_set_color(make_color_rgb(255,240,110));
    var x1 = _x + lengthdir_x(r, rot);
    var y1 = _y + lengthdir_y(r, rot);
    var x3 = _x + lengthdir_x(r, rot+180);
    var y3 = _y + lengthdir_y(r, rot+180);
    var x2 = _x + lengthdir_x(r2, rot+90);
    var y2 = _y + lengthdir_y(r2, rot+90);
    var x4 = _x + lengthdir_x(r2, rot+270);
    var y4 = _y + lengthdir_y(r2, rot+270);
    draw_triangle(x1,y1,x2,y2,x3,y3,false);
    draw_triangle(x3,y3,x4,y4,x1,y1,false);

    // Rotated cross (thin rays) — faint
    draw_set_alpha(0.55 * pulse);
    draw_set_color(make_color_rgb(255,255,200));
    var rLine = r * 1.15;
    var xA = _x + lengthdir_x(rLine, rot+45);
    var yA = _y + lengthdir_y(rLine, rot+45);
    var xB = _x + lengthdir_x(rLine, rot+225);
    var yB = _y + lengthdir_y(rLine, rot+225);
    var xC = _x + lengthdir_x(rLine, rot+135);
    var yC = _y + lengthdir_y(rLine, rot+135);
    var xD = _x + lengthdir_x(rLine, rot+315);
    var yD = _y + lengthdir_y(rLine, rot+315);
    draw_line_width(xA,yA,xB,yB,1);
    draw_line_width(xC,yC,xD,yD,1);

    // Inner core (steady)
    draw_set_alpha(1);
    draw_set_color(c_white);
    var core = max(1, r * 0.30);
    draw_rectangle(_x-core,_y-core,_x+core,_y+core,false);
    draw_set_color(c_white);
    draw_set_alpha(1);
}

// ---------- Input lock helpers ----------
// (removed) party__recompute_input_lock
// (removed) party_is_input_locked
// ---------- Basic queries / toggles ----------
function party_is_open(_pid){
    if (!variable_global_exists("PARTY")) return false;
    if (!is_array(global.PARTY)) return false;
    if (array_length(global.PARTY) <= _pid) return false;
    var _P = global.PARTY[_pid];
    if (!is_struct(_P)) return false;
    if (!variable_struct_exists(_P,"open")) return false;
    return _P.open;
}
function party_open(_pid){
    if (!variable_global_exists("PARTY")) return;
    if (!is_array(global.PARTY)) return;
    if (array_length(global.PARTY) <= _pid) return;
    var _P = global.PARTY[_pid];
    if (!is_struct(_P)) return;
    _P.open         = true;
    _P.mode         = "list";
    _P.menu_sel     = 0;
    _P.swap_index   = -1;
    _P.sum_move_sel = 0;
    _P.sum_learn_sel= 0;
    _P.lock         = 4;
}
function party_close(_pid){
    if (!variable_global_exists("PARTY")) return;
    if (!is_array(global.PARTY)) return;
    if (array_length(global.PARTY) <= _pid) return;
    var _P = global.PARTY[_pid];
    if (!is_struct(_P)) return;
    _P.open = false;
}
function party_toggle(_pid){
    if (!variable_global_exists("PARTY")) return;
    if (!is_array(global.PARTY)) return;
    if (array_length(global.PARTY) <= _pid) return;
    var _P = global.PARTY[_pid];
    if (!is_struct(_P)) return;
    _P.open = !_P.open;
    if (_P.open){
        _P.mode         = "list";
        _P.menu_sel     = 0;
        _P.swap_index   = -1;
        _P.sum_move_sel = 0;
        _P.sum_learn_sel= 0;
        _P.lock         = 4;
    }
}

// ---------- Initialization / ensure ----------
function party_init(){
    if (!variable_global_exists("PARTY")) global.PARTY = [];
    var _players = 1;
    if (variable_global_exists("PAUSE_PLAYERS_ACTIVE")) _players = max(1, global.PAUSE_PLAYERS_ACTIVE);
    array_resize(global.PARTY, _players);
    for (var _pid = 0; _pid < _players; _pid++){
        if (!is_struct(global.PARTY[_pid])){
            global.PARTY[_pid] = {
                open:false, mode:"list", sel:0, scroll:0, menu_sel:0, swap_index:-1, lock:0,
                mons:[], sum_move_sel:0, sum_learn_sel:0
            };
        }
    }
}
function party_ensure(_pid){
    if (!variable_global_exists("PARTY")) global.PARTY = [];
    if (!is_array(global.PARTY)) global.PARTY = [];
    if (array_length(global.PARTY) <= _pid) array_resize(global.PARTY, _pid + 1);
    var _P = global.PARTY[_pid];
    if (!is_struct(_P)){
        _P = { open:false, mode:"list", sel:0, scroll:0, menu_sel:0, swap_index:-1, lock:0, mons:[], sum_move_sel:0, sum_learn_sel:0 };
        global.PARTY[_pid] = _P;
    }
    if (!variable_struct_exists(_P,"open"))          _P.open         = false;
    if (!variable_struct_exists(_P,"mode"))          _P.mode         = "list";
    if (!variable_struct_exists(_P,"sel"))           _P.sel          = 0;
    if (!variable_struct_exists(_P,"scroll"))        _P.scroll       = 0;
    if (!variable_struct_exists(_P,"menu_sel"))      _P.menu_sel     = 0;
    if (!variable_struct_exists(_P,"swap_index"))    _P.swap_index   = -1;
    if (!variable_struct_exists(_P,"lock"))          _P.lock         = 0;
    if (!variable_struct_exists(_P,"mons") || !is_array(_P.mons)) _P.mons = [];
    if (!variable_struct_exists(_P,"sum_move_sel"))  _P.sum_move_sel = 0;
    if (!variable_struct_exists(_P,"sum_learn_sel")) _P.sum_learn_sel= 0;
    // New animation state vars (summary page circle intro)
        if (!variable_struct_exists(_P,"summary_anim"))        _P.summary_anim = 0;      // frame counter
        if (!variable_struct_exists(_P,"summary_anim_active"))  _P.summary_anim_active = false;
        if (!variable_struct_exists(_P,"summary_prev_mode"))    _P.summary_prev_mode = string(_P.mode);
        // Sprite cry/intro animation state (profile page)
        if (!variable_struct_exists(_P,"summary_sprite_anim"))         _P.summary_sprite_anim = 0;
        if (!variable_struct_exists(_P,"summary_sprite_anim_active"))  _P.summary_sprite_anim_active = false;
        if (!variable_struct_exists(_P,"summary_last_cry_sel"))        _P.summary_last_cry_sel = -1;
        if (!variable_struct_exists(_P,"summary_sprite_anim_start_ms")) _P.summary_sprite_anim_start_ms = -1;
    if (!variable_struct_exists(_P,"summary_cur_scale"))    _P.summary_cur_scale = 1;
    if (!variable_struct_exists(_P,"summary_target_scale")) _P.summary_target_scale = 0.6;
    if (!variable_struct_exists(_P,"summary_spin_angle"))   _P.summary_spin_angle = 0;
    if (!variable_struct_exists(_P,"summary_prev_sel"))     _P.summary_prev_sel = _P.sel;
        if (!variable_struct_exists(_P,"summary_cur_scale"))    _P.summary_cur_scale = 1;  // current scale of selected circle
        if (!variable_struct_exists(_P,"summary_target_scale")) _P.summary_target_scale = 0.6; // desired shrunk scale
        if (!variable_struct_exists(_P,"summary_spin_angle"))   _P.summary_spin_angle = 0;  // degrees

    // --- Ensure every mon has OT + IDNo (trainer ID) ---
    if (is_array(_P.mons)){
        for (var __mi = 0; __mi < array_length(_P.mons); __mi++){
            var __m = _P.mons[__mi];
            if (is_struct(__m)){
                if (!variable_struct_exists(__m, "ot")){
                    var __otName = "YOU";
                    if (variable_global_exists("PLAYER_NAME")) __otName = string(global.PLAYER_NAME);
                    if (_pid == 1 && variable_global_exists("PLAYER2_NAME")) __otName = string(global.PLAYER2_NAME);
                    __m.ot = __otName;
                }
                if (!variable_struct_exists(__m, "idno")){
                    // Deterministic-ish 5-digit ID based on species + slot + pid for stability across a run
                    var __sid_seed = -1;
                    if (variable_struct_exists(__m,"species_id")) __sid_seed = __m.species_id;
                    else if (variable_struct_exists(__m,"_id")) __sid_seed = __m._id; // fallback
                    if (!is_real(__sid_seed) || __sid_seed < 0) __sid_seed = __mi * 17 + _pid * 101;
                    var __raw = ( (__sid_seed * 7919) + (__mi * 271) + (_pid * 997) ) mod 90000; // 0..89999
                    __m.idno = 10000 + __raw; // 10000..99999
                }
            }
        }
    }

    var _n = array_length(_P.mons), _rows = 6;
    if (_n <= 0){ _P.sel = 0; _P.scroll = 0; }
    else {
        if (_P.sel >= _n) _P.sel = _n - 1;
        if (_P.sel < 0)   _P.sel = 0;
        var _max_scroll = max(0, _n - _rows);
        if (_P.scroll < 0) _P.scroll = 0;
        if (_P.scroll > _max_scroll) _P.scroll = _max_scroll;
        if (_P.sel <  _P.scroll)        _P.scroll = _P.sel;
        if (_P.sel >= _P.scroll + _rows) _P.scroll = max(0, _P.sel - _rows + 1);
    }
    return _P;
}

// ---------- Helpers ----------
function __party_mons(_pid){
    if (variable_global_exists("PARTY") && is_array(global.PARTY) && array_length(global.PARTY) > _pid){
        var _p = global.PARTY[_pid];
        if (is_struct(_p) && variable_struct_exists(_p,"mons") && is_array(_p.mons)) return _p.mons;
    }
    return [];
}
function __party_mon_get(_P, _pid){
    var _mons = __party_mons(_pid), _n = array_length(_mons);
    if (_n <= 0) return undefined;
    var _idx = _P.sel; if (_idx < 0 || _idx >= _n) return undefined;
    return _mons[_idx];
}
function __party_move_name(_id){
    if (!is_real(_id)) return "—";
    if (is_undefined(scr_move_name_by_id)) return "Move#" + string(_id);
    var _t = scr_move_name_by_id(_id);
    if (is_string(_t) && string_length(_t) > 0) return _t;
    return "Move#" + string(_id);
}

// Party Name Support Addons — v4.40.0 — 2025-10-06
// Works alongside Party System v4.39.0+ without editing it.
// Provides .name (canonical species) and .nickname fields for every mon,
// plus helpers and a one-call applicator you can run at boot and before battles.

#macro PARTY_NICKNAMES_ENABLED 1

/// mon_display_name(_mon) -> string
/// Shows nickname if present, else canonical species name, else "???"
function mon_display_name(_mon) {
    if (is_undefined(_mon)) return "???";
    if (variable_struct_exists(_mon,"nickname") && is_string(_mon.nickname) && string_length(_mon.nickname) > 0) {
        return _mon.nickname;
    }
    if (variable_struct_exists(_mon,"name") && is_string(_mon.name) && string_length(_mon.name) > 0) {
        return _mon.name;
    }
    var __sid = -1;
    if (variable_struct_exists(_mon,"species_id") && is_real(_mon.species_id)) __sid = _mon.species_id;
    else if (variable_struct_exists(_mon,"id") && is_real(_mon.id))            __sid = _mon.id;
    if (__sid > 0) return scr_poke_name_by_id(__sid);
    return "???";
}

/// party_mon_ensure_name(_mon) -> _mon (mutates + returns)
/// Guarantees .name (canonical) and .nickname fields exist on a mon struct.
function party_mon_ensure_name(_mon) {
    if (is_undefined(_mon)) return _mon;
    if (!variable_struct_exists(_mon,"nickname")) _mon.nickname = undefined;
    if (!variable_struct_exists(_mon,"name") || !is_string(_mon.name) || string_length(_mon.name) <= 0) {
        var __sid2 = -1;
        if (variable_struct_exists(_mon,"species_id") && is_real(_mon.species_id)) __sid2 = _mon.species_id;
        else if (variable_struct_exists(_mon,"id") && is_real(_mon.id))             __sid2 = _mon.id;
        _mon.name = (__sid2 > 0) ? scr_poke_name_by_id(__sid2) : "???";
    }
    return _mon;
}

/// party_apply_name_support(_pid) -> void
/// Ensures every mon in the given player's party has .name/.nickname.
function party_apply_name_support(_pid) {
    if (!PARTY_NICKNAMES_ENABLED) return;
    var __P = party_ensure(_pid);
    if (is_undefined(__P)) return;
    var __mons = __P.mons;
    var __n = array_length(__mons);
    for (var __i=0; __i<__n; ++__i) {
        var __m = __mons[__i];
        if (!is_undefined(__m)) {
            __m = party_mon_ensure_name(__m);
            __mons[__i] = __m;
        }
    }
    __P.mons = __mons;
}

/// party_set_nickname(_pid, _index, _nick) -> bool
/// Sets a nickname (or clears it when _nick empty). Returns success.
function party_set_nickname(_pid, _index, _nick) {
    if (!PARTY_NICKNAMES_ENABLED) return false;
    var __P = party_ensure(_pid);
    if (is_undefined(__P)) return false;
    var __mons = __P.mons;
    if (_index < 0 || _index >= array_length(__mons)) return false;
    var __m = __mons[_index];
    if (is_undefined(__m)) return false;
    __m = party_mon_ensure_name(__m);
    if (is_string(_nick) && string_length(_nick) > 0) __m.nickname = string(_nick);
    else __m.nickname = undefined;
    __mons[_index] = __m;
    __P.mons = __mons;
    return true;
}

/// party_ensure_named(_pid) -> party
/// Wrapper: call wherever you use party_ensure to also ensure names.
function party_ensure_named(_pid) {
    var __P = party_ensure(_pid);
    party_apply_name_support(_pid);
    return __P;
}

/// battle_test_prepare_names(_pid) -> void
/// Call before battle_open() in tests.
function battle_test_prepare_names(_pid) {
    party_apply_name_support(_pid);
}


// ---------- Update ----------
function party_update(){
    if (!variable_global_exists("PARTY")) return;
    var _players = array_length(global.PARTY); if (_players <= 0) return;

    // keep lock synced

    for (var _pid = 0; _pid < _players; _pid++){
        var _P = party_ensure(_pid);
        if (!_P.open) continue;
        if (_P.lock > 0) _P.lock--;

        var _mons = _P.mons, _n = array_length(_mons), _ROWS = 6;

        if (_P.mode != "select" && _P.mode != "summary_profile" && _P.mode != "summary_moves" && _P.mode != "summary_forget"){
            if (controls_pressed(_pid,"Run") && _P.lock == 0){ _P.open = false; _P.lock = 2; continue; }
        }

        switch (_P.mode){
            case "list": {
                if (controls_pressed(_pid,"MoveDown") && _n > 0) _P.sel = clamp(_P.sel + 1, 0, _n - 1);
                if (controls_pressed(_pid,"MoveUp")   && _n > 0) _P.sel = clamp(_P.sel - 1, 0, _n - 1);
                _P.scroll = clamp(_P.scroll, 0, max(0, _n - _ROWS));
                if (_P.sel <  _P.scroll)        _P.scroll = _P.sel;
                if (_P.sel >= _P.scroll + _ROWS) _P.scroll = max(0, _P.sel - _ROWS + 1);
                if (controls_pressed(_pid,"Interact") && _P.lock == 0){ _P.mode="menu"; _P.menu_sel=0; _P.lock=2; }
            } break;

            case "menu": {
                if (controls_pressed(_pid,"MoveDown")) _P.menu_sel = clamp(_P.menu_sel + 1, 0, 3);
                if (controls_pressed(_pid,"MoveUp"))   _P.menu_sel = clamp(_P.menu_sel - 1, 0, 3);
                if (controls_pressed(_pid,"Interact") && _P.lock == 0){
                    switch (_P.menu_sel){
                        case 0: _P.mode="summary_profile"; _P.sum_move_sel=0; _P.sum_learn_sel=0; _P.lock=2; break;
                        case 1: _P.swap_index = _P.sel; _P.mode="select"; _P.lock=2; break;
                        case 2: _P.mode="list"; _P.lock=2; break;
                        case 3: _P.mode="list"; _P.lock=2; break;
                    }
                }
                if (controls_pressed(_pid,"Run") && _P.lock == 0){ _P.mode="list"; _P.lock=2; }
            } break;

            case "select": {
                if (controls_pressed(_pid,"MoveDown") && _n > 0) _P.sel = clamp(_P.sel + 1, 0, _n - 1);
                if (controls_pressed(_pid,"MoveUp")   && _n > 0) _P.sel = clamp(_P.sel - 1, 0, _n - 1);
                _P.scroll = clamp(_P.scroll, 0, max(0, _n - _ROWS));
                if (_P.sel <  _P.scroll)        _P.scroll = _P.sel;
                if (_P.sel >= _P.scroll + _ROWS) _P.scroll = max(0, _P.sel - _ROWS + 1);
                if (controls_pressed(_pid,"Interact") && _P.lock == 0){
                    var _src = _P.swap_index, _dst = _P.sel;
                    if (_n > 0 && _src >= 0 && _src < _n && _dst >= 0 && _dst < _n && _src != _dst){
                        var _t = _mons[_src]; _mons[_src] = _mons[_dst]; _mons[_dst] = _t;
                        _P.mons = _mons; _P.sel = _dst;
                    }
                    _P.mode="list"; _P.swap_index=-1; _P.lock=2;
                }
                if (controls_pressed(_pid,"Run") && _P.lock == 0){ _P.mode="list"; _P.swap_index=-1; _P.lock=2; }
            } break;

            case "summary_profile": {
                if (controls_pressed(_pid,"MoveRight") && _n > 0){ _P.sel = clamp(_P.sel + 1, 0, _n - 1); _P.lock = 2; }
                if (controls_down(_pid,"Inventory")){
                    if (controls_pressed(_pid,"MoveLeft")){
                        if (!variable_global_exists("sys_party_desc_scroll_req")) global.sys_party_desc_scroll_req = 0;
                        global.sys_party_desc_scroll_req -= 28;
                    }
                    if (controls_pressed(_pid,"MoveRight")){
                        if (!variable_global_exists("sys_party_desc_scroll_req")) global.sys_party_desc_scroll_req = 0;
                        global.sys_party_desc_scroll_req += 28;
                    }
                }
                if (controls_pressed(_pid,"MoveLeft")  && _n > 0){ _P.sel = clamp(_P.sel - 1, 0, _n - 1); _P.lock = 2; }
                if (controls_pressed(_pid,"MoveDown")){
                    if (controls_down(_pid,"Inventory")){
                        if (!variable_global_exists("sys_party_desc_scroll_req")) global.sys_party_desc_scroll_req = 0;
                        global.sys_party_desc_scroll_req += 28;
                    } else {
                        _P.mode = "summary_moves"; _P.lock = 2;
                    }
                }
                if (controls_down(_pid,"Inventory") && controls_pressed(_pid,"MoveUp")){
                    if (!variable_global_exists("sys_party_desc_scroll_req")) global.sys_party_desc_scroll_req = 0;
                    global.sys_party_desc_scroll_req -= 28;
                }
                if (controls_pressed(_pid,"Run") && _P.lock == 0){ _P.mode = "list"; _P.lock = 2; }
            } break;

            case "summary_moves": {
                var _M  = __party_mon_get(_P, _pid);
                var _mv = is_struct(_M) && variable_struct_exists(_M,"moves") ? _M.moves : [];
                var _lr = is_struct(_M) && variable_struct_exists(_M,"learnset") ? _M.learnset : [];
                var _nm = array_length(_mv), _nl = array_length(_lr);

                if (controls_pressed(_pid,"MoveRight") && _n > 0){ _P.sel = clamp(_P.sel + 1, 0, _n - 1); _P.lock = 2; }
                if (controls_down(_pid,"Inventory")){
                    if (controls_pressed(_pid,"MoveLeft")){
                        if (!variable_global_exists("sys_party_desc_scroll_req")) global.sys_party_desc_scroll_req = 0;
                        global.sys_party_desc_scroll_req -= 28;
                    }
                    if (controls_pressed(_pid,"MoveRight")){
                        if (!variable_global_exists("sys_party_desc_scroll_req")) global.sys_party_desc_scroll_req = 0;
                        global.sys_party_desc_scroll_req += 28;
                    }
                }
                if (controls_pressed(_pid,"MoveLeft")  && _n > 0){ _P.sel = clamp(_P.sel - 1, 0, _n - 1); _P.lock = 2; }

                var _invHeld = controls_down(_pid,"Inventory");
                if (_invHeld){
                    if (controls_pressed(_pid,"MoveUp")){
                        if (!variable_global_exists("sys_party_desc_scroll_req")) global.sys_party_desc_scroll_req = 0;
                        global.sys_party_desc_scroll_req -= 28;
                    }
                    if (controls_pressed(_pid,"MoveDown")){
                        if (!variable_global_exists("sys_party_desc_scroll_req")) global.sys_party_desc_scroll_req = 0;
                        global.sys_party_desc_scroll_req += 28;
                    }
                    if (_nl > 0){
                        if (controls_pressed(_pid,"MoveDown")) _P.sum_learn_sel = clamp(_P.sum_learn_sel + 1, 0, _nl - 1);
                        if (controls_pressed(_pid,"MoveUp"))   _P.sum_learn_sel = clamp(_P.sum_learn_sel - 1, 0, _nl - 1);
                    } else _P.sum_learn_sel = 0;
                } else {
                    if (!controls_down(_pid,"Interact")){
                        if (_nm > 0){
                            if (controls_pressed(_pid,"MoveDown")) _P.sum_move_sel = clamp(_P.sum_move_sel + 1, 0, _nm - 1);
                            if (controls_pressed(_pid,"MoveUp"))   _P.sum_move_sel = clamp(_P.sum_move_sel - 1, 0, _nm - 1);
                        } else _P.sum_move_sel = 0;
                    }
                }

                if (controls_pressed(_pid,"Interact") && _P.lock == 0){
                    if (_nl > 0){
                        var _learnId = _lr[_P.sum_learn_sel];
                        if (_nm < 4){ array_push(_mv, _learnId); _M.moves = _mv; _P.sum_move_sel = array_length(_mv) - 1; _P.lock = 4; }
                        else { _P.mode = "summary_forget"; _P.lock = 2; }
                    }
                }
                if (controls_pressed(_pid,"Run") && _P.lock == 0){ _P.mode = "summary_profile"; _P.lock = 2; }
            } break;

            case "summary_forget": {
                var _M2  = __party_mon_get(_P, _pid);
                var _mv2 = is_struct(_M2) && variable_struct_exists(_M2,"moves") ? _M2.moves : [];
                var _nm2 = array_length(_mv2);
                if (_nm2 <= 0){ _P.mode = "summary_moves"; break; }
                if (controls_pressed(_pid,"MoveDown")) _P.sum_move_sel = clamp(_P.sum_move_sel + 1, 0, _nm2 - 1);
                if (controls_down(_pid,"Inventory")){
                    if (controls_pressed(_pid,"MoveLeft")){
                        if (!variable_global_exists("sys_party_desc_scroll_req")) global.sys_party_desc_scroll_req = 0;
                        global.sys_party_desc_scroll_req -= 28;
                    }
                    if (controls_pressed(_pid,"MoveRight")){
                        if (!variable_global_exists("sys_party_desc_scroll_req")) global.sys_party_desc_scroll_req = 0;
                        global.sys_party_desc_scroll_req += 28;
                    }
                }
                if (controls_pressed(_pid,"MoveUp"))   _P.sum_move_sel = clamp(_P.sum_move_sel - 1, 0, _nm2 - 1);
                var _lr2 = is_struct(_M2) && variable_struct_exists(_M2,"learnset") ? _M2.learnset : [];
                var _nl2 = array_length(_lr2);
                var _chosen = (_nl2 > 0) ? _lr2[_P.sum_learn_sel] : -1;
                if (controls_pressed(_pid,"Interact") && _P.lock == 0){
                    if (_chosen != -1){ _mv2[_P.sum_move_sel] = _chosen; _M2.moves = _mv2; _P.mode = "summary_moves"; _P.lock = 4; }
                    else { _P.mode = "summary_moves"; _P.lock = 2; }
                }
                if (controls_pressed(_pid,"Run") && _P.lock == 0){ _P.mode = "summary_moves"; _P.lock = 2; }
            } break;
        }

        // ---- Summary page animation (mode + selection driven) ----
        var _curMode = string(_P.mode);
        var _prevMode = string(_P.summary_prev_mode);
        var _isSummary_cur  = (_curMode == "summary_profile" || _curMode == "summary_moves" || _curMode == "summary_forget");
        var _isSummary_prev = (_prevMode == "summary_profile" || _prevMode == "summary_moves" || _prevMode == "summary_forget");
        if (_curMode != _prevMode){
            if (_isSummary_cur){
                _P.summary_cur_scale = 1;
                _P.summary_anim = 0;
                _P.summary_anim_active = true;
                _P.summary_spin_angle = 0;
                // If entering the profile summary page, also start the sprite intro + play cry
                if (_curMode == "summary_profile"){
                    _P.summary_sprite_anim = 0;
                    _P.summary_sprite_anim_active = true;
                    _P.summary_sprite_anim_start_ms = current_time;
                    // Play cry now (once per selection)
                    if (!is_undefined(pkicons_play_cry_by_mon)){
                        var __m_for_cry2 = __party_mon_get(_P, _pid);
                        if (is_struct(__m_for_cry2) && _P.summary_last_cry_sel != _P.sel){ pkicons_play_cry_by_mon(__m_for_cry2); _P.summary_last_cry_sel = _P.sel; }
                    }
                }
            } else if (_isSummary_prev && !_isSummary_cur){
                _P.summary_cur_scale = 1;
                _P.summary_anim_active = false;
                _P.summary_anim = 0;
                _P.summary_spin_angle = 0;
            }
            _P.summary_prev_mode = _curMode;
        }
        // Selection change inside summary triggers re-shrink
        if (_isSummary_cur){
                if (_P.sel != _P.summary_prev_sel){
                _P.summary_prev_sel = _P.sel;
                _P.summary_cur_scale = 1;
                _P.summary_anim = 0;
                _P.summary_anim_active = true;
                _P.summary_spin_angle = 0;
                // If on profile page, start sprite intro animation (time-based) and mark for cry
                if (_curMode == "summary_profile"){
                    _P.summary_sprite_anim = 0;
                    _P.summary_sprite_anim_active = true;
                    _P.summary_sprite_anim_start_ms = current_time;
                    // Play cry immediately (once per selection)
                    if (!is_undefined(pkicons_play_cry_by_mon)){
                        var __m_for_cry = __party_mon_get(_P, _pid);
                        if (is_struct(__m_for_cry) && _P.summary_last_cry_sel != _P.sel){ pkicons_play_cry_by_mon(__m_for_cry); _P.summary_last_cry_sel = _P.sel; }
                    }
                }
            }
        } else {
            _P.summary_prev_sel = _P.sel;
        }
        // Progress shrink animation (slowed & smoother)
        if (_P.summary_anim_active){
            var _DUR = 32; // slower animation (was 18)
            if (_P.summary_anim < _DUR){
                _P.summary_anim += 1;
                var _t = clamp(_P.summary_anim / _DUR, 0, 1);
                // Smoothstep easing (cubic Hermite) for gentle start/end
                var _ease = (_t * _t * (3 - 2 * _t));
                _P.summary_cur_scale = lerp(1, _P.summary_target_scale, _ease);
            } else {
                _P.summary_cur_scale = _P.summary_target_scale;
            }
        }
        // Keep a fallback old-style frame counter (not primary): cap if it grows
        if (_P.summary_sprite_anim_active){
            var _SP_DUR_FALLBACK = 60;
            if (_P.summary_sprite_anim < _SP_DUR_FALLBACK) _P.summary_sprite_anim += 1;
            else _P.summary_sprite_anim_active = false;
        }
        // Continuous spin while in summary (slower spin)
        if (_isSummary_cur){
            _P.summary_spin_angle = (_P.summary_spin_angle + 6) mod 360; // was 12
        }
    }
}

// ---------- Draw ----------
function party_draw_gui_rect(_pid, _rx, _ry, _rw, _rh){
    if (!party_is_open(_pid)) return;
    var _P = party_ensure(_pid);

    var _S  = max(1, min(floor(_rw / 240), floor(_rh / 160)));
    var _OX = _rx + (_rw - 240 * _S) div 2;
    var _OY = _ry + (_rh - 160 * _S) div 2;

    if (string(_P.mode) == "summary_profile" || string(_P.mode) == "summary_moves" || string(_P.mode) == "summary_forget"){
        __party_draw_summary(_pid, _P, _OX, _OY, _S);
        return;
    }

    var _C_BG_A    = make_color_rgb(252,236,180);
    var _C_BG_B    = make_color_rgb(248,220,140);
    var _C_PAPER   = make_color_rgb(255,243,195);
    var _C_PAPER_E = make_color_rgb(136,100,36);

    var _stripe_h = 8;
    for (var _yy = 0; _yy < 160; _yy += _stripe_h){
        draw_set_color( ((_yy div _stripe_h) & 1) == 1 ? _C_BG_B : _C_BG_A );
        draw_rectangle(_OX, _OY + _yy*_S, _OX + 240*_S, _OY + (_yy+_stripe_h)*_S, false);
    }

    var _LIST_X = 120, _LIST_Y = 8,  _LIST_W = 112, _LIST_H = 144;
    var _INFO_X = 8,   _INFO_Y = 98, _INFO_W = 104, _INFO_H = 54;

    var _lx1 = _OX + _LIST_X*_S,            _ly1 = _OY + _LIST_Y*_S;
    var _lx2 = _OX + (_LIST_X+_LIST_W)*_S,  _ly2 = _OY + (_LIST_Y+_LIST_H)*_S;
    draw_set_color(_C_PAPER);   draw_rectangle(_lx1, _ly1, _lx2, _ly2, false);
    draw_set_color(_C_PAPER_E); draw_rectangle(_lx1 - _S, _ly1 - _S, _lx2 + _S, _ly2 + _S, true);

    if (variable_global_exists("FNT_POKEMON")) draw_set_font(global.FNT_POKEMON); else draw_set_font(-1);
    draw_set_color(c_white);

    var _mons  = _P.mons;
    var _n     = array_length(_mons);
    var _ROWS  = 6;
    var _ROW_H = max(12, string_height("A") + 2);

    var sprSelector     = spr_selector;
    var sprPlaceholder  = spr_mon_icon_placeholder;

    for (var _r = 0; _r < _ROWS; _r++){
        var _idx = _P.scroll + _r; if (_idx >= _n) break;
        var _M = _mons[_idx];
        var _row_y_gui = _OY + (_LIST_Y + 8 + _r*(_ROW_H + PARTY_ROW_PAD_UI)) * _S;

        if (_idx == _P.sel){
            var _rx1 = _OX + (_LIST_X + 2) * _S;
            var _ry1 = _row_y_gui - (_ROW_H * 0.65) * _S;
            var _rx2 = _OX + (_LIST_X + _LIST_W - 2) * _S;
            var _ry2 = _ry1 + (_ROW_H * 1.25) * _S;
            draw_set_alpha(PARTY_HILITE_ALPHA);
            draw_set_color(PARTY_HILITE_COL);
            draw_rectangle(_rx1, _ry1, _rx2, _ry2, false);
            draw_set_alpha(1);
            draw_set_color(PARTY_HILITE_EDGE);
            draw_rectangle(_rx1, _ry1, _rx2, _ry2, true);
            draw_set_color(c_white);
        }

        if (_idx == _P.sel){
            var _sh2 = max(1, sprite_get_height(sprSelector));
            var _tgt2 = _ROW_H * _S;
            var _sc2  = _tgt2 / _sh2;
            draw_sprite_ext(sprSelector, 0, _OX + (_LIST_X + 2)*_S - 10*_S, _row_y_gui - _tgt2*0.15, _sc2, _sc2, 0, c_white, 1);
        }

        var _sprDown = -1;
        if (!is_undefined(pkicons_get_icon32_dir_by_mon)) _sprDown = pkicons_get_icon32_dir_by_mon(_M, "down");
        var _hasIcon = (_sprDown != -1);
        if (!_hasIcon){ _sprDown = sprPlaceholder; _hasIcon = true; }

        var _drawnIconW_ui = 0;
        if (_hasIcon){
            var _frame = 0;
            if (!is_undefined(pkicons_icon32_frame_ui)) _frame = pkicons_icon32_frame_ui();
            var _ih = max(1, sprite_get_height(_sprDown));
            var _target_h_gui = PARTY_ICON_H_UI * _S;
            var _sc_icon = _target_h_gui / _ih;
            var _ix_gui = _OX + (_LIST_X + 2) * _S;
            var _iw_gui = sprite_get_width(_sprDown) * _sc_icon;
            var _iy_gui = _row_y_gui - _target_h_gui * 0.5;
            draw_sprite_ext(_sprDown, _frame, floor(_ix_gui), floor(_iy_gui), _sc_icon, _sc_icon, 0, c_white, 1);
            // Sparkle overlay (new helper) – visually animated & stable
            if (is_struct(_M) && variable_struct_exists(_M,"shiny") && _M.shiny){
                var _cx = floor(_ix_gui + _iw_gui * 0.65);
                var _cy = floor(_iy_gui + _target_h_gui * 0.30);
                __party_draw_shiny_sparkle(_cx,_cy,_S,_idx);
            }
            _drawnIconW_ui = ceil((_iw_gui) / _S);
        } else {
            _drawnIconW_ui = 18;
        }

        var _disp_name = "???";
        if (is_struct(_M)){
            if (variable_struct_exists(_M,"species_id")){
                var _sid = _M.species_id;
                if (is_real(_sid) && _sid >= 0){
                    var _idn = scr_poke_name_by_id(_sid);
                    if (string_length(_idn) > 0){
                        _disp_name = string_replace_all(_idn, "-", " ");
                        if (string_length(_disp_name) > 0){
                            _disp_name = string_upper(string_copy(_disp_name,1,1)) + string_delete(_disp_name,1,1);
                        }
                    }
                }
            } else if (variable_struct_exists(_M,"species")) _disp_name = string(_M.species);
            else if (variable_struct_exists(_M,"name"))     _disp_name = string(_M.name);
        }
        var _name_x_ui = 120 + 2 + _drawnIconW_ui + 6;
        var _name_x_gui = _OX + _name_x_ui * _S;
        draw_text(_name_x_gui, _row_y_gui, _disp_name);
    }

    var _ix1 = _OX + _INFO_X*_S, _iy1 = _OY + _INFO_Y*_S;
    var _ix2 = _OX + (_INFO_X+_INFO_W)*_S, _iy2 = _OY + (_INFO_Y+_INFO_H)*_S;
    draw_set_color(_C_PAPER);   draw_rectangle(_ix1, _iy1, _ix2, _iy2, false);
    draw_set_color(_C_PAPER_E); draw_rectangle(_ix1 - _S, _iy1 - _S, _ix2 + _S, _iy2 + _S, true);

    if (_n > 0){
        var _Li = clamp(_P.sel, 0, _n - 1);
        var _L = _mons[_Li];

        var _nm_disp = "???";
        if (is_struct(_L)){
            if (variable_struct_exists(_L,"species_id")){
                var _sid2 = _L.species_id;
                if (is_real(_sid2) && _sid2 >= 0){
                    var _idn2 = scr_poke_name_by_id(_sid2);
                    if (string_length(_idn2) > 0){
                        _nm_disp = string_replace_all(_idn2, "-", " ");
                        if (string_length(_nm_disp) > 0){
                            _nm_disp = string_upper(string_copy(_nm_disp,1,1)) + string_delete(_nm_disp,1,1);
                        }
                    }
                }
            } else if (variable_struct_exists(_L,"species")) _nm_disp = string(_L.species);
            else if (variable_struct_exists(_L,"name"))     _nm_disp = string(_L.name);
        }
        draw_set_color(c_white);
        draw_text(_ix1 + 6*_S, _iy1 + 6*_S, _nm_disp);

        var _nature_txt = "—";
        if (is_struct(_L)){
            if (variable_struct_exists(_L,"nature"))      _nature_txt = string(_L.nature);
            else if (variable_struct_exists(_L,"Nature")) _nature_txt = string(_L.Nature);
            else if (variable_struct_exists(_L,"nat"))    _nature_txt = string(_L.nat);
        }
        draw_text(_ix1 + 6*_S, _iy1 + 20*_S, "Nature: " + _nature_txt);

        var _hp_cur = 0; if (is_struct(_L)){ if (variable_struct_exists(_L,"hp")) _hp_cur = _L.hp; else if (variable_struct_exists(_L,"HP")) _hp_cur = _L.HP; }
        var _hp_max = 1; if (is_struct(_L)){ if (variable_struct_exists(_L,"maxhp")) _hp_max = _L.maxhp; else if (variable_struct_exists(_L,"hp_max")) _hp_max = _L.hp_max; }
        if (!is_real(_hp_max) || _hp_max <= 0) _hp_max = max(1, _hp_cur);

        var _lvl_val = 1; if (is_struct(_L)){ if (variable_struct_exists(_L,"level")) _lvl_val = _L.level; else if (variable_struct_exists(_L,"lvl")) _lvl_val = _L.lvl; }

        var _bar_x = _ix1 + 6*_S, _bar_y = _iy1 + 34*_S, _bar_w = (_INFO_W - 12) * _S, _bar_h = 6 * _S;
        draw_set_color(_C_PAPER_E); draw_rectangle(_bar_x - _S, _bar_y - _S, _bar_x + _bar_w + _S, _bar_y + _bar_h + _S, true);

        var _ratio = (_hp_max > 0) ? clamp(_hp_cur / _hp_max, 0, 1) : 0;
        var _hp_col = (_ratio >= 0.5) ? make_color_rgb(56,200,72) : (_ratio >= 0.2 ? make_color_rgb(248,200,40) : make_color_rgb(232,64,48));
        var _fill_w = floor(_bar_w * _ratio);
        draw_set_color(_hp_col); draw_rectangle(_bar_x, _bar_y, _bar_x + _fill_w, _bar_y + _bar_h, false);

        var _hp_txt = string(_hp_cur) + " / " + string(_hp_max);
        var _hp_tx  = _bar_x + _bar_w - string_width(_hp_txt);
        var _hp_ty  = _bar_y + _bar_h + (2*_S) + 6;

        draw_set_color(c_white);
        draw_text(_bar_x, _hp_ty, "Lv " + string(_lvl_val));
        draw_text(_hp_tx, _hp_ty, _hp_txt);
    }

    if (string(_P.mode) == "menu"){
        var _MX = 96, _MY = 20, _MW = 76, _MH = 84;
        var _bx1 = _OX + _MX*_S;
        var _by1 = _OY + _MY*_S;
        var _bx2 = _OX + (_MX+_MW)*_S;
        var _by2 = _OY + (_MY+_MH)*_S;

        draw_set_color(_C_PAPER);   draw_rectangle(_bx1, _by1, _bx2, _by2, false);
        draw_set_color(_C_PAPER_E); draw_rectangle(_bx1 - _S, _by1 - _S, _bx2 + _S, _by2 + _S, true);

        if (variable_global_exists("FNT_POKEMON")) draw_set_font(global.FNT_POKEMON); else draw_set_font(-1);
        draw_set_color(c_white);

        var _items = ["Summary","Switch","Item","Cancel"];
        var _m_h   = max(12, string_height("A") + 2);
        for (var _i = 0; _i < 4; _i++){
            var _yy_menu = _by1 + (6 + _i*_m_h);
            if (_i == _P.menu_sel){
                var _selh = max(1, sprite_get_height(spr_selector));
                var _tgt  = _m_h;
                var _sc   = _tgt / _selh;
                draw_sprite_ext(spr_selector, 0, _bx1 + 4*_S, _yy_menu - _tgt*0.15, _sc, _sc, 0, c_white, 1);
            }
            draw_text(_bx1 + 16*_S, _yy_menu, _items[_i]);
        }
    }
}

// ---------- Summary / Description ----------
function __party_draw_summary(_pid, _P, _OX, _OY, _S){
    var _C_BG    = make_color_rgb(224, 216, 248);
    var _C_PAPER = make_color_rgb(255, 255, 255);
    var _C_EDGE  = make_color_rgb(64, 56, 112);
    var _C_ACC   = make_color_rgb(208, 48, 48);
    var _C_TEXT  = c_white;

    draw_set_color(_C_BG);   draw_rectangle(_OX, _OY, _OX + 240*_S, _OY + 160*_S, false);
    draw_set_color(_C_EDGE); draw_rectangle(_OX, _OY, _OX + 240*_S, _OY + 20*_S, true);

    var _mons = __party_mons(_pid), _n = array_length(_mons);
    // Top hints: L/R Switch (left), Up: Profile (right) when in moves/forget modes; in profile show Up: Moves maybe
    var _modeStr = string(_P.mode);
    draw_set_color(c_white);
    if (_modeStr == "summary_moves" || _modeStr == "summary_forget"){
        var _hintY = _OY + 10*_S; // moved further down (+4px from previous)
        draw_text(_OX + 4*_S, _hintY, "L/R: Switch");
        var _profileHint = "Up: Profile";
        var _phW = string_width(_profileHint);
        draw_text(_OX + 240*_S - _phW - 4*_S, _hintY, _profileHint);
    } else if (_modeStr == "summary_profile") {
        var _movesHint = "Up: Moves"; // Assuming Up returns to moves list
        var _mhW = string_width(_movesHint);
        var _hintY2 = _OY + 10*_S; // match moved hint position
        draw_text(_OX + 240*_S - _mhW - 4*_S, _hintY2, _movesHint);
    }
    var _radBase = 3; // base circle radius (scaled by _S)
    var _spinAng = _P.summary_spin_angle; // continuous spin angle (deg)
    var _isSummary = (string(_P.mode) == "summary_profile" || string(_P.mode) == "summary_moves" || string(_P.mode) == "summary_forget");
    for (var _i = 0; _i < 6; _i++){
    var _cx = _OX + (104 + _i*12)*_S - 20*_S; // shifted further left (total 20px) and reduced gap (16->12)
    var _cy = _OY + 12*_S; // lowered slightly to sit between new hint line and header area
        var _col = (_i < _n) ? (_i == _P.sel ? _C_ACC : _C_PAPER) : make_color_rgb(136,136,136);
        draw_set_color(_col);
        var _r = _radBase * _S;
        if (_i == _P.sel && _isSummary){
            var _scale = _P.summary_cur_scale; // stays shrunk until page changes
            draw_circle(_cx, _cy, _r * _scale, false);
            // Spinning spoke
            var _len = _r * 0.9 * _scale;
            var _x2 = _cx + lengthdir_x(_len, _spinAng);
            var _y2 = _cy + lengthdir_y(_len, _spinAng);
            draw_set_color(_C_ACC);
            draw_line(_cx, _cy, _x2, _y2);
            draw_set_color(_col);
        } else {
            draw_circle(_cx, _cy, _r, false);
        }
    }

    var _LEFT_X = 8, _LEFT_Y = 24, _LEFT_W = 96, _LEFT_H = 120;
    var _RIGHT_X = 108, _RIGHT_Y = 24, _RIGHT_W = 124, _RIGHT_H = 120;
    var _lx1 = _OX + _LEFT_X*_S,  _ly1 = _OY + _LEFT_Y*_S;
    var _lx2 = _OX + (_LEFT_X + _LEFT_W)*_S, _ly2 = _OY + (_LEFT_Y + _LEFT_H)*_S;
    var _rx1 = _OX + _RIGHT_X*_S, _ry1 = _OY + _RIGHT_Y*_S;
    var _rx2 = _OX + (_RIGHT_X + _RIGHT_W)*_S, _ry2 = _OY + (_RIGHT_Y + _RIGHT_H)*_S;

    draw_set_color(_C_PAPER); draw_rectangle(_lx1, _ly1, _lx2, _ly2, false);
    draw_set_color(_C_EDGE);  draw_rectangle(_lx1- _S, _ly1- _S, _lx2+ _S, _ly2+ _S, true);
    draw_set_color(_C_PAPER); draw_rectangle(_rx1, _ry1, _rx2, _ry2, false);
    draw_set_color(_C_EDGE);  draw_rectangle(_rx1- _S, _ry1- _S, _rx2+ _S, _ry2+ _S, true);

    var _DESC_PAD = 3 * _S;
    var _DESC_AREA_H = 38 * _S;

    if (variable_global_exists("FNT_POKEMON")) draw_set_font(global.FNT_POKEMON); else draw_set_font(-1);
    draw_set_color(_C_TEXT);

    var _M = __party_mon_get(_P, _pid);
    if (is_struct(_M)){
        var _nm = "???";
        if (variable_struct_exists(_M,"species_id") && is_real(_M.species_id)){
            var _idn = scr_poke_name_by_id(_M.species_id);
            if (string_length(_idn) > 0){
                _nm = string_replace_all(_idn, "-", " ");
                if (string_length(_nm) > 0) _nm = string_upper(string_copy(_nm,1,1)) + string_delete(_nm,1,1);
            }
        } else if (variable_struct_exists(_M,"species")) _nm = string(_M.species);
        else if (variable_struct_exists(_M,"name"))     _nm = string(_M.name);
        draw_text(_lx1 + 6*_S, _ly1 + 6*_S, _nm);

        var _sprArt = -1;
        if (!is_undefined(pkicons_get_art96_by_mon)) _sprArt = pkicons_get_art96_by_mon(_M);
        if (_sprArt == -1) _sprArt = spr_mon_placeholder;

        if (_sprArt != -1){
            var _artW = sprite_get_width(_sprArt), _artH = sprite_get_height(_sprArt);
            var _innerW   = (_LEFT_W - 12) * _S;
            var _topY     = _ly1 + 18 * _S;
            var _bottomY  = _ly2 - _DESC_AREA_H - PARTY_SUMMARY_ART_MARGIN * _S;
            var _availH   = max(1, _bottomY - _topY);
            var _sc   = min(_innerW / _artW, _availH / _artH);
            var _dx   = _lx1 + (_LEFT_W * _S - _artW * _sc) * 0.5 + (PARTY_SUMMARY_ART_OFFSET_X * _S);
            var _idealY = _topY + (_availH - _artH * _sc) * 0.5;
            var _dy   = clamp(_idealY + (PARTY_SUMMARY_ART_OFFSET_Y * _S), _topY, _bottomY - _artH * _sc);
            var _sub = 0;
            if (!is_undefined(pkicons_get_art96_subimg_by_mon)) _sub = pkicons_get_art96_subimg_by_mon(_M,false);

            // Apply profile sprite intro animation: scale-up then back + subtle shake
            var _anim_scale = 1;
            var _anim_offx = 0;
            var _anim_offy = 0;
            if (is_struct(_P) && variable_struct_exists(_P,"summary_sprite_anim_start_ms") && _P.summary_sprite_anim_active){
                var _start = _P.summary_sprite_anim_start_ms;
                var _D_ms = 420; // duration in milliseconds (~420ms)
                var _elapsed = max(0, current_time - _start);
                var _t = clamp(_elapsed / _D_ms, 0, 1);
                var _peak = 1.18;
                // Ease: quick rise then ease back (use sine ease for smoothness)
                var _rise = sin(min(_t * 1.6, 1) * pi * 0.5); // fast initial ease
                if (_t < 0.6) _anim_scale = lerp(1, _peak, _rise);
                else _anim_scale = lerp(_peak, 1, ( _t - 0.6 ) / 0.4 );

                // Subtle shake decaying over time
                var _shake_amp = 2 * _S * (1 - _t);
                var _time_s = current_time / 1000;
                _anim_offx = lengthdir_x(_shake_amp, (_time_s*360 + (_P.sel*37)) mod 360);
                _anim_offy = lengthdir_y(_shake_amp, (_time_s*360 + (_P.sel*51)) mod 360);

                // End animation when elapsed fully done
                if (_t >= 1){ _P.summary_sprite_anim_active = false; _P.summary_sprite_anim_start_ms = -1; }
            }

            draw_sprite_ext(_sprArt, _sub, _dx + _anim_offx, _dy + _anim_offy, _sc * _anim_scale, _sc * _anim_scale, 0, c_white, 1);
            // Sparkle overlay for shiny in summary (larger, positioned near upper-right of art)
            if (is_struct(_M) && variable_struct_exists(_M,"shiny") && _M.shiny && !is_undefined(__party_draw_shiny_sparkle)){
                var _sx = _dx + _artW * _sc * 0.78;
                var _sy = _dy + _artH * _sc * 0.22;
                __party_draw_shiny_sparkle(_sx,_sy,_S, (_M.species_id) ?? 0);
            }
        }

        // (debug overlay removed) pkicons debug drawing is disabled to avoid UI clutter

        var _lvl = 1; if (variable_struct_exists(_M,"level")) _lvl = _M.level; else if (variable_struct_exists(_M,"lvl")) _lvl = _M.lvl;
        var _name_lh = max(12, string_height("A") + 2) * _S;
        draw_text(_lx1 + 6*_S, _ly1 + 6*_S + _name_lh, "Lv " + string(_lvl));
    }

    var _descPad   = _DESC_PAD;
    var _descAreaH = _DESC_AREA_H;
    var _descX     = _lx1 + _descPad;
    var _descY     = _ly2 - _descAreaH + _descPad;
    var _descW     = min((_LEFT_W + 10) * _S, (_RIGHT_X - _LEFT_X - 4) * _S) - _descPad*2;
    var _descH     = _descAreaH - _descPad*2;

    var _descText = "";
    if (string(_P.mode) == "summary_profile") {
        var _sid_desc = -1;
        if (variable_struct_exists(_M,"species_id")) _sid_desc = _M.species_id;
        else if (variable_struct_exists(_M,"_id"))   _sid_desc = _M._id;
        if (_sid_desc >= 0 && variable_global_exists("_species_flavor_text")) {
            var _sarr = global._species_flavor_text;
            if (is_array(_sarr) && _sid_desc < array_length(_sarr)) {
                var _sv = _sarr[_sid_desc];
                if (!is_undefined(_sv)) _descText = string(_sv);
            }
        }
    } else {
        var _mid_show = -1;
        var _mv_arr = is_struct(_M) && variable_struct_exists(_M,"moves") ? _M.moves : [];
        if (array_length(_mv_arr) > 0) {
            if (_P.sum_move_sel >= 0 && _P.sum_move_sel < array_length(_mv_arr)) {
                _mid_show = _mv_arr[_P.sum_move_sel];
            }
        }
        if (_mid_show > 0 && variable_global_exists("_move_text")) {
            var _mt = global._move_text;
            if (is_array(_mt) && _mid_show < array_length(_mt)) {
                var _vv = _mt[_mid_show];
                if (is_struct(_vv)) {
                    var _sd = (!is_undefined(_vv.short_desc)) ? string(_vv.short_desc) : "";
                    var _ef = (!is_undefined(_vv.effect)) ? string(_vv.effect) : "";
                    _descText = (string_length(_sd) > 0) ? _sd : _ef;
                } else if (is_string(_vv)) {
                    _descText = _vv;
                }
            }
        }
    }
    if (string_length(_descText) > 0) {
        var _clean = __party_desc_clean_local(_descText);
        __party_desc_draw_scrollable_colored(_descX, _descY, _descW, _descH, _clean);
    }

    var _secondaryLine = "";
    if (string(_P.mode) == "summary_profile"){
        __party_draw_profile_block(_M, _rx1, _ry1, _RIGHT_W, _RIGHT_H, _S);
        // Draw IDNo outside (below) the profile box, centered relative to box width
        if (is_struct(_M)){
            var _idno_ext = "";
            if (variable_struct_exists(_M,"idno")) _idno_ext = string(_M.idno);
            if (string_length(_idno_ext) > 0){
                var _id_label = "IDNo " + _idno_ext;
                var _bx_center = _rx1 + (_RIGHT_W*_S) * 0.5;
                var _id_w2 = string_width(_id_label);
                var _id_draw_x2 = floor(_bx_center - _id_w2 * 0.5);
                var _below_gap = 9*_S; // gap below box (moved down ~5px)
                draw_text(_id_draw_x2, _ry2 + _below_gap, _id_label);
            }
        }
    } else if (string(_P.mode) == "summary_moves"){
        _secondaryLine = __party_draw_moves_block(_P, _M, _rx1, _ry1, _RIGHT_W, _RIGHT_H, _S, false);
    } else if (string(_P.mode) == "summary_forget"){
        _secondaryLine = __party_draw_moves_block(_P, _M, _rx1, _ry1, _RIGHT_W, _RIGHT_H, _S, true);
    }

    // Draw secondary help spanning full width (if provided) starting at far left of both boxes.
    if (string_length(_secondaryLine) > 0){
        var _fullLeft  = _OX + 0; // absolute far left of summary region
        var _fullRight = _OX + 240*_S; // total width of summary background
        var _availW = _fullRight - _fullLeft - 4*_S; // small right padding
        var _drawX = _fullLeft + 2*_S; // slight left pad so text not hugging edge
    var _baseY = _ly2 + 11*_S; // moved further down (+4px)
        draw_set_color(c_white);
        var _wordsH = string_split(_secondaryLine, " ");
        var _linesH = [];
        var _accH = "";
        for (var hi=0; hi<array_length(_wordsH); hi++){
            var wH = _wordsH[hi];
            var tH = (_accH=="")? wH : (_accH + " " + wH);
            if (string_width(tH) <= _availW){
                _accH = tH;
            } else {
                if (string_length(_accH) > 0) array_push(_linesH, _accH);
                _accH = wH;
            }
            if (array_length(_linesH) >= 2) break; // max 2 lines
        }
        if (array_length(_linesH) < 2 && string_length(_accH) > 0) array_push(_linesH, _accH);
        if (array_length(_linesH) > 2) array_resize(_linesH, 2);
        if (array_length(_linesH) == 2 && hi < array_length(_wordsH)){
            var lastH = _linesH[1];
            while (string_width(lastH + "...") > _availW && string_length(lastH) > 5){
                lastH = string_copy(lastH,1,string_length(lastH)-1);
            }
            if (string_length(lastH) > 3) lastH += "...";
            _linesH[1] = lastH;
        }
        var _lineHeight = max(12, string_height("A") + 2);
        for (var lhi=0; lhi<array_length(_linesH); lhi++){
            draw_text(_drawX, _baseY + lhi * _lineHeight, _linesH[lhi]);
        }
    }
}

// ---------- Summary helpers ----------
function __party_draw_profile_block(_M, _x, _y, _w, _h, _S){
    var _C_LABEL = make_color_rgb(40, 96, 96);
    var _lh = max(12, string_height("A") + 2) * _S;
    draw_set_color(c_white); draw_text(_x + 6*_S, _y + 6*_S, "PROFILE");
    draw_set_color(_C_LABEL);
    draw_text(_x + 6*_S, _y + 6*_S + _lh*1, "OT/");
    draw_text(_x + 6*_S, _y + 6*_S + _lh*2, "TYPE/");
    draw_text(_x + 6*_S, _y + 6*_S + _lh*3, "ABILITY/");
    draw_text(_x + 6*_S, _y + 6*_S + _lh*5, "TRAINER MEMO");
    draw_set_color(c_white);
    var _ot="—", _idno="—", _typ="—", _abi="—", _nat="—", _metLv="—", _metMp="—";
    if (is_struct(_M)){
        if (variable_struct_exists(_M,"ot"))   _ot   = string(_M.ot);
        if (variable_struct_exists(_M,"idno")) _idno = string(_M.idno);

        // Resolve type names. Accept several shapes: _M.type (string or array of strings),
        // _M.types (array of numeric ids), or _M.type1/_M.type2 numeric ids.
        var _type_names = [];
        // If mon provided readable type strings
        if (variable_struct_exists(_M,"type")){
            if (is_array(_M.type)){
                for (var ti=0; ti<array_length(_M.type); ti++) array_push(_type_names, string(_M.type[ti]));
            } else {
                array_push(_type_names, string(_M.type));
            }
        }
        // If numeric ids provided in .types array
        if (array_length(_type_names) == 0 && variable_struct_exists(_M,"types") && is_array(_M.types)){
            for (var ti2=0; ti2<array_length(_M.types); ti2++){
                var tid = _M.types[ti2];
                if (is_real(tid)) array_push(_type_names, "#"+string(tid));
            }
        }
        // If individual type1/type2 numeric fields
        if (array_length(_type_names) == 0){
            if (variable_struct_exists(_M,"type1") && is_real(_M.type1) && _M.type1 >= 0) array_push(_type_names, "#"+string(_M.type1));
            if (variable_struct_exists(_M,"type2") && is_real(_M.type2) && _M.type2 >= 0) array_push(_type_names, "#"+string(_M.type2));
        }

        // Translate numeric placeholders (#id) to human names using TYPE_ID_BY_NAME if available,
        // otherwise fall back to a builtin ordered list (1-based index).
        for (var tn = 0; tn < array_length(_type_names); tn++){
            var cur = _type_names[tn];
            if (string_length(cur) > 0 && string_char_at(cur,1) == "#"){
                var nid = real(string_delete(cur,1,1));
                var resolved = "";
                // Try reverse lookup in TYPE_ID_BY_NAME (map name->id) by scanning keys
                if (variable_global_exists("TYPE_ID_BY_NAME") && ds_exists(TYPE_ID_BY_NAME, ds_type_map)){
                    var _k = ds_map_find_first(TYPE_ID_BY_NAME);
                    while(_k != undefined){
                        var _v = ds_map_find_value(TYPE_ID_BY_NAME, _k);
                        if (is_real(_v) && _v == nid){ resolved = string(_k); break; }
                        _k = ds_map_find_next(TYPE_ID_BY_NAME, _k);
                    }
                }
                if (string_length(resolved) == 0){
                    // builtin fallback (common order, 1-based)
                    var __builtin = ["Normal","Fire","Water","Electric","Grass","Ice","Fighting","Poison","Ground","Flying","Psychic","Bug","Rock","Ghost","Dark","Dragon","Steel","Fairy"];
                    if (nid >= 1 && nid <= array_length(__builtin)) resolved = __builtin[nid];
                    else resolved = "Type"+string(nid);
                }
                _type_names[tn] = resolved;
            } else {
                // Clean up string type names (capitalize)
                var s = string(cur);
                if (string_length(s) > 0) _type_names[tn] = string_upper(string_copy(s,1,1)) + string_delete(s,1,1);
            }
        }

        if (array_length(_type_names) > 0){
            if (array_length(_type_names) == 1) _typ = _type_names[0];
            else _typ = _type_names[0] + " / " + _type_names[1];
        }

        if (variable_struct_exists(_M,"ability"))  _abi  = string(_M.ability);
        if (variable_struct_exists(_M,"nature"))   _nat  = string(_M.nature);
        if (variable_struct_exists(_M,"met_level")) _metLv = string(_M.met_level);
        if (variable_struct_exists(_M,"met_map"))   _metMp = string(_M.met_map);
    }
    // Draw OT value immediately after the OT/ label baseline.
    // Reposition: IDNo centered near the top row; OT remains on second line after label.
    // (Removed inline IDNo drawing; now drawn outside box in summary function)
    var _ot_label_x = _x + 6*_S;
    var _ot_value_x = _ot_label_x + string_width("OT/") + 4;
    draw_text(_ot_value_x, _y + 6*_S + _lh*1, _ot);
    // Draw TYPE value immediately after the "TYPE/" label baseline
    var _type_label_x = _x + 6*_S;
    var _type_value_x = _type_label_x + string_width("TYPE/") + 4;
    draw_text(_type_value_x, _y + 6*_S + _lh*2, _typ);
    draw_text(_x + 60*_S, _y + 6*_S + _lh*3, _abi);
    draw_text(_x + 6*_S,  _y + 6*_S + _lh*6, string_upper(_nat) + " nature,");
    draw_text(_x + 6*_S,  _y + 6*_S + _lh*7, "met at Lv." + _metLv + ",");
    draw_text(_x + 6*_S,  _y + 6*_S + _lh*8, _metMp + ".");
}
function __party_draw_moves_block(_P, _M, _x, _y, _w, _h, _S, _highlightForget){
    var _lh = max(12, string_height("A") + 2) * _S;
    draw_set_color(c_white);
    draw_text(_x + 6*_S, _y + 6*_S, "MOVES");
    // (removed) LEARNSET header

    var _mv = is_struct(_M) && variable_struct_exists(_M,"moves") ? _M.moves : [];
    var _nm = array_length(_mv);
    for (var _i = 0; _i < max(4,_nm); _i++){
        var _lineY = _y + 20*_S + _lh*_i;
        var _txt = (_i < _nm) ? __party_move_name(_mv[_i]) : "—";
        draw_set_color( _i == _P.sum_move_sel ? (_highlightForget ? make_color_rgb(232,64,48) : make_color_rgb(72,200,88)) : c_white );
        draw_text(_x + 10*_S, _lineY, _txt);
    }

    var _lr = is_struct(_M) && variable_struct_exists(_M,"learnset") ? _M.learnset : [];
    var _nl = array_length(_lr);
    for (var _j = 0; _j < _nl; _j++){
        var _lineY2 = _y + 20*_S + _lh*_j;
        var _txt2 = __party_move_name(_lr[_j]);
        draw_set_color( _j == _P.sum_learn_sel ? make_color_rgb(72,160,232) : c_white );
        draw_text(_x + (_w*_S) - 110*_S, _lineY2, _txt2);
    }

    draw_set_color(c_white);
    // --- Help text (bottom multi-line wrap within panel) ---
    // Split help: primary A/B inside panel; secondary under panel
    var _primaryHelp, _secondaryHelp;
    if (_highlightForget){
        _primaryHelp   = "A: Confirm  B: Back";
        _secondaryHelp = "(Choose a move to overwrite)"; // Top hints (L/R, Profile) drawn separately
    } else {
        _primaryHelp   = "A: Learn  B: Back";
        // Removed L/R: Switch and Up: Profile from here; they are now drawn at top bar.
        _secondaryHelp = "Hold Inv+Up/Down: Learnset";
    }
    // (Removed legacy _helpFull multi-line logic)
    // Draw primary help as stacked A/B lines
    var _tx = _x + 6*_S;
    var _lhh = max(12, string_height("A") + 2);
    var _innerBottomPad = 6*_S;
    var _pMaxW = (_w*_S) - 12*_S;
    var _aLine, _bLine;
    if (_highlightForget){ _aLine = "A: Confirm"; _bLine = "B: Back"; }
    else { _aLine = "A: Learn"; _bLine = "B: Back"; }
    function _party_trunc_line(_t,_mw){
        if (string_width(_t) <= _mw) return _t;
        while (string_width(_t + "...") > _mw && string_length(_t) > 4){
            _t = string_copy(_t,1,string_length(_t)-1);
        }
        if (string_length(_t) > 3) _t += "...";
        return _t;
    }
    _aLine = _party_trunc_line(_aLine,_pMaxW);
    _bLine = _party_trunc_line(_bLine,_pMaxW);
    var _pyBottom = _y + (_h*_S) - _lhh - _innerBottomPad;
    var _pyTop    = _pyBottom - _lhh;
    draw_text(_tx, _pyTop, _aLine);
    draw_text(_tx, _pyBottom, _bLine);
    // Return secondary help so caller can draw a single full-width line spanning both boxes
    return _secondaryHelp;
}

// ---------- Text helpers ----------
function __party_desc_clean_local(_s){
    var _t = string(_s);
    _t = string_replace_all(_t, "\n", " ");
    _t = string_replace_all(_t, "\r", " ");
    _t = string_replace_all(_t, "\f", " ");
    _t = string_replace_all(_t, "\\n", " ");
    _t = string_replace_all(_t, "\\r", " ");
    _t = string_replace_all(_t, "\\f", " ");
    while (string_pos("  ", _t) > 0) _t = string_replace_all(_t, "  ", " ");
    return string_trim(_t);
}

// --- Scrollable & colored text renderer (first occurrence highlight) ---
function __party_desc_draw_scrollable_colored(_x, _y, _w, _h, _text) {
    if (string_length(string(_text)) <= 0) return;

    // Reset scroll if content changed (compare hash/key)
    static _scroll = 0;
    static _lastKey = "";
    // Use the raw text as a key; if you later want faster compare you can build a shorter signature
    var _key = string(_text);
    if (_key != _lastKey) { _scroll = 0; _lastKey = _key; }

    var _restoreTo = -1;
    if (variable_global_exists("FNT_POKEMON")) _restoreTo = global.FNT_POKEMON;
    if (variable_global_exists("FNT_POKEMON_SMALL")) draw_set_font(global.FNT_POKEMON_SMALL);

    draw_set_halign(fa_left);
    draw_set_valign(fa_top);

    var _words = string_split(string(_text), " ");
    var _lines = [];
    var _cur = "";
    var _i, _n = array_length(_words);

    for (_i = 0; _i < _n; _i++) {
        var _test = (_cur == "") ? _words[_i] : (_cur + " " + _words[_i]);
        if (string_width(_test) <= _w) {
            _cur = _test;
        } else {
            if (string_length(_cur) == 0) {
                var _word = _words[_i];
                var _k, _seg = "";
                for (_k = 1; _k <= string_length(_word); _k++) {
                    var _segTest = _seg + string_copy(_word, _k, 1);
                    if (string_width(_segTest) > _w) {
                        array_push(_lines, _seg);
                        _seg = string_copy(_word, _k, 1);
                    } else {
                        _seg = _segTest;
                    }
                }
                _cur = _seg;
            } else {
                array_push(_lines, _cur);
                _cur = _words[_i];
            }
        }
    }
    if (string_length(_cur) > 0) array_push(_lines, _cur);

    var _lineH = max(12, string_height("A") + 2);
    var _totalH = array_length(_lines) * _lineH;

    // _scroll already declared earlier in this function (static). Apply scroll delta.
    if (variable_global_exists("sys_party_desc_scroll_req")){
        _scroll += global.sys_party_desc_scroll_req;
        global.sys_party_desc_scroll_req = 0;
    }
    var _maxScroll = max(0, _totalH - _h);
    if (_scroll < 0) _scroll = 0;
    if (_scroll > _maxScroll) _scroll = _maxScroll;

    var _hitPhysical=false, _hitSpecial=false, _hitStatus=false, _hitHeal=false, _hitDefense=false;
    var _hitType = ds_map_create();
    var _types = ["fire","water","grass","electric","ice","fighting","psychic","dark","fairy","ground","flying","rock","steel","bug","ghost","dragon","poison"];
    for (var ti = 0; ti < array_length(_types); ti++) ds_map_add(_hitType, _types[ti], 0);

    var _startLine = floor(_scroll / _lineH);
    var _offsetY = -(_scroll - (_startLine * _lineH));
    var _yPos = _y + _offsetY;

    for (var li = _startLine; li < array_length(_lines); li++) {
        if (_yPos + _lineH > _y + _h) break;

        var L = _lines[li];
        var parts = string_split(L, " ");
        var xx = _x;
        for (var wi = 0; wi < array_length(parts); wi++){
            var w = parts[wi];
            var wlower = string_lower(w);
            var core = wlower;
            core = string_replace_all(core, ",", "");
            core = string_replace_all(core, ".", "");
            core = string_replace_all(core, "!", "");
            core = string_replace_all(core, "?", "");

            var useCol = c_white;

            if (!_hitPhysical && core == "physical"){ useCol = make_color_rgb(255,140,120); _hitPhysical = true; }
            else if (! _hitSpecial && core == "special"){ useCol = make_color_rgb(120,180,255); _hitSpecial = true; }
            else if (! _hitStatus && core == "status"){ useCol = make_color_rgb(255,240,140); _hitStatus = true; }
            else if (! _hitHeal && core == "heal"){ useCol = make_color_rgb(120,255,160); _hitHeal = true; }
            else if (! _hitDefense && (core == "defense" || core == "defensive")){ useCol = make_color_rgb(200,200,200); _hitDefense = true; }
            else {
                if (ds_map_exists(_hitType, core) && (ds_map_find_value(_hitType, core) == 0)){
                    var col = c_white;
                    switch (core){
                        case "fire": col = make_color_rgb(255,150,80); break;
                        case "water": col = make_color_rgb(100,180,255); break;
                        case "grass": col = make_color_rgb(100,220,120); break;
                        case "electric": col = make_color_rgb(255,235,120); break;
                        case "ice": col = make_color_rgb(190,250,255); break;
                        case "fighting": col = make_color_rgb(240,100,100); break;
                        case "psychic": col = make_color_rgb(255,120,255); break;
                        case "dark": col = make_color_rgb(150,100,80); break;
                        case "fairy": col = make_color_rgb(255,200,255); break;
                        case "ground": col = make_color_rgb(220,180,100); break;
                        case "flying": col = make_color_rgb(200,240,255); break;
                        case "rock": col = make_color_rgb(220,200,140); break;
                        case "steel": col = make_color_rgb(200,200,220); break;
                        case "bug": col = make_color_rgb(180,220,100); break;
                        case "ghost": col = make_color_rgb(180,130,220); break;
                        case "dragon": col = make_color_rgb(120,100,255); break;
                        case "poison": col = make_color_rgb(200,120,200); break;
                    }
                    useCol = col;
                    ds_map_replace(_hitType, core, 1);
                }
            }

            draw_set_color(useCol);
            draw_text(xx, _yPos, parts[wi]);
            var adv = string_width(parts[wi]);
            xx += adv + string_width(" ");
        }

        _yPos += _lineH;
    }

    var _totalH2 = array_length(_lines) * _lineH;
    var _maxScroll2 = max(0, _totalH2 - _h);
    
// Replace old broken scrollbar drawing with corrected version
if (_maxScroll2 > 0) {
    // Track geometry (black bar)
    var _trackW   = 5; // width in pixels
    var _trackH   = _h;
    // Position 3px to the right of original flush-right edge
    var _trackX1  = _x + _w - _trackW + 3; 
    var _trackY1  = _y;
    var _trackX2  = _trackX1 + _trackW;
    var _trackY2  = _trackY1 + _trackH;
    var _inset    = 1; // inner padding for thumb

    var _oldCol   = draw_get_color();
    var _oldAlpha = draw_get_alpha();

    // Draw filled black track (was outline-only before due to outline=true misuse)
    draw_set_alpha(1);
    draw_set_color(c_black);
    draw_rectangle(_trackX1, _trackY1, _trackX2, _trackY2, false); // filled
    // Optional outline (keep subtle). Comment out if not desired.
    draw_set_color(c_white);
    draw_rectangle(_trackX1, _trackY1, _trackX2, _trackY2, true); // outline only

    // Thumb height proportional to visible fraction; guarantee minimum height
    var _visibleFrac = clamp(_h / _totalH2, 0, 1);
    var _thumbH      = max(8, floor((_trackH - _inset*2) * _visibleFrac));
    var _t           = (_maxScroll2 > 0) ? (_scroll / _maxScroll2) : 0;
    var _usableH     = (_trackH - _inset*2 - _thumbH); // travel distance
    var _thumbTop    = _trackY1 + _inset + floor(_usableH * _t);
    var _thumbBot    = _thumbTop + _thumbH;

    // Filled selector (brown) centered within track
    draw_set_color(make_color_rgb(160,120,64));
    draw_rectangle(_trackX1 + _inset, _thumbTop, _trackX2 - _inset, _thumbBot, false); // filled

    // Optional outline for clarity
    draw_set_color(c_black);
    draw_rectangle(_trackX1 + _inset, _thumbTop, _trackX2 - _inset, _thumbBot, true); // outline only

    // Restore state
    draw_set_alpha(_oldAlpha);
    draw_set_color(_oldCol);
}
    if (_restoreTo != -1) draw_set_font(_restoreTo);
}

// ---------- Entrypoint ----------
function party_draw_gui(_pid){
    var _gw = display_get_gui_width();
    var _gh = display_get_gui_height();
    party_draw_gui_rect(_pid, 0, 0, _gw, _gh);
}

// [Party UI]: party__draw_scrollbar — Build v1.3 — 2025-10-05
function party__draw_scrollbar(_rx, _ry, _rw, _rh, _scroll, _pageSize, _totalItems) {
    // Named parameters: _rx, _ry, _rw, _rh, _scroll, _pageSize, _totalItems

    var _oldCol = draw_get_color();
    var _oldAlpha = draw_get_alpha();

    var _inset = 1;
    var _visible = max(1, _pageSize);
    var _total = max(_visible, _totalItems);
    var _maxScroll = max(0, _total - _visible);
    var _t = 0;
    if (_maxScroll > 0) { _t = clamp(_scroll / _maxScroll, 0, 1); }

    // Track: filled black background (previously outline-only)
    draw_set_alpha(1);
    draw_set_color(c_black);
    draw_rectangle(_rx, _ry, _rx + _rw, _ry + _rh, false); // filled
    // Optional outline
    draw_set_color(c_white);
    draw_rectangle(_rx, _ry, _rx + _rw, _ry + _rh, true);

    // Thumb height based on visible proportion
    var _visibleFrac = (_total > 0) ? (_visible / _total) : 1;
    var _thumbH = max(8, floor((_rh - _inset*2) * _visibleFrac));
    var _usable = (_rh - _inset*2 - _thumbH); // travel distance
    if (_usable < 0) _usable = 0;
    var _thumbTop = _ry + _inset + floor(_usable * _t);
    var _thumbBot = _thumbTop + _thumbH;

    // Filled brown selector
    draw_set_color(make_color_rgb(160,120,64));
    draw_rectangle(_rx + _inset, _thumbTop, _rx + _rw - _inset, _thumbBot, false); // filled
    // Outline
    draw_set_color(c_black);
    draw_rectangle(_rx + _inset, _thumbTop, _rx + _rw - _inset, _thumbBot, true);

    draw_set_alpha(_oldAlpha);
    draw_set_color(_oldCol);
}