extends Node2D

@onready var chisel = $Chisel
@onready var brush = $Stone/DrawingViewport/Brush
@onready var drawing_viewport = $Stone/DrawingViewport
@onready var restart_button = $GameOverUI/RestartButton
@onready var win_button = $GameOverUI/WinButton
@onready var dead_zone = $DeadZone
@onready var checkpoints = $Checkpoints
@onready var path_2 = $Path2

func _ready():
	# 1. UI Initialization
	restart_button.visible = false
	win_button.visible = false
	
	# Note: If copying from previous code, ensure there are no special invisible characters
	restart_button.pressed.connect(_on_restart_button_clicked)
	win_button.pressed.connect(_on_win_button_clicked)
	
	# 2. Set Level 2 initial position
	if chisel:
		chisel.global_position = Vector2(160, 260)
		# Ensure physics authority
		chisel.set_multiplayer_authority(1)

	# --- 3. Debug and Networking Logic Branching ---
	
	# If running locally via F6 (no peer)
	if multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		print("[Debug] Local run detected, auto-assigning omni-directional control (99)")
		if chisel:
			chisel.set_player_role(99) # Allows movement when running the scene directly
	
	# If in a normal networked state (Host or Join)
	else:
		if multiplayer.is_server():
			# Host listens for collisions
			if dead_zone: dead_zone.body_entered.connect(_on_deadzone_hit)
			if checkpoints: checkpoints.body_entered.connect(_on_checkpoints_hit)
			
			# Wait for Join player to enter then distribute roles
			await get_tree().create_timer(0.5).timeout
			_assign_special_roles()
		else:
			# Join side: Path is already hidden via its own Path2.gd script (if applicable)
			pass

	drawing_viewport.size = get_viewport_rect().size

# --- Core Logic: Button Click Handling (RPC Calls) ---

func _on_restart_button_clicked():
	$ClickSound.play()
	# If debug mode, reload directly
	if multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		get_tree().reload_current_scene()
	else:
		rpc_id(1, "request_restart")

func _on_win_button_clicked():
	$ClickSound.play()
	if multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		get_tree().change_scene_to_file("res://lobby.tscn")
	else:
		rpc_id(1, "request_go_home")

# --- Core Logic: Server Sync Commands ---

@rpc("any_peer", "call_local", "reliable")
func request_restart():
	if multiplayer.is_server():
		rpc("sync_reload_scene")

@rpc("any_peer", "call_local", "reliable")
func request_go_home():
	if multiplayer.is_server():
		rpc("sync_change_scene", "res://lobby.tscn")

@rpc("authority", "call_local", "reliable")
func sync_reload_scene():
	get_tree().reload_current_scene()

@rpc("authority", "call_local", "reliable")
func sync_change_scene(path):
	get_tree().change_scene_to_file(path)

# --- Judgement and Display ---

func _on_deadzone_hit(body):
	$AudioStreamPlayer.stop()
	$FailSound.play()
	# Ensure judgement only happens on server and excludes non-chisel objects
	if body == chisel or body.name == "Chisel":
		rpc("sync_show_ui", "fail")

func _on_checkpoints_hit(body):
	$AudioStreamPlayer.stop()
	$WinSound.play()
	if body == chisel or body.name == "Chisel":
		rpc("sync_show_ui", "win")
		

@rpc("authority", "call_local", "reliable")
func sync_show_ui(type):
	if type == "fail":
		restart_button.visible = true
		_pop_ui(restart_button)
	else:
		win_button.visible = true
		_pop_ui(win_button)
	_freeze_chisel()

# --- Utilities ---

func _assign_special_roles():
	var peers = multiplayer.get_peers()
	# Set server as observer (-1)
	if chisel:
		chisel.set_player_role(-1)
	
	# Send role 99 to Join players
	for id in peers:
		if id != 1: 
			print("[Host] Assigning 99 to player: ", id)
			rpc_id(id, "receive_role", 99) 

@rpc("authority", "call_local", "reliable")
func receive_role(index):
	if chisel:
		chisel.set_player_role(index)

func _freeze_chisel():
	if chisel:
		chisel.set_physics_process(false)
		chisel.set_process_input(false)
		if chisel.has_node("MoveSound"): chisel.get_node("MoveSound").stop()

func _pop_ui(node):
	node.scale = Vector2.ZERO
	var t = create_tween()
	t.tween_property(node, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_ELASTIC)

func _process(_delta):
	if chisel and brush: 
		brush.position = chisel.global_position
