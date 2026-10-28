# Orbitbreak — animation quality pass and crystal enemy

This pass preserves the approved idle, improves attack anatomy and frame timing, separates temporary effects, and adds one basic crystallized enemy. **The exact user-supplied 12-pose run sheet is still pending its original PNG/ZIP.** The playable build currently uses the previous eight run drawings with provisional timing; it does not contain the supplied sheet yet. See [the animation audit](Docs/ANIMATION_AUDIT.md) for the completed work and remaining asset dependency.

## Play

Import `black-hole-rogue/project.godot`, wait for asset import, and press **F5** (or **fn + F5** on Mac). The user's Godot 4.7 project setting is retained; validation here used Godot 4.6.3.

- **A / D:** move. **Shift:** sprint.
- **Space:** jump; hold for height. **J:** dash.
- **K / left click:** attack. Tap during a basic move to continue **Gravity Jab → Repulsion Sweep → Singularity Headbutt**.
- Attack while sprinting, during a dash, or in the air for the corresponding special attack.

The **Void Dummy** near spawn provides repeatable health, damage, stagger and knockback feedback and reforms after depletion. One **Crystal Sentinel** stands farther right on the same ground platform. It approaches nearby players, telegraphs a short swipe, responds to gravity and melee, and can be defeated. Its five complete-body drawings cover idle, two steps, hurt and death. No enemy swarm or large AI system was added.

## Artwork and timing

The player remains one `AnimatedSprite2D`, with complete-character PNGs on a shared **160×112** transparent canvas and foot baseline **104**. Its transform and 22×60 capsule stay stable. No limb rig, skeletal animation, procedural body stretching or whole-body shaking was reintroduced.

The idle is unchanged: all eight PNG bytes, frame order, 8 FPS rate, loop setting and duration multipliers match the user's latest `main`. Jump and fall PNGs also remain unchanged. Their timing now distinguishes takeoff, rise, apex and descent; the rising drawing waits for physical ascent and the apex drawing follows vertical velocity. A short four-drawing landing compression reuses existing artwork and cancels immediately when movement, jump, dash or attack resumes.

The jab has seven authored poses: ready, anticipation, shoulder rotation, extension, impact, recoil and return. Its weights are `[0.6, 1.25, 0.65, 0.35, 1.1, 1.15, 0.7]`. Other attacks use distinct anticipation, extension, impact and recovery weights instead of equal-duration frames. The combat clock uses these weights to select drawings and derive active hitbox windows. Jab damage occurs on extension/impact drawings 3–4; the six-pose moves use drawings 2–3. Hitstop pauses both the complete image and the combat clock.

| Clip | Current state |
|---|---|
| Idle | Original eight drawings and timing preserved exactly. |
| Run | **Provisional previous eight drawings**, weighted at base 20 FPS; exact supplied 12-pose sheet not imported. |
| Sprint | Per the latest instruction, uses the **same run drawings in the same order**, at base 28 FPS with separate faint afterimages. |
| Jump / fall | Original four drawings each preserved; timing and physical apex transition polished. |
| Landing | Four reused complete drawings, about 0.175 seconds; no input lockout. |
| Gravity Jab | Seven key-pose-first drawings with visible shoulder/elbow anatomy; 0.34-second move. |
| Sweep / headbutt | Affected poses cleaned of temporary effects and retimed; 0.44 / 0.58 seconds. |
| Sprint / dash attack | Existing useful poses retained, affected effects repaired, weighted timing; 0.46 / 0.36 seconds. |
| Airborne smash | Dramatic poses retained, temporary effects removed from affected drawings, weighted plunge/contact/recovery; nominal 0.55 seconds plus bounded airborne hold. |

A generated or imported sheet alone is not proof of a good animation. The unfinished exact run-sheet replacement remains a visible art limitation, even though the current gameplay and timing tests pass.

## Independent effects and stable gameplay

`GravityVFX` owns one-shot pressure releases, confirmed-hit flashes, landing effects, the smash ground ring and small debris. Effects keep real-time lifetimes even when animation speed changes. Sprint afterimages use a separate 0.08-second emission interval and short, faint snapshots; they do not modify the run artwork. The normal black-hole head and accretion ring remain part of the character drawing.

