extends Node

# ============================================
# 信号定义 —— Lobby 阶段（供 MainMenu UI 监听）
# ============================================

## Lobby 创建成功时发出，携带 lobby_id 用于显示和分享
signal lobby_created(p_lobby_id: int)
## 成功加入一个 Lobby 时发出，携带 lobby_id
signal lobby_joined(p_lobby_id: int)
## 离开 Lobby 时发出
signal lobby_left
## 有成员进入 Lobby 时发出，携带成员的 Steam ID 和昵称
signal lobby_member_joined(p_steam_id: int, p_name: String)
## 有成员离开 Lobby 时发出，携带成员的 Steam ID
signal lobby_member_left(p_steam_id: int)
## 加入 Lobby 失败时发出，携带失败原因
signal lobby_join_failed(reason: String)
## Host 点击"开始游戏"后，客户端收到此信号，携带 host 的 Steam ID 用于建立 P2P 连接
signal game_start_announced(host_steam_id: int)

# ============================================
# 信号定义 —— 游戏阶段（与 EnetNetwork 一致，供 NetworkManager 统一监听）
# ============================================

## 服务器创建成功时发出，携带 host 的 Steam ID 作为 peer_id
signal server_started(host_peer_id: int)
## 本机成功连接到服务器时发出，携带自己的 Steam ID
signal connected_to_server(peer_id: int)
## 有新玩家加入时发出，携带新玩家的 Steam ID
signal player_connected(peer_id: int)
## 有玩家断开时发出，携带断开玩家的 Steam ID
signal player_disconnected(peer_id: int)
## 连接或创建服务器失败时发出，携带失败原因文字
signal connection_failed(reason: String)
## 本机主动离开或服务器关闭时发出
signal server_stopped

var is_owned: bool = false
var steam_app_id: int = 480
var steam_id: int = 0
var steam_username: String = ""

var lobby_id = 0
var lobby_max_members = 4
## 当客户端时，记录 host 的 Steam ID，用于建立 P2P 连接
var host_steam_id: int = 0

func _init() -> void:
	OS.set_environment("SteamAppId", str(steam_app_id))
	OS.set_environment("SteamGameId", str(steam_app_id))

func _process(_delta: float) -> void:
	Steam.run_callbacks()

func _ready() -> void:
	# 启动时自动初始化 Steam，失败不阻塞（ENet 仍可用）
	initialize_steam()

	# 将 GodotSteam 的底层回调连接到 SteamNetwork 的处理方法
	Steam.lobby_created.connect(_on_steam_lobby_created)
	Steam.lobby_joined.connect(_on_steam_lobby_joined)
	Steam.lobby_chat_update.connect(_on_steam_lobby_chat_update)
	Steam.lobby_data_update.connect(_on_steam_lobby_data_update)
	Steam.join_requested.connect(_on_steam_join_requested)

func initialize_steam():
	var initialize_response: Dictionary = Steam.steamInitEx()
	print("Did Steam initialize?: %s " % initialize_response)

	if initialize_response['status'] > Steam.STEAM_API_INIT_RESULT_OK:
		print("[SteamNetwork] Steam 初始化失败: %s" % initialize_response)
		return

	is_owned = Steam.isSubscribed()
	steam_id = Steam.getSteamID()
	steam_username = Steam.getPersonaName()

	print("steam id: %s" % steam_id)
	print("steam name: %s" % steam_username)
	
	if is_owned == false:
		print("[SteamNetwork] 用户未拥有此游戏")
		return


# ============================================
# 公开方法 —— Lobby 操作（供 UI 调用）
# ============================================

## 创建一个新的 Steam Lobby（Host 端调用）
func create_lobby() -> void:
	# LOBBY_TYPE_FRIENDS_ONLY = 好友可见的公开 Lobby
	Steam.createLobby(Steam.LOBBY_TYPE_FRIENDS_ONLY, lobby_max_members)


## 加入指定的 Steam Lobby（Client 端调用）
func join_lobby(p_lobby_id: int) -> void:
	Steam.joinLobby(p_lobby_id)


