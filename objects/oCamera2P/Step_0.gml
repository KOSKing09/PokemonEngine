/// oCamera2P Step
function __hard_center(_cam, _tgt, _shake, _snap){
    if (!instance_exists(_tgt)) return;

    var vw = camera_get_view_width(_cam);
    var vh = camera_get_view_height(_cam);

    var cx = _tgt.x - vw * 0.5;
    var cy = _tgt.y - vh * 0.5;

    cx = clamp(cx, 0, max(0, room_width  - vw));
    cy = clamp(cy, 0, max(0, room_height - vh));

    var ofs = cam_shake_update(_shake);
    var nx = cx + ofs.x;
    var ny = cy + ofs.y;

    if (_snap) { nx = round(nx); ny = round(ny); }
    camera_set_view_pos(_cam, nx, ny);
}

__hard_center(cam1, target1, shake1, pixel_snap);
__hard_center(cam2, target2, shake2, pixel_snap);

/* how to shake cameras!
with (oCamera2P) {
    cam_shake_start(shake1, 10, 20, 24, 0.9); // shake left (P1)
    cam_shake_start(shake2,  6, 14, 22, 0.9); // shake right (P2)
}
*/