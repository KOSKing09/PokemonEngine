// battle_animations.gml
// Modular animation helpers for the battle system (catch/throw/shake)
// Provides: __battle_anim_create_catch(_B, _item_id, _caught_struct, _opts)
//           __battle_anim_update(_B)
//           __battle_anim_get_draw_state(_B)

function battle_cam_ensure(_pid_or_slot){
    var _slot = _pid_or_slot;
    if (is_real(_pid_or_slot)) _slot = __battle_ensure_slot(_pid_or_slot);
    if (!is_struct(_slot)) return undefined;
    if (!variable_struct_exists(_slot, "_cam_frame") || !is_struct(variable_struct_get(_slot, "_cam_frame"))){
        variable_struct_set(_slot, "_cam_frame", { offset_x: 0, offset_y: 0, fade_alpha: 0, fade_color: c_black });
    }
    var _cam = variable_struct_get(_slot, "_cam_frame");
    if (!variable_struct_exists(_cam, "offset_x") || !is_real(_cam.offset_x)) _cam.offset_x = 0;
    if (!variable_struct_exists(_cam, "offset_y") || !is_real(_cam.offset_y)) _cam.offset_y = 0;
    if (!variable_struct_exists(_cam, "fade_alpha") || !is_real(_cam.fade_alpha)) _cam.fade_alpha = 0;
    if (!variable_struct_exists(_cam, "fade_color") || !is_real(_cam.fade_color)) _cam.fade_color = c_black;
    if (!variable_struct_exists(_cam, "hold_x") || !is_real(_cam.hold_x)) _cam.hold_x = _cam.offset_x;
    if (!variable_struct_exists(_cam, "hold_y") || !is_real(_cam.hold_y)) _cam.hold_y = _cam.offset_y;

    if (!variable_struct_exists(_cam, "pan_state") || !is_struct(_cam.pan_state)){
        _cam.pan_state = { active: false, start_ms: 0, duration: 0, from_x: _cam.hold_x, from_y: _cam.hold_y, to_x: _cam.hold_x, to_y: _cam.hold_y };
    } else {
        var _pan = _cam.pan_state;
        if (!variable_struct_exists(_pan, "active")) _pan.active = false;
        if (!variable_struct_exists(_pan, "start_ms") || !is_real(_pan.start_ms)) _pan.start_ms = 0;
        if (!variable_struct_exists(_pan, "duration") || !is_real(_pan.duration)) _pan.duration = 0;
        if (!variable_struct_exists(_pan, "from_x") || !is_real(_pan.from_x)) _pan.from_x = _cam.hold_x;
        if (!variable_struct_exists(_pan, "from_y") || !is_real(_pan.from_y)) _pan.from_y = _cam.hold_y;
        if (!variable_struct_exists(_pan, "to_x") || !is_real(_pan.to_x)) _pan.to_x = _cam.hold_x;
        if (!variable_struct_exists(_pan, "to_y") || !is_real(_pan.to_y)) _pan.to_y = _cam.hold_y;
        _cam.pan_state = _pan;
    }

    if (!variable_struct_exists(_cam, "shake_state") || !is_struct(_cam.shake_state)){
        _cam.shake_state = { active: false, start_ms: 0, duration: 0, amplitude: 0, frequency: 16, dampen: 0.9, phase: irandom(720) };
    } else {
        var _shake = _cam.shake_state;
        if (!variable_struct_exists(_shake, "active")) _shake.active = false;
        if (!variable_struct_exists(_shake, "start_ms") || !is_real(_shake.start_ms)) _shake.start_ms = 0;
        if (!variable_struct_exists(_shake, "duration") || !is_real(_shake.duration)) _shake.duration = 0;
        if (!variable_struct_exists(_shake, "amplitude") || !is_real(_shake.amplitude)) _shake.amplitude = 0;
        if (!variable_struct_exists(_shake, "frequency") || !is_real(_shake.frequency)) _shake.frequency = 16;
        if (!variable_struct_exists(_shake, "dampen") || !is_real(_shake.dampen)) _shake.dampen = 0.9;
        if (!variable_struct_exists(_shake, "phase") || !is_real(_shake.phase)) _shake.phase = irandom(720);
        _cam.shake_state = _shake;
    }

    variable_struct_set(_slot, "_cam_frame", _cam);
    return _cam;
}

function battle_cam_update(_pid){
    var _slot = __battle_ensure_slot(_pid);
    if (!is_struct(_slot)) return undefined;
    var _cam = battle_cam_ensure(_slot);
    if (!is_struct(_cam)) return undefined;
    var _now = current_time;

    var _base_x = (variable_struct_exists(_cam, "hold_x") && is_real(_cam.hold_x)) ? _cam.hold_x : 0;
    var _base_y = (variable_struct_exists(_cam, "hold_y") && is_real(_cam.hold_y)) ? _cam.hold_y : 0;

    var _pan = _cam.pan_state;
    if (is_struct(_pan) && _pan.active){
        if (!variable_struct_exists(_pan, "start_ms") || !is_real(_pan.start_ms)) _pan.start_ms = _now;
        if (!variable_struct_exists(_pan, "duration") || !is_real(_pan.duration)) _pan.duration = 240;
        var _dur = max(1, _pan.duration);
        var _t = clamp((_now - _pan.start_ms) / _dur, 0, 1);
        var _ease = 1 - power(1 - _t, 3);
        var _from_x = (variable_struct_exists(_pan, "from_x") && is_real(_pan.from_x)) ? _pan.from_x : _base_x;
        var _from_y = (variable_struct_exists(_pan, "from_y") && is_real(_pan.from_y)) ? _pan.from_y : _base_y;
        var _to_x = (variable_struct_exists(_pan, "to_x") && is_real(_pan.to_x)) ? _pan.to_x : _from_x;
        var _to_y = (variable_struct_exists(_pan, "to_y") && is_real(_pan.to_y)) ? _pan.to_y : _from_y;
        _base_x = _from_x + (_to_x - _from_x) * _ease;
        _base_y = _from_y + (_to_y - _from_y) * _ease;
        if (_t >= 1){
            _base_x = _to_x;
            _base_y = _to_y;
            _pan.active = false;
        }
        _cam.pan_state = _pan;
    }

    var _shake_add_x = 0;
    var _shake_add_y = 0;
    var _shake = _cam.shake_state;
    if (is_struct(_shake) && _shake.active){
        if (!variable_struct_exists(_shake, "start_ms") || !is_real(_shake.start_ms)) _shake.start_ms = _now;
        if (!variable_struct_exists(_shake, "duration") || !is_real(_shake.duration)) _shake.duration = 320;
        var _sdur = max(1, _shake.duration);
        var _elapsed = max(0, _now - _shake.start_ms);
        var _prog = clamp(_elapsed / _sdur, 0, 1);
        var _amp = (variable_struct_exists(_shake, "amplitude") && is_real(_shake.amplitude)) ? _shake.amplitude : 0;
        var _freq = (variable_struct_exists(_shake, "frequency") && is_real(_shake.frequency)) ? max(1, _shake.frequency) : 16;
        var _dampen = (variable_struct_exists(_shake, "dampen") && is_real(_shake.dampen)) ? clamp(_shake.dampen, 0.5, 0.999) : 0.9;
        var _phase = (variable_struct_exists(_shake, "phase") && is_real(_shake.phase)) ? _shake.phase : 0;
        var _cycles = _elapsed / _freq;
        var _decay = power(_dampen, _cycles);
        var _ang = ((_phase / 360) + _cycles) * 2 * pi;
        _shake_add_x = sin(_ang) * _amp * _decay;
        _shake_add_y = cos(_ang) * (_amp * 0.65) * _decay;
        if (_prog >= 1 || _amp <= 0.1){
            _shake.active = false;
            _shake_add_x = 0;
            _shake_add_y = 0;
        }
        _cam.shake_state = _shake;
    }

    _cam.hold_x = _base_x;
    _cam.hold_y = _base_y;
    _cam.offset_x = _base_x + _shake_add_x;
    _cam.offset_y = _base_y + _shake_add_y;

    variable_struct_set(_slot, "_cam_frame", _cam);
    return _cam;
}

function battle_cam_get_draw_state(_pid){
    var _slot = __battle_ensure_slot(_pid);
    if (!is_struct(_slot)) return undefined;
    return battle_cam_ensure(_slot);
}

