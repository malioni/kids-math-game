# CLAUDE.md

This file provides guidance to Claude Code when working with code in this repository.

## Commands

```bash
# Run the game (Mac)
/Applications/Godot.app/Contents/MacOS/Godot --path .

# Run the game headless
/Applications/Godot.app/Contents/MacOS/Godot --path . --headless --quit

# Run GUT tests
/Applications/Godot.app/Contents/MacOS/Godot --path . --headless -s addons/gut/gut_cmdln.gd -gconfig=.gut_config.json

# Lint GDScript (requires gdtoolkit: pip install gdtoolkit)
gdlint scripts/ scenes/

# Format GDScript
gdformat scripts/ scenes/
```

## Architecture

Strict three-layer boundary:

```
scenes/               — Visual presentation only; no business logic
scripts/mechanics/    — Mechanic behavior; no world-specific code
scripts/systems/      — Core game systems; no mechanic-specific code
data/levels/          — Level definitions as JSON/Resource files only
```

**Key rules:**
- Level content lives in `data/`, never hardcoded in scripts
- Mechanics communicate via signals only — no direct scene-to-scene references
- No mechanic knows about a specific world
- No world reimplements a mechanic — it composes from the mechanic library
- `scripts/autoloads/` manages global state (progression, session, registry)

## Project Structure

```
scenes/
  mechanics/     — Reusable mechanic scenes (.tscn)
  worlds/        — World and level scenes
  ui/            — HUD, menus, transitions
scripts/
  mechanics/     — Mechanic GDScript logic
  systems/       — Core systems (progression, audio, save)
  autoloads/     — Global singletons
assets/
  sprites/
  audio/
  fonts/
data/
  levels/        — Level definitions (JSON or Godot .tres resources)
    world_forest/
addons/
  gut/           — GUT testing framework
tests/           — GUT test files
```

## GDScript Conventions
- `snake_case` for variables and functions
- `PascalCase` for class names
- `UPPER_SNAKE_CASE` for constants
- Signals declared at top of script, before variables
- Type hints on all function parameters and return values
- `@onready` for node references
- Private functions and variables prefixed with `_`

## Testing
Tests use GUT and live in `tests/`. Each mechanic must have a corresponding test file.

Naming: `tests/test_<subject>.gd`

Test files extend `GutTest` and use GUT assertions (`assert_eq`, `assert_signal_emitted`, etc.).

## Adding a New Mechanic
1. Create scene in `scenes/mechanics/<name>.tscn`
2. Create script in `scripts/mechanics/<name>.gd`
3. Mechanic must emit at minimum: `correct`, `incorrect` signals
4. Write tests in `tests/test_<name>.gd`
5. Document all public methods with `##` doc comments

## Adding a New World
1. Create `data/levels/<world_name>/` with JSON level files
2. Create `scenes/worlds/<world_name>/` with scene files
3. Register the world in `scripts/autoloads/game_registry.gd`
4. Compose existing mechanics from `scenes/mechanics/` — never duplicate mechanic logic
