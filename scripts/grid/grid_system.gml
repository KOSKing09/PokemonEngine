/// grid_init(inst, tile_size, walk_px_per_frame, run_px_per_frame)
function grid_init(_inst, _tile=16, _walk=1, _run=2){
    // ensure the per-instance 'grid' struct exists BEFORE reading it
    var g;
    if (variable_instance_exists(_inst, "grid") && is_struct(_inst.grid)) {
        g = _inst.grid;
    } else {
        g = {};
        _inst.grid = g;
    }

    g.tile        = max(1, _tile);
    g.walk_speed  = max(1, _walk);
    g.run_speed   = max(g.walk_speed, _run);
    g.state       = "idle";   // "idle" | "move"
    g.dir         = 2;        // 0 up,1 right,2 down,3 left
    g.tx          = 0;        // target pixel x
    g.ty          = 0;        // target pixel y

    if (!variable_struct_exists(g, "block_cb")) g.block_cb = undefined;

    grid_snap_to_tile(_inst);
}

/// grid_snap_to_tile(inst)
// Align the *feet line* (bbox_bottom) and *mid-foot X* to the grid,
// so it works regardless of sprite origin (center, bottom-center, etc).
function grid_snap_to_tile(_inst){
    var ts = _inst.grid.tile; // 16
    _inst.x = round(_inst.x / ts) * ts;
    _inst.y = round(_inst.y / ts) * ts;
}



/// grid_set_block_checker(inst, fn_block)  // fn(inst, px, py) -> bool
function grid_set_block_checker(_inst, _fn){
    if (!(variable_instance_exists(_inst,"grid") && is_struct(_inst.grid))) _inst.grid = {};
    _inst.grid.block_cb = _fn;
}

/// INTERNAL: grid_is_blocked(inst, px, py)
function grid_is_blocked(_inst, _px, _py){
    return wc_collides_at(_inst, _px, _py);
}


/// grid_try_start(inst, dir) -> bool
function grid_try_start(_inst, _dir){
    if (!(variable_instance_exists(_inst,"grid") && is_struct(_inst.grid))) return false;
    var g  = _inst.grid;
    var ts = g.tile;

    var dx = 0, dy = 0;
    switch (_dir){
        case 0: dy = -ts; break; // up
        case 1: dx =  ts; break; // right
        case 2: dy =  ts; break; // down
        case 3: dx = -ts; break; // left
    }

    var nx = _inst.x + dx;
    var ny = _inst.y + dy;

    if (grid_is_blocked(_inst, nx, ny)) return false;

    g.dir   = _dir;
    g.tx    = nx;
    g.ty    = ny;
    g.state = "move";
    return true;
}

/// grid_step(inst, pid)
function grid_step(_inst, _pid){
    if (!(variable_instance_exists(_inst,"grid") && is_struct(_inst.grid))) return;
    var g = _inst.grid;
    var ts = g.tile;
    var spd = controls_down(_pid, "Run") ? g.run_speed : g.walk_speed;

    switch (g.state){

        case "idle":
        {
            var mvL = controls_down(_pid, "MoveLeft");
            var mvR = controls_down(_pid, "MoveRight");
            var mvU = controls_down(_pid, "MoveUp");
            var mvD = controls_down(_pid, "MoveDown");

            // Priority: vertical then horizontal (classic feel)
            var started = false;
            if (mvU)  started = grid_try_start(_inst, 0);
            if (!started && mvD) started = grid_try_start(_inst, 2);
            if (!started && mvL) started = grid_try_start(_inst, 3);
            if (!started && mvR) started = grid_try_start(_inst, 1);

            if (!started) grid_snap_to_tile(_inst);
        }
        break;

        case "move":
        {
            var remx = g.tx - _inst.x;
            var remy = g.ty - _inst.y;

            var step_x = clamp(remx, -spd, spd);
            var step_y = clamp(remy, -spd, spd);

            var nx = _inst.x + step_x;
            var ny = _inst.y + step_y;

            if (!grid_is_blocked(_inst, nx, ny)){
                _inst.x = nx;
                _inst.y = ny;
            } else {
                // blocked mid-step: snap back to tile center and stop
                _inst.x = round(_inst.x / ts) * ts;
                _inst.y = round(_inst.y / ts) * ts;
                g.state = "idle";
                break;
            }

            // reached target tile?
            if (_inst.x == g.tx && _inst.y == g.ty){
                g.state = "idle";

                // optional auto-continue if still holding same dir
                var hold = false;
                switch (g.dir){
                    case 0: hold = controls_down(_pid, "MoveUp");    break;
                    case 1: hold = controls_down(_pid, "MoveRight"); break;
                    case 2: hold = controls_down(_pid, "MoveDown");  break;
                    case 3: hold = controls_down(_pid, "MoveLeft");  break;
                }
                if (hold) grid_try_start(_inst, g.dir);
            }
        }
        break;
    }
}
	
