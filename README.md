# Heretic Reforged

A fan remake of Raven Software's **Heretic** (1994), built in Godot 4. It plays
in a web browser, on Windows and on macOS.

- **Built-in level:** *The Sunken Keep* is an original level with procedurally
  generated textures. It needs no game files and is safe to share.
- **Your own HERETIC.WAD:** load the full game (or the shareware HERETIC1.WAD)
  from the title screen. The maps are rebuilt in 3D with modern lighting. Your
  WAD stays on your device and is never uploaded.
- **Gameplay:** all eight weapons with Tome of Power modes, artifacts and Wings
  of Wrath flight, doors, lifts, switches, teleports, stairs, keys, secrets and
  exits.
- **Looks:** dynamic torch and moon lighting with shadows. Desktop adds
  volumetric fog, SSAO and global illumination.
- **Placeholder art:** monsters and weapons are simple primitives for now. The
  [art pipeline](art/PIPELINE.md) replaces them with realistic remakes of the
  originals; dropping files into [`assets/`](assets/README.md) is all it takes.

## Play

| Action | Keys |
|---|---|
| Move | WASD (Shift to walk) |
| Look | mouse |
| Fire | left click |
| Open / use | E |
| Jump / fly up | Space |
| Fly down | C |
| Weapons | 1–7 or mouse wheel |
| Choose artifact | `[` `]` or Q / Tab |
| Use artifact | R or right click |
| Pause | Esc |

Web builds can start straight into the level with
`index.html?autostart`, and `&warp=x,y,angle` (map units) places the
player somewhere specific.

## Run and build

You need [Godot 4.4.1](https://godotengine.org/download/archive/4.4.1-stable/)
(the standard build, not .NET) and its export templates.

```bash
godot --path .                                      # play
godot --headless --path . --export-release "Web" build/web/index.html
godot --headless --path . --export-release "Windows" build/windows/HereticReforged.exe
godot --headless --path . --export-release "macOS" build/macos/HereticReforged.zip
```

| Build | Notes |
|---|---|
| **Web** | Runs on any static host. It doesn't need special COOP/COEP headers (threads are off). |
| **Windows** | A single `.exe` with the game embedded. |
| **macOS** | A universal `.app`, ad-hoc signed. The first time, right-click → Open (or run `xattr -cr "Heretic Reforged.app"`), because it isn't notarized. |

**GitHub Actions** (`.github/workflows/heretic-reforged.yml`):
- **On each push:** runs the tests and attaches
  the three builds to the run as downloadable artifacts.
- **Web deployment:** on the `main` branch, the web build is also deployed to
  GitHub Pages, once Pages is enabled with source "GitHub Actions". On a private
  repository that needs a paid GitHub plan; alternatively upload the web build
  zip to itch.io as an HTML game.

## Tests

```bash
godot --headless --path . res://tests/smoke_test.tscn           # level, doors, lift, weapons, AI, exit
godot --headless --path . -s res://tests/triangulation_test.gd  # built-in level geometry
godot --headless --path . -s res://tests/wad_map_test.gd -- --wad=freedoom1.wad
godot --headless --path . res://tests/asset_override_test.tscn -- --mods=<dir with monsters/golem.glb>
```

`wad_map_test` works with any Doom-format WAD. CI uses
[Freedoom](https://freedoom.github.io) (BSD license).

## How it's organized

| Path | What |
|---|---|
| `scripts/wad/` | WAD reader, map loader, texture compositing, procedural textures |
| `scripts/world/` | sector triangulation, level geometry, doors and lifts, line specials, thing spawning, lighting |
| `scripts/actors/` | player, weapons, monsters and their AI, projectiles, pickups, effects, data tables |
| `scripts/core/` | settings and input, synthesized sound, replacement-art loader |
| `scripts/ui/` | HUD and menus |
| `tools/` | `extract_references.gd`: dumps your WAD's art as PNG references |
| `art/` | art brief, asset manifest with prompts, pipeline guide, Blender prep script |

Sound effects are synthesized at runtime, and nothing from the original game is
included in this repository.
