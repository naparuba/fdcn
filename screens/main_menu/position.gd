extends PanelContainer

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
