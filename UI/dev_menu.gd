extends CanvasLayer

const ALLOW_IN_RELEASE_BUILDS := false
const PANEL_WIDTH := 470.0

var _is_open := false
var _pause_while_open := true
var _god_mode := false
var _tree_was_paused := false
var _previous_mouse_mode := Input.MOUSE_MODE_CAPTURED
var _status_refresh_timer := 0.0

var _panel: PanelContainer
var _status_label: Label
var _clock_label: Label
var _player_label: Label
var _item_selector: OptionButton
var _pause_checkbox: CheckButton
var _god_mode_checkbox: CheckButton


func _ready() -> void:
	if not OS.is_debug_build() and not ALLOW_IN_RELEASE_BUILDS:
		queue_free()
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 1000
	_build_ui()
	hide()


func _input(event: InputEvent) -> void:
	if (
		event is InputEventKey
		and event.pressed
		and not event.echo
		and (event.keycode == KEY_F1 or event.physical_keycode == KEY_F1)
	):
		toggle()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _god_mode:
		_restore_player_stats(false)
	if not _is_open:
		return
	_status_refresh_timer -= delta
	if _status_refresh_timer <= 0.0:
		_status_refresh_timer = 0.15
		_refresh_readouts()


func toggle() -> void:
	if _is_open:
		close()
	else:
		open()


func open() -> void:
	if _is_open:
		return
	_is_open = true
	_tree_was_paused = get_tree().paused
	_previous_mouse_mode = Input.mouse_mode
	if _pause_while_open:
		get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	show()
	_refresh_item_selector()
	_refresh_readouts()


func close() -> void:
	if not _is_open:
		return
	_is_open = false
	hide()
	get_tree().paused = _tree_was_paused
	Input.mouse_mode = _previous_mouse_mode


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_panel.position = Vector2(18.0, 18.0)
	_panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	_panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	margin.add_child(content)

	var title_row := HBoxContainer.new()
	content.add_child(title_row)
	var title := Label.new()
	title.text = "SACRUM — DEV MENU"
	title.add_theme_font_size_override("font_size", 20)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	_add_button(title_row, "Close [F1]", close)

	_status_label = Label.new()
	_status_label.text = "Ready"
	_status_label.modulate = Color(0.75, 0.85, 1.0)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_status_label)

	_pause_checkbox = CheckButton.new()
	_pause_checkbox.text = "Pause game while menu is open"
	_pause_checkbox.button_pressed = true
	_pause_checkbox.toggled.connect(_set_pause_while_open)
	content.add_child(_pause_checkbox)

	_add_separator(content)
	_add_heading(content, "WORLD TIME")
	_clock_label = Label.new()
	content.add_child(_clock_label)

	var time_presets := GridContainer.new()
	time_presets.columns = 4
	content.add_child(time_presets)
	_add_button(time_presets, "Dawn 06:30", _set_time.bind(6, 30))
	_add_button(time_presets, "Morning 08:00", _set_time.bind(8, 0))
	_add_button(time_presets, "Noon 12:00", _set_time.bind(12, 0))
	_add_button(time_presets, "Dusk 16:30", _set_time.bind(16, 30))
	_add_button(time_presets, "Night 00:00", _set_time.bind(0, 0))
	_add_button(time_presets, "-1 hour", _advance_time.bind(-60.0))
	_add_button(time_presets, "+1 hour", _advance_time.bind(60.0))
	_add_button(time_presets, "+1 day", _advance_time.bind(1440.0))

	var time_scale_row := HBoxContainer.new()
	content.add_child(time_scale_row)
	var time_scale_label := Label.new()
	time_scale_label.text = "Clock speed:"
	time_scale_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	time_scale_row.add_child(time_scale_label)
	_add_button(time_scale_row, "1×", _set_time_scale.bind(1.0))
	_add_button(time_scale_row, "10×", _set_time_scale.bind(10.0))
	_add_button(time_scale_row, "100×", _set_time_scale.bind(100.0))

	_add_separator(content)
	_add_heading(content, "PLAYER")
	_player_label = Label.new()
	_player_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_player_label)

	var player_actions := GridContainer.new()
	player_actions.columns = 3
	content.add_child(player_actions)
	_add_button(player_actions, "Restore all", _restore_player_stats.bind(true))
	_add_button(player_actions, "Critical needs", _set_critical_needs)
	_add_button(player_actions, "Damage -25", _damage_player.bind(25.0))
	_add_button(player_actions, "Reset position", _reset_player_position)
	_add_button(player_actions, "Refill stamina", _refill_stamina)

	_god_mode_checkbox = CheckButton.new()
	_god_mode_checkbox.text = "God mode / freeze needs"
	_god_mode_checkbox.toggled.connect(_set_god_mode)
	content.add_child(_god_mode_checkbox)

	_add_separator(content)
	_add_heading(content, "INVENTORY")
	var inventory_row := HBoxContainer.new()
	content.add_child(inventory_row)
	_item_selector = OptionButton.new()
	_item_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inventory_row.add_child(_item_selector)
	_add_button(inventory_row, "Add 1", _add_selected_item.bind(1))
	_add_button(inventory_row, "Add 5", _add_selected_item.bind(5))

	var hint := Label.new()
	hint.text = "This menu is loaded globally in debug builds. Add future tools as another section in UI/dev_menu.gd."
	hint.modulate = Color(0.65, 0.65, 0.65)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(hint)


