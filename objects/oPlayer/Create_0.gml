// identity
if (!variable_instance_exists(id,"pid"))    pid = 0;


// ensure the grid struct exists, then init (tile=16, walk=2, run=4)
grid = {};
grid_init(id, 16, 2, 4);
grid_snap_to_tile(id);

grid_set_block_checker(id, function(self, px, py){
    // Feet probe is best for character movement:
    return wc_collides_at_feet(self, px, py);
});

// OPTIONAL: if you have a collision helper, plug it in:
// after grid_init(id, 16, 2, 4);

skin = "brendan";
skin_set(skin);

talk_cd = 0;          // cooldown frames
can_talk = true;      // release gate
_dlg_was = false;     // edge detect: dialog just closed


