extends Control

signal back_pressed

@onready var tab_container: TabContainer = $Panel/Margin/VBox/TabContainer
@onready var master_slider: HSlider = $Panel/Margin/VBox/TabContainer/Audio/MasterRow/MasterSlider
@onready var master_value_label: Label = $Panel/Margin/VBox/TabContainer/Audio/MasterRow/MasterValue
@onready var mute_button: CheckButton = $Panel/Margin/VBox/TabContainer/Audio/MuteButton
@onready var back_button: Button = $Panel/Margin/VBox/BackButton

var _updating_ui: bool = false
var _volume_before_mute: float = 0.8


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	tab_container.set_tab_title(0, "Dźwięk")
	tab_container.set_tab_title(1, "Grafika")
	tab_container.set_tab_title(2, "Sterowanie")
	tab_container.set_tab_title(3, "Ekran")
	back_button.pressed.connect(_on_back_pressed)
	master_slider.value_changed.connect(_on_master_slider_changed)
	mute_button.toggled.connect(_on_mute_toggled)
	refresh_from_settings()


func refresh_from_settings() -> void:
	_updating_ui = true
	var volume: float = GameSettings.master_volume
	master_slider.value = volume
	_update_volume_label(volume)
	mute_button.button_pressed = volume <= 0.0001
	if volume > 0.0001:
		_volume_before_mute = volume
	_updating_ui = false


func focus_default() -> void:
	back_button.grab_focus()


func _on_master_slider_changed(value: float) -> void:
	if _updating_ui:
		return
	GameSettings.set_master_volume(value)
	_update_volume_label(value)
	_updating_ui = true
	mute_button.button_pressed = value <= 0.0001
	_updating_ui = false
	if value > 0.0001:
		_volume_before_mute = value


func _on_mute_toggled(is_muted: bool) -> void:
	if _updating_ui:
		return
	if is_muted:
		if GameSettings.master_volume > 0.0001:
			_volume_before_mute = GameSettings.master_volume
		GameSettings.set_master_volume(0.0)
	else:
		GameSettings.set_master_volume(
			_volume_before_mute if _volume_before_mute > 0.0001 else 0.5
		)
	refresh_from_settings()


func _on_back_pressed() -> void:
	back_pressed.emit()


func _update_volume_label(value: float) -> void:
	master_value_label.text = "%d%%" % int(round(value * 100.0))
