extends "res://addons/gut/test.gd"

# Regle propre au livre 2 : l'ecart entre Respect et Rancune donne des bonus cumulatifs.
#   Respect >= Rancune +2 : +2 Endurance      Respect >= Rancune +4 : +2 Chance max
#   Rancune >= Respect +2 : +2 Critique       Rancune >= Respect +4 : +2 Habilete
# Bonus comptes cote "Objets & Billy" (lecture seule sur la fiche de perso), recalcules a
# chaque _recompute_stats(), uniquement dans le livre 2.

var StatsScreenScript = preload('res://StatsScreen.gd')


func before_all():
	AppParameters.set_book_number(2)
	Player.insert_all_objects()


func after_all():
	AppParameters.set_book_number(1)  # ne pas polluer les fichiers suivants


func before_each():
	AppParameters.set_book_number(2)
	Player.launch_new_billy()
	Player.visited_nodes_all_times = []
	AppParameters.set_billy_type('pegu')
	Player._recompute_matched_conditions()
	Player._recompute_stats()


func _give(respect, rancune):
	Player._apply_chapter_stat('respect', respect)
	Player._apply_chapter_stat('rancune', rancune)
	Player._recompute_stats()


func test_no_bonus_without_respect_nor_rancune():
	assert_eq_deep(Player.get_book_bonuses(), {})


func test_no_bonus_when_the_gap_is_below_2():
	_give(3, 2)
	assert_eq_deep(Player.get_book_bonuses(), {})


func test_no_bonus_when_respect_equals_rancune():
	_give(5, 5)
	assert_eq_deep(Player.get_book_bonuses(), {})


func test_respect_plus_2_gives_2_endurance_only():
	var end_before = Player.get_end()
	var chamax_before = Player.chamax
	_give(2, 0)
	assert_eq_deep(Player.get_book_bonuses(), {'end': 2})
	assert_eq(Player.get_end(), end_before + 2)
	assert_eq(Player.get_end_items(), 2)
	assert_eq(Player.pv_max, (end_before + 2) * 3)  # l'Endurance monte, les PV max avec
	assert_eq(Player.chamax, chamax_before)


func test_respect_plus_3_is_still_only_endurance():
	_give(4, 1)
	assert_eq_deep(Player.get_book_bonuses(), {'end': 2})


func test_respect_plus_4_adds_2_chance_max_on_top_of_endurance():
	var chamax_before = Player.chamax
	var end_before = Player.get_end()
	_give(4, 0)
	assert_eq_deep(Player.get_book_bonuses(), {'end': 2, 'cha': 2})
	assert_eq(Player.chamax, chamax_before + 2)
	assert_eq(Player.get_end(), end_before + 2)


func test_rancune_plus_2_gives_2_critique_only():
	var crit_before = Player.get_crit()
	var hab_before = Player.get_hab()
	_give(0, 2)
	assert_eq_deep(Player.get_book_bonuses(), {'crit': 2})
	assert_eq(Player.get_crit(), crit_before + 2)
	assert_eq(Player.get_hab(), hab_before)


func test_rancune_plus_4_adds_2_habilete_on_top_of_critique():
	var crit_before = Player.get_crit()
	var hab_before = Player.get_hab()
	_give(1, 5)
	assert_eq_deep(Player.get_book_bonuses(), {'crit': 2, 'hab': 2})
	assert_eq(Player.get_crit(), crit_before + 2)
	assert_eq(Player.get_hab(), hab_before + 2)


func test_bonus_goes_away_when_the_gap_closes():
	_give(2, 0)
	assert_eq(Player.get_end_items(), 2)
	Player._apply_chapter_stat('rancune', 2)  # 2 / 2 : plus d'ecart
	Player._recompute_stats()
	assert_eq_deep(Player.get_book_bonuses(), {})
	assert_eq(Player.get_end_items(), 0)


func test_bonus_is_not_cumulated_by_repeated_recomputes():
	_give(2, 0)
	var end_once = Player.get_end()
	Player._recompute_stats()
	Player._recompute_stats()
	assert_eq(Player.get_end(), end_once)


func test_bonus_stacks_with_items_and_chapter_stats():
	Player.add_item_from_options('SEAU')  # +1 END, +1 ARM, +2 PV MAX
	var end_with_item = Player.get_end()
	_give(2, 0)
	assert_eq(Player.get_end(), end_with_item + 2)
	assert_eq(Player.get_end_items(), 3)


func test_manual_adjustment_of_respect_triggers_the_bonus():
	var screen = StatsScreenScript.new()
	add_child_autofree(screen)
	screen._step_chapitres_autre('respect', 2)
	assert_eq_deep(Player.get_book_bonuses(), {'end': 2})
	screen.refresh()
	assert_string_contains(screen._counter_widgets['respect']['bonus_label'].text, '+2 Endurance')
	screen._step_chapitres_autre('respect', -2)
	assert_eq_deep(Player.get_book_bonuses(), {})
	assert_string_contains(screen._counter_widgets['respect']['bonus_label'].text, 'Aucun bonus')


func test_no_bonus_in_the_other_books():
	for book_number in [1, 3]:
		AppParameters.set_book_number(book_number)
		Player.launch_new_billy()
		Player._apply_chapter_stat('respect', 6)
		Player._recompute_stats()
		assert_eq_deep(Player.get_book_bonuses(), {})
		assert_eq(Player.get_end_items(), 0, 'livre %d' % book_number)
