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
	var s = SuccessScene.instantiate()
	s.set_from_success_object(REAL_SUCCESS)
	assert_eq(s.get_chapter_id(), 26)
	assert_eq(s.get_node('Label').text, 'Polir la lance?')
	assert_eq(s.get_node('Txt').text, 'Vous avez choisi la Femme-Lezard')
	s.free()


func test_set_success_id_loads_a_real_image():
	var s = SuccessScene.instantiate()
	s.set_success_id('POLIR-LANCE')
	assert_not_null(s.get_node('sprite').texture)
	s.free()


func test_set_success_id_unknown_gives_null_texture():
	var s = SuccessScene.instantiate()
	s.set_success_id('CECI_NEXISTE_PAS')
	assert_null(s.get_node('sprite').texture)
	s.free()


func test_hide_chapter_hides_chapter_widgets():
	var s = SuccessScene.instantiate()
	s.hide_chapter()
	assert_false(s.get_node('NBChapitre').visible)
	assert_false(s.get_node('click').visible)
	s.free()


func test_update_marks_already_seen_when_chapter_was_visited():
	var s = SuccessScene.instantiate()
	s.set_chapitre(26)
	s.set_success_id('POLIR-LANCE')
	Player.visited_nodes_all_times.append(26)
	s.update()
	assert_eq(s.get_node('GetPolygon').color, Color('00c2aa'))
	s.free()


func test_update_marks_not_already_seen_when_chapter_was_never_visited():
	var s = SuccessScene.instantiate()
	s.set_chapitre(26)
	s.set_success_id('POLIR-LANCE')
	s.update()
	assert_eq(s.get_node('GetPolygon').color, Color('9ea8b4'))
	s.free()


func test_update_marks_already_seen_via_a_different_chapter_than_the_one_displayed():
	# Bug reel trouve sur cdsi "PHOBIE-ADMINISTRATIVE" (obtenable aux
	# chapitres 98 ET 498) : une ligne qui affiche le chapitre 98 doit
	# quand meme passer "obtenu" si le joueur l'a eu via 498 -- jamais
	# seulement le chapitre affiche sur CETTE ligne precise.
	AppParameters.set_book_number(2)
	var s = SuccessScene.instantiate()
	s.set_chapitre(98)
	s.set_success_id('PHOBIE-ADMINISTRATIVE')
	Player.visited_nodes_all_times.append(498)  # vu via l'AUTRE chapitre
	s.update()
	assert_eq(s.get_node('GetPolygon').color, Color('00c2aa'), "obtenu via 498 doit marquer la ligne 98 comme obtenue")
	s.free()
	AppParameters.set_book_number(1)
