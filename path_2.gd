extends Sprite2D

func _ready() -> void:
	# 强行等待一帧，确保多人游戏系统（multiplayer）已经完全连接并识别出身份
	await get_tree().process_frame
	
	# 如果当前不是服务器（也就是 Join 的人）
	if not multiplayer.is_server():
		self.visible = true
		print("服务端：检测到身份为 Join，保留路径引导图")
	else:
		# 彻底隐藏并禁用处理
		self.visible = false
		# 如果你担心它还是会闪现，直接在本地物理删除它
		self.queue_free()
		print("客户端：检测到身份为 Host，已移除路径引导图")
		
func _process(_delta: float) -> void:
	pass
