extends RayCast3D

const PICK_UP_ICON := preload("res://UI/assets/pick_up_icon.png")
const EAT_ICON := preload("res://UI/assets/eat_icon.png")
const DRINK_ICON := preload("res://UI/assets/drink_icon.png")
const MEDS_ICON := preload("res://UI/assets/meds_icon.png")
const SLEEP_ICON := preload("res://UI/assets/sleep_icon_32.png")

var hud


func _ready() -> void:
	hud = get_tree().get_first_node_in_group("game_hud")


func _physics_process(_delta: float) -> void:
	if hud == null:
		return
	hud.hide_interaction()
	if not is_colliding():
		return

	var collider := get_collider() as Node
	if collider == null:
		return

	var interaction_icon := _get_interaction_icon(collider)
	var display_name := ""
	if collider.has_method("get_display_name"):
		display_name = collider.get_display_name()
	elif interaction_icon or collider is RigidBody3D:
		display_name = collider.name.replace("_", " ").capitalize()
	hud.show_interaction(display_name, interaction_icon)


func _get_interaction_icon(collider: Node) -> Texture2D:
	if collider.has_method("get_interaction_icon"):
		var custom_icon: Texture2D = collider.get_interaction_icon()
		if custom_icon:
			return custom_icon
	if collider.is_in_group("beds"):
		return SLEEP_ICON
	if collider.is_in_group("food"):
		return EAT_ICON
	if collider.is_in_group("drink"):
		return DRINK_ICON
	if collider.is_in_group("meds"):
		return MEDS_ICON
	if collider.is_in_group("pick"):
		return PICK_UP_ICON
	if collider is RigidBody3D:
		var body := collider as RigidBody3D
		var player := get_tree().get_first_node_in_group("player")
		if player and "max_manipulate_mass" in player:
			var max_manipulate: float = player.max_manipulate_mass
			if body.mass <= max_manipulate:
				if body is WorldItem and body.has_method("can_hold") and not body.can_hold():
					return null
				return PICK_UP_ICON
	return null
