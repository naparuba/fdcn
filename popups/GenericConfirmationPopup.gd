extends Panel

@export var content = "" # (String, MULTILINE)
@export var accept_button: String = "Accepter"
@export var cancel_button: String = "Annuler"

signal generic_popup_accept()


func _ready():
	$RichTextLabel.text = content
	$PopupButtonAccept.text = accept_button
	$PopupButtonCancel.text = cancel_button
	hide()

func open():
	show()


func _on_PopupButtonAccept_pressed():
	emit_signal("generic_popup_accept")
	hide()


func _on_PopupButtonCancel_pressed():
	hide()
