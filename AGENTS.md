\## Current Development Phase



\### Assignment 3 MVP



The shared starter architecture is implemented.



Currently working:

\- Hard-coded DungeonData test floor

\- 2D grid to 3D rendering

\- Grid player movement

\- Elevation metadata

\- Ramp traversal

\- Sprite3D player architecture

\- Staircase transition signal

\- Static enemy spawn



Parallel work now focuses on:

\- Procedural dungeon generation and fog of war

\- Skeleton pathfinding and combat

\- Environment graphics/assets



\## Important Architecture Rules



DungeonData is authoritative for dungeon topology.



Gameplay positions use Vector2i grid coordinates.



Do not make raw Vector3 world positions authoritative for gameplay.



DungeonRenderer is responsible for translating logical positions into

3D presentation.



Use `get\_entity\_world\_position()` when positioning gameplay entities.



Player and enemy visuals should ultimately use Sprite3D rather than 3D

character models.



TestDungeonFactory is temporary reference/demo code.



Do not expand Assignment 3 into Pokemon-specific functionality unless

explicitly requested.