function battle_cam_pan_to_offset(_pid, _offset_x, _offset_y, _duration){
    var _slot = __battle_ensure_slot(_pid);
    if (!is_struct(_slot)) return false;
    var _cam = battle_cam_ensure(_slot);
    if (!is_struct(_cam)) return false;
    var _pan = _cam.pan_state;
        var _pan = _cam.pan_state;
        if (!is_struct(_pan)) _pan = { active: false, start_ms: 0, duration: 0, from_x: _cam.hold_x, from_y: _cam.hold_y, to_x: _cam.hold_x, to_y: _cam.hold_y };
    _pan.active = true;
    _pan.start_ms = current_time;
    _pan.duration = max(1, is_real(_duration) ? floor(_duration) : 280);
    _pan.from_x = (variable_struct_exists(_cam, "hold_x") && is_real(_cam.hold_x)) ? _cam.hold_x : 0;
    _pan.from_y = (variable_struct_exists(_cam, "hold_y") && is_real(_cam.hold_y)) ? _cam.hold_y : 0;
    _pan.to_x = (is_real(_offset_x) ? _offset_x : 0);
    _pan.to_y = (is_real(_offset_y) ? _offset_y : 0);
    _cam.pan_state = _pan;
    variable_struct_set(_slot, "_cam_frame", _cam);
    return true;
}

function battle_cam_pan_to_side(_pid, _target_index, _magnitude, _duration){
    var _idx = (is_real(_target_index) ? clamp(floor(_target_index), 0, 1) : 0);
    var _mag = (is_real(_magnitude) ? _magnitude : 12);
    var _dir = (_idx == 0) ? 1 : -1;
    return battle_cam_pan_to_offset(_pid, _dir * _mag, 0, _duration);
}

function battle_cam_shake(_pid, _amplitude, _duration, _frequency, _dampen){
    var _slot = __battle_ensure_slot(_pid);
    if (!is_struct(_slot)) return false;
    var _cam = battle_cam_ensure(_slot);
    if (!is_struct(_cam)) return false;
    var _shake = _cam.shake_state;
    if (!is_struct(_shake)) _shake = { active: false, start_ms: 0, duration: 0, amplitude: 0, frequency: 16, dampen: 0.9, phase: irandom(720) };
    _shake.active = true;
    _shake.start_ms = current_time;
    _shake.duration = max(1, is_real(_duration) ? floor(_duration) : 220);
    _shake.amplitude = (is_real(_amplitude) ? _amplitude : 6);
    _shake.frequency = max(1, is_real(_frequency) ? floor(_frequency) : 16);
    _shake.dampen = clamp(is_real(_dampen) ? _dampen : 0.9, 0.5, 0.999);
    _shake.phase = irandom(720);
    _cam.shake_state = _shake;
    variable_struct_set(_slot, "_cam_frame", _cam);
    return true;
}

function __battle_anim_queue_xu(_pid, _xv){
    var _slot = __battle_ensure_slot(_pid);
    if (!is_struct(_slot)) return _xv;
    var _ui = undefined;
    if (variable_struct_exists(_slot, "_ui")) _ui = variable_struct_get(_slot, "_ui");
    if (!is_struct(_ui)) return _xv;
    var _rx = (variable_struct_exists(_ui, "rx") && is_real(variable_struct_get(_ui, "rx"))) ? variable_struct_get(_ui, "rx") : 0;
    var _s = (variable_struct_exists(_ui, "s") && is_real(variable_struct_get(_ui, "s"))) ? variable_struct_get(_ui, "s") : 1;
    return floor(_rx + _xv * _s);
}

function __battle_anim_queue_yu(_pid, _yv){
    var _slot = __battle_ensure_slot(_pid);
    if (!is_struct(_slot)) return _yv;
    var _ui = undefined;
    if (variable_struct_exists(_slot, "_ui")) _ui = variable_struct_get(_slot, "_ui");
    if (!is_struct(_ui)) return _yv;
    var _ry = (variable_struct_exists(_ui, "ry") && is_real(variable_struct_get(_ui, "ry"))) ? variable_struct_get(_ui, "ry") : 0;
    var _s = (variable_struct_exists(_ui, "s") && is_real(variable_struct_get(_ui, "s"))) ? variable_struct_get(_ui, "s") : 1;
    return floor(_ry + _yv * _s);
}

function __battle_anim_queue_wu(_pid, _wv, _fallback = undefined){
    var _slot = __battle_ensure_slot(_pid);
    var _fb = (argument_count > 2 && is_real(_fallback)) ? _fallback : _wv;
    if (!is_struct(_slot)) return _fb;
    var _ui = undefined;
    if (variable_struct_exists(_slot, "_ui")) _ui = variable_struct_get(_slot, "_ui");
    if (!is_struct(_ui)) return _fb;
    var _s = (variable_struct_exists(_ui, "s") && is_real(variable_struct_get(_ui, "s"))) ? variable_struct_get(_ui, "s") : 1;
    return floor(_wv * _s);
}

function __battle_anim_queue_hu(_pid, _hv, _fallback = undefined){
    var _fb = (argument_count > 2 && is_real(_fallback)) ? _fallback : _hv;
    return __battle_anim_queue_wu(_pid, _hv, _fb);
}

function battle_anim_queue_ensure(_pid_or_slot){
    var _slot = _pid_or_slot;
    if (is_real(_pid_or_slot)) _slot = __battle_ensure_slot(_pid_or_slot);
    if (!is_struct(_slot)) return undefined;
    if (!variable_struct_exists(_slot, "_anim_queue") || !is_struct(variable_struct_get(_slot, "_anim_queue"))){
        variable_struct_set(_slot, "_anim_queue", { pending: [], current: undefined, overlays: [], draw_states: [] });
    }
    var _aq = variable_struct_get(_slot, "_anim_queue");
    if (!variable_struct_exists(_aq, "pending") || !is_array(_aq.pending)) _aq.pending = [];
    if (!variable_struct_exists(_aq, "overlays") || !is_array(_aq.overlays)) _aq.overlays = [];
    if (!variable_struct_exists(_aq, "draw_states") || !is_array(_aq.draw_states)) _aq.draw_states = [];
    return _aq;
}

function __battle_anim_queue_find_pid_for_actor(_ref){
    if (is_real(_ref)) return _ref;
    if (!variable_global_exists("sys_battles") || !is_array(global.sys_battles)) return undefined;
    for (var __pi = 0; __pi < array_length(global.sys_battles); ++__pi){
        var __slot = global.sys_battles[__pi];
        if (!is_struct(__slot) || !variable_struct_exists(__slot, "actor")) continue;
        var __actors = variable_struct_get(__slot, "actor");
        if (!is_array(__actors)) continue;
        for (var __ai = 0; __ai < array_length(__actors); ++__ai){
            var __actor = __actors[__ai];
            if (__actor == _ref) return __pi;
            if (is_struct(__actor) && variable_struct_exists(__actor, "mon") && variable_struct_get(__actor, "mon") == _ref) return __pi;
        }
    }
    return undefined;
}

function __battle_anim_queue_default_duration(_type){
    var _t = string(_type);
    switch (_t){
        case "heal":
        case "recoil":
            return 600;
        case "stat_change":
        case "stat_change_group":
            return 720;
        case "stat_overlay":
            return 520;
        case "set_terrain":
        case "clear_terrain":
        case "pledge_combo":
            return 1000;
        case "set_spikes":
        case "set_toxic_spikes":
        case "set_sticky_web":
        case "set_stealth_rock":
            return 980;
        case "weather_tick":
        case "weather_end":
        case "weather_start":
            return 880;
        case "hit_effect":
            return 320;
        default:
            return 640;
    }
}

function __battle_anim_queue_color_for_terrain(_id){
    var _tid = string_lower(string(_id));
    switch (_tid){
        case "electric": return make_color_rgb(250, 210, 82);
        case "grassy": return make_color_rgb(120, 210, 120);
        case "misty": return make_color_rgb(150, 190, 255);
        case "psychic": return make_color_rgb(225, 140, 225);
        case "fire": return make_color_rgb(250, 160, 92);
        case "water": return make_color_rgb(110, 180, 240);
        default: return make_color_rgb(200, 200, 200);
    }
}

function __battle_anim_queue_color_for_hazard(_id){
    var _hid = string_lower(string(_id));
    switch (_hid){
        case "set_spikes": return make_color_rgb(205, 220, 240);
        case "set_toxic_spikes": return make_color_rgb(200, 150, 230);
        case "set_sticky_web": return make_color_rgb(215, 210, 140);
        case "set_stealth_rock": return make_color_rgb(190, 170, 150);
        default: return make_color_rgb(205, 205, 205);
    }

}

