extends PanelContainer
## Une ligne de succès : ruban « Obtenu », icône, libellé + description,
## numéro de chapitre et bouton d'accès.
##
## Utilisée à deux endroits : la liste de `screens/SuccesMenu.tscn` et la popup
## `popups/SuccessPopup.tscn` (qui masque le chapitre via `hide_chapter()`).

@onready var _get_polygon: Polygon2D = $Row/Marker/GetPolygon
@onready var _ribbon_label: Label = $Row/Marker/GetPolygon/Label
@onready var _sprite: TextureRect = $Row/Marker/sprite
@onready var _label: Label = $Row/Texts/Label
@onready var _txt: Label = $Row/Texts/Txt
@onready var _nb_chapitre: Label = $Row/NBChapitre
@onready var _click: Control = $Row/click

var chap_number
## L'identifiant du succès, gardé : le ruban « Obtenu » en a besoin, un succès pouvant se
## gagner dans plusieurs chapitres alors que la ligne n'en affiche qu'un.
var success_id = ''
var spoil_enabled = false
var main

## Géométrie du ruban « Obtenu » : une bande inclinée de largeur constante,
## relevée sur le dessin d'origine (fait pour une ligne de 48 px).
##
## On **recalcule** ses points à la hauteur voulue au lieu de mettre le
## `Polygon2D` à l'échelle. Une mise à l'échelle verticale aurait deux défauts :
## elle fausserait l'angle de la bande (qui s'écraserait), et surtout elle
## étirerait le texte « Obtenu » — celui-ci est un *enfant* du polygone, il hérite
## donc de son échelle.
## Le décalage est une **valeur fixe en pixels**, pas un ratio : avec un ratio,
## une ligne plus haute penche proportionnellement plus, la bande déborde
## latéralement et vient écrire par-dessus le libellé du succès. À décalage fixe,
## la bande occupe toujours la même bande horizontale, elle se redresse
## simplement quand la ligne grandit.
const _BAND_BOTTOM_X := 28.1169   # abscisse du bord gauche, en bas
const _BAND_WIDTH := 16.1         # largeur de la bande, constante
const _BAND_SLANT := 13.5         # décalage horizontal total, en pixels

## NOTE: la rotation du texte n'est pas figée dans la scène, elle est recalculée
## à chaque changement de hauteur (voir `_place_ribbon_label`).


func _ready():
	resized.connect(_fit_ribbon_to_height)
	_fit_ribbon_to_height()


## Redessine la bande sur toute la hauteur de la ligne, à angle et largeur
## constants, puis recentre le texte le long de la bande.
func _fit_ribbon_to_height() -> void:
	var h = size.y
	if h <= 0.0:
		return

	_get_polygon.polygon = PackedVector2Array([
		Vector2(_BAND_BOTTOM_X, h),                                  # bas gauche
		Vector2(_BAND_BOTTOM_X + _BAND_SLANT, 0.0),                  # haut gauche
		Vector2(_BAND_BOTTOM_X + _BAND_SLANT + _BAND_WIDTH, 0.0),    # haut droit
		Vector2(_BAND_BOTTOM_X + _BAND_WIDTH, h),                    # bas droit
	])

	_place_ribbon_label(h)


## Fait suivre le texte à la bande : même inclinaison, et centré dessus.
##
## L'angle **dépend de la hauteur**. La pente étant un décalage fixe, une ligne
## plus haute donne une bande plus redressée : garder la rotation d'origine
## (calée sur une ligne de 48 px) ferait diverger le texte de la bande.
func _place_ribbon_label(h: float) -> void:
	# Direction de la bande, du bas vers le haut : (pente, -h).
	var angle = atan2(-h, _BAND_SLANT)
	_ribbon_label.rotation = angle

	# `position` est le coin haut-gauche *avant* rotation, et la rotation se fait
	# autour de ce coin. Pour centrer le texte sur la bande, on part du centre de
	# la bande et on retranche le vecteur coin->centre, lui aussi pivoté.
	var half = _ribbon_label.size / 2.0
	var corner_to_center = Vector2(
		half.x * cos(angle) - half.y * sin(angle),
		half.x * sin(angle) + half.y * cos(angle))
	var band_center = Vector2(
		_BAND_BOTTOM_X + (_BAND_SLANT + _BAND_WIDTH) / 2.0,
		h / 2.0)
	_ribbon_label.position = band_center - corner_to_center


func set_main(main_obj):
	self.main = main_obj


func set_spoil_enabled(b):
	self.spoil_enabled = b
	_click.visible = self.spoil_enabled
	_nb_chapitre.visible = self.spoil_enabled


## Remet la ligne à jour d'après l'état du joueur (spoils, chapitre déjà vu).
func update():
	var chapter_id = self.get_chapter_id()

	# Les spoils peuvent être autorisés au cas par cas si on a déjà vu le chapitre.
	if BookData.is_node_id_freely_full_on_all_chapters(chapter_id):
		self.set_spoil_enabled(true)
	else:
		self.set_spoil_enabled(false)

	# ⚠️ Le ruban « Obtenu » regarde **tous** les chapitres qui donnent ce succès, pas
	# seulement celui affiché : `PHOBIE-ADMINISTRATIVE` de cdsi se gagne aux chapitres 98 et
	# 498, et la ligne n'en montre qu'un.
	if BookData.is_success_obtenu(self.success_id):
		self.set_already_seen()
	else:
		self.set_not_already_seen()


func get_chapter_id():
	return self.chap_number


func set_from_success_object(success_object):
	# `set_success_id()` d'abord : `update()`, appelé ensuite, s'en sert pour savoir si le
	# succès est obtenu.
	self.set_success_id(success_object['id'])
	self.set_chapitre(success_object['chapter'])
	self.set_label(success_object['label'])
	self.set_txt(success_object['txt'])


func set_success_id(new_success_id):
	self.success_id = new_success_id
	var png_path = "res://images/success/%s.png" % new_success_id
	var svg_path = "res://images/success/%s.svg" % new_success_id
	var texture = null
	if Utils.is_file_exists(svg_path):
		texture = Utils.load_external_texture(svg_path)
	elif Utils.is_file_exists(png_path):
		texture = Utils.load_external_texture(png_path)
	_sprite.texture = texture


func set_chapitre(chapitre):
	# On force l'entier : le JSON rend les nombres en float, et un 26.0 ne
	# correspond à aucun 26 dans les listes de chapitres visités — le ruban
	# « Obtenu » restait donc gris même pour un succès acquis.
	self.chap_number = int(chapitre)
	_nb_chapitre.text = '%3d' % self.chap_number


func set_label(label):
	_label.text = label


func set_txt(txt):
	_txt.text = txt


func set_already_seen():
	_get_polygon.color = Color('00c2aa')


func set_not_already_seen():
	_get_polygon.color = Color('9ea8b4')


func hide_chapter():
	_nb_chapitre.visible = false
	_click.visible = false


func _on_Button_pressed():
	if self.main != null:
		self.main.go_to_node(self.chap_number)
