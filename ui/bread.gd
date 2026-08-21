extends Control
## Un chevron du fil d'Ariane : le numéro d'un chapitre visité, cliquable pour y revenir.
##
## **Atome de taille fixe** (review §6.3) : les deux `Polygon2D` gardent leurs points, le
## conteneur ne place que la boîte.
##
## ⚠️ La largeur minimale (70) est plus PETITE que le dessin (91) — et c'est voulu : c'est
## ce débordement qui fait **chevaucher** les chevrons, la queue de l'un passant sous la
## pointe du suivant. Ne pas « corriger » en la portant à 91, ça déplierait le fil.
## La hauteur, elle, était à 0 : un conteneur pouvait donc écraser la boîte sous le dessin.
##
## Deux `Label` masqués et jamais référencés par ce script traînaient dans la scène
## (`Label`, `Label2`) : supprimés.



var chap_number = 1
var main_obj = null
var is_current = false

func set_main(main_obj):
	self.main_obj = main_obj

func set_chap_number(nb):
	self.chap_number = nb
	

# The current label should be wihtout the _, so people don't want to click on it
func _update_label():
	if !self.is_current:
		$ElLabel.text = '[u]%d[/u]' % self.chap_number
	else:
		$ElLabel.text = '%d' % self.chap_number


func _set_color(color):
	$poly_for_first.color = color
	$Polygon2D.color = color

# Called when the node enters the scene tree for the first time.
func _ready():
	#self._set_color()
	pass


func set_first():
	$poly_for_first.visible = true
	

func set_current():
	self._set_color(Color('00c2aa'))
	self.is_current = true  # means: don't jump here ^^
	self._update_label()
	

func set_previous():
	self._set_color(Color('01bcdb'))
	self._update_label()


func set_normal_color():
	self._set_color(Color('9ea8b4'))
	self._update_label()


### NOTE: the button is invisible, normal ^^
func _on_button_pressed():
	if self.is_current:
		return
	self.main_obj.jump_back(self.chap_number)
