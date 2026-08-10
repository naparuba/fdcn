extends Panel
## Choix du livre.
##
## On passe par AppParameters et non par BookData directement : c'est lui qui
## persiste le choix dans parameters.json, recharge le livre, puis émet
## `book_changed` pour que Player recharge la sauvegarde de ce livre.

func _on_bool_select_fcdn_pressed() -> void:
	AppParameters.set_book_name("fdcn")


func _on_bool_select_cdsi_pressed() -> void:
	AppParameters.set_book_name("cdsi")
