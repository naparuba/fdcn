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
##
## PERFORMANCE — pourquoi la construction est étalée sur plusieurs frames.
## Un livre compte 56 (fdcn) à 82 (cdsi) objets visibles, et chaque ligne est une scène
## de 6 nœuds. Tout construire dans `_ready()` retardait l'apparition de la popup.
## Les lignes se fabriquent donc par lots de `_LOT_PAR_FRAME`, ce qui rend la popup
## visible immédiatement et la remplit sous les yeux du joueur.
##
## ⚠️ Ce n'était PAS le coût principal : `entities/Item.gd` imprimait 2 à 4 lignes de
## debug par objet, soit 200 à 350 écritures console à chaque ouverture *et* à chaque
## case cochée. Ces traces sont supprimées. L'étalement traite ce qui reste.
##
## Si ça ne suffit pas un jour, la vraie réponse est la **virtualisation** (un pool de
## ~15 lignes recyclées), déjà écrite deux fois dans ce dépôt :
## `screens/chapitres_menu.gd` en est l'implémentation de référence.

## Nombre de lignes fabriquées avant de rendre la main d'une frame.
const _LOT_PAR_FRAME := 10

@onready var items_panel = $ItemsCont/Items

var _item_scene: PackedScene = preload('res://entities/Item.tscn')
var _gray_shader: Shader = preload('res://shaders/gray.gdshader')

## Type de Billy -> son portrait dans le HBoxContainer.
var _billy_blocks := {}

## Incrémenté à chaque reconstruction : une construction en cours qui voit ce numéro
## changer s'arrête, plutôt que de continuer à empiler des lignes périmées.
var _generation := 0


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

	_refresh_billy_blocks()
	_build_rows()


## Coroutine : elle rend la main toutes les `_LOT_PAR_FRAME` lignes.
func _build_rows() -> void:
	_generation += 1
	var ma_generation = _generation
	Utils.delete_children(items_panel)

	var all_objects = BookData.get_all_objects()
	var noms = Inventory.get_visible_item_names()
	for i in noms.size():
		var item = _item_scene.instantiate()
		items_panel.add_child(item)
		item.load_item_data(noms[i], all_objects[noms[i]])

		if i % _LOT_PAR_FRAME == _LOT_PAR_FRAME - 1:
			await get_tree().process_frame
			# La popup a pu être fermée, ou une reconstruction avoir démarré, pendant
			# qu'on attendait : sans ces deux gardes on écrirait dans un nœud libéré.
			if not is_inside_tree() or _generation != ma_generation:
				return


func _on_items_changed() -> void:
	for item in items_panel.get_children():
		item.refresh()


func _on_billy_changed(_billy_type) -> void:
	_refresh_billy_blocks()


## Le type courant en couleur, les autres en gris. En « pégu » aucun portrait ne
## correspond : les quatre restent gris, ce qui est bien l'état voulu.
func _refresh_billy_blocks() -> void:
	var current_billy = AppParameters.get_billy_type()
	for billy in _billy_blocks:
		_billy_blocks[billy].material.set_shader_parameter('grayscale', billy != current_billy)
