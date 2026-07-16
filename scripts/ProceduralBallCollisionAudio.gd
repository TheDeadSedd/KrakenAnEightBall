extends RefCounted
class_name ProceduralBallCollisionAudio

# Builds a fixed bank of short, dry billiard-like collision samples. Runtime
# collision playback only selects cached streams; synthesis never runs per hit.
const SAMPLE_RATE := 32000
const STRENGTH_BAND_COUNT := 8
const VARIANTS_PER_BAND := 4
const MATERIAL_DENSE_PHENOLIC := "dense_phenolic"
const MATERIAL_SOLID_PHENOLIC_A_DRY := "solid_phenolic_a_dry"
const MATERIAL_SOLID_PHENOLIC_B_BALANCED := "solid_phenolic_b_balanced"
const MATERIAL_SOLID_PHENOLIC_C_FULL := "solid_phenolic_c_full"
const MATERIAL_SOLID_PHENOLIC_D_SHARP := "solid_phenolic_d_sharp"
const MATERIAL_RESONANT_RESIN_PROTOTYPE := "resonant_resin_prototype"
const MATERIAL_BRIGHT_PROTOTYPE := "bright_prototype"
const LEGACY_MATERIAL_BILLIARD_RESIN := "billiard_resin"
const DEFAULT_MATERIAL_PROFILE := MATERIAL_SOLID_PHENOLIC_B_BALANCED
const SOLID_PHENOLIC_MODAL_COUNT := 5
const SOLID_PHENOLIC_MIN_DURATION_SECONDS := 0.010
const SOLID_PHENOLIC_MAX_DURATION_SECONDS := 0.028
const SOLID_PHENOLIC_MIN_TRANSIENT_SECONDS := 0.00035
const SOLID_PHENOLIC_MAX_TRANSIENT_SECONDS := 0.00120
const DENSE_MODAL_COUNT := 5
const DENSE_MIN_DURATION_SECONDS := 0.018
const DENSE_MAX_DURATION_SECONDS := 0.042
const DENSE_MIN_TRANSIENT_SECONDS := 0.0008
const DENSE_MAX_TRANSIENT_SECONDS := 0.0020
const MIN_DURATION_SECONDS := 0.040
const MAX_DURATION_SECONDS := 0.085
const RESIN_MIN_DURATION_SECONDS := 0.022
const RESIN_MAX_DURATION_SECONDS := 0.055
const RESIN_MIN_TRANSIENT_SECONDS := 0.001
const RESIN_MAX_TRANSIENT_SECONDS := 0.003
const BANK_GENERATION_SEED := 0x4B52414B454E

const DEFAULT_HARDNESS := 1.0
const DEFAULT_BRIGHTNESS := 1.0
const DEFAULT_BODY := 1.0
const DEFAULT_DECAY := 1.0
const DEFAULT_VARIATION := 1.0

var generated_streams: Array[AudioStreamWAV] = []
var tuning: Dictionary = get_default_tuning()
var generation_duration_ms := 0.0
var generation_count := 0
var generated_primary_frequency_min_hz := 0.0
var generated_primary_frequency_max_hz := 0.0
var generated_secondary_frequency_min_hz := 0.0
var generated_secondary_frequency_max_hz := 0.0
var generated_body_frequency_min_hz := 0.0
var generated_body_frequency_max_hz := 0.0
var generated_duration_min_ms := 0.0
var generated_duration_max_ms := 0.0
var generated_transient_min_ms := 0.0
var generated_transient_max_ms := 0.0
var generated_body_ratio_sum := 0.0
var generated_metadata_count := 0
var generated_modal_count := 0
var generated_modal_frequency_min_hz := 0.0
var generated_modal_frequency_max_hz := 0.0
var generated_modal_decay_min_ms := 0.0
var generated_modal_decay_max_ms := 0.0
var generated_micro_impulse_separation_min_ms := 0.0
var generated_micro_impulse_separation_max_ms := 0.0
var generated_low_body_frequency_min_hz := 0.0
var generated_low_body_frequency_max_hz := 0.0
var generated_low_body_ratio_min := 0.0
var generated_low_body_ratio_max := 0.0
var generated_profile_metadata_count := 0
var generated_candidate_name := ""
var generated_modal_center_frequencies_hz := PackedFloat32Array()
var generated_secondary_pulse_enabled := false
var generated_compression_impulse_level := 0.0
var generated_table_coupling_level := 0.0
var generated_highpass_cutoff_hz := 0.0
var generated_saturation_amount := 0.0


static func get_default_tuning() -> Dictionary:
	return {
		"material_profile": DEFAULT_MATERIAL_PROFILE,
		"hardness": DEFAULT_HARDNESS,
		"brightness": DEFAULT_BRIGHTNESS,
		"body": DEFAULT_BODY,
		"decay": DEFAULT_DECAY,
		"variation": DEFAULT_VARIATION,
	}


func generate_bank(tuning_value: Dictionary) -> bool:
	var generation_started_usec: int = Time.get_ticks_usec()
	tuning = _sanitize_tuning(tuning_value)
	generated_streams.clear()
	_reset_generated_metadata()

	var bank_rng := RandomNumberGenerator.new()
	bank_rng.seed = BANK_GENERATION_SEED
	for band_index in range(STRENGTH_BAND_COUNT):
		for variant_index in range(VARIANTS_PER_BAND):
			var stream: AudioStreamWAV = _generate_stream_for_profile(
				band_index,
				variant_index,
				bank_rng
			)
			if stream == null:
				generated_streams.clear()
				generation_duration_ms = float(Time.get_ticks_usec() - generation_started_usec) / 1000.0
				return false
			generated_streams.append(stream)

	generation_count += 1
	generation_duration_ms = float(Time.get_ticks_usec() - generation_started_usec) / 1000.0
	return generated_streams.size() == STRENGTH_BAND_COUNT * VARIANTS_PER_BAND


func is_ready() -> bool:
	return generated_streams.size() == STRENGTH_BAND_COUNT * VARIANTS_PER_BAND


func get_stream(normalized_strength: float, variant_index: int) -> AudioStreamWAV:
	if not is_ready():
		return null
	var band_index: int = get_band_for_strength(normalized_strength)
	var safe_variant: int = posmod(variant_index, VARIANTS_PER_BAND)
	var stream_index: int = band_index * VARIANTS_PER_BAND + safe_variant
	return generated_streams[stream_index]


func get_band_for_strength(normalized_strength: float) -> int:
	var clamped_strength: float = clampf(normalized_strength, 0.0, 1.0)
	return clampi(int(floor(clamped_strength * float(STRENGTH_BAND_COUNT))), 0, STRENGTH_BAND_COUNT - 1)


func get_debug_snapshot() -> Dictionary:
	var profile: String = get_material_profile()
	var authored_metadata: Dictionary = _get_authored_profile_metadata(profile)
	var average_body_ratio := 0.0
	if generated_metadata_count > 0:
		average_body_ratio = generated_body_ratio_sum / float(generated_metadata_count)
	return {
		"ready": is_ready(),
		"sample_rate": SAMPLE_RATE,
		"strength_band_count": STRENGTH_BAND_COUNT,
		"variants_per_band": VARIANTS_PER_BAND,
		"generated_stream_count": generated_streams.size(),
		"generation_duration_ms": generation_duration_ms,
		"generation_count": generation_count,
		"material_profile": profile,
		"generated_primary_frequency_min_hz": generated_primary_frequency_min_hz,
		"generated_primary_frequency_max_hz": generated_primary_frequency_max_hz,
		"generated_secondary_frequency_min_hz": generated_secondary_frequency_min_hz,
		"generated_secondary_frequency_max_hz": generated_secondary_frequency_max_hz,
		"generated_body_frequency_min_hz": generated_body_frequency_min_hz,
		"generated_body_frequency_max_hz": generated_body_frequency_max_hz,
		"generated_duration_min_ms": generated_duration_min_ms,
		"generated_duration_max_ms": generated_duration_max_ms,
		"generated_transient_min_ms": generated_transient_min_ms,
		"generated_transient_max_ms": generated_transient_max_ms,
		"authored_duration_min_ms": float(authored_metadata.get("duration_min_ms", 0.0)),
		"authored_duration_max_ms": float(authored_metadata.get("duration_max_ms", 0.0)),
		"authored_transient_min_ms": float(authored_metadata.get("transient_min_ms", 0.0)),
		"authored_transient_max_ms": float(authored_metadata.get("transient_max_ms", 0.0)),
		"body_to_primary_amplitude_ratio": average_body_ratio,
		"modal_count": generated_modal_count,
		"modal_frequency_min_hz": generated_modal_frequency_min_hz,
		"modal_frequency_max_hz": generated_modal_frequency_max_hz,
		"modal_decay_min_ms": generated_modal_decay_min_ms,
		"modal_decay_max_ms": generated_modal_decay_max_ms,
		"micro_impulse_separation_min_ms": generated_micro_impulse_separation_min_ms,
		"micro_impulse_separation_max_ms": generated_micro_impulse_separation_max_ms,
		"low_body_frequency_min_hz": generated_low_body_frequency_min_hz,
		"low_body_frequency_max_hz": generated_low_body_frequency_max_hz,
		"low_body_relative_amplitude_min": generated_low_body_ratio_min,
		"low_body_relative_amplitude_max": generated_low_body_ratio_max,
		"candidate_name": generated_candidate_name,
		"modal_center_frequencies_hz": generated_modal_center_frequencies_hz.duplicate(),
		"secondary_pulse_enabled": generated_secondary_pulse_enabled,
		"compression_impulse_level": generated_compression_impulse_level,
		"table_coupling_level": generated_table_coupling_level,
		"highpass_cutoff_hz": generated_highpass_cutoff_hz,
		"saturation_amount": generated_saturation_amount,
		"material_tail_retained": profile == MATERIAL_BRIGHT_PROTOTYPE,
		"tuning": tuning.duplicate(true),
	}


