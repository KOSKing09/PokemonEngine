/// @file scr_world_core.gml
globalvar WORLD_CORE;
if (!variable_global_exists("WORLD_CORE")) {
    WORLD_CORE = {
        encounter_step_min: 12,
        encounter_step_max: 28,
        base_rate: 1.0,
        steps_until_enc: irandom_range(12,28),
        surface: "grass",
        on_enter: function(_){},
        on_exit: function(){},
        on_update: function(){
            time_update();
            if (function_exists(controls_update)) controls_update();
            // Interact
            if (function_exists(controls_pressed) && controls_pressed("Interact",0)) {
                if (variable_global_exists("obj_player")) {
                    var p = instance_find(obj_player,0); if (instance_exists(p)) interact_try(p);
                }
            }
        },
        on_draw: function(){
            draw_set_color(c_white);
            draw_text(12,12, "[Time] " + string(floor(TIME.hour)) + ":" + string_format(TIME.minute,2,0) + "  " + TIME.bucket);
            var z = zone_active();
            draw_text(12,28, "[Zone] " + z.id + "  Set:" + z.enc_set_id + "  Weather:" + z.weather);
        },
        on_input: function(){}
    };
}

function engine_core_bootstrap() {
    // Register world scene if you use the stack
    if (function_exists(scene_register)) scene_register("world", WORLD_CORE);
    // Seed a default zone and encounter set if none registered
    if (ds_map_size(ZONES) == 0) {
        zone_register("Route 1", "route1", "", "Clear", 1.0);
        zone_set_active("Route 1", "route1");
    }
    if (ds_map_size(ENCOUNTER_SETS) == 0) {
        encounter_define_set("route1", {
            grass: {
                Morning: [ {mon:"Pidgey", lvl:[3,5], weight:55}, {mon:"Rattata", lvl:[2,4], weight:45} ],
                Day:     [ {mon:"Pidgey", lvl:[3,5], weight:50}, {mon:"Rattata", lvl:[2,4], weight:50} ],
                Evening: [ {mon:"Pidgey", lvl:[3,6], weight:40}, {mon:"Rattata", lvl:[3,5], weight:60} ],
                Night:   [ {mon:"Hoothoot", lvl:[3,5], weight:70}, {mon:"Rattata", lvl:[2,4], weight:30} ]
            }
        });
    }
}

function world_register_step(_in_grass, _count) {
    var c = is_undefined(_count) ? 1 : _count;
    repel_consume_step();
    var mult = zone_active().mult * WORLD_CORE.base_rate;
    if (repel_is_active()) mult *= 0.1;
    WORLD_CORE.surface = _in_grass ? "grass" : "none";
    if (!_in_grass) return;
    WORLD_CORE.steps_until_enc -= c;
    if (WORLD_CORE.steps_until_enc <= 0) {
        WORLD_CORE.steps_until_enc = irandom_range(WORLD_CORE.encounter_step_min, WORLD_CORE.encounter_step_max);
        if (random(1) <= mult) {
            var pick = encounter_roll_zone("grass");
            if (!is_undefined(pick)) {
                if (function_exists(battle_start)) {
                    var lvl = irandom_range(pick.lvl[0], pick.lvl[1]);
                    battle_start(pick.mon, lvl);
                }
            }
        }
    }
}
