extends PanelContainer

signal chapter_selected(chap_number)

@onready var _breads = $VBoxContainer/breads

var _bread_scene = preload('res://ui/bread.tscn')


func set_history(node_ids: Array) -> void:
	Utils.delete_children(_breads)
	var nb = len(node_ids)
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
	chapter_selected.emit(chap_number)
