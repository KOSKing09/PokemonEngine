var _win_w = window_get_fullscreen() ? display_get_width() : window_get_width();
var _win_h = window_get_fullscreen() ? display_get_height() : window_get_height();
var _surf_w = surface_get_width(application_surface);
var _surf_h = surface_get_height(application_surface);
var _scale = max(_win_w / max(1, _surf_w), _win_h / max(1, _surf_h));
var _draw_w = floor(_surf_w * _scale);
var _draw_h = floor(_surf_h * _scale);
var _draw_x = floor((_win_w - _draw_w) * 0.5);
var _draw_y = floor((_win_h - _draw_h) * 0.5);

draw_surface_stretched_ext(application_surface, _draw_x, _draw_y, _draw_w, _draw_h, c_white, 1);
