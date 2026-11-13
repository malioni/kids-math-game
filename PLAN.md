# PLAN: World 5 — Memory Meadow (memory pairs game)

## Feature
A fifth world where animal cards are dealt face down in a grid on a meadow. The child turns over two at a time: a matching pair leaves the board, a mismatch turns back over. The level is won when every pair is found, and the fox is always one of the pairs.

## Scope

**Included**
- `MemoryMechanic`: a reusable pairs mechanic that deals any list of card faces into a grid, handles turning cards over, matching and turning them back, and emits `correct` when the board is clear.
- `MemoryCard`: one card (a back and a face), tapped to turn over, with turn and leave animations.
- `MemoryPuzzleGenerator`: builds a shuffled deck from level data, always including the fox and filling the rest from a pool of other animals.
- The `memory` world: scene, `Memory` world script extending `WorldBase`, registry entry, 20 level files (easy 1–10, hard 11–20).
- Programmer-art placeholders: card back, 12 animal faces (fox + 11 others), background, world icon.
- Placeholder sounds: `memory/ambience`, `memory/place` (card turns over), `memory/remove` (mismatch turns back) and `memory/match` (pair found).
- Docs: DESIGN.md world section and skill table, `data/levels/README.md` schema, sprite README.

**Out of scope**
- A fail state or retry. There is no limit on turns, so a mismatch is never a wrong answer and `incorrect` is never emitted (see Design decisions).
- Counting or number cards (e.g. matching 3 dots with 3 apples). This is a possible later "hard" variant once plain picture matching has been playtested.
- Final art and final sounds. The placeholders keep the filenames and sizes that final assets will use.
- Look-alike animals as a hard-mode lever, scoring, turn counters, timers.
- A two-player turn mode (parent and child taking turns).

## Design decisions (flag in review)
1. **No lose state.** A mismatch shows both faces for `mismatch_delay` (1.0 s), then turns them back with the `remove` sound, with no sad fox and no retry prompt. CLAUDE.md says every mechanic "must emit `correct` and `incorrect`". `MemoryMechanic` declares the signal through `Mechanic` but documents that it never emits it. `WorldBase` still needs `RetryPrompt/RetryIcon`, which the scene includes, but it is never shown.
2. **Difficulty is the number of pairs, plus a short peek on easy.** On easy levels every card shows face up for `preview_seconds` before turning down, with no input during the peek. Hard levels have no peek.
3. **The fox is always in the deck** through `must_include: ["fox"]` in the level data. The other animals are drawn at random from `pool` on each load, so replays differ.
4. **A matched pair** pops with a small sparkle, plays `memory/match`, and the fox does a short hop (`celebrate` for 0.4 s, then `idle`). Clearing the board goes through the normal `WorldBase` win flow.
5. **Input locks while two unmatched cards are up.** Taps are ignored until they turn back, so a quick child can't turn over a third card. Taps on cards that are face up or already matched are ignored too.
6. **Skill area:** visual memory and attention. This is the first world that isn't arithmetic, so DESIGN.md gets a "Memory & attention" row in the skill table.

## Architecture Impact

**Layers touched:** scenes (mechanic, card, world), scripts/mechanics, scripts/worlds, scripts/autoloads (registry entry only), data/levels, assets, tools, tests, docs.

**New files**
- `scenes/mechanics/memory_card.tscn`, `scripts/mechanics/memory_card.gd` (`class_name MemoryCard`, extends `Node2D`)
- `scenes/mechanics/memory_mechanic.tscn`, `scripts/mechanics/memory_mechanic.gd` (`class_name MemoryMechanic`, extends `Mechanic`)
- `scripts/mechanics/memory_puzzle_generator.gd` (`class_name MemoryPuzzleGenerator`, extends `RefCounted`)
- `scenes/worlds/memory/memory.tscn`, `scripts/worlds/memory.gd`
- `data/levels/world_memory/levels.json` + `world_memory_01.json` … `world_memory_20.json`
- `tools/make_memory_placeholders.gd`
- `assets/sprites/memory/` (`bg_memory.png`, `card_back.png`, `card_front.png`, `animal_<name>.png` ×12, `README.md`), `assets/sprites/ui/icon_world_memory.png`
- `assets/audio/memory/ambience.wav`, `place.wav`, `remove.wav`, `match.wav`
- `tests/test_memory_card.gd`, `tests/test_memory_mechanic.gd`, `tests/test_memory_puzzle_generator.gd`, `tests/test_memory.gd`, `tests/test_world_memory_levels.gd`

