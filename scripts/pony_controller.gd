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

## Walk-cycle leg rig. Phase offsets are irregular on purpose — these legs
## are mismatched, they shouldn't step in a clean tripod gait.
@export var leg_swing_freq: float = 9.0
@export var leg_swing_amplitude: float = 0.9
@export var knee_bend_amplitude: float = 1.1
@export var hip_stiffness: float = 90.0
@export var hip_damping: float = 9.0
@export var knee_stiffness: float = 55.0
@export var knee_damping: float = 5.0

## Collision/ability "roll" reaction: an impulse-driven spring on the whole
## visual rig, always relaxing back toward neutral.
@export var roll_stiffness: float = 18.0
@export var roll_damping: float = 3.2
@export var collision_roll_threshold: float = 3.0
@export var collision_roll_scale: float = 0.16

@onready var visual: Node3D = $Visual
@onready var camera: Camera3D = $SpringArm3D/Camera3D
@onready var sync: MultiplayerSynchronizer = $MultiplayerSynchronizer
@onready var exhaust: CPUParticles3D = $Visual/Exhaust

## The glTF import wraps our exported "PonyRig" group in an extra generic
## scene-root node, hence the double nesting (RigInstance/PonyRig/...).
@onready var _leg_hips: Array[Node3D] = [
	$Visual/RigInstance/PonyRig/Leg1Hip,
	$Visual/RigInstance/PonyRig/Leg2Hip,
	$Visual/RigInstance/PonyRig/Leg3Hip
]
@onready var _leg_knees: Array[Node3D] = [
	$Visual/RigInstance/PonyRig/Leg1Hip/Leg1Knee,
	$Visual/RigInstance/PonyRig/Leg2Hip/Leg2Knee,
	$Visual/RigInstance/PonyRig/Leg3Hip/Leg3Knee
]

var food_collected: int = 0

var _wobble_time: float = 0.0
var _ability_cooldown_timer: float = 0.0
var _ability_flash: float = 0.0

var _ai_seed: float = 0.0
var _ai_ability_timer: float = 0.0

var _drift_time: float = 0.0
var _drift_seed: float = 0.0

var _walk_time: float = 0.0
var _leg_phase_offsets: Array[float] = [0.0, 2.3, 4.1]
var _hip_angle: Array[float] = [0.0, 0.0, 0.0]
var _hip_vel: Array[float] = [0.0, 0.0, 0.0]
var _knee_angle: Array[float] = [0.0, 0.0, 0.0]
var _knee_vel: Array[float] = [0.0, 0.0, 0.0]

var _roll_angle: Vector3 = Vector3.ZERO
var _roll_vel: Vector3 = Vector3.ZERO
var _pre_slide_velocity: Vector3 = Vector3.ZERO

func _ready() -> void:
	camera.current = is_local_player
	_ai_seed = randf() * 1000.0
	_ai_ability_timer = randf_range(1.0, 3.0)
	_drift_seed = randf() * 1000.0
	_setup_exhaust()

	var config := SceneReplicationConfig.new()
	config.add_property(NodePath(".:position"))
	config.add_property(NodePath(".:rotation"))
	sync.replication_config = config

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
	var grad := Gradient.new()
	grad.add_point(0.0, Color(1.0, 0.85, 0.2, 1.0))
	grad.add_point(0.5, Color(1.0, 0.5, 0.1, 1.0))
	grad.add_point(1.0, Color(0.3, 0.8, 0.7, 0.0))
	exhaust.color_ramp = grad

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

	var speed := Vector3(velocity.x, 0.0, velocity.z).length()
	_update_leg_rig(delta, speed)
	_update_roll_spring(delta)
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

## A hard hit kicks the roll spring, direction based on the collision normal
## crossed with incoming velocity, so it reads as tumbling from the impact
## rather than a generic shake. Purely visual — doesn't touch the actual
## collision response, so movement stays exactly as robust as before.
func _check_collision_roll() -> void:
	if get_slide_collision_count() == 0:
		return
	var impact_speed := _pre_slide_velocity.length()
	if impact_speed <= collision_roll_threshold:
		return
	var collision := get_slide_collision(0)
	var normal := collision.get_normal()
	var incoming := _pre_slide_velocity.normalized()
	var spin_axis := normal.cross(incoming)
	if spin_axis.length() < 0.05:
		spin_axis = Vector3.UP
	spin_axis = spin_axis.normalized()
	_roll_vel += spin_axis * impact_speed * collision_roll_scale

func _update_roll_spring(delta: float) -> void:
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
## planting rather than swinging like a rigid pendulum.
func _update_leg_rig(delta: float, speed: float) -> void:
	if _leg_hips.is_empty():
		return
	var speed_ratio: float = clamp(speed / max_speed, 0.0, 1.0)
	_walk_time += delta * leg_swing_freq * (0.3 + speed_ratio)
	for i in _leg_hips.size():
		var phase := _walk_time + _leg_phase_offsets[i]

		var hip_target := sin(phase) * leg_swing_amplitude * speed_ratio
		var hr := _spring_step(_hip_angle[i], _hip_vel[i], hip_target, hip_stiffness, hip_damping, delta)
		_hip_angle[i] = hr.x
		_hip_vel[i] = hr.y
		_leg_hips[i].rotation.x = _hip_angle[i]

		var knee_target: float = maxf(sin(phase - 0.6), 0.0) * knee_bend_amplitude * speed_ratio
		var kr := _spring_step(_knee_angle[i], _knee_vel[i], knee_target, knee_stiffness, knee_damping, delta)
		_knee_angle[i] = kr.x
		_knee_vel[i] = kr.y
		_leg_knees[i].rotation.x = _knee_angle[i]

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
