extends RefCounted
class_name AudioSettings

# Main-menu owned settings helper. It keeps bus setup/volume routing out of
# gameplay systems while letting existing audio owners keep their playback logic.

const MASTER_BUS_NAME := "Master"
const MUSIC_BUS_NAME := "Music"
const SFX_BUS_NAME := "SFX"
const POCKET_STREAK_BUS_NAME := "PocketStreakSFX"
const CONFIG_PATH := "user://settings.cfg"
const CONFIG_SECTION := "audio"
const MIN_AUDIBLE_LINEAR := 0.0001

static var _loaded := false
static var _master_volume := 1.0
static var _music_volume := 1.0
static var _sfx_volume := 1.0


static func load_and_apply() -> void:
	if not _loaded:
		_load()
		_loaded = true
	apply_current()


static func apply_current() -> void:
	ensure_audio_buses()
	_apply_bus_volume(MASTER_BUS_NAME, _master_volume)
	_apply_bus_volume(MUSIC_BUS_NAME, _music_volume)
	_apply_bus_volume(SFX_BUS_NAME, _sfx_volume)


static func ensure_audio_buses() -> void:
	_ensure_bus(MUSIC_BUS_NAME, MASTER_BUS_NAME)
	_ensure_bus(SFX_BUS_NAME, MASTER_BUS_NAME)
	_ensure_bus(POCKET_STREAK_BUS_NAME, SFX_BUS_NAME)


static func set_master_volume(value: float, save_to_disk := true) -> void:
	_master_volume = clampf(value, 0.0, 1.0)
	_apply_bus_volume(MASTER_BUS_NAME, _master_volume)
	if save_to_disk:
		_save()


static func set_music_volume(value: float, save_to_disk := true) -> void:
	_music_volume = clampf(value, 0.0, 1.0)
	ensure_audio_buses()
	_apply_bus_volume(MUSIC_BUS_NAME, _music_volume)
	if save_to_disk:
		_save()


static func set_sfx_volume(value: float, save_to_disk := true) -> void:
	_sfx_volume = clampf(value, 0.0, 1.0)
	ensure_audio_buses()
	_apply_bus_volume(SFX_BUS_NAME, _sfx_volume)
	if save_to_disk:
		_save()


static func get_master_volume() -> float:
	return _master_volume


static func get_music_volume() -> float:
	return _music_volume


static func get_sfx_volume() -> float:
	return _sfx_volume


static func is_web_build() -> bool:
	return OS.has_feature("web")


static func _load() -> void:
	var config := ConfigFile.new()
	var error_code: int = config.load(CONFIG_PATH)
	if error_code != OK:
		return

	_master_volume = _read_volume(config, "master", _master_volume)
	_music_volume = _read_volume(config, "music", _music_volume)
	_sfx_volume = _read_volume(config, "sfx", _sfx_volume)


static func _save() -> void:
	var config := ConfigFile.new()
	config.set_value(CONFIG_SECTION, "master", _master_volume)
	config.set_value(CONFIG_SECTION, "music", _music_volume)
	config.set_value(CONFIG_SECTION, "sfx", _sfx_volume)
	config.save(CONFIG_PATH)


static func _read_volume(config: ConfigFile, key: String, fallback: float) -> float:
	var value: Variant = config.get_value(CONFIG_SECTION, key, fallback)
	return clampf(float(value), 0.0, 1.0)


static func _ensure_bus(bus_name: String, send_bus_name: String) -> int:
	var bus_index: int = AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		bus_index = AudioServer.get_bus_count()
		AudioServer.add_bus(bus_index)
		AudioServer.set_bus_name(bus_index, bus_name)

	if bus_name != MASTER_BUS_NAME and send_bus_name != "":
		AudioServer.set_bus_send(bus_index, send_bus_name)

	return bus_index


static func _apply_bus_volume(bus_name: String, volume_linear: float) -> void:
	var bus_index: int = AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return

	var clamped_volume: float = clampf(volume_linear, 0.0, 1.0)
	AudioServer.set_bus_mute(bus_index, clamped_volume <= MIN_AUDIBLE_LINEAR)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(maxf(clamped_volume, MIN_AUDIBLE_LINEAR)))
