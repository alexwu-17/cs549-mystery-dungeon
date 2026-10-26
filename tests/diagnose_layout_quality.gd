extends SceneTree
## Headless: --script res://tests/diagnose_layout_quality.gd -- --seeds=250

func _initialize() -> void: call_deferred("diagnose")

func add_report(totals: Dictionary, report: Dictionary) -> void:
	if not report.get("evaluated", false): return
	totals.layouts += 1
	totals.violating_layouts += int(not report.violating_pairs.is_empty())
	totals.overlap_layouts += int(not report.potential_overlap_pairs.is_empty())
	totals.deficit += report.total_deficit
	for pair in report.pairs:
		var level: Dictionary = totals.by_difference[pair.difference]
		level.pairs += 1
		level.violations += int(pair.deficit > 0)
		level.overlaps += int(pair.potential_camera_overlap)
		level.separation_sum += pair.empty_separation

func new_totals() -> Dictionary:
	return {"layouts": 0, "violating_layouts": 0, "overlap_layouts": 0, "deficit": 0,
		"by_difference": [{"pairs": 0, "violations": 0, "overlaps": 0, "separation_sum": 0},
			{"pairs": 0, "violations": 0, "overlaps": 0, "separation_sum": 0},
			{"pairs": 0, "violations": 0, "overlaps": 0, "separation_sum": 0}]}

func diagnose() -> void:
	var seeds := 250
	var start_seed := 0
	var size := Vector2i(30, 22)
	var settings: DungeonQualitySettings = DungeonLayoutQuality.DEFAULT_SETTINGS.duplicate()
	settings.enabled = true
	var generation: DungeonGenerationConfig = TestDungeonFactory.get_default_config().duplicate()
	var output := "res://.godot/quality_diagnostics/layout_quality.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seeds="): seeds = arg.trim_prefix("--seeds=").to_int()
		elif arg.begins_with("--start-seed="): start_seed = arg.trim_prefix("--start-seed=").to_int()
		elif arg.begins_with("--one-level="): settings.one_level_gap = arg.trim_prefix("--one-level=").to_int()
		elif arg.begins_with("--two-level="): settings.two_level_gap = arg.trim_prefix("--two-level=").to_int()
		elif arg.begins_with("--pitch="): settings.camera_pitch_degrees = arg.trim_prefix("--pitch=").to_float()
		elif arg == "--legacy":
			generation.elevation_mode = DungeonGenerationConfig.ElevationMode.LEGACY_THREE_LEVEL
			generation.restrict_camera_hidden_ramps = false
		elif arg == "--unrestricted": generation.restrict_camera_hidden_ramps = false
		elif arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		elif arg.begins_with("--size="):
			var components := arg.trim_prefix("--size=").split("x")
			if components.size() != 2:
				push_error("Use --size=30x22.")
				quit(1)
				return
			size = Vector2i(components[0].to_int(), components[1].to_int())
		else:
			push_error("Unknown diagnostic argument: " + arg)
			quit(1)
			return
	if seeds < 1 or seeds > 10000 or size.x < 16 or size.y < 8 or size.x > 128 or size.y > 128 or not settings.validation_errors().is_empty():
		push_error("Invalid diagnostic seed count, map dimensions, or quality settings.")
		quit(1)
		return
	# Local Resources leave both standard defaults and user-edited Limit config intact.
	generation.map_size = size
	generation.quality_settings = settings
	var accepted := new_totals()
	var proposals := new_totals()
	var fallbacks := 0
	var retries := 0
	var attempts := 0
	var route_attempts := 0
	var max_attempts := 0
	var examples: Array[Dictionary] = []
	var records: Array[Dictionary] = []
	for seed_value in range(start_seed, start_seed + seeds):
		TestDungeonFactory.rng.seed = seed_value
		var data := TestDungeonFactory.create_configured_dungeon(generation)
		var report: Dictionary = TestDungeonFactory.last_quality_report.duplicate(true)
		var evaluated: Array[Dictionary] = TestDungeonFactory.last_quality_attempts.duplicate(true)
		fallbacks += int(data.used_fallback)
		retries += int(data.generation_attempts > 1)
		attempts += data.generation_attempts
		route_attempts += data.routing_attempts
		max_attempts = maxi(max_attempts, data.generation_attempts)
		for candidate in evaluated: add_report(proposals, candidate)
		if not data.used_fallback: add_report(accepted, report)
		if not report.potential_overlap_pairs.is_empty() and examples.size() < 5:
			examples.append({"seed": seed_value, "pairs": report.potential_overlap_pairs, "violations": report.violating_pairs.size(), "deficit": report.total_deficit})
		records.append({"seed": seed_value, "fallback": data.used_fallback, "layouts": data.generation_attempts, "routes": data.routing_attempts,
			"final": report, "proposals": evaluated})
		if (seed_value - start_seed + 1) % 50 == 0: print("QUALITY PROGRESS ", seed_value - start_seed + 1, "/", seeds)
	var summary := {"seeds": seeds, "start_seed": start_seed, "size": size, "thresholds": [settings.same_elevation_gap, settings.one_level_gap, settings.two_level_gap],
		"elevation_mode": generation.elevation_mode, "restricted_ramps": generation.restrict_camera_hidden_ramps,
		"camera_pitch": settings.camera_pitch_degrees, "fallbacks": fallbacks, "retried_floors": retries, "layout_attempts": attempts,
		"max_layouts": max_attempts, "route_attempts": route_attempts, "accepted_random": accepted, "pre_rasterization_proposals": proposals, "examples": examples}
	print("QUALITY SUMMARY ", JSON.stringify(DungeonLayoutQuality.serializable(summary)))
	var document := {"scope": "evaluation_only; selected generation policy; fixed +Z parallel camera-envelope proxy", "engine": Engine.get_version_info().string,
		"summary": summary, "floors": records}
	var directory := ProjectSettings.globalize_path(output).get_base_dir()
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		push_error("Could not create diagnostic output directory.")
		quit(1)
		return
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		push_error("Could not open diagnostic output: " + output)
		quit(1)
		return
	file.store_string(JSON.stringify(DungeonLayoutQuality.serializable(document), "\t"))
	file.close()
	print("QUALITY REPORT ", ProjectSettings.globalize_path(output))
	quit()
