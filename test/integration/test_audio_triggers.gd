extends "res://addons/gut/test.gd"

# Test d'integration sur les declenchements audio pilotes par main.gd
# (_play_intro, _play_node_sound), via le VRAI main.tscn + le VRAI Sounder.
# On identifie le son reellement charge via stream.resource_path (les
# ressources chargees par load() conservent leur chemin d'origine).

var _main = null


func before_all():
	AppParameters.set_book_number(1)
	Player.insert_all_objects()
	Player.launch_new_billy()
	Sounder.set_enabled(true)

	var main_scene = load("res://main.tscn")
	_main = main_scene.instance()
	add_child(_main)


func after_all():
	_main.free()
	AppParameters.set_book_number(1)
	Sounder.set_enabled(true)


func test_boot_plays_the_fdcn_intro_for_book_1():
	# _do_load_book_context() (appele a _ready()) a deja joue l'intro au
	# tout premier boot dans before_all -- on le revalide explicitement.
	_main._play_intro()
	assert_string_contains(Sounder.player.stream.resource_path, 'intro-fdcn.mp3')


func test_play_intro_uses_cdsi_sound_for_book_2():
	AppParameters.set_book_number(2)
	_main._play_intro()
	assert_string_contains(Sounder.player.stream.resource_path, 'intro-cdsi.mp3')
	AppParameters.set_book_number(1)


func test_special_chapter_plays_its_dedicated_sound():
	AppParameters.set_book_number(1)
	_main.go_to_node(27)
	assert_string_contains(Sounder.player.stream.resource_path, '27-kakaka.mp3')

	_main.go_to_node(193)
	assert_string_contains(Sounder.player.stream.resource_path, '193-la-cathedrale.mp3')

	_main.go_to_node(216)
	assert_string_contains(Sounder.player.stream.resource_path, '216-tour-des-mages.mp3')

	_main.go_to_node(338)
	assert_string_contains(Sounder.player.stream.resource_path, '338-virilus-backstory.mp3')


func test_non_special_chapter_does_not_trigger_a_new_sound():
	_main.go_to_node(27)
	var stream_after_special = Sounder.player.stream
	_main.go_to_node(1)  # pas dans la liste des chapitres speciaux
	assert_eq(Sounder.player.stream, stream_after_special,
		"un chapitre non special ne doit pas changer le son courant de Sounder")


func test_no_special_chapter_sound_exists_for_book_2():
	AppParameters.set_book_number(2)
	_main.go_to_node(27)
	var stream_before = Sounder.player.stream
	_main.go_to_node(1)
	assert_eq(Sounder.player.stream, stream_before,
		"le livre 2/CDSI n'a aucun chapitre special configure (dict vide)")
	AppParameters.set_book_number(1)
