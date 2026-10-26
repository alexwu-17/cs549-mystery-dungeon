# Decorative upper terrain prototype

The current default uses the validated geometry pipeline described in
[environment_geometry.md](environment_geometry.md). The comparisons below describe
the preceding terrace prototype, available with `geometry_validation_enabled = false`.

The standard renderer defaults to bounded stone terraces. The dungeon generator,
42×32 configuration, tile types/elevations, traversal, and gameplay are unchanged.
`TerrainFillVisuals.layout()` remains the original ownership algorithm for rollback;
`UpperTerrainVisuals.prepare()` adapts a deep copy before creating visual meshes.

## Inspector controls on DungeonRenderer

| Property | Default | Purpose |
| --- | --- | --- |
| `upper_terrain_mode` | TERRACES | UNLIMITED restores the preceding open-platform filler; BOUNDED retains flat raised filler within the limit; TERRACES steps it down. |
| `upper_filler_max_distance` | 3 | Maximum cardinal expansion from upper-room tiles into eligible empty cells; the first outside boundary cell has distance 1. |
| `terrace_band_width` | 1 | Width of each descending band, in tiles. |
| `terrace_irregular_edges` | true | A stable coordinate hash thins a small portion of the outer band. No gameplay RNG is used. |
| `terrace_protected_clearance` | 1 | Square clearance around lower terrain, stairs, and corridor tiles. |

The existing `upper_elevation_open_platforms`, `upper_corridor_support_height`,
`terrain_fill_enabled`, and `terrain_fill_margin` options remain available.
Changes take effect when the dungeon is rendered again (e.g. restart).

With a width of 1 and the existing elevation rise of 3, terrace tops are about
2.1, 1.1, and 0.1 world units. The extra 0.1 is the existing floor-surface offset.
Intermediate bands never enter `DungeonData.elevations`. Beyond the bounded raised
region, formerly upper-owned filler settles to the lower stone base. A wider band
or lower distance limit can omit a height tier; cramped layouts may omit tiers too.

Only existing upper-room-owned void is eligible. Original lower filler, conventional
lower walls, floors, stairs, and upper walkway floor/support meshes are retained.
Reserved ramp footprints, side clearance, and both approach tiles are excluded.
Lower paths, stairs and upper walkways receive additional clearance. Thin stone
skirts inside upper room edges connect the imported floor underside to nearby bands
where safe. No collision shapes or navigation data are created.

The current zero-yaw camera views from +Z. A conservative viewing stripe excludes
raised decoration near lower walkable tiles, including ramps. It reads the actual
camera script's pitch when available and defaults to the current 35 degrees in
standalone renderer tests. This is not a universal visibility guarantee for arbitrary
camera angles or artwork; revalidate if the camera changes.

Benchmark, legacy elevation fixture, and Demo boss-floor startup explicitly preserve
the prior terrain presentation. Lower-only layouts and `legacy_ramp` data also bypass
the adapter, including standalone renderer usage.

## Measured comparison

Godot 4.4.1, seeds 0–29, standard 42×32 generation; each generated floor was rendered
in all three modes. Counts are totals across 30 floors.

| Metric | Unlimited | Bounded | Terraces |
| --- | --- | --- | --- |
| Raised upper filler cells | 7,432 | 3,480 | 2,100 |
| Intermediate-height decorative cells | 0 | 0 | 2,100 |
| Former upper filler cells settled to lower ground | 0 | 3,674 | 5,054 |
| Cells/skirts flagged by the conservative viewing stripe | 435 | 0 | 0 |
| Cells/skirts intersecting sampled perspective sprite rays | 169 | 0 | 0 |
| Supporting edge skirts | 0 | 32 | 1,053 |
| Exposed/partially open underside edges | 139 | 472 | 561 |

Terraces reduce raised filler coverage by about 72%. Camera-ray tests use actual
transformed bounds and nine billboard-body samples at every lower walkable tile;
the ray test is independent of the stripe predicate. These numbers count obstructing
meshes, not affected players or screen pixels. They exclude unchanged conventional
lower filler, walkable floors, and upper corridor supports.

The underside count is an explicit prototype limitation: safety masks sometimes
omit a skirt or band, leaving an abrupt drop or open underside near protected
paths/entrances. It does **not** mean a hole in the walkable floor. Supporting
skirts are retained where they pass clearance checks; forced complete cliffs would
conflict with the visibility requirement in some current layouts. Review these
edges visually before treating this prototype as finished environmental art.

## Validation and manual review

`tests/validate_terraces.gd` writes JSON measurements to
`res://.godot/quality_diagnostics/terrace_metrics.json`. It compares all scripted
DungeonData properties and RNG state across rendering modes, lower mesh bounds,
transforms/materials, protected areas, deterministic helper output, maximum
distance, fog material selection, fade/shadow restoration, fixture exemptions, and
upper-only debug geometry. The existing traversal validation still passes.

Headless import and focused tests passed. The full suite completed with 30/31 scripts
passing; `validate_attack_leap.gd:93` retains its previously reported restart
assertion failure. Existing ObjectDB/resource shutdown warnings remain in some tests.

Manual checks:

1. Run Main or Demo and restart using each terrain mode on the same seeded layout
   if comparing shapes; ordinary R restart randomizes the layout as before.
2. Walk around upper platform edges, lower corridors, stairs, and every ramp
   orientation. Inspect step joins, abrupt protected cutoffs, and exposed undersides.
3. Cross elevations and revisit rooms. Confirm fog colors, enemies, stairs, minimap,
   selective fading and restoration remain correct.
4. Run the benchmark, legacy elevation fixture, and Demo 5F. Their presentation
   should remain unchanged. Check 1080p performance with recording active.

This uses gray placeholder stone meshes. It does not implement organic rock art,
walkable intermediate elevations, bridges, generation repair, or AI inference.
