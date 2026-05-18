extends AudioStreamPlayer
class_name GameplayMusicSystem

# Owns low-volume looping music for the gameplay scene only.
# SFX systems keep their own buses/pools and do not route through this node.

const DEFAULT_MUSIC_BUS_NAME := "Music"

@export var music_bus_name := DEFAULT_MUSIC_BUS_NAME
@export var gameplay_music_volume_db := -21.0
@export var start_automatically := true

var music_bus_index := -1


func _ready() -> void:
	AudioSettings.load_and_apply()
	_ensure_music_bus()
	bus = music_bus_name
	volume_db = gameplay_music_volume_db
	_enable_stream_looping()
	if start_automatically and stream != null and not playing:
		play()


func _exit_tree() -> void:
	stop()


func _ensure_music_bus() -> void:
	if music_bus_name == "Master":
		music_bus_name = DEFAULT_MUSIC_BUS_NAME

	music_bus_index = AudioServer.get_bus_index(music_bus_name)
	if music_bus_index >= 0:
		return

	music_bus_index = AudioServer.get_bus_count()
	AudioServer.add_bus(music_bus_index)
	AudioServer.set_bus_name(music_bus_index, music_bus_name)
	AudioServer.set_bus_send(music_bus_index, "Master")


func _enable_stream_looping() -> void:
	if stream == null:
		return

	var wav_stream: AudioStreamWAV = stream as AudioStreamWAV
	if wav_stream != null:
		wav_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav_stream.loop_begin = 0
		var loop_end_frame: int = int(wav_stream.get_length() * float(wav_stream.mix_rate))
		if loop_end_frame > 0:
			wav_stream.loop_end = loop_end_frame
		return

	_set_stream_property_if_present(stream, "loop", true)


func _set_stream_property_if_present(audio_stream: AudioStream, property_name: String, value: Variant) -> void:
	for property_data: Dictionary in audio_stream.get_property_list():
		if str(property_data.get("name", "")) == property_name:
			audio_stream.set(property_name, value)
			return
