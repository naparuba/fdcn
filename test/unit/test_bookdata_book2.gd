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
