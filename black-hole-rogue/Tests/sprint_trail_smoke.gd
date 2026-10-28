extends SceneTree
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		push_error("FAIL: "+message)
		quit(1)
		assert(ok,message)
	checks += 1
	print("PASS: "+message)

func run() -> void:
	var game = load("res://Scenes/game.tscn").instantiate()
	root.add_child(game)
	current_scene=game
	var player=game.get_node("Player")
	var vfx=player.get_node("GravityVFX")
	for tick in range(5):
		await physics_frame
	player.set_physics_process(false)
	vfx.set_process(false)
	player.visual.state="SPRINT"
	player.velocity=Vector2(360,0)
	var before_children: int=game.get_child_count()
	for tick in range(120):
		vfx._update_sprint_trail(1.0/120.0)
	var normal_rate: int=vfx.sprint_afterimages_emitted
	check(normal_rate>=10 and normal_rate<=14,"sprint afterimages emit at a capped real-time rate")
	player.visual.speed_scale=0.25
	for tick in range(120):
		vfx._update_sprint_trail(1.0/120.0)
	var slow_rate: int=vfx.sprint_afterimages_emitted-normal_rate
	check(absi(slow_rate-normal_rate)<=1,"slowing frame playback does not change trail density")
	var before: int=vfx.sprint_afterimages_emitted
	vfx._update_sprint_trail(.5)
	check(vfx.sprint_afterimages_emitted==before+1,"a slow render frame cannot produce a catch-up burst")
	player.visual.state="RUN"
	before=vfx.sprint_afterimages_emitted
	vfx._update_sprint_trail(.5)
	check(vfx.sprint_afterimages_emitted==before,"normal running does not emit sprint trails")
	player.visual.state="SPRINT"
	player.velocity=Vector2(20,0)
	vfx._update_sprint_trail(.5)
	check(vfx.sprint_afterimages_emitted==before,"a stationary or slow sprite does not leave sprint ghosts")
	player.velocity=Vector2(360,0)
	player.combat.start(0,1)
	player.visual.state="SPRINT"
	vfx._update_sprint_trail(.5)
	check(vfx.sprint_afterimages_emitted==before,"an attack prevents sprint trail emission")
	player.combat.cancel()
	player.position.y-=100
	player.velocity=Vector2(360,-100)
	player.move_and_slide()
	player.visual.state="SPRINT"
	vfx._update_sprint_trail(.5)
	check(vfx.sprint_afterimages_emitted==before,"airborne movement does not emit grounded sprint trails")
	await create_timer(.25).timeout
	check(game.get_child_count()==before_children,"brief whole-frame snapshots clean themselves up")
	print("ALL ",checks," SPRINT TRAIL CHECKS PASSED")
	game.queue_free()
	await process_frame
	quit(0)
