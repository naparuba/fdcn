extends Panel
## Page « À propos » : branchement de ses boutons, qui n'étaient reliés à rien.
##
## La scène est reconstruite en conteneurs (2026-08-12) : c'était la dernière de l'app en
## position absolue pure — 13 `layout_mode = 0`, 65 `offset_*`, zéro conteneur.
##
## Deux bugs sont tombés avec la réécriture, tous deux invisibles à la lecture du script :
##
## - le bouton Twitter avait une zone cliquable de **145×87 pour un panneau de 27×26**, donc
##   cinq fois trop grande — on ouvrait Twitter en cliquant à côté ;
## - `Disclaimer` (y 555→798) **chevauchait** `NotesTxt` (y 461→628).
##
## Le texte vit maintenant dans un `ScrollContainer` : il dépassait de l'écran (le dernier
## libellé finissait à y ≈ 1000 pour une zone d'environ 870) et rien ne permettait d'y accéder.

## Le texte de confirmation vient de `choice_next_chapiter`, qui offre le même bouton :
## une seule formulation pour une seule conséquence.
const _NOUVEAU_BILLY_TEXTE := preload(
	"res://screens/aventure_menu/choice_next_chapiter.gd").NOUVEAU_BILLY_TEXTE

const _URL_BUG := "https://github.com/naparuba/fdcn/issues"
const _URL_TWITTER := "https://twitter.com/naparuba"

const _CHEMIN_VERSION := "VBox/Apropos/Colonne/Scroll/Marge/Infos/VersionTxt"

## Où poser les deux boutons de sauvegarde, construits au `_ready()`.
const _CHEMIN_ACTIONS := "VBox/Actions/Colonne"


func _ready() -> void:
	$VBox/Actions/Colonne/Marge/Boutons/NouveauBilly/Button.pressed.connect(_on_nouveau_billy)
	$VBox/Actions/Colonne/Marge/Boutons/NewBug/Button.pressed.connect(func(): OS.shell_open(_URL_BUG))
	$VBox/Apropos/Colonne/Header/HeaderRow/MarginContainer/twitter/Button.pressed.connect(func(): OS.shell_open(_URL_TWITTER))
	_afficher_version()
	_construire_boutons_sauvegarde()


## Le numéro de version vient de `Utils.get_app_version()`, donc de `project.godot`.
##
## Il était écrit **dans la scène** (`text = "0.22"`) : personne ne pensait à rouvrir
## `AboutMenu.tscn` en livrant, et rien ne reliait ce nombre aux `version/name` de
## `export_presets.cfg`. La scène ne garde plus qu'un tiret, remplacé au lancement.
func _afficher_version() -> void:
	var label = get_node_or_null(_CHEMIN_VERSION)
	if label == null:
		push_warning("AboutMenu: label de version introuvable (%s)" % _CHEMIN_VERSION)
		return
	label.text = Utils.get_app_version()


## Effacer une partie est la seule action destructrice de l'app : elle passe par la
## confirmation de `MenuPage`, qui vit dans le conteneur de popups et bloque donc la
## navigation le temps de la question. Sans conteneur trouvé, **on ne fait rien** plutôt
## que d'effacer en silence.
func _on_nouveau_billy() -> void:
	var menu_page = Utils.find_ancestor_with_method_or_warn(self, "confirm", "AboutMenu")
	if menu_page == null:
		return
	menu_page.confirm(_NOUVEAU_BILLY_TEXTE, _do_nouveau_billy, "Nouveau Billy")


func _do_nouveau_billy() -> void:
	Player.launch_new_billy()
	Player.go_to_node(1)
	# On ramène le joueur sur l'aventure : il vient de recommencer, rester sur « À
	# propos » ne lui montrerait rien de ce qui a changé.
	var menu_page = Utils.find_ancestor_with_method(self, "go_to_page")
	if menu_page != null:
		menu_page.go_to_page("aventure")


#
#    Sauvegarde : export et import
#
# Le moteur d'archive (`SaveArchive`) ne connaît que des chemins ; c'est ici, et seulement
# ici, que se décide **où** le fichier atterrit.
#
# ANDROID — la cible réelle de l'app. `user://` y est **privé** : depuis l'API 30, aucune
# application ne peut plus écrire dans le stockage partagé par un simple chemin. La seule
# porte de sortie est le **Storage Access Framework**, le sélecteur de documents du système,
# et c'est exactement ce que Godot expose sous `FEATURE_NATIVE_DIALOG_FILE` (vérifié dans
# le binaire 4.7.1, avec son pendant `_MIME`). Un `FileDialog` en mode natif s'y branche
# tout seul : le joueur choisit Téléchargements, Drive, une carte SD, ce qu'il veut, et
# **aucune permission n'est à demander** — c'est le système qui ouvre le fichier pour nous.
#
# ⚠️ Android filtre par **type MIME**, pas par extension : `*.zip` n'y sélectionne rien.
# D'où le filtre choisi selon ce que la plateforme annonce.
#
# Là où ce sélecteur n'existe pas, on ne laisse pas de bouton mort : l'export écrit dans le
# dossier de l'app et affiche le chemin, l'import propose la **dernière archive locale**,
# qui est au minimum la sauvegarde de secours du dernier import.
#
# Les deux boutons sont construits ici plutôt que posés dans la scène : les quatre
# « pastilles » d'À propos pèsent 35 lignes de `.tscn` chacune, et deux libellés longs ne
# tiennent pas sur la même ligne que « Nouveau Billy » à 540 px de large.


