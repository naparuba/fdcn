extends Panel

# Ecran de combat interactif -- pilote combat_screen_controller.gd (donc
# combat.gd) tour par tour. Cf SPEC_ECRAN_COMBAT.md pour les principes
# directeurs (deux des reels/un seul geste, esquive automatique, coups
# sequentiels jamais simultanes, retour en arriere libre, bouton "J'ai
# gagne" toujours disponible).
#
# Palette/police reprises de l'app existante (cf audit main.tscn -- aucun
# Theme Godot dans ce projet, tout est en Color()/StyleBoxFlat inline par
# convention) -- "on verra" a l'usage pour les teintes sans equivalent
# connu (or du critique notamment, cf SPEC #8).

const Controller = preload('res://combat_screen_controller.gd')

signal combat_termine(vainqueur)

const COL_NAVY = Color(0.192157, 0.231373, 0.278431)
const COL_PAPER = Color(0.92549, 0.929412, 0.94902)
const COL_CARD = Color(1, 1, 1)
const COL_CARD_ALT = Color(0.913725, 0.917647, 0.92549)
const COL_TEAL = Color(0, 0.760784, 0.666667)
const COL_CORAIL = Color(0.956863, 0.345098, 0.345098)
const COL_CYAN = Color(0.05, 0.6, 0.75)
const COL_GOLD = Color(0.72, 0.55, 0.09)
const COL_ORANGE = Color(0.760784, 0.447059, 0)  # #C27200, dice/evenements periodiques (SPEC #8)
const COL_INK = Color(0, 0, 0)
const COL_INK_SOFT = Color(0.45, 0.45, 0.45)

var _controller = null
var _enemy_name := ""
var _enemy_hab_base := 0
var _resolved_manually := false
var _rolling := false
# Desactive les tweens/attentes reelles (tests) -- la logique de resolution
# est strictement identique, seul le rythme visuel change.
var skip_animations := false

var _turn_label: Label
var _manual_win_button: TextureButton

var _enemy_name_label: Label
var _enemy_tags_box: VBoxContainer
var _enemy_hp_label: Label
var _enemy_hp_fill: ColorRect
var _enemy_stat_hab: Label
var _enemy_stat_arm: Label
var _enemy_stat_deg: Label
var _enemy_floaters: Control
var _enemy_card: Panel

var _player_hp_label: Label
var _player_hp_fill: ColorRect
var _player_stat_hab: Label
var _player_stat_arm: Label
var _player_stat_deg: Label
var _player_stat_adr: Label
var _player_stat_crit: Label
var _player_pyro_tag: Label
var _player_floaters: Control
var _player_card: Panel

var _turns_strip: HBoxContainer
var _last_turn_line: Label

var _preview_cells := []  # Array[Dictionary{root, give, take}], index 0 = face 1
var _attack_die_rect: TextureRect
var _esquive_die_rect: TextureRect
var _esquive_die_box: Control
var _roll_button: Button
var _roll_sub_label: Label
var _undo_button: Button

var _resolution_overlay: Panel
var _resolution_icon: TextureRect
var _resolution_title: Label
var _resolution_sub: Label


func _ready():
	self._build_ui()


# opts : armure_billy, armure_adversaire, adresse_billy, critique_billy,
# deg_billy, deg_adversaire, pyro_bonus, plafond_degats_subis_billy,
# modificateurs (Array[Modificateur]), regles_speciales (Array[String], pur
# affichage -- les tags de regle special montres sur le panneau ennemi).
func start_combat(enemy_name: String, hab_billy: int, hab_adversaire: int,
		pv_billy: int, pv_adversaire: int, opts: Dictionary = {}):
	self._enemy_name = enemy_name
	self._enemy_hab_base = hab_adversaire
	self._resolved_manually = false
	self._controller = Controller.new(hab_billy, hab_adversaire, pv_billy, pv_adversaire, opts)
	# Le "max" de la barre de Billy est son vrai PV max (peut differer de
	# pv_billy s'il entre au combat deja blesse) -- celui de l'adversaire
	# n'a pas cette ambiguite, les monstres du livre demarrent toujours au max.
	self._pv_billy_max = opts.get('pv_billy_max', pv_billy)
	self._pv_adversaire_max = pv_adversaire
	self._armure_billy = opts.get('armure_billy', 0)
	self._deg_billy = opts.get('deg_billy', 0)
	self._armure_adversaire = opts.get('armure_adversaire', 0)
	self._deg_adversaire = opts.get('deg_adversaire', 0)
	self._adresse_billy = opts.get('adresse_billy', 0)
	self._critique_billy = opts.get('critique_billy', 0)
	self._pyro_bonus = opts.get('pyro_bonus', 0)
	self._regles_speciales = opts.get('regles_speciales', [])

	self._enemy_name_label.text = enemy_name
	self._enemy_stat_arm.text = str(self._armure_adversaire)
	self._enemy_stat_deg.text = str(self._deg_adversaire)
	self._player_stat_arm.text = str(self._armure_billy)
	self._player_stat_deg.text = str(self._deg_billy)
	self._player_stat_adr.text = str(self._adresse_billy)
	self._player_stat_crit.text = str(self._critique_billy)
	self._player_pyro_tag.visible = self._pyro_bonus != 0
	if self._pyro_bonus != 0:
		self._player_pyro_tag.text = "+%s Pyro-Barbare (Habileté)" % self._pyro_bonus

	for child in self._enemy_tags_box.get_children():
		child.free()
	for regle in self._regles_speciales:
		var tag = self._make_tag_label(regle, COL_CARD_ALT, COL_INK_SOFT)
		self._enemy_tags_box.add_child(tag)

	for child in self._turns_strip.get_children():
		child.free()
	self._last_turn_line.text = "Le combat commence. Lancez le dé pour jouer le tour 1."
	self._resolution_overlay.visible = false
	self._roll_button.disabled = false
	self._esquive_die_box.visible = self._controller.peut_esquiver()
	self._set_die_face(self._attack_die_rect, 6)
	self._set_die_face(self._esquive_die_rect, 6)

	self._refresh_bars()
	self._enemy_stat_hab.text = str(self._controller.etat_courant().hab_adversaire_tour)
	self._refresh_preview()
	self._append_next_chip()
	self.visible = true


