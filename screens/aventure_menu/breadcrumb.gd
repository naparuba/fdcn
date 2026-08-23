extends PanelContainer

@onready var _breads = $VBoxContainer/breads

var _bread_scene = preload('res://ui/bread.tscn')


func _ready() -> void:
	Player.chapter_changed.connect(_on_chapter_changed)
	_refresh()


func _on_chapter_changed(_node_id) -> void:
	_refresh()


func _refresh() -> void:
	set_history(Player.get_last_visited_nodes())


func set_history(node_ids: Array) -> void:
	Utils.delete_children(_breads)
	var nb = node_ids.size()
	for i in range(nb):
		var bread = _bread_scene.instantiate()
		bread.set_chap_number(node_ids[i])
		bread.set_main(self)
		if i == 0:
			bread.set_first()
		if i == nb - 2:
			bread.set_previous()
		elif i == nb - 1:
			bread.set_current()
		else:
			bread.set_normal_color()
		_breads.add_child(bread)


# bread.gd calls self.main_obj.jump_back(chap_number) on click.
func jump_back(chap_number) -> void:
	Player.go_back_to(chap_number)
