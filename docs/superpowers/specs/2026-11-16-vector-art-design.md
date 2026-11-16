# Vector Art and the Market Throw — Design Spec

## Context

GitHub issue #7 (final art). Every sprite is programmer-art drawn pixel by pixel by the scripts in `tools/`,
with hard, unsmoothed edges. The fox is the worst case: its frames are 64 px, and the market, picnic and
memory worlds show it at 2.5× size. The market has no throw frames; its "throw" plays the fox's 3-frame fall
lurch, then a tomato slides in a straight line to the table.

Agreed with the user on 2026-11-16:

- A full redraw of all art (five worlds, the menu and the HUD), with more character: rounder shapes, soft
  shading, an expressive fox, richer backgrounds. It is meant as the game's real look, not a better
  placeholder.
- The art is hand-drawn SVG, imported by Godot directly. No bought asset packs, no AI image generators.
- A real throw in the market: wind-up, release and follow-through, with the tomato flying in an arc.
- Two stages. The fox and the market come first, and the user checks the style before the rest is redrawn.

## Goals

- No visible pixel steps on any sprite, at any window size and in the web build.
- The fox stays sharp at the size the market, picnic and memory worlds show it.
- All art reads as one game: the same outline, palette and shading everywhere.
- The market throw reads as a throw: the fox winds up, the tomato leaves its paw, arcs and splats.
- Layouts, drag sizes and gameplay are unchanged, so no level needs retuning.

## Non-goals

- Changes to gameplay, layouts, level data, sounds, the confetti particles or the app icon (`icon.svg`).
- A jointed, puppet-style fox. It would animate more smoothly, but it changes the `Character` node
  (`AnimatedSprite2D`) that `WorldBase`, five worlds and their tests rely on.
- More frames for the existing fox animations. Frame counts and speeds stay, so timing does not change.
- New sprites the READMEs list as optional (`bridge_collapse`, `plank_splash`) or the Sky Balloons burst
  particles.

## Art files

### Format and import

Every sprite becomes a hand-written `.svg` with the same file name, folder and size (in SVG units) as the PNG
it replaces. Sizes are listed in each folder's README. Because the size is the same, scene positions, drag
sizes and nine-patch margins keep their numbers.

SVGs are imported as Godot's scalable texture (`DPITexture`, present in the project's Godot 4.6.2), which
re-renders the SVG at the screen's real resolution when the window is stretched.

**Step one of the work is a test of that import**, before any art is drawn: one plain sprite, one fox frame
cut from a sheet with `AtlasTexture`, and one nine-patch piece, viewed on desktop at normal and double window
size and in the web build. Each must show correctly, and the plain sprite and the fox frame must stay sharp
at double size.

- If the scalable import fails for a kind of use (nine-patch is the most likely), that kind uses Godot's
  normal SVG import, which is smooth at the base size and slightly soft when stretched.
- If it fails in the web build, everything uses the normal SVG import.

The outcome is recorded in `docs/kids-math-game-context.md`.

### Style rules

- Rounded shapes with a dark brown outline (`#3D2617`, the current `OUTLINE` colour), about 3 units wide at
  a sprite's natural size, with round joins and caps.
- Today's colours as the base palette (fox orange, wood brown, paper cream, tomato red, leaf green, sky
  blue).
- One highlight and one shade per shape: a lighter patch towards the top left, a darker one towards the
  bottom right. Backgrounds may use gradients for sky and ground.
- No text or numbers in the art. Faces that take a label (order slip, target sign, bag) stay blank.
- Only plain shapes, paths and linear or radial gradients. No filters, masks, embedded images or text, which
  Godot's SVG renderer does not handle reliably.
- Nine-patch pieces (`table`, `plank`, `plank_shadow`, `gap_slot_empty`, and any found during the redraw)
  keep their end caps inside the current margins.

### Removed files

As each folder is redrawn, its PNGs and their `.import` files are deleted, along with the script that drew
them: `make_market_placeholders.gd`, `make_fox_sad_placeholder.gd`, `make_picnic_placeholders.gd`,
`make_memory_placeholders.gd`, `make_menu_placeholders.gd`, `make_mode_icons.gd`.
`make_audio_placeholders.gd` stays. Every reference to a sprite path changes from `.png` to `.svg` in
scenes, scripts (`game_registry.gd`), tests and READMEs.

## The fox

### Sheets

`tools/make_fox_sheets.gd` (a headless `SceneTree` script, like the existing tools) writes the fox's sheets
as SVG into `assets/sprites/fox/`. The fox is built from parts (tail, body, legs, arms, head, ears, face) and
each frame is a row in a table of poses: body lean, head tilt, arm and leg angles, tail angle, expression
(eyes, brows, mouth, tears) and a held item. A generator is used here, unlike the other art, because about
thirty frames share the same parts and must not drift apart.

