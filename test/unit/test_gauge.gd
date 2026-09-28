extends "res://addons/gut/test.gd"

var GaugeScene = preload('res://gauge.tscn')


func _make_gauge():
	var gauge = GaugeScene.instantiate()
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
	# set_parameters() faisait "self.color = color" (propriete inexistante
	# sur Node2D) -- silencieusement absorbe par Godot 3 (script error dans
	# les logs mais execution poursuivie), erreur fatale en Godot 4. Corrige
	# en "self.outside_color = color", la propriete reellement dessinee.
	var gauge = _make_gauge()
	gauge.set_parameters(Color('ff0000'), 80, 0.25)
	assert_eq(gauge.radius, 80)
	assert_eq(gauge.angle_to, 90)
	assert_eq(gauge.outside_color, Color('ff0000'))
