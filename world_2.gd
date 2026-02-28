extends Node2D

@onready var chisel = $Chisel
@onready var brush = $Stone/DrawingViewport/Brush
@onready var drawing_viewport = $Stone/DrawingViewport
@onready var restart_button = $GameOverUI/RestartButton
@onready var win_button = $GameOverUI/WinButton
@onready var dead_zone = $DeadZone
@onready var checkpoints = $Checkpoints
@onready var path_2 = $Path2 # 假设你的路径节点叫 Path2

func _ready():
	restart_button.visible = false
	win_button.visible = false
	restart_button.pressed.connect(_on_restart_button_clicked)
	win_button.pressed.connect(_on_win_button_clicked) 
	
	if chisel:
		chisel.global_position = Vector2(160, 260)

	# 1. 视觉控制：只有 Host 才能看到路径
	if path_2:
		path_2.visible = multiplayer.is_server()

	# 2. 只有服务器处理逻辑
	if multiplayer.is_server():
		if dead_zone: dead_zone.body_entered.connect(_on_deadzone_hit)
		if checkpoints: checkpoints.body_entered.connect(_on_checkpoints_hit)
		
		await get_tree().create_timer(0.3).timeout
		_assign_special_roles()

	drawing_viewport.size = get_viewport_rect().size

# 第二关特殊分配：Join 玩家全向控制，Host 观察
func _assign_special_roles():
	var peers = multiplayer.get_peers()
	for id in peers:
		if id != 1:
			rpc_id(id, "receive_role", 99) # 99 代表全向控制
	rpc_id(1, "receive_role", -1) # Host 设为观察者

@rpc("authority", "call_local", "reliable")
func receive_role(index):
	if chisel:
		chisel.set_player_role(index)

# --- 按钮与同步逻辑 (保持一致) ---

func _on_restart_button_clicked():
	rpc_id(1, "request_restart")

func _on_win_button_clicked():
	# 这里如果是最后一关，可以写跳转回主菜单
	rpc_id(1, "request_restart") 

@rpc("any_peer", "call_local", "reliable")
func request_restart():
	if multiplayer.is_server():
		rpc("sync_reload_scene")

@rpc("authority", "call_local", "reliable")
func sync_reload_scene():
	get_tree().reload_current_scene()

func _on_deadzone_hit(body):
	if body.name == "Chisel" or body == chisel:
		rpc("sync_show_ui", "fail")

func _on_checkpoints_hit(body):
	if body.name == "Chisel" or body == chisel:
		rpc("sync_show_ui", "win")

@rpc("authority", "call_local", "reliable")
func sync_show_ui(type):
	if type == "fail": restart_button.visible = true
	else: win_button.visible = true
	_freeze_chisel()

func _freeze_chisel():
	chisel.set_physics_process(false)
	chisel.set_process_input(false)

func _process(_delta):
	if chisel and brush: brush.position = chisel.global_position
