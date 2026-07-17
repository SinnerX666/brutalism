extends Control

const MENU_USE := 0
const MENU_DROP := 1
const MENU_DEPLOY := 2
const MAX_STAT := 100.0

@export var player_path: NodePath

@onready var backpack: GridContainer = $Backpack

var player
var inventory: GridInventory
var context_menu: PopupMenu
var selected_stack_index: int = -1


func _ready() -> void:
	player = get_node_or_null(player_path)
	if not player is CharacterBody3D:
		player = get_tree().get_first_node_in_group("player")
	if not player is CharacterBody3D:
		push_error("Inventory UI: nie znaleziono gracza.")
		return

	inventory = player.get_node_or_null("Inventory") as GridInventory
	if inventory == null:
		push_error("Inventory UI: gracz nie ma węzła GridInventory o nazwie Inventory.")
		return

	context_menu = PopupMenu.new()
	context_menu.name = "ContextMenu"
	add_child(context_menu)
	context_menu.id_pressed.connect(_on_context_menu_selected)

	_prepare_slots()
	inventory.contents_changed.connect(refresh)
	inventory.updated_stack.connect(_on_stack_updated)
	visible = false
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory"):
		toggle_inventory()
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("escape"):
		set_inventory_visible(false)
		get_viewport().set_input_as_handled()


func toggle_inventory() -> void:
	set_inventory_visible(not visible)


func set_inventory_visible(should_be_visible: bool) -> void:
	visible = should_be_visible
	if player and player.has_method("set_inventory_ui_open"):
		player.set_inventory_ui_open(should_be_visible)
	if should_be_visible:
		refresh()
	elif context_menu:
		context_menu.hide()


func _prepare_slots() -> void:
	backpack.add_theme_constant_override("h_separation", 6)
	backpack.add_theme_constant_override("v_separation", 2)

	for index in backpack.get_child_count():
		var panel := backpack.get_child(index) as Panel
		if panel == null:
			continue

		panel.custom_minimum_size = Vector2(48.0, 48.0)
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		panel.gui_input.connect(_on_slot_gui_input.bind(index))

		var background := panel.get_node_or_null("TextureRect") as TextureRect
		if background:
			background.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var icon := TextureRect.new()
		icon.name = "ItemIcon"
		panel.add_child(icon)
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon.offset_left = 4.0
		icon.offset_top = 4.0
		icon.offset_right = -4.0
		icon.offset_bottom = -4.0
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var quantity := Label.new()
		quantity.name = "Quantity"
		panel.add_child(quantity)
		quantity.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		quantity.offset_right = -3.0
		quantity.offset_bottom = -1.0
		quantity.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		quantity.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		quantity.add_theme_font_size_override("font_size", 14)
		quantity.add_theme_color_override("font_outline_color", Color.BLACK)
		quantity.add_theme_constant_override("outline_size", 3)
		quantity.mouse_filter = Control.MOUSE_FILTER_IGNORE


func refresh() -> void:
	if inventory == null:
		return

	for index in backpack.get_child_count():
		var panel := backpack.get_child(index) as Panel
		if panel == null:
			continue

		var icon := panel.get_node_or_null("ItemIcon") as TextureRect
		var quantity := panel.get_node_or_null("Quantity") as Label
		if index >= inventory.stacks.size():
			icon.texture = null
			quantity.text = ""
			panel.tooltip_text = ""
			continue

		var stack: ItemStack = inventory.stacks[index]
		if stack == null:
			icon.texture = null
			quantity.text = ""
			panel.tooltip_text = ""
			continue

		var definition: ItemDefinition = inventory.database.get_item(stack.item_id)
		if definition == null:
			icon.texture = null
			quantity.text = str(stack.amount)
			panel.tooltip_text = stack.item_id
			continue

		icon.texture = definition.icon
		quantity.text = str(stack.amount) if stack.amount > 1 else ""
		panel.tooltip_text = "%s\n%s" % [definition.name, definition.description]


func _on_stack_updated(_stack_index: int) -> void:
	refresh()