function __battle_anim_queue_color_for_weather(_id){
    var _wid = string_lower(string(_id));
    switch (_wid){
        case "rain": return make_color_rgb(120, 170, 240);
        case "sandstorm": return make_color_rgb(210, 185, 130);
        case "hail":
        case "snow": return make_color_rgb(200, 230, 255);
        case "sun": return make_color_rgb(255, 195, 120);
        case "harsh-sun": return make_color_rgb(255, 175, 80);
        case "fog": return make_color_rgb(180, 185, 195);
        default: return make_color_rgb(200, 200, 200);
    }

}

function __battle_anim_queue_resolve_target_index(_slot, _spec){
    if (!is_struct(_spec)) return undefined;
    if (variable_struct_exists(_spec, "target_index") && is_real(variable_struct_get(_spec, "target_index"))) return clamp(floor(variable_struct_get(_spec, "target_index")), 0, 1);
    if (variable_struct_exists(_spec, "actor_index") && is_real(variable_struct_get(_spec, "actor_index"))) return clamp(floor(variable_struct_get(_spec, "actor_index")), 0, 1);
    if (variable_struct_exists(_spec, "target") && is_struct(variable_struct_get(_spec, "target"))){
        var _t = variable_struct_get(_spec, "target");
        if (is_struct(_slot) && variable_struct_exists(_slot, "actor") && is_array(variable_struct_get(_slot, "actor"))){
            var _actors = variable_struct_get(_slot, "actor");
            for (var _ai = 0; _ai < array_length(_actors); ++_ai){
                var _ac = _actors[_ai];
                if (_ac == _t) return _ai;

                if (is_struct(_ac) && variable_struct_exists(_ac, "mon") && variable_struct_get(_ac, "mon") == _t) return _ai;
            }
        }
    }
    if (variable_struct_exists(_spec, "actor") && is_struct(variable_struct_get(_spec, "actor"))){
        var _a = variable_struct_get(_spec, "actor");
        if (variable_struct_exists(_a, "actor_index") && is_real(variable_struct_get(_a, "actor_index"))) return clamp(floor(variable_struct_get(_a, "actor_index")), 0, 1);
    }
    return undefined;
}

function __battle_anim_queue_resolve_side(_slot, _spec){
    var _idx = __battle_anim_queue_resolve_target_index(_slot, _spec);

    if (is_real(_idx)) return (_idx == 0 ? "player" : "enemy");
    if (is_struct(_spec) && variable_struct_exists(_spec, "side")) return string(_spec.side);
    return "full";

}

function __battle_anim_queue_normalize(_slot, _spec){
    if (!is_struct(_spec)) return undefined;
    var _type = string_lower(string(variable_struct_exists(_spec, "type") ? variable_struct_get(_spec, "type") : "generic"));
    var _out = { type: _type, channel: "primary", duration: __battle_anim_queue_default_duration(_type), raw: _spec };

    switch (_type){
        case "stat_change":

            _out.channel = "primary";
            _out.target_index = __battle_anim_queue_resolve_target_index(_slot, _spec);
            var _from = (variable_struct_exists(_spec, "from") && is_real(variable_struct_get(_spec, "from"))) ? variable_struct_get(_spec, "from") : undefined;
            var _to = (variable_struct_exists(_spec, "to") && is_real(variable_struct_get(_spec, "to"))) ? variable_struct_get(_spec, "to") : undefined;
            _out.direction = 0;
            if (is_real(_from) && is_real(_to)) _out.direction = sign(_to - _from);
            _out.stat = (variable_struct_exists(_spec, "stat") ? string(variable_struct_get(_spec, "stat")) : "");
            break;
        case "stat_overlay":
            _out.channel = "overlay";
            _out.target_index = __battle_anim_queue_resolve_target_index(_slot, _spec);
            var _frame_in = (variable_struct_exists(_spec, "frame") && is_real(variable_struct_get(_spec, "frame"))) ? floor(variable_struct_get(_spec, "frame")) : 0;
            if (!is_real(_frame_in) || _frame_in < 0) _frame_in = 0;
            _out.frame = _frame_in;
            _out.darken = (variable_struct_exists(_spec, "darken") && variable_struct_get(_spec, "darken"));
            // propagate optional visual flags from the spec so the draw-state can honor them
            _out.bg = (variable_struct_exists(_spec, "bg") && variable_struct_get(_spec, "bg"));
            if (variable_struct_exists(_spec, "direction")) _out.direction = variable_struct_get(_spec, "direction");
            if (variable_struct_exists(_spec, "bg_loops") && is_real(variable_struct_get(_spec, "bg_loops"))) _out.bg_loops = floor(variable_struct_get(_spec, "bg_loops"));
            if (variable_struct_exists(_spec, "stat_keys")) _out.keys = variable_struct_get(_spec, "stat_keys");
            if (variable_struct_exists(_spec, "stat_deltas")) _out.deltas = variable_struct_get(_spec, "stat_deltas");
            break;
        case "hit_effect":
            // Small targetted hit effect drawn over an actor (uses spr_hiteffect by default)
            _out.channel = "overlay";
            _out.target_index = __battle_anim_queue_resolve_target_index(_slot, _spec);
            _out.sprite = (variable_struct_exists(_spec, "sprite") ? variable_struct_get(_spec, "sprite") : (variable_global_exists("spr_hiteffect") ? spr_hiteffect : undefined));
            _out.scale = (variable_struct_exists(_spec, "scale") && is_real(variable_struct_get(_spec, "scale"))) ? real(variable_struct_get(_spec, "scale")) : 1;
            // Stable random offset within the target to vary hit placement
            var _rx = irandom_range(-12, 12);
            var _ry = irandom_range(-8, 8);
            _out.offset_x = _rx; _out.offset_y = _ry;
            // Slide direction: away from attacker -> target_index - actor_index sign
            var _act_idx = undefined;
            if (variable_struct_exists(_spec, "actor") && is_struct(variable_struct_get(_spec, "actor"))){ try { if (variable_struct_exists(variable_struct_get(_spec, "actor"), "actor_index")) _act_idx = variable_struct_get(variable_struct_get(_spec, "actor"), "actor_index"); } catch (e_ai) { _act_idx = undefined; } }
            var _tidx = _out.target_index;
            var _sdir = 0;
            if (is_real(_act_idx) && is_real(_tidx)) _sdir = sign(_tidx - _act_idx);
            _out.slide_dir = _sdir;
            _out.slide_mag = (variable_struct_exists(_spec, "slide_mag") && is_real(variable_struct_get(_spec, "slide_mag"))) ? variable_struct_get(_spec, "slide_mag") : 8; // logical pixels
            break;
        case "stat_change_group":
        case "heal":
        case "recoil":
        case "guard_split":
        case "imprison":
        case "cure_party":
            _out.channel = "primary";
            _out.target_index = __battle_anim_queue_resolve_target_index(_slot, _spec);
            break;
        case "set_terrain":
        case "clear_terrain":
            _out.channel = "field";

            _out.terrain = string(variable_struct_exists(_spec, "terrain") ? variable_struct_get(_spec, "terrain") : "");
            _out.side = __battle_anim_queue_resolve_side(_slot, _spec);
            _out.color = __battle_anim_queue_color_for_terrain(_out.terrain);
            break;
        case "pledge_combo":
            _out.channel = "field";
            _out.effect = string(variable_struct_exists(_spec, "effect") ? variable_struct_get(_spec, "effect") : "");
            _out.side = "full";
            _out.color = __battle_anim_queue_color_for_terrain(_out.effect);
            break;
        case "set_spikes":
        case "set_toxic_spikes":
        case "set_sticky_web":
        case "set_stealth_rock":
            _out.channel = "field";
            _out.hazard = _type;
            _out.side = __battle_anim_queue_resolve_side(_slot, _spec);
            _out.color = __battle_anim_queue_color_for_hazard(_type);
            break;
        case "weather_tick":
        case "weather_end":
        case "weather_start":
            _out.channel = "weather";
            _out.weather = string(variable_struct_exists(_spec, "id") ? variable_struct_get(_spec, "id") : "");
            _out.color = __battle_anim_queue_color_for_weather(_out.weather);

            break;
        default:
            _out.channel = "primary";
            _out.target_index = __battle_anim_queue_resolve_target_index(_slot, _spec);

            break;
    }
    return _out;

}

