extends Control

## Gray-box M3 lobby: host or join by IP on the local network, then the
## host starts the race for everyone. No matchmaking/relay — see
## docs/design.md for why real internet play is deferred.

@onready var host_button: Button = $CenterContainer/VBox/HostButton
@onready var ip_edit: LineEdit = $CenterContainer/VBox/JoinRow/IPEdit
@onready var join_button: Button = $CenterContainer/VBox/JoinRow/JoinButton
@onready var status_label: Label = $CenterContainer/VBox/StatusLabel
@onready var start_button: Button = $CenterContainer/VBox/StartButton

func _ready() -> void:
	start_button.hide()
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	start_button.pressed.connect(_on_start_pressed)
	NetworkManager.player_list_changed.connect(_update_status)
	_update_status()

func _on_host_pressed() -> void:
	if NetworkManager.host_game() == OK:
		_lock_connect_controls()
		start_button.show()
		_update_status()

func _on_join_pressed() -> void:
	var address := ip_edit.text.strip_edges()
	if address.is_empty():
		address = "127.0.0.1"
	if NetworkManager.join_game(address) == OK:
		_lock_connect_controls()
		_update_status()

func _on_start_pressed() -> void:
	NetworkManager.start_race()

func _lock_connect_controls() -> void:
	host_button.disabled = true
	join_button.disabled = true
	ip_edit.editable = false

func _update_status() -> void:
	if not NetworkManager.is_networked():
		status_label.text = "Host a race, or join one by IP."
		return
	status_label.text = "Connected: %d/%d ponies" % [NetworkManager.connected_peers.size(), NetworkManager.MAX_PLAYERS]
