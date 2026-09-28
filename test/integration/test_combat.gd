extends "res://addons/gut/test.gd"

# Test d'integration sur le CABLAGE combat, via le VRAI main.tscn (pas de
# double) : go_to_node() doit appeler $Combat.start_combat() avec les
# bonnes valeurs (livre + joueur reel) et afficher/masquer le panneau au
# bon moment. Le comportement interactif du panneau lui-meme (tours,
# esquive, retour en arriere...) est teste separement et plus en detail
# dans test_combat_screen.gd, directement sur Combat.tscn -- exactement ce
# que son extraction en scene a part est censee permettre.
#
# Fixtures reelles du livre 1 :
# - noeud 14 : combat simple, pyro=4 (bonus allie visible)
# - noeud 276 : combat (liste), pyro=0 (bonus allie masque)
# - noeud 1 : pas de combat

var _main = null

const COMBAT_NODE_WITH_PYRO = 14
const COMBAT_NODE_NO_PYRO = 276
const NON_COMBAT_NODE = 1


func before_all():
	AppParameters.set_book_number(1)
	Player.insert_all_objects()
	Player.launch_new_billy()
	# launch_new_billy() ne calcule/soigne jamais les PV (dans le vrai jeu,
	# c'est toujours un chapitre qui les fixe avant le premier combat) --
	# sans ça Player.pv reste a 0 et tout combat demarre deja "resolu",
	# meme piege que heal_billy_full en E2E (cf e2e_runner.gd).
	Player._recompute_stats()
	Player.pv = Player.pv_max

	var main_scene = load("res://main.tscn")
	_main = main_scene.instantiate()
	add_child(_main)


func after_all():
	_main.free()


func before_each():
	AppParameters.set_billy_type('pegu')
	# Player.possessed_items/arrival_snapshot sont des singletons partages
	# par toute la suite -- les tests d'abandon de combat (§9) les mutent,
	# on les remet a un etat neutre avant CHAQUE test pour que l'ordre
	# d'execution ne compte pas (meme piege que Sounder.player.stream, cf
	# test_success_popup.gd).
	Player.possessed_items = []
	Player.arrival_snapshot = {"retour": -1, "pv": 0, "cha": 0, "items": []}


func test_combat_panel_hidden_on_non_combat_node():
	_main.go_to_node(COMBAT_NODE_WITH_PYRO)
	_main.go_to_node(NON_COMBAT_NODE)
	assert_false(_main.get_node("Combat").visible)


func test_combat_panel_shows_enemy_stats():
	_main.go_to_node(COMBAT_NODE_WITH_PYRO)
	var combat = _main.get_node("Combat")
	assert_true(combat.visible)
	assert_eq(combat._enemy_name_label.text, 'GUERRIERS ORCS')
	var etat = combat._controller.etat_courant()
	assert_eq(etat.adversaire.pv, 8)
	assert_eq(etat.hab_adversaire_tour, 5)
	assert_eq(combat._enemy_stat_arm.text, '0')
	assert_eq(combat._enemy_stat_deg.text, '0')


func test_combat_panel_shows_pyro_bonus_when_nonzero():
	_main.go_to_node(COMBAT_NODE_WITH_PYRO)
	var combat = _main.get_node("Combat")
	assert_true(combat._player_pyro_tag.visible)
	assert_eq(combat._player_pyro_tag.text, '+4 Pyro-Barbare (Habileté)')


func test_combat_panel_hides_pyro_bonus_when_zero():
	_main.go_to_node(COMBAT_NODE_NO_PYRO)
	assert_false(_main.get_node("Combat")._player_pyro_tag.visible)


func test_combat_panel_shows_real_player_stats():
	AppParameters.set_billy_type('guerrier')
	Player._recompute_stats()
	_main.go_to_node(COMBAT_NODE_WITH_PYRO)
	var combat = _main.get_node("Combat")
	assert_eq(combat._player_stat_arm.text, '%s' % Player.get_arm())
	assert_eq(combat._player_stat_deg.text, '%s' % Player.get_deg())
	assert_eq(combat._player_stat_adr.text, '%s' % Player.get_adr())
	assert_eq(combat._player_stat_crit.text, '%s' % Player.get_crit())
	assert_eq(combat._controller.etat_courant().billy.pv, Player.get_pv())
	assert_eq(combat._pv_billy_max, Player.pv_max,
		"la barre de PV de Billy doit se caler sur son vrai max, pas sur son PV d'entree en combat")


func test_debrouillard_a_bien_le_pouvoir_de_relance_en_vrai_combat():
	AppParameters.set_billy_type('debrouillard')
	Player._recompute_stats()
	_main.go_to_node(COMBAT_NODE_NO_PYRO)
	var combat = _main.get_node("Combat")
	assert_true(combat._controller.combat.peut_relancer_attaque,
		"main.gd doit transmettre peut_relancer_attaque=true pour un vrai Billy DEBROUILLARD")


func test_non_debrouillard_na_pas_le_pouvoir_de_relance():
	AppParameters.set_billy_type('guerrier')
	Player._recompute_stats()
	_main.go_to_node(COMBAT_NODE_NO_PYRO)
	var combat = _main.get_node("Combat")
	assert_false(combat._controller.combat.peut_relancer_attaque)


