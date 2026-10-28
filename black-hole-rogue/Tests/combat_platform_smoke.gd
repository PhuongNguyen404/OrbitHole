extends SceneTree
var player: CharacterBody2D
var core: RigidBody2D
var checks := 0
var game: Node2D

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool,message: String) -> void:
	if not ok:
		push_error("FAIL: " + message)
		quit(1)
		assert(ok,message)
	checks += 1
	print("PASS: " + message)

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame

func tap() -> void:
	Input.action_press("attack")
	await frames(2)
	Input.action_release("attack")
	await frames(2)

func reset_at(point: Vector2) -> void:
	for action in ["move_left","move_right","jump","sprint","dash","attack"]:
		Input.action_release(action)
	player.respawn()
	player.position = point
	player.facing = 1.0
	await frames(20)

func total_z(node: CanvasItem) -> int:
	var result := node.z_index
	var parent := node.get_parent() as CanvasItem
	if node.z_as_relative and parent != null:
		result += total_z(parent)
	return result

func run() -> void:
	game = load("res://Scenes/game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	player = game.get_node("Player")
	core = game.get_node("PracticeCore")
	await frames(5)
	for id in player.visual.bones:
		var art: Polygon2D = player.visual.bones[id].get_child(0)
		check(total_z(art)>total_z(game),id+" renders ahead of background buildings")
	# Actually jump onto each elevated slab, rather than only asserting height.
	var jumps := [[Vector2(280,448),Vector2(336,480),352.0,25],
		[Vector2(448,352),Vector2(576,704),272.0,70],
		[Vector2(1120,448),Vector2(1200,1360),336.0,40]]
	for jump in jumps:
		await reset_at(jump[0])
		Input.action_press("jump")
		Input.action_press("move_right")
		await frames(jump[3])
		Input.action_release("move_right")
		await frames(125-jump[3])
		Input.action_release("jump")
		print("slab landing: ",player.position)
		check(player.is_on_floor() and absf(player.position.y-jump[2]) < 1.0 and player.position.x >= jump[1].x and player.position.x <= jump[1].y,"jump reaches slab at height " + str(jump[2]))
	await reset_at(Vector2(718,448))
	# Park the core in front of the fist to inspect actual collision, not the pose.
	core.position = Vector2(750,401)
	core.home = core.position
	core.linear_velocity = Vector2.ZERO
	await frames(3)
	var start_x := core.position.x
	Input.action_press("attack")
	await frames(10)
	check(core.position.x < start_x,"windup gravity attracts the practice core")
	await frames(15)
	check(core.hit_count==1 and core.last_stage==0,"punch hitbox damages target once during its active window")
	await frames(100)
	check(player.attack_stage == -1 and core.hit_count == 1,"holding attack neither repeats nor chains automatically")
	Input.action_release("attack")
	await reset_at(Vector2(160,448))
	await tap()
	await frames(20)
	await tap()
	await frames(27)
	check(player.attack_stage==1,"second tap buffers reverse punch")
	await frames(13)
	await tap()
	await frames(40)
	check(player.attack_stage==2,"third tap buffers gravity kick")
	await frames(80)
	check(player.attack_stage == -1,"combo recovers to movement")
	await reset_at(Vector2(718,448))
	core.freeze = true
	core.position = Vector2(750,401)
	core.home = core.position
	await frames(3)
	var before_hits: int = core.hit_count
	await tap()
	await frames(20)
	await tap()
	await frames(40)
	await tap()
	await frames(120)
	check(core.hit_count == before_hits+3 and core.last_stage == 2,"all three combo stages hit exactly once")
	await reset_at(Vector2(718,448))
	player.facing = -1.0
	core.position = Vector2(686,401)
	core.home = core.position
	await frames(3)
	before_hits = core.hit_count
	await tap()
	await frames(50)
	check(core.hit_count == before_hits+1,"melee hitbox mirrors when facing left")
	core.freeze = false
	# Recovery cancels keep the controls responsive.
	await tap()
	Input.action_press("dash")
	await frames(3)
	check(player.attack_stage == -1 and player.state == player.State.DASH,"dash cancels melee without leaving a live hitbox")
	await reset_at(Vector2(160,448))
	await tap()
	Input.action_press("jump")
	await frames(3)
	check(player.attack_stage == -1 and player.velocity.y < 0,"jump cancels melee")
	await frames(18)
	await tap()
	check(player.air_attack_used,"airborne attack is allowed once per airtime")
	await frames(52)
	Input.action_press("attack")
	await frames(2)
	check(player.attack_stage == -1 or player.is_on_floor(),"airborne attack cannot be spammed to hover")
	Input.action_release("attack")
	Input.action_release("jump")
	print("ALL ",checks," COMBAT AND PLATFORM CHECKS PASSED")
	game.queue_free()
	await process_frame
	quit(0)
