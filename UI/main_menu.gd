extends CanvasLayer

const GAME_SCENE_PATH := "res://level/node_3d.tscn"

@onready var main_buttons: VBoxContainer = $Root/Center/MainButtons
@onready var options_host: Control = $Root/OptionsHost
@onready var new_game_button: Button = $Root/Center/MainButtons/NewGameButton
@onready var options_button: Button = $Root/Center/MainButtons/OptionsButton
@onready var quit_button: Button = $Root/Center/MainButtons/QuitButton
@onready var quit_dialog: ConfirmationDialog = $QuitDialog

var options_menu: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	options_menu = (
		load("res://UI/options_menu.tscn") as PackedScene
	).instantiate() as Control
	options_host.add_child(options_menu)
	options_menu.hide()
	options_menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	options_menu.back_pressed.connect(_show_main)

	new_game_button.pressed.connect(_on_new_game_pressed)
	options_button.pressed.connect(_show_options)
	quit_button.pressed.connect(_on_quit_pressed)
	quit_dialog.confirmed.connect(_on_quit_confirmed)

	_show_main()
	new_game_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("escape"):
		return
	if options_menu.visible:
		_show_main()
		get_viewport().set_input_as_handled()
	elif quit_dialog.visible:
		quit_dialog.hide()
		get_viewport().set_input_as_handled()


func _show_main() -> void:
	options_menu.hide()
	options_menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_buttons.show()
	new_game_button.grab_focus()


func _show_options() -> void:
	main_buttons.hide()
	options_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	options_menu.show()
	options_menu.refresh_from_settings()
	options_menu.focus_default()


func _on_new_game_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(GAME_SCENE_PATH)


func _on_quit_pressed() -> void:
	quit_dialog.popup_centered()


func _on_quit_confirmed() -> void:
	get_tree().quit()
