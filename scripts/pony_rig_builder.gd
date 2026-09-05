class_name PonyRigBuilder
extends RefCounted

## Procedurally builds a pony's visual rig from a PonyGenome, ported from
## the Look Book's buildRig()/buildLeg() (docs/index.html). Geometry is all
## Godot primitives (Box/Cylinder/flat-shaded icosahedron) rather than a
## fixed imported asset, since bred/generated ponies vary structurally
## (leg count, leg type, tail type, adaptations) in a way a single static
## mesh can't represent.

const LEG_LAYOUTS := {
	2: [{"x": 0.0, "z": 0.34, "phase": 0.0}, {"x": 0.0, "z": -0.34, "phase": PI}],
	3: [{"x": -0.5, "z": 0.3, "phase": 0.0}, {"x": 0.12, "z": -0.42, "phase": 1.8}, {"x": 0.58, "z": 0.26, "phase": 3.3}],
	4: [
		{"x": -0.5, "z": 0.34, "phase": 0.0}, {"x": 0.5, "z": 0.34, "phase": PI},
		{"x": -0.5, "z": -0.34, "phase": PI}, {"x": 0.5, "z": -0.34, "phase": 0.0}
	]
}

static var _unit_icosahedron: ArrayMesh

## Result: { leg_hips, leg_knees, leg_phase_offsets: Array[float],
## flame_outers, flame_inners (parallel arrays, null where not applicable),
## horn_glow: Node3D, tail_flame_outer, tail_flame_inner (or null) }
static func build(visual: Node3D, genome: PonyGenome) -> Dictionary:
	# Only remove a previous rig by name — Visual also hosts the Exhaust and
	# HornTrail particle emitters as fixed siblings (see Pony.tscn), which
	# must survive a rebuild, not get swept up in it.
	var old_rig := visual.get_node_or_null("Rig")
	if old_rig != null:
		visual.remove_child(old_rig)
		old_rig.queue_free()

	var rig := Node3D.new()
	rig.name = "Rig"
	visual.add_child(rig)

	var body_main := _mat(PonyGenome.hsl_to_color(genome.coat_hue, 0.42, 0.42))
	var body_light := _mat(PonyGenome.hsl_to_color(genome.coat_hue, 0.46, 0.62))
	var body_dark := _mat(PonyGenome.hsl_to_color(genome.coat_hue, 0.4, 0.24))
	var head_main := _mat(PonyGenome.hsl_to_color(genome.coat_hue, 0.38, 0.5))
	var head_light := _mat(PonyGenome.hsl_to_color(genome.coat_hue, 0.34, 0.66))
	var head_dark := _mat(PonyGenome.hsl_to_color(genome.coat_hue, 0.42, 0.32))
	var mane_light := _mat(PonyGenome.hsl_to_color(genome.mane_hue, 0.55, 0.72))
	var mane_dark := _mat(PonyGenome.hsl_to_color(genome.mane_hue, 0.5, 0.42))
	var eye_white := _mat(Color(0.953, 0.933, 0.984))
	var eye_pupil := _mat(Color(0.141, 0.109, 0.251))
	var horn_hue := fposmod(genome.coat_hue + 0.45 + randf_range(-0.1, 0.1), 1.0)
	var horn_crystal := _mat(PonyGenome.hsl_to_color(horn_hue, 0.5, 0.75), PonyGenome.hsl_to_color(horn_hue, 0.6, 0.55), 0.6)
	var horn_tip_mat := _mat(PonyGenome.hsl_to_color(horn_hue, 0.2, 0.94), PonyGenome.hsl_to_color(horn_hue, 0.3, 0.9), 0.9)
	var gill_mat := _mat(PonyGenome.hsl_to_color(0.5, 0.55, 0.55), Color(0.435, 0.89, 0.769), 0.4)
	var wing_mat := _mat(PonyGenome.hsl_to_color(genome.mane_hue, 0.5, 0.6))
	wing_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wing_mat.albedo_color.a = 0.88
	wing_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var spot_mat := _mat(PonyGenome.hsl_to_color(genome.mane_hue, 0.55, 0.6))
	var flame_orange := _mat(Color(1.0, 0.604, 0.337), Color(1.0, 0.604, 0.337), 0.5)
	var flame_yellow := _mat(Color(1.0, 0.82, 0.4), Color(1.0, 0.82, 0.4), 0.6)

	# torso
	var torso := _icosphere(Vector3(0.82 * 1.28, 0.82 * 0.82, 0.82 * 1.05), body_main)
	rig.add_child(torso)
	var torso_light := _icosphere(Vector3(0.42 * 1.1, 0.42 * 0.7, 0.42 * 0.7), body_light)
	torso_light.position = Vector3(0.42, 0.32, 0.42)
	rig.add_child(torso_light)
	var torso_dark := _icosphere(Vector3(0.46, 0.46 * 0.7, 0.46 * 0.75), body_dark)
	torso_dark.position = Vector3(-0.3, -0.28, -0.32)
	rig.add_child(torso_dark)

	if genome.coat_pattern == "spotted":
		for p in [Vector3(0.5, 0.05, 0.1), Vector3(-0.15, 0.35, 0.5), Vector3(0.1, -0.2, -0.55), Vector3(-0.45, 0.0, -0.05)]:
			var spot := _icosphere(Vector3.ONE * (0.13 + randf() * 0.06), spot_mat)
			spot.position = p
			rig.add_child(spot)

	# head
	var head_group := Node3D.new()
	head_group.name = "HeadGroup"
	head_group.position = Vector3(0, 0.58, 0.92)
	rig.add_child(head_group)
	head_group.add_child(_icosphere(Vector3.ONE * 0.4, head_main))
	var head_light_mesh := _icosphere(Vector3.ONE * 0.2, head_light)
	head_light_mesh.position = Vector3(0.18, 0.14, 0.2)
	head_group.add_child(head_light_mesh)
	var head_dark_mesh := _icosphere(Vector3.ONE * 0.2, head_dark)
	head_dark_mesh.position = Vector3(-0.15, -0.1, -0.16)
	head_group.add_child(head_dark_mesh)

	for e in [[-0.16, 0.34, 0.06, head_light, 0.35], [0.02, 0.36, 0.08, head_main, -0.2]]:
		var ear := _cone(0.09, 0.26, e[3])
		ear.position = Vector3(e[0], e[1], e[2])
		ear.rotation.z = e[4]
		head_group.add_child(ear)

	var horn_glow: Node3D = null
	if genome.antigrav_horn:
		var horn_group := Node3D.new()
		horn_group.name = "HornGroup"
		horn_group.position = Vector3(0.02, 0.42, 0.14)
		horn_group.rotation.x = -0.25
		head_group.add_child(horn_group)
		var horn := _cone(0.05, 0.5, horn_crystal)
		horn.position.y = 0.25
		horn_group.add_child(horn)
		var horn_tip := _cone(0.028, 0.2, horn_tip_mat)
		horn_tip.position.y = 0.42
		horn_group.add_child(horn_tip)
		var glow := _icosphere(Vector3.ONE * 0.075, _mat(PonyGenome.hsl_to_color(horn_hue, 0.5, 0.7)))
		glow.position.y = 0.52
		horn_group.add_child(glow)
		horn_glow = glow
	else:
		var anchor := Node3D.new()
		anchor.name = "TrailAnchor"
		anchor.position = Vector3(0, 0.4, 0.1)
		head_group.add_child(anchor)
		horn_glow = anchor

	# eyes — extra_eyes mutation adds a second pair on the forehead
	var eye_specs := [[-0.16, 0.03, 0.32, 0.068, 0.034], [0.14, 0.06, 0.33, 0.068, 0.034]]
	if genome.extra_eyes:
		eye_specs.append([-0.05, 0.22, 0.36, 0.045, 0.024])
		eye_specs.append([0.06, 0.23, 0.36, 0.045, 0.024])
	for p in eye_specs:
		var eye := Node3D.new()
		eye.position = Vector3(p[0], p[1], p[2])
		var white := _icosphere(Vector3.ONE * p[3], eye_white)
		eye.add_child(white)
		var pupil := _icosphere(Vector3.ONE * p[4], eye_pupil)
		pupil.position.z = p[3] * 0.7
		eye.add_child(pupil)
		head_group.add_child(eye)

	# mane
	if genome.mane_style == "space-mane":
		for s in [
			[-0.05, 0.32, -0.12, 0.14, 0.34, mane_light], [-0.16, 0.28, -0.28, 0.13, 0.3, mane_dark],
			[-0.28, 0.22, -0.42, 0.12, 0.26, mane_light], [-0.4, 0.14, -0.55, 0.1, 0.22, mane_dark]
		]:
			var spike := _cone(s[3], s[4], s[5])
			spike.position = Vector3(s[0], s[1], s[2])
			spike.rotation.x = -0.3
			spike.rotation.z = 0.25
			head_group.add_child(spike)
	else:
		var stalks := [Vector3(-0.1, 0.34, -0.1), Vector3(0.12, 0.36, -0.16)]
		for i in stalks.size():
			var p: Vector3 = stalks[i]
			var stalk_mesh := CylinderMesh.new()
			stalk_mesh.top_radius = 0.018
			stalk_mesh.bottom_radius = 0.028
			stalk_mesh.height = 0.36
			stalk_mesh.radial_segments = 5
			var stalk := MeshInstance3D.new()
			stalk.mesh = stalk_mesh
			stalk.set_surface_override_material(0, mane_dark if i % 2 == 1 else mane_light)
			stalk.position = Vector3(p.x, p.y + 0.18, p.z)
			stalk.rotation.x = -0.35
			head_group.add_child(stalk)
			var bead := _icosphere(Vector3.ONE * 0.05, horn_tip_mat)
			bead.position = Vector3(p.x, p.y + 0.38, p.z - 0.12)
			head_group.add_child(bead)

	if genome.gills:
		for side in [-1.0, 1.0]:
			for i in 3:
				var slat_mesh := BoxMesh.new()
				slat_mesh.size = Vector3(0.03, 0.09, 0.02)
				var slat := MeshInstance3D.new()
				slat.mesh = slat_mesh
				slat.set_surface_override_material(0, gill_mat)
				slat.position = Vector3(side * 0.36, 0.08 - i * 0.09, 0.55)
				slat.rotation.z = side * 0.3
				head_group.add_child(slat)

	if genome.wings:
		for side in [-1.0, 1.0]:
			var wing := _cone(0.62, 0.14, wing_mat, 3)
			wing.position = Vector3(side * 0.75, 0.35, -0.15)
			wing.rotation.z = side * (PI / 2.0) * 0.62
			wing.rotation.y = side * 0.3
			wing.rotation.x = -0.15
			rig.add_child(wing)

	# tail
	var tail := Node3D.new()
	tail.name = "Tail"
	tail.position = Vector3(-0.05, 0.15, -0.95)
	rig.add_child(tail)
	for s in [[0.0, 0.0, 0.0, 0.16, body_light], [-0.14, -0.06, -0.16, 0.13, body_dark], [0.1, -0.1, -0.22, 0.1, body_dark]]:
		var t := _cone(s[3], s[3] * 2.2, s[4])
		t.position = Vector3(s[0], s[1], s[2])
		t.rotation.x = PI * 0.42
		tail.add_child(t)

	var tail_flame_outer: Node3D = null
	var tail_flame_inner: Node3D = null
	if genome.tail_type == "rocket":
		var flame_group := Node3D.new()
		flame_group.position = Vector3(0.1, -0.32, -0.5)
		tail.add_child(flame_group)
		var tf1 := _cone(0.09, 0.24, flame_orange)
		tf1.rotation.x = PI * 0.42
		flame_group.add_child(tf1)
		var tf2 := _cone(0.05, 0.14, flame_yellow)
		tf2.rotation.x = PI * 0.42
		tf2.position.y = 0.04
		flame_group.add_child(tf2)
		tail_flame_outer = tf1
		tail_flame_inner = tf2
	elif genome.tail_type == "propeller":
		var prop_group := Node3D.new()
		prop_group.position = Vector3(0.14, -0.16, -0.62)
		tail.add_child(prop_group)
		for rot in [0.0, PI / 2.0]:
			var blade_mesh := BoxMesh.new()
			blade_mesh.size = Vector3(0.34, 0.018, 0.07)
			var blade := MeshInstance3D.new()
			blade.mesh = blade_mesh
			blade.set_surface_override_material(0, body_dark)
			blade.rotation.z = rot
			prop_group.add_child(blade)
	# 'whip' tail: base cones only, whip-iness comes from animation amplitude.

	# legs
	var layout: Array = LEG_LAYOUTS[genome.leg_count]
	var leg_mats := _leg_materials(genome.leg_type, genome.coat_hue, flame_orange, flame_yellow)
	var leg_hips: Array[Node3D] = []
	var leg_knees: Array[Node3D] = []
	var leg_phase_offsets: Array[float] = []
	for spot in layout:
		var length: float = randf_range(1.1, 1.9) * (0.72 if genome.leg_type == "propeller-feet" else 1.0)
		var built := _build_leg(rig, spot.x, spot.z, length, genome.leg_type, leg_mats, flame_orange, flame_yellow)
		leg_hips.append(built.hip)
		leg_knees.append(built.knee)
		leg_phase_offsets.append(spot.phase + randf_range(-0.15, 0.15))

	rig.scale = Vector3.ONE * genome.size

	return {
		"leg_hips": leg_hips,
		"leg_knees": leg_knees,
		"leg_phase_offsets": leg_phase_offsets,
		"horn_glow": horn_glow,
		"tail_flame_outer": tail_flame_outer,
		"tail_flame_inner": tail_flame_inner,
	}