function battle_anim_queue_enqueue(_pid_or_slot, _spec){
    if (!is_struct(_spec)) return false;
    var _slot = _pid_or_slot;

    var _pid = undefined;
    if (is_real(_pid_or_slot)){
        _pid = floor(_pid_or_slot);
        _slot = __battle_ensure_slot(_pid);
    }
    if (!is_struct(_slot)) return false;
    var _aq = battle_anim_queue_ensure(_slot);
    if (!is_struct(_aq)) return false;
    var _norm = __battle_anim_queue_normalize(_slot, _spec);
    if (!is_struct(_norm)) return false;
    if (!is_real(_pid)) _pid = __battle_anim_queue_find_pid_for_actor(_slot);
    if (!is_real(_pid)) _pid = 0;
    _norm.pid = _pid;
    var _channel = string(_norm.channel);
    if (_channel == "field" || _channel == "weather" || _channel == "overlay"){
        var _entry = {
            type: _norm.type,
            channel: _channel,
            duration: _norm.duration,

            start_ms: current_time,
            progress: 0,
            target_index: (variable_struct_exists(_norm, "target_index") ? _norm.target_index : undefined),
            direction: (variable_struct_exists(_norm, "direction") ? _norm.direction : undefined),
            stat: (variable_struct_exists(_norm, "stat") ? _norm.stat : undefined),
            terrain: (variable_struct_exists(_norm, "terrain") ? _norm.terrain : undefined),

            hazard: (variable_struct_exists(_norm, "hazard") ? _norm.hazard : undefined),
            effect: (variable_struct_exists(_norm, "effect") ? _norm.effect : undefined),
            color: (variable_struct_exists(_norm, "color") ? _norm.color : undefined),
            side: (variable_struct_exists(_norm, "side") ? _norm.side : "full"),
            weather: (variable_struct_exists(_norm, "weather") ? _norm.weather : undefined),
            frame: (variable_struct_exists(_norm, "frame") ? _norm.frame : undefined),
            darken: (variable_struct_exists(_norm, "darken") ? _norm.darken : undefined),
            bg: (variable_struct_exists(_norm, "bg") ? _norm.bg : undefined),
            bg_loops: (variable_struct_exists(_norm, "bg_loops") ? _norm.bg_loops : undefined),
            stat_keys: (variable_struct_exists(_norm, "keys") ? _norm.keys : undefined),
            stat_deltas: (variable_struct_exists(_norm, "deltas") ? _norm.deltas : undefined)
        };
        array_push(_aq.overlays, _entry);
    } else {
        array_push(_aq.pending, _norm);
    }
    variable_struct_set(_slot, "_anim_queue", _aq);
    return true;
}

function battle_anim_queue_tick(_pid){
    var _slot = __battle_ensure_slot(_pid);
    if (!is_struct(_slot)) return [];
    var _aq = battle_anim_queue_ensure(_slot);
    if (!is_struct(_aq)) return [];

    if (variable_struct_exists(_slot, "_pending_anims") && is_array(variable_struct_get(_slot, "_pending_anims"))){
        var __raw = variable_struct_get(_slot, "_pending_anims");
        if (array_length(__raw) > 0){
            for (var __ri = 0; __ri < array_length(__raw); ++__ri){ battle_anim_queue_enqueue(_pid, __raw[__ri]); }
            variable_struct_set(_slot, "_pending_anims", []);
        }
    }

    var _now = current_time;
    var _states = [];

    var _keep_overlays = [];
    for (var __oi = 0; __oi < array_length(_aq.overlays); ++__oi){
        var _ov = _aq.overlays[__oi];
        if (!is_struct(_ov)) continue;
        if (!variable_struct_exists(_ov, "start_ms")) _ov.start_ms = _now;
        if (!variable_struct_exists(_ov, "duration") || !is_real(_ov.duration)) _ov.duration = __battle_anim_queue_default_duration(_ov.type);
        var _dur = max(1, _ov.duration);
        var _prog = clamp((_now - _ov.start_ms) / _dur, 0, 1);
        _ov.progress = _prog;
        var _ds = __battle_anim_queue_build_draw_state(_pid, _slot, _ov);
        if (is_struct(_ds)) array_push(_states, _ds);
        if (_prog < 1) array_push(_keep_overlays, _ov);
    }
    _aq.overlays = _keep_overlays;

    if (!is_struct(_aq.current) && is_array(_aq.pending) && array_length(_aq.pending) > 0){
        var _next = _aq.pending[0];
        _aq.pending = array_delete(_aq.pending, 0, 1);
        if (is_struct(_next)){
            _next.start_ms = _now;
            if (!variable_struct_exists(_next, "duration") || !is_real(_next.duration)) _next.duration = __battle_anim_queue_default_duration(_next.type);
            _next.progress = 0;
            _aq.current = _next;
            __battle_anim_queue_trigger_camera(_pid, _slot, _next);
        }
    }

    if (is_struct(_aq.current)){
        var _cur = _aq.current;
        if (!variable_struct_exists(_cur, "start_ms")) _cur.start_ms = _now;
        if (!variable_struct_exists(_cur, "duration") || !is_real(_cur.duration)) _cur.duration = __battle_anim_queue_default_duration(_cur.type);
        var _dur_c = max(1, _cur.duration);
        var _prog_c = clamp((_now - _cur.start_ms) / _dur_c, 0, 1);
        _cur.progress = _prog_c;
        var _ds_cur = __battle_anim_queue_build_draw_state(_pid, _slot, _cur);
        if (is_struct(_ds_cur)) array_push(_states, _ds_cur);
        if (_prog_c >= 1) _aq.current = undefined;
        else _aq.current = _cur;
    }

    _aq.draw_states = _states;
    variable_struct_set(_slot, "_anim_queue", _aq);
    return _states;
}

function battle_anim_queue_get_states(_pid){
    var _slot = __battle_ensure_slot(_pid);
    if (!is_struct(_slot)) return [];
    var _aq = battle_anim_queue_ensure(_slot);
    if (!is_struct(_aq)) return [];
    if (!variable_struct_exists(_aq, "draw_states") || !is_array(_aq.draw_states)) return [];
    return _aq.draw_states;
}

function __battle_anim_queue_actor_center(_pid, _idx){
    var _xlog = (_idx == 1 ? 165 : 64);
    var _ylog = (_idx == 1 ? 40 : 112);
    var _cx = __battle_anim_queue_xu(_pid, _xlog);
    var _cy = __battle_anim_queue_yu(_pid, _ylog);
    return [_cx, _cy];
}

