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
const COLLISION_MODE_SAMPLED := "sampled"
const COLLISION_MODE_PROCEDURAL := "procedural"
const COLLISION_MODE_LAYERED := "layered"
const DEFAULT_COLLISION_MODE := COLLISION_MODE_SAMPLED
const COLLISION_MATERIAL_DENSE_PHENOLIC := "dense_phenolic"
const COLLISION_MATERIAL_SOLID_PHENOLIC_A_DRY := "solid_phenolic_a_dry"
const COLLISION_MATERIAL_SOLID_PHENOLIC_B_BALANCED := "solid_phenolic_b_balanced"
const COLLISION_MATERIAL_SOLID_PHENOLIC_C_FULL := "solid_phenolic_c_full"
const COLLISION_MATERIAL_SOLID_PHENOLIC_D_SHARP := "solid_phenolic_d_sharp"
const COLLISION_MATERIAL_RESONANT_RESIN_PROTOTYPE := "resonant_resin_prototype"
const COLLISION_MATERIAL_BRIGHT_PROTOTYPE := "bright_prototype"
const LEGACY_COLLISION_MATERIAL_BILLIARD_RESIN := "billiard_resin"
const DEFAULT_PROCEDURAL_COLLISION_MATERIAL := COLLISION_MATERIAL_SOLID_PHENOLIC_B_BALANCED
const DEFAULT_PROCEDURAL_COLLISION_HARDNESS := 1.0
const DEFAULT_PROCEDURAL_COLLISION_BRIGHTNESS := 1.0
const DEFAULT_PROCEDURAL_COLLISION_BODY := 1.0
const DEFAULT_PROCEDURAL_COLLISION_DECAY := 1.0
const DEFAULT_PROCEDURAL_COLLISION_VARIATION := 1.0
const DEFAULT_PROCEDURAL_COLLISION_VOICE_LIMIT := 24

static var _loaded := false
static var _master_volume := 1.0
static var _music_volume := 1.0
static var _sfx_volume := 1.0
static var _collision_mode := DEFAULT_COLLISION_MODE
static var _procedural_collision_material := DEFAULT_PROCEDURAL_COLLISION_MATERIAL
static var _procedural_collision_hardness := DEFAULT_PROCEDURAL_COLLISION_HARDNESS
static var _procedural_collision_brightness := DEFAULT_PROCEDURAL_COLLISION_BRIGHTNESS
static var _procedural_collision_body := DEFAULT_PROCEDURAL_COLLISION_BODY
static var _procedural_collision_decay := DEFAULT_PROCEDURAL_COLLISION_DECAY
static var _procedural_collision_variation := DEFAULT_PROCEDURAL_COLLISION_VARIATION
static var _procedural_collision_voice_limit := DEFAULT_PROCEDURAL_COLLISION_VOICE_LIMIT


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


static func set_collision_mode(value: String, save_to_disk := true) -> void:
	_collision_mode = _sanitize_collision_mode(value, COLLISION_MODE_SAMPLED)
	if save_to_disk:
		_save()


static func get_collision_mode() -> String:
	return _collision_mode


static func set_procedural_collision_material(value: String, save_to_disk := true) -> void:
	_procedural_collision_material = _sanitize_collision_material(
		value,
		DEFAULT_PROCEDURAL_COLLISION_MATERIAL
	)
	if save_to_disk:
		_save()


static func get_procedural_collision_material() -> String:
	return _procedural_collision_material


static func set_procedural_collision_hardness(value: float, save_to_disk := true) -> void:
	_procedural_collision_hardness = clampf(value, 0.5, 1.5)
	if save_to_disk:
		_save()


static func get_procedural_collision_hardness() -> float:
	return _procedural_collision_hardness


static func set_procedural_collision_brightness(value: float, save_to_disk := true) -> void:
	_procedural_collision_brightness = clampf(value, 0.5, 1.5)
	if save_to_disk:
		_save()


static func get_procedural_collision_brightness() -> float:
	return _procedural_collision_brightness


static func set_procedural_collision_body(value: float, save_to_disk := true) -> void:
	_procedural_collision_body = clampf(value, 0.5, 1.5)
	if save_to_disk:
		_save()


static func get_procedural_collision_body() -> float:
	return _procedural_collision_body


static func set_procedural_collision_decay(value: float, save_to_disk := true) -> void:
	_procedural_collision_decay = clampf(value, 0.65, 1.4)
	if save_to_disk:
		_save()


static func get_procedural_collision_decay() -> float:
	return _procedural_collision_decay


static func set_procedural_collision_variation(value: float, save_to_disk := true) -> void:
	_procedural_collision_variation = clampf(value, 0.0, 1.5)
	if save_to_disk:
		_save()


static func get_procedural_collision_variation() -> float:
	return _procedural_collision_variation


static func set_procedural_collision_voice_limit(value: int, save_to_disk := true) -> void:
	_procedural_collision_voice_limit = clampi(value, 4, 32)
	if save_to_disk:
		_save()


