class_name EnemyFlowMap
extends RefCounted
## Terrain-only distances to the player. Occupancy is checked during each action.
const DIRECTIONS = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]

static func build(dungeon: DungeonData, goal: Vector2i) -> Dictionary:
	var distances := {}
	if not dungeon.is_walkable(goal):
		return distances
	distances[goal] = 0
	var queue: Array[Vector2i] = [goal]
	var index := 0
	while index < queue.size():
		var current := queue[index]
		index += 1
		for direction: Vector2i in DIRECTIONS:
			var neighbor := current + direction
			if distances.has(neighbor) or not dungeon.can_traverse(neighbor, current):
				continue
			distances[neighbor] = int(distances[current]) + 1
			queue.append(neighbor)
	return distances
