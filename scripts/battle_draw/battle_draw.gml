// ===== Battlers drawing =====
function __battle_draw_battlers(_pid, _B) {
    var _cam_offx = 0;
    var _cam_offy = 0;
    if (!is_undefined(battle_cam_get_draw_state)){
        var _cam_draw = battle_cam_get_draw_state(_pid);
        if (is_struct(_cam_draw)){
            if (variable_struct_exists(_cam_draw, "offset_x") && is_real(_cam_draw.offset_x)) _cam_offx = _cam_draw.offset_x;
            if (variable_struct_exists(_cam_draw, "offset_y") && is_real(_cam_draw.offset_y)) _cam_offy = _cam_draw.offset_y;
        }
    }

    var _is_double_scene = (variable_struct_exists(_B, "battle_format") && string(variable_struct_get(_B, "battle_format")) == "double");
    var _enemy_draw_order = _is_double_scene
        ? [__battle_actor_index_for_side_slot(_pid, 1, 0), __battle_actor_index_for_side_slot(_pid, 1, 1)]
        : [__battle_actor_index_for_side_slot(_pid, 1, 0)];
    var _player_draw_order = _is_double_scene
        ? [__battle_actor_index_for_side_slot(_pid, 0, 0), __battle_actor_index_for_side_slot(_pid, 0, 1)]
        : [__battle_actor_index_for_side_slot(_pid, 0, 0)];

    if (string(_B.phase) != "transition_in"){
        for (var _ep = 0; _ep < array_length(_enemy_draw_order); ++_ep){
            var _enemy_idx_platform = _enemy_draw_order[_ep];
            if (!is_array(_B.actor) || _enemy_idx_platform >= array_length(_B.actor) || !is_struct(_B.actor[_enemy_idx_platform])) continue;
            var _enemy_anchor_platform = __battle_get_actor_scene_anchor(_pid, _B, _enemy_idx_platform);
            if (!is_struct(_enemy_anchor_platform) || !variable_struct_exists(_enemy_anchor_platform, "battler")) continue;
            var _enemy_pt_platform = variable_struct_get(_enemy_anchor_platform, "battler");
            if (!is_array(_enemy_pt_platform) || array_length(_enemy_pt_platform) < 2) continue;

            var _enemy_actor_platform = _B.actor[_enemy_idx_platform];
            var _enemy_h_platform = 64;
            if (is_struct(_enemy_actor_platform) && variable_struct_exists(_enemy_actor_platform, "mon") && !is_undefined(pkicons_get_art96_by_mon)){
                var _enemy_mon_platform = variable_struct_get(_enemy_actor_platform, "mon");
                var _enemy_spr_platform = pkicons_get_art96_by_mon(_enemy_mon_platform);
                if (!is_undefined(_enemy_spr_platform) && sprite_exists(_enemy_spr_platform)) _enemy_h_platform = sprite_get_height(_enemy_spr_platform);
            }

            var _enemy_ui_s_platform = 1;
            try {
                if (is_struct(_B) && variable_struct_exists(_B, "_ui")){
                    var _enemy_ui_platform = variable_struct_get(_B, "_ui");
                    if (is_struct(_enemy_ui_platform) && variable_struct_exists(_enemy_ui_platform, "s")) _enemy_ui_s_platform = variable_struct_get(_enemy_ui_platform, "s");
                }
            } catch (e_enemy_ui_platform) { _enemy_ui_s_platform = 1; }

            var _enemy_layout_platform = __battle_get_actor_scene_anchor(_pid, _B, _enemy_idx_platform);
            var _enemy_scale_mult_platform = (is_struct(_enemy_layout_platform) && variable_struct_exists(_enemy_layout_platform, "scale_mult") && is_real(variable_struct_get(_enemy_layout_platform, "scale_mult"))) ? real(variable_struct_get(_enemy_layout_platform, "scale_mult")) : 1;
            var _enemy_draw_scale_platform = _enemy_scale_mult_platform * _enemy_ui_s_platform;
            var _enemy_platform_bottom = (_enemy_pt_platform[1] + _cam_offy) + (_enemy_h_platform * _enemy_draw_scale_platform) * 0.5;
            __battle_draw_platform(_pid, _B, "enemy", _enemy_pt_platform[0] + _cam_offx, _enemy_platform_bottom, _enemy_ui_s_platform);
        }
    }

    for (var _ed = 0; _ed < array_length(_enemy_draw_order); ++_ed){
        var _enemy_idx_draw = _enemy_draw_order[_ed];
        if (!is_array(_B.actor) || _enemy_idx_draw >= array_length(_B.actor) || !is_struct(_B.actor[_enemy_idx_draw])) continue;
        var _enemy_anchor = __battle_get_actor_scene_anchor(_pid, _B, _enemy_idx_draw);
        if (!is_struct(_enemy_anchor) || !variable_struct_exists(_enemy_anchor, "battler")) continue;
        var _enemy_pt = variable_struct_get(_enemy_anchor, "battler");
        if (!is_array(_enemy_pt) || array_length(_enemy_pt) < 2) continue;
        __battle_draw_enemy(_pid, _B, _enemy_idx_draw, _enemy_pt[0] + _cam_offx, _enemy_pt[1] + _cam_offy, true);
        if (!is_undefined(__battle_draw_confusion_dialog_overlay)) __battle_draw_confusion_dialog_overlay(_pid, _B.actor[_enemy_idx_draw], _enemy_pt[0] + _cam_offx, _enemy_pt[1] + _cam_offy);
    }

    var __vict_draw = __battle_fetch_global_function("__battle_trainer_draw_victory");
    if (!is_undefined(__vict_draw)) __vict_draw(_pid, _B);

    // Draw player platforms in a separate background pass so one ally platform
    // never overlays the other ally's sprite in doubles.
    for (var _pp = 0; _pp < array_length(_player_draw_order); ++_pp){
        var _player_idx_platform = _player_draw_order[_pp];
        if (!is_array(_B.actor) || _player_idx_platform >= array_length(_B.actor) || !is_struct(_B.actor[_player_idx_platform])) continue;
        var _player_anchor_platform = __battle_get_actor_scene_anchor(_pid, _B, _player_idx_platform);
        if (!is_struct(_player_anchor_platform) || !variable_struct_exists(_player_anchor_platform, "battler")) continue;
        var _player_pt_platform = variable_struct_get(_player_anchor_platform, "battler");
        if (!is_array(_player_pt_platform) || array_length(_player_pt_platform) < 2) continue;

        var _player_actor_platform = _B.actor[_player_idx_platform];
        if (!is_struct(_player_actor_platform) || !variable_struct_exists(_player_actor_platform, "mon")) continue;
        if (is_undefined(pkicons_get_art96_by_mon) || is_undefined(pkicons_get_art96_subimg_by_mon)) continue;

        var _mon_platform = variable_struct_get(_player_actor_platform, "mon");
        var _spr_platform = pkicons_get_art96_by_mon(_mon_platform);
        var _fallback_platform = undefined;
        if (variable_global_exists("spr_mon_placeholder")) _fallback_platform = global.spr_mon_placeholder;
        if (is_undefined(_fallback_platform) || !sprite_exists(_fallback_platform)){
            try {
                var _ph_platform = asset_get_index("spr_mon_placeholder");
                if (!is_undefined(_ph_platform) && sprite_exists(_ph_platform)) _fallback_platform = _ph_platform;
            } catch (e_ph_platform) { _fallback_platform = undefined; }
        }

        var _has_player_sprite = sprite_exists(_spr_platform);
        var _w_platform = _has_player_sprite ? sprite_get_width(_spr_platform) : (sprite_exists(_fallback_platform) ? sprite_get_width(_fallback_platform) : 64);
        var _h_platform = _has_player_sprite ? sprite_get_height(_spr_platform) : (sprite_exists(_fallback_platform) ? sprite_get_height(_fallback_platform) : 64);
        var _ui_s_platform = 1;
        try {
            if (is_struct(_B) && variable_struct_exists(_B, "_ui")){
                var _ui_platform = variable_struct_get(_B, "_ui");
                if (is_struct(_ui_platform) && variable_struct_exists(_ui_platform, "s")) _ui_s_platform = variable_struct_get(_ui_platform, "s");
            }
        } catch (e_ui_platform) { _ui_s_platform = 1; }

        var _player_layout_platform = __battle_get_actor_scene_anchor(_pid, _B, _player_idx_platform);
        var _scale_mult_platform = (is_struct(_player_layout_platform) && variable_struct_exists(_player_layout_platform, "scale_mult") && is_real(variable_struct_get(_player_layout_platform, "scale_mult"))) ? real(variable_struct_get(_player_layout_platform, "scale_mult")) : 1;
        var _draw_scale_platform = 1.1 * _scale_mult_platform * _ui_s_platform;
        var _phase_platform = string(_B.phase);
        var _view_platform = __battle_actor_view_side_slot(_pid, _player_idx_platform);
        var _platform_slot = (is_struct(_view_platform) && variable_struct_exists(_view_platform, "slot")) ? variable_struct_get(_view_platform, "slot") : __battle_actor_slot(_player_idx_platform);
        var _suppress_platform = (_platform_slot == 0 && _phase_platform == "intro_call");
        if (_suppress_platform) continue;

        var _platform_bottom_player = (_player_pt_platform[1] + _cam_offy) + (_h_platform * _draw_scale_platform) * 0.5;
        if (_is_double_scene && _platform_slot == 0) _platform_bottom_player += __bhu(_pid, 4);
        __battle_draw_platform(_pid, _B, "player", _player_pt_platform[0] + _cam_offx, _platform_bottom_player, _ui_s_platform);
    }

    for (var _pd = 0; _pd < array_length(_player_draw_order); ++_pd){
        var _player_idx_draw = _player_draw_order[_pd];
        if (!is_array(_B.actor) || _player_idx_draw >= array_length(_B.actor) || !is_struct(_B.actor[_player_idx_draw])) continue;
        var _player_anchor = __battle_get_actor_scene_anchor(_pid, _B, _player_idx_draw);
        if (!is_struct(_player_anchor) || !variable_struct_exists(_player_anchor, "battler")) continue;
        var _player_pt = variable_struct_get(_player_anchor, "battler");
        if (!is_array(_player_pt) || array_length(_player_pt) < 2) continue;
        var _trainer_pt = (variable_struct_exists(_player_anchor, "trainer") ? variable_struct_get(_player_anchor, "trainer") : _player_pt);
        __battle_draw_player(_pid, _B, _player_idx_draw, _player_pt[0] + _cam_offx, _player_pt[1] + _cam_offy, _trainer_pt[0] + _cam_offx, _trainer_pt[1] + _cam_offy, true);
        if (!is_undefined(__battle_draw_confusion_dialog_overlay)) __battle_draw_confusion_dialog_overlay(_pid, _B.actor[_player_idx_draw], _player_pt[0] + _cam_offx, _player_pt[1] + _cam_offy);
    }

    if (!is_undefined(__battle_draw_target_selector)) __battle_draw_target_selector(_pid, _B, _cam_offx, _cam_offy);
}

