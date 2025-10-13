// Debug helper: print the parsed effects for an item id
function debug_print_item_effect(_item_id){
    if (!is_real(_item_id) || _item_id <= 0){ show_debug_message("[debug_item_effects] invalid id"); return; }
    if (!variable_global_exists("_item_effects") || !is_array(global._item_effects)){ show_debug_message("[debug_item_effects] _item_effects missing"); return; }
    if (_item_id >= array_length(global._item_effects)){ show_debug_message("[debug_item_effects] id out of range"); return; }
    var effs = global._item_effects[_item_id];
    if (!is_array(effs) || array_length(effs) == 0){ show_debug_message("[debug_item_effects] no parsed effects for id=" + string(_item_id)); return; }
    show_debug_message("[debug_item_effects] item=" + string(_item_id) + ", effects_count=" + string(array_length(effs)));
    for (var i = 0; i < array_length(effs); i++){
        var e = effs[i];
        if (is_struct(e)){
            var t = (variable_struct_exists(e, "type") ? string(variable_struct_get(e, "type")) : "(unknown)");
            var p = (variable_struct_exists(e, "params") ? string(json_encode(e.params)) : "{}");
            show_debug_message(" - effect[" + string(i) + "]: type=" + t + ", params=" + p);
        } else {
            show_debug_message(" - effect[" + string(i) + "]: raw=" + string(e));
        }
    }
}