**Modified files**
- `scripts/autoloads/game_registry.gd`: add the `memory` entry to `WORLDS`, after `picnic`.
- `tools/make_audio_placeholders.gd`: add `memory` to `PLACE_HZ`, an ambience and a `memory/match` chime.
- `DESIGN.md`: World 5 section; the mechanic library gets `MemoryMechanic`; the skill table gets memory; Garden and Kitchen move to Worlds 6 and 7.
- `data/levels/README.md`: memory level schema.
- `assets/audio/README.md`: list the memory sounds.

**New signals**
- `MemoryCard.tapped(card: MemoryCard)`
- `MemoryMechanic.pair_matched(animal: String)`, emitted once per found pair. The world uses it for the match sound and the fox's hop.
- No new autoloads.

**Signal use from `Mechanic`:** `piece_placed` when the player turns a card over (`memory/place`); `piece_removed` when a mismatched pair turns back (`memory/remove`); `correct` when the last pair is matched; `incorrect` never.

## Implementation Steps

1. **Level data.** Create `data/levels/world_memory/levels.json` and the 20 level files using the progression table under Data Changes. Write `tests/test_world_memory_levels.gd` and run it.
2. **Puzzle generator.** `scripts/mechanics/memory_puzzle_generator.gd`: `static func generate(params: Dictionary, rng: RandomNumberGenerator) -> Array[String]` returns a shuffled deck of `pairs × 2` faces: each `must_include` animal plus `pairs − must_include.size()` distinct random picks from `pool` (minus the must-includes), each twice, shuffled with `rng`. Write `tests/test_memory_puzzle_generator.gd`.
3. **Placeholder art.** `tools/make_memory_placeholders.gd`, in the style of `make_picnic_placeholders.gd`, draws:
   - `card_back.png` (160×160): a leaf pattern.
   - `card_front.png` (160×160): a plain cream card.
   - `animal_fox/rabbit/bear/owl/frog/hedgehog/mouse/duck/pig/cat/deer/squirrel.png` (128×128): simple faces. Each gets a clearly different main colour and a distinct ear shape, because they must be easy to tell apart at a glance.
   - `bg_memory.png` (1800×1000): a meadow clearing.
   - `ui/icon_world_memory.png`: same size as the other world icons.

   Run the tool, then `--import`. Write `assets/sprites/memory/README.md`.
4. **Card.** `scenes/mechanics/memory_card.tscn` has `Back` (Sprite2D), `Front` (Sprite2D) with a `Face` (Sprite2D) child, and a tap area sized to the card. `scripts/mechanics/memory_card.gd` provides:
   - `setup(animal, face_texture, size)`, `get_animal()`, `is_face_up()`, `is_matched()`
   - `show_face(animated := true)`, `show_back(animated := true)`: a `scale.x` squash turn of about 0.15 s.
   - `mark_matched()`: a pop and fade, after which the card ignores taps.
   - `set_tappable(enabled)` and the `tapped` signal.

   Write `tests/test_memory_card.gd`.
5. **Mechanic.** `scripts/mechanics/memory_mechanic.gd` extends `Mechanic`.
   - **Exports:** `card_textures: Dictionary` (animal → Texture2D), `back_texture`, `front_texture`, `board_rect: Rect2`, `card_gap: float`, `max_card_size: float`, `match_delay := 0.4`, `mismatch_delay := 1.0`.
   - **`setup(deck: Array[String], preview_seconds: float)`** builds the cards in a grid from `grid_for(deck.size())`. Cards are sized to fit `board_rect` (capped at `max_card_size`) and the grid is centred. If `preview_seconds > 0`, every card shows face up and then turns down, with taps ignored meanwhile.
   - **`static grid_for(card_count: int) -> Vector2i`** returns (columns, rows) from a fixed table: 4→(4,1), 6→(3,2), 8→(4,2), 10→(5,2), 12→(4,3), 14→(7,2), 16→(4,4), 18→(6,3), 20→(5,4).
   - **`tap_card(index)` / card `tapped`:** turn the card over and emit `piece_placed`. On the second card, lock input. A match waits `match_delay`, marks both matched, emits `pair_matched` and, if all cards are matched, emits `correct`. A mismatch waits `mismatch_delay`, turns both back, emits `piece_removed` and unlocks.
   - **`reset()`:** the same deck, all face down and unmatched, no peek. Each round has a counter (like `SharingMechanic._round`) so pending delays from before a reset do nothing.
   - **`set_interactive(enabled)`.**
   - **Test accessors:** `get_cards()`, `get_deck()`, `get_matched_count()`, `is_previewing()`.
   - Document that `incorrect` is never emitted.

   Write `tests/test_memory_mechanic.gd`.
