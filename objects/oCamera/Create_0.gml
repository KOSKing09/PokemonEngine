/// oCamera Create
BASE_W = 240;
BASE_H = 160;
scale  = 3;            // window scale (e.g., 3 => 720×480)
pixel_snap = true;     // round to integers for crisp tiles

//window_set_size(BASE_W * scale, BASE_H * scale);

view_enabled    = true;
view_visible[0] = true;

cam = camera_create_view(0, 0, BASE_W, BASE_H, 0, noone, -1, -1, -1, -1);
view_camera[0] = cam;

// follow target (assign after spawning your player)
target = global.p1;

// set up shake
shake = cam_shake_create();
