extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("Urban blockout smoke test: %s" % message)


func _run() -> void:
	var level_scene := load("res://level/node_3d.tscn") as PackedScene
	_check(level_scene != null, "main level does not load")
	if level_scene == null:
		_finish()
		return

	var level := level_scene.instantiate()
	root.add_child(level)
	await process_frame
	await physics_frame

	var blockout := level.get_node_or_null("MapGeometry/UrbanTestBlock")
	_check(blockout != null, "urban blockout is missing from the main level")
	_check(get_nodes_in_group("blockout_building").size() == 6, "expected six building masses")
	_check(get_nodes_in_group("blockout_street").size() == 2, "expected two street segments")
	_check(get_nodes_in_group("street_lamp").size() == 4, "expected four lamp placeholders")
	_check(get_nodes_in_group("blockout_prop").size() == 7, "expected seven street props")

	var sun := level.get_node_or_null("Environment/DirectionalLight3D") as DirectionalLight3D
	_check(sun != null and sun.shadow_enabled, "existing sun shadow setup was lost")
	_check(level.get_node_or_null("Entities/CharacterBody3D") != null, "player was lost")
	_check(
		level.get_node_or_null("WorldObjects/Workstations/MedicineWorkstation") != null,
		"workstation was lost"
	)

	var space := root.world_3d.direct_space_state
	var building_hit := space.intersect_ray(
		PhysicsRayQueryParameters3D.create(
			Vector3(-10, 20, -15),
			Vector3(-10, -2, -15)
		)
	)
	_check(not building_hit.is_empty(), "north building has no collision")
	if not building_hit.is_empty():
		_check(
			str((building_hit.collider as Node).name) == "Body",
			"building ray did not hit a building body first"
		)

	var street_hit := space.intersect_ray(
		PhysicsRayQueryParameters3D.create(
			Vector3(0, 3, 12),
			Vector3(0, -2, 12)
		)
	)
	_check(not street_hit.is_empty(), "street has no collision")
	if not street_hit.is_empty():
		_check(
			str((street_hit.collider as Node).name) == "Road",
			"street ray did not hit the road first"
		)

	level.queue_free()
	await process_frame
	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("URBAN_BLOCKOUT_SMOKE_OK")
		quit(0)
	else:
		quit(1)
