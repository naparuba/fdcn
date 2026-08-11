extends Panel
## Page « À propos » : branchement de ses boutons, qui n'étaient reliés à rien.
##
## La scène est encore celle de l'archive — 14 nœuds à position fixe, zéro conteneur
## (voir `review.md` §3). Ce script se contente de rendre les boutons vivants ; la
## reconstruction en conteneurs reste à faire (action P3).

## Le texte de confirmation vient de `choice_next_chapiter`, qui offre le même bouton :
## une seule formulation pour une seule conséquence.
const _NOUVEAU_BILLY_TEXTE := preload(
	"res://screens/aventure_menu/choice_next_chapiter.gd").NOUVEAU_BILLY_TEXTE

const _URL_BUG := "https://github.com/naparuba/fdcn/issues"
const _URL_TWITTER := "https://twitter.com/naparuba"


func _ready() -> void:
	$Actions/Content/NouveauBilly/Button.pressed.connect(_on_nouveau_billy)
	$Actions/Content/NewBug/Button.pressed.connect(func(): OS.shell_open(_URL_BUG))
	$About/twitter/Button.pressed.connect(func(): OS.shell_open(_URL_TWITTER))


## Effacer une partie est la seule action destructrice de l'app : elle passe par la
## confirmation de `MenuPage`, qui vit dans le conteneur de popups et bloque donc la
## navigation le temps de la question. Sans conteneur trouvé, **on ne fait rien** plutôt
## que d'effacer en silence.
func _on_nouveau_billy() -> void:
	var menu_page = Utils.find_ancestor_with_method(self, "confirm")
	if menu_page == null:
		push_warning("AboutMenu: pas de conteneur de popup, nouveau Billy annulé")
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
