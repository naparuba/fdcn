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


func test_bouton_annuler_a_une_legende_visible_pas_seulement_un_tooltip():
	# Un tooltip ne s'affiche jamais au toucher (mobile) -- l'icone seule
	# ("↺") ne suffit donc pas, il faut un texte toujours visible.
	_start()
	var found = false
	for child in _combat._undo_button.get_children():
		for grand_child in child.get_children():
			if grand_child is Label and grand_child.text == "Annuler":
				found = true
	assert_true(found, "le bouton annuler doit porter une legende visible en permanence")


func test_titre_previsualisation_sans_le_si_quand_esquive_impossible():
	_start()  # adresse_billy par defaut = 0, peut_esquiver() == false
	assert_false(_combat._controller.peut_esquiver())
	assert_eq(_combat._preview_title.text, "SELON LE DÉ D'ATTAQUE",
		"le resultat affiche est garanti ici, pas conditionnel -- pas de 'si' trompeur")


func test_titre_previsualisation_avec_le_si_quand_esquive_possible():
	_start({"adresse_billy": 3})
	assert_true(_combat._controller.peut_esquiver())
	assert_eq(_combat._preview_title.text, "SI VOUS N'ESQUIVEZ PAS, SELON LE DÉ D'ATTAQUE")


func test_alerte_pv_critiques_saffiche_sous_le_seuil_et_disparait_sinon():
	_start({"pv_billy_max": 20})  # pv_billy=20 (defaut _start) -> pas critique au depart
	assert_false(_combat._player_danger_tag.visible)
	_combat.start_combat("Guerriers Orcs", 9, 5, 3, 24, {"pv_billy_max": 20})  # 3/20 = 15%
	assert_true(_combat._player_danger_tag.visible, "sous le seuil, l'alerte doit etre visible")
	_combat.start_combat("Guerriers Orcs", 9, 5, 20, 24, {"pv_billy_max": 20})  # de retour au max
	assert_false(_combat._player_danger_tag.visible, "au-dessus du seuil, l'alerte doit disparaitre")


func test_lancer_le_de_joue_un_tour_reel_via_le_moteur():
	_start()
	await _combat._on_roll_pressed()
	assert_eq(_combat._controller.prochain_tour(), 2, "un tour a bien ete joue")
	assert_false(_combat._undo_button.disabled, "annuler devient possible apres 1 tour")


func test_pastille_de_tour_affiche_le_de_tire_sans_avoir_a_annuler():
	# Une vieille tuile scrollee hors champ doit rester comprehensible sans
	# tooltip (inutile au toucher) ni annulation destructive -- le de tire
	# doit donc etre visible directement sur la tuile.
	_start()
	await _combat._play_turn(6)
	var chip = _combat._turns_strip.get_child(0)
	var num = chip.get_child(1).get_child(0)  # v -> num (cf _push_turn_chip)
	assert_eq(num.text, "1\nd6")


func test_plusieurs_tours_font_baisser_les_pv_affiches():
	_start()
	var pv_avant = _combat._controller.etat_courant().adversaire.pv
	await _combat._on_roll_pressed()
	await _combat._on_roll_pressed()
	await _combat._on_roll_pressed()
	var pv_apres = _combat._controller.etat_courant().adversaire.pv
	assert_lt(pv_apres, pv_avant, "l'ennemi doit avoir subi des degats sur au moins un des 3 tours")
	assert_eq(_combat._enemy_hp_label.text, "%d / 24" % maxi(pv_apres, 0))


func _count_chips_named(nom: String) -> int:
	var total = 0
	for chip in _combat._turns_strip.get_children():
		if chip.name == nom:
			total += 1
	return total


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
	assert_true(_combat._last_turn_line.text.contains("Retour effectué"),
		"la ligne de resume doit refleter l'annulation, pas rester sur le texte du tour annule")
	# Regression : une tuile "NextChip" perimee restait affichee en double
	# (Godot renomme silencieusement un second enfant du meme nom au lieu
	# de refuser le doublon) -- constate a l'ecran via une vraie capture.
	assert_eq(_count_chips_named("NextChip"), 1, "une seule tuile 'prochain tour', jamais un doublon perime")
	assert_eq(_combat._turns_strip.get_child_count(), 2, "1 vraie tuile (tour 1) + 1 tuile 'prochain tour'")


