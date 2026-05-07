# Level Data Schema

Each level is a JSON file in `data/levels/<world_folder>/`.

## File naming

- World folder: `world_<world_slug>/` (e.g. `world_forest/`)
- Level file: `<level_id>.json` where `level_id` matches the `id` field

## levels.json

Each world folder contains a `levels.json` — a JSON array of level IDs in intended play order:

["world_forest_01", "world_forest_02"]

## Level file schema

{
  "id": "world_forest_01",
  "world": "forest",
  "mechanic": "placement",
  "target_count": 1,
  "narrative_key": "forest_bridge_intro",
  "skill_tags": ["counting", "one-to-one-correspondence"]
}

| Field | Type | Description |
|---|---|---|
| `id` | String | Unique identifier; matches filename without `.json` |
| `world` | String | World slug (e.g. `"forest"`) |
| `mechanic` | String | Mechanic type (e.g. `"placement"`) |
| `target_count` | int | Numeric parameter passed to the mechanic |
| `narrative_key` | String | Key for narrative/localisation lookup |
| `skill_tags` | Array[String] | Skill areas exercised; used by Progression |
