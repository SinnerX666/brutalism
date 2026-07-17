class_name GameHUD
extends Control

@onready var item_name_label: Label = $ItemName
@onready var interact_icon: TextureRect = $InteractIcon
@onready var hunger_bar: ProgressBar = $hunger
@onready var thirst_bar: ProgressBar = $thirst
@onready var tired_bar: ProgressBar = $eep

var stamina_bar: ProgressBar
var _stamina_visible_alpha: float = 0.0
var _want_stamina_visible: bool = false


func _ready() -> void:
	hide_interaction()
	_ensure_stamina_bar()


func _process(delta: float) -> void:
	if stamina_bar == null:
		return
	var target_alpha: float = 0.55 if _want_stamina_visible else 0.0
	_stamina_visible_alpha = move_toward(_stamina_visible_alpha, target_alpha, delta * 4.0)
	stamina_bar.modulate.a = _stamina_visible_alpha
	stamina_bar.visible = _want_stamina_visible or _stamina_visible_alpha > 0.01


func update_needs(hunger: float, thirst: float, tired: float) -> void:
	hunger_bar.value = hunger
	thirst_bar.value = thirst
	tired_bar.value = tired


func update_stamina(current: float, maximum: float, sprinting: bool = false) -> void:
	_ensure_stamina_bar()
	stamina_bar.max_value = maximum
	stamina_bar.value = current
	var regenerating: bool = current < maximum - 0.5 and not sprinting
	_want_stamina_visible = sprinting or regenerating


func show_interaction(display_name: String, texture: Texture2D) -> void:
	item_name_label.text = display_name
	item_name_label.visible = not display_name.is_empty()
	interact_icon.texture = texture
	interact_icon.visible = texture != null


func hide_interaction() -> void:
	item_name_label.visible = false
	interact_icon.visible = false


func _ensure_stamina_bar() -> void:
	if stamina_bar != null:
		return
	stamina_bar = ProgressBar.new()
	stamina_bar.name = "StaminaBar"
	add_child(stamina_bar)
	stamina_bar.set_anchors_preset(Control.PRESET_CENTER)
	stamina_bar.offset_left = -70.0
	stamina_bar.offset_top = 196.0
	stamina_bar.offset_right = 70.0
	stamina_bar.offset_bottom = 208.0
	stamina_bar.show_percentage = false
	stamina_bar.max_value = 100.0
	stamina_bar.value = 100.0
	stamina_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stamina_bar.modulate = Color(0.85, 0.9, 1.0, 0.0)
	stamina_bar.visible = false

	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.75, 0.88, 1.0, 0.7)
	fill.set_corner_radius_all(2)
	stamina_bar.add_theme_stylebox_override("fill", fill)

	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.05, 0.07, 0.1, 0.35)
	background.set_corner_radius_all(2)
	stamina_bar.add_theme_stylebox_override("background", background)
