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
    var _idx = (is_real(_target_index) ? floor(_target_index) : 0);
    var _mag = (is_real(_magnitude) ? _magnitude : 12);
    var _dir = (__battle_actor_side(_idx) == 0) ? 1 : -1;
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

function __battle_anim_queue_ui_scale(_pid){
    var _slot = __battle_ensure_slot(_pid);
    if (!is_struct(_slot) || !variable_struct_exists(_slot, "_ui")) return 1;
    var _ui = variable_struct_get(_slot, "_ui");
    if (!is_struct(_ui) || !variable_struct_exists(_ui, "s") || !is_real(variable_struct_get(_ui, "s"))) return 1;
    return max(1, real(variable_struct_get(_ui, "s")));
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

function __battle_anim_move_effect_id(_move_id){
    if (!is_real(_move_id)) return undefined;
    try {
        if (!is_undefined(__battle_move_effect_id_safe)){
            var _resolved_eid = __battle_move_effect_id_safe(_move_id);
            if (is_real(_resolved_eid)) return floor(_resolved_eid);
        }
    } catch (e_safe_eid) {}
    try {
        if (variable_global_exists("_moves") && is_array(global._moves) && _move_id >= 0 && _move_id < array_length(global._moves)){
            var _mv = global._moves[_move_id];
            if (is_struct(_mv) && variable_struct_exists(_mv, "effect_id") && is_real(variable_struct_get(_mv, "effect_id"))) return floor(variable_struct_get(_mv, "effect_id"));
        }
    } catch (e_move_eid) {}
    return undefined;
}

function __battle_anim_move_meta(_move_id){
    if (!is_real(_move_id)) return undefined;
    try {
        if (!is_undefined(__battle_get_move_meta)){
            var _meta_fn = __battle_get_move_meta(_move_id);
            if (is_struct(_meta_fn)) return _meta_fn;
        }
    } catch (e_move_meta) {}
    try {
        if (variable_global_exists("_move_meta") && is_array(global._move_meta) && _move_id >= 0 && _move_id < array_length(global._move_meta)){
            var _meta = global._move_meta[_move_id];
            if (is_struct(_meta)) return _meta;
        }
    } catch (e_move_meta_global) {}
    return undefined;
}

function __battle_anim_color_for_family(_family){
    var _fam = string_lower(string(_family));
    switch (_fam){
        case "damage": return make_color_rgb(255, 148, 124);
        case "fixed_damage": return make_color_rgb(255, 208, 112);
        case "status": return make_color_rgb(186, 146, 244);
        case "trap": return make_color_rgb(214, 170, 92);
        case "stat": return make_color_rgb(132, 224, 168);
        case "heal": return make_color_rgb(118, 228, 152);
        case "drain": return make_color_rgb(132, 208, 170);
        case "recoil": return make_color_rgb(255, 124, 124);
        case "counter": return make_color_rgb(255, 112, 168);
        case "self_destruct": return make_color_rgb(255, 170, 96);
        case "copy": return make_color_rgb(196, 170, 255);
        case "transform": return make_color_rgb(156, 220, 255);
        case "charge": return make_color_rgb(250, 226, 108);
        case "guard": return make_color_rgb(164, 196, 255);
        case "barrier": return make_color_rgb(154, 188, 255);
        case "field": return make_color_rgb(196, 196, 216);
        case "hazard": return make_color_rgb(194, 174, 150);
        case "weather": return make_color_rgb(166, 198, 236);
        case "terrain": return make_color_rgb(170, 220, 170);
        case "switch": return make_color_rgb(238, 236, 176);
        case "support": return make_color_rgb(160, 230, 205);
        case "lock": return make_color_rgb(210, 156, 214);
        default: return make_color_rgb(255, 255, 255);
    }
}

function __battle_anim_family_for_move(_move_id){
    var _eid = __battle_anim_move_effect_id(_move_id);
    var _mm = __battle_anim_move_meta(_move_id);

    if (is_real(_eid)){
        switch (_eid){
            case 8: return "self_destruct";
            case 26: case 27: case 47: case 80: case 103: case 113: case 180: case 187: case 193: case 202: case 211: case 221: case 226: case 341: case 418: case 424: case 425: return "field";
            case 29: case 128: case 129: case 154: case 173: case 177: case 229: return "switch";
            case 36: case 66: case 125: return "barrier";
            case 40: case 76: case 81: case 146: case 152: case 156: case 257: case 264: case 273: case 312: return "charge";
            case 41: case 42: case 88: case 89: case 131: case 162: return "fixed_damage";
            case 43: case 262: case 423: return "trap";
            case 90: case 145: case 228: return "counter";
            case 104: case 159: case 171: case 197: case 201: case 208: case 210: return "damage";
            case 112: case 117: case 184: case 196: case 224: return "guard";
            case 116: case 137: case 138: case 165: return "weather";
            case 118: case 174: return "copy";
            case 143: case 144: case 178: case 179: case 181: case 185: case 192: case 242: case 243: return "copy";
            case 149: return "lock";
            case 250: case 267: return "hazard";
            case 280: case 325: case 326: case 327: case 340: case 351: case 352: case 353: case 367: case 369: case 392: case 395: case 415: return "terrain";
        }
    }

    if (is_struct(_mm)){
        if (variable_struct_exists(_mm, "healing") && is_real(variable_struct_get(_mm, "healing")) && real(variable_struct_get(_mm, "healing")) > 0) return "heal";
        if (variable_struct_exists(_mm, "drain") && is_real(variable_struct_get(_mm, "drain"))){
            var _drain = real(variable_struct_get(_mm, "drain"));
            if (_drain > 0) return "drain";
            if (_drain < 0) return "recoil";
        }
        if (variable_struct_exists(_mm, "stat_changes") && is_array(variable_struct_get(_mm, "stat_changes")) && array_length(variable_struct_get(_mm, "stat_changes")) > 0) return "stat";
        if ((variable_struct_exists(_mm, "status") && string_length(string(variable_struct_get(_mm, "status"))) > 0)
            || (variable_struct_exists(_mm, "infatuation") && variable_struct_get(_mm, "infatuation") == true)
            || (variable_struct_exists(_mm, "imprison") && variable_struct_get(_mm, "imprison") == true)) return "status";
    }

    if (is_real(_eid)){
        switch (_eid){
            case 10: case 31: case 83: case 84: case 96: case 102: case 119: return "copy";
            case 48: return "support";
            case 50: case 91: case 160: case 166: case 176: case 188: case 195: return "lock";
            case 58: return "transform";
        }
    }

    return "damage";
}

function __battle_anim_duration_for_family(_family, _fallback){
    var _dur = (is_real(_fallback) ? floor(_fallback) : 640);
    switch (string_lower(string(_family))){
        case "damage": return 520;
        case "fixed_damage": return 560;
        case "status": return 700;
        case "trap": return 760;
        case "stat": return 720;
        case "heal":
        case "drain":
        case "support": return 680;
        case "recoil":
        case "counter":
        case "self_destruct": return 640;
        case "copy":
        case "transform": return 760;
        case "charge":
        case "switch": return 780;
        case "guard":
        case "lock": return 700;
        case "field":
        case "hazard":
        case "barrier":
        case "weather":
        case "terrain": return 960;
        default: return _dur;
    }
}

function __battle_anim_queue_clamp_actor_index(_slot, _idx){
    var _max_idx = 1;
    try {
        if (is_struct(_slot) && variable_struct_exists(_slot, "actor") && is_array(variable_struct_get(_slot, "actor"))){
            _max_idx = max(0, array_length(variable_struct_get(_slot, "actor")) - 1);
        }
    } catch (e_anim_clamp_actor) {
        _max_idx = 1;
    }

    if (!is_real(_idx)) return 0;
    return clamp(floor(_idx), 0, _max_idx);
}

function __battle_anim_focus_index_for_family(_family, _actor_index, _target_index){
    var _fam = string_lower(string(_family));
    switch (_fam){
        case "heal":
        case "support":
        case "copy":
        case "transform":
        case "charge":
        case "guard":
        case "switch":
        case "self_destruct":
            if (is_real(_actor_index)) return floor(_actor_index);
            break;
    }
    if (is_real(_target_index)) return floor(_target_index);
    if (is_real(_actor_index)) return floor(_actor_index);
    return 0;
}

function __battle_anim_queue_find_actor_index_by_ref(_slot, _ref){
    if (!is_struct(_slot) || !is_struct(_ref)) return undefined;
    if (!variable_struct_exists(_slot, "actor") || !is_array(variable_struct_get(_slot, "actor"))) return undefined;
    var _actors = variable_struct_get(_slot, "actor");
    for (var _ai = 0; _ai < array_length(_actors); ++_ai){
        var _ac = _actors[_ai];
        if (_ac == _ref) return _ai;
        if (is_struct(_ac) && variable_struct_exists(_ac, "mon") && variable_struct_get(_ac, "mon") == _ref) return _ai;
    }
    return undefined;
}

function __battle_anim_queue_resolve_target_index(_slot, _spec){
    if (!is_struct(_spec)) return undefined;
    if (variable_struct_exists(_spec, "target_index") && is_real(variable_struct_get(_spec, "target_index"))) return floor(variable_struct_get(_spec, "target_index"));
    if (variable_struct_exists(_spec, "target_actor_index") && is_real(variable_struct_get(_spec, "target_actor_index"))) return floor(variable_struct_get(_spec, "target_actor_index"));
    if (variable_struct_exists(_spec, "target") && is_struct(variable_struct_get(_spec, "target"))){
        var _t = variable_struct_get(_spec, "target");
        var _target_ref_idx = __battle_anim_queue_find_actor_index_by_ref(_slot, _t);
        if (is_real(_target_ref_idx)) return floor(_target_ref_idx);
    }
    if (variable_struct_exists(_spec, "resolved_target") && is_struct(variable_struct_get(_spec, "resolved_target"))){
        var _resolved_target = variable_struct_get(_spec, "resolved_target");
        var _resolved_target_idx = __battle_anim_queue_find_actor_index_by_ref(_slot, _resolved_target);
        if (is_real(_resolved_target_idx)) return floor(_resolved_target_idx);
    }
    if (variable_struct_exists(_spec, "target_mon") && is_struct(variable_struct_get(_spec, "target_mon"))){
        var _target_mon = variable_struct_get(_spec, "target_mon");
        var _target_mon_idx = __battle_anim_queue_find_actor_index_by_ref(_slot, _target_mon);
        if (is_real(_target_mon_idx)) return floor(_target_mon_idx);
    }
    if (variable_struct_exists(_spec, "actor_index") && is_real(variable_struct_get(_spec, "actor_index"))) return floor(variable_struct_get(_spec, "actor_index"));
    if (variable_struct_exists(_spec, "actor") && is_struct(variable_struct_get(_spec, "actor"))){
        var _a = variable_struct_get(_spec, "actor");
        if (variable_struct_exists(_a, "actor_index") && is_real(variable_struct_get(_a, "actor_index"))) return floor(variable_struct_get(_a, "actor_index"));
    }
    return undefined;
}

function __battle_anim_queue_resolve_side(_slot, _spec){
    var _idx = __battle_anim_queue_resolve_target_index(_slot, _spec);

    if (is_real(_idx)){
        var _side_val = 1;
        try {
            if (!is_undefined(__battle_actor_side)){
                _side_val = __battle_actor_side(floor(_idx));
            } else {
                _side_val = (floor(_idx) <= 1) ? 0 : 1;
            }
        } catch (e_anim_resolve_side) {
            _side_val = (floor(_idx) <= 1) ? 0 : 1;
        }
        return (_side_val == 0 ? "player" : "enemy");
    }
    if (is_struct(_spec) && variable_struct_exists(_spec, "side")) return string(_spec.side);
    return "full";

}

function __battle_anim_sprite_from_names(_sprite_names){
    if (!is_array(_sprite_names)) return undefined;
    for (var _i = 0; _i < array_length(_sprite_names); ++_i){
        var _sprite_name = string(_sprite_names[_i]);
        if (string_length(_sprite_name) <= 0) continue;
        var _sprite_asset = asset_get_index(_sprite_name);
        if (is_real(_sprite_asset) && _sprite_asset >= 0){
            try {
                if (sprite_exists(_sprite_asset)) return _sprite_asset;
            } catch (_sprite_exists_error) { }
        }
    }
    return undefined;
}

function __battle_anim_move_type_id_safe(_move_id){
    if (!is_real(_move_id)) return undefined;
    try {
        if (variable_global_exists("_moves") && is_array(global._moves) && _move_id >= 0 && _move_id < array_length(global._moves)){
            var _move_data = global._moves[_move_id];
            if (is_struct(_move_data) && variable_struct_exists(_move_data, "type_id") && is_real(_move_data.type_id)) return floor(_move_data.type_id);
        }
    } catch (_move_type_error) { }
    return undefined;
}

function __battle_anim_sprite_for_type_id(_type_id){
    if (!is_real(_type_id)) return undefined;
    switch (floor(_type_id)){
        case 1:  return __battle_anim_sprite_from_names(["spr_anim_normal", "spr_type_normal", "spr_normal_anim", "sanim_normal"]);
        case 2:  return __battle_anim_sprite_from_names(["spr_anim_fighting", "spr_type_fighting", "spr_fighting_anim", "sanim_fighting"]);
        case 3:  return __battle_anim_sprite_from_names(["spr_anim_flying", "spr_type_flying", "spr_flying_anim", "sanim_flying"]);
        case 4:  return __battle_anim_sprite_from_names(["spr_anim_poison", "spr_type_poison", "spr_poison_anim", "sanim_poison"]);
        case 5:  return __battle_anim_sprite_from_names(["spr_anim_ground", "spr_type_ground", "spr_ground_anim", "sanim_ground"]);
        case 6:  return __battle_anim_sprite_from_names(["spr_anim_rock", "spr_type_rock", "spr_rock_anim", "sanim_rock"]);
        case 7:  return __battle_anim_sprite_from_names(["spr_anim_bug", "spr_type_bug", "spr_bug_anim", "sanim_bug"]);
        case 8:  return __battle_anim_sprite_from_names(["spr_ghost", "spr_anim_ghost", "spr_type_ghost", "spr_ghost_anim", "sanim_ghost"]);
        case 9:  return __battle_anim_sprite_from_names(["spr_anim_steel", "spr_type_steel", "spr_steel_anim", "sanim_steel"]);
        case 10: return __battle_anim_sprite_from_names(["spr_anim_fire", "spr_type_fire", "spr_fire_anim", "sanim_fire"]);
        case 11: return __battle_anim_sprite_from_names(["spr_anim_water", "spr_type_water", "spr_water_anim", "sanim_water"]);
        case 12: return __battle_anim_sprite_from_names(["spr_anim_grass", "spr_type_grass", "spr_grass_anim", "sanim_grass"]);
        case 13: return __battle_anim_sprite_from_names(["spr_anim_electric", "spr_type_electric", "spr_electric_anim", "sanim_electric"]);
        case 14: return __battle_anim_sprite_from_names(["spr_anim_psychic", "spr_type_psychic", "spr_psychic_anim", "sanim_psychic"]);
        case 15: return __battle_anim_sprite_from_names(["spr_anim_ice", "spr_type_ice", "spr_ice_anim", "sanim_ice"]);
        case 16: return __battle_anim_sprite_from_names(["spr_anim_dragon", "spr_type_dragon", "spr_dragon_anim", "sanim_dragon"]);
        case 17: return __battle_anim_sprite_from_names(["spr_anim_dark", "spr_type_dark", "spr_dark_anim", "sanim_dark"]);
        case 18: return __battle_anim_sprite_from_names(["spr_anim_fairy", "spr_type_fairy", "spr_fairy_anim", "sanim_fairy"]);
    }
    return undefined;
}

function __battle_anim_type_color(_type_id){
    if (!is_real(_type_id)) return c_white;
    switch (floor(_type_id)){
        case 1:  return make_color_rgb(226, 218, 196);
        case 2:  return make_color_rgb(224, 112, 82);
        case 3:  return make_color_rgb(174, 204, 250);
        case 4:  return make_color_rgb(184, 120, 214);
        case 5:  return make_color_rgb(182, 132, 82);
        case 6:  return make_color_rgb(176, 154, 104);
        case 7:  return make_color_rgb(158, 206, 98);
        case 8:  return make_color_rgb(146, 124, 196);
        case 9:  return make_color_rgb(184, 198, 208);
        case 10: return make_color_rgb(246, 112, 60);
        case 11: return make_color_rgb(96, 176, 238);
        case 12: return make_color_rgb(108, 210, 104);
        case 13: return make_color_rgb(250, 220, 74);
        case 14: return make_color_rgb(232, 128, 208);
        case 15: return make_color_rgb(176, 232, 250);
        case 16: return make_color_rgb(146, 126, 240);
        case 17: return make_color_rgb(104, 94, 112);
        case 18: return make_color_rgb(250, 164, 220);
    }
    return c_white;
}

function __battle_anim_move_identifier_safe(_move_id){
    if (!is_real(_move_id)) return "";
    try {
        if (variable_global_exists("_moves") && is_array(global._moves) && _move_id >= 0 && _move_id < array_length(global._moves)){
            var _move_data = global._moves[_move_id];
            if (is_struct(_move_data) && variable_struct_exists(_move_data, "identifier")) return string_lower(string(variable_struct_get(_move_data, "identifier")));
        }
    } catch (_move_ident_error) { }
    return "";
}

function __battle_anim_profile_set_particle(_profile, _kind, _sprite, _tint, _count, _duration, _scale, _spread_x, _spread_y, _speed_x, _speed_y, _gravity, _from_user){
    var _has_particle_sprite = false;
    try { _has_particle_sprite = (!is_undefined(_sprite) && sprite_exists(_sprite)); } catch (e_profile_particle_sprite) { _has_particle_sprite = false; }
    _profile.visual_kind = _has_particle_sprite ? ((_from_user == true) ? "sprite_projectile" : "sprite_overlay") : "particle_burst";
    _profile.particle_kind = string(_kind);
    _profile.sprite = _sprite;
    _profile.tint = _tint;
    _profile.particle_count = max(1, floor(_count));
    _profile.duration = max(1, floor(_duration));
    _profile.scale = (is_real(_scale) ? real(_scale) : 1);
    _profile.spread_x = (is_real(_spread_x) ? real(_spread_x) : 18);
    _profile.spread_y = (is_real(_spread_y) ? real(_spread_y) : 14);
    _profile.speed_x = (is_real(_speed_x) ? real(_speed_x) : 0);
    _profile.speed_y = (is_real(_speed_y) ? real(_speed_y) : -10);
    _profile.gravity = (is_real(_gravity) ? real(_gravity) : 0);
    _profile.from_user = (_from_user == true);
    return _profile;
}

function __battle_anim_profile_set_sprite(_profile, _sprite, _tint, _duration, _scale, _offset_x, _offset_y, _projectile){
    _profile.visual_kind = (_projectile == true) ? "sprite_projectile" : "sprite_overlay";
    _profile.sprite = _sprite;
    _profile.tint = _tint;
    _profile.duration = max(1, floor(_duration));
    _profile.scale = (is_real(_scale) ? real(_scale) : 1);
    _profile.offset_x = (is_real(_offset_x) ? real(_offset_x) : 0);
    _profile.offset_y = (is_real(_offset_y) ? real(_offset_y) : 0);
    _profile.from_user = (_projectile == true);
    return _profile;
}

function __battle_anim_hash_unit(_seed, _salt){
    var _v = sin((real(_seed) + real(_salt) * 37.719) * 12.9898) * 43758.5453;
    return abs(_v - floor(_v));
}

function __battle_anim_profile_distinctify(_profile, _move_id, _effect_index, _type_id, _ident, _family){
    if (!is_struct(_profile)) return _profile;

    var _move_index = is_real(_move_id) ? floor(_move_id) : 0;
    var _effect_seed = is_real(_effect_index) ? floor(_effect_index) : -1;
    var _type_seed = is_real(_type_id) ? floor(_type_id) : -1;
    var _family_seed = string_length(string(_family)) * 41;
    var _ident_seed = string_length(string(_ident)) * 131;
    var _seed = (_move_index + 1) * 977 + (_effect_seed + 11) * 53 + (_type_seed + 7) * 89 + _ident_seed + _family_seed;

    var _r0 = __battle_anim_hash_unit(_seed, 1);
    var _r1 = __battle_anim_hash_unit(_seed, 2);
    var _r2 = __battle_anim_hash_unit(_seed, 3);
    var _r3 = __battle_anim_hash_unit(_seed, 4);
    var _r4 = __battle_anim_hash_unit(_seed, 5);
    var _r5 = __battle_anim_hash_unit(_seed, 6);
    var _r6 = __battle_anim_hash_unit(_seed, 7);

    var _power_factor = 0;
    try {
        if (variable_global_exists("_moves") && is_array(global._moves) && _move_index >= 0 && _move_index < array_length(global._moves)){
            var _move_data = global._moves[_move_index];
            if (is_struct(_move_data) && variable_struct_exists(_move_data, "power")){
                var _power = variable_struct_get(_move_data, "power");
                if (is_real(_power)) _power_factor = clamp(real(_power) / 120, 0, 1);
            }
        }
    } catch (_move_power_error) { }

    if (variable_struct_exists(_profile, "duration")){
        _profile.duration = max(180, floor(real(_profile.duration) + floor((_r0 - 0.5) * 130) + floor(_power_factor * 90)));
    }

    if (variable_struct_exists(_profile, "scale")){
        _profile.scale = max(0.25, real(_profile.scale) * (0.82 + _r1 * 0.42 + _power_factor * 0.22));
    }

    if (variable_struct_exists(_profile, "offset_x")) _profile.offset_x = real(_profile.offset_x) + floor((_r2 - 0.5) * 18);
    if (variable_struct_exists(_profile, "offset_y")) _profile.offset_y = real(_profile.offset_y) + floor((_r3 - 0.5) * 16);
    if (variable_struct_exists(_profile, "spin_speed")) _profile.spin_speed = real(_profile.spin_speed) * (0.75 + _r4 * 0.7);
    if (variable_struct_exists(_profile, "orbit_count")) _profile.orbit_count = max(0, floor(real(_profile.orbit_count) + floor(_r5 * 2)));
    if (variable_struct_exists(_profile, "orbit_radius_x")) _profile.orbit_radius_x = max(2, real(_profile.orbit_radius_x) * (0.78 + _r2 * 0.6));
    if (variable_struct_exists(_profile, "orbit_radius_y")) _profile.orbit_radius_y = max(2, real(_profile.orbit_radius_y) * (0.78 + _r3 * 0.6));

    var _visual_kind = variable_struct_exists(_profile, "visual_kind") ? string(_profile.visual_kind) : "none";
    if (_visual_kind == "particle_burst"){
        _profile.particle_count = max(2, floor(real(_profile.particle_count) + floor(_r0 * 5) + floor(_power_factor * 4)));
        _profile.spread_x = max(2, real(_profile.spread_x) * (0.72 + _r1 * 0.75));
        _profile.spread_y = max(2, real(_profile.spread_y) * (0.72 + _r2 * 0.75));
        _profile.speed_x = real(_profile.speed_x) + (_r3 - 0.5) * 18;
        _profile.speed_y = real(_profile.speed_y) + (_r4 - 0.5) * 14 - _power_factor * 8;
        _profile.gravity = real(_profile.gravity) + (_r5 - 0.5) * 10;

        var _kind = variable_struct_exists(_profile, "particle_kind") ? string(_profile.particle_kind) : "spark";
        if (_kind == "type" || _kind == "impact"){
            switch (floor(_r6 * 6)){
                case 0: _profile.particle_kind = "spark"; break;
                case 1: _profile.particle_kind = "slash"; break;
                case 2: _profile.particle_kind = "wind"; break;
                case 3: _profile.particle_kind = "ring"; break;
                case 4: _profile.particle_kind = "orb"; break;
                default: _profile.particle_kind = _kind; break;
            }
        }
    }

    return _profile;
}

function __battle_anim_effect_visual_profile(_effect_id, _move_id, _family){
    var _profile = {
        visual_kind: "none",
        sprite: undefined,
        duration: 640,
        scale: 1,
        offset_x: 0,
        offset_y: 0,
        orbit_count: 0,
        orbit_radius_x: 18,
        orbit_radius_y: 9,
        spin_speed: 1,
        tint: c_white,
        particle_kind: "spark",
        particle_count: 10,
        spread_x: 18,
        spread_y: 14,
        speed_x: 0,
        speed_y: -10,
        gravity: 0,
        from_user: false
    };

    var _effect_index = is_real(_effect_id) ? floor(_effect_id) : -1;
    var _type_id = __battle_anim_move_type_id_safe(_move_id);
    var _type_sprite = __battle_anim_sprite_for_type_id(_type_id);
    var _ident = __battle_anim_move_identifier_safe(_move_id);

    var _sprite_hit = __battle_anim_sprite_from_names(["spr_hiteffect"]);
    var _sprite_slash = __battle_anim_sprite_from_names(["spr_slash", "spr_scratch"]);
    var _sprite_bite = __battle_anim_sprite_from_names(["spr_bite"]);
    var _sprite_rock = __battle_anim_sprite_from_names(["spr_rock"]);
    var _sprite_water = __battle_anim_sprite_from_names(["spr_raindrop"]);
    var _sprite_sludge = __battle_anim_sprite_from_names(["spr_sludge", "spr_poison"]);
    var _sprite_powder = __battle_anim_sprite_from_names(["spr_sleeppowder", "spr_seeded", "spr_seed_sprout"]);
    var _sprite_gust = __battle_anim_sprite_from_names(["spr_gust"]);
    var _sprite_burn = __battle_anim_sprite_from_names(["spr_burn"]);
    var _sprite_para = __battle_anim_sprite_from_names(["spr_paralyze"]);
    var _sprite_freeze = __battle_anim_sprite_from_names(["spr_frozen"]);
    var _sprite_heal = __battle_anim_sprite_from_names(["spr_healing_halo", "spr_seed_sprout"]);
    var _sprite_ghost = __battle_anim_sprite_from_names(["spr_ghost", "spr_anim_ghost", "spr_type_ghost", "spr_ghost_anim"]);
    var _sprite_detect = __battle_anim_sprite_from_names(["spr_detect", "spr_protect", "spr_anim_protect", "spr_anim_detect"]);
    var _sprite_help = __battle_anim_sprite_from_names(["spr_helpinghand", "spr_helping_hand", "spr_anim_helpinghand", "spr_healing_halo"]);

    if (string_pos("sand", _ident) > 0 || _effect_index == 24){
        return __battle_anim_profile_distinctify(__battle_anim_profile_set_particle(_profile, "sand", undefined, make_color_rgb(210, 186, 122), 34, 720, 0.95, 24, 12, 64, -8, 18, true), _move_id, _effect_index, _type_id, _ident, _family);
    }

    if (string_pos("mud", _ident) > 0 || _effect_index == 74){
        return __battle_anim_profile_distinctify(__battle_anim_profile_set_particle(_profile, "mud", undefined, make_color_rgb(126, 92, 54), 28, 700, 1.05, 22, 14, 58, -10, 34, true), _move_id, _effect_index, _type_id, _ident, _family);
    }

    if (string_pos("water", _ident) > 0 || string_pos("aqua", _ident) > 0 || string_pos("surf", _ident) > 0 || string_pos("hydro", _ident) > 0 || _type_id == 11){
        return __battle_anim_profile_distinctify(__battle_anim_profile_set_particle(_profile, "water_blast", undefined, make_color_rgb(112, 190, 252), 32, 700, 0.95, 26, 18, 68, -18, 16, true), _move_id, _effect_index, _type_id, _ident, _family);
    }

    if (string_pos("rock", _ident) > 0 || string_pos("stone", _ident) > 0 || _type_id == 6){
        return __battle_anim_profile_distinctify(__battle_anim_profile_set_particle(_profile, "rock", _sprite_rock, make_color_rgb(176, 154, 104), 12, 640, 0.75, 20, 12, -26, -22, 44, true), _move_id, _effect_index, _type_id, _ident, _family);
    }

    if (string_pos("sludge", _ident) > 0 || string_pos("poison", _ident) > 0 || string_pos("toxic", _ident) > 0 || _type_id == 4 || _effect_index == 3 || _effect_index == 67){
        return __battle_anim_profile_distinctify(__battle_anim_profile_set_particle(_profile, "blob", _sprite_sludge, make_color_rgb(178, 104, 208), 14, 680, 0.9, 18, 12, -18, -20, 26, true), _move_id, _effect_index, _type_id, _ident, _family);
    }

    if (string_pos("powder", _ident) > 0 || string_pos("spore", _ident) > 0 || _effect_index == 2 || _effect_index == 67 || _effect_index == 68){
        return __battle_anim_profile_distinctify(__battle_anim_profile_set_particle(_profile, "powder", _sprite_powder, make_color_rgb(184, 228, 116), 20, 820, 0.7, 26, 22, 0, -16, -5, false), _move_id, _effect_index, _type_id, _ident, _family);
    }

    if (string_pos("leaf", _ident) > 0 || string_pos("vine", _ident) > 0 || _type_id == 12){
        return __battle_anim_profile_distinctify(__battle_anim_profile_set_particle(_profile, "leaf", _sprite_powder, make_color_rgb(92, 210, 92), 14, 660, 0.8, 28, 14, -30, -18, 20, true), _move_id, _effect_index, _type_id, _ident, _family);
    }

    if (string_pos("gust", _ident) > 0 || string_pos("wind", _ident) > 0 || string_pos("air", _ident) > 0 || _type_id == 3){
        if (!is_undefined(_sprite_gust)){
            return __battle_anim_profile_distinctify(__battle_anim_profile_set_sprite(_profile, _sprite_gust, c_white, 760, 1.0, 0, -8, true), _move_id, _effect_index, _type_id, _ident, _family);
        }
        return __battle_anim_profile_distinctify(__battle_anim_profile_set_particle(_profile, "wind", _sprite_gust, make_color_rgb(190, 220, 250), 10, 720, 0.95, 28, 18, 58, -8, 0, true), _move_id, _effect_index, _type_id, _ident, _family);
    }

    if (string_pos("slash", _ident) > 0 || string_pos("scratch", _ident) > 0 || string_pos("claw", _ident) > 0 || _effect_index == 44){
        if (!is_undefined(_sprite_slash)){
            return __battle_anim_profile_distinctify(__battle_anim_profile_set_sprite(_profile, _sprite_slash, c_white, 500, 1.0, 0, -8, false), _move_id, _effect_index, _type_id, _ident, _family);
        }
        return __battle_anim_profile_distinctify(__battle_anim_profile_set_particle(_profile, "slash", _sprite_slash, make_color_rgb(246, 238, 220), 5, 460, 1.0, 24, 12, 0, -8, 0, false), _move_id, _effect_index, _type_id, _ident, _family);
    }

    if (string_pos("bite", _ident) > 0 || string_pos("fang", _ident) > 0 || string_pos("crunch", _ident) > 0){
        if (!is_undefined(_sprite_bite)){
            return __battle_anim_profile_distinctify(__battle_anim_profile_set_sprite(_profile, _sprite_bite, c_white, 500, 1.0, 0, -6, false), _move_id, _effect_index, _type_id, _ident, _family);
        }
        return __battle_anim_profile_distinctify(__battle_anim_profile_set_particle(_profile, "bite", _sprite_bite, make_color_rgb(235, 224, 200), 4, 500, 1.0, 18, 10, 0, -6, 0, false), _move_id, _effect_index, _type_id, _ident, _family);
    }

    if (string_pos("thunder", _ident) > 0 || string_pos("shock", _ident) > 0 || string_pos("volt", _ident) > 0 || _type_id == 13 || _effect_index == 7 || _effect_index == 153){
        return __battle_anim_profile_distinctify(__battle_anim_profile_set_particle(_profile, "spark", _sprite_para, make_color_rgb(250, 232, 74), 16, 560, 0.85, 24, 18, 0, -22, 0, false), _move_id, _effect_index, _type_id, _ident, _family);
    }

    if (string_pos("ember", _ident) > 0 || string_pos("flame", _ident) > 0 || string_pos("fire", _ident) > 0 || string_pos("burn", _ident) > 0 || _type_id == 10 || _effect_index == 5){
        return __battle_anim_profile_distinctify(__battle_anim_profile_set_particle(_profile, "flame", _sprite_burn, make_color_rgb(250, 112, 52), 16, 620, 0.8, 22, 16, -22, -28, -12, true), _move_id, _effect_index, _type_id, _ident, _family);
    }

    if (string_pos("ice", _ident) > 0 || string_pos("freeze", _ident) > 0 || string_pos("snow", _ident) > 0 || _type_id == 15 || _effect_index == 6){
        return __battle_anim_profile_distinctify(__battle_anim_profile_set_particle(_profile, "ice", _sprite_freeze, make_color_rgb(180, 236, 255), 14, 660, 0.75, 22, 16, -18, -20, 18, true), _move_id, _effect_index, _type_id, _ident, _family);
    }

    if (string_pos("heal", _ident) > 0 || string_pos("recover", _ident) > 0 || string_pos("restore", _ident) > 0 || string_lower(string(_family)) == "heal"){
        return __battle_anim_profile_distinctify(__battle_anim_profile_set_particle(_profile, "heal", _sprite_heal, make_color_rgb(118, 230, 154), 14, 760, 0.85, 24, 18, 0, -24, -16, false), _move_id, _effect_index, _type_id, _ident, _family);
    }

    if (string_pos("beam", _ident) > 0 || string_pos("blast", _ident) > 0 || string_pos("pulse", _ident) > 0 || string_pos("ray", _ident) > 0){
        return __battle_anim_profile_distinctify(__battle_anim_profile_set_particle(_profile, "spark", _type_sprite, __battle_anim_type_color(_type_id), 22, 560, 0.8, 20, 12, -48, -6, 0, true), _move_id, _effect_index, _type_id, _ident, _family);
    }

    if (string_pos("punch", _ident) > 0 || string_pos("kick", _ident) > 0 || string_pos("chop", _ident) > 0 || string_pos("throw", _ident) > 0){
        return __battle_anim_profile_distinctify(__battle_anim_profile_set_particle(_profile, "impact", _sprite_hit, make_color_rgb(244, 180, 122), 9, 460, 1.05, 18, 10, 0, -10, 0, false), _move_id, _effect_index, _type_id, _ident, _family);
    }

    if (string_pos("psych", _ident) > 0 || string_pos("mind", _ident) > 0 || string_pos("confusion", _ident) > 0 || string_pos("dream", _ident) > 0){
        return __battle_anim_profile_distinctify(__battle_anim_profile_set_particle(_profile, "orb", _type_sprite, make_color_rgb(238, 122, 238), 18, 760, 0.82, 28, 22, 0, -18, -10, false), _move_id, _effect_index, _type_id, _ident, _family);
    }

    if (string_pos("shadow", _ident) > 0 || string_pos("ghost", _ident) > 0 || string_pos("hex", _ident) > 0 || string_pos("curse", _ident) > 0 || string_pos("night", _ident) > 0){
        return __battle_anim_profile_distinctify(__battle_anim_profile_set_particle(_profile, "orb", _sprite_ghost, make_color_rgb(132, 92, 190), 16, 720, 0.9, 24, 20, -12, -12, -6, true), _move_id, _effect_index, _type_id, _ident, _family);
    }

    if (string_pos("metal", _ident) > 0 || string_pos("steel", _ident) > 0 || string_pos("iron", _ident) > 0){
        return __battle_anim_profile_distinctify(__battle_anim_profile_set_particle(_profile, "slash", _sprite_slash, make_color_rgb(190, 206, 218), 8, 520, 0.95, 18, 10, 0, -8, 0, false), _move_id, _effect_index, _type_id, _ident, _family);
    }

    if (string_pos("bug", _ident) > 0 || string_pos("web", _ident) > 0 || string_pos("sting", _ident) > 0 || string_pos("pin", _ident) > 0){
        return __battle_anim_profile_distinctify(__battle_anim_profile_set_particle(_profile, "leaf", _sprite_powder, make_color_rgb(156, 210, 78), 18, 620, 0.72, 26, 16, -28, -14, 10, true), _move_id, _effect_index, _type_id, _ident, _family);
    }

    if (string_pos("roar", _ident) > 0 || string_pos("sing", _ident) > 0 || string_pos("voice", _ident) > 0 || string_pos("sound", _ident) > 0 || string_pos("screech", _ident) > 0){
        return __battle_anim_profile_distinctify(__battle_anim_profile_set_particle(_profile, "ring", undefined, make_color_rgb(244, 232, 164), 12, 700, 0.85, 30, 18, -8, -12, -4, true), _move_id, _effect_index, _type_id, _ident, _family);
    }

    if (string_pos("detect", _ident) > 0 || string_pos("protect", _ident) > 0 || string_pos("guard", _ident) > 0 || string_pos("shield", _ident) > 0){
        return __battle_anim_profile_distinctify(__battle_anim_profile_set_particle(_profile, "ring", _sprite_detect, make_color_rgb(168, 236, 250), 10, 620, 0.95, 18, 16, 0, -18, -12, false), _move_id, _effect_index, _type_id, _ident, _family);
    }

    if (string_pos("helping-hand", _ident) > 0 || string_pos("helping_hand", _ident) > 0 || string_pos("helping", _ident) > 0 || string_pos("assist", _ident) > 0){
        return __battle_anim_profile_distinctify(__battle_anim_profile_set_particle(_profile, "orb", _sprite_help, make_color_rgb(255, 224, 132), 12, 720, 0.9, 22, 18, 0, -22, -14, false), _move_id, _effect_index, _type_id, _ident, _family);
    }

    if (string_pos("dance", _ident) > 0 || string_pos("focus", _ident) > 0 || string_pos("calm", _ident) > 0 || string_pos("bulk", _ident) > 0 || string_pos("swords", _ident) > 0){
        return __battle_anim_profile_distinctify(__battle_anim_profile_set_particle(_profile, "orb", _sprite_heal, make_color_rgb(238, 220, 132), 14, 760, 0.78, 22, 20, 0, -22, -14, false), _move_id, _effect_index, _type_id, _ident, _family);
    }

    // Sleep status / Dream Eater-style sleep visuals.
    if (_effect_index == 2 || _effect_index == 9){
        _profile.visual_kind = "sprite_overlay";
        _profile.sprite = __battle_anim_sprite_from_names(["spr_sleep", "spr_anim_sleep", "spr_status_sleep", "ssleep"]);
        _profile.duration = 820;
        _profile.scale = 1;
        _profile.offset_y = -28;
        _profile.anchor = "head";
        return __battle_anim_profile_distinctify(_profile, _move_id, _effect_index, _type_id, _ident, _family);
    }

    // Poison, burn, freeze, paralysis: prefer specific status sprite, then fall back to type animation sprite.
    if (_effect_index == 3){
        _profile.visual_kind = "sprite_overlay";
        _profile.sprite = __battle_anim_sprite_from_names(["spr_poison", "spr_status_poison", "spr_anim_poison_status", "spr_poison_status"]);
        if (is_undefined(_profile.sprite)) _profile.sprite = _type_sprite;
        _profile.duration = 720;
        _profile.scale = 1;
        _profile.anchor = "head";
        return __battle_anim_profile_distinctify(_profile, _move_id, _effect_index, _type_id, _ident, _family);
    }
    if (_effect_index == 5){
        _profile.visual_kind = "sprite_overlay";
        _profile.sprite = __battle_anim_sprite_from_names(["spr_status_burn", "spr_anim_burn", "spr_burn_status"]);
        if (is_undefined(_profile.sprite)) _profile.sprite = _type_sprite;
        _profile.duration = 720;
        _profile.scale = 1;
        _profile.anchor = "head";
        return __battle_anim_profile_distinctify(_profile, _move_id, _effect_index, _type_id, _ident, _family);
    }
    if (_effect_index == 6){
        _profile.visual_kind = "sprite_overlay";
        _profile.sprite = __battle_anim_sprite_from_names(["spr_status_freeze", "spr_anim_freeze", "spr_freeze_status"]);
        if (is_undefined(_profile.sprite)) _profile.sprite = _type_sprite;
        _profile.duration = 760;
        _profile.scale = 1;
        _profile.anchor = "head";
        return __battle_anim_profile_distinctify(_profile, _move_id, _effect_index, _type_id, _ident, _family);
    }
    if (_effect_index == 7){
        _profile.visual_kind = "sprite_overlay";
        _profile.sprite = __battle_anim_sprite_from_names(["spr_status_paralyze", "spr_anim_paralyze", "spr_paralyze_status", "spr_anim_electric"]);
        if (is_undefined(_profile.sprite)) _profile.sprite = _type_sprite;
        _profile.duration = 700;
        _profile.scale = 1;
        _profile.anchor = "head";
        return __battle_anim_profile_distinctify(_profile, _move_id, _effect_index, _type_id, _ident, _family);
    }

    // Drain moves: Absorb / Mega Drain / Leech Life etc.
    if (_effect_index == 4){
        _profile.visual_kind = "sprite_overlay";
        _profile.sprite = __battle_anim_sprite_from_names(["spr_anim_absorb", "spr_absorb", "spr_drain", "spr_anim_drain", "spr_anim_grass"]);
        if (is_undefined(_profile.sprite)) _profile.sprite = _type_sprite;
        _profile.duration = 760;
        _profile.scale = 1;
        return __battle_anim_profile_distinctify(_profile, _move_id, _effect_index, _type_id, _ident, _family);
    }

    // Self-destruct / Explosion.
    if (_effect_index == 8){
        _profile.visual_kind = "sprite_overlay";
        _profile.sprite = __battle_anim_sprite_from_names(["spr_anim_explosion", "spr_explosion", "spr_boom", "spr_hiteffect"]);
        _profile.duration = 760;
        _profile.scale = 1.25;
        return __battle_anim_profile_distinctify(_profile, _move_id, _effect_index, _type_id, _ident, _family);
    }

    // Generic damage/status fallback: use move type animation if present.
    if (!is_undefined(_type_sprite)){
        return __battle_anim_profile_distinctify(__battle_anim_profile_set_sprite(_profile, _type_sprite, c_white, 560, 0.9, 0, -12, false), _move_id, _effect_index, _type_id, _ident, _family);
    }

    return __battle_anim_profile_distinctify(__battle_anim_profile_set_particle(_profile, "impact", _sprite_hit, __battle_anim_color_for_family(_family), 8, 520, 0.9, 16, 10, 0, -10, 4, false), _move_id, _effect_index, _type_id, _ident, _family);
}


function __battle_anim_queue_normalize(_slot, _spec){
    if (!is_struct(_spec)) return undefined;
    var _type = string_lower(string(variable_struct_exists(_spec, "type") ? variable_struct_get(_spec, "type") : "generic"));
    var _out = { type: _type, channel: "primary", duration: __battle_anim_queue_default_duration(_type), raw: _spec };

    switch (_type){
        case "move":
            _out.channel = "primary";
            _out.target_index = __battle_anim_queue_resolve_target_index(_slot, _spec);
            if (variable_struct_exists(_spec, "actor")) _out.actor = variable_struct_get(_spec, "actor");
            if (variable_struct_exists(_spec, "target")) _out.target = variable_struct_get(_spec, "target");
            _out.move_id = (variable_struct_exists(_spec, "move_id") && is_real(variable_struct_get(_spec, "move_id"))) ? floor(variable_struct_get(_spec, "move_id")) : undefined;
            _out.effect_id = __battle_anim_move_effect_id(_out.move_id);
            _out.family = __battle_anim_family_for_move(_out.move_id);
            _out.color = __battle_anim_color_for_family(_out.family);
            var _effect_visual_profile = __battle_anim_effect_visual_profile(_out.effect_id, _out.move_id, _out.family);
            if (is_struct(_effect_visual_profile) && string(_effect_visual_profile.visual_kind) != "none"){
                _out.visual_kind = _effect_visual_profile.visual_kind;
                _out.sprite = _effect_visual_profile.sprite;
                _out.scale = _effect_visual_profile.scale;
                _out.offset_x = _effect_visual_profile.offset_x;
                _out.offset_y = _effect_visual_profile.offset_y;
                _out.orbit_count = _effect_visual_profile.orbit_count;
                _out.orbit_radius_x = _effect_visual_profile.orbit_radius_x;
                _out.orbit_radius_y = _effect_visual_profile.orbit_radius_y;
                _out.spin_speed = _effect_visual_profile.spin_speed;
                _out.tint = _effect_visual_profile.tint;
                _out.particle_kind = _effect_visual_profile.particle_kind;
                _out.particle_count = _effect_visual_profile.particle_count;
                _out.spread_x = _effect_visual_profile.spread_x;
                _out.spread_y = _effect_visual_profile.spread_y;
                _out.speed_x = _effect_visual_profile.speed_x;
                _out.speed_y = _effect_visual_profile.speed_y;
                _out.gravity = _effect_visual_profile.gravity;
                _out.from_user = _effect_visual_profile.from_user;
                if (variable_struct_exists(_effect_visual_profile, "anchor")) _out.anchor = string(variable_struct_get(_effect_visual_profile, "anchor"));
                _out.duration = __battle_anim_duration_for_family(_out.family, _effect_visual_profile.duration);
                if (is_real(_effect_visual_profile.duration)) _out.duration = max(_out.duration, floor(_effect_visual_profile.duration));
            }
            // Allow callers to provide a bespoke move visual (for example the
            // pre-turn confusion orbit) instead of relying solely on move-id-derived effects.
            if (variable_struct_exists(_spec, "visual_kind")) _out.visual_kind = variable_struct_get(_spec, "visual_kind");
            if (variable_struct_exists(_spec, "sprite")) _out.sprite = variable_struct_get(_spec, "sprite");
            if (variable_struct_exists(_spec, "scale") && is_real(variable_struct_get(_spec, "scale"))) _out.scale = real(variable_struct_get(_spec, "scale"));
            if (variable_struct_exists(_spec, "offset_x") && is_real(variable_struct_get(_spec, "offset_x"))) _out.offset_x = variable_struct_get(_spec, "offset_x");
            if (variable_struct_exists(_spec, "offset_y") && is_real(variable_struct_get(_spec, "offset_y"))) _out.offset_y = variable_struct_get(_spec, "offset_y");
            if (variable_struct_exists(_spec, "orbit_count") && is_real(variable_struct_get(_spec, "orbit_count"))) _out.orbit_count = floor(variable_struct_get(_spec, "orbit_count"));
            if (variable_struct_exists(_spec, "orbit_radius_x") && is_real(variable_struct_get(_spec, "orbit_radius_x"))) _out.orbit_radius_x = variable_struct_get(_spec, "orbit_radius_x");
            if (variable_struct_exists(_spec, "orbit_radius_y") && is_real(variable_struct_get(_spec, "orbit_radius_y"))) _out.orbit_radius_y = variable_struct_get(_spec, "orbit_radius_y");
            if (variable_struct_exists(_spec, "spin_speed") && is_real(variable_struct_get(_spec, "spin_speed"))) _out.spin_speed = real(variable_struct_get(_spec, "spin_speed"));
            if (variable_struct_exists(_spec, "tint") && is_real(variable_struct_get(_spec, "tint"))) _out.tint = variable_struct_get(_spec, "tint");
            if (variable_struct_exists(_spec, "particle_kind")) _out.particle_kind = string(variable_struct_get(_spec, "particle_kind"));
            if (variable_struct_exists(_spec, "particle_count") && is_real(variable_struct_get(_spec, "particle_count"))) _out.particle_count = floor(variable_struct_get(_spec, "particle_count"));
            if (variable_struct_exists(_spec, "spread_x") && is_real(variable_struct_get(_spec, "spread_x"))) _out.spread_x = real(variable_struct_get(_spec, "spread_x"));
            if (variable_struct_exists(_spec, "spread_y") && is_real(variable_struct_get(_spec, "spread_y"))) _out.spread_y = real(variable_struct_get(_spec, "spread_y"));
            if (variable_struct_exists(_spec, "speed_x") && is_real(variable_struct_get(_spec, "speed_x"))) _out.speed_x = real(variable_struct_get(_spec, "speed_x"));
            if (variable_struct_exists(_spec, "speed_y") && is_real(variable_struct_get(_spec, "speed_y"))) _out.speed_y = real(variable_struct_get(_spec, "speed_y"));
            if (variable_struct_exists(_spec, "gravity") && is_real(variable_struct_get(_spec, "gravity"))) _out.gravity = real(variable_struct_get(_spec, "gravity"));
            if (variable_struct_exists(_spec, "from_user")) _out.from_user = (variable_struct_get(_spec, "from_user") == true);
            if (variable_struct_exists(_spec, "anchor")) _out.anchor = string(variable_struct_get(_spec, "anchor"));
            if (variable_struct_exists(_spec, "duration") && is_real(variable_struct_get(_spec, "duration"))) _out.duration = max(1, floor(variable_struct_get(_spec, "duration")));
            var _actor_index_move = undefined;
            if (variable_struct_exists(_spec, "actor") && is_struct(variable_struct_get(_spec, "actor")) && variable_struct_exists(variable_struct_get(_spec, "actor"), "actor_index") && is_real(variable_struct_get(variable_struct_get(_spec, "actor"), "actor_index"))){
                _actor_index_move = variable_struct_get(variable_struct_get(_spec, "actor"), "actor_index");
            }
            _out.focus_index = __battle_anim_queue_clamp_actor_index(_slot, __battle_anim_focus_index_for_family(_out.family, _actor_index_move, _out.target_index));
            _out.duration = __battle_anim_duration_for_family(_out.family, _out.duration);
            break;
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
            // Allow caller to request a specific frame (for multihit icons) and override duration
            if (variable_struct_exists(_spec, "frame") && is_real(variable_struct_get(_spec, "frame"))) _out.frame = floor(variable_struct_get(_spec, "frame"));
            if (variable_struct_exists(_spec, "duration") && is_real(variable_struct_get(_spec, "duration"))) _out.duration = max(1, floor(variable_struct_get(_spec, "duration")));
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
            // Propagate optional actor anchor and use_actor_sprite flag so draw-state can
            // optionally resolve the actor's current art and follow its nudge offsets.
            if (variable_struct_exists(_spec, "actor")) _out.actor = variable_struct_get(_spec, "actor");
            if (variable_struct_exists(_spec, "use_actor_sprite")) _out.use_actor_sprite = variable_struct_get(_spec, "use_actor_sprite");
            break;
        case "sleep_effect":
            // Floating "Z"s that rise and fade above the target while asleep
            _out.channel = "overlay";
            _out.target_index = __battle_anim_queue_resolve_target_index(_slot, _spec);
            _out.sprite = (variable_struct_exists(_spec, "sprite") ? variable_struct_get(_spec, "sprite") : (variable_global_exists("spr_sleep") ? spr_sleep : undefined));
            _out.scale = (variable_struct_exists(_spec, "scale") && is_real(variable_struct_get(_spec, "scale"))) ? real(variable_struct_get(_spec, "scale")) : 1;
            // allow caller to override duration
            if (variable_struct_exists(_spec, "duration") && is_real(variable_struct_get(_spec, "duration"))) _out.duration = max(1, floor(variable_struct_get(_spec, "duration")));
            // initial offsets in logical pixels (start near head)
            var _sx = irandom_range(-6, 6);
            var _sy = irandom_range(-12, -6);
            _out.offset_x = (variable_struct_exists(_spec, "offset_x") && is_real(variable_struct_get(_spec, "offset_x"))) ? variable_struct_get(_spec, "offset_x") : _sx;
            _out.offset_y = (variable_struct_exists(_spec, "offset_y") && is_real(variable_struct_get(_spec, "offset_y"))) ? variable_struct_get(_spec, "offset_y") : _sy;
            // how many logical pixels the Z will rise over the duration
            _out.rise = (variable_struct_exists(_spec, "rise") && is_real(variable_struct_get(_spec, "rise"))) ? variable_struct_get(_spec, "rise") : 22;
            break;
        case "status_apply":
        case "status_inflict":
            _out.status = string_lower(string(variable_struct_exists(_spec, "status") ? variable_struct_get(_spec, "status") : ""));
            if (_out.status == "paralysis" || _out.status == "poison" || _out.status == "toxic"){
                _out.channel = "overlay";
                _out.target_index = __battle_anim_queue_resolve_target_index(_slot, _spec);
                if (variable_struct_exists(_spec, "target")) _out.actor = variable_struct_get(_spec, "target");
                if (variable_struct_exists(_spec, "sprite")) _out.sprite = variable_struct_get(_spec, "sprite");
                else if (_out.status == "paralysis") _out.sprite = __battle_anim_sprite_from_names(["spr_paralyze", "spr_status_paralyze", "spr_anim_paralyze"]);
                else _out.sprite = __battle_anim_sprite_from_names(["spr_poison", "spr_status_poison", "spr_anim_poison_status", "spr_poison_status", "spr_anim_poison"]);
                _out.scale = (variable_struct_exists(_spec, "scale") && is_real(variable_struct_get(_spec, "scale"))) ? real(variable_struct_get(_spec, "scale")) : 1;
                _out.offset_y = (variable_struct_exists(_spec, "offset_y") && is_real(variable_struct_get(_spec, "offset_y"))) ? real(variable_struct_get(_spec, "offset_y")) : -14;
                _out.duration = (variable_struct_exists(_spec, "duration") && is_real(variable_struct_get(_spec, "duration"))) ? max(1, floor(variable_struct_get(_spec, "duration"))) : 560;
            } else {
                _out.channel = "primary";
                _out.target_index = __battle_anim_queue_resolve_target_index(_slot, _spec);
            }
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

        // Preserve optional visual fields from the normalized spec so overlays
        // like hit_effect can carry custom sprite/scale/offset values.
        if (variable_struct_exists(_norm, "sprite")) _entry.sprite = _norm.sprite;
        if (variable_struct_exists(_norm, "scale")) _entry.scale = _norm.scale;
        if (variable_struct_exists(_norm, "offset_x")) _entry.offset_x = _norm.offset_x;
        if (variable_struct_exists(_norm, "offset_y")) _entry.offset_y = _norm.offset_y;
        if (variable_struct_exists(_norm, "slide_dir")) _entry.slide_dir = _norm.slide_dir;
        if (variable_struct_exists(_norm, "slide_mag")) _entry.slide_mag = _norm.slide_mag;
        if (variable_struct_exists(_norm, "actor")) _entry.actor = _norm.actor;
        if (variable_struct_exists(_norm, "use_actor_sprite")) _entry.use_actor_sprite = _norm.use_actor_sprite;
        if (variable_struct_exists(_norm, "visual_kind")) _entry.visual_kind = _norm.visual_kind;
        if (variable_struct_exists(_norm, "orbit_count")) _entry.orbit_count = _norm.orbit_count;
        if (variable_struct_exists(_norm, "orbit_radius_x")) _entry.orbit_radius_x = _norm.orbit_radius_x;
        if (variable_struct_exists(_norm, "orbit_radius_y")) _entry.orbit_radius_y = _norm.orbit_radius_y;
        if (variable_struct_exists(_norm, "spin_speed")) _entry.spin_speed = _norm.spin_speed;
        if (variable_struct_exists(_norm, "tint")) _entry.tint = _norm.tint;
        if (variable_struct_exists(_norm, "particle_kind")) _entry.particle_kind = _norm.particle_kind;
        if (variable_struct_exists(_norm, "particle_count")) _entry.particle_count = _norm.particle_count;
        if (variable_struct_exists(_norm, "spread_x")) _entry.spread_x = _norm.spread_x;
        if (variable_struct_exists(_norm, "spread_y")) _entry.spread_y = _norm.spread_y;
        if (variable_struct_exists(_norm, "speed_x")) _entry.speed_x = _norm.speed_x;
        if (variable_struct_exists(_norm, "speed_y")) _entry.speed_y = _norm.speed_y;
        if (variable_struct_exists(_norm, "gravity")) _entry.gravity = _norm.gravity;
        if (variable_struct_exists(_norm, "from_user")) _entry.from_user = _norm.from_user;
        if (variable_struct_exists(_norm, "anchor")) _entry.anchor = _norm.anchor;
        if (variable_struct_exists(_norm, "move_id")) _entry.move_id = _norm.move_id;
        if (variable_struct_exists(_norm, "effect_id")) _entry.effect_id = _norm.effect_id;
        if (variable_struct_exists(_norm, "family")) _entry.family = _norm.family;
        if (variable_struct_exists(_norm, "status")) _entry.status = _norm.status;
        // Allow callers to provide a base alpha for overlays so we can fade them independently
        if (variable_struct_exists(_norm, "alpha")) _entry.alpha = variable_struct_get(_norm, "alpha");
    // (alpha is computed by the draw-state for most overlays; no explicit copy needed)

        if ((_entry.type == "status_apply" || _entry.type == "status_inflict") && variable_struct_exists(_entry, "status")){
            var _entry_status = string_lower(string(variable_struct_get(_entry, "status")));
            if (_entry_status != "paralysis" && _entry_status != "poison" && _entry_status != "toxic"){
                array_push(_aq.overlays, _entry);
                return;
            }
            try {
                var _actor_par = undefined;
                if (variable_struct_exists(_entry, "actor") && is_struct(variable_struct_get(_entry, "actor"))) _actor_par = variable_struct_get(_entry, "actor");
                else if (variable_struct_exists(_slot, "actor") && is_array(variable_struct_get(_slot, "actor")) && is_real(_entry.target_index)){
                    var _actors_par = variable_struct_get(_slot, "actor");
                    var _idx_par = floor(_entry.target_index);
                    if (_idx_par >= 0 && _idx_par < array_length(_actors_par)) _actor_par = _actors_par[_idx_par];
                }
                if (is_struct(_actor_par)){
                    variable_struct_set(_actor_par, "_nudge_active", true);
                    variable_struct_set(_actor_par, "_nudge_start_ms", current_time);
                    variable_struct_set(_actor_par, "_nudge_dur", _entry.duration);
                    variable_struct_set(_actor_par, "_nudge_mag", 5);
                    variable_struct_set(_actor_par, "_nudge_dir", ((__battle_actor_side(_entry.target_index) == 0) ? 1 : -1));
                }
                if (_entry_status == "paralysis" && is_struct(_actor_par)){
                    variable_struct_set(_actor_par, "_nudge_active", true);
                    variable_struct_set(_actor_par, "_nudge_start_ms", current_time);
                    variable_struct_set(_actor_par, "_nudge_dur", _entry.duration);
                    variable_struct_set(_actor_par, "_nudge_mag", 5);
                    variable_struct_set(_actor_par, "_nudge_dir", ((__battle_actor_side(_entry.target_index) == 0) ? 1 : -1));
                }
            } catch (e_par_nudge) {}
        }

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
    var _B = __battle_ensure_slot(_pid);
    try {
        if (is_struct(_B) && variable_struct_exists(_B, "actor") && is_array(variable_struct_get(_B, "actor"))){
            var _actors_center = variable_struct_get(_B, "actor");
            if (_idx >= 0 && _idx < array_length(_actors_center)){
                var _actor_center = _actors_center[_idx];
                if (is_struct(_actor_center)
                    && variable_struct_exists(_actor_center, "_render_center_x") && is_real(variable_struct_get(_actor_center, "_render_center_x"))
                    && variable_struct_exists(_actor_center, "_render_center_y") && is_real(variable_struct_get(_actor_center, "_render_center_y"))){
                    return [variable_struct_get(_actor_center, "_render_center_x"), variable_struct_get(_actor_center, "_render_center_y")];
                }
            }
        }
    } catch (e_render_center) {}
    if (is_struct(_B) && !is_undefined(__battle_get_actor_scene_anchor)){
        var _anchor = __battle_get_actor_scene_anchor(_pid, _B, _idx);
        if (is_struct(_anchor) && variable_struct_exists(_anchor, "battler")){
            var _pt = variable_struct_get(_anchor, "battler");
            if (is_array(_pt) && array_length(_pt) >= 2) return [_pt[0], _pt[1]];
        }
    }
    var _side = __battle_actor_side(_idx);
    var _xlog = (_side == 1 ? 165 : 64);
    var _ylog = (_side == 1 ? 40 : 112);
    var _cx = __battle_anim_queue_xu(_pid, _xlog);
    var _cy = __battle_anim_queue_yu(_pid, _ylog);
    return [_cx, _cy];
}

function __battle_anim_queue_actor_sprite_spec(_pid, _idx){
    var _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B) || !variable_struct_exists(_B, "actor") || !is_array(variable_struct_get(_B, "actor"))) return undefined;
    var _actors = variable_struct_get(_B, "actor");
    if (_idx < 0 || _idx >= array_length(_actors)) return undefined;
    var _actor = _actors[_idx];
    if (!is_struct(_actor) || !variable_struct_exists(_actor, "mon")) return undefined;
    if (is_undefined(pkicons_get_art96_by_mon) || is_undefined(pkicons_get_art96_subimg_by_mon)) return undefined;

    var _spr = pkicons_get_art96_by_mon(variable_struct_get(_actor, "mon"));
    if (is_undefined(_spr) || !sprite_exists(_spr)) return undefined;

    var _side = __battle_actor_side(_idx);
    try {
        if (!is_undefined(__battle_actor_view_side_slot)){
            var _view = __battle_actor_view_side_slot(_pid, _idx);
            if (is_struct(_view) && variable_struct_exists(_view, "side")) _side = variable_struct_get(_view, "side");
        }
    } catch (e_view_side) {}

    var _sub = 0;
    try { _sub = pkicons_get_art96_subimg_by_mon(variable_struct_get(_actor, "mon"), _side == 0); } catch (e_sub_spec) { _sub = 0; }

    var _ui_s = 1;
    try {
        if (variable_struct_exists(_B, "_ui") && is_struct(variable_struct_get(_B, "_ui"))){
            var _ui = variable_struct_get(_B, "_ui");
            if (variable_struct_exists(_ui, "s") && is_real(variable_struct_get(_ui, "s"))) _ui_s = max(1, real(variable_struct_get(_ui, "s")));
        }
    } catch (e_ui_spec) { _ui_s = 1; }

    var _anchor = undefined;
    try {
        if (!is_undefined(__battle_get_actor_scene_anchor)) _anchor = __battle_get_actor_scene_anchor(_pid, _B, _idx);
    } catch (e_anchor_spec) { _anchor = undefined; }

    var _center = __battle_anim_queue_actor_center(_pid, _idx);
    var _pt = (is_struct(_anchor) && variable_struct_exists(_anchor, "battler")) ? variable_struct_get(_anchor, "battler") : _center;
    if (!is_array(_pt) || array_length(_pt) < 2) return undefined;

    var _scale_mult = (is_struct(_anchor) && variable_struct_exists(_anchor, "scale_mult") && is_real(variable_struct_get(_anchor, "scale_mult"))) ? real(variable_struct_get(_anchor, "scale_mult")) : 1;
    var _draw_scale = ((_side == 0) ? 1.1 : 1.0) * _scale_mult * _ui_s;
    var _draw_scale_x = _draw_scale;
    var _draw_scale_y = _draw_scale;
    var _spr_w = sprite_get_width(_spr);
    var _spr_h = sprite_get_height(_spr);
    var _origin_x = sprite_get_xoffset(_spr);
    var _origin_y = sprite_get_yoffset(_spr);
    var _platform_bottom = _pt[1] + (_spr_h * _draw_scale) * 0.5;
    var _draw_x = _pt[0] + (_origin_x - (_spr_w * 0.5)) * _draw_scale;
    var _draw_y = _platform_bottom - (_spr_h - _origin_y) * _draw_scale;

    try {
        if (variable_struct_exists(_actor, "_render_draw_x") && is_real(variable_struct_get(_actor, "_render_draw_x")) &&
            variable_struct_exists(_actor, "_render_draw_y") && is_real(variable_struct_get(_actor, "_render_draw_y"))){
            _draw_x = variable_struct_get(_actor, "_render_draw_x");
            _draw_y = variable_struct_get(_actor, "_render_draw_y");
            if (variable_struct_exists(_actor, "_render_scale_x") && is_real(variable_struct_get(_actor, "_render_scale_x"))) _draw_scale_x = variable_struct_get(_actor, "_render_scale_x");
            if (variable_struct_exists(_actor, "_render_scale_y") && is_real(variable_struct_get(_actor, "_render_scale_y"))) _draw_scale_y = variable_struct_get(_actor, "_render_scale_y");
        }
    } catch (e_render_spec) {}

    return {
        sprite: _spr,
        subimg: _sub,
        draw_x: _draw_x,
        draw_y: _draw_y,
        scale_x: _draw_scale_x,
        scale_y: _draw_scale_y,
        width_px: _spr_w * _draw_scale_x,
        height_px: _spr_h * _draw_scale_y,
        side: _side
    };
}

