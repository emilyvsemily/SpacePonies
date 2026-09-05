// Standalone export of the exact Faceted Frontier rig geometry used in the
// SpacePonies Look Book (docs/index.html), to a .glb Godot can import
// natively — so the game and the Look Book preview share one real asset
// instead of two hand-maintained copies that can drift apart.
//
// Rig-building code below is copied verbatim from the Look Book's inline
// script (materials + rig hierarchy), with .name assigned on animatable
// nodes so the imported Godot scene has matching, referenceable node paths.

import * as THREE from 'three';
import { GLTFExporter } from 'three/examples/jsm/exporters/GLTFExporter.js';
import fs from 'fs';

// Minimal browser shim: this Three.js version's GLTFExporter converts its
// final Blob to an ArrayBuffer via window.FileReader, which Node lacks.
globalThis.window = globalThis;
globalThis.window.FileReader = class {
  readAsArrayBuffer(blob) {
    blob.arrayBuffer().then((buf) => {
      this.result = buf;
      if (this.onloadend) this.onloadend();
    });
  }
  readAsDataURL(blob) {
    blob.arrayBuffer().then((buf) => {
      const b64 = Buffer.from(buf).toString('base64');
      this.result = `data:${blob.type || 'application/octet-stream'};base64,${b64}`;
      if (this.onloadend) this.onloadend();
    });
  }
};

// Three.js's flatShading:true is a shader-level effect (computed via
// fragment-derivative flat normals) that doesn't survive glTF export at
// all — glTF just stores whatever vertex normals the geometry has. To keep
// the low-poly faceted look after import, bake real flat normals into the
// geometry itself: de-duplicate vertices per face (toNonIndexed) so each
// triangle owns its own vertices, then recompute normals — with no shared
// vertices between faces, per-vertex normals become per-face normals.
function flat(geometry) {
  var g = geometry.toNonIndexed();
  g.computeVertexNormals();
  return g;
}

function mat(hex, extra) {
  var o = Object.assign({ color: hex, flatShading: true, roughness: 0.65, metalness: 0.08 }, extra || {});
  return new THREE.MeshStandardMaterial(o);
}
var M = {
  bodyMain: mat(0x5b4b9e), bodyLight: mat(0x8879c9), bodyDark: mat(0x3f3372),
  headMain: mat(0x7669c0), headLight: mat(0x9c8fe0), headDark: mat(0x453873),
  maneLight: mat(0xa89be0), maneDark: mat(0x4a3d80),
  legLight: mat(0x4a3d80), legDark: mat(0x42356f),
  flameOrange: mat(0xff9a56, { emissive: 0xff9a56, emissiveIntensity: 0.5, roughness: 0.4 }),
  flameYellow: mat(0xffd166, { emissive: 0xffd166, emissiveIntensity: 0.6, roughness: 0.4 }),
  hornCrystal: mat(0xcdeeff, { emissive: 0x6fe3c4, emissiveIntensity: 0.5, roughness: 0.25, metalness: 0.1 }),
  hornTip: mat(0xeafcff, { emissive: 0xeafcff, emissiveIntensity: 0.8, roughness: 0.2 }),
  eyeWhite: mat(0xf3eefb, { roughness: 0.5 }),
  eyePupil: mat(0x241c40, { roughness: 0.6 })
};

var rig = new THREE.Group();
rig.name = 'PonyRig';

// torso (body)
var torso = new THREE.Mesh(flat(new THREE.IcosahedronGeometry(0.82, 0)), M.bodyMain);
torso.scale.set(1.28, 0.82, 1.05);
torso.name = 'TorsoMain';
rig.add(torso);
var torsoLight = new THREE.Mesh(flat(new THREE.IcosahedronGeometry(0.42, 0)), M.bodyLight);
torsoLight.position.set(0.42, 0.32, 0.42);
torsoLight.scale.set(1.1, 0.7, 0.7);
torsoLight.name = 'TorsoLight';
rig.add(torsoLight);
var torsoDark = new THREE.Mesh(flat(new THREE.IcosahedronGeometry(0.46, 0)), M.bodyDark);
torsoDark.position.set(-0.3, -0.28, -0.32);
torsoDark.scale.set(1, 0.7, 0.75);
torsoDark.name = 'TorsoDark';
rig.add(torsoDark);

