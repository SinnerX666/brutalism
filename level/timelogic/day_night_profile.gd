class_name DayNightProfile
extends Resource

@export_group("Late Autumn Schedule")
@export_range(0.0, 24.0, 0.05) var dawn_start: float = 6.5
@export_range(0.0, 24.0, 0.05) var sunrise: float = 7.25
@export_range(0.0, 24.0, 0.05) var sunset: float = 16.5
@export_range(0.0, 24.0, 0.05) var dusk_end: float = 17.25

@export_group("Sun Path")
@export_range(1.0, 90.0, 0.5) var maximum_sun_elevation: float = 28.0
@export_range(-180.0, 360.0, 1.0) var sunrise_azimuth: float = 75.0
@export_range(-180.0, 360.0, 1.0) var sunset_azimuth: float = 255.0
@export_range(-30.0, 0.0, 0.5) var night_sun_elevation: float = -10.0

@export_group("Direct Light")
@export var daylight_color: Color = Color(1.0, 0.93, 0.82)
@export var twilight_color: Color = Color(1.0, 0.48, 0.25)
@export_range(0.0, 4.0, 0.05) var noon_sun_energy: float = 1.05
@export_range(0.0, 2.0, 0.05) var horizon_sun_energy: float = 0.18

@export_group("Ambient Light")
@export var day_ambient_color: Color = Color(0.72, 0.78, 0.84)
@export var night_ambient_color: Color = Color(0.075, 0.095, 0.14)
@export_range(0.0, 2.0, 0.05) var day_ambient_energy: float = 0.72
@export_range(0.0, 1.0, 0.01) var night_ambient_energy: float = 0.08

@export_group("Sky")
@export var day_sky_top: Color = Color(0.32, 0.43, 0.56)
@export var day_sky_horizon: Color = Color(0.72, 0.70, 0.62)
@export var day_ground_bottom: Color = Color(0.12, 0.13, 0.14)
@export var day_ground_horizon: Color = Color(0.52, 0.49, 0.42)
@export var night_sky_top: Color = Color(0.008, 0.012, 0.026)
@export var night_sky_horizon: Color = Color(0.035, 0.045, 0.075)
@export var night_ground_bottom: Color = Color(0.004, 0.005, 0.008)
@export var night_ground_horizon: Color = Color(0.018, 0.022, 0.035)
@export var twilight_horizon: Color = Color(0.62, 0.23, 0.12)

@export_group("Artificial Lights")
## Latarnie zapalają się przy zachodzie i gasną po wschodzie.
@export var enable_lamps_at_sunset: bool = true
