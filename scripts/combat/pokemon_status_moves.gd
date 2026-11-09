class_name PokemonStatusMoves
extends RefCounted
## Targeting and stage application only; Main retains PP/round/lifecycle ownership.
static func apply(source: Node3D, data: DungeonData, target_tile: Vector2i, actors: Array[Node3D], move: PokemonMoveData) -> Array[Node3D]:
	var targets: Array[Node3D] = []
	if move.targeting == PokemonMoveData.Targeting.SELF:
		targets.append(source)
	else:
		var room := data.get_room_id(source.grid_position)
		for actor in actors:
			if not is_instance_valid(actor) or actor.health.current <= 0: continue
			var tiles: Array[Vector2i] = [actor.grid_position]
			if actor.has_method("footprint"): tiles.assign(actor.footprint())
			for tile in tiles:
				var matches := move.targeting == PokemonMoveData.Targeting.ADJACENT and tile == target_tile and data.can_traverse(source.grid_position, tile)
				matches = matches or (move.targeting == PokemonMoveData.Targeting.SAME_ROOM and room >= 0 and data.get_room_id(tile) == room)
				if matches:
					targets.append(actor)
					break
	var changed: Array[Node3D] = []
	for actor in targets:
		if actor.battle_state.change_stage(move.affected_stat, move.stage_change) != 0:
			changed.append(actor)
	return changed
