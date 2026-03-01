extends Control

var peer = ENetMultiplayerPeer.new()
var port = 8910

@onready var host_btn = $HostButton
@onready var join_btn = $JoinButton
@onready var start_btn = $StartButton
@onready var ip_input = $IPInput
@onready var debug_btn = $DebugButton

func _ready():
	start_btn.visible = false
	host_btn.pressed.connect(_on_host_pressed)
	join_btn.pressed.connect(_on_join_pressed)
	start_btn.pressed.connect(_on_start_pressed)
	debug_btn.pressed.connect(_on_debug_pressed)
	
	multiplayer.connected_to_server.connect(_on_connection_success)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.peer_connected.connect(_on_peer_connected)

# --- DEBUG Mode ---
func _on_debug_pressed():
	GameConfig.is_debug_mode = true
	var error = peer.create_server(port, 2)
	if error == OK:
		multiplayer.multiplayer_peer = peer
		# Sync state and switch scenes immediately in Debug mode
		rpc("sync_game_config", true)
		change_scene()
	else:
		print("Debug mode failed to start: ", error)

# --- Host Mode ---
func _on_host_pressed():
	$ClickSound.play()
	GameConfig.is_debug_mode = false
	var error = peer.create_server(port, 2)
	if error == OK:
		multiplayer.multiplayer_peer = peer
		host_btn.disabled = true
		join_btn.disabled = true
		start_btn.visible = true
		print("Host server created, waiting for players to join...")
	else:
		print("Failed to create server: ", error)

# --- Join Mode ---
func _on_join_pressed():
	$ClickSound.play()
	GameConfig.is_debug_mode = false
	var ip = ip_input.text if ip_input.text != "" else "127.0.0.1"
	var error = peer.create_client(ip, port)
	if error == OK:
		multiplayer.multiplayer_peer = peer
		host_btn.disabled = true
		join_btn.disabled = true
		print("Attempting to connect: ", ip)
	else:
		print("Failed to create client: ", error)

# --- Core Sync Logic ---

func _on_start_pressed():
	$ClickSound.play()
	# Ensure all players have consistent configurations before the Host starts
	rpc("sync_game_config", GameConfig.is_debug_mode)
	# Notify everyone to switch scenes
	rpc("change_scene")

@rpc("authority", "call_local", "reliable")
func sync_game_config(debug_state):
	# Crucial step: ensure all clients know if Debug mode is active
	GameConfig.is_debug_mode = debug_state
	print("Syncing global config: Debug Mode = ", debug_state)

@rpc("authority", "call_local", "reliable")
func change_scene():
	get_tree().change_scene_to_file("res://world.tscn")

# --- Callbacks ---
func _on_connection_success():
	print("Successfully connected to Host!")

func _on_connection_failed():
	print("Connection to Host failed.")
	host_btn.disabled = false
	join_btn.disabled = false

func _on_peer_connected(id):
	print("Player joined with ID: ", id)
	# If a player joins and Host is already in Debug mode, sync again
	if multiplayer.is_server():
		rpc_id(id, "sync_game_config", GameConfig.is_debug_mode)
