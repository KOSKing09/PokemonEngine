# Description

- You are a coding agent working inside the Pokemon Rogue repository.
- Read code, edit code, debug systems, and preserve the existing project architecture.
- Use available tools to inspect files before editing.
- Make the needed changes, then summarize afterward.
- Never delete or rewrite an entire file unless explicitly instructed.
- Prefer small targeted modifications over large rewrites.
- Only modify files relevant to the task.
- You may use Python helper scripts if needed.
- Place temporary helper scripts inside /temp.
- Prefer fixing the owning seam instead of layering duplicate behavior elsewhere.
- After any code patch, run the relevant validation path when one exists.

## Project Architecture

- Project name: Pokemon Rogue
- Engine: GameMaker Studio 2
- Language: GML
- /docs contains architecture notes, runtime contracts, implementation patterns, and smoke guidance.
- /scripts contains main project scripts.
- Igor is used to load/run the game.
- Igor may generate context.txt logs for debugging.
- New GameMaker scripts must follow the existing script folder pattern.

## Current Documentation Map

- Read /README.md first for the top-level doc map.
- /docs/runbook.md covers boot flow, manual run steps, split-screen runtime composition, and Igor usage.
- /docs/script_systems.md maps subsystem ownership by folder.
- /docs/battle_system.md covers battle slot shape, battle message ownership, and public battle entrypoints.
- /docs/battle_doubles.md covers doubles, co-op ownership, and split-screen-adjacent battle routing.
- /docs/party_system.md covers party UI, nickname support, and party/battle integration.
- /docs/dialog_system.md covers dialog queueing, battle-vs-overworld draw ownership, and split-screen dialog rules.

## Documentation Rules

- Before editing or creating any core system, inspect /docs for relevant architecture notes.
- Treat /docs as the main guide for project structure, system patterns, loader rules, UI rules, and integration requirements.
- Follow documented patterns unless the live code clearly differs.
- If /docs and live code conflict, preserve the live code and mention the conflict after editing.
- Do not invent new architecture if /docs or existing scripts already define the pattern.

## GameMaker Script Structure Rules

- New scripts require:
  - A folder inside /scripts
  - A .gml file
  - A matching .yy file
  - Registration in Pokemon Rogue.resource_order
  - Registration in Pokemon Rogue.yyp

- Search existing scripts before creating a new script.
- Prefer extending existing systems.

## Coding Standards

- Use GML.
- Follow nearby code style.
- Preserve comments unless incorrect.
- Do not rename or delete existing functions unless instructed.
- Do not create duplicate systems.
- Do not stub missing logic.

## Critical GameMaker Rules

- Never use function_exists().
- Use is_undefined() checks when needed.
- Avoid unsafe use of reserved identifiers:
  - id
  - state
  - x
  - y
  - speed
  - object_index
  - sprite_index
  - image_index
  - depth

- Safe naming:
  - Local variables: _camelCase
  - Loop variables: `_i`, `_j`, `_k`
  - System variables: `sys_*` or `engine_*`

## Pokemon Rogue Rules

- Preserve battle, party, bag, UI, input, loader, save, and split-screen behavior.
- Do not replace systems with simplified versions.
- Use structs where the project uses structs.
- Avoid ds_map unless the existing system depends on it.
- Do not hardcode Pokemon, move, ability, or item constants when CSV loaders resolve them.
- Split-screen is driven by Draw GUI composition in objects/oGame/Draw_64.gml, not by duplicating logic per system.
- When more than one oPlayer exists, pid 0 owns the left GUI rect and pid 1 owns the right GUI rect.
- Overworld dialog uses dialog2p_draw_gui_rect(...); battle dialog must stay inside the battle command UI and battle theme.
- Do not route battle message rendering through the standalone dialog box renderer.
- Caught-Pokemon nicknaming is handled by scripts/virtual_keyboard_system/ and can apply to either party or PC storage.
- Use party_model_set_stored_mon_nickname(pid, store_info, nick) when naming a caught mon that has already been stored.
- Virtual keyboard state blocks overlapping movement and menu systems through virtual_keyboard_blocks_input(pid).
- Physical keyboard text entry for the virtual keyboard is intentionally owned by the first active nickname-entry pid during split-screen.

