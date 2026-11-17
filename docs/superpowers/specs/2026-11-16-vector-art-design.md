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

Stage 1 was merged as #43. At the style checkpoint (2026-11-16) the user approved the style as it is and
asked for two changes, which stage 2 carries:

- The fox looked turned away from the viewer with its head twisted round, because its near arm sat on the
  chest side. The near arm moves left, so the body reads as turned a little towards the viewer (see The
  fox, Pose).
- The Forest Bridge fox must celebrate after it crosses the bridge, as the fox does in the other worlds
  (see Forest Bridge world).

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
  One exception, made in stage 1: the idle's three open-eyed frames are held four times as long as the
  blink frame (per-frame durations 4, 4, 4, 1), because a blink every 0.67 s looked twitchy.
- Drawing sprites larger than the PNGs they replace. A few are shown bigger than their natural size (the
  world icons on the menu's centre card at about 1.8×, the memory cards at up to 1.25×) and stay slightly
  soft there, as any enlarged texture does. Checked on the stage 1 market icon; it reads well.
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

The desktop half was run on 2026-11-16 in a scratch project at double zoom: `Sprite2D`, a sprite cut with
`AtlasTexture`, `AnimatedSprite2D`, `NinePatchRect`, `TextureRect` and `TextureButton` all stayed sharp with
the scalable import, and all were visibly soft with the normal import. The web build was checked in stage 1
and is sharp too, so the scalable import is used everywhere.

Two more kinds of use appear in stage 2 and were tried in a scratch project on 2026-11-16: a
`StyleBoxTexture` (the menu's card frame) stays sharp at its margins, and a `Button` icon works and is sharp
at its natural size.

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
- No text or numbers in the art. Faces that take a label (order slip, target sign, bag, balloon, sandbag,
  lift badge) stay blank, and the blank area is at least as large as in the PNG.
- Only plain shapes, paths and linear or radial gradients. No filters, masks, embedded images or text, which
  Godot's SVG renderer does not handle reliably.
- Nine-patch pieces (`table`, `plank`, `plank_shadow`, `gap_slot_empty`, `tray`, `card_frame`) keep their end
  caps inside the current margins, and their stretched or tiled middle carries no detail that would smear
  or break at a join (no knots or nails there; grain lines run straight through).
- Backgrounds use gradients and pale, soft, low-contrast distant shapes without the dark outline, so nothing
  competes with the play area (the look approved on the market background).
- Sprites the game tints have white and grey fills only, inside the usual dark outline: `balloon` (tinted
  per balloon) and `card_frame` (tinted by the carousel).
- World icons are free-standing objects on a transparent background, like the market's icon, not pictures
  on a tile.

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

### Pose

The fox faces right with its head turned a little towards the viewer. Its body is turned the same way: the
near arm hangs from the left half of the belly (the tail side), and the far arm shows a little at the chest.
In stage 1 the near shoulder was on the chest side, which made the body look turned away under the head.

Stage 2 moves the shoulders and retunes the poses that depend on them:

- `celebrate`: both raised paws stay visible, one on each side of the head, and neither covers the face.
- `throw`: the tomato does not overlap the tail in the wind-up, and on the release frame the empty paw is
  clearly in front of the chest.
- The paw position on the release frame changes, so the market's `_HAND_OFFSET` is measured again.

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

- The `throw` animation is six frames at 10 fps (0.6 s). It is an underhand lob, because the fox's head is
  large and an overarm swing would cross its face: frames 0–1 wind up, leaning back with the tomato held
  low in front of the belly and drawn back a little; frame 2 swings the paw down and through; frame 3
  releases, the paw forward and empty; frames 4–5 follow through. (The first draft of this spec had the
  tomato drawn back behind the fox. Stage 1 kept it in front of the belly, clear of the tail, and that
  stays.)
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

## Forest Bridge world

After a right answer the fox walks across the bridge and then celebrates until the next level loads, as it
does in the other worlds. Today it stands idle instead: the `walk_across` animation ends with a call that
plays `idle`, and that call lands after `WorldBase` has started `celebrate`. The fix is in the scene
(`forest_bridge.tscn`): `walk_across` no longer plays `idle` at its end. `WorldBase` already returns the fox
to `idle` when the next level loads.

## Stage 2 sprites

The 55 remaining PNGs are redrawn at their sizes, keeping what each one shows today:

- `forest_bridge/` (9): river background, bridge platform, plank, plank shadow, gap slot, target sign, the
  fox's home, and the Go and retry icons every world shares.
- `sky_balloons/` (6): sky background, cloud, balloon, basket, sandbag, lift badge.
- `picnic/` (7): meadow and blanket background, tray, guest plate, basket, strawberry, apple, banana.
- `memory/` (15): meadow background, card back, card front, twelve animal faces.
- `ui/` (18): menu background, card frame, the four remaining world icons, and the icons for arrow, close,
  easy, hard, home, play, shuffle, star, music on and off, effects on and off.

Each background keeps its landmarks where the PNG has them (horizon, river banks, blanket, clearing), so the
sprites placed on top still sit on them. The picnic's rule for when a friend is sad is unchanged.

## Stages

**Stage 1 (one pull request, merged as #43):** the import test, the fox sheets and shared frames in all five
worlds, the market sprites and the throw. Until stage 2, the other four worlds show the new fox on their old
backgrounds.

**Checkpoint (done 2026-11-16):** the user saw the market and the throw and played it. The style is approved
as it is; the two changes asked for are listed under Context.

**Stage 2 (one pull request):** the fox's pose and the forest celebration, then `forest_bridge/`,
`sky_balloons/`, `picnic/`, `memory/` and `ui/` redrawn to the same rules, with their generator scripts
removed. After it, no PNG is left under `assets/sprites/`.

## Testing

Existing tests move to the `.svg` paths, and `test_market.gd`'s throw timing constant is updated.

New tests:

- `test_market.gd`: `throw` has six frames, does not loop, and its frames come from
  `fox/character_throw.svg`.
- `test_market.gd`: after a wrong answer the flying tomato is hidden before the release frame and visible
  from it.
- `test_market.gd`: halfway through the flight the tomato is above the straight line from paw to table.
- `test_market.gd`: a level change during the wind-up or the flight leaves the tomato and splat hidden.
- `test_fox_frames.gd`: the shared frames have all six animations with the counts, speeds and loop settings
  above; every pose stays inside its cell; every registered world's fox uses `fox_frames.tres` at its old
  on-screen size. `test_picnic.gd` keeps its check that the friends share the fox's frames.
- `test_sprites.gd`: every SVG under `assets/sprites/` is imported as a scalable texture, and each redrawn
  sprite keeps its size. After stage 2: no PNG is left under `assets/sprites/`.
- `test_forest_bridge.gd` (stage 2): after a right answer and the walk, the fox's animation is `celebrate`.

Checks run before each pull request: the full GUT suite, `gdlint scripts/ scenes/` and
`gdformat --check scripts/ scenes/`.

Visual check: screenshots of every changed screen at 1280×720 and at double window size, and the web build
(`tools/export_web.sh`) opened in a browser.

## Docs

- `assets/sprites/*/README.md`: no longer placeholders; file names, sizes, and how the fox sheets are built.
- `CLAUDE.md`: nothing in "Adding a New World" names a sprite format, so no change is expected; confirm.
- `docs/kids-math-game-context.md`: the import test's outcome, the fox's new home and shared frames, the
  market throw, and the "Open ideas" entries for final art and the market throw frames removed.
