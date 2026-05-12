// Battle draw helpers (extracted from battle_system.gml)

function __battle_draw_platform(_pid, _B, _side, _anchor_x, _anchor_bottom, _ui_scale){
    if (!is_struct(_B) || !variable_struct_exists(_B, "theme")) return;
    var theme = _B.theme;
    var spr = undefined;
    var idx_val = 0;
    var scale_val = 1;
    var offset_val = undefined;
    if (_side == "enemy"){
        if (variable_struct_exists(theme, "platform_enemy_sprite")) spr = theme.platform_enemy_sprite;
        if (variable_struct_exists(theme, "platform_enemy_index")) idx_val = theme.platform_enemy_index;
        if (variable_struct_exists(theme, "platform_enemy_scale")) scale_val = theme.platform_enemy_scale;
        if (variable_struct_exists(theme, "platform_enemy_offset")) offset_val = theme.platform_enemy_offset;
    } else {
        if (variable_struct_exists(theme, "platform_player_sprite")) spr = theme.platform_player_sprite;
        if (variable_struct_exists(theme, "platform_player_index")) idx_val = theme.platform_player_index;
        if (variable_struct_exists(theme, "platform_player_scale")) scale_val = theme.platform_player_scale;
        if (variable_struct_exists(theme, "platform_player_offset")) offset_val = theme.platform_player_offset;
    }
    if (is_undefined(spr) || !sprite_exists(spr)) return;

    var frame_count = sprite_get_number(spr);
    var subimg = clamp(floor(idx_val), 0, max(0, frame_count - 1));
    var scale = _ui_scale * (is_real(scale_val) ? max(0.05, real(scale_val)) : 1);
    var off_x = 0;
    var off_y = 0;
    if (is_struct(offset_val)){
        if (variable_struct_exists(offset_val, "x") && is_real(variable_struct_get(offset_val, "x"))) off_x = real(variable_struct_get(offset_val, "x"));
        if (variable_struct_exists(offset_val, "y") && is_real(variable_struct_get(offset_val, "y"))) off_y = real(variable_struct_get(offset_val, "y"));
    } else if (is_array(offset_val) && array_length(offset_val) >= 2){
        var ox = offset_val[0];
        var oy = offset_val[1];
        if (is_real(ox)) off_x = real(ox);
        if (is_real(oy)) off_y = real(oy);
    }

    var anchor_x = _anchor_x + off_x * _ui_scale;
    var anchor_bottom = _anchor_bottom + off_y * _ui_scale;

    var spr_w = sprite_get_width(spr);
    var spr_h = sprite_get_height(spr);
    var spr_ox = sprite_get_xoffset(spr);
    var spr_oy = sprite_get_yoffset(spr);
    var draw_x = anchor_x + (spr_ox - spr_w * 0.5) * scale;
    var draw_y = anchor_bottom + (spr_oy - spr_h) * scale;

    draw_sprite_ext(spr, subimg, draw_x, draw_y, scale, scale, 0, c_white, 1);
}

function __battle_confusion_dialog_overlay_state(_pid, _actor, _center_x, _center_y, _alpha_mult = 1){
    if (!is_struct(_actor)) return undefined;

    var _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B)) return undefined;
    if (!variable_struct_exists(_B, "_confusion_prompt_actor_index") || !is_real(variable_struct_get(_B, "_confusion_prompt_actor_index"))) return undefined;
    if (is_undefined(dialog2p_is_open) || !dialog2p_is_open(_pid)) return undefined;

    var _actor_index = (variable_struct_exists(_actor, "actor_index") && is_real(variable_struct_get(_actor, "actor_index"))) ? floor(variable_struct_get(_actor, "actor_index")) : -1;
    var _prompt_actor_index = floor(variable_struct_get(_B, "_confusion_prompt_actor_index"));
    if (_actor_index < 0 || _actor_index != _prompt_actor_index) return undefined;

    var _spr = asset_get_index("spr_confused");
    if (!is_real(_spr) || _spr < 0 || !sprite_exists(_spr)) return undefined;

    var _loop_ms = 860;
    var _elapsed = current_time mod _loop_ms;
    var _progress = clamp(_elapsed / _loop_ms, 0, 1);
    var _alpha = clamp(_alpha_mult * (0.86 + 0.14 * sin((_progress * 2 * pi) - (pi * 0.5))), 0, 1);
    if (_alpha <= 0.001) return undefined;

    var _ui_s = 1;
    if (is_struct(_B) && variable_struct_exists(_B, "_ui") && is_struct(variable_struct_get(_B, "_ui"))){
        var _ui = variable_struct_get(_B, "_ui");
        if (variable_struct_exists(_ui, "s") && is_real(variable_struct_get(_ui, "s"))) _ui_s = max(1, real(variable_struct_get(_ui, "s")));
    }

    var _view_conf = __battle_actor_view_side_slot(_pid, _actor_index);
    var _side = (is_struct(_view_conf) && variable_struct_exists(_view_conf, "side")) ? variable_struct_get(_view_conf, "side") : __battle_actor_side(_actor_index);
    var _base_y = _center_y - ((_side == 1) ? floor(18 * _ui_s) : floor(28 * _ui_s));
    var _base_x = _center_x;
    var _scale = max(1.6, 1.15 * _ui_s);
    var _radius_x = max(10, floor(12 * _ui_s));
    var _radius_y = max(5, floor(5 * _ui_s));
    var _orbit_count = 3;
    var _spin_speed = 1.05;
    var _spr_w = sprite_get_width(_spr);
    var _spr_h = sprite_get_height(_spr);
    var _spr_xoff = sprite_get_xoffset(_spr);
    var _spr_yoff = sprite_get_yoffset(_spr);
    var _anchor_dx = (_spr_xoff - (_spr_w * 0.5)) * _scale;
    var _anchor_dy = (_spr_yoff - (_spr_h * 0.5)) * _scale;
    return {
        sprite: _spr,
        progress: _progress,
        alpha: _alpha,
        center_x: _center_x,
        center_y: _center_y,
        base_x: _base_x,
        base_y: _base_y,
        scale: _scale,
        orbit_radius_x: _radius_x,
        orbit_radius_y: _radius_y,
        orbit_count: _orbit_count,
        spin_speed: _spin_speed,
        spr_w: _spr_w,
        spr_h: _spr_h,
        anchor_dx: _anchor_dx,
        anchor_dy: _anchor_dy
    };
}

function __battle_draw_confusion_dialog_overlay(_pid, _actor, _center_x, _center_y, _alpha_mult = 1){
    var _state = __battle_confusion_dialog_overlay_state(_pid, _actor, _center_x, _center_y, _alpha_mult);
    if (!is_struct(_state)) return;

    var _spr = _state.sprite;
    var _progress = _state.progress;
    var _alpha = _state.alpha;
    var _base_x = _state.base_x;
    var _base_y = _state.base_y;
    var _scale = _state.scale;
    var _radius_x = _state.orbit_radius_x;
    var _radius_y = _state.orbit_radius_y;
    var _orbit_count = _state.orbit_count;
    var _spin_speed = _state.spin_speed;
    var _spr_w = _state.spr_w;
    var _spr_h = _state.spr_h;
    var _anchor_dx = _state.anchor_dx;
    var _anchor_dy = _state.anchor_dy;
    var _max_x = display_get_gui_width() - ceil(_spr_w * _scale) - 2;
    var _max_y = display_get_gui_height() - ceil(_spr_h * _scale) - 2;

    gpu_set_blendmode(bm_normal);
    for (var _orbit_i = 0; _orbit_i < _orbit_count; ++_orbit_i){
        var _orbit_angle = ((_progress * 2 * pi * _spin_speed) + ((_orbit_i / _orbit_count) * 2 * pi));
        var _draw_x = _base_x + cos(_orbit_angle) * _radius_x + _anchor_dx;
        var _draw_y = _base_y + sin(_orbit_angle) * _radius_y + _anchor_dy + sin((_progress * 2 * pi) + _orbit_i) * 2;
        _draw_x = clamp(_draw_x, 2, max(2, _max_x));
        _draw_y = clamp(_draw_y, 2, max(2, _max_y));
        var _frame = clamp(floor((current_time / 90) + _orbit_i) mod max(1, sprite_get_number(_spr)), 0, max(0, sprite_get_number(_spr) - 1));
        draw_sprite_ext(_spr, _frame, _draw_x, _draw_y, _scale, _scale, 0, c_white, _alpha);
    }
    gpu_set_blendmode(bm_normal);
    draw_set_alpha(1);
    draw_set_color(c_white);
}

function __battle_is_double_scene(_B){
    return is_struct(_B) && variable_struct_exists(_B, "battle_format") && string(variable_struct_get(_B, "battle_format")) == "double";
}

function __battle_scene_point(_pid, _x, _y){
    return [__bxu(_pid, _x), __byu(_pid, _y)];
}

function __battle_get_target_selector_rect(_pid, _B, _actorIndex){
    if (!is_struct(_B) || !is_array(_B.actor) || _actorIndex < 0 || _actorIndex >= array_length(_B.actor)) return undefined;
    var _actor = _B.actor[_actorIndex];
    if (!is_struct(_actor) || !variable_struct_exists(_actor, "mon")) return undefined;

    var _anchor = __battle_get_actor_scene_anchor(_pid, _B, _actorIndex);
    if (!is_struct(_anchor) || !variable_struct_exists(_anchor, "battler")) return undefined;
    var _pt = variable_struct_get(_anchor, "battler");
    if (!is_array(_pt) || array_length(_pt) < 2) return undefined;

    var _ui_s = 1;
    if (variable_struct_exists(_B, "_ui")){
        var _ui = variable_struct_get(_B, "_ui");
        if (is_struct(_ui) && variable_struct_exists(_ui, "s") && is_real(variable_struct_get(_ui, "s"))) _ui_s = real(variable_struct_get(_ui, "s"));
    }

    var _spr = undefined;
    if (!is_undefined(pkicons_get_art96_by_mon)) _spr = pkicons_get_art96_by_mon(variable_struct_get(_actor, "mon"));

    var _w = 64;
    var _h = 64;
    if (!is_undefined(_spr) && sprite_exists(_spr)){
        _w = sprite_get_width(_spr);
        _h = sprite_get_height(_spr);
    }

    var _view_target = __battle_actor_view_side_slot(_pid, _actorIndex);
    var _side = (is_struct(_view_target) && variable_struct_exists(_view_target, "side")) ? variable_struct_get(_view_target, "side") : __battle_actor_side(_actorIndex);
    var _scale_mult = (variable_struct_exists(_anchor, "scale_mult") && is_real(variable_struct_get(_anchor, "scale_mult"))) ? real(variable_struct_get(_anchor, "scale_mult")) : 1;
    var _draw_scale = ((_side == 0) ? 1.1 : 1.0) * _scale_mult * _ui_s;
    var _origin_x = (!is_undefined(_spr) && sprite_exists(_spr)) ? sprite_get_xoffset(_spr) : (_w * 0.5);
    var _origin_y = (!is_undefined(_spr) && sprite_exists(_spr)) ? sprite_get_yoffset(_spr) : ((_side == 0) ? (_h * 0.88) : (_h * 0.5));
    var _platform_bottom = _pt[1] + (_h * _draw_scale) * 0.5;
    var _draw_x = _pt[0] + (_origin_x - (_w * 0.5)) * _draw_scale;
    var _draw_y = _platform_bottom - (_h - _origin_y) * _draw_scale;
    var _sprite_w = _w * _draw_scale;
    var _sprite_h = _h * _draw_scale;
    var _box_w = clamp(_sprite_w * 0.58, __bwu(_pid, 34), __bwu(_pid, 58));
    var _box_h = clamp(_sprite_h * 0.58, __bhu(_pid, 28), __bhu(_pid, 50));
    var _cx = _draw_x + (_sprite_w * 0.5);
    var _cy = _draw_y + (_sprite_h * 0.5);

    return {
        x: _cx - (_box_w * 0.5),
        y: _cy - (_box_h * 0.5),
        w: _box_w,
        h: _box_h,
        side: _side
    };
}

