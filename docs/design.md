# SpacePonies — Design Doc

A "friendslop" party game: up to 4 players race wacky, space-adapted ponies, and breed ponies in a stable between races to chase better (or weirder) offspring.

## What is a Space Pony?

A pony that's evolved/mutated to survive in space. "Pony" is a loose starting point and vibe — mane, tail, general critter-ness — not a strict body-plan constraint. Breeding genes (leg count/type, tail type, body shape, etc.) are free to warp a pony well away from a standard horse silhouette over generations.

**Tone:** wholesome-absurd (Goat Simulator / Untitled Goose Game energy) — goofy, surreal, "shouldn't work but does," never mean-spirited or gross-out.

**Movement:** should read as chaotic/janky by design (loose, wobbly, exaggerated) rather than polished, but the vibe stays charming, not crude.

**Visual style:** not yet decided (low-poly, claymation-feel, flat cartoon, or something else) — being explored as its own parallel track. See the Visual Design Track below.

## Core Loop

Race → earn currency/unlocks → breed ponies in your stable to chase better stats or rarer/weirder trait combos → race again with your new pony.

## Visual Design Track (parallel workstream)

Visual style is intentionally undecided and being explored independently of engineering work, since the pony body plan itself is genetically variable. A design-focused pass proposes style directions (concept mockups) against the pillars above; engineering proceeds with gray-box/placeholder art the whole time and reskins once a direction is picked (see Milestone Roadmap, M5).

## Animation Approach

Because breeding can change a pony's body plan (leg count, tail type, etc.), hand-authoring a full keyframed walk-cycle per possible body variant isn't practical. Movement leans on **physics-driven/procedural locomotion** — the vertical-slice controller (`scripts/pony_controller.gd`) applies velocity via `move_and_slide()` for actual locomotion, then layers a procedural sine-wave wobble/bob onto the visual mesh only, scaled by speed. This produces the janky look for free and adapts to any leg configuration without new animation work.

A small set of hand-authored pose/reaction animations layers on top for non-locomotion moments:
- **Race:** idle at starting line, start/launch reaction, boost/ability-use effect, win celebration, loss/sad pose
- **Stable/breeding screen:** idle/breathing loop, eating/grazing variant, sleep idle, a breeding "combine" moment
- **Crash/stumble:** likely falls out of physics directly rather than being hand-animated

## Breeding / Genetics Framework

Each pony has genes across a few categories, each pony carrying two alleles per gene (dominant/recessive-style inheritance when two parents breed):

- **Locomotion genes:** leg count/type (hooves, tentacles, propeller-feet, rocket-boots), tail type (rocket tail, whip tail, propeller tail)
- **Body genes:** size, coat pattern/color, mane style (flowing "space-mane," antenna-mane)
- **Space-adaptation genes:** extra eyes, wings, antigrav horn, vacuum-adapted gills (played for laughs, not realism)
- **Ability genes:** a single "special move" per pony — dash, gravity-flip, fart-boost, teleport-hiccup, magnet-hooves, etc.

Plus a small **numeric stat block** (Speed, Acceleration, Handling, Stamina/Boost, and a "Wackiness/Chaos" stat that scales how erratic the pony's movement/animation is) that blends from both parents with some random variance.

Breeding two ponies punnett-squares the discrete genes for the foal, blends+varies the stat block, and rolls a small **mutation chance** per gene so genuinely new/rare traits can appear unprompted — the main "surprise" driver for wanting to keep breeding.

This framework is a starting point; the actual trait list is content to expand over time.

## Technical Architecture

- **Engine/language:** Godot 4.x (4.7), GDScript to start.
- **Repo layout:** Godot project at repo root (`project.godot`), with `scenes/`, `scripts/`, `assets/`, `addons/`, `docs/`.
- **Multiplayer:** Godot's high-level multiplayer API (`ENetMultiplayerPeer`), host-as-server for the MVP; NAT traversal/relay is deferred to the M3 milestone.

## Milestone Roadmap

1. **M0 — Project scaffold** *(done)*
2. **M1 — Vertical slice, gray-box (current target):** one placeholder pony, one dumb test track, physics-driven janky movement, single-player, playable start-to-finish lap.
3. **M2 — Core race loop:** 4 ponies, full race with placements, one wacky ability wired in.
4. **M3 — Online multiplayer:** up to 4 real players racing together online.
5. **M4 — Breeding & Stable:** Mendelian trait system, stable UI, pony generation from two parents.
6. **M5 — Content & polish:** reskin with chosen art style, expand trait library, more tracks, animation/jank polish.
