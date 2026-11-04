# PLAN.md — Main menu, world carousel and fade transitions

> GitHub issue: #9 (written when the game had one world; this plan replaces its scope — update the issue when the PR opens). Agreed with the user in conversation (2026-11-03).

## Feature
A start screen with Play, Shuffle and a swipeable carousel of world cards, the same carousel in place of the level picker's world tabs and the star screen's world list, a home button back to the menu, and a short fade on every level change and scene change.

---

## Scope

**Included:**
- `MainMenu` scene, opened by boot instead of the last world: a big Play button (continue where the child left off: last world, last mode, shuffle included), a Shuffle button, the fox, and the world carousel
- `WorldCarousel`: a reusable horizontal strip of cards built from a list of `{id, icon}` items (normally `GameRegistry.WORLDS`). Snaps to one centred card; neighbours shown smaller and dimmed; swipe or arrow buttons to move; no wrap-around. Adding a world to `GameRegistry.WORLDS` adds a card everywhere with no menu code
- The level picker's world tab row becomes a compact `WorldCarousel` (worlds + a shuffle card)
- The star screen's row of other-world icons becomes a compact `WorldCarousel`, next to restart and a new home button
- A home button in the picker's top row and on the star screen; it returns to the menu without changing mode or difficulty
- `Transition` autoload: fade to a dark cover and back (0.15 s out + 0.15 s in = 0.3 s), blocking input while covered. Used for level changes inside a world (no scene reload), world switches, and menu ↔ world. The game fades in from the cover on launch
- Tap targets of at least 100×100 px on every new button, and the picker's existing buttons raised to at least 100 px high (level buttons, close, easy/hard)
- Placeholder art via a new headless tool: home icon, arrow, play icon, card frame, menu background
- Tests and docs in the same PR

**Out of scope:**
- Storytelling or a world map. The carousel puts every card through one `_card_position(index)` function and scrolls a `Track` control, so a painted path can replace the straight line later without touching callers
- Audio (postponed)
- Difficulty on the menu (stays a grown-up control in the picker)
- Locked worlds, per-world progress shown on cards, Android back-button handling
- Any change to level content or mechanics

---

## Design decisions

