extends PanelContainer

signal chapter_chosen(chap_number)
signal new_billy_requested()
signal previous_chapter_requested()

@onready var _choices = $VBoxContainer/ScrollContainer/Choices

var _chapter_choice_scene = preload('res://entities/ChapterChoice.tscn')
var _ending_choice_scene = preload('res://entities/EndingChoice.tscn')


func _ready() -> void:
	Player.chapter_changed.connect(_on_chapter_changed)
	_on_chapter_changed(Player.get_current_node_id())


func _on_chapter_changed(node_id) -> void:
	var my_node = BookData.get_chapter_node(node_id)
	set_choices(my_node.get_sons(), my_node.get_secret_jumps())

	if my_node.get_ending():
		var ending_id = my_node.get_success()
		if ending_id == null:
			ending_id = my_node.get_ending_id()
		var ending_txt = BookData.get_success_txt(ending_id)
		if ending_txt == '':
			ending_txt = my_node.get_ending_txt()
		add_ending_choice(ending_id, ending_txt, my_node.get_ending_type())


func set_choices(son_ids: Array, secret_jumps: Array) -> void:
	Utils.delete_children(_choices)
	for son_id in son_ids:
		if !BookData.is_node_id_freely_showable(son_id, secret_jumps):
			continue
		var son = BookData.get_chapter_node(son_id)
		var choice = _chapter_choice_scene.instantiate()
		choice.set_main(self)
		choice.update_from_son_node(son)
		_choices.add_child(choice)


func add_ending_choice(ending_id, ending_txt: String, ending_type) -> void:
	var choice = _ending_choice_scene.instantiate()
	choice.set_main(self)
	choice.set_ending_id(ending_id)
	choice.set_label(ending_txt)
	choice.set_ending_type(ending_type)
	_choices.add_child(choice)


# ChapterChoice.gd calls self.main.go_to_node(chap_number) on click.
func go_to_node(chap_number) -> void:
	Player.go_to_node(chap_number)
	chapter_chosen.emit(chap_number)


# EndingChoice.gd calls self.main.launch_new_billy() / .jump_to_previous_chapter().
func launch_new_billy() -> void:
	Player.launch_new_billy()
	Player.go_to_node(1)
	new_billy_requested.emit()


func jump_to_previous_chapter() -> void:
	var previous_id = Player.jump_to_previous_chapter()
	if previous_id == -1:
		return
	var can_jump_back = Player.jump_back(previous_id)
	if can_jump_back:
		Player.go_to_node(previous_id)
	previous_chapter_requested.emit()
