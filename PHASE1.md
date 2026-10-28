# Orbitbreak — complete-frame Void Construct

Open `black-hole-rogue/project.godot` in Godot 4.6 or newer and press **F5** (or **fn + F5** on Mac). Allow the first asset import to finish. The project runs `Scenes/game.tscn`.

## Play

- **A / D** move; **Shift** sprint.
- **Space** jumps; hold for more height. All three raised slabs are reachable.
- **J** dashes.
- **K / left click** attacks. Tap during a basic attack to queue the next move: **Gravity Jab → Repulsion Sweep → Singularity Headbutt**.
- Attack while sprinting for **Sprint Attack**, during a dash for **Dash Attack**, or in the air for **Airborne Smash**.

The nearby **Void Dummy** has health, damage numbers, hit flash, stagger and knockback. It has no AI and reforms after depletion. Falling into the gap respawns the player.

## The visual rig was replaced

The main character is now rendered by **one AnimatedSprite2D** using `Animations/void_frames.tres`. Every texture is a complete character drawing: head/ring, torso, both arms/hands, both legs/feet and restrained debris. There are no independently animated body pieces, bones, limb pivots, procedural limb rotations, body stretching, or runtime AnimationPlayer tracks.

The complete-frame artwork was generated from the approved master. Run and sprint use separately drawn poses, including opposite-arm corrections. The jab was regenerated to make its punching shoulder, upper arm and elbow visible instead of appearing to emerge from the chest. Character motion comes from switching drawings; the sprite's transform stays fixed. Facing uses `flip_h` only.

| Animation | Drawings | Rate |
|---|---:|---:|
| Idle | 8 | 8 FPS |
| Run | 8 | 12 FPS |
| Sprint | 8 | 14 FPS |
| Jump | 4 | 10 FPS |
| Fall | 4 | 8 FPS |
| Dash | 6 | 14 FPS |
| Gravity Jab | 6 | combat clock |
| Repulsion Sweep | 6 | combat clock |
| Singularity Headbutt | 6 | combat clock |
| Sprint Attack | 6 | combat clock |
| Dash Attack | 6 | combat clock |
| Airborne Smash | 6 | combat clock |

There are **74 complete-character PNG frames** on a shared transparent **160×112** canvas, with a foot baseline at **104**. Standing character art is about 80 pixels tall. The wider transparent canvas accommodates a punch or dash silhouette without shrinking the character. Every frame uses nearest filtering. The sprite sits at `(0,-48)` so the baseline aligns with the controller's feet.

`Assets/VoidConstruct/FrameSources` retains the approved master, selected generated source drawings/sheets and portable import manifest. `Tools/build_full_frames.gd` performs ordinary whole-image cropping, uniform nearest-neighbor import scaling and canvas/baseline placement. It does not extract limbs, invent poses, deform the body, or assemble parts. Explicit atlas regions preserve complete drawings when the generated sheet's gutters are uneven. Generated source art and its normalized game frames are both retained for review; pixel-perfect art refinement can be done directly on the PNG frames without changing controller code.

Regenerate normalized frames from the retained sources:

```sh
godot --headless --path black-hole-rogue --script res://Tools/build_full_frames.gd
godot --headless --path black-hole-rogue --editor --import
```

## Stable gameplay and scene structure

`Scenes/player.tscn` contains `CollisionShape2D`, `AnimatedSprite2D`, `Camera2D`, `AttackHitbox`, `OrbitCoreContainer`, `GravityVFX` and `Combat`. The orbit-core container is empty; no new weapon system was added. Gravity effects and whole-frame dash afterimages are separate from the character body.

The original **22×60 collision capsule**, movement speeds, acceleration, sprint, coyote time, jump buffer, variable jump, dash, camera limits and platform collisions are preserved. The character remains on foreground depth 20 so buildings cannot hide the body. Jump/fall/dash animations hold their last drawing if complete; they do not restart every physics frame.

`Scripts/full_frame_visual.gd` handles animation selection and facing. `Scripts/gravity_combat.gd` owns buffered input, active windows and real Area2D hitboxes. Its clock selects the attack drawing, so hitstop pauses the complete impact frame and hitbox timing together. One press starts one attack; the one-slot buffer cannot skip steps or auto-repeat. Basic-combo inactivity resets after 0.7 seconds. Context attacks do not automatically chain into the basic combo.

Each move has its own editable resource under `Resources/FrameCombat` for damage, duration, active windows, reach, shape, knockback, pull, stagger and hitstop. Attack-window timing matches the six drawings' preparation/extension/impact/recovery sequence. Sprint and dash attacks retain more momentum than standing attacks. Airborne smash holds its plunge drawing while descending, then finishes the drawn landing recovery; a bounded hold and normal falling physics prevent hovering. Jump and dash cancel attacks safely.

Damage is limited to once per target per move. Wall checks block both damage and gravity pull through solid geometry. Headbutt and smash only add small camera feedback on confirmed hits. The dummy uses a physics-state reset and reforms automatically for repeat testing. No enemies with AI, weapons, inventory, upgrades, bosses or capture mechanics were added.

## Validation and art preview

```sh
godot --headless --path black-hole-rogue --editor --import
godot --headless --path black-hole-rogue --quit-after 120
godot --headless --path black-hole-rogue --script res://Tests/movement_smoke.gd
godot --headless --path black-hole-rogue --script res://Tests/combat_platform_smoke.gd
godot --headless --path black-hole-rogue --script res://Tests/animation_smoke.gd
godot --headless --path black-hole-rogue --script res://Tests/gravity_combat_smoke.gd
```

These check movement and jump reach, all three platform landings, foreground rendering, exact locomotion frame counts/rates, full transparent frame canvases, actual frame advancement, mirroring, nonlooping holds, stable sprite/collider transforms, three-stage order, contextual attacks, per-move hits, buffering, hitstop, wall blocking, cancellation and dummy reformation. Art readability is additionally checked in rendered contact sheets and the running game; numerical tests alone do not judge illustration quality.

With a display, capture a developer contact sheet using:

```sh
godot --path black-hole-rogue --script res://Tools/preview_full_frames.gd -- run /tmp/run-preview.png
```

## Backups and changed files

`Backups/pre_full_frames_visual.zip` is a verified archive of the previous visual scene, rig scripts, parts atlas, animation tracks and associated combat resources from commit `2229a93`. Extract it into a separate review folder rather than overwriting the current project. The old full project is also recoverable from that Git commit; a local complete snapshot was saved at `/workspace/orbithole-backups/pre-frame-animation.tar.gz` before replacement.

The old `Scenes/void_visual.tscn`, `Scripts/void_visual.gd`, `Animations/gravity_melee.tres`, disassembled `body_parts.png`, old combat resources and rig-builder script were removed after the backup was verified.

The replacement adds `Animations/void_frames.tres`, `Assets/VoidConstruct/Frames/*`, `FrameSources/*`, `Scripts/full_frame_visual.gd`, `Scripts/gravity_vfx.gd`, six `Resources/FrameCombat/*.tres`, `Tools/build_full_frames.gd`, and `Tools/preview_full_frames.gd`. It updates `Scenes/player.tscn`, the player/combat/dummy/level scripts, related test suites and this guide. Godot `.uid` and `.png.import` metadata accompany the assets. Caches and local test recordings are not committed.
