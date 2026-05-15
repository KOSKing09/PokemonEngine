/// oCamera Create
if (instance_number(oCamera) > 1){
	var _primary = instance_find(oCamera, 0);
	if (_primary != id){
		instance_destroy();
		exit;
	}
}

BASE_W = 240;
BASE_H = 160;
scale  = 3;
pixel_snap = true;
split_layout = "";
single_surface_w = BASE_W * scale;
single_surface_h = BASE_H * scale;
vertical_surface_w = BASE_W * scale * 2;
vertical_surface_h = BASE_H * scale;
horizontal_surface_w = BASE_W * scale;
horizontal_surface_h = BASE_H * scale * 2;

if (!variable_global_exists("SPLITSCREEN_LAYOUT")) global.SPLITSCREEN_LAYOUT = "vertical";

__resize_app_surface = function(_w, _h){
	if (surface_exists(application_surface)){
		surface_resize(application_surface, max(1, floor(_w)), max(1, floor(_h)));
	}
};

view_enabled = true;

// LEFT view (P1)
cam1 = camera_create_view(0, 0, BASE_W, BASE_H, 0, noone, -1, -1, -1, -1);
view_camera[0] = cam1;
view_visible[0] = true;
view_set_wport(0, BASE_W * scale);
view_set_hport(0, BASE_H * scale);
view_set_xport(0, 0);
view_set_yport(0, 0);

// RIGHT view (P2)
cam2 = camera_create_view(0, 0, BASE_W, BASE_H, 0, noone, -1, -1, -1, -1);
view_camera[1] = cam2;
view_visible[1] = true;
view_set_wport(1, BASE_W * scale);
view_set_hport(1, BASE_H * scale);
view_set_xport(1, BASE_W * scale);
view_set_yport(1, 0);

target1 = global.p1;
target2 = global.p2;
bound_room = room;

shake1 = cam_shake_create();
shake2 = cam_shake_create();

__bind_room_views = function(){
	view_enabled = true;
	camera_set_view_size(cam1, BASE_W, BASE_H);
	view_camera[0] = cam1;
	camera_set_view_size(cam2, BASE_W, BASE_H);
	view_camera[1] = cam2;
};

__apply_ports = function(){
	__bind_room_views();

	var _shared = (!is_undefined(splitscreen_should_use_shared_screen) && splitscreen_should_use_shared_screen());
	var _layout = (!is_undefined(splitscreen_get_layout) ? splitscreen_get_layout() : "vertical");
	if (!instance_exists(target2)) _layout = "single";
	if (_shared) _layout = "single";
	var _target_surface_w = (_layout == "horizontal") ? horizontal_surface_w : ((_layout == "single") ? single_surface_w : vertical_surface_w);
	var _target_surface_h = (_layout == "horizontal") ? horizontal_surface_h : ((_layout == "single") ? single_surface_h : vertical_surface_h);
	var _surface_ready = surface_exists(application_surface)
		&& surface_get_width(application_surface) == _target_surface_w
		&& surface_get_height(application_surface) == _target_surface_h;
	if (split_layout == _layout && _surface_ready) return;
	split_layout = _layout;

	if (_layout == "horizontal"){
		__resize_app_surface(_target_surface_w, _target_surface_h);
		view_visible[0] = true;
		view_visible[1] = true;
		view_set_wport(0, BASE_W * scale);
		view_set_hport(0, BASE_H * scale);
		view_set_xport(0, 0);
		view_set_yport(0, 0);
		view_set_wport(1, BASE_W * scale);
		view_set_hport(1, BASE_H * scale);
		view_set_xport(1, 0);
		view_set_yport(1, BASE_H * scale);
	} else if (_layout == "single"){
		__resize_app_surface(_target_surface_w, _target_surface_h);
		view_visible[0] = true;
		view_visible[1] = false;
		view_set_wport(0, BASE_W * scale);
		view_set_hport(0, BASE_H * scale);
		view_set_xport(0, 0);
		view_set_yport(0, 0);
	} else {
		__resize_app_surface(_target_surface_w, _target_surface_h);
		view_visible[0] = true;
		view_visible[1] = true;
		view_set_wport(0, BASE_W * scale);
		view_set_hport(0, BASE_H * scale);
		view_set_xport(0, 0);
		view_set_yport(0, 0);
		view_set_wport(1, BASE_W * scale);
		view_set_hport(1, BASE_H * scale);
		view_set_xport(1, BASE_W * scale);
		view_set_yport(1, 0);
	}
	if (!is_undefined(splitscreen_apply_gui_size)) splitscreen_apply_gui_size();
};

__apply_ports();
