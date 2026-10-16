# Kids Math Game — Design Document

## Vision

A tablet game for children aged 4–7 where mathematical concepts are the physics of the world — not a quiz bolted onto a game. The child never sees a math problem; they live in a world where quantity, pattern, and logic have natural consequences.

## Target Audience

- **Primary player:** Children aged 4–7 (core mechanic complexity scales with age)
- **Co-op mode:** Parent and child playing together (optional, not required)
- **Platform:** Tablet-first (Android and iOS), landscape orientation

## Core Design Philosophy

**Math as world physics, not a gating mechanic.**

- Quantity has consequence: planks that don't add up to the bridge's length make it collapse
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
| Multiplication (equal groups) | Counting in equal groups, groups × group size |
| Pattern recognition | Repeating sequences, odd-one-out |
| Spatial reasoning | Shapes, positions, rotations, sequences |

## Mechanic Library

Reusable building blocks that any world can compose. Each mechanic is a self-contained Godot scene that emits signals (`correct`, `incorrect`). Worlds listen to signals — they do not modify mechanic internals.

| Mechanic | Primary Skill | Example |
|----------|--------------|---------|
| `PlacementMechanic` | Addition, number composition | Lay numbered planks end to end until they add up to the bridge length |
| `CountingMechanic` | Cardinality | Tap to count a group of objects |
| `SortingMechanic` | Comparison | Order objects by size or quantity |
| `MatchingMechanic` | Equivalence | Match two groups of equal size |
| `BalanceMechanic` | Addition/subtraction | Balance a scale with groups of items |
| `BalloonPopMechanic` | Subtraction | Pop numbered balloons until their total lift equals the basket's weight |
| `MarketMechanic` | Multiplication | Fill a customer's order with equal-sized bags from crates that never run out |

## World Plan

### World 1: The Forest Bridge (v0.1 target)

A small creature needs to cross a river to get home before dark. A gap blocks the path, and a sign shows how long it is. The child picks numbered planks, each drawn to scale, that add up to exactly that length.

- **Teaches:** Addition, number composition (which numbers make a total)
- **Mechanic:** `PlacementMechanic`
- **Levels:** 20 levels, bridge length rising from under 5 to about 30 at level 10 and about 50 at level 20; each puzzle is generated from per-level ranges, so replays differ
- **Win condition:** Creature reaches home; warm celebratory animation
- **Fail state:** Bridge collapses, planks float away — gentle retry prompt, no penalty

### World 2: Sky Balloons

The fox floats in a basket under a bunch of numbered balloons (bigger number = bigger balloon). A
sandbag on the basket shows its weight; a badge where the strings meet shows the balloons' total
lift. The lift starts higher than the weight, so the basket keeps rising (clouds stream past,
faster the more extra lift there is). The child pops balloons to bring the lift down to exactly the
weight. Both numbers are on screen, so the child works out total − weight and pops that much.

- **Teaches:** Subtraction (taking away the difference), number composition
- **Mechanic:** `BalloonPopMechanic`
- **Levels:** 20 levels, total lift under 10 at level 1 rising to about 35 at level 10 and about 70 at level 20; puzzles generated from per-level ranges
- **Win condition:** Lift equals weight — the basket levels out, the fox celebrates
- **Fail state:** Lift below weight — the basket falls; gentle retry with the same balloons, no penalty

### World 3: The Market

A customer at a market stall holds up an order slip: an amount and a picture of each item they
want (e.g. 12 tomatoes). Each ordered item has a crate of equal-sized bags, each bag showing how
many it holds (e.g. 4 tomatoes). The child drags bags onto the table, one row per item, and presses
Go. The number of items on the table is never shown — the child works out bags × bag size.

- **Teaches:** Multiplication as equal groups (and finding the missing factor)
- **Mechanic:** `MarketMechanic`
- **Bag sizes:** tomatoes 1–3, potatoes 4–6, carrots 7–10; the answer takes 2–10 bags, so the biggest order is 10 × 10
- **Levels:** 20 levels. Levels 1–5 order tomatoes; 6–10 add potatoes; 11–20 add carrots. Bag counts start low again each time a new item joins, then rise to 10 by level 20; puzzles generated from per-level ranges
- **Win condition:** Every item on the slip matched exactly — the customer cheers
- **Fail state:** Any item short or over — the customer throws a tomato at the table; gentle retry with the same order, no penalty

### Planned Future Worlds

| World | Theme | Skill focus |
|-------|-------|-------------|
| World 4: The Garden | Plant seeds in rows | Addition, grouping |
| World 5: The Kitchen | Combine ingredients by quantity | Addition and subtraction |

## Progression System

- Tracks per-skill mastery silently using success rate per mechanic type
- No stars, scores, or difficulty labels visible to the child
- Narrative completion is the only visible reward (creature reaches home)
- A level badge (world icon + level number) sits in the top-left corner; tapping it opens a picker to jump to any level of any world. After a world's last level, a star screen offers "restart from 1" or another world
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