function __battle_draw_target_selector(_pid, _B, _cam_offx, _cam_offy){
    if (!is_struct(_B) || !variable_struct_exists(_B, "sys_ui") || !is_struct(variable_struct_get(_B, "sys_ui"))) return;
    if (string(variable_struct_get(_B.sys_ui, "menu")) != "target") return;

    var _targets = (variable_struct_exists(_B, "_target_pick_targets") ? variable_struct_get(_B, "_target_pick_targets") : undefined);
    if (!is_array(_targets) || array_length(_targets) <= 0) return;

    var _sel_idx = 0;
    if (variable_struct_exists(_B, "_target_pick_index") && is_real(variable_struct_get(_B, "_target_pick_index"))) _sel_idx = max(0, floor(variable_struct_get(_B, "_target_pick_index")));
    if (_sel_idx < 0 || _sel_idx >= array_length(_targets)) _sel_idx = 0;

    var _actorIndex = _targets[_sel_idx];
    var _rect = __battle_get_target_selector_rect(_pid, _B, _actorIndex);
    var _side = __battle_actor_side(_actorIndex);
    var _box_w = __bwu(_pid, (_side == 0) ? 52 : 48);
    var _box_h = __bhu(_pid, (_side == 0) ? 44 : 40);
    var _x = _cam_offx - (_box_w * 0.5);
    var _y = _cam_offy - (_side == 0 ? _box_h * 0.9 : _box_h * 0.55);
    if (is_struct(_rect)){
        _side = variable_struct_get(_rect, "side");
        _box_w = variable_struct_get(_rect, "w");
        _box_h = variable_struct_get(_rect, "h");
        _x = variable_struct_get(_rect, "x") + _cam_offx;
        _y = variable_struct_get(_rect, "y") + _cam_offy;
    } else {
        var _anchor = __battle_get_actor_scene_anchor(_pid, _B, _actorIndex);
        if (!is_struct(_anchor) || !variable_struct_exists(_anchor, "battler")) return;
        var _pt = variable_struct_get(_anchor, "battler");
        if (!is_array(_pt) || array_length(_pt) < 2) return;
        _x += _pt[0];
        _y += _pt[1];
    }

    var _pulse = 0.75 + 0.25 * sin((current_time * 2 * pi) / 500);
    var _base_col = (_side == 0) ? make_color_rgb(56, 176, 88) : make_color_rgb(224, 56, 56);
    var _shadow_col = (_side == 0) ? make_color_rgb(16, 72, 28) : make_color_rgb(96, 16, 16);

    draw_set_alpha(0.2 + 0.15 * _pulse);
    draw_set_color(_shadow_col);
    draw_rectangle(_x - 2, _y - 2, _x + _box_w + 2, _y + _box_h + 2, false);

    draw_set_alpha(1);
    draw_set_color(_base_col);
    draw_rectangle(_x, _y, _x + _box_w, _y + _box_h, true);
    draw_rectangle(_x + 1, _y + 1, _x + _box_w - 1, _y + _box_h - 1, true);

    var _corner = __bwu(_pid, 6);
    draw_line_width(_x, _y, _x + _corner, _y, 2);
    draw_line_width(_x, _y, _x, _y + _corner, 2);
    draw_line_width(_x + _box_w, _y, _x + _box_w - _corner, _y, 2);
    draw_line_width(_x + _box_w, _y, _x + _box_w, _y + _corner, 2);
    draw_line_width(_x, _y + _box_h, _x + _corner, _y + _box_h, 2);
    draw_line_width(_x, _y + _box_h, _x, _y + _box_h - _corner, 2);
    draw_line_width(_x + _box_w, _y + _box_h, _x + _box_w - _corner, _y + _box_h, 2);
    draw_line_width(_x + _box_w, _y + _box_h, _x + _box_w, _y + _box_h - _corner, 2);

    draw_set_alpha(1);
    draw_set_color(c_white);
}

function __battle_get_actor_scene_anchor(_pid, _B, _actorIndex){
    var _is_double = __battle_is_double_scene(_B);
    var _view_anchor = __battle_actor_view_side_slot(_pid, _actorIndex);
    var _side = (is_struct(_view_anchor) && variable_struct_exists(_view_anchor, "side")) ? variable_struct_get(_view_anchor, "side") : __battle_actor_side(_actorIndex);
    var _slot = (is_struct(_view_anchor) && variable_struct_exists(_view_anchor, "slot")) ? variable_struct_get(_view_anchor, "slot") : __battle_actor_slot(_actorIndex);

    if (!_is_double){
        if (_side == 1) return {
            battler: __battle_scene_point(_pid, 165, 40),
            scale_mult: 1
        };
        return {
            battler: __battle_scene_point(_pid, 64, 112),
            trainer: __battle_scene_point(_pid, 32, 108),
            scale_mult: 1
        };
    }

    if (_side == 1){
        if (_slot == 0) return {
            battler: __battle_scene_point(_pid, 180, 36),
            scale_mult: 1
        };
        return {
            battler: __battle_scene_point(_pid, 130, 52),
            scale_mult: 1
        };
    }

    if (_slot == 0){
        return {
            battler: __battle_scene_point(_pid, 110, 100),
            trainer: __battle_scene_point(_pid, 32, 108),
            scale_mult: 1
        };
    }

    return {
        battler: __battle_scene_point(_pid, 52, 114),
        trainer: __battle_scene_point(_pid, 32, 108),
        scale_mult: 1
    };
}

function __battle_draw_trainer_switch_overlay(_pid, _B, _field_x, _field_y){
    if (!is_struct(_B) || !variable_struct_exists(_B, "_trainer_switch")) return false;
    var anim = variable_struct_get(_B, "_trainer_switch");
    if (!is_struct(anim)) return false;

    var ui_s = 1;
    try {
        if (variable_struct_exists(_B, "_ui")){
            var _ui_sw = variable_struct_get(_B, "_ui");
            if (is_struct(_ui_sw) && variable_struct_exists(_ui_sw, "s")) ui_s = variable_struct_get(_ui_sw, "s");
        }
    } catch (e_ui_sw) { ui_s = 1; }

    var ball_sprite = (variable_struct_exists(anim, "ball_sprite") ? variable_struct_get(anim, "ball_sprite") : undefined);
    if (is_undefined(ball_sprite) || !sprite_exists(ball_sprite)){
        ball_sprite = __battle_get_default_ball_sprite();
    }
    var ball_scale = (variable_struct_exists(anim, "ball_scale") && is_real(variable_struct_get(anim, "ball_scale"))) ? max(0.1, real(variable_struct_get(anim, "ball_scale"))) : 0.75;
    var origin_x = __bxu(_pid, (variable_struct_exists(anim, "throw_origin_x") && is_real(variable_struct_get(anim, "throw_origin_x"))) ? real(variable_struct_get(anim, "throw_origin_x")) : 210);
    var origin_y = __byu(_pid, (variable_struct_exists(anim, "throw_origin_y") && is_real(variable_struct_get(anim, "throw_origin_y"))) ? real(variable_struct_get(anim, "throw_origin_y")) : 72);
    var phase = (variable_struct_exists(anim, "phase") ? string(variable_struct_get(anim, "phase")) : "");
    var start_ms = (variable_struct_exists(anim, "phase_start_ms") && is_real(variable_struct_get(anim, "phase_start_ms"))) ? real(variable_struct_get(anim, "phase_start_ms")) : current_time;
    var bx = _field_x;
    var by = _field_y;

    if (phase == "recall"){
        var recall_dur = (variable_struct_exists(anim, "recall_duration") && is_real(variable_struct_get(anim, "recall_duration"))) ? max(1, real(variable_struct_get(anim, "recall_duration"))) : 220;
        var recall_prog = clamp((current_time - start_ms) / recall_dur, 0, 1);
        bx = lerp(_field_x, origin_x, recall_prog);
        by = lerp(_field_y, origin_y, recall_prog) - sin(recall_prog * pi) * __bhu(_pid, 10);
    } else if (phase == "throw"){
        var throw_dur = (variable_struct_exists(anim, "throw_duration") && is_real(variable_struct_get(anim, "throw_duration"))) ? max(1, real(variable_struct_get(anim, "throw_duration"))) : 540;
        var throw_prog = clamp((current_time - start_ms) / throw_dur, 0, 1);
        bx = lerp(origin_x, _field_x, throw_prog);
        by = lerp(origin_y, _field_y, throw_prog);
        by -= sin(throw_prog * pi) * __bhu(_pid, (variable_struct_exists(anim, "throw_height") && is_real(variable_struct_get(anim, "throw_height"))) ? real(variable_struct_get(anim, "throw_height")) : 52);
    } else if (phase == "materialize"){
        bx = _field_x;
        by = _field_y;
    } else {
        return false;
    }

    if (!is_undefined(ball_sprite) && sprite_exists(ball_sprite)){
        var scale_draw = ball_scale * ui_s;
        var spr_w_ball = sprite_get_width(ball_sprite);
        var spr_h_ball = sprite_get_height(ball_sprite);
        var origin_off_x = (spr_w_ball * 0.5 - sprite_get_xoffset(ball_sprite)) * scale_draw;
        var origin_off_y = (spr_h_ball * 0.5 - sprite_get_yoffset(ball_sprite)) * scale_draw;
        var ball_alpha = 1;
        if (phase == "materialize"){
            var materialize_dur = (variable_struct_exists(anim, "materialize_duration") && is_real(variable_struct_get(anim, "materialize_duration"))) ? max(1, real(variable_struct_get(anim, "materialize_duration"))) : 180;
            var materialize_prog = clamp((current_time - start_ms) / materialize_dur, 0, 1);
            ball_alpha = max(0, 1 - materialize_prog);
        }
        draw_sprite_ext(ball_sprite, 0, bx - origin_off_x, by - origin_off_y, scale_draw, scale_draw, 0, c_white, ball_alpha);
    }
    return true;
}

function __battle_get_default_ball_sprite(){
    var ball_sprite = undefined;
    if (!is_undefined(pkicons_get_item_icon_by_id)){
        try {
            var _pk_ball = pkicons_get_item_icon_by_id(4);
            if (!is_undefined(_pk_ball) && sprite_exists(_pk_ball)) ball_sprite = _pk_ball;
        } catch (e_ball_ext) { ball_sprite = undefined; }
    }
    return ball_sprite;
}

function __battle_get_sendout_ball_sprite(_mon){
    var ball_item_id = 4;
    if (is_struct(_mon)){
        if (variable_struct_exists(_mon, "pokeball_item_id") && is_real(variable_struct_get(_mon, "pokeball_item_id"))) ball_item_id = floor(variable_struct_get(_mon, "pokeball_item_id"));
        else if (variable_struct_exists(_mon, "ball_item_id") && is_real(variable_struct_get(_mon, "ball_item_id"))) ball_item_id = floor(variable_struct_get(_mon, "ball_item_id"));
        else if (variable_struct_exists(_mon, "capture_ball_item_id") && is_real(variable_struct_get(_mon, "capture_ball_item_id"))) ball_item_id = floor(variable_struct_get(_mon, "capture_ball_item_id"));
    }
    if (!is_real(ball_item_id) || ball_item_id <= 0) ball_item_id = 4;

    var ball_sprite = undefined;
    if (!is_undefined(pkicons_get_item_icon_by_id)){
        try {
            var _ball_spr = pkicons_get_item_icon_by_id(ball_item_id);
            if (!is_undefined(_ball_spr) && sprite_exists(_ball_spr)) ball_sprite = _ball_spr;
        } catch (e_ball_mon) { ball_sprite = undefined; }
    }
    if (is_undefined(ball_sprite) && ball_item_id != 4) ball_sprite = __battle_get_default_ball_sprite();
    return ball_sprite;
}

function __battle_draw_player_throw_overlay(_pid, _progress, _origin_x, _origin_y, _target_x, _target_y, _mon, _ui_s, _ball_alpha){
    var ball_sprite = __battle_get_sendout_ball_sprite(_mon);
    if (is_undefined(ball_sprite) || !sprite_exists(ball_sprite)) return false;

    var t = clamp(_progress, 0, 1);
    var bx = lerp(_origin_x, _target_x, t);
    var by = lerp(_origin_y, _target_y, t);
    by -= sin(t * pi) * __bhu(_pid, 26);

    var frames = max(1, sprite_get_number(ball_sprite));
    var subimg = (frames <= 1) ? 0 : clamp(floor(t * (frames - 1)), 0, frames - 1);
    var scale_draw = 0.8 * _ui_s;
    var spr_w = sprite_get_width(ball_sprite);
    var spr_h = sprite_get_height(ball_sprite);
    var origin_off_x = (spr_w * 0.5 - sprite_get_xoffset(ball_sprite)) * scale_draw;
    var origin_off_y = (spr_h * 0.5 - sprite_get_yoffset(ball_sprite)) * scale_draw;
    draw_sprite_ext(ball_sprite, subimg, bx - origin_off_x, by - origin_off_y, scale_draw, scale_draw, 0, c_white, clamp(_ball_alpha, 0, 1));
    return true;
}

