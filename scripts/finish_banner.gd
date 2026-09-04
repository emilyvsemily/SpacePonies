extends CanvasLayer

## Gray-box "FINISHED!" popup for when the local player's pony crosses the
## finish line. Punches in big with an elastic overshoot, holds, then fades —
## deliberately overdone/janky rather than a clean UI transition.

@onready var label: Label = $CenterContainer/Label

func _ready() -> void:
	label.modulate.a = 0.0
	label.scale = Vector2.ZERO
	label.pivot_offset = label.size / 2.0

func show_finished(text: String = "FINISHED!") -> void:
	label.text = text
	label.pivot_offset = label.size / 2.0
	label.rotation = deg_to_rad(-6.0)
	label.modulate.a = 1.0
	label.scale = Vector2.ZERO

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_ELASTIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector2(1.15, 1.15), 0.5)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(label, "scale", Vector2.ONE, 0.2)
	tween.parallel().tween_property(label, "rotation", 0.0, 0.3)
	tween.tween_interval(1.3)
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(label, "modulate:a", 0.0, 0.6)
