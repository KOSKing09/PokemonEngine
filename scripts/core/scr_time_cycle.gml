/// @file scr_time_cycle.gml
/// Simple day/night manager with four buckets: Morning/Day/Evening/Night
globalvar TIME;
if (!variable_global_exists("TIME")) {
    TIME = { hour: 12, minute: 0, rate: 1/60, bucket: "Day" }; // rate: in-game minutes per real step
}

function time_update() {
    TIME.minute += TIME.rate;
    if (TIME.minute >= 60) { TIME.hour += 1; TIME.minute -= 60; }
    if (TIME.hour >= 24) TIME.hour -= 24;
    var h = floor(TIME.hour);
    var b = "Day";
    if (h >= 5 && h < 9)  b = "Morning";
    else if (h >= 9 && h < 17) b = "Day";
    else if (h >= 17 && h < 20) b = "Evening";
    else b = "Night";
    TIME.bucket = b;
}

function time_set(_hour, _minute) { TIME.hour = clamp(_hour,0,23); TIME.minute = clamp(_minute,0,59); }
function time_get_bucket() { return TIME.bucket; }
