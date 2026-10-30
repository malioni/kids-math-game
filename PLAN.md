# PLAN.md — Easy/Hard difficulty and Shuffle mode

> GitHub issue: not filed. Agreed with the user in conversation (2026-10-30).

## Feature
Split every world's 20 levels into Easy (1–10) and Hard (11–20), chosen once in the level picker for the whole game, and add a Shuffle mode that keeps picking a random world and plays that world's next unplayed level of the chosen difficulty.

---

## Scope

**Included:**
- A game-wide difficulty (`easy` / `hard`, default `easy`), saved, chosen with two buttons in the level picker
- Difficulty level ranges stored in data (`data/levels/difficulty.json`), not in code
- Progress saved per world **per difficulty**; one-time migration of the old per-world save
- Playing a world: start at the difficulty's saved level; after its last level (10 or 20) the star screen shows, and restart goes back to the difficulty's first level (1 or 11)
- Level picker shows only the current difficulty's 10 levels, with their real numbers (11–20 on hard); the badge keeps showing e.g. "14/20"
- Picking a level outside the current difficulty (only reachable from code/tests) switches the difficulty to match
- Shuffle mode: a Shuffle tab in the picker starts it. After every win a random world that still has unplayed levels in the current difficulty is chosen; its next shuffle level loads. Shuffle has its **own** saved place in each world, separate from normal play. When every world is done, the star screen shows; restart starts a fresh shuffle
- Picking a specific level (or a world on the star screen) leaves shuffle mode; the mode is saved, so the game reopens in shuffle
- A small shuffle icon on the badge while shuffling
- Placeholder icons for shuffle, easy and hard (`tools/make_mode_icons.gd`)
- Tests and docs in the same PR