static func _build_leg(parent: Node3D, x: float, z: float, length: float, leg_type: String, mats: Dictionary, flame_orange: Material, flame_yellow: Material) -> Dictionary:
	var upper_len := length * 0.56
	var lower_len := length * 0.44
	var segs := 6 if leg_type == "tentacles" else 5

	var hip := Node3D.new()
	hip.name = "LegHip"
	hip.position = Vector3(x, -0.18, z)
	parent.add_child(hip)

	var upper_top: float = length * (0.06 if leg_type == "tentacles" else 0.1)
	var upper_bot: float = length * (0.09 if leg_type == "tentacles" else 0.135)
	var upper := _cylinder(upper_top, upper_bot, upper_len, mats.light, segs)
	upper.position.y = -upper_len / 2.0
	hip.add_child(upper)

	var knee := Node3D.new()
	knee.name = "LegKnee"
	knee.position.y = -upper_len
	hip.add_child(knee)
	knee.add_child(_icosphere(Vector3.ONE * (length * 0.085), mats.light))

	if leg_type == "propeller-feet":
		var hub := _icosphere(Vector3.ONE * (length * 0.11), mats.accent)
		hub.position.y = -lower_len * 0.3
		knee.add_child(hub)
		var prop_group := Node3D.new()
		prop_group.position.y = -lower_len * 0.3
		knee.add_child(prop_group)
		for rot in [0.0, PI / 2.0]:
			var blade_mesh := BoxMesh.new()
			blade_mesh.size = Vector3(length * 0.42, length * 0.02, length * 0.09)
			var blade := MeshInstance3D.new()
			blade.mesh = blade_mesh
			blade.set_surface_override_material(0, mats.dark)
			blade.rotation.y = rot
			prop_group.add_child(blade)
	else:
		var lower := _cylinder(length * 0.08, length * 0.11, lower_len, mats.dark, segs)
		lower.position.y = -lower_len / 2.0
		knee.add_child(lower)

		if leg_type == "rocket-boots":
			var flame_group := Node3D.new()
			flame_group.position.y = -lower_len
			knee.add_child(flame_group)
			var flame_outer := _cone(0.13, 0.34, flame_orange)
			flame_outer.rotation.x = PI
			flame_outer.position.y = -0.15
			flame_group.add_child(flame_outer)
			var flame_inner := _cone(0.075, 0.2, flame_yellow)
			flame_inner.rotation.x = PI
			flame_inner.position.y = -0.08
			flame_group.add_child(flame_inner)
		elif leg_type == "hooves":
			var hoof_mesh := BoxMesh.new()
			hoof_mesh.size = Vector3(length * 0.16, length * 0.09, length * 0.2)
			var hoof := MeshInstance3D.new()
			hoof.mesh = hoof_mesh
			hoof.set_surface_override_material(0, mats.accent)
			hoof.position.y = -lower_len - length * 0.03
			knee.add_child(hoof)
		else:
			var tip := _icosphere(Vector3.ONE * (length * 0.07), mats.light)
			tip.position.y = -lower_len
			knee.add_child(tip)

	return {"hip": hip, "knee": knee}

