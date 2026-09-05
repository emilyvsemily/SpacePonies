class_name PonyRigBuilder
extends RefCounted

## Procedurally builds a pony's visual rig from a PonyGenome.
##
## Ported from the Look Book's rear-view lineup section (docs/index.html),
## which replaced the earlier round-blob pony with real equine anatomy:
## barrel/chest/belly/croup plus two haunch domes, a neck built as blobs
## along a quadratic arc with a mane crest riding its outside, and a head
## with a jaw and a long tapered muzzle. Those last three are what keep a
## rounded pony reading as a pony instead of a pig.
##
## The three body plans below differ only in proportion — mass
## distribution, neck length/arch, leg length, stance, tail carriage. The
## builder itself doesn't know which one it's building. Colors come from
## the genome (coat_hue/mane_hue), not the plan, so randomization still
## drives appearance.

## Proportion blocks, ported from the Look Book's SPECS. Lane position and
## the hardcoded per-pony colors are dropped — placement is the race's job
## and color is the genome's.
const BODY_PLANS := {
	"ballast-cob": {
		"barrel_w": 0.66, "barrel_h": 0.62, "barrel_l": 1.05,
		"chest_w": 0.70, "chest_h": 0.62, "chest_d": 0.52, "chest_y": -0.02, "chest_z": 0.70,
		"belly_w": 0.62, "belly_h": 0.46, "belly_d": 0.86, "belly_y": -0.20, "belly_z": -0.02,
		"croup_w": 0.60, "croup_h": 0.42, "croup_d": 0.50, "croup_y": 0.22, "croup_z": -0.62,
		"haunch_w": 0.44, "haunch_h": 0.48, "haunch_d": 0.46, "haunch_x": 0.40, "haunch_y": 0.00, "haunch_z": -0.70,
		"neck0_y": 0.40, "neck0_z": 0.72, "neck_cy": 0.86, "neck_cz": 0.94, "neck1_y": 0.70, "neck1_z": 1.30,
		"neck_r0": 0.34, "neck_r1": 0.22, "neck_segs": 7, "neck_wide": 1.00,
		"mane_off": 0.72, "mane_r": 0.80, "forelock_r": 0.13,
		"head_pitch": -0.48,
		"skull_w": 0.25, "skull_h": 0.27, "skull_d": 0.29,
		"jaw_w": 0.23, "jaw_h": 0.17, "jaw_d": 0.22, "jaw_y": -0.13, "jaw_z": 0.12,
		"muzzle_len": 0.44, "muzzle_r0": 0.20, "muzzle_r1": 0.155, "muzzle_y": -0.07,
		"ear_r": 0.075, "ear_h": 0.20, "ear_x": 0.14, "ear_y": 0.22, "ear_z": -0.06, "ear_tilt": 0.30,
		"eye_r": 0.062, "eye_x": 0.21, "eye_y": 0.05, "eye_z": 0.10,
		"leg_len": 1.10, "leg_r_top": 0.155, "leg_r_mid": 0.115, "leg_r_ankle": 0.095,
		"hoof_r": 0.14, "hoof_h": 0.13,
		"stance_xf": 0.50, "stance_xh": 0.56, "stance_zf": 0.72, "stance_zh": -0.70,
		"hip_y": -0.14, "splay_f": 0.06, "splay_h": 0.11,
		"tail_y": 0.36, "tail_z": -1.00, "tail_carry": 0.30, "tail_len": 1.05,
		"tail_r0": 0.21, "tail_r1": 0.10, "tail_wide": 1.05, "tail_droop": 0.075,
		"tail_plume": true, "tail_sway": 0.11
	},
	"slipstream-colt": {
		"barrel_w": 0.40, "barrel_h": 0.46, "barrel_l": 1.12,
		"chest_w": 0.44, "chest_h": 0.56, "chest_d": 0.52, "chest_y": 0.02, "chest_z": 0.76,
		"belly_w": 0.34, "belly_h": 0.28, "belly_d": 0.60, "belly_y": -0.20, "belly_z": -0.14,
		"croup_w": 0.36, "croup_h": 0.32, "croup_d": 0.46, "croup_y": 0.28, "croup_z": -0.70,
		"haunch_w": 0.27, "haunch_h": 0.42, "haunch_d": 0.44, "haunch_x": 0.21, "haunch_y": 0.08, "haunch_z": -0.76,
		"neck0_y": 0.36, "neck0_z": 0.84, "neck_cy": 0.70, "neck_cz": 1.32, "neck1_y": 0.76, "neck1_z": 1.72,
		"neck_r0": 0.24, "neck_r1": 0.145, "neck_segs": 8, "neck_wide": 0.92,
		"mane_off": 0.34, "mane_r": 0.50, "forelock_r": 0.07,
		"head_pitch": -0.12,
		"skull_w": 0.185, "skull_h": 0.205, "skull_d": 0.235,
		"jaw_w": 0.17, "jaw_h": 0.13, "jaw_d": 0.19, "jaw_y": -0.11, "jaw_z": 0.10,
		"muzzle_len": 0.52, "muzzle_r0": 0.148, "muzzle_r1": 0.10, "muzzle_y": -0.055,
		"ear_r": 0.055, "ear_h": 0.19, "ear_x": 0.10, "ear_y": 0.17, "ear_z": -0.05, "ear_tilt": 0.24,
		"eye_r": 0.048, "eye_x": 0.16, "eye_y": 0.04, "eye_z": 0.08,
		"leg_len": 1.62, "leg_r_top": 0.115, "leg_r_mid": 0.082, "leg_r_ankle": 0.062,
		"hoof_r": 0.095, "hoof_h": 0.10,
		"stance_xf": 0.30, "stance_xh": 0.30, "stance_zf": 0.80, "stance_zh": -0.82,
		"hip_y": -0.10, "splay_f": -0.01, "splay_h": 0.00,
		"tail_y": 0.56, "tail_z": -1.06, "tail_carry": 2.28, "tail_len": 1.62,
		"tail_r0": 0.14, "tail_r1": 0.055, "tail_wide": 0.90, "tail_droop": 0.012,
		"tail_plume": false, "tail_sway": 0.16
	},
	"aurora-willow": {
		"barrel_w": 0.44, "barrel_h": 0.50, "barrel_l": 0.90,
		"chest_w": 0.46, "chest_h": 0.54, "chest_d": 0.46, "chest_y": 0.00, "chest_z": 0.60,
		"belly_w": 0.38, "belly_h": 0.34, "belly_d": 0.68, "belly_y": -0.18, "belly_z": -0.06,
		"croup_w": 0.38, "croup_h": 0.34, "croup_d": 0.42, "croup_y": 0.26, "croup_z": -0.56,
		"haunch_w": 0.32, "haunch_h": 0.44, "haunch_d": 0.40, "haunch_x": 0.26, "haunch_y": 0.04, "haunch_z": -0.62,
		"neck0_y": 0.42, "neck0_z": 0.62, "neck_cy": 1.30, "neck_cz": 1.16, "neck1_y": 1.58, "neck1_z": 0.96,
		"neck_r0": 0.26, "neck_r1": 0.135, "neck_segs": 10, "neck_wide": 0.95,
		"mane_off": 1.05, "mane_r": 0.62, "forelock_r": 0.08,
		"head_pitch": -0.95,
		"skull_w": 0.175, "skull_h": 0.20, "skull_d": 0.22,
		"jaw_w": 0.16, "jaw_h": 0.13, "jaw_d": 0.18, "jaw_y": -0.10, "jaw_z": 0.09,
		"muzzle_len": 0.46, "muzzle_r0": 0.138, "muzzle_r1": 0.098, "muzzle_y": -0.05,
		"ear_r": 0.05, "ear_h": 0.22, "ear_x": 0.095, "ear_y": 0.17, "ear_z": -0.05, "ear_tilt": 0.20,
		"eye_r": 0.046, "eye_x": 0.15, "eye_y": 0.035, "eye_z": 0.075,
		"leg_len": 1.75, "leg_r_top": 0.105, "leg_r_mid": 0.075, "leg_r_ankle": 0.055,
		"hoof_r": 0.088, "hoof_h": 0.095,
		"stance_xf": 0.26, "stance_xh": 0.28, "stance_zf": 0.66, "stance_zh": -0.64,
		"hip_y": -0.10, "splay_f": -0.035, "splay_h": -0.03,
		"tail_y": 0.42, "tail_z": -0.86, "tail_carry": 0.62, "tail_len": 1.78,
		"tail_r0": 0.115, "tail_r1": 0.042, "tail_wide": 0.85, "tail_droop": 0.055,
		"tail_plume": false, "tail_sway": 0.20
	}
}

