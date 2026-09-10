extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("Tarp smoke test: %s" % message)


func _item_count(inventory: InvGrid, item_id: String) -> int:
	var result := 0
	for stack in inventory.stacks:
		if stack != null and stack.item_id == item_id:
			result += stack.amount
	return result


func _world_item_count(item_id: String) -> int:
	var result := 0
	for node in get_nodes_in_group("world_item"):
		if node is WorldItem and node.item_id == item_id:
			result += 1
	return result


func _run() -> void:
	var main_scene := load("res://level/node_3d.tscn") as PackedScene
	var level := main_scene.instantiate()
	root.add_child(level)
	await process_frame
	await physics_frame

	var player := get_first_node_in_group("player") as CharacterBody3D
	var inventory := player.get_node("Inventory") as InvGrid
	var controller: Node = player.get_node("DeployablePlacement")
	var crosshair := level.get_node("UI/Interface/Control/Crosshair") as Control
	var items_container: Node = get_first_node_in_group("world_items_container")
	var tarp := (
		load("res://crafting/tarp/crafting_tarp.tscn") as PackedScene
	).instantiate() as CraftingTarp
	items_container.add_child(tarp)
	var folded_tarp := level.get_node("Items/FoldedCraftingTarp") as WorldItem

	_check(player != null, "player was not found")
	_check(crosshair != null and crosshair.visible, "crosshair was not visible")
	_check(tarp != null, "tarp instance was not found")
	_check(folded_tarp != null, "folded tarp was not found")
	_check(
		folded_tarp.get_node("Visuals/Mesh").mesh is CylinderMesh,
		"discarded tarp does not use the rolled cylinder model"
	)
	_check(tarp.can_stash(), "new tarp should be stashable")
	_check(not tarp.can_use(), "tarp was incorrectly marked as consumable")
	tarp.use_item()
	_check(is_instance_valid(tarp), "using a non-consumable tarp removed it")
	_check(tarp.recipe_database.recipes.is_empty(), "starter recipe database should be empty")

	_check(inventory.add("crafting_tarp", 1) == 0, "tarp could not be added to inventory")
	_check(
		controller.begin_placement(
			"crafting_tarp",
			"res://crafting/tarp/crafting_tarp.tscn",
			inventory
		),
		"placement preview did not start"
	)
	controller.set_process(false)
	(player.get_node("Head/Camera3D") as Camera3D).rotation.x = deg_to_rad(-45.0)
	await physics_frame
	controller._update_preview()
	_check(controller.preview.visible, "floor ray did not show placement preview")
	_check(controller.placement_valid, "clear floor placement was marked invalid")
	_check(_item_count(inventory, "crafting_tarp") == 1, "preview removed inventory item")
	controller.cancel_placement()
	await process_frame
	_check(_item_count(inventory, "crafting_tarp") == 1, "cancel removed inventory item")

	_check(
		controller.begin_placement(
			"crafting_tarp",
			"res://crafting/tarp/crafting_tarp.tscn",
			inventory
		),
		"second placement preview did not start"
	)
	controller.set_process(false)
	controller._update_preview()
	controller.placement_valid = true
	var tarp_count_before := _world_item_count("crafting_tarp")
	var confirm_event := InputEventAction.new()
	confirm_event.action = "interact"
	confirm_event.pressed = true
	controller._input(confirm_event)
	await process_frame
	_check(_item_count(inventory, "crafting_tarp") == 0, "confirmed placement kept inventory item")
	_check(
		not controller.is_placing()
		and _world_item_count("crafting_tarp") == tarp_count_before,
		"confirm input did not replace preview with deployed tarp"
	)

	_check(
		not controller.is_placing()
		and _world_item_count("crafting_tarp") == tarp_count_before,
		"confirm input did not replace preview with deployed tarp"
	)

	var deployed_tarp: CraftingTarp = null
	for child in items_container.get_children():
		if child is CraftingTarp and child != tarp:
			deployed_tarp = child
			break
	_check(deployed_tarp != null, "deployed tarp was not found in world")
	_check(
		deployed_tarp.freeze and deployed_tarp.freeze_mode == RigidBody3D.FREEZE_MODE_STATIC,
		"deployed tarp was not frozen after placement"
	)
	_check(not deployed_tarp.can_hold(), "deployed tarp should not be holdable")

	var capture_ingredient := (
		load("res://items/test_base.tscn") as PackedScene
	).instantiate() as WorldItem
	items_container.add_child(capture_ingredient)
	player.set_held_object(capture_ingredient)
	deployed_tarp.slot_left._snap_item(capture_ingredient)
	_check(player.heldObject == null, "player still holds item after slot capture")

	var pickup_ingredient := (
		load("res://items/test_filler.tscn") as PackedScene
	).instantiate() as WorldItem
	items_container.add_child(pickup_ingredient)
	deployed_tarp.slot_center._snap_item(pickup_ingredient)
	player.set_held_object(pickup_ingredient)
	_check(deployed_tarp.slot_center.is_empty(), "slot still owns item after player pickup")
	_check(
		pickup_ingredient.linear_velocity.is_zero_approx()
		and pickup_ingredient.angular_velocity.is_zero_approx(),
		"picked item velocity was not reset before unfreeze"
	)
	await physics_frame
	_check(
		deployed_tarp.slot_center.is_empty(),
		"slot re-captured item during release cooldown"
	)
	pickup_ingredient.queue_free()

	var recipe_script := load("res://crafting/physical_crafting_recipe.gd")
	var database_script := load("res://crafting/physical_crafting_recipe_database.gd")
	var recipe: Resource = recipe_script.new()
	var recipe_item_ids: Array[String] = [
		"base_ingredient",
		"filler_ingredient",
		"medicine_ingredient",
	]
	recipe.ingredient_item_ids = recipe_item_ids
	recipe.result_item_scene = load("res://items/testfood.tscn")
	var database: Resource = database_script.new()
	database.recipes.append(recipe)
	tarp.recipe_database = database

	var ingredients: Array[WorldItem] = [
		(load("res://items/test_base.tscn") as PackedScene).instantiate(),
		(load("res://items/test_filler.tscn") as PackedScene).instantiate(),
		(load("res://items/Test_medicine.tscn") as PackedScene).instantiate(),
	]
	for ingredient in ingredients:
		items_container.add_child(ingredient)

	var food_before := _world_item_count("test_food")
	tarp.slot_left._snap_item(ingredients[1])
	_check(not tarp.can_stash(), "occupied tarp could be stashed")
	tarp.slot_center._snap_item(ingredients[2])
	tarp.slot_right._snap_item(ingredients[0])
	await process_frame
	_check(tarp.can_stash(), "crafted tarp did not clear its slots")
	_check(
		_world_item_count("test_food") == food_before + 1,
		"order-independent recipe did not create its result"
	)

	var workstation := level.get_node("WorldObjects/Workstations/MedicineWorkstation")
	_check(workstation.slot_left.has_method("is_empty"), "workstation did not inherit generic slot")
	for slot in [workstation.slot_left, workstation.slot_center, workstation.slot_right]:
		_check(slot.accepted_group.is_empty(), "workstation slot does not accept every item")

	var wrong_ingredients: Array[WorldItem] = [
		(load("res://items/testfood.tscn") as PackedScene).instantiate(),
		(load("res://items/testdrink.tscn") as PackedScene).instantiate(),
		(load("res://items/testmeds.tscn") as PackedScene).instantiate(),
	]
	for ingredient in wrong_ingredients:
		items_container.add_child(ingredient)
	workstation.slot_left._snap_item(wrong_ingredients[0])
	workstation.slot_center._snap_item(wrong_ingredients[1])
	workstation.slot_right._snap_item(wrong_ingredients[2])
	await process_frame
	_check(
		not workstation.slot_left.is_empty()
		and not workstation.slot_center.is_empty()
		and not workstation.slot_right.is_empty(),
		"workstation crafted an invalid three-item combination"
	)
	for slot in [workstation.slot_left, workstation.slot_center, workstation.slot_right]:
		var wrong_item: WorldItem = slot.take_current_item()
		wrong_item.queue_free()
	await process_frame

	var workstation_ingredients: Array[WorldItem] = [
		(load("res://items/test_base.tscn") as PackedScene).instantiate(),
		(load("res://items/test_filler.tscn") as PackedScene).instantiate(),
		(load("res://items/Test_medicine.tscn") as PackedScene).instantiate(),
	]
	for ingredient in workstation_ingredients:
		items_container.add_child(ingredient)
	var drink_before := _world_item_count("test_drink")
	workstation.slot_left._snap_item(workstation_ingredients[2])
	workstation.slot_center._snap_item(workstation_ingredients[0])
	workstation.slot_right._snap_item(workstation_ingredients[1])
	await process_frame
	_check(
		_world_item_count("test_drink") == drink_before + 1,
		"existing workstation no longer crafts"
	)

	level.queue_free()
	await process_frame
	if failures.is_empty():
		print("TARP_SMOKE_OK")
		quit(0)
	else:
		quit(1)
