extends RefCounted

# Palette de couleurs + helper de style de bouton partages entre les ecrans
# construits dynamiquement (aucun Theme Godot central dans ce projet, par
# convention -- cf en-tete de CombatScreen.gd). Avant ce fichier, les memes
# valeurs de couleur et une fonction de style de bouton quasi-identique
# etaient dupliquees dans CombatScreen.gd/StatsScreen.gd/
# scenes/GenericConfirmationPopup.gd (cf PR16_RECOVERY_PLAN.md §25) --
# valeurs inchangees, seul le stockage/l'appel changent. Pas de reecriture
# vers un Theme Godot complet (101 variations cote PR16) : hors de
# proportion avec le defaut reel (duplication de constantes et d'une
# fonction), et un Theme central changerait le style par defaut de TOUS
# les Controls du projet, pas seulement ces 3 fichiers.

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


# Bouton plein (normal/pressed/hover derives de "bg" + couleur de police
# "fg") -- structure commune aux 3 ecrans, mais avec des details visuels
# distincts par ecran (rayon des coins, ombre, marges internes, taille de
# police). "opts" porte ces details ; chaque appelant garde son propre
# wrapper local `_style_solid_button(button, bg, fg)` qui fixe SES valeurs
# une seule fois plutot que de les repeter a chaque site d'appel.
static func style_solid_button(button: Button, bg: Color, fg: Color, opts: Dictionary = {}) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(opts.get("corner_radius", 10))
	if opts.has("shadow_color"):
		style.shadow_color = opts["shadow_color"]
		style.shadow_size = opts.get("shadow_size", 0)
	if opts.has("content_margin_left"):
		style.content_margin_left = opts["content_margin_left"]
		style.content_margin_right = opts.get("content_margin_right", opts["content_margin_left"])
		style.content_margin_top = opts.get("content_margin_top", 0)
		style.content_margin_bottom = opts.get("content_margin_bottom", 0)
	button.add_theme_stylebox_override("normal", style)
	var style_pressed = style.duplicate()
	style_pressed.bg_color = bg.darkened(0.15)
	button.add_theme_stylebox_override("pressed", style_pressed)
	var style_hover = style.duplicate()
	style_hover.bg_color = bg.lightened(0.08)
	button.add_theme_stylebox_override("hover", style_hover)
	button.add_theme_color_override("font_color", fg)
	if opts.has("font_size"):
		button.add_theme_font_size_override("font_size", opts["font_size"])