func get_material_profile() -> String:
	return str(tuning.get("material_profile", DEFAULT_MATERIAL_PROFILE))


func _generate_stream_for_profile(
	band_index: int,
	variant_index: int,
	bank_rng: RandomNumberGenerator
) -> AudioStreamWAV:
	if _is_solid_phenolic_profile(get_material_profile()):
		return _generate_solid_phenolic_stream(
			get_material_profile(),
			band_index,
			variant_index,
			bank_rng
		)
	if get_material_profile() == MATERIAL_DENSE_PHENOLIC:
		return _generate_dense_phenolic_stream(band_index, variant_index, bank_rng)
	if get_material_profile() == MATERIAL_BRIGHT_PROTOTYPE:
		return _generate_bright_prototype_stream(band_index, variant_index, bank_rng)
	return _generate_resonant_resin_prototype_stream(band_index, variant_index, bank_rng)


func _generate_solid_phenolic_stream(
	material_profile: String,
	band_index: int,
	_variant_index: int,
	bank_rng: RandomNumberGenerator
) -> AudioStreamWAV:
	var candidate: Dictionary = _get_solid_phenolic_candidate_definition(material_profile)
	var band_strength: float = float(band_index) / float(STRENGTH_BAND_COUNT - 1)
	var hardness: float = float(tuning.get("hardness", DEFAULT_HARDNESS))
	var brightness: float = float(tuning.get("brightness", DEFAULT_BRIGHTNESS))
	var body: float = float(tuning.get("body", DEFAULT_BODY))
	var decay: float = float(tuning.get("decay", DEFAULT_DECAY))
	var variation: float = float(tuning.get("variation", DEFAULT_VARIATION))
	var variation_mix: float = clampf(variation, 0.0, 1.0)
	var decay_position: float = clampf((decay - 0.65) / (1.4 - 0.65), 0.0, 1.0)
	var decay_multiplier: float = lerpf(0.80, 1.18, decay_position)
	var duration_multiplier: float = lerpf(0.88, 1.12, decay_position)
	var profile_duration_scale: float = float(candidate.get("duration_scale", 1.0))
	var profile_decay_scale: float = float(candidate.get("modal_decay_scale", 1.0))
	var pitch_scale: float = lerpf(1.0, 0.96, band_strength)

	var duration_seconds: float = lerpf(0.012, 0.024, band_strength)
	duration_seconds *= profile_duration_scale * duration_multiplier
	duration_seconds *= bank_rng.randf_range(
		1.0 - 0.025 * variation,
		1.0 + 0.025 * variation
	)
	duration_seconds = clampf(
		duration_seconds,
		SOLID_PHENOLIC_MIN_DURATION_SECONDS,
		SOLID_PHENOLIC_MAX_DURATION_SECONDS
	)
	var sample_count: int = maxi(int(ceil(duration_seconds * float(SAMPLE_RATE))), 1)
	var samples := PackedFloat32Array()
	samples.resize(sample_count)

	var modal_centers := PackedFloat32Array([
		1450.0,
		2050.0,
		2850.0,
		3900.0,
		5200.0,
	])
	var modal_soft_decays := PackedFloat32Array([
		0.00240,
		0.00200,
		0.00160,
		0.00120,
		0.00085,
	])
	var modal_hard_decays := PackedFloat32Array([
		0.00500,
		0.00420,
		0.00350,
		0.00270,
		0.00190,
	])
	var modal_base_amplitudes := PackedFloat32Array([
		1.0,
		0.55,
		0.36,
		0.20,
		0.09,
	])
	var modal_frequencies: Array[float] = []
	var modal_decays: Array[float] = []
	var modal_amplitudes: Array[float] = []
	var modal_phases: Array[float] = []
	var modal_drifts: Array[float] = []
	var modal_frequency_min := INF
	var modal_frequency_max := 0.0
	var modal_decay_min := INF
	var modal_decay_max := 0.0
	var frequency_variation: float = 0.025 * variation
	var decay_variation: float = 0.05 * variation
	var upper_mode_scale: float = float(candidate.get("upper_mode_scale", 1.0))
	for mode_index in range(SOLID_PHENOLIC_MODAL_COUNT):
		var modal_frequency: float = modal_centers[mode_index] * pitch_scale
		modal_frequency *= bank_rng.randf_range(
			1.0 - frequency_variation,
			1.0 + frequency_variation
		)
		var modal_decay: float = lerpf(
			modal_soft_decays[mode_index],
			modal_hard_decays[mode_index],
			band_strength
		) * profile_decay_scale * decay_multiplier
		modal_decay *= bank_rng.randf_range(
			1.0 - decay_variation,
			1.0 + decay_variation
		)
		modal_decay = clampf(modal_decay, 0.0007, 0.0060)
		var modal_amplitude: float = modal_base_amplitudes[mode_index]
		if mode_index >= 3:
			modal_amplitude *= upper_mode_scale * brightness
		modal_amplitude *= bank_rng.randf_range(
			1.0 - 0.06 * variation,
			1.0 + 0.06 * variation
		)
		var authored_phase: float = fposmod(0.41 + float(mode_index) * 1.43, TAU)
		var random_phase: float = bank_rng.randf_range(0.0, TAU)
		var modal_phase: float = lerpf(authored_phase, random_phase, variation_mix)
		var modal_drift: float = bank_rng.randf_range(-0.006, 0.006) * variation
		modal_frequencies.append(modal_frequency)
		modal_decays.append(modal_decay)
		modal_amplitudes.append(modal_amplitude)
		modal_phases.append(modal_phase)
		modal_drifts.append(modal_drift)
		modal_frequency_min = minf(modal_frequency_min, modal_frequency)
		modal_frequency_max = maxf(modal_frequency_max, modal_frequency)
		modal_decay_min = minf(modal_decay_min, modal_decay)
		modal_decay_max = maxf(modal_decay_max, modal_decay)

	var transient_scale: float = float(candidate.get("transient_scale", 1.0))
	var transient_duration: float = lerpf(0.00045, 0.00100, band_strength)
	transient_duration *= transient_scale
	transient_duration *= bank_rng.randf_range(
		1.0 - 0.05 * variation,
		1.0 + 0.05 * variation
	)
	transient_duration = clampf(
		transient_duration,
		SOLID_PHENOLIC_MIN_TRANSIENT_SECONDS,
		SOLID_PHENOLIC_MAX_TRANSIENT_SECONDS
	)
	var secondary_pulse_enabled: bool = bool(candidate.get("secondary_pulse_enabled", false))
	var micro_impulse_separation := 0.0
	if secondary_pulse_enabled:
		micro_impulse_separation = float(candidate.get("secondary_pulse_separation", 0.0001))
		micro_impulse_separation *= bank_rng.randf_range(
			1.0 - 0.12 * variation,
			1.0 + 0.12 * variation
		)
		micro_impulse_separation = clampf(micro_impulse_separation, 0.00005, 0.00018)
	var secondary_pulse_ratio: float = clampf(
		float(candidate.get("secondary_pulse_ratio", 0.0)),
		0.0,
		0.30
	)
	var compression_duration: float = lerpf(0.0007, 0.0025, band_strength)
	var compression_activation: float = clampf((band_strength - 0.12) / 0.88, 0.0, 1.0)
	compression_activation = pow(compression_activation, 1.15)
	var compression_level: float = float(candidate.get("compression_level", 0.0))
	compression_level *= body * compression_activation
	compression_level = clampf(compression_level, 0.0, 0.08)
	var table_duration: float = lerpf(0.001, 0.004, band_strength)
	var table_activation: float = clampf((band_strength - 0.22) / 0.78, 0.0, 1.0)
	table_activation = pow(table_activation, 1.25)
	var table_coupling_level: float = float(candidate.get("table_coupling_level", 0.0))
	table_coupling_level *= body * table_activation
	table_coupling_level = clampf(table_coupling_level, 0.0, 0.06)
	var highpass_cutoff: float = float(candidate.get("highpass_cutoff_hz", 450.0))
	var saturation_amount: float = float(candidate.get("saturation_amount", 0.45))
	var contact_texture_scale: float = float(candidate.get("contact_texture_scale", 1.0))
	var hardness_position: float = clampf((hardness - 0.5) / 1.0, 0.0, 1.0)
	var transient_gain: float = lerpf(0.34, 0.62, band_strength)
	transient_gain *= lerpf(0.76, 1.24, hardness_position)
	var contact_noise_mix: float = lerpf(0.30, 0.46, band_strength)
	contact_noise_mix *= lerpf(0.84, 1.16, hardness_position) * contact_texture_scale
	var modal_gain := 0.38
	var strength_gain: float = lerpf(0.16, 1.0, pow(band_strength, 0.68))

	_record_generated_metadata(
		modal_frequencies[0],
		modal_frequencies[1],
		1100.0,
		duration_seconds,
		transient_duration,
		compression_level
	)
	_record_profile_diagnostics(
		SOLID_PHENOLIC_MODAL_COUNT,
		modal_frequency_min,
		modal_frequency_max,
		modal_decay_min,
		modal_decay_max,
		micro_impulse_separation,
		700.0,
		1500.0,
		compression_level
	)
	_record_solid_phenolic_candidate_diagnostics(
		candidate,
		modal_centers,
		secondary_pulse_enabled
	)

	var contact_lowpass_high := 0.0
	var contact_lowpass_low := 0.0
	var compression_lowpass_high := 0.0
	var compression_lowpass_low := 0.0
	var table_lowpass_high := 0.0
	var table_lowpass_low := 0.0
	var output_lowpass := 0.0
	var contact_high_alpha: float = 1.0 - exp(-TAU * 6500.0 / float(SAMPLE_RATE))
	var contact_low_alpha: float = 1.0 - exp(-TAU * 1200.0 / float(SAMPLE_RATE))
	var compression_high_alpha: float = 1.0 - exp(-TAU * 1500.0 / float(SAMPLE_RATE))
	var compression_low_alpha: float = 1.0 - exp(-TAU * 700.0 / float(SAMPLE_RATE))
	var table_high_alpha: float = 1.0 - exp(-TAU * 1000.0 / float(SAMPLE_RATE))
	var table_low_alpha: float = 1.0 - exp(-TAU * 450.0 / float(SAMPLE_RATE))
	var output_lowpass_alpha: float = 1.0 - exp(-TAU * 8500.0 / float(SAMPLE_RATE))
	var highpass_rc: float = 1.0 / (TAU * highpass_cutoff)
	var sample_interval: float = 1.0 / float(SAMPLE_RATE)
	var highpass_alpha: float = highpass_rc / (highpass_rc + sample_interval)
	var previous_highpass_input := 0.0
	var previous_highpass_output := 0.0
	var sample_sum := 0.0
	var contact_phase_a: float = bank_rng.randf_range(0.0, TAU)
	var contact_phase_b: float = bank_rng.randf_range(0.0, TAU)

	for sample_index in range(sample_count):
		var sample_time: float = float(sample_index) / float(SAMPLE_RATE)
		var attack: float = clampf(sample_time / 0.00005, 0.0, 1.0)
		var end_fade: float = clampf((duration_seconds - sample_time) / 0.0015, 0.0, 1.0)
		var contact_noise: float = bank_rng.randf_range(-1.0, 1.0)
		var compression_noise: float = bank_rng.randf_range(-1.0, 1.0)
		var table_noise: float = bank_rng.randf_range(-1.0, 1.0)
		contact_lowpass_high += contact_high_alpha * (contact_noise - contact_lowpass_high)
		contact_lowpass_low += contact_low_alpha * (contact_noise - contact_lowpass_low)
		compression_lowpass_high += compression_high_alpha * (
			compression_noise - compression_lowpass_high
		)
		compression_lowpass_low += compression_low_alpha * (
			compression_noise - compression_lowpass_low
		)
		table_lowpass_high += table_high_alpha * (table_noise - table_lowpass_high)
		table_lowpass_low += table_low_alpha * (table_noise - table_lowpass_low)
		var contact_band: float = contact_lowpass_high - contact_lowpass_low
		var compression_band: float = compression_lowpass_high - compression_lowpass_low
		var table_band: float = table_lowpass_high - table_lowpass_low

		var contact_pulse := 0.0
		if sample_time <= transient_duration:
			var pulse_position: float = clampf(sample_time / transient_duration, 0.0, 1.0)
			var pulse_envelope: float = sin(PI * pulse_position)
			pulse_envelope *= exp(-1.7 * pulse_position)
			var contact_carrier: float = (
				sin(TAU * 3200.0 * sample_time + contact_phase_a)
				+ 0.42 * sin(TAU * 5700.0 * sample_time + contact_phase_b)
			)
			contact_pulse = (
				contact_carrier * (1.0 - contact_noise_mix * 0.45)
				+ contact_band * contact_noise_mix
			) * pulse_envelope
		if secondary_pulse_enabled and sample_time >= micro_impulse_separation:
			var secondary_time: float = sample_time - micro_impulse_separation
			var secondary_duration: float = transient_duration * 0.72
			if secondary_time <= secondary_duration:
				var secondary_position: float = clampf(
					secondary_time / secondary_duration,
					0.0,
					1.0
				)
				var secondary_envelope: float = sin(PI * secondary_position)
				secondary_envelope *= exp(-1.9 * secondary_position)
				var secondary_carrier: float = (
					sin(TAU * 3350.0 * secondary_time + contact_phase_a)
					+ 0.36 * sin(TAU * 5500.0 * secondary_time + contact_phase_b)
				)
				contact_pulse += (
					secondary_carrier * 0.72 + contact_band * contact_noise_mix
				) * secondary_envelope * secondary_pulse_ratio

		var modal_cluster := 0.0
		for mode_index in range(SOLID_PHENOLIC_MODAL_COUNT):
			var mode_envelope: float = exp(
				-sample_time / maxf(modal_decays[mode_index], 0.0005)
			)
			var early_drift: float = modal_drifts[mode_index] * exp(
				-sample_time / 0.0015
			)
			var phase_modulation: float = 0.025 * sin(
				TAU * (780.0 + float(mode_index) * 137.0) * sample_time
				+ modal_phases[mode_index] * 0.27
			) * exp(-sample_time / 0.0020)
			var modal_angle: float = (
				TAU * modal_frequencies[mode_index] * sample_time * (1.0 + early_drift)
				+ modal_phases[mode_index]
				+ phase_modulation
			)
			modal_cluster += (
				sin(modal_angle)
				* modal_amplitudes[mode_index]
				* mode_envelope
			)

		var compression_impulse := 0.0
		if compression_level > 0.0 and sample_time <= compression_duration:
			compression_impulse = compression_band * exp(
				-sample_time / maxf(compression_duration * 0.20, 0.0001)
			)
		var table_coupling := 0.0
		if table_coupling_level > 0.0 and sample_time <= table_duration:
			table_coupling = table_band * exp(
				-sample_time / maxf(table_duration * 0.18, 0.0001)
			)

		var sample_value: float = (
			contact_pulse * transient_gain
			+ modal_cluster * modal_gain
			+ compression_impulse * compression_level
			+ table_coupling * table_coupling_level
		)
		sample_value *= attack * end_fade * strength_gain
		sample_value /= 1.0 + absf(sample_value) * saturation_amount
		output_lowpass += output_lowpass_alpha * (sample_value - output_lowpass)
		var highpass_output: float = highpass_alpha * (
			previous_highpass_output + output_lowpass - previous_highpass_input
		)
		previous_highpass_input = output_lowpass
		previous_highpass_output = highpass_output
		samples[sample_index] = highpass_output
		sample_sum += highpass_output

	var dc_offset: float = sample_sum / float(sample_count)
	var peak := 0.0
	for sample_index in range(sample_count):
		var sample_time: float = float(sample_index) / float(SAMPLE_RATE)
		var endpoint_fade: float = minf(
			clampf(sample_time / 0.00005, 0.0, 1.0),
			clampf((duration_seconds - sample_time) / 0.0015, 0.0, 1.0)
		)
		samples[sample_index] = (samples[sample_index] - dc_offset) * endpoint_fade
		peak = maxf(peak, absf(samples[sample_index]))
	samples[0] = 0.0
	samples[sample_count - 1] = 0.0
	if peak <= 0.000001:
		return null

	# Shared peak targets keep A/B decisions focused on material balance rather
	# than whichever candidate happens to be louder.
	var target_peak: float = lerpf(0.17, 0.79, pow(band_strength, 0.72))
	var normalization_gain: float = target_peak / peak
	var audio_data := PackedByteArray()
	audio_data.resize(sample_count * 2)
	for sample_index in range(sample_count):
		var normalized_sample: float = clampf(
			samples[sample_index] * normalization_gain,
			-0.96,
			0.96
		)
		var integer_sample: int = int(round(normalized_sample * 32767.0))
		if integer_sample < 0:
			integer_sample += 65536
		var byte_index: int = sample_index * 2
		audio_data[byte_index] = integer_sample & 0xff
		audio_data[byte_index + 1] = (integer_sample >> 8) & 0xff

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	stream.data = audio_data
	return stream


