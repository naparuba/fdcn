extends "res://addons/gut/test.gd"

# Test d'integration sur les 3 onglets de l'ecran Options (Equipement,
# Stats, Selection de livre), via le VRAI main.tscn.

var _main = null


func before_all():
	AppParameters.set_book_number(1)
	Player.insert_all_objects()
	Player.launch_new_billy()

	var main_scene = load("res://main.tscn")
	_main = main_scene.instantiate()
	add_child(_main)


func after_all():
	_main.free()


func before_each():
	AppParameters.set_billy_type('pegu')
	Player._recompute_stats()


func test_equipement_tab_is_the_only_one_visible():
	_main._options_show_equipement()
	assert_true(_main.get_node("Options/Equipement").visible)
	assert_false(_main.get_node("Options/Stats").visible)
	assert_false(_main.get_node("Options/BookSelect").visible)


func test_stats_tab_is_the_only_one_visible():
	_main._options_show_stats()
	assert_false(_main.get_node("Options/Equipement").visible)
	assert_true(_main.get_node("Options/Stats").visible)
	assert_false(_main.get_node("Options/BookSelect").visible)


func test_book_select_tab_is_the_only_one_visible():
	_main._options_show_book_select()
	assert_false(_main.get_node("Options/Equipement").visible)
	assert_false(_main.get_node("Options/Stats").visible)
	assert_true(_main.get_node("Options/BookSelect").visible)


func test_stats_tab_shows_real_player_values():
	AppParameters.set_billy_type('guerrier')
	Player.add_item_from_options('EPEE')
	_main.refresh()

	assert_eq(_main.get_node("Options/Stats/PlayerPvValue").text,
		('%s' % Player.get_pv()) + ('/%s' % Player.pv_max))
	assert_eq(_main.get_node("Options/Stats/PlayerEndValue").text, '%s' % Player.get_end())
	assert_eq(_main.get_node("Options/Stats/PlayerHabValue").text, '%s' % Player.get_hab())
	assert_eq(_main.get_node("Options/Stats/PlayerHabValueDetail").text,
		'(base:2, item/billy:%s' % Player.get_hab_items() + ', chapitres:%s)' % Player.get_hab_chapters())
	assert_eq(_main.get_node("Options/Stats/PlayerAdrValue").text, '%s' % Player.get_adr())
	assert_eq(_main.get_node("Options/Stats/PlayerChaValue").text,
		('%s' % Player.get_cha()) + ('/%s' % Player.get_chamax()))
	assert_eq(_main.get_node("Options/Stats/PlayerCritValue").text, '%s' % Player.get_crit())
	assert_eq(_main.get_node("Options/Stats/PlayerDegValue").text, '%s' % Player.get_deg())
	assert_eq(_main.get_node("Options/Stats/PlayerArmValue").text, '%s' % Player.get_arm())

	Player.remove_item_from_options('EPEE')


func test_stats_tab_updates_on_refresh_after_stat_change():
	_main.refresh()
	var hab_before = _main.get_node("Options/Stats/PlayerHabValue").text
	Player.add_item_from_options('EPEE')  # {'hab': 4}
	_main.refresh()
	var hab_after = _main.get_node("Options/Stats/PlayerHabValue").text
	assert_ne(hab_before, hab_after)
	Player.remove_item_from_options('EPEE')


func test_valider_la_creation_du_personnage_initialise_pv_et_chance_au_max():
	# Bug reel trouve en analysant la page Stats ("PV: 0" sans explication) :
	# un Billy tout juste cree a pv/cha a 0 (jamais initialises par le livre
	# lui-meme) -- verifie via un vrai lancement complet (main.gd, pas
	# Player seul) que le tout premier combat du livre (noeud 14, atteint en
	# 14 coups depuis le noeud 1 en choix "par defaut") ne trouve plus Billy
	# deja "mort" avant le premier jet de de.
	_main.launch_new_billy()
	assert_eq(Player.pv, 0, "avant Valider, PV est bien a 0 (pas encore initialise)")
	_main._on_options_validate_button_pressed()
	assert_eq(Player.pv, Player.pv_max, "apres Valider, PV doit demarrer plein")
	assert_gt(Player.pv, 0)
	assert_eq(Player.cha, Player.chamax, "Chance doit aussi demarrer pleine")


func test_switch_to_cdsi_grayscales_fdcn_sprite_and_colors_cdsi():
	_main._switch_to_book_cdsi()
	var fdcn_sprite = _main.get_node("Options/BookSelect/BoolSelectFcdn/sprite")
	var cdsi_sprite = _main.get_node("Options/BookSelect/BoolSelectCdsi/sprite")
	assert_true(fdcn_sprite.material.get_shader_parameter("grayscale"))
	assert_false(cdsi_sprite.material.get_shader_parameter("grayscale"))
	assert_eq(AppParameters.get_book_number(), 2)

	_main._switch_to_book_fcdn()
	assert_false(fdcn_sprite.material.get_shader_parameter("grayscale"))
	assert_true(cdsi_sprite.material.get_shader_parameter("grayscale"))
	assert_eq(AppParameters.get_book_number(), 1)
