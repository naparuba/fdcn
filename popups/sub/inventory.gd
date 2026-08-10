extends Panel
## Inventory view — one Item row per object in the book.
##
## This builds and owns the rows. `Inventory` holds the data only, so opening
## this popup several times can no longer duplicate anything.
##
## En haut, les quatre portraits de Billy : seul celui du type courant reste en
## couleur, les trois autres passent en niveaux de gris. Le type étant *déduit*
## des objets portés, cocher un objet peut déplacer la mise en évidence — d'où
## l'abonnement à `Inventory.billy_changed`.

@onready var items_panel = $ItemsCont/Items

var _item_scene: PackedScene = preload('res://entities/Item.tscn')
var _gray_shader: Shader = preload('res://shaders/gray.gdshader')

## Type de Billy -> son portrait dans le HBoxContainer.
var _billy_blocks := {}


func _ready() -> void:
	_billy_blocks = {
		'guerrier': $HBoxContainer/BlockGuerrier,
		'paysan': $HBoxContainer/BlockPaysan,
		'prudent': $HBoxContainer/BlockPrudent,
		'debrouillard': $HBoxContainer/BlockDebrouillard,
	}
	# Un matériau par portrait : un seul partagé griserait les quatre d'un coup,
	# `grayscale` étant un paramètre du matériau et non du nœud.
	for block in _billy_blocks.values():
		var gray_material := ShaderMaterial.new()
		gray_material.shader = _gray_shader
		block.material = gray_material

	Inventory.items_changed.connect(_on_items_changed)
	Inventory.billy_changed.connect(_on_billy_changed)

	_build_rows()
	_refresh_billy_blocks()


func _build_rows() -> void:
	Utils.delete_children(items_panel)
	var all_objects = BookData.get_all_objects()
	for item_name in Inventory.get_visible_item_names():
		var item = _item_scene.instantiate()
		items_panel.add_child(item)
		item.load_item_data(item_name, all_objects[item_name])


func _on_items_changed() -> void:
	for item in items_panel.get_children():
		item.refresh()


func _on_billy_changed(_billy_type) -> void:
	_refresh_billy_blocks()


## Le type courant en couleur, les autres en gris. En « pégu » aucun portrait ne
## correspond : les quatre restent donc gris, ce qui est bien l'état voulu.
func _refresh_billy_blocks() -> void:
	var current_billy = AppParameters.get_billy_type()
	for billy in _billy_blocks:
		_billy_blocks[billy].material.set_shader_parameter('grayscale', billy != current_billy)