function __battle_begin_levelup_panel(_pid, _entry){
    var _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B) || !is_struct(_entry)) return;

    var _rows = (variable_struct_exists(_entry, "rows") && is_array(variable_struct_get(_entry, "rows"))) ? variable_struct_get(_entry, "rows") : [];
    var _now = current_time;
    var _slide_dur = 220;
    var _count_dur = 320;
    var _input_ready_ms = _now + 180;
    try {
        if (variable_struct_exists(_B, "_input_grace_until") && is_real(variable_struct_get(_B, "_input_grace_until"))){
            _input_ready_ms = max(_input_ready_ms, variable_struct_get(_B, "_input_grace_until"));
        }
    } catch (e_levelup_grace) { _input_ready_ms = _now + 180; }

    variable_struct_set(_B, "_levelup_panel", {
        active: true,
        actor_index: 0,
        level: (variable_struct_exists(_entry, "level") ? variable_struct_get(_entry, "level") : 1),
        mon_name: (variable_struct_exists(_entry, "mon_name") ? variable_struct_get(_entry, "mon_name") : ""),
        rows: _rows,
        start_ms: _now,
        slide_dur: _slide_dur,
        count_dur: _count_dur,
        input_ready_ms: _input_ready_ms,
        current_row: -1,
        row_anim_start_ms: -1,
        close_ready: (array_length(_rows) <= 0)
    });
}

