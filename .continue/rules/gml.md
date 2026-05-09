# Description

- You are a coding agent working inside the Pokemon Rogue repository.
- Read code, edit code, debug systems, and preserve the existing project architecture.
- Use available tools to inspect files before editing.
- Do not explain what you are going to do before editing.
- Make the needed changes, then summarize afterward.
- Never delete or rewrite an entire file unless explicitly instructed.
- Prefer small targeted modifications over large rewrites.
- Only modify files relevant to the task.
- You may use Python helper scripts if needed.
- Place temporary helper scripts inside /temp.

# Project Architecture

- Project name: Pokemon Rogue
- Engine: GameMaker Studio 2
- Language: GML
- /doc contains architecture notes and implementation patterns.
- /scripts contains main project scripts.
- Igor is used to load/run the game.
- Igor may generate context.txt logs for debugging.
- New GameMaker scripts must follow the existing script folder pattern.

## Documentation Rules

- Before editing or creating any core system, inspect the /doc folder for relevant architecture notes.
- Treat /doc as the main guide for project structure, system patterns, loader rules, UI rules, and integration requirements.
- Follow documented patterns unless the live code clearly differs.
- If /doc and live code conflict, preserve the live code and mention the conflict after editing.
- Do not invent new architecture if /doc or existing scripts already define the pattern.

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
  - Loop variables: _i, _j, _k
  - System variables: sys_* or engine_*

## Pokemon Rogue Rules

- Preserve battle, party, bag, UI, input, loader, save, and split-screen behavior.
- Do not replace systems with simplified versions.
- Use structs where the project uses structs.
- Avoid ds_map unless the existing system depends on it.
- Do not hardcode Pokemon, move, ability, or item constants when CSV loaders resolve them.

## Debugging Rules

- Inspect error messages first.
- Inspect relevant scripts and nearby systems.
- Inspect Igor context.txt logs if available.
- Identify the root cause before editing.
- Make the smallest safe fix.

## Performance Rules

- Avoid unnecessary Draw event work.
- Avoid repeated allocations every frame.
- Cache repeated lookups when useful.
- Avoid expensive global searches in Step or Draw loops.

# Tools

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

# Response Rules

- After edits, briefly state:
  - What changed
  - Files modified
  - Tests or commands run
  - Any remaining risks

- Keep responses short.
- Do not paste massive code blocks unless requested.