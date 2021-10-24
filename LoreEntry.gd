tool

extends Panel


# Declare member variables here. Examples:
# var a = 2
# var b = "text"

export var type_entry = 'billys'
export var entry_name = 'guerrier'
export var titre = 'XXXX'


var is_playing = false

# Called when the node enters the scene tree for the first time.
func _ready():
	$Label.text = titre
	
	var texture = ImageTexture.new()
	var image = Image.new()
	var dir = type_entry
	var ext = 'png'  # default for billy
	if type_entry == 'dieux':
		ext = 'jpg'
	var pth = 'res://images/%s/'%type_entry
	pth += entry_name
	pth += '.%s' % ext
	print('FULL PATH: %s' % pth)
	var err = image.load(pth)
	if err != OK:
		print('ERROR: cannot load %s' % err)
		return
	texture.create_from_image(image)
	$Sprite.texture = texture
	print('SPRITE LOADED: %s' % entry_name)


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass

func _set_can_play():
	var sprite_play = $click/sprite_play
	var sprite_stop = $click/sprite_stop
	self.is_playing = false
	sprite_play.visible = true
	sprite_stop.visible = false


func _set_playing():
	var sprite_play = $click/sprite_play
	var sprite_stop = $click/sprite_stop
	self.is_playing = true
	sprite_play.visible = false
	sprite_stop.visible = true


func _on_play_pressed():
	var player = $AudioStreamPlayer

	# Play
	if ! self.is_playing:
		var pth = 'res://sounds/%s/'%type_entry
		pth += entry_name
		pth += '.mp3'
		print('FULL PATH: %s' % pth)
		var sound = load(pth)
		print('%s is load '% sound, 'for ', entry_name)
		
		player.stream = sound
		player.play()
		self._set_playing()

	else:  #STOP
		player.stop()
		self._set_can_play()



func _on_AudioStreamPlayer_finished():
	self._set_can_play()
