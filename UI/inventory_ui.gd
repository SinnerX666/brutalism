extends Control

const MENU_USE := 0
const MENU_DROP := 1
const MENU_DEPLOY := 2
const MAX_STAT := 100.0
const CELL_SIZE := 52.0
const CELL_GAP := 4.0

@export var player_path: NodePath

var player
var inventory: InvGrid
var context_menu: PopupMenu
var selected_stack: InvItemStack
var grid_root: Control
var item_layer: Control
var title_label: Label

var _drag_stack: InvItemStack
var _drag_index: int = -1
var _drag_preview: Control
var _drag_rotated: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	player = get_node_or_null(player_path)
	if not player is CharacterBody3D:
		player = get_tree().get_first_node_in_group("player")
	if not player is CharacterBody3D:
		push_error("Inventory UI: nie znaleziono gracza.")
		return

	inventory = player.get_node_or_null("Inventory") as InvGrid
	if inventory == null:
		push_error("Inventory UI: brak InvGrid.")
		return

	context_menu = PopupMenu.new()
	add_child(context_menu)
	context_menu.id_pressed.connect(_on_context_menu_selected)
	inventory.contents_changed.connect(refresh)
	grid_root.inventory = inventory
	visible = false
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory"):
		toggle_inventory()
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("escape"):
		set_inventory_visible(false)
		get_viewport().set_input_as_handled()
	elif visible and _drag_stack != null and event.is_action_pressed("rotate_item"):
		_drag_rotated = not _drag_rotated
		_update_drag_preview()
		get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if not visible or _drag_stack == null:
		return
	var mouse := event as InputEventMouseButton
	if mouse and mouse.button_index == MOUSE_BUTTON_LEFT and not mouse.pressed:
		var local := grid_root.get_local_mouse_position()
		if Rect2(Vector2.ZERO, grid_root.size).has_point(local):
			_drop_drag(local)
		else:
			_cancel_drag()
			refresh()
		get_viewport().set_input_as_handled()


func toggle_inventory() -> void:
	set_inventory_visible(not visible)


func set_inventory_visible(should_be_visible: bool) -> void:
	visible = should_be_visible
	_cancel_drag()
	if player and player.has_method("set_inventory_ui_open"):
		player.set_inventory_ui_open(should_be_visible)
	if should_be_visible:
		refresh()
	elif context_menu:
		context_menu.hide()


func refresh() -> void:
	if inventory == null or item_layer == null:
		return
	for child in item_layer.get_children():
		child.queue_free()
	title_label.text = "Plecak  %dx%d" % [inventory.size.x, inventory.size.y]
	grid_root.inventory = inventory
	grid_root.custom_minimum_size = Vector2(inventory.size) * (CELL_SIZE + CELL_GAP)
	grid_root.queue_redraw()
	for stack in inventory.stacks:
		if stack == null or stack == _drag_stack:
			continue
		item_layer.add_child(_make_item_widget(stack))


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var dimmer := ColorRect.new()
	dimmer.color = Color(0.02, 0.03, 0.04, 0.72)
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dimmer)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -280.0
	panel.offset_top = -260.0
	panel.offset_right = 280.0
	panel.offset_bottom = 260.0
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	title_label = Label.new()
	title_label.text = "Plecak"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 22)
	vbox.add_child(title_label)

	var hint := Label.new()
	hint.text = "PPM: akcje  |  R przy przeciąganiu: obrót"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate = Color(0.75, 0.8, 0.85, 0.85)
	vbox.add_child(hint)

	grid_root = Control.new()
	grid_root.set_script(load("res://UI/inventory_grid_paint.gd"))
	grid_root.cell_size = CELL_SIZE
	grid_root.cell_gap = CELL_GAP
	grid_root.custom_minimum_size = Vector2(8, 6) * (CELL_SIZE + CELL_GAP)
	vbox.add_child(grid_root)

	item_layer = Control.new()
	item_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	item_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid_root.add_child(item_layer)


func _process(_delta: float) -> void:
	if _drag_preview and is_instance_valid(_drag_preview):
		_drag_preview.global_position = get_global_mouse_position() - _drag_preview.size * 0.5


func _make_item_widget(stack: InvItemStack) -> Control:
	var definition: InvItemDef = inventory.database.get_item(stack.item_id)
	var dims := definition.get_grid_size(stack.rotated) if definition else Vector2i.ONE
	var step: float = CELL_SIZE + CELL_GAP
	var widget := Panel.new()
	widget.position = Vector2(stack.grid_position) * step
	widget.size = Vector2(dims) * CELL_SIZE + Vector2(dims - Vector2i.ONE) * CELL_GAP
	widget.mouse_filter = Control.MOUSE_FILTER_STOP
	widget.tooltip_text = (
		"%s\n%s" % [definition.display_name, definition.description]
		if definition
		else stack.item_id
	)
	widget.gui_input.connect(_on_item_gui_input.bind(stack))

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.22, 0.28, 0.95)
	style.set_border_width_all(1)
	style.border_color = Color(0.55, 0.65, 0.75, 0.8)
	style.set_corner_radius_all(3)
	widget.add_theme_stylebox_override("panel", style)

	var icon := TextureRect.new()
	widget.add_child(icon)
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 4.0
	icon.offset_top = 4.0
	icon.offset_right = -4.0
	icon.offset_bottom = -4.0
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if definition:
		icon.texture = definition.icon

	if stack.amount > 1:
		var qty := Label.new()
		widget.add_child(qty)
		qty.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		qty.offset_right = -4.0
		qty.offset_bottom = -2.0
		qty.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		qty.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		qty.text = str(stack.amount)
		qty.add_theme_constant_override("outline_size", 3)
		qty.add_theme_color_override("font_outline_color", Color.BLACK)
		qty.mouse_filter = Control.MOUSE_FILTER_IGNORE

	return widget


