
// Bind as many solid layers as you like (must match existing room layers)
wc_bind_layers(["WALL", "BLOCKS"]);

// Add any blocking objects; you can include noone as a placeholder
wc_set_solids([noone]);

if !(window_get_fullscreen()) {
    window_set_position(0, 0);
    window_set_size(display_get_width(), display_get_height());
}