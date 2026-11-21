# PLAN: One menu, a pause panel, a next-difficulty button and 10-level shuffle rounds

## Feature
The main menu becomes the only place to choose what to play: worlds, levels, shuffle, difficulty and sound. In a world, the badge opens a small pause panel. A finished world offers the next difficulty. Shuffle plays rounds of exactly 10 levels, drawn only from the worlds the grown-up has switched on.

## Scope

**Included**

*PR A: menu, pause panel, next difficulty*
- Main menu: the world carousel gets a Shuffle card as its last card, and the separate Shuffle button goes. A level wheel under the carousel shows the current difficulty's levels for the centred world and opens on that world's saved level. Play, or tapping the centred level card, starts the centred world at the centred level. Easy/Hard icons sit in the top-left corner and the music/effects toggles in the top-right. Still no text apart from level numbers.
- `WorldCarousel` can show text cards (level numbers) as well as icon cards. It still knows nothing about worlds or levels.
- In-world HUD: tapping the badge opens a pause panel with home, replay this level, music, effects and close. The world strip, level grid, difficulty buttons and shuffle page are removed.
- World-complete screen: restart, home, and a new next-difficulty button. The button switches the game to the next difficulty in `LevelLoader.DIFFICULTIES` order and starts this world at that difficulty's first level. It is hidden on the last difficulty and in shuffle. The strip of other worlds is removed, since choosing a world now happens only on the menu (user decision).
- While PR B is still open, the Shuffle card on the menu behaves like the old Shuffle button: Play continues or starts a shuffle. In-world shuffle flow is unchanged in PR A apart from the removed picker page.

*PR B: shuffle rounds and world selection*
- A shuffle round is exactly `SHUFFLE_ROUND_LENGTH = 10` wins, however many worlds there are.
- Shuffle follows the game-wide difficulty. Each world keeps its shuffle place (the existing `shuffle:<world>:<difficulty>` keys) between rounds. When a world's place passes the end of the difficulty's range, it wraps to the range's first level.
- Only worlds switched on are picked, and the same world is never picked twice in a row (possible because at least 2 are always on).
- Shuffle setup on the menu (shown in place of the level wheel while the Shuffle card is centred): one toggle per world icon (dimmed when off), with at least 2 always on. The choice is saved, and worlds added later are on by default. A "new round" button is shown only while a round is unfinished.
- Badge in shuffle: the world icon, the shuffle icon and `n/10` (the place in the round).
- End of round: the complete screen with restart (a new round, where every world carries on from its place) and home.

**Out of scope**
- Choosing a level range for shuffle (e.g. 17–20). Difficulty plus carried-over places covers this. More difficulty tiers in `difficulty.json` are a possible later data-only change.
- Locking levels. Every level of the difficulty stays selectable, as now.
- Painted art for new buttons. They reuse existing icons where possible; see Data Changes for the two new placeholder SVGs.
- A 10-dot round indicator. `n/10` matches the world badge and needs no new UI. Dots are a later polish option.
- Renaming `WorldCarousel` (it now also shows levels), to avoid churn.

## Architecture Impact

Layers touched: `scenes/ui`, `scripts/ui`, `scripts/autoloads`, `scripts/systems`, `scripts/worlds/world_base.gd` (shared flow only, no world-specific code). No mechanic code changes. No new autoloads.

**New files**
- `assets/sprites/ui/icon_replay.svg` (PR A): replay this level (circular arrow).
- `assets/sprites/ui/icon_new_round.svg` (PR B): start a new shuffle round (shuffle arrows with a small restart curl).

