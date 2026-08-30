extends Control
## Jauge circulaire : un disque dont une couronne montre la progression, avec le
## pourcentage écrit au centre.
##
## **`Control` et non `Node2D`** — un conteneur ne sait pas placer un `Node2D`, qui n'a
## pas de `size`. `GlobalCompletion.tscn` contournait avec un `GaugeSizer` : un `Control`
## de 100×100 dans lequel la jauge était posée à `position = (50, 50)`, soit son centre
## calculé à la main. Le rayon se déduit maintenant de la boîte, et le contournement a
## disparu.
##
## Politique des widgets à polygones (review §1.2, tranchée le 2026-08-12) : **atome de
## taille fixe**. Ici le dessin est déjà paramétrique, donc la jauge fait mieux que le
## contrat — elle suit sa boîte — mais elle garde une taille minimale pour ne jamais être
## écrasée par un conteneur trop serré.

const _NB_POINTS := 64

## Épaisseur de la couronne, en pixels. Un ratio ferait maigrir la couronne sur une petite
## jauge et l'épaissirait sur une grande : ce sont des pixels, comme les pentes des rubans.
const _EPAISSEUR := 10.0

var inside_color := Color('313b47')
var outside_color := Color('01bcdb')

var _value_pct := 0.25

@onready var _label: Label = $label


func _ready() -> void:
	# Le rayon dépend de `size` : sans ce redessin, la jauge garderait celui qu'elle avait
	# au premier affichage, avant que le conteneur ne l'ait dimensionnée.
	resized.connect(queue_redraw)


func set_value(value_pct: float) -> void:
	_value_pct = clampf(value_pct, 0.0, 1.0)
	_label.text = '%d%%' % int(100.0 * _value_pct)
	queue_redraw()


func _draw() -> void:
	var centre := size / 2.0
	var rayon := minf(size.x, size.y) / 2.0
	_secteur(centre, rayon, 360.0 * _value_pct, outside_color)
	_secteur(centre, rayon - _EPAISSEUR, 360.0, inside_color)


## Un secteur circulaire partant du haut (−90°), dessiné en éventail de triangles.
## Rayon négatif ou nul : on ne dessine rien plutôt que de produire un polygone retourné.
func _secteur(centre: Vector2, rayon: float, angle: float, couleur: Color) -> void:
	if rayon <= 0.0:
		return
	var points := PackedVector2Array()
	points.push_back(centre)
	for i in _NB_POINTS + 1:
		var a := deg_to_rad(i * angle / _NB_POINTS - 90.0)
		points.push_back(centre + Vector2(cos(a), sin(a)) * rayon)
	draw_polygon(points, PackedColorArray([couleur]))
