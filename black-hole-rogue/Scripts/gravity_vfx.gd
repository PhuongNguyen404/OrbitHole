extends Node2D
## Real-time one-shot effects. No character art and no animation-progress drawing.
var effects: Array[Dictionary] = []
var release_count := 0
var smash_count := 0
@export_range(0.065,0.09) var sprint_trail_interval := 0.08
var sprint_trail_left := 0.0
var sprint_afterimages_emitted := 0
@onready var character := get_parent() as CharacterBody2D
@onready var body_sprite := get_node_or_null("../AnimatedSprite2D") as AnimatedSprite2D

func _process(delta: float) -> void:
	_update_sprint_trail(delta)
	for effect in effects:
		effect.life -= delta
	effects = effects.filter(func(effect: Dictionary) -> bool: return effect.life > 0.0)
	queue_redraw()

func _update_sprint_trail(delta: float) -> void:
	sprint_trail_left = maxf(0.0,sprint_trail_left-delta)
	var combat := get_node_or_null("../Combat")
	var sprinting: bool = character!=null and body_sprite!=null and body_sprite.get("state")=="SPRINT"
	sprinting = sprinting and character.is_on_floor() and absf(character.velocity.x)>=character.sprint_speed*0.65
	if not sprinting or (combat!=null and combat.attacking):
		sprint_trail_left = 0.0
		return
	if sprint_trail_left<=0.0:
		# One real-time snapshot at most per render frame: never catch up in a
		# burst, and never deform or modify the shared run/sprint drawings.
		body_sprite.afterimage(0.14,0.10)
		sprint_afterimages_emitted += 1
		sprint_trail_left = sprint_trail_interval

func _emit(kind: String, point: Vector2, duration: float, direction := 1.0, heavy := false) -> void:
	effects.append({"kind":kind,"world_point":point,"life":duration,"duration":duration,"direction":direction,"heavy":heavy})
	queue_redraw()

func attack_release(stage: int, point: Vector2, direction: float) -> void:
	release_count += 1
	# These are pressure trails from a deliberate animation event, not hit flashes.
	# Playback rate affects when the event happens, never the effect's lifetime.
	_emit("plunge" if stage==5 else "release",point,0.11 if stage==0 else 0.14,direction,stage==2)

func impact(point: Vector2, heavy: bool) -> void:
	# Only confirmed hit callbacks call impact. A missed swing does not flash.
	_emit("impact",point,0.16,1.0,heavy)

func land(speed: float) -> void:
	if speed>240.0:
		_emit("land",get_parent().global_position,0.12)

func smash_land(point: Vector2) -> void:
	smash_count += 1
	_emit("smash_ring",point,0.20,1.0,true)

func _draw() -> void:
	for effect in effects:
		var point := to_local(effect.world_point)
		var fade: float = clampf(effect.life/effect.duration,0.0,1.0)
		var age := 1.0-fade
		match effect.kind:
			"release":
				var direction: float = effect.direction
				var arc := PackedVector2Array()
				for i in range(9):
					var angle := -0.7+i/8.0*1.4
					arc.append(point+Vector2(cos(angle)*7*direction,sin(angle)*9))
				draw_polyline(arc,Color(0.66,0.33,1.0,fade*0.32),1.0)
			"plunge":
				for side in [-1,1]:
					var offset := Vector2(side*7.0,-8.0)
					draw_line(point+offset,point+offset+Vector2(0,-9.0),Color(0.65,0.3,1,fade*0.35),1)
			"land":
				draw_arc(point,age*10+1,PI,TAU,12,Color(0.6,0.39,0.8,fade*0.35),1)
			"smash_ring":
				# Ground-only ellipse and a few stones leave the impact silhouette clear.
				var ring := PackedVector2Array()
				for i in range(25):
					var angle := i/24.0*TAU
					ring.append(point+Vector2(cos(angle)*(4+age*26),sin(angle)*(2+age*7)))
				draw_polyline(ring,Color(0.72,0.4,1,fade*0.7),1.3)
				for i in range(4):
					var x := (-1.0 if i%2==0 else 1.0)*(4+age*(9+i*3))
					var y := -sin(age*PI)*(4+i*1.5)
					draw_rect(Rect2(point+Vector2(x,y),Vector2(1.5,1.5)),Color(0.5,0.35,0.65,fade))
			"impact":
				var radius := age*(14 if effect.heavy else 7)+2
				draw_arc(point,radius,0,TAU,20,Color(0.85,0.46,1,fade*0.8),1.0)
				draw_line(point-Vector2(2,0),point+Vector2(2,0),Color(1,0.8,1,fade),1.5)
