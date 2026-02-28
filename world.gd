extends Node2D

@onready var stone_sprite = $Stone/Sprite2D
@onready var drawing_viewport = $Stone/DrawingViewport
@onready var brush = $Stone/DrawingViewport/Brush
@onready var chisel = $Chisel
# UI 引用
@onready var restart_button = $GameOverUI/RestartButton
# 你的 Area2D 禁区节点
@onready var dead_zone = $DeadZone

func _ready():
	# 1. 初始 UI 设置
	if restart_button:
		restart_button.visible = false
		restart_button.pressed.connect(_on_restart_pressed)
	
	# 2. 刻刀初始位置强制设定（爱心底部）
	if chisel:
		chisel.global_position = Vector2(630, 620)

	# 3. 禁区信号绑定
	# 只要 Chisel 碰到 DeadZone 节点下的任何碰撞形状，就会触发
	if dead_zone:
		dead_zone.body_entered.connect(_on_deadzone_hit)

	# 4. 多人联机角色分配
	if multiplayer.is_server():
		# 给一点缓冲时间让客户端加载
		await get_tree().create_timer(0.5).timeout
		_assign_roles()
		
		multiplayer.peer_connected.connect(_assign_roles)
		multiplayer.peer_disconnected.connect(_assign_roles)
	
	# 匹配画布尺寸
	drawing_viewport.size = get_viewport_rect().size

func _assign_roles(_id = 0):
	var players = multiplayer.get_peers()
	players.append(1) # 加入房主
	players.sort()
	
	for i in range(players.size()):
		if i < 2: # 只分配前两个人
			rpc_id(players[i], "receive_role", i)

func _process(_delta: float) -> void:
	# 让画笔位置跟随刻刀
	if chisel and brush:
		brush.position = chisel.global_position

@rpc("authority", "call_local", "reliable")
func receive_role(index):
	if chisel:
		chisel.set_player_role(index)

# --- 核心逻辑：撞击判定 ---
func _on_deadzone_hit(body):
	# 判断撞到的是不是刻刀
	if body == chisel or body.name == "Chisel":
		show_game_over()

func show_game_over():
	if restart_button:
		restart_button.visible = true
		# 弹窗动画效果
		restart_button.scale = Vector2.ZERO
		var tween = create_tween()
		tween.tween_property(restart_button, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_ELASTIC)
	
	# 冻结玩家操作和物理处理
	if chisel:
		chisel.set_physics_process(false)
		chisel.set_process_input(false)
		if chisel.has_node("MoveSound"):
			chisel.get_node("MoveSound").stop()

func _on_restart_pressed():
	# 点击按钮重新开始游戏
	get_tree().reload_current_scene()
