# Replacement art

Anything placed here replaces the built-in placeholder with the same name. You
don't need to change any code. See [`../art/PIPELINE.md`](../art/PIPELINE.md)
for how to make the files, and [`../art/asset-manifest.json`](../art/asset-manifest.json)
for the full list of names.

| Folder | Files | Examples |
|---|---|---|
| `monsters/` | `.glb` / `.gltf` | `golem.glb`, `gargoyle.glb`, `warrior.glb`, `disciple.glb` |
| `weapons/` | `.glb` / `.gltf` | `wand.glb`, `crossbow.glb`, `claw.glb`, `hellstaff.glb`, `phoenix.glb`, `mace.glb`, `staff.glb`, `gauntlets.glb` |
| `items/` | `.glb` / `.gltf` | `vial.glb`, `tome.glb`, `wings.glb`, `key_green.glb`, `shield_silver.glb` |
| `decor/` | `.glb` / `.gltf` | `brazier.glb`, `serpent_torch.glb`, `wall_torch.glb`, `chandelier.glb` |
| `textures/` | `.png` / `.jpg` / `.webp` | `BRICK.png` + optional `BRICK_normal.png`, `BRICK_roughness.png`; for your WAD, use the original names (e.g. `GRSTNPB.png`); `SKYKEEP.png` or `SKY1.png` for skies (2:1 panorama) |

**Fallbacks:**
- Variants fall back to their base model: `fire_gargoyle` uses `gargoyle.glb`,
  and `nitrogolem` uses `golem.glb` if it has no file of its own.
- Ghost variants are drawn translucent automatically.

**Animation clips** are matched by keyword:
- *idle*, *walk/run/fly*, *attack/punch/cast/throw*, *hit/pain/react* and
  *death/dying* for monsters.
- *fire* for weapons.

So Mixamo's clip names work as they are.
