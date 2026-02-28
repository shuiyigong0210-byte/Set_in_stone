extends CharacterBody2D

@export var speed = 400.0
@export var friction = 0.1
@export var boundary_margin = 20.0 

var inputs = {"up": 0, "down": 0, "left": 0, "right": 0}
var my_role = -1 # 0: 纵向(上下), 1: 横向(左右)

func set_player_role(index):
	my_role = index
	if index == 0:
		print("你是【纵向领航员】：负责控制 上/下")
	elif index == 1:
		print("你是【横向领航员】：负责控制 左/右")

func _physics_process(_delta):
	if is_multiplayer_authority():
		var dir = Vector2.ZERO
		# 综合两名玩家的输入数据
		dir.x = inputs["right"] - inputs["left"]
		dir.y = inputs["down"] - inputs["up"]
		
		if dir != Vector2.ZERO:
			velocity = dir.normalized() * speed
		else:
			velocity = velocity.lerp(Vector2.ZERO, friction)
			
		move_and_slide()
		
		# 屏幕边界限制
		var screen_size = get_viewport_rect().size
		global_position.x = clamp(global_position.x, boundary_margin, screen_size.x - boundary_margin)
		global_position.y = clamp(global_position.y, boundary_margin, screen_size.y - boundary_margin)

func _input(_event):
	if my_role == -1: return

	# 根据角色过滤按键
	if my_role == 0:
		# 只有 0 号玩家能发送上下指令
		handle_direction("move_up", "up")
		handle_direction("move_down", "down")
	elif my_role == 1:
		# 只有 1 号玩家能发送左右指令
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
