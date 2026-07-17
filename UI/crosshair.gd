extends Control

@export var outline_radius: float = 4.0
@export var dot_radius: float = 2.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	draw_circle(center, outline_radius, Color.BLACK)
	draw_circle(center, dot_radius, Color.WHITE)