func _on_item_gui_input(event: InputEvent, stack: InvItemStack) -> void:
	var mouse := event as InputEventMouseButton
	if mouse == null or not mouse.pressed:
		return
	if mouse.button_index == MOUSE_BUTTON_RIGHT:
		_open_context(stack)
	elif mouse.button_index == MOUSE_BUTTON_LEFT:
		if mouse.double_click:
			_use_item(stack)
		else:
			_begin_drag(stack)


func _begin_drag(stack: InvItemStack) -> void:
	_drag_stack = stack
	_drag_index = inventory.get_stack_index(stack)
	_drag_rotated = stack.rotated
	_update_drag_preview()
	refresh()


func _update_drag_preview() -> void:
	if _drag_preview and is_instance_valid(_drag_preview):
		_drag_preview.queue_free()
	_drag_preview = null
	if _drag_stack == null:
		return
	var temp := _drag_stack.duplicate_stack()
	temp.rotated = _drag_rotated
	_drag_preview = _make_item_widget(temp)
	_drag_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_drag_preview)


func _drop_drag(local_pos: Vector2) -> void:
	if _drag_stack == null:
		return
	var cell := _pos_to_cell(local_pos)
	inventory.move_stack(_drag_index, cell, _drag_rotated)
	_cancel_drag()
	refresh()


func _pos_to_cell(local_pos: Vector2) -> Vector2i:
	var step: float = CELL_SIZE + CELL_GAP
	return Vector2i(int(floor(local_pos.x / step)), int(floor(local_pos.y / step)))


func _cancel_drag() -> void:
	_drag_stack = null
	_drag_index = -1
	_drag_rotated = false
	if _drag_preview and is_instance_valid(_drag_preview):
		_drag_preview.queue_free()
	_drag_preview = null


func _open_context(stack: InvItemStack) -> void:
	selected_stack = stack
	var definition: InvItemDef = inventory.database.get_item(stack.item_id)
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
	if selected_stack == null:
		return
	match option_id:
		MENU_USE:
			_use_item(selected_stack)
		MENU_DROP:
			_drop_item(selected_stack)
		MENU_DEPLOY:
			_deploy_item(selected_stack)
	selected_stack = null


func _is_consumable(definition: InvItemDef) -> bool:
	if definition == null:
		return false
	for property_name in ["hunger_restore", "thirst_restore", "sanity_restore", "health_restore"]:
		if float(definition.properties.get(property_name, 0.0)) > 0.0:
			return true
	return false


func _is_deployable(definition: InvItemDef) -> bool:
	return definition != null and bool(definition.properties.get("deployable", false))


func _use_item(stack: InvItemStack) -> void:
	var definition: InvItemDef = inventory.database.get_item(stack.item_id)
	if not _is_consumable(definition):
		return
	player.hunger = clampf(player.hunger + float(definition.properties.get("hunger_restore", 0.0)), 0.0, MAX_STAT)
	player.thirst = clampf(player.thirst + float(definition.properties.get("thirst_restore", 0.0)), 0.0, MAX_STAT)
	player.sanity = clampf(player.sanity + float(definition.properties.get("sanity_restore", 0.0)), 0.0, MAX_STAT)
	player.health = clampf(player.health + float(definition.properties.get("health_restore", 0.0)), 0.0, MAX_STAT)
	inventory.remove(stack.item_id, 1)


func _drop_item(stack: InvItemStack) -> void:
	var definition: InvItemDef = inventory.database.get_item(stack.item_id)
	if definition == null:
		return
	var scene_path: String = str(definition.properties.get("dropped_item", ""))
	if scene_path.is_empty():
		return
	var packed_scene := load(scene_path) as PackedScene
	if packed_scene == null:
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


func _deploy_item(stack: InvItemStack) -> void:
	var definition: InvItemDef = inventory.database.get_item(stack.item_id)
	if not _is_deployable(definition):
		return
	var scene_path: String = str(definition.properties.get("deployable_scene", ""))
	if scene_path.is_empty():
		return
	var placement_controller: Node = player.get_node_or_null("DeployablePlacement")
	if placement_controller == null:
		return
	set_inventory_visible(false)
	if not placement_controller.begin_placement(stack.item_id, scene_path, inventory):
		set_inventory_visible(true)
