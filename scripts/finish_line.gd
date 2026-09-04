extends Area3D

## Gray-box finish trigger. Prints to the console for now — a proper
## race-complete UI/state comes with the M2 core race loop.

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("ponies"):
		print("%s crossed the finish line!" % body.name)
