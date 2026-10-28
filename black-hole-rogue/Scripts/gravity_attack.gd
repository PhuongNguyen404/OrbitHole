class_name GravityAttack
extends Resource
## One attack's editable gameplay timing; clip keyframes live in gravity_melee.tres.
@export var title := ""
@export var animation: StringName
@export_range(0.1,2.0) var duration := 0.28
@export var active_start := 0.075
@export var active_end := 0.13
@export var damage := 8
@export var knockback := Vector2(80,-20)
@export var stagger := 0.08
@export var hitstop := 0.022
@export var reach := Vector2(35,-48)
@export var size := Vector2(36,20)
@export_enum("Rectangle","Capsule","Circle") var shape_type := 0
@export var pull_strength := 0.0
@export var pull_end := 0.0