var _pv_billy_max := 0
var _pv_adversaire_max := 0
var _armure_billy := 0
var _deg_billy := 0
var _armure_adversaire := 0
var _deg_adversaire := 0
var _adresse_billy := 0
var _critique_billy := 0
var _pyro_bonus := 0
var _regles_speciales: Array = []


func is_resolved() -> bool:
	return self._resolved_manually or self._controller.is_resolved()


# =============================================================================
# Construction de l'interface (tout dynamique, cf en-tete de fichier)
# =============================================================================

func _build_ui():
	self._turn_label = self.get_node("Header/TurnLabel")
	self._manual_win_button = self.get_node("Header/ManualWinButton")
	self._manual_win_button.pressed.connect(self._on_manual_win_pressed)

	var body = self.get_node("Body")

	var layout = VBoxContainer.new()
	layout.name = "Layout"
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.add_theme_constant_override("separation", 8)
	body.add_child(layout)

	var combatants = VBoxContainer.new()
	combatants.add_theme_constant_override("separation", 6)
	layout.add_child(combatants)

	var enemy = self._build_combatant_card("Ennemi")
	self._enemy_card = enemy['card']
	self._enemy_name_label = enemy['name_label']
	self._enemy_tags_box = enemy['tags_box']
	self._enemy_hp_label = enemy['hp_label']
	self._enemy_hp_fill = enemy['hp_fill']
	self._enemy_stat_hab = enemy['stat_hab']
	self._enemy_stat_arm = enemy['stat_arm']
	self._enemy_stat_deg = enemy['stat_deg']
	self._enemy_floaters = enemy['floaters']
	combatants.add_child(enemy['card'])

	var player = self._build_combatant_card("Billy")
	self._player_card = player['card']
	self._player_hp_label = player['hp_label']
	self._player_hp_fill = player['hp_fill']
	self._player_stat_hab = player['stat_hab']
	self._player_stat_arm = player['stat_arm']
	self._player_stat_deg = player['stat_deg']
	self._player_floaters = player['floaters']
	combatants.add_child(player['card'])

	self._player_stat_adr = self._make_stat_chip(player['stats_row'], "Adresse", COL_CYAN)
	self._player_stat_crit = self._make_stat_chip(player['stats_row'], "Critique", COL_GOLD)
	self._player_pyro_tag = self._make_tag_label("", Color(0.957, 0.863, 0.733), Color(0.541, 0.298, 0))
	player['tags_box'].add_child(self._player_pyro_tag)

	var turns_wrap = VBoxContainer.new()
	turns_wrap.add_theme_constant_override("separation", 4)
	layout.add_child(turns_wrap)

	var turns_title = Label.new()
	turns_title.text = "TOURS — appuyez pour revenir avant"
	turns_title.add_theme_font_size_override("font_size", 10)
	turns_title.add_theme_color_override("font_color", COL_INK_SOFT)
	turns_wrap.add_child(turns_title)

	var turns_scroll = ScrollContainer.new()
	turns_scroll.custom_minimum_size = Vector2(0, 56)
	turns_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	turns_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	turns_wrap.add_child(turns_scroll)
	self._turns_strip = HBoxContainer.new()
	self._turns_strip.add_theme_constant_override("separation", 6)
	turns_scroll.add_child(self._turns_strip)

	self._last_turn_line = Label.new()
	self._last_turn_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	self._last_turn_line.add_theme_font_size_override("font_size", 13)
	layout.add_child(self._last_turn_line)

	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(spacer)

	var preview_wrap = VBoxContainer.new()
	preview_wrap.add_theme_constant_override("separation", 4)
	layout.add_child(preview_wrap)
	var preview_title = Label.new()
	preview_title.text = "SI VOUS N'ESQUIVEZ PAS, SELON LE DÉ D'ATTAQUE"
	preview_title.add_theme_font_size_override("font_size", 10)
	preview_title.add_theme_color_override("font_color", COL_INK_SOFT)
	preview_wrap.add_child(preview_title)
	var preview_row = HBoxContainer.new()
	preview_row.add_theme_constant_override("separation", 4)
	preview_wrap.add_child(preview_row)
	for face in range(1, 7):
		self._preview_cells.append(self._build_preview_cell(preview_row, face))

	var dice_row = HBoxContainer.new()
	dice_row.add_theme_constant_override("separation", 16)
	dice_row.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_child(dice_row)
	var attack_die_box = self._build_die_display("Attaque")
	self._attack_die_rect = attack_die_box['die']
	dice_row.add_child(attack_die_box['root'])
	var esquive_die_box = self._build_die_display("Esquive")
	self._esquive_die_rect = esquive_die_box['die']
	self._esquive_die_box = esquive_die_box['root']
	dice_row.add_child(esquive_die_box['root'])

	var action_row = HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 10)
	layout.add_child(action_row)

	self._undo_button = Button.new()
	self._undo_button.text = "↺"
	self._undo_button.custom_minimum_size = Vector2(46, 46)
	self._undo_button.disabled = true
	self._undo_button.pressed.connect(self._on_undo_pressed)
	action_row.add_child(self._undo_button)

	self._roll_button = Button.new()
	self._roll_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	self._roll_button.custom_minimum_size = Vector2(0, 52)
	self._style_solid_button(self._roll_button, COL_NAVY, Color(1, 1, 1))
	self._roll_button.pressed.connect(self._on_roll_pressed)
	action_row.add_child(self._roll_button)
	var roll_label_box = VBoxContainer.new()
	roll_label_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	roll_label_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	roll_label_box.alignment = BoxContainer.ALIGNMENT_CENTER
	self._roll_button.add_child(roll_label_box)
	var roll_title = Label.new()
	roll_title.text = "LANCER LE DÉ"
	roll_title.add_theme_font_size_override("font_size", 14)
	roll_title.add_theme_color_override("font_color", Color(1, 1, 1))
	roll_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	roll_label_box.add_child(roll_title)
	self._roll_sub_label = Label.new()
	self._roll_sub_label.text = "Tour 1"
	self._roll_sub_label.add_theme_font_size_override("font_size", 11)
	self._roll_sub_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
	self._roll_sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	roll_label_box.add_child(self._roll_sub_label)

	self._build_resolution_overlay()


