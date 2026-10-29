class_name GameModeConfig
extends RefCounted

enum Mode { INFINITE, DEMO, LIMIT_TESTING }
const DEMO_FINAL_FLOOR: int = 3

static func is_arena(mode: Mode, floor_number: int) -> bool:
	return mode == Mode.DEMO and floor_number >= DEMO_FINAL_FLOOR

static func can_advance(mode: Mode, floor_number: int) -> bool:
	return not is_arena(mode, floor_number)
