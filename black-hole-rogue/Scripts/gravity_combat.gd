extends Node
## Owns combo timing, a real Area2D, and confirmed-hit feedback. Never moves Player.
signal attack_started(stage: int)
signal confirmed_hit(target: Node, stage: int)
@export var attacks: Array[Resource] = []
@export_range(0.2,1.5) var combo_reset_time := 0.7
@export_range(0.0,0.5) var buffer_open_fraction := 0.12
@export_range(0.5,1.0) var buffer_close_fraction := 0.98
@export_range(0.0,1.0) var movement_multiplier := 0.28
@export var pull_radius := 105.0
@export_range(1,6) var basic_combo_count := 3
@export_range(0.2,2.0) var smash_hold_limit := 1.0
@export_range(0.34,0.49) var smash_plunge_fraction := 0.46
var smash_hold_elapsed := 0.0
var release_fired := false
var smash_landed := false
var effective_active_start := 0.0
var effective_active_end := 0.0
var effective_plunge_fraction := 0.46
var stage := -1
var elapsed := 0.0
var queued := false
var next_stage := 0
var idle_left := 0.0
var hitstop_left := 0.0
var frozen := false
var direction := 1.0
var active := false
var struck: Dictionary = {}
var air_used := false
@onready var character: CharacterBody2D = get_parent()
@onready var hitbox: Area2D = $"../AttackHitbox"
@onready var hit_shape: CollisionShape2D = $"../AttackHitbox/CollisionShape2D"
@onready var visual: AnimatedSprite2D = $"../AnimatedSprite2D"
var attacking: bool:
	get: return stage >= 0
var movement_factor: float:
	get:
		if stage == 3:
			return 0.72
		if stage == 4:
			return 0.85
		return movement_multiplier
var progress: float:
	get: return elapsed / attacks[stage].duration if attacking else 0.0

func _ready() -> void:
	hitbox.body_entered.connect(_try_hit)

func step(delta: float) -> void:
	if character.is_on_floor():
		air_used = false
	idle_left = maxf(0.0,idle_left-delta)
	if not attacking and idle_left <= 0.0:
		next_stage = 0
	if Input.is_action_just_pressed("attack"):
		if attacking:
			if stage < basic_combo_count - 1 and progress >= buffer_open_fraction and progress <= buffer_close_fraction:
				queued = true # One slot: extra presses cannot skip a stage.
		elif character.is_on_floor() or not air_used:
			var selected := next_stage
			if character.dash_left > 0.0:
				selected = 4
			elif not character.is_on_floor():
				selected = 5
			elif Input.is_action_pressed("sprint") and absf(character.velocity.x) > character.run_speed * 0.8:
				selected = 3
			start(selected,character.facing)
			if not character.is_on_floor():
				air_used = true
	frozen = hitstop_left > 0.0
	visual.attack_paused = frozen
	if frozen:
		hitstop_left = maxf(0.0,hitstop_left-delta)
		return
	if not attacking:
		return
	var attack := attacks[stage] as GravityAttack
	elapsed += delta
	if stage == 5 and not smash_landed and not character.is_on_floor() and elapsed >= attack.duration * effective_plunge_fraction and smash_hold_elapsed < smash_hold_limit:
		# Hold the authored plunge drawing until contact; physical descent keeps
		# running, so a smash from a high jump does not recover in mid-air.
		smash_hold_elapsed += delta
		elapsed = attack.duration * effective_plunge_fraction
	# Complete drawn frames and the active window use the same clock.
	visual.set_attack_progress(progress)
	_set_active(elapsed >= effective_active_start and elapsed < effective_active_end)
	if not release_fired and elapsed >= effective_active_start:
		release_fired = true
		visual.attack_release(stage, hitbox.global_position, direction)
	if attack.pull_strength > 0.0 and elapsed < attack.pull_end:
		_pull(attack,delta)
	if active:
		for target in hitbox.get_overlapping_bodies():
			_try_hit(target)
	if elapsed >= attack.duration:
		var follow := queued and stage < basic_combo_count-1
		var following := stage+1
		next_stage = (stage+1) % basic_combo_count if stage < basic_combo_count else 0
		_finish()
		if follow:
			start(following,direction)

