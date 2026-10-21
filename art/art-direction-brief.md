# Art direction brief: Heretic Reforged

The visual target is the **HD Character & Monster Design Template** (the design
map): a dark gothic fantasy reimagining of Heretic, rendered realistically.
Every character must match its panel on the map
([`design-map.png`](design-map.png)): the front, side and back views, the
costume, colors and weapon. Per-view references are in
[`references/`](references/) (see [`design-map-crops.png`](design-map-crops.png)).

## Game frame

- **Player fantasy:** Corvus, a red-hooded hero mage with a blue-orb staff, fighting
  the Serpent Riders' cult and monsters through a ruined gothic citadel under a
  blood-red eclipse.
- **Core verbs:** move fast, strafe, cast and shoot, pick up artifacts, open doors, fly.
- **Engine and renderer:** Godot 4.4. Desktop: Forward+ (shadows, SSAO, volumetric fog, SDFGI).
  Web: Compatibility (WebGL 2).
- **Target platforms:** web browser, Windows, macOS.
- **Camera:** first person, 85° vertical field of view, eye at 1.28 m. The design map's
  8-direction sprite rows aren't needed. The game renders 3D models, so every angle comes
  for free, but those rows define the clip set: idle, walk, attack, pain, death.

## Roster (design map → game)

| Design map | Role | Height (m) | Heretic slot it replaces |
|---|---|---|---|
| Disciple | melee enemy | 1.85 | golem (68), ghost (69) |
| Gryphon | basic enemy, flying | 1.6 | gargoyle (66), fire gargoyle (5) |
| Hell Knight | mid-tier enemy | 2.3 | undead warrior (64), ghost (65) |
| Ophidian | ranged enemy | 2.2 | ophidian (92) |
| Wraithverge | flying enemy | 2.6 | disciple of D'Sparil (15) |
| Golem | heavy enemy | 2.4 | nitrogolem (45), ghost (46) |
| Sabreclaw | fast enemy | 1.8 | sabreclaw (90) |
| Maulotaur | heavy enemy | 3.0 | maulotaur (9) |
| Iron Liche | ranged enemy | 2.5 | iron lich (6) |
| D'Sparil | final boss | 3.4 | D'Sparil (7) |
| Corvus | player | 1.85 | the player (not visible in first person yet) |

- **Heights:** they follow the map's ENVIRONMENT SCALE lineup.
- **Weredragon (70):** not on the map. It keeps a placeholder until it gets a design.

## Visual system

- **Shape language:** gothic, heavy and ornate. Hoods, horns, crowns, spikes, claws,
  flared robes. Armor is chunky and battle-worn; creatures are muscular and anatomical.
- **Silhouette priorities** (must survive at 15 m):
  - Disciple: hood and flail.
  - Gryphon: wings and eagle head.
  - Hell Knight: horns, shield and axe.
  - Ophidian: cobra hood and coiled tail.
  - Wraithverge: shroud and claws.
  - Golem: stone bulk.
  - Sabreclaw: low crouch.
  - Maulotaur: horns and giant axe.
  - Iron Liche: horned cowl and orb staff.
  - D'Sparil: crown and robe flare.
- **Value structure:** dark bodies against dark stone, separated by rim-colored magic and
  saturated cloth. Read every asset in grayscale before accepting it.
- **Palette roles:**
  - Cult and Corvus red cloth: #8e1a14.
  - Gold embroidery and trim: #c8a24a.
  - Dark iron: #2e2b2a.
  - Stone: #4a4642.
  - Corvus magic, blue lightning: #4f8cff.
  - Ophidian and Wraithverge magic, green: #49e07a.
  - Iron Liche and D'Sparil magic, purple: #8a3cff.
  - Lava: #ff6a12.
  - Gryphon feathers: #8a5a2a.
- **Materials** (the map's MATERIAL / TEXTURE DETAILS row):
  - **Cloth:** embroidered, heavy and frayed.
  - **Armor:** dark plate with gold inlay and dents.
  - **Leather:** straps and bracers.
  - **Skin:** realistic, with pores and veins.
  - **Stone:** cracked, chipped.
  - **Magic FX:** emissive energy; it is light, not texture.
- **Lighting:** the game supplies torches, moonlight and magic light, so models and
  textures must not have baked shadows or highlights. Concept images for the 3D step need
  flat, even light on a gray background, even though the map's panels are dramatically lit.
- **Detail density:** concentrate detail on faces, hands, weapons and gold trim. Keep
  large cloth and stone areas calm.
- **Motion:** Disciple and Hell Knight are weighty; Gryphon and Wraithverge keep up
  constant hovering motion; Sabreclaw is explosive; Golem and Maulotaur wind up slowly and
  hit hard.
- **Exclusions:**
  - Cartoon proportions.
  - The 1994 sprite look.
  - Sci-fi.
  - Text and logos.
  - A living artist's name as a style.

## Technical contract

- **Models:**
  - `.glb`, +Y up, facing +Z (Blender's front view), origin at the feet, centered.
    `art/tools/blender_prepare.py` enforces this.
  - It's compatible with the HereticCharacterStarter contract: clips `idle`, `move`,
    `attack`, `hit`, `death`, in place.
- **Triangle budgets:**
  | Asset | Triangles |
  |---|---|
  | Characters | 15k (web) / 40k (desktop) |
  | Bosses | 60k |
  | Weapons | 8k |
  | Items | 3k |
  | Props | 5k |
- **Model textures:** 2k for enemies; base color, normal and ORM packed per the starter's
  `MATERIALS.md`.
- **Level textures:**
  - **Files:** PNG; sRGB albedo, plus optional `<NAME>_normal.png` (OpenGL convention,
    green up) and `<NAME>_roughness.png`.
  - **Resolution and tiling:** 8× the original size, tileable.
- **Naming:** files are named after the asset id in `asset-manifest.json`:
  `monsters/hell_knight.glb`, `weapons/wand.glb`. The full list of folders is in
  `assets/README.md`.

## Visual target

- **Approval gate:** the **Disciple** is the hero asset. It's the most common enemy, a
  humanoid (the easiest Mixamo path) and has a clear silhouette. Approve one finished
  Disciple in-game before producing the rest.
- **Checks for the Disciple:**
  - It reads as its design map panel from 15 m in the great hall.
  - The flail and hood survive the walk cycle.
  - The red cloth doesn't turn to mud under torchlight.
  - It sits right next to the HUD at native resolution.
- **Do:**
  - Use `references/<id>/front.png` as the image-to-image init.
  - Check the 3D model against the panel's side and back views.
  - Keep the gold trim and colors exactly as on the map.
- **Don't:**
  - Add costume pieces that aren't on the map.
  - Shift a character's color identity.
  - Bake the map's dramatic lighting into textures.
