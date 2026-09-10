extends CanvasLayer

const GAME_SCENE_PATH := "res://level/node_3d.tscn"

@onready var main_buttons: VBoxContainer = $Root/Center/MainButtons
@onready var options_host: Control = $Root/OptionsHost
@onready var new_game_button: Button = $Root/Center/MainButtons/NewGameButton
@onready var options_button: Button = $Root/Center/MainButtons/OptionsButton
@onready var quit_button: Button = $Root/Center/MainButtons/QuitButton
@onready var quit_dialog: ConfirmationDialog = $QuitDialog

var options_menu: Control
var _status_label: Label
var _starting_game: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_ensure_status_label()

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
	if OS.get_cmdline_user_args().has("--autostart"):
		call_deferred("_on_new_game_pressed")


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
	if _starting_game:
		return
	_starting_game = true
	new_game_button.disabled = true
	_set_status("Ładowanie...")
	get_tree().paused = false
	# change_scene w callbacku przycisku bywa zawodne w eksporcie — odkładamy o klatkę.
	call_deferred("_start_new_game")


func _start_new_game() -> void:
	if not ResourceLoader.exists(GAME_SCENE_PATH):
		_fail_start("Brak sceny gry:\n%s" % GAME_SCENE_PATH)
		return

	# Krytyczne zależności — w eksporcie load() często zwraca null bez czytelnego powodu.
	var critical := PackedStringArray([
		"res://player/Player.tscn",
		"res://Inventory/grid_inventory.gd",
		"res://Inventory/inv_database.tres",
		"res://UI/inventory_ui.tscn",
	])
	for path in critical:
		if not ResourceLoader.exists(path):
			_fail_start("Brak pliku w buildzie:\n%s" % path)
			return
		var probe: Resource = ResourceLoader.load(path)
		if probe == null:
			_fail_start("Nie ładuje się:\n%s" % path)
			return

	var packed := ResourceLoader.load(GAME_SCENE_PATH, "", ResourceLoader.CACHE_MODE_REUSE) as PackedScene
	if packed == null:
		_fail_start("Nie udało się wczytać sceny gry:\n%s" % GAME_SCENE_PATH)
		return

	var err := get_tree().change_scene_to_packed(packed)
	if err != OK:
		_fail_start("Błąd zmiany sceny: %s" % error_string(err))


func _fail_start(message: String) -> void:
	push_error("New Game failed: %s" % message)
	_write_boot_log(message)
	_set_status(message)
	_starting_game = false
	new_game_button.disabled = false


func _write_boot_log(message: String) -> void:
	var path := OS.get_executable_path().get_base_dir().path_join("sacrum_boot_error.txt")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string("%s\n%s\n" % [Time.get_datetime_string_from_system(), message])
	file.close()


func _ensure_status_label() -> void:
	_status_label = Label.new()
	_status_label.name = "StatusLabel"
	$Root.add_child(_status_label)
	_status_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_status_label.offset_left = -400.0
	_status_label.offset_top = -120.0
	_status_label.offset_right = 400.0
	_status_label.offset_bottom = -40.0
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.modulate = Color(1.0, 0.45, 0.35, 1.0)
	_status_label.visible = false


func _set_status(text: String) -> void:
	if _status_label == null:
		return
	_status_label.text = text
	_status_label.visible = not text.is_empty()


func _on_quit_pressed() -> void:
	quit_dialog.popup_centered()


func _on_quit_confirmed() -> void:
	get_tree().quit()