func _build_combatant_card(role: String) -> Dictionary:
	var card = Panel.new()
	var style = StyleBoxFlat.new()
	style.bg_color = COL_CARD_ALT
	style.set_corner_radius_all(10)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", style)
	card.custom_minimum_size = Vector2(0, 96)

	var floaters = Control.new()
	floaters.mouse_filter = Control.MOUSE_FILTER_IGNORE
	floaters.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	floaters.clip_contents = false
	card.add_child(floaters)

	var v = VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override("separation", 4)
	card.add_child(v)

	var top_row = HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 8)
	v.add_child(top_row)

	var name_label = Label.new()
	name_label.text = role
	name_label.add_theme_font_size_override("font_size", 17)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(name_label)

	var hp_label = Label.new()
	hp_label.text = "-- / --"
	hp_label.add_theme_font_size_override("font_size", 16)
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top_row.add_child(hp_label)

	var tags_box = VBoxContainer.new()
	tags_box.add_theme_constant_override("separation", 2)
	v.add_child(tags_box)

	var bar_bg = Panel.new()
	bar_bg.custom_minimum_size = Vector2(0, 8)
	var bar_bg_style = StyleBoxFlat.new()
	bar_bg_style.bg_color = Color(0.83, 0.84, 0.86)
	bar_bg_style.set_corner_radius_all(4)
	bar_bg.add_theme_stylebox_override("panel", bar_bg_style)
	v.add_child(bar_bg)
	var hp_fill = ColorRect.new()
	hp_fill.color = COL_TEAL
	hp_fill.anchor_top = 0.0
	hp_fill.anchor_bottom = 1.0
	hp_fill.anchor_left = 0.0
	hp_fill.anchor_right = 1.0
	hp_fill.offset_left = 0
	hp_fill.offset_top = 0
	hp_fill.offset_right = 0
	hp_fill.offset_bottom = 0
	bar_bg.add_child(hp_fill)

	var stats_row = HBoxContainer.new()
	stats_row.add_theme_constant_override("separation", 6)
	v.add_child(stats_row)
	var stat_hab = self._make_stat_chip(stats_row, "Hab", COL_INK)
	var stat_arm = self._make_stat_chip(stats_row, "Armure", COL_INK)
	var stat_deg = self._make_stat_chip(stats_row, "Dégât", COL_INK)

	return {
		"card": card, "name_label": name_label, "tags_box": tags_box,
		"hp_label": hp_label, "hp_fill": hp_fill, "hp_bg": bar_bg,
		"stat_hab": stat_hab, "stat_arm": stat_arm, "stat_deg": stat_deg,
		"stats_row": stats_row, "floaters": floaters,
	}


