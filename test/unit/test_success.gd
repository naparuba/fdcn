extends "res://addons/gut/test.gd"

var SuccessScene = preload('res://Success.tscn')

const REAL_SUCCESS = {'chapter': 26, 'id': 'POLIR-LANCE', 'label': 'Polir la lance?', 'txt': 'Vous avez choisi la Femme-Lezard'}

func before_each():
	AppParameters.set_book_number(1)
	Player.launch_new_billy()
	Player.visited_nodes_all_times = []  # launch_new_billy() ne le remet pas a zero
	AppParameters.set_spoils(true)


func after_each():
	AppParameters.set_spoils(true)


func test_set_from_success_object_fills_all_fields():
	var s = SuccessScene.instance()
	s.set_from_success_object(REAL_SUCCESS)
	assert_eq(s.get_chapter_id(), 26)
	assert_eq(s.get_node('Label').text, 'Polir la lance?')
	assert_eq(s.get_node('Txt').text, 'Vous avez choisi la Femme-Lezard')
	s.free()


func test_set_success_id_loads_a_real_image():
	var s = SuccessScene.instance()
	s.set_success_id('POLIR-LANCE')
	assert_not_null(s.get_node('sprite').texture)
	s.free()


func test_set_success_id_unknown_gives_null_texture():
	var s = SuccessScene.instance()
	s.set_success_id('CECI_NEXISTE_PAS')
	assert_null(s.get_node('sprite').texture)
	s.free()


func test_hide_chapter_hides_chapter_widgets():
	var s = SuccessScene.instance()
	s.hide_chapter()
	assert_false(s.get_node('NBChapitre').visible)
	assert_false(s.get_node('click').visible)
	s.free()


func test_update_marks_already_seen_when_chapter_was_visited():
	var s = SuccessScene.instance()
	s.set_chapitre(26)
	Player.visited_nodes_all_times.append(26)
	s.update()
	assert_eq(s.get_node('GetPolygon').color, Color('00c2aa'))
	s.free()


func test_update_marks_not_already_seen_when_chapter_was_never_visited():
	var s = SuccessScene.instance()
	s.set_chapitre(26)
	s.update()
	assert_eq(s.get_node('GetPolygon').color, Color('9ea8b4'))
	s.free()
