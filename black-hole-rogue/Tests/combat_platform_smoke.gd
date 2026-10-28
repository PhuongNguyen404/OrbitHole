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
	core = game.get_node("TrainingDummy")
	await frames(5)
	var body_art: AnimatedSprite2D = player.get_node("AnimatedSprite2D")
	check(total_z(body_art)>total_z(game),"the complete character renders ahead of background buildings")
	check(player.scale==Vector2.ONE,"body collision parent remains unscaled")
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
	check(player.get_node("AttackHitbox") is Area2D,"melee uses an Area2D independently of main collision")
	print("ALL ",checks," PLATFORM AND LAYERING CHECKS PASSED")
	game.queue_free()
	await process_frame
	quit(0)
