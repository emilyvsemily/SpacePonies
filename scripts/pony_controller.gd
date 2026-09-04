extends CharacterBody3D

## Gray-box vertical-slice movement controller.
## Locomotion is physics-driven (velocity + gravity via move_and_slide);
## the wobble/jank layer is a procedural bob applied to the visual mesh only,
## so it works regardless of a pony's leg count/body plan (see docs/design.md).
##
## Also drives a simple wandering AI mode (is_ai) so M2's bot ponies can
## reuse the exact same movement/ability code as the player.

@export var is_ai: bool = false
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

@onready var visual: Node3D = $Visual
@onready var camera: Camera3D = $SpringArm3D/Camera3D

var food_collected: int = 0

var _wobble_time: float = 0.0
var _ability_cooldown_timer: float = 0.0
var _ability_flash: float = 0.0

var _ai_seed: float = 0.0
var _ai_ability_timer: float = 0.0

var _drift_time: float = 0.0
var _drift_seed: float = 0.0

func _ready() -> void:
	camera.current = not is_ai
	_ai_seed = randf() * 1000.0
	_ai_ability_timer = randf_range(1.0, 3.0)
	_drift_seed = randf() * 1000.0

func _physics_process(delta: float) -> void:
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
		if not is_ai and Input.is_action_just_pressed("jump"):
			velocity.y = jump_velocity
	else:
		velocity.y -= gravity * delta

	move_and_slide()

	_update_wacky_wobble(delta, Vector3(velocity.x, 0.0, velocity.z).length())

func _get_input_dir(delta: float) -> Vector2:
	if not is_ai:
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
	if not is_ai:
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

func collect_food() -> void:
	food_collected += 1
	print("%s collected food (total: %d)" % [pony_name, food_collected])

func _update_wacky_wobble(delta: float, speed: float) -> void:
	if visual == null:
		return
	var speed_ratio: float = clamp(speed / max_speed, 0.0, 1.0)
	_ability_flash = max(0.0, _ability_flash - delta * 2.0)
	_wobble_time += delta * wobble_speed * (0.3 + speed_ratio + _ability_flash * 2.0)
	var flash_boost := 1.0 + _ability_flash * 1.5
	visual.rotation.z = sin(_wobble_time) * wobble_amount * speed_ratio * flash_boost
	visual.rotation.x = cos(_wobble_time * 0.5) * wobble_amount * 0.5 * speed_ratio * flash_boost
	visual.position.y = abs(sin(_wobble_time)) * bob_amount * speed_ratio * flash_boost
