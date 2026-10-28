extends SceneTree
var checks := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:
		push_error("FAIL: "+message)
		quit(1)
		assert(ok,message)
	checks += 1
	print("PASS: "+message)
func run() -> void:
	var scene = load("res://Scenes/game.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	var player = scene.get_node("Player")
	player.set_physics_process(false)
	var visual = player.visual
	visual.set_process(false)
	var timeline: AnimationPlayer = player.get_node("AnimationPlayer")
	check(visual.bones.size()==16,"sixteen separately pivoted sprite parts")
	var sprite_art := true
	for id in visual.bones:
		sprite_art = sprite_art and visual.bones[id].get_node("Art") is Sprite2D
	check(sprite_art,"all body components use generated Sprite2D artwork")
	var body: CollisionShape2D = player.get_node("CollisionShape2D")
	var collider_transform := body.transform
	var collider_size: Vector2 = Vector2(body.shape.radius,body.shape.height)
	var expected := [[0,.105,"hand_front",45.0],[1,.18,"hand_back",55.0],[2,.19,"hand_front",55.0],[3,.205,"head",30.0]]
	for sample in expected:
		player.combat.start(sample[0],1.0)
		var playing := timeline.current_animation
		timeline.seek(sample[1],true)
		var part: Node2D = visual.bones[sample[2]]
		check(part.position.x>=sample[3],"independent strike silhouette for "+str(sample[0]+1))
		check(timeline.get_animation(playing).get_track_count()>=30,"authored position/rotation tracks for "+str(sample[0]+1))
		for fraction in [.0,.25,.5,.75,1.0]:
			timeline.seek(timeline.get_animation(playing).length*fraction,true)
			check(body.transform==collider_transform and Vector2(body.shape.radius,body.shape.height)==collider_size,"body collision remains stable in attack "+str(sample[0]+1)+" at "+str(fraction))
		timeline.seek(timeline.get_animation(playing).length,true)
		check(visual.bones["hand_front"].position==visual.anchors["hand_front"] and visual.bones["head"].position==visual.anchors["head"],"authored recovery returns separated parts")
	player.combat.cancel()
	visual.state = "IDLE"
	var root_position: Vector2 = visual.position
	visual._process(.1)
	var before_head: Vector2 = visual.bones["head"].position
	visual._process(.8)
	check(visual.position==root_position and visual.bones["head"].position!=before_head,"idle moves separate fragments without root shaking")
	for state in ["IDLE","RUN","SPRINT"]:
		visual.state = state
		for frame in range(16):
			visual._process(1.0/12)
			var lowest := -INF
			for id in ["foot_front","foot_back"]:
				var art: Sprite2D = visual.bones[id].get_node("Art")
				var rect := art.get_rect()
				for point in [rect.position,rect.end,Vector2(rect.position.x,rect.end.y),Vector2(rect.end.x,rect.position.y)]:
					lowest = maxf(lowest,visual.to_local(art.to_global(point)).y)
			check(absf(lowest)<.01,"grounded foot alignment in "+state)
	visual.facing = -1
	visual._process(.1)
	check(visual.rig.scale.x==-1,"all components mirror together")
	var before: int = scene.get_child_count()
	visual.afterimage()
	check(scene.get_child_count()==before+1,"dash captures the entire new sprite rig")
	await create_timer(.3).timeout
	check(scene.get_child_count()==before,"dash snapshot cleans itself up")
	print("ALL ",checks," ANIMATION CHECKS PASSED")
	scene.queue_free()
	await process_frame
	quit(0)