func _generate_dense_phenolic_stream(
	band_index: int,
	_variant_index: int,
	bank_rng: RandomNumberGenerator
) -> AudioStreamWAV:
	var band_strength: float = float(band_index) / float(STRENGTH_BAND_COUNT - 1)
	var hardness: float = float(tuning.get("hardness", DEFAULT_HARDNESS))
	var brightness: float = float(tuning.get("brightness", DEFAULT_BRIGHTNESS))
	var body: float = float(tuning.get("body", DEFAULT_BODY))
	var decay: float = float(tuning.get("decay", DEFAULT_DECAY))
	var variation: float = float(tuning.get("variation", DEFAULT_VARIATION))
	var variation_mix: float = clampf(variation, 0.0, 1.0)
	var decay_position: float = clampf((decay - 0.65) / (1.4 - 0.65), 0.0, 1.0)
	var decay_multiplier: float = lerpf(0.82, 1.18, decay_position)
	var pitch_scale: float = lerpf(1.0, 0.93, band_strength)

	var duration_seconds: float = lerpf(0.020, 0.038, band_strength) * decay_multiplier
	duration_seconds *= bank_rng.randf_range(
		1.0 - 0.035 * variation,
		1.0 + 0.035 * variation
	)
	duration_seconds = clampf(
		duration_seconds,
		DENSE_MIN_DURATION_SECONDS,
		DENSE_MAX_DURATION_SECONDS
	)
	var sample_count: int = maxi(int(ceil(duration_seconds * float(SAMPLE_RATE))), 1)
	var samples := PackedFloat32Array()
	samples.resize(sample_count)

	var modal_base_frequencies := PackedFloat32Array([
		970.0,
		1270.0,
		1580.0,
		2050.0,
		2650.0,
	])
	var modal_soft_decays := PackedFloat32Array([
		0.0055,
		0.0045,
		0.0038,
		0.0030,
		0.0023,
	])
	var modal_hard_decays := PackedFloat32Array([
		0.0120,
		0.0090,
		0.0075,
		0.0060,
		0.0046,
	])
	var modal_base_amplitudes := PackedFloat32Array([
		1.0,
		0.58,
		0.40,
		0.23,
		0.14,
	])
	var modal_frequencies: Array[float] = []
	var modal_decays: Array[float] = []
	var modal_amplitudes: Array[float] = []
	var modal_phases: Array[float] = []
	var modal_drifts: Array[float] = []
	var modal_frequency_min := INF
	var modal_frequency_max := 0.0
	var modal_decay_min := INF
	var modal_decay_max := 0.0
	var frequency_variation: float = 0.035 * variation
	var decay_variation: float = 0.06 * variation
	for mode_index in range(DENSE_MODAL_COUNT):
		var modal_frequency: float = modal_base_frequencies[mode_index] * pitch_scale
		modal_frequency *= bank_rng.randf_range(
			1.0 - frequency_variation,
			1.0 + frequency_variation
		)
		var modal_decay: float = lerpf(
			modal_soft_decays[mode_index],
			modal_hard_decays[mode_index],
			band_strength
		) * decay_multiplier
		modal_decay *= bank_rng.randf_range(
			1.0 - decay_variation,
			1.0 + decay_variation
		)
		var maximum_modal_decay: float = 0.014 if mode_index == 0 else 0.010
		modal_decay = clampf(modal_decay, 0.002, maximum_modal_decay)
		var modal_amplitude: float = modal_base_amplitudes[mode_index]
		modal_amplitude *= bank_rng.randf_range(
			1.0 - 0.08 * variation,
			1.0 + 0.08 * variation
		)
		var authored_phase: float = fposmod(0.73 + float(mode_index) * 1.27, TAU)
		var random_phase: float = bank_rng.randf_range(0.0, TAU)
		var modal_phase: float = lerpf(authored_phase, random_phase, variation_mix)
		var modal_drift: float = bank_rng.randf_range(-0.012, 0.012) * variation
		modal_frequencies.append(modal_frequency)
		modal_decays.append(modal_decay)
		modal_amplitudes.append(modal_amplitude)
		modal_phases.append(modal_phase)
		modal_drifts.append(modal_drift)
		modal_frequency_min = minf(modal_frequency_min, modal_frequency)
		modal_frequency_max = maxf(modal_frequency_max, modal_frequency)
		modal_decay_min = minf(modal_decay_min, modal_decay)
		modal_decay_max = maxf(modal_decay_max, modal_decay)

	var transient_duration: float = lerpf(0.0009, 0.0017, band_strength)
	transient_duration *= bank_rng.randf_range(
		1.0 - 0.06 * variation,
		1.0 + 0.06 * variation
	)
	transient_duration = clampf(
		transient_duration,
		DENSE_MIN_TRANSIENT_SECONDS,
		DENSE_MAX_TRANSIENT_SECONDS
	)
	var micro_impulse_separation: float = lerpf(0.00030, 0.00064, band_strength)
	micro_impulse_separation *= bank_rng.randf_range(
		1.0 - 0.18 * variation,
		1.0 + 0.18 * variation
	)
	micro_impulse_separation = clampf(micro_impulse_separation, 0.0002, 0.0008)
	var body_duration: float = lerpf(0.002, 0.007, band_strength)
	var body_activation: float = clampf((band_strength - 0.08) / 0.92, 0.0, 1.0)
	body_activation = pow(body_activation, 1.2)
	var body_ratio: float = lerpf(0.08, 0.24, band_strength) * body * body_activation
	body_ratio = clampf(body_ratio, 0.0, 0.28)
	var upper_texture_duration: float = lerpf(0.00065, 0.00165, band_strength)
	var hardness_position: float = clampf((hardness - 0.5) / 1.0, 0.0, 1.0)
	var transient_gain: float = lerpf(0.30, 0.58, band_strength)
	transient_gain *= lerpf(0.72, 1.28, hardness_position)
	var second_impulse_ratio: float = lerpf(0.30, 0.52, band_strength)
	second_impulse_ratio *= lerpf(0.78, 1.18, hardness_position)
	var upper_texture_gain: float = clampf(
		lerpf(0.050, 0.085, band_strength) * brightness,
		0.025,
		0.12
	)
	var modal_gain := 0.44
	var modal_texture_gain: float = lerpf(0.024, 0.050, band_strength)
	var strength_gain: float = lerpf(0.16, 1.0, pow(band_strength, 0.68))

	_record_generated_metadata(
		modal_frequencies[0],
		modal_frequencies[1],
		550.0,
		duration_seconds,
		transient_duration,
		body_ratio
	)
	_record_profile_diagnostics(
		DENSE_MODAL_COUNT,
		modal_frequency_min,
		modal_frequency_max,
		modal_decay_min,
		modal_decay_max,
		micro_impulse_separation,
		350.0,
		750.0,
		body_ratio
	)

	var transient_lowpass_high := 0.0
	var transient_lowpass_low := 0.0
	var body_lowpass_high := 0.0
	var body_lowpass_low := 0.0
	var upper_lowpass_high := 0.0
	var upper_lowpass_low := 0.0
	var transient_high_alpha: float = 1.0 - exp(-TAU * 4000.0 / float(SAMPLE_RATE))
	var transient_low_alpha: float = 1.0 - exp(-TAU * 700.0 / float(SAMPLE_RATE))
	var body_high_alpha: float = 1.0 - exp(-TAU * 750.0 / float(SAMPLE_RATE))
	var body_low_alpha: float = 1.0 - exp(-TAU * 350.0 / float(SAMPLE_RATE))
	var upper_high_alpha: float = 1.0 - exp(-TAU * 4800.0 / float(SAMPLE_RATE))
	var upper_low_alpha: float = 1.0 - exp(-TAU * 2800.0 / float(SAMPLE_RATE))
	var highpass_cutoff := 120.0
	var highpass_rc: float = 1.0 / (TAU * highpass_cutoff)
	var sample_interval: float = 1.0 / float(SAMPLE_RATE)
	var highpass_alpha: float = highpass_rc / (highpass_rc + sample_interval)
	var previous_highpass_input := 0.0
	var previous_highpass_output := 0.0
	var sample_sum := 0.0

	for sample_index in range(sample_count):
		var sample_time: float = float(sample_index) / float(SAMPLE_RATE)
		var attack: float = clampf(sample_time / 0.00008, 0.0, 1.0)
		var end_fade: float = clampf((duration_seconds - sample_time) / 0.0018, 0.0, 1.0)
		var transient_noise: float = bank_rng.randf_range(-1.0, 1.0)
		var body_noise: float = bank_rng.randf_range(-1.0, 1.0)
		var upper_noise: float = bank_rng.randf_range(-1.0, 1.0)
		transient_lowpass_high += transient_high_alpha * (
			transient_noise - transient_lowpass_high
		)
		transient_lowpass_low += transient_low_alpha * (
			transient_noise - transient_lowpass_low
		)
		body_lowpass_high += body_high_alpha * (body_noise - body_lowpass_high)
		body_lowpass_low += body_low_alpha * (body_noise - body_lowpass_low)
		upper_lowpass_high += upper_high_alpha * (upper_noise - upper_lowpass_high)
		upper_lowpass_low += upper_low_alpha * (upper_noise - upper_lowpass_low)
		var transient_band: float = transient_lowpass_high - transient_lowpass_low
		var body_band: float = body_lowpass_high - body_lowpass_low
		var upper_band: float = upper_lowpass_high - upper_lowpass_low

		var transient := 0.0
		if sample_time <= transient_duration:
			transient = transient_band * exp(
				-sample_time / maxf(transient_duration * 0.22, 0.0001)
			)
		if (
			sample_time >= micro_impulse_separation
			and sample_time <= micro_impulse_separation + transient_duration
		):
			var second_impulse_time: float = sample_time - micro_impulse_separation
			transient += transient_band * second_impulse_ratio * exp(
				-second_impulse_time / maxf(transient_duration * 0.20, 0.0001)
			)

		var modal_cluster := 0.0
		for mode_index in range(DENSE_MODAL_COUNT):
			var mode_envelope: float = exp(
				-sample_time / maxf(modal_decays[mode_index], 0.001)
			)
			var early_drift: float = modal_drifts[mode_index] * exp(
				-sample_time / 0.0025
			)
			var phase_modulation: float = 0.040 * sin(
				TAU * (370.0 + float(mode_index) * 91.0) * sample_time
				+ modal_phases[mode_index] * 0.31
			) * exp(-sample_time / 0.0035)
			var modal_angle: float = (
				TAU * modal_frequencies[mode_index] * sample_time * (1.0 + early_drift)
				+ modal_phases[mode_index]
				+ phase_modulation
			)
			modal_cluster += (
				sin(modal_angle)
				* modal_amplitudes[mode_index]
				* mode_envelope
			)

		var low_body := 0.0
		if body_ratio > 0.0 and sample_time <= body_duration:
			low_body = body_band * exp(
				-sample_time / maxf(body_duration * 0.24, 0.0001)
			)
		var upper_texture := 0.0
		if sample_time <= upper_texture_duration:
			upper_texture = upper_band * exp(
				-sample_time / maxf(upper_texture_duration * 0.20, 0.0001)
			)
		var modal_texture: float = transient_band * exp(-sample_time / 0.005)

		var sample_value: float = (
			modal_cluster * modal_gain
			+ transient * transient_gain
			+ low_body * modal_gain * body_ratio
			+ upper_texture * upper_texture_gain
			+ modal_texture * modal_texture_gain
		)
		sample_value *= attack * end_fade * strength_gain
		var highpass_output: float = highpass_alpha * (
			previous_highpass_output + sample_value - previous_highpass_input
		)
		previous_highpass_input = sample_value
		previous_highpass_output = highpass_output
		highpass_output /= 1.0 + absf(highpass_output) * 0.50
		samples[sample_index] = highpass_output
		sample_sum += highpass_output

	var dc_offset: float = sample_sum / float(sample_count)
	var peak := 0.0
	for sample_index in range(sample_count):
		var sample_time: float = float(sample_index) / float(SAMPLE_RATE)
		var endpoint_fade: float = minf(
			clampf(sample_time / 0.00008, 0.0, 1.0),
			clampf((duration_seconds - sample_time) / 0.0018, 0.0, 1.0)
		)
		samples[sample_index] = (samples[sample_index] - dc_offset) * endpoint_fade
		peak = maxf(peak, absf(samples[sample_index]))
	samples[0] = 0.0
	samples[sample_count - 1] = 0.0
	if peak <= 0.000001:
		return null

	var target_peak: float = lerpf(0.18, 0.80, pow(band_strength, 0.72))
	var normalization_gain: float = target_peak / peak
	var audio_data := PackedByteArray()
	audio_data.resize(sample_count * 2)
	for sample_index in range(sample_count):
		var normalized_sample: float = clampf(
			samples[sample_index] * normalization_gain,
			-0.96,
			0.96
		)
		var integer_sample: int = int(round(normalized_sample * 32767.0))
		if integer_sample < 0:
			integer_sample += 65536
		var byte_index: int = sample_index * 2
		audio_data[byte_index] = integer_sample & 0xff
		audio_data[byte_index + 1] = (integer_sample >> 8) & 0xff

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	stream.data = audio_data
	return stream