## Leg placement for any count from 3 up. Legs are laid out in rows walking
## front-to-back along the barrel, each row a left/right pair (an odd count
## leaves one row with a single centered leg). 4 legs lands on the normal
## quadruped stance; beyond that the extra pairs fill in along the middle
## and the phase offsets form a travelling wave, so a 7-legged pony ripples
## like a centipede instead of stomping in unison.
static func _leg_slots(count: int, plan: Dictionary) -> Array:
	var rows: int = int(ceil(count / 2.0))
	var slots: Array = []
	var placed := 0
	for row in rows:
		var t: float = 0.0 if rows <= 1 else float(row) / float(rows - 1)
		var z: float = lerpf(plan.stance_zf, plan.stance_zh, t)
		var x_spread: float = lerpf(plan.stance_xf, plan.stance_xh, t)
		var splay: float = lerpf(plan.splay_f, plan.splay_h, t)
		var remaining := count - placed
		# Travelling wave down the body; left/right in a row are opposed so
		# each pair still reads as a diagonal step.
		var row_phase: float = float(row) * PI * 0.7
		if remaining == 1:
			slots.append({"x": 0.0, "z": z, "splay": 0.0, "phase": row_phase})
			placed += 1
		else:
			slots.append({"x": -x_spread, "z": z, "splay": -splay, "phase": row_phase})
			slots.append({"x": x_spread, "z": z, "splay": splay, "phase": row_phase + PI})
			placed += 2
		if placed >= count:
			break
	return slots

