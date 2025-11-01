// battle_state_overlay.gml
// Provides __battle_trigger_stat_overlay which creates a stat_overlay
// payload consumed by the battle animation queue. Designed as a safe,
// small implementation that chooses frame/direction and requests a
// full-field tiled background (bg=true).

function __battle_trigger_stat_overlay(_pid, _actor, _overlay_changes, _actor_idx){
    try {
        // Collect stat keys and deltas from provided _overlay_changes struct
        var _stat_keys = [];
        var _stat_deltas = {};
        var _any_pos = false;
        var _any_neg = false;
        var _known_keys = ["atk","def","spe","spa","spd","accuracy","evasion"];
        for (var _i=0; _i<array_length(_known_keys); ++_i){
            var _k = _known_keys[_i];
            if (variable_struct_exists(_overlay_changes, _k)){
                var _d = variable_struct_get(_overlay_changes, _k);
                array_push(_stat_keys, _k);
                variable_struct_set(_stat_deltas, _k, _d);
                if (is_real(_d) && _d > 0) _any_pos = true;
                if (is_real(_d) && _d < 0) _any_neg = true;
            }
        }

        // Map single-stat to frame index (0 = mixed/default)
        var _frame_idx = 0;
        if (array_length(_stat_keys) == 1){
            switch(string(_stat_keys[0])){
                case "atk": _frame_idx = 1; break;
                case "def": _frame_idx = 2; break;
                case "spe": _frame_idx = 3; break;
                case "spa": _frame_idx = 4; break;
                case "spd": _frame_idx = 5; break;
                case "accuracy": _frame_idx = 6; break;
                case "evasion": _frame_idx = 7; break;
                default: _frame_idx = 0; break;
            }
        }

        // Direction: 1 raise (all positive), -1 lower (all negative), 0 mixed/neutral
    var _direction = 0;
    if (_any_pos && !_any_neg) _direction = 1;
    else if (_any_neg && !_any_pos) _direction = -1;

    // Allow callers to override loops and darken via overlay_changes fields if provided
    var _bg_loops = undefined;
    if (variable_struct_exists(_overlay_changes, "bg_loops") && is_real(variable_struct_get(_overlay_changes, "bg_loops"))) _bg_loops = floor(variable_struct_get(_overlay_changes, "bg_loops"));
    var _darken = false;
    if (variable_struct_exists(_overlay_changes, "darken")) _darken = variable_struct_get(_overlay_changes, "darken");

    var payload = { type: "stat_overlay", frame: _frame_idx, darken: _darken, stat_keys: _stat_keys, stat_deltas: _stat_deltas, bg: true, direction: _direction };
    if (!is_undefined(_bg_loops)) payload.bg_loops = _bg_loops;

        try { battle_anim_queue_enqueue(_pid, payload); } catch (e_q) {}
    } catch (e) {
        if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) show_debug_message("[battle_state_overlay] __battle_trigger_stat_overlay failed: " + string(e));
    }
}
