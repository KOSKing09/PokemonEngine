/// @file scr_zone_registry.gml
/// Zone holds encounter set id, music, weather, modifiers.
globalvar ZONES, __zone_active;
if (!variable_global_exists("ZONES")) ZONES = ds_map_create();
if (!variable_global_exists("__zone_active")) __zone_active = { id:"", enc_set_id:"default", music:"", weather:"Clear", mult:1.0 };

function zone_register(_id, _enc_set_id, _music, _weather, _mult) {
    var z = { id:_id, enc_set_id:_enc_set_id, music:_music, weather:_weather, mult:_mult };
    ds_map_replace(ZONES, _id, z);
}
function zone_get(_id) { return ZONES[? _id]; }

function zone_set_active(_id, _enc_set_id) {
    var z = zone_get(_id);
    if (is_undefined(z)) z = { id:_id, enc_set_id: _enc_set_id, music:"", weather:"Clear", mult:1.0 };
    __zone_active = z;
    if (!is_undefined(_enc_set_id)) __zone_active.enc_set_id = _enc_set_id;
}

function zone_active() { return __zone_active; }
