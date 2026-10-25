extends "res://addons/gut/test.gd"

# Equivalent de test_chapter_data.gd, mais sur les VRAIES donnees du livre 2
# (fdcn-2-compilated-*.json). Le but : chapter_data.gd/BookData.gd sont du
# code generique (aucune branche "if book == 1"), donc en theorie les memes
# getters marchent pour n'importe quel livre -- mais seul un test avec de
# vraies fixtures livre 2 le verrouille reellement (le livre 2 a un schema
# de stats different du livre 1 : 'chance_max'/'richesse'/'pv' au lieu de
# 'end'/'hab'/'deg', voir test_player_stats_book2.gd pour les consequences
# cote Player).
#
# Fixtures reelles du livre 2 :
# - noeud 102 : noeud "vide" de controle (aucun effet daucune sorte)
# - noeud 11  : combat simple (dict), pyro=4 (meme forme que le livre 1)
# - noeud 51  : aquire non vide (1 seul objet)
# - noeud 522 : remove non vide (1 seul objet)
# - noeud 100 : a un label ("Acte I, L'Exode")
# - noeud 335 : secret
# - noeud 13  : success ("GRAND-FAN")
# - noeud 10  : sons + jump_conditions sur des OBJETS (KHAZIN/PLOUF), pas
#   sur un type de Billy -- contrairement au livre 1 ou l'exemple choisi
#   (noeud 10 aussi, coincidence) conditionne sur un objet ("KIT D'ESCALADE")
# - noeud 450 : stats inconditionnelles {'pv':3} + 1 stats_cond sur le type
#   de Billy DEBROUILLARD ({'deg':1}) -- cf test_player_stats_book2.gd pour
#   la verification de l'application reelle
# - noeud 32  : fin reelle, ending_id="COUDE", ending_type=2 (mauvaise fin)

func before_all():
	AppParameters.set_book_number(2)


func after_all():
	AppParameters.set_book_number(1)  # ne pas polluer les fichiers suivants


func test_get_id():
	assert_eq(BookData.get_chapter_data(11).get_id(), 11)


func test_combat_simple_dict():
	var node = BookData.get_chapter_data(11)
	assert_true(node.is_combat())
	assert_eq(node.get_combat_name(), 'SERGENT ET TROUFION')
	assert_eq(node.get_combat_hab(), 5.0)
	assert_eq(node.get_combat_pv(), 9.0)
	assert_eq(node.get_combat_armure(), 1.0)
	assert_eq(node.get_combat_degat(), 0.0)
	assert_eq(node.get_combat_pyro(), 4)


func test_non_combat_node():
	var node = BookData.get_chapter_data(102)
	assert_false(node.is_combat())


func test_aquire_and_remove():
	assert_eq(BookData.get_chapter_data(51).get_aquire(), ['GRI-GRI'])
	assert_eq(BookData.get_chapter_data(522).get_remove(), ['GOURDE SCELLEE'])
	assert_eq(BookData.get_chapter_data(102).get_aquire(), [])
	assert_eq(BookData.get_chapter_data(102).get_remove(), [])


func test_label():
	assert_eq(BookData.get_chapter_data(100).get_label(), "Acte I, L'Exode")
	assert_null(BookData.get_chapter_data(102).get_label())


func test_secret_flag():
	assert_true(BookData.get_chapter_data(335).get_secret())
	assert_false(BookData.get_chapter_data(102).get_secret())


func test_success_field():
	assert_eq(BookData.get_chapter_data(13).get_success(), 'GRAND-FAN')
	assert_null(BookData.get_chapter_data(102).get_success())


func test_sons_list():
	var sons = BookData.get_chapter_data(10).get_sons()
	assert_eq_deep(sons, [338, 378])


func test_jump_conditions_and_txts():
	# Contrairement au livre 1 (condition sur un type de Billy dans son
	# exemple equivalent), ici les deux conditions portent sur des OBJETS
	# (KHAZIN, PLOUF) -- verrouille que _check_cond_rec()/le format $end
	# marche pour les deux cas indifferemment (voir player.gd::
	# get_all_matched_conditions, qui melange objets possedes + type de
	# Billy en majuscules dans la meme liste).
	var node = BookData.get_chapter_data(10)
	assert_eq_deep(node.get_jump_conditions(), {
		'338': {'$end': 'KHAZIN'},
		'378': {'$end': 'PLOUF'},
	})
	assert_eq_deep(node.get_jump_conditions_txts(), {'338': 'KHAZIN', '378': 'PLOUF'})


func test_stats_and_stats_cond():
	assert_eq_deep(BookData.get_chapter_data(450).get_stats(), {'pv': 3})
	assert_eq(len(BookData.get_chapter_data(450).get_stats_cond()), 1)
	assert_eq(BookData.get_chapter_data(102).get_stats(), {})
	assert_eq(BookData.get_chapter_data(102).get_stats_cond(), [])


func test_ending_fields_on_a_non_ending_node():
	var node = BookData.get_chapter_data(102)
	assert_false(node.get_ending())
	assert_null(node.get_ending_id())
	assert_null(node.get_ending_type())


func test_ending_fields_on_a_real_ending_node():
	var node = BookData.get_chapter_data(32)  # mauvaise fin, ending_id="COUDE"
	assert_true(node.get_ending())
	assert_eq(node.get_ending_id(), 'COUDE')
	assert_eq(node.get_ending_type(), 2.0)


func test_secret_jumps():
	var node = BookData.get_chapter_data(102)
	assert_eq(node.get_secret_jumps(), [])
