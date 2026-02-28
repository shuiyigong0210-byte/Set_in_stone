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
	# 1. UI 初始化
	restart_button.visible = false
	win_button.visible = false
	
	# 注意：如果你从之前的代码复制，确保这里没有特殊不可见字符（如多余的空格）
	restart_button.pressed.connect(_on_restart_button_clicked)
	win_button.pressed.connect(_on_win_button_clicked)
	
	# 2. 设定第二关初始位置
	if chisel:
		chisel.global_position = Vector2(160, 260)
		# 确保物理控制权
		chisel.set_multiplayer_authority(1)

	# --- 3. 调试与联网逻辑分流 ---
	
	# 如果是单机直接按 F6 运行（没有 peer）
	if multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		print("【Debug】检测到单机运行，自动分配全向控制权(99)")
		if chisel:
			chisel.set_player_role(99) # 这样你直接跑场景就能动了
	
	# 如果是正常的联机状态（Host 或 Join）
	else:
		if multiplayer.is_server():
			# 房主监听碰撞
			if dead_zone: dead_zone.body_entered.connect(_on_deadzone_hit)
			if checkpoints: checkpoints.body_entered.connect(_on_checkpoints_hit)
			
			# 等待 Join 玩家进入后分发角色
			await get_tree().create_timer(0.5).timeout
			_assign_special_roles()
		else:
			# Join 端：路径已经通过它自己的 Path2.gd 脚本隐藏了（如果有的话）
			pass

	drawing_viewport.size = get_viewport_rect().size

# --- 核心逻辑：按钮点击处理 (RPC 调用) ---

func _on_restart_button_clicked():
	# 如果是单机调试，直接重启
	if multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		get_tree().reload_current_scene()
	else:
		rpc_id(1, "request_restart")

func _on_win_button_clicked():
	if multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		get_tree().change_scene_to_file("res://lobby.tscn")
	else:
		rpc_id(1, "request_go_home")

# --- 核心逻辑：服务器同步指令 ---

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

# --- 判定与显示 ---

func _on_deadzone_hit(body):
	# 确保只在服务器判定，并排除非刻刀物体
	if body == chisel or body.name == "Chisel":
		rpc("sync_show_ui", "fail")

func _on_checkpoints_hit(body):
	if body == chisel or body.name == "Chisel":
		rpc("sync_show_ui", "win")

@rpc("authority", "call_local", "reliable")
func sync_show_ui(type):
	if type == "fail":
		restart_button.visible = true
		_pop_ui(restart_button)
	else:
		win_button.text = "返回大厅"
		win_button.visible = true
		_pop_ui(win_button)
	_freeze_chisel()

# --- 通用工具 ---

func _assign_special_roles():
	var peers = multiplayer.get_peers()
	# 服务器设为观察者 (-1)
	if chisel:
		chisel.set_player_role(-1)
	
	# 给 Join 玩家发送 99 角色
	for id in peers:
		if id != 1: 
			print("【Host】分配 99 给玩家: ", id)
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
