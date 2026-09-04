extends Node3D

## Gray-box race manager: listens to the finish trigger and logs placements
## as each of the 4 ponies crosses. No UI yet — console output only,
## sufficient to verify the core race loop works end to end.

@export var finish_trigger_path: NodePath
@export var finish_banner_path: NodePath

var placements: Array = []
var _banner: Node = null

func _ready() -> void:
	var trigger := get_node_or_null(finish_trigger_path) as Area3D
	if trigger and trigger.has_signal("pony_finished"):
		trigger.pony_finished.connect(_on_pony_finished)
	_banner = get_node_or_null(finish_banner_path)

func _on_pony_finished(body: Node3D) -> void:
	if placements.has(body):
		return
	placements.append(body)
	print("Place %d: %s (food: %d)" % [placements.size(), body.pony_name, body.food_collected])
	if not body.is_ai and _banner and _banner.has_method("show_finished"):
		_banner.show_finished("FINISHED!")
	if placements.size() >= 4:
		print("=== RACE COMPLETE ===")
		for i in placements.size():
			print("%d. %s" % [i + 1, placements[i].pony_name])
