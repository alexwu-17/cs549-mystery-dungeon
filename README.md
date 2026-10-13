# CS549 Mystery Dungeon

A 2.5D grid-based, turn-based dungeon crawler built with **Godot 4.4.1** and GDScript for Rutgers University's CS549 Visual AI course.

The project is inspired by *Pokémon Mystery Dungeon*, combining traditional 2D grid-based dungeon gameplay with a 3D environment, elevation changes, lighting, and 2D character sprites.

The current Assignment 3 prototype uses original placeholder gameplay featuring a swordsman, skeleton enemies, and a Minotaur boss while establishing the core dungeon systems.

## Current Features

### Procedural Dungeon Generation
- Procedurally generated rooms and connecting corridors.
- Logical 2D dungeon representation using `Vector2i` coordinates.
- 3D dungeon rendering based on the underlying 2D grid.
- Multiple elevation levels (-1, 0, +1) with traversable ramps.
- Valid player, enemy, and staircase placement.
- Multi-floor dungeon progression.

### Player Movement and Combat
- Grid-based, turn-based player movement.
- Directional facing and basic melee attacks.
- Logical tile occupancy and collision handling.
- Player and enemy HP, damage, and death.
- HP restoration through lifesteal when defeating enemies.
- Game-over handling when the player's HP reaches zero.

### Enemy AI
- Skeleton enemies with breadth-first search (BFS) pathfinding.
- Turn-based enemy movement and attacks.
- Enemy pursuit based on dungeon walkability and occupied tiles.
- Combat integrated with the player's turn system.

### Graphics and Visibility
- 2D character sprites displayed within a 3D dungeon.
- Camera-facing sprite presentation.
- 3D geometry for floors, elevation changes, and ramps.
- Dungeon lighting and shadows.
- Fog of war and visibility based on the player's position.
- Camera occlusion handling to maintain visibility of the player.
- Character movement and attack animations.

### Floor Progression and Boss
- Staircases for transitioning between dungeon floors.
- A dedicated Minotaur boss encounter.
- Boss combat and dungeon completion handling.

## Game Modes

The project includes three modes:

- **Demo Mode:** A five-floor dungeon experience featuring procedurally generated floors 1–4 and a fixed Minotaur boss arena on floor 5.
- **Infinite Mode:** Continued dungeon progression without a fixed final floor.
- **Limit Testing Mode:** A dedicated environment for evaluating the game's performance and behavior under increased enemy loads.

## Controls

| Input | Action |
|---|---|
| W | Move up |
| S | Move down |
| A | Move left |
| D | Move right |
| Space | Basic attack |
| F3 | Toggle performance HUD |

Movement and combat are turn-based. Successful movement and attack actions advance the game by one turn. Changing facing direction or attempting to move into an impassable tile does not consume a turn.

## Requirements

- **Godot Engine 4.4.1** (Godot 4.4 series)
- A system capable of running Godot 4's 3D renderer
- Git (for cloning the repository)

No external GDScript dependencies are required.

## Building and Running

### Run from the Godot Editor

1. Install [Godot 4.4.1](https://godotengine.org/download/archive/4.4.1-stable/).
2. Clone the repository:
   ```bash
   git clone https://github.com/alexwu-17/cs549-mystery-dungeon.git
   ```
3. Open Godot and select **Import**.
4. Navigate to the cloned repository and select `project.godot`.
5. Allow Godot to import the project's resources.
6. Press **F6** to run the currently open scene, or **F5** to run the project's configured main scene.

### Export a Standalone Build

1. Open the project in Godot 4.4.1.
2. Navigate to **Project → Export**.
3. Add an export preset for your target platform (Windows, Linux, macOS, or Web).
4. Install the matching Godot export templates if prompted.
5. Configure the export preset and destination.
6. Select **Export Project** to generate the build.

For Web exports, use the Web preset and host the generated files on a compatible web server or static hosting service.

## Architecture

The project separates dungeon logic from its 3D presentation.

### DungeonData

`DungeonData` is the authoritative logical representation of each floor.

Gameplay systems use `Vector2i` grid coordinates for movement, occupancy, walkability, enemy pathfinding, and combat rather than relying on 3D physics collisions.

Dungeon data also contains elevation information and the locations of relevant floor entities.

### Dungeon Generation

Procedural generation creates rooms, corridors, elevation assignments, and traversable connections between dungeon areas.

Player, enemy, and staircase positions are selected from valid locations within the generated dungeon.

### DungeonRenderer

`DungeonRenderer` converts logical grid coordinates and elevation metadata into the rendered 3D dungeon.

- `grid_to_world()` maps logical grid coordinates to their corresponding base world positions.
- `get_entity_world_position()` determines the appropriate surface position for entities, accounting for elevation.

### Turn-Based Gameplay

Player actions drive the turn system. Enemy AI processes movement and attacks according to the current dungeon state.

Skeleton pathfinding uses BFS over the logical dungeon grid, while combat and collision rely on logical tile occupancy.

### Visibility and Camera

Fog of war determines which dungeon areas are visible to the player.

Camera occlusion handling separately adjusts obstructing geometry to keep the player visible within the 3D environment.

## Development Status

**Assignment 3 — Functional MVP**

The current implementation demonstrates the core dungeon generation, rendering, movement, combat, enemy AI, visibility, elevation, floor progression, and boss systems.

Future development will focus on environmental presentation, visual polish, and expanding the gameplay toward the project's original Pokémon Mystery Dungeon inspiration.