func _generate_resonant_resin_prototype_stream(
	band_index: int,
	_variant_index: int,
	bank_rng: RandomNumberGenerator
) -> AudioStreamWAV:
	var band_strength: float = float(band_index) / float(STRENGTH_BAND_COUNT - 1)
	var hardness: float = float(tuning.get("hardness", DEFAULT_HARDNESS))
	var brightness: float = float(tuning.get("brightness", DEFAULT_BRIGHTNESS))
	var body: float = float(tuning.get("body", DEFAULT_BODY))
	var decay: float = float(tuning.get("decay", DEFAULT_DECAY))
	var variation: float = float(tuning.get("variation", DEFAULT_VARIATION))
	var frequency_variation: float = 0.035 * variation
	var decay_variation: float = 0.06 * variation
	var decay_position: float = clampf((decay - 0.65) / (1.4 - 0.65), 0.0, 1.0)
	var decay_multiplier: float = lerpf(0.80, 1.18, decay_position)
	decay_multiplier *= bank_rng.randf_range(1.0 - decay_variation, 1.0 + decay_variation)

	var duration_seconds: float = lerpf(0.025, 0.052, band_strength) * decay_multiplier
	duration_seconds *= bank_rng.randf_range(1.0 - 0.04 * variation, 1.0 + 0.04 * variation)
	duration_seconds = clampf(
		duration_seconds,
		RESIN_MIN_DURATION_SECONDS,
		RESIN_MAX_DURATION_SECONDS
	)
	var sample_count: int = maxi(int(ceil(duration_seconds * float(SAMPLE_RATE))), 1)
	var samples := PackedFloat32Array()
	samples.resize(sample_count)

	# Increasing strength lowers the material modes while increasing body weight.
	var primary_frequency: float = lerpf(1250.0, 650.0, band_strength)
	primary_frequency *= bank_rng.randf_range(1.0 - frequency_variation, 1.0 + frequency_variation)
	var secondary_frequency: float = lerpf(2150.0, 1325.0, band_strength)
	secondary_frequency *= bank_rng.randf_range(1.0 - frequency_variation, 1.0 + frequency_variation)
	var secondary_ratio: float = secondary_frequency / maxf(primary_frequency, 1.0)
	if absf(secondary_ratio - roundf(secondary_ratio)) < 0.08:
		secondary_frequency *= 1.055
	var body_frequency: float = lerpf(480.0, 180.0, band_strength)
	body_frequency *= bank_rng.randf_range(1.0 - frequency_variation, 1.0 + frequency_variation)
	var upper_tick_frequency: float = lerpf(3400.0, 2400.0, band_strength)
	upper_tick_frequency *= bank_rng.randf_range(
		1.0 - 0.02 * variation,
		1.0 + 0.02 * variation
	)
	var primary_phase: float = bank_rng.randf_range(0.0, TAU)
	var secondary_phase: float = bank_rng.randf_range(0.0, TAU)
	var body_phase: float = bank_rng.randf_range(0.0, TAU)
	var upper_phase: float = bank_rng.randf_range(0.0, TAU)

	var transient_duration: float = lerpf(
		RESIN_MIN_TRANSIENT_SECONDS,
		RESIN_MAX_TRANSIENT_SECONDS,
		band_strength
	)
	transient_duration *= bank_rng.randf_range(
		1.0 - 0.05 * variation,
		1.0 + 0.05 * variation
	)
	transient_duration = clampf(
		transient_duration,
		RESIN_MIN_TRANSIENT_SECONDS,
		RESIN_MAX_TRANSIENT_SECONDS
	)
	var primary_decay: float = clampf(
		lerpf(0.010, 0.024, band_strength) * decay_multiplier,
		0.008,
		0.030
	)
	var secondary_decay: float = clampf(
		lerpf(0.004, 0.010, band_strength) * decay_multiplier,
		0.003,
		0.012
	)
	var body_decay: float = clampf(
		lerpf(0.005, 0.014, band_strength) * decay_multiplier,
		0.004,
		0.017
	)
	var upper_tick_decay: float = lerpf(0.0011, 0.0018, band_strength)
	var knock_duration: float = lerpf(0.004, 0.015, band_strength)

	var hardness_position: float = clampf((hardness - 0.5) / 1.0, 0.0, 1.0)
	var hardness_body_balance: float = lerpf(1.12, 0.88, hardness_position)
	var primary_gain: float = lerpf(0.50, 0.58, band_strength)
	var body_ratio: float = lerpf(0.18, 0.65, band_strength) * body * hardness_body_balance
	body_ratio = clampf(body_ratio, 0.10, 0.78)
	var body_gain: float = primary_gain * body_ratio
	var secondary_amplitude_ratio: float = clampf(
		lerpf(0.25, 0.16, band_strength) * brightness,
		0.12,
		0.31
	)
	var secondary_gain: float = primary_gain * secondary_amplitude_ratio
	var upper_tick_ratio: float = clampf(
		lerpf(0.075, 0.045, band_strength) * brightness,
		0.025,
		0.10
	)
	var upper_tick_gain: float = primary_gain * upper_tick_ratio
	var transient_gain: float = lerpf(0.24, 0.52, band_strength) * hardness
	var knock_gain: float = lerpf(0.08, 0.24, band_strength) * body * hardness_body_balance
	var strength_gain: float = lerpf(0.16, 1.0, pow(band_strength, 0.68))

	_record_generated_metadata(
		primary_frequency,
		secondary_frequency,
		body_frequency,
		duration_seconds,
		transient_duration,
		body_ratio
	)
	_record_profile_diagnostics(
		2,
		minf(primary_frequency, secondary_frequency),
		maxf(primary_frequency, secondary_frequency),
		minf(primary_decay, secondary_decay),
		maxf(primary_decay, secondary_decay),
		0.0,
		body_frequency,
		body_frequency,
		body_ratio
	)

	var transient_lowpass := 0.0
	var knock_lowpass := 0.0
	var transient_alpha: float = 1.0 - exp(-TAU * 3400.0 / float(SAMPLE_RATE))
	var knock_cutoff: float = lerpf(520.0, 760.0, band_strength)
	var knock_alpha: float = 1.0 - exp(-TAU * knock_cutoff / float(SAMPLE_RATE))
	var highpass_cutoff := 90.0
	var highpass_rc: float = 1.0 / (TAU * highpass_cutoff)
	var sample_interval: float = 1.0 / float(SAMPLE_RATE)
	var highpass_alpha: float = highpass_rc / (highpass_rc + sample_interval)
	var previous_highpass_input := 0.0
	var previous_highpass_output := 0.0
	var sample_sum := 0.0

	for sample_index in range(sample_count):
		var sample_time: float = float(sample_index) / float(SAMPLE_RATE)
		var attack: float = clampf(sample_time / 0.00018, 0.0, 1.0)
		var end_fade: float = clampf((duration_seconds - sample_time) / 0.0025, 0.0, 1.0)
		var noise: float = bank_rng.randf_range(-1.0, 1.0)
		transient_lowpass += transient_alpha * (noise - transient_lowpass)
		knock_lowpass += knock_alpha * (noise - knock_lowpass)

		var transient := 0.0
		if sample_time <= transient_duration:
			var transient_envelope: float = exp(
				-sample_time / maxf(transient_duration * 0.25, 0.0001)
			)
			var transient_density: float = lerpf(0.82, 1.0, band_strength)
			transient = transient_lowpass * transient_envelope * transient_density

		var phase_irregularity: float = 0.09 * sin(
			TAU * body_frequency * 1.31 * sample_time
		)
		var primary: float = sin(
			TAU * primary_frequency * sample_time + primary_phase + phase_irregularity
		)
		primary *= exp(-sample_time / maxf(primary_decay, 0.001))
		var secondary: float = sin(TAU * secondary_frequency * sample_time + secondary_phase)
		secondary *= exp(-sample_time / maxf(secondary_decay, 0.001))
		var low_body: float = sin(TAU * body_frequency * sample_time + body_phase)
		low_body *= exp(-sample_time / maxf(body_decay, 0.001))

		var low_knock := 0.0
		if sample_time <= knock_duration:
			low_knock = knock_lowpass * exp(
				-sample_time / maxf(knock_duration * 0.32, 0.001)
			)
		var upper_tick := 0.0
		if sample_time <= 0.005:
			upper_tick = sin(TAU * upper_tick_frequency * sample_time + upper_phase)
			upper_tick *= exp(-sample_time / upper_tick_decay)

		var sample_value: float = (
			transient * transient_gain
			+ primary * primary_gain
			+ secondary * secondary_gain
			+ low_body * body_gain
			+ low_knock * knock_gain
			+ upper_tick * upper_tick_gain
		)
		sample_value *= attack * end_fade * strength_gain
		var highpass_output: float = highpass_alpha * (
			previous_highpass_output + sample_value - previous_highpass_input
		)
		previous_highpass_input = sample_value
		previous_highpass_output = highpass_output
		highpass_output /= 1.0 + absf(highpass_output) * 0.42
		samples[sample_index] = highpass_output
		sample_sum += highpass_output

	var dc_offset: float = sample_sum / float(sample_count)
	var peak := 0.0
	for sample_index in range(sample_count):
		var sample_time: float = float(sample_index) / float(SAMPLE_RATE)
		var endpoint_fade: float = minf(
			clampf(sample_time / 0.00018, 0.0, 1.0),
			clampf((duration_seconds - sample_time) / 0.0025, 0.0, 1.0)
		)
		samples[sample_index] = (samples[sample_index] - dc_offset) * endpoint_fade
		peak = maxf(peak, absf(samples[sample_index]))
	samples[0] = 0.0
	samples[sample_count - 1] = 0.0
	if peak <= 0.000001:
		return null

	var target_peak: float = lerpf(0.20, 0.82, pow(band_strength, 0.72))
	var normalization_gain: float = target_peak / peak
	var audio_data := PackedByteArray()
	audio_data.resize(sample_count * 2)
	for sample_index in range(sample_count):
		var normalized_sample: float = clampf(
			samples[sample_index] * normalization_gain,
			-0.96,
			0.96
		)
		var integer_sample: int = int(round(normalized_sample * 32767.0))
		if integer_sample < 0:
			integer_sample += 65536
		var byte_index: int = sample_index * 2
		audio_data[byte_index] = integer_sample & 0xff
		audio_data[byte_index + 1] = (integer_sample >> 8) & 0xff

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	stream.data = audio_data
	return stream


