extends Panel
## Écran « Tous les chapitres » — liste virtualisée.
##
## POURQUOI UNE LISTE VIRTUELLE
## Un livre compte 606 (fdcn) à 691 (cdsi) chapitres, et une ligne
## `ChapterChoice` pèse 21 nœuds. Tout instancier ferait ~13 000 nœuds : c'est
## ce que faisait l'ancienne app (`archive/main.gd:insert_all_chapters`), et
## c'est la cause des ralentissements sur cet écran.
##
## Ici on ne crée qu'une poignée de lignes — de quoi couvrir la hauteur visible
## plus une marge — et on les **recycle** au défilement. Le nombre de nœuds ne
## dépend donc plus de la taille du livre.
##
## Le `Content` du ScrollContainer n'a pas d'enfants empilés : il a simplement la
## hauteur totale qu'aurait la liste complète, et les lignes recyclées y sont
## posées à la bonne position. La barre de défilement se comporte donc
## exactement comme si les 606 lignes existaient.

## Hauteur d'une ligne, alignée sur `ChapterChoice.tscn` (custom_minimum_size.y).
const ROW_HEIGHT := 75.0

## Lignes gardées en plus au-dessus et en dessous de la zone visible, pour que
## le recyclage ne se voie pas pendant un défilement rapide.
const BUFFER_ROWS := 3

## Paliers proposés par la barre « Saut ».
const JUMP_STEPS := [1, 100, 200, 300, 400, 500, 600]

@onready var _scroll: ScrollContainer = $VBox/Scroll
@onready var _content: Control = $VBox/Scroll/Content
@onready var _jump_buttons: HBoxContainer = $VBox/JumpBar/Buttons

var _row_scene: PackedScene = preload("res://entities/ChapterChoice.tscn")

## Identifiants de chapitres, triés numériquement.
var _chapter_ids: Array = []

## Les lignes recyclées. `_pool[i]` affiche le chapitre `_first_index + i`.
var _pool: Array = []
var _first_index := -1


func _ready() -> void:
	_build_jump_buttons()
	_scroll.get_v_scroll_bar().value_changed.connect(func(_v): _refresh_rows())
	_scroll.resized.connect(_on_scroll_resized)

	Player.chapter_changed.connect(func(_id): _refresh_rows(true))
	AppParameters.book_changed.connect(func(_name): _load_chapters())
	# Les spoils changent ce qu'une ligne a le droit d'afficher.
	AppParameters.settings_changed.connect(func(): _refresh_rows(true))

	_load_chapters()


#
#    Données
#

func _load_chapters() -> void:
	_chapter_ids = []
	for id_str in BookData.get_all_nodes().keys():
		_chapter_ids.append(int(id_str))
	_chapter_ids.sort()

	# La hauteur totale fait comme si toutes les lignes étaient là : c'est elle
	# qui donne sa course à la barre de défilement.
	_content.custom_minimum_size.y = _chapter_ids.size() * ROW_HEIGHT
	_scroll.scroll_vertical = 0
	_first_index = -1
	_refresh_rows(true)


#
#    Virtualisation
#

func _on_scroll_resized() -> void:
	_ensure_pool()
	_refresh_rows(true)


## Crée juste assez de lignes pour couvrir la hauteur visible (+ marge).
func _ensure_pool() -> void:
	var visible_height = _scroll.size.y
	if visible_height <= 0.0:
		return
	var needed = int(ceil(visible_height / ROW_HEIGHT)) + BUFFER_ROWS * 2
	needed = min(needed, _chapter_ids.size())

	while _pool.size() < needed:
		var row = _row_scene.instantiate()
		row.set_main(self)
		# Ancrages gauche/droite conservés : la ligne suit la largeur du
		# conteneur toute seule. On ne pilote que sa position verticale.
		row.offset_left = 0
		row.offset_right = 0
		_content.add_child(row)
		_pool.append(row)

	# Le livre est plus court que la zone visible : on rend le surplus inutile.
	while _pool.size() > needed:
		var row = _pool.pop_back()
		row.queue_free()


## Replace et réalimente les lignes selon la position de défilement.
## `force` réactualise même les lignes qui n'ont pas changé de chapitre (utile
## quand c'est l'état du joueur, et non le défilement, qui a bougé).
func _refresh_rows(force := false) -> void:
	if _pool.is_empty():
		_ensure_pool()
		if _pool.is_empty():
			return

	var first = int(_scroll.scroll_vertical / ROW_HEIGHT) - BUFFER_ROWS
	first = clampi(first, 0, max(0, _chapter_ids.size() - _pool.size()))

	var moved = first != _first_index
	_first_index = first

	for i in _pool.size():
		var row = _pool[i]
		var index = first + i
		if index >= _chapter_ids.size():
			row.visible = false
			continue

		row.visible = true
		var y = index * ROW_HEIGHT
		row.offset_top = y
		row.offset_bottom = y + ROW_HEIGHT

		# On ne réalimente que si la ligne change de chapitre : inutile de
		# refaire les lectures BookData à chaque pixel de défilement.
		var chapter_id = _chapter_ids[index]
		if force or moved or row.get_chapter_id() != chapter_id:
			row.set_chapitre(chapter_id)
			row.update_when_in_all_chapters()


#
#    Barre « Saut »
#

func _build_jump_buttons() -> void:
	for step in JUMP_STEPS:
		var button = Button.new()
		button.text = str(step)
		button.custom_minimum_size = Vector2(44, 42)
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		button.pressed.connect(_jump_to_chapter.bind(step))
		_jump_buttons.add_child(button)


## Amène la vue sur le premier chapitre dont le numéro est >= `chapter_number`.
func _jump_to_chapter(chapter_number: int) -> void:
	for i in _chapter_ids.size():
		if _chapter_ids[i] >= chapter_number:
			_scroll.scroll_vertical = int(i * ROW_HEIGHT)
			_refresh_rows(true)
			return


#
#    Appelé par les lignes
#

## `ChapterChoice.gd` fait `self.main.go_to_node(...)` au clic.
func go_to_node(chapter_id) -> void:
	Player.go_to_node(chapter_id)
