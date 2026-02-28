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

# --- DEBUG 模式 ---
func _on_debug_pressed():
	GameConfig.is_debug_mode = true
	var error = peer.create_server(port, 2)
	if error == OK:
		multiplayer.multiplayer_peer = peer
		# Debug 模式下直接同步状态并跳场景
		rpc("sync_game_config", true)
		change_scene()
	else:
		print("Debug 模式启动失败: ", error)

# --- 房主模式 ---
func _on_host_pressed():
	GameConfig.is_debug_mode = false
	var error = peer.create_server(port, 2)
	if error == OK:
		multiplayer.multiplayer_peer = peer
		host_btn.disabled = true
		join_btn.disabled = true
		start_btn.visible = true
		print("房主已创建服务器，等待加入...")
	else:
		print("创建服务器失败: ", error)

# --- 加入模式 ---
func _on_join_pressed():
	GameConfig.is_debug_mode = false
	var ip = ip_input.text if ip_input.text != "" else "127.0.0.1"
	var error = peer.create_client(ip, port)
	if error == OK:
		multiplayer.multiplayer_peer = peer
		host_btn.disabled = true
		join_btn.disabled = true
		print("正在尝试连接: ", ip)
	else:
		print("创建客户端失败: ", error)

# --- 核心同步逻辑 ---

func _on_start_pressed():
	# 房主开始前，先确保所有人的配置一致
	rpc("sync_game_config", GameConfig.is_debug_mode)
	# 通知所有人切换场景
	rpc("change_scene")

@rpc("authority", "call_local", "reliable")
func sync_game_config(debug_state):
	# 这一步非常重要：确保所有客户端都知道现在是不是 Debug 模式
	GameConfig.is_debug_mode = debug_state
	print("同步全局配置：Debug 模式 = ", debug_state)

@rpc("authority", "call_local", "reliable")
func change_scene():
	get_tree().change_scene_to_file("res://world.tscn")

# --- 回调 ---
func _on_connection_success():
	print("已成功连接到房主！")

func _on_connection_failed():
	print("连接房主失败。")
	host_btn.disabled = false
	join_btn.disabled = false

func _on_peer_connected(id):
	print("玩家加入 ID: ", id)
	# 当有人加入时，如果房主已经在 Debug 模式，可以再次同步
	if multiplayer.is_server():
		rpc_id(id, "sync_game_config", GameConfig.is_debug_mode)
