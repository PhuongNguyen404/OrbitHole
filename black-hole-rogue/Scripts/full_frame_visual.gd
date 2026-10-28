extends AnimatedSprite2D
## The body is always one complete authored frame. Only frame selection and flip
## happen here; this node never rotates, stretches, or assembles separate limbs.
var state := "IDLE":
	set(value):
		if state != value:
			state = value
			_select_locomotion()
var facing := 1.0:
	set(value):
		facing = -1.0 if value < 0.0 else 1.0
		flip_h = facing < 0.0
var motion_velocity := Vector2.ZERO
var attack_stage := -1
var attack_progress := -1.0
var attacking := false
var _resume_after_hitstop := false
var attack_paused := false:
	set(value):
		if attack_paused == value:
			return
		attack_paused = value
		if attack_paused:
			_resume_after_hitstop = is_playing() and not attacking
			pause()
		elif not attacking and _resume_after_hitstop:
			play(animation)
			_resume_after_hitstop = false
var attack_animation: StringName

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_select_locomotion()
	if not is_playing() and sprite_frames != null:
		play(animation)

func _select_locomotion() -> void:
	if attacking or sprite_frames == null:
		return
	var next := StringName(state.to_lower())
	if next == &"attack" or not sprite_frames.has_animation(next):
		next = &"idle"
	if animation != next:
		play(next)

func begin_attack(index: int, clip: StringName) -> void:
	attacking = true
	attack_stage = index
	attack_animation = clip
	attack_progress = 0.0
	if sprite_frames != null and sprite_frames.has_animation(clip):
		animation = clip
		pause()
		frame = 0

func set_attack_progress(value: float) -> void:
	attack_progress = value
	if not attacking or sprite_frames == null or not sprite_frames.has_animation(attack_animation):
		return
	# The combat clock pauses on confirmed-hit hitstop, so the whole character
	# holds the same impact drawing while the Area2D active window also pauses.
	var count := sprite_frames.get_frame_count(attack_animation)
	if count > 0:
		frame = mini(count - 1, int(clampf(value, 0.0, 1.0) * count))
		frame_progress = 0.0

func end_attack() -> void:
	attacking = false
	attack_stage = -1
	attack_progress = -1.0
	attack_animation = &""
	_select_locomotion()

func land(speed: float) -> void:
	var vfx := get_node_or_null("../GravityVFX")
	if vfx != null:
		vfx.land(speed)

func impact(point: Vector2, heavy: bool) -> void:
	var vfx := get_node_or_null("../GravityVFX")
	if vfx != null:
		vfx.impact(point, heavy)

func afterimage() -> void:
	if sprite_frames == null or sprite_frames.get_frame_count(animation) == 0:
		return
	var ghost := Sprite2D.new()
	ghost.texture = sprite_frames.get_frame_texture(animation, frame)
	ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ghost.flip_h = flip_h
	ghost.offset = offset
	get_tree().current_scene.add_child(ghost)
	ghost.global_transform = global_transform
	ghost.modulate = Color(0.66, 0.28, 1.0, 0.32)
	ghost.z_index = 15
	var tween := ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.16)
	tween.tween_callback(ghost.queue_free)
