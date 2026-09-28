extends "res://addons/gut/test.gd"

# Equivalent de test_bookdata.gd, sur les vraies donnees du livre 2. Se
# concentre sur la logique de BookData.gd (matching de conditions, stats de
# chapitre conditionnelles, donnees d'objet) -- l'application reelle cote
# Player (aquire/remove/stats via go_to_node) est dans
# test_player_stats_book2.gd.
#
# Fixtures reelles du livre 2 :
# - noeud 450 : stats inconditionnelles {'pv':3} + 1 stats_cond sur le type
#   de Billy DEBROUILLARD ({'deg':1})
# - noeud 10 -> 338 : condition simple sur un objet (KHAZIN)
# - noeud 175 -> 49 : condition en $or sur 3 objets (ARC, PIOCHE, LANCE)
# - objet "ARC" : stats {'adr':1, 'crit':4, 'hab':3} -- toutes des cles
#   gerees par le systeme de stats d'objet (cf player.gd::_recompute_stats)

func before_all():
	AppParameters.set_book_number(2)
	Player.insert_all_objects()


func after_all():
	AppParameters.set_book_number(1)  # ne pas polluer les fichiers suivants


func before_each():
	Player.launch_new_billy()
	Player.visited_nodes_all_times = []  # launch_new_billy() ne le remet pas a zero
	AppParameters.set_billy_type('pegu')
	Player._recompute_matched_conditions()
	Player._recompute_stats()


func test_get_item_data_returns_expected_stats():
	var data = BookData.get_item_data('ARC')
	assert_eq_deep(data['stats'], {'adr': 1, 'crit': 4, 'hab': 3})


func test_exists_item_data():
	assert_true(BookData.exists_item_data('ARC'))
	assert_false(BookData.exists_item_data('OBJET QUI NEXISTE PAS'))


func test_get_chapter_stats_unconditional_only():
	var r = BookData.get_chapter_stats(450)
	assert_eq_deep(r['stats'], {'pv': 3})
	assert_eq(len(r['stats_conds']), 0)


func test_get_chapter_stats_applies_only_the_matching_billy_condition():
	AppParameters.set_billy_type('debrouillard')
	Player._recompute_matched_conditions()
	var r = BookData.get_chapter_stats(450)
	assert_eq_deep(r['stats_conds'], [{'deg': 1}])


func test_get_chapter_stats_no_condition_matches_for_pegu():
	AppParameters.set_billy_type('pegu')
	Player._recompute_matched_conditions()
	var r = BookData.get_chapter_stats(450)
	assert_eq(r['stats_conds'], [])


func test_match_chapter_conditions_false_without_the_item():
	assert_false(BookData.match_chapter_conditions(10, 338))


func test_match_chapter_conditions_true_once_item_is_possessed():
	Player.add_item_from_options('KHAZIN')
	assert_true(BookData.match_chapter_conditions(10, 338))


func test_match_chapter_conditions_or_false_without_any_of_the_items():
	assert_false(BookData.match_chapter_conditions(175, 49))


func test_match_chapter_conditions_or_true_with_just_one_of_the_items():
	Player.add_item_from_options('PIOCHE')  # $or: ARC, PIOCHE ou LANCE
	assert_true(BookData.match_chapter_conditions(175, 49))


# PHOBIE-ADMINISTRATIVE est le seul succes du livre 2 obtenable a deux
# chapitres (98 et 498, cf fdcn-2-compilated-success-chapters.json) --
# fixture reelle, pas construite a la main, pour couvrir le vrai cas.
func test_get_deduped_success_keeps_a_single_row_for_a_multi_chapter_success():
	var deduped = BookData.get_deduped_success()
	var ids = []
	for success in deduped:
		ids.append(success['id'])
	var occurrences = ids.count('PHOBIE-ADMINISTRATIVE')
	assert_eq(occurrences, 1, "PHOBIE-ADMINISTRATIVE ne doit apparaitre qu'une fois apres dedup")
	# Aucun autre succes du livre 2 ne doit avoir ete perdu au passage --
	# le dedup ne doit retirer QUE les vrais doublons.
	var raw_unique_ids = {}
	for success in BookData.get_all_success():
		raw_unique_ids[success['id']] = true
	assert_eq(deduped.size(), raw_unique_ids.size(), "un id par succes distinct, ni plus ni moins")


func test_is_success_obtenu_true_via_the_chapter_not_shown_on_the_row():
	# Bug reel : Success.gd::update() ne regardait QUE le chapitre affiche
	# sur la ligne courante -- obtenu via l'AUTRE chapitre associe au meme
	# succes doit aussi compter.
	Player.visited_nodes_all_times.append(498)
	assert_true(BookData.is_success_obtenu('PHOBIE-ADMINISTRATIVE'))


func test_is_success_obtenu_false_when_neither_chapter_was_visited():
	assert_false(BookData.is_success_obtenu('PHOBIE-ADMINISTRATIVE'))
