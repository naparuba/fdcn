extends "res://addons/gut/test.gd"

# Test d'intégration P0 : charge de VRAIES sauvegardes écrites par le vrai
# binaire Godot 3.6.2 (test/fixtures/save_formats_godot3/, cf son README),
# PAS un cycle fermé save-puis-reload avec le même code Godot 4 (déjà
# couvert par test_save_reload_cycle.gd). C'est le chemin qui a révélé un
# bug réel : FileAccess.get_var() ne peut pas lire ce format (cf
# godot3_variant_decoder.gd et le README des fixtures pour le détail).
#
# Même limite assumée que test_save_reload_cycle.gd : un seul processus
# Godot pour toute la suite -- on simule "un joueur qui vient de mettre à
# jour vers Godot 4 sans avoir jamais relancé Godot 3 depuis son dernier
# vrai fichier .save" en copiant les fixtures dans un user:// isolé
# (XDG_DATA_HOME temporaire, voir tests/README.md) avant d'appeler
# Player.do_load()/AppParameters._load_parameters().

const FIXTURES_DIR = "res://test/fixtures/save_formats_godot3/"


func before_all():
	AppParameters.set_book_number(1)
	Player.insert_all_objects()


func before_each():
	Player.current_node_id = 1
	Player.session_visited_nodes = []
	Player.visited_nodes_all_times = []
	Player.possessed_items = []
	Player.need_force_display_options = false
	Player._fully_reset_our_stats()


func _delete_if_exists(pth):
	# Meme piege que test_migration.gd::_delete_if_exists -- _load_var()
	# lit le miroir .json en PRIORITE : un miroir laisse par un AUTRE
	# fichier de test tourne dans le meme processus/user:// (GUT ne
	# redemarre pas Godot entre les fichiers) ferait ignorer completement
	# le binaire fraichement installe ci-dessous, meme s'il est correct.
	if FileAccess.file_exists(pth):
		DirAccess.remove_absolute(pth)
	var json_pth = pth.replace(".save", ".json")
	if json_pth != pth and FileAccess.file_exists(json_pth):
		DirAccess.remove_absolute(json_pth)


func _copy_fixture_into_user_dir(fname):
	_delete_if_exists("user://" + fname)
	var src = FileAccess.open(FIXTURES_DIR + fname, FileAccess.READ)
	var bytes = src.get_buffer(src.get_length())
	src.close()
	var dst = FileAccess.open("user://" + fname, FileAccess.WRITE)
	dst.store_buffer(bytes)
	dst.close()


func _install_all_player_fixtures():
	# Nom EXACT attendu par player.gd pour le livre 1 (FDCN).
	_copy_fixture_into_user_dir("current_node_id-1.save")
	_copy_fixture_into_user_dir("all_times_already_visited-1.save")
	_copy_fixture_into_user_dir("session_visited_nodes-1.save")
	_copy_fixture_into_user_dir("possessed_item-1.save")


func test_do_load_reads_a_real_godot3_save_correctly():
	# Contrat documenté dans test/fixtures/save_formats_godot3/README.md.
	_install_all_player_fixtures()

	Player.do_load()

	assert_eq(Player.current_node_id, 112)
	assert_eq(Player.visited_nodes_all_times, [1, 128, 112])
	assert_eq(Player.session_visited_nodes, [1, 128, 112])
	assert_eq(Player.possessed_items, ["PALAIS DES PLAISIRS D'YTIA", "EPEE"])


func test_do_load_writes_a_json_mirror_after_reading_the_legacy_binary():
	# Migration silencieuse : une fois lu, le binaire ne doit plus jamais
	# etre relu -- le miroir JSON prend le relais des le premier chargement.
	_install_all_player_fixtures()
	Player.do_load()

	var f = FileAccess.open("user://current_node_id-1.json", FileAccess.READ)
	assert_not_null(f, "le miroir JSON doit exister apres le premier chargement du binaire legacy")
	var value = Utils.ints_from_json(JSON.parse_string(f.get_as_text()))
	f.close()
	assert_eq(value, 112)


func test_do_load_second_call_reads_the_json_mirror_not_the_stale_binary():
	# Si le joueur avance puis recharge une seconde fois, le JSON (a jour)
	# doit primer sur le binaire (perime, jamais reecrit apres la migration).
	_install_all_player_fixtures()
	Player.do_load()
	Player.go_to_node(1)  # change l'etat en memoire ET reecrit le JSON (pas le binaire)

	Player.current_node_id = 1
	Player.session_visited_nodes = []
	Player.visited_nodes_all_times = []
	Player.possessed_items = []
	Player.do_load()

	assert_eq(Player.current_node_id, 1,
		"le 2eme chargement doit lire le JSON a jour (node 1), pas le binaire perime (node 112)")


func test_parameters_load_reads_a_real_godot3_save_correctly():
	# AppParameters._init() s'est deja execute au demarrage du moteur, avant
	# que ce test ne place la fixture -- on appelle donc _load_parameters()
	# une seconde fois, une fois la fixture en place, pour exercer le meme
	# chemin de fallback qu'un vrai (re)demarrage le ferait.
	_copy_fixture_into_user_dir("parameters.save")

	AppParameters._load_parameters()

	# "pegu" (pas "guerrier", le defaut compile) : c'est le vrai contenu du
	# fichier, tel qu'ecrit par le jeu lors de la generation de la fixture
	# (choix de personnage par defaut au premier lancement) -- pas une
	# valeur qu'on choisit arbitrairement pour le test.
	assert_eq(AppParameters.parameters.get("current_book"), 1)
	assert_eq(AppParameters.parameters.get("billy"), "pegu")
	assert_eq(AppParameters.parameters.get("spoils"), true)
	assert_eq(AppParameters.parameters.get("sound"), true)
