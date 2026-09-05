extends CharacterBody3D

## Gray-box vertical-slice movement controller.
## Locomotion is physics-driven (velocity + gravity via move_and_slide);
## the wobble/jank layer is a procedural bob applied to the visual mesh only,
## so it works regardless of a pony's leg count/body plan (see docs/design.md).
##
## The leg rig (3 mismatched two-bone legs, hip -> knee) is driven by the
## same spring-damper secondary-motion technique used in the Three.js Look
## Book prototype: a walk-cycle target angle per joint, sprung toward rather
## than snapped to, so the legs lag/overshoot instead of moving in lockstep.
## Hard collisions and ability use feed impulses into a second spring system
## (_roll) that visually tumbles the body and settles back — a physics-
## flavored reaction layered on top of move_and_slide(), not a real
## rigid-body ragdoll (that would mean giving up the CharacterBody3D
## controller this whole game is tuned around).
##
## Also drives a simple wandering AI mode so bots (and, over the network,
## host-simulated bots) reuse the exact same movement/ability code as the
## player. In multiplayer, only the peer with authority over a given pony
## simulates it at all — everyone else just sees the synced transform.

@export var is_local_player: bool = false
@export var pony_name: String = "Pony"

@export var acceleration: float = 7.0
@export var max_speed: float = 9.0
@export var turn_speed: float = 2.4
@export var jump_velocity: float = 6.0
@export var gravity: float = 20.0

## Passive steering drift — a "bad shopping cart wheel" pull that's always
## live, on top of whatever the driver (player or AI) is asking for. This is
## the main thing that makes the controls feel unwieldy rather than just slow.
@export var drift_strength: float = 0.35
@export var drift_freq: float = 0.5

@export var wobble_speed: float = 14.0
@export var wobble_amount: float = 0.12
@export var bob_amount: float = 0.08

@export var ability_dash_speed: float = 14.0
@export var ability_cooldown: float = 2.5
@export var ability_recoil_kick: float = 3.0

## Walk-cycle leg rig. Springs are deliberately loose and underdamped —
## these legs are dangling in zero gravity, so they should lag well behind
## the gait target, overshoot it, and keep drifting after it stops, rather
## than tracking it crisply. Stiffness/damping are the whole difference
## between "animated legs" and "ragdoll legs".
@export var leg_swing_freq: float = 9.0
@export var leg_swing_amplitude: float = 0.9
@export var knee_bend_amplitude: float = 1.1
@export var hip_stiffness: float = 26.0
@export var hip_damping: float = 3.0
@export var knee_stiffness: float = 16.0
@export var knee_damping: float = 1.8
## Zero-g idle drift, so legs keep floating even at a standstill.
@export var leg_idle_dangle: float = 0.22

## Head and tail run their own spring-damper chains so they lag and whip
## behind the body instead of moving with it — the swoosh.
@export var head_stiffness: float = 34.0
@export var head_damping: float = 3.4
@export var tail_stiffness: float = 18.0
@export var tail_damping: float = 1.9
@export var tail_swoosh: float = 2.6
## How hard turning throws the head and tail out sideways.
@export var turn_whip: float = 7.0

## Ability-use "roll" kick: a small impulse-driven spring on the whole visual
## rig, always relaxing back toward neutral.
@export var roll_stiffness: float = 18.0
@export var roll_damping: float = 3.2

## A hard collision triggers a genuine Zero-G Barrel Roll — continuous
## multi-rotation spin with the legs flailing independently, matching the
## Look Book's dedicated barrel-roll animation — rather than just a small
## nudge. It settles back to neutral via the same spring once it ends.
@export var collision_roll_threshold: float = 3.0
@export var barrel_roll_duration: float = 1.1
@export var barrel_roll_spin_speed: float = 14.0
@export var barrel_roll_flail_amount: float = 2.2
@export var barrel_roll_retrigger_cooldown: float = 1.2
## How much of the tumble axis is random rather than derived from the
## impact. At 0 every hit rolls the same predictable way; higher mixes in
## pitch and yaw so it tumbles end-over-end or corkscrews too.
@export var barrel_roll_axis_chaos: float = 0.85
## Springs go even looser mid-tumble — this is where the legs should look
## genuinely unattached.
@export var barrel_roll_limpness: float = 0.35