func _construire_boutons_sauvegarde() -> void:
	var colonne = get_node_or_null(_CHEMIN_ACTIONS)
	if colonne == null:
		push_warning("AboutMenu: colonne des actions introuvable (%s)" % _CHEMIN_ACTIONS)
		return

	var ligne := HBoxContainer.new()
	ligne.name = "Sauvegarde"
	ligne.add_theme_constant_override("separation", 12)
	ligne.add_child(_bouton("Exporter ma partie", _on_exporter))
	ligne.add_child(_bouton("Importer une partie", _on_importer))
	colonne.add_child(ligne)


func _bouton(texte: String, action: Callable) -> Button:
	var bouton := Button.new()
	bouton.text = texte
	bouton.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bouton.custom_minimum_size = Vector2(0, 44)
	bouton.pressed.connect(action)
	return bouton


## Nom proposé au joueur : le jour de l'export suffit à s'y retrouver entre deux archives.
func _nom_archive() -> String:
	return "fdcn-save-%s.zip" % Time.get_date_string_from_system()


func _on_exporter() -> void:
	if not _selecteur_disponible():
		_exporter_vers(SaveManager.base_dir + _nom_archive())
		return
	_ouvrir_dialogue(FileDialog.FILE_MODE_SAVE_FILE, _nom_archive(), _exporter_vers)


## On **vérifie que le fichier est là** au lieu de croire le rapport sur parole : sur
## Android le chemin passe par le système, et un export qui annoncerait « réussi » sans
## rien avoir écrit serait le pire des messages.
func _exporter_vers(chemin: String) -> void:
	var rapport = SaveArchive.export_to(chemin)
	if not rapport["ok"]:
		_dire("Export impossible :\n%s" % rapport["erreur"])
		return
	if not FileAccess.file_exists(chemin):
		_dire("L'archive n'a pas pu être écrite ici :\n%s" % chemin)
		return
	_dire("Partie exportée (%d fichiers) dans :\n%s" % [rapport["fichiers"], chemin])


## ⚠️ L'import ÉCRASE la partie en cours : on décrit d'abord ce que l'archive contient, et
## on ne touche à rien tant que le joueur n'a pas confirmé. La sauvegarde de secours part
## quand même juste avant la bascule, c'est `SaveArchive` qui s'en charge.
func _on_importer() -> void:
	if _selecteur_disponible():
		_ouvrir_dialogue(FileDialog.FILE_MODE_OPEN_FILE, "", _demander_confirmation_import)
		return
	var locales = SaveArchive.archives_locales()
	if locales.is_empty():
		_dire("Aucune archive trouvée dans le dossier de l'application.")
		return
	_demander_confirmation_import(locales[0])


func _demander_confirmation_import(chemin: String) -> void:
	var description = SaveArchive.describe(chemin)
	if not description["ok"]:
		_dire("Archive refusée :\n%s" % description["erreur"])
		return

	var menu_page = Utils.find_ancestor_with_method_or_warn(self, "confirm", "AboutMenu")
	if menu_page == null:
		return
	var texte = "Remplacer la partie en cours par celle du %s (%s) ?\n\nUne sauvegarde de secours sera écrite avant." % [
		description["date"], ", ".join(description["livres"])]
	menu_page.confirm(texte, func(): _importer_depuis(chemin), "Importer")


func _importer_depuis(chemin: String) -> void:
	var rapport = SaveArchive.import_from(chemin)
	if not rapport["ok"]:
		_dire("Import impossible :\n%s" % rapport["erreur"])
		return
	_dire("Partie importée.\nSecours : %s" % rapport["secours"])
	var menu_page = Utils.find_ancestor_with_method(self, "go_to_page")
	if menu_page != null:
		menu_page.go_to_page("aventure")


## Le `FileDialog` est créé à la demande et libéré à la fermeture : en garder un en
## permanence dans la scène ferait vivre une fenêtre invisible sur toutes les plateformes,
## y compris celles qui ne s'en servent jamais.
func _ouvrir_dialogue(mode: int, nom_propose: String, sur_choix: Callable) -> void:
	var dialogue := FileDialog.new()
	dialogue.file_mode = mode
	dialogue.access = FileDialog.ACCESS_FILESYSTEM
	dialogue.add_filter(_filtre(), "Archive de sauvegarde")
	dialogue.use_native_dialog = true
	if nom_propose != "":
		dialogue.current_file = nom_propose
	dialogue.file_selected.connect(sur_choix)
	dialogue.close_requested.connect(dialogue.queue_free)
	dialogue.file_selected.connect(func(_c): dialogue.queue_free())
	add_child(dialogue)
	dialogue.popup_centered_ratio(0.9)


## Le sélecteur du système : natif sur desktop, Storage Access Framework sur Android.
func _selecteur_disponible() -> bool:
	return DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE)


## Android ne connaît que les types MIME, les autres plateformes que les extensions.
func _filtre() -> String:
	if DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE_MIME):
		return "application/zip"
	return "*.zip"


## Un simple message : la popup de confirmation sait déjà afficher un texte, et n'avoir
## qu'un bouton en fait un accusé de réception.
func _dire(texte: String) -> void:
	var menu_page = Utils.find_ancestor_with_method(self, "confirm")
	if menu_page == null:
		print(texte)
		return
	menu_page.confirm(texte, func(): pass, "D'accord", "")