function __battle_draw_enemy(_pid, _B, _actorIndex, fx, fy){
    var scale_foe = 1.0;
    var E = undefined;
    if (is_array(_B.actor) && _actorIndex >= 0 && _actorIndex < array_length(_B.actor)) E = _B.actor[_actorIndex];
    // If the enemy actor or its mon data is missing, still draw the
    // battlefield platform so the scene doesn't lose its ground.
    if (!is_struct(E) || !variable_struct_exists(E, "mon")){
        try {
            var ui_s_tmp = 1;
            var __Bsl_tmp = __battle_ensure_slot(_pid);
            if (is_struct(__Bsl_tmp) && variable_struct_exists(__Bsl_tmp, "_ui")){
                var __ui_tmp = variable_struct_get(__Bsl_tmp, "_ui");
                if (is_struct(__ui_tmp) && variable_struct_exists(__ui_tmp, "s")) ui_s_tmp = variable_struct_get(__ui_tmp, "s");
            }
            var _w_tmp = 64; var _h_tmp = 64;
            var platform_bottom_tmp = fy + (_h_tmp * scale_foe * ui_s_tmp) * 0.5;
            __battle_draw_platform(_pid, _B, "enemy", fx, platform_bottom_tmp, ui_s_tmp);
        } catch (e_pl) {}
        return;
    }
    if (string(_B.phase) == "transition_in") return;
    var __trainer_hide = false;
    var __trainer_scale = 1;
    var __trainer_skip_slide = false;
    var __view_enemy = __battle_actor_view_side_slot(_pid, _actorIndex);
    var __enemy_slot = (is_struct(__view_enemy) && variable_struct_exists(__view_enemy, "slot")) ? variable_struct_get(__view_enemy, "slot") : __battle_actor_slot(_actorIndex);
    var __is_lead_enemy = (__enemy_slot == 0);
    try {
        if (is_struct(_B) && variable_struct_exists(_B, "_trainer_intro")){
            var __ti = variable_struct_get(_B, "_trainer_intro");
            if (is_struct(__ti)){
                if (__is_lead_enemy && variable_struct_exists(__ti, "hide_enemy_mon") && __ti.hide_enemy_mon) __trainer_hide = true;
                if (variable_struct_exists(__ti, "enemy_scale_mult")){
                    var __sc = variable_struct_get(__ti, "enemy_scale_mult");
                    if (is_real(__sc)) __trainer_scale = clamp(__sc, 0, 4);
                }
                if (variable_struct_exists(__ti, "skip_intro_slide") && __ti.skip_intro_slide) __trainer_skip_slide = true;
            }
        }
    } catch (e_hide) {}
    if (__trainer_hide) return;
    var mE = variable_struct_get(E, "mon");
    // Try to obtain art; if the pkicons loaders aren't ready or the sprite is missing
    // we must NOT abort here — draw a placeholder so intro and ball overlay still run.
    var sprE = undefined;
    var subE = 0;
    if (!(is_undefined(pkicons_get_art96_by_mon) || is_undefined(pkicons_get_art96_subimg_by_mon))){
        sprE = pkicons_get_art96_by_mon(mE);
        subE = pkicons_get_art96_subimg_by_mon(mE, false);
    }
    var _spr_missing = false;
    var w = 64;
    var h = 64;
    if (!is_undefined(sprE) && sprite_exists(sprE)){
        _spr_missing = false;
        w = sprite_get_width(sprE);
        h = sprite_get_height(sprE);
    } else {
        _spr_missing = true;
    }
    var ui_s = 1;
    try {
        var __Bsl = __battle_ensure_slot(_pid);
        if (is_struct(__Bsl) && variable_struct_exists(__Bsl, "_ui")){
            var __ui = variable_struct_get(__Bsl, "_ui");
            if (is_struct(__ui) && variable_struct_exists(__ui, "s")) ui_s = variable_struct_get(__ui, "s");
        }
    } catch (e_ui) { ui_s = 1; }
    var _enemy_layout = __battle_get_actor_scene_anchor(_pid, _B, _actorIndex);
    var _enemy_scale_mult = (is_struct(_enemy_layout) && variable_struct_exists(_enemy_layout, "scale_mult") && is_real(variable_struct_get(_enemy_layout, "scale_mult"))) ? real(variable_struct_get(_enemy_layout, "scale_mult")) : 1;
    var drawScaleE = scale_foe * _enemy_scale_mult * ui_s * __trainer_scale;
    var __trainer_switch = undefined;
    try {
        if (variable_struct_exists(_B, "_trainer_switch")){
            var __ts_chk = variable_struct_get(_B, "_trainer_switch");
            if (is_struct(__ts_chk)) __trainer_switch = __ts_chk;
        }
    } catch (e_ts_chk) {}
    // Compute a species-based vertical origin adjustment so small/large mons align with platform
    var species_adj_px_e = 0;
    var species_height_m_e = undefined;
    // Resolve species id from common fields (species_id preferred, fall back to species)
    var _resolved_sid_e = undefined;
    if (variable_struct_exists(mE, "species_id")) _resolved_sid_e = variable_struct_get(mE, "species_id");
    else if (variable_struct_exists(mE, "species")) _resolved_sid_e = variable_struct_get(mE, "species");
    if (is_real(_resolved_sid_e) && variable_global_exists("_pokemon") && is_array(global._pokemon)){
        var _sid_e2 = floor(_resolved_sid_e);
        if (is_real(_sid_e2) && _sid_e2 >= 0 && _sid_e2 < array_length(global._pokemon)){
            var _sp_e2 = global._pokemon[_sid_e2];
            if (is_struct(_sp_e2) && variable_struct_exists(_sp_e2, "height")){
                var _height_dm_e2 = real(variable_struct_get(_sp_e2, "height"));
                var _height_m_e2 = _height_dm_e2 * 0.1;
                species_height_m_e = _height_m_e2;
                var minH_e = 0.15; var maxH_e = 3.0;
                var norm_e2 = clamp((_height_m_e2 - minH_e) / max(0.0001, (maxH_e - minH_e)), 0, 1);
                var adj_px_e2 = lerp(0.30 * h, -0.04 * h, norm_e2);
                // increased extra nudge for the tiniest species to ensure they touch ground
                var extra_nudge_e = floor(lerp(10, 0, norm_e2));
                species_adj_px_e = floor(adj_px_e2) + extra_nudge_e;
            }
        }
    }
    // Freeze detection for enemy (used to modify breathing and tint)
    var _has_freeze = false;
    try { _has_freeze = status_system_has_status(E, "freeze"); } catch (e_hf_e) { _has_freeze = false; }
    var _just_cured = (variable_struct_exists(E, "_freeze_just_cured_ms") ? variable_struct_get(E, "_freeze_just_cured_ms") : undefined);
    var _img_blend_e = c_white;
    if (_has_freeze) _img_blend_e = make_color_rgb(120,160,255);
    // Preserve the original fx for platform drawing. We may override `fx`
    // below to hide the sprite early in the intro, but the platform should
    // still draw at the intended anchor.
    var __orig_fx = fx;
    // If this is a wild enemy intro and we're at the very start, force
    // the sprite origin offscreen so nothing is drawn at the usual center.
    // We place this early so the platform/placeholder code doesn't briefly
    // draw the foe at the screen origin before the intro slide begins.
    try {
        var __is_trainer_intro_early = (variable_struct_exists(_B, "_trainer_intro") && is_struct(variable_struct_get(_B, "_trainer_intro")));
        if (string(_B.phase) == "intro_enemy" && !__trainer_skip_slide && !__is_trainer_intro_early){
            var __p_intro_early = (variable_struct_exists(_B, "phase_progress") ? real(_B.phase_progress) : 0);
            if (__p_intro_early <= 0.2){
                // move the drawing origin to offscreen right so any early draw is out of view
                fx = __bxu(_pid, 280);
            }
        }
    } catch (e_early_hide) {}
    var base_fy = fy;
    var platform_bottom = base_fy + (h * drawScaleE) * 0.5;
    // Use the preserved origin for platform drawing so the platform stays
    // anchored even when we temporarily move `fx` offscreen for the sprite.
    __battle_draw_platform(_pid, _B, "enemy", __orig_fx, platform_bottom, ui_s);

    var _local_versus_switch_intro = false;
    var _incoming_switch_mon = undefined;
    try {
        if (!is_undefined(__battle_is_local_versus_slot) && __battle_is_local_versus_slot(_B)
            && string(_B.phase) == "intro_call"
            && variable_struct_exists(_B, "_pending_switch_after_intro") && variable_struct_get(_B, "_pending_switch_after_intro")
            && variable_struct_exists(_B, "_switch_actor_index") && is_real(variable_struct_get(_B, "_switch_actor_index"))
            && floor(variable_struct_get(_B, "_switch_actor_index")) == floor(_actorIndex)){
            var _switch_owner_pid = __battle_actor_owner_pid(_pid, _actorIndex);
            var _switch_dialog_open = (!is_undefined(dialog2p_is_open) && is_real(_switch_owner_pid) && dialog2p_is_open(floor(_switch_owner_pid)));
            if (is_real(_switch_owner_pid) && floor(_switch_owner_pid) != floor(_pid)
                && _switch_dialog_open
                && variable_struct_exists(_B, "_switch_target_idx") && is_real(variable_struct_get(_B, "_switch_target_idx"))
                && !is_undefined(party_ensure)){
                var _switch_party = party_ensure(_switch_owner_pid);
                var _switch_idx = floor(variable_struct_get(_B, "_switch_target_idx"));
                if (is_struct(_switch_party) && variable_struct_exists(_switch_party, "mons") && is_array(variable_struct_get(_switch_party, "mons"))
                    && _switch_idx >= 0 && _switch_idx < array_length(variable_struct_get(_switch_party, "mons"))){
                    _incoming_switch_mon = variable_struct_get(_switch_party, "mons")[_switch_idx];
                    _local_versus_switch_intro = is_struct(_incoming_switch_mon);
                }
            }
        }
    } catch (e_vs_switch_intro) {
        _local_versus_switch_intro = false;
        _incoming_switch_mon = undefined;
    }
    if (_local_versus_switch_intro){
        var _switch_prog_intro = clamp((variable_struct_exists(_B, "phase_progress") ? real(variable_struct_get(_B, "phase_progress")) : 0), 0, 1);
        var _throw_split_intro = 0.58;
        var _throw_prog_intro = clamp(_switch_prog_intro / _throw_split_intro, 0, 1);
        var _reveal_prog_intro = clamp((_switch_prog_intro - _throw_split_intro) / max(0.001, 1 - _throw_split_intro), 0, 1);
        var _reveal_ease_intro = 1 - power(1 - _reveal_prog_intro, 2);
        var _trainer_anchor_intro = (is_struct(_enemy_layout) && variable_struct_exists(_enemy_layout, "trainer")) ? variable_struct_get(_enemy_layout, "trainer") : [__bxu(_pid, 165), __byu(_pid, 40)];
        var _ball_origin_x_intro = (is_array(_trainer_anchor_intro) && array_length(_trainer_anchor_intro) >= 2) ? _trainer_anchor_intro[0] + __bwu(_pid, 8) : __bxu(_pid, 173);
        var _ball_origin_y_intro = (is_array(_trainer_anchor_intro) && array_length(_trainer_anchor_intro) >= 2) ? _trainer_anchor_intro[1] - __bhu(_pid, 20) : __byu(_pid, 20);
        var _ball_target_x_intro = fx;
        var _ball_target_y_intro = fy - __bhu(_pid, 10);
        var _ball_alpha_intro = (_switch_prog_intro < _throw_split_intro) ? 1 : max(0, 1 - _reveal_prog_intro);
        __battle_draw_player_throw_overlay(_pid, _throw_prog_intro, _ball_origin_x_intro, _ball_origin_y_intro, _ball_target_x_intro, _ball_target_y_intro, _incoming_switch_mon, ui_s, _ball_alpha_intro);

        if (_switch_prog_intro >= _throw_split_intro && !is_undefined(pkicons_get_art96_by_mon) && !is_undefined(pkicons_get_art96_subimg_by_mon)){
            var _spr_intro = pkicons_get_art96_by_mon(_incoming_switch_mon);
            var _sub_intro = pkicons_get_art96_subimg_by_mon(_incoming_switch_mon, false);
            if (!is_undefined(_spr_intro) && sprite_exists(_spr_intro)){
                var _w_intro = sprite_get_width(_spr_intro);
                var _h_intro = sprite_get_height(_spr_intro);
                var _origin_x_intro = sprite_get_xoffset(_spr_intro);
                var _origin_y_intro = sprite_get_yoffset(_spr_intro);
                var _scale_intro = lerp(drawScaleE * 0.55, drawScaleE, _reveal_ease_intro);
                var _draw_x_intro = fx + (_origin_x_intro - (_w_intro * 0.5)) * _scale_intro;
                var _platform_bottom_intro = base_fy + (_h_intro * _scale_intro) * 0.5;
                var _draw_y_intro = _platform_bottom_intro - (_h_intro - _origin_y_intro) * _scale_intro - __bhu(_pid, 8) * (1 - _reveal_prog_intro);
                draw_set_color(make_color_rgb(20,20,20));
                draw_set_alpha(0.45);
                var _shadow_w_intro = floor((_w_intro * _scale_intro) * 0.6);
                var _shadow_h_intro = max(2, floor((_w_intro * _scale_intro) * 0.12));
                var _shadow_cx_intro = floor(_draw_x_intro + (_w_intro * _scale_intro) * 0.5);
                var _shadow_cy_intro = floor(_platform_bottom_intro + _shadow_h_intro * 0.8 + floor(15 * ui_s));
                draw_ellipse(_shadow_cx_intro - _shadow_w_intro div 2, _shadow_cy_intro - _shadow_h_intro div 2, _shadow_cx_intro + _shadow_w_intro div 2, _shadow_cy_intro + _shadow_h_intro div 2, false);
                draw_set_alpha(1);
                draw_sprite_ext(_spr_intro, _sub_intro, _draw_x_intro, _draw_y_intro, _scale_intro, _scale_intro, 0, c_white, clamp(_reveal_ease_intro, 0, 1));
            }
        }
        return;
    }

    var catchA = (variable_struct_exists(_B, "_catch_anim") ? _B._catch_anim : undefined);
    var catch_affects_enemy = false;
    if (is_struct(catchA) && variable_struct_exists(catchA, "active") && catchA.active){
        var _catch_target_actor = (variable_struct_exists(catchA, "target_actor_index") && is_real(variable_struct_get(catchA, "target_actor_index"))) ? floor(variable_struct_get(catchA, "target_actor_index")) : 1;
        catch_affects_enemy = (_actorIndex == _catch_target_actor);
    }
    var fainting = false;
    var faint_prog = 0;
    var enemy_alpha = 1;
    if (!catch_affects_enemy){
        var hp_now_enemy = undefined;
        if (!is_undefined(__battle_hp_now)){
            hp_now_enemy = __battle_hp_now(E);
        } else if (variable_struct_exists(E, "hp_now")){
            hp_now_enemy = variable_struct_get(E, "hp_now");
        }
        if (!is_real(hp_now_enemy)) hp_now_enemy = (variable_struct_exists(E, "hp_now") ? real(variable_struct_get(E, "hp_now")) : 1);
        if (hp_now_enemy <= 0){
            fainting = true;
            var faint_start_ms = current_time;
            if (variable_struct_exists(E, "_faint_draw_start_ms") && is_real(variable_struct_get(E, "_faint_draw_start_ms"))){
                faint_start_ms = variable_struct_get(E, "_faint_draw_start_ms");
            } else {
                variable_struct_set(E, "_faint_draw_start_ms", faint_start_ms);
            }
            faint_prog = clamp((current_time - faint_start_ms) / 520, 0, 1);
            var faint_ease = 1 - power(1 - faint_prog, 3);
            var faint_scale_mult = max(0, 1 - faint_ease);
            drawScaleE *= faint_scale_mult;
            enemy_alpha = max(0, 1 - faint_ease);
            var faint_drop = __bhu(_pid, 16) * faint_ease;
            fy += faint_drop;
            if (enemy_alpha <= 0.001 || faint_scale_mult <= 0.001){
                enemy_alpha = 0;
            }
        } else {
            if (variable_struct_exists(E, "_faint_draw_start_ms")) variable_struct_set(E, "_faint_draw_start_ms", undefined);
        }
    } else {
        if (variable_struct_exists(E, "_faint_draw_start_ms")) variable_struct_set(E, "_faint_draw_start_ms", undefined);
    }
    if (is_struct(__trainer_switch)){
        var __ts_phase = (variable_struct_exists(__trainer_switch, "phase") ? string(variable_struct_get(__trainer_switch, "phase")) : "");
        var __ts_start = (variable_struct_exists(__trainer_switch, "phase_start_ms") && is_real(variable_struct_get(__trainer_switch, "phase_start_ms"))) ? real(variable_struct_get(__trainer_switch, "phase_start_ms")) : current_time;
        if (__ts_phase == "recall"){
            var __recall_dur = (variable_struct_exists(__trainer_switch, "recall_duration") && is_real(variable_struct_get(__trainer_switch, "recall_duration"))) ? max(1, real(variable_struct_get(__trainer_switch, "recall_duration"))) : 220;
            var __recall_prog = clamp((current_time - __ts_start) / __recall_dur, 0, 1);
            var __recall_ease = 1 - power(1 - __recall_prog, 2);
            drawScaleE *= max(0, 1 - __recall_ease);
            enemy_alpha *= max(0, 1 - __recall_ease);
            fy -= __bhu(_pid, 10) * __recall_ease;
        } else if (__ts_phase == "throw"){
            enemy_alpha = 0;
            drawScaleE = 0;
        } else if (__ts_phase == "materialize"){
            var __mat_dur = (variable_struct_exists(__trainer_switch, "materialize_duration") && is_real(variable_struct_get(__trainer_switch, "materialize_duration"))) ? max(1, real(variable_struct_get(__trainer_switch, "materialize_duration"))) : 180;
            var __mat_prog = clamp((current_time - __ts_start) / __mat_dur, 0, 1);
            var __mat_ease = 1 - power(1 - __mat_prog, 2);
            enemy_alpha *= lerp(0.15, 1, __mat_ease);
            drawScaleE *= lerp(0.05, 1, __mat_ease);
            fy -= __bhu(_pid, 12) * (1 - __mat_ease);
        }
    }
    if (enemy_alpha <= 0.001 && drawScaleE <= 0.001){
        __battle_draw_trainer_switch_overlay(_pid, _B, fx, fy);
        return;
    }
    // Hide the enemy sprite at the very start of the enemy intro for wild battles.
    // Some startup/cutscene timing can briefly draw the foe at its final center
    // before the intro logic moves it offscreen; for wild battles we keep it
    // invisible until the intro progress has moved slightly to avoid a flicker.
    try {
        var __is_trainer_intro = (variable_struct_exists(_B, "_trainer_intro") && is_struct(variable_struct_get(_B, "_trainer_intro")));
        if (string(_B.phase) == "intro_enemy" && !__trainer_skip_slide && !__is_trainer_intro){
            var __p_intro = (variable_struct_exists(_B, "phase_progress") ? real(_B.phase_progress) : 0);
            // keep hidden until progress advances beyond a modest threshold
            if (__p_intro <= 0.2){
                enemy_alpha = 0;
                drawScaleE = 0;
            }
        }
    } catch (e_intro_hide) {}
    var cry_started_e = (variable_struct_exists(_B, "_cry_play_start_ms_enemy") && is_real(_B._cry_play_start_ms_enemy)) ? real(_B._cry_play_start_ms_enemy) : -1;
    if (cry_started_e > 0){
        var tnow_e = current_time;
        var dt_e = tnow_e - cry_started_e;
        var grow_dur = 600;
        if (dt_e >= 0 && dt_e <= grow_dur){
            var prog_e = dt_e / grow_dur;
            var ease_e = sin(prog_e * pi);
            var grow = 1 + ease_e * 0.06;
            drawScaleE *= grow;
        }
    }
    // During enemy intro, start offscreen to the right and slide in based on phase_progress
    if (__is_lead_enemy && string(_B.phase) == "intro_enemy" && !__trainer_skip_slide){
        var p_in = (variable_struct_exists(_B, "phase_progress") ? _B.phase_progress : 0);
        var start_cx = __bxu(_pid, 280); // logical 280 -> offscreen right of 240-wide canvas
        var ease = 1 - (1 - p_in) * (1 - p_in);
        fx = lerp(start_cx, fx, ease);
    }
    // Position using sprite origin so large sprites anchor correctly
    var origin_x_e = (is_undefined(sprE) || !sprite_exists(sprE)) ? (w * 0.5) : sprite_get_xoffset(sprE);
    var origin_y_e = (is_undefined(sprE) || !sprite_exists(sprE)) ? (h * 0.5) : sprite_get_yoffset(sprE);
    // Apply species-origin adjustment computed earlier so visual feet/shadow align with platform
    origin_y_e = clamp(origin_y_e + species_adj_px_e, 0, h);
    var draw_x = fx + (origin_x_e - (w * 0.5)) * drawScaleE;
    // Anchor sprite bottom to the platform bottom so different sprite origins/sizes align correctly
    var platform_bottom_local = base_fy + (h * drawScaleE) * 0.5;
    var draw_y = platform_bottom_local - (h - origin_y_e) * drawScaleE;
    __battle_draw_trainer_switch_overlay(_pid, _B, fx, fy);
    // If actor is not grounded (flying / levitate), raise sprite to simulate floating
    try {
        var _is_grounded_e = true;
        if (!is_undefined(__actor_is_grounded)) _is_grounded_e = __actor_is_grounded(E);
        // species-level fallback: if grounded==true, check types/ability/species types for Flying
        if (_is_grounded_e){
            try {
                var _flying_id_e = undefined;
                if (variable_global_exists("TYPE_ID_BY_NAME")){
                    var _tmp_e = variable_global_get("TYPE_ID_BY_NAME"); if (ds_exists(_tmp_e, ds_type_map)) _flying_id_e = ds_map_find_value(_tmp_e, string_lower("flying"));
                }
                if (!is_undefined(_flying_id_e) && is_real(_flying_id_e)){
                    if (variable_struct_exists(E, "types") && is_array(variable_struct_get(E, "types"))){ var _pta_e = variable_struct_get(E, "types"); for (var _tti_e=0; _tti_e<array_length(_pta_e); ++_tti_e) if (is_real(_pta_e[_tti_e]) && _pta_e[_tti_e] == _flying_id_e) { _is_grounded_e = false; break; } }
                    if (_is_grounded_e && variable_struct_exists(E, "type1") && is_real(variable_struct_get(E, "type1")) && variable_struct_get(E, "type1") == _flying_id_e) _is_grounded_e = false;
                    if (_is_grounded_e && variable_struct_exists(E, "type2") && is_real(variable_struct_get(E, "type2")) && variable_struct_get(E, "type2") == _flying_id_e) _is_grounded_e = false;
                    // Also check the inner mon struct (mE) for stored type fields when actor-level fields are missing
                    if (_is_grounded_e && is_struct(mE)){
                        if (variable_struct_exists(mE, "types") && is_array(variable_struct_get(mE, "types"))){ var _mpta = variable_struct_get(mE, "types"); for (var _mmi=0; _mmi<array_length(_mpta); ++_mmi) if (is_real(_mpta[_mmi]) && _mpta[_mmi] == _flying_id_e){ _is_grounded_e = false; break; } }
                        if (_is_grounded_e && variable_struct_exists(mE, "type1") && is_real(variable_struct_get(mE, "type1")) && variable_struct_get(mE, "type1") == _flying_id_e) _is_grounded_e = false;
                        if (_is_grounded_e && variable_struct_exists(mE, "type2") && is_real(variable_struct_get(mE, "type2")) && variable_struct_get(mE, "type2") == _flying_id_e) _is_grounded_e = false;
                    }
                    if (_is_grounded_e && variable_struct_exists(E, "mon") && is_struct(variable_struct_get(E, "mon")) && variable_global_exists("_species_types") && is_array(global._species_types)){
                        var _mref_e = variable_struct_get(E, "mon");
                        var _resolved_sid_mref = undefined;
                        if (variable_struct_exists(_mref_e, "species_id")) _resolved_sid_mref = variable_struct_get(_mref_e, "species_id");
                        else if (variable_struct_exists(_mref_e, "species")) _resolved_sid_mref = variable_struct_get(_mref_e, "species");
                        if (is_real(_resolved_sid_mref)){
                            var _sid_e = floor(_resolved_sid_mref);
                            if (_sid_e >= 0 && _sid_e < array_length(global._species_types)){
                                var _starr_e = global._species_types[_sid_e];
                                if (is_array(_starr_e)) for (var _jj_e=0; _jj_e<array_length(_starr_e); ++_jj_e) if (is_real(_starr_e[_jj_e]) && _starr_e[_jj_e] == _flying_id_e) { _is_grounded_e = false; break; }
                            }
                        }
                    }
                }
            } catch (e_fly_e) {}
        }
        if (!_is_grounded_e){
            var _float_px = __bhu(_pid, 18);
            draw_y -= _float_px;
        }
    } catch (e_flt_e) {}
    // Draw frozen-state sprite behind the battler when applicable.
    try {
        if (sprite_exists(spr_frozen)){
            var _has_freeze = false;
            try { _has_freeze = status_system_has_status(E, "freeze"); } catch (e_hasf) { _has_freeze = false; }
            var _just_cured = (variable_struct_exists(E, "_freeze_just_cured_ms") ? variable_struct_get(E, "_freeze_just_cured_ms") : undefined);
            // Fade-out on cure instead of shrinking: compute alpha over time
            var _freeze_scale = drawScaleE;
            var _freeze_alpha = enemy_alpha;
            if (is_real(_just_cured)){
                var _dt = current_time - _just_cured;
                var _dur = 700; // fade duration in ms
                var _prog = clamp(_dt / max(1, _dur), 0, 1);
                _freeze_alpha = lerp(enemy_alpha, 0, _prog);
                if (_prog >= 1){
                    // remove transient marker once animation finished
                    try { variable_struct_set(E, "_freeze_just_cured_ms", undefined); } catch (e_cl) {}
                }
            } else if (!_has_freeze){
                // not frozen and no recent cure -> don't draw
                _freeze_alpha = 0;
            }
            if (_freeze_alpha > 0.001){
                // position sprite slightly offset under the mon (-45, -45) in logical pixels scaled by UI
                var _offx = __bxu(_pid, 0) * 0; // noop but keeps style consistent
                var _spr_x = fx - 45 * ui_s;
                var _spr_y = fy - 45 * ui_s;
                draw_sprite_ext(spr_frozen, 0, _spr_x, _spr_y, _freeze_scale, _freeze_scale, 0, c_white, _freeze_alpha);
                // debug logging disabled: removed noisy per-frame freeze draw messages
            }
        }
    } catch (e_fd) {}
    // Read temporary nudge offsets (attacker/defender may be moved by effects).
    // We compute the offset here but apply it later after scaling/anchor recompute so it isn't overwritten.
    var _nudge_px_e = 0;
    var _nudge_finished_e = false;
    try {
        if (is_struct(E) && variable_struct_exists(E, "_nudge_active") && variable_struct_get(E, "_nudge_active") == true){
            var _ns = variable_struct_get(E, "_nudge_start_ms");
            var _nd = variable_struct_get(E, "_nudge_dur");
            var _nm = variable_struct_get(E, "_nudge_mag");
            var _ndir = variable_struct_get(E, "_nudge_dir");
            var _now_n = current_time;
            var _p_n = clamp((_now_n - _ns) / max(1, _nd), 0, 1);
            // ease out then return: symmetric curve
            var _frac_n = (_p_n <= 0.5) ? (1 - power(1 - (_p_n / 0.5), 2)) : (1 - power(((_p_n - 0.5) / 0.5), 2));
            _nudge_px_e = __battle_anim_queue_wu(_pid, _nm) * _ndir * _frac_n;
            if (_p_n >= 1) _nudge_finished_e = true;
        }
    } catch (e_nudge_e) {}
    // If a catch animation is active, allow it to modify the enemy scale and draw a pokéball
    var anchor_overridden = fainting;
    var ball_to_draw = undefined;
    // Use the actor anchor as the capture landing point so the ball settles on the
    // selected target's bottom-center instead of a generic enemy-area midpoint.
    var catch_shadow_center_x = floor(fx);
    var catch_shadow_h = max(2, floor((w * drawScaleE) * 0.12));
    var catch_shadow_center_y = 0;
    catch_shadow_center_y = floor(platform_bottom_local + catch_shadow_h * 0.8 + floor(15 * ui_s));
    // The ball itself should sit above the shadow, not at the shadow center.
    var catch_land_x = catch_shadow_center_x;
    var catch_land_y = floor(platform_bottom_local - max(4, floor(6 * ui_s)));
    if (!fainting && catch_affects_enemy && is_struct(catchA) && catchA.active){
        // Re-stamp the landing point from the live enemy draw path. The catch
        // animation is created during update, where _B._ui may be undefined and
        // __bxu/__byu can fall back to unscaled logical coordinates.
        variable_struct_set(catchA, "land_x", catch_land_x);
        variable_struct_set(catchA, "land_y", catch_land_y);
        var now = current_time;
        var since = now - (variable_struct_exists(catchA, "start_ms") ? catchA.start_ms : now);
        // Compute phases: throw -> impact -> shake -> resolve -> escape
        var phase = string(catchA.phase);
        // safe defaults for durations
        var throw_dur = (variable_struct_exists(catchA, "throw_dur") ? max(1, real(catchA.throw_dur)) : 380);
        var impact_dur = (variable_struct_exists(catchA, "impact_dur") ? max(1, real(catchA.impact_dur)) : 220);
        var shake_dur = (variable_struct_exists(catchA, "shake_dur") ? max(1, real(catchA.shake_dur)) : 900);
        var escape_dur = (variable_struct_exists(catchA, "escape_dur") ? max(1, real(catchA.escape_dur)) : 320);

        if (phase == "throw"){
            var t = clamp(since / throw_dur, 0, 1);
            // Ball travels from the trainer area to the stored landing point at the target's feet.
            var sx = __bxu(_pid, 32);
            var sy = __byu(_pid, 108);
            var txp = (variable_struct_exists(catchA, "land_x") ? variable_struct_get(catchA, "land_x") : catch_land_x);
            var typ = (variable_struct_exists(catchA, "land_y") ? variable_struct_get(catchA, "land_y") : catch_land_y);
            // base linear interpolation
            var bx_lin = lerp(sx, txp, t);
            var by_lin = lerp(sy, typ, t);
            // arc height (pixels) proportional to distance between start and target
            var dx = abs(txp - sx);
            var dy = abs(typ - sy);
            var h_arc = max(24, floor((dx + dy) * 0.25));
            // parabolic offset: peaks at t=0.5, value in range [0, h_arc]
            var arc = (1 - ((t - 0.5) * 2) * ((t - 0.5) * 2)) * h_arc;
            var bx = floor(bx_lin);
            var by = floor(by_lin - arc);
            // flight: use a slightly smaller ball and do NOT shrink the enemy until impact
            ball_to_draw = {spr: (is_undefined(catchA.ball_sprite) ? undefined : catchA.ball_sprite), x: bx, y: by, scale: 0.8};
        } else if (phase == "impact"){
            var e = now - (variable_struct_exists(catchA, "phase_start") ? catchA.phase_start : now);
            var t2 = clamp(e / impact_dur, 0, 1);
            var ease2 = sin(t2 * pi);
            // shrink the enemy nearly to zero so it appears to be pulled into the ball
            // Compute target anchor (landing position) and lerp both scale and center toward it
            var anchor_x = (variable_struct_exists(catchA, "land_x") ? variable_struct_get(catchA, "land_x") : catch_land_x);
            var anchor_y = (variable_struct_exists(catchA, "land_y") ? variable_struct_get(catchA, "land_y") : catch_land_y);
            // Lerp scale down smoothly
            var target_scale_mult = lerp(1, 0, ease2);
            drawScaleE *= target_scale_mult;
            enemy_alpha = max(0, 1 - ease2);
            // Lerp the draw center toward the anchor so the sprite appears to be pulled into the ball
            var cur_cx = fx;
            var cur_cy = fy;
            var lerp_cx = lerp(cur_cx, anchor_x, ease2);
            var lerp_cy = lerp(cur_cy, anchor_y, ease2);
            // Update draw_x/draw_y to the lerped center after recalc (we'll recalc later once drawScaleE is set)
            fx = lerp_cx;
            fy = lerp_cy;
            // ball starts centered on the foe while impact completes
                // Record the landed position once so every later phase stays centered on the shadow.
                if (!variable_struct_exists(catchA, "land_x")) variable_struct_set(catchA, "land_x", catch_land_x);
                if (!variable_struct_exists(catchA, "land_y")) variable_struct_set(catchA, "land_y", catch_land_y);
                var bx2 = variable_struct_exists(catchA, "land_x") ? variable_struct_get(catchA, "land_x") : catch_land_x;
                var by2 = variable_struct_exists(catchA, "land_y") ? variable_struct_get(catchA, "land_y") : catch_land_y;
                ball_to_draw = {spr: (is_undefined(catchA.ball_sprite) ? undefined : catchA.ball_sprite), x: bx2, y: by2, scale: 0.8};
            anchor_overridden = true;
        } else if (phase == "shake"){
            // Hopping logic: during shake we run up to hop_total hops. Each hop consists of hop_dur (up/down) + hop_pause.
            var hop_total = (variable_struct_exists(catchA, "hop_total") ? real(catchA.hop_total) : 3);
            var hop_index = (variable_struct_exists(catchA, "hop_index") ? real(catchA.hop_index) : 1);
            var hop_dur_local = (variable_struct_exists(catchA, "hop_dur") ? max(1, real(catchA.hop_dur)) : 320);
            var hop_pause_local = (variable_struct_exists(catchA, "hop_pause") ? max(0, real(catchA.hop_pause)) : 180);
            var cycle = hop_dur_local + hop_pause_local;
            var e3 = now - (variable_struct_exists(catchA, "phase_start") ? catchA.phase_start : now);
            // clamp e3 within current hop cycle
            var local_t = clamp((e3 % cycle) / hop_dur_local, 0, 1);
            // hop Y offset: use sine easing for smooth up/down and increase height slightly for visibility
            var hop_height = max(16, floor((h * ui_s) * 0.18));
            // eased progress in [0..1] with sine easing (0->1->0 across the hop)
            var eased = sin(local_t * pi);
            var arc = eased * hop_height;
            // if we're in the pause portion (after hop_dur_local), keep at bottom
            var in_pause = ((e3 % cycle) >= hop_dur_local);
            var base_x = (variable_struct_exists(catchA, "land_x") ? variable_struct_get(catchA, "land_x") : catch_land_x);
            var base_y = (variable_struct_exists(catchA, "land_y") ? variable_struct_get(catchA, "land_y") : catch_land_y);
            var enemy_base_bottom = base_y;
            var by3 = in_pause ? enemy_base_bottom : (base_y - arc);
            // enemy remains hidden while hops run
            drawScaleE *= 0;
            enemy_alpha = 0;
            var ballScale = (in_pause ? 0.65 : 0.8);
            var bx3 = base_x;
            ball_to_draw = {spr: (is_undefined(catchA.ball_sprite) ? undefined : catchA.ball_sprite), x: bx3, y: by3, scale: ballScale};
            anchor_overridden = true;
        } else if (phase == "resolve" || phase == "caught"){
            // ball rests at the bottom of the enemy sprite; enemy remains hidden
            var enemy_base_bottom_res = catch_land_y;
            // During resolve/caught, smoothly lerp the remaining tiny scale toward zero and keep center at anchor
            var res_phase_progress = 1;
            if (variable_struct_exists(catchA, "phase_progress")) res_phase_progress = real(catchA.phase_progress);
            // Use a small ease to finish the shrink
            var res_ease = sin(res_phase_progress * pi);
            // Reduce scale to near zero
            drawScaleE *= lerp(0, 0, res_ease); // effectively zero but keeps timing consistent
            // Ensure the center is anchored at the landing spot
            var anchor_x2 = (variable_struct_exists(catchA, "land_x") ? variable_struct_get(catchA, "land_x") : catch_land_x);
            var anchor_y2 = (variable_struct_exists(catchA, "land_y") ? variable_struct_get(catchA, "land_y") : enemy_base_bottom_res);
            fx = anchor_x2;
            fy = anchor_y2;
            ball_to_draw = {spr: (is_undefined(catchA.ball_sprite) ? undefined : catchA.ball_sprite), x: fx, y: enemy_base_bottom_res, scale: 0.65};
            enemy_alpha = 0;
            anchor_overridden = true;
        } else if (phase == "escape"){
            var e4 = now - (variable_struct_exists(catchA, "phase_start") ? catchA.phase_start : now);
            var t4 = clamp(e4 / escape_dur, 0, 1);
            // grow enemy back to normal from the near-zero hidden state
            // grow enemy back to normal from fully hidden (0 -> 1)
            drawScaleE *= lerp(0, 1, t4);
            // ball stays near the bottom while it fades and slightly drifts
            var enemy_base_bottom_e = catch_land_y;
            var bx4 = (variable_struct_exists(catchA, "land_x") ? variable_struct_get(catchA, "land_x") : catch_land_x);
            var by4 = enemy_base_bottom_e - lerp(0, 24, t4);
            var scaleb = lerp(0.65, 0.45, t4);
            ball_to_draw = {spr: (is_undefined(catchA.ball_sprite) ? undefined : catchA.ball_sprite), x: bx4, y: by4, scale: scaleb, alpha: lerp(1, 0, t4)};
            enemy_alpha = lerp(0, 1, t4);
            anchor_overridden = true;
        }
    }
    // Debug: avoid spamming the console every frame. Only log on phase change or first missing sprite.
    if (catch_affects_enemy){
        var lastp = (variable_struct_exists(catchA, "_dbg_last_phase") ? string(catchA._dbg_last_phase) : "");
        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG){
            if (lastp != string(catchA.phase)){
                if (variable_global_exists("DATA_DEBUG_VERBOSE") && global.DATA_DEBUG_VERBOSE) show_debug_message("[battle][debug] catch draw phase change pid=" + string(_pid) + ", phase=" + string(catchA.phase));
                variable_struct_set(catchA, "_dbg_last_phase", string(catchA.phase));
            }
            if (!(is_struct(ball_to_draw) && !is_undefined(ball_to_draw.spr))){
                var logged_missing = (variable_struct_exists(catchA, "_dbg_missing_logged") ? catchA._dbg_missing_logged : false);
                if (!logged_missing){
                    if (variable_global_exists("DATA_DEBUG_VERBOSE") && global.DATA_DEBUG_VERBOSE) show_debug_message("[battle][debug] catch active but no ball_to_draw or invalid sprite (pid=" + string(_pid) + ", phase=" + string(catchA.phase) + ")");
                    variable_struct_set(catchA, "_dbg_missing_logged", true);
                }
            }
        }
    }
    if (__is_lead_enemy && string(_B.phase) == "intro_enemy" && !__trainer_skip_slide){
        var p = (variable_struct_exists(_B,"phase_progress") ? _B.phase_progress : 0);
        var start_log = 240 + 40;
        var start_px = __bxu(_pid, start_log);
        var target_px = fx - (w*drawScaleE)/2;
        var t = 1 - (1 - p) * (1 - p);
        draw_x = floor(lerp(start_px, target_px, t));
            // If the animation entered 'resolve' (caught) and we still have the state, draw the steady ball
            if (is_struct(catchA) && catchA.active && string(catchA.phase) == "resolve"){
                // show ball centered, no rotation
                ball_to_draw = {spr: (is_undefined(catchA.ball_sprite) ? undefined : catchA.ball_sprite), x: fx, y: fy, scale: 0.8};
                // keep the enemy small so it looks like it remained inside
                drawScaleE *= 0.35;
            }
    }
    // Recompute draw_x/draw_y now that drawScaleE may have been modified by the catch animation
    // (this keeps the sprite centered while scaling instead of shifting left/right)
    // If `intro_enemy` set a custom draw_x we preserve it but still recalc draw_y
    if (!(string(_B.phase) == "intro_enemy")) draw_x = fx - (w*drawScaleE)/2;
    draw_y = fy - (h*drawScaleE)/2;

    // Apply nudge offset after recomputing draw_x so it isn't stomped by later recalcs.
    try {
        if (_nudge_px_e != 0){
            draw_x += _nudge_px_e;
            if (_nudge_finished_e && is_struct(E)) variable_struct_set(E, "_nudge_active", false);
        }
    } catch (e_apply_nudge_e) {}

    if (!anchor_overridden && catch_affects_enemy){
        var catch_phase_anchor = string(catchA.phase);
        if (catch_phase_anchor == "impact" || catch_phase_anchor == "shake" || catch_phase_anchor == "resolve" || catch_phase_anchor == "escape") anchor_overridden = true;
    }
    // anchor handled via sprite origin above; skip legacy anchor adjustment

    var _breath_amp = 0.03;
    var _breath_period = 2000;
    var _bs_e = 1;
    if (!fainting && string(_B.phase) == "command"){
        var _tms = current_time;
        _bs_e = 1 + sin((_tms * 2 * pi) / _breath_period) * _breath_amp;
    }
    // If the foe is frozen, disable the breathing animation so it appears static
    if (_has_freeze) _bs_e = 1;
    // Skip drawing the shadow while the battler is frozen (visual clarity)
    if (!_has_freeze){
        draw_set_color(make_color_rgb(20,20,20));
        draw_set_alpha(0.45 * enemy_alpha);
        var shadow_w_e = floor((w * drawScaleE * _bs_e) * 0.6);
        var shadow_h_e = max(2, floor((w * drawScaleE) * 0.12));
        var shadow_cx_e = floor(draw_x + (w * drawScaleE * _bs_e) * 0.5);
        var shadow_cy_e = 0;
        if (typeof(_is_grounded_e) != "undefined" && !_is_grounded_e){
            shadow_cy_e = floor(base_fy + (h * scale_foe * ui_s) * 0.5 + shadow_h_e * 0.8 + floor(15 * ui_s));
        } else {
            shadow_cy_e = floor(draw_y + (h * drawScaleE) * 0.5 + shadow_h_e * 0.8 + floor(15 * ui_s));
        }
        draw_ellipse(shadow_cx_e - shadow_w_e div 2, shadow_cy_e - shadow_h_e div 2, shadow_cx_e + shadow_w_e div 2, shadow_cy_e + shadow_h_e div 2, false);
        draw_set_alpha(1);
    }
    // Determine if we should hide the enemy sprite for the initial part of a
    // wild intro. Keep the platform visible but prevent drawing the foe sprite
    // or fallback placeholder for a short threshold to avoid a single-frame flash.
    var __hide_sprite_intro_now = false;
    try {
        var __is_trainer_intro_now = (variable_struct_exists(_B, "_trainer_intro") && is_struct(variable_struct_get(_B, "_trainer_intro")));
        if (string(_B.phase) == "intro_enemy" && !__trainer_skip_slide && !__is_trainer_intro_now){
            var __p_now = (variable_struct_exists(_B, "phase_progress") ? real(_B.phase_progress) : 0);
            if (__p_now <= 0.2) __hide_sprite_intro_now = true;
        }
    } catch (e_hide_now) {}

    if (!__hide_sprite_intro_now){
        if (!_spr_missing && sprite_exists(sprE)){
            draw_sprite_ext(sprE, subE, draw_x, draw_y, drawScaleE * _bs_e, drawScaleE, 0, _img_blend_e, enemy_alpha);
        } else {
            // Fallback: draw a simple placeholder so enemy isn't invisible (matches player fallback)
            draw_set_color(make_color_rgb(20,20,20)); draw_set_alpha(0.45 * enemy_alpha);
            var fw = max(8, floor(64 * ui_s * drawScaleE));
            var fh = max(8, floor(64 * ui_s * drawScaleE));
            var cx = draw_x + (w * drawScaleE) * 0.5;
            var cy = draw_y + (h * drawScaleE) * 0.5;
            draw_ellipse(cx - fw/2, cy - fh/2, cx + fw/2, cy + fh/2, false);
            draw_set_alpha(1);
            draw_set_color(c_white);
                if (enemy_alpha > 0){
                var name_txt = (is_struct(E) && variable_struct_exists(E, "name") ? string(variable_struct_get(E, "name")) : (is_struct(mE) && variable_struct_exists(mE, "name") ? string(variable_struct_get(mE, "name")) : "Enemy"));
                draw_text(cx - fw/2, cy - fh/2 - __bhu(_pid,6), name_txt);
            }
        }
    }

    // Prepare ball overlay info into the catch animation so it can be drawn later on top of UI
    if (!is_undefined(ball_to_draw) && !is_undefined(ball_to_draw.spr) && sprite_exists(ball_to_draw.spr)){
        var fr = 0;
        if (variable_struct_exists(ball_to_draw, "frame")) fr = variable_struct_get(ball_to_draw, "frame");
        var bs = ball_to_draw.spr;
        var bsw = sprite_get_width(bs);
        var bsh = sprite_get_height(bs);
        var origin_x = sprite_get_xoffset(bs);
        var origin_y = sprite_get_yoffset(bs);
        var bscale_ui = ball_to_draw.scale * ui_s;
        var cx_off = (bsw * 0.5 - origin_x) * bscale_ui;
        var cy_off = (bsh - origin_y) * bscale_ui;
        var rot = 0;
        var alpha = (variable_struct_exists(ball_to_draw, "alpha") ? real(ball_to_draw.alpha) : 1);
        var th = rot * pi / 180;
        var rx = cx_off * cos(th) - cy_off * sin(th);
        var ry = cx_off * sin(th) + cy_off * cos(th);
        var bx_draw = ball_to_draw.x - rx;
        var by_draw = ball_to_draw.y - ry;
        var base_x = (variable_struct_exists(catchA, "land_x") ? variable_struct_get(catchA, "land_x") : catch_land_x);
        var base_y = (variable_struct_exists(catchA, "land_y") ? variable_struct_get(catchA, "land_y") : catch_land_y);
        var shadow_y = catch_shadow_center_y;
        var hop_est = max(16, floor((h * ui_s) * 0.18));
        var store = {
            spr: bs,
            frame: fr,
            bx: bx_draw,
            by: by_draw,
            scale: ball_to_draw.scale,
            alpha: alpha,
            base_x: base_x,
            base_y: base_y,
            shadow_y: shadow_y,
            bsw: bsw,
            bsh: bsh,
            ui_s: ui_s,
            hop_est: hop_est,
            contact_x: ball_to_draw.x,
            contact_y: ball_to_draw.y
        };
        variable_struct_set(catchA, "_ball_to_draw", store);
    if (variable_global_exists("DATA_DEBUG_VERBOSE") && global.DATA_DEBUG_VERBOSE) show_debug_message("[battle][debug] prepared ball overlay pid=" + string(_pid) + ", x=" + string(bx_draw) + ", y=" + string(by_draw));
    }
}

