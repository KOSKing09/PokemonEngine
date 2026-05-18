/// oCamera Step
if (!is_undefined(player_by_pid)){
	target1 = player_by_pid(0);
	target2 = player_by_pid(1);
}

if (!variable_instance_exists(id, "bound_room")) bound_room = room;
if (bound_room != room){
	bound_room = room;
	split_layout = "";
}

if (is_undefined(__apply_ports)){
	split_layout = "";
} else {
	__apply_ports();
}

function __hard_center(_cam, _tgt, _shake, _snap){
	if (!instance_exists(_tgt)) return;

	var vw = camera_get_view_width(_cam);
	var vh = camera_get_view_height(_cam);

	var cx = _tgt.x - vw * 0.5;
	var cy = _tgt.y - vh * 0.5;

	var _overscroll = (variable_instance_exists(id, "allow_room_overscroll") && allow_room_overscroll == true);
	if (!_overscroll){
		var _bound_w = room_width;
		var _bound_h = room_height;
		if (variable_global_exists("ROGUE_ROOM_BOUNDS") && is_struct(global.ROGUE_ROOM_BOUNDS)){
			var _B = global.ROGUE_ROOM_BOUNDS;
			if (variable_struct_exists(_B, "active") && _B.active == true && variable_struct_exists(_B, "room") && _B.room == room){
				_bound_w = variable_struct_exists(_B, "w") ? real(_B.w) : _bound_w;
				_bound_h = variable_struct_exists(_B, "h") ? real(_B.h) : _bound_h;
			}
		}
		cx = clamp(cx, 0, max(0, _bound_w - vw));
		cy = clamp(cy, 0, max(0, _bound_h - vh));
	}

	var ofs = cam_shake_update(_shake);
	var nx = cx + ofs.x;
	var ny = cy + ofs.y;

	if (_snap) { nx = round(nx); ny = round(ny); }
	camera_set_view_pos(_cam, nx, ny);
}

__hard_center(cam1, target1, shake1, pixel_snap);
if (view_visible[1]) __hard_center(cam2, target2, shake2, pixel_snap);

/* how to shake cameras!
with (oCamera) {
	cam_shake_start(shake1, 10, 20, 24, 0.9); // shake left (P1)
	cam_shake_start(shake2,  6, 14, 22, 0.9); // shake right (P2)
}
*/
