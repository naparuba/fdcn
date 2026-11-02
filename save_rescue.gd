extends Node

# Autoload n°1 (AVANT tous les autres, cf project.godot) : au tout debut du
# lancement, copie NOS fichiers de sauvegarde (+ les logs du moteur) dans un
# dossier lisible par le joueur sans root ni adb, pour qu'il puisse nous les
# envoyer si l'app bloque au demarrage.
#
# Pourquoi dans _init() et pas _ready() : Godot instancie tous les autoloads
# (leur _init) puis seulement ensuite appelle leurs _ready, dans l'ordre. Si un
# autoload suivant (BookData, Player...) bloque dans son _init, notre _ready ne
# serait jamais atteint. Etant le premier de la liste, notre _init passe avant.
#
# Destination (Android uniquement) :
#   /storage/emulated/0/Android/data/<package>/files/fdcn_rescue/
# C'est le dossier "externe" propre a l'app : aucune permission requise, et
# visible depuis un PC en USB (mode "Transfert de fichiers"). Il est masque
# dans l'appli Fichiers du telephone depuis Android 11. Aucun getter Godot ne
# donne ce chemin : on le construit a partir du nom de paquet.
#
#   fdcn_rescue/initial/  photo du PREMIER lancement avec ce code, jamais
#                         ecrasee (avant toute migration de ce build)
#   fdcn_rescue/latest/   photo du lancement courant, rafraichie a chaque fois
#
# Hors Android, ne fait rien (export_dir vide) : les tests la surchargent.
# Ne doit JAMAIS planter ni bloquer le demarrage : on teste les retours et on
# se contente de logguer les echecs.

const ANDROID_PACKAGE = "org.naparuba.fdcn"
const RESCUE_DIR_NAME = "fdcn_rescue"
const INITIAL_DONE_MARKER = "_initial_done.txt"
const INFO_FILE_NAME = "rescue_info.txt"

# Prefixes des fichiers ecrits par player.gd dans user:// (avec ou sans
# suffixe "-N" de livre), en .save (ancien binaire) et .json (miroir).
const SAVE_PREFIXES = [
	"all_times_already_visited",
	"current_node_id",
	"session_visited_nodes",
	"possessed_item",
	"bug_book_2_fixed",
]
const SAVE_EXTENSIONS = [".save", ".json"]

var export_dir = ""


func _init():
	self.export_dir = self._default_export_dir()
	self.rescue_save_files()


func _default_export_dir():
	if OS.get_name() != "Android":
		return ""
	return "/storage/emulated/0/Android/data/%s/files/%s" % [ANDROID_PACKAGE, RESCUE_DIR_NAME]


# Retourne true si tout a ete copie sans erreur (ou rien a faire).
func rescue_save_files():
	if self.export_dir == "":
		return true
	if !self._ensure_dir(self.export_dir):
		printerr("SaveRescue:: impossible de creer le dossier: ", self.export_dir)
		return false

	var all_ok = true
	var initial_dir = self.export_dir.path_join("initial")
	var initial_marker = initial_dir.path_join(INITIAL_DONE_MARKER)
	if !FileAccess.file_exists(initial_marker):
		if self._snapshot_into(initial_dir):
			self._write_text(initial_marker, "initial snapshot complete\n")
		else:
			all_ok = false
	if !self._snapshot_into(self.export_dir.path_join("latest")):
		all_ok = false
	print("SaveRescue:: termine (ok=%s) -> %s" % [all_ok, self.export_dir])
	return all_ok


func _snapshot_into(target_dir):
	if !self._ensure_dir(target_dir):
		printerr("SaveRescue:: impossible de creer: ", target_dir)
		return false
	self._clear_dir(target_dir)

	var all_ok = true
	var copied = []

	var root = DirAccess.open("user://")
	if root != null:
		for file_name in root.get_files():
			if !self._is_our_save_file(file_name):
				continue
			if self._copy_file("user://" + file_name, target_dir.path_join(file_name)):
				copied.append(file_name)
			else:
				printerr("SaveRescue:: echec de copie: ", file_name)
				all_ok = false

	# Logs du moteur (godot.log + sessions precedentes si max_log_files > 1)
	var logs = DirAccess.open("user://logs")
	if logs != null:
		var target_logs = target_dir.path_join("logs")
		if self._ensure_dir(target_logs):
			for file_name in logs.get_files():
				if self._copy_file("user://logs/" + file_name, target_logs.path_join(file_name)):
					copied.append("logs/" + file_name)
				else:
					printerr("SaveRescue:: echec de copie du log: ", file_name)
					all_ok = false

	self._write_info(target_dir, copied)
	return all_ok


func _is_our_save_file(file_name):
	var has_extension = false
	for extension in SAVE_EXTENSIONS:
		if file_name.ends_with(extension):
			has_extension = true
	if !has_extension:
		return false
	for prefix in SAVE_PREFIXES:
		if file_name.begins_with(prefix):
			return true
	return false


func _ensure_dir(pth):
	if DirAccess.dir_exists_absolute(pth):
		return true
	DirAccess.make_dir_recursive_absolute(pth)
	return DirAccess.dir_exists_absolute(pth)


# Vide les fichiers d'un snapshot (et de son sous-dossier logs) avant de le
# refaire, pour ne pas y laisser de fichiers perimes.
func _clear_dir(pth):
	for dir_path in [pth, pth.path_join("logs")]:
		var d = DirAccess.open(dir_path)
		if d == null:
			continue
		for file_name in d.get_files():
			d.remove(file_name)


func _copy_file(from, to):
	var src = FileAccess.open(from, FileAccess.READ)
	if src == null:
		return false
	var bytes = src.get_buffer(src.get_length())
	src.close()
	var dst = FileAccess.open(to, FileAccess.WRITE)
	if dst == null:
		return false
	dst.store_buffer(bytes)
	dst.close()
	return true


func _write_text(pth, text):
	var f = FileAccess.open(pth, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	f.close()
	return true


# Petit descriptif a cote des fichiers : permet de voir d'un coup d'oeil, sans
# les ouvrir, de quel appareil/version ils viennent et ce qui a ete copie
# (y compris "rien", ce qui est une information en soi).
func _write_info(target_dir, copied):
	var lines = []
	lines.append("date: %s" % Time.get_datetime_string_from_system())
	lines.append("os: %s %s" % [OS.get_name(), OS.get_version()])
	lines.append("modele: %s" % OS.get_model_name())
	lines.append("moteur: %s" % Engine.get_version_info()["string"])
	lines.append("user_data_dir: %s" % OS.get_user_data_dir())
	lines.append("fichiers copies (%d):" % copied.size())
	for file_name in copied:
		lines.append("  - %s" % file_name)
	self._write_text(target_dir.path_join(INFO_FILE_NAME), "\n".join(lines) + "\n")
