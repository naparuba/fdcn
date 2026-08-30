extends Panel
## Flèche de navigation latérale (barre verticale sur le bord de l'écran).
##
## La barre est un `Polygon2D` dont les coordonnées ont été dessinées à la main
## pour un écran de 960 px de haut. Depuis que l'app s'étire réellement
## (`stretch/mode = canvas_items`), la hauteur du viewport peut
## dépasser 960 sur les écrans allongés (un 20:9 donne 1200) : le polygone est
## donc **redimensionné à l'exécution** pour couvrir toute la hauteur, sinon il
## s'arrête en cours de route et laisse un trou en bas.
##
## On étire le dessin d'origine au lieu de le redessiner : la forme (barre
## légèrement biseautée), sa largeur et sa couleur sont conservées telles quelles.

## Libellé écrit verticalement le long de la barre : **le titre de la page où la flèche
## mène**. `MenuPage` le repose à chaque changement de page (`_refresh_nav_labels`).
##
## Vide par défaut, et non `'unset'` comme avant : cette valeur de remplissage s'affichait
## telle quelle, personne ne branchant le libellé. Vide, une flèche non branchée ne montre
## que son chevron au lieu d'un mot faux.
@export var txt: String = ''
@export var is_disabled: bool = false
@export var is_mirror: bool = false

signal pressed_for_navigation()

## Demi-longueur du polygone dans son repère local, mesurée une fois au départ.
## Le polygone est tourné de 90°, donc son axe X local devient la verticale.
var _poly_half_length := 0.0


func _ready():
	$txt.text = txt
	_measure_poly()
	if is_mirror:
		set_mirror(true)
	if is_disabled:
		set_disabled(true)
	resized.connect(_on_resized)
	_on_resized()


## Mesure l'étendue du polygone (offset compris) sur son axe long.
func _measure_poly() -> void:
	var points = $poly.polygon
	if points.is_empty():
		return
	var offset = $poly.offset
	var x_min = points[0].x + offset.x
	var x_max = x_min
	for p in points:
		var x = p.x + offset.x
		x_min = minf(x_min, x)
		x_max = maxf(x_max, x)
	_poly_half_length = (x_max - x_min) / 2.0


func _on_resized() -> void:
	# Le pivot doit rester au centre, sinon le miroir (rotation de PI) décale la
	# flèche droite hors de l'écran dès que la hauteur change.
	pivot_offset = size / 2.0
	_fit_poly_to_height()
	_fit_label_to_bar()


## Écrit le libellé **le long** de la barre : une boîte aux dimensions du bouton avec largeur
## et hauteur **échangées** (960 × 50 au lieu de 50 × 960), centrée sur lui, puis tournée d'un
## quart de tour autour de son propre centre. Le rectangle tourné retombe alors exactement sur
## la barre, à toute hauteur d'écran.
##
## ⚠️ C'est un correctif, pas une préférence de style. La géométrie d'origine venait de
## l'éditeur Godot 3 : une boîte de 880 × 40 tournant autour d'un pivot décalé, si bien que le
## texte atterrissait centré à **x ≈ 54,7** pour une barre large de **50** — 4,7 px À CÔTÉ,
## donc en blanc sur le fond clair de la page. Le libellé était bien dessiné mais
## **invisible**, ce qui explique que le texte de remplissage « unset » n'ait jamais été
## remarqué par personne.
func _fit_label_to_bar() -> void:
	var l: Label = $txt
	l.size = Vector2(size.y, size.x)
	l.position = (size - l.size) / 2.0
	l.pivot_offset = l.size / 2.0
	l.rotation = PI / 2.0


## Étire la barre pour qu'elle couvre exactement la hauteur du bouton.
func _fit_poly_to_height() -> void:
	if _poly_half_length <= 0.0:
		return
	$poly.scale.x = (size.y / 2.0) / _poly_half_length
	$poly.position.y = size.y / 2.0


## Met à jour l'ÉTAT autant que la couleur. `is_disabled` était un `@export` lu une seule
## fois au `_ready()` : appeler `set_disabled()` repeignait le chevron sans jamais le tenir à
## jour, donc rien — pas même un test — ne pouvait demander si la flèche était active.
func set_disabled(newValue: bool):
	is_disabled = newValue
	$poly.color = Color('9ea8b4') if newValue else Color('313b47')


## Change le libellé après coup. `$txt` est résolu dès l'instanciation, donc l'appel est sûr
## même avant `_ready()` — qui repose `txt` de toute façon, la valeur restant cohérente.
func set_txt(value: String) -> void:
	txt = value
	$txt.text = value


func set_mirror(newValue: bool):
	if (newValue == true):
		set_rotation(PI)
	else:
		set_rotation(0)


func _on_button_button_down() -> void:
	pressed_for_navigation.emit()