## Runtime Contracts

- Boot path lives in objects/oGame/Create_0.gml.
- controls_update() must run every Step before reading controls_pressed(), controls_down(), or controls_released().
- scr_controls(), party_init(), bags_init(), pause_init(), dialog2p_init(), evolution_init(), and virtual_keyboard_init() are boot-time systems.
- objects/oGame/Step_1.gml is the main per-frame system step for bag, pause, party, evolution, virtual keyboard, and queued dialog drain.
- battle_update(pid) must run each Step while battle_is_open(pid).
- battle_draw_gui(pid) or battle_draw_gui_rect(pid, ...) must run from Draw GUI.
- dialog2p_step(pid) drains queued dialog; dialog2p_update(pid) advances an open dialog.
- virtual_keyboard_update(pid) and virtual_keyboard_draw_gui_rect(pid, ...) own caught-mon nickname entry.

## Debugging Rules

- Inspect error messages first.
- Inspect relevant scripts and nearby systems.
- Inspect Igor context.txt logs if available.
- Identify the root cause before editing.
- Make the smallest safe fix.
- For dialog bugs, check queue state, dialog2p_is_open(pid), per-frame step/update calls, then draw ownership.
- For split-screen bugs, inspect objects/oGame/Draw_64.gml and the subsystem draw entrypoint before changing core logic.
- For battle UI bugs, confirm whether the owning seam is battle_ui, battle_draw, battle_draw_helpers, or generic GUI composition.

## Performance Rules

- Avoid unnecessary Draw event work.
- Avoid repeated allocations every frame.
- Cache repeated lookups when useful.
- Avoid expensive global searches in Step or Draw loops.

## Tools

- Use only available tools:
  - read_file
  - create_new_file
  - run_terminal_command
  - file_glob_search
  - view_diff
  - read_currently_open_file
  - ls
  - create_rule_block
  - fetch_url_content
  - request_rule
  - read_skill
  - view_repo_map
  - view_subdirectory
  - codebase
  - read_file_range
  - edit_existing_file
  - single_find_replace
  - grep_search

## Tool Usage Rules

- Before editing, inspect files with read_file or read_file_range.
- Use grep_search, file_glob_search, codebase, view_repo_map, or view_subdirectory to locate relevant files.
- After editing, use view_diff.

## Validation Rules

- After any code patch, prefer runnable validation over diff-only inspection.
- In this repo, the common full-project validation path is the Igor Windows VM run command from /docs/runbook.md.
- For documentation-only changes, run the available file or markdown diagnostics if the environment exposes them.
- If a focused smoke path exists for the touched system, prefer that before broader validation.

## Response Rules

- After edits, briefly state:
  - What changed
  - Files modified
  - Tests or commands run
  - Any remaining risks

- Keep responses short.
- Do not paste massive code blocks unless requested.

## Current System Pointers

- Battle core: scripts/battle_system/, scripts/battle_command_helpers/, scripts/battle_ui/, scripts/battle_draw/, scripts/battle_draw_helpers/, scripts/battle_trainer/
- Dialog core: scripts/DialogSystem/DialogSystem.gml
- Split-screen composition: objects/oGame/Draw_64.gml
- Boot and per-frame runtime wiring: objects/oGame/Create_0.gml and objects/oGame/Step_1.gml
- Player movement/input seam: objects/oPlayer/Step_0.gml and objects/oPlayer/Step_1.gml
- Caught nickname flow: scripts/virtual_keyboard_system/virtual_keyboard_system.gml, scripts/party_model/party_model.gml, scripts/battle_impls/battle_impls.gml
