extends Panel
## Bandeau « objet gagné / perdu », affiché 3 s dans le `ToastLayer` de `MenuPage`.
##
## Converti en conteneurs : l'icône était un `Sprite2D`, donc un `Node2D` — **aucun
## conteneur ne sait placer ça**, faute de `size`. Elle est devenue un `TextureRect`, comme
## dans `entities/Item.tscn`.
##
## La racine reste un `Panel` : son stylebox est **remplacé à l'exécution**, une instance
## par toast (voir `load_item_data`). Un stylebox partagé venu de la scène repeindrait tous
## les toasts affichés d'un coup.

var is_new = false
var _item_name = ''
var _item_data = {}


var _item_icon = null

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.



func load_item_data(item_name, item_data):
	self._item_name = item_name
	self._item_data = item_data
	$Row/Nom.text = self._item_name
	# Un stylebox par instance, avec le rayon 2 des cartes de l'app : la scène ne sert que
	# d'aperçu d'éditeur puisque celui-ci l'écrase.
	var new_style = StyleBoxFlat.new()
	new_style.set_corner_radius_all(2)
	self.set('theme_override_styles/panel', new_style)
	# Repli svg -> png, comme `entities/Item.gd` : sans lui, tout objet dont l'icône est un
	# PNG s'affichait sans image dans cette popup alors qu'il en a une dans l'inventaire.
	var svg_path = 'res://images/items/%s.svg' % self._item_name
	var png_path = 'res://images/items/%s.png' % self._item_name
	if Utils.is_file_exists(svg_path):
		self._item_icon = Utils.load_external_texture(svg_path)
	elif Utils.is_file_exists(png_path):
		self._item_icon = Utils.load_external_texture(png_path)
	else:
		self._item_icon = null


	
func set_is_new(b):
	self.is_new = b
	self.refresh()
	

func refresh():
	var _style = self.get('theme_override_styles/panel')
	
	$Row/Nom.text = self._item_name
	$Row/sprite.texture = self._item_icon

	if self.is_new:
		_style.set_bg_color(Color('c0ffed'))  # set to light grey
	else:
		_style.set_bg_color(Color('f45858'))  # set to light grey





func _on_Timer_timeout():
	self.queue_free()
