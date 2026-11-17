class_name GameModeConfig
extends RefCounted

enum Mode { INFINITE, DEMO, LIMIT_TESTING }
const DEMO_FINAL_FLOOR: int = 6
const DRAPION_FLOOR: int = DEMO_FINAL_FLOOR - 1

static func is_arena(mode: Mode, floor_number: int) -> bool:
	return mode == Mode.DEMO and floor_number >= DRAPION_FLOOR

static func can_advance(mode: Mode, floor_number: int) -> bool:
	return mode != Mode.DEMO or floor_number < DEMO_FINAL_FLOOR

static func is_final_floor(mode: Mode, floor_number: int) -> bool:
	return mode == Mode.DEMO and floor_number == DEMO_FINAL_FLOOR
