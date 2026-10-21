# Free AI art pipeline

How to turn the **design map** (HD Character & Monster Design Template) into
realistic 3D characters for Heretic Reforged using free tools, and get them
into the game. What to make is
listed in [`asset-manifest.json`](asset-manifest.json); the visual rules are in
[`art-direction-brief.md`](art-direction-brief.md).

```
design map panels (characters)  +  your HERETIC.WAD (level textures, optional)
   │  1. crop references / extract textures (tools/extract_references.gd)
   ▼
front view per character, original textures
   │  2. clean concept art / HD textures (Draw Things or ComfyUI, image-to-image)
   ▼
concept image per asset
   │  3. image → 3D model          (TRELLIS / TripoSR)
   ▼
raw .glb
   │  4. rig + animate             (Mixamo) → clean up (art/tools/blender_prepare.py)
   ▼
game-ready .glb  ──►  assets/monsters/disciple.glb  ──►  in game
```

> **Rights.** The design map's characters are reimagined rather than copied
> from the 1994 sprites, which keeps you much safer when sharing builds. The
> names "Heretic", "D'Sparil", "Corvus" and so on are still id Software's
> (Microsoft's) trademarks, so consider your own title before a public or
> commercial release. Original WAD textures extracted in step 1 are
> copyrighted: keep them private. Check the license of every AI model you use
> (noted below).

Start with **one hero asset: the Disciple**. Take it all the way into the game
and judge it there before making the rest (see "Visual target" in the brief).

---

## 0. Install (one time, all free)

| Tool | For | Notes |
|---|---|---|
| [Godot 4.4.1](https://godotengine.org/download/archive/4.4.1-stable/) | running the game, the extractor | standard build, not .NET |
| [Blender 4.2 LTS or newer](https://www.blender.org/download/) | cleanup, export | |
| **Mac:** Draw Things (Mac App Store) | image generation, offline | easiest on Apple Silicon |
| **Windows/NVIDIA:** [ComfyUI](https://github.com/comfyanonymous/ComfyUI) | image generation, offline | more control; ControlNet, tiling |
| Image model: **FLUX.1 [schnell]** (Apache-2.0) or **SDXL** (OpenRAIL++) | concept art, textures | both allow commercial use; check current terms |
| Image → 3D: **TRELLIS** (MIT) or **TripoSR** (MIT) | 3D models | run locally (NVIDIA, 16 GB+ for TRELLIS) or via a free Hugging Face Space |
| [Mixamo](https://www.mixamo.com) (free Adobe account) | auto-rig + animations | humanoids only |

Hunyuan3D-2 gives great results, but its community license excludes some
regions (including the EU and UK) and limits large commercial use. Read it
before relying on it.

## 1. References

**Characters:** crop each character's panel from the design map into three
images: `front`, `side`, `back` (Preview on a Mac: select → Crop). The front
view feeds image-to-image; the side and back views are for checking the 3D
model. Save the full map as `art/design-map.png` in the repository.

**Level textures (optional, only for playing your own WAD in HD):** extract the
originals. From the repository folder:

```bash
# macOS: GODOT=/Applications/Godot.app/Contents/MacOS/Godot
"$GODOT" --headless --path heretic-remake -s res://tools/extract_references.gd -- \
    --wad="$HOME/Games/HERETIC.WAD" --out="$HOME/heretic-references"
```

You get:
- `sprites/<PREFIX>/*.png`: every frame, 4× upscaled.
- `sprites/<PREFIX>_sheet.png`: contact sheets, one per monster or item.
- `textures/` and `flats/`: every wall and floor at original size.
- `INDEX.md`: which prefix is which monster.

Keep these files private: they are the original copyrighted art.

## 2. Concept art and HD textures

Build each prompt from the manifest entry's `prompt` blocks (ROLE, SUBJECT,
VIEW, ART DIRECTION, ...). Put the shared blocks first, unchanged, every time.
That keeps the whole family consistent.

**Characters and props (image-to-image):**
1. Use the character's **front view** crop from the design map as the init image.
2. Set **strength/denoise to 0.45–0.6**. The goal isn't a new design: it's the
   same design in flat, even light on a gray background, with full limbs
   visible. Lower keeps more of the map; higher cleans up more.
3. Prompt with the manifest's SUBJECT + ART DIRECTION. Add the negative prompt
   from `shared_prompt_blocks.exclude`.
4. Aim for a full body, A-pose, plain gray background and flat light. The 3D
   step needs a clean silhouette with no shadows baked in.
5. Generate 4–8 options and pick the one that best matches the map panel at
   thumbnail size, not the prettiest close up.

**Textures:**
1. Init image: the original texture upscaled 8× (nearest), denoise **0.35–0.5**,
   with **tiling/seamless** turned on (Draw Things: "Tiled"; ComfyUI: a
   seamless-tiling node).
2. Output size: 8× the original (a 64×128 texture becomes 512×1024).
3. Check the seams by tiling it 3×3 with the asset skill's script:
   ```bash
   python .claude/skills/create-game-assets/scripts/build_preview_sheet.py \
       BRICK.png BRICK.png BRICK.png BRICK.png BRICK.png BRICK.png BRICK.png BRICK.png BRICK.png \
       --out brick-3x3.png --columns 3 --cell-size 512
   ```
4. Normal and roughness maps are optional. Without them the game derives
   bumps from brightness. To make them, use the free
   [NormalMap-Online](https://cpetry.github.io/NormalMap-Online/) (runs in your
   browser) and save as `<NAME>_normal.png` and `<NAME>_roughness.png`.

## 3. Image → 3D model

1. Upload the chosen concept image to TRELLIS (or TripoSR) and generate.
2. Download the **textured GLB**.
3. Open it in Blender and check it:
   - Is the silhouette right?
   - Are the hands separate from the body?
   - Is anything missing? (AI meshes often fuse fingers or lose the back of
     the model.)
4. Fix obvious holes. Regenerate from a better concept image rather than
   sculpting for hours.

Non-humanoids (Gryphon, Sabreclaw, Ophidian, maybe the Wraithverge) can skip
Mixamo. Either:
- give them a simple bone chain in Blender, or
- ship them without animation. The game still bobs and hovers them, and
  plays any clips the file has.

## 4. Rig, animate and prepare

**Humanoids** (Disciple, Hell Knight, Golem, Iron Liche, Maulotaur, D'Sparil,
Corvus):

1. In Blender, export the model as FBX (File → Export → FBX).
2. Upload it to Mixamo and place the auto-rigger markers.
3. Download the character **With Skin** (T-pose).
4. Download each animation as **FBX Binary, Without Skin, 30 fps**. Suggested
   Mixamo searches:

   | Clip | Disciple | Hell Knight | Golem | Iron Liche / D'Sparil |
   |---|---|---|---|---|
   | idle | "Idle" | "Sword And Shield Idle" | "Mutant Idle" | "Standing Idle" |
   | walk | "Walking" | "Sword And Shield Walk" | "Mutant Walking" | "Walking" |
   | attack | "Standing Melee Attack Horizontal" | "Sword And Shield Slash" | "Mutant Punch" | "Standing 2H Magic Attack" |
   | pain | "Hit Reaction" | "Sword And Shield Impact" | "Mutant Hit Reaction" | "Hit Reaction" |
   | death | "Dying" | "Sword And Shield Death" | "Mutant Dying" | "Dying" |

5. Run the prepare script. It scales, grounds, decimates and merges the clips:

   ```bash
   blender -b --python heretic-remake/art/tools/blender_prepare.py -- \
       --in disciple_skin.fbx --height 1.85 --max-tris 25000 \
       --anim idle=Idle.fbx --anim walk=Walking.fbx \
       --anim attack=Standing_Melee_Attack_Horizontal.fbx --anim pain=Hit_Reaction.fbx \
       --anim death=Dying.fbx \
       --out heretic-remake/assets/monsters/disciple.glb
   ```

   It prints the final height, triangle count and which clips it found. Use
   `--yaw 180` if the model ends up facing backwards in the game.

**Weapons, items and props:** just run the script without `--anim`. The game
fits them by length or height (see the manifest).

## 5. See it in the game

- **In the project:** files in `heretic-remake/assets/<kind>/` load automatically.
  Run the game from Godot, or with
  `"$GODOT" --path heretic-remake -- --autostart --warp=960,384,0`
  (that drops you in the great hall).
- **Without rebuilding:** put the same folders in `mods/` next to the
  exported game, or pass `--mods=/path/to/folder`.
- **Fine-tuning:** a `disciple.json` next to `disciple.glb` adjusts the fit:
  `{"height": 1.9, "yaw": 0, "anims": {"attack": "Standing_Melee_Attack_Horizontal"}}`.
- **Automated check:**
  `"$GODOT" --headless --path heretic-remake res://tests/asset_override_test.tscn -- --mods=<folder with monsters/golem.glb>`
  (the test reuses any model you give it as the golem)

Check the asset as the brief asks:
- at a distance in the hall,
- under torchlight and in shadow,
- while walking and attacking.

Then fill in its `source` and `verification` fields in the manifest: tool,
model, prompt, date and license.

## Using the HereticCharacterStarter project

Your starter project and this game share one model contract:
- glTF, 1 unit = 1 m, feet at the origin, facing -Z in Godot
- in-place clips named `idle`, `move`, `attack`, `hit`, `death`

The game maps `move` → walk and `hit` → pain automatically, so a character
finished in the starter works here unchanged. Copy its `.glb` to
`assets/monsters/<id>.glb`, using the ids from the manifest (`disciple`,
`gryphon`, `hell_knight`, `ophidian`, `wraithverge`, `golem`, `sabreclaw`,
`maulotaur`, `iron_liche`, `dsparil`, `corvus`). The starter's roster notes
follow the 1994 designs; where they disagree with the design map (for example
the Golem and the Iron Liche), the design map wins. The starter's
`rigged_blockout.glb` was tested this way as the golem. Follow its
`BLENDER_PIPELINE.md` and `MATERIALS.md` for production quality:
- retopology and LODs
- ORM-packed textures, 2k for common enemies
- clean, separate actions per clip

## 6. Rebuild and share

Push to the branch. GitHub Actions builds the web, Windows and macOS versions
(see the project README). Or export locally from Godot with the included export
presets.
