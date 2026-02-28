extends Control

var peer = ENetMultiplayerPeer.new()
var port = 8910

@onready var host_btn = $HostButton
@onready var join_btn = $JoinButton
@onready var start_btn = $StartButton
@onready var ip_input = $IPInput
@onready var debug_btn = $DebugButton # 确保你的场景里有这个按钮

func _ready():
	# 确保 ClickSound 节点存在再进行绑定
	if has_node("ClickSound"):
		# 遍历场景中所有的按钮
		for child in get_children():
			if child is Button:
				# 绑定点击音效
				child.pressed.connect(func(): $ClickSound.play())
	else:
		print("警告：没找到 ClickSound 节点，请检查场景树！")

	start_btn.visible = false
	host_btn.pressed.connect(_on_host_pressed)
	join_btn.pressed.connect(_on_join_pressed)
	start_btn.pressed.connect(_on_start_pressed)
	debug_btn.pressed.connect(_on_debug_pressed)
	
	multiplayer.connected_to_server.connect(_on_connection_success)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.peer_connected.connect(_on_peer_connected)

# --- 新增的 Debug 逻辑 ---
func _on_debug_pressed():
	# 1. 开启全局 Debug 标记（需要你已经建好 GameConfig.gd）
	GameConfig.is_debug_mode = true
	print("--- DEBUG 模式开启：一人控制四个方向 ---")
	
	# 2. Debug 模式本质上是本地房主，直接创建服务器
	var error = peer.create_server(port, 2)
	if error == OK:
		multiplayer.multiplayer_peer = peer
		# 3. Debug 模式不需要等别人，直接切换场景
		change_scene()
	else:
		print("Debug 模式启动失败: ", error)

# --- 原有的 Host/Join 逻辑 ---

func _on_host_pressed():
	# 房主模式不开启全局 Debug 标记
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

# --- 场景切换与回调 ---

func _on_connection_success():
	print("已成功连接到房主！")

func _on_connection_failed():
	print("连接房主失败。")
	host_btn.disabled = false
	join_btn.disabled = false

func _on_peer_connected(id):
	print("新玩家加入，ID: ", id)

func _on_start_pressed():
	# 正常多人模式，房主点击开始，通知所有人
	rpc("change_scene")

@rpc("authority", "call_local", "reliable")
func change_scene():
	get_tree().change_scene_to_file("res://world.tscn")
