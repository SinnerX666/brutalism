extends CanvasLayer

signal quit_requested

@onready var root_control: Control = $Root
@onready var dimmer: ColorRect = $Root/Dimmer
@onready var main_panel: VBoxContainer = $Root/Center/MainPanel
@onready var options_host: Control = $Root/OptionsHost
@onready var resume_button: Button = $Root/Center/MainPanel/ResumeButton
@onready var options_button: Button = $Root/Center/MainPanel/OptionsButton
@onready var quit_button: Button = $Root/Center/MainPanel/QuitButton
@onready var quit_dialog: ConfirmationDialog = $QuitDialog

var options_menu: Control
var _is_open: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	visible = false
	root_control.hide()

	options_menu = (
		load("res://UI/options_menu.tscn") as PackedScene
	).instantiate() as Control
	options_host.add_child(options_menu)
	options_menu.hide()
	options_menu.back_pressed.connect(_show_main)

	resume_button.pressed.connect(resume)
	options_button.pressed.connect(_show_options)
	quit_button.pressed.connect(_on_quit_pressed)
	quit_dialog.confirmed.connect(_on_quit_confirmed)


func is_open() -> bool:
	return _is_open


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("escape"):
		return

	if quit_dialog.visible:
		quit_dialog.hide()
		get_viewport().set_input_as_handled()
		return

	if _is_open:
		if options_menu.visible:
			_show_main()
		else:
			resume()
		get_viewport().set_input_as_handled()
		return

	if _should_ignore_pause_request():
		return

	pause_game()
	get_viewport().set_input_as_handled()


func pause_game() -> void:
	if _is_open:
		return
	_is_open = true
	get_tree().paused = true
	visible = true
	root_control.show()
	_show_main()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	resume_button.grab_focus()


func resume() -> void:
	if not _is_open:
		return
	_is_open = false
	quit_dialog.hide()
	options_menu.hide()
	root_control.hide()
	visible = false
	get_tree().paused = false
	_restore_mouse_mode()


func _show_main() -> void:
	options_menu.hide()
	main_panel.show()
	resume_button.grab_focus()


func _show_options() -> void:
	main_panel.hide()
	options_menu.show()
	options_menu.refresh_from_settings()
	options_menu.focus_default()


func _on_quit_pressed() -> void:
	quit_dialog.popup_centered()


func _on_quit_confirmed() -> void:
	quit_requested.emit()
	get_tree().quit()


func _should_ignore_pause_request() -> bool:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return false
	if bool(player.get("ui_open")):
		return true
	if bool(player.get("deployment_mode")):
		return true
	if bool(player.get("is_sleeping")):
		return true
	return false


func _restore_mouse_mode() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player and bool(player.get("ui_open")):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
