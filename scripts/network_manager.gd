extends Node

enum MULTIPLAYER_NETWORK_TYPE {ENET, STEAM}


var active_network_type: MULTIPLAYER_NETWORK_TYPE = MULTIPLAYER_NETWORK_TYPE.ENET

func _build_multiplayer_network():

	match active_network_type:
		MULTIPLAYER_NETWORK_TYPE.ENET:
			pass
		MULTIPLAYER_NETWORK_TYPE.STEAM:
			pass
		_:
			print("no match for network type")

func start_server():
	match active_network_type:
		MULTIPLAYER_NETWORK_TYPE.ENET:
			EnetNetwork.start_server()
			pass
		MULTIPLAYER_NETWORK_TYPE.STEAM:
			pass
		_:
			print("no match for network type")

	
func join_server():
	match active_network_type:
		MULTIPLAYER_NETWORK_TYPE.ENET:
			EnetNetwork.join_server()
			pass
		MULTIPLAYER_NETWORK_TYPE.STEAM:
			pass
		_:
			print("no match for network type")

	
