extends CharacterBody2D
## 可通过鼠标左键点击地面移动的角色。

@export var speed: float = 120.0
@export var stop_distance: float = 4.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var _target_position: Vector2
var _has_target: bool = false


func _ready() -> void:
	_target_position = global_position


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			_target_position = get_global_mouse_position()
			_has_target = true


func _physics_process(_delta: float) -> void:
	if not _has_target:
		_set_animation(&"idle")
		return

	var to_target := _target_position - global_position
	var distance := to_target.length()

	if distance <= stop_distance:
		_has_target = false
		velocity = Vector2.ZERO
		_set_animation(&"idle")
		move_and_slide()
		return

	var direction := to_target / distance
	velocity = direction * speed
	_update_facing(direction)
	_set_animation(&"run")
	move_and_slide()


func _update_facing(direction: Vector2) -> void:
	if absf(direction.x) > 0.01:
		animated_sprite.flip_h = direction.x < 0.0


func _set_animation(animation_name: StringName) -> void:
	if animated_sprite.animation != animation_name:
		animated_sprite.play(animation_name)
