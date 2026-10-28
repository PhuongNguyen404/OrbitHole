extends CharacterBody2D
signal state_changed(new_state: String)
signal melee_hit(target: Node, stage: int)
signal enemy_hit
enum State { IDLE, RUN, SPRINT, JUMP, FALL, DASH, ATTACK }
@export var run_speed := 240.0
@export var sprint_speed := 360.0
@export var acceleration := 2200.0
@export var deceleration := 2600.0
@export var air_acceleration := 1700.0
@export var jump_velocity := -580.0
@export var gravity := 1200.0
@export var coyote_time := 0.10
@export var jump_buffer_time := 0.12
@export var dash_speed := 650.0
@export var dash_duration := 0.16
@export var dash_cooldown := 0.45
var state: State = State.IDLE
var facing := 1.0
var coyote_left := 0.0
var jump_buffer_left := 0.0
var dash_left := 0.0
var cooldown_left := 0.0
var dash_direction := 1.0
var trail_left := 0.0
var landing_speed := 0.0
var spawn_position: Vector2
var camera_look_x := 0.0
var shake_left := 0.0
var shake_clock := 0.0
var enemy_invuln_left := 0.0
var enemy_knockback_left := 0.0
var enemy_hit_count := 0
var enemy_flash: Tween
@onready var visual: AnimatedSprite2D = $AnimatedSprite2D
@onready var camera: Camera2D = $Camera2D
@onready var combat: Node = $Combat
var attack_stage: int:
	get: return combat.stage
var air_attack_used: bool:
	get: return combat.air_used

func _ready() -> void:
	spawn_position = global_position
	floor_snap_length = 6.0
	floor_stop_on_slope = true
	combat.confirmed_hit.connect(_on_melee_hit)

func _physics_process(delta: float) -> void:
	enemy_invuln_left = maxf(0.0,enemy_invuln_left-delta)
	enemy_knockback_left = maxf(0.0,enemy_knockback_left-delta)
	var direction := Input.get_axis("move_left","move_right")
	if direction!=0.0 and not combat.attacking:
		facing = signf(direction)
	combat.step(delta)
	cooldown_left = maxf(0.0,cooldown_left-delta)
	coyote_left = coyote_time if is_on_floor() else maxf(0.0,coyote_left-delta)
	jump_buffer_left = maxf(0.0,jump_buffer_left-delta)
	if Input.is_action_just_pressed("jump"):
		jump_buffer_left = jump_buffer_time
		if is_on_floor():
			combat.cancel()
	if Input.is_action_just_pressed("dash") and cooldown_left<=0.0:
		combat.cancel()
		dash_left = dash_duration
		cooldown_left = dash_cooldown
		dash_direction = facing
		trail_left = 0.0
	if combat.frozen:
		_update_state()
		_update_camera(delta)
		return
	if dash_left>0.0:
		dash_left = maxf(0.0,dash_left-delta)
		velocity = Vector2(dash_direction*dash_speed,0)
		trail_left -= delta
		if trail_left<=0.0:
			visual.afterimage()
			trail_left = .035
	else:
		var gravity_scale := .78 if absf(velocity.y)<90.0 else 1.0
		velocity.y = minf(velocity.y+gravity*gravity_scale*delta,800.0)
		if jump_buffer_left>0.0 and coyote_left>0.0:
			combat.cancel()
			velocity.y = jump_velocity
			jump_buffer_left = 0.0
			coyote_left = 0.0
			floor_snap_length = 0.0
		else:
			floor_snap_length = 6.0
		if not Input.is_action_pressed("jump") and velocity.y<0.0:
			velocity.y += gravity*2.0*delta
		var target := direction*(sprint_speed if Input.is_action_pressed("sprint") else run_speed)
		if combat.attacking:
			target *= combat.movement_factor
		var rate := acceleration if is_on_floor() else air_acceleration
		if direction==0.0:
			rate = deceleration if is_on_floor() else air_acceleration*.65
		if enemy_knockback_left<=0.0:
			velocity.x = move_toward(velocity.x,target,rate*delta)
	# A context smash accelerates down after its drawn anticipation; the body
	# still uses move_and_slide and the unchanged collision shape.
	if combat.attacking and combat.stage == 5 and combat.progress > 0.30 and not is_on_floor():
		velocity.y = maxf(velocity.y, 360.0)
	var was_grounded := is_on_floor()
	landing_speed = velocity.y
	move_and_slide()
	if is_on_floor() and not was_grounded and landing_speed>120.0:
		combat.on_landed()
		visual.land(landing_speed)
	if global_position.y>720.0:
		respawn()
	_update_state()
	visual.motion_velocity = velocity
	visual.facing = facing
	_update_camera(delta)

func _update_state() -> void:
	var next := State.IDLE
	if combat.attacking:
		next = State.ATTACK
	elif dash_left>0.0:
		next = State.DASH
	elif not is_on_floor():
		next = State.JUMP if velocity.y<0.0 else State.FALL
	elif absf(velocity.x)>12.0:
		next = State.SPRINT if Input.is_action_pressed("sprint") else State.RUN
	if next!=state:
		state = next
		visual.state = State.keys()[state]
		state_changed.emit(visual.state)

func _on_melee_hit(target: Node,index: int) -> void:
	melee_hit.emit(target,index)
	if index in [2,5]:
		shake_left = .10 # Finisher confirmed hits only, never a missed swing.

func _update_camera(delta: float) -> void:
	camera_look_x = move_toward(camera_look_x,facing*36.0,delta*120.0)
	shake_left = maxf(0.0,shake_left-delta)
	shake_clock += delta
	var shake := Vector2(sin(shake_clock*97),cos(shake_clock*83))*1.4*shake_left/.10
	camera.offset = Vector2(camera_look_x,0)+shake

func respawn() -> void:
	combat.cancel()
	combat.air_used = false
	global_position = spawn_position
	velocity = Vector2.ZERO
	dash_left = 0.0
	cooldown_left = 0.0
	jump_buffer_left = 0.0
	coyote_left = 0.0
	shake_left = 0.0
	enemy_invuln_left = 0.0
	enemy_knockback_left = 0.0
	if enemy_flash!=null and enemy_flash.is_valid():
		enemy_flash.kill()
	visual.modulate = Color.WHITE
	camera.reset_smoothing()

func receive_enemy_hit(impulse: Vector2) -> bool:
	if enemy_invuln_left>0.0:
		return false
	enemy_invuln_left = 0.75
	enemy_knockback_left = 0.12
	enemy_hit_count += 1
	combat.cancel()
	velocity = impulse
	if enemy_flash!=null and enemy_flash.is_valid():
		enemy_flash.kill()
	visual.modulate = Color(1.6,0.7,0.8)
	enemy_flash = create_tween()
	enemy_flash.tween_property(visual,"modulate",Color.WHITE,0.18)
	enemy_hit.emit()
	return true
