\# CS549 Mystery Dungeon



A 2.5D grid-based dungeon crawler built with Godot 4.4.1 and GDScript.



The final project is inspired by Pokemon Mystery Dungeon. The current

Assignment 3 prototype intentionally uses generic/test content while the

core dungeon systems are developed.



\## Current Prototype



The starter implementation currently demonstrates:



\- Logical 2D grid representation using Vector2i

\- 2D grid to 3D dungeon rendering

\- Grid-based player movement

\- Walkability checks

\- Room elevation metadata

\- Ramp traversal between elevations

\- Sprite3D player representation

\- Enemy spawn positions

\- Staircase/floor transition signaling



The current test dungeon contains two hard-coded rooms. Room 2 is one

elevation level above Room 1.



The staircase intentionally reloads the same test floor indefinitely.

This behavior is temporary and provides the floor-transition interface

for procedural generation.



The test enemy is intentionally static.



\## Test Enemy



The current test enemy is a static spawn marker used to verify that

enemy spawn coordinates from DungeonData are correctly translated into

the 3D world.



The starter implementation intentionally does not implement enemy

occupancy, collision, pathfinding, attacks, or combat.



The enemy/combat system should implement logical grid occupancy rather

than relying on 3D physics collisions. Attempting to move into a tile

occupied by an enemy should eventually trigger the appropriate combat

behavior rather than allowing the player to occupy the same logical

tile.



\## Controls



W - Move up

S - Move down

A - Move left

D - Move right



\## Running



1\. Install Godot 4.4.1.

2\. Clone this repository.

3\. Open `project.godot` in Godot.

4\. Open `scenes/main/main.tscn`.

5\. Run the scene/project.



\## Architecture



DungeonData is the authoritative logical representation of a floor.



Gameplay systems should primarily use Vector2i grid coordinates rather

than raw Vector3 positions.



DungeonRenderer converts logical grid coordinates and elevation metadata

into the 3D world.



`grid\_to\_world()` represents the base geometry coordinate.



`get\_entity\_world\_position()` returns the surface position where an

entity should stand.



TestDungeonFactory is temporary reference code and is expected to be

replaced by procedural dungeon generation.



\## Assignment 3 Work Split



\### Dungeon / Fog

\- Procedural room generation

\- Corridor generation

\- Elevation assignment

\- Valid ramp connections

\- Player/enemy/stair spawn placement

\- Fog of war



\### Enemy / Combat

\- Skeleton implementation

\- Enemy grid pathfinding

\- Enemy turn behavior

\- Basic player/enemy attacks

\- HP/death

\- Lifesteal on kill



\### Graphics

\- Dungeon environment assets

\- Materials/textures

\- Elevation/ramp visual assets



\### Integration / Core

\- Core Godot architecture

\- Player/grid integration

\- 2D-to-3D rendering integration

\- Elevation integration

\- Floor transitions

\- Team integration/debugging

\- Final polish

