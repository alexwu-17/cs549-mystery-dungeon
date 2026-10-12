# Character sprite presentation

Original sheets in assets/sprites/source remain unchanged. Run
`python tools/extract_character_sprites.py` to regenerate the 29 RGBA frames and
extraction_manifest.json. The tool requires Pillow, numpy, and scipy.
Run `python tests/validate_sprite_extraction.py` to check hashes, canvases,
padding, and conservation of every nontransparent source pixel.

Frame isolation uses explicitly named body/foot anchors and alpha >32 connected
components as seeds. Faint alpha bridges between adjacent trails are assigned to
the closest seed. Their exact original ownership is ambiguous; this preserves
pixels without repainting, but faint fringe ownership needs visual inspection.
Some faint alpha reaches the original image edge; extraction cannot recover art
that may already be clipped in the supplied sheet. All output frames have padding.
The manifest records source hashes, strong-alpha regions and frame anchors.

CharacterVisual changes textures only. AttackLeap continues to move the visual
node. All frames for one character share a canvas and pixel-space foot anchor.
Tune pixel_size on PlayerSprite, EnemyMesh (now Sprite3D), and BossSprite.
Current sizes are 0.0028, 0.0025, and 0.00746268656716 respectively. The boss stays centered
on its upper anchor plus half a tile along grid Y; transparent canvas width does
not define its logical footprint. The perspective camera is unchanged.

Player/skeleton attack poses span the existing leap. A boss charge resolves its
existing damage and clears warning markers immediately, then spins once through
eight frames at 0.08 seconds each. Sequential rounds await the spin. Lethal boss
damage stops gameplay immediately; the game-over overlay waits for the spin.
Restart invalidates the round before cancellation releases presentation waits.

Inspect feet and body centering in all directions, sword/axe trail isolation,
spin pose jitter, relative character sizes, fog/occlusion on ramps, and charge
arrow visibility in the editor. Source poses differ slightly in body proportion;
extraction deliberately does not resize or redraw them.
