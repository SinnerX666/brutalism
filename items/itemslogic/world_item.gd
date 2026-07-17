class_name WorldItem
extends RigidBody3D

@export var item_id: String = ""
@export var display_name: String = ""
@export var hunger_restore: float = 0.0
@export var thirst_restore: float = 0.0
@export var sanity_restore: float = 0.0
@export var health_restore: float = 0.0
@export_range(0.0, 5.0, 0.01) var collision_radius_override: float = 0.0


func use_item() -> void:
	if not can_use():
		return
	queue_free()


func can_use() -> bool:
	return (
		hunger_restore > 0.0
		or thirst_restore > 0.0
		or sanity_restore > 0.0
		or health_restore > 0.0
	)


func can_stash() -> bool:
	return true


func can_hold() -> bool:
	return true


func get_display_name() -> String:
	if not display_name.is_empty():
		return display_name
	if not item_id.is_empty():
		return item_id.replace("_", " ").capitalize()
	return name


func get_collision_radius() -> float:
	if collision_radius_override > 0.0:
		return collision_radius_override

	var result := 0.1
	for child in find_children("*", "CollisionShape3D", true, false):
		var collision_shape := child as CollisionShape3D
		if collision_shape == null or collision_shape.disabled or collision_shape.shape == null:
			continue

		var shape_radius := _get_shape_radius(collision_shape.shape)
		var shape_scale := collision_shape.scale.abs()
		var max_shape_scale: float = maxf(shape_scale.x, maxf(shape_scale.y, shape_scale.z))
		result = maxf(
			result,
			collision_shape.position.length() + shape_radius * max_shape_scale
		)

	var body_scale := scale.abs()
	return result * maxf(body_scale.x, maxf(body_scale.y, body_scale.z))


func _get_shape_radius(shape: Shape3D) -> float:
	if shape is SphereShape3D:
		return shape.radius
	if shape is BoxShape3D:
		return shape.size.length() * 0.5
	if shape is CapsuleShape3D:
		return maxf(shape.radius, shape.height * 0.5)
	if shape is CylinderShape3D:
		return Vector2(shape.radius, shape.height * 0.5).length()
	if shape is ConvexPolygonShape3D:
		var radius := 0.0
		for point in shape.points:
			radius = maxf(radius, point.length())
		return radius
	if shape is ConcavePolygonShape3D:
		var radius := 0.0
		for point in shape.get_faces():
			radius = maxf(radius, point.length())
		return radius
	return 0.5
