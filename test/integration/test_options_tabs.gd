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
	var stats_screen = _main.get_node("Options/Stats")

	assert_eq(stats_screen._pv_value_field.text, "%d/%d" % [Player.pv, Player.pv_max])
	assert_eq(stats_screen._cha_value_field.text, "%d/%d" % [Player.cha, Player.chamax])
	assert_eq(stats_screen._stat_widgets["end"]["total_label"].text, '%s' % Player.get_end())
	assert_eq(stats_screen._stat_widgets["hab"]["total_label"].text, '%s' % Player.get_hab())
	assert_eq(stats_screen._stat_widgets["hab"]["objets_val"].text, "+%d" % Player.get_hab_items())
	assert_eq(stats_screen._stat_widgets["adr"]["total_label"].text, '%s' % Player.get_adr())
	assert_eq(stats_screen._stat_widgets["chamax"]["total_label"].text, '%s' % Player.get_chamax())
	assert_eq(stats_screen._stat_widgets["crit"]["total_label"].text, '%s' % Player.get_crit())
	assert_eq(stats_screen._stat_widgets["deg"]["total_label"].text, '%s' % Player.get_deg())
	assert_eq(stats_screen._stat_widgets["arm"]["total_label"].text, '%s' % Player.get_arm())

	Player.remove_item_from_options('EPEE')


func test_stats_tab_updates_on_refresh_after_stat_change():
	_main.refresh()
	var stats_screen = _main.get_node("Options/Stats")
	var hab_before = stats_screen._stat_widgets["hab"]["total_label"].text
	Player.add_item_from_options('EPEE')  # {'hab': 4}
	_main.refresh()
	var hab_after = stats_screen._stat_widgets["hab"]["total_label"].text
	assert_ne(hab_before, hab_after)
	Player.remove_item_from_options('EPEE')


func test_chapitres_autre_step_edite_le_bucket_user_jamais_le_vrai_chapitres():
	# Le point de la fiche de personnage : "Chapitres & Autre" est
	# editable, mais ne doit JAMAIS corrompre le vrai vecu narratif
	# (Player.hab_chapters), seulement le bucket dedie a la triche.
	_main.refresh()
	var stats_screen = _main.get_node("Options/Stats")
	var hab_chapters_avant = Player.hab_chapters
	stats_screen._step_chapitres_autre("hab", 3)
	assert_eq(Player.hab_chapters, hab_chapters_avant, "le vrai accumulateur de chapitre ne doit pas bouger")
	assert_eq(Player.hab_user, 3)
	stats_screen._step_chapitres_autre("hab", -3)
	Player.hab_user = 0
	Player._recompute_stats()


func test_taper_une_valeur_precise_dans_chapitres_autre_ne_touche_que_user():
	_main.refresh()
	var stats_screen = _main.get_node("Options/Stats")
	Player.go_to_node(128)  # {'end': 1} -- un vrai chapitre avec une stat simple
	var end_chapters_avant = Player.end_chapters  # = 1
	var end_avant = Player.get_end()
	stats_screen._set_chapitres_autre("end", end_chapters_avant + 5)
	assert_eq(Player.end_chapters, end_chapters_avant, "toujours pas touche")
	assert_eq(Player.end_user, 5)
	assert_eq(Player.get_end(), end_avant + 5)


func test_plein_remplit_pv_et_chance_a_leur_max():
	_main.refresh()
	var stats_screen = _main.get_node("Options/Stats")
	Player.pv = 1
	Player.cha = 0
	stats_screen._fill_pv()
	stats_screen._fill_cha()
	assert_eq(Player.pv, Player.pv_max)
	assert_eq(Player.cha, Player.chamax)


func test_pv_ne_peut_jamais_depasser_son_max_meme_en_forcant():
	_main.refresh()
	var stats_screen = _main.get_node("Options/Stats")
	stats_screen._set_pv(Player.pv_max + 500)
	assert_eq(Player.pv, Player.pv_max)
	stats_screen._step_pv(500)
	assert_eq(Player.pv, Player.pv_max)


func test_endurance_ne_descend_jamais_sous_1_via_chapitres_autre():
	_main.refresh()
	var stats_screen = _main.get_node("Options/Stats")
	for i in range(10):
		stats_screen._step_chapitres_autre("end", -1)
	assert_true(Player.get_end() >= 1, "PV max deviendrait nul/negatif sinon")
	# remise a zero pour ne pas polluer les tests suivants du fichier
	Player.end_user = 0
	Player._recompute_stats()


func test_bonus_pv_max_editable_recalcule_pv_max_sans_toucher_le_vrai_bonus():
	_main.refresh()
	var stats_screen = _main.get_node("Options/Stats")
	var pv_max_bonus_reel_avant = Player.pv_max_bonus
	var pv_max_avant = Player.pv_max
	stats_screen._step_pv_max_bonus(4)
	assert_eq(Player.pv_max, pv_max_avant + 4)
	assert_eq(Player.pv_max_bonus, pv_max_bonus_reel_avant, "le vrai bonus de chapitre ne doit pas bouger")
	assert_eq(Player.pv_max_bonus_user, 4)
	stats_screen._step_pv_max_bonus(-4)


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
