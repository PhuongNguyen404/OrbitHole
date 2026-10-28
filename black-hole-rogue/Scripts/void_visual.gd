extends Node2D
## Generated Sprite2D parts, authored AnimationPlayer poses, secondary gravity motion.
const NODE_NAMES := {"hips":"Pelvis","chest":"Torso","head":"Head","ring":"AccretionRing",
	"arm_front":"LeftUpperArm","forearm_front":"LeftForearm","hand_front":"LeftHand",
	"arm_back":"RightUpperArm","forearm_back":"RightForearm","hand_back":"RightHand",
	"thigh_front":"LeftLeg","shin_front":"LeftShin","foot_front":"LeftFoot",
	"thigh_back":"RightLeg","shin_back":"RightShin","foot_back":"RightFoot"}
const RATES := {"IDLE":8.0,"RUN":12.0,"SPRINT":14.0,"JUMP":8.0,"FALL":8.0,"DASH":14.0,"ATTACK":24.0}
var state := "IDLE":
	set(value):
		if state != value:
			state = value
			animation_time = 0.0
var facing := 1.0
var animation_time := 0.0
var orbit_time := 0.0
var motion_velocity := Vector2.ZERO
var previous_velocity := Vector2.ZERO
var body_drag := Vector2.ZERO
var attack_stage := 0
var attack_progress := -1.0
var attack_paused := false
var attacking := false
var landing_left := 0.0
var landing_weight := 0.0
var bones: Dictionary = {}
var anchors: Dictionary = {}
var art_origins: Dictionary = {}
var sampled_rotations: Dictionary = {}
var fragments: Array[Sprite2D] = []
var fragment_homes: Array[Vector2] = []
var trails: Array[Vector2] = []
var impacts: Array[Dictionary] = []
@onready var rig: Node2D = $Rig

func _ready() -> void:
	for id in NODE_NAMES:
		var bone: Node2D = rig.get_node(NODE_NAMES[id])
		bones[id] = bone
		anchors[id] = bone.position
		art_origins[id] = bone.get_node("Art").position
	# Small debris uses a real piece of the generated stone atlas, not fake limb art.
	for i in range(7):
		var stone := Sprite2D.new()
		stone.texture = bones["hand_front"].get_node("Art").texture
		stone.scale = Vector2.ONE * (0.008 if i % 2 == 0 else 0.006)
		stone.modulate = Color("ac83bf")
		rig.get_node("FloatingFragments").add_child(stone)
		fragments.append(stone)
		fragment_homes.append(Vector2(-19 if i%2==0 else 19,-68+i*9))

func begin_attack(index: int) -> void:
	attacking = true
	attack_stage = index
	attack_progress = 0.0
	trails.clear()
	state = "ATTACK"

func end_attack() -> void:
	attacking = false
	attack_progress = -1.0
	trails.clear()

func land(speed: float) -> void:
	landing_left = 0.20
	landing_weight = clampf(speed/650.0,0.25,1.0)

func _process(delta: float) -> void:
	for effect in impacts:
		effect.life -= delta
	impacts = impacts.filter(func(effect: Dictionary) -> bool: return effect.life > 0.0)
	if not attack_paused:
		animation_time += delta
		orbit_time += delta
		landing_left = maxf(0.0,landing_left-delta)
		if not attacking:
			_locomotion(delta)
		_secondary(delta)
	rig.scale.x = facing
	if not attacking or _grounded():
		_plant_feet()
	else:
		rig.position.y = move_toward(rig.position.y,0.0,delta*60.0)
	queue_redraw()