func _generate_bright_prototype_stream(
	band_index: int,
	_variant_index: int,
	bank_rng: RandomNumberGenerator
) -> AudioStreamWAV:
	var band_strength: float = float(band_index) / float(STRENGTH_BAND_COUNT - 1)
	var hardness: float = float(tuning.get("hardness", DEFAULT_HARDNESS))
	var brightness: float = float(tuning.get("brightness", DEFAULT_BRIGHTNESS))
	var body: float = float(tuning.get("body", DEFAULT_BODY))
	var decay: float = float(tuning.get("decay", DEFAULT_DECAY))
	var variation: float = float(tuning.get("variation", DEFAULT_VARIATION))
	var frequency_variation: float = 0.04 * variation
	var decay_variation: float = 0.08 * variation

	var duration_seconds: float = lerpf(MIN_DURATION_SECONDS, MAX_DURATION_SECONDS, band_strength)
	duration_seconds *= clampf(decay, 0.65, 1.4)
	duration_seconds *= bank_rng.randf_range(1.0 - decay_variation, 1.0 + decay_variation)
	var tuned_min_duration: float = MIN_DURATION_SECONDS * decay
	var tuned_max_duration: float = MAX_DURATION_SECONDS * decay
	duration_seconds = clampf(duration_seconds, tuned_min_duration, tuned_max_duration)
	duration_seconds = clampf(duration_seconds, 0.032, 0.105)
	var sample_count: int = maxi(int(ceil(duration_seconds * float(SAMPLE_RATE))), 1)
	var samples := PackedFloat32Array()
	samples.resize(sample_count)

	var primary_frequency: float = lerpf(3000.0, 1700.0, band_strength)
	primary_frequency *= bank_rng.randf_range(1.0 - frequency_variation, 1.0 + frequency_variation)
	var secondary_frequency: float = lerpf(5000.0, 2800.0, band_strength)
	secondary_frequency *= bank_rng.randf_range(1.0 - frequency_variation, 1.0 + frequency_variation)
	var low_frequency: float = lerpf(750.0, 350.0, band_strength)
	low_frequency *= bank_rng.randf_range(1.0 - frequency_variation, 1.0 + frequency_variation)
	var primary_phase: float = bank_rng.randf_range(0.0, TAU)
	var secondary_phase: float = bank_rng.randf_range(0.0, TAU)
	var low_phase: float = bank_rng.randf_range(0.0, TAU)

	var transient_duration: float = lerpf(0.002, 0.006, band_strength)
	var primary_decay: float = lerpf(0.010, 0.036, band_strength) * decay
	var secondary_decay: float = lerpf(0.006, 0.024, band_strength) * decay
	var low_decay: float = lerpf(0.009, 0.032, band_strength) * decay
	var tail_decay: float = lerpf(0.015, 0.050, band_strength) * decay
	var strength_gain: float = lerpf(0.18, 1.0, pow(band_strength, 0.68))
	var transient_gain: float = lerpf(0.28, 0.62, band_strength) * hardness
	var primary_gain: float = lerpf(0.34, 0.55, band_strength) * body
	var secondary_gain: float = lerpf(0.18, 0.34, band_strength) * brightness
	var low_gain: float = lerpf(0.015, 0.20, band_strength) * body * band_strength
	var tail_gain: float = lerpf(0.008, 0.045, band_strength) * brightness
	_record_generated_metadata(
		primary_frequency,
		secondary_frequency,
		low_frequency,
		duration_seconds,
		transient_duration,
		low_gain / maxf(primary_gain, 0.0001)
	)
	_record_profile_diagnostics(
		2,
		minf(primary_frequency, secondary_frequency),
		maxf(primary_frequency, secondary_frequency),
		minf(primary_decay, secondary_decay),
		maxf(primary_decay, secondary_decay),
		0.0,
		low_frequency,
		low_frequency,
		low_gain / maxf(primary_gain, 0.0001)
	)
	var previous_noise := 0.0
	var sample_sum := 0.0

	for sample_index in range(sample_count):
		var sample_time: float = float(sample_index) / float(SAMPLE_RATE)
		var attack: float = clampf(sample_time / 0.00025, 0.0, 1.0)
		var end_fade: float = clampf((duration_seconds - sample_time) / 0.003, 0.0, 1.0)
		var noise: float = bank_rng.randf_range(-1.0, 1.0)
		var centered_noise: float = noise - previous_noise * 0.45
		previous_noise = noise

		var transient := 0.0
		if sample_time <= transient_duration:
			transient = centered_noise * exp(-sample_time / maxf(transient_duration * 0.24, 0.0001))
		var primary: float = sin(TAU * primary_frequency * sample_time + primary_phase)
		primary *= exp(-sample_time / maxf(primary_decay, 0.001))
		var secondary: float = sin(TAU * secondary_frequency * sample_time + secondary_phase)
		secondary *= exp(-sample_time / maxf(secondary_decay, 0.001))
		var low_body: float = sin(TAU * low_frequency * sample_time + low_phase)
		low_body *= exp(-sample_time / maxf(low_decay, 0.001))
		var material_tail: float = centered_noise * exp(-sample_time / maxf(tail_decay, 0.001))

		var sample_value: float = (
			transient * transient_gain
			+ primary * primary_gain
			+ secondary * secondary_gain
			+ low_body * low_gain
			+ material_tail * tail_gain
		)
		sample_value *= attack * end_fade * strength_gain
		sample_value /= 1.0 + absf(sample_value) * 0.38
		samples[sample_index] = sample_value
		sample_sum += sample_value

	var dc_offset: float = sample_sum / float(sample_count)
	var peak := 0.0
	for sample_index in range(sample_count):
		var sample_time: float = float(sample_index) / float(SAMPLE_RATE)
		var endpoint_fade: float = minf(
			clampf(sample_time / 0.00025, 0.0, 1.0),
			clampf((duration_seconds - sample_time) / 0.003, 0.0, 1.0)
		)
		samples[sample_index] = (samples[sample_index] - dc_offset) * endpoint_fade
		peak = maxf(peak, absf(samples[sample_index]))
	samples[0] = 0.0
	samples[sample_count - 1] = 0.0
	if peak <= 0.000001:
		return null

	# Preserve the authored strength curve instead of normalizing every band to
	# the same loudness. Playback gain adds a second restrained intensity curve.
	var target_peak: float = lerpf(0.24, 0.88, pow(band_strength, 0.72))
	var normalization_gain: float = target_peak / peak
	var audio_data := PackedByteArray()
	audio_data.resize(sample_count * 2)
	for sample_index in range(sample_count):
		var normalized_sample: float = clampf(samples[sample_index] * normalization_gain, -0.98, 0.98)
		var integer_sample: int = int(round(normalized_sample * 32767.0))
		if integer_sample < 0:
			integer_sample += 65536
		var byte_index: int = sample_index * 2
		audio_data[byte_index] = integer_sample & 0xff
		audio_data[byte_index + 1] = (integer_sample >> 8) & 0xff

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	stream.data = audio_data
	return stream


