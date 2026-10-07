# PLAN.md — Plank lengths: build the bridge from numbered planks that add up to its length

> GitHub issue: not yet filed. Builds on issue #7 (merged to `main` as #15).

## Feature
Replace "drop N planks into N slots" with an addition puzzle: each level generates a bridge of length *L* (shown on a sign) and a pile of numbered planks drawn to scale, and the child must lay planks end to end that sum to exactly *L* before pressing Go.

---

## Scope

**Included:**
- One continuous gap instead of per-plank slots; planks laid end to end from the left bank
- Planks show their length as a number **and** are drawn proportionally (bigger number = longer plank)
- A target sign at the near end of the bridge showing *L* — the only number on screen besides the planks
- Rule-based puzzle generation from per-level ranges in `data/levels/`, with at least 1 and at most 2 distinct solutions
- Over-filling impossible: a plank longer than the remaining gap bounces back
- Tap a placed plank to send it back to the pile; remaining placed planks close the gap
- Go with the bridge exactly full → walk home; Go with any gap left → collapse + retry
- Retry keeps the same puzzle; loading a level (new run, resume, replay) generates a fresh one
- New difficulty curve, bridge length 2–4 at level 1 rising to 45–55 at level 10

**Out of scope:**
- Running total / "how much is left" display (deliberately omitted — the child does the adding)
- Adaptive difficulty from `Progression` (ranges are static per level for now)
- Audio (issue #8), menus and transitions (issue #9)
- Final art — placeholders continue (`assets/sprites/forest_bridge/README.md`)
- Persisting the generated puzzle across app restarts (resume regenerates the level)

---

## Design decisions

| Decision | Choice | Why |
|---|---|---|
| Visual scale | `unit_px = bridge_width / L` per level; plank width = `length × unit_px` | Planks and gap share one scale, so a correct set visibly fills the gap exactly |
| Placement position | Drop anywhere over the gap; plank snaps to the next free spot from the left | Removes fiddly positioning; the math is the choice of planks, not where they go |
| Too long for remaining gap | Bounce back to pile | "Putting in more is not possible" |
| Undo | Tap a placed plank | Without it one wrong plank strands the child |
| Running total | Not shown | Keeps the addition with the child |
| "Too many possibilities" | Accept a generated puzzle only if 1 ≤ distinct solutions ≤ `max_solutions` (2) | Distinct = distinct multisets of lengths, so two planks both labelled 3 don't count as separate answers |
| Trivial puzzles | Solution always uses ≥ 2 planks; no single plank equals *L* | Otherwise "find the plank that says L" is a matching task, not addition |
| Pile size | Total pile length ≤ 2 × *L* | Keeps the pile within 3 rows under the river at the shared scale |
| Retry vs. reload | Retry = same puzzle; `_load_level` = new puzzle | Child can learn from the failed attempt; replays differ |

### Generator feasibility (prototyped before writing this plan)
A Python prototype of the algorithm in Step 1, run 500× per level against the difficulty table below:

| Level | Fails | Max attempts | Max pile width (px) | Plank width range (px) |
|---|---|---|---|---|
| 1 | 0 | 1 | 1090 | 150–450 |
| 5 | 0 | 7 | 1280 | 80–480 |
| 10 | 0 | 18 | 1340 | 54–266 |

All levels generate on the first few attempts; `MAX_ATTEMPTS = 200` is a wide margin. Narrowest plank is 54 px — wide enough for a two-digit label and a small finger.

---

## Architecture Impact

**Layers touched:** `data/levels`, `scripts/mechanics`, `scenes/mechanics`, `scripts/worlds`, `scenes/worlds`, `assets/sprites`, `tests`

### New files
```
scripts/mechanics/plank_puzzle_generator.gd   ← pure static generator + solution counter (no nodes, no world knowledge)
assets/sprites/forest_bridge/target_sign.png  ← placeholder wooden sign, ~120×100, blank face for a Label
tests/test_plank_puzzle_generator.gd
```

### Files to modify
| File | Change |
|---|---|
| `scripts/mechanics/placement_mechanic.gd` | Lengths instead of counts: `setup()`, continuous gap, end-to-end placement, tap-to-remove, `total_changed` signal |
| `scenes/mechanics/placement_mechanic.tscn` | Replace `GapContainer` with `Gap` (NinePatchRect) + `PlacedPlanks`; add `TargetSign`; move `GoButton` |
| `scripts/mechanics/plank_drag.gd` | `configure(length, unit_px)`, `tapped` signal, placed state, `home` position |
| `scenes/mechanics/plank_drag.tscn` | `Sprite2D` → `NinePatchRect` body + `LengthLabel`; shadow becomes NinePatchRect |
| `scripts/worlds/forest_bridge.gd` | Own an RNG, generate a puzzle per level, pass it to `setup()` |
| `data/levels/world_forest/world_forest_01..10.json` | New schema (see Data Changes) |
| `data/levels/README.md` | Document new schema |
| `DESIGN.md` | World 1 description: "planks whose lengths add up to the bridge length" |
| `tests/test_placement_mechanic.gd`, `tests/test_plank_drag.gd`, `tests/test_forest_bridge.gd`, `tests/test_world_forest_levels.gd` | Rewritten for lengths |

### Files to delete
```
scenes/mechanics/gap_slot.tscn, scripts/mechanics/gap_slot.gd(.uid)
tests/test_gap_slot.gd(.uid)
assets/sprites/forest_bridge/gap_slot_filled.png(.import)
```
`gap_slot_empty.png` is kept and reused as the 9-patch texture for the continuous `Gap`.

### Signals
- `PlacementMechanic`: `correct`, `incorrect` unchanged. **`count_changed(new_count)` is replaced by `total_changed(new_total: int)`** (no current listeners outside tests).
- `PlankDrag`: `dropped(release_position)` unchanged; **new `tapped`** — press and release within `TAP_THRESHOLD` px.

No new autoloads.

---

## Implementation Steps

### Step 1 — `PlankPuzzleGenerator`
`scripts/mechanics/plank_puzzle_generator.gd` — `class_name PlankPuzzleGenerator extends RefCounted`, static functions only.

```gdscript
const MAX_ATTEMPTS := 200
const MAX_PILE_RATIO := 2.0

## Returns {"bridge_length": int, "plank_lengths": Array[int]} (lengths shuffled).
static func generate(params: Dictionary, rng: RandomNumberGenerator) -> Dictionary
## Number of distinct multisets of lengths drawn from plank_lengths that sum to target.
static func count_solutions(plank_lengths: Array[int], target: int) -> int
```

`generate()` loop (up to `MAX_ATTEMPTS`):
1. `L = rng.randi_range(bridge_length.min, bridge_length.max)`
2. Solution size `k` uniformly in `[max(2, ceil(L / plank_max)), min(plank_count - 1, floor(L / plank_min))]`; if the range is empty, retry
3. Split *L* into `k` parts: start each at `plank_min`, then add 1 to a random part below `plank_max` until the parts sum to *L*
4. Decoys: `plank_count - k` lengths uniform in `[plank_min, min(plank_max, L - 1)]`
5. Reject if `sum(all) > MAX_PILE_RATIO × L`
6. Reject unless `1 <= count_solutions(all, L) <= max_solutions`
7. Shuffle with `rng` and return

If every attempt fails: `push_error` and return the solution parts from the last attempt with no decoys (always solvable). `count_solutions` enumerates all subsets by bitmask (`plank_count` ≤ 10 → ≤ 1024 subsets), collects sorted length arrays that sum to the target in a Dictionary used as a set, and returns its size.

_Files:_ `scripts/mechanics/plank_puzzle_generator.gd`, `tests/test_plank_puzzle_generator.gd`

---

### Step 2 — Level data
Rewrite the 10 level files to the schema in Data Changes using the difficulty table. Update `data/levels/README.md` and `tests/test_world_forest_levels.gd`.

_Files:_ `data/levels/world_forest/*.json`, `data/levels/README.md`, `tests/test_world_forest_levels.gd`

---

### Step 3 — `PlankDrag` with length
Scene (`Node2D` root):
- `Shadow: NinePatchRect` — `plank_shadow.png`, offset `(4, 8)`, hidden by default
- `Body: NinePatchRect` — `plank.png`, patch margins 10 px, height 40
- `LengthLabel: Label` — centred on `Body`, font size 28, dark outline, `mouse_filter = IGNORE`
- All Controls `mouse_filter = IGNORE` so `_unhandled_input` still receives presses

Script:
- `var length: int`, `var is_placed: bool`, `var home: Vector2`
- `configure(length_units: int, unit_px: float) -> void` — sets `length`, sizes `Body`/`Shadow` to `length × unit_px` wide, centres them on the origin, sets label text
- Hit test uses `Body`'s rect
- Press → record press point. If not placed: begin drag as today. Release: if pointer moved < `TAP_THRESHOLD` (12 px) emit `tapped`, otherwise (unplaced only) emit `dropped(global_position)`
- Placed planks never drag; they only emit `tapped`
- `bounce_back()` → tween to `home` (rename of `_origin`)
- `move_to(target: Vector2) -> void` — 0.2 s ease-out tween to a position (used for re-laying and returning home)
- Remove `lock()` (superseded by `is_placed`)
- Keep the `interactive` setter and `cancel_drag()` from `604d668`; `cancel_drag()` returns to `home`

_Files:_ `scenes/mechanics/plank_drag.tscn`, `scripts/mechanics/plank_drag.gd`, `tests/test_plank_drag.gd`

---

### Step 4 — `PlacementMechanic` with lengths
Scene (local origin = centre of gap at bridge height):
- `Gap: NinePatchRect` — `gap_slot_empty.png`, patch margins 12, rect `(-300, -40, 600, 80)`
- `PlacedPlanks: Node2D`, `PlankSource: Node2D`
- `TargetSign: Sprite2D` at `(-370, -90)` — `target_sign.png`, child `TargetLabel: Label` (font size 40)
- `GoButton` at offset `(400, 170)`, 100×100
- Remove `GapContainer`

Tunables follow the `@export` pattern introduced in `604d668`: keep `bridge_width` (600) and `go_texture`; replace `plank_source_y`, `plank_spacing` and `snap_radius` with `drop_margin` (60, vertical tolerance around the gap), `pile_left` (-460), `pile_right` (340), `pile_row_y: Array[float]` ([170, 230, 290]) and `pile_spacing` (16).

Public API:
```gdscript
## Stores the puzzle and calls reset().
func setup(target_length: int, plank_lengths: Array[int]) -> void
## Returns every plank to the pile and rebuilds it from the stored puzzle.
func reset() -> void
## Emits correct if placed total == target_length, else incorrect.
func confirm() -> void
func set_interactive(enabled: bool) -> void
func get_target_length() -> int
func get_placed_total() -> int
func get_remaining_length() -> int
func get_planks() -> Array[Node]          # all planks, pile and placed
func get_placed_planks() -> Array[Node]   # left to right
```
Remove `place()`, `remove()`, `get_placed_count()`, `get_gap_slots()`, `target_count`.

Behaviour:
- `reset()`: free all planks; `unit_px = bridge_width / target_length`; instantiate one `PlankDrag` per length, `configure()`, lay them out in the pile (left to right from `pile_left`, wrap to the next row at `pile_right`), set each `home`; set `TargetLabel.text`; emit `total_changed(0)`
- `_on_plank_dropped(pos, plank)`: if `pos` is outside the gap rect grown by `drop_margin` vertically and 40 px horizontally → `bounce_back()`. Else if `plank.length > get_remaining_length()` → `bounce_back()`. Else mark placed, reparent to `PlacedPlanks` (keeping global position), `_relayout_placed()`, emit `total_changed`
- `_on_plank_tapped(plank)`: if placed → unmark, reparent to `PlankSource`, `move_to(home)`, `_relayout_placed()`, emit `total_changed`
- `_relayout_placed()`: x cursor starts at `-bridge_width / 2`; each placed plank `move_to(Vector2(cursor + width / 2, 0))`; cursor += width

_Files:_ `scenes/mechanics/placement_mechanic.tscn`, `scripts/mechanics/placement_mechanic.gd`, `tests/test_placement_mechanic.gd`; delete gap slot files

---

### Step 5 — `ForestBridge` generates puzzles
- `@export var puzzle_seed: int = 0` — 0 means `randomize()`; tests set a fixed seed
- `var _rng := RandomNumberGenerator.new()` seeded in `_ready()`
- `_load_level(index)`: `var puzzle := PlankPuzzleGenerator.generate(_levels[index], _rng)` then `_mechanic.setup(puzzle.bridge_length, puzzle.plank_lengths)`
- `_on_retry_pressed()` keeps calling `_mechanic.reset()` (same puzzle)
- No changes to animations or save logic

_Files:_ `scripts/worlds/forest_bridge.gd`, `tests/test_forest_bridge.gd`

---

### Step 6 — Placeholder art + docs
- Add `target_sign.png` (wooden sign on a post, blank face) using the existing placeholder style
- Delete `gap_slot_filled.png`; check that `plank.png` and `gap_slot_empty.png` look right stretched as 9-patches (redraw `plank.png` with even end caps if not)
- Update `assets/sprites/forest_bridge/README.md` and `DESIGN.md` (World 1 description, "Place N planks across N gaps" example)

_Files:_ `assets/sprites/forest_bridge/*`, `DESIGN.md`

---

### Step 7 — Visual check
Render levels 1, 5 and 10 (`xvfb` + `--rendering-driver opengl3`, as in #7) in three states: fresh pile, partly built, exactly full. Check that labels are readable, nothing overlaps the Go button or the river edges, and the pile fits in 3 rows.

---

## Data Changes

`target_count` is removed. New level schema:

```json
{
  "id": "world_forest_10",
  "world": "forest",
  "mechanic": "placement",
  "bridge_length": { "min": 45, "max": 55 },
  "plank_length": { "min": 5, "max": 20 },
  "plank_count": 8,
  "max_solutions": 2,
  "narrative_key": "forest_bridge_intro",
  "skill_tags": ["addition", "number-composition"]
}
```

| Field | Type | Description |
|---|---|---|
| `bridge_length.min/max` | int | Inclusive range for the generated bridge length *L* |
| `plank_length.min/max` | int | Inclusive range for every plank (solution and decoys) |
| `plank_count` | int | Total planks in the pile (solution + decoys) |
| `max_solutions` | int | Upper bound on distinct solutions; lower bound is always 1 |

### Difficulty curve

| Level | `bridge_length` | `plank_length` | `plank_count` |
|---|---|---|---|
| 1 | 2–4 | 1–3 | 3 |
| 2 | 3–5 | 1–3 | 4 |
| 3 | 5–8 | 1–4 | 4 |
| 4 | 7–11 | 2–6 | 5 |
| 5 | 10–15 | 2–8 | 5 |
| 6 | 14–20 | 3–10 | 6 |
| 7 | 18–26 | 3–12 | 6 |
| 8 | 24–33 | 4–15 | 7 |
| 9 | 30–40 | 5–18 | 7 |
| 10 | 45–55 | 5–20 | 8 |

`max_solutions` = 2 on every level. To be tuned after playtesting with the target age group.

---

## Test Plan

### `tests/test_plank_puzzle_generator.gd`
```
test_count_solutions_single_exact_pair_returns_1
test_count_solutions_duplicate_lengths_counted_once
test_count_solutions_no_subset_sums_to_target_returns_0
test_count_solutions_two_distinct_multisets_returns_2
test_generate_same_seed_returns_same_puzzle
test_generate_different_seeds_return_different_puzzles            (level 10 params; level 1 has too few possible puzzles)
test_generate_returns_plank_count_planks
test_generate_bridge_length_within_range_for_all_levels
test_generate_plank_lengths_within_range_for_all_levels
test_generate_has_between_1_and_max_solutions_for_all_levels      (200 seeds × 10 levels)
test_generate_no_single_plank_equals_bridge_length_for_all_levels
test_generate_pile_total_at_most_twice_bridge_length_for_all_levels
test_generate_impossible_params_falls_back_to_solvable_puzzle
```

### `tests/test_world_forest_levels.gd`
```
test_world_forest_get_levels_for_world_returns_10_levels          (kept)
test_world_forest_levels_are_in_order                             (kept)
test_world_forest_all_levels_have_required_fields                 (new field list)
test_world_forest_all_levels_use_placement_mechanic               (kept)
test_world_forest_all_ranges_have_min_le_max
test_world_forest_level_01_bridge_length_below_5
test_world_forest_level_10_bridge_length_around_50                 (min ≥ 45, max ≤ 55)
test_world_forest_bridge_length_min_never_decreases_between_levels
test_world_forest_max_solutions_is_at_least_1
```

### `tests/test_plank_drag.gd`
```
test_plank_drag_configure_sets_width_from_length_and_unit_px
test_plank_drag_configure_sets_label_text
test_plank_drag_follows_pointer_while_dragged                     (kept)
test_plank_drag_shows_shadow_only_while_dragged                   (kept)
test_plank_drag_ignores_press_outside_body
test_plank_drag_dropped_signal_emitted_with_correct_position      (kept)
test_plank_drag_short_press_release_emits_tapped_not_dropped
test_plank_drag_placed_plank_does_not_drag
test_plank_drag_placed_plank_emits_tapped
test_plank_drag_bounce_back_returns_to_home
test_plank_drag_ignores_input_when_not_interactive                (kept)
(plus the cancel-drag tests added in 604d668, kept)
```

### `tests/test_placement_mechanic.gd`
```
test_placement_mechanic_setup_spawns_one_plank_per_length
test_placement_mechanic_setup_sets_target_sign_text
test_placement_mechanic_plank_widths_proportional_to_length
test_placement_mechanic_drop_on_gap_places_plank_and_updates_total
test_placement_mechanic_drop_on_gap_emits_total_changed
test_placement_mechanic_placed_planks_laid_end_to_end_from_left
test_placement_mechanic_drop_longer_than_remaining_bounces_back
test_placement_mechanic_drop_exactly_remaining_is_accepted
test_placement_mechanic_drop_outside_gap_bounces_back
test_placement_mechanic_tap_placed_plank_returns_it_and_closes_gap
test_placement_mechanic_confirm_exact_total_emits_correct
test_placement_mechanic_confirm_short_total_emits_incorrect
test_placement_mechanic_confirm_empty_bridge_emits_incorrect
test_placement_mechanic_reset_returns_all_planks_to_pile_with_same_lengths
test_placement_mechanic_reset_emits_total_changed_zero
test_placement_mechanic_pile_fits_within_three_rows_for_level_10
test_placement_mechanic_set_interactive_false_disables_go_and_planks   (kept)
test_go_button_press_calls_confirm                                   (kept)
test_placement_mechanic_get_remaining_length_is_target_minus_total
```

### `tests/test_forest_bridge.gd`
Existing flow tests are kept, with `_fill_and_confirm` changed to place one known solution, found with `count_solutions`-style search over `get_planks()`. Added:
```
test_forest_bridge_load_level_sets_bridge_length_within_level_range
test_forest_bridge_same_seed_generates_same_first_puzzle
test_forest_bridge_retry_keeps_same_puzzle
test_forest_bridge_next_level_generates_new_puzzle
```

---

## Definition of Done

### Gameplay
- [ ] Each plank shows its length as a number, and its drawn width is proportional to that number
- [ ] Target sign shows the bridge length; no running total or other numbers on screen
- [ ] Dropping a plank over the gap lays it end to end after the previous one, starting at the left bank
- [ ] A plank longer than the remaining gap bounces back
- [ ] Tapping a placed plank returns it to the pile and the remaining planks close the gap
- [ ] Go with the bridge exactly full → fox walks home; Go with a gap left → collapse and retry prompt
- [ ] Retry restores the same puzzle; the next level and a fresh run produce different puzzles

### Generation
- [ ] Every generated puzzle has between 1 and `max_solutions` distinct solutions (tested: 200 seeds × 10 levels)
- [ ] Level 1 bridge length < 5; level 10 bridge length 45–55
- [ ] All difficulty parameters live in `data/levels/`; no level numbers hardcoded in scripts

### Layout
- [ ] Levels 1, 5 and 10 render with readable labels, no overlap with the Go button, and the pile within 3 rows (screenshots checked)

### Quality
- [ ] Gap slot scene, script, test and `gap_slot_filled.png` removed
- [ ] All GUT tests pass
- [ ] `gdlint scripts/ scenes/` reports no errors
- [ ] `Godot --path . --headless --quit` runs without errors
