extends Node

const SETTINGS_PATH := "user://settings.cfg"
const SECTION := "audio"
const MASTER_VOLUME_KEY := "master_volume"
const DEFAULT_MASTER_VOLUME := 0.8

var master_volume: float = DEFAULT_MASTER_VOLUME


func _ready() -> void:
	load_settings()
	apply_audio()


func set_master_volume(value: float, save_now: bool = true) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	apply_audio()
	if save_now:
		save_settings()


func apply_audio() -> void:
	var bus_idx := AudioServer.get_bus_index("Master")
	if bus_idx < 0:
		return
	if master_volume <= 0.0001:
		AudioServer.set_bus_mute(bus_idx, true)
		AudioServer.set_bus_volume_db(bus_idx, -80.0)
	else:
		AudioServer.set_bus_mute(bus_idx, false)
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(master_volume))


func load_settings() -> void:
	var config := ConfigFile.new()
	var err := config.load(SETTINGS_PATH)
	if err != OK:
		master_volume = DEFAULT_MASTER_VOLUME
		return
	master_volume = clampf(
		float(config.get_value(SECTION, MASTER_VOLUME_KEY, DEFAULT_MASTER_VOLUME)),
		0.0,
		1.0
	)


func save_settings() -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value(SECTION, MASTER_VOLUME_KEY, master_volume)
	config.save(SETTINGS_PATH)
