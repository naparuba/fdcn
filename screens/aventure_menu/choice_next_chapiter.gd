extends PanelContainer

signal chapter_chosen(chap_number)
signal new_billy_requested()
signal previous_chapter_requested()

@onready var _choices = $VBoxContainer/ScrollContainer/Choices

## Texte de la seule action destructrice de l'app. Partagé avec `screens/about_menu.gd`,
## qui propose le même bouton : deux formulations différentes pour la même conséquence
## seraient un piège.
const NOUVEAU_BILLY_TEXTE := "Commencer un nouveau Billy ?\n\nTa progression, tes objets et tes stats de cette partie seront effacés. Les chapitres déjà découverts et les succès obtenus sont conservés."

var _chapter_choice_scene = preload('res://entities/ChapterChoice.tscn')
var _ending_choice_scene = preload('res://entities/EndingChoice.tscn')


func _ready() -> void:
	Player.chapter_changed.connect(_on_chapter_changed)
	# Le chapitre courant n'est pas la seule entrée de cette liste : les **spoils**
	# décident quels choix sont affichés (`is_node_id_freely_showable`, plus la décoration
	# de chaque ligne). Sans cet abonnement, basculer le réglage ne changeait rien jusqu'au
	# chapitre suivant.
	#
	# `settings_changed` est volontairement grossier — il part aussi pour le son ou le type
	# de Billy. Reconstruire une quinzaine de lignes pour rien est sans conséquence, et
	# c'est le même compromis que les deux écrans de listes.
	AppParameters.settings_changed.connect(_rebuild)
	_on_chapter_changed(Player.get_current_node_id())


## Reconstruit la liste pour le chapitre courant, sans changer de chapitre.
## `set_choices()` vide ses enfants d'abord, donc l'appel est idempotent.
func _rebuild() -> void:
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
		# ⚠️ `add_child` AVANT d'alimenter : `ChapterChoice` a rassemblé ses chemins de
		# nœuds dans des `@onready`, qui ne sont affectés qu'à l'entrée dans l'arbre.
		# L'ordre inverse leur laisserait la valeur `null`.
		_choices.add_child(choice)
		choice.update_from_son_node(son)


func add_ending_choice(ending_id, ending_txt: String, ending_type) -> void:
	var choice = _ending_choice_scene.instantiate()
	choice.set_main(self)
	# `add_child` AVANT les setters, même raison que dans `set_choices` : `EndingChoice`
	# rassemble ses chemins de nœuds dans des `@onready`, nuls hors de l'arbre.
	_choices.add_child(choice)
	choice.set_ending_id(ending_id)
	choice.set_label(ending_txt)
	choice.set_ending_type(ending_type)


# ChapterChoice.gd calls self.main.go_to_node(chap_number) on click.
func go_to_node(chap_number) -> void:
	Player.go_to_node(chap_number)
	chapter_chosen.emit(chap_number)


# EndingChoice.gd calls self.main.launch_new_billy() / .jump_to_previous_chapter().
#
# Ça efface le fil d'Ariane, l'inventaire et les stats : c'est la seule action
# destructrice de l'app, elle passe donc par une confirmation. Si la popup ne trouve pas
# de conteneur (hors d'un MenuPage), on **ne fait rien** plutôt que d'effacer sans
# demander — une partie perdue coûte plus cher qu'un bouton qui ne réagit pas.
func launch_new_billy() -> void:
	var menu_page = Utils.find_ancestor_with_method(self, "confirm")
	if menu_page == null:
		push_warning("ChoiceNextChapiter: pas de conteneur de popup, nouveau Billy annulé")
		return
	menu_page.confirm(NOUVEAU_BILLY_TEXTE, _do_launch_new_billy, "Nouveau Billy")


func _do_launch_new_billy() -> void:
	Player.launch_new_billy()
	Player.go_to_node(1)
	new_billy_requested.emit()


func jump_to_previous_chapter() -> void:
	var previous_id = Player.jump_to_previous_chapter()
	if previous_id == -1:
		return
	Player.go_back_to(previous_id)
	previous_chapter_requested.emit()
