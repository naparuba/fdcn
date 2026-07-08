extends Node

# Double minimal de main.gd pour tester les widgets qui lui delegue des
# actions (swipe.gd, top_menu.gd) sans avoir a instancier tout main.tscn.

var calls = []


func _record(name, arg=null):
	self.calls.append([name, arg])


func print_debug(s):
	_record('print_debug', s)

func jump_to_previous_chapter():
	_record('jump_to_previous_chapter')

func go_to_node(node_id):
	_record('go_to_node', node_id)

func jump_back(chapter_id):
	_record('jump_back', chapter_id)

func set_camera_to_pos(x):
	_record('set_camera_to_pos', x)

func update_page_in_top_menus(page):
	_record('update_page_in_top_menus', page)

func change_spoils(b):
	_record('change_spoils', b)

func change_sound(b):
	_record('change_sound', b)

func _switch_to_guerrier():
	_record('_switch_to_guerrier')

func _switch_to_paysan():
	_record('_switch_to_paysan')

func _switch_to_prudent():
	_record('_switch_to_prudent')

func _switch_to_debrouillard():
	_record('_switch_to_debrouillard')

func _on_option_btn_pressed():
	_record('_on_option_btn_pressed')