func _on_slot_gui_input(event: InputEvent, stack_index: int) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event == null or not mouse_event.pressed:
		return
	if inventory == null or stack_index >= inventory.stacks.size():
		return
	if inventory.stacks[stack_index] == null:
		return

	if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.double_click:
		_use_item(inventory.stacks[stack_index])
		return
	if mouse_event.button_index != MOUSE_BUTTON_RIGHT:
		return

	selected_stack_index = stack_index
	var stack: ItemStack = inventory.stacks[stack_index]
	var definition: ItemDefinition = inventory.database.get_item(stack.item_id)
	context_menu.clear()
	context_menu.add_item("Użyj", MENU_USE)
	context_menu.set_item_disabled(
		context_menu.get_item_index(MENU_USE),
		not _is_consumable(definition)
	)
	if _is_deployable(definition):
		context_menu.add_item("Rozłóż", MENU_DEPLOY)
	context_menu.add_item("Wyrzuć", MENU_DROP)
	context_menu.position = Vector2i(get_viewport().get_mouse_position())
	context_menu.popup()


func _on_context_menu_selected(option_id: int) -> void:
	if selected_stack_index < 0 or selected_stack_index >= inventory.stacks.size():
		return

	var stack: ItemStack = inventory.stacks[selected_stack_index]
	if stack == null:
		return

	match option_id:
		MENU_USE:
			_use_item(stack)
		MENU_DROP:
			_drop_item(stack)
		MENU_DEPLOY:
			_deploy_item(stack)

	selected_stack_index = -1


func _is_consumable(definition: ItemDefinition) -> bool:
	if definition == null:
		return false
	for property_name in ["hunger_restore", "thirst_restore", "sanity_restore", "health_restore"]:
		if float(definition.properties.get(property_name, 0.0)) > 0.0:
			return true
	return false


func _is_deployable(definition: ItemDefinition) -> bool:
	return definition != null and bool(definition.properties.get("deployable", false))


func _use_item(stack: ItemStack) -> void:
	var definition: ItemDefinition = inventory.database.get_item(stack.item_id)
	if not _is_consumable(definition):
		return

	player.hunger = clampf(
		player.hunger + float(definition.properties.get("hunger_restore", 0.0)),
		0.0,
		MAX_STAT
	)
	player.thirst = clampf(
		player.thirst + float(definition.properties.get("thirst_restore", 0.0)),
		0.0,
		MAX_STAT
	)
	player.sanity = clampf(
		player.sanity + float(definition.properties.get("sanity_restore", 0.0)),
		0.0,
		MAX_STAT
	)
	player.health = clampf(
		player.health + float(definition.properties.get("health_restore", 0.0)),
		0.0,
		MAX_STAT
	)
	inventory.remove(stack.item_id, 1)


func _drop_item(stack: ItemStack) -> void:
	var definition: ItemDefinition = inventory.database.get_item(stack.item_id)
	if definition == null:
		return

	var scene_path: String = str(definition.properties.get("dropped_item", ""))
	if scene_path.is_empty():
		return

	var packed_scene := load(scene_path) as PackedScene
	if packed_scene == null:
		push_error("Inventory UI: nie udało się wczytać sceny %s." % scene_path)
		return
	var dropped_item := packed_scene.instantiate() as RigidBody3D
	if dropped_item == null:
		return

	var safe_position: Variant = player.get_safe_item_spawn_position(dropped_item, 2.0)
	if not safe_position is Vector3:
		dropped_item.free()
		return
	if inventory.remove(stack.item_id, 1) != 0:
		dropped_item.free()
		return

	var items_container: Node = get_tree().get_first_node_in_group("world_items_container")
	if items_container:
		items_container.add_child(dropped_item)
	else:
		get_tree().current_scene.add_child(dropped_item)
	dropped_item.global_position = safe_position
	dropped_item.global_rotation = Vector3.ZERO
	dropped_item.linear_velocity = Vector3.ZERO
	dropped_item.angular_velocity = Vector3.ZERO


func _deploy_item(stack: ItemStack) -> void:
	var definition: ItemDefinition = inventory.database.get_item(stack.item_id)
	if not _is_deployable(definition):
		return
	var scene_path: String = str(definition.properties.get("deployable_scene", ""))
	if scene_path.is_empty():
		return
	var placement_controller: Node = player.get_node_or_null("DeployablePlacement")
	if placement_controller == null:
		push_error("Inventory UI: player has no DeployablePlacement controller.")
		return

	set_inventory_visible(false)
	if not placement_controller.begin_placement(stack.item_id, scene_path, inventory):
		set_inventory_visible(true)
