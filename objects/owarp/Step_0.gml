if (_room == noone) exit;
if (!is_undefined(transition_is_blocking) && transition_is_blocking()) exit;

var _left = bbox_left + 1;
var _right = bbox_right - 1;
var _top = bbox_top + 1;
var _bottom = bbox_bottom - 1;
var _opts = { transition_style: trans_style };

for (var _pid = 0; _pid < 2; ++_pid){
    var _pl = player_by_pid(_pid);
    if (_pl == noone) continue;
    if (_pid == 1 && !multiplayer_player_joined(1)) continue;

    var _moving_into_warp = controls_down(_pid, "MoveUp") || controls_down(_pid, "MoveRight") || controls_down(_pid, "MoveDown") || controls_down(_pid, "MoveLeft");
    if (!_moving_into_warp) continue;
    if (world_warp_player_if_in_rect(_pid, _left, _top, _right, _bottom, _room, _x, _y, _opts)) exit;
}