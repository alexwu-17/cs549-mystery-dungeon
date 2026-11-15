class_name PokemonProjectile
extends RefCounted
## Authoritative straight-line targeting on the 2D grid. Rendering never decides hits.


## Tiles a projectile flies over, in order, up to range_tiles from origin.
## Flight stops before the first tile that cannot be traversed from the previous
## one (walls, void, elevation changes, ramp side entries) and stops on the first
## occupied tile, which is included as the final element. Empty means no flight.
static func flight_path(data: DungeonData, origin: Vector2i, direction: Vector2i, range_tiles: int, is_occupied: Callable = Callable()) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	if data == null or absi(direction.x) + absi(direction.y) != 1:
		return path
	var current := origin
	var angled := allows_ramp_angle(data, origin, direction)
	for _step in range(maxi(0, range_tiles)):
		var next := current + direction
		if not data.can_traverse(current, next):
			break
		# A distant ramp cannot bend a level shot toward its endpoint.
		if not angled and (data.get_tile(next) == DungeonData.TileType.RAMP or not is_equal_approx(data.surface_elevation(next), data.surface_elevation(origin))):
			break
		path.append(next)
		if is_occupied.is_valid() and is_occupied.call(next):
			break
		# Angled targets are limited to this ramp and its adjoining buffers.
		if angled and data.get_tile(next) != DungeonData.TileType.RAMP:
			break
		current = next
	return path


static func allows_ramp_angle(data: DungeonData, origin: Vector2i, direction: Vector2i) -> bool:
	if data == null or absi(direction.x) + absi(direction.y) != 1 or not data.can_traverse(origin, origin + direction):
		return false
	return data.get_tile(origin) == DungeonData.TileType.RAMP or data.get_tile(origin + direction) == DungeonData.TileType.RAMP


## Open upper platforms have no walls at a void/drop edge. Keep ordinary
## traversal until that edge, then extend at the original +1 shot height.
## This never makes air walkable and never targets actors on a lower floor.
static func flight_plan(data: DungeonData, origin: Vector2i, direction: Vector2i, range_tiles: int, is_occupied: Callable = Callable(), allow_upper_air: bool = false) -> Dictionary:
	var path := flight_path(data, origin, direction, range_tiles, is_occupied)
	var occupied: bool = not path.is_empty() and is_occupied.is_valid() and bool(is_occupied.call(path.back()))
	var result := {"path": path, "hits_actor": occupied, "air_extension": false, "angled": allows_ramp_angle(data, origin, direction)}
	if not allow_upper_air or data == null or not data.is_walkable(origin) or data.get_elevation(origin) != 1 or data.get_tile(origin) == DungeonData.TileType.RAMP:
		return result
	if absi(direction.x) + absi(direction.y) != 1 or occupied or path.size() >= range_tiles:
		return result
	var current: Vector2i = origin if path.is_empty() else path.back()
	if data.get_elevation(current) != 1 or data.get_tile(current) == DungeonData.TileType.RAMP or data.reserved_transitions.has(current):
		return result
	var edge := current + direction
	# Do not reinterpret a same-height traversal/ramp restriction as open air.
	if data.get_tile(edge) != DungeonData.TileType.VOID and not (data.is_walkable(edge) and data.surface_elevation(edge) < 1.0 and data.get_tile(edge) != DungeonData.TileType.RAMP):
		return result
	for _step in range(path.size(), maxi(0, range_tiles)):
		var next := current + direction
		var kind := data.get_tile(next)
		if kind == DungeonData.TileType.WALL or kind == DungeonData.TileType.RAMP or data.get_elevation(next) > 1:
			break
		if data.reserved_transitions.has(next):
			break
		if kind != DungeonData.TileType.VOID and not data.is_walkable(next):
			break
		path.append(next)
		result.air_extension = true
		if data.is_walkable(next) and data.get_elevation(next) == 1 and is_occupied.is_valid() and is_occupied.call(next):
			result.hits_actor = true
			break
		current = next
	return result
