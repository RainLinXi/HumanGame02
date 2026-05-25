extends Node

# ============================================
# 枚举与常量
# ============================================

enum MULTIPLAYER_NETWORK_TYPE {ENET, STEAM}

## 预加载 World 场景，网络游戏开始时加载
const WORLD = preload("uid://bvdtdbtjkjrio")
## 预加载 Player 场景，玩家加入时动态生成
const PLAYER = preload("uid://c8404uokh3vyu")

## 当前活跃的网络类型，UI 或配置可通过它切换 ENet/Steam
var active_network_type: MULTIPLAYER_NETWORK_TYPE = MULTIPLAYER_NETWORK_TYPE.ENET


# ============================================
# 公开方法 —— 供 UI 调用
# ============================================

## Host 端入口：加载世界场景 → 启动服务器
func host_game() -> void:
	# 先将 World 场景挂到当前场景树上
	_add_world()
	# 根据当前网络类型委托给对应的传输层
	match active_network_type:
		MULTIPLAYER_NETWORK_TYPE.ENET:
			# 先绑定信号再启动，确保不会漏掉 server_started 等信号
			_bind_enet_signals()
			EnetNetwork.start_server()
		MULTIPLAYER_NETWORK_TYPE.STEAM:
			_bind_steam_signals()
			SteamNetwork.start_server()
		_:
			printerr("[NetworkManager] 未支持的网络类型: %s" % active_network_type)


## Client 端入口：加载世界场景 → 加入服务器
func join_game() -> void:
	# 先将 World 场景挂到当前场景树上
	_add_world()
	match active_network_type:
		MULTIPLAYER_NETWORK_TYPE.ENET:
			# 先绑定信号再加入，确保 connected_to_server 能被捕获
			_bind_enet_signals()
			EnetNetwork.join_server()
		MULTIPLAYER_NETWORK_TYPE.STEAM:
			_bind_steam_signals()
			SteamNetwork.join_server()
		_:
			printerr("[NetworkManager] 未支持的网络类型: %s" % active_network_type)

## 主动离开游戏（UI 中 Leave Game 按钮调用）
func leave_game() -> void:
	# 根据当前网络类型，委托对应传输层关闭连接
	match active_network_type:
		MULTIPLAYER_NETWORK_TYPE.ENET:
			EnetNetwork.leave_server()
		MULTIPLAYER_NETWORK_TYPE.STEAM:
			SteamNetwork.leave_server()
		_:
			printerr("[NetworkManager] 未支持的网络类型: %s" % active_network_type)


# ============================================
# 私有方法 —— 场景管理
# ============================================

## 实例化 World 场景并挂到当前场景树
func _add_world() -> void:
	var new_world = WORLD.instantiate()
	get_tree().current_scene.add_child(new_world)


# ============================================
# 私有方法 —— 信号绑定与解绑
# ============================================

## 将 EnetNetwork 的所有信号连接到本管理器的处理方法
func _bind_enet_signals() -> void:
	# 先解绑再绑定，防止重复连接同一个信号
	_unbind_enet_signals()

	EnetNetwork.server_started.connect(_on_server_started)
	EnetNetwork.connected_to_server.connect(_on_connected_to_server)
	EnetNetwork.player_connected.connect(_on_player_connected)
	EnetNetwork.player_disconnected.connect(_on_player_disconnected)
	EnetNetwork.connection_failed.connect(_on_connection_failed)
	EnetNetwork.server_stopped.connect(_on_server_stopped)


## 将 SteamNetwork 的所有信号连接到本管理器的处理方法（待 Steam 实现）
func _bind_steam_signals() -> void:
	# 先解绑再绑定，防止重复连接同一个信号
	_unbind_steam_signals()

	SteamNetwork.server_started.connect(_on_server_started)
	SteamNetwork.connected_to_server.connect(_on_connected_to_server)
	SteamNetwork.player_connected.connect(_on_player_connected)
	SteamNetwork.player_disconnected.connect(_on_player_disconnected)
	SteamNetwork.connection_failed.connect(_on_connection_failed)
	SteamNetwork.server_stopped.connect(_on_server_stopped)


## 解绑 EnetNetwork 全部信号，先检查 is_connected 再断开，避免重复断开报错
func _unbind_enet_signals() -> void:
	if EnetNetwork.server_started.is_connected(_on_server_started):
		EnetNetwork.server_started.disconnect(_on_server_started)
	if EnetNetwork.connected_to_server.is_connected(_on_connected_to_server):
		EnetNetwork.connected_to_server.disconnect(_on_connected_to_server)
	if EnetNetwork.player_connected.is_connected(_on_player_connected):
		EnetNetwork.player_connected.disconnect(_on_player_connected)
	if EnetNetwork.player_disconnected.is_connected(_on_player_disconnected):
		EnetNetwork.player_disconnected.disconnect(_on_player_disconnected)
	if EnetNetwork.connection_failed.is_connected(_on_connection_failed):
		EnetNetwork.connection_failed.disconnect(_on_connection_failed)
	if EnetNetwork.server_stopped.is_connected(_on_server_stopped):
		EnetNetwork.server_stopped.disconnect(_on_server_stopped)