| Decision | Choice | Why |
|---|---|---|
| Carousel input | Handles `InputEventMouseButton` / `InputEventMouseMotion` in `_gui_input` (touch arrives as mouse emulation, like the rest of the game). Cards and `Track` use `mouse_filter = IGNORE`, so a press anywhere on the strip (cards included) reaches the carousel; the carousel hit-tests a tap against each card's rect itself, as `DragPiece` does. Only the arrow buttons handle their own presses. Press + release within 12 px = tap on the card under the release point (none → nothing); otherwise a drag that moves the track live and on release snaps to `round(-drag / pitch)` cards away, clamped | One code path for touch and mouse; a swipe that starts on a card still swipes; same tap threshold as `DragPiece` |
| Tapping cards | Every tap emits `card_pressed(id, was_centred)` and centres that card. The menu opens a world only when `was_centred`; the picker selects on any tap | A child who taps a peeking card sees it slide in first, then taps again to go — no surprise jumps; the picker stays one tap |
| Highlight | `set_highlighted(id)` draws the card frame in the "current" colour (picker: page shown; star screen: none) | Replaces the tab highlight |
| Card sizes | Export `card_size`, `pitch`, `side_scale` (0.75), `side_alpha` (0.6). Menu: 360×300 cards, pitch 420. Picker / star screen: 120×100 cards, pitch 132, side_scale 1.0, side_alpha 1.0 (several visible, still scrolls when worlds don't fit) | One component, two densities |
| Future map | Card positions come only from `_card_position(index) -> Vector2` (a straight line now); cards are children of `Track`, which is what scrolls; `track_texture` export (unused now) can draw a strip behind them | Keeps the "painted path later" option cheap |
| Fade owner | New autoload `Transition` (`scripts/autoloads/transition.gd`, a CanvasLayer at layer 100 with a full-rect `ColorRect` cover). `run(action: Callable)`: fade cover in (skipped if the screen is already fully covered), call action (skipped if its object was freed), fade out. `change_scene(path)`: `run()` around `scene_changer.call(path)`, waiting one frame before fading out. Calls made while a transition runs are queued and run in order | Global, survives scene changes; nothing in mechanics |
| Launch | `Transition` starts fully covered and fades out on the frame after `_ready`, unless a `run()`/`change_scene()` has been queued by then. Boot's deferred `go_to_menu()` therefore lands while covered: no fade-in, the scene changes, then one fade out. Result: a single fade-in from the cover at launch, no double flash | Boot always changes scene right away |
| Scene-change seam | `Transition.scene_changer: Callable`, default `get_tree().change_scene_to_file`. Tests swap in a stub that records the path | Lets `change_scene()` be tested without replacing GUT's scene |
| Fade in tests | `Transition.enabled` (default true). Setting it false (a setter) immediately hides the cover, sets its `mouse_filter` to `IGNORE`, kills any running tween and clears the queue; while false, `run()` calls the action at once and `change_scene()` calls `scene_changer` at once. A GUT pre-run hook (`tests/pre_run_hook.gd`, set in `.gut_config.json` `pre_run_script`) turns it off for the whole suite; `test_transition.gd` turns it on per test and back off in `after_each` | The 362 existing tests assume synchronous loads and unblocked input; one switch keeps them unchanged |
| Fade colour | `Color(0.12, 0.08, 0.05)` (very dark brown), export `cover_color` | Softer than pure black; matches the earthy palette |
| Level change inside a world | `WorldBase` gets `_go_to_level(index)` = `Transition.run(_load_level.bind(index))`. `_resume(fade := true)` and `_choose_level(index, fade := true)` gain a `fade` flag choosing `_go_to_level` or `_load_level`. Callers: `_ready` → `_resume(false)` / `_choose_level(i, false)` (the scene fade already covers it); `_on_level_chosen` same world → `_resume()` / `_choose_level(i)` (fade); `_on_difficulty_chosen` → `_resume()` (fade); `_on_restart_requested` worlds mode → `_go_to_level(first)`; `_advance` next level → `_go_to_level`; `_advance_shuffle` same world → `_go_to_level`. Inside `_resume`, the "shuffle finished here" branch loads the range's last level with the same `fade` flag and still defers `GameRegistry.start_shuffle()` (which fades via `change_scene`, queued after any running fade) | No scene reload; `_load_count` still guards stale animations; every caller is explicit |
| Scene changes | `GameRegistry.go_to_world()` and new `go_to_menu()` go through `Transition.change_scene()` when `change_scenes` is true; both record the target scene path in new `last_scene_request` (worlds also keep `last_world_request`) | Existing test seam extended, not replaced |
| Play button | `GameRegistry.start_last_world()` (unchanged: the world resumes in the saved mode, shuffle included) | Already does "continue" |
| Menu Shuffle button | `GameRegistry.start_shuffle()` | Same as the picker's continue when not shuffling; when already shuffling it moves on to a random world with levels left |
| Menu world card | `GameRegistry.set_shuffle(false)` then `go_to_world(id)` (resume its saved level) | Same as picking a world elsewhere: leaves shuffle |
| Menu start card | The carousel starts centred on `SaveManager.load_last_world()` (first world if none), without animating | The child sees where they were |
| Home | `LevelHud.home_requested` → `WorldBase` calls `GameRegistry.go_to_menu()`. Mode, difficulty and progress are untouched | Play then continues exactly where they left off |
| Star screen scaling | Restart, home, then a compact carousel of the other worlds (every world in shuffle) instead of one icon per world | A row of icons breaks past ~6 worlds |
| Safe area | Menu content lives in a 1280×720 `PlayArea` control centred on screen (like the HUD badge's centre-relative offsets), with a 40 px inset; the 1800×1000 background fills the rest | Matches the worlds' "extra scenery on wide phones" approach |
| No text | Menu has no labels; Play is a large green circle with a white triangle, Shuffle reuses `icon_shuffle.png` | DESIGN: no reading required |

---

## Architecture Impact

| Layer | Files |
|---|---|
| `scenes/ui/` | **new** `main_menu.tscn`, `world_carousel.tscn`; **modified** `level_hud.tscn` (TopRow: `WorldTabs` → `WorldCarousel` instance, `HomeButton`; `Complete/Choices`: `HomeButton`, `WorldCarousel` instance; level/close/easy/hard sizes) |
| `scripts/ui/` | **new** `main_menu.gd` (`MainMenu`), `world_carousel.gd` (`WorldCarousel`); **modified** `level_hud.gd`, `boot.gd` |
| `scripts/autoloads/` | **new** `transition.gd`; **modified** `game_registry.gd` (`MENU_SCENE`, `go_to_menu()`, `last_scene_request`, scene changes through `Transition`) |
| `scripts/worlds/` | **modified** `world_base.gd` (`_go_to_level`, home) |
| `project.godot` | **modified**: register `Transition` autoload |
| `assets/sprites/ui/` | **new** `icon_home.png`, `icon_arrow.png`, `icon_play.png`, `card_frame.png`, `bg_menu.png`; **modified** `README.md` |
| `tools/` | **new** `make_menu_placeholders.gd` |
| `tests/` | **new** `test_world_carousel.gd`, `test_transition.gd`, `test_main_menu.gd`, `test_boot.gd`, `pre_run_hook.gd`; **modified** `test_level_hud.gd`, `test_game_registry.gd`, `test_world_modes.gd`; `.gut_config.json` |
| Docs | `DESIGN.md` (Progression System: menu, carousel, home, fades), `CLAUDE.md` (Adding a New World: the card appears automatically), `assets/sprites/ui/README.md` |

No mechanics, systems or level data change.

**New signals:** `WorldCarousel.card_pressed(id: String, was_centred: bool)`, `WorldCarousel.centred_changed(id: String)`, `LevelHud.home_requested`, `Transition.finished`.
**New autoload:** `Transition`.

---

## Implementation Steps

1. **Placeholder art** — `tools/make_menu_placeholders.gd` draws into `assets/sprites/ui/`: `icon_home.png` (128², a little house), `icon_arrow.png` (128², right-pointing; left uses `flip_h`), `icon_play.png` (200², green circle, white triangle), `card_frame.png` (96², cream rounded rect with brown border, used as a 9-patch with 24 px margins), `bg_menu.png` (1800×1000, sky over a meadow). Run it, `--import`, add README rows.
2. **Transition autoload** — `scripts/autoloads/transition.gd`: exports `half_duration` (0.15), `cover_color`; vars `enabled` (with the setter above), `scene_changer`. `run(action)`, `change_scene(path)`, `is_covering()` (cover fully opaque), `is_busy()` (a fade is running or the queue isn't empty), signal `finished` (after the fade back, once the queue is empty). Cover `mouse_filter = STOP` while visible, `IGNORE` otherwise. Queue for overlapping calls. Launch: starts covered; on the next frame fades out only if nothing was queued (see Launch). Register in `project.godot`.
3. **Test hook** — `tests/pre_run_hook.gd` (extends `GutHookScript`, sets `Transition.enabled = false`); `.gut_config.json` `"pre_run_script": "res://tests/pre_run_hook.gd"`. Run the existing suite: still 362 passing.
4. **GameRegistry** — `const MENU_SCENE := "res://scenes/ui/main_menu.tscn"`; `last_scene_request`; `go_to_menu()`; `go_to_world()` records the scene and uses `Transition.change_scene()`.
5. **WorldCarousel** — `scenes/ui/world_carousel.tscn` (`WorldCarousel` Control, `clip_contents`; children `Track` (Control), `PrevButton`, `NextButton` (TextureButtons, `icon_arrow.png`, ≥100×100)). `scripts/ui/world_carousel.gd`: exports above; `set_items(items: Array[Dictionary])`, `scroll_to(id, animate := true)` (false = centre immediately, no tween), `next()`, `previous()`, `get_centred_id()`, `get_cards()`, `get_card(id)` (null if unknown), `set_highlighted(id)`, `_card_position(index)`. Each card is a `Panel` named `Card_<id>` with the `card_frame.png` stylebox and a centred `TextureRect` icon, all `mouse_filter = IGNORE`; taps and swipes are handled by the carousel's `_gui_input` with its own hit-testing (see Carousel input). Arrows hidden at the ends and when everything fits. Snap tween 0.2 s.
6. **MainMenu** — `scenes/ui/main_menu.tscn`: `Background` (`bg_menu.png`, centred), `PlayArea` (1280×720 centred) with `Fox` (AnimatedSprite2D using `forest_bridge/character_idle.png`), `PlayButton` (TextureButton 200×200), `ShuffleButton` (140×140), `WorldCarousel` (menu density). `scripts/ui/main_menu.gd`: fills the carousel from `GameRegistry.get_worlds()`, centres on the last world, wires buttons as in the decision table; test accessors `get_carousel()`, `get_play_button()`, `get_shuffle_button()`.
7. **Boot** — after migration, `GameRegistry.go_to_menu.call_deferred()` instead of `start_last_world`.
8. **LevelHud** — picker: replace `_world_tabs` building with a compact carousel (`items` = worlds + `{id: "shuffle", icon: icon_shuffle}`); `centred`/pressed card → `_show_picker_world(id)` and `set_highlighted(id)`; opens centred on the current world or shuffle. `HomeButton` (100×100) in TopRow emits `home_requested` and closes. Raise level buttons to 150×100, close to 100×100, easy/hard to 120×100; check the panel still fits 720 px with the badge. Star screen: `HomeButton` next to restart; other worlds in a compact carousel; pressing a world card emits `level_chosen(id, -1)` as before. Keep `get_world_tabs()` / `get_shuffle_tab()` returning the carousel's world cards / shuffle card (docs updated); add `get_home_buttons()`, `get_choice_carousel()`.
9. **WorldBase** — `_go_to_level(index)`; `fade` flags on `_resume` and `_choose_level`; wire every caller exactly as in the "Level change inside a world" row; connect `home_requested` → `GameRegistry.go_to_menu()`.
10. **Tests** (see Test Plan).
11. **Docs** — DESIGN.md Progression System; CLAUDE.md "Adding a New World" (register it and its card shows on the menu, picker and star screen); sprite README; refresh `docs/kids-math-game-context.md` locally (untracked).
12. **Verify** — full suite, gdlint, headless boot; screenshots at 1280×720 and 1688×780 of the menu, the menu mid-swipe, the picker, and the star screen; play the web build on a phone (swipe feel, fade timing).

---

## Data Changes

None. Worlds still come from `GameRegistry.WORLDS`; no level or save data changes.

`.gut_config.json` gains:
```json
"pre_run_script": "res://tests/pre_run_hook.gd"
```

---

## Test Plan

`tests/test_world_carousel.gd`
- `test_world_carousel_set_items_creates_a_card_per_item_in_order`
- `test_world_carousel_starts_centred_on_first_item`
- `test_world_carousel_scroll_to_centres_item_and_emits_centred_changed`
- `test_world_carousel_scroll_to_unknown_id_does_nothing`
- `test_world_carousel_scroll_to_without_animation_centres_immediately`
- `test_world_carousel_get_card_unknown_id_returns_null`
- `test_world_carousel_swipe_starting_on_a_card_moves_the_track`
- `test_world_carousel_next_and_previous_move_one_card`
- `test_world_carousel_next_at_last_card_stays_on_last`
- `test_world_carousel_arrows_hidden_at_ends`
- `test_world_carousel_arrows_hidden_when_all_cards_fit`
- `test_world_carousel_swipe_past_half_pitch_centres_next_card`
- `test_world_carousel_short_swipe_snaps_back_to_same_card`
- `test_world_carousel_long_swipe_moves_several_cards_clamped_to_ends`
- `test_world_carousel_tap_on_centred_card_emits_was_centred_true`
- `test_world_carousel_tap_on_neighbour_emits_was_centred_false_and_centres_it`
- `test_world_carousel_swipe_does_not_emit_card_pressed`
- `test_world_carousel_card_position_spaces_cards_by_pitch`
- `test_world_carousel_highlighted_card_uses_current_colour`
- `test_world_carousel_cards_and_arrows_meet_minimum_tap_size`
- `test_world_carousel_with_twelve_items_reaches_every_card`

`tests/test_transition.gd`
- `test_transition_disabled_runs_action_immediately`
- `test_transition_run_covers_screen_before_calling_action`
- `test_transition_run_calls_action_once_then_uncovers_and_emits_finished`
- `test_transition_blocks_input_only_while_covering`
- `test_transition_overlapping_runs_call_actions_in_order`
- `test_transition_skips_action_whose_object_was_freed`
- `test_transition_full_fade_is_under_half_a_second`
- `test_transition_disabling_hides_cover_and_lets_input_through`
- `test_transition_change_scene_covers_then_calls_scene_changer_once`
- `test_transition_change_scene_while_covered_does_not_fade_in_again`
- `test_transition_is_busy_until_queue_is_empty`

`tests/test_main_menu.gd`
- `test_main_menu_has_a_card_per_registered_world`
- `test_main_menu_carousel_starts_on_last_world_played`
- `test_main_menu_carousel_starts_on_first_world_without_save`
- `test_main_menu_play_opens_last_world`
- `test_main_menu_play_keeps_shuffle_mode`
- `test_main_menu_shuffle_button_starts_shuffle`
- `test_main_menu_tapping_centred_card_opens_world_and_leaves_shuffle`
- `test_main_menu_tapping_neighbour_card_only_centres_it`
- `test_main_menu_buttons_meet_minimum_tap_size`

`tests/test_boot.gd`
- `test_boot_migrates_old_save_and_opens_main_menu`

`tests/test_game_registry.gd` (added)
- `test_game_registry_go_to_menu_without_scene_changes_records_request`
- `test_game_registry_go_to_world_records_scene_path`
- `test_game_registry_go_to_world_with_scene_changes_uses_transition` (stub `Transition.scene_changer`)

`tests/test_level_hud.gd` (updated/added)
- `test_level_hud_picker_has_a_card_per_world_plus_shuffle` (replaces `..._has_a_tab_per_world`)
- `test_level_hud_other_world_card_lists_its_levels_and_emits_its_id` (replaces the tab version)
- `test_level_hud_world_card_from_shuffle_page_shows_its_levels` (replaces the tab version)
- `test_level_hud_picker_opens_centred_on_current_world`
- `test_level_hud_picker_home_button_emits_home_requested_and_closes`
- `test_level_hud_world_complete_home_button_emits_home_requested`
- `test_level_hud_world_complete_offers_other_worlds` (updated: cards in the choice carousel)
- `test_level_hud_world_complete_in_shuffle_hides_label_and_lists_every_world` (updated: cards)
- `test_level_hud_buttons_meet_minimum_tap_size`

`tests/test_world_modes.gd` (added)
- `test_world_modes_home_requested_goes_to_menu_and_keeps_mode`
- `test_world_modes_level_change_with_transition_loads_after_cover`
- `test_world_modes_first_level_loads_without_transition`

---

## Definition of Done
- [ ] The game opens on the main menu (after a fade in), not inside a world
- [ ] Play continues the last world in the saved mode (shuffle included); Shuffle starts or continues a shuffle; a centred world card opens that world at its saved level and leaves shuffle
- [ ] The carousel swipes and snaps on a phone and with a mouse, arrows step one card, a peeking card slides in on the first tap; adding a world to `GameRegistry.WORLDS` adds its card on the menu, picker and star screen with no other code
- [ ] The picker's world tabs and the star screen's world list are carousels; home in both returns to the menu without changing mode, difficulty or progress
- [ ] Every level change, world switch and menu ↔ world change fades in about 0.3 s, and taps are ignored while covered; levels inside a world still don't reload the scene
- [ ] Every button on the menu, picker and star screen is at least 100×100 px and inside the iPhone landscape safe area (screenshots at 1280×720 and 1688×780)
- [ ] No text on the menu
- [ ] Every public method and signal is documented and tested; full suite passes; gdlint clean; headless boot clean
- [ ] Web build played on a phone: swipe, fade and home checked
- [ ] Tests and docs in the same PR; issue #9 updated; not merged without the user's go-ahead
