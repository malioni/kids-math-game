# Kids Math Game — Design Document

## Vision

A tablet game for children aged 4–7 where mathematical concepts are the physics of the world — not a quiz bolted onto a game. The child never sees a math problem; they live in a world where quantity, pattern, and logic have natural consequences.

## Target Audience

- **Primary player:** Children aged 4–7 (core mechanic complexity scales with age)
- **Co-op mode:** Parent and child playing together (optional, not required)
- **Platform:** Tablet-first (Android and iOS), landscape orientation

## Core Design Philosophy

**Math as world physics, not a gating mechanic.**

- Quantity has consequence: placing the wrong number of planks collapses a bridge
- No quiz popups — mathematical concepts emerge through play, not testing
- Short sessions: 5–10 minutes per sitting
- Immediate visual and audio feedback for all interactions
- No reading required — icons, animation, and sound carry all meaning
- Difficulty adjusts silently — the child never sees an Easy/Hard label

## Skill Areas

| Skill | Description |
|-------|-------------|
| Number sense & counting | One-to-one correspondence, cardinality |
| Quantity comparison | More, less, equal |
| Addition & subtraction | Combining and removing groups |
| Pattern recognition | Repeating sequences, odd-one-out |
| Spatial reasoning | Shapes, positions, rotations, sequences |

## Mechanic Library

Reusable building blocks that any world can compose. Each mechanic is a self-contained Godot scene that emits signals (`correct`, `incorrect`). Worlds listen to signals — they do not modify mechanic internals.

| Mechanic | Primary Skill | Example |
|----------|--------------|---------|
| `PlacementMechanic` | Counting, one-to-one | Place N planks across N gaps |
| `CountingMechanic` | Cardinality | Tap to count a group of objects |
| `SortingMechanic` | Comparison | Order objects by size or quantity |
| `MatchingMechanic` | Equivalence | Match two groups of equal size |
| `BalanceMechanic` | Addition/subtraction | Balance a scale with groups of items |

## World Plan

### World 1: The Forest Bridge (v0.1 target)

A small creature needs to cross a river to get home before dark. Gaps of varying widths block the path. The child places wooden planks to fill each gap exactly.

- **Teaches:** Counting, one-to-one correspondence
- **Mechanic:** `PlacementMechanic`
- **Levels:** 10 levels, gap count increases from 1 to 5 planks
- **Win condition:** Creature reaches home; warm celebratory animation
- **Fail state:** Bridge collapses, planks float away — gentle retry prompt, no penalty

### Planned Future Worlds

| World | Theme | Skill focus |
|-------|-------|-------------|
| World 2: The Garden | Plant seeds in rows | Addition, grouping |
| World 3: The Market | Trade items in equal groups | Multiplication intuition |
| World 4: The Kitchen | Combine ingredients by quantity | Addition and subtraction |

## Progression System

- Tracks per-skill mastery silently using success rate per mechanic type
- No stars, scores, or difficulty labels visible to the child
- Narrative completion is the only visible reward (creature reaches home)
- **Parent view:** Session summaries accessible via a separate parent-only screen (PIN-gated)
- Adaptive branching: if a child struggles at N=4, the system repeats N=3 variants before retrying

## Art Direction

- 2D, hand-drawn style (AI-assisted asset generation acceptable)
- Warm, earthy color palette — greens, browns, soft yellows
- Minimal on-screen text; visual cues and animation carry meaning
- Main character: a small expressive animal (fox, rabbit, or similar — TBD)
- Audio: gentle ambient nature sounds; soft celebratory sound on correct actions

## Technical Stack

| Component | Choice |
|-----------|--------|
| Engine | Godot 4 (Mobile renderer) |
| Language | GDScript |
| Testing | GUT (Godot Unit Testing) |
| Level data | JSON files in `data/levels/` |
| Target platforms | Android, iOS |
| Viewport | 1280×720 landscape |

## Out of Scope

- Multiplayer or network features
- Image uploads or camera access
- In-app purchases or ads
- Accounts or cloud save (local save only for now)
- 3D scenes
