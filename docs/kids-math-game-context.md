# Kids Math Game: project context

_Last updated 2026-11-05. Everything below is merged to `main` through PR #30: the plank puzzle and phone layout (#17), the level HUD/picker and World 2, Sky Balloons (#18), the GitHub Pages web deploy (#19), World 3, the Market (#20–#22), World 4, the Picnic (#23), fox sprite fixes and a sad animation (#24), Easy/Hard difficulty and Shuffle mode (#25), the badge counting to the end of the difficulty (#26), the shuffle page in the picker (#27), the main menu and fade transitions (#29), and menu Play opening the centred world (#30)._

## What it is

A tablet- and phone-first Godot 4 game for children aged 4–7, where math is the physics of the world rather than a quiz. There's no reading, no scores and no difficulty labels for the child; meaning comes from icons and animation. Short sessions of 5–10 minutes. Repo: `github.com/malioni/kids-math-game` (local: `~/Documents/kids-math-game`). The design doc is `DESIGN.md` and the architecture rules are in `CLAUDE.md`, both in the repo. The fox is the main character in every world.

**World 1: The Forest Bridge (addition).** A fox must cross a river to get home. A wooden sign shows the bridge length (e.g. **23**). Below the river is a pile of numbered planks, each drawn to scale (a bigger number means a longer plank). The child drags planks onto one continuous gap, where they lay end to end from the left bank, then presses the Go button.
- Exact fit → the fox walks home, celebrates (confetti), and the next level loads.
- Short → the fox walks across the planks that are there, steps off the end, falls; the planks fade; an icon-only retry button appears. Retry keeps the same puzzle.
- Over-filling is impossible: a plank longer than the remaining gap bounces back.
- Tapping a placed plank returns it to the pile; the others slide left to close the gap.
- Only the target number is shown, never a running total, so the child does the adding.

