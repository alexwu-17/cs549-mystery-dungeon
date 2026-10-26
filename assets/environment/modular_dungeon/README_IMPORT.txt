Godot 4.4.1 modular dungeon model export bundle

Contains seven OBJ meshes and matched MTL files. Corrected OBJ material references for floor_corner and up_stairs; renamed floor_wall to floor_wall.mtl. No source meshes changed.

The floor covers 2x2 source units, while the current dungeon renderer is reportedly using 1x1 world-space grid cells. Try 0.5 uniform scale using a Node3D wrapper scene, then verify pivot, Y offset, wall edge/rotation, stairs, and all elevation levels before procedural mass placement.

The MTL files define flat material colors and properties; no image texture files were present in the original archive. Torch is optional. The original .blend and .blend1 files were intentionally excluded; preserve your source archive separately.
