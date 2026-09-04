extends Node

## Autoload. Thin host/join layer over Godot's high-level multiplayer API.
## Gray-box M3: same-network play only (direct IP). Real internet play
## across NATs (relay/matchmaking) is a known deferred problem — see
## docs/design.md.

const PORT := 8910
const MAX_PLAYERS := 4
const RACE_SCENE := "res://scenes/Main.tscn"
const LOBBY_SCENE := "res://scenes/ui/NetworkLobby.tscn"

signal player_list_changed

## Peer IDs currently connected, host (1) always included once hosting/joined.
var connected_peers: Array = []

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	_check_cmdline_autostart()

func host_game() -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, MAX_PLAYERS)
	if err != OK:
		push_warning("host_game failed: %s" % err)
		return err
	multiplayer.multiplayer_peer = peer
	connected_peers = [1]
	player_list_changed.emit()
	return OK

func join_game(address: String) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, PORT)
	if err != OK:
		push_warning("join_game failed: %s" % err)
		return err
	multiplayer.multiplayer_peer = peer
	return OK

func start_race() -> void:
	if not multiplayer.is_server():
		return
	_start_race_rpc.rpc()

@rpc("authority", "call_local", "reliable")
func _start_race_rpc() -> void:
	get_tree().change_scene_to_file(RACE_SCENE)

func is_networked() -> bool:
	return multiplayer.multiplayer_peer != null

func _on_peer_connected(id: int) -> void:
	if not connected_peers.has(id):
		connected_peers.append(id)
	print("NetworkManager: peer %d connected (%d/%d)" % [id, connected_peers.size(), MAX_PLAYERS])
	player_list_changed.emit()

func _on_peer_disconnected(id: int) -> void:
	connected_peers.erase(id)
	player_list_changed.emit()

func _on_connected_to_server() -> void:
	if not connected_peers.has(1):
		connected_peers.append(1)
	if not connected_peers.has(multiplayer.get_unique_id()):
		connected_peers.append(multiplayer.get_unique_id())
	player_list_changed.emit()

func _on_connection_failed() -> void:
	push_warning("Connection failed")
	multiplayer.multiplayer_peer = null

func _on_server_disconnected() -> void:
	push_warning("Server disconnected")
	multiplayer.multiplayer_peer = null
	connected_peers.clear()
	get_tree().change_scene_to_file(LOBBY_SCENE)

## Headless/automated-testing entry point: `--host` or `--join=127.0.0.1`
## on the command line, so two Godot processes can connect without a UI.
func _check_cmdline_autostart() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--host":
			call_deferred("_autostart_host")
		elif arg.begins_with("--join="):
			call_deferred("_autostart_join", arg.substr("--join=".length()))

func _autostart_host() -> void:
	if host_game() != OK:
		return
	await get_tree().create_timer(6.0).timeout
	start_race()

func _autostart_join(address: String) -> void:
	join_game(address)
