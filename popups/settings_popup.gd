extends Panel

@onready var content_container = $ContentContainer

var scene_inventory: PackedScene = preload("res://popups/sub/Inventory.tscn")
var scene_stats: PackedScene = preload("res://popups/sub/Stats.tscn")
var scene_books: PackedScene = preload("res://popups/sub/BookSelection.tscn")

var current_instance: Node = null

func _ready():
	$Header/VBoxContainer/TabInventory/Button.pressed.connect(func(): _show_scene(scene_inventory))
	$Header/VBoxContainer/TabStats/button.pressed.connect(func(): _show_scene(scene_stats))
	$Header/VBoxContainer/TabSelectBook/button.pressed.connect(func(): _show_scene(scene_books))

	# Load default tab on open
	_show_scene(scene_inventory)

func _show_scene(scene: PackedScene):
	if current_instance:
		current_instance.queue_free()
	
	current_instance = scene.instantiate()
	content_container.add_child(current_instance)
