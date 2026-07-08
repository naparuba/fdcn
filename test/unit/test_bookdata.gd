extends "res://addons/gut/test.gd"

# Fixtures reelles du livre 1 (fdcn-1-compilated-*.json), choisies pour
# leurs proprietes precises :
# - noeud 10: condition de saut simple ("184" necessite KIT D'ESCALADE),
#   sons 461/530 sans condition
# - noeud 16: condition en $or (MORGENSTERN ou GUERRIER) vers 294
# - noeud 126: stats conditionnelles sur le type de Billy
# - noeud 13: secret
# - "Cathedrale": nom d'arc reel (chapitre au sens BookData) avec 73 noeuds
# - success "POLIR-LANCE" sur le chapitre 26

func before_all():
	AppParameters.set_book_number(1)
	Player.insert_all_objects()


func before_each():
	Player.launch_new_billy()
	Player.visited_nodes_all_times = []  # launch_new_billy() ne le remet pas a zero
	AppParameters.set_billy_type('pegu')
	Player._recompute_matched_conditions()
	Player._recompute_stats()


func test_get_node_returns_matching_chapter_data():
	var node = BookData.get_node(10)
	assert_eq(node.get_id(), 10)


func test_get_all_objects_contains_known_item():
	var all_objects = BookData.get_all_objects()
	assert_true(all_objects.has('EPEE'))


func test_exists_item_data():
	assert_true(BookData.exists_item_data('EPEE'))
	assert_false(BookData.exists_item_data('OBJET QUI NEXISTE PAS'))


func test_get_item_data_returns_expected_stats():
	var data = BookData.get_item_data('EPEE')
	assert_eq_deep(data['stats'], {'hab': 4.0})


func test_is_node_id_secret():
	assert_true(BookData.is_node_id_secret(13))
	assert_false(BookData.is_node_id_secret(1))


func test_have_chapter_conditions_true_when_condition_exists():
	assert_true(BookData.have_chapter_conditions(10, 184))


func test_have_chapter_conditions_false_when_no_condition():
	assert_false(BookData.have_chapter_conditions(10, 461))


func test_get_condition_txt_returns_readable_text():
	assert_eq(BookData.get_condition_txt(10, 184), "KIT D'ESCALADE")


func test_get_condition_txt_empty_when_no_condition():
	assert_eq(BookData.get_condition_txt(10, 461), '')


func test_match_chapter_conditions_false_without_the_item():
	assert_false(BookData.match_chapter_conditions(10, 184))


func test_match_chapter_conditions_true_once_item_is_possessed():
	Player.add_item_from_options("KIT D'ESCALADE")
	assert_true(BookData.match_chapter_conditions(10, 184))


func test_match_chapter_conditions_or_matches_on_billy_type():
	AppParameters.set_billy_type('guerrier')
	Player._recompute_matched_conditions()
	assert_true(BookData.match_chapter_conditions(16, 294),
		"condition = MORGENSTERN ou GUERRIER, le type Billy doit suffire")


func test_match_chapter_conditions_or_matches_on_item_alone():
	AppParameters.set_billy_type('pegu')
	Player.add_item_from_options('MORGENSTERN')
	assert_true(BookData.match_chapter_conditions(16, 294))


func test_get_chapter_stats_unconditional_only():
	var r = BookData.get_chapter_stats(128)  # {'end': 1}, pas de stats_cond
	assert_eq_deep(r['stats'], {'end': 1.0})
	assert_eq(r['stats_conds'], [])


func test_get_chapter_stats_applies_only_the_matching_billy_condition():
	AppParameters.set_billy_type('guerrier')
	Player._recompute_matched_conditions()
	var r = BookData.get_chapter_stats(126)
	assert_eq_deep(r['stats_conds'], [{'hab': 1.0}])


func test_get_chapter_stats_no_condition_matches_for_pegu():
	AppParameters.set_billy_type('pegu')
	Player._recompute_matched_conditions()
	var r = BookData.get_chapter_stats(126)
	assert_eq(r['stats_conds'], [])


func test_get_acte_completion_zero_when_nothing_visited():
	var pct = BookData.get_acte_completion(7, [])  # noeud 7 est dans l'arc "Cathedrale"
	assert_eq(pct, 0)


func test_get_acte_completion_full_when_all_visited():
	var other_nodes = BookData.get_all_nodes_in_the_same_chapter(7)
	assert_true(len(other_nodes) > 0)
	var pct = BookData.get_acte_completion(7, other_nodes)
	assert_eq(pct, 100)


func test_get_success_txt_known_and_unknown():
	assert_eq(BookData.get_success_txt('POLIR-LANCE'), 'Vous avez choisi la Femme-Lézard')
	assert_eq(BookData.get_success_txt('CECI_NEXISTE_PAS'), '')


func test_is_success_chapter():
	assert_true(BookData.is_success_chapter(26))
	assert_false(BookData.is_success_chapter(1))


func test_get_success_from_chapter():
	var success = BookData.get_success_from_chapter(26)
	assert_eq(success['id'], 'POLIR-LANCE')


func test_is_node_id_freely_showable_true_when_spoils_ok():
	AppParameters.set_spoils(true)
	assert_true(BookData.is_node_id_freely_showable(13, []))


func test_is_node_id_freely_showable_false_for_unseen_secret_without_spoils():
	AppParameters.set_spoils(false)
	assert_false(BookData.is_node_id_freely_showable(13, []))
	AppParameters.set_spoils(true)  # restore pour ne pas polluer les autres tests


func test_is_node_id_freely_showable_true_for_secret_already_seen():
	AppParameters.set_spoils(false)
	Player.visited_nodes_all_times.append(13)
	assert_true(BookData.is_node_id_freely_showable(13, []))
	AppParameters.set_spoils(true)


func test_is_node_id_freely_showable_true_for_non_secret_without_spoils():
	AppParameters.set_spoils(false)
	assert_true(BookData.is_node_id_freely_showable(1, []))
	AppParameters.set_spoils(true)
