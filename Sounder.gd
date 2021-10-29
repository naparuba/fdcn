extends Node2D


# Declare member variables here. Examples:
# var a = 2
# var b = "text"

var player = null

# Called when the node enters the scene tree for the first time.
func _ready():
	self.player = $Player



func play(pth):
	self.player.stop()
	var full_pth = 'res://sounds/%s' % pth
	var sound = load(full_pth)
	self.player.stream = sound
	self.player.play()
	print('PLAYING %s' % full_pth)
