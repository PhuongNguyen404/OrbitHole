extends SceneTree
## Inspect the articulated visual hierarchy independently of movement physics.
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		push_error("FAIL: " + message)
		quit(1)
		assert(ok,message)
	checks += 1
	print("PASS: " + message)

func run() -> void:
	var scene := Node2D.new()
	root.add_child(scene)
	current_scene = scene
	var visual = load("res://Scripts/void_visual.gd").new()
	scene.add_child(visual)
	visual.set_process(false)
	check(visual.bones.size() == 15,"15 independently articulated body parts")
	for joint in visual.bones.values():
		var artwork: Polygon2D = joint.get_child(0)
		check(artwork.texture == visual.MASTER and artwork.uv.size() == artwork.polygon.size(),"joint uses master artwork with matching UV coordinates")
	var poses: Array[Dictionary] = []
	for state in ["IDLE","RUN","SPRINT","JUMP","FALL","DASH"]:
		visual.state = state
		visual._process(0.25)
		poses.append(visual.sampled_rotations.duplicate())
		check(visual.head_ring.points.size() == 5,"head ring animates in " + state)
		check(visual.RATES[state] == (12.0 if state == "RUN" else 14.0 if state == "SPRINT" or state == "DASH" else 8.0),"requested sample rate for " + state)
	check(poses[1]["thigh_front"] * poses[1]["thigh_back"] < 0.0,"run alternates legs")
	check(poses[1]["arm_front"] * poses[1]["thigh_front"] < 0.0,"run arm swing opposes legs")
	check(poses[2]["chest"] > poses[1]["chest"],"sprint leans farther than run")
	check(poses[3] != poses[4] and poses[4] != poses[5],"jump fall and dash have distinct full-body poses")
	visual.state = "IDLE"
	visual._process(0.1)
	var time_before: float = visual.animation_time
	visual.state = "IDLE"
	check(visual.animation_time == time_before,"repeated state does not restart animation")
	var original_root: Vector2 = visual.position
	var head_before: Vector2 = visual.bones["head"].position
	visual._process(0.9)
	check(visual.position == original_root,"idle does not shake visual root")
	check(visual.bones["head"].position != head_before,"head floats independently while idle")
	for state in ["IDLE","RUN","SPRINT"]:
		visual.state = state
		for step in range(16):
			visual._process(1.0/12.0)
			var lowest := -INF
			for foot_id in ["foot_front","foot_back"]:
				var art: Polygon2D = visual.bones[foot_id].get_child(0)
				for vertex in art.polygon:
					lowest = maxf(lowest,visual.to_local(art.to_global(vertex)).y)
			if absf(lowest) > 0.01:
				check(false,"grounded foot baseline drift in " + state)
		check(true,"feet stay at ground baseline across " + state + " cycle")
	visual.facing = -1.0
	visual.state = "DASH"
	visual._process(0.1)
	check(visual.rig.scale.x == -1.0,"entire articulated pose flips left")
	var before := scene.get_child_count()
	visual.afterimage()
	var ghost: Node2D = scene.get_child(scene.get_child_count()-1)
	check(scene.get_child_count() == before + 1 and ghost.global_transform == visual.rig.global_transform,"afterimage captures current facing and transform")
	check(ghost.get_child_count() == visual.rig.get_child_count(),"afterimage includes all posed body parts")
	await create_timer(0.3).timeout
	check(scene.get_child_count() == before,"afterimage is removed after fading")
	print("ALL ",checks," ANIMATION CHECKS PASSED")
	scene.queue_free()
	await process_frame
	quit(0)