**Modified files**
- `scripts/ui/world_carousel.gd` / `scenes/ui/world_carousel.tscn`: an item can have `"text"` instead of `"icon"`, which draws a centred Label. Add `set_dimmed(id, dimmed)` for shuffle toggles. The level wheel and the toggle row are separate instances with smaller `card_size`/`pitch`.
- `scenes/ui/main_menu.tscn`, `scripts/ui/main_menu.gd`: new layout and level wheel, shuffle card and setup, corner buttons. Shuffle button removed.
- `scenes/ui/level_hud.tscn`, `scripts/ui/level_hud.gd`: picker replaced by the pause panel. The complete screen loses its choice carousel and gains the next-difficulty button.
- `scripts/worlds/world_base.gd`: handlers for replay and next difficulty. Level-choosing, difficulty-choosing and shuffle-page handlers removed. Shuffle advance counts the round (PR B).
- `scripts/autoloads/game_registry.gd`: `next_difficulty()` (A). Round counter, enabled worlds, wrapping places and `shuffle_position()` as round progress (B).
- `scripts/systems/level_loader.gd`: `get_next_difficulty(difficulty) -> String` (A).
- `scripts/systems/shuffle_picker.gd`: picks from a list of enabled worlds, avoiding the last one (B).
- `scripts/autoloads/save_manager.gd`: round count and switched-off worlds (B).
- `DESIGN.md`: main menu, HUD, difficulty and shuffle bullets.
- Tests: see Test Plan. Also `test_forest_bridge.gd`, `test_sky_balloons.gd`, `test_market.gd`, `test_picnic.gd`, `test_memory.gd` and `test_drive.gd`, which emit `level_chosen`/`difficulty_chosen` on the HUD to jump levels. They switch to a new shared helper, `_start_at(world_scene: PackedScene, level_index: int, difficulty: String) -> Node2D` in `tests/save_fixture.gd`. It calls `GameRegistry.set_difficulty(difficulty)` and `GameRegistry.request_level(<world id>, level_index)` before adding the instanced world to the tree, so tests go through the same path as the menu. No test calls the private `_choose_level()`.

**Signals**
- `LevelHud`: **removed** `level_chosen`, `difficulty_chosen`, `shuffle_requested`. **Added** `replay_requested` (pause panel) and `next_difficulty_requested` (complete screen). **Kept** `restart_requested`, `home_requested`.
- `WorldCarousel`: no new signals. The menu uses the existing `centred_changed` to rebuild the level wheel.

## Implementation Steps

### PR A: menu, pause panel, next difficulty

