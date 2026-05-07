# Level Data Schema and LevelLoader Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement a `LevelLoader` autoload that reads JSON level files from `data/levels/` and exposes a typed GDScript API for loading individual levels and world level lists.

**Architecture:** `LevelLoader` lives in `scripts/systems/level_loader.gd` and is registered as a Godot autoload. It is stateless — no caching, no session state. Level files follow a strict schema; world order is controlled by a per-world `levels.json` index file. All errors return empty values with `push_error()`.

**Tech Stack:** Godot 4.6, GDScript, GUT testing framework, JSON via `FileAccess` and `JSON.parse_string()`.

---

### Task 1: Schema documentation and data fixtures

**Files:**
- Create: `data/levels/README.md`
- Create: `data/levels/world_forest/levels.json`
- Create: `data/levels/world_forest/world_forest_01.json`
- Create: `data/levels/world_forest/world_forest_02.json`
- Delete: `data/levels/world_forest/.gitkeep`

- [ ] **Step 1: Write the schema README**

Create `data/levels/README.md`:

```markdown
# Level Data Schema

Each level is a JSON file in `data/levels/<world_folder>/`.

## File naming

- World folder: `world_<world_slug>/` (e.g. `world_forest/`)
- Level file: `<level_id>.json` where `level_id` matches the `id` field

## levels.json

Each world folder contains a `levels.json` — a JSON array of level IDs in intended play order:

```json
["world_forest_01", "world_forest_02"]
```

## Level file schema

```json
{
  "id": "world_forest_01",
  "world": "forest",
  "mechanic": "placement",
  "target_count": 2,
  "narrative_key": "forest_bridge_intro",
  "skill_tags": ["counting", "one-to-one-correspondence"]
}
```

| Field | Type | Description |
|---|---|---|
| `id` | String | Unique identifier; matches filename without `.json` |
| `world` | String | World slug (e.g. `"forest"`) |
| `mechanic` | String | Mechanic type (e.g. `"placement"`) |
| `target_count` | int | Numeric parameter passed to the mechanic |
| `narrative_key` | String | Key for narrative/localisation lookup |
| `skill_tags` | Array[String] | Skill areas exercised; used by Progression |
```

- [ ] **Step 2: Write the world index file**

Create `data/levels/world_forest/levels.json`:

```json
["world_forest_01", "world_forest_02"]
```

- [ ] **Step 3: Write placeholder level files**

Create `data/levels/world_forest/world_forest_01.json`:

```json
{
  "id": "world_forest_01",
  "world": "forest",
  "mechanic": "placement",
  "target_count": 1,
  "narrative_key": "forest_bridge_intro",
  "skill_tags": ["counting", "one-to-one-correspondence"]
}
```

Create `data/levels/world_forest/world_forest_02.json`:

```json
{
  "id": "world_forest_02",
  "world": "forest",
  "mechanic": "placement",
  "target_count": 2,
  "narrative_key": "forest_bridge_02",
  "skill_tags": ["counting", "one-to-one-correspondence"]
}
```

- [ ] **Step 4: Remove the placeholder**

```bash
git rm data/levels/world_forest/.gitkeep
```

- [ ] **Step 5: Commit**

```bash
git add data/levels/README.md data/levels/world_forest/
git commit -m "Add level schema docs and world_forest placeholder level files"
```

---

### Task 2: Write failing tests for LevelLoader

**Files:**
- Create: `tests/test_level_loader.gd`

- [ ] **Step 1: Write the test file**

Create `tests/test_level_loader.gd`:

```gdscript
extends GutTest

# get_levels_for_world("fixture_world") constructs path world_fixture_world/,
# and load_level("world_fixture_world_01") splits to folder world_fixture_world.
# Both must match the fixture directory name.
const FIXTURE_DIR := "res://data/levels/world_fixture_world/"
const FIXTURE_INDEX := FIXTURE_DIR + "levels.json"
const FIXTURE_LEVEL_A := FIXTURE_DIR + "world_fixture_world_01.json"
const FIXTURE_LEVEL_B := FIXTURE_DIR + "world_fixture_world_02.json"


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(FIXTURE_DIR)
	)
	_write_file(FIXTURE_INDEX, '["world_fixture_world_01", "world_fixture_world_02"]')
	_write_file(FIXTURE_LEVEL_A, JSON.stringify({
		"id": "world_fixture_world_01",
		"world": "fixture_world",
		"mechanic": "placement",
		"target_count": 1,
		"narrative_key": "test_key_a",
		"skill_tags": ["counting"]
	}))
	_write_file(FIXTURE_LEVEL_B, JSON.stringify({
		"id": "world_fixture_world_02",
		"world": "fixture_world",
		"mechanic": "placement",
		"target_count": 2,
		"narrative_key": "test_key_b",
		"skill_tags": ["counting"]
	}))


func after_each() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FIXTURE_LEVEL_A))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FIXTURE_LEVEL_B))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FIXTURE_INDEX))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FIXTURE_DIR))


func _write_file(path: String, content: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(content)
	f.close()


func test_load_level_valid_file_returns_dictionary() -> void:
	var result := LevelLoader.load_level("world_fixture_world_01")
	assert_eq(result.get("id"), "world_fixture_world_01")
	assert_eq(result.get("target_count"), 1)


func test_load_level_missing_file_returns_empty_dict() -> void:
	var result := LevelLoader.load_level("nonexistent_level_99")
	assert_eq(result, {})


func test_load_level_malformed_json_returns_empty_dict() -> void:
	_write_file(FIXTURE_LEVEL_A, "this is not json {{{{")
	var result := LevelLoader.load_level("world_fixture_world_01")
	assert_eq(result, {})


func test_get_levels_for_world_returns_levels_in_order() -> void:
	var result := LevelLoader.get_levels_for_world("fixture_world")
	assert_eq(result.size(), 2)
	assert_eq(result[0].get("id"), "world_fixture_world_01")
	assert_eq(result[1].get("id"), "world_fixture_world_02")


func test_get_levels_for_world_missing_index_returns_empty_array() -> void:
	var result := LevelLoader.get_levels_for_world("nonexistent_world")
	assert_eq(result, [])
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
/Applications/Godot-2.app/Contents/MacOS/Godot --path . --headless -s addons/gut/gut_cmdln.gd -gconfig=.gut_config.json 2>&1 | grep -A5 "test_level_loader"
```