## 解绑 SteamNetwork 全部信号，与 ENet 同理
func _unbind_steam_signals() -> void:
	if SteamNetwork.server_started.is_connected(_on_server_started):
		SteamNetwork.server_started.disconnect(_on_server_started)
	if SteamNetwork.connected_to_server.is_connected(_on_connected_to_server):
		SteamNetwork.connected_to_server.disconnect(_on_connected_to_server)
	if SteamNetwork.player_connected.is_connected(_on_player_connected):
		SteamNetwork.player_connected.disconnect(_on_player_connected)
	if SteamNetwork.player_disconnected.is_connected(_on_player_disconnected):
		SteamNetwork.player_disconnected.disconnect(_on_player_disconnected)
	if SteamNetwork.connection_failed.is_connected(_on_connection_failed):
		SteamNetwork.connection_failed.disconnect(_on_connection_failed)
	if SteamNetwork.server_stopped.is_connected(_on_server_stopped):
		SteamNetwork.server_stopped.disconnect(_on_server_stopped)


# ============================================
# 私有方法 —— 信号处理：玩家管理
# ============================================

## Host 端收到：服务器已启动，生成 host 自己的 Player 实体
func _on_server_started(host_peer_id: int) -> void:
	_spawn_player(host_peer_id)
	print("[NetworkManager] 服务器已启动，host peer_id=%d" % host_peer_id)


## Client 端收到：本机已成功连上服务器，生成"自己"的 Player
func _on_connected_to_server(peer_id: int) -> void:
	_spawn_player(peer_id)
	print("[NetworkManager] 我已连接到服务器，peer_id=%d" % peer_id)


## 所有端收到：有新玩家加入，生成其 Player 实体
func _on_player_connected(peer_id: int) -> void:
	_spawn_player(peer_id)
	print("[NetworkManager] 玩家 %d 加入了游戏" % peer_id)


## 所有端收到：有玩家断开，移除其 Player 实体
func _on_player_disconnected(peer_id: int) -> void:
	# 如果断开的是 host（id=1），说明服务器要关了
	if peer_id == 1:
		# 根据当前网络类型，委托对应传输层关闭连接
		match active_network_type:
			MULTIPLAYER_NETWORK_TYPE.ENET:
				EnetNetwork.leave_server()
			MULTIPLAYER_NETWORK_TYPE.STEAM:
				SteamNetwork.leave_server()
		return

	# 从场景中删除该玩家的实体
	_remove_player(peer_id)
	print("[NetworkManager] 玩家 %d 离开了游戏" % peer_id)


# ============================================
# 私有方法 —— 信号处理：连接状态
# ============================================

## 连接或创建服务器失败时收到
func _on_connection_failed(reason: String) -> void:
	# 打印错误原因，后续可改为 UI 弹窗提示
	printerr("[NetworkManager] 连接失败: %s" % reason)


## 服务器完全关闭后收到，清理场景回到主菜单
func _on_server_stopped() -> void:
	print("[NetworkManager] 服务器已关闭，返回主菜单")
	# 断开所有网络信号，防止残留回调
	match active_network_type:
		MULTIPLAYER_NETWORK_TYPE.ENET:
			_unbind_enet_signals()
		MULTIPLAYER_NETWORK_TYPE.STEAM:
			_unbind_steam_signals()
	# 重载当前场景 → 回到 Main 场景，即主菜单界面
	get_tree().reload_current_scene()


# ============================================
# 私有方法 —— 玩家节点的生成与移除
# ============================================

## 在随机位置实例化一个 Player 节点并挂到场景树
func _spawn_player(peer_id: int) -> void:
	var new_player = PLAYER.instantiate()
	# 用 peer_id 作为节点名
	# Player 的 _enter_tree 会读取 name 并调用 set_multiplayer_authority
	# 这样 MultiplayerSynchronizer 才知道该听谁的
	new_player.name = str(peer_id)

	# 随机生成位置，避免所有玩家出生点重叠
	var rand_x = randf_range(-5.0, 5.0)
	var rand_z = randf_range(-5.0, 5.0)
	new_player.position = Vector3(rand_x, 1.0, rand_z)

	# 挂到当前场景，第二个参数 true = 分配可读的节点名称
	get_tree().current_scene.add_child(new_player, true)


## 根据 peer_id 在场景中找到对应玩家节点并释放
func _remove_player(peer_id: int) -> void:
	# 从 "Players" 分组中查找名为 peer_id 的节点
	var players: Array[Node] = get_tree().get_nodes_in_group("Players")
	var index: int = players.find_custom(
		func(item: Node) -> bool: return item.name == str(peer_id)
	)
	# 找到了就释放该节点
	if index != -1:
		players[index].queue_free()
