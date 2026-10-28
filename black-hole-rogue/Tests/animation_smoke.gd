extends SceneTree
## The body is one complete-image animation, never a hierarchy of moving limbs.
var checks := 0
var game: Node2D
var player: CharacterBody2D
var visual: AnimatedSprite2D
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
func run() -> void:
	game = load("res://Scenes/game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	player = game.get_node("Player")
	visual = player.get_node("AnimatedSprite2D")
	await frames(5)
	check(player.visual==visual,"controller renders through the main AnimatedSprite2D")
	check(not player.has_node("VisualRoot") and not player.has_node("AnimationPlayer"),"puppet root and limb AnimationPlayer are removed from the playable scene")
	check(visual.get_child_count()==0,"the character image has no independently animated limb children")
	check(player.has_node("GravityVFX") and player.has_node("OrbitCoreContainer"),"gravity effects and orbit cores remain separate from body art")
	var expected := {"idle":[8,8.0],"run":[8,12.0],"sprint":[8,14.0],"jump":[4,10.0],"fall":[4,8.0],"dash":[6,14.0]}
	for animation in expected:
		check(visual.sprite_frames.has_animation(animation),"full-character animation exists: "+animation)
		check(visual.sprite_frames.get_frame_count(animation)==expected[animation][0] and visual.sprite_frames.get_animation_speed(animation)==expected[animation][1],"requested count and FPS: "+animation)
	var all_complete_canvases := true
	var all_have_alpha_margins := true
	var distinct_poses := true
	for animation in visual.sprite_frames.get_animation_names():
		if animation==&"default":
			continue
		var hashes: Dictionary = {}
		for frame in range(visual.sprite_frames.get_frame_count(animation)):
			var texture := visual.sprite_frames.get_frame_texture(animation,frame)
			all_complete_canvases = all_complete_canvases and texture!=null and texture.get_width()==160 and texture.get_height()==112
			if texture!=null:
				var image := texture.get_image()
				var used := image.get_used_rect()
				all_have_alpha_margins = all_have_alpha_margins and used.has_area() and used.position.x>0 and used.position.y>0 and used.end.x<160 and used.end.y<112
				hashes[hash(image.get_data())] = true
		if visual.sprite_frames.get_frame_count(animation)>1 and hashes.size()<2:
			distinct_poses = false
	check(all_complete_canvases,"every animation texture uses the same 160 by 112 canvas")
	check(all_have_alpha_margins,"complete-frame artwork keeps transparent margins on every side")
	check(distinct_poses,"animation sequences contain changed image pixels rather than repeated static textures")
	var collision: CollisionShape2D = player.get_node("CollisionShape2D")
	var collider_transform := collision.transform
	var collider_dimensions := Vector2(collision.shape.radius,collision.shape.height)
	var sprite_transform := visual.transform
	player.set_physics_process(false)
	for index in range(player.combat.attacks.size()):
		player.combat.start(index,1.0)
		var selected := visual.animation
		var frame_before := visual.frame
		player.combat.step(player.combat.attacks[index].duration*.45)
		check(visual.animation==selected and visual.frame!=frame_before,"attack advances actual complete frames for move "+str(index+1))
		check(collision.transform==collider_transform and Vector2(collision.shape.radius,collision.shape.height)==collider_dimensions,"main collision stays fixed during move "+str(index+1))
		check(visual.transform==sprite_transform,"move "+str(index+1)+" does not rotate, scale or shake the whole character")
		var elapsed: float = player.combat.elapsed
		var frame_at_hitstop := visual.frame
		player.combat.hitstop_left = .05
		player.combat.step(.01)
		check(player.combat.elapsed==elapsed and visual.frame==frame_at_hitstop,"hitstop holds the current complete-character frame")
		player.combat.cancel()
	visual.state = "JUMP"
	await create_timer(.55).timeout
	var jump_last := visual.sprite_frames.get_frame_count(&"jump")-1
	check(not visual.sprite_frames.get_animation_loop(&"jump") and visual.frame==jump_last,"nonlooping jump reaches its final drawing")
	await create_timer(.20).timeout
	check(visual.animation==&"jump" and visual.frame==jump_last and not visual.is_playing(),"finished jump holds the last drawing instead of restarting takeoff")
	check(visual.transform==sprite_transform and collision.transform==collider_transform,"holding a finished pose does not alter body transform or collision")
	visual.facing = -1.0
	visual.state = "IDLE"
	player.set_physics_process(true)
	player.facing = -1.0
	await frames(3)
	check(visual.flip_h and visual.scale==Vector2.ONE,"facing flips the complete sprite without changing body scale")
	var idle_before := visual.frame
	await frames(20)
	check(visual.animation==&"idle" and visual.frame!=idle_before,"idle advances drawings while the controller remains grounded")
	Input.action_press("move_left")
	await frames(5)
	var run_before := visual.frame
	await frames(16)
	check(visual.animation==&"run" and visual.frame!=run_before,"movement selects and advances the complete run cycle")
	Input.action_release("move_left")
	await frames(20)
	var before := game.get_child_count()
	visual.afterimage()
	check(game.get_child_count()>before,"dash afterimage is separate from the character image")
	await create_timer(.3).timeout
	check(game.get_child_count()==before,"afterimage cleans itself up")
	print("ALL ",checks," FRAME ANIMATION CHECKS PASSED")
	game.queue_free()
	await process_frame
	quit(0)