func test_revenir_avant_un_tour_du_milieu_via_la_strip():
	_start()
	await _combat._on_roll_pressed()  # tour 1
	await _combat._on_roll_pressed()  # tour 2
	await _combat._on_roll_pressed()  # tour 3
	assert_eq(_combat._controller.prochain_tour(), 4)
	_combat._on_turn_chip_pressed(2)  # revenir avant le tour 2
	assert_eq(_combat._controller.prochain_tour(), 2, "doit annuler les tours 3 ET 2, pas seulement le dernier")
	# Regression : la tuile du tour 1 (toujours valide, jamais annule par ce
	# retour) disparaissait a tort, et une tuile "NextChip" perimee restait
	# en double -- constate a l'ecran via une vraie capture E2E.
	assert_eq(_count_chips_named("NextChip"), 1, "une seule tuile 'prochain tour', jamais un doublon perime")
	assert_eq(_combat._turns_strip.get_child_count(), 2, "1 vraie tuile (tour 1, toujours valide) + 1 tuile 'prochain tour'")


func test_bouton_jai_gagne_termine_le_combat_avant_meme_un_tour():
	_start()
	assert_false(_combat.is_resolved())
	_combat._on_manual_win_pressed()
	assert_true(_combat.is_resolved())
	assert_true(_combat._resolution_overlay.visible)
	assert_eq(_combat._resolution_title.text, "Victoire")


func test_continuer_l_aventure_ferme_tout_le_panneau_pas_seulement_la_carte():
	# Regression : "CONTINUER L'AVENTURE" ne fermait que la petite carte de
	# resolution, jamais le panneau Combat lui-meme -- qui recouvre en
	# vrai les choix de la suite dans main.tscn (mouse_filter=STOP), donc
	# bloquait le joueur indefiniment apres tout combat termine.
	_start()
	_combat._on_manual_win_pressed()
	_combat._on_continue_pressed()
	assert_false(_combat._resolution_overlay.visible)
	assert_false(_combat.visible, "le panneau entier doit disparaitre, pas seulement l'overlay")


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


# =============================================================================
# Scenarios complets, dés forcés pour rester reproductibles -- joue l'écran
# de bout en bout (plusieurs tours réels, pas des raccourcis) jusqu'à une
# vraie résolution (victoire ou défaite), en vérifiant l'état à chaque
# étape, pas seulement le résultat final.
# =============================================================================

func _nb_tours_dans_la_strip() -> int:
	# Compte les tuiles jouées, sans la tuile "prochain tour" en pointillés.
	var total = _combat._turns_strip.get_child_count()
	if _combat._turns_strip.get_node_or_null("NextChip"):
		total -= 1
	return total


func test_scenario_victoire_complete_sur_plusieurs_tours():
	# Hab 9 vs 5 (diff=4), face 6 chaque tour -> table[4][5]=[6,1] : Billy
	# inflige 6, subit 1, a chaque tour. 12 PV adverses => exactement 2 tours.
	_combat.start_combat("Guerriers Orcs", 9, 5, 20, 12)

	await _combat._play_turn(6)
	assert_eq(_combat._controller.etat_courant().adversaire.pv, 6, "12 - 6 apres le tour 1")
	assert_eq(_combat._controller.etat_courant().billy.pv, 19, "20 - 1 apres le tour 1")
	assert_false(_combat.is_resolved(), "pas encore termine apres 1 seul tour")
	assert_eq(_nb_tours_dans_la_strip(), 1)
	assert_eq(_combat._enemy_hp_label.text, "6 / 12")

	await _combat._play_turn(6)
	assert_eq(_combat._controller.etat_courant().adversaire.pv, 0, "12 - 6 - 6 = 0")
	assert_eq(_combat._controller.etat_courant().billy.pv, 18, "20 - 1 - 1")
	assert_true(_combat.is_resolved())
	assert_eq(_combat._controller.get_winner(), "billy")
	assert_eq(_nb_tours_dans_la_strip(), 2)
	assert_true(_combat._resolution_overlay.visible)
	assert_eq(_combat._resolution_title.text, "Victoire")
	assert_true(_combat._roll_button.disabled, "plus possible de rejouer un tour une fois resolu")

	# Un tour supplementaire ne doit rien faire : le combat est deja fini.
	await _combat._play_turn(6)
	assert_eq(_nb_tours_dans_la_strip(), 2, "aucun 3e tour ne doit avoir ete ajoute")