function __battle_anim_queue_build_draw_state(_pid, _slot, _entry){
    if (!is_struct(_entry)) return undefined;
    var _type = string(_entry.type);
    var _prog = clamp((variable_struct_exists(_entry, "progress") ? _entry.progress : 0), 0, 1);
    if (_type == "stat_overlay"){
        var _idx_so = (variable_struct_exists(_entry, "target_index") && is_real(_entry.target_index)) ? clamp(_entry.target_index, 0, 1) : 0;
        var _frame_so = (variable_struct_exists(_entry, "frame") && is_real(_entry.frame)) ? clamp(floor(_entry.frame), 0, 7) : 0;
        var _darken_so = (variable_struct_exists(_entry, "darken") && _entry.darken);
        // Include optional fields so draw code can access bg mode, direction and loop count
        var _bg_so = (variable_struct_exists(_entry, "bg") && _entry.bg);
        var _dir_so = (variable_struct_exists(_entry, "direction") && is_real(_entry.direction)) ? _entry.direction : 0;
        var _stat_keys_so = (variable_struct_exists(_entry, "stat_keys") ? _entry.stat_keys : undefined);
        var _stat_deltas_so = (variable_struct_exists(_entry, "stat_deltas") ? _entry.stat_deltas : undefined);
        var _bg_loops_so = (variable_struct_exists(_entry, "bg_loops") && is_real(_entry.bg_loops)) ? max(0, floor(_entry.bg_loops)) : undefined;
        return { kind: "stat_overlay", target_index: _idx_so, frame: _frame_so, darken: _darken_so, progress: _prog, bg: _bg_so, direction: _dir_so, stat_keys: _stat_keys_so, stat_deltas: _stat_deltas_so, bg_loops: _bg_loops_so };
    }
    if (_type == "hit_effect"){
        var _idx_he = (variable_struct_exists(_entry, "target_index") && is_real(_entry.target_index)) ? clamp(_entry.target_index, 0, 1) : 0;
        var _sprite_he = (variable_struct_exists(_entry, "sprite") && !is_undefined(_entry.sprite)) ? _entry.sprite : spr_hiteffect;
        var _spr_count_he = 1;
        try { if (is_undefined(_sprite_he) == false && sprite_exists(_sprite_he)) _spr_count_he = max(1, sprite_get_number(_sprite_he)); } catch (e_sp) { _spr_count_he = 1; }
        var _frame_he = clamp(floor(_prog * _spr_count_he), 0, max(0, _spr_count_he - 1));
        var _scale_he = (variable_struct_exists(_entry, "scale") && is_real(_entry.scale)) ? _entry.scale : 1;
        var _alpha_he = 1 - _prog;
        var _offx_he = (variable_struct_exists(_entry, "offset_x") && is_real(_entry.offset_x)) ? _entry.offset_x : 0;
        var _offy_he = (variable_struct_exists(_entry, "offset_y") && is_real(_entry.offset_y)) ? _entry.offset_y : 0;
        var _sdir_he = (variable_struct_exists(_entry, "slide_dir") && is_real(_entry.slide_dir)) ? clamp(_entry.slide_dir, -1, 1) : 0;
        var _smag_he = (variable_struct_exists(_entry, "slide_mag") && is_real(_entry.slide_mag)) ? _entry.slide_mag : 8;
        return { kind: "sprite_overlay", target_index: _idx_he, sprite: _sprite_he, frame: _frame_he, scale: _scale_he, alpha: _alpha_he, progress: _prog, offset_x: _offx_he, offset_y: _offy_he, slide_dir: _sdir_he, slide_mag: _smag_he };
    }
    if (_type == "stat_change"){
        var _idx = (variable_struct_exists(_entry, "target_index") && is_real(_entry.target_index)) ? clamp(_entry.target_index, 0, 1) : 0;
        var _dir = (variable_struct_exists(_entry, "direction") && is_real(_entry.direction)) ? _entry.direction : 0;
    // Use green for stat increases (was a light blue previously). Keep down as orange.
    var _col_up = make_color_rgb(120, 230, 150); // green (stat raise)
    var _col_down = make_color_rgb(255, 168, 84); // orange (stat lower)
    var _col_neutral = make_color_rgb(220, 220, 220);
        var _col_sc = (_dir > 0 ? _col_up : (_dir < 0 ? _col_down : _col_neutral));
    return { kind: "actor_glow", target_index: _idx, color: _col_sc, alpha: 0.45 * (1 - _prog * 0.65), radius: __battle_anim_queue_wu(_pid, 44), progress: _prog };
    }
    if (_type == "stat_change_group"){
        var _idxg = (variable_struct_exists(_entry, "target_index") && is_real(_entry.target_index)) ? clamp(_entry.target_index, 0, 1) : 0;
    return { kind: "actor_glow", target_index: _idxg, color: make_color_rgb(248, 220, 120), alpha: 0.4 * (1 - _prog * 0.7), radius: __battle_anim_queue_wu(_pid, 48), progress: _prog };
    }
    if (_type == "heal"){
        var _idxh = (variable_struct_exists(_entry, "target_index") && is_real(_entry.target_index)) ? clamp(_entry.target_index, 0, 1) : 0;
    return { kind: "actor_glow", target_index: _idxh, color: make_color_rgb(120, 230, 150), alpha: 0.4 * (1 - _prog * 0.8), radius: __battle_anim_queue_wu(_pid, 42), progress: _prog };
    }
    if (_type == "recoil"){
        var _idxr = (variable_struct_exists(_entry, "target_index") && is_real(_entry.target_index)) ? clamp(_entry.target_index, 0, 1) : 0;
    return { kind: "actor_glow", target_index: _idxr, color: make_color_rgb(255, 120, 120), alpha: 0.45 * (1 - _prog * 0.7), radius: __battle_anim_queue_wu(_pid, 40), progress: _prog };
    }
    if (_type == "guard_split" || _type == "imprison" || _type == "cure_party"){
        var _idxs = (variable_struct_exists(_entry, "target_index") && is_real(_entry.target_index)) ? clamp(_entry.target_index, 0, 1) : 0;
        var _col_misc = (_type == "guard_split" ? make_color_rgb(200, 150, 250) : (_type == "imprison" ? make_color_rgb(180, 180, 230) : make_color_rgb(160, 240, 200)));
    return { kind: "actor_glow", target_index: _idxs, color: _col_misc, alpha: 0.55 * (1 - _prog * 0.6), radius: __battle_anim_queue_wu(_pid, 46), progress: _prog };
    }
    if (string(_entry.channel) == "field"){
        var _side = (variable_struct_exists(_entry, "side") ? string(_entry.side) : "full");
        var _col_field = (variable_struct_exists(_entry, "color") ? _entry.color : make_color_rgb(210, 210, 210));
        if (variable_struct_exists(_entry, "hazard") && string(_entry.hazard) != ""){
            return { kind: "hazard_overlay", side: _side, color: _col_field, alpha: 0.55 * (1 - _prog * 0.5), progress: _prog };
        }
        return { kind: "field_overlay", side: _side, color: _col_field, alpha: 0.45 * (1 - _prog * 0.45), progress: _prog };
    }
    if (string(_entry.channel) == "weather"){
        var _col_weather = (variable_struct_exists(_entry, "color") ? _entry.color : make_color_rgb(200, 200, 200));
        return { kind: "weather_overlay", color: _col_weather, alpha: 0.4 * (1 - _prog * 0.4), progress: _prog };
    }
    return { kind: "screen_flash", color: make_color_rgb(255, 255, 255), alpha: 0.3 * (1 - _prog), progress: _prog };
}