## 离开当前 Lobby
func leave_lobby() -> void:
	if lobby_id != 0:
		# 调用 Steam API 离开 Lobby
		Steam.leaveLobby(lobby_id)
		# 重置本地记录
		lobby_id = 0
		# 通知 UI 返回上级菜单
		lobby_left.emit()


## 获取当前 Lobby 的所有成员信息，返回 [{steam_id, name}, ...]
func get_lobby_members() -> Array:
	var members: Array = []
	if lobby_id == 0:
		return members
	# 遍历 Lobby 成员列表，收集每个人的 Steam ID 和昵称
	var count: int = Steam.getNumLobbyMembers(lobby_id)
	for i in range(count):
		var member_id: int = Steam.getLobbyMemberByIndex(lobby_id, i)
		var member_name: String = Steam.getFriendPersonaName(member_id)
		members.append({"steam_id": member_id, "name": member_name})
	return members


## 打开 Steam 好友邀请界面
func invite_friends() -> void:
	if lobby_id != 0:
		Steam.activateGameOverlayInviteDialog(lobby_id)


# ============================================
# 公开方法 —— 游戏网络（供 NetworkManager 调用）
# ============================================

## Host 端：创建 SteamMultiplayerPeer 服务器，通知 lobby 成员进入游戏
func start_server() -> void:
	# 创建基于 Steam P2P 的多人对等体（不需要开放端口，Steam 内部处理 NAT）
	var peer := SteamMultiplayerPeer.new()
	# 0 = 虚拟通道号，区分同游戏内的多个连接
	var result = peer.create_host(0)
	if result != OK:
		connection_failed.emit("Steam 多人服务器创建失败")
		return

	# 赋值给 multiplayer，激活多人系统
	multiplayer.multiplayer_peer = peer
	# 监听玩家加入/断开事件
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	# 在 Lobby 数据里写标记，通知所有客户端"游戏开始"
	Steam.setLobbyData(lobby_id, "game_started", "true")
	Steam.setLobbyData(lobby_id, "host_steam_id", str(steam_id))

	# 通知 NetworkManager 服务器就绪
	server_started.emit(multiplayer.get_unique_id())


## Client 端：创建 SteamMultiplayerPeer 客户端，连接到 host
func join_server(p_host_steam_id: int = 0) -> void:
	# 如果传入了 host_steam_id，覆盖之前记录的值
	if p_host_steam_id != 0:
		host_steam_id = p_host_steam_id

	# host_steam_id 应该在 lobby 阶段就已获取，这里做最后兜底检查
	if host_steam_id == 0:
		connection_failed.emit("主机 Steam ID 未知，无法连接")
		return

	# 创建基于 Steam P2P 的多人对等体
	var peer := SteamMultiplayerPeer.new()
	# 连接到 host 的 Steam P2P 通道（通过 Steam ID，不需要 IP）
	var result = peer.create_client(host_steam_id, 0)
	if result != OK:
		connection_failed.emit("Steam 多人客户端连接失败")
		return

	# 监听：有其他人加入时触发
	multiplayer.peer_connected.connect(_on_peer_connected)
	# 监听：有其他人断开时触发
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	# 监听：本机成功连上服务器时触发
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	# 激活连接
	multiplayer.multiplayer_peer = peer


# ============================================
# 私有方法 —— Steam 回调处理
# ============================================

## Steam 回调：createLobby 的结果
func _on_steam_lobby_created(connect_result: int, p_lobby_id: int) -> void:
	# ROOM_ENTER_SUCCESS 表示创建成功
	# Steam API 返回值：1 = k_EResultOK（成功）
	if connect_result == 1:
		# 记录当前 lobby_id，后续操作需要用到
		lobby_id = p_lobby_id
		# 通知 UI 显示大厅信息
		lobby_created.emit(lobby_id)
	else:
		# 创建失败，通知 UI 显示错误
		lobby_join_failed.emit("创建 Lobby 失败，错误码: %d" % connect_result)