func test_abandonner_le_combat_restaure_pv_chance_objets_et_revient_au_chapitre_precedent():
	# §9 (PR16_RECOVERY_PLAN.md) : l'abandon doit annuler tout effet du
	# chapitre de combat lui-meme, pas seulement fermer le panneau -- via
	# Player.arrival_snapshot, pris par go_to_node() AVANT que le noeud 14
	# n'applique quoi que ce soit (cf player.gd).
	_main.go_to_node(NON_COMBAT_NODE)
	Player.pv = 15
	Player.cha = 3
	Player.possessed_items = ["EPEE"]  # item reel -- _recompute_stats() (appele via refresh())
	# exige un id connu de BookData, cf player.gd::_recompute_stats().
	_main.go_to_node(COMBAT_NODE_WITH_PYRO)
	# Simule ce que le combat (ou le chapitre lui-meme) a change en route --
	# le vrai jeu ne synchronise jamais Player.pv depuis le simulateur de
	# des (cf combat.gd::get_pv_delta_billy, jamais appele hors tests), donc
	# on mute directement l'autoload comme le ferait n'importe quel autre
	# effet de chapitre.
	Player.pv = 4
	Player.cha = 0
	Player.possessed_items = ["EPEE", "ARC"]
	var combat = _main.get_node("Combat")
	combat._on_abandon_pressed()
	assert_false(combat.visible, "le panneau de combat doit disparaitre completement")
	assert_eq(Player.get_current_node_id(), NON_COMBAT_NODE, "retour exact au chapitre quitte pour entrer dans le combat")
	assert_eq(Player.pv, 15, "PV restaures a leur valeur d'avant le chapitre de combat")
	assert_eq(Player.cha, 3, "chance restauree a sa valeur d'avant le chapitre de combat")
	assert_eq(Player.possessed_items, ["EPEE"], "objets restaures a leur etat d'avant le chapitre de combat")


func test_abandonner_le_combat_ne_fait_rien_sans_chapitre_precedent():
	_main.go_to_node(COMBAT_NODE_WITH_PYRO)
	# Simule le tout premier noeud d'une session (retour=-1, cf
	# player.gd::arrival_snapshot) sans reconstruire une vraie session
	# complete via launch_new_billy() -- ca remettrait a zero un etat
	# partage par tout le reste de ce fichier de test.
	Player.arrival_snapshot = {"retour": -1, "pv": 0, "cha": 0, "items": []}
	var combat = _main.get_node("Combat")
	var node_avant = Player.get_current_node_id()
	combat._on_abandon_pressed()
	assert_true(combat.visible, "sans chapitre precedent ou revenir, l'abandon ne doit rien faire")
	assert_eq(Player.get_current_node_id(), node_avant)


func test_paysan_a_bien_son_plafond_de_degats_subis_en_vrai_combat():
	# §0 (PR16_RECOVERY_PLAN.md) : bug pre-existant, jamais branche depuis
	# main.gd malgre combat.gd le sachant faire et le testant en isolation.
	AppParameters.set_billy_type('paysan')
	Player._recompute_stats()
	_main.go_to_node(COMBAT_NODE_NO_PYRO)
	var combat = _main.get_node("Combat")
	assert_eq(combat._controller.combat.plafond_degats_subis_billy, 3,
		"main.gd doit transmettre le plafond de 3 PV/tour pour un vrai Billy PAYSAN")


func test_non_paysan_na_pas_de_plafond_de_degats_subis():
	AppParameters.set_billy_type('guerrier')
	Player._recompute_stats()
	_main.go_to_node(COMBAT_NODE_NO_PYRO)
	var combat = _main.get_node("Combat")
	assert_null(combat._controller.combat.plafond_degats_subis_billy)


func test_bouton_jai_gagne_disponible_immediatement_depuis_main():
	# Le cablage complet du bouton "J'ai gagne" (cf CombatScreen.gd) est deja
	# teste en detail dans test_combat_screen.gd -- ici on verifie juste
	# qu'il reste bien accessible une fois le panneau affiche via le vrai
	# go_to_node(), pas seulement en instanciant Combat.tscn seul.
	_main.go_to_node(COMBAT_NODE_WITH_PYRO)
	var combat = _main.get_node("Combat")
	assert_false(combat.is_resolved())
	combat._on_manual_win_pressed()
	assert_true(combat.is_resolved())


func test_continuer_l_aventure_liberte_le_vrai_choix_de_suite_sous_le_panneau():
	# Regression grave : le panneau Combat (quasi plein ecran,
	# mouse_filter=STOP) recouvre Background/Next (les vrais choix de
	# suite) -- "CONTINUER L'AVENTURE" ne fermait que la petite carte de
	# resolution, jamais le panneau entier, donc bloquait le joueur pour
	# toujours apres n'importe quel combat. Verifie ici via le vrai
	# main.tscn, pas juste Combat.tscn isole, puisque c'est justement le
	# recouvrement d'un AUTRE noeud du meme arbre qui etait en cause.
	_main.go_to_node(COMBAT_NODE_WITH_PYRO)
	var combat = _main.get_node("Combat")
	combat._on_manual_win_pressed()
	combat._on_continue_pressed()
	assert_false(combat.visible, "le panneau de combat doit disparaitre completement")
	var choices = _main.get_node("Background/Next/ScrollContainer/Choices")
	assert_gt(choices.get_child_count(), 0,
		"le vrai choix de suite existe et doit redevenir accessible (rien ne doit plus le recouvrir)")
