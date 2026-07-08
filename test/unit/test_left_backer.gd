extends "res://addons/gut/test.gd"

var LeftBackerScene = preload('res://left_backer.tscn')
var FakeMain = preload('res://test/unit/fakes/fake_main_ui.gd')


func _make_backer(txt, dest):
	var backer = LeftBackerScene.instance()
	backer.txt = txt
	backer.dest = dest
	add_child_autofree(backer)  # _ready() applique txt sur $txt.text
	return backer


func test_ready_applies_the_exported_text():
	var backer = _make_backer('Chapitres', 'chapitres')
	assert_eq(backer.get_node('txt').text, 'Chapitres')


func test_set_enabled_and_disabled_change_the_polygon_color():
	var backer = _make_backer('Chapitres', 'chapitres')
	backer.set_enabled()
	assert_eq(backer.get_node('poly').color, Color('313b47'))
	backer.set_disabled()
	assert_eq(backer.get_node('poly').color, Color('9ea8b4'))


func test_clicking_navigates_to_the_configured_destination():
	var backer = _make_backer('Chapitres', 'chapitres')
	var fake_main = FakeMain.new()
	Swiper.register_main(fake_main)
	backer._on_button_pressed()
	assert_has(fake_main.calls, ['set_camera_to_pos', 876])
	fake_main.free()
