extends SceneTree
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
	var player = load("res://Scenes/player.tscn").instantiate()
	scene.add_child(player)
	player.set_physics_process(false)
	var visual = player.visual
	visual.set_process(false)
	var combat = player.combat
	var vfx = player.get_node("GravityVFX")
	vfx.set_process(false)
	# An isolated resource fixture proves manual playback respects unequal drawing
	# durations rather than selecting int(progress*count). Actual artwork is reused.
	visual.sprite_frames = visual.sprite_frames.duplicate(true)
	visual.sprite_frames.add_animation(&"timing_fixture")
	visual.sprite_frames.set_animation_speed(&"timing_fixture",10)
	for index in range(3):
		visual.sprite_frames.add_frame(&"timing_fixture",visual.sprite_frames.get_frame_texture(&"idle",index),3.0 if index==1 else 1.0)
	visual.begin_attack(0,&"timing_fixture")
	visual.set_attack_progress(0.3)
	check(visual.frame==1,"a long anticipation drawing remains visible at 30% attack progress")
	check(is_equal_approx(visual.frame_progress,1.0/6.0),"local frame progress follows the drawing's duration")
	check(is_equal_approx(visual.frame_start_fraction(&"timing_fixture",1),.2) and is_equal_approx(visual.frame_end_fraction(&"timing_fixture",1),.8),"weighted frame boundaries expose gameplay event timing")
	visual.set_attack_progress(1.0)
	check(visual.frame==2 and is_equal_approx(visual.frame_progress,1.0),"weighted playback safely holds the final drawing")
	visual.end_attack()
	var collider: CollisionShape2D = player.get_node("CollisionShape2D")
	var original_collider := collider.transform
	var original_sprite: Transform2D = visual.transform
	for stage in range(combat.attacks.size()):
		combat.start(stage,1)
		var data = combat.attacks[stage]
		var start: float = visual.frame_start_fraction(data.animation,data.active_from_frame)
		var finish: float = visual.frame_end_fraction(data.animation,data.active_through_frame)
		check(is_equal_approx(combat.effective_active_start,data.duration*start) and is_equal_approx(combat.effective_active_end,data.duration*finish),"hitbox boundaries follow authored drawing timing for move "+str(stage))
		visual.set_attack_progress((start+finish)*.5)
		check(visual.frame>=data.active_from_frame and visual.frame<=data.active_through_frame,"active hit window displays an action/impact drawing for move "+str(stage))
		check(collider.transform==original_collider and visual.transform==original_sprite,"weighted attack leaves body and collision transforms stable")
		combat.cancel()
	var before: int = vfx.release_count
	combat.start(0,1)
	for index in range(60):
		combat.step(.01)
	check(vfx.release_count==before+1,"a complete attack emits its release VFX only once")
	var only_release := true
	for effect in vfx.effects:
		only_release = only_release and effect.kind!="impact"
	check(only_release,"a whiff does not emit a confirmed-hit flash")
	vfx.effects.clear()
	vfx.attack_release(1,player.global_position,1)
	visual.speed_scale=.1
	vfx._process(.07)
	check(vfx.effects.size()==1 and is_equal_approx(vfx.effects[0].life,.07),"VFX lifetime advances in real time during slow animation playback")
	visual.speed_scale=8
	vfx._process(.08)
	check(vfx.effects.is_empty(),"speeding up animation does not lengthen or replay a VFX event")
	var smash_before: int = vfx.smash_count
	combat.start(5,1)
	combat.on_landed()
	combat.on_landed()
	check(vfx.smash_count==smash_before+1,"smash contact emits one independent ground shockwave")
	combat.cancel()
	check(visual.sprite_frames.has_animation(&"landing"),"authored landing compression clip is installed")
	visual.state="IDLE"
	visual.motion_velocity=Vector2.ZERO
	visual.land(500)
	check(visual.animation==&"landing" and visual.landing_left>0,"ground contact plays a real landing compression drawing")
	visual.state="RUN"
	check(visual.animation==&"run" and visual.landing_left==0,"movement cancels landing animation without input lockout")
	visual.frame=3
	visual.frame_progress=.4
	visual.state="SPRINT"
	check(visual.frame==3 and is_equal_approx(visual.frame_progress,.4),"run-to-sprint transition preserves the corresponding stride pose")
	visual.state="RUN"
	check(visual.frame==3 and is_equal_approx(visual.frame_progress,.4),"releasing sprint does not pop the legs back to contact A")
	print("ALL ",checks," TIMING AND VFX CHECKS PASSED")
	scene.queue_free()
	await process_frame
	quit(0)
