extends Node2D

@onready var stone_sprite = $Stone/Sprite2D
@onready var drawing_viewport = $Stone/DrawingViewport
@onready var brush = $Stone/DrawingViewport/Brush
@onready var chisel = $Chisel

# UI 引用
@onready var restart_button = $GameOverUI/RestartButton
@onready var win_button = $GameOverUI/WinButton # 新增：成功按钮引用

# 区域节点引用
@onready var dead_zone = $DeadZone
@onready var checkpoints = $Checkpoints # 新增：成功点区域引用

func _ready():
	# 1. 初始 UI 设置
	if restart_button:
		restart_button.visible = false
		restart_button.pressed.connect(_on_restart_pressed)
	
	if win_button: # 新增：初始化成功按钮
		win_button.visible = false
		# 成功后点击按钮通常也是重新开始或下一关，这里设为重启
		win_button.pressed.connect(_on_restart_pressed)
	
	# 2. 刻刀初始位置强制设定
	if chisel:
		chisel.global_position = Vector2(630, 620)

	# 3. 禁区信号绑定 (失败判定)
	if dead_zone:
		dead_zone.body_entered.connect(_on_deadzone_hit)
		
	# 4. 成功点信号绑定 (胜利判定)
	if checkpoints:
		checkpoints.body_entered.connect(_on_checkpoints_hit)

	# 5. 多人联机角色分配
	if multiplayer.is_server():
		await get_tree().create_timer(0.5).timeout
		_assign_roles()
		multiplayer.peer_connected.connect(_assign_roles)
		multiplayer.peer_disconnected.connect(_assign_roles)
	
	# 匹配画布尺寸
	drawing_viewport.size = get_viewport_rect().size

func _assign_roles(_id = 0):
	var players = multiplayer.get_peers()
	players.append(1) 
	players.sort()
	for i in range(players.size()):
		if i < 2:
			rpc_id(players[i], "receive_role", i)

func _process(_delta: float) -> void:
	if chisel and brush:
		brush.position = chisel.global_position

@rpc("authority", "call_local", "reliable")
func receive_role(index):
	if chisel:
		chisel.set_player_role(index)

# --- 逻辑：撞击禁区 (失败) ---
func _on_deadzone_hit(body):
	if body == chisel or body.name == "Chisel":
		show_game_over()

# --- 逻辑：撞击检测点 (成功) ---
func _on_checkpoints_hit(body):
	if body == chisel or body.name == "Chisel":
		show_win_screen()

func show_game_over():
	if restart_button:
		restart_button.visible = true
		_play_pop_animation(restart_button)
	_freeze_chisel()

func show_win_screen():
	if win_button:
		win_button.visible = true
		_play_pop_animation(win_button)
	_freeze_chisel()

# 通用的弹出动画
func _play_pop_animation(target_node):
	target_node.scale = Vector2.ZERO
	var tween = create_tween()
	tween.tween_property(target_node, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_ELASTIC)

# 冻结刻刀的通用逻辑
func _freeze_chisel():
	if chisel:
		chisel.set_physics_process(false)
		chisel.set_process_input(false)
		if chisel.has_node("MoveSound"):
			chisel.get_node("MoveSound").stop()

func _on_restart_pressed():
	get_tree().reload_current_scene()
