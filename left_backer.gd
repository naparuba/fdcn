tool

extends Panel



export var txt = 'unset'
export var dest = 'UNSET'
export var is_disabled = false

# Called when the node enters the scene tree for the first time.
func _ready():
	$txt.text = txt
	
func set_enabled():
	$poly.color = Color('313b47')

func set_disabled():
	$poly.color = Color('9ea8b4')

func _on_button_pressed():
	Swiper.go_to_page(self.dest)
