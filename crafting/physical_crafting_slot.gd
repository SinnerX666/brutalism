class_name PhysicalCraftingSlot
extends Area3D

signal item_placed
signal item_removed

@export_group("Slot Configuration")
@export var accepted_group: String = ""
@export var snap_point: Node3D
@export_range(0.0, 5.0, 0.1) var same_item_reinsert_cooldown: float = 0.5
@export_range(0.0, 0.1, 0.005) var snap_height_offset: float = 0.03

const CRAFTING_SLOT_META := "crafting_slot"

var current_item: WorldItem
var blocked_item_id: int = 0
var blocked_until_msec: int = 0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func is_empty() -> bool:
	return not is_instance_valid(current_item)


func take_current_item() -> WorldItem:
	if not is_instance_valid(current_item):
		current_item = null
		return null
	var item := current_item
	current_item = null
	if item.has_meta(CRAFTING_SLOT_META):
		item.remove_meta(CRAFTING_SLOT_META)
	return item


func _on_body_entered(body: Node3D) -> void:
	if body.is_ancestor_of(self):
		return
	if not is_empty() or not body is WorldItem:
		return
	if _is_same_item_on_cooldown(body):
		return
	if not accepted_group.is_empty() and not body.is_in_group(accepted_group):
		return
	_snap_item(body)


func _snap_item(item: WorldItem) -> void:
	current_item = item
	# Zerujemy prędkości PRZED zamrożeniem, żeby przedmiot nie "wystrzelił"
	# gdy w przyszłości zostanie odmrożony (np. wyjęty przez gracza).
	item.linear_velocity = Vector3.ZERO
	item.angular_velocity = Vector3.ZERO
	item.global_position = (
		(snap_point.global_position if snap_point else global_position)
		+ Vector3.UP * snap_height_offset
	)
	item.global_rotation = Vector3.ZERO
	item.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	item.freeze = true
	item.set_meta(CRAFTING_SLOT_META, self)
	_notify_player_item_captured(item)
	item_placed.emit()


func _notify_player_item_captured(item: WorldItem) -> void:
	# Jeśli gracz aktualnie "trzymał" ten przedmiot podczas wkładania go do slotu,
	# musimy wyczyścić jego rękę - inaczej trzyma sprężynę przypiętą do zamrożonego obiektu.
	var player := item.get_tree().get_first_node_in_group("player")
	if player and player.has_method("notify_held_object_captured"):
		player.notify_held_object_captured(item)


func notify_item_taken(item: WorldItem) -> void:
	# Wywoływane bezpośrednio przez gracza w momencie podniesienia przedmiotu ze slotu,
	# zanim fizyka zdąży wyemitować body_exited - dzięki temu cooldown startuje od razu
	# i slot nie "zasysa" przedmiotu z powrotem, gdy ten jeszcze nie zdążył opuścić Area3D.
	if item != current_item:
		return
	current_item = null
	if item.has_meta(CRAFTING_SLOT_META):
		item.remove_meta(CRAFTING_SLOT_META)
	blocked_item_id = item.get_instance_id()
	blocked_until_msec = Time.get_ticks_msec() + int(same_item_reinsert_cooldown * 1000.0)
	item_removed.emit()


func _on_body_exited(body: Node3D) -> void:
	if body != current_item:
		return
	current_item = null
	if body.has_meta(CRAFTING_SLOT_META):
		body.remove_meta(CRAFTING_SLOT_META)
	blocked_item_id = body.get_instance_id()
	blocked_until_msec = Time.get_ticks_msec() + int(same_item_reinsert_cooldown * 1000.0)
	item_removed.emit()


func _is_same_item_on_cooldown(body: Node3D) -> bool:
	if body.get_instance_id() != blocked_item_id:
		return false
	if Time.get_ticks_msec() >= blocked_until_msec:
		blocked_item_id = 0
		blocked_until_msec = 0
		return false
	return true
