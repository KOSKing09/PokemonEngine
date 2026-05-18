// identity
if (!variable_instance_exists(id,"pid"))    pid = 0;

// ensure the grid struct exists, then init (tile=16, walk=2, run=4)
grid = {};
grid_init(id, 16, 2, 4);
grid_snap_to_tile(id);

// Use the named feet-block checker to avoid anonymous function syntax (compat)
grid_set_block_checker(id, grid_block_checker_feet);

// OPTIONAL: if you have a collision helper, plug it in:
// after grid_init(id, 16, 2, 4);

skin = "brendan";
var _skinData = skin_set(skin);
if (is_struct(_skinData)){
    if (variable_struct_exists(_skinData, "defaultIndex")) sprite_index = variable_struct_get(_skinData, "defaultIndex");
    if (variable_struct_exists(_skinData, "battleAnim")) battleAnim = variable_struct_get(_skinData, "battleAnim");
    if (variable_struct_exists(_skinData, "trainerSprite")) trainerSprite = variable_struct_get(_skinData, "trainerSprite");
    if (variable_struct_exists(_skinData, "trainerSubimg")) trainerSubimg = variable_struct_get(_skinData, "trainerSubimg");
    if (variable_struct_exists(_skinData, "trainerScale")) trainerScale = variable_struct_get(_skinData, "trainerScale");
    // optional: also assign directional sprites for other systems
    if (variable_struct_exists(_skinData, "spriteLeft")) spriteLeft = variable_struct_get(_skinData, "spriteLeft");
    if (variable_struct_exists(_skinData, "spriteUp")) spriteUp = variable_struct_get(_skinData, "spriteUp");
    if (variable_struct_exists(_skinData, "spriteDown")) spriteDown = variable_struct_get(_skinData, "spriteDown");
    if (variable_struct_exists(_skinData, "spriteRight")) spriteRight = variable_struct_get(_skinData, "spriteRight");
}

// If no global battleAnim is set, provide a fallback from the player's skin so
// the battle draw code can use it even if instance lookup fails.
if (!variable_global_exists("battleAnim") && variable_instance_exists(id, "battleAnim")){
    global.battleAnim = battleAnim;
}

talk_cd = 0;          // cooldown frames
can_talk = true;      // release gate
_dlg_was = false;     // edge detect: dialog just closed

