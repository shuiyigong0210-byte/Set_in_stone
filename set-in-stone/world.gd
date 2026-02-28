extends Node2D

func _ready():
	if multiplayer.is_server():
		# 给一点缓冲时间让客户端加载
		await get_tree().create_timer(0.5).timeout
		_assign_roles()
		
		multiplayer.peer_connected.connect(_assign_roles)
		multiplayer.peer_disconnected.connect(_assign_roles)

func _assign_roles(_id = 0):
	var players = multiplayer.get_peers()
	players.append(1) # 加入房主
	players.sort()
	
	for i in range(players.size()):
		if i < 2: # 只分配前两个人
			rpc_id(players[i], "receive_role", i)

@rpc("authority", "call_local", "reliable")
func receive_role(index):
	var chisel = get_node_or_null("Chisel")
	if chisel:
		chisel.set_player_role(index)
