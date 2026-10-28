extends SceneTree
var checks := 0
var game: Node2D
var player: CharacterBody2D
var enemy: CharacterBody2D
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool,message: String) -> void:
	if not ok:
		push_error("FAIL: "+message)
		quit(1)
		assert(ok,message)
	checks+=1
	print("PASS: "+message)
func frames(count: int) -> void:
	for i in range(count):
		await physics_frame
func reset_pair(p: Vector2,e: Vector2) -> void:
	player.position = p
	player.velocity = Vector2.ZERO
	player.enemy_invuln_left = 0
	player.enemy_knockback_left = 0
	enemy.position = e
	enemy.velocity = Vector2.ZERO
	enemy.push_velocity = 0
	enemy.windup_left = 0
	enemy.strike_left = 0
	enemy.cooldown_left = 0
	enemy.stagger_left = 0
	enemy.hitstop_left = 0
	await frames(5)
func run() -> void:
	game = load("res://Scenes/game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	player = game.get_node("Player")
	enemy = game.get_node("CrystalSentinel")
	await frames(5)
	check(get_nodes_in_group("crystal_enemies").size()==1,"exactly one crystal enemy is present")
	check(enemy.is_on_floor() and enemy.health==40,"enemy spawns grounded with forty health")
	check(enemy.get_node("AnimatedSprite2D") is AnimatedSprite2D,"enemy renders complete character frames")
	var sprite: AnimatedSprite2D = enemy.get_node("AnimatedSprite2D")
	for animation in ["idle","walk","hurt","dead","swipe"]:
		check(sprite.sprite_frames.has_animation(animation),"small sprite set includes "+animation)
	player.set_physics_process(false)
	await reset_pair(Vector2(600,448),Vector2(720,448))
	var before := enemy.position.x
	await frames(45)
	check(enemy.position.x<before-10,"enemy approaches a nearby player")
	await reset_pair(Vector2(1000,448),Vector2(874,448))
	enemy.facing=1
	await frames(60)
	check(enemy.position.x<880 and enemy.is_on_floor(),"floor probe prevents chasing into the gap")
	await reset_pair(Vector2(670,448),Vector2(710,448))
	var before_hits: int = player.enemy_hit_count
	await frames(12)
	check(enemy.windup_left>0 and player.enemy_hit_count==before_hits,"swipe has a readable windup before damage response")
	for i in range(80):
		if player.enemy_hit_count>before_hits:
			break
		await frames(1)
	check(player.enemy_hit_count==before_hits+1 and player.enemy_invuln_left>0,"enemy swipe connects through its Area2D")
	check(absf(player.velocity.x)>200 and player.velocity.y<0,"swipe applies directional knockback")
	await frames(21)
	check(player.enemy_hit_count==before_hits+1,"one swipe cannot repeatedly hit the player")
	check(not player.receive_enemy_hit(Vector2(100,0)),"player's brief invulnerability rejects repeated hits")
	check(enemy.cooldown_left>0,"enemy waits before winding up again")
	await reset_pair(Vector2(650,448),Vector2(700,448))
	var push_before: float = enemy.push_velocity
	enemy.apply_gravity_pull(Vector2(650,410),40)
	check(enemy.push_velocity<push_before,"enemy responds to the player's gravity pull")
	enemy.apply_hitstop(.03)
	var held: Vector2 = enemy.position
	await frames(2)
	check(enemy.position==held,"confirmed-hit hitstop holds enemy body")
	await frames(5)
	# Send a real player input and let the actual attack Area2D find the enemy.
	player.set_physics_process(true)
	await reset_pair(Vector2(660,448),Vector2(700,448))
	player.facing=1
	var hp_before: int=enemy.health
	Input.action_press("attack")
	await frames(2)
	Input.action_release("attack")
	for i in range(60):
		if enemy.health<hp_before:
			break
		await frames(1)
	check(enemy.health==hp_before-8,"real Gravity Jab damages the crystal enemy")
	check(enemy.stagger_left>0 and enemy.flash_left>0,"confirmed hit produces stagger and flash")
	await frames(30)
	check(enemy.health==hp_before-8,"one jab cannot repeatedly damage the enemy")
	var count_before := get_nodes_in_group("crystal_enemies").size()
	check(enemy.receive_attack(100,Vector2(100,-20),.2,enemy.global_position),"enemy accepts a lethal hit")
	await frames(10)
	check(enemy.dead and enemy.health==0 and enemy.collision_layer==0,"defeated enemy disables its damageable collision layer")
	check(enemy.get_node("Strike/CollisionShape2D").disabled,"defeated enemy cannot leave a live melee hitbox")
	check(not enemy.receive_attack(8,Vector2.ZERO,.1,enemy.global_position),"corpse cannot be hit repeatedly")
	await frames(150)
	check(get_nodes_in_group("crystal_enemies").size()==count_before,"defeat does not spawn more enemies")
	print("ALL ",checks," CRYSTAL ENEMY CHECKS PASSED")
	game.queue_free()
	await process_frame
	quit(0)