func _locomotion(delta: float) -> void:
	var phase: float = animation_time*TAU*(RATES[state]/8.0 if state in ["RUN","SPRINT"] else 1.5)
	var gait := sin(phase)
	var moving := state in ["RUN","SPRINT"]
	var pose: Dictionary = {}
	var positions: Dictionary = anchors.duplicate()
	for id in bones:
		pose[id] = 0.0
	var compression := sin((1.0-landing_left/.20)*PI)*landing_weight if landing_left>0 else 0.0
	var acceleration := (motion_velocity-previous_velocity)/maxf(delta,.001)
	previous_velocity = motion_velocity
	body_drag = body_drag.lerp(Vector2(clampf(-acceleration.x*facing*.0004,-1.4,1.4),compression*1.8),1.0-exp(-delta*10))
	if moving:
		var stride := .58 if state=="RUN" else .82
		pose["hips"] = .04
		pose["chest"] = (.08 if state=="RUN" else .19)+sin(phase-.4)*.04
		pose["head"] = -.08+sin(phase-.8)*.025
		pose["thigh_front"] = gait*stride
		pose["thigh_back"] = -gait*stride
		pose["shin_front"] = -pow(maxf(0,sin(phase-.45)),1.5)*1.05-compression*.15
		pose["shin_back"] = -pow(maxf(0,-sin(phase-.45)),1.5)*1.05-compression*.15
		pose["arm_front"] = -sin(phase-.22)*stride*.8
		pose["arm_back"] = sin(phase-.22)*stride*.8
		pose["forearm_front"] = -.25-maxf(0,-gait)*.5
		pose["forearm_back"] = -.25-maxf(0,gait)*.5
	elif state=="JUMP":
		pose.merge({"chest":-.10,"head":.08,"thigh_front":-.55,"shin_front":-.55,
			"thigh_back":.4,"shin_back":-.85,"arm_front":-.7,"forearm_front":-.65,"arm_back":.5,"forearm_back":-.5},true)
	elif state=="FALL":
		pose.merge({"chest":.05,"thigh_front":-.20,"shin_front":-.3,"thigh_back":.3,"shin_back":-.35,
			"arm_front":.65,"forearm_front":-.6,"arm_back":-.6,"forearm_back":-.5},true)
	elif state=="DASH":
		pose.merge({"chest":.48,"head":-.3,"thigh_front":-.45,"shin_front":-.4,
			"thigh_back":.6,"shin_back":-.7,"arm_front":.9,"forearm_front":-.3,"arm_back":.8,"forearm_back":-.4},true)
	else:
		pose["chest"] = sin(orbit_time*1.8)*.018
		pose["head"] = -pose["chest"]
		pose["arm_front"] = sin(orbit_time*1.5)*.025
		pose["arm_back"] = -pose["arm_front"]
	positions["hips"] += body_drag
	positions["chest"] += body_drag+Vector2(0,sin(orbit_time*1.8)*.35)
	positions["head"] += body_drag*.3+Vector2(0,sin(orbit_time*1.8-.5)*.8)
	positions["ring"] = positions["head"]
	pose["ring"] = pose["head"]
	# Forward kinematics keeps elbows, knees and wrists coherent in locomotion.
	for side in ["front","back"]:
		var arm: String = "arm_"+side
		var forearm: String = "forearm_"+side
		var hand: String = "hand_"+side
		positions[arm] += body_drag
		positions[forearm] = positions[arm]+Vector2(0,13).rotated(pose[arm])
		pose[forearm] += pose[arm]
		positions[hand] = positions[forearm]+Vector2(0,14).rotated(pose[forearm])
		pose[hand] = pose[forearm]*.7
		var thigh: String = "thigh_"+side
		var shin: String = "shin_"+side
		var foot: String = "foot_"+side
		positions[thigh] += body_drag
		positions[shin] = positions[thigh]+Vector2(0,13).rotated(pose[thigh])
		pose[shin] += pose[thigh]
		positions[foot] = positions[shin]+Vector2(0,12).rotated(pose[shin])
		pose[foot] = -pose[shin]*.2
	sampled_rotations = pose
	var blend := 1.0-exp(-delta*22.0)
	for id in bones:
		bones[id].position = bones[id].position.lerp(positions[id],blend)
		bones[id].rotation = lerp_angle(bones[id].rotation,pose[id],blend)

