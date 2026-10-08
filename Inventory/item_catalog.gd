extends Node

## JSON item catalog. No plugin — native FileAccess + JSON.
## Add a new file under data/items/ and list it in index.json.

const INDEX_PATH := "res://data/items/index.json"
const GENERIC_WORLD_ITEM_PATH := "res://items/generic_world_item.tscn"
const REQUIRED_IDS := [
	"test_food",
	"test_drink",
	"test_meds",
	"base_ingredient",
	"filler_ingredient",
	"medicine_ingredient",
	"crafting_tarp",
]

var _defs: Dictionary = {}


func _ready() -> void:
	reload()


func reload() -> void:
	_defs.clear()
	var index: Variant = _read_json(INDEX_PATH)
	if not index is Dictionary:
		push_error("ItemCatalog: missing or invalid %s" % INDEX_PATH)
		return

	var files: Variant = index.get("files", [])
	if not files is Array:
		push_error("ItemCatalog: index.json needs a 'files' array.")
		return

	for file_path in files:
		_load_catalog_file(str(file_path))

	for required_id in REQUIRED_IDS:
		if not _defs.has(required_id):
			push_error("ItemCatalog: required item '%s' is missing." % required_id)


func get_item(item_id: String) -> InvItemDef:
	if item_id.is_empty():
		return null
	return _defs.get(item_id) as InvItemDef


func has_item(item_id: String) -> bool:
	return get_item(item_id) != null


func get_all_items() -> Array[InvItemDef]:
	var result: Array[InvItemDef] = []
	for item in _defs.values():
		if item is InvItemDef:
			result.append(item)
	return result


func dropped_scene_path(item_id: String) -> String:
	var definition := get_item(item_id)
	if definition == null:
		return ""
	var path := str(definition.get_property("dropped_item", ""))
	if path.is_empty():
		return GENERIC_WORLD_ITEM_PATH
	return path


func _load_catalog_file(path: String) -> void:
	var parsed: Variant = _read_json(path)
	if not parsed is Dictionary:
		push_error("ItemCatalog: invalid catalog file %s" % path)
		return
	var items: Variant = parsed.get("items", [])
	if not items is Array:
		push_error("ItemCatalog: %s needs an 'items' array." % path)
		return
	for entry in items:
		if not entry is Dictionary:
			continue
		var definition := _definition_from_dict(entry)
		if definition.id.is_empty():
			push_error("ItemCatalog: item without id in %s" % path)
			continue
		if _defs.has(definition.id):
			push_error("ItemCatalog: duplicate id '%s' in %s" % [definition.id, path])
			continue
		_defs[definition.id] = definition


func _definition_from_dict(data: Dictionary) -> InvItemDef:
	var definition := InvItemDef.new()
	definition.id = str(data.get("id", ""))
	definition.display_name = str(data.get("display_name", definition.id))
	definition.description = str(data.get("description", ""))
	definition.max_stack = maxi(int(data.get("max_stack", 1)), 1)
	definition.grid_width = maxi(int(data.get("grid_width", 1)), 1)
	definition.grid_height = maxi(int(data.get("grid_height", 1)), 1)

	var icon_path := str(data.get("icon", ""))
	if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
		definition.icon = load(icon_path) as Texture2D

	var properties := {}
	for key in data.keys():
		if key in ["id", "display_name", "description", "icon", "max_stack", "grid_width", "grid_height"]:
			continue
		properties[key] = data[key]
	for stat_name in ["hunger_restore", "thirst_restore", "sanity_restore", "health_restore"]:
		properties[stat_name] = float(data.get(stat_name, 0.0))
	if not properties.has("dropped_item"):
		properties["dropped_item"] = ""
	definition.properties = properties
	return definition


func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return null
	return JSON.parse_string(text)
