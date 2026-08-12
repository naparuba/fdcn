@tool

extends Panel
## Bandeau latéral « retour ». `dest` vaut soit `BACK` (revenir au chapitre
## précédent), soit le nom d'une page (voir `MenuPage.page_names`).
##
## N'est plus utilisé que par l'archive ; conservé le temps que celle-ci vive.

@export var txt = 'unset'
@export var dest = 'UNSET'
@export var is_disabled = false


func _ready():
	$txt.text = txt

func set_enabled():
	$poly.color = Color('313b47')

func set_disabled():
	$poly.color = Color('9ea8b4')


func _on_button_pressed():
	if dest == 'BACK':
		_jump_to_previous_chapter()
		return
	# Comme le menu du haut : on retrouve le conteneur de pages en remontant.
	var menu_page = Utils.find_ancestor_with_method(self, "go_to_page")
	if menu_page == null:
		return
	menu_page.go_to_page(dest)


func _jump_to_previous_chapter() -> void:
	var previous_id = Player.jump_to_previous_chapter()
	if previous_id == -1:
		return
	Player.go_back_to(previous_id)
