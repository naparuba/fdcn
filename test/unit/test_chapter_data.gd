extends "res://addons/gut/test.gd"

# Fixtures reelles du livre 1 :
# - noeud 14 : combat simple (dict), pyro=4 (bonus allie non nul)
# - noeud 276 : combat sous forme de LISTE (2 adversaires) -- cas special
#   gere par chapter_data.gd::_get_combat() (retourne combat[0])
# - noeud 112 : aquire non vide
# - noeud 166 : remove non vide
# - noeud 10 : a un label ("Tour nord")
# - noeud 13 : secret
# - noeud 26 : success ("POLIR-LANCE")
# - noeud 184 : fils conditionnel de 10 (condition "KIT D'ESCALADE")

func before_all():
	AppParameters.set_book_number(1)


func test_get_id():
	assert_eq(BookData.get_chapter_data(14).get_id(), 14.0)


func test_combat_simple_dict():
	var node = BookData.get_chapter_data(14)
	assert_true(node.is_combat())
	assert_eq(node.get_combat_name(), 'GUERRIERS ORCS')
	assert_eq(node.get_combat_hab(), 5.0)
	assert_eq(node.get_combat_pv(), 8.0)
	assert_eq(node.get_combat_armure(), 0.0)
	assert_eq(node.get_combat_degat(), 0.0)
	assert_eq(node.get_combat_pyro(), 4.0)


func test_combat_as_list_returns_first_entry():
	# cf le commentaire "TODO: the 276 is a list" dans chapter_data.gd --
	# le noeud 276 est justement l'exemple qui a motive ce cas special.
	var node = BookData.get_chapter_data(276)
	assert_true(node.is_combat())
	assert_eq(node.get_combat_name(), 'GUARDES CORROMPUS')
	assert_eq(node.get_combat_hab(), 6.0)


func test_non_combat_node():
	var node = BookData.get_chapter_data(1)
	assert_false(node.is_combat())


func test_aquire_and_remove():
	assert_eq(BookData.get_chapter_data(112).get_aquire(), ["PALAIS DES PLAISIRS D'YTIA"])
	assert_eq(BookData.get_chapter_data(166).get_remove(), ["PHILTRE D'AMOUR"])
	assert_eq(BookData.get_chapter_data(1).get_aquire(), [])
	assert_eq(BookData.get_chapter_data(1).get_remove(), [])


func test_label():
	assert_eq(BookData.get_chapter_data(10).get_label(), 'Tour nord')
	assert_null(BookData.get_chapter_data(1).get_label())


func test_secret_flag():
	assert_true(BookData.get_chapter_data(13).get_secret())
	assert_false(BookData.get_chapter_data(1).get_secret())


func test_success_field():
	assert_eq(BookData.get_chapter_data(26).get_success(), 'POLIR-LANCE')
	assert_null(BookData.get_chapter_data(1).get_success())


func test_sons_list():
	# les ids viennent du JSON compile -> ce sont des float (184.0), pas des int
	var sons = BookData.get_chapter_data(10).get_sons()
	assert_eq_deep(sons, [184.0, 461.0, 530.0])


func test_jump_conditions_and_txts():
	var node = BookData.get_chapter_data(10)
	assert_eq_deep(node.get_jump_conditions(), {'184': {'$end': "KIT D'ESCALADE"}})
	assert_eq_deep(node.get_jump_conditions_txts(), {'184': "KIT D'ESCALADE"})


func test_stats_and_stats_cond():
	assert_eq_deep(BookData.get_chapter_data(128).get_stats(), {'end': 1.0})
	assert_eq(BookData.get_chapter_data(128).get_stats_cond(), [])
	assert_eq(len(BookData.get_chapter_data(126).get_stats_cond()), 4)


func test_ending_fields_on_a_non_ending_node():
	var node = BookData.get_chapter_data(1)
	assert_false(node.get_ending())
	assert_null(node.get_ending_id())
	assert_null(node.get_ending_txt())
	assert_null(node.get_ending_type())


func test_ending_fields_on_a_real_ending_node():
	var node = BookData.get_chapter_data(163)  # bad ending, ending_id="TULIPES"
	assert_true(node.get_ending())
	assert_eq(node.get_ending_id(), 'TULIPES')
	assert_eq(node.get_ending_type(), 2.0)


func test_secret_jumps():
	var node = BookData.get_chapter_data(1)
	assert_eq(node.get_secret_jumps(), [])
