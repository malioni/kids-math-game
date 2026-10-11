# Level Data Schema

Each level is a JSON file in `data/levels/<world_folder>/`.

## File naming

- World folder: `world_<world_slug>/` (e.g. `world_forest/`)
- Level file: `<level_id>.json` where `level_id` matches the `id` field

## levels.json

Each world folder contains a `levels.json` — a JSON array of level IDs in intended play order:

["world_forest_01", "world_forest_02"]

## Level file schema

Placement levels don't store a fixed puzzle. They store ranges, and
`PlankPuzzleGenerator` builds a fresh puzzle from them each time the level loads.

{
  "id": "world_forest_01",
  "world": "forest",
  "mechanic": "placement",
  "bridge_length": { "min": 2, "max": 4 },
  "plank_length": { "min": 1, "max": 3 },
  "plank_count": 3,
  "max_solutions": 2,
  "narrative_key": "forest_bridge_intro",
  "skill_tags": ["addition", "number-composition"]
}

| Field | Type | Description |
|---|---|---|
| `id` | String | Unique identifier; matches filename without `.json` |
| `world` | String | World slug (e.g. `"forest"`) |
| `mechanic` | String | Mechanic type (e.g. `"placement"`) |
| `bridge_length.min/max` | int | Inclusive range for the generated bridge length |
| `plank_length.min/max` | int | Inclusive range for every plank, solution and decoys alike |
| `plank_count` | int | Total planks in the pile (solution + decoys) |
| `max_solutions` | int | Most distinct plank combinations allowed to fill the bridge; at least 1 is guaranteed |
| `narrative_key` | String | Key for narrative/localisation lookup |
| `skill_tags` | Array[String] | Skill areas exercised; used by Progression |
