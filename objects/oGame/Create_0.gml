// --- GUI / FONT -----------------------------------------------------------
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



randomize();
global.FNT_POKEMON = font_add_sprite_ext(spr_font_pokemon_new, ORDER, false, 0);
global.FNT_POKEMON_SMALL = font_add_sprite_ext(spr_font_pokemon_new, ORDER, false, -1);
var spr = spr_font_pokemon_new;
global.FONT_CHAR_W = sprite_get_width(spr);
global.FONT_CHAR_H = sprite_get_height(spr);

// If your GUI isn’t already 240x160, this locks the bag/party layout scale.
display_set_gui_size(240, 160);

// --- DEBUG FLAGS ---------------------------------------------------------
// Central debug master switch. False by default in production builds.
globalvar TYPE_ID_BY_NAME;
globalvar DEBUG;
global.DEBUG = true;

// Data loaders debug gate (opt-in). Default OFF for normal play; set true for troubleshooting.
globalvar DATA_DEBUG;
global.DATA_DEBUG = true;

global.CUTSCENE_DEBUG = true;
global.DATA_DEBUG_TRAINER = false;

// Very verbose data debug (opt-in). Default OFF.
globalvar DATA_DEBUG_VERBOSE;
global.DATA_DEBUG_VERBOSE = false;

// MOVES_DEBUG is noisy; default to false. Set to true when actively debugging moves.
global.MOVES_DEBUG = true;
// Developer-only move-report runner (disabled by default). Enable to run
// `dev_moves_impl_report()` at boot for a one-time diagnostics print.
global.DEV_REPORT_MOVES = true;

// run once (debug boot or in a quick test script)
if (variable_global_exists("_battle_impls") && is_struct(global._battle_impls)){
    show_debug_message("[reg] __battle_perform_action_impl present? " + string(variable_struct_exists(global._battle_impls, "__battle_perform_action_impl")));
} else show_debug_message("[reg] _battle_impls missing");



// --- DATA: ensure globals exist BEFORE loading ----------------------------
// Ensure `global._pokemon` exists (alias older `global.pokemon` if present).
if (!(variable_global_exists("_pokemon") && is_real(global._pokemon))) {
    if (variable_global_exists("pokemon") && is_real(global.pokemon) && ds_exists(global.pokemon, ds_type_map)) {
        global._pokemon = global.pokemon; // alias existing
    } else {
        global._pokemon = ds_map_create();  // create empty
        global.pokemon  = global._pokemon;  // alias legacy name
    }
}

// --- CSV LOAD / PROFILE --------------------------------------------------
//data_load_all_structs(); // fills global._pokemon + global._poke_stats
var _metrics = data_load_profile_run();
if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) {
    show_debug_message("=== DATA LOAD PROFILE COMPLETE ===");
    show_debug_message("Total ms: " + string(_metrics.sys_total_ms));
}

// Startup data sanity checks (helpful when types/species arrays appear empty)
if (variable_global_exists("DATA_DEBUG") && global.DATA_DEBUG) {
    // Types list
    if (variable_global_exists("_types") && is_array(global._types)) show_debug_message("[STARTUP] global._types loaded count=" + string(array_length(global._types)));
    else show_debug_message("[STARTUP] global._types MISSING or not array");

    // TYPE_ID_BY_NAME map
    if (variable_global_exists("TYPE_ID_BY_NAME")) {
        var _type_id_by_name_map = variable_global_get("TYPE_ID_BY_NAME");
        if (is_real(_type_id_by_name_map) && ds_exists(_type_id_by_name_map, ds_type_map)) show_debug_message("[STARTUP] TYPE_ID_BY_NAME ds_map exists");
        else show_debug_message("[STARTUP] TYPE_ID_BY_NAME missing");
    } else show_debug_message("[STARTUP] TYPE_ID_BY_NAME missing");

    // species types
    if (variable_global_exists("_species_types") && is_array(global._species_types)) show_debug_message("[STARTUP] global._species_types loaded count=" + string(array_length(global._species_types)));
    else show_debug_message("[STARTUP] global._species_types MISSING or not array");
}

// Normalize numeric IDs to textual keys for downstream code that expects prose keys
if (!is_undefined(data_normalize_item_flag_map)) data_normalize_item_flag_map();

// --- POKÉMON INDEX & ASSET BASES -----------------------------------------
scr_poke_index_build_simple_structs(); // builds global._name_by_id / _name_list / _id_list
pkicons_init();

