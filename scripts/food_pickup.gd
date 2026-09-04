extends Area3D

## Gray-box food pickup. Collection only for M2 — the zero-G feeding
## mechanic that spends this food back at the stable is M4 work.

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("ponies") and body.has_method("collect_food"):
		body.collect_food()
		queue_free()
