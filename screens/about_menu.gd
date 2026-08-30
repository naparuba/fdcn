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
##
## L'export/import de sauvegarde vit dans `screens/save_export_import.gd`, un sous-composant
## à part (review-code.md 4.2) : cette page n'a par ailleurs rien à voir avec la sauvegarde.

## Le texte de confirmation vient de `choice_next_chapiter`, qui offre le même bouton :
## une seule formulation pour une seule conséquence.
const _NOUVEAU_BILLY_TEXTE := preload(
	"res://screens/aventure_menu/choice_next_chapiter.gd").NOUVEAU_BILLY_TEXTE

const _URL_BUG := "https://github.com/naparuba/fdcn/issues"
const _URL_TWITTER := "https://twitter.com/naparuba"

const _CHEMIN_VERSION := "VBox/Apropos/Colonne/Scroll/Marge/Infos/VersionTxt"

## Où `save_export_import.gd` pose ses deux boutons.
const _CHEMIN_ACTIONS := "VBox/Actions/Colonne"


func _ready() -> void:
	$VBox/Actions/Colonne/Marge/Boutons/NouveauBilly/Button.pressed.connect(_on_nouveau_billy)
	$VBox/Actions/Colonne/Marge/Boutons/NewBug/Button.pressed.connect(func(): OS.shell_open(_URL_BUG))
	$VBox/Apropos/Colonne/Header/HeaderRow/MarginContainer/twitter/Button.pressed.connect(func(): OS.shell_open(_URL_TWITTER))
	_afficher_version()

	var sauvegarde = preload("res://screens/save_export_import.gd").new()
	add_child(sauvegarde)
	sauvegarde.setup(get_node_or_null(_CHEMIN_ACTIONS))


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
