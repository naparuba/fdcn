extends Control
## Un chevron du fil d'Ariane : le numéro d'un chapitre visité, cliquable pour y revenir.
##
## **Atome de taille fixe** (review §1.2) : les deux `Polygon2D` gardent leurs points, le
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

func set_main(new_main):
	main_obj = new_main

func set_chap_number(nb):
	chap_number = nb
	

# The current label should be wihtout the _, so people don't want to click on it
func _update_label():
	if !is_current:
		$ElLabel.text = '[u]%d[/u]' % chap_number
	else:
		$ElLabel.text = '%d' % chap_number


func _set_color(color):
	$poly_for_first.color = color
	$Polygon2D.color = color


func set_first():
	$poly_for_first.visible = true
	

func set_current():
	_set_color(Color('00c2aa'))
	is_current = true  # means: don't jump here ^^
	_update_label()
	

func set_previous():
	_set_color(Color('01bcdb'))
	_update_label()


func set_normal_color():
	_set_color(Color('9ea8b4'))
	_update_label()


### NOTE: the button is invisible, normal ^^
func _on_button_pressed():
	if is_current:
		return
	main_obj.jump_back(chap_number)