@onready var visual: Node3D = $Visual
@onready var camera: Camera3D = $SpringArm3D/Camera3D
@onready var sync: MultiplayerSynchronizer = $MultiplayerSynchronizer
@onready var exhaust: CPUParticles3D = $Visual/Exhaust
@onready var horn_trail: CPUParticles3D = $Visual/HornTrail

## The pony's genetic traits — see pony_genome.gd. Assigned via
## build_from_genome(), normally by RaceManager at race start (each player/
## bot gets its own randomly generated pony); _ready() below generates a
## throwaway fallback genome so a standalone/offline Pony scene still has
## a body, which RaceManager's call immediately replaces in the normal flow.
var genome: PonyGenome = null

## Leg count/type varies per genome, so these are sized dynamically by
## build_from_genome() rather than fixed at 3 — see pony_rig_builder.gd.
var _leg_hips: Array[Node3D] = []
var _leg_knees: Array[Node3D] = []

## Head and tail get their own sway on top of the gait — the tail
## especially, since it carries most of the silhouette from behind, which
## is the angle a racing player actually sees.
var _head: Node3D = null
var _tail: Node3D = null
var _head_pitch: float = 0.0
var _tail_sway: float = 0.12

## Spring state for the head/tail chains (angle + angular velocity per axis).
var _head_angle: Vector3 = Vector3.ZERO
var _head_vel: Vector3 = Vector3.ZERO
var _tail_angle: Vector3 = Vector3.ZERO
var _tail_vel: Vector3 = Vector3.ZERO
## Yaw delta from the previous frame, used to whip head/tail on turns.
var _turn_rate: float = 0.0
var _prev_yaw: float = 0.0

var food_collected: int = 0

var _wobble_time: float = 0.0
var _ability_cooldown_timer: float = 0.0
var _ability_flash: float = 0.0

var _ai_seed: float = 0.0
var _ai_ability_timer: float = 0.0

var _drift_time: float = 0.0
var _drift_seed: float = 0.0

var _walk_time: float = 0.0
var _leg_phase_offsets: Array[float] = []
var _hip_angle: Array[float] = []
var _hip_vel: Array[float] = []
var _knee_angle: Array[float] = []
var _knee_vel: Array[float] = []

var _roll_angle: Vector3 = Vector3.ZERO
var _roll_vel: Vector3 = Vector3.ZERO
var _pre_slide_velocity: Vector3 = Vector3.ZERO

var _barrel_roll_timer: float = 0.0
var _barrel_roll_cooldown: float = 0.0
var _barrel_roll_axis: Vector3 = Vector3.ZERO
var _flail_seed: float = 0.0

## Shared across every Pony instance so 4 ponies loading at once (race
## start) don't each allocate their own copies of the same mesh/material —
## that redundant setup work landing all at once was a real contributor to
## the scene-load hitch.
static var _shared_exhaust_mesh: BoxMesh
static var _shared_horn_trail_mesh: SphereMesh

func _ready() -> void:
	camera.current = is_local_player
	_ai_seed = randf() * 1000.0
	_ai_ability_timer = randf_range(1.0, 3.0)
	_drift_seed = randf() * 1000.0
	_flail_seed = randf() * 1000.0
	_setup_exhaust()
	_setup_horn_trail()
	# Fallback so a standalone Pony (no RaceManager) still has a body;
	# RaceManager overrides this with a seeded/synced genome immediately
	# after in the normal race-start flow.
	build_from_genome(PonyGenome.generate_random())

	var config := SceneReplicationConfig.new()
	config.add_property(NodePath(".:position"))
	config.add_property(NodePath(".:rotation"))
	sync.replication_config = config

