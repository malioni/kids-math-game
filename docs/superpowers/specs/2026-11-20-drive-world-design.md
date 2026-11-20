# World 6: Country Drive — Design Spec

## Context

A new world, agreed with the user on 2026-11-18 to 2026-11-20. The fox sits in a little car on a grassy
field seen from above. Obstacles stand between the car and the fox's garage. The child builds a program
of driving commands first, then presses Go, and the car follows the program square by square while the
command it is running lights up.

It is the first world for **spatial reasoning and sequencing** (planning a route, left and right,
counting squares), a skill area in `DESIGN.md` that has no world yet.

Decisions the user made:

- Easy levels use screen directions (↑ ↓ ← →); hard levels use directions relative to the car (forward,
  turn left, turn right).
- Difficulty rises level by level like the other worlds, and restarts small when hard mode begins.
- The car drives left to right across the screen; the program strip is at the bottom.
- One finish square: the fox's garage on the right edge.
- Taps of the same command in a row merge into one tile with a number. This applies to turns as well as
  steps.
- The car must finish **exactly** on the garage with the program's last move. Driving through the garage
  and on is not a win.
- A bump or a short stop shows the retry button; retry keeps the program so the child can fix it.
- Countryside setting: trees, rocks, bushes and ponds.
- The car is the character: a top-down car with the fox in it, as its own animation sheet (option A).
- New vector art in the existing style is part of this work.

## Goals

- A child of 4–7 can play it with no reading: icons, the car's movement and sound carry all meaning.
- Every generated field can be solved, and its difficulty matches the level's ranges.
- The rules (program, simulation, generation) are pure logic, tested without scenes.
- The world composes the same way as the other five: `WorldBase` flow, `LevelHud`, retry, save, shuffle.

## Non-goals

- Pickups on the way, loops or repeat blocks, conditions.
- Obstacles bigger than one square.
- Final sounds (placeholders, as for the other worlds).
- Changes to `WorldBase`.

## How it plays

### Screen

```
┌────────────────────────────────────────────────────────────┐
│ [badge]                                                    │
│ ┌───┐  ┌──┬──┬──┬──┬──┬──┬──┐                              │
│ │ ↑ │  │🚗│  │🌳│  │  │🪨│  │                              │
│ ├───┤  ├──┼──┼──┼──┼──┼──┼──┤                              │
│ │ ↓ │  │  │  │🌳│  │  │  │🏠│                              │
│ ├───┤  ├──┼──┼──┼──┼──┼──┼──┤                              │
│ │ ← │  │  │  │  │  │💧│  │  │                              │
│ ├───┤  └──┴──┴──┴──┴──┴──┴──┘                              │
│ │ → │                                                      │
│ └───┘  [ →2 ][ ↓ ][ →4 ][ ↑ ]                         [GO] │
└────────────────────────────────────────────────────────────┘
```

- **Field:** a grid of grass squares in two soft shades, centred in the area right of the command
  buttons and above the strip. The largest field (7×5) uses about 80 px squares; smaller fields use
  bigger squares, capped so a 4×3 field doesn't look huge. All of it stays inside the iPhone landscape
  safe area.
- **Start** is a square in the left column, **garage** a square in the right column. Obstacles fill other
  squares, one per square.
- **Command buttons:** a column on the left, below the level badge. Easy: ↑ ↓ ← →. Hard: forward, turn
  left, turn right.
- **Program strip:** along the bottom, left of the Go button. At most **10 tiles**; when it is full, the
  command buttons stop adding (they dim).
- **Go button** at the bottom right, the same size (120 px) as the other worlds' Go buttons.

### Commands

| Mode | Command | Effect of one step |
|---|---|---|
| global (easy) | ↑ ↓ ← → | The car turns to face that way (no extra command needed) and drives one square |
| relative (hard) | forward | Drives one square the way the car faces |
| relative (hard) | turn left / turn right | Turns 90° on the spot |

The car starts each run facing right in both modes.

### Building the program

- Tapping a command button adds one step. If the last tile holds the same command, its count goes up
  (→ 2, → 3, ↰ 2). Otherwise a new tile with count 1 is added.
