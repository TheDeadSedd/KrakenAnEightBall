extends RefCounted
class_name RogueliteDoubloonPayoutResolver

# Pure, value-only Long Sink Doubloon payout derivation. Wallet mutation and
# transaction deduplication belong to the authoritative shot-settlement owner.

const SCHEMA_VERSION := 1
const PAYOUT_SOURCE := "haul_mult_base_haul_v1"
const SUPPORTED_SCORE_SCHEMA_VERSION := 1
const SUPPORTED_SCORING_MODEL := "haul_mult_v1"
const BASE_HAUL_PER_DOUBLOON := 10


static func resolve(score_result: Dictionary) -> Dictionary:
	var payout: Dictionary = _make_empty_result(score_result)
	var warnings: Array[String] = []

	if int(score_result.get("schema_version", -1)) != SUPPORTED_SCORE_SCHEMA_VERSION:
		warnings.append("Unsupported, missing, or invalid Haul x Mult result schema version.")
		return _finalize_safe_zero(payout, warnings)
	if str(score_result.get("scoring_model", "")) != SUPPORTED_SCORING_MODEL:
		warnings.append("Payout input is not an authoritative Haul x Mult score result.")
		return _finalize_safe_zero(payout, warnings)

	var shot_id_value: Variant = score_result.get("shot_id", null)
	var attempt_id_value: Variant = score_result.get("attempt_id", null)
	if not _is_nonnegative_integer(shot_id_value):
		warnings.append("Shot ID is missing or invalid; payout cannot be applied safely.")
		return _finalize_safe_zero(payout, warnings)
	if not _is_nonnegative_integer(attempt_id_value):
		warnings.append("Attempt ID is missing or invalid; payout cannot be applied safely.")
		return _finalize_safe_zero(payout, warnings)

	var base_haul_value: Variant = score_result.get("base_haul", null)
	if not _is_nonnegative_integer(base_haul_value):
		warnings.append("Base Haul is missing or invalid; payout was resolved to zero.")
		return _finalize_safe_zero(payout, warnings)

	var base_haul: int = int(base_haul_value)
	var scoring_object_ball_count: int = int(floor(
		float(base_haul) / float(BASE_HAUL_PER_DOUBLOON)
	))
	if base_haul % BASE_HAUL_PER_DOUBLOON != 0:
		warnings.append(
			"Base Haul is not divisible by %d; Doubloon payout was floored."
			% BASE_HAUL_PER_DOUBLOON
		)

	payout["shot_id"] = int(shot_id_value)
	payout["attempt_id"] = int(attempt_id_value)
	payout["base_haul"] = base_haul
	payout["scoring_object_ball_count"] = scoring_object_ball_count
	payout["doubloons_awarded"] = scoring_object_ball_count
	payout["warnings"] = warnings
	return payout.duplicate(true)


static func _make_empty_result(score_result: Dictionary) -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"source": PAYOUT_SOURCE,
		"shot_id": _safe_int(score_result.get("shot_id", -1), -1),
		"attempt_id": _safe_int(score_result.get("attempt_id", -1), -1),
		"base_haul": 0,
		"scoring_object_ball_count": 0,
		"doubloons_awarded": 0,
		"warnings": [],
	}


static func _finalize_safe_zero(payout: Dictionary, warnings: Array[String]) -> Dictionary:
	payout["base_haul"] = 0
	payout["scoring_object_ball_count"] = 0
	payout["doubloons_awarded"] = 0
	payout["warnings"] = warnings
	return payout.duplicate(true)


static func _is_nonnegative_integer(value: Variant) -> bool:
	return value is int and int(value) >= 0


static func _safe_int(value: Variant, fallback: int) -> int:
	return int(value) if value is int else fallback
