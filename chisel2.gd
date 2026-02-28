extends CharacterBody2D

@export var speed = 200.0
@export var friction = 0.1
@export var boundary_margin = 20.0

# 存储所有玩家的输入状态（由服务器统一管理）
var inputs = {"up": 0, "down": 0, "left": 0, "right": 0}

# 角色定义：
# -1: 观察者（无控制权）
#  0: 纵向领航员（仅上下）
#  1: 横向领航员（仅左右）
# 99: 执行官（全方向控制 - 用于第二关）
var my_role = -1 

func _ready():
	# 初始位置由 World 脚本动态设定
	pass

# 由 World 脚本通过 RPC 调用，分配玩家职责
func set_player_role(index):
	my_role = index
	if !GameConfig.is_debug_mode:
		match index:
			0: print("【分工】你是纵向领航员：控制 上/下")
			1: print("【分工】你是横向领航员：控制 左/右")
			99: print("【分工】你是执行官：负责全方向控制（盲操模式）")
			-1: print("【分工】你是指挥官：负责观察并引导队友")

func _physics_process(_delta):
	# 只有服务器（房主）计算物理位移，确保两边刀的位置绝对同步
	if is_multiplayer_authority():
		var dir = Vector2.ZERO
		
		if GameConfig.is_debug_mode:
			# Debug 模式：本地直接读取所有方向
			dir.x = Input.get_axis("move_left", "move_right")
			dir.y = Input.get_axis("move_up", "move_down")
		else:
			# 正常模式：根据 inputs 字典计算合力（inputs 由各客户端 RPC 传来）
			dir.x = inputs["right"] - inputs["left"]
			dir.y = inputs["down"] - inputs["up"]

		# 基础移动逻辑
		if dir != Vector2.ZERO:
			velocity = dir.normalized() * speed
		else:
			velocity = velocity.lerp(Vector2.ZERO, friction)
			
		move_and_slide()
		
		# 处理声音
		_handle_move_sound()
		
		# 处理旋转：让刀尖指向移动方向
		if velocity.length() > 0:
			var target_rotation = velocity.angle() + PI/2
			rotation = lerp_angle(rotation, target_rotation, 0.2)
			
		# 限制在屏幕内，防止刀飞出视野
		_apply_boundary_limit()

func _apply_boundary_limit():
	var screen_size = get_viewport_rect().size
	global_position.x = clamp(global_position.x, boundary_margin, screen_size.x - boundary_margin)
	global_position.y = clamp(global_position.y, boundary_margin, screen_size.y - boundary_margin)

func _input(_event):
	# Debug 模式或未分配角色时，不执行联网输入逻辑
	if GameConfig.is_debug_mode or my_role == -1: return

	# 根据分配到的角色，决定监听哪些按键
	if my_role == 0: # 纵向控制
		handle_direction("move_up", "up")
		handle_direction("move_down", "down")
	elif my_role == 1: # 横向控制
		handle_direction("move_left", "left")
		handle_direction("move_right", "right")
	elif my_role == 99: # 全向控制 (Scene 2 专用)
		handle_direction("move_up", "up")
		handle_direction("move_down", "down")
		handle_direction("move_left", "left")
		handle_direction("move_right", "right")

# 将本地按键动作转换为 RPC 信号发给服务器
func handle_direction(action: String, dir_name: String):
	if Input.is_action_just_pressed(action):
		rpc_id(1, "server_update_input", dir_name, 1)
	if Input.is_action_just_released(action):
		rpc_id(1, "server_update_input", dir_name, 0)

# 服务器接收输入更新
@rpc("any_peer", "call_local", "reliable")
func server_update_input(dir: String, val: int):
	if is_multiplayer_authority():
		inputs[dir] = val

func _handle_move_sound():
	if velocity.length() > 10: # 有明显位移时播放
		if has_node("MoveSound") and !$MoveSound.playing:
			$MoveSound.play()
	else:
		if has_node("MoveSound") and $MoveSound.playing:
			$MoveSound.stop()