// head group
var headGroup = new THREE.Group();
headGroup.position.set(0, 0.58, 0.92);
headGroup.name = 'HeadGroup';
rig.add(headGroup);

var headMesh = new THREE.Mesh(flat(new THREE.IcosahedronGeometry(0.4, 0)), M.headMain);
headMesh.name = 'HeadMain';
headGroup.add(headMesh);
var headLight = new THREE.Mesh(flat(new THREE.IcosahedronGeometry(0.2, 0)), M.headLight);
headLight.position.set(0.18, 0.14, 0.2);
headLight.name = 'HeadLight';
headGroup.add(headLight);
var headDark = new THREE.Mesh(flat(new THREE.IcosahedronGeometry(0.2, 0)), M.headDark);
headDark.position.set(-0.15, -0.1, -0.16);
headDark.name = 'HeadDark';
headGroup.add(headDark);

// ears
[[-0.16, 0.34, 0.06, M.headLight, 'EarLeft'], [0.02, 0.36, 0.08, M.headMain, 'EarRight']].forEach(function (e) {
  var ear = new THREE.Mesh(flat(new THREE.ConeGeometry(0.09, 0.26, 4)), e[3]);
  ear.position.set(e[0], e[1], e[2]);
  ear.rotation.z = e[0] < 0 ? 0.35 : -0.2;
  ear.name = e[4];
  headGroup.add(ear);
});

// antigrav horn
var hornGroup = new THREE.Group();
hornGroup.position.set(0.02, 0.42, 0.14);
hornGroup.rotation.x = -0.25;
hornGroup.name = 'HornGroup';
headGroup.add(hornGroup);
var horn = new THREE.Mesh(flat(new THREE.ConeGeometry(0.05, 0.5, 5)), M.hornCrystal);
horn.position.y = 0.25;
horn.name = 'Horn';
hornGroup.add(horn);
var hornTip = new THREE.Mesh(flat(new THREE.ConeGeometry(0.028, 0.2, 5)), M.hornTip);
hornTip.position.y = 0.42;
hornTip.name = 'HornTip';
hornGroup.add(hornTip);
var hornGlow = new THREE.Mesh(flat(new THREE.IcosahedronGeometry(0.075, 0)), new THREE.MeshBasicMaterial({ color: 0x6fe3c4, transparent: true, opacity: 0.55 }));
hornGlow.position.y = 0.52;
hornGlow.name = 'HornGlow';
hornGroup.add(hornGlow);

// eyes
[[-0.16, 0.03, 0.32, 'EyeLeft'], [0.14, 0.06, 0.33, 'EyeRight']].forEach(function (p) {
  var e = new THREE.Group();
  e.position.set(p[0], p[1], p[2]);
  e.name = p[3];
  var white = new THREE.Mesh(flat(new THREE.IcosahedronGeometry(0.068, 0)), M.eyeWhite);
  white.name = p[3] + 'White';
  e.add(white);
  var pupil = new THREE.Mesh(flat(new THREE.IcosahedronGeometry(0.034, 0)), M.eyePupil);
  pupil.position.z = 0.05;
  pupil.name = p[3] + 'Pupil';
  e.add(pupil);
  headGroup.add(e);
});

// mane (spikes riding the neck, wags with the head)
var maneSpecs = [
  [-0.05, 0.32, -0.12, 0.14, 0.34, M.maneLight],
  [-0.16, 0.28, -0.28, 0.13, 0.3, M.maneDark],
  [-0.28, 0.22, -0.42, 0.12, 0.26, M.maneLight],
  [-0.4, 0.14, -0.55, 0.1, 0.22, M.maneDark]
];
maneSpecs.forEach(function (s, i) {
  var spike = new THREE.Mesh(flat(new THREE.ConeGeometry(s[3], s[4], 4)), s[5]);
  spike.position.set(s[0], s[1], s[2]);
  spike.rotation.x = -0.3;
  spike.rotation.z = 0.25;
  spike.name = 'ManeSpike' + (i + 1);
  headGroup.add(spike);
});

