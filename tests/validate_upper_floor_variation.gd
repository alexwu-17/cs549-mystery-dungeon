extends SceneTree
const Snapshots=preload("res://tests/validate_terraces.gd")
func _initialize(): call_deferred("run")
func snapshot(renderer: DungeonRenderer) -> Array:
	var result:Array=[]
	for v in renderer.fog_visuals:
		result.append([v.tiles,v.purpose,v.mesh.transform,v.mesh.mesh if v.purpose=="floor" else v.mesh.mesh.get_aabb(),v.materials if v.purpose=="floor" else []])
	return result
func run():
	var data=TestDungeonFactory.create_fallback_dungeon()
	data.update_fog(data.player_spawn)
	var before=Snapshots.snapshot(data)
	var state=TestDungeonFactory.rng.state
	var renderer=DungeonRenderer.new()
	root.add_child(renderer)
	renderer.upper_floor_quarter_turns_enabled=false
	assert(renderer.render_dungeon(data))
	var baseline=snapshot(renderer)
	renderer.upper_floor_quarter_turns_enabled=true
	assert(renderer.render_dungeon(data))
	var varied=snapshot(renderer)
	assert(varied.size()==baseline.size())
	var turns:Dictionary={}
	for i in range(varied.size()):
		var v=renderer.fog_visuals[i]
		var tile:Vector2i=v.tiles[0]
		var eligible=v.purpose=="floor" and renderer.is_open_upper_tile(tile) and data.get_tile(tile) in [DungeonData.TileType.FLOOR,DungeonData.TileType.CORRIDOR] and not data.reserved_transitions.has(tile)
		if not eligible: assert(varied[i]==baseline[i]); continue
		assert(varied[i][3]==baseline[i][3] and varied[i][4]==baseline[i][4])
		assert(v.mesh.position==baseline[i][2].origin)
		var turn=posmod(renderer.floor_hash(tile),4)
		turns[turn]=true
		assert(v.mesh.basis.is_equal_approx(baseline[i][2].basis.rotated(Vector3.UP,turn*PI/2.0)))
	assert(turns.size()==4)
	assert(renderer.render_dungeon(data) and snapshot(renderer)==varied)
	renderer.upper_floor_quarter_turns_enabled=false
	assert(renderer.render_dungeon(data) and snapshot(renderer)==baseline)
	assert(Snapshots.snapshot(data)==before and TestDungeonFactory.rng.state==state)
	renderer.free()
	print("PASS: four upper-floor quarter turns, deterministic rebuild, exact rollback, shared meshes/materials/node count, protected visuals/topology/RNG unchanged")
	quit()
