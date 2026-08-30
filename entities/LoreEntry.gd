@tool
extends Panel
## Une fiche du Lore : un portrait, un titre, un bouton qui joue la voix.
##
## `@tool` pour que le titre s'affiche **dans l'éditeur** : la page Lore aligne 16 instances
## qui ne diffèrent que par leurs trois propriétés exportées, et sans ça elles seraient
## impossibles à distinguer en la composant.
##
## MISE EN PAGE — reconstruite en conteneurs. Trois points valent d'être sus :
##
## 1. **Les trois `Sprite2D` sont devenus des `TextureRect`.** Un `Sprite2D` est un `Node2D` :
##    il n'a pas de `size`, donc aucun conteneur ne sait le placer. C'était le vrai blocage
##    de cette scène.
## 2. **L'image de 2,7 Mo embarquée dans le `.tscn` a disparu.** Le `Sprite2D` portait une
##    `ImageTexture` construite sur un `Image` de 320×435 sérialisé en base64 — soit une
##    copie exacte de `images/billys/guerrier.png`, que la scène référence maintenant. Elle
##    ne servait que d'aperçu d'éditeur : `_ready()` remplace la texture à l'exécution.
##    C'était **99 % du poids des scènes du dépôt**.
## 3. **Le titre et le portrait ne se chevauchent plus.** Le libellé occupait toute la
##    largeur en absolu, donc il passait par-dessus le haut du portrait. Il est maintenant
##    au-dessus, dans un `VBoxContainer` : le portrait prend la hauteur qui reste et se
##    redimensionne avec la carte, sans jamais se déformer (`stretch_mode` en aspect
##    conservé).

@export var type_entry = 'billys'
@export var entry_name = 'guerrier'
@export var titre = 'XXXX'

## Les images et sons des dieux sont rangés par nom de livre (`images/dieux/fdcn/atella.jpg`),
## comme le reste de l'app depuis le 2026-08-22 (todo 3.7) — plus d'identification par numéro.
@export var book_name = 'fdcn'


var is_playing = false

@onready var _titre: Label = $Marge/Contenu/Titre
@onready var _image: TextureRect = $Marge/Contenu/Corps/Image
@onready var _play: TextureRect = $Marge/Contenu/Corps/click/sprite_play
@onready var _stop: TextureRect = $Marge/Contenu/Corps/click/sprite_stop
@onready var _player: AudioStreamPlayer = $AudioStreamPlayer


func _ready():
	_titre.text = titre

	# Dans l'éditeur on s'arrête au titre : charger le portrait passerait par `Utils`, un
	# autoload dont le `_ready()` n'a pas tourné côté éditeur.
	if Engine.is_editor_hint():
		return

	_image.texture = Utils.load_external_texture(_chemin_image())


## `billys/<nom>.png` ou `dieux/<livre>/<nom>.jpg` — deux rangements, deux extensions.
func _chemin_image() -> String:
	if type_entry == 'dieux':
		return 'res://images/dieux/%s/%s.jpg' % [book_name, entry_name]
	return 'res://images/%s/%s.png' % [type_entry, entry_name]


## Même arborescence que les images, en mp3.
func _chemin_son() -> String:
	if type_entry == 'dieux':
		return 'res://sounds/dieux/%s/%s.mp3' % [book_name, entry_name]
	return 'res://sounds/%s/%s.mp3' % [type_entry, entry_name]


func _set_can_play():
	is_playing = false
	_play.visible = true
	_stop.visible = false


func _set_playing():
	is_playing = true
	_play.visible = false
	_stop.visible = true


func _on_play_pressed():
	if !Sounder.is_enabled():
		return

	if is_playing:
		_player.stop()
		_set_can_play()
		return

	# `load()` planterait sur un fichier absent, et il en manque (tous les dieux n'ont pas
	# leur voix) : on vérifie avant, et on ne bascule l'icône que si le son existe.
	var pth = _chemin_son()
	if not Utils.is_file_exists(pth):
		push_warning("LoreEntry: pas de son pour %s (%s)" % [entry_name, pth])
		return
	_player.stream = load(pth)
	_player.play()
	_set_playing()


func _on_AudioStreamPlayer_finished():
	_set_can_play()
