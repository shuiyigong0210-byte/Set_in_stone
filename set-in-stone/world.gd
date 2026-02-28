extends Node2D

@onready var stone_sprite = $Stone/Sprite2D
@onready var drawing_viewport = $Stone/DrawingViewport
@onready var brush = $Stone/DrawingViewport/Brush
@onready var chisel = $Chisel

func _ready():
	if multiplayer.is_server():
		# 给一点缓冲时间让客户端加载
		await get_tree().create_timer(0.5).timeout
		_assign_roles()
		
		multiplayer.peer_connected.connect(_assign_roles)
		multiplayer.peer_disconnected.connect(_assign_roles)
		
		# Match the drawing viewport's size with the current viewport's size
		drawing_viewport.size = get_viewport_rect().size

func _assign_roles(_id = 0):
	var players = multiplayer.get_peers()
	players.append(1) # 加入房主
	players.sort()
	
	for i in range(players.size()):
		if i < 2: # 只分配前两个人
			rpc_id(players[i], "receive_role", i)
			
func _process(delta: float) -> void:
	#var tex = drawing_viewport.get_texture()
	#stone_sprite.material.set_shader_parameter("trail_tex", tex)
	brush.position = chisel.global_position

@rpc("authority", "call_local", "reliable")
func receive_role(index):
	var chisel = get_node_or_null("Chisel")
	if chisel:
		chisel.set_player_role(index)
