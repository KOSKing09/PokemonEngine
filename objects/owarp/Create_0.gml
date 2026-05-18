
_room = noone;
_x = -1;
_y = -1;
trans_style = "emerald_fade_black";
room_music = -1;
warp_kind = "exit"; // "exit", "door", or "ladder"
warp_sound = -1; // Optional direct sound override; leave -1 to use warp_kind.
return_to_rogue = false; // Interior exits can set this to return to the last rogue-world doorway.
remember_rogue_return = true; // Rogue-world doors to interiors remember where the player should return.
rogue_return_x = -1; // Optional exact return x in rm_world. Leave -1 to use player position + offset.
rogue_return_y = -1; // Optional exact return y in rm_world. Leave -1 to use player position + offset.
rogue_return_offset_x = 0;
rogue_return_offset_y = 16;
rogue_room_file = ""; // Set to a data/rogue_rooms JSON file to enter rm_rogue_building.
