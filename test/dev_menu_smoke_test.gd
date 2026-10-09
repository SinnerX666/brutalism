extends Node


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var menu := get_node_or_null("/root/DevMenu")
	if menu == null:
		_fail("DevMenu autoload is missing.")
		return

	menu.open()
	if not menu.visible or not get_tree().paused:
		_fail("DevMenu must become visible and pause the game.")
		return

	menu.close()
	if menu.visible or get_tree().paused:
		_fail("DevMenu must restore visibility and pause state when closed.")
		return

	print("DEV_MENU_SMOKE_OK")
	get_tree().quit(0)


func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
