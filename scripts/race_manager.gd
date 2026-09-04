extends Node3D

## Gray-box race manager: listens to the finish trigger and logs placements
## as each of the 4 ponies crosses. No UI yet — console output only,
## sufficient to verify the core race loop works end to end.

@export var finish_trigger_path: NodePath

var placements: Array = []

func _ready() -> void:
	var trigger := get_node_or_null(finish_trigger_path) as Area3D
	if trigger and trigger.has_signal("pony_finished"):
		trigger.pony_finished.connect(_on_pony_finished)

func _on_pony_finished(body: Node3D) -> void:
	if placements.has(body):
		return
	placements.append(body)
	print("Place %d: %s (food: %d)" % [placements.size(), body.pony_name, body.food_collected])
	if placements.size() >= 4:
		print("=== RACE COMPLETE ===")
		for i in placements.size():
			print("%d. %s" % [i + 1, placements[i].pony_name])