function __battle_resume_exp_after_levelup_panel(_pid){
    var _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B) || !variable_struct_exists(_B, "_exp_anim")) return;

    var _E = variable_struct_get(_B, "_exp_anim");
    if (!is_struct(_E) || !variable_struct_exists(_E, "waiting_for_panel") || !_E.waiting_for_panel) return;

    var _q = (variable_struct_exists(_E, "queue") ? variable_struct_get(_E, "queue") : []);
    var _cur_idx = (variable_struct_exists(_E, "playing_index") ? floor(variable_struct_get(_E, "playing_index")) : 0);
    var _next_idx = _cur_idx + 1;
    if (_next_idx >= 0 && _next_idx < array_length(_q)){
        var _next_step = _q[_next_idx];
        _next_step.start_ms = current_time;
        _q[_next_idx] = _next_step;
        variable_struct_set(_E, "queue", _q);
        variable_struct_set(_E, "playing_index", _next_idx);
        variable_struct_set(_E, "waiting_for_panel", false);
        if (variable_struct_exists(_next_step, "from")) variable_struct_set(_E, "cur", _next_step.from);
        variable_struct_set(_B, "_exp_anim", _E);
    } else {
        variable_struct_set(_E, "active", false);
        variable_struct_set(_E, "waiting_for_panel", false);
        variable_struct_set(_B, "_exp_anim", _E);
    }
}

