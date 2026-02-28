extends Control

var peer = ENetMultiplayerPeer.new()
var port = 8910

@onready var host_btn = $HostButton
@onready var join_btn = $JoinButton
@onready var start_btn = $StartButton
@onready var ip_input = $IPInput

func _ready():
	start_btn.visible = false
	host_btn.pressed.connect(_on_host_pressed)
	join_btn.pressed.connect(_on_join_pressed)
	start_btn.pressed.connect(_on_start_pressed)
	
	# 连接成功的回调
	multiplayer.connected_to_server.connect(_on_connection_success)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.peer_connected.connect(_on_peer_connected)

func _on_host_pressed():
	var error = peer.create_server(port, 2)
	if error == OK:
		multiplayer.multiplayer_peer = peer
		host_btn.disabled = true
		join_btn.disabled = true
		start_btn.visible = true
		print("房主已创建服务器，等待加入...")
	else:
		print("创建服务器失败: ", error)

func _on_join_pressed():
	var ip = ip_input.text if ip_input.text != "" else "127.0.0.1"
	var error = peer.create_client(ip, port)
	if error == OK:
		multiplayer.multiplayer_peer = peer
		host_btn.disabled = true
		join_btn.disabled = true
		print("正在尝试连接: ", ip)
	else:
		print("创建客户端失败: ", error)

func _on_connection_success():
	print("已成功连接到房主！")

func _on_connection_failed():
	print("连接房主失败。")
	host_btn.disabled = false
	join_btn.disabled = false

func _on_peer_connected(id):
	print("新玩家加入，ID: ", id)

func _on_start_pressed():
	# 房主使用 RPC 通知所有人同步切换场景
	rpc("change_scene")

@rpc("authority", "call_local", "reliable")
func change_scene():
	get_tree().change_scene_to_file("res://world.tscn")