## Builds this pony's visual rig and leg-animation state from a genome, and
## tunes movement to its stats. Called by RaceManager for every slot at
## race start (each player/bot gets its own randomly generated pony); safe
## to call again later for breeding/regeneration.
func build_from_genome(g: PonyGenome) -> void:
	genome = g
	var built := PonyRigBuilder.build(visual, genome)
	_leg_hips = built.leg_hips
	_leg_knees = built.leg_knees
	_leg_phase_offsets = built.leg_phase_offsets
	_head = built.head
	_tail = built.tail
	_head_pitch = built.head_pitch
	_tail_sway = built.tail_sway
	var n := _leg_hips.size()
	_hip_angle.resize(n)
	_hip_vel.resize(n)
	_knee_angle.resize(n)
	_knee_vel.resize(n)
	_hip_angle.fill(0.0)
	_hip_vel.fill(0.0)
	_knee_angle.fill(0.0)
	_knee_vel.fill(0.0)

	visual.scale = Vector3.ONE * (1.5 * genome.size)

	# Stats -> movement tuning. Wackiness/Chaos scaling the erratic-ness of
	# movement is exactly what docs/design.md's genetics framework describes
	# for that stat, not just a flavor number.
	max_speed = 9.0 * (0.7 + genome.stat_speed / 100.0 * 0.6)
	acceleration = 7.0 * (0.7 + genome.stat_acceleration / 100.0 * 0.6)
	turn_speed = 2.4 * (0.7 + genome.stat_handling / 100.0 * 0.6)
	var chaos_ratio: float = 0.5 + genome.stat_wackiness / 100.0
	wobble_amount = 0.12 * chaos_ratio
	drift_strength = 0.35 * chaos_ratio

func _setup_exhaust() -> void:
	if exhaust == null:
		return
	exhaust.emitting = false
	exhaust.one_shot = true
	exhaust.amount = 40
	exhaust.lifetime = 0.6
	exhaust.explosiveness = 0.85
	exhaust.direction = Vector3(0, 0.15, 1)
	exhaust.spread = 35.0
	exhaust.initial_velocity_min = 4.0
	exhaust.initial_velocity_max = 9.0
	exhaust.gravity = Vector3.ZERO
	exhaust.scale_amount_min = 0.15
	exhaust.scale_amount_max = 0.35
	exhaust.angular_velocity_min = -180.0
	exhaust.angular_velocity_max = 180.0
	# Generous explicit bounds — CPUParticles3D's automatic visibility AABB
	# can under-estimate the true travel range and cull particles inside
	# their own effect, which reads as flickering/strobing.
	exhaust.visibility_aabb = AABB(Vector3(-6, -3, -6), Vector3(12, 8, 14))
	var grad := Gradient.new()
	grad.add_point(0.0, Color(1.0, 0.85, 0.2, 1.0))
	grad.add_point(0.5, Color(1.0, 0.5, 0.1, 1.0))
	grad.add_point(1.0, Color(0.3, 0.8, 0.7, 0.0))
	exhaust.color_ramp = grad
	exhaust.mesh = _get_exhaust_mesh()

## Chunky cube "pixel debris" mesh instead of a soft billboard, matching the
## Look Book's Turbo Boost look. Unshaded + vertex-color (no emission): a
## flat white emission color was overpowering the color ramp under bloom,
## which is why these were reading as white instead of fire-colored, and
## was very likely also the "seizure-inducing" flicker (bright emissive
## particles blooming hard, worsened by the AABB culling above).
func _get_exhaust_mesh() -> BoxMesh:
	if _shared_exhaust_mesh == null:
		var box := BoxMesh.new()
		box.size = Vector3(0.14, 0.14, 0.14)
		var particle_mat := StandardMaterial3D.new()
		particle_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		particle_mat.vertex_color_use_as_albedo = true
		particle_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		box.material = particle_mat
		_shared_exhaust_mesh = box
	return _shared_exhaust_mesh

