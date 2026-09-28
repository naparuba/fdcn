extends "res://addons/gut/test.gd"

# Preuve que le registre node_id -> Array[Modificateur]
# (combat_modificateurs_par_node.gd, PR16_RECOVERY_PLAN.md §0) est
# REELLEMENT cable depuis main.gd jusqu'a un vrai Combat en jeu -- pas
# seulement verifie en isolation (cf test_combat_modificateurs_par_node.gd,
# et le rappel explicite du plan : "ne pas se fier aux seuls tests
# unitaires existants comme preuve de succes ... verifier avec un vrai
# playthrough E2E"). Trois nœuds emblematiques (256 "Mimine", 97 "brasier
# periodique", 649 "benediction de Neit") sont verifies jusqu'a un EFFET
# OBSERVABLE reel, pas juste la presence de la bonne classe.

var _main = null
const Mods = preload('res://combat_modificateurs.gd')


func before_all():
	AppParameters.set_book_number(1)
	Player.insert_all_objects()
	Player.launch_new_billy()
	Player._recompute_stats()
	Player.pv = Player.pv_max

	var main_scene = load("res://main.tscn")
	_main = main_scene.instantiate()
	add_child(_main)


func after_all():
	_main.free()
	AppParameters.set_book_number(1)


func before_each():
	AppParameters.set_billy_type('pegu')
	Player.possessed_items = []
	# PV genereux (meme convention que test_combat_regles_speciales_tome1/2.gd) :
	# certains de ces nœuds (256 "Mimine" notamment) ont encore leurs vraies
	# stats "sentinelle" 99/99/99/99 en jeu (§8 du plan, pas encore traite) --
	# sans cette marge, Billy meurt de degats normaux avant meme que le
	# Modificateur teste ici n'ait la moindre chance de s'exprimer.
	Player.pv = 999


func _combat() -> Node:
	var combat = _main.get_node("Combat")
	combat.skip_animations = true
	return combat


func test_noeud_76_tome1_squelettes_reellement_cable_depuis_main():
	AppParameters.set_book_number(1)
	_main.go_to_node(76)
	var mods = _combat()._controller.combat.modificateurs
	assert_eq(mods.size(), 1)
	assert_true(mods[0] is Mods.HabiliteAdverseDegressiveParDegatsCumules,
		"le vrai go_to_node() doit transmettre le Modificateur du nœud 76 jusqu'au Combat reel")


func test_noeud_97_tome1_brasier_periodique_inflige_reellement_3pv_au_3eme_tour():
	AppParameters.set_book_number(1)
	_main.go_to_node(97)
	var combat = _combat()
	await combat._play_turn(3)
	await combat._play_turn(3)
	var t3 = await combat._play_turn(3)
	assert_eq(t3.degats_supplementaires_adversaire, 3,
		"le brasier periodique du nœud 97 doit reellement infliger 3 PV supplementaires au 3eme tour, via le vrai main.gd")


func test_noeud_240_tome1_esquive_reellement_desactivee_par_la_lance_en_jeu():
	AppParameters.set_book_number(1)
	Player.possessed_items = []
	_main.go_to_node(240)
	var sans_lance = _combat()._controller.combat.modificateurs
	assert_true(sans_lance[0].predicat.call(1), "sans LANCE/ARC, l'esquive du nœud 240 doit rester active en jeu reel")
	Player.possessed_items = ["LANCE"]
	_main.go_to_node(1)  # revient hors combat pour forcer un vrai re-cablage
	_main.go_to_node(240)
	var avec_lance = _combat()._controller.combat.modificateurs
	assert_false(avec_lance[0].predicat.call(1), "avec la LANCE reellement possedee, l'esquive du nœud 240 doit etre neutralisee en jeu reel")
	Player.possessed_items = []


func test_noeud_256_tome2_mimine_arrete_reellement_le_combat_sur_3_parites_identiques():
	AppParameters.set_book_number(2)
	_main.go_to_node(256)
	var combat = _combat()
	await combat._play_turn(2)
	await combat._play_turn(4)
	assert_false(combat.is_resolved(), "seulement 2 jets pairs consecutifs -- pas encore")
	await combat._play_turn(6)
	assert_true(combat.is_resolved(), "3 jets pairs consecutifs -- Mimine doit reellement arreter le combat via le vrai main.gd")
	assert_eq(combat._controller.get_winner(), "billy")
	AppParameters.set_book_number(1)


func test_noeud_649_tome2_benediction_de_neit_esquive_reellement_sur_de_impair():
	AppParameters.set_book_number(2)
	_main.go_to_node(649)
	var combat = _combat()
	var t_impair = await combat._play_turn(1)
	assert_eq(t_impair.degats_adversaire, 0, "die impair -- la benediction de Neit doit reellement annuler les degats subis en jeu")
	var t_pair = await combat._play_turn(2)
	assert_gt(t_pair.degats_adversaire, 0, "die pair -- degats normaux, la benediction ne doit pas s'appliquer hors condition")
	AppParameters.set_book_number(1)
