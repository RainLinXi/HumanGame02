extends Node
const PLAYER = preload("uid://c8404uokh3vyu")

var enet_peer := ENetMultiplayerPeer.new()

var PORT = 9999
var IP_ADDRESS = '127.0.0.1'

func start_server():
	enet_peer.create_server(PORT)
	multiplayer.multiplayer_peer = enet_peer
	multiplayer.peer_connected.connect(add_player)
	multiplayer.peer_disconnected.connect(remove_player)

	
func join_server():
	enet_peer.create_client(IP_ADDRESS, PORT)
	#当有新的peer连接时，新连接的客户端和其他客户端会收到通知
	#peer_connected 只监听添加其他的peer
	multiplayer.peer_connected.connect(add_player)
	
	multiplayer.peer_disconnected.connect(remove_player)
	
	#connected_to_server 是用来添加自己的
	multiplayer.connected_to_server.connect(on_connected_to_server)
	
	#正式确立连接关系
	multiplayer.multiplayer_peer = enet_peer
	
func on_connected_to_server():
	add_player(multiplayer.get_unique_id())

func add_player(peer_id: int):
	#新客户端也会收到此信号，此时对等体id为服务器（ID 为 1）
	if peer_id == 1:
		return
		
	var new_player = PLAYER.instantiate()
	new_player.name = str(peer_id)
	
	var rand_x = randf_range(-5.0, 5.0)
	var rand_z = randf_range(-5.0, 5.0)
	
	new_player.position = Vector3(rand_x, 1.0, rand_z)
	get_tree().current_scene.add_child(new_player, true)
	
func remove_player(peer_id: int):
	#代表主机host下线了
	if peer_id == 1:
		leave_server()
		
	var players: Array[Node] = get_tree().get_nodes_in_group('Players')
	var player_to_remove = players.find_custom(func(item): return item.name == str(peer_id))
	if player_to_remove != -1:
		players[player_to_remove].queue_free()
	
	
	multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	clean_up_signals()
	
	get_tree().reload_current_scene()
	
func clean_up_signals():
	multiplayer.peer_connected.disconnect(add_player)
	
	multiplayer.peer_disconnected.disconnect(remove_player)
	
	multiplayer.connected_to_server.disconnect(on_connected_to_server)

func leave_server():
	
	multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	clean_up_signals()
	
	get_tree().reload_current_scene()