// Encounter style startup switch:
// "old" = classic random step-in-bush encounters.
// "new" = visible Pokemon wander inside bush bounds and start battle on contact.
global.OVERWORLD_ENCOUNTER_MODE = "new";
global.OVERWORLD_SHINY_CHANCE = 1 / 4096;
global.OVERWORLD_VISIBLE_MAX_ACTIVE = 16;
global.OVERWORLD_VISIBLE_PATCH_DENSITY = 4;
global.OVERWORLD_VISIBLE_PATCH_MAX = 8;
global.OVERWORLD_ENCOUNTER_GRACE_MS = 1500;
global.OVERWORLD_ENCOUNTER_BLOCK_UNTIL_MS = 0;

// Ensure PKICONS debug flags exist (preserve pre-existing settings when possible)
    if (variable_global_exists("PKICONS")){
        if (variable_struct_exists(global.PKICONS, "debug")) global.PKICONS.debug = false;
        else variable_struct_set(global.PKICONS, "debug", false);
    } else {
        global.PKICONS = { debug: false, data_debug: false };
    }

// Configure external asset bases (adjust paths as needed on your machine)
pkicons_set_art96_base("C:/Users/trane/Documents/Pokemon Engine/sprites/pokemon/");
pkicons_set_overworld_base("C:/Users/trane/Documents/Pokemon Engine/sprites/overworld/Normal/", "C:/Users/trane/Documents/Pokemon Engine/sprites/overworld/Shiny/");
pkicons_set_cries_base("C:/Users/trane/Documents/Pokemon Engine/cries/");
pkicons_set_item_icon_base("C:/Users/trane/Documents/Pokemon Engine/sprites/items/");

