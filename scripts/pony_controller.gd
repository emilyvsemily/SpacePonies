extends CharacterBody3D

## Gray-box vertical-slice movement controller.
## Locomotion is physics-driven (velocity + gravity via move_and_slide);
## the wobble/jank layer is a procedural bob applied to the visual mesh only,
## so it works regardless of a pony's leg count/body plan (see docs/design.md).

@export var acceleration: float = 18.0
@export var max_speed: float = 9.0
@export var turn_speed: float = 4.0
@export var jump_velocity: float = 6.0
@export var gravity: float = 20.0

@export var wobble_speed: float = 14.0
@export var wobble_amount: float = 0.12
@export var bob_amount: float = 0.08

@onready var visual: Node3D = $Visual

var _wobble_time: float = 0.0

func _physics_process(delta: float) -> void:
	var input_dir := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_back") - Input.get_action_strength("move_forward")
	)

	if input_dir.length() > 0.0:
		rotate_y(-input_dir.x * turn_speed * delta)

	var forward := -global_transform.basis.z
	var target_speed := -input_dir.y * max_speed
	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	var desired_velocity := forward * target_speed
	horizontal_velocity = horizontal_velocity.move_toward(desired_velocity, acceleration * delta)
	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z

	if is_on_floor():
		if Input.is_action_just_pressed("jump"):
			velocity.y = jump_velocity
	else:
		velocity.y -= gravity * delta

	move_and_slide()

	_update_wacky_wobble(delta, horizontal_velocity.length())

func _update_wacky_wobble(delta: float, speed: float) -> void:
	if visual == null:
		return
	var speed_ratio: float = clamp(speed / max_speed, 0.0, 1.0)
	_wobble_time += delta * wobble_speed * (0.3 + speed_ratio)
	visual.rotation.z = sin(_wobble_time) * wobble_amount * speed_ratio
	visual.rotation.x = cos(_wobble_time * 0.5) * wobble_amount * 0.5 * speed_ratio
	visual.position.y = abs(sin(_wobble_time)) * bob_amount * speed_ratio
