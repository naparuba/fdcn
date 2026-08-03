extends Panel

# Fiche de personnage de Billy (onglet "Stats" des Options) -- affiche
# chaque statistique avec sa provenance (Base / Objets & Billy / Chapitres
# & Autre) et permet une edition directe ("on sera toujours en mode
# triche", cf retour explicite) qui respecte les vraies regles du jeu :
# PV max = Endurance x3 + bonus, Chance jamais au-dessus de son max,
# Endurance jamais sous 1, esquive derivee de l'Adresse.
#
# "Objets & Billy" reste EN LECTURE SEULE : c'est un total calcule (vrais
# objets possedes + type de Billy), le corriger a la main masquerait un
# vrai bug plutot que de tricher legitimement (cf retour explicite). Seul
# "Chapitres & Autre" est editable -- mais jamais en touchant les vrais
# accumulateurs de chapitre (Player.*_chapters, l'historique narratif
# reel) : les +/- passent par les champs Player.*_user, prevus pour
# "debug ou triche" (cf leur commentaire dans player.gd) mais jamais
# cables jusqu'ici. La pastille affiche chapters+user combines ; taper une
# valeur precise ne modifie que la part "user", jamais chapters.
#
# UI entierement construite en code (cf Combat.gd -- convention du projet,
# hand-editer des .tscn complexes s'est deja montre fragile cette session).

const COL_NAVY = Color(0.192157, 0.231373, 0.278431)
const COL_TEAL = Color(0, 0.760784, 0.666667)
const COL_CORAIL = Color(0.956863, 0.345098, 0.345098)
const COL_CYAN = Color(0.05, 0.6, 0.75)
const COL_GOLD = Color(0.72, 0.55, 0.09)
const COL_CARD = Color(1, 1, 1)
const COL_CARD_ALT = Color(0.913725, 0.917647, 0.92549)
const COL_INK = Color(0, 0, 0)
const COL_INK_SOFT = Color(0.45, 0.45, 0.45)

const BASE = {"hab": 2, "end": 2, "adr": 1, "chamax": 3, "crit": 0, "deg": 0, "arm": 0}

const STAT_DEFS = [
	{"key": "hab", "label": "Habileté", "role": "Différence d'Habileté avec l'adversaire → détermine les dégâts échangés à chaque tour de combat."},
	{"key": "end", "label": "Endurance", "role": "PV maximum = Endurance × 3, plus un éventuel bonus gagné en cours d'aventure."},
	{"key": "adr", "label": "Adresse", "role": "Dès 2, Billy peut esquiver une attaque (jet séparé) : probabilité et contre-attaque critique ci-dessous."},
	{"key": "chamax", "label": "Chance (max)", "role": "Réserve maximum de Chance — la Chance actuelle ne peut jamais la dépasser."},
	{"key": "crit", "label": "Critique", "role": "Bonus de dégâts ajouté à une contre-attaque critique (esquive réussie + jet de 1)."},
	{"key": "deg", "label": "Dégâts", "role": "Bonus de dégâts plat ajouté à une attaque normale réussie."},
	{"key": "arm", "label": "Armure", "role": "Réduction plate des dégâts subis par Billy, avant tout autre effet."},
]

var _type_badge: Label
var _pv_bar_fill: ColorRect
var _pv_value_field: LineEdit
var _cha_bar_fill: ColorRect
var _cha_value_field: LineEdit
var _pv_max_bonus_field: LineEdit
var _pv_max_result_label: Label
var _stat_widgets := {}  # key -> Dictionary{total_label, autre_field, esquive_dice: Array, esquive_state_label}


func _ready():
	self._build_ui()
	self.refresh()


# =============================================================================
# Lecture/ecriture des donnees reelles (Player) -- seul point de contact
# avec les vraies regles du jeu.
# =============================================================================

func _total(key: String) -> int:
	return Player.call("get_%s" % key)


func _chapitres_autre(key: String) -> int:
	return Player.call("get_%s_chapters" % key) + Player.call("get_%s_user" % key)


