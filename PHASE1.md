# Orbitbreak — Phase 1

Open `black-hole-rogue/project.godot` in Godot 4.6 or newer and press **F6** with `Scenes/game.tscn` open, or **F5** to run the project.

From this checkout:

```sh
godot --path black-hole-rogue
```

Controls: **A/D** move, **Space** jump (hold for height), **Shift** sprint, **J** dash, **K / left click** melee (tap again to chain). Falling into the gap resets the player. There are three raised platforms and a 144-pixel gap on a 16-pixel TileMapLayer grid. The 22×60 collision capsule is independent of the visual scale.

## Artwork and animation status

`Assets/VoidConstruct/void_construct.png` is newly generated original transparent artwork. No old character sprites are referenced by the new scene. The roughly 72-pixel visible character uses nearest-neighbor filtering.

The character now uses a **15-part articulated cutout rig** textured directly from the generated master: head, chest, hips, two upper arms, forearms, hands, thighs, shins, and feet. Run and sprint alternate arms and legs with knee bends and grounded foot contact. Sprint adds forward lean and fragment lag. Jump, fall, and dash have distinct full-body poses. Idle breathes through the chest while the head and surrounding fragments float independently. A highlight moves around the black-hole ring. Dash ghosts snapshot the full articulated pose, including facing, and fade out.

Motion now uses continuous gait interpolation, delayed wrists/head, offset knee timing, acceleration drag, and landing compression to avoid rigid clockwork stepping; repeated state assignments do not restart playback. Mirroring happens inside the visual hierarchy, leaving player collision unchanged. This is runtime cutout animation from consistent original artwork, not newly drawn frame-by-frame sprite sheets.

## Validation

```sh
godot --headless --path black-hole-rogue --editor --import
godot --headless --path black-hole-rogue --quit-after 120
godot --headless --path black-hole-rogue --script res://Tests/movement_smoke.gd
godot --headless --path black-hole-rogue --script res://Tests/animation_smoke.gd
godot --headless --path black-hole-rogue --script res://Tests/combat_platform_smoke.gd
```

The smoke test exercises grounded spawn, TileMapLayer collision, run/sprint speeds, deceleration, variable jump height, gap crossing and landing, dash speed, held-key behavior, facing, coyote time, jump buffering, and fall recovery. The animation suite also checks limb opposition, pose differences, idle root stability, grounded foot alignment, facing, and afterimage cleanup. Animation poses and the game view were additionally rendered and visually inspected through a local dummy display using Mesa software rendering. Subjective controller feel still benefits from hands-on playtesting.

Before replacement, the entire original project was archived at `/workspace/orbithole-backups/pre-phase1.tar.gz`. Existing sprite files remain in the checkout, unused. Basic melee was added in the follow-up polish pass described below. No enemies, weapons, inventory, or upgrade systems were added.

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
- `black-hole-rogue/Scripts/practice_core.gd`
- `black-hole-rogue/Scripts/practice_core.gd.uid`
- `black-hole-rogue/Scripts/void_visual.gd`
- `black-hole-rogue/Scripts/void_visual.gd.uid`
- `black-hole-rogue/Tests/movement_smoke.gd`
- `black-hole-rogue/Tests/movement_smoke.gd.uid`
- `black-hole-rogue/Tests/animation_smoke.gd`
- `black-hole-rogue/Tests/animation_smoke.gd.uid`
- `black-hole-rogue/Tests/combat_platform_smoke.gd`
- `black-hole-rogue/Tests/combat_platform_smoke.gd.uid`

Godot's ignored `.godot/` directory contains generated import/cache files.

The pre-animation implementation was also backed up at `/workspace/orbithole-backups/pre-animation-rig.tar.gz`.

## Movement and gravity-melee polish

The player now renders on foreground depth 20. Negative depths inside the rig therefore stay ahead of the skyline, and dash ghosts use foreground depth 15. This fixes buildings hiding the back arm and legs.

Jump takeoff is now -580 px/s (previously -420), with slightly reduced gravity near the apex and variable height on release. The old jump reached about 74 pixels, below the 96-pixel first slab. All three elevated slabs are now reachable; the test suite actually jumps onto and lands on each. A ledge-climb mechanic is not needed for these jumps.

Tap **K or left mouse** to start **inward-pull punch → reverse punch → gravity kick**. Tap again after the windup begins to buffer the next stage. Each move compresses its stone fragments toward the head, snaps the striking limb outward, follows through, and recalls the pieces. Inward spirals, ring pulses, asymmetrical poses, and delayed hands/head emphasize a singularity learning to use a humanoid body. Holding attack does not repeat the combo.

The attack uses actual directional collision queries with windup/active/recovery windows, one hit per target per stage, and knockback. During windup, the practice core is physically attracted toward the player. The core then reacts to punches/kicks and reports hits; it is an anchored training prop, not an enemy. Jump or dash cancels an attack. Airborne attacks do not suspend gravity and cannot restart repeatedly before landing.

The combat/platform test covers the layering regression, all three slab landings, attraction, all combo hit windows, left-facing hits, buffering, no held-key repetition, cancellation, and airborne limits. The original movement and animation tests also pass. Combat pose galleries and a player standing directly in front of a building were rendered for visual inspection; hands-on playtesting remains useful for tuning feel.

A pre-polish backup is retained at `/workspace/orbithole-backups/pre-combat-polish.tar.gz`.