## Steam 回调：joinLobby 的结果
func _on_steam_lobby_joined(p_lobby_id: int, _permissions: int, _locked: bool, response: int) -> void:
	# CHAT_ROOM_ENTER_SUCCESS 表示加入成功
	# Steam API 返回值：1 = 成功加入房间
	if response == 1:
		lobby_id = p_lobby_id
		# 通知 UI 显示大厅
		lobby_joined.emit(lobby_id)
	else:
		# 加入失败（ lobby_id 错误、lobby 已满等）
		lobby_join_failed.emit("加入 Lobby 失败，错误码: %d" % response)


## Steam 回调：Lobby 成员变化（有人加入或离开）
func _on_steam_lobby_chat_update(p_lobby_id: int, changed_member: int, _making_change_member: int) -> void:
	# 获取变动成员的昵称
	var member_name: String = Steam.getFriendPersonaName(changed_member)
	# Steam 不直接告诉是加入还是离开，需要遍历当前成员列表来判断
	var still_in_lobby: bool = false
	var member_count: int = Steam.getNumLobbyMembers(p_lobby_id)
	for i in range(member_count):
		if Steam.getLobbyMemberByIndex(p_lobby_id, i) == changed_member:
			still_in_lobby = true
			break

	if still_in_lobby:
		# 该成员还在 Lobby 里 → 是新加入的
		lobby_member_joined.emit(changed_member, member_name)
	else:
		# 该成员不在 Lobby 里了 → 离开了
		lobby_member_left.emit(changed_member)


## Steam 回调：Lobby 数据变更（host 写了新键值对，会同步给所有成员）
func _on_steam_lobby_data_update(p_lobby_id: int, success: int, _member_id: int) -> void:
	# success 为 0 表示数据读取失败，直接跳过
	if not success:
		return

	# 检查是否有"游戏开始"标记
	var game_started: String = Steam.getLobbyData(p_lobby_id, "game_started")
	if game_started == "true":
		# 只有客户端才需要响应（host 自己不需要被自己的通知触发）
		var owner_id: int = Steam.getLobbyOwner(p_lobby_id)
		if steam_id != owner_id:
			# 读取 host 的 Steam ID，后面建立 P2P 连接要用
			var host_str: String = Steam.getLobbyData(p_lobby_id, "host_steam_id")
			if host_str != "":
				game_start_announced.emit(int(host_str))


## Steam 回调：收到好友的游戏邀请
func _on_steam_join_requested(p_lobby_id: int, _friend_id: int) -> void:
	# 直接加入邀请对应的 Lobby
	Steam.joinLobby(p_lobby_id)


## 离开游戏或关闭服务器
func leave_server() -> void:
	# 关闭多人连接
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	_disconnect_signals()

	# 如果是 host，清除 Lobby 中的游戏开始标记（允许重新开始）
	if lobby_id != 0:
		var owner_id: int = Steam.getLobbyOwner(lobby_id)
		if owner_id == steam_id:
			Steam.setLobbyData(lobby_id, "game_started", "false")

	server_stopped.emit()


# ============================================
# 私有方法 —— 多人对等体信号处理（与 EnetNetwork 相同逻辑）内部信号处理，只做转发
# ============================================

## 当有新对等体连接到 multiplayer 时触发
func _on_peer_connected(peer_id: int) -> void:
	# 不跳过任何人，包括 host，让 NetworkManager 统一处理
	player_connected.emit(peer_id)


## 当有对等体断开连接时触发
func _on_peer_disconnected(peer_id: int) -> void:
	player_disconnected.emit(peer_id)


## 仅客户端触发 —— 本机成功连上服务器后调用
func _on_connected_to_server() -> void:
	connected_to_server.emit(multiplayer.get_unique_id())


## 断开所有 multiplayer 信号连接，防止残留回调
func _disconnect_signals() -> void:
	if multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.disconnect(_on_peer_connected)
	if multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.disconnect(_on_peer_disconnected)
	if multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.disconnect(_on_connected_to_server)