func _set_chapitres_autre(key: String, nouveau_total: int) -> void:
	var part_chapitres = Player.call("get_%s_chapters" % key)
	Player.set("%s_user" % key, nouveau_total - part_chapitres)
	self._recompute_and_refresh()


func _step_chapitres_autre(key: String, delta: int) -> void:
	Player.set("%s_user" % key, Player.get("%s_user" % key) + delta)
	self._recompute_and_refresh()


func _pv_max_bonus_total() -> int:
	return Player.pv_max_bonus + Player.pv_max_bonus_user


func _set_pv_max_bonus(nouveau_total: int) -> void:
	Player.pv_max_bonus_user = nouveau_total - Player.pv_max_bonus
	self._recompute_and_refresh()


func _step_pv_max_bonus(delta: int) -> void:
	Player.pv_max_bonus_user += delta
	self._recompute_and_refresh()


func _recompute_and_refresh() -> void:
	Player._recompute_stats()
	# L'Endurance ne doit jamais tomber a 0 ou moins : PV max deviendrait
	# nul ou negatif, un etat que le reste du jeu ne gere pas.
	if Player.get_end() < 1:
		Player.end_user += 1 - Player.get_end()
		Player._recompute_stats()
	# PV/Chance courants ne doivent jamais depasser leur max, meme apres un
	# changement d'Endurance/Chance max qui abaisserait ce plafond.
	Player.pv = clampi(Player.pv, 0, Player.pv_max)
	Player.cha = clampi(Player.cha, 0, Player.chamax)
	self.refresh()


func _step_pv(delta: int) -> void:
	Player.pv = clampi(Player.pv + delta, 0, Player.pv_max)
	self.refresh()


func _set_pv(v: int) -> void:
	Player.pv = clampi(v, 0, Player.pv_max)
	self.refresh()


func _fill_pv() -> void:
	Player.pv = Player.pv_max
	self.refresh()


func _step_cha(delta: int) -> void:
	Player.cha = clampi(Player.cha + delta, 0, Player.chamax)
	self.refresh()


func _set_cha(v: int) -> void:
	Player.cha = clampi(v, 0, Player.chamax)
	self.refresh()


func _fill_cha() -> void:
	Player.cha = Player.chamax
	self.refresh()


func fill_all() -> void:
	Player.pv = Player.pv_max
	Player.cha = Player.chamax
	self.refresh()


# =============================================================================
# Construction de l'interface (tout dynamique, cf en-tete de fichier)
# =============================================================================

func _build_ui():
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	self.add_child(margin)

	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)

	var layout = VBoxContainer.new()
	layout.set_h_size_flags(Control.SIZE_EXPAND_FILL)
	layout.add_theme_constant_override("separation", 8)
	scroll.add_child(layout)

	var warning = Label.new()
	warning.text = "Attention : fonctionnalité non finie, bugs possibles :)"
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warning.add_theme_font_size_override("font_size", 11)
	warning.add_theme_color_override("font_color", Color(1, 0.419608, 0))
	layout.add_child(warning)

	self._type_badge = Label.new()
	self._type_badge.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	self._type_badge.add_theme_font_size_override("font_size", 11)
	self._type_badge.add_theme_color_override("font_color", COL_INK_SOFT)
	layout.add_child(self._type_badge)

	layout.add_child(self._build_pv_card())

	for stat_def in STAT_DEFS:
		layout.add_child(self._build_stat_card(stat_def))

	var footer = HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	layout.add_child(footer)
	var fill_all_btn = Button.new()
	fill_all_btn.text = "⚡ Tout remplir (PV + Chance)"
	self._style_solid_button(fill_all_btn, COL_NAVY, Color(1, 1, 1))
	fill_all_btn.pressed.connect(self.fill_all)
	footer.add_child(fill_all_btn)


