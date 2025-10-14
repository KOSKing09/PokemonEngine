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
#macro PARTY_ROW_PAD_UI 7
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
    // Forward to modular draw helper
    if (!is_undefined(__party_impl_draw_shiny_sparkle)) __party_impl_draw_shiny_sparkle(_x,_y,_S,_seed);
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
    // restore font state for caller
    __party_restore_font(_partyFontOld);
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
    return party_model_get_mons(_pid);
}
function __party_mon_get(_P, _pid){
    return party_model_get_mon(_pid, _P.sel);
}
function __party_move_name(_id){
    // Treat non-positive IDs as empty slots
    if (!is_real(_id) || _id <= 0) return "—";
    if (is_undefined(scr_move_name_by_id)) return "Move#" + string(_id);
    var _t = scr_move_name_by_id(_id);
    if (is_string(_t) && string_length(_t) > 0) return _t;
    return "Move#" + string(_id);
}

// Name helpers forwarded to modular implementation file
function mon_display_name(_mon){ if (!is_undefined(__party_impl_mon_display_name)) return __party_impl_mon_display_name(_mon); return "???"; }
function party_mon_ensure_name(_mon){ if (!is_undefined(__party_impl_party_mon_ensure_name)) return __party_impl_party_mon_ensure_name(_mon); return _mon; }
function party_apply_name_support(_pid){ if (!is_undefined(__party_impl_party_apply_name_support)) return __party_impl_party_apply_name_support(_pid); }
function party_set_nickname(_pid,_index,_nick){ if (!is_undefined(__party_impl_party_set_nickname)) return __party_impl_party_set_nickname(_pid,_index,_nick); return false; }
function party_ensure_named(_pid){ if (!is_undefined(__party_impl_party_ensure_named)) return __party_impl_party_ensure_named(_pid); return party_ensure(_pid); }
function battle_test_prepare_names(_pid){ if (!is_undefined(__party_impl_battle_test_prepare_names)) return __party_impl_battle_test_prepare_names(_pid); }


