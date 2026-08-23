extends PanelContainer
## Bandeau de position dans le livre : nom de l'acte et sa progression, nom du sous-arc et
## sa progression s'il y en a un, numéro du chapitre courant.
##
## Un chapitre n'a pas forcément de sous-arc (`get_arc()` peut rendre `null`) : la section
## correspondante se masque, et le numéro de chapitre grossit pour occuper la place laissée
## (`_CHAPTER_FONT_SIZE_NO_ARC` contre `_CHAPTER_FONT_SIZE_WITH_ARC`).

@onready var _acte_label = $VBoxContainer/Content/Acte
@onready var _fill_bar = $VBoxContainer/Content/ProgressRow/fill_bar
@onready var _fill_bar_pct = $VBoxContainer/Content/ProgressRow/fill_par_pct

@onready var _arc_section = $VBoxContainer/Content/ArcSection
@onready var _arc_label = $VBoxContainer/Content/ArcSection/Arc
@onready var _fill_bar_arc = $VBoxContainer/Content/ArcSection/ProgressRow/fill_bar_arc
@onready var _fill_bar_arc_pct = $VBoxContainer/Content/ArcSection/ProgressRow/fill_bar_arc_pct

@onready var _numero_chapitre = $VBoxContainer/Content/ChapterRow/NumeroChapitre

const _CHAPTER_FONT_SIZE_WITH_ARC = 24
const _CHAPTER_FONT_SIZE_NO_ARC = 40


func _ready() -> void:
	Player.chapter_changed.connect(_on_chapter_changed)
	_on_chapter_changed(Player.get_current_node_id())


func _on_chapter_changed(node_id) -> void:
	var my_node = BookData.get_chapter_node(node_id)

	set_acte(my_node.get_chapter(), BookData.get_acte_completion(node_id, Player.get_visited_nodes_all_times()))

	var arc_name = my_node.get_arc()
	var pct100_sub_arc = 0
	if arc_name != null:
		pct100_sub_arc = BookData.get_sub_arc_completion(node_id, Player.get_visited_nodes_all_times())
	set_arc(arc_name, pct100_sub_arc)

	set_chapter_number(my_node.get_id())


func set_acte(acte_name: String, pct100: int) -> void:
	_acte_label.text = acte_name
	_fill_bar.value = pct100
	_fill_bar_pct.text = '%3d%%' % pct100


# Pass arc_name = null when the current chapter has no arc.
func set_arc(arc_name, pct100_sub_arc: int) -> void:
	_arc_section.visible = arc_name != null
	if arc_name == null:
		_numero_chapitre.add_theme_font_size_override('font_size', _CHAPTER_FONT_SIZE_NO_ARC)
		return
	_arc_label.text = arc_name
	_fill_bar_arc.value = pct100_sub_arc
	_fill_bar_arc_pct.text = '%3d%%' % pct100_sub_arc
	_numero_chapitre.add_theme_font_size_override('font_size', _CHAPTER_FONT_SIZE_WITH_ARC)


func set_chapter_number(node_id) -> void:
	_numero_chapitre.text = '%s' % node_id
