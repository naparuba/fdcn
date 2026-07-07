extends Panel

@export var txt: String = 'unset'
@export var is_disabled: bool = false
@export var is_mirror: bool = false

signal _on_nav_pressed()

# Called when the node enters the scene tree for the first time.
func _ready():
	$txt.text = txt
	if is_mirror:
		setMirror(true)
	if is_disabled:
		setDisabled(true)

func setDisabled(newValue: bool):
	if (newValue == true):
		$poly.color = Color('9ea8b4')
	else:
		$poly.color = Color('313b47')

func setMirror(newValue: bool):
	if (newValue == true):
		set_rotation(PI)
	else:
		set_rotation(0)

func _on_button_button_down() -> void:
	emit_signal("_on_nav_pressed")
