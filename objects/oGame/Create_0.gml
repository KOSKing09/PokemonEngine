// --- POKÉ FONT / GUI --------------------------------------------------------
var ORDER =
    "0123456789" +
    "!?“”‘’♂♀$*/.-:,_" +
    "ABCDEFGHIJKLMNOPQRSTUVWXYZ" +
    "abcdefghijklmnopqrstuvwxyz" +
    ">" +
    "" +
    "…" +
    "“”‘’" +
    "♪▶";

if !(window_get_fullscreen()) {
    window_set_position(10, 10);
    window_set_size(display_get_width() - 10, display_get_height() - 10);
}


randomize();
global.FNT_POKEMON = font_add_sprite_ext(spr_font_pokemon_new, ORDER, false, 0);
global.FNT_POKEMON_SMALL = font_add_sprite_ext(spr_font_pokemon_new, ORDER, false, -1);
var spr = spr_font_pokemon_new;
global.FONT_CHAR_W = sprite_get_width(spr);
global.FONT_CHAR_H = sprite_get_height(spr);

// If your GUI isn’t already 240x160, this locks the bag/party layout scale.
display_set_gui_size(240, 160);

// Central debug master switch. False by default in production builds.
globalvar DEBUG;
global.DEBUG = true;

// Data loaders debug gate (opt-in)
globalvar DATA_DEBUG;
// Data loaders debug gate (opt-in). Default OFF for normal play; set true for troubleshooting.
global.DATA_DEBUG = false;

// Additional verbose data debug (very noisy). Default OFF.
globalvar DATA_DEBUG_VERBOSE;
global.DATA_DEBUG_VERBOSE = false;

// --- DATA: ensure globals exist BEFORE loading ------------------------------
// Make sure a DS map object exists and pokemon/_pokemon point to the SAME id.
if (!(variable_global_exists("_pokemon") && is_real(global._pokemon))) {
    if (variable_global_exists("pokemon") && is_real(global.pokemon) && ds_exists(global.pokemon, ds_type_map)) {
        global._pokemon = global.pokemon;           // alias existing
    } else {
        global._pokemon = ds_map_create();          // create empty
        global.pokemon  = global._pokemon;          // alias legacy name
    }
}

// --- LOAD ALL CSVs ----------------------------------------------------------
// --- DATA (structs) ---
//data_load_all_structs();                // fills global._pokemon + global._poke_stats
// PROFILE RUN
var _metrics = data_load_profile_run();

// after profiling, continue normal boot
// (your loader orchestrator will run again inside the profiler)
if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) {
    show_debug_message("=== DATA LOAD PROFILE COMPLETE ===");
    show_debug_message("Total ms: " + string(_metrics.sys_total_ms));
}

// Normalize any numeric flag ids to textual keys so downstream logic can rely on prose keys
if (!is_undefined(data_normalize_item_flag_map)) data_normalize_item_flag_map();

// --- BUILD SIMPLE INDEX (name <-> id) --------------------------------------
scr_poke_index_build_simple_structs();  // builds global._name_by_id/_name_list/_id_list
pkicons_init();
// Ensure pkicons exists and enable debug so item base scan logs will run
if (variable_global_exists("PKICONS")){
    if (variable_struct_exists(global.PKICONS, "debug")) global.PKICONS.debug = true;
    else variable_struct_set(global.PKICONS, "debug", true);
} else {
    global.PKICONS = { debug: true, data_debug: true};
}
pkicons_set_art96_base("C:/Users/King2/Documents/Pokemon Engine/sprites/pokemon/");
pkicons_set_icon32_base("C:/Users/King2/Documents/Pokemon Engine/sprites/Overworld/Normal/");
pkicons_set_cries_base("C:/Users/King2/Documents/Pokemon Engine/cries/");
pkicons_set_item_icon_base("C:/Users/King2/Documents/Pokemon Engine/sprites/items/")
// Centralized debug flag initializations (preserve existing PKICONS.debug if already set)
// Ensure PKICONS exists before setting its debug flag
if (variable_global_exists("PKICONS")){
    if (!variable_struct_exists(global.PKICONS, "debug")) variable_struct_set(global.PKICONS, "debug", false);
    if (!variable_struct_exists(global.PKICONS, "debug_crys")) variable_struct_set(global.PKICONS, "debug_crys", false);
} else {
    global.PKICONS = { debug: false, debug_item : false };
}

// World collision debug (module-level struct WC)
if (variable_global_exists("WC")){
    if (variable_struct_exists(global.WC, "debug")) global.WC.debug = false;
    else variable_struct_set(global.WC, "debug", false);
} else {
    global.WC = { tilemaps: [], tile_size: 16, solids: [], debug: false };
}

// Master switches
global.DEBUG_BATTLE_SPRITES = false;


global.PARTY_ASSETS = {
    selector: "spr_selector",
    placeholder: "spr_mon_icon_placeholder",
    ball: "spr_bag_pokeball_small"
};

// --- PARTY / BAGS / PLAYERS -------------------------------------------------
party_init();               // must be before demo seed (party_ensure uses it)
//global.DEMO_FORCE_SPECIES = [250, 249]; // optional, you can change or remove
scr_poke_runtime_demo_init_random(6);           // seeds PARTY[0] (and [1] if present)

// (Debug call to scr_debug_species_moves removed - use manual call if needed)

// Bags after party is fine
bags_init(1);
bag_inventory_add_item(0, 4, 10);
bag_inventory_add_item(0, 1, 10);
bag_inventory_add_item(0, 17, 5);
bag_inventory_add_item(0, 18, 5);
bag_inventory_add_item(0, 182, 10);
bags_seed_from_items(0); // refresh once, not every step
// (item loader diagnostic removed - bootstrap diagnostic removed)
// ... keep inv around for gameplay; destroy when appropriate

// --- PLAYER SPAWN -----------------------------------------------------------
global.p1 = instance_create_layer(ospawn.x, ospawn.y, "Instances", oPlayer);
global.p1.pid = 0;
global.p1._speed = 2;

// If you use this elsewhere, keep it up to date
var players_active = max(1, (variable_global_exists("PAUSE_PLAYERS_ACTIVE") ? global.PAUSE_PLAYERS_ACTIVE : 1));

// --- SYSTEMS (controls, pause, dialog) -------------------------------------
scr_controls();          // creates global CTRL, loads options.ini
pause_init();            // pause system
dialog2p_init();         // dialog system (if you’re using it)

// Controls tweak (optional)
CTRL.deadzone  = 0.25;
CTRL.pad_index = [0,1];

// --- WORLD COLLISION SETUP --------------------------------------------------
wc_reset();
wc_bind_layers(["WALL"]);
wc_set_solids([noone]);  // add object ids here if you have solid instances
