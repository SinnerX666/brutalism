class_name StreetLamp
extends Node3D

@export var casts_shadows: bool = false
@onready var light: SpotLight3D = $LightAnchor/SpotLight3D

var is_powered: bool = false


func _ready() -> void:
	light.shadow_enabled = casts_shadows
	set_powered(false)


func set_powered(enabled: bool) -> void:
	is_powered = enabled
	if light:
		light.visible = enabled
