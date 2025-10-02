// scr_world_collision_simple.gml

globalvar WC;
WC = { tilemaps: [], tile_size: 16, solids: [], debug: false };

function wc_reset(){
    WC.tilemaps = [];
    WC.solids   = [];
    WC.tile_size = 16;
    WC.debug = false;
}

/// Bind ONLY collision tile layers (NOT ground/decor)
function wc_bind_layers(_names){
    WC.tilemaps = [];
    for (var i = 0; i < array_length(_names); i++){
        var lid = layer_get_id(_names[i]);
        if (lid == -1) continue;
        var tm = layer_tilemap_get_id(lid);
        if (tm != -1) array_push(WC.tilemaps, tm);
    }
    // infer tile size from first tilemap if present
    if (array_length(WC.tilemaps) > 0){
        var tm0 = WC.tilemaps[0];
        WC.tile_size = max(1, tilemap_get_tile_width(tm0));
    }
}

function wc_set_solids(_objs){ WC.solids = _objs; }
function wc_debug_draw_enable(_f){ WC.debug = !!_f; }

/// Return true if ANY bound collision tile overlaps the moved bbox
function wc_tiles_hit_rect(_l,_t,_r,_b){
    if (array_length(WC.tilemaps) == 0) return false;

    var ts = WC.tile_size;
    var cx0 = floor(_l / ts);
    var cy0 = floor(_t / ts);
    var cx1 = floor((_r - 1) / ts);
    var cy1 = floor((_b - 1) / ts);

    for (var ty = cy0; ty <= cy1; ty++){
        for (var tx = cx0; tx <= cx1; tx++){
            // sample each tilemap; any non-zero tile blocks
            for (var m = 0; m < array_length(WC.tilemaps); m++){
                var tm = WC.tilemaps[m];
                if (tilemap_get(tm, tx, ty) != 0) return true;
            }
        }
    }
    return false;
}

/// Collide at proposed position using YOUR mask (no offsets)
function wc_collides_at(_inst, _px, _py){
    var dx = _px - _inst.x;
    var dy = _py - _inst.y;

    var l = _inst.bbox_left   + dx;
    var r = _inst.bbox_right  + dx;
    var t = _inst.bbox_top    + dy;
    var b = _inst.bbox_bottom + dy;

    // tiles
    if (wc_tiles_hit_rect(l,t,r,b)) return true;

    // blocking objects via your mask
    if (is_array(WC.solids)){
        for (var i = 0; i < array_length(WC.solids); i++){
            var o = WC.solids[i];
            if (o == noone) continue;
            if (place_meeting(_px, _py, o)) return true;
        }
    }

    return false;
}
