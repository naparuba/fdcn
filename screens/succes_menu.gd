extends Panel
## Écran « Tous les succès » — liste virtualisée.
##
## Même motif que `screens/chapitres_menu.gd` (voir review §5bis) : le `Content`
## du ScrollContainer porte la hauteur totale de la liste, et seule une poignée
## de lignes existe, recyclée au défilement.
##
## Ici la virtualisation n'est pas un enjeu de performance — il n'y a que ~51
## succès, contre 606 chapitres — mais elle garde **un seul motif** pour tous les
## écrans-listes, et ne coûte rien.
##
## ROW_HEIGHT doit être **supérieure ou égale à la plus grande hauteur qu'une
## ligne puisse réclamer**, sinon les lignes se recouvrent : leur `size.y` ne
## peut pas descendre sous leur taille minimale, alors qu'on les positionne, elle,
## tous les ROW_HEIGHT pixels.
##
## Mesuré à la largeur d'écran la plus étroite possible (416 px, cf. §5ter — la
## largeur logique ne descend jamais sous 540) : 45 succès tiennent en 80 px, les
## 6 plus bavards réclament 86 px. D'où 88, qui couvre tout avec un peu de marge.
## À revérifier si on change la police ou le gabarit de `SuccessItem.tscn`.
const ROW_HEIGHT := 88.0
const BUFFER_ROWS := 3

@onready var _scroll: ScrollContainer = $VBox/Scroll
@onready var _content: Control = $VBox/Scroll/Content
@onready var _counter: Label = $VBox/Counter

var _row_scene: PackedScene = preload("res://entities/SuccessItem.tscn")

## Les succès du livre, dans l'ordre de la donnée compilée.
var _successes: Array = []

var _pool: Array = []
var _first_index := -1


func _ready() -> void:
	_scroll.get_v_scroll_bar().value_changed.connect(func(_v): _refresh_rows())
	_scroll.resized.connect(_on_scroll_resized)

	Player.chapter_changed.connect(func(_id): _on_state_changed())
	AppParameters.book_changed.connect(func(_name): _load_successes())
	# Les spoils changent ce qu'une ligne a le droit d'afficher.
	AppParameters.settings_changed.connect(_on_state_changed)

	_load_successes()


#
#    Données
#

func _load_successes() -> void:
	_successes = BookData.get_all_success()
	if _successes == null:
		_successes = []
	_content.custom_minimum_size.y = _successes.size() * ROW_HEIGHT
	_scroll.scroll_vertical = 0
	_first_index = -1
	_refresh_rows(true)
	_update_counter()


func _on_state_changed() -> void:
	_refresh_rows(true)
	_update_counter()


## « obtenus / total » : un succès compte comme obtenu si **l'un** des chapitres qui le
## donnent a déjà été visité, toutes parties confondues.
##
## ⚠️ « l'un » et pas « le sien » : `PHOBIE-ADMINISTRATIVE` de cdsi se gagne aux chapitres
## 98 **et** 498. Ne regarder que le premier le déclarait manquant à qui l'avait obtenu par
## l'autre.
func _update_counter() -> void:
	var obtained := 0
	for success in _successes:
		if BookData.is_success_obtenu(success['id']):
			obtained += 1
	_counter.text = "%d / %d" % [obtained, _successes.size()]


#
#    Virtualisation
#

func _on_scroll_resized() -> void:
	_ensure_pool()
	_refresh_rows(true)


func _ensure_pool() -> void:
	var visible_height = _scroll.size.y
	if visible_height <= 0.0:
		return
	var needed = int(ceil(visible_height / ROW_HEIGHT)) + BUFFER_ROWS * 2
	needed = min(needed, _successes.size())

	while _pool.size() < needed:
		var row = _row_scene.instantiate()
		row.set_main(self)
		# Ancrages gauche/droite conservés : la largeur suit le conteneur.
		row.offset_left = 0
		row.offset_right = 0
		_content.add_child(row)
		_pool.append(row)

	while _pool.size() > needed:
		var row = _pool.pop_back()
		row.queue_free()


func _refresh_rows(force := false) -> void:
	if _pool.is_empty():
		_ensure_pool()
		if _pool.is_empty():
			return

	var first = int(_scroll.scroll_vertical / ROW_HEIGHT) - BUFFER_ROWS
	first = clampi(first, 0, max(0, _successes.size() - _pool.size()))

	var moved = first != _first_index
	_first_index = first

	for i in _pool.size():
		var row = _pool[i]
		var index = first + i
		if index >= _successes.size():
			row.visible = false
			continue

		row.visible = true
		var y = index * ROW_HEIGHT
		row.offset_top = y
		row.offset_bottom = y + ROW_HEIGHT

		if force or moved:
			row.set_from_success_object(_successes[index])
			row.update()


#
#    Appelé par les lignes
#

## `Success.gd` fait `self.main.go_to_node(...)` au clic.
func go_to_node(chapter_id) -> void:
	Player.go_to_node(int(chapter_id))
