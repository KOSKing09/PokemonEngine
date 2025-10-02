/// @file scr_overworld_events.gml
globalvar EVENTS, EVENT_FLAGS;
if (!variable_global_exists("EVENTS")) EVENTS = { triggers: [], warps: [] };
if (!variable_global_exists("EVENT_FLAGS")) EVENT_FLAGS = ds_map_create();

function events_clear_room() { EVENTS.triggers = []; EVENTS.warps = []; }
function event_flag_get(_k) { return EVENT_FLAGS[? _k]; }
function event_flag_set(_k, _v) { ds_map_replace(EVENT_FLAGS, _k, _v); }

function events_register_trigger(_rect, _cb_enter, _flag_once_key) {
    array_push(EVENTS.triggers, {rect:_rect, cb:_cb_enter, once:_flag_once_key});
}
function events_register_warp(_rect, _room_name, _x, _y, _facing) {
    array_push(EVENTS.warps, {rect:_rect, room:_room_name, x:_x, y:_y, face:_facing});
}

function events_update(_px, _py) {
    // triggers
    for (var i=0;i<array_length(EVENTS.triggers);++i) {
        var t = EVENTS.triggers[i];
        if (point_in_rectangle(_px, _py, t.rect[0], t.rect[1], t.rect[2], t.rect[3])) {
            if (is_string(t.once)) {
                if (event_flag_get(t.once)) continue;
                event_flag_set(t.once, true);
            }
            if (is_method(t.cb)) t.cb();
        }
    }
    // warps
    for (var j=0;j<array_length(EVENTS.warps);++j) {
        var w = EVENTS.warps[j];
        if (point_in_rectangle(_px, _py, w.rect[0], w.rect[1], w.rect[2], w.rect[3])) {
            room_goto(asset_get_index(w.room));
            // position will need to be applied by your room start controller
        }
    }
}