// ---------- Update ----------
function party_update(){
    // Forward to input module implementation (keeps API stable)
    if (!is_undefined(__party_impl_party_update)) __party_impl_party_update();
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
    // Ensure full alpha before drawing background stripes
    for (var _yy = 0; _yy < 160; _yy += _stripe_h){
        draw_set_color( ((_yy div _stripe_h) & 1) == 1 ? _C_BG_B : _C_BG_A );
        draw_rectangle(_OX, _OY + _yy*_S, _OX + 240*_S, _OY + (_yy+_stripe_h)*_S, false);
    }

    var _LIST_X = 120, _LIST_Y = 8,  _LIST_W = 112, _LIST_H = 144;
    var _INFO_X = 8,   _INFO_Y = 98, _INFO_W = 104, _INFO_H = 54;

    var _lx1 = _OX + _LIST_X*_S,            _ly1 = _OY + _LIST_Y*_S;
    var _lx2 = _OX + (_LIST_X+_LIST_W)*_S,  _ly2 = _OY + (_LIST_Y+_LIST_H)*_S;
    var _PARCHMENT = make_color_rgb(255,243,195);
    draw_set_color(_PARCHMENT);   draw_rectangle(_lx1, _ly1, _lx2, _ly2, false);
    draw_set_color(_C_PAPER_E); draw_rectangle(_lx1 - _S, _ly1 - _S, _lx2 + _S, _ly2 + _S, true);

    var _partyFontOld = __party_use_font();
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
            draw_set_color(PARTY_HILITE_COL);
            draw_rectangle(_rx1, _ry1, _rx2, _ry2, false);
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
            var _iy_gui = _row_y_gui - _target_h_gui * 0.5 - 4*_S; // raised by 4 UI pixels
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

        // Draw small held-item icon at bottom-left of the party portrait if the mon has one
        if (is_struct(_M)){
            var _held_spr = -1;
            // prefer the canonical real name if present
            if (variable_struct_exists(_M, "held_item_real_name") && string_length(string(_M.held_item_real_name)) > 0){
                if (!is_undefined(pkicons_get_item_icon_by_name)) _held_spr = pkicons_get_item_icon_by_name(string(_M.held_item_real_name));
            }
            // fallback to held_item_id
            if ((_held_spr == -1 || is_undefined(_held_spr)) && variable_struct_exists(_M, "held_item_id") && is_real(_M.held_item_id) && _M.held_item_id > 0){
                if (!is_undefined(pkicons_get_item_icon_by_id)) _held_spr = pkicons_get_item_icon_by_id(_M.held_item_id);
            }
            // if we have a usable sprite, draw a small 5x5 px icon at bottom-left of the icon area
            if ((!is_undefined(_held_spr) && _held_spr != -1) && sprite_exists(_held_spr)){
                var _small_w = 5; var _small_h = 5;
                var _sx = _OX + (_LIST_X + 2) * _S; // left edge of icon area
                var _sy = _row_y_gui - (_ROW_H * 0.5) * _S + (_ROW_H * 0.5) * _S; // bottom of row icon area
                // place slightly inset from bottom-left of the icon region
                var _px = floor(_sx + 2 * _S);
                var _py = floor(_row_y_gui + (_target_h_gui * 0.5) - (_small_h * _S) - 1 * _S - 5 * _S + 3 * _S);
                // compute scale to map sprite intrinsic size to 5x5 UI pixels
                var _spr_w = max(1, sprite_get_width(_held_spr));
                var _spr_h = max(1, sprite_get_height(_held_spr));
                var _scale_x = (_small_w) / _spr_w;
                var _scale_y = (_small_h) / _spr_h;
                var _scale = min(_scale_x, _scale_y);
                draw_sprite_ext(_held_spr, 0, _px, _py, _scale, _scale, 0, c_white, 1);
            }
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
    var _PARCHMENT = make_color_rgb(255,243,195);
    draw_set_color(_PARCHMENT);   draw_rectangle(_ix1, _iy1, _ix2, _iy2, false);
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

    if (string(_P.mode) == "menu" || string(_P.mode) == "item_action"){
        var _MX = 96, _MY = 20, _MW = 76, _MH = 84;
        var _bx1 = _OX + _MX*_S;
        var _by1 = _OY + _MY*_S;
        var _bx2 = _OX + (_MX+_MW)*_S;
        var _by2 = _OY + (_MY+_MH)*_S;

    var _PARCHMENT = make_color_rgb(255,243,195);
    draw_set_color(_PARCHMENT);   draw_rectangle(_bx1, _by1, _bx2, _by2, false);
    draw_set_color(_C_PAPER_E); draw_rectangle(_bx1 - _S, _by1 - _S, _bx2 + _S, _by2 + _S, true);

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
        // If in item_action mode, draw a small submenu replacing the 'Item' entry
        if (string(_P.mode) == "item_action"){
            var _ix = _bx1 + 36*_S;
            var _iy = _by1 + (6 + 2*_m_h);
            // Dynamically include 'Give' only when a give_pending exists and the item is holdable
            var _labels = ["Take","Cancel"];
            var _menuSel = 0;
            if (variable_struct_exists(_P, "item_menu_sel")) _menuSel = variable_struct_get(_P, "item_menu_sel");
            // Determine whether to show Give or Take based on selected mon state or a pending give from the bag.
            var _shouldShowGive = false;
            // If a give is pending (bag -> party flow), always show Give.
            if (variable_struct_exists(_P, "give_pending")){
                _shouldShowGive = true;
            } else {
                // Otherwise infer from the selected mon: if it already holds an item, show Take; else show Give.
                var _selMon = undefined;
                if (variable_struct_exists(_P, "mons") && is_array(_P.mons) && _P.sel >= 0 && _P.sel < array_length(_P.mons)) _selMon = _P.mons[_P.sel];
                if (!is_undefined(_selMon) && is_struct(_selMon) && variable_struct_exists(_selMon, "held_item_id")){
                    var _hid_tmp = variable_struct_get(_selMon, "held_item_id");
                    if (is_real(_hid_tmp) && _hid_tmp > 0){ _shouldShowGive = false; } else { _shouldShowGive = true; }
                } else {
                    _shouldShowGive = true;  // mon has no item -> show Give
                }
            }
            if (_shouldShowGive) array_insert(_labels, 0, "Give");

            // draw a small parchment box behind the submenu
            var _box_pad_x = 6 * _S;
            var _box_pad_y = 3 * _S;
            var _box_w = 48 * _S;
            var _box_h = array_length(_labels) * _m_h + _box_pad_y * 2;
            var _box_x1 = _ix - _box_pad_x;
            var _box_y1 = _iy - _box_pad_y;
            var _box_x2 = _box_x1 + _box_w;
            var _box_y2 = _box_y1 + _box_h;
            draw_set_color(_PARCHMENT); draw_rectangle(_box_x1, _box_y1, _box_x2, _box_y2, false);
            draw_set_color(_C_PAPER_E); draw_rectangle(_box_x1 - _S, _box_y1 - _S, _box_x2 + _S, _box_y2 + _S, true);

            // render labels in white (no black text) and prefix the selected with '>'
            for (var _ii = 0; _ii < array_length(_labels); _ii++){
                var _y2 = _iy + (_ii * _m_h);
                if (_ii == _menuSel){ draw_set_color(c_white); draw_text(_ix + 4*_S, _y2, "> " + _labels[_ii]); }
                else { draw_set_color(c_white); draw_text(_ix + 4*_S, _y2, _labels[_ii]); }
            }
        }
    }
}

// ---------- Summary / Description ----------
function __party_draw_summary(_pid, _P, _OX, _OY, _S){
    if (!is_undefined(__party_impl_draw_summary)) { __party_impl_draw_summary(_pid, _P, _OX, _OY, _S); return; }
    // fallback: nothing to draw
}

// ---------- Summary helpers ----------
function __party_draw_profile_block(_M, _x, _y, _w, _h, _S){
    if (!is_undefined(__party_impl_draw_profile_block)) { __party_impl_draw_profile_block(_M,_x,_y,_w,_h,_S); return; }
}
function __party_draw_moves_block(_P, _M, _x, _y, _w, _h, _S, _highlightForget){
    if (!is_undefined(__party_impl_draw_moves_block)) return __party_impl_draw_moves_block(_P,_M,_x,_y,_w,_h,_S,_highlightForget);
    return "";
}

// Draw a secondary single-line help message across the bottom of the summary area.
function __party_draw_secondary_help(_text, _OX, _S, _leftInfo){
    if (!is_undefined(__party_impl_draw_secondary_help)) { __party_impl_draw_secondary_help(_text, _OX, _S, _leftInfo); return; }
}

// Draw the left panel (profile art + basic labels). Returns an object with desc geometry so parent can render text.
function __party_draw_left_panel(_P, _M, _OX, _OY, _S, _LEFT_X, _LEFT_Y, _LEFT_W, _LEFT_H){
    if (!is_undefined(__party_impl_draw_left_panel)) return __party_impl_draw_left_panel(_P,_M,_OX,_OY,_S,_LEFT_X,_LEFT_Y,_LEFT_W,_LEFT_H);
    return { descPad: 3*_S, descAreaH: 38*_S, descX: (_OX + _LEFT_X*_S) + 3*_S, descY: (_OY + _LEFT_Y*_S) + (_LEFT_H*_S) - 38*_S + 3*_S, descW: min((_LEFT_W + 10) * _S, (108 - _LEFT_X - 4) * _S) - 3*_S*2, descH: 38*_S - 3*_S*2 };
}

// Draw the right panel background and return x/y for content placement.
function __party_draw_right_frame(_OX, _OY, _S, _RIGHT_X, _RIGHT_Y, _RIGHT_W, _RIGHT_H){
    if (!is_undefined(__party_impl_draw_right_frame)) return __party_impl_draw_right_frame(_OX,_OY,_S,_RIGHT_X,_RIGHT_Y,_RIGHT_W,_RIGHT_H);
    var _rx1 = _OX + _RIGHT_X*_S, _ry1 = _OY + _RIGHT_Y*_S;
    var _rx2 = _OX + (_RIGHT_X + _RIGHT_W)*_S, _ry2 = _OY + (_RIGHT_Y + _RIGHT_H)*_S;
    return { rx1: _rx1, ry1: _ry1, rx2: _rx2, ry2: _ry2 };
}

// Return the appropriate description text for the summary page (species flavor or move text)
function __party_get_desc_text(_P, _M){
    var _descText = "";
    if (string(_P.mode) == "summary_profile") {
        // Resolve species id into a safe integer (accept real or numeric string)
        var _sid_desc_raw = -1;
        if (variable_struct_exists(_M,"species_id")) _sid_desc_raw = variable_struct_get(_M, "species_id");
        else if (variable_struct_exists(_M,"_id"))   _sid_desc_raw = variable_struct_get(_M, "_id");
        // coerce to integer safely
        var _sid_desc = -1;
        if (is_real(_sid_desc_raw)) _sid_desc = floor(_sid_desc_raw);
        else if (is_string(_sid_desc_raw)) {
            var _st = string_trim(_sid_desc_raw);
            if (string_length(_st) > 0) {
                // try to parse numeric content
                var _val = 0;
                try { _val = real(_st); } catch (ee) { _val = -1; }
                if (is_real(_val)) _sid_desc = floor(_val);
            }
        }

        if (_sid_desc >= 0 && variable_global_exists("_species_flavor_text")) {
            var _sarr = global._species_flavor_text;
            var _sv = undefined;
            // Array-backed lookup
            if (is_array(_sarr) && _sid_desc < array_length(_sarr)) {
                _sv = _sarr[_sid_desc];
            }
            // Struct-backed lookup (keys may be numeric strings)
            else if (is_struct(_sarr)) {
                var _k = string(_sid_desc);
                if (variable_struct_exists(_sarr, _k)) _sv = variable_struct_get(_sarr, _k);
            }
            // ds_map-backed lookup
            else if (is_real(_sarr) && ds_exists(_sarr, ds_type_map)) {
                var _k2 = string(_sid_desc);
                if (ds_map_exists(_sarr, _k2)) _sv = ds_map_find_value(_sarr, _k2);
            }

            // DEBUG: report what we found when DATA_DEBUG is set
            if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) {
                var _typeStr = is_string(_sv) ? "string" : (is_struct(_sv) ? "struct" : (is_real(_sv) ? "real" : "other"));
                var _rawPreview = "";
                if (is_string(_sv)) _rawPreview = string_trim(_sv);
                else if (is_real(_sv)) _rawPreview = string(_sv);
                else if (is_struct(_sv)) {
                    var _has_short = variable_struct_exists(_sv, "short_desc");
                    var _has_eff = variable_struct_exists(_sv, "effect");
                    var _sdv = _has_short ? string(variable_struct_get(_sv, "short_desc")) : "";
                    var _efv = _has_eff ? string(variable_struct_get(_sv, "effect")) : "";
                    _rawPreview = "short_len=" + string(string_length(string_trim(_sdv))) + ",eff_len=" + string(string_length(string_trim(_efv)));
                }
                show_debug_message("[DBG][party_desc] sid=" + string(_sid_desc) + " arr_type=" + string(is_array(_sarr) ? "array" : (is_struct(_sarr) ? "struct" : (is_real(_sarr) && ds_exists(_sarr, ds_type_map) ? "ds_map" : "other"))) + " type=" + _typeStr + " preview='" + _rawPreview + "'");
            }

            // Accept if it's a non-empty string
            if (is_string(_sv) && string_length(string_trim(_sv)) > 0) {
                _descText = string_trim(string(_sv));
            }
            // Some loaders may store a struct with keys like short_desc/effect
            else if (is_struct(_sv)) {
                var _sd = variable_struct_exists(_sv, "short_desc") ? string(variable_struct_get(_sv, "short_desc")) : "";
                var _ef = variable_struct_exists(_sv, "effect") ? string(variable_struct_get(_sv, "effect")) : "";
                if (string_length(string_trim(_sd)) > 0) _descText = string_trim(_sd);
                else if (string_length(string_trim(_ef)) > 0) _descText = string_trim(_ef);
            }
            // otherwise ignore numeric 0 or undefined entries to avoid rendering "0"
        }
        // Fallback: if no flavor text, show the species display name if available
        if (string_length(string_trim(_descText)) == 0) {
            if (!is_undefined(scr_poke_name_by_id)) {
                var _nm = scr_poke_name_by_id(_sid_desc);
                if (is_string(_nm) && string_length(string_trim(_nm)) > 0) _descText = string_trim(_nm);
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
    return _descText;
}

// Draw top hints and the six selection circles used on the summary page.
function __party_draw_header_and_circles(_P, _OX, _OY, _S, _n, _C_ACC, _C_PAPER){
    if (!is_undefined(__party_impl_draw_header_and_circles)) { __party_impl_draw_header_and_circles(_P,_OX,_OY,_S,_n,_C_ACC,_C_PAPER); return; }
}

// ---------- Text helpers ----------
function __party_desc_clean_local(_s){
    if (!is_undefined(__party_impl_desc_clean_local)) return __party_impl_desc_clean_local(_s);
    // fallback
    var _t = string(_s);
    _t = string_replace_all(_t, "\n", " ");
    _t = string_replace_all(_t, "\r", " ");
    _t = string_replace_all(_t, "\f", " ");
    while (string_pos("  ", _t) > 0) _t = string_replace_all(_t, "  ", " ");
    return string_trim(_t);
}

// --- Scrollable & colored text renderer (first occurrence highlight) ---
function __party_desc_draw_scrollable_colored(_x, _y, _w, _h, _text) {
    // Forward to modular implementation
    if (!is_undefined(__party_impl_desc_draw_scrollable_colored)) __party_impl_desc_draw_scrollable_colored(_x, _y, _w, _h, _text);
}

// ---------- Entrypoint ----------
function party_draw_gui(_pid){
    var _gw = display_get_gui_width();
    var _gh = display_get_gui_height();
    party_draw_gui_rect(_pid, 0, 0, _gw, _gh);
}

// Ensure draw alpha restored after party GUI draw (safety net)
draw_set_alpha(1);

// [Party UI]: party__draw_scrollbar — Build v1.3 — 2025-10-05
function party__draw_scrollbar(_rx, _ry, _rw, _rh, _scroll, _pageSize, _totalItems) {
    if (!is_undefined(__party_impl_draw_scrollbar)) __party_impl_draw_scrollbar(_rx,_ry,_rw,_rh,_scroll,_pageSize,_totalItems);
}

// Draw the right-side content based on current mode and return the secondary help line (string).
function __party_draw_right_content(_P, _M, _rightInfo, _RIGHT_W, _RIGHT_H, _S){
    if (!is_undefined(__party_impl_draw_right_content)) return __party_impl_draw_right_content(_P,_M,_rightInfo,_RIGHT_W,_RIGHT_H,_S);
    return "";
}

// --- Local font helpers for consistent font state ---
function __party_use_font(){
    if (!is_undefined(__party_impl_use_font)) return __party_impl_use_font();
    var _old = -1;
    if (variable_global_exists("FNT_POKEMON")){
        _old = draw_get_font();
        draw_set_font(global.FNT_POKEMON);
    }
    return _old;
}
function __party_restore_font(_old){
    if (!is_undefined(__party_impl_restore_font)) { __party_impl_restore_font(_old); return; }
    if (_old != -1) draw_set_font(_old);
}

// Draw white text using canonical party font (if present) and keep color set
function __party_text_white(_x,_y,_txt){
    if (!is_undefined(__party_impl_text_white)) { __party_impl_text_white(_x,_y,_txt); return; }
    var _old = __party_use_font();
    draw_set_color(c_white);
    draw_text(_x, _y, _txt);
    __party_restore_font(_old);
}