function __battle_anim_queue_draw_states(_pid, _states){
    if (!is_array(_states) || array_length(_states) <= 0) return;
    var _offx = 0;
    var _offy = 0;
    if (!is_undefined(battle_cam_get_draw_state)){
        var _cam_draw = battle_cam_get_draw_state(_pid);
        if (is_struct(_cam_draw)){
            if (variable_struct_exists(_cam_draw, "offset_x") && is_real(_cam_draw.offset_x)) _offx = _cam_draw.offset_x;
            if (variable_struct_exists(_cam_draw, "offset_y") && is_real(_cam_draw.offset_y)) _offy = _cam_draw.offset_y;
        }
    }
    var _center_player_arr = __battle_anim_queue_actor_center(_pid, 0);
    var _center_enemy_arr = __battle_anim_queue_actor_center(_pid, 1);
    var _player_cx = (is_array(_center_player_arr) && array_length(_center_player_arr) >= 2) ? _center_player_arr[0] + _offx : _offx;
    var _player_cy = (is_array(_center_player_arr) && array_length(_center_player_arr) >= 2) ? _center_player_arr[1] + _offy : _offy;
    var _enemy_cx = (is_array(_center_enemy_arr) && array_length(_center_enemy_arr) >= 2) ? _center_enemy_arr[0] + _offx : _offx;
    var _enemy_cy = (is_array(_center_enemy_arr) && array_length(_center_enemy_arr) >= 2) ? _center_enemy_arr[1] + _offy : _offy;
    var _full_x1 = __battle_anim_queue_xu(_pid, 0) + _offx;
    var _full_y1 = __battle_anim_queue_yu(_pid, 0) + _offy;
    var _full_x2 = __battle_anim_queue_xu(_pid, 240) + _offx;
    var _full_y2 = __battle_anim_queue_yu(_pid, 160) + _offy;
    var _split_y = __battle_anim_queue_yu(_pid, 88) + _offy;
    var _field_full = [_full_x1, _full_y1, _full_x2, _full_y2];
    var _field_player = [_full_x1, _split_y, _full_x2, _full_y2];
    var _field_enemy = [_full_x1, _full_y1, _full_x2, _split_y];

    for (var _si = 0; _si < array_length(_states); ++_si){
        var _st = _states[_si];
        if (!is_struct(_st)) continue;
        var _kind = (variable_struct_exists(_st, "kind") ? string(_st.kind) : "");
        if (_kind == "stat_overlay"){
            if (!sprite_exists(spr_stateffects)) continue;
            var _idx_so = (variable_struct_exists(_st, "target_index") && is_real(_st.target_index)) ? clamp(_st.target_index, 0, 1) : 0;
            var _cx_so = (_idx_so == 1 ? _enemy_cx : _player_cx);
            var _cy_so = (_idx_so == 1 ? _enemy_cy : _player_cy);
            var _frame_so = (variable_struct_exists(_st, "frame") && is_real(_st.frame)) ? clamp(floor(_st.frame), 0, max(0, sprite_get_number(spr_stateffects) - 1)) : 0;
            var _darken_so = (variable_struct_exists(_st, "darken") && _st.darken);
            var _prog_so = clamp((variable_struct_exists(_st, "progress") ? _st.progress : 0), 0, 1);
            // Soften tiled background alpha so it isn't overwhelmingly bright
            var _alpha_so = clamp(0.6 * (1 - _prog_so), 0, 1);
            var _yoff_so = -__battle_anim_queue_hu(_pid, 16, 16) * _prog_so;
            var _scale_so = 1;
            var _spr_w_so = sprite_get_width(spr_stateffects);
            if (_spr_w_so > 0) _scale_so = __battle_anim_queue_wu(_pid, 32, 32) / _spr_w_so;
            var _color_so = (_darken_so ? make_color_rgb(96, 96, 96) : c_white);
            // If requested, draw a full-field tiled background using the same sprite frame.
            var _bg_flag = (variable_struct_exists(_st, "bg") && _st.bg);
            if (_bg_flag){
                // Tile size: use same logical 32×32 tile sizing as the small overlay.
                var _tile_w = __battle_anim_queue_wu(_pid, 32, 32);
                var _tile_h = __battle_anim_queue_hu(_pid, 32, 32);
                var _spr_w = _spr_w_so;
                var _scale_tile = (_spr_w > 0) ? (_tile_w / _spr_w) : _scale_so;
                // Directional scroll: positive direction => raise (move up), negative => lower (move down)
                var _dir = (variable_struct_exists(_st, "direction") && is_real(_st.direction)) ? floor(_st.direction) : 0;
                // Continuous looping scroll: run several loops across the overlay duration
                var _loops = (variable_struct_exists(_st, "bg_loops") && is_real(_st.bg_loops)) ? max(0, floor(_st.bg_loops)) : 3; // how many tile-heights to scroll during full duration
                var _frac = 0;
                if (_loops > 0) {
                    var _lp = _prog_so * _loops;
                    _frac = _lp - floor(_lp); // fractional position within current loop (0..1)
                }
                var _scroll = 0;
                if (_dir > 0) _scroll = -(_frac * _tile_h); else if (_dir < 0) _scroll = (_frac * _tile_h);
                // Draw tiled across the full battlefield rectangle
                // Use normal blending for the tiled background to avoid additive brightness
                gpu_set_blendmode(bm_normal);
                // Force full logical canvas (0..240 x 0..160) to guarantee full-screen coverage
                var _lx = __battle_anim_queue_xu(_pid, 0);
                var _ty0 = __battle_anim_queue_yu(_pid, 0);
                var _rx = __battle_anim_queue_xu(_pid, 240);
                var _by = __battle_anim_queue_yu(_pid, 160);
                // Start one tile earlier to ensure full coverage at the left/top edges.
                // Use floor-based alignment so floating GUI coords don't skip the first column.
                var _start_y = _ty0 + _scroll - _tile_h;
                var _start_x = floor(_lx / max(1, _tile_w)) * _tile_w - _tile_w;
                // Inclusive bounds (+tile) to avoid missing the right/bottom edge due to rounding
                var _end_x = _rx + _tile_w;
                var _end_y = _by + _tile_h;
                for (var _tx = _start_x; _tx <= _end_x; _tx += _tile_w){
                    for (var _ty = _start_y; _ty <= _end_y; _ty += _tile_h){
                        draw_sprite_ext(spr_stateffects, _frame_so, _tx + _tile_w * 0.5, _ty + _tile_h * 0.5, _scale_tile, _scale_tile, 0, _color_so, _alpha_so);
                    }
                }
                gpu_set_blendmode(bm_normal);
                draw_set_alpha(1);
                draw_set_color(c_white);
            } else {
                gpu_set_blendmode(bm_normal);
                draw_sprite_ext(spr_stateffects, _frame_so, _cx_so, _cy_so + _yoff_so, _scale_so, _scale_so, 0, _color_so, _alpha_so);
                gpu_set_blendmode(bm_normal);
                draw_set_alpha(1);
                draw_set_color(c_white);
            }
            draw_set_alpha(1);
            draw_set_color(c_white);
        } else if (_kind == "actor_glow"){
            var _idx = (variable_struct_exists(_st, "target_index") && is_real(_st.target_index)) ? clamp(_st.target_index, 0, 1) : 0;
            var _cx = (_idx == 1 ? _enemy_cx : _player_cx);
            var _cy = (_idx == 1 ? _enemy_cy : _player_cy);
            var _color = (variable_struct_exists(_st, "color") ? _st.color : c_white);
            var _alpha = clamp((variable_struct_exists(_st, "alpha") ? _st.alpha : 0.4), 0, 1);
            var _prog = clamp((variable_struct_exists(_st, "progress") ? _st.progress : 0), 0, 1);
            var _radius_base_w = (variable_struct_exists(_st, "radius") && is_real(_st.radius)) ? _st.radius : __battle_anim_queue_wu(_pid, 40);
            var _radius_base_h = __battle_anim_queue_hu(_pid, 40);
            var _ease = sin(_prog * pi);
            var _radius_w = _radius_base_w * (0.65 + 0.35 * _ease);
            var _radius_h = _radius_base_h * (0.65 + 0.35 * _ease);
            // Draw ellipses (correct aspect for non-square UI scaling)
            draw_set_alpha(_alpha);
            draw_set_color(_color);
            draw_ellipse(_cx - _radius_w, _cy - _radius_h, _cx + _radius_w, _cy + _radius_h, false);
            draw_set_alpha(_alpha * 0.45);
            draw_ellipse(_cx - _radius_w * 0.55, _cy - _radius_h * 0.55, _cx + _radius_w * 0.55, _cy + _radius_h * 0.55, false);
            draw_set_alpha(1);
            draw_set_color(c_white);
        } else if (_kind == "field_overlay"){
            var _side = (variable_struct_exists(_st, "side") ? string(_st.side) : "full");
            var _rect = (_side == "player" ? _field_player : (_side == "enemy" ? _field_enemy : _field_full));
            var _colorf = (variable_struct_exists(_st, "color") ? _st.color : make_color_rgb(210, 210, 210));
            var _alphaf = clamp((variable_struct_exists(_st, "alpha") ? _st.alpha : 0.45), 0, 1);
            // Tile the area using 32x32 logical tiles so edges align with the rest of the tiled overlays.
            var _tile_w = __battle_anim_queue_wu(_pid, 32, 32);
            var _tile_h = __battle_anim_queue_hu(_pid, 32, 32);
            // Start one tile earlier and extend the end by one tile to guarantee full coverage
            var _start_x = floor(_rect[0] / max(1, _tile_w)) * _tile_w - _tile_w;
            var _start_y = floor(_rect[1] / max(1, _tile_h)) * _tile_h - _tile_h;
            var _end_x = _rect[2] + _tile_w; var _end_y = _rect[3] + _tile_h;
            draw_set_color(_colorf);
            // Fill tiles (lighter fill)
            draw_set_alpha(_alphaf * 0.35);
            for (var _tx = _start_x; _tx <= _end_x; _tx += _tile_w){
                for (var _ty = _start_y; _ty <= _end_y; _ty += _tile_h){
                    draw_rectangle(_tx, _ty, _tx + _tile_w, _ty + _tile_h, true);
                }
            }
            // Draw border over tiles
            draw_set_alpha(_alphaf * 0.6);
            draw_rectangle(_rect[0], _rect[1], _rect[2], _rect[3], false);
            draw_set_alpha(1);
            draw_set_color(c_white);
        } else if (_kind == "hazard_overlay"){
            var _sideh = (variable_struct_exists(_st, "side") ? string(_st.side) : "enemy");
            var _recth = (_sideh == "player" ? _field_player : (_sideh == "enemy" ? _field_enemy : _field_full));
            var _colorh = (variable_struct_exists(_st, "color") ? _st.color : make_color_rgb(205, 205, 205));
            var _alphah = clamp((variable_struct_exists(_st, "alpha") ? _st.alpha : 0.55), 0, 1);
            // Tile the hazard area using 32x32 tiles
            var _tile_w_h = __battle_anim_queue_wu(_pid, 32, 32);
            var _tile_h_h = __battle_anim_queue_hu(_pid, 32, 32);
            // Start one tile before the rect and extend past the end to avoid seams at edges
            var _s_x = floor(_recth[0] / max(1, _tile_w_h)) * _tile_w_h - _tile_w_h;
            var _s_y = floor(_recth[1] / max(1, _tile_h_h)) * _tile_h_h - _tile_h_h;
            var _end_x_h = _recth[2] + _tile_w_h;
            var _end_y_h = _recth[3] + _tile_h_h;
            draw_set_color(_colorh);
            draw_set_alpha(_alphah * 0.5);
            for (var _txh = _s_x; _txh <= _end_x_h; _txh += _tile_w_h){
                for (var _tyh = _s_y; _tyh <= _end_y_h; _tyh += _tile_h_h){
                    draw_rectangle(_txh, _tyh, _txh + _tile_w_h, _tyh + _tile_h_h, true);
                }
            }
            // Draw hazard diagonal stripes over tiled base
            draw_set_alpha(_alphah);
            var _stripe_step = __battle_anim_queue_wu(_pid, 20);
            var _maxw = max(1, (_recth[2] - _recth[0]));
            var _lines = max(2, floor(_maxw / _stripe_step));
            for (var _li = 0; _li <= _lines; ++_li){
                var _t = _li / max(1, _lines);
                var _sx = _recth[0] + _t * (_recth[2] - _recth[0]);
                draw_line(_sx, _recth[1], _sx - __battle_anim_queue_wu(_pid, 10), _recth[3]);
            }
            draw_set_alpha(1);
            draw_set_color(c_white);
        } else if (_kind == "weather_overlay"){
            var _colorw = (variable_struct_exists(_st, "color") ? _st.color : make_color_rgb(200, 200, 200));
            var _alphaw = clamp((variable_struct_exists(_st, "alpha") ? _st.alpha : 0.4), 0, 1);
            // Pad full-field weather rect to avoid seams
            var _pad_xw = max(1, floor(__battle_anim_queue_wu(_pid, 1)));
            var _pad_yw = max(1, floor(__battle_anim_queue_hu(_pid, 1)));
            var _wf0 = _field_full[0] - _pad_xw; var _wf1 = _field_full[1] - _pad_yw; var _wf2 = _field_full[2] + _pad_xw; var _wf3 = _field_full[3] + _pad_yw;
            draw_set_alpha(_alphaw * 0.7);
            draw_set_color(_colorw);
            draw_rectangle(_wf0, _wf1, _wf2, _wf3, false);
            draw_set_alpha(_alphaw * 0.35);
            draw_rectangle(_wf0, _wf1, _wf2, _wf3, true);
            draw_set_alpha(1);
            draw_set_color(c_white);
        } else if (_kind == "screen_flash"){
            var _colors = (variable_struct_exists(_st, "color") ? _st.color : c_white);
            var _alphas = clamp((variable_struct_exists(_st, "alpha") ? _st.alpha : 0.3), 0, 1);
            var _pad_xs = max(1, floor(__battle_anim_queue_wu(_pid, 1)));
            var _pad_ys = max(1, floor(__battle_anim_queue_hu(_pid, 1)));
            var _sf0 = _field_full[0] - _pad_xs; var _sf1 = _field_full[1] - _pad_ys; var _sf2 = _field_full[2] + _pad_xs; var _sf3 = _field_full[3] + _pad_ys;
            draw_set_alpha(_alphas);
            draw_set_color(_colors);
            draw_rectangle(_sf0, _sf1, _sf2, _sf3, false);
            draw_set_alpha(1);
            draw_set_color(c_white);
        }
        else if (_kind == "sprite_overlay"){
            // Draw an arbitrary single-frame/animated sprite centered on the target actor
            var _idxs = (variable_struct_exists(_st, "target_index") && is_real(_st.target_index)) ? clamp(_st.target_index, 0, 1) : 0;
            var _cxs = (_idxs == 1 ? _enemy_cx : _player_cx);
            var _cys = (_idxs == 1 ? _enemy_cy : _player_cy);
            var _sprs = (variable_struct_exists(_st, "sprite") ? _st.sprite : undefined);
            var _frs = (variable_struct_exists(_st, "frame") && is_real(_st.frame)) ? floor(_st.frame) : 0;
            var _scs = (variable_struct_exists(_st, "scale") && is_real(_st.scale)) ? _st.scale : 1;
            var _als = clamp((variable_struct_exists(_st, "alpha") ? _st.alpha : 1), 0, 1);
            var _offx = (variable_struct_exists(_st, "offset_x") && is_real(_st.offset_x)) ? _st.offset_x : 0;
            var _offy = (variable_struct_exists(_st, "offset_y") && is_real(_st.offset_y)) ? _st.offset_y : 0;
            var _sdir = (variable_struct_exists(_st, "slide_dir") && is_real(_st.slide_dir)) ? clamp(_st.slide_dir, -1, 1) : 0;
            var _smag = (variable_struct_exists(_st, "slide_mag") && is_real(_st.slide_mag)) ? _st.slide_mag : 8;
            // Compute slide progress: quick outward then return (0..1 -> 0 out, 1 back to origin)
            var _p = clamp((variable_struct_exists(_st, "progress") ? _st.progress : 0), 0, 1);
            var _slide_frac = 0;
            if (_p <= 0.25) {
                var t = (_p / 0.25);
                _slide_frac = 1 - power(1 - t, 2); // ease-out
            } else {
                var t2 = ((_p - 0.25) / 0.75);
                _slide_frac = 1 - (1 - (1 - power(1 - t2, 2))); // go back to 0
                // simpler: shrink back linearly eased
                _slide_frac = 1 - power(t2, 2);
            }
            var _slide_px = __battle_anim_queue_wu(_pid, _smag);
            var _apply_slide_x = _sdir * _slide_px * _slide_frac;
            var _draw_x = _cxs + _offx + _apply_slide_x;
            var _draw_y = _cys + _offy;
            if (!is_undefined(_sprs) && sprite_exists(_sprs)){
                gpu_set_blendmode(bm_normal);
                draw_sprite_ext(_sprs, _frs, _draw_x, _draw_y, _scs, _scs, 0, c_white, _als);
                gpu_set_blendmode(bm_normal);
                draw_set_alpha(1);
                draw_set_color(c_white);
            }
        }
    }
}

