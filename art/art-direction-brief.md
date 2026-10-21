# Art direction brief: Heretic Reforged

The goal is the original 1994 designs, rebuilt as realistic, high-fidelity
art. Every asset must still read as the original at a glance: same
silhouette, same color identity, same signature details. Only the rendering
fidelity changes.

## Game frame

- **Player fantasy:** Corvus, an elven heretic with a wand and a spellbook, cutting through
  the Serpent Riders' undead and demon armies in a ruined gothic world.
- **Core verbs:** move fast, strafe, shoot, pick up artifacts, open doors, fly (Wings of Wrath).
- **Engine and renderer:** Godot 4.4. Desktop: Forward+ (shadows, SSAO, volumetric fog, SDFGI).
  Web: Compatibility (WebGL 2).
- **Target platforms:** web browser, Windows, macOS.
- **Camera:** first person, 85° vertical field of view, eye at 1.28 m.
- **Typical on-screen size:** a 2 m monster at 10 m fills about 1/5 of the screen height.
  Detail finer than a fist won't read during play.

## Visual system

- **Shape language:** gothic and heavy. Pointed arches, horns, claws and ribbed armor.
  Organic monsters stay asymmetric and gnarled; worked metal stays ornate but chunky.
- **Silhouette priorities:**
  - Gargoyles: wings and horns.
  - Golems: hunched bulk and long arms.
  - Undead Warrior: the axe and the helm.
  - Disciple: hood, robe flare and floating hands.
  - Iron Lich: a giant floating skull.
  - Maulotaur: bull horns and the hammer.
  - Never let wings, weapons or horns merge into the body mass in the reference image.
- **Value structure:** mid-dark bodies, with bright accents only on magic: eyes, gems,
  ethereal weapons. Each asset must read in grayscale against dark stone.
- **Palette roles** (from the original):
  - Stone and earth: cold grays and umber (#3a3632, #5b5148, #7a6e60).
  - Gold and bronze ornament: #b8892f, #d9b25c.
  - Gargoyle red and blood: #7a1f14, #a8321e.
  - Ethereal magic: green #4cff7a, crossbow and Undead Warrior axes.
  - Wand and phoenix fire: yellow #ffd75a, orange #ff8a1f.
  - Dragon Claw and Iron Lich ice: blue #5a8cff.
  - Disciple purple: #7a3cc8.
  - Lava: #ff5a0a to #ffd24a.
- **Materials:** weathered stone with chipped edges; aged bronze and gold with grime in
  recesses; bandage cloth; leathery wing membranes; scaled hide; dented plate armor;
  translucent glowing magic.
- **Edges:** physically based. Worn bevels on everything. No outlines, no cel shading.
- **Lighting:** the game lights everything (torches, moonlight, magic), so textures and
  models must not have baked-in shadows or highlights. Concept images should use flat,
  even studio light so the 3D tools don't bake lighting into the color.
- **Detail density:** concentrate detail on heads, hands, weapons and gems. Keep large
  planes calm so they read at distance.
- **Motion:**
  - Golems and the Maulotaur: heavy, with a slow wind-up and fast impact.
  - Gargoyles and the Disciple: hovering, constant small motion.
  - Undead Warrior: stiff and deliberate.
- **Exclusions:**
  - Cartoon proportions, chibi, anime styling.
  - Sci-fi tech.
  - Text and logos.
  - A living artist's name as a style.
  - Gore beyond the original's level.

## Technical contract

- **Models:** `.glb`, +Y up, facing +Z (Blender's front view). Origin at the feet, centered.
  `art/tools/blender_prepare.py` enforces all of this.
- **Heights (m):**
  | Monster | Height |
  |---|---|
  | Gargoyle | 1.1 |
  | Golem | 2.0 |
  | Undead Warrior | 2.2 |
  | Sabreclaw | 1.8 |
  | Weredragon | 2.2 |
  | Ophidian | 2.2 |
  | Disciple | 2.0 |
  | Iron Lich | 2.2 |
  | Maulotaur | 3.2 |
  | D'Sparil | 3.0 |
- **Weapon lengths (m):**
  | Weapon | Length |
  |---|---|
  | Staff | 0.9 |
  | Gauntlets | 0.4 |
  | Wand | 0.48 |
  | Crossbow | 0.6 |
  | Claw | 0.45 |
  | Hellstaff | 0.75 |
  | Phoenix Rod | 0.62 |
  | Firemace | 0.56 |
- **Triangle budgets:**
  | Asset | Triangles |
  |---|---|
  | Monsters | 15k (web) / 40k (desktop) |
  | Bosses | 60k |
  | Weapons | 8k |
  | Items | 3k |
  | Props | 5k |
- **Animation clips** (names matched by keyword, so Mixamo names work):
  - `idle`, `walk`, `attack`, `pain`, `death` for monsters
  - `idle`, `fire` for weapons
- **Textures:**
  - **Files:** PNG, sRGB albedo, plus optional `<NAME>_normal.png` (OpenGL convention,
    green up) and `<NAME>_roughness.png` (linear, white = rough).
  - **Resolution:** 8× the original in each direction. A 64×128 WAD texture becomes
    512×1024; a 64×64 flat becomes 512×512. The game keeps the original size in map units,
    so alignment stays exactly right.
  - **Tiling:** walls tile horizontally (and vertically where the original did); flats tile
    in both directions.
- **Naming:** files are named after the thing they replace: `monsters/golem.glb`,
  `weapons/crossbow.glb`, `textures/BRICK.png`. Folders are listed in `assets/README.md`.

## Visual target

- **Approval gate:** the golem is the hero asset. It's the most common monster, a humanoid
  (the easiest auto-rigging path) and has a clear silhouette. Approve one finished golem
  in-game before producing the rest.
- **Checks for the golem:**
  - It reads as the original from 15 m in the hall.
  - The bandage texture doesn't swim when it walks.
  - It looks right under torchlight and in shadow.
- **Do:**
  - Keep the original's proportions and colors.
  - Keep the reference sprite's pose for image-to-image.
  - Use a neutral gray background.
- **Don't:**
  - Add new costume pieces.
  - Change color identity (a golem is never green).
  - Use dramatic lighting in concept images.
  - Use backgrounds that the 3D tools could mistake for geometry.