## Trails a spinning horn during a Zero-G Barrel Roll (matches the Look
## Book's cyan horn-glow trail). Emits continuously in world space — since
## the emission point spins with the body, the particles left behind form a
## visible streak on their own, no manual position-history buffer needed.
func _setup_horn_trail() -> void:
	if horn_trail == null:
		return
	horn_trail.emitting = false
	horn_trail.one_shot = false
	horn_trail.local_coords = false
	horn_trail.amount = 24
	horn_trail.lifetime = 0.45
	horn_trail.explosiveness = 0.0
	horn_trail.direction = Vector3.ZERO
	horn_trail.spread = 0.0
	horn_trail.initial_velocity_min = 0.0
	horn_trail.initial_velocity_max = 0.3
	horn_trail.gravity = Vector3.ZERO
	horn_trail.scale_amount_min = 0.1
	horn_trail.scale_amount_max = 0.18
	# world-space (local_coords=false) particles orbit far from this node's
	# own origin as the body spins, so the auto-estimated AABB is unreliable
	# here specifically — same flicker risk as the exhaust, bigger radius.
	horn_trail.visibility_aabb = AABB(Vector3(-4, -4, -4), Vector3(8, 8, 8))
	var grad := Gradient.new()
	grad.add_point(0.0, Color(0.44, 0.89, 0.77, 0.9))
	grad.add_point(1.0, Color(0.44, 0.89, 0.77, 0.0))
	horn_trail.color_ramp = grad
	horn_trail.mesh = _get_horn_trail_mesh()

func _get_horn_trail_mesh() -> SphereMesh:
	if _shared_horn_trail_mesh == null:
		var sphere := SphereMesh.new()
		sphere.radial_segments = 6
		sphere.rings = 3
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.vertex_color_use_as_albedo = true
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sphere.material = mat
		_shared_horn_trail_mesh = sphere
	return _shared_horn_trail_mesh

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return

	var input_dir := _get_input_dir(delta)

	_drift_time += delta
	var passive_drift := sin(_drift_time * drift_freq + _drift_seed) * drift_strength
	rotate_y((-input_dir.x * turn_speed + passive_drift) * delta)

	var forward := -global_transform.basis.z
	var target_speed := -input_dir.y * max_speed
	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	var desired_velocity := forward * target_speed
	horizontal_velocity = horizontal_velocity.move_toward(desired_velocity, acceleration * delta)
	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z

	_ability_cooldown_timer = max(0.0, _ability_cooldown_timer - delta)
	if _wants_ability(delta) and _ability_cooldown_timer <= 0.0:
		_use_ability(forward)

	if is_on_floor():
		if is_local_player and Input.is_action_just_pressed("jump"):
			velocity.y = jump_velocity
	else:
		velocity.y -= gravity * delta

	_pre_slide_velocity = velocity
	move_and_slide()
	_check_collision_roll()

	# Yaw change this frame drives the head/tail whip below.
	if delta > 0.0:
		_turn_rate = wrapf(rotation.y - _prev_yaw, -PI, PI) / delta
	_prev_yaw = rotation.y

	var speed := Vector3(velocity.x, 0.0, velocity.z).length()
	_update_leg_rig(delta, speed)
	_update_roll(delta)
	_update_wacky_wobble(delta, speed)

func _get_input_dir(delta: float) -> Vector2:
	if is_local_player:
		return Vector2(
			Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
			Input.get_action_strength("move_back") - Input.get_action_strength("move_forward")
		)
	# Wandering AI: always pushes forward, with a slow noisy steer so bots
	# don't drive dead straight. A proportional pull back toward straight-
	# ahead (rotation.y == 0, the track's forward axis) keeps that wander —
	# plus the passive drift every pony gets — from accumulating into a
	# runaway spin that stalls the bot's forward progress; wall bumps are
	# still fine, they just can't out-spin their own steering forever.
	_ai_seed += delta
	var wander := sin(_ai_seed * 0.6) * 0.35 + sin(_ai_seed * 1.7 + 2.0) * 0.15
	# rotate_y() below applies -input.x * turn_speed, so this needs a
	# POSITIVE coefficient on rotation.y to net out as restoring feedback.
	var heading_correction := rotation.y * 0.6
	var steer := wander + heading_correction
	return Vector2(clamp(steer, -1.0, 1.0), -1.0)