# Chip "Label <valeur>" -- retourne le Label de la VALEUR seule (le
# libelle ne change jamais une fois cree).
func _make_stat_chip(parent: HBoxContainer, libelle: String, couleur_valeur: Color) -> Label:
	var box = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = COL_CARD
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
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", COL_INK_SOFT)
	h.add_child(l)
	var v = Label.new()
	v.text = "0"
	v.add_theme_font_size_override("font_size", 11)
	v.add_theme_color_override("font_color", couleur_valeur)
	h.add_child(v)
	return v


# Change le texte d'une stat chip (cf _make_stat_chip) en l'annonçant
# clairement si la valeur bouge -- pulse colore + delta flottant +N/-N,
# jamais un texte qui change silencieusement (meme piege que les degats
# hors-echange). Sans effet si la valeur ne change pas (rien a annoncer).
func _animate_stat_change(label: Label, nouvelle_valeur: int, floaters: Control) -> void:
	var ancienne_valeur = label.text.to_int()
	var nouveau_texte = str(nouvelle_valeur)
	if label.text == nouveau_texte:
		return
	var delta = nouvelle_valeur - ancienne_valeur
	label.text = nouveau_texte
	if self.skip_animations:
		return

	var box = label.get_parent().get_parent()
	if box is PanelContainer:
		var normal = box.get_theme_stylebox("panel").duplicate()
		var pulse = normal.duplicate()
		pulse.bg_color = (Color(0.18, 0.62, 0.39) if delta > 0 else COL_CORAIL).lightened(0.55)
		box.add_theme_stylebox_override("panel", pulse)
		var tween = create_tween()
		tween.tween_interval(0.6)
		tween.tween_callback(func(): box.add_theme_stylebox_override("panel", normal))

	var couleur = Color(0.18, 0.62, 0.39) if delta > 0 else COL_CORAIL
	self._spawn_float(floaters, ("+%d" % delta) if delta > 0 else str(delta), couleur, 15)


func _make_tag_label(txt: String, bg: Color, fg: Color) -> Label:
	var l = Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", 10)
	l.add_theme_color_override("font_color", fg)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _build_preview_cell(parent: HBoxContainer, face: int) -> Dictionary:
	var cell = PanelContainer.new()
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style = StyleBoxFlat.new()
	style.bg_color = COL_CARD_ALT
	style.set_corner_radius_all(6)
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	cell.add_theme_stylebox_override("panel", style)
	parent.add_child(cell)
	var v = VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	cell.add_child(v)
	var face_label = Label.new()
	face_label.text = str(face)
	face_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	face_label.add_theme_font_size_override("font_size", 10)
	face_label.add_theme_color_override("font_color", COL_INK_SOFT)
	v.add_child(face_label)
	var give = Label.new()
	give.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	give.add_theme_font_size_override("font_size", 11)
	give.add_theme_color_override("font_color", Color(0.18, 0.62, 0.39))
	v.add_child(give)
	var take = Label.new()
	take.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	take.add_theme_font_size_override("font_size", 11)
	take.add_theme_color_override("font_color", COL_CORAIL)
	v.add_child(take)
	return {"root": cell, "give": give, "take": take}


# Dé visuel (icone reelle du projet, res://images/dice/*.svg, modulate
# orange -- meme convention que l'ancien panneau Combat/dice). Deux
# instances : un pour le jet d'attaque, un pour le jet d'esquive --
# affiches separement, jamais un seul de qui servirait aux deux (cf
# SPEC_ECRAN_COMBAT.md #2 : deux des reels, un seul geste).
func _build_die_display(libelle: String) -> Dictionary:
	var root = VBoxContainer.new()
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	var label = Label.new()
	label.text = libelle.to_upper()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", COL_INK_SOFT)
	root.add_child(label)
	var die = TextureRect.new()
	die.custom_minimum_size = Vector2(34, 34)
	die.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	die.expand_mode = TextureRect.EXPAND_IGNORE_SIZE  # sans ca, la taille native du SVG (~550px) ecrase custom_minimum_size
	die.self_modulate = COL_ORANGE
	die.texture = load("res://images/dice/6-b.svg")
	die.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	root.add_child(die)
	return {"root": root, "die": die}


