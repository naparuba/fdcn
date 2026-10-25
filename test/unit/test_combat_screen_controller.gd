extends "res://addons/gut/test.gd"

# Teste combat_screen_controller.gd en isolation, sans aucune scene/noeud --
# la couche que l'ecran de combat (CombatScreen.gd) pilote reellement. Ne
# reteste PAS la table des situations elle-meme (deja couvert par
# test_combat_resolver.gd/test_combat_regles_speciales_*.gd) : seulement le
# comportement propre a cette couche (previsualisation, retour en arriere
# par numero de tour).

const Controller = preload('res://combat_screen_controller.gd')


func test_previsualisation_reflete_la_table_des_situations():
	var c = Controller.new(9, 9, 30, 30)  # diff=0
	var p = c.previsualisation(1)  # table[0][0] = [3, 5]
	assert_eq(p['dmg_ennemi'], 3)
	assert_eq(p['dmg_billy'], 5)


func test_previsualisation_ajoute_degat_et_retire_armure():
	var c = Controller.new(9, 9, 30, 30, {"deg_billy": 2, "armure_billy": 3})
	var p = c.previsualisation(1)  # base [3, 5] ; +2 degats billy, -3 armure billy (plancher 0)
	assert_eq(p['dmg_ennemi'], 5)
	assert_eq(p['dmg_billy'], 2)


func test_previsualisation_suit_lhabilete_effective_apres_baisse():
	var Mods = preload('res://combat_modificateurs.gd')
	var mod = Mods.HabiliteAdverseDegressiveParDegatsCumules.new(4, 1)
	var c = Controller.new(9, 12, 30, 100, {"modificateurs": [mod]})
	var avant = c.previsualisation(6)  # diff=-3, table[-3][5] = [4, 3]
	assert_eq(avant['dmg_ennemi'], 4)
	c.jouer_tour(6)  # inflige 4 PV (seuil franchi une fois)
	c.jouer_tour(5)  # inflige 4 PV de plus (8 cumules, 2 paliers) -> diff passe de -3 a -1
	var apres = c.previsualisation(6)  # table[-1][5] = [5, 3]
	assert_eq(apres['dmg_ennemi'], 5, "la previsualisation doit refleter l'Habileté adverse EFFECTIVE pour le PROCHAIN tour, pas celle deja figee sur le dernier tour joue")


func test_jouer_tour_renvoie_null_si_deja_resolu():
	var c = Controller.new(9, 5, 30, 1)
	c.jouer_tour(6)  # devrait suffire a mettre l'adversaire a 0 PV
	assert_true(c.is_resolved())
	assert_null(c.jouer_tour(6), "jouer un tour sur un combat termine ne doit rien faire")


func test_revenir_avant_tour_annule_jusqu_au_bon_tour():
	var c = Controller.new(9, 9, 30, 30)
	c.jouer_tour(1)
	c.jouer_tour(2)
	c.jouer_tour(3)
	assert_eq(c.prochain_tour(), 4)
	c.revenir_avant_tour(2)  # doit annuler les tours 3 ET 2, pas seulement le dernier
	assert_eq(c.prochain_tour(), 2, "apres 'revenir avant le tour 2', le prochain tour a jouer doit etre 2")


func test_revenir_avant_tour_restaure_les_pv_du_bon_moment():
	var c = Controller.new(9, 9, 30, 30)
	c.jouer_tour(1)  # table[0][0] = [3,5] -> adversaire 30-3=27, billy 30-5=25
	var pv_adversaire_apres_t1 = c.etat_courant().adversaire.pv
	c.jouer_tour(6)  # un autre tour, change encore les PV
	c.revenir_avant_tour(2)  # revient juste avant le tour 2 = etat du tour 1
	assert_eq(c.etat_courant().adversaire.pv, pv_adversaire_apres_t1)


func test_revenir_avant_tour_1_vide_completement_la_pile():
	var c = Controller.new(9, 9, 30, 30)
	c.jouer_tour(1)
	c.jouer_tour(2)
	c.revenir_avant_tour(1)
	assert_eq(c.prochain_tour(), 1)
	assert_false(c.peut_annuler(), "plus aucun tour dans la pile, revenu a l'etat initial")


func test_revenir_avant_tour_sans_effet_si_tour_futur():
	var c = Controller.new(9, 9, 30, 30)
	c.jouer_tour(1)
	c.revenir_avant_tour(50)  # 50 est dans le futur, aucun tour a annuler
	assert_eq(c.prochain_tour(), 2, "ne doit rien annuler si le tour demande n'a pas encore ete joue")


func test_delegue_correctement_peut_esquiver_et_gagnant():
	var c = Controller.new(9, 5, 30, 1, {"adresse_billy": 3})
	assert_true(c.peut_esquiver())
	c.jouer_tour(6)
	assert_eq(c.get_winner(), "billy")
