extends "res://addons/gut/test.gd"

var TopMenuScene = preload('res://top_menu.tscn')
var FakeMain = preload('res://test/unit/fakes/fake_main_ui.gd')


func before_each():
	AppParameters.set_book_number(1)
	AppParameters.set_spoils(true)
	AppParameters.set_sound(true)
	AppParameters.set_billy_type('pegu')


func after_each():
	AppParameters.set_book_number(1)
	AppParameters.set_spoils(true)
	AppParameters.set_sound(true)


func test_set_spoils_reflects_current_parameter():
	var tm = TopMenuScene.instance()
	AppParameters.set_spoils(true)
	tm.set_spoils()
	assert_true(tm.get_node('SpoilButton').pressed)
	AppParameters.set_spoils(false)
	tm.set_spoils()
	assert_false(tm.get_node('SpoilButton').pressed)
	tm.free()


func test_set_sound_reflects_current_parameter():
	var tm = TopMenuScene.instance()
	AppParameters.set_sound(false)
	tm.set_sound()
	assert_false(tm.get_node('SoundButton').pressed)
	AppParameters.set_sound(true)
	tm.set_sound()
	assert_true(tm.get_node('SoundButton').pressed)
	tm.free()


func test_set_billy_highlights_the_current_billy_block():
	var tm = TopMenuScene.instance()
	AppParameters.set_billy_type('guerrier')
	tm.set_billy()
	assert_eq(tm.get_node('Billys/BlockGuerrier').get('custom_styles/panel').bg_color, Color('9ea8b4'))
	assert_eq(tm.get_node('Billys/BlockPaysan').get('custom_styles/panel').bg_color, Color('e9eaec'))
	assert_eq(tm.get_node('Billys/BillyTypeLabel').text, 'Guerrier')
	tm.free()


func test_set_billy_pegu_highlights_nothing():
	var tm = TopMenuScene.instance()
	AppParameters.set_billy_type('pegu')
	tm.set_billy()
	assert_eq(tm.get_node('Billys/BlockGuerrier').get('custom_styles/panel').bg_color, Color('e9eaec'))
	assert_eq(tm.get_node('Billys/BillyTypeLabel').text, 'Pegu!!')
	tm.free()


func test_set_page_highlights_the_current_page():
	var tm = TopMenuScene.instance()
	tm.set_page('chapitres')
	assert_eq(tm.get_node('Pages/BlockChapitres').get('custom_styles/panel').bg_color, Color('9ea8b4'))
	assert_eq(tm.get_node('Pages/BlockMain').get('custom_styles/panel').bg_color, Color('e9eaec'))
	tm.free()


func test_set_book_context_shows_fdcn_panel_for_book_1():
	var tm = TopMenuScene.instance()
	AppParameters.set_book_number(1)
	tm.set_book_context()
	assert_true(tm.get_node('BookSelection/BookDisplayFdcn').visible)
	assert_false(tm.get_node('BookSelection/BookDisplayCdsi').visible)
	tm.free()


func test_set_book_context_shows_cdsi_panel_for_book_2():
	var tm = TopMenuScene.instance()
	AppParameters.set_book_number(2)
	tm.set_book_context()
	assert_false(tm.get_node('BookSelection/BookDisplayFdcn').visible)
	assert_true(tm.get_node('BookSelection/BookDisplayCdsi').visible)
	AppParameters.set_book_number(1)
	tm.free()


func test_spoil_button_toggled_delegates_to_main():
	var tm = TopMenuScene.instance()
	var fake_main = FakeMain.new()
	tm.register_main(fake_main)
	tm._on_spoil_button_toggled(false)
	assert_has(fake_main.calls, ['change_spoils', false])
	tm.free()
	fake_main.free()


func test_sound_button_toggled_delegates_to_main():
	var tm = TopMenuScene.instance()
	var fake_main = FakeMain.new()
	tm.register_main(fake_main)
	tm._on_sound_button_toggled(false)
	assert_has(fake_main.calls, ['change_sound', false])
	tm.free()
	fake_main.free()


func test_switch_to_guerrier_delegates_to_main():
	var tm = TopMenuScene.instance()
	var fake_main = FakeMain.new()
	tm.register_main(fake_main)
	tm._switch_to_guerrier()
	assert_has(fake_main.calls, ['_switch_to_guerrier', null])
	tm.free()
	fake_main.free()


func test_on_button_options_delegates_to_main():
	var tm = TopMenuScene.instance()
	var fake_main = FakeMain.new()
	tm.register_main(fake_main)
	tm._on_button_options()
	assert_has(fake_main.calls, ['_on_option_btn_pressed', null])
	tm.free()
	fake_main.free()