6. **Sounds.** In `tools/make_audio_placeholders.gd`, add `"memory": <Hz>` to `PLACE_HZ`, a calm meadow ambience (soft breeze with a few low chimes), and `memory/match` (a short rising two-note chime). Regenerate and import. Update `assets/audio/README.md`.
7. **World script.** `scripts/worlds/memory.gd` extends `WorldBase`. It overrides `_world_id()` (returns `"memory"`), `_get_mechanic()` and `_setup_level(level)`, which calls `MemoryPuzzleGenerator.generate(level, _rng)` and `_mechanic.setup(deck, level["preview_seconds"])`. In `_ready()` it calls `super()`, then connects `pair_matched` to play `memory/match` and the fox's short hop. `_restore_stage()` calls `super()` and stops the hop timer/tween.
8. **World scene.** `scenes/worlds/memory/memory.tscn` contains `Background`, `Camera2D`, `Character` (the fox frames reused from Forest Bridge: idle, celebrate, sad), `MemoryMechanic` (exports set: textures, `board_rect` to the right of the fox and clear of the top-left badge), `CelebrationParticles`, `RetryPrompt/RetryIcon` (hidden) and a `LevelHud` instance.
9. **Register.** Add the `memory` entry to `GameRegistry.WORLDS`. Run the full suite: registry, menu, shuffle and `test_world_audio` must all pass with five worlds.
10. **World tests.** Write `tests/test_memory.gd` (see Test Plan).
11. **Docs.** Update DESIGN.md (World 5 section, mechanic library row, skill table row, Garden and Kitchen moved to 6 and 7) and `data/levels/README.md` (memory schema).
12. **Lint and verify.** Run `gdlint scripts/ scenes/`, `gdformat`, then the full GUT run, then launch the game and play levels 1, 10 and 20 by hand. Check card tap size, layout clear of the badge, the peek, and match and mismatch timing.

## Data Changes

`data/levels/world_memory/world_memory_NN.json`:

```json
{
  "id": "world_memory_01",
  "world": "memory",
  "pairs": 2,
  "must_include": ["fox"],
  "pool": ["rabbit", "bear", "owl", "frog", "hedgehog", "mouse", "duck", "pig", "cat", "deer", "squirrel"],
  "preview_seconds": 2.0
}
```

| Field | Type | Description |
|---|---|---|
| `pairs` | int | Pairs on the board (2–10); the deck has `pairs × 2` cards |
| `must_include` | Array[String] | Animals always dealt (the fox) |
| `pool` | Array[String] | Animals the remaining pairs are drawn from at random, without repeats; must hold at least `pairs − must_include.size()` |
| `preview_seconds` | float | How long every card shows face up before the first turn; 0 for no peek |

Each animal name is a key into `MemoryMechanic.card_textures`, set in the world scene.

**Progression**

| Levels | Pairs | Cards | Grid | Peek |
|---|---|---|---|---|
| 1–2 | 2 | 4 | 4×1 | 2.0 s |
| 3–4 | 3 | 6 | 3×2 | 2.0 s |
| 5–6 | 4 | 8 | 4×2 | 1.5 s |
| 7–8 | 5 | 10 | 5×2 | 1.0 s |
| 9–10 | 6 | 12 | 4×3 | 1.0 s |
| 11–12 | 6 | 12 | 4×3 | 0 |
| 13–14 | 7 | 14 | 7×2 | 0 |
| 15–16 | 8 | 16 | 4×4 | 0 |
| 17–18 | 9 | 18 | 6×3 | 0 |
| 19–20 | 10 | 20 | 5×4 | 0 |

## Test Plan

`tests/test_world_memory_levels.gd`
- `test_world_memory_has_20_levels_in_order`
- `test_world_memory_all_levels_have_required_fields`
- `test_world_memory_all_levels_belong_to_memory`
- `test_world_memory_every_level_includes_fox`
- `test_world_memory_pairs_between_2_and_10`
- `test_world_memory_pool_large_enough_for_pairs`
- `test_world_memory_pool_has_no_duplicates_or_fox`
- `test_world_memory_pairs_never_decrease_within_difficulty`
- `test_world_memory_easy_levels_have_preview_hard_levels_none`
- `test_world_memory_every_animal_has_a_texture_in_world_scene`