// Ensure per-module debug keys exist (quiet by default)
if (variable_global_exists("PKICONS")){
    if (!variable_struct_exists(global.PKICONS, "debug")) variable_struct_set(global.PKICONS, "debug", false);
    if (!variable_struct_exists(global.PKICONS, "debug_crys")) variable_struct_set(global.PKICONS, "debug_crys", false);
} else {
    global.PKICONS = { debug: false, debug_item: false };
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

// Asset shortcuts used by party UI
global.PARTY_ASSETS = {
    selector: "spr_selector",
    placeholder: "spr_mon_icon_placeholder",
    ball: "spr_bag_pokeball_small"
};

// Region music default (used by battle system to restore pre-battle music)
global._REGIONMUSIC = snd_Littleroot_Town;

// --- PARTY / BAGS / PLAYERS -----------------------------------------------
if (!variable_global_exists("PAUSE_PLAYERS_ACTIVE")) global.PAUSE_PLAYERS_ACTIVE = 1;
else global.PAUSE_PLAYERS_ACTIVE = clamp(floor(global.PAUSE_PLAYERS_ACTIVE), 1, 2);
party_init(); // must be before demo seed (party_ensure uses it)
// global.DEMO_FORCE_SPECIES = [250, 249]; // optional override
global.DEMO_FORCE_SPECIES = [188, 268, 471, 559, 17];
scr_poke_runtime_demo_init_random(6); // seeds PARTY[0] (and [1] if present)
dev_assign_moves_to_first(0, [240, 4, 79, 507]);

global.DEV_FORCE_FLINCH_CHANCE = -1;
global.DEV_FORCE_SLEEP_CHANCE = -1;
global.DEV_FORCE_POISON_CHANCE = -1;
global.DEV_FORCE_TOXIC_CHANCE = -1;
global.DEV_FORCE_BURN_CHANCE = -1;
global.DEV_FORCE_FREEZE_CHANCE = -1;
global.DEV_FORCE_PARALYSIS_CHANCE = -1;
global.DEV_FORCE_CONFUSION_CHANCE = -1;
global.DEV_FORCE_TRAP_CHANCE = -1;
global.DEV_AUTO_STATUS_SMOKE = false;
global.DEV_AUTO_HEAL_BLOCK_SMOKE = false;
global.DEV_AUTO_EMBARGO_SMOKE = false;
global.DEV_AUTO_PERISH_SONG_SMOKE = false;
global.DEV_AUTO_ENDURE_SMOKE = false;
global.DEV_AUTO_ROLLOUT_SMOKE = false;
global.DEV_AUTO_FURY_CUTTER_SMOKE = false;
global.DEV_AUTO_LOVE_GIFT_SMOKE = false;
global.DEV_AUTO_FIELD_SWITCH_SMOKE = false;
global.DEV_AUTO_FORCED_PLAYER_SWITCH_SMOKE = false;
global.DEV_AUTO_DOUBLES_ENEMY_FAINT_SEND_SMOKE = false;
global.DEV_AUTO_COOP_DOUBLE_WILD_SMOKE = false;
global.DEV_AUTO_COOP_DOUBLE_TRAINER_SMOKE = false;
global.DEV_AUTO_BURN_POISON_RESIDUAL_SMOKE = false;
global.DEV_AUTO_VISUAL_TARGET_SMOKE = false;
global.DEV_AUTO_EFFECT_131_155_SMOKE = false;
global.DEV_AUTO_EFFECT_159_176_SMOKE = false;
global.DEV_AUTO_EFFECT_27_42_SMOKE = false;
global.DEV_AUTO_EFFECT_76_94_SMOKE = false;
global.DEV_AUTO_EFFECT_9_112_SMOKE = false;
global.DEV_AUTO_EFFECT_ITEM_ABILITY_SMOKE = false;
global.DEV_AUTO_EFFECT_200_204_SMOKE = false;
global.DEV_AUTO_EFFECT_173_177_224_SMOKE = false;
global.DEV_AUTO_EFFECT_174_198_SMOKE = false;
global.DEV_AUTO_EFFECT_215_SMOKE = false;
global.DEV_AUTO_EFFECT_216_SMOKE = false;
global.DEV_AUTO_EFFECT_225_SMOKE = false;
global.DEV_AUTO_EFFECT_221_SMOKE = false;
global.DEV_AUTO_EFFECT_217_SMOKE = false;
global.DEV_AUTO_ACCURACY_SMOKE = false;
global.DEV_AUTO_EFFECT_195_SMOKE = false;
global.DEV_AUTO_EFFECT_210_SMOKE = false;
global.DEV_AUTO_EFFECT_211_229_SMOKE = false;
global.DEV_AUTO_EVOLUTION_SMOKE = false;
global.DEV_FORCE_CRIT_ROLL_100 = -1;
global.DEV_FORCE_ACCURACY_HIT = false;
global.DEV_SMOKE_EXIT_GAME = false;

// Initialize bags (seed with some items for demo/dev)
bags_init(2);
poke_index_init(2);
bag_inventory_add_item(0, 4, 10);
bag_inventory_add_item(0, 1, 10);
bag_inventory_add_item(0, 17, 25);
bag_inventory_add_item(0, 26, 25);
bag_inventory_add_item(0, 25, 25);
bag_inventory_add_item(0, 24, 25);
bag_inventory_add_item(0, 23, 25);
bag_inventory_add_item(0, 18, 25);
bag_inventory_add_item(0, 182, 10);
bags_seed_from_items(0); // refresh once
bag_inventory_add_item(1, 4, 10);
bag_inventory_add_item(1, 1, 10);
bag_inventory_add_item(1, 17, 25);
bag_inventory_add_item(1, 26, 25);
bag_inventory_add_item(1, 25, 25);
bag_inventory_add_item(1, 24, 25);
bag_inventory_add_item(1, 23, 25);
bag_inventory_add_item(1, 18, 25);
bag_inventory_add_item(1, 182, 10);
bags_seed_from_items(1); // refresh once

// NOTE: startup debug simulation for move-learn/leveling removed.
// To re-enable for debugging, reintroduce the DEBUG_SIMULATE_LEARN_ON_START guard and block here.

// --- PLAYER SPAWN ---------------------------------------------------------
global.p1 = instance_create_layer(ospawn.x + 8, ospawn.y + 8, "Instances", oPlayer);
global.p2 = noone;
// Assign instance fields in a guarded way to satisfy static analyzers/runtime differences
try { variable_instance_set(global.p1, "pid", 0); } catch (e_var) { /* ignore */ }
try { variable_instance_set(global.p1, "_speed", 2); } catch (e_var2) { /* ignore */ }
// Active player count (used by pause system)
var players_active = max(1, (variable_global_exists("PAUSE_PLAYERS_ACTIVE") ? global.PAUSE_PLAYERS_ACTIVE : 1));

// --- SYSTEMS (controls, pause, dialog) -----------------------------------
scr_controls();   // creates global CTRL, loads options.ini
if (!is_undefined(multiplayer_sync_runtime)) multiplayer_sync_runtime();
pause_init();     // pause system
dialog2p_init();  // dialog system (if you’re using it)
evolution_init(); // evolution scene manager
virtual_keyboard_init();

// Controls tweak (optional)
CTRL.deadzone = 0.25;
CTRL.pad_index = [0,1];

// --- WORLD COLLISION SETUP ------------------------------------------------
wc_reset();
wc_bind_layers(["WALL", "BLOCKS"]);
wc_set_solids([noone]); // add object ids here if you have solid instances

show_debug_message(global._move_meta[79]);

global.DEV_AUTO_CONFUSION_ANIM_SMOKE = true

test_battle_phase2_behavior_smoke_start(true);
