# TimeLabel.gd
extends Label

var time_manager

func _ready() -> void:
	time_manager = get_tree().get_first_node_in_group("time_manager")
	if time_manager == null:
		push_error("TimeLabel: missing node in time_manager group.")
		return
	time_manager.time_updated.connect(_on_time_updated)
	text = time_manager.get_time_string()

func _on_time_updated(hours: int, minutes: int) -> void:
	text = "%02d:%02d" % [hours, minutes]