/// debug_grid_draw(cam, draw_block_tiles, draw_bbox_inst)
/// cam: camera id (e.g., view_camera[0])
/// draw_block_tiles: true/false — show solid tiles as red boxes
/// draw_bbox_inst:   instance id to outline bbox (or noone)
function debug_grid_draw(_cam, _drawTiles, _who){
    // --- camera view rect ---
    var _vx = camera_get_view_x(_cam);
    var _vy = camera_get_view_y(_cam);
    var _vw = camera_get_view_width(_cam);
    var _vh = camera_get_view_height(_cam);

    // --- grid size ---
    var ts = (variable_global_exists("WC") && is_struct(WC)) ? WC.tile_size : 16;

    // --- align start to grid ---
    var gx0 = floor(_vx / ts) * ts;
    var gy0 = floor(_vy / ts) * ts;
    var gx1 = _vx + _vw;
    var gy1 = _vy + _vh;

    // --- grid lines ---
    draw_set_alpha(0.35);
    draw_set_color($00BFFF);
    for (var xx = gx0; xx <= gx1; xx += ts){
        draw_line(xx, _vy, xx, _vy + _vh);
    }
    for (var yy = gy0; yy <= gy1; yy += ts){
        draw_line(_vx, yy, _vx + _vw, yy);
    }
    draw_set_alpha(1);

    // --- optional: draw solid tiles
    if (_drawTiles && variable_global_exists("WC") && is_array(WC.tilemaps) && array_length(WC.tilemaps) > 0){
        var cx0 = floor(_vx / ts);
        var cy0 = floor(_vy / ts);
        var cx1 = floor((_vx + _vw - 1) / ts);
        var cy1 = floor((_vy + _vh - 1) / ts);

        draw_set_alpha(0.25);
        draw_set_color(c_red);
        for (var ty = cy0; ty <= cy1; ty++){
            for (var tx = cx0; tx <= cx1; tx++){
                var _is_solid = false;
                for (var m = 0; m < array_length(WC.tilemaps); m++){
                    if (tilemap_get(WC.tilemaps[m], tx, ty) != 0){
                        _is_solid = true; break;
                    }
                }
                if (_is_solid){
                    var px = tx * ts;
                    var py = ty * ts;
                    draw_rectangle(px, py, px + ts, py + ts, false);
                }
            }
        }
        draw_set_alpha(1);
    }

    // --- optional: draw one instance's bbox ---
    if (_who != noone){
        draw_set_color(c_lime);
        draw_rectangle(_who.bbox_left, _who.bbox_top, _who.bbox_right, _who.bbox_bottom, false);

        // text: current tile coords of the instance
        var tx = floor(_who.x / ts);
        var ty = floor(_who.y / ts);
        draw_set_color(c_white);
        draw_text(_who.x + 8, _who.y - 24, "tile: " + string(tx) + "," + string(ty));
    }
}