function __battle_update_levelup_panel(_pid){
    var _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B) || !variable_struct_exists(_B, "_levelup_panel")) return false;

    var _panel = variable_struct_get(_B, "_levelup_panel");
    if (!is_struct(_panel) || !variable_struct_exists(_panel, "active") || !_panel.active) return false;

    var _now = current_time;
    var _slide_dur = (variable_struct_exists(_panel, "slide_dur") && is_real(variable_struct_get(_panel, "slide_dur"))) ? max(1, variable_struct_get(_panel, "slide_dur")) : 220;
    var _count_dur = (variable_struct_exists(_panel, "count_dur") && is_real(variable_struct_get(_panel, "count_dur"))) ? max(1, variable_struct_get(_panel, "count_dur")) : 320;
    var _rows = (variable_struct_exists(_panel, "rows") && is_array(variable_struct_get(_panel, "rows"))) ? variable_struct_get(_panel, "rows") : [];
    var _current_row = (variable_struct_exists(_panel, "current_row") && is_real(variable_struct_get(_panel, "current_row"))) ? floor(variable_struct_get(_panel, "current_row")) : -1;
    var _row_anim_start = (variable_struct_exists(_panel, "row_anim_start_ms") && is_real(variable_struct_get(_panel, "row_anim_start_ms"))) ? variable_struct_get(_panel, "row_anim_start_ms") : -1;
    var _close_ready = (variable_struct_exists(_panel, "close_ready") && variable_struct_get(_panel, "close_ready"));
    var _input_ready_ms = (variable_struct_exists(_panel, "input_ready_ms") && is_real(variable_struct_get(_panel, "input_ready_ms"))) ? variable_struct_get(_panel, "input_ready_ms") : 0;
    var _slide_done = (_now - (variable_struct_exists(_panel, "start_ms") ? variable_struct_get(_panel, "start_ms") : _now)) >= _slide_dur;
    var _advance_pressed = false;
    if (_slide_done && _now >= _input_ready_ms && !is_undefined(__battle_pressed)) _advance_pressed = (__battle_pressed(_pid, "A") || __battle_pressed(_pid, "B"));

    if (_slide_done && _current_row >= 0 && _row_anim_start > 0 && (_now - _row_anim_start) >= _count_dur && (_current_row + 1) >= array_length(_rows)){
        _close_ready = true;
    }

    if (_slide_done && _advance_pressed){
        if (_close_ready){
            variable_struct_set(_panel, "active", false);
            variable_struct_set(_B, "_levelup_panel", _panel);
            __battle_resume_exp_after_levelup_panel(_pid);
            return false;
        }

        if (_current_row < 0 || (_row_anim_start > 0 && (_now - _row_anim_start) >= _count_dur)){
            _current_row += 1;
            variable_struct_set(_panel, "current_row", _current_row);
            variable_struct_set(_panel, "row_anim_start_ms", _now);
            if ((_current_row + 1) >= array_length(_rows)) variable_struct_set(_panel, "close_ready", false);
        }
    }

    if (array_length(_rows) <= 0 && _slide_done && _advance_pressed){
        variable_struct_set(_panel, "active", false);
        variable_struct_set(_B, "_levelup_panel", _panel);
        __battle_resume_exp_after_levelup_panel(_pid);
        return false;
    }

    variable_struct_set(_B, "_levelup_panel", _panel);
    return true;
}

function __battle_has_active_exp_sequence(_B){
    if (!is_struct(_B)) return false;
    try {
        if (variable_struct_exists(_B, "_levelup_panel")){
            var _panel = variable_struct_get(_B, "_levelup_panel");
            if (is_struct(_panel) && variable_struct_exists(_panel, "active") && variable_struct_get(_panel, "active") == true) return true;
        }
    } catch (e_exp_panel) {}
    try {
        if (variable_struct_exists(_B, "_exp_anim")){
            var _exp = variable_struct_get(_B, "_exp_anim");
            if (is_struct(_exp)){
                if (variable_struct_exists(_exp, "active") && variable_struct_get(_exp, "active") == true) return true;
                if (variable_struct_exists(_exp, "waiting_for_panel") && variable_struct_get(_exp, "waiting_for_panel") == true) return true;
            }
        }
    } catch (e_exp_anim) {}
    return false;
}