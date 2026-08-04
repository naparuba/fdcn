extends "res://addons/gut/test.gd"

var PopupScene = preload('res://scenes/GenericConfirmationPopup.tscn')


func test_ready_applies_exported_texts_and_hides_by_default():
	var popup = PopupScene.instantiate()
	popup.content = 'Etes-vous sur ?'
	popup.accept_button = 'Oui'
	popup.cancel_button = 'Non'
	add_child_autofree(popup)  # _ready() construit l'UI, applique le contenu et hide()
	assert_eq(popup._rich_text_label.text, 'Etes-vous sur ?')
	assert_eq(popup._accept_button.text, 'Oui')
	assert_eq(popup._cancel_button.text, 'Non')
	assert_false(popup.visible)


func test_open_shows_the_popup():
	var popup = PopupScene.instantiate()
	add_child_autofree(popup)
	popup.open()
	assert_true(popup.visible)


func test_accept_emits_signal_and_hides():
	var popup = PopupScene.instantiate()
	add_child_autofree(popup)
	popup.open()
	watch_signals(popup)
	popup._on_PopupButtonAccept_pressed()
	assert_signal_emitted(popup, 'generic_popup_accept')
	assert_false(popup.visible)


func test_cancel_hides_without_emitting_signal():
	var popup = PopupScene.instantiate()
	add_child_autofree(popup)
	popup.open()
	watch_signals(popup)
	popup._on_PopupButtonCancel_pressed()
	assert_signal_not_emitted(popup, 'generic_popup_accept')
	assert_false(popup.visible)
