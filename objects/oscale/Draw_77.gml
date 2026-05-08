if (!window_get_fullscreen()){
	draw_surface_stretched_ext(application_surface,0 ,0, window_get_width(), window_get_height(), c_white, 1);
}else{
	var _w, _h;
	_w = display_get_width();
	_h = display_get_height();
	draw_surface_stretched_ext(application_surface,0 ,0, _w, _h, c_white, 1);
}