func _add_heading(parent: Control, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	parent.add_child(label)


func _add_separator(parent: Control) -> void:
	parent.add_child(HSeparator.new())


func _add_button(parent: Control, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _set_pause_while_open(enabled: bool) -> void:
	_pause_while_open = enabled
	if not _is_open:
		return
	get_tree().paused = true if enabled else _tree_was_paused


func _set_god_mode(enabled: bool) -> void:
	_god_mode = enabled
	if enabled:
		_restore_player_stats(true)
	else:
		_set_status("God mode disabled.")


func _set_time(hour: int, minute: int) -> void:
	var clock := _get_clock()
	if clock == null:
		_set_status("No TimeManager in the current scene.", true)
		return
	clock.set_time(hour, minute)
	_set_status("Time set to %02d:%02d." % [hour, minute])
	_refresh_readouts()


func _advance_time(minutes: float) -> void:
	var clock := _get_clock()
	if clock == null:
		_set_status("No TimeManager in the current scene.", true)
		return
	clock.advance_minutes(minutes)
	_set_status("Advanced time by %s minutes." % minutes)
	_refresh_readouts()


func _set_time_scale(scale: float) -> void:
	var clock := _get_clock()
	if clock == null:
		_set_status("No TimeManager in the current scene.", true)
		return
	clock.set_time_scale(scale)
	_set_status("Clock speed set to %s×." % scale)


func _restore_player_stats(show_status: bool = true) -> void:
	var player := _get_player()
	if player == null:
		if show_status:
			_set_status("No player in the current scene.", true)
		return
	player.set("hunger", 100.0)
	player.set("thirst", 100.0)
	player.set("sanity", 100.0)
	player.set("tired", 100.0)
	player.set("health", 100.0)
	player.set("stamina", float(player.get("max_stamina")))
	if show_status:
		_set_status("Player stats restored.")


func _set_critical_needs() -> void:
	var player := _get_player()
	if player == null:
		_set_status("No player in the current scene.", true)
		return
	player.set("hunger", 5.0)
	player.set("thirst", 5.0)
	player.set("sanity", 5.0)
	player.set("tired", 5.0)
	_set_status("Needs set to critical values.")


func _damage_player(amount: float) -> void:
	var player := _get_player()
	if player == null:
		_set_status("No player in the current scene.", true)
		return
	player.set("health", maxf(float(player.get("health")) - amount, 0.0))
	_set_status("Applied %s damage." % amount)


func _refill_stamina() -> void:
	var player := _get_player()
	if player == null:
		_set_status("No player in the current scene.", true)
		return
	player.set("stamina", float(player.get("max_stamina")))
	_set_status("Stamina refilled.")


func _reset_player_position() -> void:
	var player := _get_player() as Node3D
	if player == null:
		_set_status("No player in the current scene.", true)
		return
	player.global_position = Vector3(0.0, 2.0, 0.0)
	if player is CharacterBody3D:
		player.velocity = Vector3.ZERO
	_set_status("Player moved to the level origin.")


func _refresh_item_selector() -> void:
	var previous_id := ""
	if _item_selector.selected >= 0:
		previous_id = str(_item_selector.get_item_metadata(_item_selector.selected))
	_item_selector.clear()

	var catalog := get_node_or_null("/root/ItemCatalog")
	if catalog == null or not catalog.has_method("get_all_items"):
		_item_selector.add_item("Item catalog unavailable")
		_item_selector.disabled = true
		return

	_item_selector.disabled = false
	var selected_index := 0
	var items: Array = catalog.call("get_all_items")
	for definition in items:
		var index := _item_selector.item_count
		_item_selector.add_item("%s  [%s]" % [definition.display_name, definition.id])
		_item_selector.set_item_metadata(index, definition.id)
		if definition.id == previous_id:
			selected_index = index
	if _item_selector.item_count > 0:
		_item_selector.select(selected_index)


func _add_selected_item(amount: int) -> void:
	var player := _get_player()
	if player == null:
		_set_status("No player in the current scene.", true)
		return
	if _item_selector.selected < 0 or _item_selector.disabled:
		_set_status("No item selected.", true)
		return
	var inventory := player.get("inventory") as InvGrid
	if inventory == null:
		_set_status("Player inventory unavailable.", true)
		return
	var item_id := str(_item_selector.get_item_metadata(_item_selector.selected))
	var remaining := inventory.add(item_id, amount)
	if remaining == 0:
		_set_status("Added %d × %s." % [amount, item_id])
	else:
		_set_status("Added %d × %s; %d did not fit." % [amount - remaining, item_id, remaining], true)


func _refresh_readouts() -> void:
	var clock := _get_clock()
	if clock:
		_clock_label.text = "Day %d   %s   speed %.0f×" % [
			clock.day,
			clock.get_time_string(),
			clock.time_scale,
		]
	else:
		_clock_label.text = "No active game clock"

	var player := _get_player()
	if player:
		_player_label.text = (
			"HP %.0f | Hunger %.0f | Thirst %.0f | Sanity %.0f | Tired %.0f | Stamina %.0f\n"
			+ "Position: (%.1f, %.1f, %.1f) | FPS: %d"
		) % [
			float(player.get("health")),
			float(player.get("hunger")),
			float(player.get("thirst")),
			float(player.get("sanity")),
			float(player.get("tired")),
			float(player.get("stamina")),
			player.global_position.x,
			player.global_position.y,
			player.global_position.z,
			Engine.get_frames_per_second(),
		]
	else:
		_player_label.text = "No active player | FPS: %d" % Engine.get_frames_per_second()


func _get_clock() -> GameTimeManager:
	return get_tree().get_first_node_in_group("time_manager") as GameTimeManager


func _get_player() -> Node:
	return get_tree().get_first_node_in_group("player")


func _set_status(message: String, is_error: bool = false) -> void:
	_status_label.text = message
	_status_label.modulate = Color(1.0, 0.55, 0.45) if is_error else Color(0.65, 0.9, 0.7)
