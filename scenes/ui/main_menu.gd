extends CanvasLayer
@onready var button_host_enet: Button = %ButtonHost
@onready var button_join_enet: Button = %ButtonJoin
@onready var button_quit_enet: Button = %ButtonQuit

@onready var button_host_steam: Button = %ButtonHostSteam
@onready var button_join_steam: Button = %ButtonJoinSteam
@onready var button_quit_steam: Button = %ButtonQuitSteam

@onready var net_container: MarginContainer = %NetContainer
@onready var steam_lobby_container: MarginContainer = %SteamLobbyContainer

@onready var lobby_id_label: Label = %LobbyIdLabel
@onready var member_container: VBoxContainer = %MemberContainer

@onready var start_button: Button = %StartButton
@onready var invite_button: Button = %InviteButton
@onready var leave_button: Button = %LeaveButton
@onready var line_edit_steam: LineEdit = %LineEditSteam


func _ready() -> void:
	button_join_enet.pressed.connect(_on_join_enet)
	button_quit_enet.pressed.connect(func(): get_tree().quit())

	button_host_enet.pressed.connect(_on_host_enet)

	button_host_steam.pressed.connect(_on_host_steam)
	button_join_steam.pressed.connect(_on_join_steam)
	button_quit_steam.pressed.connect(func(): get_tree().quit())

	start_button.pressed.connect(_on_start_game_pressed)
	invite_button.pressed.connect(_on_invite_pressed)
	leave_button.pressed.connect(_on_leave_lobby_pressed)

	# Lobby 阶段信号 —— SteamNetwork → MainMenu UI
	SteamNetwork.lobby_created.connect(_on_lobby_created)
	SteamNetwork.lobby_joined.connect(_on_lobby_joined)
	SteamNetwork.lobby_left.connect(_on_lobby_left)
	SteamNetwork.lobby_member_joined.connect(func(_id, _name): _refresh_member_list())
	SteamNetwork.lobby_member_left.connect(func(_id): _refresh_member_list())
	SteamNetwork.lobby_join_failed.connect(_on_lobby_join_failed)
	SteamNetwork.server_stopped_ui_reset.connect(_on_server_stopped_ui_reset)
	# Host 开始游戏 → 客户端自动进入游戏
	SteamNetwork.game_start_announced.connect(_on_game_start_announced)

	steam_lobby_container.hide()

func _on_lobby_created(p_lobby_id: int) -> void:
	# 显示大厅 ID
	lobby_id_label.text = "Lobby ID: %d" % p_lobby_id

func _on_lobby_joined(p_lobby_id: int) -> void:
	# 显示大厅 ID + 刷新成员列表
	lobby_id_label.text = "Lobby ID: %d" % p_lobby_id
	_refresh_member_list()
	
	net_container.hide()
	steam_lobby_container.show()
	

func _on_lobby_join_failed(reason: String) -> void:
	# 暂时打印失败原因，后续可改为弹窗
	printerr("[MainMenu] Lobby 加入失败: %s" % reason)

func _on_lobby_left() -> void:
	# 返回网络选择菜单
	steam_lobby_container.hide()
	net_container.show()

func _refresh_member_list() -> void:
	# 先清空成员列表的所有子节点
	for child in member_container.get_children():
		child.queue_free()

	# 从 SteamNetwork 获取当前 Lobby 所有成员
	var members: Array = SteamNetwork.get_lobby_members()
	for member in members:
		var label := Label.new()
		label.text = member["name"]
		member_container.add_child(label)

func _on_join_enet():
	# 让 NetworkManager 加载世界并加入服务器
	NetworkManager.join_game(1)
	hide()


func _on_host_enet():
	# 让 NetworkManager 加载世界并启动服务器
	NetworkManager.host_game()
	hide()

func _on_join_steam():
	# 切换到 Steam 大厅界面
	net_container.hide()
	steam_lobby_container.show()
	# 读取输入框中的 lobby_id 并加入
	var input_id: String = line_edit_steam.text.strip_edges()
	if input_id != "":
		SteamNetwork.join_lobby(int(input_id))

func _on_host_steam():
	# 切换到 Steam 大厅界面
	net_container.hide()
	steam_lobby_container.show()
	# 创建 Steam Lobby
	SteamNetwork.create_lobby()

func _on_start_game_pressed() -> void:
	hide()
	# 加载世界 + 启动 Steam P2P 服务器
	NetworkManager.host_game()

func _on_leave_lobby_pressed() -> void:
	SteamNetwork.leave_lobby()
	
	steam_lobby_container.hide()
	net_container.show()
	pass

func _on_invite_pressed() -> void:
	# 弹出 Steam 好友邀请界面
	SteamNetwork.invite_friends()

func _on_game_start_announced(p_host_steam_id: int) -> void:
	hide()
	# Host 开始游戏 → 客户端自动加入
	NetworkManager.join_game(p_host_steam_id)
	
func _on_server_stopped_ui_reset():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
