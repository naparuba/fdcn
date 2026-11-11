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


func test_every_book3_success_has_an_icon():
	for success in BookData.get_all_success():
		var base = 'res://images/success/%s' % success['id']
		assert_true(FileAccess.file_exists(base + '.svg') or FileAccess.file_exists(base + '.png'),
			'pas d icone pour %s' % success['id'])


func test_every_displayable_book3_object_has_an_icon():
	# BILLY (choisi dans les options) et SEUIL (jeton de condition) ne sont pas affiches.
	var sans_icone = []
	for item_name in BookData.get_all_objects():
		var category = BookData.get_item_data(item_name)['category']
		if category == 'BILLY' or category == 'SEUIL':
			continue
		if not Utils.is_file_exists('res://images/items/%s.svg' % item_name):
			sans_icone.append(item_name)
	assert_eq_deep(sans_icone, [])


func test_book3_combats_are_defined_from_the_sources():
	var combat_ids = []
	for node_id_str in BookData.get_all_nodes().keys():
		if BookData.get_chapter_data(int(node_id_str)).is_combat():
			combat_ids.append(int(node_id_str))
	combat_ids.sort()
	assert_eq_deep(combat_ids, [61, 62, 63, 118, 167, 236, 261, 266, 274, 296, 336, 365, 368, 371, 413, 450, 452, 454, 460, 461, 468, 562, 563, 568, 613, 616, 626, 631, 634, 641, 666, 685, 686, 689, 722, 728, 731, 736, 766, 768, 777, 796, 799, 810, 820, 860])


func test_book3_combat_61_sanglier_d_acier():
	var combats = BookData.get_chapter_data(61).get_combat_list()
	assert_eq(len(combats), 1)
	assert_eq_deep(combats[0], {'nom': "Sanglier d'Acier", 'hab': 16, 'pv': 12, 'arm': 2, 'deg': 2, 'pyro': 10})


func test_book3_combat_negative_armor_and_damage_are_kept():
	# 261 : armure -1 ; 296 : degats -2 (valeurs negatives du livre, comme deg -1 au livre 2).
	var phasme = BookData.get_chapter_data(261).get_combat_list()[0]
	assert_eq_deep(phasme, {'nom': 'Phasme géant', 'hab': 13, 'pv': 7, 'arm': -1, 'deg': 3, 'pyro': 7})
	var gnomes = BookData.get_chapter_data(296).get_combat_list()[0]
	assert_eq(gnomes['deg'], -2)


func test_book3_combat_236_bande_de_pirates():
	assert_eq_deep(BookData.get_chapter_data(236).get_combat_list()[0],
		{'nom': 'Bande de pirates', 'hab': 12, 'pv': 20, 'arm': 0, 'deg': 0, 'pyro': 4})


func test_book3_combat_names_with_parentheses_and_defaults():
	# 460 : "Votre mere (creuse)", seulement hab/pv/arm ; 563 : seulement hab/pv.
	assert_eq_deep(BookData.get_chapter_data(460).get_combat_list()[0],
		{'nom': 'Votre mère (creuse)', 'hab': 2, 'pv': 2, 'arm': 1, 'deg': 0, 'pyro': 0})
	assert_eq_deep(BookData.get_chapter_data(563).get_combat_list()[0],
		{'nom': 'Coq à trois têtes', 'hab': 8, 'pv': 11, 'arm': 0, 'deg': 0, 'pyro': 0})
	assert_eq(BookData.get_chapter_data(461).get_combat_list()[0]['nom'], "Austère, Duc d'Arkadie")


func test_book3_combat_chapter_keeps_conditional_jumps():
	# 613 : combat suivi de sauts conditionnels (VALOISIE / SOLQUARDIE).
	var node = BookData.get_chapter_data(613)
	assert_true(node.is_combat())
	assert_eq_deep(node.get_sons(), [47, 464])  # liens tries
	assert_true(BookData.have_chapter_conditions(613, 464))


func test_book3_combat_666_mimine_l_invincible_keeps_its_extreme_values():
	assert_eq_deep(BookData.get_chapter_data(666).get_combat_list()[0],
		{'nom': "Mimine l'invincible", 'hab': 666, 'pv': 666, 'arm': 666, 'deg': 666, 'pyro': 10})


func test_book3_combat_with_zero_habilete_and_with_a_success():
	assert_eq(BookData.get_chapter_data(685).get_combat_list()[0]['hab'], 0)
	# 731 : combat (degats -1) ET succes "Enfermes ici avec moi".
	assert_eq(BookData.get_chapter_data(731).get_combat_list()[0]['deg'], -1)
	assert_true(BookData.is_success_chapter(731))


func test_book3_combat_860_cadence_l_evidee():
	assert_eq_deep(BookData.get_chapter_data(860).get_combat_list()[0],
		{'nom': "Cadence, l'évidée", 'hab': 22, 'pv': 29, 'arm': 2, 'deg': 1, 'pyro': 10})


func test_book3_combat_name_can_contain_a_comma():
	assert_eq(BookData.get_chapter_data(365).get_combat_list()[0]['nom'], 'Automne, princesse de Solquardie')
	assert_eq_deep(BookData.get_chapter_data(365).get_sons(), [799])


func test_book3_combat_stats_default_to_zero_when_not_given():
	# 62 : "hab:7, pv:10, deg:1" -- ni armure ni Pyro.
	var combat = BookData.get_chapter_data(62).get_combat_list()[0]
	assert_eq(combat['hab'], 7)
	assert_eq(combat['pv'], 10)
	assert_eq(combat['deg'], 1)
	assert_eq(combat['arm'], 0)
	assert_eq(combat['pyro'], 0)


func test_book3_combat_chapter_keeps_its_other_effects_and_links():
	# 118 : combat + classe BELLICISTE + liens vers 113 et 849.
	var node = BookData.get_chapter_data(118)
	assert_true(node.is_combat())
	assert_true('BELLICISTE' in node.get_aquire())
	assert_eq_deep(node.get_sons(), [113, 849])


func test_book3_combats_have_no_special_rule_yet():
	var par_node = preload('res://combat_modificateurs_par_node.gd')
	for node_id in [61, 62, 63, 118, 167, 236, 261, 266, 274, 296, 336, 365, 368, 371, 413, 450, 452, 454, 460, 461, 468, 562, 563, 568, 613, 616, 626, 631, 634, 641, 666, 685, 686, 689, 722, 728, 731, 736, 766, 768, 777, 796, 799, 810, 820, 860]:
		assert_eq_deep(par_node.for_node(3, node_id), [])


func test_book3_has_successes_and_endings():
	assert_eq(len(BookData.get_deduped_success()), 53)
	assert_eq_deep(BookData.good_endings, [803, 878])
