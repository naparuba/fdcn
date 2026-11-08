extends "res://addons/gut/test.gd"

# Equivalent de test_bookdata_book2.gd pour le livre 3 (La lance de Valkar) :
# donnees compilees, Billy, seuils de stats (LUCIDITE>=N...) et stats d'objet.
#
# Fixtures reelles du livre 3 :
# - noeud 98  : stats {'impulsion': 1}, aquire ['RAT BEAUFORT'], goto 225
# - noeud 633 : aquire BRASSARDS + 4 autres objets
# - noeud 822 : condition "ELUSIF|SIFFLET ETRANGE|LUCIDITE>=6" vers 584
# - noeud 875 : conditions "RICHESSE>=4" vers 717 et "RICHESSE>=8" vers 787

func before_all():
	AppParameters.set_book_number(3)
	Player.insert_all_objects()


func after_all():
	AppParameters.set_book_number(1)  # ne pas polluer les fichiers suivants


func before_each():
	Player.launch_new_billy()
	Player.visited_nodes_all_times = []
	AppParameters.set_billy_type('pegu')
	Player._recompute_matched_conditions()
	Player._recompute_stats()


func test_book3_is_loaded_with_all_chapters_but_404():
	var nodes = BookData.get_all_nodes()
	assert_eq(len(nodes), 877)
	assert_true(nodes.has('1'))
	assert_true(nodes.has('878'))
	assert_false(nodes.has('404'))


func test_billy_objects_exist_with_stats_taken_from_book2():
	assert_eq_deep(BookData.get_item_data('GUERRIER')['stats'], {'hab': 2, 'cha': -1, 'deg': 1})
	assert_eq(BookData.get_item_data('PAYSAN')['category'], 'BILLY')


func test_starting_weapons_have_a_category_and_stats():
	var data = BookData.get_item_data('EPEE BATARDE 2 MAINS')
	assert_eq(data['category'], 'ARME')
	assert_eq_deep(data['stats'], {'hab': 5, 'end': 1})


func test_threshold_tokens_are_not_shown_as_items():
	assert_eq(BookData.get_item_data('LUCIDITE>=6')['category'], 'SEUIL')
	for item in Player.all_items:
		assert_false('>=' in item._item_name)


func test_chapter_stats_impulsion_is_applied_and_reset_with_a_new_billy():
	Player._apply_chapter_stat('impulsion', 1)
	assert_eq(Player.impulsion, 1)
	Player.launch_new_billy()
	assert_eq(Player.impulsion, 0)


func test_threshold_condition_is_matched_only_when_the_stat_reaches_it():
	assert_false('IMPULSION>=2' in Player.get_all_matched_conditions())
	Player._apply_chapter_stat('impulsion', 1)
	Player._recompute_matched_conditions()
	assert_true('IMPULSION>=1' in Player.get_all_matched_conditions())
	assert_false('IMPULSION>=2' in Player.get_all_matched_conditions())
	Player._apply_chapter_stat('impulsion', 1)
	Player._recompute_matched_conditions()
	assert_true('IMPULSION>=2' in Player.get_all_matched_conditions())


func test_jump_with_lucidite_threshold_follows_the_stat():
	assert_false(BookData.match_chapter_conditions(822, 584))
	Player._apply_chapter_stat('lucidite', 6)
	Player._recompute_matched_conditions()
	assert_true(BookData.match_chapter_conditions(822, 584))


func test_jump_with_richesse_thresholds():
	Player._apply_chapter_stat('richesse', 4)
	Player._recompute_matched_conditions()
	assert_true(BookData.match_chapter_conditions(875, 717))
	assert_false(BookData.match_chapter_conditions(875, 787))
	Player._apply_chapter_stat('richesse', 4)
	Player._recompute_matched_conditions()
	assert_true(BookData.match_chapter_conditions(875, 787))


func test_brassards_stats_apply():
	var arm_before = Player.get_arm()
	Player.add_item_from_options('BRASSARDS')
	assert_eq(Player.get_arm(), arm_before + 1)


func test_casserole_ornee_adds_its_pv_max_and_richesse_bonus():
	var pv_max_before = Player.pv_max
	Player.add_item_from_options('CASSEROLE ORNEE')  # +1 ARM, +2 CRIT, +2 PV MAX, +1 RICHESSE
	assert_eq(Player.pv_max, pv_max_before + 2)
	assert_eq(Player.richesse_items, 1)


func test_book3_has_successes_and_endings():
	assert_eq(len(BookData.get_deduped_success()), 51)
	assert_eq_deep(BookData.good_endings, [803, 878])