- Tapping a tile in the strip takes one off its count; at count 1 the tile is removed and the tiles after
  it slide left. If that leaves two neighbouring tiles with the same command, they stay separate (the
  child sees what they built; both still run).
- Adding plays `drive/place`; taking off plays `drive/remove` (through `piece_placed` / `piece_removed`).
- Buttons, tiles and Go are locked while the car drives.
- Go with an empty program does nothing.

### Running the program

On Go the program is unrolled into single moves and simulated on the field. The car then animates move by
move: about 0.35 s per square (`drive` animation, `drive/step` sound), about 0.2 s per turn. The tile that
the current move came from lights up.

Outcomes:

- **Garage:** the program's last move ends on the garage square. The car toots (`drive/honk`), then the
  normal `WorldBase` win flow runs: `celebrate`, particles, next level. Passing through the garage earlier
  in the program doesn't count.
- **Bump:** a move would drive into an obstacle or off the field. The car nudges a third of a square
  towards it and back, plays `bump` (dizzy stars) and `drive/bump`; then the retry button appears.
- **Short:** every move ran without a bump but the car isn't on the garage. The car plays `sad`; then the
  retry button appears.

Both the bump and the short stop emit `incorrect`, so `WorldBase` plays `lose` and shows the retry prompt
as in every other world.

### Retry and new levels

- Retry puts the car back on the start, facing right, `idle`. The program stays. The tile whose move
  bumped, or the last tile for a short stop, is marked ("went wrong here") until the program is edited or
  Go is pressed again.
- Loading a level (next level, the picker, shuffle) clears the program and the mark.

## Levels

Level files live in `data/levels/world_drive/` (`levels.json` plus `world_drive_01.json` …
`world_drive_20.json`):

```json
{ "id": "world_drive_07", "world": "drive", "mode": "global",
  "cols": 6, "rows": 4, "obstacles": { "min": 5, "max": 7 },
  "turns": { "min": 2, "max": 3 }, "max_tiles": 8 }
```

- `mode`: `"global"` or `"relative"`.
- `cols`, `rows`: field size.
- `obstacles`: how many obstacle squares.
- `turns`: how many turns the shortest program needs (see below).
- `max_tiles`: the shortest program may use at most this many tiles. Always below the strip's cap of 10,
  so a longer route than the best one still fits.

**Turns** are counted on the shortest program: in global mode, the number of times the direction changes
(tiles − 1); in relative mode, the number of turn tiles.

### Curve

| Levels | Mode | Field | Obstacles | Turns | Max tiles |
|---|---|---|---|---|---|
| 1–2 | global | 4×3 | 0–1 | 0–1 | 2 |
| 3–4 | global | 5×3 | 2–3 | 1 | 3 |
| 5–6 | global | 5×4 | 3–5 | 1–2 | 3 |
| 7–8 | global | 6×4 | 5–7 | 2–3 | 4 |
| 9–10 | global | 7×5 | 7–9 | 2–3 | 4 |
| 11–12 | relative | 4×3 | 1–2 | 1 | 3 |
| 13–14 | relative | 5×4 | 3–4 | 1–2 | 5 |
| 15–16 | relative | 6×4 | 5–6 | 2 | 5 |
| 17–18 | relative | 6×5 | 6–8 | 2–3 | 7 |
| 19–20 | relative | 7×5 | 8–10 | 3 | 7 |

In relative mode a route with *t* direction changes needs about 2*t* + 1 tiles (forward runs between turn
tiles), so 3 turns is the most that fits comfortably in a 10-tile strip. The curve is a first guess, to be
tuned after playtesting like the other worlds.

## Puzzle generation

`DrivePuzzleGenerator.generate(params, rng) -> Dictionary` returns:

```
{ cols, rows, start: Vector2i, garage: Vector2i,
  obstacles: Array of { cell: Vector2i, kind: "tree" | "rock" | "bush" | "pond" },
  fallback: bool }
```

