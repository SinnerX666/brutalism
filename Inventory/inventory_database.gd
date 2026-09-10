class_name InvDatabase
extends Resource

@export var items: Array[InvItemDef] = []

var _cache: Dictionary = {}


func _rebuild_cache() -> void:
	_cache.clear()
	for item in items:
		if item != null and not item.id.is_empty():
			_cache[item.id] = item


func get_item(item_id: String) -> InvItemDef:
	if _cache.is_empty():
		_rebuild_cache()
	return _cache.get(item_id) as InvItemDef


func has_item(item_id: String) -> bool:
	return get_item(item_id) != null