1. **Next-difficulty lookup**: `scripts/systems/level_loader.gd`. Add `get_next_difficulty(difficulty: String) -> String`, which returns the next entry in `DIFFICULTIES` or `""` on the last or an unknown one. Add `GameRegistry.next_difficulty() -> String` for the current difficulty. Tests in `test_level_loader.gd`.
2. **Text cards and dimming in WorldCarousel**: `scripts/ui/world_carousel.gd`. `_make_card` adds a Label named `Text` when the item has `"text"`, with font size scaling to `card_size.y * 0.45`, centred, in the HUD text colour. Add `set_dimmed(id: String, dimmed: bool)`, which sets the card's `self_modulate` to grey and half alpha so it composes with the side-card alpha from `_layout`. Doc comments updated. Tests in `test_world_carousel.gd`.
3. **Pause panel**: `scenes/ui/level_hud.tscn`, `scripts/ui/level_hud.gd`. Replace `Picker/Panel/Margin/VBox` contents with one centred row: Home, Replay (`icon_replay.svg`), Music, Effects, Close. Each is 110×110 (tests check the existing 100×100 minimum). The backdrop still closes it. Rename `open_picker`/`close_picker`/`is_picker_open` to `open_pause`/`close_pause`/`is_pause_open`. Delete `_show_picker_world`, the grid and level buttons, the world carousel, the shuffle page, the difficulty buttons and their getters. Add `get_replay_button()`. Replay closes the panel and emits `replay_requested`. Update the class doc comment.
4. **Complete screen**: same files. Remove `ChoiceCarousel` and `_on_choice_card_pressed`. Add `NextDifficultyButton` to `Complete/Choices`, using `icon_<next difficulty>.svg` (`icon_hard.svg` after easy) and a small `OneLabel`-style number showing the next difficulty's first level (e.g. "11"). `show_world_complete()` shows it only when `GameRegistry.next_difficulty() != ""` and not shuffling. Pressing it emits `next_difficulty_requested`. Add `get_next_difficulty_button()`.
5. **World flow**: `scripts/worlds/world_base.gd`. Connect `replay_requested` to `_go_to_level(_current_index)`. This fades, loads a fresh puzzle for the same level (`_load_level` already calls `_restore_stage()`), and cancels any running win or lose flow through `_load_count`. It does not reuse the retry prompt's same-puzzle reset. Connect `next_difficulty_requested`: `GameRegistry.set_difficulty(next)`, set this world's progress at the new difficulty to its first level, and `_go_to_level(first)`. Delete `_on_level_chosen`, `_on_difficulty_chosen` and `_on_shuffle_requested`. Keep `_choose_level()`, since the menu still starts worlds at a chosen level through `take_requested_level`. Update the class doc comment.
6. **Fix world tests**: `tests/save_fixture.gd`, the six world test files and `test_world_modes.gd`. Add `_start_at()` to `save_fixture.gd` and replace every HUD-signal level or difficulty jump with it (see Architecture Impact). Delete tests for removed behaviour. Write the new ones listed below.
7. **Menu layout**: `scenes/ui/main_menu.tscn` (1280×720 `PlayArea`):
   - `DifficultyRow` top-left (x 24, y 16): `EasyButton` and `HardButton` (`icon_easy.svg`, `icon_hard.svg`), 110×110, with the current one highlighted.
   - `SoundRow` top-right: `MusicButton` and `EffectsButton`, 110×110.
   - `WorldCarousel` y 40–300, `card_size` 280×220, `pitch` 330.
   - `LevelWheel` (a WorldCarousel instance) y 310–450, `card_size` 160×140, `pitch` 180, so side cards (`side_scale` 0.75) are 120×105 on screen, above the 100×100 tap minimum.
   - `ShuffleSetup` (Control, same rect as the level wheel, hidden by default): `WorldToggles` (an HBoxContainer of icon TextureButtons, one per world, 110×110) and `NewRoundButton` (PR B; in PR A this node is not added).
   - `PlayButton` y 480–660, centred. `Fox` moved bottom-left so it doesn't overlap.
   - Remove `ShuffleButton`. Check the layout headless (no overlaps between button rects) and by running the game.
8. **Menu logic**: `scripts/ui/main_menu.gd`.
   - Carousel items are the worlds plus `{"id": "shuffle", "icon": icon_shuffle.svg}` last. It opens on the Shuffle card if the play mode is shuffle, otherwise on the last world.
   - On `centred_changed` (and in `_ready`): for a world, fill `LevelWheel` with `{"id": str(i), "text": str(i + 1)}` for every level index in `GameRegistry.get_level_range()`, scroll it to that world's saved level (`SaveManager.load_progress(progress_key(world, difficulty)) - 1`, clamped to the range), highlight it, show the wheel and hide `ShuffleSetup`. For Shuffle, hide the wheel and show `ShuffleSetup`.
   - Play, or tapping the centred world card: for a world, `set_shuffle(false)` then `GameRegistry.go_to_world(id, int(level_wheel.get_centred_id()) - 1)`, since ids are 1-based to match the text. For Shuffle, `GameRegistry.start_shuffle()`. Tapping the centred level card does the same as Play.
   - Difficulty buttons: `GameRegistry.set_difficulty()`, then re-highlight and rebuild the wheel for the centred world.
   - Sound buttons: the same toggle logic as the old HUD. Move `_update_sound_buttons` styling into a tiny shared helper only if it isn't trivial to duplicate; otherwise duplicate the few lines.
   - Every button and carousel tap plays `tap`. Update getters: drop `get_shuffle_button()`; add `get_level_wheel()`, `get_difficulty_buttons()`, `get_sound_buttons()`, `get_shuffle_setup()`. Update the class doc comment.
