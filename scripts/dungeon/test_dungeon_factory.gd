class_name TestDungeonFactory
extends RefCounted


static func create_test_dungeon() -> DungeonData:
	var dungeon := DungeonData.new()

	# Room 1
	for x in range(0, 5):
		for y in range(0, 5):
			dungeon.set_tile(Vector2i(x, y), DungeonData.TileType.FLOOR, 0)

	# Corridor (unused currently as it was for same level corridor)
	#for x in range(5, 8):
		#dungeon.set_tile(Vector2i(x, 2), DungeonData.TileType.CORRIDOR, 0)
	
	# Corridor from Room 1 toward Room 2
	for x in range(5, 7):
		dungeon.set_tile(Vector2i(x, 2), DungeonData.TileType.CORRIDOR, 0)

	# Ramp connects elevation 0 to elevation +1.
	dungeon.set_tile(
		Vector2i(7, 2),
		DungeonData.TileType.RAMP,
		0
	)

	# Room 2
	for x in range(8, 13):
		for y in range(0, 5):
			dungeon.set_tile(Vector2i(x, y), DungeonData.TileType.FLOOR, 1)

	dungeon.player_spawn = Vector2i(2, 2)
	dungeon.enemy_spawns = [Vector2i(10, 2)]
	dungeon.stairs_position = Vector2i(11, 3)

	var stairs_elevation := dungeon.get_elevation(dungeon.stairs_position)

	dungeon.set_tile(
		dungeon.stairs_position,
		DungeonData.TileType.STAIRS,
		stairs_elevation
	)

	return dungeon