func _is_solid_phenolic_profile(material_profile: String) -> bool:
	return material_profile in [
		MATERIAL_SOLID_PHENOLIC_A_DRY,
		MATERIAL_SOLID_PHENOLIC_B_BALANCED,
		MATERIAL_SOLID_PHENOLIC_C_FULL,
		MATERIAL_SOLID_PHENOLIC_D_SHARP,
	]


func _get_solid_phenolic_candidate_definition(material_profile: String) -> Dictionary:
	match material_profile:
		MATERIAL_SOLID_PHENOLIC_A_DRY:
			return {
				"label": "Solid Phenolic A - Dry",
				"duration_scale": 0.86,
				"modal_decay_scale": 0.78,
				"transient_scale": 0.88,
				"compression_level": 0.018,
				"table_coupling_level": 0.010,
				"upper_mode_scale": 0.90,
				"contact_texture_scale": 0.90,
				"secondary_pulse_enabled": false,
				"secondary_pulse_separation": 0.0,
				"secondary_pulse_ratio": 0.0,
				"highpass_cutoff_hz": 500.0,
				"saturation_amount": 0.38,
			}
		MATERIAL_SOLID_PHENOLIC_C_FULL:
			return {
				"label": "Solid Phenolic C - Full",
				"duration_scale": 1.10,
				"modal_decay_scale": 1.08,
				"transient_scale": 1.08,
				"compression_level": 0.080,
				"table_coupling_level": 0.060,
				"upper_mode_scale": 0.95,
				"contact_texture_scale": 0.95,
				"secondary_pulse_enabled": true,
				"secondary_pulse_separation": 0.00014,
				"secondary_pulse_ratio": 0.27,
				"highpass_cutoff_hz": 400.0,
				"saturation_amount": 0.52,
			}
		MATERIAL_SOLID_PHENOLIC_D_SHARP:
			return {
				"label": "Solid Phenolic D - Sharp",
				"duration_scale": 0.90,
				"modal_decay_scale": 0.82,
				"transient_scale": 0.84,
				"compression_level": 0.020,
				"table_coupling_level": 0.008,
				"upper_mode_scale": 1.28,
				"contact_texture_scale": 1.24,
				"secondary_pulse_enabled": true,
				"secondary_pulse_separation": 0.00007,
				"secondary_pulse_ratio": 0.17,
				"highpass_cutoff_hz": 520.0,
				"saturation_amount": 0.43,
			}
		_:
			return {
				"label": "Solid Phenolic B - Balanced",
				"duration_scale": 1.0,
				"modal_decay_scale": 1.0,
				"transient_scale": 1.0,
				"compression_level": 0.045,
				"table_coupling_level": 0.028,
				"upper_mode_scale": 1.0,
				"contact_texture_scale": 1.0,
				"secondary_pulse_enabled": true,
				"secondary_pulse_separation": 0.00010,
				"secondary_pulse_ratio": 0.20,
				"highpass_cutoff_hz": 450.0,
				"saturation_amount": 0.44,
			}