9. **Docs**: `DESIGN.md` main menu, HUD, difficulty, sound and shuffle bullets. Run `gdlint`/`gdformat` and the full GUT suite.

### PR B: shuffle rounds and world selection

10. **Save fields**: `scripts/autoloads/save_manager.gd`, in the `meta` section.
    - `shuffle_round_played` (int ≥ 0): `save_shuffle_round_played(n)` / `load_shuffle_round_played() -> int`. Invalid values read as 0.
    - `shuffle_off` (Array of world ids switched off): `save_shuffle_off(ids: Array[String])` / `load_shuffle_off() -> Array[String]`, where non-string entries are dropped. Storing the *off* list means new worlds are on by default.
11. **ShufflePicker**: `scripts/systems/shuffle_picker.gd`. Replace `pick(next_levels, last_index, rng)` with `pick(worlds: Array[String], previous: String, rng) -> String`. It picks randomly from the sorted `worlds` minus `previous`, falls back to `previous` if that's the only one, and returns `""` for an empty list.
12. **Registry round logic**: `scripts/autoloads/game_registry.gd`.
    - `const SHUFFLE_ROUND_LENGTH := 10`.
    - `shuffle_worlds() -> Array[String]`: registered worlds minus `load_shuffle_off()`. Ids that are no longer registered are ignored. If fewer than 2 remain (e.g. a hand-edited save), returns every world.
    - `is_shuffle_world_on(id) -> bool` and `set_shuffle_world_on(id, on) -> bool`. The setter refuses (returns false, no change) to switch off a world when only 2 are on.
    - `shuffle_next_index(world)`: the saved place, clamped up to the range's first index; **wraps to the first index when past the last**. This also makes old saves where a world was "done" carry on correctly, so no migration is needed.
    - `shuffle_position() -> Vector2i`: `(mini(played + 1, SHUFFLE_ROUND_LENGTH), SHUFFLE_ROUND_LENGTH)`.
    - `next_shuffle_world(previous: String = "") -> String`: `ShufflePicker.pick(shuffle_worlds(), previous, _rng)`. The registry keeps no "last world" state.
    - `is_shuffle_round_finished() -> bool`: played ≥ length. `start_new_shuffle_round()`: sets played to 0 and leaves every world's place unchanged. `start_shuffle()`: sets shuffle on, starts a new round if the last one finished, then goes to `next_shuffle_world()` (no previous).
    - The round count is only changed by a shuffle win, `start_new_shuffle_round()` and `start_shuffle()` on a finished round. It persists when the player leaves shuffle mid-round (Play on a world card, home) and when the difficulty changes mid-round, so coming back to Shuffle continues the same round.
    - Remove `reset_shuffle()`. Its only callers were the HUD start-over and the all-done path, and places are now kept across rounds by design.
13. **World flow**: `scripts/worlds/world_base.gd`. `_advance_shuffle()`: save this world's place (`_current_index + 2`; wrapping is handled on read), add 1 to played, and show the complete screen if the round is finished. Otherwise call `GameRegistry.next_shuffle_world(_world_id())` and `go_to_world()` it. It is never this world, because at least 2 worlds are on. `_resume()` in shuffle loads `shuffle_next_index(_world_id())` directly; the "finished world moves on" branch is no longer needed because places wrap. Restart on the complete screen in shuffle runs `start_new_shuffle_round()` then `start_shuffle()`.
14. **HUD badge**: `scripts/ui/level_hud.gd`. `_update_badge_numbers` in shuffle shows `shuffle_position()`, so it reads `n/10`. Update doc comments.
15. **Menu shuffle setup**: `scripts/ui/main_menu.gd`, `main_menu.tscn`.
    - Build one toggle per registered world in `WorldToggles`. Tapping one calls `set_shuffle_world_on(id, not on)`. On refusal, play a short wiggle tween on the button and no state change. Off toggles use `self_modulate` grey at half alpha.
    - `NewRoundButton` is visible whenever `0 < played < SHUFFLE_ROUND_LENGTH`, whatever the play mode. Tapping it calls `start_new_shuffle_round()` then `start_shuffle()`.
    - Play on the Shuffle card calls `start_shuffle()`, which continues an unfinished round.