func _set_die_face(rect: TextureRect, face: int) -> void:
	rect.texture = load("res://images/dice/%d-b.svg" % face)


# "Roule" quelques faces au hasard avant de se figer sur le resultat reel
# (deja connu -- le RNG a deja eu lieu cote moteur, ceci n'est qu'une
# revelation dramatisee). skip_animations : fixe directement le resultat.
func _roll_die_animation(rect: TextureRect, final_face: int) -> void:
	if self.skip_animations:
		self._set_die_face(rect, final_face)
		return
	for i in range(5):
		self._set_die_face(rect, 1 + randi() % 6)
		await self.get_tree().create_timer(0.06).timeout
	self._set_die_face(rect, final_face)


# Surligne brievement la case de la bande de previsualisation qui
# correspondait a la face d'attaque reellement tiree.
func _flash_preview_face(face: int) -> void:
	if self.skip_animations or face < 1 or face > 6:
		return
	var cell = self._preview_cells[face - 1]['root']
	var normal = cell.get_theme_stylebox("panel").duplicate()
	var actif = normal.duplicate()
	actif.bg_color = COL_CARD
	actif.border_width_left = 2
	actif.border_width_right = 2
	actif.border_width_top = 2
	actif.border_width_bottom = 2
	actif.border_color = COL_NAVY
	cell.add_theme_stylebox_override("panel", actif)
	await self._delay(1.0)
	cell.add_theme_stylebox_override("panel", normal)


func _build_resolution_overlay():
	self._resolution_overlay = Panel.new()
	self._resolution_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	self._resolution_overlay.visible = false
	self._resolution_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.192157, 0.231373, 0.278431, 0.85)
	self._resolution_overlay.add_theme_stylebox_override("panel", bg_style)
	self.add_child(self._resolution_overlay)

	var card = PanelContainer.new()
	card.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	card.position -= Vector2(150, 90)
	card.custom_minimum_size = Vector2(300, 0)
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = COL_CARD
	card_style.set_corner_radius_all(14)
	card_style.content_margin_left = 20
	card_style.content_margin_right = 20
	card_style.content_margin_top = 20
	card_style.content_margin_bottom = 20
	card.add_theme_stylebox_override("panel", card_style)
	self._resolution_overlay.add_child(card)

	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	card.add_child(v)

	self._resolution_icon = TextureRect.new()
	self._resolution_icon.custom_minimum_size = Vector2(36, 36)
	self._resolution_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	self._resolution_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	self._resolution_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(self._resolution_icon)

	self._resolution_title = Label.new()
	self._resolution_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	self._resolution_title.add_theme_font_size_override("font_size", 20)
	v.add_child(self._resolution_title)

	self._resolution_sub = Label.new()
	self._resolution_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	self._resolution_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	self._resolution_sub.add_theme_font_size_override("font_size", 12)
	self._resolution_sub.add_theme_color_override("font_color", COL_INK_SOFT)
	v.add_child(self._resolution_sub)

	var cta = Button.new()
	cta.text = "CONTINUER L'AVENTURE"
	cta.custom_minimum_size = Vector2(0, 40)
	self._style_solid_button(cta, COL_NAVY, Color(1, 1, 1))
	cta.pressed.connect(func(): self._resolution_overlay.visible = false)
	v.add_child(cta)

	var secondary = Button.new()
	secondary.text = "Revenir en arrière"
	secondary.flat = true
	secondary.pressed.connect(self._on_resolution_rewind_pressed)
	v.add_child(secondary)


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


# =============================================================================
# Rafraichissement de l'affichage
# =============================================================================

func _refresh_bars():
	var etat = self._controller.etat_courant()
	self._turn_label.text = "TOUR %d" % self._controller.prochain_tour()
	self._roll_sub_label.text = "Tour %d" % self._controller.prochain_tour()
	self._enemy_hp_label.text = "%d / %d" % [maxi(etat.adversaire.pv, 0), self._pv_adversaire_max]
	self._player_hp_label.text = "%d / %d" % [maxi(etat.billy.pv, 0), self._pv_billy_max]
	# La stat Habileté ennemie n'est PAS mise a jour ici : elle est soit
	# figee directement (initialisation, retour en arriere -- rien a
	# annoncer), soit animee explicitement dans _play_turn() (cf
	# _animate_stat_change) -- jamais les deux en meme temps, sinon le
	# texte est deja identique quand l'animation verifie s'il a change.
	self._resize_bar(self._enemy_hp_fill, float(maxi(etat.adversaire.pv, 0)) / maxf(self._pv_adversaire_max, 1))
	self._resize_bar(self._player_hp_fill, float(maxi(etat.billy.pv, 0)) / maxf(self._pv_billy_max, 1))
	self._undo_button.disabled = !self._controller.peut_annuler()


