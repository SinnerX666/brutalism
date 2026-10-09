class_name DayNightController
extends Node

signal phase_changed(phase: DayPhase)
signal artificial_lights_changed(enabled: bool)

enum DayPhase {
	NIGHT,
	DAWN,
	DAY,
	DUSK,
}

@export var profile: DayNightProfile
@export var time_manager: GameTimeManager
@export var sun: DirectionalLight3D
@export var world_environment: WorldEnvironment

var current_phase: DayPhase = DayPhase.NIGHT
var _artificial_lights_enabled: bool = false
var _sky_material: ProceduralSkyMaterial
var _initialized: bool = false


func _ready() -> void:
	if time_manager == null:
		time_manager = get_tree().get_first_node_in_group("time_manager") as GameTimeManager
	if profile == null:
		push_error("DayNightController: missing DayNightProfile.")
	if time_manager == null:
		push_error("DayNightController: missing GameTimeManager.")
	if sun == null:
		push_error("DayNightController: missing sun DirectionalLight3D.")
	if world_environment == null or world_environment.environment == null:
		push_error("DayNightController: missing WorldEnvironment.")

	_sky_material = _get_sky_material()
	_initialized = (
		profile != null
		and time_manager != null
		and sun != null
		and world_environment != null
		and world_environment.environment != null
	)
	if _initialized:
		apply_lighting()


func _process(_delta: float) -> void:
	if _initialized:
		apply_lighting()


func apply_lighting() -> void:
	var decimal_hour := time_manager.get_decimal_hour()
	var phase := get_phase_for_hour(decimal_hour)
	if phase != current_phase:
		current_phase = phase
		phase_changed.emit(current_phase)

	var daylight_strength := get_daylight_strength(decimal_hour)
	var elevation := get_sun_elevation(decimal_hour)
	var elevation_factor := clampf(
		maxf(elevation, 0.0) / maxf(profile.maximum_sun_elevation, 0.001),
		0.0,
		1.0
	)
	var azimuth := get_sun_azimuth(decimal_hour)

	sun.rotation_degrees = Vector3(-elevation, azimuth, 0.0)
	sun.light_color = profile.twilight_color.lerp(
		profile.daylight_color,
		_smooth01(elevation_factor)
	)
	sun.light_energy = daylight_strength * lerpf(
		profile.horizon_sun_energy,
		profile.noon_sun_energy,
		_smooth01(elevation_factor)
	)
	sun.visible = daylight_strength > 0.001

	_apply_environment(daylight_strength, elevation_factor)
	_update_artificial_lights(_should_enable_artificial_lights(phase))


func get_phase_for_hour(decimal_hour: float) -> DayPhase:
	var hour := fposmod(decimal_hour, 24.0)
	if hour >= profile.dawn_start and hour < profile.sunrise:
		return DayPhase.DAWN
	if hour >= profile.sunrise and hour < profile.sunset:
		return DayPhase.DAY
	if hour >= profile.sunset and hour < profile.dusk_end:
		return DayPhase.DUSK
	return DayPhase.NIGHT


func get_daylight_strength(decimal_hour: float) -> float:
	var hour := fposmod(decimal_hour, 24.0)
	match get_phase_for_hour(hour):
		DayPhase.DAWN:
			return _smooth01(inverse_lerp(profile.dawn_start, profile.sunrise, hour))
		DayPhase.DAY:
			return 1.0
		DayPhase.DUSK:
			return 1.0 - _smooth01(inverse_lerp(profile.sunset, profile.dusk_end, hour))
		_:
			return 0.0


func get_sun_elevation(decimal_hour: float) -> float:
	var hour := fposmod(decimal_hour, 24.0)
	match get_phase_for_hour(hour):
		DayPhase.DAWN:
			var dawn_t := _smooth01(inverse_lerp(profile.dawn_start, profile.sunrise, hour))
			return lerpf(profile.night_sun_elevation, 0.0, dawn_t)
		DayPhase.DAY:
			var day_t := inverse_lerp(profile.sunrise, profile.sunset, hour)
			return sin(day_t * PI) * profile.maximum_sun_elevation
		DayPhase.DUSK:
			var dusk_t := _smooth01(inverse_lerp(profile.sunset, profile.dusk_end, hour))
			return lerpf(0.0, profile.night_sun_elevation, dusk_t)
		_:
			return profile.night_sun_elevation


func get_sun_azimuth(decimal_hour: float) -> float:
	var hour := fposmod(decimal_hour, 24.0)
	if hour <= profile.sunrise:
		return profile.sunrise_azimuth
	if hour >= profile.sunset:
		return profile.sunset_azimuth
	var day_t := inverse_lerp(profile.sunrise, profile.sunset, hour)
	return lerpf(profile.sunrise_azimuth, profile.sunset_azimuth, day_t)


func _apply_environment(daylight_strength: float, elevation_factor: float) -> void:
	var environment := world_environment.environment
	var light_blend := _smooth01(daylight_strength)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = profile.night_ambient_color.lerp(
		profile.day_ambient_color,
		light_blend
	)
	environment.ambient_light_energy = lerpf(
		profile.night_ambient_energy,
		profile.day_ambient_energy,
		light_blend
	)

	if _sky_material == null:
		return
	var twilight_weight := (1.0 - _smooth01(elevation_factor)) * light_blend
	_sky_material.sky_top_color = profile.night_sky_top.lerp(
		profile.day_sky_top,
		light_blend
	)
	_sky_material.sky_horizon_color = (
		profile.night_sky_horizon
		.lerp(profile.day_sky_horizon, light_blend)
		.lerp(profile.twilight_horizon, twilight_weight)
	)
	_sky_material.ground_bottom_color = profile.night_ground_bottom.lerp(
		profile.day_ground_bottom,
		light_blend
	)
	_sky_material.ground_horizon_color = (
		profile.night_ground_horizon
		.lerp(profile.day_ground_horizon, light_blend)
		.lerp(profile.twilight_horizon.darkened(0.35), twilight_weight)
	)


func _should_enable_artificial_lights(phase: DayPhase) -> bool:
	if not profile.enable_lamps_at_sunset:
		return false
	return phase != DayPhase.DAY


func _update_artificial_lights(should_enable: bool) -> void:
	if _artificial_lights_enabled == should_enable:
		return
	_artificial_lights_enabled = should_enable
	get_tree().call_group("street_lamp", "set_powered", should_enable)
	artificial_lights_changed.emit(should_enable)


func _get_sky_material() -> ProceduralSkyMaterial:
	if world_environment == null or world_environment.environment == null:
		return null
	var sky := world_environment.environment.sky
	if sky == null:
		return null
	return sky.sky_material as ProceduralSkyMaterial


func _smooth01(value: float) -> float:
	var t := clampf(value, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
