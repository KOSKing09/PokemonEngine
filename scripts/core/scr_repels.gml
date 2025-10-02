/// @file scr_repels.gml
globalvar REPEL;
if (!variable_global_exists("REPEL")) REPEL = { steps: 0 };

function repel_apply(_steps) { REPEL.steps = max(REPEL.steps, _steps); }
function repel_consume_step() { if (REPEL.steps > 0) REPEL.steps -= 1; }
function repel_is_active() { return REPEL.steps > 0; }
