var _gw = display_get_gui_width();
var _gh = display_get_gui_height();

if (instance_number(oPlayer) > 1) {
    // --- Splitscreen ---
    // Left (P1)
    if (bag_is_open(0))   bag_draw_gui_rect(0, 0,          0, _gw div 2, _gh);
    if (pause_is_open(0)) pause_draw_gui_rect(0, 0,          0, _gw div 2, _gh);
	if (party_is_open(0)) party_draw_gui_rect(0, 0,     0, _gw div 2, _gh);

    // Right (P2)
    if (bag_is_open(1))   bag_draw_gui_rect(1, _gw div 2,  0, _gw div 2, _gh);
    if (pause_is_open(1)) pause_draw_gui_rect(1, _gw div 2,  0, _gw div 2, _gh);
	if (party_is_open(1)) party_draw_gui_rect(1, _gw div 2, 0, _gw div 2, _gh);
} else {
    // --- Single player ---
    if (bag_is_open(0))   bag_draw_gui(0);                    // your full-screen wrapper
    if (pause_is_open(0)) pause_draw_gui(0);  // your full-screen wrapper
	if (party_is_open(0)) party_draw_gui(0);
	if (battle_is_open(0)) battle_draw_gui(0);
}