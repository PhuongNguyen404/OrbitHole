# Orbitbreak — playable gravity-combat prototype

Open `black-hole-rogue/project.godot` in Godot 4.6 or newer and press **F5** (on Mac, possibly **fn + F5**). The main scene is `Scenes/game.tscn`.

- **A / D:** move; **Shift:** sprint.
- **Space:** jump; hold for height. All three slabs are reachable.
- **J:** dash, preserving the existing binding.
- **Left click / K:** attack. Tap during a move to queue the next strike.

The dummy is just ahead of the spawn on the existing ground platform. Its health bar, damage numbers, flash, stagger and knockback make hits visible. It has no AI and reforms two seconds after its health is depleted. Falls still return the player to the spawn.

## Four gravitational attacks

| Move | Duration | Damage | Motion |
|---|---:|---:|---|
| Singularity Jab | 0.28 s | 8 | Shoulder counters backward; detached fist accelerates ahead of the forearm, then recalls. |
| Event Horizon Sweep | 0.36 s | 10 | Torso twists while the detached forearm/fist orbit through a wide arc. Subtle nearby pull. |
| Gravity Reversal | 0.42 s | 16 | Stones gather toward the brightening head and accelerating ring; a detached fist launches while the torso recoils. Pulls toward the impact point and staggers. |
| Collapse Headbutt | 0.55 s | 28 | Head leads independently, torso follows, stones reassemble, then a deliberate recovery. Stronger knockback and hitstop. |

One press starts one move. The combo has one buffered input slot; holding attack does not repeat it, and extra buffered presses cannot skip stages. Default buffering opens 12% into a move and closes at 98%. An unbuffered follow-up can continue within 0.7 seconds after recovery; inactivity resets to jab. Small horizontal movement remains available while attacking. Jump and dash cancel safely. Gravity is not suspended by airborne attacks.

## Animation and artwork

`Assets/VoidConstruct/body_parts.png` is a newly generated coherent transparent atlas. It supplies sixteen actual Sprite2D components with independent pivots: torso, pelvis, head, ring, both upper arms/forearms/fists, thighs, shins and feet. `Scenes/void_visual.tscn` exposes these nodes in the editor. Nearest filtering and the original roughly 80-pixel character scale are retained. The earlier generated master remains in the repository as a reference; old uploaded character sprites are not used.

`Animations/gravity_melee.tres` contains four authored AnimationPlayer clips plus RESET. Their position and rotation tracks define anticipation, rapid extension, follow-through and recovery; no attack stretches an arm rectangle or scales the entire body. Detached pieces follow distinct trajectories. Procedural motion is limited to secondary stone drift, head/corona response, locomotion overlap and landing compression.

The player controller explicitly advances AnimationPlayer on the same clock as active windows. Confirmed-hit hitstop pauses that clock and the player, while the dummy uses its force integrator to hold its impact pose without disabling Area2D monitoring. The finisher adds only a small 0.1-second camera impulse on a confirmed hit. Misses do not produce hitstop or camera shake. Short violet trails, impact rings and a few heavy-impact chips are intentionally restrained procedural effects, not claimed as generated character artwork.

## Combat and tuning

`AttackHitbox` is a separate **Area2D** with a CollisionShape2D. Jab/reversal use rectangles, sweep a horizontal capsule, and headbutt a circle. Active windows, damage, shapes, reach, knockback, stagger, pull strength and hitstop are defined in the four `Resources/Combat/*.tres` resources. Combo reset/buffer timings and attack movement fraction are exported on `Combat` in `Scenes/player.tscn`.

`Scripts/gravity_combat.gd` handles input buffering and collision confirmation. Each target can be hit once per move. A wall ray blocks damage and attraction through solid geometry. Visual detachment never changes the main 22×60 collision capsule or teleports the player. Movement values, sprint, dash, jump, camera limits, tile grid and platform collision remain intact. Foreground rendering keeps every limb ahead of background buildings.

Open the AnimationPlayer in `Scenes/player.tscn` to inspect the `melee/…` tracks. The authored source for the rig and clips is `Tools/build_combat_assets.py`; run it with Python 3 from any directory to regenerate `Scenes/void_visual.tscn` and `Animations/gravity_melee.tres`. It uses only the standard library and never edits image pixels. Regeneration replaces those two files, so keep any hand-edited tracks in sync with the builder.

## Validation

From the repository root:

```sh
godot --headless --path black-hole-rogue --editor --import
godot --headless --path black-hole-rogue --quit-after 120
godot --headless --path black-hole-rogue --script res://Tests/movement_smoke.gd
godot --headless --path black-hole-rogue --script res://Tests/combat_platform_smoke.gd
godot --headless --path black-hole-rogue --script res://Tests/animation_smoke.gd
godot --headless --path black-hole-rogue --script res://Tests/gravity_combat_smoke.gd
```

The movement tests exercise the running/sprinting speeds, acceleration/deceleration, variable jump height, gap landing, dash, coyote time, buffering and respawn. Platform/layer tests actually land on each slab and check limb rendering depth. Animation tests sample each clip, check detachment/recovery, collision stability, grounded feet, facing and afterimage cleanup. Combat tests send real attack inputs against the dummy and check four-stage ordering, per-move damage, one-hit limits, buffering/inactivity, confirmed-hit hitstop, camera feedback, pull/stagger, cancellations, wall blocking and dummy reformation.

The four-move pose gallery and the real rendered combo are additionally inspected through a local dummy display using Mesa software rendering. Automated input and rendering validate implementation; subjective feel still benefits from hands-on playtesting.

No weapons, bosses, enemy AI, inventory, capture mechanic or upgrade system was added. The pre-rebuild project is backed up locally at `/workspace/orbithole-backups/pre-combat-rebuild.tar.gz` (cloud workspace only).

## Files changed in the combat rebuild

Modified:
- `PHASE1.md`
- `black-hole-rogue/Scenes/player.tscn`
- `black-hole-rogue/Scripts/player.gd`
- `black-hole-rogue/Scripts/practice_core.gd`
- `black-hole-rogue/Scripts/test_level.gd`
- `black-hole-rogue/Scripts/void_visual.gd`
- `black-hole-rogue/Tests/animation_smoke.gd`
- `black-hole-rogue/Tests/combat_platform_smoke.gd`

Added:
- `black-hole-rogue/Assets/VoidConstruct/body_parts.png` and `.png.import`
- `black-hole-rogue/Scenes/void_visual.tscn`
- `black-hole-rogue/Animations/gravity_melee.tres`
- `black-hole-rogue/Resources/Combat/singularity_jab.tres`
- `black-hole-rogue/Resources/Combat/event_horizon_sweep.tres`
- `black-hole-rogue/Resources/Combat/gravity_reversal.tres`
- `black-hole-rogue/Resources/Combat/collapse_headbutt.tres`
- `black-hole-rogue/Scripts/gravity_attack.gd` and `.gd.uid`
- `black-hole-rogue/Scripts/gravity_combat.gd` and `.gd.uid`
- `black-hole-rogue/Tests/gravity_combat_smoke.gd` and `.gd.uid`
- `black-hole-rogue/Tools/build_combat_assets.py`

Godot's `.godot/` cache is ignored. No setup caches, test recordings or local backup archives are committed.