16. **Docs and checks**: the `DESIGN.md` shuffle bullet. Run `gdlint`, `gdformat` and the full GUT suite. Do a manual playtest: a round of 10 across switched-on worlds, then the complete screen, then a new round carrying on.

## Data Changes
- No level JSON changes. `data/levels/difficulty.json` is unchanged and its key order is still mirrored by `LevelLoader.DIFFICULTIES` (easiest first), which drives the next-difficulty button.
- Save file (`user://save.cfg`), `[meta]` section, PR B:
  ```ini
  [meta]
  shuffle_round_played=3          ; wins so far in the current round, 0..10
  shuffle_off=["memory"]          ; worlds switched off for shuffle; missing = all on
  ```
- Existing `[progress]` keys `shuffle:<world>:<difficulty>` are kept as each world's shuffle place. Values past the range end (from the old "world finished" state) wrap on read, so no migration is needed.
- New placeholder sprites: `assets/sprites/ui/icon_replay.svg` (A) and `assets/sprites/ui/icon_new_round.svg` (B), each 128×128 in the existing icon style. Add both to the size table in `tests/test_sprites.gd` (`"ui/icon_replay.svg": Vector2(128, 128)`, `"ui/icon_new_round.svg": Vector2(128, 128)`) and to `assets/sprites/ui/README.md`.

## Test Plan

**test_level_loader.gd (A)**
- `test_level_loader_next_difficulty_after_easy_is_hard`
- `test_level_loader_next_difficulty_after_last_is_empty`
- `test_level_loader_next_difficulty_of_unknown_is_empty`

**test_game_registry.gd (A)**
- `test_game_registry_next_difficulty_follows_current_difficulty`

**test_world_carousel.gd (A)**
- `test_world_carousel_text_item_shows_label_with_text`
- `test_world_carousel_icon_item_has_no_label`
- `test_world_carousel_set_dimmed_greys_only_that_card`
- `test_world_carousel_set_dimmed_false_restores_card`

**test_level_hud.gd (A; replaces the picker tests)**
- `test_level_hud_pause_hidden_on_start`
- `test_level_hud_badge_press_opens_pause`
- `test_level_hud_pause_has_home_replay_music_effects_close`
- `test_level_hud_pause_has_no_level_buttons_or_world_strip`
- `test_level_hud_replay_emits_replay_requested_and_closes`
- `test_level_hud_pause_home_emits_home_requested_and_closes`
- `test_level_hud_close_button_closes_pause`
- `test_level_hud_backdrop_tap_closes_pause`
- `test_level_hud_world_complete_on_easy_shows_next_difficulty_button`
- `test_level_hud_world_complete_on_hard_hides_next_difficulty_button`
- `test_level_hud_world_complete_in_shuffle_hides_next_difficulty_button`
- `test_level_hud_next_difficulty_button_emits_next_difficulty_requested`
- `test_level_hud_next_difficulty_label_shows_next_difficultys_first_level`
- `test_level_hud_world_complete_has_no_world_strip`
- Kept and updated: badge counts on easy and hard, world icon, shuffle icon only while shuffling, show_level closes overlays, restart label, complete home, the tap-size test (for the new buttons), the sound toggle tests (moved to the pause panel), taps play `tap`.

