extends "res://addons/gut/test.gd"

# Test d'integration sur le raccourci "Saut" (1/100/200/.../600) de l'ecran
# "Tous les chapitres", via le VRAI main.tscn (necessite les 606 vrais
# ChapterChoice construits par insert_all_chapters()).

var _main = null


func before_all():
	AppParameters.set_book_number(1)
	Player.insert_all_objects()
	Player.launch_new_billy()

	var main_scene = load("res://main.tscn")
	_main = main_scene.instantiate()
	add_child(_main)
	# Le VBoxContainer des 606 ChapterChoice n'a pas encore calcule ses
	# positions (rect_position.y reste a 0 tant qu'un passage de layout ne
	# s'est pas produit) : attendre quelques frames avant de s'y fier.
	for i in range(5):
		await get_tree().idle_frame


func after_all():
	_main.free()


func _expected_scroll_y_for(centaine):
	var all_choices = _main.get_node("Chapitres/AllChapters/VScrollBar/Choices")
	for choice in all_choices.get_children():
		if choice.get_chapter_id() >= centaine:
			return choice.position.y
	return null


func test_jump_to_1_scrolls_to_the_first_chapter():
	_main.jump_to_chapter_1()
	var scroll_bar = _main.get_node("Chapitres/AllChapters/VScrollBar")
	assert_eq(scroll_bar.scroll_vertical, _expected_scroll_y_for(1))


func test_jump_to_100_scrolls_to_the_right_chapter():
	_main.jump_to_chapter_100()
	var scroll_bar = _main.get_node("Chapitres/AllChapters/VScrollBar")
	assert_eq(scroll_bar.scroll_vertical, _expected_scroll_y_for(100))


func test_jump_to_600_scrolls_further_than_jump_to_100():
	_main.jump_to_chapter_100()
	var scroll_after_100 = _main.get_node("Chapitres/AllChapters/VScrollBar").scroll_vertical
	_main.jump_to_chapter_600()
	var scroll_after_600 = _main.get_node("Chapitres/AllChapters/VScrollBar").scroll_vertical
	assert_true(scroll_after_600 > scroll_after_100)


func test_all_seven_shortcuts_do_not_crash():
	# Verifie non seulement l'absence de crash, mais que chaque raccourci
	# scrolle bien au bon endroit ET que les sept destinations sont
	# strictement croissantes (sinon un raccourci pourrait silencieusement
	# ne rien faire, ou tous pointer par coincidence au meme endroit, sans
	# qu'aucune assertion ne le remarque).
	var scroll_bar = _main.get_node("Chapitres/AllChapters/VScrollBar")
	var centaines = [1, 100, 200, 300, 400, 500, 600]
	var precedent = null
	for centaine in centaines:
		_main.call("jump_to_chapter_%d" % centaine)
		# scroll_vertical est un Range -- toute valeur au-dela de
		# max_value-page est automatiquement clampee par le moteur (cas du
		# dernier chapitre, trop proche de la fin de la liste pour que sa
		# position.y brute soit atteignable) : on compare donc a la meme
		# valeur clampee, pas a choice.position.y brut.
		var v_scroll_bar = scroll_bar.get_v_scroll_bar()
		var attendu = clampf(_expected_scroll_y_for(centaine), v_scroll_bar.min_value, v_scroll_bar.max_value - v_scroll_bar.page)
		assert_eq(scroll_bar.scroll_vertical, attendu, "jump_to_chapter_%d scrolle au mauvais endroit" % centaine)
		if precedent != null:
			assert_true(scroll_bar.scroll_vertical > precedent,
				"jump_to_chapter_%d devrait scroller plus loin que le raccourci precedent" % centaine)
		precedent = scroll_bar.scroll_vertical