| Sheet | Frames | Notes |
|---|---|---|
| `character_idle.svg` | 4 | Gentle breathing, a blink |
| `character_walk.svg` | 6 | |
| `character_celebrate.svg` | 4 | Arms up, hop |
| `character_fall.svg` | 3 | |
| `character_sad.svg` | 4 | Drooping head, worried brows, tears |
| `character_throw.svg` | 6 | New; see The throw |

Each frame is a 160×160 cell in a horizontal strip. Every pose stays inside its cell with an empty margin at
each edge, so no neighbouring frame bleeds in (the rule from #24).

The fox moves from `assets/sprites/forest_bridge/` to `assets/sprites/fox/` because all five worlds use it.
`go_icon` and `retry_icon` stay in `forest_bridge/`.

### Shared frames

One `SpriteFrames` resource, `assets/sprites/fox/fox_frames.tres`, holds all six animations and replaces the
copy of the frame list each world scene carries today. Names, speeds and loop settings are today's, which
already agree across the scenes:

| Animation | Speed (fps) | Loops |
|---|---|---|
| `idle` | 6 | yes |
| `walk` | 10 | yes |
| `celebrate` | 8 | yes |
| `fall` | 8 | no |
| `sad` | 4 | yes |
| `throw` | 10 | no |

### Scale

Frames grow from 64 to 160 units, so every place that scales the fox is multiplied by 0.4 to keep its size
on screen:

| Where | Today | New |
|---|---|---|
| Market, picnic, memory `Character` | 2.5 | 1.0 |
| Forest Bridge `Character` | 1.0 | 0.4 |
| Sky Balloons `Rig/Character` | 1.3 | 0.52 |
| Picnic friends (`SharingMechanic.guest_scale`) | 2.0 | 0.8 |

Any offset measured in fox pixels (such as the market's `_HAND_OFFSET`) is re-measured against the new
frames.

## Market world

### Sprites

The ten sprites in `assets/sprites/market/` and `ui/icon_world_market` are redrawn to the style rules, at
today's sizes: a market stall background with an awning and depth, the table, crate, paper bag and its
shadow, the order slip, the three produce icons and the splat.

### The throw

All of this lives in `scripts/worlds/market.gd`, a world script, so the layer rules hold.

- The `throw` animation is six frames at 10 fps (0.6 s): frames 0–1 wind up, leaning back with the tomato in
  the raised paw; frame 2 swings; frame 3 releases, the paw forward and empty; frames 4–5 follow through.
- `_play_lose()` plays `throw` and waits for the release frame (`_RELEASE_FRAME := 3`). The tomato then
  appears at the paw and flies to the table over `throw_duration`.
- The flight is an arc: x moves evenly, and y follows the straight line minus a hump that peaks
  `_ARC_HEIGHT := 120.0` px above it at the midpoint. The tomato spins one full turn and grows from 0.6 to
  1.6 as today.
- On landing the tomato hides, the splat shows with a short pop (scale 0.6 → 1.0) and `market/splat` plays,
  as today. The fox returns to `idle` once its throw animation has finished. The retry prompt follows after
  `splat_duration`, as today.
- `_restore_stage()` kills the flight and pop tweens and hides the tomato and splat. A level change during
  the wind-up or the flight leaves no tomato, splat or retry prompt behind.

## Stages

**Stage 1 (one pull request):** the import test, the fox sheets and shared frames in all five worlds, the
market sprites and the throw. Until stage 2, the other four worlds show the new fox on their old
backgrounds.

**Checkpoint:** the user sees screenshots of the market and each throw frame, and plays it. Changes to the
style are made here and written back into the style rules above.

**Stage 2 (one pull request):** `forest_bridge/`, `sky_balloons/`, `picnic/`, `memory/` and `ui/` redrawn to
the same rules, with their generator scripts removed.

## Testing

Existing tests move to the `.svg` paths, and `test_market.gd`'s throw timing constant is updated.

New tests:

- `test_market.gd`: `throw` has six frames, does not loop, and its frames come from
  `fox/character_throw.svg`.
- `test_market.gd`: after a wrong answer the flying tomato is hidden before the release frame and visible
  from it.
- `test_market.gd`: halfway through the flight the tomato is above the straight line from paw to table.
- `test_market.gd`: a level change during the wind-up leaves the tomato and splat hidden.
- Each world's test: its fox uses `fox_frames.tres` and has every animation that world plays.
  `test_picnic.gd` keeps its check that the friends share the fox's frames.

Checks run before each pull request: the full GUT suite, `gdlint scripts/ scenes/` and
`gdformat --check scripts/ scenes/`.

Visual check: screenshots of every changed screen at 1280×720 and at double window size, and the web build
(`tools/export_web.sh`) opened in a browser.

## Docs

- `assets/sprites/*/README.md`: no longer placeholders; file names, sizes, and how the fox sheets are built.
- `CLAUDE.md`: nothing in "Adding a New World" names a sprite format, so no change is expected; confirm.
- `docs/kids-math-game-context.md`: the import test's outcome, the fox's new home and shared frames, the
  market throw, and the "Open ideas" entries for final art and the market throw frames removed.
