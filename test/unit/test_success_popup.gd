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
	# Passe desormais par Sounder (point de lecture unique de toute l'app,
	# cf PR16_RECOVERY_PLAN.md §22) au lieu d'un AudioPlayer local a la
	# popup -- on verifie donc le lecteur partage, pas un noeud propre.
	# Stream remis a null avant coup : Sounder est un singleton partage par
	# toute la suite, un test precedent peut avoir laisse un stream charge
	# (play() ne le vide jamais lui-meme, seulement stop() la lecture).
	Sounder.player.stream = null
	Sounder.set_enabled(false)
	var popup = SuccessPopupScene.instantiate()
	add_child_autofree(popup)
	popup._new_success_play_sound()
	assert_null(Sounder.player.stream, "son desactive -- le stream ne doit jamais etre charge")
	assert_false(Sounder.player.playing, "son desactive -- rien ne doit etre en train de jouer")
	Sounder.set_enabled(true)


func test_play_sound_sets_the_stream_when_sound_enabled():
	Sounder.set_enabled(true)
	var popup = SuccessPopupScene.instantiate()
	add_child_autofree(popup)
	popup._new_success_play_sound()
	assert_not_null(Sounder.player.stream)
