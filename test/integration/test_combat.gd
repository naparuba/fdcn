extends "res://addons/gut/test.gd"

# Test d'integration sur le panneau de combat, via le VRAI main.tscn (pas
# de double). Fixtures reelles du livre 1 :
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
	assert_true(_main.get_node("Combat").visible)
	assert_eq(_main.get_node("Combat/Nom").text, 'GUERRIERS ORCS')
	assert_eq(_main.get_node("Combat/EnnemiPvValue").text, '8')
	assert_eq(_main.get_node("Combat/EnnemiHabValue").text, '5')
	assert_eq(_main.get_node("Combat/EnnemiArmValue").text, '0')
	assert_eq(_main.get_node("Combat/EnnemiDegValue").text, '0')


func test_combat_panel_shows_pyro_bonus_when_nonzero():
	_main.go_to_node(COMBAT_NODE_WITH_PYRO)
	assert_true(_main.get_node("Combat/SpritePyro").visible)
	assert_true(_main.get_node("Combat/PyroHab").visible)
	assert_eq(_main.get_node("Combat/PyroHab").text, '+4')


func test_combat_panel_hides_pyro_bonus_when_zero():
	_main.go_to_node(COMBAT_NODE_NO_PYRO)
	assert_false(_main.get_node("Combat/SpritePyro").visible)
	assert_false(_main.get_node("Combat/PyroHab").visible)


func test_combat_panel_shows_real_player_stats():
	AppParameters.set_billy_type('guerrier')
	Player._recompute_stats()
	_main.go_to_node(COMBAT_NODE_WITH_PYRO)
	assert_eq(_main.get_node("Combat/PlayerHabValue").text, '%s' % Player.get_hab())
	assert_eq(_main.get_node("Combat/PlayerArmValue").text, '%s' % Player.get_arm())
	assert_eq(_main.get_node("Combat/PlayerDegValue").text, '%s' % Player.get_deg())
	assert_eq(_main.get_node("Combat/PlayerPvValue").text, '%s' % Player.get_pv())


func test_dice_roll_sets_a_valid_texture():
	_main.go_to_node(COMBAT_NODE_WITH_PYRO)
	for i in range(10):  # plusieurs lancers pour couvrir plusieurs faces
		_main._on_dice_pressed()
		assert_not_null(_main.get_node("Combat/dice/sprite").texture)