func test_scenario_defaite_complete_sur_plusieurs_tours():
	# Hab 5 vs 12 (diff=-7, plafond), face 6 chaque tour -> table[-7][5]=[3,4] :
	# Billy inflige 3, subit 4, a chaque tour. 12 PV Billy => exactement 3 tours.
	_combat.start_combat("Titan des Sables", 5, 12, 12, 100)

	await _combat._play_turn(6)
	await _combat._play_turn(6)
	assert_eq(_combat._controller.etat_courant().billy.pv, 4, "12 - 4 - 4")
	assert_false(_combat.is_resolved())

	await _combat._play_turn(6)
	assert_eq(_combat._controller.etat_courant().billy.pv, 0)
	assert_eq(_combat._controller.etat_courant().adversaire.pv, 91, "100 - 3*3 : l'adversaire est loin d'etre mort")
	assert_true(_combat.is_resolved())
	assert_eq(_combat._controller.get_winner(), "adversaire")
	assert_eq(_nb_tours_dans_la_strip(), 3)
	assert_true(_combat._resolution_overlay.visible)
	assert_eq(_combat._resolution_title.text, "Défaite")


func test_scenario_victoire_via_esquive_et_contre_attaque_critique():
	# Adresse 3, Critique 2 : tour 1 esquive simple (esquive_die=2, <=3,
	# !=1 -> pas de critique), tour 2 esquive critique (esquive_die=1).
	# Sans Adresse >= 2 aucune esquive n'est meme tentee -- verifie donc
	# aussi peut_esquiver() en creux.
	_combat.start_combat("Sentinelle", 9, 5, 20, 14, {"adresse_billy": 3, "critique_billy": 2})
	assert_true(_combat._controller.peut_esquiver())

	var t1 = await _combat._play_turn(6, 2)
	assert_true(t1.esquive)
	assert_false(t1.contre_attaque_critique)
	assert_eq(t1.degats_adversaire, 0, "esquive reussie -> Billy ne subit rien")
	assert_eq(t1.degats_billy, 6, "table[4][5] normal, l'esquive ne change QUE ce que Billy subit")
	assert_eq(_combat._controller.etat_courant().billy.pv, 20, "aucun degat subi ce tour")

	var t2 = await _combat._play_turn(3, 1)  # attack_die ignore : le critique impose degats_max+critique
	assert_true(t2.esquive)
	assert_true(t2.contre_attaque_critique)
	assert_eq(t2.degats_adversaire, 0)
	assert_eq(t2.degats_billy, 8, "degats max de la situation (6) + Critique (2)")

	assert_true(_combat.is_resolved(), "14 - 6 - 8 = 0")
	assert_eq(_combat._controller.get_winner(), "billy")
	assert_eq(_combat._controller.etat_courant().billy.pv, 20, "Billy n'a jamais ete touche sur ce scenario")
	assert_eq(_nb_tours_dans_la_strip(), 2)
	assert_eq(_combat._resolution_title.text, "Victoire")


func test_scenario_avec_degats_periodiques_entre_les_tours():
	# Nœud 97 (MASSACRE) : brasier de 3 PV tous les 3 tours, en plus de
	# l'echange normal -- un "troisieme temps" hors du bond attaquant/
	# defenseur habituel. Hab 9 vs 9 (diff=0), face 3 -> table[0][2]=[3,3]
	# chaque tour normal.
	var Mods = preload('res://combat_modificateurs.gd')
	var brasier = Mods.DegatsPeriodiques.new(3, 3, "billy", false, false, 1)
	_combat.start_combat("Massacre", 9, 9, 30, 30, {"modificateurs": [brasier]})

	await _combat._play_turn(3)  # tour 1 : normal seulement
	assert_eq(_combat._controller.etat_courant().billy.pv, 27, "30 - 3, pas encore de brasier")
	await _combat._play_turn(3)  # tour 2 : normal seulement
	assert_eq(_combat._controller.etat_courant().billy.pv, 24, "27 - 3, toujours pas de brasier")

	var t3 = await _combat._play_turn(3)  # tour 3 : normal + brasier
	assert_eq(t3.degats_supplementaires_adversaire, 3, "le brasier cible Billy -- stocke cote 'adversaire' dans EtatTour")
	assert_eq(_combat._controller.etat_courant().billy.pv, 18, "24 - 3 (normal) - 3 (brasier)")
	assert_eq(_combat._controller.etat_courant().adversaire.pv, 21, "le brasier ne touche pas l'adversaire")
	assert_true(_combat._last_turn_line.text.contains("effet spécial"),
		"le troisieme temps doit etre annonce a l'ecran, pas juste un PV qui bouge sans explication")


