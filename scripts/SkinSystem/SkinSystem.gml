

function skin_set(skinName){
	// Return a small struct describing the skin's sprites so callers can assign
	var out = {};
	switch(skinName){
		case "brendan":
			out.spriteLeft = sbrendanleft;
			out.spriteUp = sbrendanup;
			out.spriteDown = sbrendandown;
			out.spriteRight = sbrendanright;
			out.defaultIndex = sbrendandown;
			out.battleAnim = sbrendanbattle;
			out.trainerSprite = sprite_exists(spr_PokemonEmeraldTrainers) ? spr_PokemonEmeraldTrainers : -1;
			out.trainerSubimg = 0;
			out.trainerScale = 1;
		break;

		default:
			// default to brendan
			out.spriteLeft = sbrendanleft;
			out.spriteUp = sbrendanup;
			out.spriteDown = sbrendandown;
			out.spriteRight = sbrendanright;
			out.defaultIndex = sbrendandown;
			out.battleAnim = sbrendanbattle;
			out.trainerSprite = sprite_exists(spr_PokemonEmeraldTrainers) ? spr_PokemonEmeraldTrainers : -1;
			out.trainerSubimg = 0;
			out.trainerScale = 1;
		break;
	}
	return out;
}