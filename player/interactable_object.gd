class_name InteractableObject
extends CollisionObject3D

@export var display_name: String = ""
@export var interaction_icon: Texture2D


func get_display_name() -> String:
	if not display_name.is_empty():
		return display_name
	return name.replace("_", " ").capitalize()


func get_interaction_icon() -> Texture2D:
	return interaction_icon