// tail
var tail = new THREE.Group();
tail.position.set(-0.05, 0.15, -0.95);
tail.name = 'Tail';
rig.add(tail);
[[0, 0, 0, 0.16, M.bodyLight, 'TailSeg1'], [-0.14, -0.06, -0.16, 0.13, M.legLight, 'TailSeg2'], [0.1, -0.1, -0.22, 0.1, M.bodyDark, 'TailSeg3']].forEach(function (s) {
  var t = new THREE.Mesh(flat(new THREE.ConeGeometry(s[3], s[3] * 2.2, 4)), s[4]);
  t.position.set(s[0], s[1], s[2]);
  t.rotation.x = Math.PI * 0.42;
  t.name = s[5];
  tail.add(t);
});

// legs: mismatched rocket-boots — two-bone (hip -> upper -> knee -> lower/boot)
var legSpecs = [
  { x: -0.5, z: 0.3, len: 1.42, mat: M.legLight },
  { x: 0.12, z: -0.42, len: 1.95, mat: M.legDark },
  { x: 0.58, z: 0.26, len: 1.22, mat: M.legLight }
];
legSpecs.forEach(function (spec, i) {
  var n = i + 1;
  var upperLen = spec.len * 0.56;
  var lowerLen = spec.len * 0.44;

  var hip = new THREE.Group();
  hip.position.set(spec.x, -0.18, spec.z);
  hip.name = 'Leg' + n + 'Hip';
  rig.add(hip);

  var upper = new THREE.Mesh(flat(new THREE.CylinderGeometry(spec.len * 0.1, spec.len * 0.135, upperLen, 5)), spec.mat);
  upper.position.y = -upperLen / 2;
  upper.name = 'Leg' + n + 'Upper';
  hip.add(upper);

  var knee = new THREE.Group();
  knee.position.y = -upperLen;
  knee.name = 'Leg' + n + 'Knee';
  hip.add(knee);

  var kneeCap = new THREE.Mesh(flat(new THREE.IcosahedronGeometry(spec.len * 0.085, 0)), spec.mat);
  kneeCap.name = 'Leg' + n + 'KneeCap';
  knee.add(kneeCap);

  var lower = new THREE.Mesh(flat(new THREE.CylinderGeometry(spec.len * 0.08, spec.len * 0.11, lowerLen, 5)), spec.mat);
  lower.position.y = -lowerLen / 2;
  lower.name = 'Leg' + n + 'Lower';
  knee.add(lower);

  var flameGroup = new THREE.Group();
  flameGroup.position.y = -lowerLen;
  flameGroup.name = 'Leg' + n + 'FlameGroup';
  knee.add(flameGroup);
  var flameOuter = new THREE.Mesh(flat(new THREE.ConeGeometry(0.13, 0.34, 5)), M.flameOrange);
  flameOuter.rotation.x = Math.PI;
  flameOuter.position.y = -0.15;
  flameOuter.name = 'Leg' + n + 'FlameOuter';
  flameGroup.add(flameOuter);
  var flameInner = new THREE.Mesh(flat(new THREE.ConeGeometry(0.075, 0.2, 5)), M.flameYellow);
  flameInner.rotation.x = Math.PI;
  flameInner.position.y = -0.08;
  flameInner.name = 'Leg' + n + 'FlameInner';
  flameGroup.add(flameInner);
});

var exporter = new GLTFExporter();
exporter.parse(
  rig,
  function (result) {
    var text = JSON.stringify(result);
    fs.writeFileSync('pony_rig.gltf', text);
    console.log('Wrote pony_rig.gltf,', text.length, 'bytes');
  },
  function (err) {
    console.error('Export error:', err);
    process.exit(1);
  },
  {}
);
