extends Panel
## Une ligne d'objet de l'inventaire : icône, nom, stats, case à cocher.
##
## ⚠️ Le gabarit n'impose **que sa hauteur** (`custom_minimum_size = (0, 50)`).
## Il exigeait 450 px de large, soit plus que les ~444 px que la popup des
## options laisse à sa colonne de contenu : la liste affichait donc une barre de
## défilement horizontale. La largeur appartient au conteneur, ne remets pas de
## minimum en x.


## Icône des objets pas encore découverts. Préchargée une fois pour toutes : elle était
## rechargée par ligne, soit 56 à 82 fois à chaque ouverture de l'inventaire.
const _ICONE_INCONNUE := preload('res://images/items/question.svg')

var _is_enabled = null
var _item_name = ''
var _item_data = {}

var _item_icon = null

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.



func load_item_data(item_name, item_data):
	self._item_name = item_name
	self._item_data = item_data
	#print('Loading item data: %s' % self._item_name)
	$Row/Nom.text = self._item_name
	self._display_stats()
	var new_style = StyleBoxFlat.new()
	self.set('theme_override_styles/panel', new_style)
	var svg_path = 'res://images/items/%s.svg' % self._item_name
	var png_path = 'res://images/items/%s.png' % self._item_name
	if Utils.is_file_exists(svg_path):
		self._item_icon = Utils.load_external_texture(svg_path, null)
	elif Utils.is_file_exists(png_path):
		self._item_icon = Utils.load_external_texture(png_path, null)
	else:
		self._item_icon = null
	self.refresh()


func _display_stats():
	var s = ''
	for k in self._item_data['stats'].keys():
		var v = self._item_data['stats'][k]
		s += ('%s=' % k.to_upper()) + str(v) + '    '
	$Row/Stats.text = s

func get_item_name():
	return self._item_name

func is_enabled():
	return self._is_enabled


#func raw_disable():
#	$button.pressed = false
#	self._is_enabled = false


func get_category():
	return self._item_data['category']


# Depends on the item category, some won't be display: the BILLY one
func is_ok_to_be_shown():
	if self.get_category() == 'BILLY':
		return false
	return true
	

# Is an item name can be shown?
# * we have it, so of course we can
# * we are spoills ok, so we can too
# * we already did see it's chapter in the past plays
func _can_item_be_shown():
	if self._is_enabled:
		return true
	if AppParameters.are_spoils_ok():
		return true
	for chapter_id in self._item_data['in_chapters']:
		if Player.did_all_times_seen(chapter_id):
			return true
	return false


## ⚠️ Aucune trace ici : `refresh()` tourne pour CHAQUE ligne à chaque ouverture de
## l'inventaire et à chaque case cochée. Les 4 `print()` qui s'y trouvaient coûtaient 200
## à 350 écritures console par ouverture — c'était le vrai frein de la popup, pas le
## chargement des textures.
func refresh():
	# Une ligne pas encore alimentée (construction étalée sur plusieurs frames, voir
	# `popups/sub/inventory.gd`) n'a rien à rafraîchir.
	if self._item_name == '':
		return

	var do_have_item = Inventory.have_item(self._item_name)
	self._is_enabled = do_have_item

	var _style = self.get('theme_override_styles/panel')

	if self._can_item_be_shown():
		$Row/Nom.text = self._item_name
		$Row/sprite.texture = self._item_icon
	else:
		$Row/Nom.text = ''  # l'icône « ? » suffit à dire qu'on ne sait pas
		$Row/sprite.texture = _ICONE_INCONNUE

	if do_have_item:
		_style.set_bg_color(Color('c0ffed'))
	else:
		_style.set_bg_color(Color('ffffff'))
	$Row/button.button_pressed = do_have_item


func _on_button_toggled(button_pressed):
	print('ITEM: %s goes' % self._item_name, '%s' % button_pressed)
	if button_pressed:
		Inventory.add_item_from_options(self._item_name)
	else:  # remove it
		Inventory.remove_item_from_options(self._item_name)
	self.refresh()
