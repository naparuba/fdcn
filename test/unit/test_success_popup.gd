extends "res://addons/gut/test.gd"

var SuccessPopupScene = preload('res://SuccessPopup.tscn')

const REAL_SUCCESS = {'chapter': 26, 'id': 'POLIR-LANCE', 'label': 'Polir la lance?', 'txt': 'Vous avez choisi la Femme-Lezard'}


func test_update_and_show_fills_the_inner_success_panel():
	var popup = SuccessPopupScene.instantiate()
	add_child_autofree(popup)  # necessaire pour que popup() fonctionne correctement
	popup.update_and_show(REAL_SUCCESS)
	var inner = popup.get_node('wholebackground/PanelBorder/Success')
	assert_eq(inner.get_chapter_id(), 26)
	assert_eq(inner.get_node('Label').text, 'Polir la lance?')


func test_update_and_show_hides_the_chapter_number():
	var popup = SuccessPopupScene.instantiate()
	add_child_autofree(popup)
	popup.update_and_show(REAL_SUCCESS)
	var inner = popup.get_node('wholebackground/PanelBorder/Success')
	assert_false(inner.get_node('NBChapitre').visible)


func test_play_sound_is_a_noop_when_sound_disabled():
	Sounder.set_enabled(false)
	var popup = SuccessPopupScene.instantiate()
	add_child_autofree(popup)
	popup._new_success_play_sound()  # ne doit pas planter, ne joue rien
	Sounder.set_enabled(true)


func test_play_sound_sets_the_stream_when_sound_enabled():
	Sounder.set_enabled(true)
	var popup = SuccessPopupScene.instantiate()
	add_child_autofree(popup)
	popup._new_success_play_sound()
	assert_not_null(popup.get_node('AudioPlayer').stream)
