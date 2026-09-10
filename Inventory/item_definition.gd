class_name InvItemDef
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var max_stack: int = 1
@export var grid_width: int = 1
@export var grid_height: int = 1
@export var properties: Dictionary = {}


func get_grid_size(rotated: bool = false) -> Vector2i:
	if rotated:
		return Vector2i(grid_height, grid_width)
	return Vector2i(maxi(grid_width, 1), maxi(grid_height, 1))


func get_property(key: String, default: Variant = null) -> Variant:
	return properties.get(key, default)
