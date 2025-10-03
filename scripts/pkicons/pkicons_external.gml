// [Pokémon Data]: pkicons_external — Build v2.9.2 — 2025-10-03
// Changes
// - Keeps split defaults:
//      * Missing 32×32 icon => spr_mon_icon_placeholder
//      * Missing 96×96 art  => spr_mon_placeholder
// - Restores pkicons_get_icon32_dir (used by _by_mon)
// - Restores pkicons_icon32_frame_ui (2‑frame UI animator)
// - Uses robust 8‑tile grid + centered scaling (from v2.8.x)
//
// Safe to drop-in over v2.9.0. No legacy pkicons_set_missing_sprite shim (you removed that call).

globalvar PKICONS;

function pkicons_init(){
    if (!variable_global_exists("PKICONS")){
        global.PKICONS = {
            debug: false,
            ext: ".png",
            art96_base: "",
            icon32_base: "",
            art_cache: {},
            icon_sheet_cache: {},
            icon_strip_cache: {},
            icon_dir_cache: {},
            // Split placeholders
            missing_icon32: spr_mon_icon_placeholder,
            missing_art96:  spr_mon_placeholder
        };
    }
}

function pkicons__log(_m){
    if (PKICONS.debug) show_debug_message("[pkicons] " + string(_m));
}

// Explicit setters for placeholders & bases
function pkicons_set_missing_icon(_spr){ PKICONS.missing_icon32 = _spr; }
function pkicons_set_missing_art(_spr){  PKICONS.missing_art96  = _spr;  }

function pkicons_set_art96_base(_absDir){
    var p = string_replace_all(string(_absDir),"\\","/");
    if (string_length(p)>0 && string_copy(p,string_length(p),1)!="/") p+="/";
    PKICONS.art96_base = p;
}
function pkicons_set_icon32_base(_absDir){
    var p = string_replace_all(string(_absDir),"\\","/");
    if (string_length(p)>0 && string_copy(p,string_length(p),1)!="/") p+="/";
    PKICONS.icon32_base = p;
}

function pkicons__join(_a,_b){
    var A=string(_a),B=string(_b);
    if (string_length(A)<=0) return B;
    if (string_copy(A,string_length(A),1)!="/") A+="/";
    return A+B;
}

function pkicons__cands(_species){
    var ret=[];
    if (is_real(_species)){
        var sid_val=floor(_species);
        array_push(ret,string(sid_val)+PKICONS.ext);
        array_push(ret,string_format(sid_val,3,0)+PKICONS.ext);
        array_push(ret,string_format(sid_val,4,0)+PKICONS.ext);
    } else {
        var s=string(_species);
        array_push(ret,s+PKICONS.ext);
        array_push(ret,string_upper(s)+PKICONS.ext);
        array_push(ret,string_lower(s)+PKICONS.ext);
    }
    return ret;
}

// ---------------- 96×96 Summary Art ----------------
function pkicons_get_art96(_species){
    pkicons_init();
    var key="ART|"+string(_species);
    if (variable_struct_exists(PKICONS.art_cache,key)){
        var c=variable_struct_get(PKICONS.art_cache,key);
        if (sprite_exists(c)) return c;
    }
    var base=PKICONS.art96_base; if (string_length(base)<=0) return PKICONS.missing_art96;
    var spr=-1,cands=pkicons__cands(_species);
    for (var i=0;i<array_length(cands);i++){
        var fn=pkicons__join(base,cands[i]);
        if (file_exists(fn)){
            spr=sprite_add(fn,1,false,false,0,0);
            if (sprite_exists(spr)) break;
        }
    }
    if (!sprite_exists(spr)) spr=PKICONS.missing_art96;
    variable_struct_set(PKICONS.art_cache,key,spr);
    return spr;
}
function pkicons_get_art96_by_mon(_mon){
    if (!is_struct(_mon)) return PKICONS.missing_art96;
    if (variable_struct_exists(_mon,"species_id") && is_real(_mon.species_id)) return pkicons_get_art96(_mon.species_id);
    if (variable_struct_exists(_mon,"species")) return pkicons_get_art96(_mon.species);
    return PKICONS.missing_art96;
}

// ---------------- 32×32 Overworld Icons ----------------
function pkicons__load_icon32_sheet(_species){
    pkicons_init();
    var key="SHEET|"+string(_species);
    if (variable_struct_exists(PKICONS.icon_sheet_cache,key)){
        var c=variable_struct_get(PKICONS.icon_sheet_cache,key);
        if (sprite_exists(c)) return c;
    }
    var base=PKICONS.icon32_base; if (string_length(base)<=0) return PKICONS.missing_icon32;
    var spr=-1,cands=pkicons__cands(_species);
    for (var i=0;i<array_length(cands);i++){
        var fn=pkicons__join(base,cands[i]);
        if (file_exists(fn)){
            spr=sprite_add(fn,1,false,false,0,0);
            if (sprite_exists(spr)) break;
        }
    }
    if (!sprite_exists(spr)) spr=PKICONS.missing_icon32;
    variable_struct_set(PKICONS.icon_sheet_cache,key,spr);
    return spr;
}

