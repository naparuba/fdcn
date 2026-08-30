extends PanelContainer
## Jauge de complétion globale du livre : « X / Y » chapitres visités, toutes parties
## confondues (`Player.get_nb_all_time_seen()`), sur le total du livre courant.
##
## Plus de `GaugeSizer` entre les deux : la jauge est passée de `Node2D` à `Control`, un
## conteneur sait donc la placer lui-même.
@onready var _gauge = $VBoxContainer/GaugeWrap/Gauge
@onready var _footnode = $VBoxContainer/footnode


func _ready() -> void:
	Player.chapter_changed.connect(_on_chapter_changed)
	_refresh()


func _on_chapter_changed(_node_id) -> void:
	_refresh()


func _refresh() -> void:
	var nb_all_nodes = BookData.get_all_nodes().size()
	if nb_all_nodes == 0:
		return
	set_completion(Player.get_nb_all_time_seen(), nb_all_nodes)


func set_completion(nb_visited: int, nb_all_nodes: int) -> void:
	_footnode.text = (' %d /' % nb_visited) + (' %d' % nb_all_nodes)
	_gauge.set_value(nb_visited / float(nb_all_nodes))
