extends "res://addons/gut/test.gd"

# Test d'intégration sur les boutons Spoils/Son du bandeau superieur, en
# instanciant le VRAI main.tscn (pas un double de main comme dans
# test/unit/test_top_menu.gd) : on verifie que cliquer sur un bouton d'une
# des 5 instances de top_menu.tscn (une par page) se propage correctement a
# TOUTES les autres, et produit un vrai effet visible (masquage des
# secrets, coupure du son), pas juste un changement de valeur isolee.

var _main = null

const SECRET_NODE_ID = 13  # cf test/unit/test_bookdata.gd


func before_all():
	# Instancier main.tscn EN ENTIER (606 ChapterChoice + tout le catalogue
	# d'objets) est lourd : le faire une seule fois pour tout le fichier
	# plutot qu'a chaque test (avant cette version, 8 boots completes
	# faisaient timeout au dela de 30s).
	AppParameters.set_book_number(1)
	Player.insert_all_objects()
	Player.launch_new_billy()

	var main_scene = load("res://main.tscn")
	_main = main_scene.instantiate()
	add_child(_main)


func after_all():
	_main.free()


func before_each():
	AppParameters.set_spoils(true)
	AppParameters.set_sound(true)


func after_each():
	AppParameters.set_spoils(true)
	AppParameters.set_sound(true)


func _find_chapter_choice(node_id):
	var all_choices = _main.get_node("Chapitres/AllChapters/VScrollBar/Choices")
	for choice in all_choices.get_children():
		if choice.get_chapter_id() == node_id:
			return choice
	return null


func test_five_top_menu_instances_are_registered():
	assert_eq(len(_main.top_menus), 5)


func test_toggling_spoils_from_one_button_syncs_all_five():
	_main.change_spoils(false)
	for top_menu in _main.top_menus:
		assert_false(top_menu.get_node("SpoilButton").button_pressed,
			"les 5 instances de top_menu doivent refleter le meme etat de spoils")
	assert_false(AppParameters.are_spoils_ok())

	_main.change_spoils(true)
	for top_menu in _main.top_menus:
		assert_true(top_menu.get_node("SpoilButton").button_pressed)


func test_toggling_spoils_hides_a_secret_chapter_in_the_live_list():
	# Sans spoils, et sans jamais avoir vu le chapitre secret 13, il doit
	# apparaitre en mode "masque" (spoil_enabled=false) dans la liste
	# "Tous les chapitres" -- effet reel, pas juste un flag AppParameters.
	Player.visited_nodes_all_times = []  # jamais vu, meme pas cette session
	var choice = _find_chapter_choice(SECRET_NODE_ID)
	assert_not_null(choice, "le chapitre secret %s devrait exister dans la liste" % SECRET_NODE_ID)

	_main.change_spoils(true)
	assert_true(choice.spoil_enabled, "avec spoils actifs, tout est visible")

	_main.change_spoils(false)
	assert_false(choice.spoil_enabled, "sans spoils et jamais vu, le secret doit rester masque")


func test_toggling_spoils_off_then_on_reveals_secret_again_once_marked_seen():
	Player.visited_nodes_all_times.append(SECRET_NODE_ID)
	var choice = _find_chapter_choice(SECRET_NODE_ID)

	_main.change_spoils(false)
	assert_true(choice.spoil_enabled,
		"un secret DEJA vu doit rester visible meme sans spoils actifs")


func test_toggling_sound_from_one_button_syncs_all_five_and_stops_sounder():
	_main.change_sound(false)
	for top_menu in _main.top_menus:
		assert_false(top_menu.get_node("SoundButton").button_pressed)
	assert_false(AppParameters.is_sound_ok())
	assert_false(Sounder.is_enabled(),
		"change_sound doit repercuter jusqu'a Sounder (via AppParameters._apply_parameters)")

	_main.change_sound(true)
	for top_menu in _main.top_menus:
		assert_true(top_menu.get_node("SoundButton").button_pressed)
	assert_true(Sounder.is_enabled())


func test_sound_off_through_the_real_button_actually_prevents_playback():
	_main.change_sound(false)
	Sounder.play("billy-pegu.mp3")
	assert_false(Sounder.player.playing,
		"le bouton son doit reellement empecher la lecture, pas juste changer un flag")
	_main.change_sound(true)


func test_clicking_the_spoil_button_signal_handler_delegates_to_main():
	# _on_spoil_button_toggled est le vrai handler connecte au signal
	# "toggled" du bouton dans top_menu.tscn (voir top_menu.gd) : on
	# l'appelle directement, comme le ferait un vrai clic.
	var top_menu = _main.top_menus[0]
	top_menu._on_spoil_button_toggled(false)
	assert_false(AppParameters.are_spoils_ok())
	top_menu._on_spoil_button_toggled(true)
	assert_true(AppParameters.are_spoils_ok())


func test_clicking_the_sound_button_signal_handler_delegates_to_main():
	var top_menu = _main.top_menus[0]
	top_menu._on_sound_button_toggled(false)
	assert_false(AppParameters.is_sound_ok())
	top_menu._on_sound_button_toggled(true)
	assert_true(AppParameters.is_sound_ok())
