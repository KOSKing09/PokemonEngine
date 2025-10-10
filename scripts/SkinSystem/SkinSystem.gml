

function skin_set(skinName){
	switch(skinName){
		case "brendan":
			spriteLeft = sbrendanleft;
			spriteUp = sbrendanup;
			spriteDown = sbrendandown;
			spriteRight = sbrendanright;
			sprite_index = spriteDown
			battleAnim = sbrendanbattle;
		break;
		
		default://default to brendan
			spriteLeft = sbrendanleft;
			spriteUp = sbrendanup;
			spriteDown = sbrendandown;
			spriteRight = sbrendanright;
			sprite_index = spriteDown
			battleAnim = sbrendanbattle;
		break;
	}
}