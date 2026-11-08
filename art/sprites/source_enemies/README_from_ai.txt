HackSla enemies & objects sprite set (2026-11-08, per pixel-art-enemies-request.md)

Game-ready sheets (transparent, 16 colors each)
- hacksla_rockgolem_22px.png      : 66x22, 3 cells of 22x22, order front / back / right
- hacksla_treasure_chest_18px.png : 36x14, 2 cells of 18x14, order closed / open
- hacksla_training_dummy_16x30.png: 16x30, front only
- hacksla_drop_icons_8px.png      : 48x8, 6 cells of 8x8, order skill gem (red) /
  support gem (blue) / sword / armor / ring / coin
Previews are 12-24x enlargements on green. Sources are the high-res generations.

Post-processing (same as player sprites)
- Green/white background removal, largest-component cleanup, NEAREST resize,
  16-color quantization, bottom alignment
- Hand fixes after resize: rock golem glowing eyes repainted (pale yellow),
  chest lock repainted (gold + keyhole), ring center hole cleared in icons

Known issues
- Open chest reads poorly at 18x14 (dark and muddy). Regeneration with a
  simpler, bolder design is recommended if it matters.
- Drop icons were extracted per connected component, not by equal slicing
  (spacing in the source was uneven).
- Slime reference image in the request doc was not attached this time,
  so style matching used the samurai sprite only.
