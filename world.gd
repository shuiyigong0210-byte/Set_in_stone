extends Node2D

@onready var chisel = $Chisel
@onready var brush = $Stone/DrawingViewport/Brush
@onready var drawing_viewport = $Stone/DrawingViewport
@onready var restart_button = $GameOverUI/RestartButton
@onready var win_button = $GameOverUI/WinButton
@onready var dead_zone = $DeadZone
@onready var checkpoints = $Checkpoints

func _ready():
	# 1. 初始化 UI 和位置
	restart_button.visible = false
	win_button.visible = false
	
	# 分别绑定失败重启和胜利跳转
	restart_button.pressed.connect(_on_restart_button_clicked)
	win_button.pressed.connect(_on_win_button_clicked) 
	
	if chisel:
		chisel.global_position = Vector2(630, 620)

	# 2. 只有服务器（Host）监听物理碰撞和分发角色
	if multiplayer.is_server():
		if dead_zone: dead_zone.body_entered.connect(_on_deadzone_hit)
		if checkpoints: checkpoints.body_entered.connect(_on_checkpoints_hit)
		
		# 重启场景后，立即重新给所有在线玩家分配角色
		await get_tree().create_timer(0.2).timeout 
		_assign_roles()
		
		if not multiplayer.peer_connected.is_connected(_assign_roles):
			multiplayer.peer_connected.connect(_assign_roles)

	drawing_viewport.size = get_viewport_rect().size

func _assign_roles(_id = 0):
	if not multiplayer.is_server(): return
	var players = multiplayer.get_peers()
	players.append(1) 
	players.sort()
	for i in range(players.size()):
		if i < 2:
			rpc_id(players[i], "receive_role", i)

@rpc("authority", "call_local", "reliable")
func receive_role(index):
	if chisel:
		chisel.set_player_role(index)

# --- 核心逻辑：按钮点击处理 ---

func _on_restart_button_clicked():
	$ClickSound.play()
	# 请求服务器执行全体重启
	rpc_id(1, "request_restart")

func _on_win_button_clicked():
	$ClickSound.play()
	# 请求服务器执行全体跳转
	rpc_id(1, "request_next_level")

# --- 核心逻辑：服务器同步指令 ---

@rpc("any_peer", "call_local", "reliable")
func request_restart():
	if multiplayer.is_server():
		rpc("sync_reload_scene")

@rpc("any_peer", "call_local", "reliable")
func request_next_level():
	if multiplayer.is_server():
		# 房主控制跳转到 world_2
		rpc("sync_next_level", "res://world_2.tscn")

@rpc("authority", "call_local", "reliable")
func sync_reload_scene():
	get_tree().reload_current_scene()

@rpc("authority", "call_local", "reliable")
func sync_next_level(scene_path):
	get_tree().change_scene_to_file(scene_path)

# --- 判定与同步逻辑 ---

func _on_deadzone_hit(body):
	$AudioStreamPlayer.stop()
	$FailSound.play()
	if body.name == "Chisel" or body == chisel:
		rpc("sync_show_ui", "fail")
		

func _on_checkpoints_hit(body):
	$AudioStreamPlayer.stop()
	$WinSound.play()
	if body.name == "Chisel" or body == chisel:
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

func _freeze_chisel():
	chisel.set_physics_process(false)
	chisel.set_process_input(false)
	if chisel.has_node("MoveSound"): chisel.get_node("MoveSound").stop()

func _pop_ui(node):
	node.scale = Vector2.ZERO
	create_tween().tween_property(node, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_ELASTIC)

func _process(_delta):
	if chisel and brush: brush.position = chisel.global_position