func _style_solid_button(button: Button, bg: Color, fg: Color):
	var style = StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(8)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	button.add_theme_stylebox_override("normal", style)
	var style_pressed = style.duplicate()
	style_pressed.bg_color = bg.darkened(0.15)
	button.add_theme_stylebox_override("pressed", style_pressed)
	var style_hover = style.duplicate()
	style_hover.bg_color = bg.lightened(0.08)
	button.add_theme_stylebox_override("hover", style_hover)
	button.add_theme_color_override("font_color", fg)
	button.add_theme_font_size_override("font_size", 12)


func _card_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = COL_CARD
	style.set_corner_radius_all(10)
	style.shadow_color = Color(0.05, 0.08, 0.12, 0.06)
	style.shadow_size = 3
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style


func _make_step_button(glyph: String, minus: bool) -> Button:
	var btn = Button.new()
	btn.text = glyph
	btn.custom_minimum_size = Vector2(24, 24)
	self._style_solid_button(btn, COL_INK_SOFT if minus else COL_NAVY, Color(1, 1, 1))
	btn.add_theme_font_size_override("font_size", 13)
	return btn


# LineEdit numerique compact -- affiche/edite une valeur en place, jamais
# un Label qu'il faudrait d'abord "activer" (cf retour explicite : on est
# TOUJOURS en edition sur cette page).
func _make_number_field(on_commit: Callable) -> LineEdit:
	var field = LineEdit.new()
	field.custom_minimum_size = Vector2(38, 0)
	field.alignment = HORIZONTAL_ALIGNMENT_CENTER
	field.add_theme_font_size_override("font_size", 13)
	field.text_submitted.connect(func(_t): field.release_focus())
	field.focus_exited.connect(func():
		var v = field.text.to_int()
		on_commit.call(v)
	)
	return field


func _make_static_pill(parent: HBoxContainer, libelle: String, valeur_getter: Callable) -> Label:
	var box = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = COL_CARD_ALT
	style.set_corner_radius_all(6)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	box.add_theme_stylebox_override("panel", style)
	parent.add_child(box)
	var h = HBoxContainer.new()
	h.add_theme_constant_override("separation", 3)
	box.add_child(h)
	var l = Label.new()
	l.text = libelle + " "
	l.add_theme_font_size_override("font_size", 10)
	l.add_theme_color_override("font_color", COL_INK_SOFT)
	h.add_child(l)
	var v = Label.new()
	v.add_theme_font_size_override("font_size", 10)
	v.add_theme_color_override("font_color", COL_INK)
	h.add_child(v)
	return v


func _build_pv_card() -> PanelContainer:
	var card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", self._card_style())
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	card.add_child(v)

	var top = HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	v.add_child(top)
	var label = Label.new()
	label.text = "Points de Vie"
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", COL_INK)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(label)

	var role = Label.new()
	role.text = "Tombe à 0 : Billy est vaincu. Ne peut jamais dépasser son maximum, même en éditant."
	role.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	role.add_theme_font_size_override("font_size", 10)
	role.add_theme_color_override("font_color", COL_INK_SOFT)
	v.add_child(role)

	var bar_row = HBoxContainer.new()
	bar_row.add_theme_constant_override("separation", 6)
	v.add_child(bar_row)

	var minus = self._make_step_button("−", true)
	minus.pressed.connect(self._step_pv.bind(-1))
	bar_row.add_child(minus)

	var bar_bg = Panel.new()
	bar_bg.custom_minimum_size = Vector2(0, 10)
	bar_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bar_bg_style = StyleBoxFlat.new()
	bar_bg_style.bg_color = COL_CARD_ALT
	bar_bg_style.set_corner_radius_all(5)
	bar_bg.add_theme_stylebox_override("panel", bar_bg_style)
	bar_row.add_child(bar_bg)
	self._pv_bar_fill = ColorRect.new()
	self._pv_bar_fill.color = COL_TEAL
	self._pv_bar_fill.anchor_top = 0.0
	self._pv_bar_fill.anchor_bottom = 1.0
	self._pv_bar_fill.anchor_left = 0.0
	self._pv_bar_fill.anchor_right = 0.0
	bar_bg.add_child(self._pv_bar_fill)

	var plus = self._make_step_button("+", false)
	plus.pressed.connect(self._step_pv.bind(1))
	bar_row.add_child(plus)

	self._pv_value_field = self._make_number_field(self._set_pv)
	bar_row.add_child(self._pv_value_field)

	var fill_btn = Button.new()
	fill_btn.text = "Plein"
	self._style_solid_button(fill_btn, COL_TEAL, Color(1, 1, 1))
	fill_btn.pressed.connect(self._fill_pv)
	bar_row.add_child(fill_btn)

	return card


