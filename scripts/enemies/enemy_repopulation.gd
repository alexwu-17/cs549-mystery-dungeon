class_name EnemyRepopulation
extends RefCounted
## Floor-lifetime timer and safe spawn selection, independent of generation RNG.
var empty_turns: int = 0
var just_cleared: bool = false
var rng := RandomNumberGenerator.new()

func _init() -> void:
	rng.randomize()

func reset() -> void:
	empty_turns = 0
	just_cleared = false

func cleared() -> void:
	reset()
	just_cleared = true

func advance(has_enemies: bool, delay: int) -> bool:
	if has_enemies:
		reset()
		return false
	if just_cleared:
		just_cleared = false
		return false
	empty_turns += 1
	if empty_turns < delay: return false
	empty_turns = 0
	return true

func candidates(data: DungeonData, player_tile: Vector2i, occupied: Dictionary) -> Array[Vector2i]:
	# Search only on demand. Use the exact movement graph, including ramp rules.
	var visited := {player_tile: true}
	var queue: Array[Vector2i] = [player_tile]
	var index := 0
	while index < queue.size():
		var tile := queue[index]
		index += 1
		for direction: Vector2i in DungeonData.CARDINALS:
			var neighbor := tile + direction
			if not visited.has(neighbor) and data.can_traverse(tile, neighbor):
				visited[neighbor] = true
				queue.append(neighbor)
	var result: Array[Vector2i] = []
	var player_room := data.get_room_id(player_tile)
	for tile: Vector2i in queue:
		var room := data.get_room_id(tile)
		# Room interiors only: never the player's corridor, ramps or exit stairs.
		if room < 0 or room == player_room or tile == player_tile: continue
		if data.get_tile(tile) != DungeonData.TileType.FLOOR: continue
		if occupied.has(tile) or data.is_bright(tile) or data.reserved_transitions.has(tile): continue
		result.append(tile)
	return result

func choose(data: DungeonData, player_tile: Vector2i, occupied: Dictionary) -> Variant:
	var eligible := candidates(data, player_tile, occupied)
	if eligible.is_empty(): return null
	return eligible[rng.randi_range(0, eligible.size() - 1)]