// Draw the prepared ball overlay (shadow + ball) on top of UI
function __battle_draw_ball_overlay(_pid, _B){
    if (is_undefined(_B)) return;
    if (!variable_struct_exists(_B, "_catch_anim")) return;
    var catchA = variable_struct_get(_B, "_catch_anim");
    if (is_undefined(catchA)) return;
    if (!variable_struct_exists(catchA, "_ball_to_draw")) return;
    var bd = variable_struct_get(catchA, "_ball_to_draw");
    if (is_undefined(bd) || !variable_struct_exists(bd, "spr")) return;
    var bs = bd.spr;
    var _ball_sprite_exists = (!is_undefined(bs) && sprite_exists(bs));
    var fr = bd.frame;
    var bx_draw = bd.bx;
    var by_draw = bd.by;
    var alpha = bd.alpha;
    var scale = bd.scale;
    var base_x = bd.base_x;
    var base_y = bd.base_y;
    var bsw = bd.bsw;
    var contact_y = (variable_struct_exists(bd, "contact_y") ? bd.contact_y : base_y);
    var shadow_y = (variable_struct_exists(bd, "shadow_y") ? bd.shadow_y : base_y);
    // Shadow: bring it up 2 pixels as requested. Use stored ui_s/hop_est so we don't rely on outer locals.
    var _u = (variable_struct_exists(bd, "ui_s") ? bd.ui_s : 1);
    var _hop_est_local = (variable_struct_exists(bd, "hop_est") ? bd.hop_est : 16);
    var _shadow_base_y = shadow_y;
    var _hop_height_est = _hop_est_local;
    var _dist = max(0, (_shadow_base_y - contact_y));
    var _shadow_alpha = clamp(1 - (_dist / (_hop_height_est * 1.5)), 0, 1) * alpha;
    var _sw = (bsw * scale * _u) * 0.6;
    var _sh = max(2, _sw * 0.18);
    var _cx = base_x;
    var _cy = _shadow_base_y;
    draw_set_color(c_black);
    draw_set_alpha(_shadow_alpha * 0.8);
    draw_ellipse(_cx - _sw / 2, _cy - _sh / 2, _cx + _sw / 2, _cy + _sh / 2, false);
    draw_set_alpha(1);
    // Draw the ball sprite (or a circular placeholder if sprite missing)
    if (_ball_sprite_exists){
        draw_sprite_ext(bs, fr, bx_draw, by_draw, scale * _u, scale * _u, 0, c_white, alpha);
    } else {
        // compute a visual size and center for the placeholder
        var raw_bsw = (variable_struct_exists(bd, "bsw") ? bd.bsw : 16);
        var vis_w = max(8, floor(raw_bsw * scale * _u));
        var cx = bx_draw + vis_w * 0.5;
        var cy = by_draw + vis_w * 0.5;
        draw_set_color(c_white);
        draw_set_alpha(alpha);
        draw_ellipse(cx - vis_w/2, cy - vis_w/2, cx + vis_w/2, cy + vis_w/2, false);
        draw_set_alpha(1);
    }
}