func _build_stat_card(stat_def: Dictionary) -> PanelContainer:
	var key = stat_def["key"]
	var card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", self._card_style())
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	card.add_child(v)

	var top = HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	v.add_child(top)
	var label = Label.new()
	label.text = stat_def["label"]
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", COL_INK)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(label)
	var total_label = Label.new()
	total_label.add_theme_font_size_override("font_size", 19)
	total_label.add_theme_color_override("font_color", COL_NAVY)
	top.add_child(total_label)

	var role = Label.new()
	role.text = stat_def["role"]
	role.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	role.add_theme_font_size_override("font_size", 10)
	role.add_theme_color_override("font_color", COL_INK_SOFT)
	v.add_child(role)

	var pill_row = HBoxContainer.new()
	pill_row.add_theme_constant_override("separation", 6)
	v.add_child(pill_row)

	var base_pill = PanelContainer.new()
	var base_style = StyleBoxFlat.new()
	base_style.bg_color = COL_CARD_ALT
	base_style.set_corner_radius_all(6)
	base_style.content_margin_left = 6
	base_style.content_margin_right = 6
	base_style.content_margin_top = 2
	base_style.content_margin_bottom = 2
	base_pill.add_theme_stylebox_override("panel", base_style)
	pill_row.add_child(base_pill)
	var base_h = HBoxContainer.new()
	base_h.add_theme_constant_override("separation", 3)
	base_pill.add_child(base_h)
	var base_lbl = Label.new()
	base_lbl.text = "Base "
	base_lbl.add_theme_font_size_override("font_size", 10)
	base_lbl.add_theme_color_override("font_color", COL_INK_SOFT)
	base_h.add_child(base_lbl)
	var base_val = Label.new()
	base_val.text = str(BASE[key])
	base_val.add_theme_font_size_override("font_size", 10)
	base_val.add_theme_color_override("font_color", COL_INK)
	base_h.add_child(base_val)

	# "Objets & Billy" : total calcule, JAMAIS editable (cf en-tete de fichier).
	var objets_val = self._make_static_pill(pill_row, "Objets & Billy", Callable())

	# "Chapitres & Autre" : seule pastille editable (chapters+user combines).
	var autre_pill = PanelContainer.new()
	var autre_style = StyleBoxFlat.new()
	autre_style.bg_color = COL_CARD_ALT
	autre_style.set_corner_radius_all(6)
	autre_style.content_margin_left = 3
	autre_style.content_margin_right = 3
	autre_style.content_margin_top = 1
	autre_style.content_margin_bottom = 1
	autre_pill.add_theme_stylebox_override("panel", autre_style)
	pill_row.add_child(autre_pill)
	var autre_h = HBoxContainer.new()
	autre_h.add_theme_constant_override("separation", 2)
	autre_pill.add_child(autre_h)
	var autre_lbl = Label.new()
	autre_lbl.text = "Chapitres & Autre "
	autre_lbl.add_theme_font_size_override("font_size", 10)
	autre_lbl.add_theme_color_override("font_color", COL_INK_SOFT)
	autre_h.add_child(autre_lbl)
	var autre_minus = self._make_step_button("−", true)
	autre_minus.custom_minimum_size = Vector2(18, 18)
	autre_minus.pressed.connect(self._step_chapitres_autre.bind(key, -1))
	autre_h.add_child(autre_minus)
	var autre_field = self._make_number_field(func(v): self._set_chapitres_autre(key, v))
	autre_field.custom_minimum_size = Vector2(28, 0)
	autre_h.add_child(autre_field)
	var autre_plus = self._make_step_button("+", false)
	autre_plus.custom_minimum_size = Vector2(18, 18)
	autre_plus.pressed.connect(self._step_chapitres_autre.bind(key, 1))
	autre_h.add_child(autre_plus)

	var widgets = {"total_label": total_label, "objets_val": objets_val, "autre_field": autre_field}

	if key == "end":
		v.add_child(self._build_pv_formula_strip())
	elif key == "adr":
		var esquive = self._build_esquive_strip()
		v.add_child(esquive["root"])
		widgets["esquive_dice"] = esquive["dice"]
		widgets["esquive_state_label"] = esquive["state_label"]
	elif key == "chamax":
		v.add_child(self._build_cha_strip())

	self._stat_widgets[key] = widgets
	return card


