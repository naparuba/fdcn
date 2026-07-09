extends "res://addons/gut/test.gd"

var GoingToLineScene = preload('res://going_to_line.tscn')
var FakeMain = preload('res://test/unit/fakes/fake_main_ui.gd')


func before_each():
	AppParameters.set_book_number(1)


func _make_line():
	var line = GoingToLineScene.instantiate()
	add_child_autofree(line)
	return line


func test_set_node_shows_button_text_with_id():
	var line = _make_line()
	line.set_node(BookData.get_chapter_data(128))
	assert_eq(line.get_node('MarginContainer/my_button').text, '=> 128')


func test_set_node_shows_combat_icon_for_combat_chapter():
	var line = _make_line()
	line.set_node(BookData.get_chapter_data(14))  # noeud avec combat
	assert_true(line.get_node('MarginContainer/combat').visible)


func test_set_node_hides_combat_icon_for_non_combat_chapter():
	var line = _make_line()
	line.set_node(BookData.get_chapter_data(128))
	assert_false(line.get_node('MarginContainer/combat').visible)


func test_set_node_shows_end_icon_for_ending_chapter():
	var line = _make_line()
	line.set_node(BookData.get_chapter_data(96))  # noeud de fin reel
	assert_true(line.get_node('MarginContainer/end').visible)


func test_set_all_times_already_visited_shows_the_tick():
	var line = _make_line()
	line.set_node(BookData.get_chapter_data(128))
	assert_false(line.get_node('MarginContainer/already_visited').visible)
	line.set_all_times_already_visited()
	assert_true(line.get_node('MarginContainer/already_visited').visible)


func test_clicking_the_button_asks_the_father_to_go_to_the_node():
	var line = _make_line()
	line.set_node(BookData.get_chapter_data(128))
	var fake_father = FakeMain.new()
	line.set_father(fake_father)
	line._on_Button_pressed()
	# node.get_id() vient du JSON compile -> c'est un float (128.0), pas un int
	assert_has(fake_father.calls, ['go_to_node', 128.0])
	fake_father.free()


func test_clicking_without_a_father_does_not_crash():
	var line = _make_line()
	line.set_node(BookData.get_chapter_data(128))
	assert_eq(line.father, null)
	line._on_Button_pressed()  # ne doit pas planter malgre father == null
