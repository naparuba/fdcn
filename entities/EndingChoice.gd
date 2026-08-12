extends Panel
## La carte de fin d'aventure : le texte de la fin, son image, un ruban « Bonne / Mauvaise
## fin », et deux sorties — revenir au chapitre précédent (« Oups ») ou repartir à zéro.
##
## Converti en conteneurs. Trois pièges de la version Godot 3 corrigés au passage :
##
## 1. **`autowrap = true` ne voulait plus rien dire.** C'est le nom Godot 3 ; en Godot 4 la
##    propriété est `autowrap_mode`. Le texte des fins ne revenait donc **pas à la ligne** —
##    il débordait de sa boîte en silence. Même famille que le `align = 2` de `LoreEntry`.
## 2. **Deux `Sprite2D`** (l'image de la fin, le portrait du nouveau Billy) : des `Node2D`,
##    donc impossibles à placer dans un conteneur. Devenus des `TextureRect`. L'image de fin
##    garde `stretch_mode = 4` (centrée, sans mise à l'échelle) pour dessiner à sa taille
##    native comme le faisait le sprite — les fins font 128×128, sauf quelques-unes en 40×40.
## 3. **Deux polices mortes** (`FontFile` avec `size`/`font_data`, noms Godot 3). Le `40`
##    voulu pour « > » et « Oups » est redevenu réel via `theme_override_font_sizes`.
##
## Le ruban reste un **atome de taille fixe** (review §6.3) : ses points et la rotation de
## son libellé sont intacts, dans un `Control` de 75×260.


var ending_type = 0
var main

@onready var _icone: TextureRect = $Row/Contenu/Haut/Icone
@onready var _label: Label = $Row/Contenu/Haut/Label
@onready var _ruban: Polygon2D = $Row/Ruban/EndingType


func set_ending_id(ending_id):
	_icone.texture = Utils.load_external_texture("res://images/endings/%s.png" % ending_id)


func set_main(main):
	self.main = main


func set_label(label):
	_label.text = label


func set_ending_type(ending_type):
	self.ending_type = ending_type
	if self.ending_type == 1:  # GOOD
		_ruban.color = Color('00c2aa')
	else:  # bad one
		_ruban.color = Color('ff6f04')


func _on_bouton_billy_pressed():
	self.main.launch_new_billy()


func _on_oups_pressed():
	self.main.jump_to_previous_chapter()