func _resize_bar(fill: ColorRect, pct: float):
	# Ancre plutot que taille en pixels : correct immediatement, sans
	# dependre du moment ou le Container parent a fini de se redimensionner.
	fill.anchor_right = clampf(pct, 0.0, 1.0)


func _refresh_preview():
	for face in range(1, 7):
		var p = self._controller.previsualisation(face)
		var cell = self._preview_cells[face - 1]
		cell['give'].text = "+%d" % p['dmg_ennemi']
		cell['take'].text = "-%d" % p['dmg_billy']


func _append_next_chip():
	if self.is_resolved():
		return
	var chip = PanelContainer.new()
	chip.name = "NextChip"
	chip.custom_minimum_size = Vector2(46, 0)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.7, 0.7, 0.7)
	style.set_corner_radius_all(8)
	chip.add_theme_stylebox_override("panel", style)
	var l = Label.new()
	l.text = "%d\n?" % self._controller.prochain_tour()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", COL_INK_SOFT)
	chip.add_child(l)
	self._turns_strip.add_child(chip)


func _remove_next_chip():
	var existing = self._turns_strip.get_node_or_null("NextChip")
	if existing:
		existing.free()


func _outcome_couleur(entry: Dictionary) -> Color:
	if entry.get('crit', false):
		return COL_GOLD
	if entry.get('esquive', false):
		return COL_CYAN
	var give = entry.get('dmg_ennemi', 0)
	var take = entry.get('dmg_billy', 0)
	if give > 0 and take == 0:
		return Color(0.18, 0.62, 0.39)
	if take > 0 and give == 0:
		return COL_CORAIL
	if give == 0 and take == 0:
		return COL_INK_SOFT
	return Color(0.68, 0.42, 0.02)


func _push_turn_chip(entry: Dictionary):
	self._remove_next_chip()
	var chip = PanelContainer.new()
	chip.custom_minimum_size = Vector2(46, 0)
	var style = StyleBoxFlat.new()
	style.bg_color = COL_CARD_ALT
	style.set_corner_radius_all(8)
	chip.add_theme_stylebox_override("panel", style)
	chip.tooltip_text = "Revenir avant le tour %d" % entry['tour']
	var btn = Button.new()
	btn.flat = true
	btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	btn.pressed.connect(self._on_turn_chip_pressed.bind(entry['tour']))
	chip.add_child(btn)
	var v = VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	chip.add_child(v)
	var num = Label.new()
	num.text = str(entry['tour'])
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.add_theme_font_size_override("font_size", 10)
	num.add_theme_color_override("font_color", COL_INK_SOFT)
	v.add_child(num)
	var dot = ColorRect.new()
	dot.custom_minimum_size = Vector2(10, 10)
	dot.color = self._outcome_couleur(entry)
	dot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(dot)
	var hp = Label.new()
	hp.text = "%d·%d" % [maxi(entry['pv_billy'], 0), maxi(entry['pv_adversaire'], 0)]
	hp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp.add_theme_font_size_override("font_size", 10)
	v.add_child(hp)
	self._turns_strip.add_child(chip)
	self._append_next_chip()
	await self.get_tree().process_frame
	var scroll = self._turns_strip.get_parent()
	if scroll is ScrollContainer:
		scroll.scroll_horizontal = int(self._turns_strip.size.x)


func _update_last_turn_line(entry: Dictionary):
	var texte = "Tour %d — dé %d" % [entry['tour'], entry['face']]
	if entry.get('esquive', false):
		texte += " — Esquive ! l'ennemi vous rate entièrement."
		if entry.get('crit', false):
			texte += " Contre-attaque critique : -%d." % entry['dmg_ennemi']
	else:
		texte += " — Billy inflige -%d, subit -%d." % [entry['dmg_ennemi'], entry['dmg_billy']]
	if entry.get('effet_ennemi', 0) > 0:
		texte += " + effet spécial : -%d à l'ennemi." % entry['effet_ennemi']
	if entry.get('effet_billy', 0) > 0:
		texte += " + effet spécial : -%d à Billy." % entry['effet_billy']
	self._last_turn_line.text = texte


# =============================================================================
# Interaction
# =============================================================================

func _on_roll_pressed():
	await self._play_turn()


