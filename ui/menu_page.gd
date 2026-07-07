extends Control

@export var scenes: Array[PackedScene] = []

var current_index: int = 0
var current_scene_instance: Node = null

@onready var scene_container = $SceneContainer

# Swipe detection
var drag_start_pos: Vector2 = Vector2.ZERO
var is_dragging: bool = false
@export var swipe_threshold: float = 100.0  # min px distance to count as swipe

func _ready():
	_load_scene(current_index)
	$NavLeft._on_nav_pressed.connect(func(): _change_page(-1))
	$NavRight._on_nav_pressed.connect(func(): _change_page(1))

func _load_scene(index: int):
	if current_scene_instance:
		current_scene_instance.queue_free()
	current_scene_instance = scenes[index].instantiate()
	scene_container.add_child(current_scene_instance)

func _change_page(direction: int):
	print("hello")
	current_index = wrapi(current_index + direction, 0, scenes.size())
	_load_scene(current_index)

# --- Swipe input handling ---
func _input(event):
	if event is InputEventScreenTouch:
		if event.pressed:
			drag_start_pos = event.position
			is_dragging = true
		else:
			if is_dragging:
				_check_swipe(event.position)
			is_dragging = false
	elif event is InputEventScreenDrag:
		pass  # could add live drag feedback here (parallax, page preview slide)

func _check_swipe(end_pos: Vector2):
	var delta_x = end_pos.x - drag_start_pos.x
	if abs(delta_x) >= swipe_threshold:
		if delta_x > 0:
			_change_page(-1)  # swiped right → go to previous
		else:
			_change_page(1)   # swiped left → go to next
