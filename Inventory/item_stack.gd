class_name InvItemStack
extends RefCounted

var item_id: String = ""
var amount: int = 1
var grid_position: Vector2i = Vector2i.ZERO
var rotated: bool = false


func _init(
	p_item_id: String = "",
	p_amount: int = 1,
	p_grid_position: Vector2i = Vector2i.ZERO,
	p_rotated: bool = false
) -> void:
	item_id = p_item_id
	amount = p_amount
	grid_position = p_grid_position
	rotated = p_rotated


func duplicate_stack() -> InvItemStack:
	return InvItemStack.new(item_id, amount, grid_position, rotated)
