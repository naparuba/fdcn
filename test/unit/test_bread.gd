extends "res://addons/gut/test.gd"

var BreadScene = preload('res://bread.tscn')
var FakeMain = preload('res://test/unit/fakes/fake_main_jump_recorder.gd')


func test_set_chap_number_and_label_without_underline_when_current():
	var b = BreadScene.instantiate()
	b.set_chap_number(42)
	b.set_current()
	assert_eq(b.get_node('ElLabel').text, '42')
	b.free()


func test_label_has_underline_when_not_current():
	var b = BreadScene.instantiate()
	b.set_chap_number(42)
	b.set_previous()
	assert_eq(b.get_node('ElLabel').text, '[u]42[/u]')
	b.free()


func test_set_current_uses_the_current_color():
	var b = BreadScene.instantiate()
	b.set_current()
	assert_eq(b.get_node('Polygon2D').color, Color('00c2aa'))
	assert_true(b.is_current)
	b.free()


func test_set_previous_uses_the_previous_color():
	var b = BreadScene.instantiate()
	b.set_previous()
	assert_eq(b.get_node('Polygon2D').color, Color('01bcdb'))
	assert_false(b.is_current)
	b.free()


func test_clicking_current_node_does_not_jump():
	var b = BreadScene.instantiate()
	var fake_main = FakeMain.new()
	b.set_main(fake_main)
	b.set_chap_number(42)
	b.set_current()
	b._on_button_pressed()
	assert_eq(fake_main.jump_back_calls, [])
	b.free()
	fake_main.free()


func test_clicking_a_previous_node_jumps_back_to_it():
	var b = BreadScene.instantiate()
	var fake_main = FakeMain.new()
	b.set_main(fake_main)
	b.set_chap_number(42)
	b.set_previous()
	b._on_button_pressed()
	assert_eq(fake_main.jump_back_calls, [42])
	b.free()
	fake_main.free()
