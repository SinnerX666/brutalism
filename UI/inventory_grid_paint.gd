extends Control

## Rysuje siatkę tetris; parent UI ustawia `inventory` i stałe komórek.
var inventory: InvGrid
var cell_size: float = 52.0
var cell_gap: float = 4.0


func _draw() -> void:
	if inventory == null:
		return
	var step: float = cell_size + cell_gap
	for y in inventory.size.y:
		for x in inventory.size.x:
			var rect := Rect2(Vector2(x, y) * step, Vector2(cell_size, cell_size))
			draw_rect(rect, Color(0.12, 0.14, 0.17, 0.95), true)
			draw_rect(rect, Color(0.35, 0.4, 0.45, 0.7), false, 1.0)