static var _shared_blob_mesh: SphereMesh

## Returns { leg_hips, leg_knees, leg_phase_offsets, head, tail,
## head_pitch, tail_sway, horn_glow } — the controller animates the legs
## and sways head/tail from these.
static func build(visual: Node3D, genome: PonyGenome, capsule_half_height: float = 2.1) -> Dictionary:
	# Only remove a previous rig by name — Visual also hosts the Exhaust and
	# HornTrail particle emitters as fixed siblings (see Pony.tscn), which
	# must survive a rebuild, not get swept up in it.
	var old_rig := visual.get_node_or_null("Rig")
	if old_rig != null:
		visual.remove_child(old_rig)
		old_rig.queue_free()

	var plan: Dictionary = BODY_PLANS.get(genome.body_plan, BODY_PLANS["ballast-cob"])

	# Exaggeration genes stretch the plan's proportions before anything is
	# built from them.
	var leg_len: float = plan.leg_len * genome.leg_scale
	var girth: float = genome.girth_scale
	# Scaling the neck arc's end and control points relative to its base
	# lengthens the neck without detaching it from the shoulder.
	var neck1_y: float = plan.neck0_y + (plan.neck1_y - plan.neck0_y) * genome.neck_scale
	var neck1_z: float = plan.neck0_z + (plan.neck1_z - plan.neck0_z) * genome.neck_scale
	var neck_cy: float = plan.neck0_y + (plan.neck_cy - plan.neck0_y) * genome.neck_scale
	var neck_cz: float = plan.neck0_z + (plan.neck_cz - plan.neck0_z) * genome.neck_scale

	var rig := Node3D.new()
	rig.name = "Rig"
	# Geometry is authored head-toward-+Z; this game treats -Z as forward.
	rig.rotation.y = PI
	# Lift so the hooves land on the collision capsule's bottom, using the
	# gene-scaled leg length — otherwise a stilt-legged pony sinks and a
	# stumpy one floats.
	var visual_scale: float = 1.5 * genome.size
	rig.position.y = -capsule_half_height / visual_scale + leg_len - plan.hip_y
	visual.add_child(rig)

	var body := Node3D.new()
	body.name = "Body"
	rig.add_child(body)

	# One coat tone per pony (plus a slightly darker one for underside/lower
	# leg shading), genome-driven rather than per-plan.
	var coat := _mat(PonyGenome.hsl_to_color(genome.coat_hue, 0.45, 0.58))
	var coat_dark := _mat(PonyGenome.hsl_to_color(genome.coat_hue, 0.45, 0.44))
	var mane_mat := _mat(PonyGenome.hsl_to_color(genome.mane_hue, 0.5, 0.62))
	var hoof_mat := _mat(Color(0.169, 0.125, 0.22))
	var eye_white := _mat(Color(0.953, 0.933, 0.984))
	var eye_pupil := _mat(Color(0.141, 0.109, 0.251))
	var flame_orange := _mat(Color(1.0, 0.604, 0.337), Color(1.0, 0.604, 0.337), 0.5)
	var flame_yellow := _mat(Color(1.0, 0.82, 0.4), Color(1.0, 0.82, 0.4), 0.6)

	# torso: barrel, chest, belly, croup, then the two haunch domes that ARE
	# the rear silhouette
	body.add_child(_blob(coat, plan.barrel_w * girth, plan.barrel_h * girth, plan.barrel_l, 0.0, 0.0, 0.0))
	body.add_child(_blob(coat, plan.chest_w * girth, plan.chest_h * girth, plan.chest_d, 0.0, plan.chest_y, plan.chest_z))
	body.add_child(_blob(coat_dark, plan.belly_w * girth, plan.belly_h * girth, plan.belly_d, 0.0, plan.belly_y, plan.belly_z))
	body.add_child(_blob(coat, plan.croup_w * girth, plan.croup_h * girth, plan.croup_d, 0.0, plan.croup_y, plan.croup_z))
	body.add_child(_blob(coat, plan.haunch_w * girth, plan.haunch_h * girth, plan.haunch_d, -plan.haunch_x * girth, plan.haunch_y, plan.haunch_z))
	body.add_child(_blob(coat, plan.haunch_w * girth, plan.haunch_h * girth, plan.haunch_d, plan.haunch_x * girth, plan.haunch_y, plan.haunch_z))

	if genome.coat_pattern == "spotted":
		var spot_mat := _mat(PonyGenome.hsl_to_color(genome.mane_hue, 0.5, 0.66))
		for p in [Vector3(0.34, 0.12, 0.1), Vector3(-0.3, 0.2, -0.4), Vector3(0.26, -0.1, -0.55)]:
			var spot_r: float = plan.barrel_w * 0.32
			body.add_child(_blob(spot_mat, spot_r, spot_r * 0.8, spot_r, p.x, p.y, p.z))

	# neck: ellipsoids along a quadratic arc, with a mane crest riding the
	# outside of the curve so it stays visible from astern
	var neck_segs: int = plan.neck_segs
	for i in neck_segs:
		var t := float(i) / float(neck_segs - 1)
		var p := _qbez(plan.neck0_y, plan.neck0_z, neck_cy, neck_cz, neck1_y, neck1_z, t)
		var r: float = plan.neck_r0 + (plan.neck_r1 - plan.neck_r0) * t
		body.add_child(_blob(coat, r * plan.neck_wide, r * 1.06, r, 0.0, p.x, p.y))

	if genome.mane_style == "space-mane":
		var mane_steps := neck_segs * 4
		for i in mane_steps + 1:
			var t := float(i) / float(mane_steps)
			var p := _qbez(plan.neck0_y, plan.neck0_z, neck_cy, neck_cz, neck1_y, neck1_z, t)
			var r: float = plan.neck_r0 + (plan.neck_r1 - plan.neck_r0) * t
			var mr: float = r * plan.mane_r
			body.add_child(_blob(mane_mat, mr * 0.8, mr * 1.1, mr,
				0.0, p.x + r * plan.mane_off * 0.52, p.y - r * plan.mane_off * 0.88))
	else:
		# antenna-mane: a pair of stalks with glowing beads instead of a crest
		var p_top := _qbez(plan.neck0_y, plan.neck0_z, neck_cy, neck_cz, neck1_y, neck1_z, 0.75)
		for side in [-1.0, 1.0]:
			var stalk := _cylinder(plan.neck_r1 * 0.16, plan.neck_r1 * 0.24, plan.neck_r0 * 1.6, mane_mat, 5)
			stalk.position = Vector3(side * plan.neck_r0 * 0.4, p_top.x + plan.neck_r0 * 0.9, p_top.y - plan.neck_r0 * 0.3)
			stalk.rotation.x = -0.35
			body.add_child(stalk)
			var bead_r: float = plan.neck_r1 * 0.5
			body.add_child(_blob(mane_mat, bead_r, bead_r, bead_r,
				side * plan.neck_r0 * 0.4, p_top.x + plan.neck_r0 * 1.7, p_top.y - plan.neck_r0 * 0.7))

	# head — the anti-pig kit: long tapered muzzle, a real jaw/cheek,
	# laterally-set eyes, pricked ears
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0.0, neck1_y, neck1_z)
	head.rotation.x = plan.head_pitch
	body.add_child(head)

	head.add_child(_blob(coat, plan.skull_w, plan.skull_h, plan.skull_d, 0.0, 0.0, 0.0))
	head.add_child(_blob(coat, plan.jaw_w, plan.jaw_h, plan.jaw_d, 0.0, plan.jaw_y, plan.jaw_z))

	var muzzle := _cylinder(plan.muzzle_r1, plan.muzzle_r0, plan.muzzle_len, coat, 12)
	muzzle.rotation.x = PI / 2.0
	muzzle.position = Vector3(0.0, plan.muzzle_y, plan.skull_d * 0.42 + plan.muzzle_len * 0.5)
	head.add_child(muzzle)
	head.add_child(_blob(coat, plan.muzzle_r1 * 1.06, plan.muzzle_r1 * 1.02, plan.muzzle_r1 * 0.85,
		0.0, plan.muzzle_y, plan.skull_d * 0.42 + plan.muzzle_len))
	head.add_child(_blob(coat_dark, plan.muzzle_r1 * 0.9, plan.muzzle_r1 * 0.55, plan.muzzle_r1 * 0.6,
		0.0, plan.muzzle_y - plan.muzzle_r1 * 0.4, plan.skull_d * 0.42 + plan.muzzle_len * 0.92))

	for side in [-1.0, 1.0]:
		var ear := _cylinder(0.004, plan.ear_r, plan.ear_h, coat, 8)
		ear.position = Vector3(side * plan.ear_x, plan.ear_y, plan.ear_z)
		ear.rotation.z = -side * plan.ear_tilt
		ear.rotation.x = -0.18
		head.add_child(ear)

		var eye := Node3D.new()
		eye.position = Vector3(side * plan.eye_x, plan.eye_y, plan.eye_z)
		eye.add_child(_blob(eye_white, plan.eye_r, plan.eye_r, plan.eye_r, 0.0, 0.0, 0.0))
		eye.add_child(_blob(eye_pupil, plan.eye_r * 0.6, plan.eye_r * 0.6, plan.eye_r * 0.6,
			side * plan.eye_r * 0.55, 0.0, plan.eye_r * 0.5))
		head.add_child(eye)

	if genome.extra_eyes:
		for side in [-1.0, 1.0]:
			var eye2 := Node3D.new()
			eye2.position = Vector3(side * plan.eye_x * 0.55, plan.eye_y + plan.skull_h * 0.62, plan.eye_z * 0.7)
			var r2: float = plan.eye_r * 0.66
			eye2.add_child(_blob(eye_white, r2, r2, r2, 0.0, 0.0, 0.0))
			eye2.add_child(_blob(eye_pupil, r2 * 0.6, r2 * 0.6, r2 * 0.6, 0.0, 0.0, r2 * 0.5))
			head.add_child(eye2)

	head.add_child(_blob(mane_mat, plan.forelock_r * 1.2, plan.forelock_r, plan.forelock_r,
		0.0, plan.skull_h * 0.72, -plan.skull_d * 0.28))

	var horn_glow: Node3D = null
	if genome.antigrav_horn:
		var horn_hue := fposmod(genome.coat_hue + 0.45, 1.0)
		var horn_mat := _mat(PonyGenome.hsl_to_color(horn_hue, 0.5, 0.75),
			PonyGenome.hsl_to_color(horn_hue, 0.6, 0.55), 0.6)
		var horn := _cylinder(0.0, plan.skull_w * 0.22, plan.skull_h * 2.2, horn_mat, 6)
		horn.position = Vector3(0.0, plan.skull_h * 1.2, -plan.skull_d * 0.1)
		horn.rotation.x = -0.25
		head.add_child(horn)
		var glow_r: float = plan.skull_w * 0.2
		var glow := _blob(_mat(PonyGenome.hsl_to_color(horn_hue, 0.5, 0.72)), glow_r, glow_r, glow_r,
			0.0, plan.skull_h * 2.3, -plan.skull_d * 0.2)
		head.add_child(glow)
		horn_glow = glow

	# Space helmet: a bubble big enough to clear the muzzle, plus a seal ring
	# at the base. A horn pokes straight through it, which is left alone on
	# purpose — it's exactly the kind of "shouldn't work but does" the tone
	# is going for.
	if genome.space_helmet:
		var reach: float = plan.skull_d * 0.42 + plan.muzzle_len
		var dome_r: float = maxf(plan.skull_w, plan.skull_h) * 1.2 + reach * 0.46
		var glass := _mat(Color(0.72, 0.88, 1.0))
		glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glass.albedo_color.a = 0.26
		glass.cull_mode = BaseMaterial3D.CULL_DISABLED
		glass.roughness = 0.04
		glass.metallic = 0.0
		head.add_child(_blob(glass, dome_r, dome_r * 1.02, dome_r * 1.12,
			0.0, plan.muzzle_y * 0.35, reach * 0.4))
		var ring_mat := _mat(Color(0.78, 0.8, 0.86), Color.BLACK, 0.3, 0.55)
		var ring := _cylinder(dome_r * 0.66, dome_r * 0.72, plan.skull_h * 0.2, ring_mat, 12)
		ring.rotation.x = PI / 2.0
		ring.position = Vector3(0.0, plan.muzzle_y * 0.35, reach * 0.4 - dome_r * 0.92)
		head.add_child(ring)

	if genome.gills:
		var gill_mat := _mat(PonyGenome.hsl_to_color(0.5, 0.55, 0.6), Color(0.435, 0.89, 0.769), 0.4)
		for side in [-1.0, 1.0]:
			for i in 3:
				var slat := _blob(gill_mat, plan.neck_r0 * 0.1, plan.neck_r0 * 0.34, plan.neck_r0 * 0.12,
					side * plan.neck_r0 * 0.9, plan.neck0_y + 0.1 - i * plan.neck_r0 * 0.4, plan.neck0_z)
				body.add_child(slat)

	if genome.wings:
		var wing_mat := _mat(PonyGenome.hsl_to_color(genome.mane_hue, 0.5, 0.66))
		wing_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		wing_mat.albedo_color.a = 0.88
		wing_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		for side in [-1.0, 1.0]:
			var wing := _cylinder(0.0, plan.barrel_w * 1.1, plan.barrel_h * 0.24, wing_mat, 3)
			wing.position = Vector3(side * plan.barrel_w * 1.15, plan.barrel_h * 0.5, -plan.barrel_l * 0.1)
			wing.rotation.z = side * (PI / 2.0) * 0.62
			wing.rotation.y = side * 0.3
			wing.rotation.x = -0.15
			body.add_child(wing)

	# legs: two-bone hip -> knee, the hierarchy the controller animates
	var leg_hips: Array[Node3D] = []
	var leg_knees: Array[Node3D] = []
	var leg_phase_offsets: Array[float] = []
	var slots: Array = _leg_slots(genome.leg_count, plan)
	for slot in slots:
		var hip := Node3D.new()
		hip.name = "LegHip"
		hip.position = Vector3(slot.x, plan.hip_y, slot.z)
		hip.rotation.z = slot.splay
		body.add_child(hip)

		var upper_len: float = plan.leg_len * 0.55
		var lower_len: float = plan.leg_len * 0.45
		var upper := _cylinder(plan.leg_r_mid, plan.leg_r_top, upper_len, coat, 10)
		upper.position.y = -upper_len / 2.0
		hip.add_child(upper)

		var knee := Node3D.new()
		knee.name = "LegKnee"
		knee.position.y = -upper_len
		hip.add_child(knee)
		var kr: float = plan.leg_r_mid * 1.22
		knee.add_child(_blob(coat, kr, kr, kr, 0.0, 0.0, 0.0))

		var lower := _cylinder(plan.leg_r_ankle, plan.leg_r_mid * 0.94, lower_len, coat_dark, 10)
		lower.position.y = -lower_len / 2.0
		knee.add_child(lower)

		_add_foot(knee, genome.leg_type, plan, lower_len, hoof_mat, coat_dark, flame_orange, flame_yellow)

		leg_hips.append(hip)
		leg_knees.append(knee)
		leg_phase_offsets.append(slot.phase)

	# tail: a chain of blobs walking along a carriage direction, drooping as
	# it goes. tail_carry 0 hangs straight down, PI/2 points straight back,
	# above that it flags up — the difference between a curtain over the
	# rump and a banner above it.
	var tail := Node3D.new()
	tail.name = "Tail"
	tail.position = Vector3(0.0, plan.tail_y, plan.tail_z)
	body.add_child(tail)
	var dock: float = plan.tail_r0 * 0.95
	tail.add_child(_blob(coat, dock, dock, dock, 0.0, 0.0, 0.0))

	var dy := -cos(plan.tail_carry)
	var dz := -sin(plan.tail_carry)
	var py := 0.0
	var pz := 0.0
	var travelled := 0.0
	var guard := 0
	var tip_y := 0.0
	var tip_z := 0.0
	while travelled < plan.tail_len and guard < 80:
		guard += 1
		var t: float = minf(1.0, travelled / plan.tail_len)
		var r: float = plan.tail_r0 + (plan.tail_r1 - plan.tail_r0) * t
		tail.add_child(_blob(mane_mat, r * plan.tail_wide, r, r, 0.0, py, pz))
		if plan.tail_plume and guard > 1 and guard % 2 == 0 and t < 0.94:
			tail.add_child(_blob(mane_mat, r * 0.74, r * 0.74, r * 0.74, r * 0.85, py, pz))
			tail.add_child(_blob(mane_mat, r * 0.74, r * 0.74, r * 0.74, -r * 0.85, py, pz))
		var step_len: float = maxf(0.025, r * 0.58)
		py += dy * step_len
		pz += dz * step_len
		travelled += step_len
		dy -= plan.tail_droop * (step_len / 0.12)
		var dl: float = sqrt(dy * dy + dz * dz)
		if dl > 0.0:
			dy /= dl
			dz /= dl
		tip_y = py
		tip_z = pz

	_add_tail_tip(tail, genome.tail_type, plan, tip_y, tip_z, coat_dark, flame_orange, flame_yellow)

	return {
		"leg_hips": leg_hips,
		"leg_knees": leg_knees,
		"leg_phase_offsets": leg_phase_offsets,
		"head": head,
		"tail": tail,
		"head_pitch": float(plan.head_pitch),
		"tail_sway": float(plan.tail_sway),
		"horn_glow": horn_glow,
	}

