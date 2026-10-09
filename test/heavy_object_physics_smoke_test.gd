extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("Heavy object physics smoke test: %s" % message)


func _run() -> void:
	var level_scene := load("res://level/node_3d.tscn") as PackedScene
	var level := level_scene.instantiate()
	root.add_child(level)
	await process_frame
	await physics_frame

	var player := get_first_node_in_group("player")
	var wardrobe := level.get_node_or_null("Items/HeavyWardrobe") as RigidBody3D
	_check(player != null, "player was not found")
	_check(wardrobe != null, "heavy wardrobe was not found")
	if player == null or wardrobe == null:
		_finish(level)
		return

	_check(
		wardrobe.center_of_mass_mode == RigidBody3D.CENTER_OF_MASS_MODE_AUTO,
		"wardrobe does not use its collision shape center of mass"
	)
	_check(
		not wardrobe.axis_lock_angular_x and not wardrobe.axis_lock_angular_z,
		"wardrobe tipping axes are locked"
	)

	wardrobe.global_position = player.global_position + Vector3(0, 0.5, -2)
	player.set_grabbed_object(wardrobe)
	wardrobe.rotation.x = 0.2
	wardrobe.angular_velocity = Vector3(0.5, 0.0, 0.25)
	player._update_grabbed_object()
	_check(not wardrobe.axis_lock_angular_x, "grabbing locked the X tipping axis")
	_check(not wardrobe.axis_lock_angular_z, "grabbing locked the Z tipping axis")
	_check(absf(wardrobe.rotation.x) > 0.1, "grab update forced the wardrobe upright")
	_check(
		absf(wardrobe.angular_velocity.x) > 0.1,
		"grab update erased physical tipping velocity"
	)
	player.release_grabbed_object()

	wardrobe.gravity_scale = 0.0
	wardrobe.linear_velocity = Vector3.ZERO
	wardrobe.angular_velocity = Vector3.ZERO
	wardrobe.apply_torque_impulse(Vector3(0, 0, 200))
	await physics_frame
	await physics_frame
	_check(
		absf(wardrobe.angular_velocity.z) > 0.01,
		"wardrobe did not respond to tipping torque"
	)

	_finish(level)


func _finish(level: Node) -> void:
	level.queue_free()
	await process_frame
	if failures.is_empty():
		print("HEAVY_OBJECT_PHYSICS_SMOKE_OK")
		quit(0)
	else:
		quit(1)
