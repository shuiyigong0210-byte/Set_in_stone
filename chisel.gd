extends CharacterBody2D

@export var speed = 200.0
@export var friction = 0.1
@export var boundary_margin = 20.0

var inputs = {"up": 0, "down": 0, "left": 0, "right": 0}
var my_role = -1 # 0: 纵向(上下), 1: 横向(左右)

func _ready():
	global_position = Vector2(630, 620)
	# 检查全局 Debug 状态
	if GameConfig.is_debug_mode:
		print("DDEBUG Mode Active: Full Control Enabled")

func set_player_role(index):
	my_role = index
	# 如果不是 Debug 模式，才显示分工提示
	if !GameConfig.is_debug_mode:
		if index == 0:
			print("[Role] You are Vertical Pilot: Move UP/DOWN")
		elif index == 1:
			print("[Role] You are Horizontal Pilot: Move LEFT/RIGHT")

func _physics_process(_delta):
	# 只有房主（Authority）执行物理移动
	if is_multiplayer_authority():
		var dir = Vector2.ZERO
		
		if GameConfig.is_debug_mode:
			# --- DEBUG 逻辑：直接读取本地四个方向轴 ---
			dir.x = Input.get_axis("move_left", "move_right")
			dir.y = Input.get_axis("move_up", "move_down")
		else:
			# --- 正常联网逻辑：综合多名玩家的输入数据 ---
			dir.x = inputs["right"] - inputs["left"]
			dir.y = inputs["down"] - inputs["up"]

		# 执行移动逻辑
		if dir != Vector2.ZERO:
			velocity = dir.normalized() * speed
		else:
			velocity = velocity.lerp(Vector2.ZERO, friction)
			
		move_and_slide()
		_handle_move_sound()
		
		if velocity.length() > 0:
			# 计算目标角度
			var target_rotation = velocity.angle() + PI/2
			rotation = lerp_angle(rotation, target_rotation, 0.2)
			
		# 屏幕边界限制
		_apply_boundary_limit()

func _apply_boundary_limit():
	var screen_size = get_viewport_rect().size
	global_position.x = clamp(global_position.x, boundary_margin, screen_size.x - boundary_margin)
	global_position.y = clamp(global_position.y, boundary_margin, screen_size.y - boundary_margin)

func _input(_event):
	# 如果是 Debug 模式，不需要执行下方的 RPC 输入逻辑
	if GameConfig.is_debug_mode: return
	if my_role == -1: return

	# 正常联网分工逻辑
	if my_role == 0:
		handle_direction("move_up", "up")
		handle_direction("move_down", "down")
	elif my_role == 1:
		handle_direction("move_left", "left")
		handle_direction("move_right", "right")

func handle_direction(action: String, dir_name: String):
	if Input.is_action_just_pressed(action):
		rpc_id(1, "server_update_input", dir_name, 1)
	if Input.is_action_just_released(action):
		rpc_id(1, "server_update_input", dir_name, 0)

@rpc("any_peer", "call_local", "reliable")
func server_update_input(dir: String, val: int):
	if is_multiplayer_authority():
		inputs[dir] = val

func _handle_move_sound():
	# 检查刻刀是否在移动
	if velocity.length() > 1:
		if !$MoveSound.playing:
			$MoveSound.play()
	else:
		# 停下时停止声音
		if $MoveSound.playing:
			$MoveSound.stop()
