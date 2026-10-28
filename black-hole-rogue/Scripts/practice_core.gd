extends RigidBody2D
## An anchored training prop, not an enemy: reacts to pull and real melee hits.
var home: Vector2
var hit_count := 0
var last_stage := -1
var flash := 0.0
var clock := 0.0

func _ready() -> void:
	name = "PracticeCore"
	collision_layer = 4
	collision_mask = 1
	gravity_scale = 0.0
	mass = 1.5
	linear_damp = 4.0
	lock_rotation = true
	z_index = 12
	home = global_position
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 15.0
	shape.shape = circle
	add_child(shape)

func _physics_process(delta: float) -> void:
	clock += delta
	flash = maxf(0.0,flash - delta * 3.0)
	apply_central_force((home - global_position) * 28.0)
	queue_redraw()

func apply_gravity_pull(origin: Vector2, impulse: float) -> void:
	apply_central_impulse(global_position.direction_to(origin) * impulse)

func receive_melee_hit(impulse: Vector2, stage: int) -> void:
	hit_count += 1
	last_stage = stage
	flash = 1.0
	apply_central_impulse(impulse)

func _draw() -> void:
	draw_circle(Vector2.ZERO,19,Color(0.52,0.25,0.8,0.12 + flash * 0.2))
	draw_colored_polygon(PackedVector2Array([Vector2(-12,-12),Vector2(7,-15),Vector2(16,-3),Vector2(10,13),Vector2(-9,14),Vector2(-16,0)]),Color("463655").lerp(Color("f2ceff"),flash))
	draw_circle(Vector2.ZERO,7,Color("090610"))
	draw_arc(Vector2.ZERO,9,clock,clock+TAU*0.8,20,Color("ca83ff"),1.5)
	var font := ThemeDB.fallback_font
	draw_string(font,Vector2(-50,-30),"PRACTICE CORE",HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("bba1d0"))
	if hit_count > 0:
		draw_string(font,Vector2(-23,37),str(hit_count)+" HITS",HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("e2bfff"))
