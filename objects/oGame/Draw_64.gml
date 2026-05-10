var _gw = display_get_gui_width();
var _gh = display_get_gui_height();
var _evo0 = (!is_undefined(evolution_is_active) && evolution_is_active(0));
var _evo1 = (!is_undefined(evolution_is_active) && evolution_is_active(1));
var _vk0 = (!is_undefined(virtual_keyboard_is_active) && virtual_keyboard_is_active(0));
var _vk1 = (!is_undefined(virtual_keyboard_is_active) && virtual_keyboard_is_active(1));

if (instance_number(oPlayer) > 1) {
    // --- Splitscreen ---
    // Left (P1)
    if (battle_is_open(0)){
    if (variable_global_exists("DATA_DEBUG_VERBOSE") && global.DATA_DEBUG_VERBOSE) show_debug_message("[draw64][debug] calling battle_draw_gui_rect pid=0");
        battle_draw_gui_rect(0, 0, 0, _gw div 2, _gh);
    }
    if (pause_is_open(0)) pause_draw_gui_rect(0, 0,          0, _gw div 2, _gh);
    if (bag_is_open(0))   bag_draw_gui_rect(0, 0,          0, _gw div 2, _gh);
    if (party_is_open(0)) party_draw_gui_rect(0, 0,     0, _gw div 2, _gh);
    if (_evo0) evolution_draw_gui_rect(0, 0, 0, _gw div 2, _gh);
    if (_vk0) virtual_keyboard_draw_gui_rect(0, 0, 0, _gw div 2, _gh);
    if (!battle_is_open(0) && !is_undefined(dialog2p_is_open) && dialog2p_is_open(0)){
        dialog2p_draw_gui_rect(0, 0, 0, _gw div 2, _gh);
    }

    // Right (P2)
    if (battle_is_open(1)){
    if (variable_global_exists("DATA_DEBUG_VERBOSE") && global.DATA_DEBUG_VERBOSE) show_debug_message("[draw64][debug] calling battle_draw_gui_rect pid=1");
        battle_draw_gui_rect(1, _gw div 2, 0, _gw div 2, _gh);
    }
    if (pause_is_open(1)) pause_draw_gui_rect(1, _gw div 2,  0, _gw div 2, _gh);
    if (bag_is_open(1))   bag_draw_gui_rect(1, _gw div 2,  0, _gw div 2, _gh);
    if (party_is_open(1)) party_draw_gui_rect(1, _gw div 2, 0, _gw div 2, _gh);
    if (_evo1) evolution_draw_gui_rect(1, _gw div 2, 0, _gw div 2, _gh);
    if (_vk1) virtual_keyboard_draw_gui_rect(1, _gw div 2, 0, _gw div 2, _gh);
    if (!battle_is_open(1) && !is_undefined(dialog2p_is_open) && dialog2p_is_open(1)){
        dialog2p_draw_gui_rect(1, _gw div 2, 0, _gw div 2, _gh);
    }
} else {
    // --- Single player ---
    if (battle_is_open(0)){
    if (variable_global_exists("DATA_DEBUG_VERBOSE") && global.DATA_DEBUG_VERBOSE) show_debug_message("[draw64][debug] calling battle_draw_gui pid=0");
        battle_draw_gui(0);
    }
    if (pause_is_open(0)) pause_draw_gui(0);  // your full-screen wrapper
    if (bag_is_open(0))   bag_draw_gui(0);                    // your full-screen wrapper
    if (party_is_open(0)) party_draw_gui(0);
    if (_evo0) evolution_draw_gui(0);
    if (_vk0) virtual_keyboard_draw_gui(0);

    // Draw any world-space dialogs last so they appear on top of party/bag UI
    if (!battle_is_open(0) && !is_undefined(dialog2p_is_open) && dialog2p_is_open(0)){
        dialog2p_draw_gui_rect(0, 0, 0, _gw, _gh);
    }
}