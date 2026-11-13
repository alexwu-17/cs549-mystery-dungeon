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
	for _step in range(maxi(0, range_tiles)):
		var next := current + direction
		if not data.can_traverse(current, next):
			break
		path.append(next)
		if is_occupied.is_valid() and is_occupied.call(next):
			break
		current = next
	return path
