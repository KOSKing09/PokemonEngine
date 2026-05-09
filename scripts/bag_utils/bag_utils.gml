// Bag utilities: defaults, placeholder lookup, rect scaler, and item helpers.
function __bag_impl__ensure_props(_s, _names, _defs){ if (!is_struct(_s) || !is_array(_names) || !is_array(_defs)) return; var n = min(array_length(_names), array_length(_defs)); for (var i = 0; i < n; i++){ var k = _names[i]; if (!variable_struct_exists(_s, k)) variable_struct_set(_s, k, _defs[i]); } }

function __bag_impl__default_bag(){ return { open:false, mode:"bag", page:0, sel:0, scroll:0, spin_ticks:0, items:[[],[],[],[],[]], sys_qty:[], item_menu_open:false, item_menu_sel:0, item_menu_row:0, lock:0, registered_item_id:-1, registered_item_name:"", registered_item_real_name:"" }; }

function __bag_impl__empty_items(){ return [[],[],[],[],[]]; }

function __bag_impl__get_item_placeholder(){ var ph = asset_get_index("spr_item_placeholder"); if (ph == -1 && variable_global_exists("PKICONS") && is_struct(PKICONS) && variable_struct_exists(PKICONS, "missing_icon32")) ph = variable_struct_get(PKICONS, "missing_icon32"); return ph; }

function __bag_impl__bag_rect_scaler(_rx, _ry, _rw, _rh){ var _s = max(1, min(floor(_rw / 240), floor(_rh / 160))); var _ox = _rx + (_rw - 240 * _s) div 2; var _oy = _ry + (_rh - 160 * _s) div 2; return { s:_s, ox:_ox, oy:_oy, rw:_rw, rh:_rh }; }

function __bag_impl__bag_ui_rect_gui(){ var _gw = display_get_gui_width(); var _gh = display_get_gui_height(); return __bag_impl__bag_rect_scaler(0,0,_gw,_gh); }