## The leg_type gene still picks what's on the end of the leg, on top of
## whatever proportions the body plan gave it.
static func _add_foot(knee: Node3D, leg_type: String, plan: Dictionary, lower_len: float,
		hoof_mat: Material, coat_dark: Material, flame_orange: Material, flame_yellow: Material) -> void:
	match leg_type:
		"rocket-boots":
			var flame_group := Node3D.new()
			flame_group.position.y = -lower_len
			knee.add_child(flame_group)
			var outer := _cylinder(0.0, plan.hoof_r * 1.2, plan.hoof_r * 2.6, flame_orange, 6)
			outer.rotation.x = PI
			outer.position.y = -plan.hoof_r * 1.1
			flame_group.add_child(outer)
			var inner := _cylinder(0.0, plan.hoof_r * 0.7, plan.hoof_r * 1.5, flame_yellow, 6)
			inner.rotation.x = PI
			inner.position.y = -plan.hoof_r * 0.6
			flame_group.add_child(inner)
		"propeller-feet":
			var prop := Node3D.new()
			prop.position.y = -lower_len - plan.hoof_r * 0.3
			knee.add_child(prop)
			for rot in [0.0, PI / 2.0]:
				var blade_mesh := BoxMesh.new()
				blade_mesh.size = Vector3(plan.hoof_r * 5.0, plan.hoof_r * 0.22, plan.hoof_r * 1.0)
				var blade := MeshInstance3D.new()
				blade.mesh = blade_mesh
				blade.set_surface_override_material(0, coat_dark)
				blade.rotation.y = rot
				prop.add_child(blade)
		"tentacles":
			var tip_r: float = plan.leg_r_ankle * 1.3
			knee.add_child(_blob(coat_dark, tip_r, tip_r, tip_r, 0.0, -lower_len, 0.0))
		_:
			var hoof := _cylinder(plan.hoof_r, plan.hoof_r * 0.9, plan.hoof_h, hoof_mat, 10)
			hoof.position.y = -lower_len - plan.hoof_h * 0.35
			knee.add_child(hoof)

