var _gw = display_get_gui_width();
var _gh = display_get_gui_height();
var _evo0 = (!is_undefined(evolution_is_active) && evolution_is_active(0));
var _evo1 = (!is_undefined(evolution_is_active) && evolution_is_active(1));
var _vk0 = (!is_undefined(virtual_keyboard_is_active) && virtual_keyboard_is_active(0));
var _vk1 = (!is_undefined(virtual_keyboard_is_active) && virtual_keyboard_is_active(1));
if (!is_undefined(splitscreen_apply_gui_size)) splitscreen_apply_gui_size();
_gw = display_get_gui_width();
_gh = display_get_gui_height();

var _shared_battle = (!is_undefined(splitscreen_should_use_shared_screen) && splitscreen_should_use_shared_screen());
if (_shared_battle){
    var _sw = display_get_gui_width();
    var _sh = display_get_gui_height();
    var _battle_draw_pid = 0;
    if (!battle_is_open(0) && battle_is_open(1)) _battle_draw_pid = 1;
    if (!is_undefined(__battle_ensure_slot)){
        var _shared_slot = __battle_ensure_slot(_battle_draw_pid);
        if (is_struct(_shared_slot) && variable_struct_exists(_shared_slot, "_command_actor_index") && is_real(variable_struct_get(_shared_slot, "_command_actor_index")) && !is_undefined(__battle_actor_owner_pid)){
            var _cmd_owner = __battle_actor_owner_pid(_battle_draw_pid, variable_struct_get(_shared_slot, "_command_actor_index"));
            if (is_real(_cmd_owner) && _cmd_owner >= 0 && battle_is_open(floor(_cmd_owner))) _battle_draw_pid = floor(_cmd_owner);
        }
    }
    if (battle_is_open(_battle_draw_pid)) battle_draw_gui_rect(_battle_draw_pid, 0, 0, _sw, _sh);
    if (pause_is_open(0)) pause_draw_gui_rect(0, 0, 0, _sw, _sh);
    if (pause_is_open(1)) pause_draw_gui_rect(1, 0, 0, _sw, _sh);
    if (bag_is_open(0)) bag_draw_gui_rect(0, 0, 0, _sw, _sh);
    if (bag_is_open(1)) bag_draw_gui_rect(1, 0, 0, _sw, _sh);
    if (poke_index_is_open(0)) poke_index_draw_gui_rect(0, 0, 0, _sw, _sh);
    if (poke_index_is_open(1)) poke_index_draw_gui_rect(1, 0, 0, _sw, _sh);
    if (party_is_open(0)) party_draw_gui_rect(0, 0, 0, _sw, _sh);
    if (!is_undefined(pc_is_open) && pc_is_open(0) && !is_undefined(pc_draw_gui_rect)) pc_draw_gui_rect(0, 0, 0, _sw, _sh);
    if (!is_undefined(pc_is_open) && pc_is_open(1) && !is_undefined(pc_draw_gui_rect)) pc_draw_gui_rect(1, 0, 0, _sw, _sh);
    if (party_is_open(1)) party_draw_gui_rect(1, 0, 0, _sw, _sh);
    if (_evo0) evolution_draw_gui_rect(0, 0, 0, _sw, _sh);
    if (_evo1) evolution_draw_gui_rect(1, 0, 0, _sw, _sh);
    if (_vk0) virtual_keyboard_draw_gui_rect(0, 0, 0, _sw, _sh);
    if (_vk1) virtual_keyboard_draw_gui_rect(1, 0, 0, _sw, _sh);
} else if (instance_number(oPlayer) > 1) {
    // --- Splitscreen ---
    var _r0 = (!is_undefined(splitscreen_get_gui_rect)) ? splitscreen_get_gui_rect(0) : [0, 0, _gw div 2, _gh];
    var _r1 = (!is_undefined(splitscreen_get_gui_rect)) ? splitscreen_get_gui_rect(1) : [_gw div 2, 0, _gw div 2, _gh];

    // P2
    if (battle_is_open(1)){
    if (variable_global_exists("DATA_DEBUG_VERBOSE") && global.DATA_DEBUG_VERBOSE) show_debug_message("[draw64][debug] calling battle_draw_gui_rect pid=1");
        battle_draw_gui_rect(1, _r1[0], _r1[1], _r1[2], _r1[3]);
    }
    if (pause_is_open(1)) pause_draw_gui_rect(1, _r1[0], _r1[1], _r1[2], _r1[3]);
    if (bag_is_open(1))   bag_draw_gui_rect(1, _r1[0], _r1[1], _r1[2], _r1[3]);
    if (poke_index_is_open(1)) poke_index_draw_gui_rect(1, _r1[0], _r1[1], _r1[2], _r1[3]);
    if (party_is_open(1)) party_draw_gui_rect(1, _r1[0], _r1[1], _r1[2], _r1[3]);
    if (!is_undefined(pc_is_open) && pc_is_open(1) && !is_undefined(pc_draw_gui_rect)) pc_draw_gui_rect(1, _r1[0], _r1[1], _r1[2], _r1[3]);
    if (_evo1) evolution_draw_gui_rect(1, _r1[0], _r1[1], _r1[2], _r1[3]);
    if (_vk1) virtual_keyboard_draw_gui_rect(1, _r1[0], _r1[1], _r1[2], _r1[3]);
    if (!battle_is_open(1) && (is_undefined(battle_any_open) || !battle_any_open()) && !is_undefined(dialog2p_is_open) && dialog2p_is_open(1)){
        dialog2p_draw_gui_rect(1, _r1[0], _r1[1], _r1[2], _r1[3]);
    }

    // P1 draws last so its UI stays on top when battler/platform sprites spill over the split boundary.
    if (battle_is_open(0)){
    if (variable_global_exists("DATA_DEBUG_VERBOSE") && global.DATA_DEBUG_VERBOSE) show_debug_message("[draw64][debug] calling battle_draw_gui_rect pid=0");
        battle_draw_gui_rect(0, _r0[0], _r0[1], _r0[2], _r0[3]);
    }
    if (pause_is_open(0)) pause_draw_gui_rect(0, _r0[0], _r0[1], _r0[2], _r0[3]);
    if (bag_is_open(0))   bag_draw_gui_rect(0, _r0[0], _r0[1], _r0[2], _r0[3]);
    if (poke_index_is_open(0)) poke_index_draw_gui_rect(0, _r0[0], _r0[1], _r0[2], _r0[3]);
    if (party_is_open(0)) party_draw_gui_rect(0, _r0[0], _r0[1], _r0[2], _r0[3]);
    if (!is_undefined(pc_is_open) && pc_is_open(0) && !is_undefined(pc_draw_gui_rect)) pc_draw_gui_rect(0, _r0[0], _r0[1], _r0[2], _r0[3]);
    if (_evo0) evolution_draw_gui_rect(0, _r0[0], _r0[1], _r0[2], _r0[3]);
    if (_vk0) virtual_keyboard_draw_gui_rect(0, _r0[0], _r0[1], _r0[2], _r0[3]);
    if (!battle_is_open(0) && (is_undefined(battle_any_open) || !battle_any_open()) && !is_undefined(dialog2p_is_open) && dialog2p_is_open(0)){
        dialog2p_draw_gui_rect(0, _r0[0], _r0[1], _r0[2], _r0[3]);
    }
} else {
    // --- Single player ---
    if (battle_is_open(0)){
    if (variable_global_exists("DATA_DEBUG_VERBOSE") && global.DATA_DEBUG_VERBOSE) show_debug_message("[draw64][debug] calling battle_draw_gui pid=0");
        battle_draw_gui(0);
    }
    if (pause_is_open(0)) pause_draw_gui(0);  // your full-screen wrapper
    if (bag_is_open(0))   bag_draw_gui(0);                    // your full-screen wrapper
    if (poke_index_is_open(0)) poke_index_draw_gui(0);
    if (party_is_open(0)) party_draw_gui(0);
    if (!is_undefined(pc_is_open) && pc_is_open(0) && !is_undefined(pc_draw_gui)) pc_draw_gui(0);
    if (_evo0) evolution_draw_gui(0);
    if (_vk0) virtual_keyboard_draw_gui(0);

    // Draw any world-space dialogs last so they appear on top of party/bag UI
    if (!battle_is_open(0) && (is_undefined(battle_any_open) || !battle_any_open()) && !is_undefined(dialog2p_is_open) && dialog2p_is_open(0)){
        dialog2p_draw_gui_rect(0, 0, 0, _gw, _gh);
    }
}

if (!is_undefined(transition_draw_gui)) transition_draw_gui();