func _wants_ability(delta: float) -> bool:
	if is_local_player:
		return Input.is_action_just_pressed("ability")
	_ai_ability_timer -= delta
	if _ai_ability_timer <= 0.0:
		_ai_ability_timer = randf_range(1.5, 4.0)
		return true
	return false

func _use_ability(forward: Vector3) -> void:
	velocity += forward * ability_dash_speed
	_ability_cooldown_timer = ability_cooldown
	_ability_flash = 1.0
	_roll_vel += Vector3(
		randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)
	) * ability_recoil_kick
	if exhaust != null:
		exhaust.restart()

## Called by RaceManager after reassigning multiplayer authority for this
## slot, since is_local_player is normally only read once in _ready().
func set_as_local_player(value: bool) -> void:
	is_local_player = value
	camera.current = value

func collect_food() -> void:
	food_collected += 1
	print("%s collected food (total: %d)" % [pony_name, food_collected])

## A hard hit starts a full Zero-G Barrel Roll: continuous multi-rotation
## spin around an axis derived from the collision normal crossed with
## incoming velocity, so it reads as tumbling from the impact rather than a
## generic shake. Purely visual — doesn't touch the actual collision
## response, so movement stays exactly as robust as before.
func _check_collision_roll() -> void:
	if get_slide_collision_count() == 0:
		return
	# Gate on both the active roll AND a post-roll cooldown — without this, a
	# pony resting continuously against a wall (very common: the guard rails
	# are always there) would retrigger a fresh multi-rotation roll on every
	# single physics tick it's in contact, instead of once per real impact.
	if _barrel_roll_timer > 0.0 or _barrel_roll_cooldown > 0.0:
		return
	var impact_speed := _pre_slide_velocity.length()
	if impact_speed <= collision_roll_threshold:
		return
	# Skip floor-like contacts (landing from a jump, settling at spawn) —
	# only a wall/bump/pony hit should trigger the roll. A collision normal
	# pointing mostly straight up is the ground plane, not an impact.
	var normal := _first_non_floor_normal()
	if normal == Vector3.ZERO:
		return
	var incoming := _pre_slide_velocity.normalized()
	var spin_axis := normal.cross(incoming)
	if spin_axis.length() < 0.05:
		spin_axis = Vector3.UP
	spin_axis = spin_axis.normalized()
	# Blend the impact-derived axis with a random one so hits don't all
	# tumble the same way — some roll along the body, some pitch it
	# end-over-end, some corkscrew across two axes at once.
	var random_axis := Vector3(
		randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)
	)
	if random_axis.length() < 0.05:
		random_axis = Vector3.RIGHT
	spin_axis = spin_axis.lerp(random_axis.normalized(), barrel_roll_axis_chaos * randf())
	if spin_axis.length() < 0.05:
		spin_axis = Vector3.UP
	_barrel_roll_axis = spin_axis.normalized() * randf_range(0.7, 1.45)
	_barrel_roll_timer = barrel_roll_duration * randf_range(0.8, 1.5)

func _first_non_floor_normal() -> Vector3:
	for i in get_slide_collision_count():
		var normal := get_slide_collision(i).get_normal()
		if normal.dot(Vector3.UP) < 0.7:
			return normal
	return Vector3.ZERO

