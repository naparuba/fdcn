tool

extends Panel



export var txt = 'unset'
export var dest = 'UNSET'

# Called when the node enters the scene tree for the first time.
func _ready():
	$txt.text = txt




func _on_button_pressed():
	Swiper.go_to_page(self.dest)
