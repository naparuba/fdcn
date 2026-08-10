extends Panel
## Flèche de navigation latérale (barre verticale sur le bord de l'écran).
##
## La barre est un `Polygon2D` dont les coordonnées ont été dessinées à la main
## pour un écran de 960 px de haut. Depuis que l'app s'étire réellement
## (`stretch/mode = canvas_items`, voir review §2.6), la hauteur du viewport peut
## dépasser 960 sur les écrans allongés (un 20:9 donne 1200) : le polygone est
## donc **redimensionné à l'exécution** pour couvrir toute la hauteur, sinon il
## s'arrête en cours de route et laisse un trou en bas.
##
## On étire le dessin d'origine au lieu de le redessiner : la forme (barre
## légèrement biseautée), sa largeur et sa couleur sont conservées telles quelles.

@export var txt: String = 'unset'
@export var is_disabled: bool = false
@export var is_mirror: bool = false

signal _on_nav_pressed()

## Demi-longueur du polygone dans son repère local, mesurée une fois au départ.
## Le polygone est tourné de 90°, donc son axe X local devient la verticale.
var _poly_half_length := 0.0


func _ready():
	$txt.text = txt
	_measure_poly()
	if is_mirror:
		setMirror(true)
	if is_disabled:
		setDisabled(true)
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
		x_min = min(x_min, x)
		x_max = max(x_max, x)
	_poly_half_length = (x_max - x_min) / 2.0


func _on_resized() -> void:
	# Le pivot doit rester au centre, sinon le miroir (rotation de PI) décale la
	# flèche droite hors de l'écran dès que la hauteur change.
	pivot_offset = size / 2.0
	_fit_poly_to_height()


## Étire la barre pour qu'elle couvre exactement la hauteur du bouton.
func _fit_poly_to_height() -> void:
	if _poly_half_length <= 0.0:
		return
	$poly.scale.x = (size.y / 2.0) / _poly_half_length
	$poly.position.y = size.y / 2.0


func setDisabled(newValue: bool):
	if (newValue == true):
		$poly.color = Color('9ea8b4')
	else:
		$poly.color = Color('313b47')


func setMirror(newValue: bool):
	if (newValue == true):
		set_rotation(PI)
	else:
		set_rotation(0)


func _on_button_button_down() -> void:
	emit_signal("_on_nav_pressed")
