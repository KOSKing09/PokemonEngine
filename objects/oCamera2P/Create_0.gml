/// oCamera2P Create
BASE_W = 240;
BASE_H = 160;
scale  = 3;
pixel_snap = true;

window_set_size(BASE_W * scale * 2, BASE_H * scale);

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

// targets
target1 = global.p1;
target2 = global.p2;

// independent shakes
shake1 = cam_shake_create();
shake2 = cam_shake_create();
