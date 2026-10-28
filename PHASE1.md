# Orbitbreak — Phase 1

Open `black-hole-rogue/project.godot` in Godot 4.6 or newer and press **F6** with `Scenes/game.tscn` open, or **F5** to run the project.

From this checkout:

```sh
godot --path black-hole-rogue
```

Controls: **A/D** move, **Space** jump (hold for height), **Shift** sprint, **J** dash. Falling into the gap resets the player. There are three raised platforms and a 144-pixel gap on a 16-pixel TileMapLayer grid. The 22×60 collision capsule is independent of the visual scale.

## Artwork and animation status

`Assets/VoidConstruct/void_construct.png` is newly generated original transparent artwork. No old character sprites are referenced by the new scene. The roughly 72-pixel visible character uses nearest-neighbor filtering.

The character now uses a **15-part articulated cutout rig** textured directly from the generated master: head, chest, hips, two upper arms, forearms, hands, thighs, shins, and feet. Run and sprint alternate arms and legs with knee bends and grounded foot contact. Sprint adds forward lean and fragment lag. Jump, fall, and dash have distinct full-body poses. Idle breathes through the chest while the head and surrounding fragments float independently. A highlight moves around the black-hole ring. Dash ghosts snapshot the full articulated pose, including facing, and fade out.

State motion is sampled at 8/12/14/8/8/14 FPS with smooth transition blending; repeated state assignments do not restart playback. Mirroring happens inside the visual hierarchy, leaving player collision unchanged. This is runtime cutout animation from consistent original artwork, not newly drawn frame-by-frame sprite sheets.

## Validation

```sh
godot --headless --path black-hole-rogue --editor --import
godot --headless --path black-hole-rogue --quit-after 120
godot --headless --path black-hole-rogue --script res://Tests/movement_smoke.gd
godot --headless --path black-hole-rogue --script res://Tests/animation_smoke.gd
```

The smoke test exercises grounded spawn, TileMapLayer collision, run/sprint speeds, deceleration, variable jump height, gap crossing and landing, dash speed, held-key behavior, facing, coyote time, jump buffering, and fall recovery. The animation suite also checks limb opposition, pose differences, idle root stability, grounded foot alignment, facing, and afterimage cleanup. Animation poses and the game view were additionally rendered and visually inspected through a local dummy display using Mesa software rendering. Subjective controller feel still benefits from hands-on playtesting.

Before replacement, the entire original project was archived at `/workspace/orbithole-backups/pre-phase1.tar.gz`. Existing sprite files remain in the checkout, unused. No combat or later-phase systems were added.

## Changed files

Modified:
- `black-hole-rogue/project.godot`
- `black-hole-rogue/Scenes/game.tscn`
- `black-hole-rogue/Scenes/player.tscn`
- `black-hole-rogue/Scripts/player.gd`

Added:
- `.gitignore`
- `PHASE1.md`
- `black-hole-rogue/Assets/VoidConstruct/void_construct.png`
- `black-hole-rogue/Assets/VoidConstruct/void_construct.png.import`
- `black-hole-rogue/Scripts/test_level.gd`
- `black-hole-rogue/Scripts/test_level.gd.uid`
- `black-hole-rogue/Scripts/void_visual.gd`
- `black-hole-rogue/Scripts/void_visual.gd.uid`
- `black-hole-rogue/Tests/movement_smoke.gd`
- `black-hole-rogue/Tests/movement_smoke.gd.uid`
- `black-hole-rogue/Tests/animation_smoke.gd`
- `black-hole-rogue/Tests/animation_smoke.gd.uid`

Godot's ignored `.godot/` directory contains generated import/cache files.

The pre-animation implementation was also backed up at `/workspace/orbithole-backups/pre-animation-rig.tar.gz`.
