# Level Data Schema and LevelLoader — Design Spec

## Context

GitHub issue #4. All level content lives in `data/` as JSON files — nothing is hardcoded in scripts. `LevelLoader` is a stateless data-access utility registered as a Godot autoload.

## Data Layout

```
data/levels/
  world_forest/
    levels.json            ← ordered array of level IDs for this world
    world_forest_01.json
    world_forest_02.json
    ...
  README.md                ← schema documentation
```

### `levels.json` format

A plain JSON array of level ID strings, in intended play order:

```json
["world_forest_01", "world_forest_02"]
```

Ordering is explicit and authoritative. The `Progression` autoload uses this order for adaptive branching.

### Level file schema

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
| `id` | String | Unique level identifier, matches filename without `.json` |
| `world` | String | World slug (e.g. `"forest"`) |
| `mechanic` | String | Mechanic type to compose (e.g. `"placement"`) |
| `target_count` | int | Parameter passed to the mechanic |
| `narrative_key` | String | Key for localisation/narrative lookup |
| `skill_tags` | Array[String] | Skill areas exercised, used by Progression |

## LevelLoader

**File:** `scripts/systems/level_loader.gd`  
**Autoload name:** `LevelLoader`  
**Layer:** `scripts/systems/` — stateless data-access utility (no session state)

### API

```gdscript
## Loads a single level by ID. Returns {} on missing file or malformed JSON.
func load_level(level_id: String) -> Dictionary

## Returns all levels for a world in index order. Returns [] on any error.
func get_levels_for_world(world_name: String) -> Array[Dictionary]
```

### Behaviour

**`load_level(level_id)`**
- Derives the world folder by splitting `level_id` on `_`, dropping the last segment (the number), and rejoining: `world_forest_01` → `["world", "forest", "01"]` → drop `"01"` → `world_forest`
- Constructs path: `res://data/levels/<folder>/<level_id>.json` (e.g. `res://data/levels/world_forest/world_forest_01.json`)
- Opens the file; on failure, calls `push_error()` and returns `{}`
- Parses JSON; on malformed content or non-Dictionary result, calls `push_error()` and returns `{}`
- Returns the parsed Dictionary

**`get_levels_for_world(world_name)`**
- Reads `res://data/levels/world_<world_name>/levels.json`
- On any error (missing file, malformed JSON, non-Array result), calls `push_error()` and returns `[]`
- Iterates the ID array, calls `load_level()` for each
- Skips entries where `load_level()` returns `{}`
- Returns the accumulated `Array[Dictionary]` in index order

**No caching.** Files are read fresh each call. Levels load once per session in practice; caching is deferred.

## Error Handling

| Situation | Return value | Side effect |
|---|---|---|
| File not found | `{}` or `[]` | `push_error()` |
| File exists but invalid JSON | `{}` or `[]` | `push_error()` |
| JSON parsed but wrong type | `{}` or `[]` | `push_error()` |
| Valid file | parsed data | none |

The game never crashes on bad level data. Errors surface in the Godot debugger via `push_error()`.

## Registration

Add to `project.godot` `[autoload]` section:

```
LevelLoader="*res://scripts/systems/level_loader.gd"
```

## Tests

File: `tests/test_level_loader.gd`

| Test | Condition | Expected |
|---|---|---|
| `test_load_level_valid_file_returns_dictionary` | Valid fixture JSON | Returns dict with correct fields |
| `test_load_level_missing_file_returns_empty_dict` | Non-existent ID | Returns `{}` |
| `test_load_level_malformed_json_returns_empty_dict` | Invalid JSON content | Returns `{}` |
| `test_get_levels_for_world_returns_levels_in_order` | Valid index + two fixtures | Returns array of 2 dicts in order |
| `test_get_levels_for_world_missing_index_returns_empty_array` | Non-existent world | Returns `[]` |

Fixtures are written to `res://data/levels/` test subdirectories during `before_each()` and removed in `after_each()`, since tests run from source (not a packed export) and `res://` is writable.

## Out of Scope

- Caching or preloading
- Schema validation beyond type-checking the top-level JSON value
- Level hot-reloading
- Writing or mutating level files
