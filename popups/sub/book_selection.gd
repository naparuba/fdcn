extends Panel
## Choix du livre.
##
## On passe par AppParameters et non par BookData directement : c'est lui qui
## persiste le choix dans parameters.json, recharge le livre, puis émet
## `book_changed` pour que Player recharge la sauvegarde de ce livre.
##
## La couverture du livre **non chargé** est grisée, avec le même shader que les
## portraits de Billy de l'inventaire (`shaders/gray.gdshader`). C'est le seul retour
## visuel qui dit lequel des deux est en cours : sans lui, les deux couvertures sont
## identiquement colorées et rien ne distingue le livre actif.

var _gray_shader: Shader = preload('res://shaders/gray.gdshader')

## Nom du livre -> son bouton de couverture.
var _covers := {}


func _ready() -> void:
	_covers = {
		"fdcn": $VBoxContainer/CenterContainer/BoolSelectFcdn,
		"cdsi": $VBoxContainer/CenterContainer2/BoolSelectCdsi,
	}
	# Un matériau par couverture : `grayscale` est un paramètre du matériau, un seul
	# partagé griserait les deux d'un coup.
	for cover in _covers.values():
		var gray_material := ShaderMaterial.new()
		gray_material.shader = _gray_shader
		cover.material = gray_material

	AppParameters.book_changed.connect(_on_book_changed)
	_refresh()


func _on_book_changed(_book_name) -> void:
	_refresh()


func _refresh() -> void:
	var courant = AppParameters.get_book_name()
	for nom in _covers:
		_covers[nom].material.set_shader_parameter('grayscale', nom != courant)


func _on_bool_select_fcdn_pressed() -> void:
	AppParameters.set_book_name("fdcn")


func _on_bool_select_cdsi_pressed() -> void:
	AppParameters.set_book_name("cdsi")
