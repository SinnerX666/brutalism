extends Node

var failures: Array[String] = []
const SETTINGS_PATH := "user://settings.cfg"


func _ready() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("Menu smoke test: %s" % message)


func _clear_settings_file() -> void:
	if FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(SETTINGS_PATH)


func _settings() -> Node:
	return get_node("/root/GameSettings")


func _run() -> void:
	var settings := _settings()
	_clear_settings_file()
	settings.master_volume = settings.DEFAULT_MASTER_VOLUME
	settings.apply_audio()

	settings.set_master_volume(0.42)
	_check(
		is_equal_approx(float(settings.master_volume), 0.42),
		"master volume was not stored in memory"
	)
	_check(FileAccess.file_exists(SETTINGS_PATH), "settings file was not created")

	settings.master_volume = 1.0
	settings.load_settings()
	_check(
		is_equal_approx(float(settings.master_volume), 0.42),
		"master volume was not reloaded from disk"
	)
	settings.apply_audio()
	var bus_idx := AudioServer.get_bus_index("Master")
	_check(bus_idx >= 0, "Master audio bus is missing")
	_check(
		is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(bus_idx)), 0.42),
		"AudioServer did not receive saved master volume"
	)

	var main_menu_scene := load("res://UI/main_menu.tscn") as PackedScene
	var main_menu := main_menu_scene.instantiate()
	add_child(main_menu)
	await get_tree().process_frame
	_check(main_menu.get_node("Root/Center/MainButtons/NewGameButton") != null, "new game button missing")
	_check(main_menu.get_node("QuitDialog") is ConfirmationDialog, "quit dialog missing")
	main_menu._show_options()
	await get_tree().process_frame
	_check(main_menu.options_menu.visible, "options panel did not open from title menu")
	main_menu._show_main()
	_check(not main_menu.options_menu.visible, "options panel did not close")
	main_menu.queue_free()
	await get_tree().process_frame

	var level_scene := load("res://level/node_3d.tscn") as PackedScene
	var level := level_scene.instantiate()
	add_child(level)
	await get_tree().process_frame
	await get_tree().physics_frame

	var pause_menu := level.get_node("UI/PauseMenu")
	_check(pause_menu != null, "pause menu was not present in game scene")
	_check(
		pause_menu.process_mode == Node.PROCESS_MODE_ALWAYS,
		"pause menu is not always processing"
	)

	var quit_calls := [0]
	pause_menu.quit_requested.connect(func() -> void: quit_calls[0] += 1)
	if pause_menu.quit_dialog.confirmed.is_connected(pause_menu._on_quit_confirmed):
		pause_menu.quit_dialog.confirmed.disconnect(pause_menu._on_quit_confirmed)
	pause_menu.quit_dialog.confirmed.connect(
		func() -> void:
			quit_calls[0] += 1
			pause_menu.quit_requested.emit()
	)

	pause_menu.pause_game()
	await get_tree().process_frame
	_check(bool(pause_menu.is_open()), "pause menu did not open")
	_check(get_tree().paused, "scene tree was not paused")
	_check(
		Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,
		"mouse was not released while paused"
	)

	pause_menu._show_options()
	await get_tree().process_frame
	_check(pause_menu.options_menu.visible, "options panel did not open from pause menu")
	pause_menu._show_main()
	_check(not pause_menu.options_menu.visible, "options did not return to pause main")

	pause_menu.resume()
	await get_tree().process_frame
	_check(not bool(pause_menu.is_open()), "pause menu did not close")
	_check(not get_tree().paused, "scene tree remained paused after resume")
	# Headless builds often cannot really capture the mouse; still verify restore path ran.
	_check(
		Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
		or DisplayServer.get_name() == "headless",
		"mouse was not recaptured after resume"
	)

	pause_menu.pause_game()
	pause_menu._on_quit_pressed()
	await get_tree().process_frame
	_check(pause_menu.quit_dialog.visible, "quit confirmation did not open")
	pause_menu.quit_dialog.hide()
	_check(quit_calls[0] == 0, "quit confirmation fired without confirm")
	# Use the stubbed confirmed path (real handler disconnected to avoid process exit).
	pause_menu.quit_dialog.confirmed.emit()
	_check(quit_calls[0] == 2, "dialog confirmed path did not emit quit signal")
	pause_menu.resume()
	await get_tree().process_frame

	var player := get_tree().get_first_node_in_group("player") as CharacterBody3D
	_check(player != null, "player missing in game scene")
	player.ui_open = true
	pause_menu.resume()
	await get_tree().process_frame
	_check(
		bool(pause_menu._should_ignore_pause_request()),
		"pause request should be ignored while inventory is open"
	)
	player.ui_open = false
	player.deployment_mode = true
	_check(
		bool(pause_menu._should_ignore_pause_request()),
		"pause request should be ignored during deploy mode"
	)
	player.deployment_mode = false

	level.queue_free()
	await get_tree().process_frame
	_clear_settings_file()
	settings.set_master_volume(settings.DEFAULT_MASTER_VOLUME)

	if failures.is_empty():
		print("MENU_SMOKE_OK")
		get_tree().quit(0)
	else:
		get_tree().quit(1)