func _build_pv_formula_strip() -> VBoxContainer:
	# Jamais melanger un Label autowrap avec des boutons a taille fixe dans
	# le MEME HBoxContainer : le Label ecrase alors sa largeur disponible a
	# presque zero, explose en hauteur (un mot par ligne), et etire tous
	# ses voisins avec lui (bug reel constate a l'ecran). Le texte reste
	# donc seul sur sa ligne, les controles a taille fixe sur la suivante.
	var wrap = VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 2)

	var prefix = Label.new()
	prefix.text = "PV max = Endurance × 3 + Bonus chapitres/autre"
	prefix.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prefix.add_theme_font_size_override("font_size", 10.5)
	prefix.add_theme_color_override("font_color", COL_INK_SOFT)
	wrap.add_child(prefix)

	var strip = HBoxContainer.new()
	strip.add_theme_constant_override("separation", 4)
	wrap.add_child(strip)

	var minus = self._make_step_button("−", true)
	minus.custom_minimum_size = Vector2(18, 18)
	minus.pressed.connect(self._step_pv_max_bonus.bind(-1))
	strip.add_child(minus)
	self._pv_max_bonus_field = self._make_number_field(self._set_pv_max_bonus)
	self._pv_max_bonus_field.custom_minimum_size = Vector2(28, 0)
	strip.add_child(self._pv_max_bonus_field)
	var plus = self._make_step_button("+", false)
	plus.custom_minimum_size = Vector2(18, 18)
	plus.pressed.connect(self._step_pv_max_bonus.bind(1))
	strip.add_child(plus)

	var eq = Label.new()
	eq.text = "="
	eq.add_theme_font_size_override("font_size", 10.5)
	eq.add_theme_color_override("font_color", COL_INK_SOFT)
	strip.add_child(eq)
	self._pv_max_result_label = Label.new()
	self._pv_max_result_label.add_theme_font_size_override("font_size", 11)
	self._pv_max_result_label.add_theme_color_override("font_color", COL_TEAL)
	strip.add_child(self._pv_max_result_label)

	return wrap


func _build_esquive_strip() -> Dictionary:
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)

	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	v.add_child(row)
	var state_label = Label.new()
	state_label.add_theme_font_size_override("font_size", 11)
	row.add_child(state_label)
	var dice = []
	var dice_row = HBoxContainer.new()
	dice_row.add_theme_constant_override("separation", 2)
	row.add_child(dice_row)
	for i in range(6):
		var cell = Label.new()
		cell.text = str(i + 1)
		cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.custom_minimum_size = Vector2(15, 15)
		cell.add_theme_font_size_override("font_size", 9)
		var style = StyleBoxFlat.new()
		style.set_corner_radius_all(3)
		cell.add_theme_stylebox_override("normal", style)
		dice_row.add_child(cell)
		dice.append(cell)

	var note = Label.new()
	note.text = "Un jet d'esquive de 1 déclenche en plus une contre-attaque critique (dégâts max + Critique, Armure adverse ignorée)."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 10)
	note.add_theme_color_override("font_color", COL_INK_SOFT)
	v.add_child(note)

	return {"root": v, "dice": dice, "state_label": state_label}