1. Start: a random row in column 0. Garage: a random row in column `cols − 1`.
2. Obstacle count: random in `obstacles`. Each goes on a random free square that is not the start or the
   garage, with a random kind.
3. `fewest_tiles(field, mode)` finds the shortest program (below). Keep the field if a route exists, its
   turns are within `turns`, and its tile count is at most `max_tiles`.
4. Otherwise try again, up to 500 attempts, all with the level's seeded `rng`. After that, fall back to the
   last attempt's start and garage with no obstacles. The fallback is always solvable but may not meet
   `turns`, and it sets `fallback` to true; the generator tests check no level ever needs it.

### Shortest program: 0-1 breadth-first search

`DrivePuzzleGenerator.fewest_tiles(field, mode) -> Dictionary` returns `{ tiles, turns }`, or `tiles = -1`
when the garage can't be reached.

- A search state is (square, facing, current command).
- Each move either continues the current command (it merges into the current tile, cost 0) or starts a
  different command (a new tile, cost 1).
- Global mode: moves are the four directions; the car faces the way it moved.
- Relative mode: moves are forward, turn left and turn right.
- A double-ended queue holds the states: cost-0 moves go to the front, cost-1 moves to the back. The first
  time the garage is reached as the end of a move, its cost is the fewest tiles.
