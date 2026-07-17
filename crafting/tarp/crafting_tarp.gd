class_name CraftingTarp
extends WorldItem

@export_group("Crafting")
@export var recipe_database: Resource
@export var slot_left: Area3D
@export var slot_center: Area3D
@export var slot_right: Area3D
@export var result_spawn_point: Marker3D

@export_group("Placement")
@export var placement_footprint: Vector3 = Vector3(2.4, 0.08, 1.8)

var _is_crafting: bool = false
var _preview_material := StandardMaterial3D.new()


func _ready() -> void:
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	freeze = true
	for slot in _get_slots():
		if slot:
			slot.item_placed.connect(_try_craft)


func can_stash() -> bool:
	for slot in _get_slots():
		if slot and not slot.is_empty():
			return false
	return true


func can_hold() -> bool:
	# Rozłożona plandeka nie może być chwytana/przesuwana za pomocą "interact" -
	# w przeciwnym razie gracz mógłby ją odmrozić i przesunąć, gdy leżą na niej
	# przedmioty w slotach, co rozjeżdża ich pozycje. Jedyny sposób jej zabrania
	# to schowanie (stash) do ekwipunku, gdy jest pusta.
	return false


func finalize_placement() -> void:
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	freeze = true


func get_placement_footprint() -> Vector3:
	return placement_footprint


func configure_as_placement_preview() -> void:
	collision_layer = 0
	collision_mask = 0
	for area in find_children("*", "Area3D", true, false):
		var slot_area := area as Area3D
		slot_area.monitoring = false
		slot_area.monitorable = false
	for child in find_children("*", "CollisionShape3D", true, false):
		(child as CollisionShape3D).disabled = true
	_preview_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_preview_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	set_placement_preview_valid(false)


func set_placement_preview_valid(is_valid: bool) -> void:
	_preview_material.albedo_color = (
		Color(0.2, 0.9, 0.35, 0.45)
		if is_valid
		else Color(0.95, 0.2, 0.2, 0.45)
	)
	for geometry in find_children("*", "GeometryInstance3D", true, false):
		(geometry as GeometryInstance3D).material_override = _preview_material


func _try_craft() -> void:
	if _is_crafting or recipe_database == null:
		return

	var item_ids: Array[String] = []
	for slot in _get_slots():
		if slot == null or slot.is_empty():
			return
		item_ids.append(slot.current_item.item_id)

	var recipe: Resource = recipe_database.find_matching_recipe(item_ids)
	if recipe == null:
		return
	_craft(recipe)


func _craft(recipe: Resource) -> void:
	_is_crafting = true
	for slot in _get_slots():
		var ingredient: WorldItem = slot.take_current_item()
		if is_instance_valid(ingredient):
			ingredient.queue_free()

	var result := recipe.result_item_scene.instantiate() as WorldItem
	if result == null:
		push_error("CraftingTarp: recipe result must inherit WorldItem.")
		_is_crafting = false
		return

	var items_container: Node = get_tree().get_first_node_in_group("world_items_container")
	if items_container:
		items_container.add_child(result)
	else:
		get_tree().current_scene.add_child(result)
	result.global_position = (
		result_spawn_point.global_position
		if result_spawn_point
		else global_position + Vector3.UP * 0.5
	)
	result.global_rotation = Vector3.ZERO
	result.freeze = false
	_is_crafting = false


func _get_slots() -> Array[Area3D]:
	return [slot_left, slot_center, slot_right]
