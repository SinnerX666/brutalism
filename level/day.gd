# TimeLabel.gd
extends Label

var time_manager

func _ready() -> void:
	time_manager = get_tree().get_first_node_in_group("time_manager")
	if time_manager == null:
		push_error("DayLabel: missing node in time_manager group.")
		return
	time_manager.day_changed.connect(_on_day_updated)
	text = time_manager.get_day_string()

func _on_day_updated(_day: int) -> void:
	text = time_manager.get_day_string()