// Grid helpers (robust 8‑tile inference)
function pkicons__best_grid8(_w,_h){
    var bestCols=4, bestRows=2, bestTw=_w div 4, bestTh=_h div 2;
    var bestScore=$1e30;
    var found=false;

    var pairs=[ [4,2], [2,4], [8,1], [1,8] ];
    for (var i=0; i<array_length(pairs); i++){
        var c = pairs[i][0];
        var r = pairs[i][1];
        if ((_w mod c)==0 && (_h mod r)==0){
            var tw = _w div c;
            var th = _h div r;
            var ratio = (th>0) ? (tw/th) : 999999;
            var fit_score = abs(ratio - 1); // closer to 1 => more square
            if (fit_score < bestScore){
                bestScore = fit_score;
                bestCols = c; bestRows = r; bestTw = tw; bestTh = th;
                found = true;
            }
        }
    }
    return [bestCols, bestRows, bestTw, bestTh, found];
}
function pkicons__infer_grid(_w,_h){
    if (_w mod 32==0 && _h mod 32==0){
        return [_w div 32, _h div 32, 32, 32];
    }
    var best = pkicons__best_grid8(_w, _h);
    if (best[4]) return [best[0], best[1], best[2], best[3]];
    return [4, 2, _w div 4, _h div 2];
}

// Build 8‑frame strip, centered in 32×32
function pkicons__get_icon32_strip(_species){
    var key="STRIP|"+string(_species);
    if (variable_struct_exists(PKICONS.icon_strip_cache,key)){
        var c=variable_struct_get(PKICONS.icon_strip_cache,key);
        if (sprite_exists(c)) return c;
    }

    var sheet=pkicons__load_icon32_sheet(_species);
    if (!sprite_exists(sheet)) return PKICONS.missing_icon32;

    var fullW=sprite_get_width(sheet);
    var fullH=sprite_get_height(sheet);
    var info=pkicons__infer_grid(fullW,fullH);
    var cols=info[0],rows=info[1],tileW=max(1,info[2]),tileH=max(1,info[3]);

    var total=cols*rows;
    var sc=min(32/tileW,32/tileH);
    var surf=surface_create(32,32);
    if (!surface_exists(surf)) return PKICONS.missing_icon32;

    var strip=-1;
    for (var i=0;i<8;i++){
        var ii=(i<total)?i:(total-1);
        var sx=(ii mod cols)*tileW;
        var sy=(ii div cols)*tileH;

        surface_set_target(surf);
        draw_clear_alpha(c_black,0);

        var offX=(32 - tileW*sc) * 0.5;
        var offY=(32 - tileH*sc) * 0.5;
        draw_sprite_part_ext(sheet,0,sx,sy,tileW,tileH,offX,offY,sc,sc,c_white,1);

        surface_reset_target();

        if (i==0){
            strip=sprite_create_from_surface(surf,0,0,32,32,false,false,0,0);
        } else if (sprite_exists(strip)){
            sprite_add_from_surface(strip,surf,0,0,32,32,false,false);
        }
    }
    surface_free(surf);
    if (!sprite_exists(strip)) strip=PKICONS.missing_icon32;
    variable_struct_set(PKICONS.icon_strip_cache,key,strip);
    return strip;
}

function pkicons__make_dir_from_strip(_sprStrip,_sub0,_sub1){
    if (!sprite_exists(_sprStrip)) return PKICONS.missing_icon32;
    var surf=surface_create(32,32);
    if (!surface_exists(surf)) return PKICONS.missing_icon32;

    surface_set_target(surf);
    draw_clear_alpha(c_black,0);
    draw_sprite_ext(_sprStrip,_sub0,0,0,1,1,0,c_white,1);
    surface_reset_target();
    var spr_dir=sprite_create_from_surface(surf,0,0,32,32,false,false,0,0);

    surface_set_target(surf);
    draw_clear_alpha(c_black,0);
    draw_sprite_ext(_sprStrip,_sub1,0,0,1,1,0,c_white,1);
    surface_reset_target();
    if (sprite_exists(spr_dir)) sprite_add_from_surface(spr_dir,surf,0,0,32,32,false,false);

    surface_free(surf);
    return spr_dir;
}

// 32×32 directional icon resolver (restored)
function pkicons_get_icon32_dir(_species,_dir){
    pkicons_init();
    var d=string_upper(string(_dir));
    if (d!="UP" && d!="DOWN" && d!="LEFT" && d!="RIGHT") d="DOWN";
    var key="DIR|"+string(_species)+"|"+d;
    if (variable_struct_exists(PKICONS.icon_dir_cache,key)){
        var c=variable_struct_get(PKICONS.icon_dir_cache,key);
        if (sprite_exists(c)) return c;
    }
    var strip=pkicons__get_icon32_strip(_species);
    if (!sprite_exists(strip)) return PKICONS.missing_icon32;

    var sub0=4,sub1=5;
    if (d=="UP"){sub0=0;sub1=1;}
    if (d=="LEFT"){sub0=2;sub1=3;}
    if (d=="DOWN"){sub0=4;sub1=5;}
    if (d=="RIGHT"){sub0=6;sub1=7;}

    var spr_dir=pkicons__make_dir_from_strip(strip,sub0,sub1);
    variable_struct_set(PKICONS.icon_dir_cache,key,spr_dir);
    return spr_dir;
}

function pkicons_get_icon32_dir_by_mon(_mon,_dir){
    if (!is_struct(_mon)) return PKICONS.missing_icon32;
    if (variable_struct_exists(_mon,"species_id") && is_real(_mon.species_id)) return pkicons_get_icon32_dir(_mon.species_id,_dir);
    if (variable_struct_exists(_mon,"species")) return pkicons_get_icon32_dir(_mon.species,_dir);
    return PKICONS.missing_icon32;
}

// Simple 2‑frame animator for UI icons (as expected by party system)
function pkicons_icon32_frame_ui(){
    return (current_time div 166) mod 2;
}

// Init (bases left to your Create event or dev setup)
// pkicons_init();
// pkicons_set_art96_base("C:/.../sprites/pokemon/");
// pkicons_set_icon32_base("C:/.../sprites/Overworld/Normal/");