static func _leg_materials(leg_type: String, coat_hue: float, flame_orange: Material, flame_yellow: Material) -> Dictionary:
	match leg_type:
		"propeller-feet":
			return {
				"light": _mat(PonyGenome.hsl_to_color(coat_hue, 0.06, 0.75), Color.BLACK, 0.3, 0.55),
				"dark": _mat(PonyGenome.hsl_to_color(coat_hue, 0.08, 0.42), Color.BLACK, 0.3, 0.55),
				"accent": _mat(PonyGenome.hsl_to_color(coat_hue, 0.1, 0.85), PonyGenome.hsl_to_color(coat_hue, 0.3, 0.4), 0.25, 0.6),
			}
		"tentacles":
			var tl := _mat(PonyGenome.hsl_to_color(coat_hue + 0.06, 0.55, 0.5), Color.BLACK, 0.3, 0.05)
			return {
				"light": tl,
				"dark": _mat(PonyGenome.hsl_to_color(coat_hue + 0.06, 0.5, 0.3), Color.BLACK, 0.3, 0.05),
				"accent": tl,
			}
		"hooves":
			return {
				"light": _mat(PonyGenome.hsl_to_color(coat_hue, 0.32, 0.36)),
				"dark": _mat(PonyGenome.hsl_to_color(coat_hue, 0.34, 0.24)),
				"accent": _mat(PonyGenome.hsl_to_color(coat_hue, 0.2, 0.12)),
			}
		_:
			return {
				"light": _mat(PonyGenome.hsl_to_color(coat_hue, 0.3, 0.34)),
				"dark": _mat(PonyGenome.hsl_to_color(coat_hue, 0.32, 0.24)),
				"accent": flame_orange,
			}