func _sanitize_tuning(tuning_value: Dictionary) -> Dictionary:
	var material_profile: String = str(
		tuning_value.get("material_profile", DEFAULT_MATERIAL_PROFILE)
	)
	if material_profile == LEGACY_MATERIAL_BILLIARD_RESIN:
		material_profile = MATERIAL_RESONANT_RESIN_PROTOTYPE
	if material_profile not in [
		MATERIAL_SOLID_PHENOLIC_A_DRY,
		MATERIAL_SOLID_PHENOLIC_B_BALANCED,
		MATERIAL_SOLID_PHENOLIC_C_FULL,
		MATERIAL_SOLID_PHENOLIC_D_SHARP,
		MATERIAL_DENSE_PHENOLIC,
		MATERIAL_RESONANT_RESIN_PROTOTYPE,
		MATERIAL_BRIGHT_PROTOTYPE,
	]:
		material_profile = DEFAULT_MATERIAL_PROFILE
	return {
		"material_profile": material_profile,
		"hardness": clampf(float(tuning_value.get("hardness", DEFAULT_HARDNESS)), 0.5, 1.5),
		"brightness": clampf(float(tuning_value.get("brightness", DEFAULT_BRIGHTNESS)), 0.5, 1.5),
		"body": clampf(float(tuning_value.get("body", DEFAULT_BODY)), 0.5, 1.5),
		"decay": clampf(float(tuning_value.get("decay", DEFAULT_DECAY)), 0.65, 1.4),
		"variation": clampf(float(tuning_value.get("variation", DEFAULT_VARIATION)), 0.0, 1.5),
	}


