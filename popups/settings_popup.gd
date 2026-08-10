extends Panel

@onready var content_container = $ContentContainer

var scene_inventory: PackedScene = preload("res://popups/sub/Inventory.tscn")
var scene_stats: PackedScene = preload("res://popups/sub/Stats.tscn")
var scene_books: PackedScene = preload("res://popups/sub/BookSelection.tscn")

## L'onglet affiché passe en blanc, comme le fond du contenu à sa droite : les
## deux ne forment plus qu'une seule surface. Les autres restent gris sur
## l'en-tête sombre.
const TAB_SELECTED := Color('ffffff')
const TAB_UNSELECTED := Color('9ea8b4')

var current_instance: Node = null

## Panneau d'onglet -> scène qu'il affiche. Une seule table pour brancher les
## clics ET pour la coloration, sinon on finit par oublier un onglet d'un côté.
var _tabs := {}


func _ready():
	_tabs = {
		$Header/VBoxContainer/TabInventory: scene_inventory,
		$Header/VBoxContainer/TabStats: scene_stats,
		$Header/VBoxContainer/TabSelectBook: scene_books,
	}
	for tab in _tabs:
		_tab_button(tab).pressed.connect(_show_scene.bind(_tabs[tab]))

	# Load default tab on open
	_show_scene(scene_inventory)


func _show_scene(scene: PackedScene):
	if current_instance:
		current_instance.queue_free()

	current_instance = scene.instantiate()
	content_container.add_child(current_instance)
	_highlight_tab(scene)


## Repeint tous les onglets d'un coup. Comme ils sont tous réécrits à chaque
## changement, peu importe que Godot partage ou non les StyleBox entre deux
## ouvertures de la popup : aucun état résiduel ne peut survivre.
func _highlight_tab(scene: PackedScene) -> void:
	for tab in _tabs:
		var style: StyleBoxFlat = tab.get('theme_override_styles/panel')
		style.set_bg_color(TAB_SELECTED if _tabs[tab] == scene else TAB_UNSELECTED)


## Les deux orthographes cohabitent dans la scène (`TabInventory/Button` mais
## `TabStats/button`) : on prend donc le bouton par son type, pas par son nom.
func _tab_button(tab: Panel) -> BaseButton:
	for child in tab.get_children():
		if child is BaseButton:
			return child
	return null
