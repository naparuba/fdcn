extends Panel

@onready var _choice_next_chapiter = $Padding/VBoxContainer/ChoiceNextChapiter
@onready var _combat = $Padding/VBoxContainer/Combat


func _ready() -> void:
	Player.chapter_changed.connect(_on_chapter_changed)
	_combat.combat_finished.connect(_on_combat_finished)
	_on_chapter_changed(Player.get_current_node_id())


func _on_chapter_changed(node_id) -> void:
	var node = BookData.get_chapter_node(node_id)
	_choice_next_chapiter.visible = !node.is_combat()


func _on_combat_finished() -> void:
	_choice_next_chapiter.visible = true
