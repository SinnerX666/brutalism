extends Node

## Runtime item catalog backed by JSON. No external plugin is required.
## Add a file under data/items/ and register it in index.json.

signal catalog_reloaded(item_count: int)

const INDEX_PATH := "res://data/items/index.json"
const GENERIC_WORLD_ITEM_PATH := "res://items/generic_world_item.tscn"
const SUPPORTED_SCHEMA_VERSION := 1
const REQUIRED_IDS: PackedStringArray = [
	"test_food",
	"test_drink",
	"test_meds",
	"base_ingredient",
	"filler_ingredient",
	"medicine_ingredient",
	"crafting_tarp",
]

var _defs: Dictionary = {}
var _errors: PackedStringArray = []


func _ready() -> void:
	reload()


func reload() -> void:
	_defs.clear()
	_errors.clear()
	var index: Variant = _read_json(INDEX_PATH)
	if not index is Dictionary:
		if _errors.is_empty():
			_report_error("missing or invalid %s" % INDEX_PATH)
		return

	var schema_version := int(index.get("schema_version", 0))
	if schema_version != SUPPORTED_SCHEMA_VERSION:
		_report_error(
			"%s uses schema version %d; expected %d."
			% [INDEX_PATH, schema_version, SUPPORTED_SCHEMA_VERSION]
		)

	var files: Variant = index.get("files", [])
	if not files is Array:
		_report_error("index.json needs a 'files' array.")
		return

	var loaded_files: Dictionary = {}
	for file_path in files:
		if not file_path is String or str(file_path).is_empty():
			_report_error("index.json contains an invalid file path.")
			continue
		var path := str(file_path)
		if loaded_files.has(path):
			_report_error("index.json lists '%s' more than once." % path)
			continue
		loaded_files[path] = true
		_load_catalog_file(path)

	for required_id in REQUIRED_IDS:
		if not _defs.has(required_id):
			_report_error("required item '%s' is missing." % required_id)

	if not ResourceLoader.exists(GENERIC_WORLD_ITEM_PATH):
		_report_error("generic world item scene is missing: %s" % GENERIC_WORLD_ITEM_PATH)

	catalog_reloaded.emit(_defs.size())


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
	result.sort_custom(func(a: InvItemDef, b: InvItemDef) -> bool: return a.id < b.id)
	return result


func is_valid() -> bool:
	return _errors.is_empty()


func get_errors() -> PackedStringArray:
	return _errors.duplicate()


func dropped_scene_path(item_id: String) -> String:
	var definition := get_item(item_id)
	if definition == null:
		return ""
	var path := str(definition.get_property("dropped_item", ""))
	if path.is_empty():
		return GENERIC_WORLD_ITEM_PATH
	return path


func _load_catalog_file(path: String) -> void:
	var errors_before := _errors.size()
	var parsed: Variant = _read_json(path)
	if not parsed is Dictionary:
		if _errors.size() == errors_before:
			_report_error("invalid catalog file %s" % path)
		return
	var items: Variant = parsed.get("items", [])
	if not items is Array:
		_report_error("%s needs an 'items' array." % path)
		return
	for entry_index in items.size():
		var entry: Variant = items[entry_index]
		if not entry is Dictionary:
			_report_error("%s item %d is not an object." % [path, entry_index])
			continue
		var definition := _definition_from_dict(entry, path, entry_index)
		if definition == null:
			continue
		if _defs.has(definition.id):
			_report_error("duplicate id '%s' in %s" % [definition.id, path])
			continue
		_defs[definition.id] = definition


func _definition_from_dict(
	data: Dictionary,
	source_path: String,
	entry_index: int
) -> InvItemDef:
	var item_id := str(data.get("id", "")).strip_edges()
	var context := "%s item %d" % [source_path, entry_index]
	if item_id.is_empty():
		_report_error("%s has no id." % context)
		return null
	if not item_id.is_valid_identifier() or item_id != item_id.to_lower():
		_report_error("%s has invalid id '%s'; use lower_snake_case." % [context, item_id])
		return null

	var definition := InvItemDef.new()
	definition.id = item_id
	definition.display_name = str(data.get("display_name", "")).strip_edges()
	if definition.display_name.is_empty():
		_report_error("%s ('%s') has no display_name." % [context, item_id])
		definition.display_name = item_id.replace("_", " ").capitalize()
	definition.description = str(data.get("description", ""))
	definition.max_stack = _positive_int(data, "max_stack", 1, item_id)
	definition.grid_width = _positive_int(data, "grid_width", 1, item_id)
	definition.grid_height = _positive_int(data, "grid_height", 1, item_id)

	var icon_path := str(data.get("icon", ""))
	if not icon_path.is_empty():
		if ResourceLoader.exists(icon_path):
			definition.icon = load(icon_path) as Texture2D
		else:
			_report_error("item '%s' references missing icon '%s'." % [item_id, icon_path])

	var properties := {}
	for key in data.keys():
		if key in ["id", "display_name", "description", "icon", "max_stack", "grid_width", "grid_height"]:
			continue
		properties[key] = data[key]
	for stat_name in ["hunger_restore", "thirst_restore", "sanity_restore", "health_restore"]:
		var stat_value: Variant = data.get(stat_name, 0.0)
		if not stat_value is int and not stat_value is float:
			_report_error("item '%s' has non-numeric %s." % [item_id, stat_name])
			stat_value = 0.0
		properties[stat_name] = float(stat_value)
	if not properties.has("dropped_item"):
		properties["dropped_item"] = ""

	for scene_property in ["dropped_item", "deployable_scene"]:
		var scene_path := str(properties.get(scene_property, ""))
		if not scene_path.is_empty() and not ResourceLoader.exists(scene_path):
			_report_error(
				"item '%s' references missing %s '%s'."
				% [item_id, scene_property, scene_path]
			)

	var tags: Variant = properties.get("tags", [])
	if not tags is Array:
		_report_error("item '%s' has non-array tags." % item_id)
		properties["tags"] = []
	else:
		for tag in tags:
			if not tag is String or str(tag).is_empty():
				_report_error("item '%s' contains an invalid tag." % item_id)

	var mass_value: Variant = properties.get("mass", null)
	if mass_value != null and (
		(not mass_value is int and not mass_value is float)
		or float(mass_value) <= 0.0
	):
		_report_error("item '%s' has invalid mass." % item_id)

	var color_value: Variant = properties.get("preview_color", null)
	if color_value != null and not _is_rgb_array(color_value):
		_report_error("item '%s' has invalid preview_color." % item_id)

	definition.properties = properties
	return definition


func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		_report_error("file does not exist: %s" % path)
		return null
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		_report_error("file is empty: %s" % path)
		return null
	var json := JSON.new()
	var error := json.parse(text)
	if error != OK:
		_report_error(
			"cannot parse %s at line %d: %s"
			% [path, json.get_error_line(), json.get_error_message()]
		)
		return null
	return json.data


func _report_error(message: String) -> void:
	_errors.append(message)
	push_error("ItemCatalog: %s" % message)


func _positive_int(
	data: Dictionary,
	field: String,
	default_value: int,
	item_id: String
) -> int:
	var value: Variant = data.get(field, default_value)
	if (not value is int and not value is float) or int(value) <= 0:
		_report_error("item '%s' has invalid %s." % [item_id, field])
		return default_value
	return int(value)


func _is_rgb_array(value: Variant) -> bool:
	if not value is Array or value.size() < 3:
		return false
	for index in 3:
		var channel: Variant = value[index]
		if (
			(not channel is int and not channel is float)
			or float(channel) < 0.0
			or float(channel) > 1.0
		):
			return false
	return true
