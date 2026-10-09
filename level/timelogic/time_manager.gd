class_name GameTimeManager
extends Node3D

signal time_updated(hours: int, minutes: int)
signal day_changed(day: int)
signal clock_updated(day: int, hours: int, minutes: int, day_fraction: float)
signal pause_changed(is_paused: bool)

const SECONDS_PER_MINUTE := 60.0
const SECONDS_PER_HOUR := 3600.0
const SECONDS_PER_DAY := 86400.0

@export_group("Initial Time")
@export_range(1, 9999, 1) var start_day: int = 1
@export_range(0, 23, 1) var start_hour: int = 8
@export_range(0, 59, 1) var start_minute: int = 0

@export_group("Clock")
## Długość pełnej growej doby w minutach czasu rzeczywistego.
@export_range(0.0, 1440.0, 0.5) var day_length_in_minutes: float = 60.0
@export var starts_paused: bool = false

var current_seconds: float = 0.0
var minutes: int = 0
var hours: int = 8
var day: int = 1
var time_scale: float = 1.0
var time_multiplier: float = 0.0
var is_paused: bool = false


func _ready() -> void:
	_recalculate_time_multiplier()
	is_paused = starts_paused
	set_datetime(start_day, start_hour, start_minute, false)


func _process(delta: float) -> void:
	if is_paused or time_multiplier <= 0.0 or time_scale <= 0.0:
		return
	update_time(delta * time_multiplier * time_scale)


## Przesuwa zegar o podaną liczbę sekund czasu growego.
func update_time(elapsed_seconds: float) -> void:
	if is_zero_approx(elapsed_seconds):
		return

	var previous_day := day
	var previous_hours := hours
	var previous_minutes := minutes
	var total_seconds := current_seconds + elapsed_seconds

	if total_seconds >= SECONDS_PER_DAY:
		var elapsed_days := floori(total_seconds / SECONDS_PER_DAY)
		day += elapsed_days
		total_seconds = fmod(total_seconds, SECONDS_PER_DAY)
	elif total_seconds < 0.0:
		var days_back := ceili(absf(total_seconds) / SECONDS_PER_DAY)
		day = maxi(day - days_back, 1)
		total_seconds = fposmod(total_seconds, SECONDS_PER_DAY)

	current_seconds = total_seconds
	_sync_components()
	_emit_clock_changes(previous_day, previous_hours, previous_minutes)


func set_datetime(
	new_day: int,
	new_hour: int,
	new_minute: int,
	emit_updates: bool = true
) -> void:
	var previous_day := day
	var previous_hours := hours
	var previous_minutes := minutes

	day = maxi(new_day, 1)
	hours = clampi(new_hour, 0, 23)
	minutes = clampi(new_minute, 0, 59)
	current_seconds = hours * SECONDS_PER_HOUR + minutes * SECONDS_PER_MINUTE

	if emit_updates:
		_emit_clock_changes(previous_day, previous_hours, previous_minutes, true)


func set_time(new_hour: int, new_minute: int = 0) -> void:
	set_datetime(day, new_hour, new_minute)


func advance_minutes(amount: float) -> void:
	update_time(amount * SECONDS_PER_MINUTE)


## Zmienia szybkość zegara, np. podczas snu. Zero zatrzymuje jego upływ.
func set_time_scale(new_time_scale: float) -> void:
	time_scale = maxf(new_time_scale, 0.0)


func set_clock_paused(should_pause: bool) -> void:
	if is_paused == should_pause:
		return
	is_paused = should_pause
	pause_changed.emit(is_paused)


func get_day_fraction() -> float:
	return current_seconds / SECONDS_PER_DAY


func get_decimal_hour() -> float:
	return current_seconds / SECONDS_PER_HOUR


func get_time_string() -> String:
	return "%02d:%02d" % [hours, minutes]


func get_day_string() -> String:
	return "Day %d" % [day]


func _recalculate_time_multiplier() -> void:
	var real_seconds_for_day := day_length_in_minutes * SECONDS_PER_MINUTE
	time_multiplier = (
		SECONDS_PER_DAY / real_seconds_for_day
		if real_seconds_for_day > 0.0
		else 0.0
	)


func _sync_components() -> void:
	hours = floori(current_seconds / SECONDS_PER_HOUR)
	minutes = floori(fmod(current_seconds, SECONDS_PER_HOUR) / SECONDS_PER_MINUTE)


func _emit_clock_changes(
	previous_day: int,
	previous_hours: int,
	previous_minutes: int,
	force: bool = false
) -> void:
	if force or day != previous_day:
		day_changed.emit(day)
	if force or hours != previous_hours or minutes != previous_minutes:
		time_updated.emit(hours, minutes)
	if force or day != previous_day or hours != previous_hours or minutes != previous_minutes:
		clock_updated.emit(day, hours, minutes, get_day_fraction())
