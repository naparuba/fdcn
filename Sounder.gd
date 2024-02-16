extends Node2D


var _is_enabled = true  # parameters can change this

var cache = {}  # no lot load() too much if we can avoid

var player = null

# Called when the node enters the scene tree for the first time.
func _ready():
	self.player = $Player


func set_enabled(b):
	self._is_enabled = b
	if !self._is_enabled:  # Maybe the user is asking for no more sound ^^
		print('STOPING SOUND')
		if self.player != null:
			self.player.stop()


func is_enabled():
	return self._is_enabled


func play(pth):
	self.player.stop()
	if !self._is_enabled:
		return
	var sound
	if pth in self.cache:
		sound = self.cache[pth]
	else:
		var full_pth = 'res://sounds/%s' % pth
		sound = load(full_pth)
		self.cache[pth] = sound
	self.player.stream = sound
	self.player.play()


func stop():
	self.player.stop()
