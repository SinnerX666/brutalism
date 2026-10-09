extends SceneTree

const STREET_LAMP_SCENE := preload("res://level/blockout/street_lamp_placeholder.tscn")
const LATE_AUTUMN_PROFILE := preload("res://level/timelogic/late_autumn_day_night.tres")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_time_manager()
	_test_profile_boundaries()
	await _test_level_lighting()

	if _failures.is_empty():
		print("DAY_NIGHT_SMOKE_OK")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_time_manager() -> void:
	var clock := GameTimeManager.new()
	root.add_child(clock)
	await process_frame

	_check(clock.day == 1 and clock.hours == 8 and clock.minutes == 0, "Clock must start at day 1, 08:00.")
	clock.set_datetime(2, 23, 50, false)
	clock.advance_minutes(2890.0)
	_check(clock.day == 5 and clock.hours == 0 and clock.minutes == 0, "Clock must handle multi-day advancement.")
	clock.set_time(14, 25)
	_check(clock.get_time_string() == "14:25", "set_time must preserve the public HUD API.")
	clock.set_time_scale(500.0)
	_check(is_equal_approx(clock.time_scale, 500.0), "Sleep time scaling must remain compatible.")
	clock.queue_free()
	await process_frame


func _test_profile_boundaries() -> void:
	var controller := DayNightController.new()
	controller.profile = LATE_AUTUMN_PROFILE

	_check(controller.get_phase_for_hour(6.0 + 29.0 / 60.0) == DayNightController.DayPhase.NIGHT, "06:29 must be night.")
	_check(controller.get_phase_for_hour(6.5) == DayNightController.DayPhase.DAWN, "06:30 must begin dawn.")
	_check(controller.get_phase_for_hour(7.25) == DayNightController.DayPhase.DAY, "07:15 must begin day.")
	_check(controller.get_phase_for_hour(16.5) == DayNightController.DayPhase.DUSK, "16:30 must begin dusk.")
	_check(controller.get_phase_for_hour(17.25) == DayNightController.DayPhase.NIGHT, "17:15 must begin night.")
	controller.free()


func _test_level_lighting() -> void:
	var fixture := Node3D.new()
	var clock := GameTimeManager.new()
	var sun := DirectionalLight3D.new()
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	environment.sky = sky
	world_environment.environment = environment
	sun.shadow_enabled = true
	fixture.add_child(clock)
	fixture.add_child(sun)
	fixture.add_child(world_environment)

	var lamps: Array[Node] = []
	for index in 4:
		var lamp := STREET_LAMP_SCENE.instantiate() as StreetLamp
		lamp.casts_shadows = index < 2
		fixture.add_child(lamp)
		lamps.append(lamp)

	var controller := DayNightController.new()
	controller.profile = LATE_AUTUMN_PROFILE
	controller.time_manager = clock
	controller.sun = sun
	controller.world_environment = world_environment
	fixture.add_child(controller)
	root.add_child(fixture)
	await process_frame

	_check(sun != null and sun.shadow_enabled, "Sun must remain the global shadow-casting light.")
	_check(lamps.size() == 4, "Urban blockout must expose four street lamps.")
	_check(_count_shadow_lamps(lamps) == 2, "Exactly two prototype street lamps should cast shadows.")

	clock.set_time(12, 0)
	await process_frame
	_check(sun.visible and sun.light_energy > 0.0, "Sun must illuminate the level at noon.")
	_check(controller.get_sun_elevation(12.0) > 20.0, "Late-autumn noon sun must be above the horizon.")
	_check(_count_powered_lamps(lamps) == 0, "Street lamps must be off during the day.")

	clock.set_time(0, 0)
	await process_frame
	_check(not sun.visible and is_zero_approx(sun.light_energy), "Sun must be disabled at midnight.")
	_check(_count_powered_lamps(lamps) == lamps.size(), "All street lamps must turn on at night.")

	fixture.queue_free()
	await process_frame


func _count_shadow_lamps(lamps: Array[Node]) -> int:
	var count := 0
	for lamp in lamps:
		var light := lamp.get_node("LightAnchor/SpotLight3D") as SpotLight3D
		if light != null and light.shadow_enabled:
			count += 1
	return count


func _count_powered_lamps(lamps: Array[Node]) -> int:
	var count := 0
	for lamp in lamps:
		var light := lamp.get_node("LightAnchor/SpotLight3D") as SpotLight3D
		if light != null and light.visible:
			count += 1
	return count


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
