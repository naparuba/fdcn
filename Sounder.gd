extends Node2D


var cache = {}  # no lot load() too much if we can avoid

var player = null

# Called when the node enters the scene tree for the first time.
func _ready():
	self.player = $Player



func play(pth):
	self.player.stop()
	var sound
	if pth in self.cache:
		sound = self.cache[pth]
	else:
		var full_pth = 'res://sounds/%s' % pth
		sound = load(full_pth)
		self.cache[pth] = sound
	self.player.stream = sound
	self.player.play()