func _update_roll(delta: float) -> void:
	_barrel_roll_cooldown = max(0.0, _barrel_roll_cooldown - delta)
	if horn_trail != null:
		horn_trail.emitting = _barrel_roll_timer > 0.0
	if _barrel_roll_timer > 0.0:
		_barrel_roll_timer -= delta
		_roll_angle += _barrel_roll_axis * barrel_roll_spin_speed * delta
		_roll_vel = _barrel_roll_axis * barrel_roll_spin_speed
		if _barrel_roll_timer <= 0.0:
			# Wrap to the small residual past the last full rotation so the
			# settle-phase spring below relaxes it, instead of unwinding the
			# whole multi-rotation spin backward.
			_roll_angle.x = wrapf(_roll_angle.x, -PI, PI)
			_roll_angle.y = wrapf(_roll_angle.y, -PI, PI)
			_roll_angle.z = wrapf(_roll_angle.z, -PI, PI)
			_barrel_roll_cooldown = barrel_roll_retrigger_cooldown
		return
	var rx := _spring_step(_roll_angle.x, _roll_vel.x, 0.0, roll_stiffness, roll_damping, delta)
	_roll_angle.x = rx.x
	_roll_vel.x = rx.y
	var ry := _spring_step(_roll_angle.y, _roll_vel.y, 0.0, roll_stiffness, roll_damping, delta)
	_roll_angle.y = ry.x
	_roll_vel.y = ry.y
	var rz := _spring_step(_roll_angle.z, _roll_vel.z, 0.0, roll_stiffness, roll_damping, delta)
	_roll_angle.z = rz.x
	_roll_vel.z = rz.y

## Two-bone walk cycle: a sine target per hip, sprung toward (not snapped),
## with the knee bending on a delayed phase so the leg reads as lifting and
## planting rather than swinging like a rigid pendulum. During an active
## Zero-G Barrel Roll, the legs flail on their own chaotic noise instead of
## the gait targets, matching the Look Book's "ragdoll in freefall" look.
func _update_leg_rig(delta: float, speed: float) -> void:
	if _leg_hips.is_empty():
		return
	var speed_ratio: float = clamp(speed / max_speed, 0.0, 1.0)
	var tumbling := _barrel_roll_timer > 0.0

	# Mid-tumble the springs go limp, so the legs stop tracking any pose and
	# just get dragged around by the body — the difference between legs
	# playing a flail animation and legs that have given up entirely.
	var limp: float = barrel_roll_limpness if tumbling else 1.0
	var hip_k: float = hip_stiffness * limp
	var hip_d: float = hip_damping * limp
	var knee_k: float = knee_stiffness * limp
	var knee_d: float = knee_damping * limp

	if tumbling:
		_flail_seed += delta * leg_swing_freq
	else:
		_walk_time += delta * leg_swing_freq * (0.3 + speed_ratio)

	for i in _leg_hips.size():
		var hip_target: float
		var knee_target: float
		if tumbling:
			# Each leg on its own frequency and axis mix, so they scatter
			# rather than flailing in formation.
			var f := _flail_seed * (1.3 + i * 0.37) + _leg_phase_offsets[i] * 2.0
			hip_target = sin(f) * barrel_roll_flail_amount
			knee_target = (sin(f * 1.7 + 1.0) * 0.5 + 0.5) * barrel_roll_flail_amount
			# Legs also splay sideways in a tumble instead of staying in the
			# sagittal plane.
			_leg_hips[i].rotation.z = sin(f * 0.63 + i) * barrel_roll_flail_amount * 0.4
		else:
			var phase := _walk_time + _leg_phase_offsets[i]
			# The idle term never scales to zero with speed, so legs keep
			# drifting in zero g at a standstill instead of locking rigid.
			var dangle := sin(_walk_time * 0.23 + i * 1.7) * leg_idle_dangle
			hip_target = sin(phase) * leg_swing_amplitude * speed_ratio + dangle
			knee_target = maxf(sin(phase - 0.6), 0.0) * knee_bend_amplitude * speed_ratio \
				+ absf(dangle) * 0.5
			_leg_hips[i].rotation.z = lerpf(_leg_hips[i].rotation.z, 0.0, clampf(delta * 4.0, 0.0, 1.0))

		var hr := _spring_step(_hip_angle[i], _hip_vel[i], hip_target, hip_k, hip_d, delta)
		_hip_angle[i] = hr.x
		_hip_vel[i] = hr.y
		_leg_hips[i].rotation.x = _hip_angle[i]

		var kr := _spring_step(_knee_angle[i], _knee_vel[i], knee_target, knee_k, knee_d, delta)
		_knee_angle[i] = kr.x
		_knee_vel[i] = kr.y
		_leg_knees[i].rotation.x = _knee_angle[i]

	_update_head_and_tail(delta, speed_ratio, tumbling)

