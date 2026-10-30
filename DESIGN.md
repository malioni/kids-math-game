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
| `MarketMechanic` | Multiplication | Fill the fox's order with equal-sized bags from crates that never run out |
| `SharingMechanic` | Division | Fill the fox's plate so the baskets can share the same amount with every friend |

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

The fox shops at a market stall and holds up an order slip: an amount and a picture of each item
it wants (e.g. 12 tomatoes). Each ordered item has a crate of equal-sized bags, each bag showing how
many it holds (e.g. 4 tomatoes). The child drags or taps bags onto the table, one row per item, and presses
Go. The number of items on the table is never shown — the child works out bags × bag size.

- **Teaches:** Multiplication as equal groups (and finding the missing factor)
- **Mechanic:** `MarketMechanic`
- **Bag sizes:** tomatoes 2–4, potatoes 5–7, carrots 8–10 (no bags of 1, so it is never just counting); the answer takes 2–10 bags, so the biggest order is 10 × 10
- **Levels:** 20 levels. Levels 1–5 order tomatoes; 6–10 add potatoes; 11–20 add carrots. Bag counts start low again each time a new item joins, then rise to 10 by level 20; puzzles generated from per-level ranges
- **Win condition:** Every item on the slip matched exactly — the fox cheers
- **Fail state:** Any item short or over — the fox throws a tomato at the table; gentle retry with the same order, no penalty

### World 4: The Picnic

The fox has a picnic with friends, each at their own plate. Each fruit has a basket showing only
how many it holds (e.g. 12 strawberries). The child drags or taps fruit onto the fox's plate, one
row per fruit, and presses Go. The baskets then deal the fox's amount to every friend in turn. The
fox's amount is never shown — the child works out total ÷ plates.

- **Teaches:** Division as fair sharing
- **Mechanic:** `SharingMechanic`
- **Plates and shares:** 2–5 plates (the fox's included); every plate should get 2–10 of each fruit, so the biggest basket is 50
- **Levels:** 20 levels. Levels 1–5 share strawberries; 6–10 add apples; 11–20 add bananas. Plates and shares start low again each time a new fruit joins, then rise to 5 plates of up to 10 by level 20; puzzles generated from per-level ranges
- **Win condition:** Every plate gets the same of every fruit and the baskets are empty — everyone cheers
- **Fail state:** Too much and the last friends come up short (they look sad); too little and fruit is left in the basket. The fox is sad; gentle retry with the same baskets, no penalty

### Planned Future Worlds

| World | Theme | Skill focus |
|-------|-------|-------------|
| World 5: The Garden | Plant seeds in rows | Addition, grouping |
| World 6: The Kitchen | Combine ingredients by quantity | Addition and subtraction |

## Progression System

- Tracks per-skill mastery silently using success rate per mechanic type
- No stars, scores, or difficulty labels visible to the child
- Narrative completion is the only visible reward (creature reaches home)
- A level badge (world icon + level number) sits in the top-left corner; tapping it opens a picker to jump to any level of any world. After the last level of the difficulty, a star screen offers a restart from the difficulty's first level or another world
- **Difficulty:** every world's levels split into Easy (1–10) and Hard (11–20) (`data/levels/difficulty.json`). A grown-up picks it with two icon buttons in the picker (a hill and a mountain); it applies to every world, and progress is kept separately per difficulty. The child-facing badge never names it, but counts to the end of it: 4/10 on easy, 14/20 on hard
- **Shuffle:** a shuffle tab in the picker plays a random world after every win, always that world's next unplayed level of the current difficulty. Shuffle keeps its own place in each world, and the badge shows the place in the whole shuffle (e.g. 7/40 with four worlds); when every world's levels are played the star screen shows and restart starts a fresh shuffle. Picking a level leaves shuffle
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