`tests/test_memory_puzzle_generator.gd`
- `test_memory_puzzle_generator_deck_size_is_twice_pairs`
- `test_memory_puzzle_generator_every_face_appears_exactly_twice`
- `test_memory_puzzle_generator_always_includes_fox`
- `test_memory_puzzle_generator_other_faces_come_from_pool`
- `test_memory_puzzle_generator_same_seed_same_deck`
- `test_memory_puzzle_generator_different_seeds_vary_animals_and_order`

`tests/test_memory_card.gd`
- `test_memory_card_setup_starts_face_down`
- `test_memory_card_show_face_makes_face_up`
- `test_memory_card_show_back_makes_face_down`
- `test_memory_card_tap_emits_tapped`
- `test_memory_card_not_tappable_ignores_tap`
- `test_memory_card_mark_matched_ignores_taps`

`tests/test_memory_mechanic.gd`
- `test_memory_mechanic_setup_creates_one_card_per_deck_entry`
- `test_memory_mechanic_setup_all_cards_face_down_without_preview`
- `test_memory_mechanic_grid_for_matches_table_for_every_even_count_4_to_20`
- `test_memory_mechanic_cards_fit_inside_board_rect`
- `test_memory_mechanic_cards_meet_minimum_tap_size_at_20_cards`
- `test_memory_mechanic_preview_shows_faces_then_hides_them`
- `test_memory_mechanic_taps_ignored_during_preview`
- `test_memory_mechanic_turning_a_card_emits_piece_placed`
- `test_memory_mechanic_matching_pair_emits_pair_matched_and_marks_matched`
- `test_memory_mechanic_mismatch_turns_both_back_and_emits_piece_removed`
- `test_memory_mechanic_mismatch_does_not_emit_incorrect`
- `test_memory_mechanic_third_tap_ignored_while_two_cards_up`
- `test_memory_mechanic_tapping_face_up_card_does_nothing`
- `test_memory_mechanic_last_pair_emits_correct_once`
- `test_memory_mechanic_set_interactive_false_ignores_taps`
- `test_memory_mechanic_reset_turns_all_down_with_same_deck`
- `test_memory_mechanic_reset_during_mismatch_delay_cancels_pending_turn_back`
- `test_memory_mechanic_setup_does_not_emit_piece_signals`

`tests/test_memory.gd`
- `test_memory_world_id_is_memory`
- `test_memory_loads_level_1_with_two_pairs_including_fox`
- `test_memory_level_badge_shows_level_1`
- `test_memory_clearing_board_advances_to_level_2`
- `test_memory_clearing_board_saves_progress`
- `test_memory_last_easy_level_shows_world_complete`
- `test_memory_pair_matched_plays_match_sound`
- `test_memory_mismatch_never_shows_retry_prompt`
- `test_memory_registered_in_game_registry`

## Definition of Done
- [ ] `GameRegistry.get_world("memory")` returns the entry, and a Memory card appears on the main menu, in the level picker and on the star screen
- [ ] `data/levels/world_memory/` has 20 levels that `LevelLoader.get_levels_for_world("memory")` loads, covering easy 1–10 and hard 11–20
- [ ] Every generated deck contains the fox pair, and every face appears exactly twice
- [ ] `MemoryMechanic` emits `piece_placed` on each turn, `piece_removed` when a mismatch turns back, `pair_matched` on each match, and `correct` exactly once when the board is clear, never `incorrect`
- [ ] A mismatch turns back after `mismatch_delay`, with no retry prompt and no lose sound
- [ ] Easy levels show the peek for the level's `preview_seconds`; hard levels start face down
- [ ] At 20 cards, every card fits inside `board_rect`, clear of the level badge, and meets the project's minimum tap size
- [ ] Clearing the board plays the win flow and advances; clearing level 10 on easy (or 20 on hard) shows the star screen
- [ ] `assets/audio/memory/` has `ambience.wav`, `place.wav`, `remove.wav` and `match.wav`, and the audio test passes
- [ ] Shuffle includes the memory world (badge shows /50 with five worlds)
- [ ] DESIGN.md and `data/levels/README.md` describe the world and its schema
- [ ] `gdlint scripts/ scenes/` is clean
- [ ] All GUT tests pass
- [ ] Levels 1, 10 and 20 played by hand in the running game without errors