function __battle_player_intro_segment(_pid, _B, _actorIndex){
    var _count = 1;
    if (is_struct(_B) && variable_struct_exists(_B, "battle_format") && string(variable_struct_get(_B, "battle_format")) == "double") _count = 2;
    var _view_intro = __battle_actor_view_side_slot(_pid, _actorIndex);
    var _slot = clamp((is_struct(_view_intro) && variable_struct_exists(_view_intro, "slot")) ? variable_struct_get(_view_intro, "slot") : __battle_actor_slot(_actorIndex), 0, _count - 1);
    var _span = 1 / max(1, _count);
    return {
        count: _count,
        slot: _slot,
        start: _slot * _span,
        finish: (_slot + 1) * _span
    };
}

function __battle_player_intro_anim_sprite(_pid, _B, _actorIndex){
    var _owner_pid = (!is_undefined(__battle_actor_control_pid) ? __battle_actor_control_pid(_pid, _actorIndex) : 0);
    if (!is_real(_owner_pid) || _owner_pid < 0) _owner_pid = 0;
    if (!is_undefined(player_by_pid)){
        var _owner_inst = player_by_pid(_owner_pid);
        if (_owner_inst != noone && variable_instance_exists(_owner_inst, "battleAnim")){
            var _owner_anim = variable_instance_get(_owner_inst, "battleAnim");
            if (is_real(_owner_anim) && sprite_exists(_owner_anim)) return _owner_anim;
        }
    }
    if (variable_struct_exists(_B, "caller_battleAnim") && !is_undefined(variable_struct_get(_B, "caller_battleAnim")) && sprite_exists(variable_struct_get(_B, "caller_battleAnim"))) return variable_struct_get(_B, "caller_battleAnim");
    if (variable_global_exists("battleAnim") && sprite_exists(global.battleAnim)) return global.battleAnim;
    return undefined;
}

