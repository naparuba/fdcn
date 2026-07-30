extends "res://addons/gut/test.gd"

# Teste Combat.tscn de maniere autonome (pas via main.tscn) -- exactement
# ce que l'extraction en scene separee est censee permettre. skip_animations
# rend les tours instantanes (pas de vraie attente de tween) pour que la
# suite reste rapide.

var _combat = null


func before_each():
	var scene = load("res://Combat.tscn")
	_combat = scene.instantiate()
	_combat.skip_animations = true
	add_child(_combat)


func after_each():
	_combat.free()


func _start(opts: Dictionary = {}) -> void:
	_combat.start_combat("Guerriers Orcs", 9, 5, 20, 24, opts)


func test_start_combat_affiche_le_panneau_et_les_stats():
	_start()
	assert_true(_combat.visible)
	assert_eq(_combat._enemy_name_label.text, "Guerriers Orcs")
	assert_eq(_combat._enemy_hp_label.text, "24 / 24")
	assert_eq(_combat._player_hp_label.text, "20 / 20")
	assert_false(_combat.is_resolved())


func test_lancer_le_de_joue_un_tour_reel_via_le_moteur():
	_start()
	await _combat._on_roll_pressed()
	assert_eq(_combat._controller.prochain_tour(), 2, "un tour a bien ete joue")
	assert_false(_combat._undo_button.disabled, "annuler devient possible apres 1 tour")


func test_plusieurs_tours_font_baisser_les_pv_affiches():
	_start()
	var pv_avant = _combat._controller.etat_courant().adversaire.pv
	await _combat._on_roll_pressed()
	await _combat._on_roll_pressed()
	await _combat._on_roll_pressed()
	var pv_apres = _combat._controller.etat_courant().adversaire.pv
	assert_lt(pv_apres, pv_avant, "l'ennemi doit avoir subi des degats sur au moins un des 3 tours")
	assert_eq(_combat._enemy_hp_label.text, "%d / 24" % maxi(pv_apres, 0))


func test_annuler_le_dernier_tour_restaure_pv_et_tour():
	_start()
	await _combat._on_roll_pressed()
	var etat_apres_t1 = _combat._controller.etat_courant()
	var pv_billy_t1 = etat_apres_t1.billy.pv
	var pv_adv_t1 = etat_apres_t1.adversaire.pv
	await _combat._on_roll_pressed()
	_combat._on_undo_pressed()
	assert_eq(_combat._controller.prochain_tour(), 2)
	assert_eq(_combat._controller.etat_courant().billy.pv, pv_billy_t1)
	assert_eq(_combat._controller.etat_courant().adversaire.pv, pv_adv_t1)


func test_revenir_avant_un_tour_du_milieu_via_la_strip():
	_start()
	await _combat._on_roll_pressed()  # tour 1
	await _combat._on_roll_pressed()  # tour 2
	await _combat._on_roll_pressed()  # tour 3
	assert_eq(_combat._controller.prochain_tour(), 4)
	_combat._on_turn_chip_pressed(2)  # revenir avant le tour 2
	assert_eq(_combat._controller.prochain_tour(), 2, "doit annuler les tours 3 ET 2, pas seulement le dernier")


func test_bouton_jai_gagne_termine_le_combat_avant_meme_un_tour():
	_start()
	assert_false(_combat.is_resolved())
	_combat._on_manual_win_pressed()
	assert_true(_combat.is_resolved())
	assert_true(_combat._resolution_overlay.visible)
	assert_eq(_combat._resolution_title.text, "Victoire")


func test_revenir_en_arriere_depuis_la_resolution_manuelle_sans_tour_joue():
	_start()
	_combat._on_manual_win_pressed()
	_combat._on_resolution_rewind_pressed()
	assert_false(_combat.is_resolved(), "sans tour a annuler, doit juste rouvrir la main sur le combat")
	assert_false(_combat._resolution_overlay.visible)
	assert_false(_combat._roll_button.disabled)


func test_victoire_automatique_quand_pv_ennemi_a_zero():
	_start({"deg_billy": 999})  # garantit la mort de l'ennemi au 1er tour
	await _combat._on_roll_pressed()
	assert_true(_combat.is_resolved())
	assert_true(_combat._resolution_overlay.visible)
	assert_eq(_combat._resolution_title.text, "Victoire")


func test_previsualisation_correspond_a_la_table_des_situations():
	_start()  # diff = 9-5 = 4
	var CombatScript = preload('res://combat.gd')
	var attendu = CombatScript.resolve_round(9, 5, 3)  # face 3
	var cell = _combat._preview_cells[2]  # index 0 = face 1
	assert_eq(cell['give'].text, "+%d" % attendu['degats_billy'])
	assert_eq(cell['take'].text, "-%d" % attendu['degats_adversaire'])


func test_tags_de_regles_speciales_affiches_sur_le_panneau_ennemi():
	_start({"regles_speciales": ["Règle spéciale : -1 Habileté tous les 4 PV perdus"]})
	assert_eq(_combat._enemy_tags_box.get_child_count(), 1)
	assert_eq(_combat._enemy_tags_box.get_child(0).text, "Règle spéciale : -1 Habileté tous les 4 PV perdus")


func test_bonus_pyro_affiche_seulement_si_non_nul():
	_start({"pyro_bonus": 4})
	assert_true(_combat._player_pyro_tag.visible)
	assert_eq(_combat._player_pyro_tag.text, "+4 Pyro-Barbare (Habileté)")

	_start({"pyro_bonus": 0})
	assert_false(_combat._player_pyro_tag.visible)


func test_recommencer_start_combat_reinitialise_lhistorique():
	_start()
	await _combat._on_roll_pressed()
	assert_eq(_combat._controller.prochain_tour(), 2)
	_start()  # nouveau combat, doit repartir de zero
	assert_eq(_combat._controller.prochain_tour(), 1)
	assert_true(_combat._undo_button.disabled)