## Head and tail chase a moving target through their own springs rather
## than being posed directly, so they lag the body, overshoot, and keep
## swinging after it stops — the swoosh. Turning throws them sideways
## (the whip), and a tumble throws them everywhere.
func _update_head_and_tail(delta: float, speed_ratio: float, tumbling: bool) -> void:
	var whip: float = clampf(_turn_rate * turn_whip, -1.6, 1.6)
	var limp: float = 0.45 if tumbling else 1.0
	var energy: float = 0.35 + speed_ratio
	if tumbling:
		energy = 1.8

	if _head != null:
		var head_target := Vector3(
			_head_pitch + sin(_walk_time * 0.9 + 0.6) * 0.22 * energy,
			-whip * 0.5,
			sin(_walk_time * 0.42) * 0.2 * energy + whip * 0.35
		)
		var hx := _spring_step(_head_angle.x, _head_vel.x, head_target.x, head_stiffness * limp, head_damping * limp, delta)
		var hy := _spring_step(_head_angle.y, _head_vel.y, head_target.y, head_stiffness * limp, head_damping * limp, delta)
		var hz := _spring_step(_head_angle.z, _head_vel.z, head_target.z, head_stiffness * limp, head_damping * limp, delta)
		_head_angle = Vector3(hx.x, hy.x, hz.x)
		_head_vel = Vector3(hx.y, hy.y, hz.y)
		_head.rotation = _head_angle

	if _tail != null:
		var sway: float = _tail_sway * tail_swoosh
		var tail_target := Vector3(
			sin(_walk_time * 0.5 + 1.1) * sway * 0.5 * energy,
			whip * 0.8,
			sin(_walk_time * 0.62) * sway * energy - whip * 0.9
		)
		var tx := _spring_step(_tail_angle.x, _tail_vel.x, tail_target.x, tail_stiffness * limp, tail_damping * limp, delta)
		var ty := _spring_step(_tail_angle.y, _tail_vel.y, tail_target.y, tail_stiffness * limp, tail_damping * limp, delta)
		var tz := _spring_step(_tail_angle.z, _tail_vel.z, tail_target.z, tail_stiffness * limp, tail_damping * limp, delta)
		_tail_angle = Vector3(tx.x, ty.x, tz.x)
		_tail_vel = Vector3(tx.y, ty.y, tz.y)
		_tail.rotation = _tail_angle

func _update_wacky_wobble(delta: float, speed: float) -> void:
	if visual == null:
		return
	var speed_ratio: float = clamp(speed / max_speed, 0.0, 1.0)
	_ability_flash = max(0.0, _ability_flash - delta * 2.0)
	_wobble_time += delta * wobble_speed * (0.3 + speed_ratio + _ability_flash * 2.0)
	var flash_boost := 1.0 + _ability_flash * 1.5
	visual.rotation.z = sin(_wobble_time) * wobble_amount * speed_ratio * flash_boost + _roll_angle.z
	visual.rotation.x = cos(_wobble_time * 0.5) * wobble_amount * 0.5 * speed_ratio * flash_boost + _roll_angle.x
	visual.rotation.y = _roll_angle.y
	visual.position.y = abs(sin(_wobble_time)) * bob_amount * speed_ratio * flash_boost

## Damped-harmonic-oscillator step, shared by the leg rig and the roll
## system: current/velocity spring toward target rather than snapping,
## giving lag/overshoot instead of perfectly periodic motion.
func _spring_step(current: float, velocity_in: float, target: float, stiffness: float, damping: float, dt: float) -> Vector2:
	var accel := (target - current) * stiffness - velocity_in * damping
	var new_vel := velocity_in + accel * dt
	var new_current := current + new_vel * dt
	return Vector2(new_current, new_vel)