function __battle_draw_player(_pid, _B, _actorIndex, mx, my, tx, ty, _skip_platform){
    var scale_us = 1.1;
    var P = undefined;
    if (is_array(_B.actor) && _actorIndex >= 0 && _actorIndex < array_length(_B.actor)) P = _B.actor[_actorIndex];
    if (!is_struct(P) || !variable_struct_exists(P, "mon")) return;
    if (is_undefined(pkicons_get_art96_by_mon) || is_undefined(pkicons_get_art96_subimg_by_mon)) return;
    var mP = variable_struct_get(P, "mon");
    var _player_name = (variable_struct_exists(P, "name") ? string(variable_struct_get(P, "name")) : "Pokemon");
    var sprP = pkicons_get_art96_by_mon(mP);
    var subP = pkicons_get_art96_subimg_by_mon(mP, true);
    var player_fallback_sprite = undefined;
    if (variable_global_exists("spr_mon_placeholder")) player_fallback_sprite = global.spr_mon_placeholder;
    if (is_undefined(player_fallback_sprite) || !sprite_exists(player_fallback_sprite)){
        try {
            var _ph_try = asset_get_index("spr_mon_placeholder");
            if (!is_undefined(_ph_try) && sprite_exists(_ph_try)) player_fallback_sprite = _ph_try;
        } catch (e_ph_player) { player_fallback_sprite = undefined; }
    }
    var player_has_sprite = sprite_exists(sprP);
    var w = player_has_sprite ? sprite_get_width(sprP) : (sprite_exists(player_fallback_sprite) ? sprite_get_width(player_fallback_sprite) : 64);
    var h = player_has_sprite ? sprite_get_height(sprP) : (sprite_exists(player_fallback_sprite) ? sprite_get_height(player_fallback_sprite) : 64);
    var ui_s = 1;
    try {
        var __Bsl2 = __battle_ensure_slot(_pid);
        if (is_struct(__Bsl2) && variable_struct_exists(__Bsl2, "_ui")){
            var __ui2 = variable_struct_get(__Bsl2, "_ui");
            if (is_struct(__ui2) && variable_struct_exists(__ui2, "s")) ui_s = variable_struct_get(__ui2, "s");
        }
    } catch (e_ui2) { ui_s = 1; }
    var _player_layout = __battle_get_actor_scene_anchor(_pid, _B, _actorIndex);
    var _player_scale_mult = (is_struct(_player_layout) && variable_struct_exists(_player_layout, "scale_mult") && is_real(variable_struct_get(_player_layout, "scale_mult"))) ? real(variable_struct_get(_player_layout, "scale_mult")) : 1;
    var drawScaleP = scale_us * _player_scale_mult * ui_s;
    var _player_phase = string(_B.phase);
    var _player_intro_seg = __battle_player_intro_segment(_pid, _B, _actorIndex);
    var _suppress_player_platform = (_player_phase == "intro_call");
    if (is_undefined(_skip_platform)) _skip_platform = false;
    // Freeze detection for player (affects breathing and tint)
    var _has_freeze_p = false;
    try { _has_freeze_p = status_system_has_status(P, "freeze"); } catch (e_hf_p) { _has_freeze_p = false; }
    var _just_cured_p = (variable_struct_exists(P, "_freeze_just_cured_ms") ? variable_struct_get(P, "_freeze_just_cured_ms") : undefined);
    var _img_blend_p = c_white;
    if (_has_freeze_p) _img_blend_p = make_color_rgb(120,160,255);
    var platform_bottom_player = my + (h * drawScaleP) * 0.5;
    if (!_skip_platform && !_suppress_player_platform) __battle_draw_platform(_pid, _B, "player", mx, platform_bottom_player, ui_s);
    var cry_started_p = (variable_struct_exists(_B, "_cry_play_start_ms_player") && is_real(_B._cry_play_start_ms_player)) ? real(_B._cry_play_start_ms_player) : -1;
    if (cry_started_p > 0){
        var tnow_p = current_time;
        var dt_p = tnow_p - cry_started_p;
        var grow_dur_p = 600;
        if (dt_p >= 0 && dt_p <= grow_dur_p){
            var prog_p = dt_p / grow_dur_p;
            var ease_p = sin(prog_p * pi);
            var growp = 1 + ease_p * 0.06;
            drawScaleP *= growp;
        }
    }

    // Use sprite origin so player sprites of different sizes align correctly
    var origin_x_p = player_has_sprite ? sprite_get_xoffset(sprP) : (w * 0.5);
    var origin_y_p = player_has_sprite ? sprite_get_yoffset(sprP) : (h * 0.88);
    // Adjust player origin area based on species height to keep alignment with platform/shadow
    var species_height_m_p = undefined;
    var species_adj_px_p = 0;
    var _resolved_sid_p = undefined;
    if (variable_struct_exists(mP, "species_id")) _resolved_sid_p = variable_struct_get(mP, "species_id");
    else if (variable_struct_exists(mP, "species")) _resolved_sid_p = variable_struct_get(mP, "species");
    if (is_real(_resolved_sid_p) && variable_global_exists("_pokemon") && is_array(global._pokemon)){
        var _sid_h_p = floor(_resolved_sid_p);
        if (is_real(_sid_h_p) && _sid_h_p >= 0 && _sid_h_p < array_length(global._pokemon)){
            var _sp_hp = global._pokemon[_sid_h_p];
            if (is_struct(_sp_hp) && variable_struct_exists(_sp_hp, "height")){
                var _height_dm_p = real(variable_struct_get(_sp_hp, "height"));
                var _height_m_p = _height_dm_p * 0.1;
                species_height_m_p = _height_m_p;
                var minH_p = 0.15; var maxH_p = 3.0;
                var norm_p = clamp((_height_m_p - minH_p) / max(0.0001, (maxH_p - minH_p)), 0, 1);
                // player nudges are smaller to avoid shifting UI overlays
                var adj_px_p = lerp(0.14 * h, -0.02 * h, norm_p);
                var extra_nudge_p = floor(lerp(3, 0, norm_p));
                species_adj_px_p = floor(adj_px_p) + extra_nudge_p;
                origin_y_p = clamp(origin_y_p + species_adj_px_p, 0, h);
            }
        }
    }
    var draw_x = mx + (origin_x_p - (w * 0.5)) * drawScaleP;
    // Anchor player sprite bottom to the player's platform bottom to avoid half-height offset
    var draw_y = platform_bottom_player - (h - origin_y_p) * drawScaleP;
    // Float flying-type players slightly above ground
    try {
        var _is_grounded_p = true;
        if (!is_undefined(__actor_is_grounded)) _is_grounded_p = __actor_is_grounded(P);
        // If grounded check reports true, try a species-level fallback for Flying type / Levitate
        if (_is_grounded_p){
            try {
                var _flying_id_chk = undefined;
                if (variable_global_exists("TYPE_ID_BY_NAME")){
                    var _tmap_chk = variable_global_get("TYPE_ID_BY_NAME");
                    if (ds_exists(_tmap_chk, ds_type_map)) _flying_id_chk = ds_map_find_value(_tmap_chk, string_lower("flying"));
                }
                if (!is_undefined(_flying_id_chk) && is_real(_flying_id_chk)){
                    // actor-level explicit types
                    if (variable_struct_exists(P, "types") && is_array(variable_struct_get(P, "types"))){ var _pta = variable_struct_get(P, "types"); for (var _tti2=0; _tti2<array_length(_pta); ++_tti2) if (is_real(_pta[_tti2]) && _pta[_tti2] == _flying_id_chk) { _is_grounded_p = false; break; } }
                    if (_is_grounded_p && variable_struct_exists(P, "type1") && is_real(variable_struct_get(P, "type1")) && variable_struct_get(P, "type1") == _flying_id_chk) _is_grounded_p = false;
                    if (_is_grounded_p && variable_struct_exists(P, "type2") && is_real(variable_struct_get(P, "type2")) && variable_struct_get(P, "type2") == _flying_id_chk) _is_grounded_p = false;
                    // also check inner mon struct (mP) for types
                    if (_is_grounded_p && is_struct(mP)){
                        if (variable_struct_exists(mP, "types") && is_array(variable_struct_get(mP, "types"))){ var _mpta2 = variable_struct_get(mP, "types"); for (var _ii=0; _ii<array_length(_mpta2); ++_ii) if (is_real(_mpta2[_ii]) && _mpta2[_ii] == _flying_id_chk) { _is_grounded_p = false; break; } }
                        if (_is_grounded_p && variable_struct_exists(mP, "type1") && is_real(variable_struct_get(mP, "type1")) && variable_struct_get(mP, "type1") == _flying_id_chk) _is_grounded_p = false;
                        if (_is_grounded_p && variable_struct_exists(mP, "type2") && is_real(variable_struct_get(mP, "type2")) && variable_struct_get(mP, "type2") == _flying_id_chk) _is_grounded_p = false;
                    }
                    // species-level lookup (support legacy `species` field in mon struct)
                    if (_is_grounded_p && variable_struct_exists(P, "mon") && is_struct(variable_struct_get(P, "mon")) && variable_global_exists("_species_types") && is_array(global._species_types)){
                        var _mref = variable_struct_get(P, "mon");
                        var _resolved_sid_mref_p = undefined;
                        if (variable_struct_exists(_mref, "species_id")) _resolved_sid_mref_p = variable_struct_get(_mref, "species_id");
                        else if (variable_struct_exists(_mref, "species")) _resolved_sid_mref_p = variable_struct_get(_mref, "species");
                        if (is_real(_resolved_sid_mref_p)){
                            var _sidchk = floor(_resolved_sid_mref_p);
                            if (_sidchk >= 0 && _sidchk < array_length(global._species_types)){
                                var _starr2 = global._species_types[_sidchk];
                                if (is_array(_starr2)) for (var _jj2=0; _jj2<array_length(_starr2); ++_jj2) if (is_real(_starr2[_jj2]) && _starr2[_jj2] == _flying_id_chk) { _is_grounded_p = false; break; }
                            }
                        }
                    }
                }
            } catch (e_flychk_p) {}
        }
        if (!_is_grounded_p){
            var _float_px_p = __bhu(_pid, 18);
            draw_y -= _float_px_p;
        }
    } catch (e_fp) {}

    // Draw frozen-state sprite behind the player battler when applicable.
    try {
        if (sprite_exists(spr_frozen)){
            // Fade-out on cure instead of shrinking: keep scale, animate alpha
            var _freeze_scale_p = drawScaleP;
            var _alpha_p = 1;
            if (is_real(_just_cured_p)){
                var _dtp = current_time - _just_cured_p;
                var _durp = 700;
                var _progp = clamp(_dtp / max(1, _durp), 0, 1);
                _alpha_p = lerp(1, 0, _progp);
                if (_progp >= 1){ try { variable_struct_set(P, "_freeze_just_cured_ms", undefined); } catch (e_c_p) {} }
            } else if (!_has_freeze_p){
                _alpha_p = 0;
            }
            if (_alpha_p > 0.001){
                var _spr_x_p = mx - 45 * ui_s;
                var _spr_y_p = my - 45 * ui_s;
                draw_sprite_ext(spr_frozen, 0, _spr_x_p, _spr_y_p, _freeze_scale_p, _freeze_scale_p, 0, c_white, _alpha_p);
                // debug logging disabled: removed noisy per-frame freeze draw messages for player
            }
        }
    } catch (e_fdp) {}

    // Apply temporary nudge offsets (attacker/defender may be moved by effects)
    try {
        if (is_struct(P) && variable_struct_exists(P, "_nudge_active") && variable_struct_get(P, "_nudge_active") == true){
            var _ns_p = variable_struct_get(P, "_nudge_start_ms");
            var _nd_p = variable_struct_get(P, "_nudge_dur");
            var _nm_p = variable_struct_get(P, "_nudge_mag");
            var _ndir_p = variable_struct_get(P, "_nudge_dir");
            var _now_p = current_time;
            var _p_n_p = clamp((_now_p - _ns_p) / max(1, _nd_p), 0, 1);
            var _frac_n_p = (_p_n_p <= 0.5) ? (1 - power(1 - (_p_n_p / 0.5), 2)) : (1 - power(((_p_n_p - 0.5) / 0.5), 2));
            var _offset_px_p = __battle_anim_queue_wu(_pid, _nm_p) * (_ndir_p) * _frac_n_p;
            draw_x += _offset_px_p;
            if (_p_n_p >= 1){ variable_struct_set(P, "_nudge_active", false); }
        }
    } catch (e_nudge_p) {}

    if (string(_B.phase) == "intro_call"){
        var _is_local_versus_trainer_intro = false;
        try {
            _is_local_versus_trainer_intro = (!is_undefined(__battle_is_local_versus_slot) && __battle_is_local_versus_slot(_B)
                && variable_struct_exists(_B, "_trainer_intro") && is_struct(variable_struct_get(_B, "_trainer_intro")));
        } catch (e_local_versus_intro) { _is_local_versus_trainer_intro = false; }
        if (_is_local_versus_trainer_intro) return;
        var p2 = (variable_struct_exists(_B,"phase_progress") ? _B.phase_progress : 0);
        if (p2 < variable_struct_get(_player_intro_seg, "start") || p2 >= variable_struct_get(_player_intro_seg, "finish")) return;
        var _seg_prog_call = clamp((p2 - variable_struct_get(_player_intro_seg, "start")) / max(0.001, variable_struct_get(_player_intro_seg, "finish") - variable_struct_get(_player_intro_seg, "start")), 0, 1);
        var slide_frac = 0.35;
        var start_log = -40;
        var start_px = __bxu(_pid, start_log);
        var target_px = tx;
        var trainer_x_px = (_seg_prog_call < slide_frac) ? floor(lerp(start_px, target_px, 1 - (1 - (_seg_prog_call / slide_frac)) * (1 - (_seg_prog_call / slide_frac)))) : tx;

        var _phase = string(_B.phase);
        var _anim_phase_allowed = (_phase == "intro_call" || _phase == "switch_in");
        var _player_intro_anim = __battle_player_intro_anim_sprite(_pid, _B, _actorIndex);
        if (_anim_phase_allowed && !is_undefined(_player_intro_anim) && sprite_exists(_player_intro_anim)){
            var bs = _player_intro_anim;
            var frames = max(1, sprite_get_number(bs));
            var now_ms = current_time;
            var call_start = (variable_struct_exists(_B, "phase_start_ms") ? _B.phase_start_ms : now_ms);
            var call_dur = max(1, real(_B.phase_durs.call));
            var hold_ms = 0;
            if (variable_struct_exists(_B, "phase_holds") && variable_struct_exists(_B.phase_holds, "call")) hold_ms = max(0, real(_B.phase_holds.call));
            var segment_ms = max(1, floor(call_dur / max(1, variable_struct_get(_player_intro_seg, "count"))));
            var slide_ms = floor(segment_ms * slide_frac);
            var anim_ms = segment_ms - slide_ms;
            var elapsed_ms = clamp((now_ms - call_start) - floor(variable_struct_get(_player_intro_seg, "slot") * segment_ms), 0, segment_ms + hold_ms);

            var draw_frame = 0;
            if (elapsed_ms < slide_ms){ draw_frame = 0; }
            else if (elapsed_ms < slide_ms + anim_ms){
                var anim_elapsed = elapsed_ms - slide_ms;
                if (frames <= 1){ draw_frame = 0; }
                else {
                    var prog = clamp(anim_elapsed / max(1, anim_ms), 0, 0.999999);
                    draw_frame = floor(prog * frames);
                    if (draw_frame >= frames) draw_frame = frames - 1;
                }
            } else if (elapsed_ms < slide_ms + anim_ms + hold_ms){ draw_frame = max(0, frames - 1); }
            else { draw_frame = max(0, frames - 1); }

            var bx = trainer_x_px - (sprite_get_width(bs)*ui_s)/2;
            var by = ty - (sprite_get_height(bs)*ui_s)/2;
            draw_sprite_ext(bs, draw_frame, bx, by, ui_s, ui_s, 0, c_white, 1);
        }
        return;
    }

    if (string(_B.phase) == "intro_player"){
        var p3 = (variable_struct_exists(_B,"phase_progress") ? _B.phase_progress : 0);
        if (p3 < variable_struct_get(_player_intro_seg, "start")) return;
        var _seg_prog_player = clamp((p3 - variable_struct_get(_player_intro_seg, "start")) / max(0.001, variable_struct_get(_player_intro_seg, "finish") - variable_struct_get(_player_intro_seg, "start")), 0, 1);
        var throw_split = 0.58;
        var throw_prog_p = clamp(_seg_prog_player / throw_split, 0, 1);
        var reveal_prog_p = clamp((_seg_prog_player - throw_split) / max(0.001, 1 - throw_split), 0, 1);
        var t3 = 1 - (1 - reveal_prog_p) * (1 - reveal_prog_p);
        var minScale = 0.55;
        var targetScale = drawScaleP;
        var curScale = (_seg_prog_player < throw_split) ? 0 : lerp(minScale * ui_s, targetScale, t3);
        // Position intro using the same origin/platform math as normal draw
        var draw_x2 = mx + (origin_x_p - (w * 0.5)) * curScale;
        var platform_bottom_intro = platform_bottom_player;
        var draw_y2 = platform_bottom_intro - (h - origin_y_p) * curScale;
        var ball_origin_x = tx + __bwu(_pid, 8);
        var ball_origin_y = ty - __bhu(_pid, 20);
        var ball_target_x = mx;
        var ball_target_y = my - __bhu(_pid, 10);
        var ball_alpha_intro = (p3 < throw_split) ? 1 : max(0, 1 - reveal_prog_p);
        __battle_draw_player_throw_overlay(_pid, throw_prog_p, ball_origin_x, ball_origin_y, ball_target_x, ball_target_y, mP, ui_s, ball_alpha_intro);
        // Don't draw the player shadow while frozen
        if (!_has_freeze_p && curScale > 0.001){
            draw_set_color(make_color_rgb(20,20,20));
            draw_set_alpha(0.45);
            var shadow_w_p = floor((w * curScale) * 0.6);
            var shadow_h_p = max(2, floor((w * curScale) * 0.12));
            var shadow_cx_p = floor(draw_x2 + (w * curScale) * 0.5);
            var shadow_cy_p = floor(platform_bottom_intro + shadow_h_p * 0.8 + floor(15 * ui_s));
            draw_ellipse(shadow_cx_p - shadow_w_p div 2, shadow_cy_p - shadow_h_p div 2, shadow_cx_p + shadow_w_p div 2, shadow_cy_p + shadow_h_p div 2, false);
            draw_set_alpha(1);
        }
    if (curScale > 0.001 && player_has_sprite) draw_sprite_ext(sprP, subP, draw_x2, draw_y2, curScale, curScale, 0, _img_blend_p, 1);
        else {
            if (curScale <= 0.001) return;
            // Fallback: draw a simple placeholder so player isn't invisible
            if (!is_undefined(player_fallback_sprite) && sprite_exists(player_fallback_sprite)){
                draw_sprite_ext(player_fallback_sprite, 0, draw_x2, draw_y2, curScale, curScale, 0, c_white, 1);
            } else {
                draw_set_color(make_color_rgb(20,20,20)); draw_set_alpha(0.45);
                var fw = max(8, floor(w * curScale));
                var fh = max(8, floor(h * curScale));
                draw_ellipse(mx - fw/2, my - fh/2, mx + fw/2, my + fh/2, false);
                draw_set_alpha(1);
                draw_set_color(c_white);
                draw_text(mx - fw/2, my - fh/2 - __bhu(_pid,6), _player_name);
            }
        }
        return;
    } else if (string(_B.phase) == "command" || string(_B.phase) == "turn"){
        var _breath_amp_p = 0.03;
        var _breath_period_p = 2000;
        var _bs_p = 1;
        if (string(_B.phase) == "command"){
            var _tms_p = current_time;
            var _offset = floor(_breath_period_p / 2);
            _bs_p = 1 + sin(((_tms_p + _offset) * 2 * pi) / _breath_period_p) * _breath_amp_p;
        }
        // Disable breathing while frozen
        if (_has_freeze_p) _bs_p = 1;
        // Don't draw the player shadow while frozen
        if (!_has_freeze_p){
            draw_set_color(make_color_rgb(20,20,20));
            draw_set_alpha(0.45);
            var shadow_w_p2 = floor((w * drawScaleP * _bs_p) * 0.6);
            var shadow_h_p2 = max(2, floor((w * drawScaleP) * 0.12));
            var shadow_cx_p2 = floor(draw_x + (w * drawScaleP * _bs_p) * 0.5);
            var shadow_cy_p2 = 0;
            if (typeof(_is_grounded_p) != "undefined" && !_is_grounded_p){
                shadow_cy_p2 = floor(platform_bottom_player + (h * drawScaleP) * 0.5 + shadow_h_p2 * 0.8 + floor(15 * ui_s));
            } else {
                shadow_cy_p2 = floor(draw_y + (h * drawScaleP) * 0.5 + shadow_h_p2 * 0.8 + floor(15 * ui_s));
            }
            draw_ellipse(shadow_cx_p2 - shadow_w_p2 div 2, shadow_cy_p2 - shadow_h_p2 div 2, shadow_cx_p2 + shadow_w_p2 div 2, shadow_cy_p2 + shadow_h_p2 div 2, false);
            draw_set_alpha(1);
        }
    if (player_has_sprite) draw_sprite_ext(sprP, subP, draw_x, draw_y, drawScaleP * _bs_p, drawScaleP, 0, _img_blend_p, 1);
        else {
            // Fallback while idle/command
            if (!is_undefined(player_fallback_sprite) && sprite_exists(player_fallback_sprite)){
                draw_sprite_ext(player_fallback_sprite, 0, draw_x, draw_y, drawScaleP * _bs_p, drawScaleP, 0, c_white, 1);
            } else {
                draw_set_color(make_color_rgb(20,20,20)); draw_set_alpha(0.45);
                var fw2 = max(8, floor(w * drawScaleP * _bs_p));
                var fh2 = max(8, floor(h * drawScaleP));
                draw_ellipse(mx - fw2/2, my - fh2/2, mx + fw2/2, my + fh2/2, false);
                draw_set_alpha(1);
                draw_set_color(c_white);
                draw_text(mx - fw2/2, my - fh2/2 - __bhu(_pid,6), _player_name);
            }
        }
    }

    // switch_in visuals
    var _view_switch = __battle_actor_view_side_slot(_pid, _actorIndex);
    var _switch_slot = (is_struct(_view_switch) && variable_struct_exists(_view_switch, "slot")) ? variable_struct_get(_view_switch, "slot") : __battle_actor_slot(_actorIndex);
    if (_switch_slot == 0 && string(_B.phase) == "switch_in"){
        var prog = (variable_struct_exists(_B, "phase_progress") ? _B.phase_progress : 0);
        var out_prog = min(1, prog * 2);
        var in_prog = max(0, (prog - 0.5) * 2);
        var in_throw_split = 0.58;

        var outScale = lerp(drawScaleP, drawScaleP * 0.7, out_prog);
        var in_reveal_prog = clamp((in_prog - in_throw_split) / max(0.001, 1 - in_throw_split), 0, 1);
        var inScale = (in_prog < in_throw_split) ? 0 : lerp(drawScaleP * 0.55, drawScaleP, 1 - power(1 - in_reveal_prog, 2));

        if (prog < 0.5){
            var draw_x_out = mx + (origin_x_p - (w * 0.5)) * outScale;
            var platform_bottom_out = platform_bottom_player;
            var draw_y_out = platform_bottom_out - (h - origin_y_p) * outScale;
            draw_set_color(make_color_rgb(20,20,20)); draw_set_alpha(0.45);
            var sw = floor((w * outScale) * 0.6);
            var sh = max(2, floor((w * outScale) * 0.12));
            var scx = floor(draw_x_out + (w * outScale) * 0.5);
            var scy = floor(platform_bottom_out + sh * 0.8 + floor(15 * ui_s));
            draw_ellipse(scx - sw div 2, scy - sh div 2, scx + sw div 2, scy + sh div 2, false);
            draw_set_alpha(1);
            if (player_has_sprite){
                draw_sprite_ext(sprP, subP, draw_x_out, draw_y_out, outScale, outScale, 0, _img_blend_p, 1);
            } else {
                // Fallback placeholder when sprite missing during switch-out.
                // Prefer drawing the project's placeholder sprite if present.
                var _ph = player_fallback_sprite;
                var _scale_ph = outScale;
                if (!is_undefined(_ph) && sprite_exists(_ph)){
                    var ph_w = sprite_get_width(_ph);
                    var ph_h = sprite_get_height(_ph);
                    var ph_x = mx - (ph_w * _scale_ph) / 2;
                    var ph_y = my - (ph_h * _scale_ph) / 2;
                    draw_sprite_ext(_ph, 0, ph_x, ph_y, _scale_ph, _scale_ph, 0, c_white, 1);
                } else {
                    draw_set_color(make_color_rgb(20,20,20)); draw_set_alpha(0.45);
                    var _fw_o = max(8, floor(64 * ui_s * outScale));
                    var _fh_o = max(8, floor(64 * ui_s * outScale));
                    draw_ellipse(mx - _fw_o/2, my - _fh_o/2, mx + _fw_o/2, my + _fh_o/2, false);
                    draw_set_alpha(1);
                    draw_set_color(c_white);
                    draw_text(mx - _fw_o/2, my - _fh_o/2 - __bhu(_pid,6), _player_name);
                }
            }

        } else {
            var curA = _B.actor[_actorIndex];
            var sprIn = -1, subIn = 0, wIn = 0, hIn = 0;
            if (is_struct(curA) && is_struct(curA.mon) && !is_undefined(pkicons_get_art96_by_mon) && !is_undefined(pkicons_get_art96_subimg_by_mon)){
                sprIn = pkicons_get_art96_by_mon(curA.mon);
                subIn = pkicons_get_art96_subimg_by_mon(curA.mon, true);
                if (sprite_exists(sprIn)){ wIn = sprite_get_width(sprIn); hIn = sprite_get_height(sprIn); }
            }
            var ball_origin_x_sw = tx + __bwu(_pid, 8);
            var ball_origin_y_sw = ty - __bhu(_pid, 20);
            var ball_target_x_sw = mx;
            var ball_target_y_sw = my - __bhu(_pid, 10);
            var throw_prog_sw = clamp(in_prog / in_throw_split, 0, 1);
            var ball_alpha_sw = (in_prog < in_throw_split) ? 1 : max(0, 1 - in_reveal_prog);
            __battle_draw_player_throw_overlay(_pid, throw_prog_sw, ball_origin_x_sw, ball_origin_y_sw, ball_target_x_sw, ball_target_y_sw, curA.mon, ui_s, ball_alpha_sw);

            if (inScale > 0.001){
                var origin_x_in = sprite_exists(sprIn) ? sprite_get_xoffset(sprIn) : (wIn * 0.5);
                var origin_y_in = sprite_exists(sprIn) ? sprite_get_yoffset(sprIn) : (hIn * 0.88);
                var platform_bottom_in = platform_bottom_player;
                var draw_x_in = mx + (origin_x_in - (wIn * 0.5)) * inScale;
                var draw_y_in = platform_bottom_in - (hIn - origin_y_in) * inScale - __bhu(_pid, 8) * (1 - in_reveal_prog);
                draw_set_color(make_color_rgb(20,20,20)); draw_set_alpha(0.45);
                var sw2 = floor((wIn * inScale) * 0.6);
                var sh2 = max(2, floor((wIn * inScale) * 0.12));
                var scx2 = floor(draw_x_in + (wIn * inScale) * 0.5);
                var scy2 = floor(platform_bottom_in + sh2 * 0.8 + floor(15 * ui_s));
                draw_ellipse(scx2 - sw2 div 2, scy2 - sh2 div 2, scx2 + sw2 div 2, scy2 + sh2 div 2, false);
                draw_set_alpha(1);
                if (sprite_exists(sprIn)) draw_sprite_ext(sprIn, subIn, draw_x_in, draw_y_in, inScale, inScale, 0, _img_blend_p, 1);
            }
        }
    }
}
