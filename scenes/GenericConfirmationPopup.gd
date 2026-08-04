extends Panel

@export var content = "" # (String, MULTILINE)
@export var accept_button: String = "Accepter"
@export var cancel_button: String = "Annuler"

signal generic_popup_accept()

const COL_NAVY = Color(0.192157, 0.231373, 0.278431)
const COL_CARD = Color(1, 1, 1)
const COL_CARD_ALT = Color(0.913725, 0.917647, 0.92549)
const COL_INK = Color(0, 0, 0)

var _rich_text_label: RichTextLabel
var _accept_button: Button
var _cancel_button: Button


func _ready():
	self._build_ui()
	hide()


func _build_ui():
	# Panneau racine plein-ecran = fond sombre semi-transparent (meme teinte que
	# l'overlay de resolution du combat) pour lire comme une vraie modale et
	# empecher les clics vers ce qu'il y a derriere.
	self.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	self.mouse_filter = Control.MOUSE_FILTER_STOP
	var backdrop_style = StyleBoxFlat.new()
	backdrop_style.bg_color = Color(0.192157, 0.231373, 0.278431, 0.85)
	self.add_theme_stylebox_override("panel", backdrop_style)

	var center = CenterContainer.new()
	center.name = "Center"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	self.add_child(center)

	var card = PanelContainer.new()
	card.name = "Card"
	card.custom_minimum_size = Vector2(480, 0)
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = COL_CARD
	card_style.set_corner_radius_all(14)
	card_style.shadow_color = Color(0.05, 0.08, 0.12, 0.15)
	card_style.shadow_size = 6
	card_style.content_margin_left = 20
	card_style.content_margin_right = 20
	card_style.content_margin_top = 20
	card_style.content_margin_bottom = 20
	card.add_theme_stylebox_override("panel", card_style)
	center.add_child(card)

	var v = VBoxContainer.new()
	v.name = "VBox"
	v.add_theme_constant_override("separation", 16)
	card.add_child(v)

	self._rich_text_label = RichTextLabel.new()
	self._rich_text_label.name = "RichTextLabel"
	self._rich_text_label.fit_content = true
	self._rich_text_label.scroll_active = false
	self._rich_text_label.add_theme_font_size_override("normal_font_size", 16)
	self._rich_text_label.add_theme_color_override("default_color", COL_INK)
	v.add_child(self._rich_text_label)

	var buttons_row = HBoxContainer.new()
	buttons_row.name = "ButtonsRow"
	buttons_row.add_theme_constant_override("separation", 10)
	v.add_child(buttons_row)

	self._accept_button = Button.new()
	self._accept_button.name = "PopupButtonAccept"
	self._accept_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	self._accept_button.custom_minimum_size = Vector2(0, 44)
	self._style_solid_button(self._accept_button, COL_NAVY, Color(1, 1, 1))
	self._accept_button.pressed.connect(self._on_PopupButtonAccept_pressed)
	buttons_row.add_child(self._accept_button)

	self._cancel_button = Button.new()
	self._cancel_button.name = "PopupButtonCancel"
	self._cancel_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	self._cancel_button.custom_minimum_size = Vector2(0, 44)
	self._style_solid_button(self._cancel_button, COL_CARD_ALT, COL_INK)
	self._cancel_button.pressed.connect(self._on_PopupButtonCancel_pressed)
	buttons_row.add_child(self._cancel_button)

	self._rich_text_label.text = self.content
	self._accept_button.text = self.accept_button
	self._cancel_button.text = self.cancel_button


func _style_solid_button(button: Button, bg: Color, fg: Color):
	var style = StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(10)
	button.add_theme_stylebox_override("normal", style)
	var style_pressed = style.duplicate()
	style_pressed.bg_color = bg.darkened(0.15)
	button.add_theme_stylebox_override("pressed", style_pressed)
	var style_hover = style.duplicate()
	style_hover.bg_color = bg.lightened(0.08)
	button.add_theme_stylebox_override("hover", style_hover)
	button.add_theme_color_override("font_color", fg)


func open():
	show()


func _on_PopupButtonAccept_pressed():
	emit_signal("generic_popup_accept")
	hide()


func _on_PopupButtonCancel_pressed():
	hide()
