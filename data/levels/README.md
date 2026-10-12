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

## Balloon-pop level schema (world_sky)

Like placement levels, balloon levels store ranges. `BalloonPuzzleGenerator` builds a fresh
puzzle from them each time the level loads: a weight (the target) and a bunch of numbered
balloons whose total is more than the weight. The child pops balloons adding up to
total − weight.

{
  "id": "world_sky_10",
  "world": "sky",
  "mechanic": "balloon_pop",
  "balloon_count": 6,
  "balloon_value": { "min": 3, "max": 9 },
  "pop_count": { "min": 2, "max": 3 },
  "total_max": 36,
  "max_solutions": 2,
  "narrative_key": "sky_balloons_10",
  "skill_tags": ["subtraction", "number-composition"]
}

| Field | Type | Description |
|---|---|---|
| `balloon_count` | int | Balloons in the bunch (at most 8, so they fit in two rows) |
| `balloon_value.min/max` | int | Inclusive range for every balloon's number |
| `pop_count.min/max` | int | How many balloons the intended answer pops; every valid answer pops at least `min` |
| `total_max` | int | Most the balloons may add up to (keeps the starting number manageable) |
| `max_solutions` | int | Most distinct sets of balloons that can be popped to level out; at least 1 is guaranteed |