# Extrait de _on_roll_pressed pour permettre des tests de scenario complets
# et reproductibles (forcer attack_die/esquive_die) -- memes parametres que
# combat.gd::play_turn(), null = de reel/aleatoire (comportement du bouton).
func _play_turn(attack_die = null, esquive_die = null):
	if self._rolling or self.is_resolved():
		return null
	self._rolling = true
	self._roll_button.disabled = true

	var nouveau_tour = self._controller.jouer_tour(attack_die, esquive_die)
	if nouveau_tour == null:
		self._rolling = false
		return null

	await self._roll_die_animation(self._attack_die_rect, nouveau_tour.attack_die_roll)
	if nouveau_tour.esquive_die_roll != null:
		await self._roll_die_animation(self._esquive_die_rect, nouveau_tour.esquive_die_roll)
	self._flash_preview_face(nouveau_tour.attack_die_roll)

	if nouveau_tour.esquive:
		await self._lunge(self._enemy_card, Vector2(0, 18))
		if nouveau_tour.contre_attaque_critique:
			self._spawn_float(self._player_floaters, "CRITIQUE !", COL_GOLD, 20)
			await self._delay(0.3)
			await self._lunge(self._player_card, Vector2(0, -18))
			self._hit_panel(self._enemy_card, nouveau_tour.degats_billy)
			self._spawn_float(self._enemy_floaters, "-%d" % nouveau_tour.degats_billy, COL_GOLD, 20 + nouveau_tour.degats_billy * 4)
		else:
			self._spawn_float(self._player_floaters, "ESQUIVE !", COL_CYAN, 18)
	else:
		await self._lunge(self._player_card, Vector2(0, -18))
		if nouveau_tour.degats_billy > 0:
			self._hit_panel(self._enemy_card, nouveau_tour.degats_billy)
			self._spawn_float(self._enemy_floaters, "-%d" % nouveau_tour.degats_billy, COL_CORAIL, 18 + nouveau_tour.degats_billy * 4)
		else:
			self._spawn_float(self._enemy_floaters, "0", COL_INK_SOFT, 14)
		await self._delay(0.3)
		await self._lunge(self._enemy_card, Vector2(0, 18))
		if nouveau_tour.degats_adversaire > 0:
			self._hit_panel(self._player_card, nouveau_tour.degats_adversaire)
			self._spawn_float(self._player_floaters, "-%d" % nouveau_tour.degats_adversaire, COL_CORAIL, 18 + nouveau_tour.degats_adversaire * 4)
		else:
			self._spawn_float(self._player_floaters, "0", COL_INK_SOFT, 14)

	# Troisieme temps, hors de l'echange normal (DegatsPeriodiques,
	# AttaquePosthume...) -- jamais porte par un bond, ce n'est pas un
	# combattant qui attaque. Sans ca, un PV qui bouge sans explication
	# ressemble a un bug (meme piege que "l'ennemi n'attaque pas ce tour").
	if nouveau_tour.degats_supplementaires_billy > 0 or nouveau_tour.degats_supplementaires_adversaire > 0:
		await self._delay(0.3)
		if nouveau_tour.degats_supplementaires_billy > 0:
			self._hit_panel(self._enemy_card, nouveau_tour.degats_supplementaires_billy)
			self._spawn_float(self._enemy_floaters, "Effet -%d" % nouveau_tour.degats_supplementaires_billy,
				COL_ORANGE, 16 + nouveau_tour.degats_supplementaires_billy * 4)
		if nouveau_tour.degats_supplementaires_adversaire > 0:
			self._hit_panel(self._player_card, nouveau_tour.degats_supplementaires_adversaire)
			self._spawn_float(self._player_floaters, "Effet -%d" % nouveau_tour.degats_supplementaires_adversaire,
				COL_ORANGE, 16 + nouveau_tour.degats_supplementaires_adversaire * 4)

	self._refresh_bars()
	self._animate_stat_change(self._enemy_stat_hab, nouveau_tour.hab_adversaire_tour, self._enemy_floaters)
	self._refresh_preview()

	var entry = {
		"tour": nouveau_tour.tour, "face": nouveau_tour.attack_die_roll,
		"dmg_ennemi": nouveau_tour.degats_billy, "dmg_billy": nouveau_tour.degats_adversaire,
		"esquive": nouveau_tour.esquive, "crit": nouveau_tour.contre_attaque_critique,
		"effet_ennemi": nouveau_tour.degats_supplementaires_billy,
		"effet_billy": nouveau_tour.degats_supplementaires_adversaire,
		"pv_billy": self._controller.etat_courant().billy.pv,
		"pv_adversaire": self._controller.etat_courant().adversaire.pv,
	}
	self._push_turn_chip(entry)
	self._update_last_turn_line(entry)

	self._rolling = false
	self._roll_button.disabled = self.is_resolved()
	if self._controller.is_resolved():
		self._show_resolution(self._controller.get_winner() == "billy", false)
	return nouveau_tour


func _on_undo_pressed():
	if !self._controller.peut_annuler():
		return
	var dernier = self._controller.annuler_dernier_tour()
	self._remove_turn_chip(dernier.tour)
	self._resolved_manually = false
	self._resolution_overlay.visible = false
	self._refresh_bars()
	self._enemy_stat_hab.text = str(self._controller.etat_courant().hab_adversaire_tour)
	self._refresh_preview()
	self._roll_button.disabled = false


