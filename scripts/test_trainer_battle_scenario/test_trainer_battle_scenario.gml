// Minimal trainer-battle test scenario helper
// Usage notes:
// - This script demonstrates two equivalent ways to open a trainer battle:
//   1) Use `pokemon_factory_create(species_id, level, opts)` to build party mons
//      and call `battle_open_trainer(pid, trainer_payload)` where `trainer_payload`
//      is a struct with keys: `trainer_name`, `sprite`, `sprite_index`, `party`,
//      `area_type`, and optional `trainer_reward`.
//   2) Alternatively you can call `battle_open(pid, level, opts)` with
//      `opts = { type: "trainer", enemy_party: [monStructs...], trainer_reward: N }`.
// - Important: `battle_update(pid)` must be called every Step and
//   `battle_draw_gui(pid)` must be called in Draw GUI for the battle to progress.
// - Example (from project comments):
//     var trainer_party = [ pokemon_factory_create(133,5,{}), pokemon_factory_create(10,5,{}), pokemon_factory_create(252,5,{}) ];
//     var trainer_payload = { trainer_name: "Bug Catcher Rick", sprite: spr_PokemonEmeraldTrainers, sprite_index: 12, party: trainer_party, area_type: "forest" };
//     battle_open_trainer(0, trainer_payload);
// - This helper is bound to F2 in `oPlayer/Step_1.gml` so it only runs when pressed.
function test_trainer_battle_scenario(){
    var trainer_party = [];
    if (!is_undefined(pokemon_factory_create)){
        trainer_party = [
            pokemon_factory_create(133, 5, {}),
            pokemon_factory_create(10, 5, {}),
            pokemon_factory_create(252, 5, {})
        ];
    } else {
        // Fallback minimal structs
        array_push(trainer_party, { species_id: 133, name: "Trainermon A", level: 5 });
        array_push(trainer_party, { species_id: 10, name: "Trainermon B", level: 5 });
        array_push(trainer_party, { species_id: 252, name: "Trainermon C", level: 5 });
    }
    var trainer_payload = {
        trainer_name: "Bug Catcher Rick",
        sprite: (variable_global_exists("spr_PokemonEmeraldTrainers") ? variable_global_get("spr_PokemonEmeraldTrainers") : undefined),
        sprite_index: 12,
        party: trainer_party,
        area_type: "forest",
        trainer_reward: 50
    };
    try { battle_open_trainer(0, trainer_payload); } catch (e) { show_debug_message("[test_trainer] battle_open_trainer failed: " + string(e)); }
}