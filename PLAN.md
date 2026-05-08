# Save System — Implementation Plan

## Feature

Implement `SaveManager`, an autoload that persists per-world level progress and total session count locally using `ConfigFile` at `user://save.cfg`, and integrate it into `ForestBridge` so the world resumes from the last completed level on relaunch.

## Scope

**Included:**
- `scripts/autoloads/save_manager.gd` — full implementation of the existing stub
- `scripts/worlds/forest_bridge.gd` — save on correct and resume from saved level in `_ready()`
- `tests/test_save_manager.gd` — GUT tests for all public methods

**Out of scope:**
- Parent view / session summary UI (issue #9 or later)
- Cloud save or multi-device sync
- PIN-gated parent screen
- `increment_session_count` integration point (no entry scene yet; method exists, integration deferred to issue #9)
- Adaptive branching or per-mechanic mastery tracking (that is `Progression`, not `SaveManager`)

## Architecture Impact

**Layers touched:** `scripts/autoloads/` (modify stub), `scripts/worlds/` (modify), `tests/` (new file)

**Files to modify:**
- `scripts/autoloads/save_manager.gd` — implement from stub; already registered as autoload in `project.godot`
- `scripts/worlds/forest_bridge.gd` — call `SaveManager.save_progress` on correct, start from saved level in `_ready()`

**Files to create:**
- `tests/test_save_manager.gd`

**New signals:** none

**New autoloads:** none — `SaveManager` is already registered in `project.godot`

## Implementation Steps

1. **Implement `scripts/autoloads/save_manager.gd`**

   ```gdscript
   extends Node

   ## Handles reading and writing local save data for level progress.

   const SAVE_PATH := "user://save.cfg"

   const _SECTION_PROGRESS := "progress"
   const _SECTION_META := "meta"
   const _KEY_SESSIONS := "sessions_played"


   ## Saves the 1-indexed level number to resume from for the given world.
   ## Only updates if the new value is higher than the stored value.
   func save_progress(world: String, level: int) -> void:
       var cfg := ConfigFile.new()
       cfg.load(SAVE_PATH)
       var current: int = cfg.get_value(_SECTION_PROGRESS, world, 1)
       if level > current:
           cfg.set_value(_SECTION_PROGRESS, world, level)
           cfg.save(SAVE_PATH)


   ## Returns the 1-indexed level to resume from for the given world.
   ## Returns 1 if no save data exists or the file is corrupt.
   func load_progress(world: String) -> int:
       var cfg := ConfigFile.new()
       var err: Error = cfg.load(SAVE_PATH)
       if err != OK:
           return 1
       var value: Variant = cfg.get_value(_SECTION_PROGRESS, world, 1)
       if not value is int or value < 1:
           return 1
       return value


   ## Increments the total session count by one and persists it.
   func increment_session_count() -> void:
       var cfg := ConfigFile.new()
       cfg.load(SAVE_PATH)
       var count: int = cfg.get_value(_SECTION_META, _KEY_SESSIONS, 0)
       cfg.set_value(_SECTION_META, _KEY_SESSIONS, count + 1)
       cfg.save(SAVE_PATH)


   ## Returns the total number of sessions played.
   ## Returns 0 if no save data exists or the file is corrupt.
   func get_session_count() -> int:
       var cfg := ConfigFile.new()
       var err: Error = cfg.load(SAVE_PATH)
       if err != OK:
           return 0
       var value: Variant = cfg.get_value(_SECTION_META, _KEY_SESSIONS, 0)
       if not value is int or value < 0:
           return 0
       return value


   ## Unconditionally resets the saved progress for the given world to 1.
   ## Use after world completion to allow a fresh replay next session.
   func reset_progress(world: String) -> void:
       var cfg := ConfigFile.new()
       cfg.load(SAVE_PATH)
       cfg.set_value(_SECTION_PROGRESS, world, 1)
       cfg.save(SAVE_PATH)
   ```

   Notes on design:
   - `save_progress` only writes when `level > current` — progress never goes backwards.
   - `ConfigFile.load()` on a missing file returns `ERR_FILE_NOT_FOUND`; on a corrupt file it returns a parse error. Both cases return the default value.
   - `cfg.load(SAVE_PATH)` is called before `save_progress` so existing keys in other sections are preserved.

2. **Modify `scripts/worlds/forest_bridge.gd`**

   In `_ready()`, replace:
   ```gdscript
   _load_level(0)
   ```
   with:
   ```gdscript
   var start_index: int = clampi(SaveManager.load_progress("forest") - 1, 0, _levels.size() - 1)
   _load_level(start_index)
   ```

   In `_on_correct()`, add a save call before advancing:
   ```gdscript
   func _on_correct() -> void:
       if _current_index >= _levels.size() - 1:
           SaveManager.reset_progress("forest")
           world_complete.emit()
       else:
           SaveManager.save_progress("forest", _current_index + 2)
           _load_level(_current_index + 1)
   ```

   Semantics:
   - Completing the last level calls `reset_progress` (unconditional write to 1), not `save_progress`, because `save_progress` guards against backwards updates and would silently skip the reset.
   - Completing any other level saves the 1-indexed number of the next level to play (`_current_index + 2` because `_current_index` is 0-based).

3. **Write `tests/test_save_manager.gd`** — see Test Plan.

4. **Run Godot headless import** to register new test file:
   ```bash
   /Applications/Godot-2.app/Contents/MacOS/Godot --path . --headless --import
   ```

5. **Run GUT tests** and confirm all pass:
   ```bash
   /Applications/Godot-2.app/Contents/MacOS/Godot --path . --headless -s addons/gut/gut_cmdln.gd -gconfig=.gut_config.json
   ```

6. **Commit:**
   ```bash
   git add scripts/autoloads/save_manager.gd scripts/worlds/forest_bridge.gd tests/test_save_manager.gd tests/test_forest_bridge.gd
   git commit -m "Add SaveManager and integrate progress persistence into ForestBridge

   Closes #10"
   ```

## Data Changes

No new data files. Save data is written at runtime to `user://save.cfg` using Godot's `ConfigFile` format (INI-style). Example file contents after one session:

```
[progress]
forest=3

[meta]
sessions_played=1
```

## Test Plan

`tests/test_save_manager.gd` — accesses `SaveManager` via the autoload singleton. Each test deletes `user://save.cfg` in `before_each` to start clean.

- `test_load_progress_returns_1_when_no_save_file` — no file, `load_progress("forest")` returns 1
- `test_load_progress_returns_1_for_unknown_world` — save "forest" level 3, then `load_progress("other")` returns 1
- `test_save_and_load_progress_roundtrip` — `save_progress("forest", 3)`, `load_progress("forest")` returns 3
- `test_save_progress_updates_to_higher_value` — save 3, save 5, `load_progress` returns 5
- `test_save_progress_does_not_overwrite_with_lower_value` — save 5, save 3, `load_progress` returns 5
- `test_load_progress_returns_default_on_corrupt_file` — write garbage bytes to `user://save.cfg`, `load_progress("forest")` returns 1 without crashing
- `test_get_session_count_returns_0_when_no_save_file` — no file, `get_session_count()` returns 0
- `test_increment_and_get_session_count` — increment twice, `get_session_count()` returns 2
- `test_save_progress_preserves_other_worlds` — save "forest" level 3 and "garden" level 2, both `load_progress` calls return correct values
- `test_reset_progress_unconditionally_resets_to_1` — save level 10, call `reset_progress("forest")`, `load_progress("forest")` returns 1
- `test_reset_progress_works_on_missing_file` — no save file, `reset_progress("forest")` does not crash and `load_progress("forest")` returns 1

`tests/test_forest_bridge.gd` additions — pre-populate `user://save.cfg` before instantiating the scene to verify save/load integration:

- `test_forest_bridge_resumes_from_saved_level` — save level 3 for "forest", instantiate scene, verify `_mechanic.target_count` equals the `target_count` from the third level data entry
- `test_forest_bridge_correct_saves_next_level` — instantiate scene at default (level 1), trigger correct on level 1 (place 1 plank and confirm), verify `SaveManager.load_progress("forest")` returns 2
- `test_forest_bridge_last_level_correct_resets_progress` — drive all 10 levels to completion, verify `SaveManager.load_progress("forest")` returns 1 after `world_complete` fires

## Definition of Done

- [ ] `scripts/autoloads/save_manager.gd` implements `save_progress`, `load_progress`, `reset_progress`, `increment_session_count`, `get_session_count`
- [ ] `load_progress` returns 1 when the save file is missing
- [ ] `load_progress` returns 1 when the save file is corrupt (no crash)
- [ ] `save_progress` never decrements stored progress (only updates if new value > stored)
- [ ] `scripts/worlds/forest_bridge.gd` calls `SaveManager.load_progress("forest")` in `_ready()` and starts from the saved level
- [ ] `scripts/worlds/forest_bridge.gd` calls `SaveManager.save_progress("forest", ...)` in `_on_correct()`
- [ ] After completing the last level, `reset_progress` is called and progress returns to 1 on next `load_progress`
- [ ] Save file is at `user://save.cfg`
- [ ] All 11 GUT tests in `tests/test_save_manager.gd` pass
- [ ] 3 new ForestBridge integration tests for save/load pass in `tests/test_forest_bridge.gd`
- [ ] All prior tests continue to pass (no regressions)
- [ ] No level data hardcoded anywhere
