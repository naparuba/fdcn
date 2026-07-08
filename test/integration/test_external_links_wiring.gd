extends "res://addons/gut/test.gd"

# Les 4 liens externes (bug report, twitter auteur, wiki lore, twitter
# illustratrice) appellent OS.shell_open() : on ne doit JAMAIS les invoquer
# reellement dans un test automatise (ouvrirait un vrai navigateur / ferait
# une vraie requete reseau selon l'environnement). Ce test verifie que le
# CABLAGE est correct (bouton -> bon handler -> bonne URL) sans jamais
# appeler les fonctions elles-memes.

var _main = null


func before_all():
	AppParameters.set_book_number(1)
	Player.insert_all_objects()
	Player.launch_new_billy()

	var main_scene = load("res://main.tscn")
	_main = main_scene.instance()
	add_child(_main)


func after_all():
	_main.free()


func _main_source_text():
	var f = File.new()
	f.open("res://main.gd", File.READ)
	var text = f.get_as_text()
	f.close()
	return text


func test_bug_report_button_is_wired_to_the_right_handler():
	var button = _main.get_node("About/Actions/new_bug/Button")
	assert_true(button.is_connected("pressed", _main, "_on_button_bug"))
	assert_true(_main.has_method("_on_button_bug"))


func test_twitter_button_is_wired_to_the_right_handler():
	var button = _main.get_node("About/About/twitter/Button")
	assert_true(button.is_connected("pressed", _main, "_on_button_pressed_twitter"))
	assert_true(_main.has_method("_on_button_pressed_twitter"))


func test_more_lore_button_is_wired_to_the_right_handler():
	var button = _main.get_node("Lore/Lore/Header/LinkButton")
	assert_true(button.is_connected("pressed", _main, "_on_morelore_button_pressed"))
	assert_true(_main.has_method("_on_morelore_button_pressed"))


func test_image_author_button_is_wired_to_the_right_handler():
	var button = _main.get_node("Lore/Lore/LoreAuthor/LinkButton")
	assert_true(button.is_connected("pressed", _main, "_on_image_author_button_pressed"))
	assert_true(_main.has_method("_on_image_author_button_pressed"))


func test_handlers_still_target_the_documented_urls():
	# Verification statique du texte source (jamais d'appel reel a
	# OS.shell_open) : detecte si une URL change sans que la doc/le test
	# ne soit mis a jour.
	var source = _main_source_text()
	assert_string_contains(source, "github.com/naparuba/fdcn/issues")
	assert_string_contains(source, "twitter.com/naparuba")
	assert_string_contains(source, "saga-de-billy.fandom.com")
	assert_string_contains(source, "twitter.com/DrazielUnicorn")