function __battle_anim_queue_stat_overlay_surface(_B, _want_w, _want_h){
    if (!is_struct(_B)) return -1;
    var _surf_w = max(8, ceil(_want_w));
    var _surf_h = max(8, ceil(_want_h));
    var _surf = (variable_struct_exists(_B, "_stat_overlay_mask_surface") ? variable_struct_get(_B, "_stat_overlay_mask_surface") : -1);
    var _reuse = false;
    if (surface_exists(_surf)){
        try {
            if (surface_get_width(_surf) == _surf_w && surface_get_height(_surf) == _surf_h) _reuse = true;
            else surface_free(_surf);
        } catch (e_surf_size) {
            _reuse = false;
            try { if (surface_exists(_surf)) surface_free(_surf); } catch (e_surf_free) {}
        }
    }
    if (!_reuse){
        _surf = surface_create(_surf_w, _surf_h);
        if (surface_exists(_surf)) variable_struct_set(_B, "_stat_overlay_mask_surface", _surf);
    }
    return _surf;
}

function __battle_anim_queue_draw_stat_overlay_stencil(_pid, _st, _actor_spec){
    if (!is_struct(_st) || !is_struct(_actor_spec)) return false;
    var _prog = clamp((variable_struct_exists(_st, "progress") ? variable_struct_get(_st, "progress") : 0), 0, 1);
    var _dir = (variable_struct_exists(_st, "direction") && is_real(variable_struct_get(_st, "direction"))) ? variable_struct_get(_st, "direction") : 0;
    var _alpha = clamp(0.72 * (1 - (_prog * 0.28)), 0, 1);

    var _spr = variable_struct_get(_actor_spec, "sprite");
    var _sub = variable_struct_get(_actor_spec, "subimg");
    var _draw_x = variable_struct_get(_actor_spec, "draw_x");
    var _draw_y = variable_struct_get(_actor_spec, "draw_y");
    var _scale_x = (variable_struct_exists(_actor_spec, "scale_x") && is_real(variable_struct_get(_actor_spec, "scale_x"))) ? variable_struct_get(_actor_spec, "scale_x") : 1;
    var _scale_y = (variable_struct_exists(_actor_spec, "scale_y") && is_real(variable_struct_get(_actor_spec, "scale_y"))) ? variable_struct_get(_actor_spec, "scale_y") : _scale_x;
    var _src_w = sprite_get_width(_spr);
    var _src_h = sprite_get_height(_spr);
    if (_src_w <= 0 || _src_h <= 0 || !sprite_exists(spr_stateffects)) return false;

    var _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B)) return false;

    var _pad_x = max(6, ceil(__battle_anim_queue_wu(_pid, 8, 8)));
    var _pad_y = max(6, ceil(__battle_anim_queue_hu(_pid, 8, 8)));
    var _surf_w = max(8, ceil(variable_struct_get(_actor_spec, "width_px")) + (_pad_x * 2));
    var _surf_h = max(8, ceil(variable_struct_get(_actor_spec, "height_px")) + (_pad_y * 2));
    var _surf = __battle_anim_queue_stat_overlay_surface(_B, _surf_w, _surf_h);
    if (!surface_exists(_surf)) return false;

    var _surf_x = floor(_draw_x - _pad_x);
    var _surf_y = floor(_draw_y - _pad_y);
    var _local_x = _draw_x - _surf_x;
    var _local_y = _draw_y - _surf_y;

    var _frame = (variable_struct_exists(_st, "frame") && is_real(variable_struct_get(_st, "frame"))) ? clamp(floor(variable_struct_get(_st, "frame")), 0, max(0, sprite_get_number(spr_stateffects) - 1)) : 0;
    var _tile_w = __battle_anim_queue_wu(_pid, 32, 32);
    var _tile_h = __battle_anim_queue_hu(_pid, 32, 32);
    var _tile_scale_x = _tile_w / max(1, sprite_get_width(spr_stateffects));
    var _tile_scale_y = _tile_h / max(1, sprite_get_height(spr_stateffects));
    var _loops = (variable_struct_exists(_st, "bg_loops") && is_real(variable_struct_get(_st, "bg_loops"))) ? max(1, floor(variable_struct_get(_st, "bg_loops"))) : 2;
    var _loop_prog = _prog * (_loops * 0.55);
    var _frac = _loop_prog - floor(_loop_prog);
    var _scroll_y = 0;
    if (_dir > 0) _scroll_y = -(_frac * _tile_h);
    else if (_dir < 0) _scroll_y = (_frac * _tile_h);

    surface_set_target(_surf);
    draw_clear_alpha(c_black, 0);
    gpu_set_blendmode(bm_normal);
    draw_set_color(c_white);
    draw_set_alpha(1);
    draw_sprite_ext(_spr, _sub, _local_x, _local_y, _scale_x, _scale_y, 0, c_white, 1);

    gpu_set_blendmode_ext(bm_dest_alpha, bm_zero);
    draw_set_color(c_white);
    draw_set_alpha(_alpha);
    var _start_x = -_tile_w;
    var _start_y = _scroll_y - _tile_h;
    var _end_x = _surf_w + _tile_w;
    var _end_y = _surf_h + _tile_h;
    for (var _tx = _start_x; _tx <= _end_x; _tx += _tile_w){
        for (var _ty = _start_y; _ty <= _end_y; _ty += _tile_h){
            draw_sprite_ext(spr_stateffects, _frame, _tx + (_tile_w * 0.5), _ty + (_tile_h * 0.5), _tile_scale_x, _tile_scale_y, 0, c_white, _alpha);
        }
    }
    gpu_set_blendmode(bm_normal);
    draw_set_alpha(1);
    draw_set_color(c_white);
    surface_reset_target();

    draw_surface(_surf, _surf_x, _surf_y);
    gpu_set_blendmode(bm_normal);
    draw_set_alpha(1);
    draw_set_color(c_white);
    return true;
}

