extends Panel

@export_multiline var content := ""
@export var accept_button: String = "Accepter"
@export var cancel_button: String = "Annuler"

signal generic_popup_accept()


## Les chemins ont changé avec le passage en conteneurs : la boîte est désormais centrée
## par un `CenterContainer` au lieu d'être posée à un offset fixe (16, 256), qui la
## plaçait de travers dès que la page n'était pas exactement 540 de large.
func _ready():
	$Center/Boite/Margin/Contenu/RichTextLabel.text = content
	$Center/Boite/Margin/Contenu/Boutons/PopupButtonAccept.text = accept_button
	# Un libellé d'annulation VIDE cache le bouton : la même popup sert alors d'accusé de
	# réception (« Partie exportée dans… »), où proposer d'annuler n'aurait aucun sens.
	var annuler = $Center/Boite/Margin/Contenu/Boutons/PopupButtonCancel
	annuler.text = cancel_button
	annuler.visible = cancel_button != ""
	hide()

func open():
	show()


# Les deux boutons LIBÈRENT la popup au lieu de la masquer. `MenuPage.is_popup_open()`
# compte tout enfant non détruit de son conteneur : une popup seulement cachée y
# bloquerait la navigation définitivement.
#
# `hide()` dans `_ready()` est conservé : `screens/AboutMenu.tscn` instancie cette scène
# à même la page et compte sur ce masquage pour rester invisible.
func _on_PopupButtonAccept_pressed():
	generic_popup_accept.emit()
	queue_free()


func _on_PopupButtonCancel_pressed():
	queue_free()
