extends RigidBody2D
## Stationary, spring-anchored training dummy. Health, stagger, no AI.
@export var max_health := 160
var health := 160
var home: Vector2
var hit_count := 0
var damage_log: Array[int] = []
var flash := 0.0
var stagger_left := 0.0
var clock := 0.0
var reset_left := 0.0
var last_damage := 0
var number_left := 0.0
var art: Node2D
var hitstop_left := 0.0
var held_velocity := Vector2.ZERO
var held_position := Vector2.ZERO
var teleport_pending := false
var reset_position := Vector2.ZERO

func _ready() -> void:
	name = "TrainingDummy"
	collision_layer = 4
	collision_mask = 1
	gravity_scale = 0.0
	mass = 3.0
	linear_damp = 6.0
	lock_rotation = true
	z_index = 12
	health = max_health
	home = global_position
	var shape := CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	capsule.radius = 13.0
	capsule.height = 52.0
	shape.shape = capsule
	add_child(shape)
	art = Node2D.new()
	add_child(art)
	_add_art(Rect2(351,37,266,274),Vector2(0,2),.069)
	_add_art(Rect2(63,61,208,224),Vector2(0,-18),.042)

func _add_art(region: Rect2,point: Vector2,size: float) -> void:
	var sprite := Sprite2D.new()
	var texture := AtlasTexture.new()
	texture.atlas = preload("res://Assets/VoidConstruct/body_parts.png")
	texture.region = region
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.position = point
	sprite.scale = Vector2.ONE*size
	art.add_child(sprite)

func _physics_process(delta: float) -> void:
	clock += delta
	flash = maxf(0.0,flash-delta*6)
	stagger_left = maxf(0.0,stagger_left-delta)
	number_left = maxf(0.0,number_left-delta)
	if hitstop_left>0.0:
		hitstop_left = maxf(0,hitstop_left-delta)
		if hitstop_left<=0.0:
			linear_velocity = held_velocity
	elif not teleport_pending:
		apply_central_force((home-global_position)*(55.0 if stagger_left<=0 else 12.0))
	if health<=0:
		reset_left -= delta
		if reset_left<=0:
			reset_to(home)
	art.visible = health>0
	art.modulate = Color(.72,.68,.78).lerp(Color(1.7,1.0,2.0),flash)
	art.rotation = sin(clock*35)*stagger_left*.16
	queue_redraw()

func apply_gravity_pull(origin: Vector2,impulse: float) -> void:
	if health>0:
		apply_central_impulse(global_position.direction_to(origin)*impulse)

func receive_attack(damage: int,impulse: Vector2,stagger: float,_point: Vector2) -> bool:
	if health<=0:
		return false
	health = maxi(0,health-damage)
	hit_count += 1
	damage_log.append(damage)
	last_damage = damage
	flash = 1.0
	number_left = .55
	stagger_left = stagger
	apply_central_impulse(impulse)
	if health==0:
		reset_left = 2.0
	return true

func _draw() -> void:
	draw_line(Vector2(0,20),home-global_position+Vector2(0,29),Color(.4,.3,.5,.5),1)
	draw_arc(Vector2(0,29),16,0,PI,16,Color("806391"),1)
	draw_rect(Rect2(-21,-40,42,3),Color("292037"))
	draw_rect(Rect2(-21,-40,42*float(health)/max_health,3),Color("c38be8"))
	var font := ThemeDB.fallback_font
	draw_string(font,Vector2(-37,-47),"VOID DUMMY",HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("c5a5d5"))
	if number_left>0:
		draw_string(font,Vector2(17,-16-(1-number_left/.55)*9),str(last_damage),HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color(1,.7,1,number_left/.55))
	if health==0:
		draw_string(font,Vector2(-28,-10),"REFORMING",HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("c5a5d5"))

func apply_hitstop(seconds: float) -> void:
	if hitstop_left<=0.0:
		held_velocity = linear_velocity
		held_position = global_position
	hitstop_left = maxf(hitstop_left,seconds)

func reset_to(point: Vector2) -> void:
	home = point
	reset_position = point
	teleport_pending = true
	health = max_health
	hitstop_left = 0.0
	held_velocity = Vector2.ZERO
	linear_velocity = Vector2.ZERO
	sleeping = false

func _integrate_forces(body_state: PhysicsDirectBodyState2D) -> void:
	if teleport_pending:
		body_state.transform = Transform2D(0.0,reset_position)
		body_state.linear_velocity = Vector2.ZERO
		teleport_pending = false
		return
	# Keep the body dynamic so Area2D overlap monitoring stays valid during hitstop.
	if hitstop_left>0.0:
		body_state.linear_velocity = Vector2.ZERO
		body_state.transform = Transform2D(0.0,held_position)
