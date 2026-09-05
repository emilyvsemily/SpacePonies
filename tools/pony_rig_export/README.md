# Pony rig export (Look Book → Godot)

The Faceted Frontier pony rig is authored once, in the Three.js Look Book
prototype (`docs/index.html`). This script re-derives that exact geometry —
copied from the Look Book's inline rig-building code, kept in sync by hand
whenever that code changes — and exports it to `assets/pony_rig/pony_rig.gltf`,
which Godot imports natively. This is the real interop path: the game and
the Look Book preview share one asset instead of two hand-maintained copies
that drift apart.

## Why this exists

Three.js's `flatShading: true` is a shader-level effect that doesn't survive
glTF export — glTF only stores whatever normals the geometry has. This
script bakes real flat normals into every mesh (`toNonIndexed()` +
`computeVertexNormals()`) before export, so the low-poly faceted look
survives the round-trip into Godot.

Every joint/attachment node (`Leg1Hip`, `Leg1Knee`, `HeadGroup`, `HornGroup`,
`Tail`, etc.) is explicitly named to match what `pony_controller.gd`
references, so re-running this export and re-importing in Godot doesn't
require rewiring the animation code — as long as names aren't renamed here.

## Usage

```bash
cd tools/pony_rig_export
npm install
node export.mjs
cp pony_rig.gltf ../../assets/pony_rig/pony_rig.gltf
```

Then let Godot re-import (open the editor, or run
`godot --headless --editor --quit-after 5`).

## When to re-run this

Whenever the rig-building code in `docs/index.html`'s inline `<script>`
changes (new geometry, new joints, new colors) and you want the Godot game
to match. Copy the updated rig-building code from `docs/index.html` into
`export.mjs` (keeping the `.name` assignments and the `flat()` wrapping),
then re-run.
