extends CSGBox3D

@export_group("Slots")
@export var slot_left: Area3D
@export var slot_center: Area3D
@export var slot_right: Area3D

@export_group("Recipe")
@export var required_item_ids: Array[String] = [
	"base_ingredient",
	"filler_ingredient",
	"medicine_ingredient",
]

@export_group("Crafting Result")
@export var result_item_scene: PackedScene
@export var spawn_point: Node3D


func _ready() -> void:
	for slot in _get_slots():
		if slot:
			slot.item_placed.connect(check_recipe)


func check_recipe() -> void:
	if not _recipe_is_configured():
		return

	var placed_item_ids: Array[String] = []
	for slot in _get_slots():
		if slot == null or slot.is_empty():
			return
		placed_item_ids.append(slot.current_item.item_id)

	var expected_item_ids: Array[String] = required_item_ids.duplicate()
	placed_item_ids.sort()
	expected_item_ids.sort()
	if placed_item_ids == expected_item_ids:
		craft_item()


func craft_item() -> void:
	for slot in _get_slots():
		var ingredient: WorldItem = slot.take_current_item()
		if is_instance_valid(ingredient):
			ingredient.queue_free()

	if result_item_scene == null:
		return
	var new_item := result_item_scene.instantiate() as WorldItem
	if new_item == null:
		push_error("Workstation: crafting result must inherit WorldItem.")
		return

	var items_container: Node = get_tree().get_first_node_in_group("world_items_container")
	if items_container:
		items_container.add_child(new_item)
	else:
		get_tree().current_scene.add_child(new_item)
	new_item.global_position = (
		spawn_point.global_position
		if spawn_point
		else slot_center.global_position
	)
	new_item.global_rotation = Vector3.ZERO
	new_item.freeze = false


func _recipe_is_configured() -> bool:
	if required_item_ids.size() != 3:
		return false
	var unique_ids := {}
	for item_id in required_item_ids:
		if item_id.is_empty() or unique_ids.has(item_id):
			return false
		unique_ids[item_id] = true
	return true


func _get_slots() -> Array[Area3D]:
	return [slot_left, slot_center, slot_right]
