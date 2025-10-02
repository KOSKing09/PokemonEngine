/// @file scr_save_flags.gml
function world_save_to_json() {
    var data = {
        time: TIME,
        zone: zone_active(),
        flags: EVENT_FLAGS,
        repel: REPEL
    };
    return json_stringify(data);
}
function world_load_from_json(_json) {
    var data = json_parse(_json);
    TIME = data.time;
    __zone_active = data.zone;
    EVENT_FLAGS = data.flags;
    REPEL = data.repel;
}
