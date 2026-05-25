extends Node

# ============================================
# 信号定义 —— 传输层只负责通知，不做业务逻辑
# ============================================

## 服务器创建成功时发出，携带 host 的 peer_id（固定为 1）
signal server_started(host_peer_id: int)
## 本机成功连接到服务器时发出，携带自己的 peer_id
signal connected_to_server(peer_id: int)
## 有新玩家加入时发出（所有已连接端都会收到），携带新玩家的 peer_id
signal player_connected(peer_id: int)
## 有玩家断开时发出，携带断开玩家的 peer_id
signal player_disconnected(peer_id: int)
## 连接或创建服务器失败时发出，携带失败原因文字
signal connection_failed(reason: String)
## 本机主动离开或服务器关闭时发出
signal server_stopped

# ============================================
# 成员变量
# ============================================

## ENet 网络对等体对象，负责底层 UDP 通信
var enet_peer: ENetMultiplayerPeer

## 服务器监听端口，测试用硬编码
var port: int = 9999
## 要连接的服务器 IP 地址，测试用硬编码
var address: String = "127.0.0.1"


# ============================================
# 公开方法 —— 供 NetworkManager 调用
# ============================================

## 启动服务器（Host 端调用）
func start_server() -> void:
	# 创建新的 ENet 对等体实例
	enet_peer = ENetMultiplayerPeer.new()
	# 在指定端口创建服务器，失败则返回错误码（如端口被占用）
	var result = enet_peer.create_server(port)
	if result != OK:
		# 失败时发出信号，让 NetworkManager 决定怎么处理
		connection_failed.emit("创建服务器失败，端口 %d 可能被占用" % port)
		return

	# 将 peer 赋值给 multiplayer，激活多人系统
	multiplayer.multiplayer_peer = enet_peer
	# 监听：有新客户端连上服务器时触发（所有端都会收到通知）
	multiplayer.peer_connected.connect(_on_peer_connected)
	
	# 监听：有客户端断开连接时触发
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	# 通知 NetworkManager 服务器已就绪，把 host 的 peer_id 传过去用于生成 Player
	server_started.emit(multiplayer.get_unique_id())


## 加入服务器（Client 端调用）
func join_server() -> void:
	# 创建新的 ENet 对等体实例
	enet_peer = ENetMultiplayerPeer.new()
	# 以客户端模式连接到服务器
	var result = enet_peer.create_client(address, port)
	if result != OK:
		# 连接失败（服务器未启动、IP 错误等）
		connection_failed.emit("连接服务器失败: %s:%d" % [address, port])
		return

	# 监听：有其他人加入时触发（用于感知其他新玩家）
	multiplayer.peer_connected.connect(_on_peer_connected)
	# 监听：有其他人断开时触发
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	# 监听：本机成功连上服务器时触发（只触发一次，用来添加自己）
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	# 激活连接 —— 从这行开始，连接流程正式启动
	multiplayer.multiplayer_peer = enet_peer


## 离开服务器或关闭服务器
func leave_server() -> void:
	# 如果当前有活跃的多人连接
	if multiplayer.multiplayer_peer:
		# 关闭底层 UDP 连接，通知所有相关端
		multiplayer.multiplayer_peer.close()
		# 清空引用
		multiplayer.multiplayer_peer = null
	# 断开所有信号监听，防止残留回调
	_disconnect_signals()
	# 通知 NetworkManager 连接已关闭，让它处理场景重载等清理
	server_stopped.emit()


# ============================================
# 私有方法 —— 内部信号处理，只做转发
# ============================================

## 当有新对等体连接到 multiplayer 时触发（所有端都会收到）
## peer_id: 新加入玩家的唯一 ID，host 也会作为普通玩家被处理
func _on_peer_connected(peer_id: int) -> void:
	# 转发为自定义信号，让 NetworkManager 处理玩家生成
	player_connected.emit(peer_id)


## 当有对等体断开连接时触发（所有端都会收到）
## peer_id: 断开玩家的唯一 ID（为 1 表示 host 下线）
func _on_peer_disconnected(peer_id: int) -> void:
	# 转发为自定义信号，让 NetworkManager 处理玩家移除
	player_disconnected.emit(peer_id)


## 仅客户端触发 —— 本机成功连上服务器后调用
func _on_connected_to_server() -> void:
	# 通知 NetworkManager："我已连上，我的 ID 是 XXX"
	connected_to_server.emit(multiplayer.get_unique_id())


## 断开所有 multiplayer 信号连接，防止内存泄漏和重复回调
func _disconnect_signals() -> void:
	# 每次断开前先检查是否还连着，避免重复断开导致报错
	if multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.disconnect(_on_peer_connected)
	if multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.disconnect(_on_peer_disconnected)
	if multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.disconnect(_on_connected_to_server)
