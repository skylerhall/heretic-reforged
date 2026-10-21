# Free AI art pipeline

How to turn the original Heretic designs into realistic, high-fidelity art for
Heretic Reforged using free tools, and get it into the game. What to make is
listed in [`asset-manifest.json`](asset-manifest.json); the visual rules are in
[`art-direction-brief.md`](art-direction-brief.md).

```
your HERETIC.WAD
   │  1. extract references        (tools/extract_references.gd)
   ▼
reference sprites + textures
   │  2. concept art / HD textures (Draw Things or ComfyUI, image-to-image)
   ▼
concept image per asset
   │  3. image → 3D model          (TRELLIS / TripoSR)
   ▼
raw .glb
   │  4. rig + animate             (Mixamo) → clean up (art/tools/blender_prepare.py)
   ▼
game-ready .glb  ──►  assets/monsters/golem.glb  ──►  in game
```

> **Rights.** The original designs belong to id Software (Microsoft). Recreations
> of them are fine for your own copy of the game. Before publishing a build
> with them (web page, store), get advice. The game's built-in level and
> placeholders are original and safe to share. Also check the license of every
> AI model you use (noted below).

Start with **one hero asset: the golem**. Take it all the way into the game and
judge it there before making the rest (see "Approve the target" in the brief).

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

## 1. Extract references from your WAD

From the repository folder:

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

The manifest names the prefix for each asset (the golem is `MUMM`). Keep these
files private: they are the original copyrighted art.

## 2. Concept art and HD textures

Build each prompt from the manifest entry's `prompt` blocks (ROLE, SUBJECT,
VIEW, ART DIRECTION, ...). Put the shared blocks first, unchanged, every time.
That keeps the whole family consistent.

**Characters and props (image-to-image):**
1. Pick the clearest **front view** frame from the reference sprite folder (for
   the golem, `MUMMA1.png`).
2. Use it as the init image, at **strength/denoise 0.55–0.7**. Lower keeps more
   of the original; higher adds more detail.
3. Prompt with the manifest's SUBJECT + ART DIRECTION. Add the negative prompt
   from `shared_prompt_blocks.exclude`.
4. Aim for a full body, A-pose, plain gray background and flat light. The 3D
   step needs a clean silhouette with no shadows baked in.
5. Generate 4–8 options and pick the one that reads most like the original at
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

Non-humanoids (gargoyle, Ophidian, Iron Lich) can skip Mixamo. Either:
- give them a simple bone chain in Blender, or
- ship them without animation. The game still bobs and hovers them, and
  plays any clips the file has.

## 4. Rig, animate and prepare

**Humanoids** (golem, Undead Warrior, Disciple, Weredragon, Sabreclaw,
Maulotaur, D'Sparil):

1. In Blender, export the model as FBX (File → Export → FBX).
2. Upload it to Mixamo and place the auto-rigger markers.
3. Download the character **With Skin** (T-pose).
4. Download each animation as **FBX Binary, Without Skin, 30 fps**. Suggested
   Mixamo searches:

   | Clip | Golem | Undead Warrior | Disciple |
   |---|---|---|---|
   | idle | "Zombie Idle" | "Sword And Shield Idle" | "Floating" |
   | walk | "Zombie Walk" | "Walking" | "Floating" |
   | attack | "Zombie Punching" | "Throw" | "Magic Spell Casting" |
   | pain | "Hit Reaction" | "Hit Reaction" | "Hit Reaction" |
   | death | "Zombie Dying" | "Dying" | "Dying" |

5. Run the prepare script. It scales, grounds, decimates and merges the clips:

   ```bash
   blender -b --python heretic-remake/art/tools/blender_prepare.py -- \
       --in golem_skin.fbx --height 2.0 --max-tris 25000 \
       --anim idle=Zombie_Idle.fbx --anim walk=Zombie_Walk.fbx \
       --anim attack=Zombie_Punching.fbx --anim pain=Hit_Reaction.fbx \
       --anim death=Zombie_Dying.fbx \
       --out heretic-remake/assets/monsters/golem.glb
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
- **Fine-tuning:** a `golem.json` next to `golem.glb` adjusts the fit:
  `{"height": 2.1, "yaw": 0, "anims": {"attack": "Zombie_Punching"}}`.
- **Automated check:**
  `"$GODOT" --headless --path heretic-remake res://tests/asset_override_test.tscn -- --mods=<folder with monsters/golem.glb>`

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
`assets/monsters/<id>.glb`, using the ids from the manifest. The starter's
`rigged_blockout.glb` was tested this way as the golem. Follow its
`BLENDER_PIPELINE.md` and `MATERIALS.md` for production quality:
- retopology and LODs
- ORM-packed textures, 2k for common enemies
- clean, separate actions per clip

## 6. Rebuild and share

Push to the branch. GitHub Actions builds the web, Windows and macOS versions
(see the project README). Or export locally from Godot with the included export
presets.
