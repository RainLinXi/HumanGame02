extends CanvasLayer
@onready var button_join: Button = %ButtonJoin
@onready var button_quit: Button = %ButtonQuit

@onready var button_init_steam: Button = %ButtonInitSteam
@onready var button_join_steam: Button = %ButtonJoinSteam
@onready var button_quit_steam: Button = %ButtonQuitSteam
@onready var button_host: Button = %ButtonHost


const WORLD = preload("uid://bvdtdbtjkjrio")
const PLAYER = preload("uid://c8404uokh3vyu")

func _ready() -> void:
	button_join.pressed.connect(on_join)
	button_quit.pressed.connect(func(): get_tree().quit())
	
	button_host.pressed.connect(on_host)
	#button_init_steam.pressed.connect(SteamNetwork.initialize_steam)
	button_join_steam.pressed.connect(on_join_steam)
	button_quit_steam.pressed.connect(func(): get_tree().quit())
	#if OS.has_feature('server'):
		#add_world()
		#hide()

	
func on_join():
	add_world()
	hide()


func add_world():
	var new_world = WORLD.instantiate()
	get_tree().current_scene.add_child.call_deferred(new_world)

func on_host():
	#NetworkManager.start_server()
	add_world()
	hide()
	pass

func on_join_steam():
	pass

func on_create_steam():
	pass