static func get_procedural_collision_voice_limit() -> int:
	return _procedural_collision_voice_limit


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
	if config.has_section_key(CONFIG_SECTION, "ball_collision_mode"):
		_collision_mode = _sanitize_collision_mode(
			str(config.get_value(CONFIG_SECTION, "ball_collision_mode", DEFAULT_COLLISION_MODE)),
			COLLISION_MODE_SAMPLED
		)
	else:
		_collision_mode = DEFAULT_COLLISION_MODE
	_procedural_collision_material = _sanitize_collision_material(
		str(config.get_value(
			CONFIG_SECTION,
			"procedural_collision_material",
			DEFAULT_PROCEDURAL_COLLISION_MATERIAL
		)),
		DEFAULT_PROCEDURAL_COLLISION_MATERIAL
	)
	_procedural_collision_hardness = _read_float_setting(
		config,
		"procedural_collision_hardness",
		DEFAULT_PROCEDURAL_COLLISION_HARDNESS,
		0.5,
		1.5
	)
	_procedural_collision_brightness = _read_float_setting(
		config,
		"procedural_collision_brightness",
		DEFAULT_PROCEDURAL_COLLISION_BRIGHTNESS,
		0.5,
		1.5
	)
	_procedural_collision_body = _read_float_setting(
		config,
		"procedural_collision_body",
		DEFAULT_PROCEDURAL_COLLISION_BODY,
		0.5,
		1.5
	)
	_procedural_collision_decay = _read_float_setting(
		config,
		"procedural_collision_decay",
		DEFAULT_PROCEDURAL_COLLISION_DECAY,
		0.65,
		1.4
	)
	_procedural_collision_variation = _read_float_setting(
		config,
		"procedural_collision_variation",
		DEFAULT_PROCEDURAL_COLLISION_VARIATION,
		0.0,
		1.5
	)
	_procedural_collision_voice_limit = clampi(
		int(config.get_value(
			CONFIG_SECTION,
			"procedural_collision_voice_limit",
			DEFAULT_PROCEDURAL_COLLISION_VOICE_LIMIT
		)),
		4,
		32
	)


static func _save() -> void:
	var config := ConfigFile.new()
	config.load(CONFIG_PATH)
	config.set_value(CONFIG_SECTION, "master", _master_volume)
	config.set_value(CONFIG_SECTION, "music", _music_volume)
	config.set_value(CONFIG_SECTION, "sfx", _sfx_volume)
	config.set_value(CONFIG_SECTION, "ball_collision_mode", _collision_mode)
	config.set_value(CONFIG_SECTION, "procedural_collision_material", _procedural_collision_material)
	config.set_value(CONFIG_SECTION, "procedural_collision_hardness", _procedural_collision_hardness)
	config.set_value(CONFIG_SECTION, "procedural_collision_brightness", _procedural_collision_brightness)
	config.set_value(CONFIG_SECTION, "procedural_collision_body", _procedural_collision_body)
	config.set_value(CONFIG_SECTION, "procedural_collision_decay", _procedural_collision_decay)
	config.set_value(CONFIG_SECTION, "procedural_collision_variation", _procedural_collision_variation)
	config.set_value(CONFIG_SECTION, "procedural_collision_voice_limit", _procedural_collision_voice_limit)
	config.save(CONFIG_PATH)


static func _read_volume(config: ConfigFile, key: String, fallback: float) -> float:
	var value: Variant = config.get_value(CONFIG_SECTION, key, fallback)
	return clampf(float(value), 0.0, 1.0)


static func _read_float_setting(
	config: ConfigFile,
	key: String,
	fallback: float,
	minimum: float,
	maximum: float
) -> float:
	var value: Variant = config.get_value(CONFIG_SECTION, key, fallback)
	return clampf(float(value), minimum, maximum)


static func _sanitize_collision_mode(value: String, fallback: String) -> String:
	if value in [COLLISION_MODE_SAMPLED, COLLISION_MODE_PROCEDURAL, COLLISION_MODE_LAYERED]:
		return value
	return fallback


static func _sanitize_collision_material(value: String, fallback: String) -> String:
	if value == LEGACY_COLLISION_MATERIAL_BILLIARD_RESIN:
		return COLLISION_MATERIAL_RESONANT_RESIN_PROTOTYPE
	if value in [
		COLLISION_MATERIAL_SOLID_PHENOLIC_A_DRY,
		COLLISION_MATERIAL_SOLID_PHENOLIC_B_BALANCED,
		COLLISION_MATERIAL_SOLID_PHENOLIC_C_FULL,
		COLLISION_MATERIAL_SOLID_PHENOLIC_D_SHARP,
		COLLISION_MATERIAL_DENSE_PHENOLIC,
		COLLISION_MATERIAL_RESONANT_RESIN_PROTOTYPE,
		COLLISION_MATERIAL_BRIGHT_PROTOTYPE,
	]:
		return value
	return fallback


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
