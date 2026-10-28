extends SceneTree
var game: Node2D
var player: CharacterBody2D
var dummy: RigidBody2D
var combat: Node
var starts: Array[int] = []
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
func frames(count: int) -> void:
	for i in range(count):
		await physics_frame
func tap() -> void:
	Input.action_press("attack")
	await frames(2)
	Input.action_release("attack")
	await frames(2)
func prepare(close := true) -> void:
	for action in ["attack","jump","dash","move_left","move_right","sprint"]:
		Input.action_release(action)
	player.respawn()
	player.position = Vector2(230,448)
	player.facing = 1
	dummy.freeze = false
	dummy.linear_velocity = Vector2.ZERO
	dummy.hitstop_left = 0.0
	dummy.reset_to(Vector2(264 if close else 800,413))
	dummy.health = dummy.max_health
	dummy.damage_log.clear()
	dummy.hit_count = 0
	await frames(5)
	starts.clear()
func wait_stage_end() -> void:
	for i in range(160):
		if not combat.attacking:
			return
		await frames(1)
	check(false,"attack must recover")
func run() -> void:
	game = load("res://Scenes/game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	player = game.get_node("Player")
	dummy = game.get_node("TrainingDummy")
	combat = player.combat
	combat.attack_started.connect(func(stage: int) -> void: starts.append(stage))
	await frames(5)
	await prepare()
	Input.action_press("attack")
	await frames(150)
	check(starts==[0] and not combat.attacking,"one held click produces one jab, never an automatic combo")
	check(dummy.damage_log==[8],"active Area2D hits once despite several overlapping physics frames")
	Input.action_release("attack")
	await prepare()
	await tap()
	for expected in range(3):
		for i in range(100):
			if combat.stage==expected and combat.progress>=.50:
				break
			await frames(1)
		check(combat.stage==expected,"combo reaches step "+str(expected+1)+" in order")
		await tap()
		check(combat.queued,"press inside broad window buffers one next attack")
		for i in range(100):
			if combat.stage!=expected:
				break
			await frames(1)
	await wait_stage_end()
	check(starts==[0,1,2,3],"four timed presses play jab sweep reversal and headbutt without skipping")
	check(dummy.damage_log==[8,10,16,28] and dummy.health==98,"all four Area2D shapes apply their own damage exactly once")
	check(not combat.active and player.get_node("AttackHitbox/CollisionShape2D").disabled,"hitbox closes during recovery")
	check(player.visual.bones["head"].position.distance_to(player.visual.anchors["head"])<1.0,"head reforms after headbutt")
	await frames(4)
	check(player.state==player.State.IDLE,"combo returns cleanly to idle")
	await prepare(false)
	await tap()
	await wait_stage_end()
	await frames(20)
	await tap()
	check(combat.stage==1,"a relaxed follow-up within inactivity window advances one step")
	await wait_stage_end()
	await frames(100)
	await tap()
	check(combat.stage==0,"inactivity resets the combo to jab")
	await prepare(false)
	Input.action_press("attack")
	await frames(1)
	Input.action_release("attack")
	await frames(1)
	Input.action_press("attack")
	await frames(1)
	Input.action_release("attack")
	await frames(70)
	check(starts==[0],"a press before the valid buffer window does not chain")
	check(combat.hitstop_left==0 and player.shake_left==0,"misses cause neither hitstop nor camera shake")
	await prepare()
	dummy.freeze = false
	await tap()
	var found := false
	for i in range(40):
		if combat.hitstop_left>0:
			found = true
			break
		await frames(1)
	check(found and dummy.stagger_left>0,"confirmed jab triggers hitstop and dummy stagger")
	var elapsed: float = combat.elapsed
	var position_before: Vector2 = player.position
	await frames(1)
	check(combat.elapsed==elapsed and player.position==position_before,"hitstop freezes clip and player movement together")
	check(dummy.hitstop_left>0 or dummy.flash>0,"dummy receives impact flash and hitstop")
	check(player.shake_left==0,"light hits do not shake the camera")
	await prepare()
	combat.start(3,1)
	for i in range(60):
		if dummy.hit_count>0:
			break
		await frames(1)
	check(dummy.damage_log==[28] and player.shake_left>0,"only a confirmed finisher triggers small camera shake")
	check(combat.hitstop_left>=.04,"finisher has stronger hitstop")
	await prepare()
	player.facing = -1
	dummy.reset_to(Vector2(196,413))
	await frames(3)
	await tap()
	await wait_stage_end()
	check(dummy.damage_log==[8],"left-facing Area2D hits mirror correctly")
	await prepare(false)
	dummy.reset_to(Vector2(299,413))
	await frames(3)
	dummy.freeze = false
	var start_x := dummy.position.x
	combat.start(2,1)
	await frames(14)
	check(dummy.position.x<start_x,"reversal pulls the dummy toward the impact point before striking")
	await prepare(false)
	await tap()
	Input.action_press("dash")
	await frames(3)
	check(not combat.attacking and player.state==player.State.DASH and not combat.active,"dash cancels the animation and Area2D safely")
	await prepare(false)
	await tap()
	Input.action_press("jump")
	await frames(3)
	check(not combat.attacking and player.velocity.y<0,"jump remains responsive during attacks")
	await prepare()
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(8,160)
	shape.shape = rectangle
	wall.add_child(shape)
	wall.position = Vector2(252,400)
	game.add_child(wall)
	dummy.reset_to(Vector2(281,413))
	await frames(5)
	combat.start(3,1)
	Input.action_press("move_right")
	await frames(80)
	Input.action_release("move_right")
	check(player.position.x<=238 and dummy.hit_count==0,"headbutt neither teleports through walls nor damages through them")
	wall.queue_free()
	await frames(2)
	await prepare()
	dummy.health = 8
	await tap()
	await wait_stage_end()
	check(dummy.health==0,"dummy can be depleted")
	await frames(270)
	check(dummy.health==dummy.max_health,"dummy reforms automatically for continued testing")
	print("ALL ",checks," GRAVITY COMBAT CHECKS PASSED")
	game.queue_free()
	await process_frame
	quit(0)