Movement speeds, jump/coyote/buffer behavior, dash, camera limits and platform collision remain intact. Input bindings keep their physical keys and mouse button; their device IDs now use Godot's wildcard so the bindings work with both the serialized device IDs and ordinary device-0 input. The user's project version setting remains unchanged.

Attacks retain buffered inputs, safe jump/dash cancellation, limited movement, once-per-target damage, directional knockback and wall checks. Airborne smash holds its plunge drawing while continuing to fall, then advances into its drawn impact on actual contact and emits one independent shockwave. Head and arm drawings never teleport the collision body through geometry. The enemy receives line-of-sight checks at its body center rather than its feet, preventing valid melee hits from being rejected as floor collisions.

## Portable artwork rebuild

A normal clone already includes the playable normalized PNGs and `Animations/void_frames.tres`; no rebuild script is needed to play.

The quality overlay is retained in `Assets/VoidConstruct/QualitySources/manifest.json`. It preserves unlisted animations, especially idle. To reapply that overlay to the existing project, run from the repository root:

```sh
godot --headless --path black-hole-rogue --editor --import
godot --headless --path black-hole-rogue --script res://Tools/import_quality_frames.gd -- res://Assets/VoidConstruct/QualitySources/manifest.json
godot --headless --path black-hole-rogue --editor --import
```

If reconstructing the older base PNG set from source, run `Tools/build_full_frames.gd` first, import it, and then apply the quality overlay above. **The base builder alone restores the earlier artwork/timing and is not the final quality pass.** Both tools crop and uniformly normalize whole drawings; neither synthesizes poses or assembles limbs. The overlay's source regions, reused PNG paths and individual duration weights are explicit and portable.

The retained overlay was reapplied and compared with the tested build: every character PNG and the SpriteFrames resource had identical hashes. Manifest serialization retains full floating-point precision so a saved crop/normalization value does not move a pixel on rebuild. Idle is absent from the overlay and remains untouched.

## Validation

After a clean editor import, all seven suites completed without engine errors or warnings on Godot 4.6.3:

| Suite | Passed checks |
|---|---:|
| `movement_smoke.gd` | 21 |
| `combat_platform_smoke.gd` | 6 |
| `animation_smoke.gd` | 88 |
| `gravity_combat_smoke.gd` | 33 |
| `animation_timing_smoke.gd` | 32 |
| `crystal_enemy_smoke.gd` | 26 |
| `sprint_trail_smoke.gd` | 8 |

Run a suite with `godot --headless --path black-hole-rogue --script res://Tests/<suite>.gd`. The player-only suites deliberately isolate the enemy; the dedicated enemy suite tests real interaction. Preservation fixtures assert exact idle artwork/order/timing and unchanged jump/fall PNGs. The suites also cover native input matching, every slab landing, weighted impact timing, stable transforms/collision, hitstop, cancellation, wall blocking, enemy approach/swipe/hurt/death, and effect cleanup. They validate the active **provisional** run resource, not import of the unavailable supplied sheet or subjective animation quality.

Live rendered Godot playback was also inspected for jab contact, sprint, the enemy's windup and hit, and smash landing. See [the audit's gameplay captures](Docs/ANIMATION_AUDIT.md#rendered-gameplay-review). After the portable rebuild, editor import was clean and the 88-check animation suite passed again.

With a display, inspect individual imported sequences using `Tools/preview_full_frames.gd`, for example:

```sh
godot --path black-hole-rogue --script res://Tools/preview_full_frames.gd -- gravity_jab /tmp/jab-preview.png
```

## Files and scope

The main quality changes are in `Scripts/full_frame_visual.gd`, `gravity_combat.gd`, `gravity_vfx.gd`, `gravity_attack.gd`, the six `Resources/FrameCombat` resources, `Animations/void_frames.tres`, selected complete PNGs, `QualitySources`, and `Tools/import_quality_frames.gd`. Enemy additions are `Scenes/crystal_enemy.tscn`, `Scripts/crystal_enemy.gd`, `Assets/Enemies/CrystalSentinel`, its builder and its tests. Player/level scripts add localized enemy response and one spawn. Tests and preservation fixtures document the regressions.

The prior rig remains archived in `Backups/pre_full_frames_visual.zip`; Git history preserves earlier project versions. Existing user updates from `main` were used as the starting point. Grappling/swinging, gravity absorption/capture, weapons, transformation, bosses, inventory and upgrades are not implemented and were not introduced by this pass.