**Out of scope:**
- Showing difficulty to the child anywhere but the picker (DESIGN: no difficulty labels for the child — the picker is the grown-up's control)
- Weighting shuffle towards less-played worlds, avoiding repeats of the same world
- Changing any level's content

---

## Design decisions

| Decision | Choice | Why |
|---|---|---|
| Where the split lives | `data/levels/difficulty.json`: `{"easy": {"first": 1, "last": 10}, "hard": {"first": 11, "last": 20}}`, read by `LevelLoader.get_difficulty_range()` (0-based `Vector2i`) | Level content in `data/`; every world has 20 levels |
| Save keys | `"<world>:<difficulty>"` for normal play, `"shuffle:<world>:<difficulty>"` for shuffle; values stay 1-indexed level numbers. Helper `SaveManager.progress_key(world, difficulty, shuffle)` | Reuses the existing progress functions unchanged |
| Migration | `SaveManager.migrate_progress()` (called by boot): an old `"<world>"` value N becomes `easy = N` if N ≤ 10, else `easy = 1, hard = N`; the old key is erased | Existing players keep their place |
| Game-wide state | `SaveManager` stores `difficulty` and `play_mode` (`"worlds"` / `"shuffle"`) in `meta`. `GameRegistry` reads them through, never caches | One source of truth; tests reset it by deleting the save file |
| Shuffle choice | Pure `ShufflePicker.pick(next_levels: Dictionary, last_index: int, rng) -> String` returns a uniformly random world whose next shuffle index ≤ the difficulty's last index, or `""` | Testable without scenes |
| Same world rolled | The world loads its next level in place instead of reloading the scene | No flicker |
| Changing difficulty | Picker emits `difficulty_chosen`; the world saves it and resumes: in worlds mode at its saved level for the new difficulty; in shuffle at its shuffle level, or the next shuffle pick if it has none left | Takes effect immediately |
| Star screen restart label | Shows the difficulty's first level number (1 or 11) in worlds mode; hidden in shuffle (restart = new shuffle) | Accurate on hard |
| Testing world switches | `GameRegistry.change_scenes: bool = true`; when false, `go_to_world()` only records the target in `last_world_request` (and still stores the requested level) | Shuffle switches worlds via `change_scene_to_file`, which would replace GUT's own scene in tests |
| Opening a finished world in shuffle | If the world's shuffle level is past the range end (e.g. reopened after finishing it), `_ready` loads the range's last level and defers `GameRegistry.start_shuffle()` to move on | Never shows a level outside the difficulty; no scene change inside `_ready` |
| Icons | Easy = small hill, Hard = tall snowy mountain, Shuffle = two crossing arrows; 128×128 placeholders | No text, matching the HUD |

---

## Architecture Impact

| Layer | Files |
|---|---|
| `data/levels/` | **new** `difficulty.json`; **modified** `README.md` |
| `scripts/systems/` | **modified** `level_loader.gd` (`get_difficulty_range`); **new** `shuffle_picker.gd` |
| `scripts/autoloads/` | **modified** `save_manager.gd` (keys, migration, difficulty, play mode), `game_registry.gd` (difficulty/mode accessors, `get_level_range`, `start_shuffle`, `next_shuffle_world`) |
| `scripts/worlds/` | **modified** `world_base.gd` (ranges, per-difficulty saves, shuffle flow, difficulty/shuffle signals) |
| `scripts/ui/` | **modified** `level_hud.gd` (difficulty buttons, shuffle tab, range-limited grid, badge shuffle icon, restart label); `boot.gd` (migration) |
| `scenes/ui/` | **modified** `level_hud.tscn` (ModeRow with Easy/Hard buttons, ShuffleIcon on the badge) |
| `assets/sprites/ui/` | **new** `icon_shuffle.png`, `icon_easy.png`, `icon_hard.png`; **modified** `README.md` |
| `tools/` | **new** `make_mode_icons.gd` |
| `tests/` | **new** `test_shuffle_picker.gd`, `test_world_modes.gd`; **modified** `test_save_manager.gd`, `test_level_loader.gd`, `test_game_registry.gd`, `test_level_hud.gd`, `test_forest_bridge.gd`, `test_sky_balloons.gd`, `test_market.gd`, `test_picnic.gd` |
| Docs | `DESIGN.md` (Progression System section) |

**New signals:** `LevelHud.difficulty_chosen(difficulty: String)`, `LevelHud.shuffle_requested`.
**No new autoloads.**

---

## Implementation Steps

1. **Data + loader** — `data/levels/difficulty.json`; `LevelLoader.get_difficulty_range(difficulty: String) -> Vector2i` (0-based first/last; unknown difficulty → whole of easy). `LevelLoader.DIFFICULTIES := ["easy", "hard"]`.
2. **SaveManager** — `progress_key(world, difficulty, shuffle := false) -> String` (static); `save_difficulty/load_difficulty` (default `"easy"`, invalid → `"easy"`); `save_play_mode/load_play_mode` (default `"worlds"`); `migrate_progress(worlds: Array)`.
3. **ShufflePicker** — `scripts/systems/shuffle_picker.gd`, `static func pick(next_levels: Dictionary, last_index: int, rng: RandomNumberGenerator) -> String` (next_levels: world id → 0-based next index; sorted keys before picking so a seed is deterministic).
4. **GameRegistry** — `get_difficulty()`, `set_difficulty(d)`, `is_shuffle()`, `set_shuffle(on)`, `get_level_range(world_id = "") -> Vector2i` (current difficulty), `shuffle_next_index(world_id) -> int` (0-based, from the shuffle save), `next_shuffle_world() -> String` (via ShufflePicker with `_rng`), `start_shuffle()` (set mode, reset all shuffle saves for the difficulty if none left, go to `next_shuffle_world()`), `reset_shuffle()`. `go_to_world()` gains the `change_scenes` test seam (`last_world_request`).
5. **WorldBase** —
   - `_ready`: requested level, else resume index for the mode (`_resume_index()`), clamped to the range.
   - `_advance`: worlds mode as today but against the range end and the per-difficulty key; reset sets the key to the range's first level. Shuffle mode: save `current + 2` to the shuffle key, then `next_shuffle_world()`: `""` → `world_complete` + star screen; this world → `_load_level(current + 1)`; another → `GameRegistry.go_to_world(id)`.
   - `_on_level_chosen`: leaves shuffle; switches difficulty if the index is outside the range; saves to the per-difficulty key.
   - `_on_restart_requested`: worlds mode → first level of the range; shuffle → `GameRegistry.start_shuffle()`.
   - `_on_difficulty_chosen(d)`: save, then resume (see design table).
   - `_on_shuffle_requested`: `GameRegistry.start_shuffle()`.
6. **Icons** — `tools/make_mode_icons.gd` → `assets/sprites/ui/icon_shuffle.png`, `icon_easy.png`, `icon_hard.png`; import; README rows.
7. **LevelHud** — scene: `Root/Picker/Panel/Margin/VBox/ModeRow` (HBox, centred) with `EasyButton`, `HardButton` (Buttons with icon, 110×80); `Root/LevelBadge/Row/ShuffleIcon` (TextureRect 48×48, hidden). Script: signals above; a Shuffle tab appended after the world tabs (`Tab_shuffle`, highlighted while shuffling) emitting `shuffle_requested` and closing; Easy/Hard highlight the current difficulty and emit `difficulty_chosen` and close; `_show_picker_world` lists only `GameRegistry.get_level_range()` levels, buttons named and labelled by real level number, `get_level_buttons()` unchanged; `show_level` toggles `ShuffleIcon`; `show_world_complete()` sets `OneLabel` to the range's first level number, hides it while shuffling, and in shuffle lists every world.
8. **Boot** — `SaveManager.migrate_progress(GameRegistry.get_worlds() ids)` before `start_last_world`.
9. **Tests** (see Test Plan) and update existing world tests to the new keys and the 10-level range.
10. **Docs** — DESIGN.md Progression System; `data/levels/README.md` (difficulty.json); UI sprite README.
11. **Verify** — full suite, gdlint, screenshots of the picker (easy, hard) and a shuffle badge, web export.

---

## Data Changes

`data/levels/difficulty.json`:
```json
{
  "easy": { "first": 1, "last": 10 },
  "hard": { "first": 11, "last": 20 }
}
```
Save file (`user://save.cfg`): section `progress` keys `forest:easy`, `forest:hard`, `shuffle:forest:easy`, …; section `meta` adds `difficulty` and `play_mode`.

---

## Test Plan

`tests/test_level_loader.gd` (added)
- `test_level_loader_difficulty_range_easy_is_levels_1_to_10`
- `test_level_loader_difficulty_range_hard_is_levels_11_to_20`
- `test_level_loader_difficulty_range_unknown_falls_back_to_easy`

`tests/test_save_manager.gd` (added)
- `test_save_manager_progress_key_formats_world_difficulty_and_shuffle`
- `test_save_manager_difficulty_defaults_to_easy_and_roundtrips`
- `test_save_manager_invalid_difficulty_loads_as_easy`
- `test_save_manager_play_mode_defaults_to_worlds_and_roundtrips`
- `test_save_manager_migrate_progress_low_level_moves_to_easy`
- `test_save_manager_migrate_progress_high_level_moves_to_hard`
- `test_save_manager_migrate_progress_leaves_new_keys_alone`

`tests/test_shuffle_picker.gd`
- `test_shuffle_picker_returns_only_worlds_with_levels_left`
- `test_shuffle_picker_returns_empty_when_all_done`
- `test_shuffle_picker_eventually_picks_every_open_world`
- `test_shuffle_picker_same_seed_same_pick`

`tests/test_game_registry.gd` (added)
- `test_game_registry_level_range_follows_difficulty`
- `test_game_registry_next_shuffle_world_skips_finished_worlds`
- `test_game_registry_next_shuffle_world_empty_when_all_finished`
- `test_game_registry_set_shuffle_persists_mode`
- `test_game_registry_go_to_world_without_scene_changes_records_request`
- `test_game_registry_start_shuffle_resets_when_all_finished`

`tests/test_level_hud.gd` (updated/added)
- `test_level_hud_picker_lists_only_easy_levels` (10 buttons, "1".."10")
- `test_level_hud_picker_on_hard_lists_levels_11_to_20`
- `test_level_hud_difficulty_button_emits_difficulty_chosen_and_closes`
- `test_level_hud_current_difficulty_button_is_highlighted`
- `test_level_hud_shuffle_tab_emits_shuffle_requested_and_closes`
- `test_level_hud_badge_shows_shuffle_icon_only_while_shuffling`
- `test_level_hud_world_complete_restart_label_shows_first_level_of_difficulty`
- `test_level_hud_world_complete_in_shuffle_hides_label_and_lists_every_world`

`tests/test_world_modes.gd` (uses the forest world with tiny durations)
- `test_world_modes_easy_starts_at_level_1_and_completes_after_level_10`
- `test_world_modes_easy_restart_goes_to_level_1`
- `test_world_modes_hard_starts_at_level_11`
- `test_world_modes_hard_completes_after_level_20_and_restart_goes_to_11`
- `test_world_modes_progress_is_saved_per_difficulty`
- `test_world_modes_difficulty_chosen_resumes_at_that_difficultys_level`
- `test_world_modes_picking_hard_level_on_easy_switches_difficulty`
- `test_world_modes_shuffle_win_saves_shuffle_progress_not_normal_progress`
- `test_world_modes_shuffle_win_with_only_this_world_left_loads_next_level_in_place`
- `test_world_modes_shuffle_all_done_shows_star_screen`
- `test_world_modes_shuffle_restart_starts_fresh_shuffle`
- `test_world_modes_picking_a_level_leaves_shuffle`
- `test_world_modes_shuffle_resumes_at_shuffle_level`
- `test_world_modes_shuffle_win_with_other_worlds_left_requests_one_of_them`
- `test_world_modes_shuffle_finished_world_on_open_moves_on`

Existing world tests (`forest_bridge`, `sky_balloons`, `market`, `picnic`): switch save assertions to `progress_key(...)`, and "every level / world complete after all levels" tests to the 10-level easy range plus a hard-range run.

---

## Definition of Done
- [ ] Easy plays levels 1–10, Hard 11–20, in every world; finishing the range shows the star screen and restart returns to its first level
- [ ] Difficulty is chosen in the picker, saved, and applies to every world; the child-facing badge never shows it
- [ ] Progress is kept separately per world, per difficulty, and for shuffle; an old save is migrated
- [ ] Shuffle picks only worlds with unplayed levels in the difficulty, plays each world's levels in order, and ends with the star screen; restart starts a fresh shuffle
- [ ] Picking a level leaves shuffle; the game reopens in the mode it was left in
- [ ] Every public method and signal is documented and tested; full suite passes; gdlint clean
- [ ] Picker screenshots (easy, hard) and a shuffle badge checked; web export builds
- [ ] Tests and docs in the same PR; not merged without the user's go-ahead
