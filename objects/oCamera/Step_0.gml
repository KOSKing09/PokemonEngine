/// oCamera Step
if (!instance_exists(target)) exit;

var vw = camera_get_view_width(cam);
var vh = camera_get_view_height(cam);

// exact center on target (no lerp; hard lock)
var center_x = target.x - vw * 0.5;
var center_y = target.y - vh * 0.5;

// clamp to room
center_x = clamp(center_x, 0, max(0, room_width  - vw));
center_y = clamp(center_y, 0, max(0, room_height - vh));

// screen shake offset
var ofs = cam_shake_update(shake);
var next_x = center_x + ofs.x;
var next_y = center_y + ofs.y;

// pixel snap
if (pixel_snap) { next_x = round(next_x); next_y = round(next_y); }

camera_set_view_pos(cam, next_x, next_y);

/* how to shake the camera
with (oCamera) cam_shake_start(shake, 8, 18, 28, 0.88);
// amp=8px, duration=18 frames, ~28Hz, decay=0.88
*/
