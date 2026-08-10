extends PanelContainer

@onready var _gauge = $VBoxContainer/GaugeWrap/GaugeSizer/Gauge
@onready var _footnode = $VBoxContainer/footnode


func set_completion(nb_visited: int, nb_all_nodes: int) -> void:
	_footnode.text = (' %d /' % nb_visited) + (' %d' % nb_all_nodes)
	_gauge.set_value(nb_visited / float(nb_all_nodes))