## roughness/metallic defaults are already tuned shinier than the Look
## Book's own values (which read flat/washed-out once lit in Godot) — a
## glossy clearcoat plus lowered roughness, with only a small metallic bump
## since a strongly metallic surface has almost no diffuse albedo and
## reads as near-black without a ReflectionProbe in the scene.
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

static func _cylinder(top_radius: float, bottom_radius: float, height: float, material: Material, segments: int = 5) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = segments
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.set_surface_override_material(0, material)
	return mi

static func _cone(radius: float, height: float, material: Material, segments: int = 5) -> MeshInstance3D:
	return _cylinder(0.0, radius, height, material, segments)

static func _icosphere(radius: Vector3, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _get_icosahedron()
	mi.set_surface_override_material(0, material)
	mi.scale = radius
	return mi

## A real regular icosahedron (20 flat-shaded triangular faces), unit
## radius, built once and reused via per-instance `scale` — the low-poly
## "gem" look from the Look Book, since Godot has no built-in icosahedron
## primitive.
static func _get_icosahedron() -> ArrayMesh:
	if _unit_icosahedron == null:
		_unit_icosahedron = _build_icosahedron()
	return _unit_icosahedron

static func _build_icosahedron() -> ArrayMesh:
	var t := (1.0 + sqrt(5.0)) / 2.0
	var raw := [
		Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
		Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
		Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)
	]
	var verts: Array[Vector3] = []
	for v in raw:
		verts.append(v.normalized())
	var faces := [
		[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11],
		[1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
		[3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9],
		[4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1]
	]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for f in faces:
		var a: Vector3 = verts[f[0]]
		var b: Vector3 = verts[f[1]]
		var c: Vector3 = verts[f[2]]
		var normal := (b - a).cross(c - a).normalized()
		st.set_normal(normal)
		st.add_vertex(a)
		st.set_normal(normal)
		st.add_vertex(b)
		st.set_normal(normal)
		st.add_vertex(c)
	return st.commit()
