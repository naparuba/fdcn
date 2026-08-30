extends Panel
## L'écran Aventure : bascule entre la liste de choix du chapitre et le combat.
##
## Ne fait rien d'autre qu'arbitrer les deux : `ChoiceNextChapiter` est masqué pendant un
## combat (`is_combat()`), et remontre dès `combat_finished`, que l'issue soit une victoire,
## une défaite ou une fuite — le moteur ne pousse qu'un seul signal pour les trois, à étendre
## en trois issues distinctes si besoin un jour.

@onready var _choice_next_chapiter = $VBoxContainer/ChoiceNextChapiter
@onready var _combat = $VBoxContainer/Combat


func _ready() -> void:
	Player.chapter_changed.connect(_on_chapter_changed)
	_combat.combat_finished.connect(_on_combat_finished)
	_on_chapter_changed(Player.get_current_node_id())


func _on_chapter_changed(node_id) -> void:
	var node = BookData.get_chapter_node(node_id)
	_choice_next_chapiter.visible = !node.is_combat()


func _on_combat_finished() -> void:
	_choice_next_chapiter.visible = true
