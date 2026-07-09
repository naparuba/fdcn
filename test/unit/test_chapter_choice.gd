extends "res://addons/gut/test.gd"

var ChapterChoiceScene = preload('res://ChapterChoice.tscn')

func before_all():
	AppParameters.set_book_number(1)
	Player.insert_all_objects()


func before_each():
	Player.launch_new_billy()
	AppParameters.set_billy_type('pegu')
	AppParameters.set_spoils(true)
	# launch_new_billy() ne rappelle pas _recompute_matched_conditions():
	# sans ca, all_matched_conditions garde les objets/type d'un test
	# precedent (cache derive non invalide par le reset).
	Player._recompute_matched_conditions()


func _make_choice():
	return ChapterChoiceScene.instantiate()


func test_set_chapitre_updates_number_and_getter():
	var cc = _make_choice()
	cc.set_chapitre(184)
	assert_eq(cc.get_chapter_id(), 184)
	cc.free()


func test_update_from_son_node_flags_combat():
	var cc = _make_choice()
	Player.current_node_id = 1
	cc.update_from_son_node(BookData.get_node(14))  # noeud avec combat
	assert_eq(cc.get_node('CombatPolygon').color, Color('ff6f04'))
	cc.free()


func test_update_from_son_node_does_not_flag_combat_for_non_combat_node():
	var cc = _make_choice()
	Player.current_node_id = 1
	cc.update_from_son_node(BookData.get_node(128))  # pas de combat
	assert_ne(cc.get_node('CombatPolygon').color, Color('ff6f04'))
	cc.free()


func test_update_from_son_node_flags_ending():
	var cc = _make_choice()
	Player.current_node_id = 1
	cc.update_from_son_node(BookData.get_node(96))  # noeud de fin reel
	assert_eq(cc.get_node('EndPolygon').color, Color('00c2aa'))
	cc.free()


func test_update_from_son_node_flags_session_seen_after_visit():
	var cc = _make_choice()
	Player.go_to_node(128)
	Player.current_node_id = 128
	cc.update_from_son_node(BookData.get_node(128))
	assert_eq(cc.get_node('SessionSeenPolygon').color, Color('00c2aa'))
	cc.free()


func test_update_from_son_node_disables_special_jump_without_condition():
	var cc = _make_choice()
	Player.current_node_id = 10
	cc.update_from_son_node(BookData.get_node(461))  # fils de 10 sans condition
	assert_false(cc.get_node('special').visible)
	cc.free()


func test_update_from_son_node_enables_special_jump_when_condition_matches():
	var cc = _make_choice()
	Player.current_node_id = 10
	Player.add_item_from_options("KIT D'ESCALADE")
	cc.update_from_son_node(BookData.get_node(184))  # condition: KIT D'ESCALADE
	assert_true(cc.get_node('special').visible)
	assert_true(cc.get_node('click/special').visible)
	assert_false(cc.get_node('click/special_wrong').visible)
	cc.free()


func test_update_from_son_node_enables_special_jump_wrong_when_condition_unmet():
	var cc = _make_choice()
	Player.current_node_id = 10
	cc.update_from_son_node(BookData.get_node(184))  # condition non remplie
	assert_true(cc.get_node('special').visible)
	assert_false(cc.get_node('click/special').visible)
	assert_true(cc.get_node('click/special_wrong').visible)
	cc.free()


func test_set_spoil_enabled_toggles_child_visibility():
	var cc = _make_choice()
	cc.set_spoil_enabled(true)
	assert_true(cc.get_node('CombatPolygon').visible)
	cc.set_spoil_enabled(false)
	assert_false(cc.get_node('CombatPolygon').visible)
	cc.free()
