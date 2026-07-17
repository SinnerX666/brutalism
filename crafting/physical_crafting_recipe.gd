class_name PhysicalCraftingRecipe
extends Resource

@export var ingredient_item_ids: Array[String] = ["", "", ""]
@export var result_item_scene: PackedScene


func is_valid() -> bool:
	if ingredient_item_ids.size() != 3 or result_item_scene == null:
		return false
	for item_id in ingredient_item_ids:
		if item_id.is_empty():
			return false
	return true


func matches(item_ids: Array[String]) -> bool:
	if not is_valid() or item_ids.size() != 3:
		return false
	var expected: Array[String] = ingredient_item_ids.duplicate()
	var actual: Array[String] = item_ids.duplicate()
	expected.sort()
	actual.sort()
	return expected == actual
