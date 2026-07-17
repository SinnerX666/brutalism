class_name DeployablePlacementController
extends Node

@export var max_placement_distance: float = 5.0
@export_flags_3d_physics var placement_surface_mask: int = 2
@export var minimum_surface_up_dot: float = 0.75
@export var surface_clearance: float = 0.03
@export var rotation_step_degrees: float = 45.0

var player: CharacterBody3D
var camera: Camera3D
var inventory: GridInventory
var preview: Node3D
var deploy_scene: PackedScene
var deploy_item_id: String = ""
var placement_footprint: Vector3 = Vector3.ONE
var placement_valid: bool = false
var placement_transform := Transform3D.IDENTITY
var rotation_degrees: float = 0.0


func _ready() -> void:
	player = get_parent() as CharacterBody3D
	if player:
		camera = player.get_node_or_null("Head/Camera3D") as Camera3D


func is_placing() -> bool:
	return is_instance_valid(preview)


func begin_placement(item_id: String, scene_path: String, source_inventory: GridInventory) -> bool:
	if is_placing() or camera == null or source_inventory == null:
		return false

	deploy_scene = load(scene_path) as PackedScene
	if deploy_scene == null:
		push_error("DeployablePlacement: could not load %s." % scene_path)
		return false

	preview = deploy_scene.instantiate() as Node3D
	if preview == null or not preview.has_method("configure_as_placement_preview"):
		if preview:
			preview.free()
		preview = null
		push_error("DeployablePlacement: scene is not a deployable world item.")
		return false

	deploy_item_id = item_id
	inventory = source_inventory
	placement_footprint = preview.get_placement_footprint()
	rotation_degrees = 0.0

	var items_container: Node = get_tree().get_first_node_in_group("world_items_container")
	if items_container:
		items_container.add_child(preview)
	else:
		get_tree().current_scene.add_child(preview)
	preview.configure_as_placement_preview()
	player.set_deployment_mode(true)
	return true


func cancel_placement() -> void:
	_finish_placement()


func _process(_delta: float) -> void:
	if not is_placing():
		return
	_update_preview()


func _input(event: InputEvent) -> void:
	if not is_placing():
		return

	if event.is_action_pressed("rotate"):
		rotation_degrees = fmod(rotation_degrees + rotation_step_degrees, 360.0)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("item_place") or event.is_action_pressed("interact"):
		_confirm_placement()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("escape"):
		cancel_placement()
		get_viewport().set_input_as_handled()


func _update_preview() -> void:
	var from := camera.global_position
	var to := from - camera.global_basis.z * max_placement_distance
	var ray_query := PhysicsRayQueryParameters3D.create(
		from,
		to,
		placement_surface_mask,
		[player.get_rid()]
	)
	var hit := player.get_world_3d().direct_space_state.intersect_ray(ray_query)
	placement_valid = false
	if hit.is_empty():
		preview.visible = false
		return

	preview.visible = true
	var normal: Vector3 = hit.normal
	var basis := _surface_basis(normal)
	var center: Vector3 = hit.position + normal * (
		placement_footprint.y * 0.5 + surface_clearance
	)
	placement_transform = Transform3D(basis, center)
	preview.global_transform = placement_transform
	placement_valid = (
		normal.dot(Vector3.UP) >= minimum_surface_up_dot
		and _has_clear_placement_space()
	)
	preview.set_placement_preview_valid(placement_valid)


func _surface_basis(normal: Vector3) -> Basis:
	var forward := (-camera.global_basis.z).slide(normal).normalized()
	if forward.is_zero_approx():
		forward = Vector3.FORWARD.slide(normal).normalized()
	var base := Basis.looking_at(forward, normal)
	return Basis(normal, deg_to_rad(rotation_degrees)) * base


func _has_clear_placement_space() -> bool:
	var shape := BoxShape3D.new()
	shape.size = Vector3(
		maxf(placement_footprint.x - 0.04, 0.05),
		maxf(placement_footprint.y - 0.02, 0.02),
		maxf(placement_footprint.z - 0.04, 0.05)
	)
	var shape_query := PhysicsShapeQueryParameters3D.new()
	shape_query.shape = shape
	shape_query.transform = placement_transform
	shape_query.collision_mask = 0xFFFFFFFF
	shape_query.collide_with_areas = false
	shape_query.collide_with_bodies = true
	shape_query.exclude = [player.get_rid()]
	return player.get_world_3d().direct_space_state.intersect_shape(shape_query, 1).is_empty()


func _confirm_placement() -> void:
	if not placement_valid or inventory == null:
		return

	var deployed := deploy_scene.instantiate() as Node3D
	if deployed == null:
		return
	if inventory.remove(deploy_item_id, 1) != 0:
		deployed.free()
		cancel_placement()
		return

	var items_container: Node = get_tree().get_first_node_in_group("world_items_container")
	if items_container:
		items_container.add_child(deployed)
	else:
		get_tree().current_scene.add_child(deployed)
	deployed.global_transform = placement_transform
	_finalize_deployed(deployed)
	_finish_placement()


func _finalize_deployed(deployed: Node3D) -> void:
	if deployed.has_method("finalize_placement"):
		deployed.finalize_placement()
		return
	if deployed is RigidBody3D:
		var body := deployed as RigidBody3D
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO
		body.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
		body.freeze = true


func _finish_placement() -> void:
	if is_instance_valid(preview):
		preview.queue_free()
	preview = null
	deploy_scene = null
	deploy_item_id = ""
	inventory = null
	placement_valid = false
	if player:
		player.set_deployment_mode(false)