**World 2: Sky Balloons (subtraction).** The fox floats in a wicker basket under a bunch of numbered balloons (bigger number = bigger balloon, radius = 30 + 8·√n px). A sandbag hanging off the basket shows its **weight** (the target); a blue badge where the strings meet shows the balloons' **lift** (their total). Lift always starts above the weight, so the basket keeps rising: clouds stream down, faster the more extra lift there is (30 px/s per unit, capped at 360). The child taps balloons to pop them; the lift badge updates after each pop.
- Lift = weight → the basket levels out (clouds slow to a stop), the fox celebrates, next level.
- Lift < weight → the basket falls off the bottom of the screen; retry restores the same balloons.
- Popping can't be undone (that's the risk). Both numbers are shown on purpose (the author's choice), so the child is steered to compute lift − weight and pop that much, rather than add up a subset.

**World 3: The Market (multiplication as equal groups).** The fox is the customer and holds up an order slip: an amount and a picture per item (e.g. 12 tomatoes). Each ordered item has a crate of equal-sized bags that never runs out, each bag showing how many it holds. The child drags or taps bags onto the table (one row per item) and presses Go. The number on the table is never shown, so the child works out bags × bag size.
- Bag sizes: tomatoes 2–4, potatoes 5–7, carrots 8–10 (never 1, so it's never just counting). The answer takes 2–10 bags.
- Every item exact → the fox cheers. Any item short or over → the fox throws a tomato at the table (a splat; until the fox has throw frames its fall lurch stands in); retry keeps the same order.
- Tapping a placed bag sends it back; the row closes the gap.

**World 4: The Picnic (division as fair sharing).** The fox sits at a plate with 1–4 friends (2–5 plates in all). Each fruit's basket shows only its total (e.g. 12 strawberries). The child drags or taps fruit onto the fox's plate (one row per fruit) and presses Go; the baskets then deal the fox's amount to every friend in turn. The fox's amount is never shown, so the child works out total ÷ plates.
- Every plate equal and the baskets empty → everyone cheers.
- Too much → the last friends come up short and look sad. Too little → fruit is left in the basket. Either way the fox plays its sad animation (`character_sad.png`, 4 frames, looping until retry); retry keeps the same baskets.

**Level HUD (every world).** A badge in the top-left of the play area: world icon + level number + the end of the current difficulty (e.g. 4/10 on easy, 14/20 on hard). While shuffling it shows a small shuffle icon and the place in the whole shuffle (e.g. 7/40 with four worlds). Tapping the badge opens the picker:
- A tab per world, showing the current difficulty's 10 levels by their real numbers, current level highlighted, all open. Picking a level loads it and sets that world's saved level for the difficulty (it can lower it). Picking a level in another world switches scenes. Picking a level leaves shuffle.
- Two icon buttons, Easy (a hill) and Hard (a snowy mountain), set the difficulty for the whole game. This is the grown-up's control; the child never sees it named.
- A Shuffle tab with its own page: continue (or start shuffling) and start over (clears shuffle's place in every world and begins again). The picker opens on this page while shuffling.
- After the difficulty's last level, a star screen offers restart from the difficulty's first level (retry icon labelled 1 or 11) or another world's icon. In shuffle, the star screen shows once every world is done, and restart starts a fresh shuffle.
- The game opens on the main menu (`scenes/ui/main_menu.tscn`, via `scenes/ui/boot.tscn`): Play (or tapping the centred card) opens the centred world, which starts as the last world played, and leaves shuffle; Shuffle starts or continues a shuffle; and a swipeable `WorldCarousel` (`scripts/ui/world_carousel.gd`) has a card per registered world. The picker's world row and the star screen's world list use the same carousel; both have a home button. Every level change and scene change fades through the `Transition` autoload (0.3 s); tests run with `Transition.enabled = false` via `tests/pre_run_hook.gd`. Merged in #29 and #30.

## Current state

- Four worlds, 20 levels each, split Easy (1–10) / Hard (11–20) by `data/levels/difficulty.json`.
- Every puzzle is generated at load from per-level ranges, so replays differ. Progress is saved locally per world, per difficulty, and separately for shuffle.
- All art is programmer-art placeholder (`assets/sprites/forest_bridge/`, `sky_balloons/`, `market/`, `picnic/`, `ui/`, see the READMEs there), at final filenames and sizes so real art can drop in. Several placeholders are drawn by headless tools in `tools/` (`make_market_placeholders.gd`, `make_picnic_placeholders.gd`, `make_mode_icons.gd`, `make_fox_sad_placeholder.gd`). The author said the placeholders are fine for now.
- Every push to `main` builds the Web preset in CI and publishes it to GitHub Pages at https://malioni.github.io/kids-math-game/ (`.github/workflows/deploy-web.yml`); the runs for #25–#27 all succeeded.
- 416 GUT tests passing (2026-11-05); headless boot clean. `gdlint` isn't installed on the Mac right now (`pip install gdtoolkit`).
- Not yet done: audio (issue #8, `assets/audio/` is empty), final art (issue #7), adaptive difficulty (`scripts/autoloads/progression.gd` is an empty stub), the PIN-gated parent view, native Android/iOS exports (only a Web preset exists), and playtesting with the target age.

## Tech stack and tools

- Godot **4.6** (Mobile renderer; web builds use Compatibility), GDScript, GUT **9.6.0** for tests, gdtoolkit for lint/format.
- Mac Godot binary: `/Applications/Godot-2.app/Contents/MacOS/Godot`.
- Viewport 1280×720 landscape; stretch mode `canvas_items`, aspect `expand`.

```bash
# Run / test / lint (from repo root; see CLAUDE.md)
/Applications/Godot-2.app/Contents/MacOS/Godot --path .
/Applications/Godot-2.app/Contents/MacOS/Godot --path . --headless -s addons/gut/gut_cmdln.gd -gconfig=.gut_config.json
gdlint scripts/ scenes/

# Web build and phone testing
tools/export_web.sh            # needs Godot export templates installed (Editor > Manage Export Templates)
tools/serve_web.sh --tunnel    # prints an https://*.trycloudflare.com address; needs `brew install cloudflared`
```

## Architecture

Strict layers (from `CLAUDE.md`): `scenes/` are presentation only; `scripts/mechanics/` hold mechanic behaviour with no world-specific code; `scripts/systems/` and `scripts/autoloads/` hold core systems; `scripts/worlds/` hold world flow (all extend `WorldBase`); `data/levels/` holds all level content as JSON. Mechanics talk to worlds only through signals and public methods. Every mechanic emits `correct` / `incorrect` and has a `tests/test_<name>.gd` file. Conventions: snake_case, type hints everywhere, `##` doc comments on public methods, signals at the top of the file, `_private` names.

### Key files

| File | Role |
|---|---|
| `scripts/worlds/world_base.gd` | `WorldBase` (extends Node2D): flow shared by every world. Owns the RNG (`puzzle_seed`, 0 = random) and `celebrate_duration`, loads levels, resumes from `GameRegistry.take_requested_level()` or the save for the current difficulty and mode (clamped to the difficulty's range), saves the last world, drives the `LevelHud`, and `_advance()`: in worlds mode the next level, or at the range's end reset to its first level + `world_complete` + star screen; in shuffle, save the shuffle place, then load the next level in place, switch to another world, or show the star screen when every world is done. Handles `level_chosen`, `restart_requested`, `difficulty_chosen`, `shuffle_requested`. `_load_count` is bumped per load; animations check it after each `await` so picking a level mid-animation doesn't double-advance. Subclasses override `_world_id()` and `_setup_level(level)`. |
| `scripts/mechanics/drag_piece.gd` | `DragPiece`: base class for draggable pieces. `bounce_back()`, `move_to(pos)`, `cancel_drag()`, `is_dragging()`; signals `dropped(release_position)`, `tapped` (press and release within 12 px). `PlankDrag`, `BagDrag` and `FruitDrag` extend it. |
| `scripts/mechanics/plank_puzzle_generator.gd` | `PlankPuzzleGenerator` (static). `generate(params, rng) -> {bridge_length, plank_lengths}`, `count_solutions(lengths, target)`. Pure logic, seedable. |
| `scripts/mechanics/placement_mechanic.gd` + `.tscn` | The bridge puzzle. `setup(target_length, plank_lengths)`, `reset()` (same puzzle), `confirm()`, `set_interactive(bool)`, `get_target_length()`, `get_placed_total()`, `get_remaining_length()`, `get_planks()`, `get_placed_planks()`, `get_bridge_end_position()`. Signals: `correct`, `incorrect`, `total_changed(new_total)`. Exported layout tunables: `bridge_width` (600), `drop_margin`, `pile_left`, `pile_right`, `pile_row_y` (3 rows), `pile_spacing`, `go_texture`. |
| `scripts/mechanics/plank_drag.gd` + `.tscn` | A numbered plank (`DragPiece`). `configure(length, unit_px)`; vars `length`, `is_placed`, `home`, `interactive`. 64 px tall, with an 8×6 px touch margin. |
| `scripts/worlds/forest_bridge.gd` + `scenes/worlds/forest_bridge/` | Generates a plank puzzle per level load and runs animations (`walk_across`, `bridge_collapse`, `RESET`), particles and retry. Exports `walk_speed` (500 px/s). Has a `Camera2D` centred at (640, 360). |
| `scripts/mechanics/balloon_puzzle_generator.gd` | `BalloonPuzzleGenerator` (static). `generate(params, rng) -> {target, balloon_values}`, `count_solutions(values, extra)`. |
| `scripts/mechanics/balloon_pop_mechanic.gd` + `.tscn` | `BalloonPopMechanic`. `setup(target, values)`, `reset()`, `pop(balloon)`, `set_interactive()`, `get_target()`, `get_lift_total()`, `get_balance()` (lift − weight), `get_balloons()`, `get_unpopped_balloons()`, `radius_for(value)`. Signals `correct` (lift = weight), `incorrect` (lift < weight), `total_changed`. Evaluates after every pop; no Go button. Up to 4 per row, 2 rows (8 balloons max). Local origin = basket rim. |
| `scripts/mechanics/balloon.gd` + `.tscn` | `Balloon`: `configure(value, radius, color, string_end)`, `pop()`, `contains_global_point()`; signal `tapped` (on press). Texture is white and tinted per balloon. |
| `scripts/worlds/sky_balloons.gd` + `scenes/worlds/sky_balloons/` | `Rig` (mechanic + fox + basket) bobs at (640, 486); clouds scroll by `get_balance()`; states rising / level / falling. Exports `rise_speed_per_unit`, `max_cloud_speed`, `fall_duration`, `fall_distance`, `bob_height`. |
| `scripts/mechanics/market_puzzle_generator.gd` | `MarketPuzzleGenerator` (static). `generate(params, rng) -> Array[{item, bag_size, bag_count, quantity}]`, one order per level item. |
| `scripts/mechanics/market_mechanic.gd` + `.tscn` | `MarketMechanic`. `setup(orders)`, `reset()`, `confirm()`, `set_interactive()`, `get_orders()`, `get_placed_count(item)`, `get_placed_total(item)`, `get_placed_bags(item)`, `get_ready_bag(item)`. Signals `correct`, `incorrect`, `bags_changed(item, count)`. Exports `item_icons`, `go_texture`, `crate_texture`, table/row layout, `max_bags_per_row` (12). |
| `scripts/mechanics/bag_drag.gd` + `.tscn` | `BagDrag` (`DragPiece`): `configure(item_id, size, icon)`, `get_width()`. |
| `scripts/worlds/market.gd` + `scenes/worlds/market/` | Market flow: fox cheer, or tomato throw + splat and retry. Exports `throw_duration`, `splat_duration`. |
| `scripts/mechanics/sharing_puzzle_generator.gd` | `SharingPuzzleGenerator` (static). `generate(params, rng) -> {plates, orders: [{item, share, total}]}`. |
| `scripts/mechanics/sharing_mechanic.gd` + `.tscn` | `SharingMechanic`. `setup(plates, orders)`, `reset()`, `confirm()` (deals to the friends, `deal_step` s per step), `set_interactive()`, `is_dealing()`, `get_orders()`, `get_plate_count()`, `get_placed_count(item)`, `get_placed_pieces(item)`, `get_ready_piece(item)`, `get_basket_count(item)`, `get_dealt_count(guest, item)`, `get_guest(guest)`. Signals `correct`, `incorrect`. Exports textures, `guest_frames`, `guest_tints` and layout. |
| `scripts/mechanics/fruit_drag.gd` + `.tscn` | `FruitDrag` (`DragPiece`): `configure(item_id, icon)`, `get_width()`. |
| `scripts/worlds/picnic.gd` + `scenes/worlds/picnic/` | Picnic flow: everyone cheers, or the fox's sad loop and retry. Exports `sad_duration`. |
| `scripts/ui/level_hud.gd` + `scenes/ui/level_hud.tscn` | `LevelHud` (CanvasLayer 5). `show_level(world_id, index, count)`, `open_picker()`, `close_picker()`, `is_picker_open()`, `show_world_complete()`, `is_world_complete_shown()`, plus test accessors (`get_difficulty_buttons()`, `get_level_buttons()`, `get_world_tabs()`, `get_shuffle_tab()`, `is_shuffle_page_shown()`, `get_shuffle_buttons()`). Signals `level_chosen(world_id, index)` (index −1 = resume that world), `restart_requested`, `difficulty_chosen(difficulty)`, `shuffle_requested(from_start)`. Badge anchored to the play area's top-left so it stays inside the iPhone safe area. |
| `scripts/autoloads/game_registry.gd` | `WORLDS` list (id, scene, icon): forest, sky, market, picnic. `get_worlds()`, `get_world(id)`, `get_level_count(id)`, `go_to_world(id, level_index = -1)`, `request_level()` / `take_requested_level()`, `start_last_world()`. Difficulty and mode read through to `SaveManager`: `get_difficulty()` / `set_difficulty()`, `is_shuffle()` / `set_shuffle()`, `get_level_range()` (0-based `Vector2i`). Shuffle: `shuffle_next_index(id)`, `shuffle_position()` (place in the whole run, for the badge), `next_shuffle_world()`, `reset_shuffle()`, `start_shuffle()`. Test seam: `change_scenes = false` makes `go_to_world()` only record `last_world_request`. |
| `scripts/autoloads/save_manager.gd` | `ConfigFile` at `user://save.cfg`. Progress keys come from `progress_key(world, difficulty, shuffle)`: `"forest:easy"`, `"shuffle:forest:hard"`, … (1-indexed levels). `save_progress` (only raises) / `set_progress` (exact) / `load_progress` / `reset_progress`, `save_last_world` / `load_last_world`, `save_difficulty` / `load_difficulty` (default `easy`), `save_play_mode` / `load_play_mode` (`worlds` / `shuffle`), `migrate_progress(worlds)` (old per-world keys → per-difficulty), and a session count. |
| `scripts/autoloads/progression.gd` | Empty stub, meant for per-skill mastery and adaptive difficulty. |
| `scripts/systems/level_loader.gd` | Autoload. `get_levels_for_world("forest")` reads `data/levels/world_forest/levels.json` and then each level file. `get_difficulty_range(difficulty) -> Vector2i` (0-based, from `difficulty.json`; unknown → easy). `DIFFICULTIES = ["easy", "hard"]`. |
| `scripts/systems/shuffle_picker.gd` | `ShufflePicker.pick(next_levels, last_index, rng) -> String`: a uniformly random world that still has levels left, or `""`. Keys are sorted first, so a seed is deterministic. |
| `scripts/systems/subset_sums.gd` | `SubsetSums.analyze(values, target) -> {count, min_size, max_size}` over distinct multisets. Used by the plank and balloon generators. |
| `scripts/ui/boot.gd` + `scenes/ui/boot.tscn` | Main scene: migrates old saves, then opens the main menu. |
| `tools/export_web.sh`, `tools/serve_web.sh` | Web export and serving (see above). `export_presets.cfg` is committed (single-threaded "Web" preset, no secrets) so CI can see it. `build/` is git-ignored. |
| `.github/workflows/deploy-web.yml` | On push to `main` (or manually): installs Godot 4.6 and its export templates, imports assets, exports "Web" to `build/web`, and deploys it with GitHub Pages. |

## Puzzle generation

The level JSON holds ranges, not puzzles; every schema is documented in `data/levels/README.md`.

```json
{ "id": "world_forest_10", "world": "forest", "mechanic": "placement",
  "bridge_length": { "min": 27, "max": 33 }, "plank_length": { "min": 4, "max": 14 },
  "plank_count": 8, "max_solutions": 2,
  "narrative_key": "forest_bridge_10", "skill_tags": ["addition", "number-composition"] }
```

Generator rules (it retries up to 500 attempts, then falls back to a puzzle with no decoys, which is always solvable):
- Pick bridge length *L* from its range, then a solution of *k* planks: at least 2, and at most `plank_count − ⌈plank_count / 3⌉`. So at least a third of the pile are decoys, and the child has to choose rather than just leave one plank out.
- Split *L* into parts, each drawn uniformly from the range that keeps the remaining parts feasible. This gives varied lengths rather than everything bunched near the average.
- Decoys are random lengths in `[plank_min, min(plank_max, L − 1)]`, so no single plank ever equals *L*.
- Reject the puzzle unless: there are 1 to `max_solutions` distinct solutions (counted by distinct sets of lengths, so two planks labelled 3 don't count twice); no solution uses more than the *k* cap; and the pile totals at most 2 × *L* (so it fits in 3 rows on screen).
- Scale: `unit_px = 600 / L`, so planks and gap share one scale and a correct set exactly fills the gap.

### Forest difficulty curve

| Lvl | Bridge | Planks | Count | Lvl | Bridge | Planks | Count |
|---|---|---|---|---|---|---|---|
| 1 | 2–4 | 1–3 | 3 | 11 | 29–35 | 4–15 | 8 |
| 2 | 3–5 | 1–3 | 4 | 12 | 31–37 | 4–15 | 8 |
| 3 | 4–7 | 1–4 | 4 | 13 | 33–39 | 5–16 | 8 |
| 4 | 6–9 | 2–5 | 5 | 14 | 35–41 | 5–16 | 8 |
| 5 | 8–12 | 2–6 | 5 | 15 | 37–43 | 5–17 | 8 |
| 6 | 10–15 | 2–7 | 6 | 16 | 39–45 | 5–17 | 8 |
| 7 | 13–18 | 3–8 | 6 | 17 | 41–47 | 5–18 | 8 |
| 8 | 16–22 | 3–10 | 7 | 18 | 43–49 | 5–18 | 8 |
| 9 | 20–26 | 4–12 | 7 | 19 | 45–51 | 5–19 | 8 |
| 10 | 27–33 | 4–14 | 8 | 20 | 47–53 | 5–20 | 8 |

`max_solutions` is 2 everywhere. Each level was checked with 1,000 generated puzzles: no fallbacks, worst case 139 attempts, at most 2 ms per puzzle. The narrowest plank is 57 px, at level 20. The curve is meant to be tuned by editing the JSON after playtesting with the author's 6-year-old. When changing ranges, re-run that kind of simulation and the generator tests; `tests/test_plank_puzzle_generator.gd` checks every property over 200 seeds per level.

### Sky Balloons generation

```json
{ "id": "world_sky_10", "world": "sky", "mechanic": "balloon_pop",
  "balloon_count": 6, "balloon_value": { "min": 3, "max": 9 }, "pop_count": { "min": 2, "max": 3 },
  "total_max": 36, "max_solutions": 2, "narrative_key": "sky_balloons_10", "skill_tags": ["subtraction", "number-composition"] }
```

Draw `balloon_count` values; reject if the total exceeds `total_max`; the first *p* (∈ `pop_count`) are the intended pops, extra = their sum, target = total − extra. Reject unless the distinct pop sets summing to extra number ≤ `max_solutions` and every such set pops at least `pop_count.min` balloons (so a level meant to need two pops can't be solved with one). 500 attempts, then a fallback. Prototyped at 300 puzzles per level: no fallbacks, worst case 107 attempts.

| Lvl | Count | Values | Pops | Max total | Lvl | Count | Values | Pops | Max total |
|---|---|---|---|---|---|---|---|---|---|
| 1 | 3 | 1–3 | 1 | 9 | 11 | 6 | 3–10 | 2–3 | 40 |
| 2 | 3 | 1–4 | 1 | 10 | 12 | 6 | 3–11 | 2–3 | 44 |
| 3 | 4 | 1–4 | 1 | 12 | 13 | 7 | 3–11 | 2–3 | 48 |
| 4 | 4 | 1–5 | 1–2 | 14 | 14 | 7 | 3–12 | 2–3 | 52 |
| 5 | 4 | 2–6 | 1–2 | 18 | 15 | 7 | 4–12 | 2–3 | 56 |
| 6 | 5 | 2–6 | 1–2 | 20 | 16 | 7 | 4–13 | 2–4 | 60 |
| 7 | 5 | 2–7 | 2 | 24 | 17 | 8 | 4–13 | 2–4 | 64 |
| 8 | 5 | 2–8 | 2 | 28 | 18 | 8 | 4–14 | 3–4 | 68 |
| 9 | 6 | 2–8 | 2 | 32 | 19 | 8 | 5–14 | 3–4 | 72 |
| 10 | 6 | 3–9 | 2–3 | 36 | 20 | 8 | 5–15 | 3–4 | 76 |

Untested with the target age; the upper levels (subtracting 15–50 from 50–76) are probably hard for a 6-year-old and are the first thing to tune.

### Market generation

```json
{ "id": "world_market_06", "world": "market", "mechanic": "market",
  "items": [
    { "item": "tomato", "bag_size": { "min": 2, "max": 4 }, "bag_count": { "min": 2, "max": 3 } },
    { "item": "potato", "bag_size": { "min": 5, "max": 7 }, "bag_count": { "min": 2, "max": 3 } } ],
  "narrative_key": "market_06", "skill_tags": ["multiplication", "equal-groups"] }
```

Per item, pick a bag size and a bag count from their ranges; the order is size × count. No rejection step: the crates never run out, so every order is solvable and has one answer. Levels 1–5 order tomatoes; 6–10 add potatoes; 11–20 add carrots. Bag counts start low (2–3) each time a new item joins and rise to 8–10 at level 20, so the biggest order is 10 × 10.

### Picnic generation

```json
{ "id": "world_picnic_01", "world": "picnic", "mechanic": "sharing",
  "plates": { "min": 2, "max": 2 },
  "items": [ { "item": "strawberry", "share": { "min": 2, "max": 3 } } ],
  "narrative_key": "picnic_01", "skill_tags": ["division", "fair-sharing"] }
```

Pick the number of plates (the fox's included), then a share per fruit; each basket holds plates × share. Levels 1–5 share strawberries; 6–10 add apples; 11–20 add bananas. Plates and shares start low each time a fruit joins and rise to 5 plates of 7–10 each at level 20, so the biggest basket is 50.

## Difficulty and shuffle

- `data/levels/difficulty.json`: `{"easy": {"first": 1, "last": 10}, "hard": {"first": 11, "last": 20}}`, read by `LevelLoader.get_difficulty_range()` as a 0-based `Vector2i`.
- Save file sections: `progress` holds `<world>:<difficulty>` and `shuffle:<world>:<difficulty>` (1-indexed); `meta` holds `difficulty`, `play_mode`, the last world and the session count. Boot migrates an old `<world>` value N to `easy = N` if N ≤ 10, else `easy = 1, hard = N`.
- Shuffle after every win: save this world's shuffle place, then `ShufflePicker` picks a random world that still has levels left in the difficulty. The same world loads its next level in place (no scene reload); another world is opened at its shuffle place; none left → star screen. Opening a world whose shuffle place is past the range loads the range's last level and defers `start_shuffle()`, so a scene change never happens inside `_ready`.
- Changing difficulty resumes immediately: in worlds mode at that difficulty's saved level, in shuffle at the shuffle place (or the next pick if this world is done).

## Phone and web notes

- Stretch `canvas_items` + aspect `expand` + a centred `Camera2D`: wider phones see extra scenery left and right, and 4:3 iPads see extra above and below. Backgrounds are 1800×1000 with the 1280×720 play area centred, so no bars show. All interactive content stays inside the iPhone landscape safe area.
- The retry icon is anchored to the screen centre (CanvasLayer), 160 px. The Go button is 120 px. The pile rows are kept above the iPhone home indicator.
- Touch works through Godot's default mouse emulation from touch. The input code handles `InputEventMouseButton` / `InputEventMouseMotion` in `_unhandled_input`, with pointer position converted through `get_canvas_transform().affine_inverse()` so it works with the camera.
- **Godot 4 web builds only run in a secure context (https or localhost), even single-threaded.** iPhone Safari rejects a plain `http://` LAN address. GitHub Pages (https) is now the easy way to play on a phone; the Cloudflare quick tunnel (`serve_web.sh --tunnel`) is for testing a local build that isn't on `main`.
- Web export template `web_nothreads_release`; the build is about 38 MB of `.wasm` plus a small `.pck`.
- Native iOS not done yet: it needs Xcode, an Apple ID (a free one means reinstalling every 7 days; the paid $99/yr account adds TestFlight), an iOS export preset, and Developer Mode on the phone. Android needs an Android export preset, the Android SDK and a debug keystore.

## Workflow

- One feature per branch, squash-merged to `main` through PRs. Because of the squash, `git branch -d` refuses merged branches; check the PR is merged and nothing is unpushed, then use `-D`. Commits are authored as `malioni <47998755+malioni@users.noreply.github.com>`.
- `.claude/commands/` holds the project's agent workflow: `/plan` (writes `PLAN.md`), `/plan-review`, `/implement`, `/write-tests`, `/review`, `/write-docs`, `/ship` (all of them in sequence). `PLAN.md` at the repo root holds the current feature's plan, with a revision note at the top whenever implementation departed from it. It currently holds the main menu plan (#29); the next `/plan` replaces it.
- Godot also runs in the Cowork Linux VM (download the `linux.arm64` 4.6 build from GitHub releases into `$HOME`, rsync the repo to a scratch copy, `--import`, then run GUT / `xvfb-run` screenshots there). Run Godot on the scratch copy, not the mounted folder, since deletes are blocked in the mount.
- Before committing: run GUT, `gdlint scripts/ scenes/`, and a headless boot. For visual changes, render screenshots: `xvfb-run` + `--rendering-driver opengl3`, and `--resolution 1688x780` for an iPhone shape.

## Gotchas learned

- macOS ships bash 3.2. Avoid an apostrophe inside `${var:-default}` within double quotes, and don't loop over an empty `"$@"` under `set -u` (use `${1+"$@"}`). Editing a script in place (`sed -i`) can drop its executable bit.
- Set GUT's config `"suffix": ".gd"`, or it tries to load Godot's `.uid` sidecar files as tests.
- Commit Godot 4.6 `.uid` files; the editor creates them for new scripts.
- JSON numbers load as floats in GDScript; assigning them to `int`-typed variables converts them.
- `set_process_input()` on a parent doesn't reach child pieces; use the mechanic's `set_interactive()`.
- Compute piece and bridge positions from the placed total, not from node positions, because pieces may still be mid-tween.
- `bridge_collapse` animates only `Character:position:y`, so the fall happens wherever the walk tween left the fox. Play `RESET` (then `advance(0)`) before each level load and each retry.
- A world that awaits an animation must re-check `_load_count` after each `await`; the player can pick another level mid-animation. Kill running tweens in `_restore_stage()`.
- gdlint rejects enum names starting with `_` (`enum-name`).
- `Array.shuffle()` uses the global RNG; the generators have their own seeded shuffle, so puzzles are reproducible from a seed.
- `change_scene_to_file` in a test replaces GUT's own scene; set `GameRegistry.change_scenes = false` in tests that make a world switch (shuffle does this).
- Tests touching difficulty, mode or progress must delete `user://save.cfg` first; `GameRegistry` reads through to the save rather than caching.
- Each fox frame must stay inside its own 64 px cell with an empty column at each edge, or texture filtering bleeds a neighbour's pixels in (the stray tail tip fixed in #24).

## Open ideas and next steps

- Playtest every world with the target age and tune the level JSON in `data/levels/world_*/`.
- Audio (#8), final art (#7).
- Adaptive difficulty through `Progression` (e.g. repeat easier variants after a failure). DESIGN.md says difficulty should adjust silently; today Easy/Hard is a manual grown-up choice, so either build the adaptive part or update the design.
- Parent view (PIN-gated session summaries).
- Skill areas with no world yet: counting, comparison, patterns and spatial reasoning (mechanics `CountingMechanic`, `SortingMechanic`, `MatchingMechanic`, `BalanceMechanic` in DESIGN.md are unbuilt). Planned worlds: Garden (addition and grouping), Kitchen (addition and subtraction).
- Native Android/iOS builds.
- Market: throw frames for the fox (the fall lurch stands in now).
- Sky Balloons: a pop sound and burst particles; optionally hide the lift total on later levels so the child also has to add.
