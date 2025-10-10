// ============================================================================
// Pokémon-style sprite font (monospace) with ORDER mapping
// Usage:
//   font_pokemon_init(spr_font, ORDER_STRING, 8, 8);
//   font_pokemon_draw("Hello", x, y);
// ============================================================================

globalvar FONT_POKEMON;

/// Initialize / rebuild the font mapping for the CURRENT sprite & order.
/// _spr  : sprite strip (each subimage = one glyph, left→right)
/// _ord  : string whose characters are in the SAME order as frames
/// _gw/_gh : per-glyph draw advance (mono). (Use your 8x8 or 8x16)
function font_pokemon_init(_spr, _ord, _gw, _gh){
    // basic struct
    if (!variable_global_exists("FONT_POKEMON") || !is_struct(FONT_POKEMON)) {
        FONT_POKEMON = {};
    }
    FONT_POKEMON.sprite = _spr;
    FONT_POKEMON.order  = string(_ord);
    FONT_POKEMON.width  = max(1, _gw);
    FONT_POKEMON.height = max(1, _gh);

    // build map char -> subimage
    if (variable_struct_exists(FONT_POKEMON, "map") && ds_exists(FONT_POKEMON.map, ds_type_map)) {
        ds_map_destroy(FONT_POKEMON.map);
    }
    FONT_POKEMON.map = ds_map_create();

    var ord_len = string_length(FONT_POKEMON.order);
    var spr_len = sprite_get_number(_spr);

    // warn if lengths don't match (this is the #1 cause of wrong glyphs)
    if (spr_len != ord_len) {
        show_debug_message("[FONT] WARNING: sprite frames (" + string(spr_len) +
            ") != order length (" + string(ord_len) + "). Update your ORDER string to match the strip.");
    }

    // fill map for min length to avoid OOB if they mismatch
    var lim = min(ord_len, spr_len);
    for (var i = 1; i <= lim; i++){
        var ch = string_char_at(FONT_POKEMON.order, i);
        // if the char already exists, last one wins (rare)
        ds_map_replace(FONT_POKEMON.map, ch, i - 1);
    }

    // always ensure space works, even if not in order
    if (!ds_map_exists(FONT_POKEMON.map, " ")) ds_map_add(FONT_POKEMON.map, " ", -1);
}

/// Draw a string using the sprite font (two lines max per call is OK; supports any length)
function font_pokemon_draw(_text, _xx, _yy){
    // fallback
    if (!(variable_global_exists("FONT_POKEMON") && is_struct(FONT_POKEMON))) {
        draw_text(_xx, _yy, _text);
        return;
    }
    var f = FONT_POKEMON;
    var has_map = variable_struct_exists(f, "map") && ds_exists(f.map, ds_type_map);
    var has_spr = variable_struct_exists(f, "sprite") && f.sprite != -1;

    if (!(has_map && has_spr)) { draw_text(_xx, _yy, _text); return; }

    var adv = max(1, f.width);
    var dx = 0;
    var len = string_length(_text);

    for (var i = 1; i <= len; i++){
        var ch = string_char_at(_text, i);

        // newline → move to next line (monospace; you control line spacing where you call)
        if (ch == "\n") { _yy += f.height + 2; dx = 0; continue; }

        // space → advance
        if (ch == " ")  { dx += adv; continue; }

        var idx = ds_map_exists(f.map, ch) ? f.map[? ch] : -1;
        if (idx >= 0) {
            draw_sprite(f.sprite, idx, _xx + dx, _yy);
        }
        dx += adv;
    }
}

/// Tiny debug helper: draws all frames in order with their characters beneath
function font_pokemon_debug_strip(_x, _y){
    if (!(variable_global_exists("FONT_POKEMON") && is_struct(FONT_POKEMON))) return;
    var f = FONT_POKEMON;
    var n = sprite_get_number(f.sprite);
    var adv = f.width;
    for (var i = 0; i < n; i++){
        var cx = _x + i * adv;
        draw_sprite(f.sprite, i, cx, _y);
        // try to find which char maps to this index (slow but only for debug)
        var ch = "?";
        // invert map (linear search)
        var ord_len = string_length(f.order);
        if (i < ord_len) ch = string_char_at(f.order, i + 1);
        draw_text(cx, _y + f.height + 2, ch);
    }
}