function __battle_anim_queue_trigger_camera(_pid, _slot, _entry){
    if (!is_struct(_entry)) return;
    if (is_undefined(battle_cam_pan_to_side) || is_undefined(battle_cam_pan_to_offset) || is_undefined(battle_cam_shake)) return;
    var _type = string(_entry.type);
    if (_type == "stat_change" || _type == "heal" || _type == "recoil" || _type == "guard_split" || _type == "imprison" || _type == "cure_party"){
        var _idx = (variable_struct_exists(_entry, "target_index") && is_real(_entry.target_index)) ? clamp(_entry.target_index, 0, 1) : 0;
        var _mag = max(4, __battle_anim_queue_wu(_pid, 6, 10));
        battle_cam_pan_to_side(_pid, _idx, _mag, 320);
        var _shake_amp = __battle_anim_queue_wu(_pid, (_type == "recoil" ? 4 : 2), (_type == "recoil" ? 8 : 5));
        battle_cam_shake(_pid, _shake_amp, (_type == "recoil" ? 16 : 12), 14, 0.86);
    } else if (_type == "set_terrain" || _type == "clear_terrain" || _type == "pledge_combo"){
        var _off_y = __battle_anim_queue_hu(_pid, -5, -5);
        battle_cam_pan_to_offset(_pid, 0, _off_y, 420);
    } else if (_type == "weather_tick" || _type == "weather_end" || _type == "weather_start"){
        var _shake_weather = __battle_anim_queue_wu(_pid, 2, 5);
        battle_cam_shake(_pid, _shake_weather, 18, 16, 0.9);
    }
}