func _build_cha_strip() -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var minus = self._make_step_button("−", true)
	minus.pressed.connect(self._step_cha.bind(-1))
	row.add_child(minus)

	var bar_bg = Panel.new()
	bar_bg.custom_minimum_size = Vector2(0, 10)
	bar_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bar_bg_style = StyleBoxFlat.new()
	bar_bg_style.bg_color = COL_CARD_ALT
	bar_bg_style.set_corner_radius_all(5)
	bar_bg.add_theme_stylebox_override("panel", bar_bg_style)
	row.add_child(bar_bg)
	self._cha_bar_fill = ColorRect.new()
	self._cha_bar_fill.color = COL_GOLD
	self._cha_bar_fill.anchor_top = 0.0
	self._cha_bar_fill.anchor_bottom = 1.0
	self._cha_bar_fill.anchor_left = 0.0
	self._cha_bar_fill.anchor_right = 0.0
	bar_bg.add_child(self._cha_bar_fill)

	var plus = self._make_step_button("+", false)
	plus.pressed.connect(self._step_cha.bind(1))
	row.add_child(plus)

	self._cha_value_field = self._make_number_field(self._set_cha)
	row.add_child(self._cha_value_field)

	var fill_btn = Button.new()
	fill_btn.text = "Plein"
	self._style_solid_button(fill_btn, COL_GOLD, Color(1, 1, 1))
	fill_btn.pressed.connect(self._fill_cha)
	row.add_child(fill_btn)

	return row


# =============================================================================
# Rafraichissement de l'affichage
# =============================================================================

func refresh() -> void:
	var billy_type_names = {"pegu": "Pégu", "guerrier": "Guerrier", "prudent": "Prudent", "paysan": "Paysan", "debrouillard": "Débrouillard"}
	var type_name = billy_type_names.get(AppParameters.get_billy_type(), AppParameters.get_billy_type())
	self._type_badge.text = "Type de Billy : %s (choisi sur l'onglet Équipement)" % type_name

	self._resize_bar(self._pv_bar_fill, float(Player.pv) / maxf(Player.pv_max, 1))
	self._pv_value_field.text = "%d/%d" % [Player.pv, Player.pv_max]
	self._resize_bar(self._cha_bar_fill, float(Player.cha) / maxf(Player.chamax, 1))
	self._cha_value_field.text = "%d/%d" % [Player.cha, Player.chamax]
	self._pv_max_bonus_field.text = str(self._pv_max_bonus_total())
	self._pv_max_result_label.text = str(Player.pv_max)

	for stat_def in STAT_DEFS:
		var key = stat_def["key"]
		var widgets = self._stat_widgets[key]
		var total = self._total(key)
		widgets["total_label"].text = str(total)
		var objets = Player.call("get_%s_items" % key)
		widgets["objets_val"].text = ("+%d" % objets) if objets > 0 else str(objets)
		var autre = self._chapitres_autre(key)
		widgets["autre_field"].text = ("+%d" % autre) if autre > 0 else str(autre)

		if key == "adr":
			var active = total >= 2
			var chance = clampi(total, 0, 6)
			widgets["esquive_state_label"].text = "Esquive active" if active else "Esquive inactive (besoin de 2)"
			widgets["esquive_state_label"].add_theme_color_override("font_color", COL_CYAN if active else COL_CORAIL)
			for i in range(6):
				var cell = widgets["esquive_dice"][i]
				var on = i < chance
				cell.add_theme_color_override("font_color", Color(1, 1, 1) if on else COL_INK_SOFT)
				var style = cell.get_theme_stylebox("normal").duplicate()
				style.bg_color = COL_CYAN if on else COL_CARD_ALT
				cell.add_theme_stylebox_override("normal", style)


func _resize_bar(fill: ColorRect, pct: float):
	fill.anchor_right = clampf(pct, 0.0, 1.0)