## The tail_type gene decorates the end of the blob chain.
static func _add_tail_tip(tail: Node3D, tail_type: String, plan: Dictionary, tip_y: float, tip_z: float,
		coat_dark: Material, flame_orange: Material, flame_yellow: Material) -> void:
	match tail_type:
		"rocket":
			var outer := _cylinder(0.0, plan.tail_r1 * 1.9, plan.tail_r1 * 4.4, flame_orange, 6)
			outer.rotation.x = PI * 0.42
			outer.position = Vector3(0.0, tip_y, tip_z - plan.tail_r1 * 1.6)
			tail.add_child(outer)
			var inner := _cylinder(0.0, plan.tail_r1 * 1.1, plan.tail_r1 * 2.6, flame_yellow, 6)
			inner.rotation.x = PI * 0.42
			inner.position = Vector3(0.0, tip_y + plan.tail_r1 * 0.3, tip_z - plan.tail_r1 * 1.2)
			tail.add_child(inner)
		"propeller":
			var prop := Node3D.new()
			prop.position = Vector3(0.0, tip_y, tip_z - plan.tail_r1 * 1.4)
			tail.add_child(prop)
			for rot in [0.0, PI / 2.0]:
				var blade_mesh := BoxMesh.new()
				blade_mesh.size = Vector3(plan.tail_r1 * 7.0, plan.tail_r1 * 0.35, plan.tail_r1 * 1.6)
				var blade := MeshInstance3D.new()
				blade.mesh = blade_mesh
				blade.set_surface_override_material(0, coat_dark)
				blade.rotation.z = rot
				prop.add_child(blade)
		_:
			pass  # 'whip' is just the bare chain — its character is in the sway

