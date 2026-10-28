extends SceneTree
var player: CharacterBody2D
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		push_error("FAIL: " + message)
		quit(1)
		assert(ok, message)
	checks += 1
	print("PASS: " + message)

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame

func reset_at(point := Vector2(160,448)) -> void:
	for action in ["move_left","move_right","jump","sprint","dash","attack"]:
		Input.action_release(action)
	player.respawn()
	player.global_position = point
	await frames(4)

func jump_height(hold: int) -> float:
	await reset_at()
	Input.action_press("jump")
	var top := player.position.y
	for i in range(65):
		if i == hold:
			Input.action_release("jump")
		await frames(1)
		top = minf(top,player.position.y)
	Input.action_release("jump")
	return 448.0 - top

func run() -> void:
	var game = load("res://Scenes/game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	# These regressions isolate the player/dummy; enemy interaction has its own suite.
	for enemy in get_nodes_in_group("crystal_enemies"):
		enemy.queue_free()
	player = game.get_node("Player")
	await frames(4)
	# Native input matching catches incompatible serialized device IDs that direct
	# Input.action_press fixtures deliberately bypass during physics checks.
	var bindings := {"move_left":65,"move_right":68,"jump":32,"sprint":4194325,"dash":74,"attack":75}
	for action in bindings:
		var matched := true
		for device in [0,16]:
			var key := InputEventKey.new()
			key.device = device
			key.physical_keycode = bindings[action]
			key.pressed = true
			matched = matched and InputMap.event_is_action(key,action)
		check(matched,"physical keyboard binding works across device IDs: "+action)
	var mouse_matched := true
	for device in [0,32]:
		var mouse := InputEventMouseButton.new()
		mouse.device = device
		mouse.button_index = MOUSE_BUTTON_LEFT
		mouse.pressed = true
		mouse_matched = mouse_matched and InputMap.event_is_action(mouse,&"attack")
	check(mouse_matched,"left mouse attack works across device IDs")
	check(player.is_on_floor() and absf(player.position.y-448) < 1,"spawn stands on solid ground")
	check(player.scale == Vector2.ONE,"collision parent is unscaled")
	check(game.get_node("Platforms") is TileMapLayer,"platforms use TileMapLayer")
	Input.action_press("move_right")
	await frames(24)
	check(absf(player.velocity.x-240) < 1 and player.state == player.State.RUN,"run reaches 240 px/s")
	Input.action_press("sprint")
	await frames(20)
	check(absf(player.velocity.x-360) < 1 and player.state == player.State.SPRINT,"sprint reaches 360 px/s")
	Input.action_release("move_right")
	Input.action_release("sprint")
	await frames(25)
	check(absf(player.velocity.x) < 1 and player.state == player.State.IDLE,"release decelerates to idle")
	var short_hop := await jump_height(3)
	var full_jump := await jump_height(60)
	check(full_jump > short_hop + 20,"holding Space produces a higher jump")
	await reset_at(Vector2(840,448))
	Input.action_press("move_right")
	await frames(30)
	Input.action_press("jump")
	await frames(125)
	Input.action_release("jump")
	Input.action_release("move_right")
	check(player.position.x > 1040 and player.is_on_floor(),"running jump crosses the gap and lands")
	await reset_at()
	Input.action_press("dash")
	await frames(3)
	check(player.state == player.State.DASH and absf(player.velocity.x-650)<1,"J activates 650 px/s dash")
	await frames(65)
	check(player.dash_left == 0 and player.position.x < 380,"holding J does not repeatedly dash")
	Input.action_release("dash")
	await reset_at()
	Input.action_press("move_left")
	await frames(2)
	Input.action_release("move_left")
	Input.action_press("dash")
	await frames(2)
	check(player.velocity.x == -650,"stationary dash uses last facing direction")
	await reset_at(Vector2(890,448))
	Input.action_press("move_right")
	while player.is_on_floor():
		await frames(1)
	await frames(4)
	Input.action_press("jump")
	await frames(2)
	check(player.velocity.y < -300,"coyote jump works after leaving edge")
	await reset_at(Vector2(160,420))
	player.velocity.y = 220
	Input.action_press("jump")
	await frames(18)
	check(player.velocity.y < 0,"jump pressed before landing is buffered")
	await reset_at(Vector2(950,710))
	await frames(30)
	check(player.position.y <= 448.1 and player.position.x < 300,"falling in gap respawns safely")
	print("ALL ",checks," CHECKS PASSED")
	game.queue_free()
	await process_frame
	quit(0)