func start(index: int, facing: float) -> void:
	stage = clampi(index,0,attacks.size()-1)
	direction = facing
	elapsed = 0.0
	smash_hold_elapsed = 0.0
	release_fired = false
	smash_landed = false
	queued = false
	struck.clear()
	var attack := attacks[stage] as GravityAttack
	effective_active_start = attack.duration * visual.frame_start_fraction(attack.animation, attack.active_from_frame)
	effective_active_end = attack.duration * visual.frame_end_fraction(attack.animation, attack.active_through_frame)
	effective_plunge_fraction = visual.frame_middle_fraction(attack.animation, 2) if stage == 5 else smash_plunge_fraction
	var shape: Shape2D
	match attack.shape_type:
		1:
			var capsule := CapsuleShape2D.new()
			capsule.radius = attack.size.y * 0.5
			capsule.height = maxf(attack.size.x,attack.size.y)
			shape = capsule
		2:
			var circle := CircleShape2D.new()
			circle.radius = attack.size.x * 0.5
			shape = circle
		_:
			var rectangle := RectangleShape2D.new()
			rectangle.size = attack.size
			shape = rectangle
	hit_shape.shape = shape
	hit_shape.rotation = PI*0.5 if attack.shape_type == 1 else 0.0
	hitbox.position = Vector2(attack.reach.x*direction,attack.reach.y)
	_set_active(false)
	visual.begin_attack(stage,attack.animation)
	visual.facing = direction
	attack_started.emit(stage)

func on_landed() -> void:
	if stage != 5 or smash_landed:
		return
	smash_landed = true
	var attack := attacks[stage] as GravityAttack
	# Contact advances from the held airborne drawing into the actual impact
	# drawing. Ground shockwave is a separate one-shot effect, not baked art.
	elapsed = maxf(elapsed, attack.duration * visual.frame_start_fraction(attack.animation, 3))
	visual.set_attack_progress(progress)
	_set_active(elapsed >= effective_active_start and elapsed < effective_active_end)
	# A very low smash may reach ground before its airborne release event.
	# The contact shockwave replaces that skipped pressure trail.
	release_fired = true
	visual.smash_land(character.global_position)

func _set_active(value: bool) -> void:
	if active == value:
		return
	active = value
	hit_shape.set_deferred("disabled",not value)

func _finish() -> void:
	_set_active(false)
	stage = -1
	queued = false
	idle_left = combo_reset_time
	visual.end_attack()

func cancel() -> void:
	if attacking:
		_finish()
	next_stage = 0
	idle_left = 0.0
	hitstop_left = 0.0
	frozen = false
	visual.attack_paused = false

func _clear_sight(point: Vector2) -> bool:
	var origin := character.global_position + Vector2(0,-48)
	var ray := PhysicsRayQueryParameters2D.create(origin,point,1,[character.get_rid()])
	return character.get_world_2d().direct_space_state.intersect_ray(ray).is_empty()

func _target_point(target: Node2D) -> Vector2:
	# Characters place their origin at the feet; aiming there would raycast into
	# the floor and incorrectly reject a valid body hit. Props keep center origins.
	return target.get_combat_target_point() if target.has_method("get_combat_target_point") else target.global_position

func _try_hit(target: Node) -> void:
	if not attacking or not active or struck.has(target.get_instance_id()) or not target.has_method("receive_attack"):
		return
	if not _clear_sight(_target_point(target)):
		return
	var attack := attacks[stage] as GravityAttack
	var impulse := Vector2(attack.knockback.x*direction,attack.knockback.y)
	if not target.receive_attack(attack.damage,impulse,attack.stagger,hitbox.global_position):
		return
	struck[target.get_instance_id()] = true
	hitstop_left = maxf(hitstop_left,attack.hitstop)
	if target.has_method("apply_hitstop"):
		target.apply_hitstop(attack.hitstop)
	visual.impact(hitbox.global_position,stage in [2,5])
	confirmed_hit.emit(target,stage)

func _pull(attack: GravityAttack,delta: float) -> void:
	var circle := CircleShape2D.new()
	circle.radius = pull_radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	var center := character.global_position + Vector2(attack.reach.x*direction if stage in [1,2] else 0.0,-48)
	query.transform = Transform2D(0.0,center)
	query.collision_mask = 4
	for result in character.get_world_2d().direct_space_state.intersect_shape(query):
		var target: Node = result.collider
		if target.has_method("apply_gravity_pull") and _clear_sight(_target_point(target)):
			target.apply_gravity_pull(center,delta*attack.pull_strength)
