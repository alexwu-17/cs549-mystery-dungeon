# AGENTS.md — Visual AI Dungeon Project

## Project Overview

This is a Godot 4.7.2 project written primarily in GDScript.

The project is a 2.5D, grid-based dungeon crawler inspired by Pokémon Mystery Dungeon. Its goal is to translate classic 2D dungeon-crawling gameplay into a three-dimensional environment while retaining grid-based movement, procedural dungeon generation, and 2D character sprites.

The current priority is completing the Assignment 3 MVP. The initial playable experience features a swordsman fighting skeletons. Pokémon-specific content will be introduced during later development.

Codex should prioritize working, testable, maintainable functionality over premature abstraction or visual polish.

## Current Development Phase — Assignment 3 MVP

The shared starter architecture exists, and the procedural dungeon-generation branch has been merged.

### Previously implemented and tested

- Hardcoded two-room dungeon with a connecting corridor.
- Conversion of logical 2D dungeon tiles into 3D geometry.
- Grid-based player movement.
- Elevation metadata and ramp traversal.
- Player architecture supporting Sprite3D visuals.
- Staircase interaction and floor-reset behavior.
- Static enemy spawning using placeholder geometry.

These features were tested against the original hardcoded dungeon. They must be revalidated against the merged procedural generator.

### Merged but incomplete or unverified

- Randomized room placement.
- Room-overlap detection.
- Corridor generation and room connectivity.
- 2D grid and room metadata.
- Procedural dungeon integration with the renderer.

Known issues to investigate include incorrect room indexing during corridor generation, potentially unsupported GDScript array methods, and missing or incomplete gameplay spawn data.

The merged generator currently lacks complete staircase placement, enemy spawning, elevation integration, and functional fog of war.

Do not assume that the merged project is playable until it has been tested in Godot.

### Not yet implemented

- Turn-based skeleton movement and pathfinding.
- Logical entity occupancy and collision prevention.
- Player and enemy attacks.
- Health, damage, death, and game-over.
- Player healing on enemy defeat.
- Functional fog of war.
- Complete procedural elevation and ramp integration.
- Solid environmental walls around rooms and corridors.

## MVP Gameplay Requirements

Implement a simple, playable swordsman-versus-skeleton dungeon crawler.

Required behavior:

- The player moves one tile at a time using the existing grid movement system.
- Enemies occupy logical grid positions and cannot overlap the player or one another.
- Skeletons pursue the player using grid-based pathfinding.
- Player actions trigger enemy turns.