Expected: errors because `LevelLoader` autoload does not exist yet.

- [ ] **Step 3: Commit failing tests**

```bash
git add tests/test_level_loader.gd
git commit -m "Add failing tests for LevelLoader"
```

---

### Task 3: Implement LevelLoader

**Files:**
- Create: `scripts/systems/level_loader.gd`
- Modify: `project.godot` — add `LevelLoader` to `[autoload]`
- Delete: `scripts/systems/.gitkeep`

- [ ] **Step 1: Write the implementation**

Create `scripts/systems/level_loader.gd`:

```gdscript
extends Node

## Loads a single level by ID from data/levels/. Returns {} on missing file or malformed JSON.
func load_level(level_id: String) -> Dictionary:
	var parts := level_id.split("_")
	parts.resize(parts.size() - 1)
	var folder := "_".join(parts)
	var path := "res://data/levels/%s/%s.json" % [folder, level_id]

	if not FileAccess.file_exists(path):
		push_error("LevelLoader: file not found: %s" % path)
		return {}

	var content := FileAccess.get_file_as_string(path)
	var parsed := JSON.parse_string(content)

	if not parsed is Dictionary:
		push_error("LevelLoader: expected Dictionary, got %s in %s" % [type_string(typeof(parsed)), path])
		return {}

	return parsed


## Returns all levels for a world in index order. Returns [] on any error.
func get_levels_for_world(world_name: String) -> Array[Dictionary]:
	var index_path := "res://data/levels/world_%s/levels.json" % world_name

	if not FileAccess.file_exists(index_path):
		push_error("LevelLoader: index not found: %s" % index_path)
		return []

	var content := FileAccess.get_file_as_string(index_path)
	var parsed := JSON.parse_string(content)

	if not parsed is Array:
		push_error("LevelLoader: expected Array in index %s" % index_path)
		return []

	var levels: Array[Dictionary] = []
	for level_id in parsed:
		var level := load_level(level_id)
		if not level.is_empty():
			levels.append(level)
	return levels
```

- [ ] **Step 2: Register the autoload in project.godot**

Open `project.godot` and add `LevelLoader` to the `[autoload]` section:

```ini
[autoload]

GameRegistry="*res://scripts/autoloads/game_registry.gd"
Progression="*res://scripts/autoloads/progression.gd"
SaveManager="*res://scripts/autoloads/save_manager.gd"
LevelLoader="*res://scripts/systems/level_loader.gd"
```

- [ ] **Step 3: Remove the placeholder**

```bash
git rm scripts/systems/.gitkeep
```

- [ ] **Step 4: Run the Godot importer to register the new script**

```bash
/Applications/Godot-2.app/Contents/MacOS/Godot --path . --headless --import 2>&1 | tail -5
```

Expected: exits cleanly with no script errors.

- [ ] **Step 5: Run all tests and confirm they pass**

```bash
/Applications/Godot-2.app/Contents/MacOS/Godot --path . --headless -s addons/gut/gut_cmdln.gd -gconfig=.gut_config.json 2>&1 | tail -20
```

Expected: `---- All tests passed! ----` with 19 passing (14 existing + 5 new).

- [ ] **Step 6: Commit**

```bash
git add scripts/systems/level_loader.gd project.godot
git commit -m "Implement LevelLoader system and register as autoload

Closes #4"
```

---

### Task 4: Open pull request

**Files:** none

- [ ] **Step 1: Push branch and open PR**

```bash
git push
gh pr create \
  --title "Level data schema and LevelLoader (#4)" \
  --body "$(cat <<'EOF'
## Summary
- Adds JSON level schema documented in `data/levels/README.md`
- Implements `LevelLoader` autoload in `scripts/systems/` with `load_level()` and `get_levels_for_world()`
- Adds `world_forest` index and two placeholder level files
- 5 new GUT tests (19 total passing)

Closes #4
EOF
)"
```
