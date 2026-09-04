extends Area3D

## Gray-box finish trigger. Emits a signal so a RaceManager can track
## placements; a proper race-complete UI comes later.

signal pony_finished(body)

var _already_finished: Array = []

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("ponies") and not _already_finished.has(body):
		_already_finished.append(body)
		pony_finished.emit(body)
