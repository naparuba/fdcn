extends Node2D


# Declare member variables here. Examples:
# var a = 2
# var b = "text"
onready var label_value = $label


var radius = 50
var inside_color = Color('313b47')
var outside_color = Color('01bcdb')
var angle_to = 90
var value_pct = 0.25

# Called when the node enters the scene tree for the first time.
func _ready():
	pass
	
func set_parameters(color, radius, value_pct):
	self.radius = radius
	self.color = color
	self.angle_to = 360 * value_pct


func set_value(value_pct):
	#print('Gauge: set value to %s' % value_pct)
	self.angle_to = 360 * value_pct
	self.label_value.text = '%s%%' % int(100*value_pct)
	

func _draw_inside(center, radius):
	var nb_points = 64
	var points_arc = PoolVector2Array()
	points_arc.push_back(center)
	var colors = PoolColorArray([self.inside_color])

	for i in range(nb_points + 1):
		var angle_point = deg2rad(0 + i * (360 ) / nb_points - 90)
		points_arc.push_back(center + Vector2(cos(angle_point), sin(angle_point)) * radius)
	draw_polygon(points_arc, colors)


func _draw():
	#print("PRINT CIRCLE")
	var center = Vector2(0, 0)
	#var radius = 60
	var angle_from = 0
	#var angle_to = 195
	#var color = Color('313b47')
	
	var nb_points = 64
	var points_arc = PoolVector2Array()
	points_arc.push_back(center)
	var colors = PoolColorArray([self.outside_color])

	for i in range(nb_points + 1):
		var angle_point = deg2rad(angle_from + i * (angle_to - angle_from) / nb_points - 90)
		points_arc.push_back(center + Vector2(cos(angle_point), sin(angle_point)) * radius)
	draw_polygon(points_arc, colors)

	self._draw_inside(center, radius-10)


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
