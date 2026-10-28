extends CharacterBody2D
## One small, deliberately limited enemy: approaches, telegraphs, swipes, dies.
signal defeated
@export var max_health := 40
@export var move_speed := 72.0
@export var detection_range := 280.0
@export var attack_range := 50.0
@export var attack_windup := 0.36
@export var attack_cooldown := 1.1
var health := 40
var facing := -1.0
var windup_left := 0.0
var strike_left := 0.0
var cooldown_left := 0.0
var stagger_left := 0.0
var hitstop_left := 0.0
var flash_left := 0.0
var attack_connected := false
var dead := false
var push_velocity := 0.0
var player: CharacterBody2D
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var strike: Area2D = $Strike
@onready var strike_shape: CollisionShape2D = $Strike/CollisionShape2D

func _ready() -> void:
	health = max_health
	add_to_group("crystal_enemies")
	player = get_parent().get_node_or_null("Player") as CharacterBody2D
	strike.body_entered.connect(_try_strike)
	floor_snap_length = 5.0

func _physics_process(delta: float) -> void:
	flash_left = maxf(0,flash_left-delta)
	sprite.modulate = Color(1.7,1.7,1.9) if flash_left>0 else Color.WHITE
	if hitstop_left>0:
		hitstop_left = maxf(0,hitstop_left-delta)
		if hitstop_left<=0:
			sprite.play(sprite.animation)
		queue_redraw()
		return
	cooldown_left = maxf(0,cooldown_left-delta)
	stagger_left = maxf(0,stagger_left-delta)
	velocity.y = minf(velocity.y+1200.0*delta,650.0)
	push_velocity = move_toward(push_velocity,0,680.0*delta)
	var travel := 0.0
	if dead:
		_play(&"dead")
	elif stagger_left>0:
		_play(&"hurt")
		windup_left = 0
		strike_left = 0
		_close_strike()
	elif windup_left>0:
		windup_left = maxf(0,windup_left-delta)
		_play(&"idle")
		sprite.modulate = Color(1.0,0.78,0.40)
		if windup_left<=0:
			strike_left = 0.13
			attack_connected = false
			strike.position.x = facing*27.0
			strike_shape.set_deferred("disabled",false)
	elif strike_left>0:
		strike_left = maxf(0,strike_left-delta)
		_play(&"swipe")
		for body in strike.get_overlapping_bodies():
			_try_strike(body)
		if strike_left<=0:
			_close_strike()
			cooldown_left = attack_cooldown
	else:
		var difference := player.global_position-global_position if is_instance_valid(player) else Vector2(INF,INF)
		if absf(difference.x)<detection_range and absf(difference.y)<70:
			if absf(difference.x)>5:
				facing = signf(difference.x)
			if absf(difference.x)<=attack_range and absf(difference.y)<45 and cooldown_left<=0:
				windup_left = attack_windup
			elif absf(difference.x)>attack_range*.75 and _safe_step(facing):
				travel = facing*move_speed
		_play(&"walk" if travel!=0 else &"idle")
	velocity.x = travel+push_velocity
	move_and_slide()
	sprite.flip_h = facing<0
	queue_redraw()

func _safe_step(direction: float) -> bool:
	if not is_on_floor():
		return false
	var start := global_position+Vector2(direction*24,-7)
	var floor_ray := PhysicsRayQueryParameters2D.create(start,start+Vector2(0,32),1,[get_rid()])
	if get_world_2d().direct_space_state.intersect_ray(floor_ray).is_empty():
		return false
	return not test_move(global_transform,Vector2(direction*5,0))

func _play(animation: StringName) -> void:
	if sprite.animation!=animation:
		sprite.play(animation)
	elif not sprite.is_playing() and sprite.sprite_frames.get_animation_loop(animation):
		sprite.play(animation)

func _try_strike(body: Node) -> void:
	if dead or strike_left<=0 or stagger_left>0 or attack_connected or not body.has_method("receive_enemy_hit"):
		return
	var ray := PhysicsRayQueryParameters2D.create(global_position+Vector2(0,-24),body.global_position+Vector2(0,-24),1,[get_rid()])
	if not get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
		return
	attack_connected = body.receive_enemy_hit(Vector2(facing*260,-135))

func _close_strike() -> void:
	strike_shape.set_deferred("disabled",true)

func receive_attack(damage: int,impulse: Vector2,stagger: float,_point: Vector2) -> bool:
	if dead:
		return false
	health = maxi(0,health-damage)
	flash_left = 0.11
	stagger_left = maxf(stagger,0.12)
	windup_left = 0
	strike_left = 0
	_close_strike()
	push_velocity = clampf(impulse.x*0.65,-240,240)
	velocity.y = minf(velocity.y,impulse.y*0.6)
	if health==0:
		dead = true
		collision_layer = 0
		push_velocity *= 0.3
		_play(&"dead")
		defeated.emit()
	return true

func apply_gravity_pull(origin: Vector2,impulse: float) -> void:
	if not dead:
		push_velocity += signf(origin.x-global_position.x)*impulse*.7

func apply_hitstop(seconds: float) -> void:
	hitstop_left = maxf(hitstop_left,seconds)
	sprite.pause()

func _draw() -> void:
	if not dead and health<max_health:
		draw_rect(Rect2(-18,-57,36,3),Color("1a3340"))
		draw_rect(Rect2(-18,-57,36*float(health)/max_health,3),Color("78dfde"))
	if windup_left>0:
		var progress := 1.0-windup_left/attack_windup
		draw_arc(Vector2.ZERO,16,-PI, -PI+PI*progress,16,Color("f8bd64"),1.3)

func get_combat_target_point() -> Vector2:
	return global_position+Vector2(0,-24)