static func _qbez(p0y: float, p0z: float, p1y: float, p1z: float, p2y: float, p2z: float, t: float) -> Vector2:
	var it := 1.0 - t
	return Vector2(
		it * it * p0y + 2.0 * it * t * p1y + t * t * p2y,
		it * it * p0z + 2.0 * it * t * p1z + t * t * p2z
	)

## roughness/metallic defaults are tuned shinier than flat matte, with a
## glossy clearcoat. Metallic stays low deliberately: a strongly metallic
## surface has almost no diffuse albedo and reads near-black without a
## ReflectionProbe in the scene.
static func _mat(color: Color, emission: Color = Color.BLACK, roughness: float = 0.26, metallic: float = 0.14) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	m.clearcoat_enabled = true
	m.clearcoat = 0.5
	if emission != Color.BLACK:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = 0.6
	return m

static func _cylinder(top_radius: float, bottom_radius: float, height: float, material: Material, segments: int = 10) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = segments
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.set_surface_override_material(0, material)
	return mi

## An ellipsoid: the shared unit sphere scaled per-axis and placed. Nearly
## the whole pony is built out of these.
static func _blob(material: Material, w: float, h: float, d: float, x: float, y: float, z: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _get_blob_mesh()
	mi.set_surface_override_material(0, material)
	mi.scale = Vector3(w, h, d)
	mi.position = Vector3(x, y, z)
	return mi

## Smooth-shaded so the coat color reads evenly. A flat-shaded low-poly
## solid puts most faces at a steep angle to the scene's key light, which
## made every pony render near-black regardless of its actual color.
static func _get_blob_mesh() -> SphereMesh:
	if _shared_blob_mesh == null:
		var s := SphereMesh.new()
		s.radius = 1.0
		s.height = 2.0
		s.radial_segments = 14
		s.rings = 8
		_shared_blob_mesh = s
	return _shared_blob_mesh
