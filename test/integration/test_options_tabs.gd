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

	# Le panneau de rapport de GUT (GutRunner/GutLayer, CanvasLayer 128 --
	# rendu au-dessus de tout, y compris _main) capte et avale tout clic/
	# touche avant qu'il n'atteigne _main -- meme piege deja documente dans
	# test_real_swipe_navigation.gd, necessaire ici pour le test de glisse-
	# doigt sur la fiche de personnage.
	var gut_layer = get_tree().root.get_node_or_null("GutRunner/GutLayer")
	if gut_layer:
		gut_layer.visible = false


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


func test_boutons_pv_et_chance_grises_a_leurs_bornes():
	# Un bouton +/- qui ne peut plus rien faire (deja a sa borne) doit se
	# griser -- sinon il a l'air casse plutot qu'inutile a cet instant.
	var stats_screen = _main.get_node("Options/Stats")

	stats_screen._set_pv(0)
	stats_screen._set_cha(0)
	assert_true(stats_screen._pv_minus_button.disabled, "PV a 0 : le bouton moins doit se griser")
	assert_false(stats_screen._pv_plus_button.disabled, "PV a 0 (pas au max) : le bouton plus reste actif")
	assert_true(stats_screen._cha_minus_button.disabled, "Chance a 0 : le bouton moins doit se griser")
	assert_false(stats_screen._cha_plus_button.disabled, "Chance a 0 (pas au max) : le bouton plus reste actif")

	stats_screen._fill_pv()
	stats_screen._fill_cha()
	assert_false(stats_screen._pv_minus_button.disabled, "PV au max (pas a 0) : le bouton moins reste actif")
	assert_true(stats_screen._pv_plus_button.disabled, "PV au max : le bouton plus doit se griser")
	assert_false(stats_screen._cha_minus_button.disabled, "Chance au max (pas a 0) : le bouton moins reste actif")
	assert_true(stats_screen._cha_plus_button.disabled, "Chance au max : le bouton plus doit se griser")

	stats_screen._step_pv(-1)
	stats_screen._step_cha(-1)
	assert_false(stats_screen._pv_minus_button.disabled, "PV entre 0 et son max : aucun bouton grise")
	assert_false(stats_screen._pv_plus_button.disabled)
	assert_false(stats_screen._cha_minus_button.disabled, "Chance entre 0 et son max : aucun bouton grise")
	assert_false(stats_screen._cha_plus_button.disabled)


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


func test_edition_bloquee_pendant_un_combat_avec_message_explicite():
	# Un combat en cours tourne sur un instantane fige de Billy (verifie a
	# l'ecran : Habileté/PV max trafiques pendant un combat restaient
	# invisibles sur le combat affiche) -- plutot que de re-synchroniser un
	# combat deja lance, on bloque l'edition ici. Player.in_combat est pose
	# par CombatScreen.gd lui-meme (cf test_combat_screen.gd) ; on le simule
	# directement ici, ce fichier ne teste que StatsScreen.gd.
	_main.refresh()
	var stats_screen = _main.get_node("Options/Stats")
	var hab_avant = Player.get_hab()

	# PV/Chance a une valeur ni nulle ni au max : ce test verifie UNIQUEMENT
	# le verrou combat, pas le grisage aux bornes (cf test_boutons_pv_et_chance_grises_a_leurs_bornes) --
	# sans ca, un PV/Chance qui traine a 0 ou au max apres un test precedent
	# ferait echouer l'assertion "non grise hors combat" ci-dessous pour une
	# tout autre raison.
	Player.pv = 1
	Player.cha = 1
	stats_screen.refresh()
	var pv_avant = Player.pv

	Player.in_combat = true
	stats_screen.refresh()
	assert_true(stats_screen._combat_warning.visible, "le message d'avertissement doit s'afficher")
	for control in stats_screen._editable_controls:
		if control is LineEdit:
			assert_false(control.editable, "un LineEdit de triche doit devenir non editable en combat")
		else:
			assert_true(control.disabled, "un bouton +/-/Plein doit se desactiver en combat")

	# Meme un appel direct (pas juste le bouton grise) ne doit rien changer --
	# defense en profondeur, pas seulement cosmetique.
	stats_screen._step_chapitres_autre("hab", 5)
	stats_screen._fill_pv()
	stats_screen._step_pv_max_bonus(3)
	assert_eq(Player.get_hab(), hab_avant, "aucune triche ne doit passer pendant un combat")
	assert_eq(Player.pv, pv_avant)

	Player.in_combat = false
	stats_screen.refresh()
	assert_false(stats_screen._combat_warning.visible, "le message disparait une fois le combat termine")
	for control in stats_screen._editable_controls:
		if control is LineEdit:
			assert_true(control.editable, "l'edition redevient possible hors combat")
		else:
			assert_false(control.disabled)
	stats_screen._step_chapitres_autre("hab", 5)
	assert_eq(Player.get_hab(), hab_avant + 5, "l'edition fonctionne de nouveau normalement")
	stats_screen._step_chapitres_autre("hab", -5)


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


