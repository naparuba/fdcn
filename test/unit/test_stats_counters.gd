extends "res://addons/gut/test.gd"

# Compteurs propres a un livre sur la fiche de personnage (StatsScreen.gd) :
# rancune/respect (livre 2), lucidite/impulsion/ego (livre 3), richesse (tous).
# Visibles seulement dans le bon livre, modifiables comme les autres stats.

var StatsScreenScript = preload('res://StatsScreen.gd')


func after_all():
	AppParameters.set_book_number(1)  # ne pas polluer les fichiers suivants


func _make_screen(book_number):
	AppParameters.set_book_number(book_number)
	Player.launch_new_billy()
	Player.visited_nodes_all_times = []
	AppParameters.set_billy_type('pegu')
	Player._recompute_matched_conditions()
	Player._recompute_stats()
	var screen = StatsScreenScript.new()
	add_child_autofree(screen)
	return screen


func _visible_keys(screen):
	var keys = []
	for key in screen._counter_widgets:
		if screen._counter_widgets[key]['card'].visible:
			keys.append(key)
	keys.sort()
	return keys


func test_book1_shows_gloire_info_and_richesse():
	assert_eq_deep(_visible_keys(_make_screen(1)), ['gloire', 'info', 'richesse'])


func test_book2_shows_rancune_respect_and_richesse():
	assert_eq_deep(_visible_keys(_make_screen(2)), ['rancune', 'respect', 'richesse'])


func test_book3_shows_lucidite_impulsion_ego_and_richesse():
	assert_eq_deep(_visible_keys(_make_screen(3)), ['ego', 'impulsion', 'lucidite', 'richesse'])


func test_chapter_counters_are_displayed():
	var screen = _make_screen(2)
	Player._apply_chapter_stat('rancune', 2)
	screen.refresh()
	var w = screen._counter_widgets['rancune']
	assert_eq(w['total_label'].text, '2')
	assert_eq(w['autre_field'].text, '+2')


func test_plus_button_changes_only_the_user_part():
	var screen = _make_screen(2)
	Player._apply_chapter_stat('respect', 1)
	screen._step_chapitres_autre('respect', 1)
	assert_eq(Player.get_respect(), 2)
	assert_eq(Player.get_respect_chapters(), 1)  # le vecu narratif n'est jamais touche
	assert_eq(Player.get_respect_user(), 1)


func test_typed_value_sets_the_total():
	var screen = _make_screen(2)
	Player._apply_chapter_stat('rancune', 2)
	screen._set_chapitres_autre('rancune', 5)
	assert_eq(Player.get_rancune(), 5)
	assert_eq(Player.get_rancune_user(), 3)
	screen._set_chapitres_autre('rancune', 0)  # peut descendre sous ce que les chapitres ont donne
	assert_eq(Player.get_rancune(), 0)


func test_book1_info_counter_uses_the_info_chapter_stat():
	var screen = _make_screen(1)
	Player._apply_chapter_stat('info', 2)
	Player._apply_chapter_stat('gloire', 1)
	screen._step_chapitres_autre('info', 1)
	assert_eq(Player.get_info(), 3)
	assert_eq(Player.get_info_chapters(), 2)
	assert_eq(Player.get_gloire(), 1)
	screen.refresh()
	assert_eq(screen._counter_widgets['info']['total_label'].text, '3')
	Player.launch_new_billy()
	assert_eq(Player.get_info(), 0)
	assert_eq(Player.get_gloire(), 0)


func test_counters_never_go_negative():
	var screen = _make_screen(2)
	screen._step_chapitres_autre('rancune', -1)  # deja a 0 : rien ne bouge
	assert_eq(Player.get_rancune(), 0)
	assert_eq(Player.get_rancune_user(), 0)
	screen._set_chapitres_autre('respect', -4)  # valeur tapee negative : ramenee a 0
	assert_eq(Player.get_respect(), 0)
	assert_eq(Player.get_respect_user(), 0)
	screen.refresh()
	assert_true(screen._counter_widgets['rancune']['minus'].disabled)
	screen._step_chapitres_autre('rancune', 1)
	screen.refresh()
	assert_false(screen._counter_widgets['rancune']['minus'].disabled)


func test_a_new_billy_resets_counters_and_adjustments():
	var screen = _make_screen(3)
	Player._apply_chapter_stat('ego', 1)
	screen._step_chapitres_autre('ego', 2)
	Player.launch_new_billy()
	assert_eq(Player.get_ego(), 0)
	assert_eq(Player.get_ego_user(), 0)


func test_editing_a_counter_updates_the_jump_thresholds():
	var screen = _make_screen(3)
	assert_false('LUCIDITE>=6' in Player.get_all_matched_conditions())
	screen._set_chapitres_autre('lucidite', 6)
	assert_true('LUCIDITE>=6' in Player.get_all_matched_conditions())
	assert_false('LUCIDITE>=7' in Player.get_all_matched_conditions())


func test_richesse_total_includes_objects():
	var screen = _make_screen(3)
	Player._apply_chapter_stat('richesse', 2)
	Player.add_item_from_options('CASSEROLE ORNEE')  # +1 richesse
	screen.refresh()
	assert_eq(Player.get_richesse(), 3)
	assert_eq(screen._counter_widgets['richesse']['total_label'].text, '3')
