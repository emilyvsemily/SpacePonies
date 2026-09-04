extends Node3D

## Gray-box race manager: listens to the finish trigger and logs placements
## as each of the 4 ponies crosses. No UI yet — console output only,
## sufficient to verify the core race loop works end to end.
##
## Also does the M3 multiplayer slot assignment: the scene always has 4
## static pony slots (Pony/Bot1/Bot2/Bot3); when networked, each connected
## peer claims one slot (authority + is_local_player reassigned at runtime)
## and any leftover slots stay AI bots, host-authoritative by default.

@export var finish_trigger_path: NodePath
@export var finish_banner_path: NodePath
@export var pony_slot_paths: Array[NodePath] = [NodePath("Pony"), NodePath("Bot1"), NodePath("Bot2"), NodePath("Bot3")]

var placements: Array = []
var _banner: Node = null

func _ready() -> void:
	_assign_multiplayer_slots()

	var trigger := get_node_or_null(finish_trigger_path) as Area3D
	if trigger and trigger.has_signal("pony_finished"):
		trigger.pony_finished.connect(_on_pony_finished)
	_banner = get_node_or_null(finish_banner_path)

func _assign_multiplayer_slots() -> void:
	if not NetworkManager.is_networked():
		return
	var peers := NetworkManager.connected_peers.duplicate()
	peers.sort()
	var my_id := multiplayer.get_unique_id()
	for i in pony_slot_paths.size():
		var pony := get_node_or_null(pony_slot_paths[i])
		if pony == null:
			continue
		if i < peers.size():
			var peer_id: int = peers[i]
			pony.set_multiplayer_authority(peer_id)
			pony.set_as_local_player(peer_id == my_id)
			pony.pony_name = "Player %d" % peer_id
		else:
			pony.set_multiplayer_authority(1)
			pony.set_as_local_player(false)
		print("RaceManager: slot %d = %s (local=%s)" % [i, pony.pony_name, pony.is_local_player])

func _on_pony_finished(body: Node3D) -> void:
	if placements.has(body):
		return
	placements.append(body)
	print("Place %d: %s (food: %d)" % [placements.size(), body.pony_name, body.food_collected])
	if body.is_local_player and _banner and _banner.has_method("show_finished"):
		_banner.show_finished("FINISHED!")
	if placements.size() >= 4:
		print("=== RACE COMPLETE ===")
		for i in placements.size():
			print("%d. %s" % [i + 1, placements[i].pony_name])
