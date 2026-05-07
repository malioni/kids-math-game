# PLAN.md

## Feature
Install the GUT testing framework addon and wire up a working headless test runner with a smoke test.

## Scope

**Included:**
- Download GUT for Godot 4 from the official GitHub release and place files in `addons/gut/`
- Enable the GUT plugin in `project.godot`
- Create `.gut_config.json` pointing to `tests/`
- Write `tests/test_setup.gd` smoke test that asserts basic GDScript truthiness
- Verify the headless runner exits cleanly

**Out of scope:**
- Mechanic tests (no mechanics exist yet)
- GUT editor panel configuration (headless-only concern for now)
- CI/CD pipeline integration

## Architecture Impact

**Layers touched:** none of the three game layers — this is pure tooling infrastructure.

**New files:**
- `addons/gut/` — entire GUT addon tree (downloaded from release)
- `.gut_config.json` — headless runner configuration
- `tests/test_setup.gd` — smoke test

**Modified files:**
- `project.godot` — add `[editor_plugins]` section to enable GUT

**New signals / autoloads:** none

## Implementation Steps

1. **Download GUT addon** (`addons/gut/`)
   - Fetch the latest GUT Godot 4-compatible release zip from the GitHub releases page.
   - Extract the `addons/gut/` subtree into the project's `addons/gut/` directory.
   - Confirm `addons/gut/gut_cmdln.gd` and `addons/gut/plugin.cfg` are present.

2. **Enable plugin in project.godot** (`project.godot`)
   - Add the `[editor_plugins]` section with `enabled=PackedStringArray("res://addons/gut/plugin.cfg")`.

3. **Create `.gut_config.json`** (`.gut_config.json`)
   - Point at `res://tests/`, use prefix `test_`, log level 1, include subdirectories.

4. **Write smoke test** (`tests/test_setup.gd`)
   - Extend `GutTest`.
   - One test function `test_runner_is_working` that calls `assert_true(true)`.

5. **Remove placeholder** (`tests/.gitkeep`)
   - Delete `tests/.gitkeep` now that a real file occupies the directory.

6. **Verify headless run**
   - Execute: `/Applications/Godot.app/Contents/MacOS/Godot --path . --headless -s addons/gut/gut_cmdln.gd -gconfig=.gut_config.json`
   - Confirm exit code 0 and "All tests passed" in output.

## Data Changes
None — this feature has no level data.

## Test Plan
- `test_runner_is_working_assert_true_passes` — asserts `true` to confirm GUT loads and the runner reaches test code

## Definition of Done
- [ ] `addons/gut/gut_cmdln.gd` exists and is committed
- [ ] `addons/gut/plugin.cfg` exists and is committed
- [ ] `project.godot` contains `[editor_plugins]` enabling GUT
- [ ] `.gut_config.json` exists and points to `res://tests/`
- [ ] `tests/test_setup.gd` exists and extends `GutTest`
- [ ] Headless run command exits with code 0
- [ ] `addons/gut/` is NOT listed in `.gitignore`