func _secondary(_delta: float) -> void:
	var power := sin(clampf(attack_progress,0,1)*PI) if attacking else 0.0
	for id in bones:
		var art: Sprite2D = bones[id].get_node("Art")
		var drift := Vector2.ZERO
		if id in ["head","chest"] and not attacking:
			drift.y = sin(orbit_time*1.8+(0.8 if id=="head" else 0))*.25
		art.position = art_origins[id]+drift
		art.modulate = Color.WHITE
	var head_art: Sprite2D = bones["head"].get_node("Art")
	head_art.modulate = Color(1+power*.3,1+power*.2,1+power*.5)
	var ring_art: Sprite2D = bones["ring"].get_node("Art")
	# Independent corona motion; no neck or scaling of the head/body.
	ring_art.rotation = sin(orbit_time*1.7)*.09 + (power*.65 if attacking and attack_stage==2 else 0.0)
	ring_art.modulate = Color(1+power*.5,1+power*.15,1+power*.4)
	for i in range(fragments.size()):
		var phase := orbit_time*1.6+i*1.4
		var home := fragment_homes[i]
		var drift := Vector2(sin(phase)*1.5,cos(phase)*2)
		if attacking:
			var inward := sin(clampf(attack_progress*2,0,1)*PI)
			drift += (Vector2(0,-67)-home)*inward*(.25 if attack_stage==2 else .08)
			drift.x -= power*(3.0 if attack_stage==3 else 1.0)
		elif state in ["SPRINT","DASH"]:
			drift.x -= 3.0
		elif state=="FALL":
			drift.y -= 2.0
		fragments[i].position = home+drift
		fragments[i].rotation = phase*.25
	if attacking and attack_progress>.2 and attack_progress<.7:
		var trail_bone: Node2D = bones["hand_back"] if attack_stage==1 else bones["head"] if attack_stage==3 else bones["hand_front"]
		trails.append(rig.to_local(trail_bone.global_position)+rig.position)
		if trails.size()>7:
			trails.pop_front()
	elif not trails.is_empty():
		trails.pop_front()

func _plant_feet() -> void:
	var lowest := -INF
	for id in ["foot_front","foot_back"]:
		var art: Sprite2D = bones[id].get_node("Art")
		var rect := art.get_rect()
		for point in [rect.position,rect.end,Vector2(rect.position.x,rect.end.y),Vector2(rect.end.x,rect.position.y)]:
			lowest = maxf(lowest,rig.to_local(art.to_global(point)).y)
	rig.position.y = -lowest

func _grounded() -> bool:
	var parent := get_parent() as CharacterBody2D
	return parent!=null and parent.is_on_floor()

func afterimage() -> void:
	var ghost := rig.duplicate() as Node2D
	get_tree().current_scene.add_child(ghost)
	ghost.global_transform = rig.global_transform
	ghost.modulate = Color(.65,.25,1,.38)
	ghost.z_index = 15
	var tween := ghost.create_tween()
	tween.tween_property(ghost,"modulate:a",0.0,.20)
	tween.tween_callback(ghost.queue_free)

func impact(point: Vector2,heavy: bool) -> void:
	impacts.append({"point":to_local(point),"life":.18,"heavy":heavy})

func _draw() -> void:
	if trails.size()>1:
		var points := PackedVector2Array()
		for point in trails:
			points.append(Vector2(point.x*facing,point.y))
		draw_polyline(points,Color(.72,.32,1,.55),1.3)
	if attacking and attack_stage==2 and attack_progress<.44:
		for i in range(6):
			var angle := i*TAU/6.0+attack_progress*13
			var radius := lerpf(34,4,clampf(attack_progress/.44,0,1))
			var point := Vector2(cos(angle)*radius*facing,-67+sin(angle)*radius*.6)
			draw_line(point,point+Vector2(-cos(angle)*3*facing,-sin(angle)*3),Color(.7,.35,1,.55),1)
	for effect in impacts:
		var fade: float = effect.life/.18
		var radius := (1-fade)*(18 if effect.heavy else 9)+2
		draw_arc(effect.point,radius,0,TAU,24,Color(.85,.45,1,fade),1.2)
		draw_line(effect.point-Vector2(3,0),effect.point+Vector2(3,0),Color(1,.8,1,fade),2)
		if effect.heavy:
			for i in range(5):
				var offset := Vector2(cos(i*2.4),sin(i*2.4))*(1-fade)*20
				draw_rect(Rect2(effect.point+offset,Vector2(1.5,1.5)),Color(.5,.35,.65,fade))