func _reset_generated_metadata() -> void:
	generated_primary_frequency_min_hz = 0.0
	generated_primary_frequency_max_hz = 0.0
	generated_secondary_frequency_min_hz = 0.0
	generated_secondary_frequency_max_hz = 0.0
	generated_body_frequency_min_hz = 0.0
	generated_body_frequency_max_hz = 0.0
	generated_duration_min_ms = 0.0
	generated_duration_max_ms = 0.0
	generated_transient_min_ms = 0.0
	generated_transient_max_ms = 0.0
	generated_body_ratio_sum = 0.0
	generated_metadata_count = 0
	generated_modal_count = 0
	generated_modal_frequency_min_hz = 0.0
	generated_modal_frequency_max_hz = 0.0
	generated_modal_decay_min_ms = 0.0
	generated_modal_decay_max_ms = 0.0
	generated_micro_impulse_separation_min_ms = 0.0
	generated_micro_impulse_separation_max_ms = 0.0
	generated_low_body_frequency_min_hz = 0.0
	generated_low_body_frequency_max_hz = 0.0
	generated_low_body_ratio_min = 0.0
	generated_low_body_ratio_max = 0.0
	generated_profile_metadata_count = 0
	generated_candidate_name = ""
	generated_modal_center_frequencies_hz = PackedFloat32Array()
	generated_secondary_pulse_enabled = false
	generated_compression_impulse_level = 0.0
	generated_table_coupling_level = 0.0
	generated_highpass_cutoff_hz = 0.0
	generated_saturation_amount = 0.0


func _record_generated_metadata(
	primary_frequency: float,
	secondary_frequency: float,
	body_frequency: float,
	duration_seconds: float,
	transient_seconds: float,
	body_ratio: float
) -> void:
	var duration_ms: float = duration_seconds * 1000.0
	var transient_ms: float = transient_seconds * 1000.0
	if generated_metadata_count == 0:
		generated_primary_frequency_min_hz = primary_frequency
		generated_primary_frequency_max_hz = primary_frequency
		generated_secondary_frequency_min_hz = secondary_frequency
		generated_secondary_frequency_max_hz = secondary_frequency
		generated_body_frequency_min_hz = body_frequency
		generated_body_frequency_max_hz = body_frequency
		generated_duration_min_ms = duration_ms
		generated_duration_max_ms = duration_ms
		generated_transient_min_ms = transient_ms
		generated_transient_max_ms = transient_ms
	else:
		generated_primary_frequency_min_hz = minf(
			generated_primary_frequency_min_hz,
			primary_frequency
		)
		generated_primary_frequency_max_hz = maxf(
			generated_primary_frequency_max_hz,
			primary_frequency
		)
		generated_secondary_frequency_min_hz = minf(
			generated_secondary_frequency_min_hz,
			secondary_frequency
		)
		generated_secondary_frequency_max_hz = maxf(
			generated_secondary_frequency_max_hz,
			secondary_frequency
		)
		generated_body_frequency_min_hz = minf(
			generated_body_frequency_min_hz,
			body_frequency
		)
		generated_body_frequency_max_hz = maxf(
			generated_body_frequency_max_hz,
			body_frequency
		)
		generated_duration_min_ms = minf(generated_duration_min_ms, duration_ms)
		generated_duration_max_ms = maxf(generated_duration_max_ms, duration_ms)
		generated_transient_min_ms = minf(generated_transient_min_ms, transient_ms)
		generated_transient_max_ms = maxf(generated_transient_max_ms, transient_ms)
	generated_body_ratio_sum += body_ratio
	generated_metadata_count += 1


func _record_profile_diagnostics(
	modal_count: int,
	modal_frequency_min_hz: float,
	modal_frequency_max_hz: float,
	modal_decay_min_seconds: float,
	modal_decay_max_seconds: float,
	micro_impulse_separation_seconds: float,
	low_body_frequency_min_hz: float,
	low_body_frequency_max_hz: float,
	low_body_ratio: float
) -> void:
	var modal_decay_min_ms: float = modal_decay_min_seconds * 1000.0
	var modal_decay_max_ms: float = modal_decay_max_seconds * 1000.0
	var micro_impulse_separation_ms: float = micro_impulse_separation_seconds * 1000.0
	generated_modal_count = maxi(generated_modal_count, modal_count)
	if generated_profile_metadata_count == 0:
		generated_modal_frequency_min_hz = modal_frequency_min_hz
		generated_modal_frequency_max_hz = modal_frequency_max_hz
		generated_modal_decay_min_ms = modal_decay_min_ms
		generated_modal_decay_max_ms = modal_decay_max_ms
		generated_micro_impulse_separation_min_ms = micro_impulse_separation_ms
		generated_micro_impulse_separation_max_ms = micro_impulse_separation_ms
		generated_low_body_frequency_min_hz = low_body_frequency_min_hz
		generated_low_body_frequency_max_hz = low_body_frequency_max_hz
		generated_low_body_ratio_min = low_body_ratio
		generated_low_body_ratio_max = low_body_ratio
	else:
		generated_modal_frequency_min_hz = minf(
			generated_modal_frequency_min_hz,
			modal_frequency_min_hz
		)
		generated_modal_frequency_max_hz = maxf(
			generated_modal_frequency_max_hz,
			modal_frequency_max_hz
		)
		generated_modal_decay_min_ms = minf(
			generated_modal_decay_min_ms,
			modal_decay_min_ms
		)
		generated_modal_decay_max_ms = maxf(
			generated_modal_decay_max_ms,
			modal_decay_max_ms
		)
		generated_micro_impulse_separation_min_ms = minf(
			generated_micro_impulse_separation_min_ms,
			micro_impulse_separation_ms
		)
		generated_micro_impulse_separation_max_ms = maxf(
			generated_micro_impulse_separation_max_ms,
			micro_impulse_separation_ms
		)
		generated_low_body_frequency_min_hz = minf(
			generated_low_body_frequency_min_hz,
			low_body_frequency_min_hz
		)
		generated_low_body_frequency_max_hz = maxf(
			generated_low_body_frequency_max_hz,
			low_body_frequency_max_hz
		)
		generated_low_body_ratio_min = minf(
			generated_low_body_ratio_min,
			low_body_ratio
		)
		generated_low_body_ratio_max = maxf(
			generated_low_body_ratio_max,
			low_body_ratio
		)
	generated_profile_metadata_count += 1


func _record_solid_phenolic_candidate_diagnostics(
	candidate: Dictionary,
	modal_centers: PackedFloat32Array,
	secondary_pulse_enabled: bool
) -> void:
	var body_scale: float = float(tuning.get("body", DEFAULT_BODY))
	generated_candidate_name = str(candidate.get("label", "Solid Phenolic"))
	generated_modal_center_frequencies_hz = modal_centers.duplicate()
	generated_secondary_pulse_enabled = secondary_pulse_enabled
	generated_compression_impulse_level = clampf(
		float(candidate.get("compression_level", 0.0)) * body_scale,
		0.0,
		0.08
	)
	generated_table_coupling_level = clampf(
		float(candidate.get("table_coupling_level", 0.0)) * body_scale,
		0.0,
		0.06
	)
	generated_highpass_cutoff_hz = float(candidate.get("highpass_cutoff_hz", 0.0))
	generated_saturation_amount = float(candidate.get("saturation_amount", 0.0))


func _get_authored_profile_metadata(material_profile: String) -> Dictionary:
	if material_profile == MATERIAL_BRIGHT_PROTOTYPE:
		return {
			"duration_min_ms": MIN_DURATION_SECONDS * 1000.0,
			"duration_max_ms": MAX_DURATION_SECONDS * 1000.0,
			"transient_min_ms": 2.0,
			"transient_max_ms": 6.0,
		}
	if material_profile == MATERIAL_DENSE_PHENOLIC:
		return {
			"duration_min_ms": DENSE_MIN_DURATION_SECONDS * 1000.0,
			"duration_max_ms": DENSE_MAX_DURATION_SECONDS * 1000.0,
			"transient_min_ms": DENSE_MIN_TRANSIENT_SECONDS * 1000.0,
			"transient_max_ms": DENSE_MAX_TRANSIENT_SECONDS * 1000.0,
		}
	if _is_solid_phenolic_profile(material_profile):
		return {
			"duration_min_ms": SOLID_PHENOLIC_MIN_DURATION_SECONDS * 1000.0,
			"duration_max_ms": SOLID_PHENOLIC_MAX_DURATION_SECONDS * 1000.0,
			"transient_min_ms": SOLID_PHENOLIC_MIN_TRANSIENT_SECONDS * 1000.0,
			"transient_max_ms": SOLID_PHENOLIC_MAX_TRANSIENT_SECONDS * 1000.0,
		}
	return {
		"duration_min_ms": RESIN_MIN_DURATION_SECONDS * 1000.0,
		"duration_max_ms": RESIN_MAX_DURATION_SECONDS * 1000.0,
		"transient_min_ms": RESIN_MIN_TRANSIENT_SECONDS * 1000.0,
		"transient_max_ms": RESIN_MAX_TRANSIENT_SECONDS * 1000.0,
	}