func _remove_turn_chip(numero_tour: int):
	# Les tuiles sont ajoutees dans l'ordre des tours -- la derniere tuile
	# NON "next" correspond toujours au tour le plus recent.
	for i in range(self._turns_strip.get_child_count() - 1, -1, -1):
		var chip = self._turns_strip.get_child(i)
		if chip.name != "NextChip":
			chip.free()
			break
	self._append_next_chip()


func _on_turn_chip_pressed(numero_tour: int):
	self._controller.revenir_avant_tour(numero_tour)
	for i in range(self._turns_strip.get_child_count() - 1, -1, -1):
		var chip = self._turns_strip.get_child(i)
		if chip.name == "NextChip":
			continue
		chip.free()
	self._append_next_chip()
	self._resolved_manually = false
	self._resolution_overlay.visible = false
	self._refresh_bars()
	self._enemy_stat_hab.text = str(self._controller.etat_courant().hab_adversaire_tour)
	self._refresh_preview()
	self._roll_button.disabled = false
	self._last_turn_line.text = "Retour effectué — rejouez le tour %d quand vous êtes prêt." % self._controller.prochain_tour()


# Bouton "J'ai gagne" (icone coche, cf Combat/IWin dans l'ancien panneau) :
# le vainqueur final est toujours decide par le livre (le joueur choisit le
# bon paragraphe suivant), jamais par les PV simules ici -- disponible a
# tout moment, meme avant le premier tour joue (cf SPEC_ECRAN_COMBAT.md #7).
func _on_manual_win_pressed():
	if self.is_resolved():
		return
	self._resolved_manually = true
	self._roll_button.disabled = true
	self._show_resolution(true, true)


func _on_resolution_rewind_pressed():
	self._resolution_overlay.visible = false
	if self._controller.peut_annuler():
		self._on_undo_pressed()
	else:
		self._resolved_manually = false
		self._roll_button.disabled = false


func _show_resolution(gagne: bool, manuel: bool):
	self._resolution_icon.visible = gagne
	if gagne:
		self._resolution_icon.texture = load("res://images/tick.png")
	self._resolution_title.text = "Victoire" if gagne else "Défaite"
	self._resolution_title.add_theme_color_override("font_color", Color(0.18, 0.62, 0.39) if gagne else COL_CORAIL)
	if manuel:
		self._resolution_sub.text = "Combat terminé à la main — c'est le livre qui décide, pas les PV affichés ici."
	elif gagne:
		self._resolution_sub.text = "%s est vaincu. La suite du chapitre s'ouvre." % self._enemy_name
	else:
		self._resolution_sub.text = "Billy s'effondre. Vous pouvez encore revenir en arrière si un jet ne vous a pas plu."
	self._resolution_overlay.visible = true
	self.combat_termine.emit("billy" if gagne else "adversaire")


# =============================================================================
# Animations
# =============================================================================

func _delay(seconds: float) -> void:
	if self.skip_animations:
		return
	await self.get_tree().create_timer(seconds).timeout


func _lunge(panel: Control, offset: Vector2) -> void:
	if self.skip_animations:
		return
	var origine = panel.position
	var tween = create_tween()
	tween.tween_property(panel, "position", origine + offset, 0.16).set_trans(Tween.TRANS_SINE)
	tween.tween_property(panel, "position", origine, 0.18).set_trans(Tween.TRANS_SINE)
	await tween.finished


func _hit_panel(panel: Control, magnitude: int) -> void:
	if self.skip_animations or magnitude <= 0:
		return
	var amp = mini(4 + magnitude * 3, 22)
	var origine = panel.position
	var tween = create_tween()
	tween.tween_property(panel, "position", origine + Vector2(-amp, 0), 0.05)
	tween.tween_property(panel, "position", origine + Vector2(amp * 0.7, 0), 0.05)
	tween.tween_property(panel, "position", origine + Vector2(-amp * 0.4, 0), 0.05)
	tween.tween_property(panel, "position", origine, 0.05)
	var style = panel.get_theme_stylebox("panel")
	if style is StyleBoxFlat:
		var original = style.duplicate()
		var flash = style.duplicate()
		flash.bg_color = Color(0.956863, 0.345098, 0.345098, 0.35)
		panel.add_theme_stylebox_override("panel", flash)
		var restore = create_tween()
		restore.tween_interval(0.05)
		restore.tween_callback(func(): panel.add_theme_stylebox_override("panel", original))


func _spawn_float(container: Control, texte: String, couleur: Color, taille: int) -> void:
	var l = Label.new()
	l.text = texte
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_color", couleur)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	l.anchor_left = 0.5
	l.anchor_right = 0.5
	container.add_child(l)
	l.position = Vector2(-l.size.x / 2.0, 0)
	if self.skip_animations:
		l.queue_free()
		return
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(l, "position:y", -40.0, 0.9).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.3)
	tween.set_parallel(false)
	tween.tween_callback(l.queue_free)
