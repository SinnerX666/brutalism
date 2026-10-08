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
	var catalog_item := _catalog_item(item_id)
	if catalog_item:
		return catalog_item
	if _cache.is_empty():
		_rebuild_cache()
	return _cache.get(item_id) as InvItemDef


func _catalog_item(item_id: String) -> InvItemDef:
	var tree := Engine.get_main_loop()
	if tree is SceneTree:
		var catalog := (tree as SceneTree).root.get_node_or_null("ItemCatalog")
		if catalog and catalog.has_method("get_item"):
			return catalog.get_item(item_id) as InvItemDef
	return null


func has_item(item_id: String) -> bool:
	return get_item(item_id) != null
