extends "res://addons/gut/test.gd"

# Test d'integration sur le declenchement du SuccessPopup a l'entree d'un
# chapitre succes SANS que ce soit aussi une fin (cf test/e2e pour le cas
# combine succes+fin, qui a son propre piege de timing). Noeud 26 du livre
# 1 : success="POLIR-LANCE", ending=false.

var _main = null

const SUCCESS_ONLY_NODE = 26


func before_all():
	AppParameters.set_book_number(1)
	Player.insert_all_objects()
	Player.launch_new_billy()

	var main_scene = load("res://main.tscn")
	_main = main_scene.instance()
	add_child(_main)


func after_all():
	_main.free()


func before_each():
	Player.visited_nodes_all_times = []
	_main.get_node("SuccessPopup").hide()


func test_first_visit_of_a_success_chapter_shows_the_popup_with_the_right_content():
	assert_false(_main.get_node("SuccessPopup").visible)
	_main.go_to_node(SUCCESS_ONLY_NODE)
	assert_true(_main.get_node("SuccessPopup").visible)
	var inner = _main.get_node("SuccessPopup/wholebackground/PanelBorder/Success")
	assert_eq(inner.get_chapter_id(), SUCCESS_ONLY_NODE)
	assert_eq(inner.get_node("Label").text, 'Polir la lance?')
	assert_eq(inner.get_node("Txt").text, 'Vous avez choisi la Femme-Lézard')


func test_revisiting_an_already_seen_success_chapter_does_not_retrigger_the_popup():
	_main.go_to_node(SUCCESS_ONLY_NODE)
	assert_true(_main.get_node("SuccessPopup").visible)
	_main.get_node("SuccessPopup").hide()

	_main.go_to_node(1)  # bouger ailleurs
	_main.go_to_node(SUCCESS_ONLY_NODE)  # revisite : plus "nouveau" pour ce Billy

	assert_false(_main.get_node("SuccessPopup").visible,
		"un chapitre succes deja vu ne doit pas re-declencher le popup")


func test_a_new_billy_does_not_resee_the_popup_for_a_chapter_already_seen_all_time():
	# Contrairement a l'intuition initiale : le "is_new_node" qui
	# declenche _check_new_success() dans main.gd est base sur
	# Player.visited_nodes_all_times (jamais reset), PAS sur
	# session_visited_nodes (reset par launch_new_billy). Un nouveau Billy
	# qui repasse par un chapitre succes deja vu par un Billy precedent ne
	# reverra donc PAS le popup -- comportement voulu (un succes debloque
	# une fois reste debloque), verrouille explicitement ici.
	_main.go_to_node(SUCCESS_ONLY_NODE)
	_main.get_node("SuccessPopup").hide()

	Player.launch_new_billy()
	_main.go_to_node(SUCCESS_ONLY_NODE)

	assert_false(_main.get_node("SuccessPopup").visible)