func test_scenario_ennemi_nattaque_pas_au_premier_tour():
	# Nœuds 321/349 : entree spectaculaire/surprise, l'ennemi ne porte
	# aucune attaque au 1er tour. Hab 9 vs 5 (diff=4), face 6 ->
	# table[4][5]=[6,1] : sans le modificateur Billy subirait 1 degat.
	var Mods = preload('res://combat_modificateurs.gd')
	var surprise = Mods.SansAttaqueTour.new(1, 1)
	_combat.start_combat("Guerriers surpris", 9, 5, 20, 20, {"modificateurs": [surprise]})

	var t1 = await _combat._play_turn(6)
	assert_eq(t1.degats_billy, 6, "Billy attaque normalement, seule la riposte adverse est supprimee")
	assert_eq(t1.degats_adversaire, 0, "l'ennemi surpris ne riposte pas ce tour")
	assert_true(t1.sans_attaque_adversaire,
		"doit etre distingue d'un simple 0 naturel, pour que l'ecran affiche un message plutot qu'un 0 muet")
	assert_eq(_combat._controller.etat_courant().billy.pv, 20, "aucun degat subi malgre une table qui en promettait 1")

	var t2 = await _combat._play_turn(6)  # le malus ne couvre que le tour 1
	assert_eq(t2.degats_adversaire, 1, "a partir du tour 2, l'ennemi riposte normalement")
	assert_false(t2.sans_attaque_adversaire, "le malus ne couvre que le tour 1")
	assert_eq(_combat._controller.etat_courant().billy.pv, 19)
	assert_eq(_combat._controller.etat_courant().adversaire.pv, 8, "20 - 6 - 6")


func test_scenario_habilete_adverse_degressive_affichee_a_lecran():
	# Nœud 76 : -1 Habileté tous les 4 PV cumules infliges. Hab 9 vs 12
	# (diff=-3), face 6 chaque tour -- verifie que l'affichage de la stat
	# (pas seulement le controleur/moteur) suit la baisse au bon moment.
	var Mods = preload('res://combat_modificateurs.gd')
	var degressive = Mods.HabiliteAdverseDegressiveParDegatsCumules.new(4, 1)
	_combat.start_combat("Guerriers Squelettes", 9, 12, 30, 100, {"modificateurs": [degressive]})
	assert_eq(_combat._enemy_stat_hab.text, "12")

	var t1 = await _combat._play_turn(6)  # diff=-3, table[-3][5]=[4,3]
	assert_eq(t1.degats_billy, 4)
	assert_eq(_combat._enemy_stat_hab.text, "12", "seuil pas encore franchi PENDANT ce tour")

	var t2 = await _combat._play_turn(6)  # 4 PV cumules -> 1 palier franchi -> diff passe a -2
	assert_eq(t2.hab_adversaire_tour, 11)
	assert_eq(t2.degats_billy, 5, "table[-2][5]=[5,3] : Billy inflige plus, l'ennemi est affaibli")
	assert_eq(_combat._enemy_stat_hab.text, "11", "l'affichage doit refleter la baisse, pas juste le moteur")

	# Revenir en arriere doit aussi corriger l'affichage (silencieusement,
	# pas de pulse pour un retour dans le temps).
	_combat._on_turn_chip_pressed(2)
	assert_eq(_combat._enemy_stat_hab.text, "12", "de retour avant le seuil franchi")