- Plain breadth-first search would minimise squares, not tiles, and can pick a route that needs more
  tiles. Dijkstra gives the same answer as 0-1 breadth-first search but needs a priority queue; A* and
  enumerating every route (only needed to count solutions, which this world doesn't limit) are more code
  for nothing on fields of at most 35 squares.

## Code structure

Pure logic (no nodes, `RefCounted` or static):

- `scripts/mechanics/drive_program.gd`, `class_name DriveProgram`: the tile list.
  `add(command)`, `take_step(index)`, `get_tiles() -> Array[{command, count}]`, `is_full()`, `clear()`,
  `expand() -> Array[{command, tile}]` (single moves, each with the index of its tile). `MAX_TILES := 10`.
- `scripts/mechanics/drive_simulator.gd`, `class_name DriveSimulator`: `static run(field, moves, mode)
  -> Dictionary` with `poses` (cell and facing after each move), `outcome` (`"garage"`, `"bump"`,
  `"short"`), `fail_move` (index of the bumping move, or the last move for `short`, −1 on `garage`) and
  `bump_kind` (an obstacle kind or `"edge"`).
- `scripts/mechanics/drive_puzzle_generator.gd`, `class_name DrivePuzzleGenerator`: `static generate`,
  `static fewest_tiles`.

Mechanic:

- `scenes/mechanics/drive_mechanic.tscn`, `scripts/mechanics/drive_mechanic.gd`,
  `class_name DriveMechanic extends Mechanic`.
  - `setup(field, mode)`: draws the field and the buttons for the mode, clears the program.
  - `reset()`: car back to the start facing right, program kept, mark kept.
  - `set_interactive(enabled)`.
  - `press_command(command)`, `tap_tile(index)`, `go()`: what the buttons do, public for tests.
  - `get_program() -> DriveProgram`, `get_car() -> AnimatedSprite2D`, `get_lit_tile()`,
    `get_marked_tile()`, `is_driving()`.
  - Signals: `correct`, `incorrect` (from `Mechanic`), `piece_placed`, `piece_removed`,
    `bumped(kind: String)`, `stopped_short`.
  - Exports: textures, `step_duration` (0.35), `turn_duration` (0.2), `max_square_size`, layout rects.
  - Every `await` in the drive checks a run counter bumped by `reset()` and `setup()`, so a level change
    mid-drive stops the old drive.
- `scenes/mechanics/drive_tile.tscn`, `scripts/mechanics/drive_tile.gd`, `class_name DriveTile`: icon,
  count label (hidden at 1), `set_lit()`, `set_marked()`, signal `tapped`.

World:

- `scripts/worlds/drive.gd` extends `WorldBase`: `_world_id()` → `"drive"`, `_get_mechanic()`,
  `_get_character()` → the mechanic's car, `_setup_level(level)` → generate and `setup`. `_play_win()`
  plays `drive/honk` and a short park. `_play_lose()` waits for the bump or sad animation and checks
  `_load_count` after each `await`. `_restore_stage()` calls `_mechanic.reset()` and `super()`.
- `scenes/worlds/drive/drive.tscn`: background, `DriveMechanic`, `LevelHud`, `CelebrationParticles`,
  `RetryPrompt/RetryIcon`, `Camera2D` at (640, 360). No separate `Character` node; the car is the
  character.
- `scripts/autoloads/game_registry.gd`: a `drive` entry after `memory`.

Because `WorldBase` calls `_character.play("idle")` and `play("celebrate")`, the car's sprite frames must
have those animation names.

## Art

All vector SVGs imported as scalable textures (`tools/import_svgs.sh`), each in `tests/test_sprites.gd`'s
size table, listed in `assets/sprites/drive/README.md`.

- **Car sheets**, written by a new `tools/make_car_sheets.gd` (like `make_fox_sheets.gd`), with their own
  `assets/sprites/drive/car_frames.tres`. A small round car seen from above, drawn facing right, with the
  fox's head and ears in the seat, in the fox's palette. Animations: `idle` (engine wobble, blink), `drive`
  (wheels turning, slight bounce), `celebrate` (hop, ears up), `bump` (jolt, dizzy stars), `sad` (ears
  down). The car is rotated by code for other directions. The fox's own sheets don't change.
- **Field:** `bg_drive.svg` (1800×1000 meadow), `grass_light.svg` and `grass_dark.svg` squares,
  `tree.svg`, `rock.svg`, `bush.svg`, `pond.svg`, `garage.svg`.
- **Commands:** `cmd_up/down/left/right.svg`, `cmd_forward.svg`, `cmd_turn_left.svg`,
  `cmd_turn_right.svg`; `tile_frame.svg` (white and grey inside so it can be tinted for lit and marked).
  Go reuses the existing Go texture.
- **World icon:** `ui/icon_world_drive.svg`.

## Sound

Placeholders in `tools/make_audio_placeholders.gd`: `drive` added to `PLACE_HZ` and given an ambience
(birds and a light breeze), plus `drive/step` (a short engine purr), `drive/bump` (a soft boing) and
`drive/honk` (a toot). Listed in `assets/audio/README.md`.

## Tests

- `tests/test_drive_program.gd`: merging steps and turns, taking a step off, removing at 1, no merging
  after a removal, the 10-tile cap, `expand()` tile indices.
- `tests/test_drive_simulator.gd`: both modes; garage exactly; through the garage and on (not a win);
  bump on an obstacle and on each edge with the right `fail_move` and `bump_kind`; short stop; car faces
  the way it moved in global mode.
- `tests/test_drive_puzzle_generator.gd`: for every level, over 200 seeds: a route exists, turns in range,
  shortest program within `max_tiles`, no obstacle on start or garage, start in column 0, garage in the
  last column, the same seed gives the same field, and no level falls back. Hand-built fields for
  `fewest_tiles`, including one where the route with the fewest squares needs more tiles, and an
  unreachable garage.
- `tests/test_drive_mechanic.gd`: buttons build the strip, the cap dims the buttons, tapping tiles, Go
  locks input, tiles light in order, `correct` / `incorrect` / `bumped` / `stopped_short`, `reset()` keeps
  the program, the mark, empty Go does nothing, `setup()` mid-drive stops the old drive.
- `tests/test_drive.gd`: win advances, bump and short show retry, retry keeps the program, a level change
  mid-drive and mid-bump leaves nothing behind, every level solvable in order with the program from
  `fewest_tiles`.
- `tests/test_world_drive_levels.gd`: level files valid, both difficulties covered, `max_tiles` below the
  cap.

## Docs

- `DESIGN.md`: World 6, Country Drive; `DriveMechanic` in the mechanic library; the Garden and the Kitchen
  become Worlds 7 and 8.
- `data/levels/README.md`: the drive level format.
- `assets/sprites/drive/README.md`, `assets/audio/README.md`.
- `docs/kids-math-game-context.md`: World 6 section, key files, generation.
