# PLAN.md

## Feature
A self-contained `PlacementMechanic` node that tracks how many objects a player has placed, auto-emits `correct` when the exact target is reached, and emits `incorrect` when the player confirms with the wrong count.

## Scope

**Included:**
- `scripts/mechanics/placement_mechanic.gd` — all mechanic logic
- `scenes/mechanics/placement_mechanic.tscn` — minimal composable scene (Node2D + script)
- `tests/test_placement_mechanic.gd` — full GUT test coverage

**Out of scope:**
- Visual representation (sprites, animations) — belongs to world scenes
- Drag-and-drop input handling — belongs to world scenes; worlds call mechanic methods
- Integration with any world or level scene
- Level data loading

## Architecture Impact

**Layers touched:** `scripts/mechanics/`, `scenes/mechanics/`

**New files:**
- `scripts/mechanics/placement_mechanic.gd`
- `scenes/mechanics/placement_mechanic.tscn`
- `tests/test_placement_mechanic.gd`

**Modified files:**
- `scenes/mechanics/.gitkeep` — deleted (directory now has a real file)
- `scripts/mechanics/.gitkeep` — deleted (directory now has a real file)

**New signals:**
- `correct` — emitted when `_placed_count == target_count`
- `incorrect` — emitted when `confirm()` is called and `_placed_count != target_count`
- `count_changed(new_count: int)` — emitted on every placement or removal

**New autoloads:** none

## Implementation Steps

1. **Write `scripts/mechanics/placement_mechanic.gd`**
   - Declare signals `correct`, `incorrect`, `count_changed` at top of file
   - `@export var target_count: int = 0` — configurable per level
   - `var _placed_count: int = 0` — private counter
   - `place() -> void` — increments `_placed_count`, emits `count_changed`; if `_placed_count == target_count`, emits `correct`
   - `remove() -> void` — decrements `_placed_count` (floor 0), emits `count_changed`
   - `confirm() -> void` — emits `incorrect` when `_placed_count != target_count`
   - `reset() -> void` — sets `_placed_count = 0`, emits `count_changed(0)`
   - `get_placed_count() -> int` — returns `_placed_count`

2. **Create `scenes/mechanics/placement_mechanic.tscn`**
   - Root node: `Node2D`, named `PlacementMechanic`
   - Script attached: `res://scripts/mechanics/placement_mechanic.gd`
   - No child nodes — visual composition is the world's responsibility

3. **Delete placeholders**
   - Remove `scenes/mechanics/.gitkeep`
   - Remove `scripts/mechanics/.gitkeep`

4. **Write `tests/test_placement_mechanic.gd`**
   - Instantiate the scene in `before_each`, free in `after_each`
   - Cover all test cases listed in Test Plan

## Data Changes
None — mechanic behaviour is entirely in code; level-specific `target_count` values will come from level data (tracked in a separate issue).

## Test Plan
- `test_place_increments_placed_count` — after one `place()`, `get_placed_count()` returns 1
- `test_place_multiple_accumulates_count` — after N `place()` calls, count equals N
- `test_remove_decrements_placed_count` — after `place()` then `remove()`, count returns to 0
- `test_remove_at_zero_does_not_go_negative` — `remove()` on empty mechanic keeps count at 0
- `test_place_emits_count_changed` — `place()` emits `count_changed` with the new count value
- `test_remove_emits_count_changed` — `remove()` emits `count_changed` with the new count value
- `test_place_exact_target_emits_correct` — placing up to `target_count` emits `correct`
- `test_place_exact_target_does_not_emit_incorrect` — placing up to `target_count` does not emit `incorrect`
- `test_confirm_under_target_emits_incorrect` — `confirm()` when count < target emits `incorrect`
- `test_confirm_over_target_emits_incorrect` — `confirm()` when count > target emits `incorrect`
- `test_confirm_exact_target_does_not_emit_incorrect` — `confirm()` when count == target does not emit `incorrect`
- `test_reset_sets_count_to_zero` — `reset()` sets placed count back to 0
- `test_reset_emits_count_changed_with_zero` — `reset()` emits `count_changed(0)`

## Definition of Done
- [ ] `placement_mechanic.gd` exists with all five public methods and three signals
- [ ] `placement_mechanic.tscn` exists and has the script attached
- [ ] `correct` is emitted when placed count reaches `target_count` via `place()`
- [ ] `incorrect` is emitted by `confirm()` when count does not match `target_count`
- [ ] `count_changed` is emitted on every `place()`, `remove()`, and `reset()`
- [ ] `remove()` cannot push count below zero
- [ ] `reset()` returns count to zero
- [ ] No world, UI, or level references anywhere in the mechanic script
- [ ] All 13 test cases pass
- [ ] All public methods and signals have `##` doc comments
