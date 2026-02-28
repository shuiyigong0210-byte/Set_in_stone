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
	
	# 失败按钮：重启本关
	restart_button.pressed.connect(_on_restart_button_clicked)
	# 胜利按钮：返回首页
	win_button.pressed.connect(_on_win_button_clicked) 
	
	if chisel:
		chisel.global_position = Vector2(160, 260)

	# 2. 视觉控制：只有 Host 才能看到路径
	if path_2:
		path_2.visible = multiplayer.is_server()

	# 3. 只有服务器处理逻辑
	if multiplayer.is_server():
		if dead_zone: dead_zone.body_entered.connect(_on_deadzone_hit)
		if checkpoints: checkpoints.body_entered.connect(_on_checkpoints_hit)
		
		# 分配角色：Join 玩家全向控制(99)，Host 观察(-1)
		await get_tree().create_timer(0.3).timeout
		_assign_special_roles()

	drawing_viewport.size = get_viewport_rect().size

# --- 核心逻辑：按钮点击处理 ---

func _on_restart_button_clicked():
	rpc_id(1, "request_restart")

func _on_win_button_clicked():
	# 告诉服务器：玩家想要回首页了
	rpc_id(1, "request_go_home")

# --- 核心逻辑：服务器同步指令 ---

@rpc("any_peer", "call_local", "reliable")
func request_restart():
	if multiplayer.is_server():
		rpc("sync_reload_scene")

@rpc("any_peer", "call_local", "reliable")
func request_go_home():
	if multiplayer.is_server():
		# 服务器通知所有人跳回 Lobby 场景
		rpc("sync_change_scene", "res://lobby.tscn")

@rpc("authority", "call_local", "reliable")
func sync_reload_scene():
	get_tree().reload_current_scene()

@rpc("authority", "call_local", "reliable")
func sync_change_scene(path):
	get_tree().change_scene_to_file(path)

# --- 判定与显示 ---

func _on_deadzone_hit(body):
	if body.name == "Chisel" or body == chisel:
		rpc("sync_show_ui", "fail")

func _on_checkpoints_hit(body):
	if body.name == "Chisel" or body == chisel:
		rpc("sync_show_ui", "win")

@rpc("authority", "call_local", "reliable")
func sync_show_ui(type):
	if type == "fail":
		restart_button.visible = true
		_pop_ui(restart_button)
	else:
		win_button.text = "返回大厅" # 修改文字增加清晰度
		win_button.visible = true
		_pop_ui(win_button)
	_freeze_chisel()

# --- 通用工具 ---

func _assign_special_roles():
	var peers = multiplayer.get_peers()
	for id in peers:
		if id != 1: rpc_id(id, "receive_role", 99)
	rpc_id(1, "receive_role", -1)

@rpc("authority", "call_local", "reliable")
func receive_role(index):
	if chisel: chisel.set_player_role(index)

func _freeze_chisel():
	chisel.set_physics_process(false)
	chisel.set_process_input(false)
	if chisel.has_node("MoveSound"): chisel.get_node("MoveSound").stop()

func _pop_ui(node):
	node.scale = Vector2.ZERO
	create_tween().tween_property(node, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_ELASTIC)

func _process(_delta):
	if chisel and brush: brush.position = chisel.global_position
