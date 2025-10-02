/// @file scr_npc_basic.gml
/// Drop-in helpers for a grid-based wandering NPC. You can adapt to objects if you prefer.
function npc_init(_self) {
    _self.grid_x = _self.grid_x ?? 0;
    _self.grid_y = _self.grid_y ?? 0;
    _self.face_x = _self.face_x ?? 0;
    _self.face_y = _self.face_y ?? 1;
    _self.move_cooldown = 0;
    _self.blocking = true;
    _self.on_interact = function(player) {
        if (function_exists(dlg_show)) dlg_show(["Hi!", "Nice weather today."]);
    };
    _self.direction_face = function(dx,dy){ _self.face_x = dx; _self.face_y = dy; };
}
function npc_step(_self) {
    if (_self.move_cooldown > 0) { _self.move_cooldown -= 1; return; }
    if (irandom(100) < 2) { // random idle turn or step
        var r = irandom(3);
        if (r == 0) { _self.direction_face( 0,-1); }
        if (r == 1) { _self.direction_face( 0, 1); }
        if (r == 2) { _self.direction_face(-1, 0); }
        if (r == 3) { _self.direction_face( 1, 0); }
    }
}
function npc_find_at_tile(_tx,_ty) {
    var inst = noone;
    with (all) {
        if (variable_instance_exists(id,"grid_x") && variable_instance_exists(id,"grid_y")) {
            if (grid_x == _tx && grid_y == _ty) { inst = id; break; }
        }
    }
    return inst;
}
