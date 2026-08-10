extends Panel
## Inventory view — one Item row per object in the book.
##
## This builds and owns the rows. `Inventory` holds the data only, so opening
## this popup several times can no longer duplicate anything.

@onready var items_panel = $ItemsCont/Items

var _item_scene: PackedScene = preload('res://entities/Item.tscn')


func _ready() -> void:
	Inventory.items_changed.connect(_on_items_changed)
	_build_rows()


func _build_rows() -> void:
	Utils.delete_children(items_panel)
	var all_objects = BookData.get_all_objects()
	for item_name in Inventory.get_visible_item_names():
		var item = _item_scene.instantiate()
		items_panel.add_child(item)
		item.load_item_data(item_name, all_objects[item_name])


func _on_items_changed() -> void:
	for item in items_panel.get_children():
		item.refresh()