**test_world_modes.gd (A)**
- `test_world_modes_replay_reloads_same_level`
- `test_world_modes_replay_during_win_cancels_advance`
- `test_world_modes_next_difficulty_switches_to_hard_and_loads_level_11`
- `test_world_modes_next_difficulty_saves_hard_progress_at_level_11`
- Removed: `difficulty_chosen_resumes...`, `picking_a_level_leaves_shuffle`, `shuffle_continue_*`, `shuffle_start_over_*`. Kept: `picking_hard_level_on_easy_switches_difficulty`, now driven by `request_level`.

**test_main_menu.gd (A)**
- `test_main_menu_carousel_has_every_world_then_shuffle_card_last`
- `test_main_menu_has_no_separate_shuffle_button`
- `test_main_menu_level_wheel_lists_current_difficultys_levels`
- `test_main_menu_level_wheel_on_hard_lists_levels_11_to_20`
- `test_main_menu_level_wheel_opens_on_centred_worlds_saved_level`
- `test_main_menu_centring_another_world_rebuilds_wheel_at_its_saved_level`
- `test_main_menu_play_opens_centred_world_at_centred_level`
- `test_main_menu_tapping_centred_level_card_opens_that_level`
- `test_main_menu_play_on_world_leaves_shuffle`
- `test_main_menu_shuffle_card_hides_wheel_and_shows_shuffle_setup`
- `test_main_menu_play_on_shuffle_card_starts_shuffle`
- `test_main_menu_opens_on_shuffle_card_while_shuffling`
- `test_main_menu_difficulty_button_sets_difficulty_and_rebuilds_wheel`
- `test_main_menu_current_difficulty_button_is_highlighted`
- `test_main_menu_music_button_toggles_and_shows_it`
- `test_main_menu_effects_button_toggles_and_shows_it`
- `test_main_menu_buttons_meet_minimum_tap_size` (carousel and wheel cards are checked at `size * scale`, so side cards count at their drawn size)
- `test_main_menu_shuffle_setup_hidden_on_world_card`
- `test_main_menu_corner_buttons_do_not_overlap_carousel_or_play`
- Kept: one card per world, starts on last world or the first without a save, taps play `tap`.

**test_save_manager.gd (B)**
- `test_save_manager_shuffle_round_played_defaults_to_0`
- `test_save_manager_shuffle_round_played_round_trips`
- `test_save_manager_shuffle_round_played_invalid_reads_0`
- `test_save_manager_shuffle_off_defaults_to_empty`
- `test_save_manager_shuffle_off_round_trips`
- `test_save_manager_shuffle_off_drops_non_string_entries`

**test_shuffle_picker.gd (B; replaces the current four tests)**
- `test_shuffle_picker_picks_only_from_given_worlds`
- `test_shuffle_picker_never_repeats_previous_when_others_exist`
- `test_shuffle_picker_returns_previous_when_it_is_the_only_world`
- `test_shuffle_picker_returns_empty_for_no_worlds`
- `test_shuffle_picker_eventually_picks_every_world_but_previous`
- `test_shuffle_picker_same_seed_same_pick`

**test_game_registry.gd (B)**
- `test_game_registry_shuffle_worlds_defaults_to_every_world`
- `test_game_registry_switched_off_world_is_not_in_shuffle_worlds`
- `test_game_registry_cannot_switch_off_below_two_worlds`
- `test_game_registry_is_shuffle_world_on_reflects_saved_choice`
- `test_game_registry_next_shuffle_world_never_returns_previous`
- `test_game_registry_round_finished_after_ten_wins`
- `test_game_registry_start_new_shuffle_round_resets_count_only`
- `test_game_registry_round_count_survives_leaving_shuffle`
- `test_game_registry_unregistered_off_ids_are_ignored`
- `test_game_registry_shuffle_next_index_wraps_past_range_end`
- `test_game_registry_shuffle_next_index_keeps_place_on_new_round`
- `test_game_registry_shuffle_position_counts_to_round_length`
- `test_game_registry_start_shuffle_after_finished_round_resets_count`
- `test_game_registry_start_shuffle_mid_round_keeps_count`
- `test_game_registry_next_shuffle_world_only_picks_switched_on_worlds`