function __battle_anim_queue_build_draw_state(_pid, _slot, _entry){
    if (!is_struct(_entry)) return undefined;
    var _type = string(_entry.type);
    var _prog = clamp((variable_struct_exists(_entry, "progress") ? _entry.progress : 0), 0, 1);
    if (_type == "move" && variable_struct_exists(_entry, "visual_kind")){
        var _visual_kind = string(_entry.visual_kind);
        var _idx_fx = (variable_struct_exists(_entry, "target_index") && is_real(_entry.target_index)) ? floor(_entry.target_index) : 0;
        var _sprite_fx = (variable_struct_exists(_entry, "sprite")) ? _entry.sprite : undefined;
        var _scale_fx = (variable_struct_exists(_entry, "scale") && is_real(_entry.scale)) ? real(_entry.scale) : 1;
        var _offset_x_fx = (variable_struct_exists(_entry, "offset_x") && is_real(_entry.offset_x)) ? __battle_anim_queue_wu(_pid, _entry.offset_x, _entry.offset_x) : 0;
        var _offset_y_fx = (variable_struct_exists(_entry, "offset_y") && is_real(_entry.offset_y)) ? __battle_anim_queue_hu(_pid, _entry.offset_y, _entry.offset_y) : 0;
        var _tint_fx = (variable_struct_exists(_entry, "tint") && is_real(_entry.tint)) ? _entry.tint : c_white;

        if (_visual_kind == "confused_ducks"){
            if (is_undefined(_sprite_fx)) _sprite_fx = __battle_anim_sprite_from_names(["spr_confused"]);
            return {
                kind: "sprite_orbit",
                target_index: _idx_fx,
                sprite: _sprite_fx,
                progress: _prog,
                alpha: 1 - max(0, (_prog - 0.82) / 0.18),
                scale: _scale_fx,
                offset_x: _offset_x_fx,
                offset_y: _offset_y_fx,
                orbit_count: (variable_struct_exists(_entry, "orbit_count") && is_real(_entry.orbit_count)) ? floor(_entry.orbit_count) : 3,
                orbit_radius_x: (variable_struct_exists(_entry, "orbit_radius_x") && is_real(_entry.orbit_radius_x)) ? __battle_anim_queue_wu(_pid, _entry.orbit_radius_x, _entry.orbit_radius_x) : __battle_anim_queue_wu(_pid, 22, 22),
                orbit_radius_y: (variable_struct_exists(_entry, "orbit_radius_y") && is_real(_entry.orbit_radius_y)) ? __battle_anim_queue_hu(_pid, _entry.orbit_radius_y, _entry.orbit_radius_y) : __battle_anim_queue_hu(_pid, 8, 8),
                spin_speed: (variable_struct_exists(_entry, "spin_speed") && is_real(_entry.spin_speed)) ? real(_entry.spin_speed) : 1.35,
                tint: _tint_fx
            };
        }

        if (_visual_kind == "sprite_overlay"){
            var _spr_count_fx = 1;
            try { if (!is_undefined(_sprite_fx) && sprite_exists(_sprite_fx)) _spr_count_fx = max(1, sprite_get_number(_sprite_fx)); } catch (_sprite_count_error) { _spr_count_fx = 1; }
            var _frame_fx = clamp(floor(_prog * _spr_count_fx), 0, max(0, _spr_count_fx - 1));
            return {
                kind: "sprite_overlay",
                target_index: _idx_fx,
                sprite: _sprite_fx,
                frame: _frame_fx,
                scale: _scale_fx,
                alpha: 1 - max(0, (_prog - 0.70) / 0.30),
                progress: _prog,
                offset_x: _offset_x_fx,
                offset_y: _offset_y_fx,
                slide_dir: 0,
                slide_mag: 0,
                tint: _tint_fx
            };
        }

        if (_visual_kind == "sprite_projectile"){
            var _src_idx_proj = undefined;
            try {
                if (variable_struct_exists(_entry, "actor") && is_struct(variable_struct_get(_entry, "actor"))) _src_idx_proj = __battle_anim_queue_find_actor_index_by_ref(_slot, variable_struct_get(_entry, "actor"));
            } catch (e_src_idx_proj) { _src_idx_proj = undefined; }
            try {
                if (!is_real(_src_idx_proj) && variable_struct_exists(_entry, "actor") && is_struct(variable_struct_get(_entry, "actor"))){
                    var _actor_proj_ref = variable_struct_get(_entry, "actor");
                    if (variable_struct_exists(_actor_proj_ref, "actor_index") && is_real(variable_struct_get(_actor_proj_ref, "actor_index"))) _src_idx_proj = floor(variable_struct_get(_actor_proj_ref, "actor_index"));
                }
            } catch (e_src_idx_proj_field) {}
            var _spr_count_proj = 1;
            try { if (!is_undefined(_sprite_fx) && sprite_exists(_sprite_fx)) _spr_count_proj = max(1, sprite_get_number(_sprite_fx)); } catch (_sprite_proj_count_error) { _spr_count_proj = 1; }
            var _frame_proj = clamp(floor(_prog * _spr_count_proj * 1.25), 0, max(0, _spr_count_proj - 1));
            return {
                kind: "sprite_projectile",
                target_index: _idx_fx,
                source_index: _src_idx_proj,
                sprite: _sprite_fx,
                frame: _frame_proj,
                scale: _scale_fx,
                alpha: 1 - max(0, (_prog - 0.84) / 0.16),
                progress: _prog,
                offset_x: _offset_x_fx,
                offset_y: _offset_y_fx,
                tint: _tint_fx
            };
        }

        if (_visual_kind == "particle_burst"){
            var _src_idx_fx = undefined;
            try {
                if (variable_struct_exists(_entry, "actor") && is_struct(variable_struct_get(_entry, "actor"))) _src_idx_fx = __battle_anim_queue_find_actor_index_by_ref(_slot, variable_struct_get(_entry, "actor"));
            } catch (e_src_idx_fx) { _src_idx_fx = undefined; }
            var _from_user_fx = (variable_struct_exists(_entry, "from_user") && variable_struct_get(_entry, "from_user") == true);
            return {
                kind: "particle_burst",
                target_index: _idx_fx,
                source_index: _src_idx_fx,
                from_user: _from_user_fx,
                sprite: _sprite_fx,
                progress: _prog,
                alpha: 1 - max(0, (_prog - 0.72) / 0.28),
                scale: _scale_fx,
                offset_x: _offset_x_fx,
                offset_y: _offset_y_fx,
                tint: _tint_fx,
                particle_kind: (variable_struct_exists(_entry, "particle_kind") ? string(variable_struct_get(_entry, "particle_kind")) : "spark"),
                particle_count: (variable_struct_exists(_entry, "particle_count") && is_real(variable_struct_get(_entry, "particle_count"))) ? max(1, floor(variable_struct_get(_entry, "particle_count"))) : 10,
                spread_x: (variable_struct_exists(_entry, "spread_x") && is_real(variable_struct_get(_entry, "spread_x"))) ? __battle_anim_queue_wu(_pid, variable_struct_get(_entry, "spread_x"), variable_struct_get(_entry, "spread_x")) : __battle_anim_queue_wu(_pid, 18, 18),
                spread_y: (variable_struct_exists(_entry, "spread_y") && is_real(variable_struct_get(_entry, "spread_y"))) ? __battle_anim_queue_hu(_pid, variable_struct_get(_entry, "spread_y"), variable_struct_get(_entry, "spread_y")) : __battle_anim_queue_hu(_pid, 14, 14),
                speed_x: (variable_struct_exists(_entry, "speed_x") && is_real(variable_struct_get(_entry, "speed_x"))) ? __battle_anim_queue_wu(_pid, variable_struct_get(_entry, "speed_x"), variable_struct_get(_entry, "speed_x")) : 0,
                speed_y: (variable_struct_exists(_entry, "speed_y") && is_real(variable_struct_get(_entry, "speed_y"))) ? __battle_anim_queue_hu(_pid, variable_struct_get(_entry, "speed_y"), variable_struct_get(_entry, "speed_y")) : __battle_anim_queue_hu(_pid, -10, -10),
                gravity: (variable_struct_exists(_entry, "gravity") && is_real(variable_struct_get(_entry, "gravity"))) ? __battle_anim_queue_hu(_pid, variable_struct_get(_entry, "gravity"), variable_struct_get(_entry, "gravity")) : 0,
                move_id: (variable_struct_exists(_entry, "move_id") && is_real(variable_struct_get(_entry, "move_id"))) ? floor(variable_struct_get(_entry, "move_id")) : -1
            };
        }
    }
    if (_type == "move"){
        var _family_mv = string_lower(string(variable_struct_exists(_entry, "family") ? variable_struct_get(_entry, "family") : "damage"));
        var _focus_mv = (variable_struct_exists(_entry, "focus_index") && is_real(variable_struct_get(_entry, "focus_index"))) ? __battle_anim_queue_clamp_actor_index(_slot, variable_struct_get(_entry, "focus_index")) : ((variable_struct_exists(_entry, "target_index") && is_real(variable_struct_get(_entry, "target_index"))) ? __battle_anim_queue_clamp_actor_index(_slot, variable_struct_get(_entry, "target_index")) : 0);
        var _color_mv = (variable_struct_exists(_entry, "color") ? variable_struct_get(_entry, "color") : __battle_anim_color_for_family(_family_mv));
        switch (_family_mv){
            case "field":
            case "barrier":
            case "terrain":
                return { kind: "field_overlay", side: "full", color: _color_mv, alpha: 0.34 * (1 - _prog * 0.45), progress: _prog };
            case "hazard":
                return { kind: "hazard_overlay", side: "full", color: _color_mv, alpha: 0.48 * (1 - _prog * 0.35), progress: _prog };
            case "weather":
                return { kind: "weather_overlay", color: _color_mv, alpha: 0.34 * (1 - _prog * 0.35), progress: _prog };
            case "damage":
                return { kind: "actor_glow", target_index: _focus_mv, color: _color_mv, alpha: 0.28 * (1 - _prog * 0.5), radius: __battle_anim_queue_wu(_pid, 36), progress: _prog };
            case "fixed_damage":
                return { kind: "actor_glow", target_index: _focus_mv, color: _color_mv, alpha: 0.34 * (1 - _prog * 0.42), radius: __battle_anim_queue_wu(_pid, 40), progress: _prog };
            case "status":
            case "trap":
            case "stat":
            case "lock":
                return { kind: "actor_glow", target_index: _focus_mv, color: _color_mv, alpha: 0.38 * (1 - _prog * 0.48), radius: __battle_anim_queue_wu(_pid, 42), progress: _prog };
            case "heal":
            case "drain":
            case "support":
                return { kind: "actor_glow", target_index: _focus_mv, color: _color_mv, alpha: 0.34 * (1 - _prog * 0.55), radius: __battle_anim_queue_wu(_pid, 40), progress: _prog };
            case "recoil":
            case "counter":
            case "self_destruct":
                return { kind: "actor_glow", target_index: _focus_mv, color: _color_mv, alpha: 0.42 * (1 - _prog * 0.42), radius: __battle_anim_queue_wu(_pid, 46), progress: _prog };
            case "copy":
            case "transform":
            case "charge":
            case "guard":
            case "switch":
                return { kind: "actor_glow", target_index: _focus_mv, color: _color_mv, alpha: 0.36 * (1 - _prog * 0.5), radius: __battle_anim_queue_wu(_pid, 44), progress: _prog };
        }
    }
    if (_type == "stat_overlay"){
        var _idx_so = (variable_struct_exists(_entry, "target_index") && is_real(_entry.target_index)) ? floor(_entry.target_index) : 0;
        var _target_indexes_so = (variable_struct_exists(_entry, "target_indexes") && is_array(_entry.target_indexes)) ? _entry.target_indexes : undefined;
        var _frame_so = (variable_struct_exists(_entry, "frame") && is_real(_entry.frame)) ? clamp(floor(_entry.frame), 0, 7) : 0;
        var _darken_so = (variable_struct_exists(_entry, "darken") && _entry.darken);
        // Include optional fields so draw code can access bg mode, direction and loop count
        var _bg_so = (variable_struct_exists(_entry, "bg") && _entry.bg);
        var _dir_so = (variable_struct_exists(_entry, "direction") && is_real(_entry.direction)) ? _entry.direction : 0;
        var _stat_keys_so = (variable_struct_exists(_entry, "stat_keys") ? _entry.stat_keys : undefined);
        var _stat_deltas_so = (variable_struct_exists(_entry, "stat_deltas") ? _entry.stat_deltas : undefined);
        var _bg_loops_so = (variable_struct_exists(_entry, "bg_loops") && is_real(_entry.bg_loops)) ? max(0, floor(_entry.bg_loops)) : undefined;
        return { kind: "stat_overlay", target_index: _idx_so, target_indexes: _target_indexes_so, frame: _frame_so, darken: _darken_so, progress: _prog, bg: _bg_so, direction: _dir_so, stat_keys: _stat_keys_so, stat_deltas: _stat_deltas_so, bg_loops: _bg_loops_so };
    }
        if (_type == "hit_effect"){
        var _idx_he = (variable_struct_exists(_entry, "target_index") && is_real(_entry.target_index)) ? floor(_entry.target_index) : 0;
        var _sprite_he = (variable_struct_exists(_entry, "sprite") && !is_undefined(_entry.sprite)) ? _entry.sprite : spr_hiteffect;
        var _spr_count_he = 1;
        try { if (is_undefined(_sprite_he) == false && sprite_exists(_sprite_he)) _spr_count_he = max(1, sprite_get_number(_sprite_he)); } catch (e_sp) { _spr_count_he = 1; }
        var _frame_he = 0;
        if (variable_struct_exists(_entry, "frame") && is_real(_entry.frame)){
            _frame_he = clamp(floor(_entry.frame), 0, max(0, _spr_count_he - 1));
        } else {
            _frame_he = clamp(floor(_prog * _spr_count_he), 0, max(0, _spr_count_he - 1));
        }
        // If requested, resolve the actor's current art sprite/subimage at draw time
        try {
            if (variable_struct_exists(_entry, "use_actor_sprite") && variable_struct_get(_entry, "use_actor_sprite") == true && variable_struct_exists(_entry, "actor") && is_struct(variable_struct_get(_entry, "actor"))){
                var _actor_spec = variable_struct_get(_entry, "actor");
                var _mon_for_sprite = undefined;
                try { if (variable_struct_exists(_actor_spec, "mon")) _mon_for_sprite = variable_struct_get(_actor_spec, "mon"); else _mon_for_sprite = _actor_spec; } catch (e_mfs) { _mon_for_sprite = undefined; }
                if (!is_undefined(_mon_for_sprite) && !is_undefined(pkicons_get_art96_by_mon) && !is_undefined(pkicons_get_art96_subimg_by_mon)){
                    try {
                        var _spr_res = pkicons_get_art96_by_mon(_mon_for_sprite);
                        if (!is_undefined(_spr_res) && sprite_exists(_spr_res)){
                            _sprite_he = _spr_res;
                            var _is_player_actor = (variable_struct_exists(_actor_spec, "actor_index") && is_real(variable_struct_get(_actor_spec, "actor_index")) && variable_struct_get(_actor_spec, "actor_index") == 0);
                            try { _frame_he = pkicons_get_art96_subimg_by_mon(_mon_for_sprite, _is_player_actor); } catch (e_rsf) { _frame_he = 0; }
                        }
                    } catch (e_resact) {}
                }
            }
        } catch (e_usea) {}
        var _scale_he = (variable_struct_exists(_entry, "scale") && is_real(_entry.scale)) ? _entry.scale : 1;
        // Compute alpha using an optional base alpha and an eased fade so afterimages fade faster
        var _alpha_base = (variable_struct_exists(_entry, "alpha") && is_real(variable_struct_get(_entry, "alpha"))) ? clamp(variable_struct_get(_entry, "alpha"), 0, 1) : 1;
        var _alpha_he = _alpha_base * (1 - power(_prog, 1.8));
    // Offsets in the normalized spec are provided in logical pixels; convert
    // to UI pixels here so overlays are positioned relative to the actor
    // center correctly under different UI scales.
    var _offx_he = 0;
    var _offy_he = 0;
    if (variable_struct_exists(_entry, "offset_x") && is_real(_entry.offset_x)) _offx_he = __battle_anim_queue_wu(_pid, _entry.offset_x, _entry.offset_x);
    if (variable_struct_exists(_entry, "offset_y") && is_real(_entry.offset_y)) _offy_he = __battle_anim_queue_hu(_pid, _entry.offset_y, _entry.offset_y);
    // If the spec provided an `actor` struct with nudge data, add that actor's current nudge
    // so overlays anchored to the actor follow its movement.
    try {
        if (variable_struct_exists(_entry, "actor") && is_struct(variable_struct_get(_entry, "actor"))){
            var _actor_obj = variable_struct_get(_entry, "actor");
            if (is_struct(_actor_obj) && variable_struct_exists(_actor_obj, "_nudge_active") && variable_struct_get(_actor_obj, "_nudge_active") == true){
                var _ns_a = (variable_struct_exists(_actor_obj, "_nudge_start_ms") ? variable_struct_get(_actor_obj, "_nudge_start_ms") : 0);
                var _nd_a = (variable_struct_exists(_actor_obj, "_nudge_dur") ? variable_struct_get(_actor_obj, "_nudge_dur") : 0);
                var _nm_a = (variable_struct_exists(_actor_obj, "_nudge_mag") ? variable_struct_get(_actor_obj, "_nudge_mag") : 0);
                var _ndir_a = (variable_struct_exists(_actor_obj, "_nudge_dir") ? variable_struct_get(_actor_obj, "_nudge_dir") : 0);
                var _now_n_a = current_time;
                var _p_n_a = (_nd_a > 0) ? clamp((_now_n_a - _ns_a) / max(1, _nd_a), 0, 1) : 0;
                var _frac_n_a = (_p_n_a <= 0.5) ? (1 - power(1 - (_p_n_a / 0.5), 2)) : (1 - power(((_p_n_a - 0.5) / 0.5), 2));
                var _nudge_px_a = __battle_anim_queue_wu(_pid, _nm_a) * (_ndir_a) * _frac_n_a;
                _offx_he += _nudge_px_a;
            }
        }
    } catch (e_offn) {}
        var _sdir_he = (variable_struct_exists(_entry, "slide_dir") && is_real(_entry.slide_dir)) ? clamp(_entry.slide_dir, -1, 1) : 0;
        var _smag_he = (variable_struct_exists(_entry, "slide_mag") && is_real(_entry.slide_mag)) ? _entry.slide_mag : 8;
        var _anchor_he = (variable_struct_exists(_entry, "anchor")) ? string(variable_struct_get(_entry, "anchor")) : "";
        return { kind: "sprite_overlay", target_index: _idx_he, sprite: _sprite_he, frame: _frame_he, scale: _scale_he, alpha: _alpha_he, progress: _prog, offset_x: _offx_he, offset_y: _offy_he, slide_dir: _sdir_he, slide_mag: _smag_he, anchor: _anchor_he };
    }
    if (_type == "sleep_effect"){
        var _idx_s = (variable_struct_exists(_entry, "target_index") && is_real(_entry.target_index)) ? floor(_entry.target_index) : 0;
        var _sprite_s = (variable_struct_exists(_entry, "sprite") && !is_undefined(_entry.sprite)) ? _entry.sprite : spr_sleep;
        var _spr_count_s = 1;
        try { if (is_undefined(_sprite_s) == false && sprite_exists(_sprite_s)) _spr_count_s = max(1, sprite_get_number(_sprite_s)); } catch (e_sp2) { _spr_count_s = 1; }
        var _frame_s = 0;
        if (variable_struct_exists(_entry, "frame") && is_real(_entry.frame)){
            _frame_s = clamp(floor(_entry.frame), 0, max(0, _spr_count_s - 1));
        }
        var _scale_s = (variable_struct_exists(_entry, "scale") && is_real(_entry.scale)) ? _entry.scale : 1;
        // alpha fades out over progress
        var _alpha_s = 1 - _prog;
        // Offsets: normalized offsets are logical pixels; convert to UI pixels
        var _offx_s = 0;
        var _offy_s = 0;
        if (variable_struct_exists(_entry, "offset_x") && is_real(_entry.offset_x)) _offx_s = __battle_anim_queue_wu(_pid, _entry.offset_x, _entry.offset_x);
        if (variable_struct_exists(_entry, "offset_y") && is_real(_entry.offset_y)) _offy_s = __battle_anim_queue_hu(_pid, _entry.offset_y, _entry.offset_y);
        // rise distance (logical pixels) converted to UI pixels
        var _rise_s = (variable_struct_exists(_entry, "rise") && is_real(_entry.rise)) ? __battle_anim_queue_hu(_pid, _entry.rise, _entry.rise) : __battle_anim_queue_hu(_pid, 22, 22);
        // Move upward as progress increases
        var _offy_apply = _offy_s - floor(_rise_s * _prog);
        var _sdir_s = (variable_struct_exists(_entry, "slide_dir") && is_real(_entry.slide_dir)) ? clamp(_entry.slide_dir, -1, 1) : 0;
        var _smag_s = (variable_struct_exists(_entry, "slide_mag") && is_real(_entry.slide_mag)) ? _entry.slide_mag : 6;
        return { kind: "sprite_overlay", target_index: _idx_s, sprite: _sprite_s, frame: _frame_s, scale: _scale_s, alpha: _alpha_s, progress: _prog, offset_x: _offx_s, offset_y: _offy_apply, slide_dir: _sdir_s, slide_mag: _smag_s, anchor: "head" };
    }
    if ((_type == "status_apply" || _type == "status_inflict") && variable_struct_exists(_entry, "status")){
        var _status_apply = string_lower(string(variable_struct_get(_entry, "status")));
        if (_status_apply == "paralysis" || _status_apply == "poison" || _status_apply == "toxic"){
            var _idx_pz = (variable_struct_exists(_entry, "target_index") && is_real(_entry.target_index)) ? floor(_entry.target_index) : 0;
            var _sprite_pz = (variable_struct_exists(_entry, "sprite") && !is_undefined(_entry.sprite)) ? _entry.sprite : ((_status_apply == "paralysis") ? spr_paralyze : spr_poison);
            var _spr_count_pz = 1;
            try { if (!is_undefined(_sprite_pz) && sprite_exists(_sprite_pz)) _spr_count_pz = max(1, sprite_get_number(_sprite_pz)); } catch (e_pz_count) { _spr_count_pz = 1; }
            var _frame_pz = clamp(floor(_prog * _spr_count_pz * ((_status_apply == "paralysis") ? 1.2 : 1)), 0, max(0, _spr_count_pz - 1));
            var _scale_pz = (variable_struct_exists(_entry, "scale") && is_real(_entry.scale)) ? real(_entry.scale) : 1;
            var _offset_y_pz = (variable_struct_exists(_entry, "offset_y") && is_real(_entry.offset_y)) ? __battle_anim_queue_hu(_pid, _entry.offset_y, _entry.offset_y) : __battle_anim_queue_hu(_pid, -14, -14);
            var _alpha_pz = 1 - max(0, (_prog - 0.62) / 0.38);
            if (_status_apply == "paralysis"){
                var _flip_phase_pz = floor(_prog * 9) mod 2;
                var _shake_wave_pz = sin(_prog * pi * 8);
                var _offset_x_pz = __battle_anim_queue_wu(_pid, _shake_wave_pz * 3, _shake_wave_pz * 3);
                return {
                    kind: "sprite_overlay",
                    target_index: _idx_pz,
                    sprite: _sprite_pz,
                    frame: _frame_pz,
                    scale_x: ((_flip_phase_pz == 0) ? -_scale_pz : _scale_pz),
                    scale_y: _scale_pz,
                    alpha: _alpha_pz,
                    progress: _prog,
                    offset_x: _offset_x_pz,
                    offset_y: _offset_y_pz,
                    slide_dir: 0,
                    slide_mag: 0,
                    anchor: "head"
                };
            }
            return {
                kind: "sprite_overlay",
                target_index: _idx_pz,
                sprite: _sprite_pz,
                frame: _frame_pz,
                scale: _scale_pz,
                alpha: _alpha_pz,
                progress: _prog,
                offset_x: 0,
                offset_y: _offset_y_pz,
                slide_dir: 0,
                slide_mag: 0,
                anchor: "head"
            };
        }
    }
    if (_type == "stat_change"){
        var _idx = (variable_struct_exists(_entry, "target_index") && is_real(_entry.target_index)) ? floor(_entry.target_index) : 0;
        var _dir = (variable_struct_exists(_entry, "direction") && is_real(_entry.direction)) ? _entry.direction : 0;
    // Use green for stat increases (was a light blue previously). Keep down as orange.
    var _col_up = make_color_rgb(120, 230, 150); // green (stat raise)
    var _col_down = make_color_rgb(255, 168, 84); // orange (stat lower)
    var _col_neutral = make_color_rgb(220, 220, 220);
        var _col_sc = (_dir > 0 ? _col_up : (_dir < 0 ? _col_down : _col_neutral));
    return { kind: "actor_glow", target_index: _idx, color: _col_sc, alpha: 0.45 * (1 - _prog * 0.65), radius: __battle_anim_queue_wu(_pid, 44), progress: _prog };
    }
    if (_type == "stat_change_group"){
        var _idxg = (variable_struct_exists(_entry, "target_index") && is_real(_entry.target_index)) ? floor(_entry.target_index) : 0;
    return { kind: "actor_glow", target_index: _idxg, color: make_color_rgb(248, 220, 120), alpha: 0.4 * (1 - _prog * 0.7), radius: __battle_anim_queue_wu(_pid, 48), progress: _prog };
    }
    if (_type == "heal"){
        var _idxh = (variable_struct_exists(_entry, "target_index") && is_real(_entry.target_index)) ? floor(_entry.target_index) : 0;
    return { kind: "actor_glow", target_index: _idxh, color: make_color_rgb(120, 230, 150), alpha: 0.4 * (1 - _prog * 0.8), radius: __battle_anim_queue_wu(_pid, 42), progress: _prog };
    }
    if (_type == "recoil"){
        var _idxr = (variable_struct_exists(_entry, "target_index") && is_real(_entry.target_index)) ? floor(_entry.target_index) : 0;
    return { kind: "actor_glow", target_index: _idxr, color: make_color_rgb(255, 120, 120), alpha: 0.45 * (1 - _prog * 0.7), radius: __battle_anim_queue_wu(_pid, 40), progress: _prog };
    }
    if (_type == "guard_split" || _type == "imprison" || _type == "cure_party"){
        var _idxs = (variable_struct_exists(_entry, "target_index") && is_real(_entry.target_index)) ? floor(_entry.target_index) : 0;
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
    var _gui_w = display_get_gui_width();
    var _gui_h = display_get_gui_height();
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
    var _center_enemy_arr = __battle_anim_queue_actor_center(_pid, 2);
    var _player_cx_base = (is_array(_center_player_arr) && array_length(_center_player_arr) >= 2) ? _center_player_arr[0] : 0;
    var _player_cy_base = (is_array(_center_player_arr) && array_length(_center_player_arr) >= 2) ? _center_player_arr[1] : 0;
    var _enemy_cx_base = (is_array(_center_enemy_arr) && array_length(_center_enemy_arr) >= 2) ? _center_enemy_arr[0] : 0;
    var _enemy_cy_base = (is_array(_center_enemy_arr) && array_length(_center_enemy_arr) >= 2) ? _center_enemy_arr[1] : 0;
    var _player_cx = _player_cx_base + _offx;
    var _player_cy = _player_cy_base + _offy;
    var _enemy_cx = _enemy_cx_base + _offx;
    var _enemy_cy = _enemy_cy_base + _offy;
    var _ui_scale_anim = __battle_anim_queue_ui_scale(_pid);
    var _full_x1_base = __battle_anim_queue_xu(_pid, 0);
    var _full_y1_base = __battle_anim_queue_yu(_pid, 0);
    var _full_x2_base = __battle_anim_queue_xu(_pid, 240);
    var _full_y2_base = __battle_anim_queue_yu(_pid, 160);
    var _full_x1 = _full_x1_base + _offx;
    var _full_y1 = _full_y1_base + _offy;
    var _full_x2 = _full_x2_base + _offx;
    var _full_y2 = _full_y2_base + _offy;
    var _split_y = __battle_anim_queue_yu(_pid, 88) + _offy;
    var _field_full = [_full_x1, _full_y1, _full_x2, _full_y2];
    var _field_player = [_full_x1, _split_y, _full_x2, _full_y2];
    var _field_enemy = [_full_x1, _full_y1, _full_x2, _split_y];
    var _gui_full = [0, 0, _gui_w, _gui_h];

    for (var _si = 0; _si < array_length(_states); ++_si){
        var _st = _states[_si];
        if (!is_struct(_st)) continue;
        var _kind = (variable_struct_exists(_st, "kind") ? string(_st.kind) : "");
        if (_kind == "stat_overlay"){
            if (!sprite_exists(spr_stateffects)) continue;
            // Keep stat overlays anchored to the stable GUI battlefield rect so
            // screen shake does not drag or clip the fullscreen effect.
            var _cam_cx = floor((_full_x1_base + _full_x2_base) * 0.5);
            var _cam_cy = floor((_full_y1_base + _full_y2_base) * 0.5);
            var _idx_so = (variable_struct_exists(_st, "target_index") && is_real(variable_struct_get(_st, "target_index"))) ? floor(variable_struct_get(_st, "target_index")) : 0;
            // Preserve actor-relative centering for targeted flashes, but keep it in
            // stable GUI coordinates instead of shaken camera coordinates.
            var _has_target = (variable_struct_exists(_st, "target_index") && is_real(variable_struct_get(_st, "target_index")));
            var _target_center_so = _has_target ? __battle_anim_queue_actor_center(_pid, _idx_so) : undefined;
            var _cx_so = (_has_target && is_array(_target_center_so) && array_length(_target_center_so) >= 2) ? _target_center_so[0] : _cam_cx;
            var _cy_so = (_has_target && is_array(_target_center_so) && array_length(_target_center_so) >= 2) ? _target_center_so[1] : _cam_cy;
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
            var _delta_count_so = 1;
            if (variable_struct_exists(_st, "stat_deltas") && is_struct(variable_struct_get(_st, "stat_deltas"))){
                var _delta_obj_so = variable_struct_get(_st, "stat_deltas");
                var _known_delta_keys = ["atk","def","spe","spa","spd","accuracy","evasion"];
                var _delta_max_so = 0;
                for (var _dsi = 0; _dsi < array_length(_known_delta_keys); ++_dsi){
                    var _dk = _known_delta_keys[_dsi];
                    if (!variable_struct_exists(_delta_obj_so, _dk)) continue;
                    var _dv = variable_struct_get(_delta_obj_so, _dk);
                    if (is_real(_dv)) _delta_max_so = max(_delta_max_so, abs(floor(_dv)));
                }
                if (_delta_max_so > 0) _delta_count_so = clamp(_delta_max_so, 1, 6);
            }
            var _delta_spacing_so = __battle_anim_queue_wu(_pid, 14, 14);
            var _draw_stat_overlay_icons = function(_center_x, _center_y){
                var _half_span = (_delta_count_so - 1) * 0.5;
                for (var _icon_i = 0; _icon_i < _delta_count_so; ++_icon_i){
                    var _icon_x = _center_x + ((_icon_i - _half_span) * _delta_spacing_so);
                    draw_sprite_ext(spr_stateffects, _frame_so, _icon_x, _center_y + _yoff_so, _scale_so, _scale_so, 0, _color_so, _alpha_so);
                }
            };
            // If requested, draw a full-field tiled background using the same sprite frame.
            var _bg_flag = (variable_struct_exists(_st, "bg") && _st.bg);
            if (_bg_flag){
                var _target_indexes_so = (variable_struct_exists(_st, "target_indexes") && is_array(variable_struct_get(_st, "target_indexes"))) ? variable_struct_get(_st, "target_indexes") : [_idx_so];
                var _used_stencil = false;
                for (var _sti = 0; _sti < array_length(_target_indexes_so); ++_sti){
                    var _st_idx = _target_indexes_so[_sti];
                    if (!is_real(_st_idx)) continue;
                    var _stencil_spec = __battle_anim_queue_actor_sprite_spec(_pid, floor(_st_idx));
                    if (__battle_anim_queue_draw_stat_overlay_stencil(_pid, _st, _stencil_spec)) _used_stencil = true;
                }
                if (!_used_stencil){
                    var _tile_w = __battle_anim_queue_wu(_pid, 32, 32);
                    var _tile_h = __battle_anim_queue_hu(_pid, 32, 32);
                    var _spr_w = _spr_w_so;
                    var _scale_tile = (_spr_w > 0) ? (_tile_w / _spr_w) : _scale_so;
                    var _dir = (variable_struct_exists(_st, "direction") && is_real(_st.direction)) ? floor(_st.direction) : 0;
                    var _loops = (variable_struct_exists(_st, "bg_loops") && is_real(_st.bg_loops)) ? max(0, floor(_st.bg_loops)) : 3;
                    var _frac = 0;
                    if (_loops > 0) {
                        var _lp = _prog_so * _loops;
                        _frac = _lp - floor(_lp);
                    }
                    var _scroll = 0;
                    if (_dir > 0) _scroll = -(_frac * _tile_h); else if (_dir < 0) _scroll = (_frac * _tile_h);
                    gpu_set_blendmode(bm_normal);
                    var _lx = _field_full[0];
                    var _ty0 = _field_full[1];
                    var _rx = _field_full[2];
                    var _by = _field_full[3];
                    var _start_y = _ty0 + _scroll - _tile_h;
                    var _start_x = floor(_lx / max(1, _tile_w)) * _tile_w - _tile_w;
                    var _end_x = _rx + _tile_w;
                    var _end_y = _by + _tile_h;
                    for (var _tx = _start_x; _tx <= _end_x; _tx += _tile_w){
                        for (var _ty = _start_y; _ty <= _end_y; _ty += _tile_h){
                            draw_sprite_ext(spr_stateffects, _frame_so, _tx + _tile_w * 0.5, _ty + _tile_h * 0.5, _scale_tile, _scale_tile, 0, _color_so, _alpha_so);
                        }
                    }
                    gpu_set_blendmode(bm_normal);
                }
                draw_set_alpha(1);
                draw_set_color(c_white);
                for (var _ico_i = 0; _ico_i < array_length(_target_indexes_so); ++_ico_i){
                    var _ico_idx = _target_indexes_so[_ico_i];
                    if (!is_real(_ico_idx)) continue;
                    var _ico_center = __battle_anim_queue_actor_center(_pid, floor(_ico_idx));
                    if (is_array(_ico_center) && array_length(_ico_center) >= 2) _draw_stat_overlay_icons(_ico_center[0], _ico_center[1]);
                }
            } else {
                gpu_set_blendmode(bm_normal);
                _draw_stat_overlay_icons(_cx_so, _cy_so);
                gpu_set_blendmode(bm_normal);
                draw_set_alpha(1);
                draw_set_color(c_white);
            }
            draw_set_alpha(1);
            draw_set_color(c_white);
        } else if (_kind == "actor_glow"){
            var _idx = (variable_struct_exists(_st, "target_index") && is_real(_st.target_index)) ? floor(_st.target_index) : 0;
            var _center = __battle_anim_queue_actor_center(_pid, _idx);
            var _cx = (is_array(_center) && array_length(_center) >= 2) ? _center[0] + _offx : _player_cx;
            var _cy = (is_array(_center) && array_length(_center) >= 2) ? _center[1] + _offy : _player_cy;
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
            var _wf0 = _gui_full[0] - _pad_xw; var _wf1 = _gui_full[1] - _pad_yw; var _wf2 = _gui_full[2] + _pad_xw; var _wf3 = _gui_full[3] + _pad_yw;
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
            var _sf0 = _gui_full[0] - _pad_xs; var _sf1 = _gui_full[1] - _pad_ys; var _sf2 = _gui_full[2] + _pad_xs; var _sf3 = _gui_full[3] + _pad_ys;
            draw_set_alpha(_alphas);
            draw_set_color(_colors);
            draw_rectangle(_sf0, _sf1, _sf2, _sf3, false);
            draw_set_alpha(1);
            draw_set_color(c_white);
        } else if (_kind == "sprite_projectile"){
            var _idx_pr = (variable_struct_exists(_st, "target_index") && is_real(_st.target_index)) ? floor(_st.target_index) : 0;
            var _target_center_pr = __battle_anim_queue_actor_center(_pid, _idx_pr);
            var _tx_pr = (is_array(_target_center_pr) && array_length(_target_center_pr) >= 2) ? _target_center_pr[0] + _offx : _enemy_cx;
            var _ty_pr = (is_array(_target_center_pr) && array_length(_target_center_pr) >= 2) ? _target_center_pr[1] + _offy : _enemy_cy;
            var _sx_pr = _player_cx;
            var _sy_pr = _player_cy;
            if (variable_struct_exists(_st, "source_index") && is_real(_st.source_index)){
                var _source_center_pr = __battle_anim_queue_actor_center(_pid, floor(_st.source_index));
                if (is_array(_source_center_pr) && array_length(_source_center_pr) >= 2){
                    _sx_pr = _source_center_pr[0] + _offx;
                    _sy_pr = _source_center_pr[1] + _offy;
                }
            }
            var _p_pr = clamp((variable_struct_exists(_st, "progress") && is_real(_st.progress)) ? _st.progress : 0, 0, 1);
            var _travel_pr = clamp(_p_pr / 0.78, 0, 1);
            var _ease_pr = 1 - power(1 - _travel_pr, 2);
            var _dir_pr = sign(_tx_pr - _sx_pr);
            if (_dir_pr == 0) _dir_pr = 1;
            var _overshoot_pr = __battle_anim_queue_wu(_pid, 42, 42) * max(0, (_p_pr - 0.78) / 0.22) * _dir_pr;
            var _arc_pr = sin(_travel_pr * pi) * __battle_anim_queue_hu(_pid, 12, 12);
            var _x_pr = lerp(_sx_pr, _tx_pr, _ease_pr) + _overshoot_pr;
            var _y_pr = lerp(_sy_pr, _ty_pr, _ease_pr) - _arc_pr;
            if (variable_struct_exists(_st, "offset_x") && is_real(_st.offset_x)) _x_pr += _st.offset_x;
            if (variable_struct_exists(_st, "offset_y") && is_real(_st.offset_y)) _y_pr += _st.offset_y;
            var _sprite_pr = variable_struct_exists(_st, "sprite") ? _st.sprite : undefined;
            var _has_sprite_pr = false;
            try { _has_sprite_pr = (!is_undefined(_sprite_pr) && sprite_exists(_sprite_pr)); } catch (e_sprite_pr) { _has_sprite_pr = false; }
            if (_has_sprite_pr){
                var _frame_pr = (variable_struct_exists(_st, "frame") && is_real(_st.frame)) ? floor(_st.frame) : 0;
                var _scale_pr = ((variable_struct_exists(_st, "scale") && is_real(_st.scale)) ? real(_st.scale) : 1) * _ui_scale_anim;
                var _alpha_pr = clamp((variable_struct_exists(_st, "alpha") && is_real(_st.alpha)) ? _st.alpha : 1, 0, 1);
                var _tint_pr = (variable_struct_exists(_st, "tint") && is_real(_st.tint)) ? _st.tint : c_white;
                var _sw_pr = sprite_get_width(_sprite_pr);
                var _sh_pr = sprite_get_height(_sprite_pr);
                draw_sprite_ext(_sprite_pr, _frame_pr, _x_pr - (_sw_pr * _scale_pr) * 0.5, _y_pr - (_sh_pr * _scale_pr) * 0.5, _scale_pr, _scale_pr, 0, _tint_pr, _alpha_pr);
            }
        } else if (_kind == "particle_burst"){
            var _idx_pb = (variable_struct_exists(_st, "target_index") && is_real(_st.target_index)) ? floor(_st.target_index) : 0;
            var _target_center_pb = __battle_anim_queue_actor_center(_pid, _idx_pb);
            var _tx_pb = (is_array(_target_center_pb) && array_length(_target_center_pb) >= 2) ? _target_center_pb[0] + _offx : _player_cx;
            var _ty_pb = (is_array(_target_center_pb) && array_length(_target_center_pb) >= 2) ? _target_center_pb[1] + _offy : _player_cy;

            var _sx_pb = _tx_pb;
            var _sy_pb = _ty_pb;
            if (variable_struct_exists(_st, "source_index") && is_real(_st.source_index)){
                var _source_center_pb = __battle_anim_queue_actor_center(_pid, floor(_st.source_index));
                if (is_array(_source_center_pb) && array_length(_source_center_pb) >= 2){
                    _sx_pb = _source_center_pb[0] + _offx;
                    _sy_pb = _source_center_pb[1] + _offy;
                }
            }

            var _p_pb = clamp((variable_struct_exists(_st, "progress") && is_real(_st.progress)) ? _st.progress : 0, 0, 1);
            var _alpha_pb = clamp((variable_struct_exists(_st, "alpha") && is_real(_st.alpha)) ? _st.alpha : 1, 0, 1);
            var _count_pb = (variable_struct_exists(_st, "particle_count") && is_real(_st.particle_count)) ? max(1, floor(_st.particle_count)) : 10;
            var _spread_x_pb = (variable_struct_exists(_st, "spread_x") && is_real(_st.spread_x)) ? real(_st.spread_x) : __battle_anim_queue_wu(_pid, 18, 18);
            var _spread_y_pb = (variable_struct_exists(_st, "spread_y") && is_real(_st.spread_y)) ? real(_st.spread_y) : __battle_anim_queue_hu(_pid, 14, 14);
            var _speed_x_pb = (variable_struct_exists(_st, "speed_x") && is_real(_st.speed_x)) ? real(_st.speed_x) : 0;
            var _speed_y_pb = (variable_struct_exists(_st, "speed_y") && is_real(_st.speed_y)) ? real(_st.speed_y) : __battle_anim_queue_hu(_pid, -10, -10);
            var _gravity_pb = (variable_struct_exists(_st, "gravity") && is_real(_st.gravity)) ? real(_st.gravity) : 0;
            var _scale_pb = (variable_struct_exists(_st, "scale") && is_real(_st.scale)) ? real(_st.scale) : 1;
            var _offset_x_pb = (variable_struct_exists(_st, "offset_x") && is_real(_st.offset_x)) ? real(_st.offset_x) : 0;
            var _offset_y_pb = (variable_struct_exists(_st, "offset_y") && is_real(_st.offset_y)) ? real(_st.offset_y) : 0;
            var _tint_pb = (variable_struct_exists(_st, "tint") && is_real(_st.tint)) ? _st.tint : c_white;
            var _pk_pb = variable_struct_exists(_st, "particle_kind") ? string_lower(string(_st.particle_kind)) : "spark";
            var _sprite_pb = variable_struct_exists(_st, "sprite") ? _st.sprite : undefined;
            var _has_sprite_pb = false;
            try { _has_sprite_pb = (!is_undefined(_sprite_pb) && sprite_exists(_sprite_pb)); } catch (e_sprite_pb) { _has_sprite_pb = false; }
            var _sprite_frames_pb = 1;
            try { if (_has_sprite_pb) _sprite_frames_pb = max(1, sprite_get_number(_sprite_pb)); } catch (e_frames_pb) { _sprite_frames_pb = 1; }
            var _from_user_pb = (variable_struct_exists(_st, "from_user") && _st.from_user == true);
            var _travel_pb = clamp(_p_pb * 1.18, 0, 1);
            var _ease_pb = 1 - power(1 - _travel_pb, 2);
            var _base_x_pb = (_from_user_pb ? (_sx_pb + (_tx_pb - _sx_pb) * _ease_pb) : _tx_pb) + _offset_x_pb;
            var _base_y_pb = (_from_user_pb ? (_sy_pb + (_ty_pb - _sy_pb) * _ease_pb - sin(_travel_pb * pi) * __battle_anim_queue_hu(_pid, 16, 16)) : _ty_pb) + _offset_y_pb;
            var _move_seed_pb = (variable_struct_exists(_st, "move_id") && is_real(_st.move_id)) ? floor(_st.move_id) : 0;

            for (var _pi_pb = 0; _pi_pb < _count_pb; ++_pi_pb){
                var _seed_a_pb = sin((_pi_pb + 1) * 12.9898 + _idx_pb * 78.233 + _move_seed_pb * 3.117);
                var _seed_b_pb = sin((_pi_pb + 5) * 39.3467 + _idx_pb * 11.135 + _move_seed_pb * 5.331);
                var _rand_a_pb = abs(_seed_a_pb - floor(_seed_a_pb));
                var _rand_b_pb = abs(_seed_b_pb - floor(_seed_b_pb));
                var _ang_pb = (_rand_a_pb * 2 * pi) + (_p_pb * pi * 0.65);
                var _burst_pb = sin(clamp(_p_pb * pi, 0, pi));
                var _phase_pb = clamp((_p_pb - (_pi_pb / max(1, _count_pb)) * 0.16), 0, 1);
                var _dx_pb = cos(_ang_pb) * _spread_x_pb * (0.25 + _burst_pb * (0.65 + _rand_b_pb * 0.5));
                var _dy_pb = sin(_ang_pb) * _spread_y_pb * (0.25 + _burst_pb * (0.65 + _rand_a_pb * 0.5));
                var _dir_pb = (_idx_pb <= 1) ? -1 : 1;
                if (_from_user_pb) _dir_pb = sign(_tx_pb - _sx_pb);
                if (_dir_pb == 0) _dir_pb = 1;
                _dx_pb += _speed_x_pb * _phase_pb * _dir_pb;
                _dy_pb += _speed_y_pb * _phase_pb + _gravity_pb * _phase_pb * _phase_pb;

                var _draw_x_pb = _base_x_pb + _dx_pb;
                var _draw_y_pb = _base_y_pb + _dy_pb;
                if (_pk_pb == "water_blast"){
                    var _face_dir_wb = sign(_tx_pb - _sx_pb);
                    if (_face_dir_wb == 0) _face_dir_wb = _dir_pb;
                    var _impact_mix_wb = clamp((_p_pb - 0.16) / 0.56, 0, 1);
                    var _face_x_wb = _tx_pb + __battle_anim_queue_wu(_pid, 7, 7) * _face_dir_wb;
                    var _face_y_wb = _ty_pb - __battle_anim_queue_hu(_pid, 10, 10);
                    _draw_x_pb = lerp(_draw_x_pb, _face_x_wb + _dx_pb * 0.48, _impact_mix_wb);
                    _draw_y_pb = lerp(_draw_y_pb, _face_y_wb + _dy_pb * 0.52, _impact_mix_wb);
                }
                if (_pk_pb == "sand" || _pk_pb == "mud"){
                    var _face_dir_pb = sign(_tx_pb - _sx_pb);
                    if (_face_dir_pb == 0) _face_dir_pb = _dir_pb;
                    var _impact_mix_pb = clamp((_p_pb - 0.22) / 0.58, 0, 1);
                    var _face_x_pb = _tx_pb + __battle_anim_queue_wu(_pid, 8, 8) * _face_dir_pb;
                    var _face_y_pb = _ty_pb - __battle_anim_queue_hu(_pid, 12, 12);
                    _draw_x_pb = lerp(_draw_x_pb, _face_x_pb + _dx_pb * 0.55, _impact_mix_pb);
                    _draw_y_pb = lerp(_draw_y_pb, _face_y_pb + _dy_pb * 0.42, _impact_mix_pb);
                }
                var _a_pb = _alpha_pb * (1 - power(_p_pb, 1.6)) * (0.72 + _rand_b_pb * 0.28);
                if (_a_pb <= 0) continue;
                var _size_pb = max(1, __battle_anim_queue_wu(_pid, 2 + floor(_rand_a_pb * 3), 2) * _scale_pb);

                if (_has_sprite_pb){
                    var _frame_pb = clamp(floor((_p_pb * _sprite_frames_pb * 1.5) + _pi_pb) mod _sprite_frames_pb, 0, max(0, _sprite_frames_pb - 1));
                    var _sw_pb = sprite_get_width(_sprite_pb);
                    var _sh_pb = sprite_get_height(_sprite_pb);
                    var _sc_pb = max(0.25, _scale_pb * _ui_scale_anim * (0.55 + _rand_a_pb * 0.35));
                    draw_sprite_ext(_sprite_pb, _frame_pb, _draw_x_pb - (_sw_pb * _sc_pb) * 0.5, _draw_y_pb - (_sh_pb * _sc_pb) * 0.5, _sc_pb, _sc_pb, (_rand_a_pb - 0.5) * 38, _tint_pb, _a_pb);
                } else {
                    draw_set_color(_tint_pb);
                    draw_set_alpha(_a_pb);
                    if (_pk_pb == "slash" || _pk_pb == "wind"){
                        var _len_pb = _size_pb * ((_pk_pb == "wind") ? 5 : 4);
                        draw_line_width(_draw_x_pb - _len_pb * 0.5, _draw_y_pb + _size_pb, _draw_x_pb + _len_pb * 0.5, _draw_y_pb - _size_pb, max(1, floor(_size_pb * 0.6)));
                    } else if (_pk_pb == "spark"){
                        draw_line_width(_draw_x_pb - _size_pb * 2, _draw_y_pb, _draw_x_pb + _size_pb * 2, _draw_y_pb, max(1, floor(_size_pb * 0.5)));
                        draw_line_width(_draw_x_pb, _draw_y_pb - _size_pb * 2, _draw_x_pb, _draw_y_pb + _size_pb * 2, max(1, floor(_size_pb * 0.5)));
                    } else if (_pk_pb == "water_blast"){
                        var _water_r_pb = max(1, floor(_size_pb * (0.8 + _rand_a_pb * 0.65)));
                        var _tail_len_pb = max(1, floor(_water_r_pb * (1.6 + _rand_b_pb * 1.4)));
                        draw_circle(_draw_x_pb, _draw_y_pb, _water_r_pb, false);
                        draw_set_alpha(_a_pb * 0.72);
                        draw_line_width(_draw_x_pb - _tail_len_pb, _draw_y_pb + _water_r_pb * 0.25, _draw_x_pb + _water_r_pb * 0.6, _draw_y_pb - _water_r_pb * 0.35, max(1, floor(_water_r_pb * 0.55)));
                        if (_rand_b_pb > 0.42){
                            draw_circle(_draw_x_pb + _water_r_pb * 1.05, _draw_y_pb - _water_r_pb * 0.4, max(1, floor(_water_r_pb * 0.68)), false);
                        }
                        draw_set_alpha(_a_pb);
                    } else if (_pk_pb == "ring"){
                        var _rw_pb = _size_pb * (2.2 + _rand_a_pb);
                        var _rh_pb = _size_pb * (1.1 + _rand_b_pb * 0.5);
                        draw_ellipse(_draw_x_pb - _rw_pb, _draw_y_pb - _rh_pb, _draw_x_pb + _rw_pb, _draw_y_pb + _rh_pb, true);
                    } else if (_pk_pb == "powder"){
                        var _d_pb = max(1, floor(_size_pb * (0.55 + _rand_a_pb * 0.45)));
                        draw_rectangle(_draw_x_pb - _d_pb, _draw_y_pb - _d_pb, _draw_x_pb + _d_pb, _draw_y_pb + _d_pb, false);
                        draw_rectangle(_draw_x_pb + _d_pb * 2, _draw_y_pb - _d_pb, _draw_x_pb + _d_pb * 3, _draw_y_pb, false);
                    } else if (_pk_pb == "orb"){
                        var _star_pb = max(1, floor(_size_pb * (0.75 + _rand_a_pb * 0.5)));
                        draw_line_width(_draw_x_pb - _star_pb, _draw_y_pb, _draw_x_pb + _star_pb, _draw_y_pb, 1);
                        draw_line_width(_draw_x_pb, _draw_y_pb - _star_pb, _draw_x_pb, _draw_y_pb + _star_pb, 1);
                    } else if (_pk_pb == "sand"){
                        var _sand_r_pb = max(1, floor(_size_pb * (0.45 + _rand_a_pb * 0.45)));
                        draw_circle(_draw_x_pb, _draw_y_pb, _sand_r_pb, false);
                        if (_rand_b_pb > 0.58){
                            draw_set_alpha(_a_pb * 0.72);
                            draw_circle(_draw_x_pb - _sand_r_pb * 1.4, _draw_y_pb + _sand_r_pb * 0.35, max(1, floor(_sand_r_pb * 0.72)), false);
                            draw_set_alpha(_a_pb);
                        }
                    } else if (_pk_pb == "mud"){
                        var _mud_r_pb = max(1, floor(_size_pb * (0.65 + _rand_a_pb * 0.55)));
                        draw_circle(_draw_x_pb, _draw_y_pb, _mud_r_pb, false);
                        if (_rand_b_pb > 0.35){
                            draw_set_alpha(_a_pb * 0.8);
                            draw_circle(_draw_x_pb + _mud_r_pb * 0.8, _draw_y_pb - _mud_r_pb * 0.2, max(1, floor(_mud_r_pb * 0.75)), false);
                            draw_set_alpha(_a_pb);
                        }
                    } else if (_pk_pb == "rock"){
                        draw_rectangle(_draw_x_pb - _size_pb, _draw_y_pb - _size_pb * 0.7, _draw_x_pb + _size_pb, _draw_y_pb + _size_pb * 0.7, false);
                    } else if (_pk_pb == "droplet" || _pk_pb == "blob" || _pk_pb == "flame" || _pk_pb == "ice"){
                        draw_ellipse(_draw_x_pb - _size_pb * 0.8, _draw_y_pb - _size_pb * 1.3, _draw_x_pb + _size_pb * 0.8, _draw_y_pb + _size_pb * 1.3, false);
                    } else if (_pk_pb == "leaf"){
                        draw_ellipse(_draw_x_pb - _size_pb * 1.5, _draw_y_pb - _size_pb * 0.55, _draw_x_pb + _size_pb * 1.5, _draw_y_pb + _size_pb * 0.55, false);
                        draw_line_width(_draw_x_pb - _size_pb * 1.2, _draw_y_pb, _draw_x_pb + _size_pb * 1.2, _draw_y_pb, 1);
                    } else {
                        draw_triangle(_draw_x_pb, _draw_y_pb - _size_pb, _draw_x_pb + _size_pb, _draw_y_pb, _draw_x_pb, _draw_y_pb + _size_pb, false);
                        draw_triangle(_draw_x_pb, _draw_y_pb - _size_pb, _draw_x_pb - _size_pb, _draw_y_pb, _draw_x_pb, _draw_y_pb + _size_pb, false);
                    }
                }
            }
            draw_set_alpha(1);
            draw_set_color(c_white);
        } else if (_kind == "sprite_orbit"){
            var _idx_orbit = (variable_struct_exists(_st, "target_index") && is_real(_st.target_index)) ? floor(_st.target_index) : 0;
            var _center_orbit = __battle_anim_queue_actor_center(_pid, _idx_orbit);
            var _sprite_orbit = (variable_struct_exists(_st, "sprite")) ? _st.sprite : undefined;
            if (is_undefined(_sprite_orbit)) continue;
            try { if (!sprite_exists(_sprite_orbit)) continue; } catch (_orbit_sprite_error) { continue; }

            var _spr_count_orbit = 1;
            try { _spr_count_orbit = max(1, sprite_get_number(_sprite_orbit)); } catch (_orbit_count_error) { _spr_count_orbit = 1; }

            var _progress_orbit = (variable_struct_exists(_st, "progress") && is_real(_st.progress)) ? clamp(_st.progress, 0, 1) : 0;
            var _alpha_orbit = (variable_struct_exists(_st, "alpha") && is_real(_st.alpha)) ? clamp(_st.alpha, 0, 1) : 1;
            var _scale_orbit = ((variable_struct_exists(_st, "scale") && is_real(_st.scale)) ? real(_st.scale) : 1) * _ui_scale_anim;
            var _offset_x_orbit = (variable_struct_exists(_st, "offset_x") && is_real(_st.offset_x)) ? _st.offset_x : 0;
            var _offset_y_orbit = (variable_struct_exists(_st, "offset_y") && is_real(_st.offset_y)) ? _st.offset_y : 0;
            var _orbit_count = (variable_struct_exists(_st, "orbit_count") && is_real(_st.orbit_count)) ? max(1, floor(_st.orbit_count)) : 3;
            var _radius_x_orbit = (variable_struct_exists(_st, "orbit_radius_x") && is_real(_st.orbit_radius_x)) ? real(_st.orbit_radius_x) : 22;
            var _radius_y_orbit = (variable_struct_exists(_st, "orbit_radius_y") && is_real(_st.orbit_radius_y)) ? real(_st.orbit_radius_y) : 8;
            var _spin_speed_orbit = (variable_struct_exists(_st, "spin_speed") && is_real(_st.spin_speed)) ? real(_st.spin_speed) : 1.35;
            var _tint_orbit = (variable_struct_exists(_st, "tint") && is_real(_st.tint)) ? _st.tint : c_white;

            for (var _orbit_i = 0; _orbit_i < _orbit_count; ++_orbit_i){
                var _orbit_angle = ((_progress_orbit * 2 * pi * _spin_speed_orbit) + ((_orbit_i / _orbit_count) * 2 * pi));
                var _draw_x_orbit = _center_orbit[0] + _offset_x_orbit + cos(_orbit_angle) * _radius_x_orbit;
                var _draw_y_orbit = _center_orbit[1] + _offset_y_orbit + sin(_orbit_angle) * _radius_y_orbit;
                var _frame_orbit = clamp(floor((_progress_orbit * _spr_count_orbit * 1.75) + _orbit_i) mod _spr_count_orbit, 0, max(0, _spr_count_orbit - 1));
                draw_sprite_ext(_sprite_orbit, _frame_orbit, _draw_x_orbit, _draw_y_orbit, _scale_orbit, _scale_orbit, 0, _tint_orbit, _alpha_orbit);
            }
        }
        else if (_kind == "sprite_overlay"){
            // Draw an arbitrary single-frame/animated sprite centered on the target actor
            var _idxs = (variable_struct_exists(_st, "target_index") && is_real(_st.target_index)) ? floor(_st.target_index) : 0;
            var _center_s = __battle_anim_queue_actor_center(_pid, _idxs);
            var _cxs = (is_array(_center_s) && array_length(_center_s) >= 2) ? _center_s[0] + _offx : _player_cx;
            var _cys = (is_array(_center_s) && array_length(_center_s) >= 2) ? _center_s[1] + _offy : _player_cy;
            var _anchor_s = (variable_struct_exists(_st, "anchor")) ? string_lower(string(variable_struct_get(_st, "anchor"))) : "";
            if (_anchor_s == "head" || _anchor_s == "top"){
                var _actor_spec_s = __battle_anim_queue_actor_sprite_spec(_pid, _idxs);
                if (is_struct(_actor_spec_s)){
                    var _spec_draw_x_s = (variable_struct_exists(_actor_spec_s, "draw_x") && is_real(variable_struct_get(_actor_spec_s, "draw_x"))) ? real(variable_struct_get(_actor_spec_s, "draw_x")) : _cxs;
                    var _spec_draw_y_s = (variable_struct_exists(_actor_spec_s, "draw_y") && is_real(variable_struct_get(_actor_spec_s, "draw_y"))) ? real(variable_struct_get(_actor_spec_s, "draw_y")) : _cys;
                    var _spec_w_s = (variable_struct_exists(_actor_spec_s, "width_px") && is_real(variable_struct_get(_actor_spec_s, "width_px"))) ? real(variable_struct_get(_actor_spec_s, "width_px")) : 0;
                    _cxs = _spec_draw_x_s + (_spec_w_s * 0.5) + _offx;
                    _cys = _spec_draw_y_s + _offy;
                }
            }
            var _sprs = (variable_struct_exists(_st, "sprite") ? _st.sprite : undefined);
            var _frs = (variable_struct_exists(_st, "frame") && is_real(_st.frame)) ? floor(_st.frame) : 0;
            var _scale_base_s = (variable_struct_exists(_st, "scale") && is_real(_st.scale)) ? _st.scale : 1;
            var _scx = ((variable_struct_exists(_st, "scale_x") && is_real(_st.scale_x)) ? _st.scale_x : _scale_base_s) * _ui_scale_anim;
            var _scy = ((variable_struct_exists(_st, "scale_y") && is_real(_st.scale_y)) ? _st.scale_y : _scale_base_s) * _ui_scale_anim;
            var _als = clamp((variable_struct_exists(_st, "alpha") ? _st.alpha : 1), 0, 1);
            var _sprite_offx = (variable_struct_exists(_st, "offset_x") && is_real(_st.offset_x)) ? _st.offset_x : 0;
            var _sprite_offy = (variable_struct_exists(_st, "offset_y") && is_real(_st.offset_y)) ? _st.offset_y : 0;
            var _rot_s = (variable_struct_exists(_st, "rotation") && is_real(_st.rotation)) ? real(_st.rotation) : 0;
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
            // Compute draw position so the overlay is centered on the actor center
            var _draw_x = _cxs + _sprite_offx + _apply_slide_x;
            var _draw_y = _cys + _sprite_offy;
            if (!is_undefined(_sprs) && sprite_exists(_sprs)){
                var _sw = sprite_get_width(_sprs);
                var _sh = sprite_get_height(_sprs);
                // Adjust so sprite is centered at (_cxs, _cys) (matching battler centering logic)
                _draw_x = _draw_x - (_sw * abs(_scx)) / 2;
                _draw_y = _draw_y - (_sh * abs(_scy)) / 2;
                gpu_set_blendmode(bm_normal);
                var _tint_s = (variable_struct_exists(_st, "tint") && is_real(_st.tint)) ? _st.tint : c_white;
                draw_sprite_ext(_sprs, _frs, _draw_x, _draw_y, _scx, _scy, _rot_s, _tint_s, _als);
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
    if (_type == "move"){
        var _family_mv = string_lower(string(variable_struct_exists(_entry, "family") ? variable_struct_get(_entry, "family") : "damage"));
        var _focus_mv = (variable_struct_exists(_entry, "focus_index") && is_real(variable_struct_get(_entry, "focus_index"))) ? clamp(variable_struct_get(_entry, "focus_index"), 0, 1) : ((variable_struct_exists(_entry, "target_index") && is_real(variable_struct_get(_entry, "target_index"))) ? clamp(variable_struct_get(_entry, "target_index"), 0, 1) : 0);
        switch (_family_mv){
            case "field":
            case "barrier":
            case "hazard":
            case "terrain":
                battle_cam_pan_to_offset(_pid, 0, __battle_anim_queue_hu(_pid, -4, -4), 380);
                break;
            case "weather":
                battle_cam_shake(_pid, __battle_anim_queue_wu(_pid, 2, 5), 18, 16, 0.9);
                break;
            case "recoil":
            case "counter":
            case "self_destruct":
                battle_cam_pan_to_side(_pid, _focus_mv, max(5, __battle_anim_queue_wu(_pid, 8, 12)), 300);
                battle_cam_shake(_pid, __battle_anim_queue_wu(_pid, 4, 8), 18, 14, 0.84);
                break;
            default:
                battle_cam_pan_to_side(_pid, _focus_mv, max(3, __battle_anim_queue_wu(_pid, 5, 8)), 260);
                battle_cam_shake(_pid, __battle_anim_queue_wu(_pid, 2, 4), 12, 14, 0.88);
                break;
        }
    } else if (_type == "stat_change" || _type == "heal" || _type == "recoil" || _type == "guard_split" || _type == "imprison" || _type == "cure_party"){
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
    if (!is_undefined(pkicons_get_capture_ball_icon_by_id) && is_real(_item_id) && _item_id > 0){
        try { var s_try = pkicons_get_capture_ball_icon_by_id(floor(_item_id)); if (!is_undefined(s_try) && sprite_exists(s_try)) ball_spr = s_try; } catch (e) { ball_spr = undefined; }
    } else if (!is_undefined(pkicons_get_item_icon_by_id) && is_real(_item_id) && _item_id > 0){
        try { var s_fallback = pkicons_get_item_icon_by_id(floor(_item_id)); if (!is_undefined(s_fallback) && sprite_exists(s_fallback)) ball_spr = s_fallback; } catch (e_fallback) { ball_spr = undefined; }
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
        ball_sprite: ball_spr,
        ball_frame: 0,
        start_x: undefined,
        start_y: undefined,
        target_x: undefined,
        target_y: undefined,
        land_x: (variable_struct_exists(_local_opts, "land_x") && is_real(variable_struct_get(_local_opts, "land_x")) ? real(variable_struct_get(_local_opts, "land_x")) : undefined),
        land_y: (variable_struct_exists(_local_opts, "land_y") && is_real(variable_struct_get(_local_opts, "land_y")) ? real(variable_struct_get(_local_opts, "land_y")) : undefined),
        enemy_orig_scale: undefined,
        enemy_scale_now: undefined,
        caught_struct: _caught_struct,
        target_actor_index: (variable_struct_exists(_local_opts, "target_actor_index") ? floor(variable_struct_get(_local_opts, "target_actor_index")) : 1),
        owner_pid: (variable_struct_exists(_local_opts, "owner_pid") && is_real(variable_struct_get(_local_opts, "owner_pid")) ? max(0, floor(variable_struct_get(_local_opts, "owner_pid"))) : undefined)
    };

        variable_struct_set(_B, "_catch_anim", ca);
        return ca;
    }

// Simple battle animations module
// Provides: __battle_anim_update(_B) -> progresses animations
//           __battle_anim_draw(_pid) -> draws current animation state

function __battle_anim_legacy_spec_is_idle(_spec){
    if (!is_struct(_spec)) return true;
    if (variable_struct_exists(_spec, "type")) return false;
    var _anim_id = variable_struct_exists(_spec, "anim_id") ? string_lower(string(variable_struct_get(_spec, "anim_id"))) : "";
    return (_anim_id == "" || _anim_id == "idle");
}

function __battle_anim_update(_B){
    // Accept pid or slot
    var _slot = _B;
    if (is_real(_B)) _slot = __battle_ensure_slot(_B);
    if (!is_struct(_slot)) return { resolved:false };
    if (!variable_struct_exists(_slot, "sys_anim") || !is_struct(variable_struct_get(_slot, "sys_anim"))) return { resolved:false };
    var sa = variable_struct_get(_slot, "sys_anim");
    var active = (variable_struct_exists(sa, "active") ? variable_struct_get(sa, "active") : []);
    var current = (variable_struct_exists(sa, "current") ? variable_struct_get(sa, "current") : undefined);
    if (is_struct(current) && variable_struct_exists(current, "spec") && __battle_anim_legacy_spec_is_idle(current.spec)){
        variable_struct_set(sa, "current", undefined);
        variable_struct_set(_slot, "sys_anim", sa);
        current = undefined;
    }

    // If no current and there's an active, pop the next real effect. Idle
    // placeholders are battler-state markers, not particles.
    while (!is_struct(current) && is_array(active) && array_length(active) > 0){
        var next = active[0];
        var newarr = [];
        for (var ii=1; ii<array_length(active); ++ii) newarr[array_length(newarr)] = active[ii];
        active = newarr;
        variable_struct_set(sa, "active", active);
        if (__battle_anim_legacy_spec_is_idle(next)){
            variable_struct_set(_slot, "sys_anim", sa);
            continue;
        }
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



function __battle_anim_legacy_status_visual(_status){
    var _s = string_lower(string(_status));
    if (_s == "psn" || _s == "poison" || _s == "toxic") return "poison";
    if (_s == "brn" || _s == "burn") return "burn";
    if (_s == "frz" || _s == "freeze" || _s == "frozen") return "freeze";
    if (_s == "par" || _s == "para" || _s == "paralyze" || _s == "paralysis") return "paralysis";
    if (_s == "slp" || _s == "sleep" || _s == "asleep") return "sleep";
    if (_s == "confusion" || _s == "confuse" || _s == "confused") return "confusion";
    if (_s == "impact" || _s == "damage" || _s == "hurt") return "impact";
    return "spark";
}

function __battle_anim_legacy_visual_color(_visual){
    switch (string_lower(string(_visual))){
        case "poison": return make_color_rgb(178, 82, 206);
        case "burn": return make_color_rgb(248, 104, 42);
        case "freeze": return make_color_rgb(164, 232, 255);
        case "paralysis": return make_color_rgb(252, 224, 62);
        case "sleep": return make_color_rgb(132, 178, 244);
        case "confusion": return make_color_rgb(210, 118, 236);
        case "heal": return make_color_rgb(116, 228, 144);
        case "stat_up": return make_color_rgb(122, 232, 150);
        case "stat_down": return make_color_rgb(255, 166, 78);
        case "shield": return make_color_rgb(166, 226, 250);
        case "impact": return make_color_rgb(244, 180, 122);
    }
    return c_white;
}

function __battle_anim_legacy_burst(_pid, _tx, _ty, _visual, _frac, _count, _radius){
    var _p = clamp(_frac, 0, 1);
    var _kind = string_lower(string(_visual));
    var _col = __battle_anim_legacy_visual_color(_kind);
    var _burst = sin(_p * pi);
    var _rad = __battle_anim_queue_wu(_pid, _radius, _radius);
    var _rise = __battle_anim_queue_hu(_pid, 14, 14) * _p;
    var _base_alpha = 1 - power(_p, 1.4);

    for (var _i = 0; _i < _count; ++_i){
        var _seed_a = sin((_i + 1) * 12.9898 + _tx * 0.17 + _ty * 0.23);
        var _seed_b = sin((_i + 7) * 39.3467 + _tx * 0.11 + _ty * 0.19);
        var _ra = abs(_seed_a - floor(_seed_a));
        var _rb = abs(_seed_b - floor(_seed_b));
        var _ang = (_ra * 2 * pi) + (_p * pi * ((_kind == "confusion") ? 1.5 : 0.35));
        var _dist = _rad * (0.22 + _burst * (0.58 + _rb * 0.42));
        var _x = _tx + cos(_ang) * _dist;
        var _y = _ty + sin(_ang) * _dist * 0.72 - _rise;
        var _a = _base_alpha * (0.62 + _rb * 0.38);
        if (_a <= 0) continue;

        draw_set_alpha(_a);
        draw_set_color(_col);
        var _size = max(1, floor(__battle_anim_queue_wu(_pid, 2 + floor(_ra * 3), 2)));
        if (_kind == "paralysis"){
            draw_line_width(_x - _size * 2, _y, _x + _size * 2, _y, 1);
            draw_line_width(_x, _y - _size * 2, _x, _y + _size * 2, 1);
        } else if (_kind == "burn"){
            draw_triangle(_x, _y - _size * 2, _x - _size, _y + _size, _x + _size, _y + _size, false);
        } else if (_kind == "freeze"){
            draw_line_width(_x - _size, _y + _size, _x + _size, _y - _size, 1);
            draw_line_width(_x - _size, _y - _size, _x + _size, _y + _size, 1);
        } else if (_kind == "poison"){
            draw_circle(_x, _y, _size, false);
            draw_set_alpha(_a * 0.45);
            draw_circle(_x + _size, _y - _size, max(1, floor(_size * 0.65)), false);
        } else if (_kind == "sleep"){
            draw_text(_x, _y - _size, "Z");
        } else if (_kind == "confusion"){
            draw_circle(_x, _y, max(1, floor(_size * 0.85)), true);
            draw_line_width(_x - _size, _y, _x + _size, _y, 1);
        } else if (_kind == "heal" || _kind == "stat_up"){
            draw_line_width(_x - _size, _y, _x + _size, _y, 1);
            draw_line_width(_x, _y - _size, _x, _y + _size, 1);
        } else if (_kind == "stat_down"){
            draw_triangle(_x, _y + _size * 2, _x - _size, _y - _size, _x + _size, _y - _size, false);
        } else if (_kind == "shield"){
            var _rw = _size * (2.8 + _ra);
            var _rh = _size * (1.45 + _rb * 0.5);
            draw_ellipse(_x - _rw, _y - _rh, _x + _rw, _y + _rh, true);
        } else {
            draw_line_width(_x - _size * 2, _y - _size, _x + _size * 2, _y + _size, 1);
            draw_line_width(_x - _size * 2, _y + _size, _x + _size * 2, _y - _size, 1);
        }
    }
    draw_set_alpha(1);
    draw_set_color(c_white);
}

function __battle_anim_legacy_target_center(_pid, _spec){
    var _tx = __battle_anim_queue_xu(_pid, 165);
    var _ty = __battle_anim_queue_yu(_pid, 40);
    if (variable_struct_exists(_spec, "target_index")){
        var _idx = variable_struct_get(_spec, "target_index");
        if (is_real(_idx)){
            var _center = __battle_anim_queue_actor_center(_pid, floor(_idx));
            if (is_array(_center) && array_length(_center) >= 2) return [_center[0], _center[1]];
            if (_idx == 0){
                _tx = __battle_anim_queue_xu(_pid, 64);
                _ty = __battle_anim_queue_yu(_pid, 112);
            }
        }
    }
    return [_tx, _ty];
}

function __battle_anim_draw(_pid){
    var _B = __battle_ensure_slot(_pid);
    if (!is_struct(_B)) return;
    if (variable_struct_exists(_B, "sys_open") && !variable_struct_get(_B, "sys_open")) return;
    if (!variable_struct_exists(_B, "sys_anim")) return;
    var sa = variable_struct_get(_B, "sys_anim");
    var cur = (variable_struct_exists(sa, "current") ? variable_struct_get(sa, "current") : undefined);
    if (!is_struct(cur) || !variable_struct_exists(cur, "spec")) return;
    if (!variable_struct_exists(cur, "active") || variable_struct_get(cur, "active") != true) return;
    var spec = cur.spec;
    if (__battle_anim_legacy_spec_is_idle(spec)) return;
    var now = current_time;
    var elapsed = now - (variable_struct_exists(cur, "start") ? cur.start : now);
    if (!variable_struct_exists(cur, "dur") || !is_real(cur.dur) || cur.dur <= 0) return;
    if (elapsed < 0 || elapsed > cur.dur) return;
    var frac_v = 0;
    frac_v = clamp(elapsed / cur.dur, 0, 1);

    // Draw different visuals by spec.type
    var t = string_lower(string(variable_struct_exists(spec, "type") ? variable_struct_get(spec, "type") : "unknown"));
    draw_set_color(c_white);
    draw_set_alpha(1);
    var _target_center = __battle_anim_legacy_target_center(_pid, spec);
    var tx = _target_center[0];
    var ty = _target_center[1];

    if (t == "status_inflict" || t == "status_apply"){
        var st = (variable_struct_exists(spec, "status") ? string(variable_struct_get(spec, "status")) : "");
        var _visual = __battle_anim_legacy_status_visual(st);
        __battle_anim_legacy_burst(_pid, tx, ty - __battle_anim_queue_hu(_pid, 10, 10), _visual, frac_v, 14, 24);
        draw_set_alpha(max(0, 1 - frac_v * 1.25));
        draw_set_color(__battle_anim_legacy_visual_color(_visual));
        if (_visual == "sleep") draw_text(tx - __battle_anim_queue_wu(_pid, 8, 8), ty - __battle_anim_queue_hu(_pid, 34, 34), "Z");
        draw_set_alpha(1);
    } else if (t == "status_tick_damage" || t == "confusion_hit"){
        var amt = (variable_struct_exists(spec, "amount") ? string(variable_struct_get(spec, "amount")) : "");
        var _tick_status = (t == "confusion_hit") ? "confusion" : (variable_struct_exists(spec, "status") ? variable_struct_get(spec, "status") : "impact");
        __battle_anim_legacy_burst(_pid, tx, ty - __battle_anim_queue_hu(_pid, 8, 8), __battle_anim_legacy_status_visual(_tick_status), frac_v, 10, 20);
        var y_off = - (frac_v * __battle_anim_queue_hu(_pid, 20, 20));
        draw_set_alpha(max(0, 1 - frac_v * 0.9));
        draw_set_color(c_red);
        if (amt != "") draw_text(tx, ty + y_off, "-" + string(amt));
        draw_set_alpha(1);
        draw_set_color(c_white);
    } else if (t == "status_blocked"){
        var st2 = (variable_struct_exists(spec, "status") ? string(variable_struct_get(spec, "status")) : "");
        __battle_anim_legacy_burst(_pid, tx, ty - __battle_anim_queue_hu(_pid, 10, 10), "shield", frac_v, 8, 26);
        draw_set_alpha(max(0, 1 - frac_v));
        draw_set_color(c_yellow);
        draw_text(tx - __battle_anim_queue_wu(_pid, 24, 24), ty - __battle_anim_queue_hu(_pid, 36, 36), string_upper(st2) + "!");
        draw_set_alpha(1);
        draw_set_color(c_white);
    } else {
        var _fallback_visual = "impact";
        if (t == "heal" || t == "recover" || t == "revive") _fallback_visual = "heal";
        else if (t == "stat_change" || t == "stat_up" || t == "boost"){
            var _dir = (variable_struct_exists(spec, "direction") && is_real(spec.direction)) ? spec.direction : 1;
            _fallback_visual = (_dir < 0) ? "stat_down" : "stat_up";
        } else if (t == "stat_down" || t == "debuff") _fallback_visual = "stat_down";
        else if (t == "protected" || t == "protect" || t == "block" || t == "failed") _fallback_visual = "shield";
        else if (t == "flinch" || t == "recoil" || t == "charge" || t == "focus_energy") _fallback_visual = "impact";
        else if (t == "transform") _fallback_visual = "confusion";

        if (variable_global_exists("DATA_DEBUG_VERBOSE") && global.DATA_DEBUG_VERBOSE){
            try { show_debug_message("[battle][anim] fallback spec=" + string(spec)); } catch (e) {}
        }
        __battle_anim_legacy_burst(_pid, tx, ty - __battle_anim_queue_hu(_pid, 8, 8), _fallback_visual, frac_v, 12, 22);
    }
}
