class_name TestDungeonFactory
extends RefCounted


static func create_test_dungeon() -> DungeonData:
	var dungeon := DungeonData.new()

	# Room 1
	for x in range(0, 5):
		for y in range(0, 5):
			dungeon.set_tile(Vector2i(x, y), DungeonData.TileType.FLOOR, 0)

	# Corridor
	for x in range(5, 8):
		dungeon.set_tile(Vector2i(x, 2), DungeonData.TileType.CORRIDOR, 0)

	# Room 2
	for x in range(8, 13):
		for y in range(0, 5):
			dungeon.set_tile(Vector2i(x, y), DungeonData.TileType.FLOOR, 0)

	dungeon.player_spawn = Vector2i(2, 2)
	dungeon.enemy_spawns = [Vector2i(10, 2)]
	dungeon.stairs_position = Vector2i(11, 3)

	dungeon.set_tile(
		dungeon.stairs_position,
		DungeonData.TileType.STAIRS,
		0
	)

	return dungeon
