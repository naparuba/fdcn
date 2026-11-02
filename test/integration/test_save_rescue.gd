extends "res://addons/gut/test.gd"

# Test d'integration de l'autoload SaveRescue (save_rescue.gd) : copie de nos
# fichiers de sauvegarde dans un dossier lisible par le joueur. Ecrit de vrais
# fichiers user:// : lancer uniquement avec XDG_DATA_HOME pointe vers un
# repertoire temporaire (cf TEST_PLAN.md).
#
# On instancie le script a part (et non l'autoload SaveRescue) pour pouvoir
# fixer export_dir : hors Android l'autoload reste inactif (export_dir vide).

const SaveRescueScript = preload("res://save_rescue.gd")

const OUT_DIR = "user://test_rescue_out"
const UNRELATED_FILE = "user://test_rescue_unrelated.txt"
const FAKE_LOG = "user://logs/test_rescue_fake.log"
# Livre 7 : numero qui n'existe pas, pour ne jamais toucher une vraie save.
const OUR_FILES = [
	"user://current_node_id-7.json",
	"user://possessed_item-7.save",
	"user://all_times_already_visited-7.json",
	"user://bug_book_2_fixed.flag.json",
]


func before_each():
	_cleanup()


func after_each():
	_cleanup()


func _cleanup():
	for pth in OUR_FILES + [UNRELATED_FILE, FAKE_LOG]:
		if FileAccess.file_exists(pth):
			DirAccess.remove_absolute(pth)
	_remove_dir_recursive(OUT_DIR)


func _remove_dir_recursive(pth):
	var d = DirAccess.open(pth)
	if d == null:
		return
	for sub in d.get_directories():
		_remove_dir_recursive(pth.path_join(sub))
	for file_name in d.get_files():
		d.remove(file_name)
	DirAccess.remove_absolute(pth)


func _write(pth, content):
	var f = FileAccess.open(pth, FileAccess.WRITE)
	f.store_string(content)
	f.close()


func _read(pth):
	var f = FileAccess.open(pth, FileAccess.READ)
	var text = f.get_as_text()
	f.close()
	return text


func _make_rescue(export_dir):
	var rescue = autofree(SaveRescueScript.new())
	rescue.export_dir = export_dir
	return rescue


func _write_our_files():
	for pth in OUR_FILES:
		_write(pth, "contenu de " + pth)


func test_does_nothing_when_export_dir_is_empty():
	_write_our_files()
	var rescue = _make_rescue("")

	assert_true(rescue.rescue_save_files())
	assert_false(DirAccess.dir_exists_absolute(OUT_DIR), "rien ne doit etre cree hors Android")


func test_copies_only_our_save_files():
	_write_our_files()
	_write(UNRELATED_FILE, "pas a nous")
	var rescue = _make_rescue(OUT_DIR)

	assert_true(rescue.rescue_save_files())

	for snapshot in ["initial", "latest"]:
		for pth in OUR_FILES:
			var copy = OUT_DIR.path_join(snapshot).path_join(pth.get_file())
			assert_true(FileAccess.file_exists(copy), "%s doit etre copie dans %s" % [pth.get_file(), snapshot])
			assert_eq(_read(copy), "contenu de " + pth, "contenu identique a l'original")
		assert_false(FileAccess.file_exists(OUT_DIR.path_join(snapshot).path_join(UNRELATED_FILE.get_file())),
			"un fichier qui n'est pas une save ne doit pas etre copie")


func test_copies_engine_logs():
	_write(FAKE_LOG, "ligne de log")
	var rescue = _make_rescue(OUT_DIR)

	rescue.rescue_save_files()

	var copy = OUT_DIR.path_join("latest").path_join("logs").path_join(FAKE_LOG.get_file())
	assert_true(FileAccess.file_exists(copy), "les logs du moteur doivent etre copies")
	assert_eq(_read(copy), "ligne de log")


func test_initial_snapshot_is_never_overwritten_but_latest_is_refreshed():
	_write(OUR_FILES[0], "avant migration")
	var rescue = _make_rescue(OUT_DIR)
	rescue.rescue_save_files()

	_write(OUR_FILES[0], "apres migration")
	rescue.rescue_save_files()

	var name = OUR_FILES[0].get_file()
	assert_eq(_read(OUT_DIR.path_join("initial").path_join(name)), "avant migration",
		"la photo initiale doit garder l'etat d'avant")
	assert_eq(_read(OUT_DIR.path_join("latest").path_join(name)), "apres migration",
		"la photo latest doit etre rafraichie")


func test_latest_drops_files_that_no_longer_exist():
	_write_our_files()
	var rescue = _make_rescue(OUT_DIR)
	rescue.rescue_save_files()

	DirAccess.remove_absolute(OUR_FILES[0])
	rescue.rescue_save_files()

	assert_false(FileAccess.file_exists(OUT_DIR.path_join("latest").path_join(OUR_FILES[0].get_file())),
		"latest ne doit pas garder un fichier disparu")
	assert_true(FileAccess.file_exists(OUT_DIR.path_join("initial").path_join(OUR_FILES[0].get_file())),
		"initial garde l'historique")


func test_writes_info_file_even_with_nothing_to_copy():
	var rescue = _make_rescue(OUT_DIR)

	assert_true(rescue.rescue_save_files())

	var info = OUT_DIR.path_join("latest").path_join(SaveRescueScript.INFO_FILE_NAME)
	assert_true(FileAccess.file_exists(info), "le descriptif doit exister")
	assert_string_contains(_read(info), "fichiers copies")


func test_save_file_filter():
	var rescue = _make_rescue("")
	assert_true(rescue._is_our_save_file("current_node_id-2.save"))
	assert_true(rescue._is_our_save_file("possessed_item.json"))
	assert_true(rescue._is_our_save_file("bug_book_2_fixed.flag.save"))
	assert_false(rescue._is_our_save_file("project.binary"))
	assert_false(rescue._is_our_save_file("settings.json"))
	assert_false(rescue._is_our_save_file("current_node_id-2.txt"))