function __battle_anim_create_catch(_B, _item_id, _caught_struct, _opts){
        if (!is_struct(_B)) return undefined;
        var _local_opts = (argument_count > 3 && is_struct(_opts)) ? _opts : {};
    var now = current_time;
    var ball_spr = undefined;
    if (!is_undefined(pkicons_get_item_icon_by_id) && is_real(_item_id) && _item_id > 0){
        try { var s_try = pkicons_get_item_icon_by_id(floor(_item_id)); if (!is_undefined(s_try) && sprite_exists(s_try)) ball_spr = s_try; } catch (e) { ball_spr = undefined; }
    }

    var hop_total = (variable_struct_exists(_local_opts, "hop_total") ? max(1, floor(variable_struct_get(_local_opts, "hop_total"))) : 3);
    var success = (variable_struct_exists(_local_opts, "success") ? (variable_struct_get(_local_opts, "success") == true) : false);
    var break_hop = (variable_struct_exists(_local_opts, "break_hop") ? floor(variable_struct_get(_local_opts, "break_hop")) : 0);
    // when success is true, we require final hop; if break_hop is not provided and failure, pick random
    if (!success && break_hop <= 0) break_hop = irandom(hop_total - 1) + 1;
    if (success) break_hop = 0;

    var ca = {
        active: true,
        start_ms: now,
        phase: "throw",
    throw_dur: (variable_struct_exists(_local_opts, "throw_dur") ? variable_struct_get(_local_opts, "throw_dur") : 380),
    impact_dur: (variable_struct_exists(_local_opts, "impact_dur") ? variable_struct_get(_local_opts, "impact_dur") : 220),
        hop_total: hop_total,
        hop_index: 0,
    hop_dur: (variable_struct_exists(_local_opts, "hop_dur") ? variable_struct_get(_local_opts, "hop_dur") : 700),
    hop_pause: (variable_struct_exists(_local_opts, "hop_pause") ? variable_struct_get(_local_opts, "hop_pause") : 350),
    catch_hop_success: (success ? hop_total : 0),
    break_hop: break_hop,
    outcome: success,
        ball_sprite: (is_undefined(ball_spr) ? (variable_global_exists("sbagpokeball") ? sbagpokeball : undefined) : ball_spr),
        ball_frame: 0,
        start_x: undefined,
        start_y: undefined,
        target_x: undefined,
        target_y: undefined,
        enemy_orig_scale: undefined,
        enemy_scale_now: undefined,
        caught_struct: _caught_struct
    };

        variable_struct_set(_B, "_catch_anim", ca);
        return ca;
    }

// Simple battle animations module
// Provides: __battle_anim_update(_B) -> progresses animations
//           __battle_anim_draw(_pid) -> draws current animation state

function __battle_anim_update(_B){
    // Accept pid or slot
    var _slot = _B;
    if (is_real(_B)) _slot = __battle_ensure_slot(_B);
    if (!is_struct(_slot)) return { resolved:false };
    if (!variable_struct_exists(_slot, "sys_anim") || !is_struct(variable_struct_get(_slot, "sys_anim"))) return { resolved:false };
    var sa = variable_struct_get(_slot, "sys_anim");
    var active = (variable_struct_exists(sa, "active") ? variable_struct_get(sa, "active") : []);
    var current = (variable_struct_exists(sa, "current") ? variable_struct_get(sa, "current") : undefined);

    // If no current and there's an active, pop one
    if (!is_struct(current) && is_array(active) && array_length(active) > 0){
        var next = active[0];
        // remove from active
        var newarr = [];
        for (var ii=1; ii<array_length(active); ++ii) newarr[array_length(newarr)] = active[ii];
        variable_struct_set(sa, "active", newarr);
        // current spec
        var now = current_time;
        var dur = (is_struct(next) && variable_struct_exists(next, "duration") ? variable_struct_get(next, "duration") : 700);
        variable_struct_set(sa, "current", { spec: next, start: now, dur: dur, active: true });
        variable_struct_set(_slot, "sys_anim", sa);
        return { resolved:false };
    }

    if (is_struct(current) && variable_struct_exists(current, "active") && current.active){
        var now2 = current_time;
        var elapsed = now2 - (variable_struct_exists(current, "start") ? current.start : now2);
        if (elapsed >= (variable_struct_exists(current, "dur") ? current.dur : 0)){
            variable_struct_set(sa, "current", undefined);
            variable_struct_set(_slot, "sys_anim", sa);
            return { resolved:true, action: (is_struct(current.spec) && variable_struct_exists(current.spec, "action") ? variable_struct_get(current.spec, "action") : undefined) };
        }
    }
    return { resolved:false };
}

// Returns a small draw state struct consumed by battle_draw.gml
function __battle_anim_get_draw_state(_B){
    if (!is_struct(_B) || !variable_struct_exists(_B, "_catch_anim")) return undefined;
    var A = variable_struct_get(_B, "_catch_anim");
    if (!is_struct(A)) return undefined;
    var out = { phase: string(A.phase), hop_index: (variable_struct_exists(A, "hop_index") ? A.hop_index : 0), hop_total: (variable_struct_exists(A, "hop_total") ? A.hop_total : 0), ball_sprite: A.ball_sprite, ball_frame: (variable_struct_exists(A, "ball_frame") ? A.ball_frame : 0), bounce:0 };
    // compute a simple fractional progress for the current hop if in shake
    if (string(A.phase) == "shake"){
        var now = current_time;
        var e2 = now - (variable_struct_exists(A, "phase_start") ? A.phase_start : now);
        var hop_dur = (variable_struct_exists(A, "hop_dur") ? max(1, real(A.hop_dur)) : 320);
        var hop_pause = (variable_struct_exists(A, "hop_pause") ? max(0, real(A.hop_pause)) : 180);
        var cycle = hop_dur + hop_pause;
        var phaseFr = clamp((hop_dur > 0 ? max(0, min(1, e2 / cycle * (hop_dur / cycle))) : 0), 0, 1);
        out.bounce = sin(phaseFr * pi) * 8;
    }
        return out;
    }
	


function __battle_anim_draw(_pid){
    var _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B)) return;
    if (variable_struct_exists(_B, "sys_open") && !variable_struct_get(_B, "sys_open")) return;
    if (!variable_struct_exists(_B, "sys_anim")) return;
    var sa = variable_struct_get(_B, "sys_anim");
    var cur = (variable_struct_exists(sa, "current") ? variable_struct_get(sa, "current") : undefined);
    if (!is_struct(cur) || !variable_struct_exists(cur, "spec")) return;
    var spec = cur.spec;
    var now = current_time;
    var elapsed = now - (variable_struct_exists(cur, "start") ? cur.start : now);
    var frac_v = 0;
    if (variable_struct_exists(cur, "dur") && cur.dur > 0) frac_v = clamp(elapsed / cur.dur, 0, 1);

    // Draw different visuals by spec.type
    var t = (variable_struct_exists(spec, "type") ? string(variable_struct_get(spec, "type")) : "unknown");
    draw_set_color(c_white);
    draw_set_alpha(1);
    // choose target coords: default to player or enemy centers
    var tx = 120; var ty = 80;
    if (variable_struct_exists(spec, "target_index")){
        var idx = variable_struct_get(spec, "target_index");
    if (idx == 0){ tx = __battle_anim_queue_xu(_pid, 64); ty = __battle_anim_queue_yu(_pid, 112); }
    else { tx = __battle_anim_queue_xu(_pid, 165); ty = __battle_anim_queue_yu(_pid, 40); }
    }

    if (t == "status_inflict" || t == "status_apply"){
        var st = (variable_struct_exists(spec, "status") ? string(variable_struct_get(spec, "status")) : "");
        // draw small status name above target, fade out
    var alpha = 1 - frac_v;
        draw_set_alpha(alpha);
        draw_set_color(c_black);
        draw_rectangle(tx-30, ty-38, tx+30, ty-18, false);
        draw_set_color(c_white);
        draw_text(tx-24, ty-36, string_upper(st));
        draw_set_alpha(1);
    } else if (t == "status_tick_damage" || t == "confusion_hit"){
        var amt = (variable_struct_exists(spec, "amount") ? string(variable_struct_get(spec, "amount")) : "");
        // pop-up damage text
    var y_off = - (frac_v * 20);
        draw_set_color(c_red);
        draw_text(tx, ty + y_off, "-" + string(amt));
        draw_set_color(c_white);
    } else if (t == "status_blocked"){
        var st2 = (variable_struct_exists(spec, "status") ? string(variable_struct_get(spec, "status")) : "");
    draw_set_color(c_yellow);
    draw_text(tx-24, ty-36, string_upper(st2) + "!");
        draw_set_color(c_white);
    } else {
        // generic: small translucent filled dot; if DATA_DEBUG is enabled, log the unexpected spec
        if (variable_global_exists("DATA_DEBUG_VERBOSE") && global.DATA_DEBUG_VERBOSE){
            try { show_debug_message("[battle][anim] generic spec=" + string(spec)); } catch (e) {}
        }
    var alpha2 = 0.6 * (1 - frac_v);
    draw_set_alpha(alpha2);
    draw_set_color(c_white);
    var _rx = __battle_anim_queue_wu(_pid, 3);
    var _ry = __battle_anim_queue_hu(_pid, 3);
    draw_ellipse(tx - _rx, ty - _ry, tx + _rx, ty + _ry, true);
    draw_set_alpha(1);
    }
}

