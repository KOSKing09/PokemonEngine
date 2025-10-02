/// @file scr_scene_stack.gml
/// State/scene stack

globalvar __scene_stack, __scene_registry;
if (!variable_global_exists("__scene_stack"))  __scene_stack = [];
if (!variable_global_exists("__scene_registry")) __scene_registry = ds_map_create();

function scene_register(_name, _callbacks_struct) { ds_map_replace(__scene_registry, _name, _callbacks_struct); }

function scene_push(_name, _payload) {
    if (!ds_map_exists(__scene_registry, _name)) { show_debug_message("[scene] Unknown: " + string(_name)); return; }
    var cb = __scene_registry[? _name];
    array_push(__scene_stack, [_name, cb]);
    if (is_struct(cb) && is_method(cb.on_enter)) cb.on_enter(_payload);
}

function scene_pop() {
    if (array_length(__scene_stack) <= 0) return;
    var top_entry = array_pop(__scene_stack);
    var cb = top_entry[1];
    if (is_struct(cb) && is_method(cb.on_exit)) cb.on_exit();
}

function scene_clear() { while (array_length(__scene_stack) > 0) scene_pop(); }
function scene_top()   { return array_length(__scene_stack) > 0 ? __scene_stack[array_length(__scene_stack)-1] : undefined; }
function scene_is(_n)  { var t = scene_top(); return (is_array(t) && t[0] == _n); }

function scene_update() {
    var t = scene_top(); if (!is_array(t)) return;
    var cb = t[1];
    if (is_struct(cb) && is_method(cb.on_update)) cb.on_update();
    if (is_struct(cb) && is_method(cb.on_input))  cb.on_input();
}

function scene_draw() {
    var t = scene_top(); if (!is_array(t)) return;
    var cb = t[1];
    if (is_struct(cb) && is_method(cb.on_draw)) cb.on_draw();
}
