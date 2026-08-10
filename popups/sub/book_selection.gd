extends Panel

func _on_bool_select_fcdn_pressed() -> void:
	BookData.do_load_book("fdcn")


func _on_bool_select_cdsi_pressed() -> void:
	BookData.do_load_book("cdsi")