func test_search_filters_items_by_name_case_insensitive():
	_main._options_show_equipement()
	_main._on_item_search_text_changed("epee")
	var item_stack = _main.get_node("Options/Equipement/ItemsCont/Items")
	var visible_items = []
	for item in item_stack.get_children():
		if item.visible:
			visible_items.append(item.get_item_name())
	assert_eq(visible_items, ["EPEE"])
	assert_eq(_main.get_node("Options/Equipement/SearchBar/Count").text, "1 objet(s) trouvé(s)")
	assert_true(_main.get_node("Options/Equipement/SearchBar/Box/Clear").visible)
	_main._on_item_search_clear_pressed()


func test_clear_search_restores_full_list_and_hides_clear_button():
	_main._options_show_equipement()
	_main._on_item_search_text_changed("epee")
	_main._on_item_search_clear_pressed()
	var item_stack = _main.get_node("Options/Equipement/ItemsCont/Items")
	for item in item_stack.get_children():
		assert_true(item.visible, "%s doit redevenir visible apres avoir vide la recherche" % item.get_item_name())
	assert_eq(_main.get_node("Options/Equipement/SearchBar/Box/Field").text, "")
	assert_eq(_main.get_node("Options/Equipement/SearchBar/Count").text, "")
	assert_false(_main.get_node("Options/Equipement/SearchBar/Box/Clear").visible)


func test_search_with_no_match_hides_all_items():
	_main._options_show_equipement()
	_main._on_item_search_text_changed("zzzzznomatch")
	var item_stack = _main.get_node("Options/Equipement/ItemsCont/Items")
	var visible_count = 0
	for item in item_stack.get_children():
		if item.visible:
			visible_count += 1
	assert_eq(visible_count, 0)
	_main._on_item_search_clear_pressed()


func test_item_popup_banner_pushes_cards_down_and_reverts_when_it_empties():
	# Le bandeau "objet acquis" ne doit jamais recouvrir les cartes
	# Complete/Position (cf le bug visuel constate a l'ecran), mais ne doit
	# pas non plus laisser un trou permanent quand il n'y a rien a montrer --
	# les cartes ne descendent que pendant que la pile en contient au moins
	# un, cf main.gd::_recompute_item_popups_layout.
	var position_card = _main.get_node("Background/Position")
	var cont = _main.get_node("ItemPopups/ScrollContainer/ItemPopupsCont")
	var anim_wait = _main.ITEM_POPUP_ANIM_DURATION + 0.1
	# Etat de depart force (plutot que suppose) : un scenario precedent peut
	# avoir laisse un popup en cours dans cette meme suite.
	for child in cont.get_children():
		child.free()
	_main._shift_item_popups_layout(false)
	await get_tree().create_timer(anim_wait).timeout
	var top_avant = position_card.offset_top

	var popup = _main._create_popup_item("EPEE")
	popup.set_is_new(true)
	cont.add_child(popup)
	await get_tree().create_timer(anim_wait).timeout
	assert_eq(position_card.offset_top, top_avant + _main.ITEM_POPUP_BANNER_SHIFT, "la carte doit descendre (en douceur) pour laisser la place au bandeau")

	popup.free()
	await get_tree().create_timer(anim_wait).timeout
	assert_eq(position_card.offset_top, top_avant, "la carte doit revenir a sa place une fois le bandeau vide, jamais un trou permanent")


func test_touch_drag_scrolls_the_stats_screen_not_just_the_scrollbar():
	# Bug signale par l'utilisateur : chaque carte de stat (fond, labels,
	# lignes de mise en page) avait mouse_filter=STOP par defaut (valeur de
	# base de tout Control en Godot 4) -- ca avalait le glisse-doigt avant
	# qu'il n'atteigne le ScrollContainer, seul le slider de la scrollbar
	# fonctionnait (meme classe de bug deja rencontree et corrigee dans
	# CombatScreen.gd). Verifie avec de VRAIS InputEventScreenTouch/
	# ScreenDrag (pas un appel direct a scroll_vertical), pour valider le
	# vrai pipeline d'input, pas juste que la propriete existe.
	_main.show_options()
	_main._options_show_stats()
	_main.refresh()
	var stats_screen = _main.get_node("Options/Stats")
	var scroll = stats_screen._scroll_container
	scroll.scroll_vertical = 0
	await get_tree().process_frame

	# Precondition : le contenu doit vraiment deborder, sinon le test ne
	# demontre rien (rien a scroller, glisser ou pas).
	var content_height = scroll.get_child(0).size.y
	assert_gt(content_height, scroll.size.y, "precondition : le contenu de la fiche de personnage doit deborder du cadre visible")

	# Point de depart garanti "passif" (un Label, jamais un Button/LineEdit) :
	# le badge de type de Billy, toujours present en haut du contenu.
	var start_pos = stats_screen._type_badge.get_global_rect().get_center()

	var press = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = start_pos
	press.global_position = start_pos
	Input.parse_input_event(press)
	await get_tree().process_frame
	await get_tree().process_frame

	for i in range(15):
		var motion = InputEventMouseMotion.new()
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		motion.position = start_pos + Vector2(0, -10 * (i + 1))
		motion.global_position = motion.position
		motion.relative = Vector2(0, -10)
		Input.parse_input_event(motion)
		await get_tree().process_frame

	var release = InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = start_pos + Vector2(0, -150)
	release.global_position = release.position
	Input.parse_input_event(release)
	await get_tree().process_frame
	await get_tree().process_frame

	assert_gt(scroll.scroll_vertical, 0, "un glisse-doigt doit faire defiler le contenu, pas seulement le slider de la scrollbar")
