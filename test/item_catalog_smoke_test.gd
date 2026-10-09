extends SceneTree

const GENERIC_SCENE_PATH := "res://items/generic_world_item.tscn"
const MINIMUM_ITEM_COUNT := 30

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("Item catalog smoke test: %s" % message)


func _run() -> void:
	var catalog := root.get_node_or_null("ItemCatalog")
	_check(catalog != null, "ItemCatalog autoload is missing")
	if catalog == null:
		_finish()
		return

	catalog.reload()
	_check(catalog.is_valid(), "catalog validation failed: %s" % catalog.get_errors())

	var definitions: Array[InvItemDef] = catalog.get_all_items()
	_check(
		definitions.size() >= MINIMUM_ITEM_COUNT,
		"expected at least %d items, got %d" % [MINIMUM_ITEM_COUNT, definitions.size()]
	)

	var seen_ids: Dictionary = {}
	for definition in definitions:
		_check(definition != null, "catalog contains a null definition")
		if definition == null:
			continue
		_check(not definition.id.is_empty(), "item has an empty id")
		_check(not seen_ids.has(definition.id), "duplicate id '%s'" % definition.id)
		seen_ids[definition.id] = true
		_check(not definition.display_name.is_empty(), "%s has no display name" % definition.id)
		_check(definition.max_stack > 0, "%s has invalid max_stack" % definition.id)
		_check(
			definition.grid_width > 0 and definition.grid_height > 0,
			"%s has invalid grid size" % definition.id
		)

	var bread: InvItemDef = catalog.get_item("rye_bread")
	_check(bread != null, "rye_bread is missing")
	if bread:
		_check(bread.grid_width == 2 and bread.grid_height == 1, "rye_bread grid size changed")
		_check(
			is_equal_approx(float(bread.get_property("hunger_restore", 0.0)), 18.0),
			"rye_bread hunger stat changed"
		)

	var database := InvDatabase.new()
	_check(
		database.get_item("cheap_vodka") == catalog.get_item("cheap_vodka"),
		"InvDatabase does not resolve items through ItemCatalog"
	)
	_check(
		catalog.dropped_scene_path("rye_bread") == GENERIC_SCENE_PATH,
		"items without a custom scene do not use the generic world item"
	)
	_check(
		catalog.dropped_scene_path("test_food") == "res://items/testfood.tscn",
		"custom dropped scene was not preserved"
	)

	var generic_scene := load(GENERIC_SCENE_PATH) as PackedScene
	_check(generic_scene != null, "generic world item scene does not load")
	if generic_scene:
		var world_item := generic_scene.instantiate() as WorldItem
		_check(world_item != null, "generic scene does not instantiate as WorldItem")
		if world_item:
			world_item.item_id = "rye_bread"
			root.add_child(world_item)
			await process_frame
			_check(world_item.get_display_name() == "Chleb żytni", "catalog name was not applied")
			_check(is_equal_approx(world_item.mass, 0.6), "catalog mass was not applied")
			_check(world_item.is_in_group("food"), "catalog tags were not applied as groups")
			world_item.queue_free()
			await process_frame

	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("ITEM_CATALOG_SMOKE_OK")
		quit(0)
	else:
		quit(1)
