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


func test_bouton_jai_gagne_disponible_immediatement_depuis_main():
	# Le cablage complet du bouton "J'ai gagne" (cf Combat.gd) est deja
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
