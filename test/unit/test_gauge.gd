extends "res://addons/gut/test.gd"

var GaugeScene = preload('res://gauge.tscn')


func _make_gauge():
	var gauge = GaugeScene.instance()
	add_child_autofree(gauge)  # necessaire: onready var label_value = $label n'est resolu qu'a l'entree dans l'arbre
	return gauge


func test_set_value_updates_angle_and_label():
	var gauge = _make_gauge()
	gauge.set_value(0.5)
	assert_eq(gauge.angle_to, 180)
	assert_eq(gauge.get_node('label').text, '50%')


func test_set_value_zero():
	var gauge = _make_gauge()
	gauge.set_value(0)
	assert_eq(gauge.angle_to, 0)
	assert_eq(gauge.get_node('label').text, '0%')


func test_set_parameters_updates_radius_and_angle():
	# NOTE: set_parameters() fait "self.color = color" (ligne 22) alors que
	# Node2D n'a pas de propriete "color" -- SCRIPT ERROR a l'execution
	# (visible dans les logs), silencieusement absorbee par Godot qui
	# poursuit l'execution. Bug reel mais actuellement mort: aucun appelant
	# de set_parameters() n'existe ailleurs dans le code. La couleur n'est
	# donc jamais appliquee, mais radius/angle_to (avant/apres la ligne en
	# erreur) sont bien mis a jour.
	var gauge = _make_gauge()
	gauge.set_parameters(Color('ff0000'), 80, 0.25)
	assert_eq(gauge.radius, 80)
	assert_eq(gauge.angle_to, 90)