**test_world_modes.gd (B)**
- `test_world_modes_shuffle_win_adds_one_to_round`
- `test_world_modes_shuffle_tenth_win_shows_complete_screen`
- `test_world_modes_shuffle_win_before_tenth_goes_to_another_world`
- `test_world_modes_shuffle_win_never_loads_same_world_next`
- `test_world_modes_shuffle_restart_starts_new_round_keeping_places`
- `test_world_modes_shuffle_world_past_last_level_resumes_at_first`
- `test_world_modes_shuffle_badge_counts_to_10_with_six_worlds`
- Removed: `shuffle_all_done_shows_star_screen`, `shuffle_win_with_only_this_world_left_loads_next_level_in_place`, `shuffle_finished_world_on_open_moves_on`, `shuffle_badge_counts_through_every_world`.

**test_main_menu.gd (B)**
- `test_main_menu_shuffle_setup_has_a_toggle_per_world`
- `test_main_menu_world_toggle_switches_world_off_and_dims_it`
- `test_main_menu_world_toggle_refuses_below_two_worlds`
- `test_main_menu_new_round_button_hidden_without_unfinished_round`
- `test_main_menu_new_round_button_shown_mid_round_in_worlds_mode`
- `test_main_menu_new_round_button_starts_new_round`

## Definition of Done

**PR A**
- [ ] The main menu shows every world plus a Shuffle card last, and there is no separate Shuffle button
- [ ] The level wheel shows only the current difficulty's levels and opens on the centred world's saved level
- [ ] Play, or tapping the centred level card, opens the centred world at that level, outside shuffle
- [ ] Easy/Hard on the menu change the game-wide difficulty and rebuild the wheel; music/effects toggle and remember their setting
- [ ] The badge opens a pause panel with only home, replay, music, effects and close
- [ ] Replay reloads the current level with a fresh puzzle and cancels any running win or lose flow
- [ ] The world-complete screen on easy shows a next-difficulty button that switches to hard and loads level 11. It is hidden on hard and in shuffle
- [ ] The world-complete screen has no world strip
- [ ] No `level_chosen`, `difficulty_chosen` or `shuffle_requested` remain in `scripts/` or `tests/`
- [ ] Every new menu and pause-panel button is 110×110, every tap target (including side cards at their drawn size) passes the 100×100 test, and nothing overlaps at 1280×720 (checked by test and by eye in the running game)
- [ ] `ui/icon_replay.svg` exists at 128×128 and is listed in `tests/test_sprites.gd` and `assets/sprites/ui/README.md`
- [ ] World tests start levels only through `_start_at()` in `tests/save_fixture.gd`
- [ ] `DESIGN.md` describes the new menu, pause panel and next-difficulty button
- [ ] `gdlint scripts/ scenes/` is clean; the full GUT suite passes

**PR B**
- [ ] A shuffle round ends after exactly 10 wins with six worlds registered, and the badge reads `1/10` … `10/10`
- [ ] A new round continues each world from its shuffle place, and a world past its last level wraps to the difficulty's first level
- [ ] Switched-off worlds are never picked, at least 2 worlds always stay on, and the choice survives a restart of the game
- [ ] A world registered after the choice was saved is on by default
- [ ] The same world is never picked twice in a row
- [ ] A save with an old finished-shuffle place loads and plays without errors
- [ ] New round on the menu shows only during an unfinished round, in either play mode, and resets the count without moving any world's place
- [ ] Leaving shuffle or changing difficulty mid-round keeps the round count
- [ ] `ui/icon_new_round.svg` exists at 128×128 and is listed in `tests/test_sprites.gd` and `assets/sprites/ui/README.md`
- [ ] `DESIGN.md` describes shuffle rounds and world selection
- [ ] `gdlint scripts/ scenes/` is clean; the full GUT suite passes
