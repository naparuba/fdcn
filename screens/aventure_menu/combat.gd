extends PanelContainer
## L'écran de combat : une VUE par-dessus `CombatEngine`, qui ne calcule rien.
##
## Toute règle vit dans le moteur (`autoload/combat_engine.gd`, spec dans
## `review-combat.md`). Ici on lit son état, on lui transmet les décisions du joueur, et on
## peint. La séparation est ce qui rend les règles testables sans interface.
##
## TROIS ÉTATS, un seul panneau (review-combat.md §3.6) :
##   EN_COURS  dés, esquive, journal
##   VICTOIRE  bandeau vert, dés masqués
##   DEFAITE   bandeau rouge, dés masqués — mais « gagner » RESTE cliquable, parce que
##             le moteur se trompe sur les combats à règle spéciale et que l'app ne
##             décide jamais à la place du joueur.

signal combat_finished()

enum Etat {EN_COURS, VICTOIRE, DEFAITE}

const _COULEUR_NEUTRE := Color('e9eaec')
const _COULEUR_VICTOIRE := Color('27ae60')
const _COULEUR_DEFAITE := Color('c0392b')

## Durée du roulement du dé avant qu'il ne s'arrête sur le vrai résultat.
const _ANIM_DUREE := 0.4
const _ANIM_PAS := 0.05

@onready var _nom = $VBoxContainer/Scroll/Margin/Content/NomRow/Nom
@onready var _tour_label = $VBoxContainer/Header/HeaderRow/Tour
@onready var _enemy_gauge = $VBoxContainer/Scroll/Margin/Content/EnemyGauge

# La grille est **transposée** par rapport à l'ancienne : 3 lignes de 5 colonnes au
# lieu de 5 lignes de 3. Aligné en colonnes, et trois fois moins haut. Les pv n'y
# figurent plus, les deux jauges les portent déjà.
@onready var _lui_hab = $VBoxContainer/Scroll/Margin/Content/StatsGrid/LuiHab
@onready var _lui_arm = $VBoxContainer/Scroll/Margin/Content/StatsGrid/LuiArm
@onready var _lui_deg = $VBoxContainer/Scroll/Margin/Content/StatsGrid/LuiDeg
@onready var _moi_hab = $VBoxContainer/Scroll/Margin/Content/StatsGrid/MoiHab
@onready var _moi_arm = $VBoxContainer/Scroll/Margin/Content/StatsGrid/MoiArm
@onready var _moi_deg = $VBoxContainer/Scroll/Margin/Content/StatsGrid/MoiDeg
@onready var _moi_adr = $VBoxContainer/Scroll/Margin/Content/StatsGrid/MoiAdr

@onready var _pyro_row = $VBoxContainer/Scroll/Margin/Content/NomRow/PyroRow
@onready var _pyro_hab = $VBoxContainer/Scroll/Margin/Content/NomRow/PyroRow/PyroHab

@onready var _mid_row = $VBoxContainer/Scroll/Margin/Content/MidRow
@onready var _ecart = $VBoxContainer/Scroll/Margin/Content/MidRow/EcartPanel/EcartMargin/EcartBox/EcartRow/Ecart
@onready var _situation = $VBoxContainer/Scroll/Margin/Content/MidRow/EcartPanel/EcartMargin/EcartBox/EcartRow/Situation
@onready var _detail = $VBoxContainer/Scroll/Margin/Content/MidRow/EcartPanel/EcartMargin/EcartBox/Detail
@onready var _plafonne = $VBoxContainer/Scroll/Margin/Content/MidRow/EcartPanel/EcartMargin/EcartBox/Plafonne

@onready var _banner = $VBoxContainer/Scroll/Margin/Content/Banner
@onready var _dice_sprite = $VBoxContainer/Scroll/Margin/Content/MidRow/dice/sprite
@onready var _dice_dodge = $VBoxContainer/Scroll/Margin/Content/MidRow/diceDodge
@onready var _dice_dodge_sprite = $VBoxContainer/Scroll/Margin/Content/MidRow/diceDodge/sprite

@onready var _actions_row = $VBoxContainer/Scroll/Margin/Content/ActionsRow
@onready var _lancer = $VBoxContainer/Scroll/Margin/Content/ActionsRow/Lancer
@onready var _relancer = $VBoxContainer/Scroll/Margin/Content/ActionsRow/Relancer
@onready var _esquiver = $VBoxContainer/Scroll/Margin/Content/ActionsRow/Esquiver
## Esquive à la chance du PRUDENT — masquée pour les trois autres types, comme « Relancer »
## l'est hors DÉBROUILLARD : un bouton grisé en permanence n'apprend rien.
@onready var _esquive_chance = $VBoxContainer/Scroll/Margin/Content/ActionsRow/EsquiveChance

@onready var _journal = $VBoxContainer/Scroll/Margin/Content/Journal
@onready var _val_de = $VBoxContainer/Scroll/Margin/Content/Journal/Grid/ValDe
@onready var _val_esq = $VBoxContainer/Scroll/Margin/Content/Journal/Grid/ValEsq
@onready var _val_inf = $VBoxContainer/Scroll/Margin/Content/Journal/Grid/ValInf
@onready var _val_rec = $VBoxContainer/Scroll/Margin/Content/Journal/Grid/ValRec
@onready var _journal_note = $VBoxContainer/Scroll/Margin/Content/Journal/Note
@onready var _issue_panel = $VBoxContainer/Scroll/Margin/Content/IssuePanel
@onready var _issue_label = $VBoxContainer/Scroll/Margin/Content/IssuePanel/IssueMargin/IssueLabel
@onready var _gagner = $VBoxContainer/Scroll/Margin/Content/BottomRow/Gagner
@onready var _fuir = $VBoxContainer/Scroll/Margin/Content/BottomRow/Fuir
@onready var _annuler = $VBoxContainer/Scroll/Margin/Content/BottomRow/Annuler

var _etat := Etat.EN_COURS
var _automatise := false
## Vrai pendant le roulement du dé : on refuse les clics, sinon deux animations se
## chevauchent et la face affichée n'est plus celle qui a été appliquée.
var _anime := false


func _ready() -> void:
	Player.chapter_changed.connect(_on_chapter_changed)
	PlayerStats.stats_changed.connect(_refresh_stats)

	_lancer.pressed.connect(_on_lancer)
	_relancer.pressed.connect(_on_relancer)
	_esquiver.pressed.connect(_on_esquiver)
	_esquive_chance.pressed.connect(_on_esquive_chance)
	_fuir.pressed.connect(_on_fuir)
	_annuler.pressed.connect(_on_annuler)
	_gagner.pressed.connect(_on_gagner)

	CombatEngine.combat_won.connect(func(): _set_etat(Etat.VICTOIRE))
	CombatEngine.combat_lost.connect(func(): _set_etat(Etat.DEFAITE))

	# « Gagner » ne déclare que son `normal` dans la scène : ses états de survol et
	# d'enfoncement viennent donc du thème global, en gris neutre. Sans ces deux copies,
	# survoler le bouton **effacerait le rouge de la défaite** — l'information la plus
	# importante que ce bouton porte. On duplique une fois pour toutes ; `_styler_gagner`
	# repeint ensuite les trois états d'un coup.
	var normal = _gagner.get('theme_override_styles/normal')
	if normal != null:
		for etat in ['hover', 'pressed']:
			_gagner.add_theme_stylebox_override(etat, normal.duplicate())

	_on_chapter_changed(Player.get_current_node_id())


func _on_chapter_changed(node_id) -> void:
	var node = BookData.get_chapter_node(node_id)
	if node == null or not node.is_combat():
		visible = false
		if CombatEngine.is_running():
			CombatEngine.stop()
		return

	visible = true
	# Un combat déjà en cours sur ce chapitre n'est pas redémarré : on y revient (le
	# joueur a pu aller consulter son inventaire au milieu d'un assaut).
	_automatise = CombatEngine.is_running() or CombatEngine.start(node_id)
	set_enemy(node)
	_set_etat(Etat.EN_COURS)


## ⚠️ Tout passe par `int()` : le json rend ses nombres en float, et un `'%s' % 10.0`
## affiche « 10.0 ». C'est le piège documenté du dépôt, il s'applique aussi ici.
##
## En mode automatisé la fiche vient du **moteur**, pas du chapitre : un combat peut
## enchaîner plusieurs adversaires (fdcn ch274), et c'est le moteur qui sait lequel est en
## cours. En mode manuel il n'y a pas de moteur, on retombe sur les données du chapitre.
func set_enemy(node) -> void:
	var e = CombatEngine.get_enemy() if _automatise else {
		"nom": node.get_combat_name(),
		"hab": int(node.get_combat_hab()),
		"arm": int(node.get_combat_armure()),
		"deg": int(node.get_combat_degat()),
		"pyro": int(node.get_combat_pyro()),
	}
	if e.is_empty():
		return

	_nom.text = e["nom"]
	if _automatise and CombatEngine.get_enemy_count() > 1:
		# Sans ça, un second adversaire qui surgit avec des pv pleins ressemble à un bug.
		_nom.text += "  (%d/%d)" % [CombatEngine.get_enemy_index() + 1, CombatEngine.get_enemy_count()]
	_lui_hab.text = '%d' % int(e["hab"])
	_lui_arm.text = '%d' % int(e["arm"])
	_lui_deg.text = '%d' % int(e["deg"])

	# L'icône du barbare ne s'affiche que si le livre a posé un bonus sur ce combat :
	# c'est le seul signal existant sur la présence du Pyro-Barbare, rien dans les
	# données ne suit son état par ailleurs.
	var hab_pyro = int(e["pyro"])
	_pyro_row.visible = hab_pyro != 0
	if hab_pyro != 0:
		_pyro_hab.text = '%+d' % hab_pyro


#
#    Peinture
#

func _set_etat(etat: int) -> void:
	_etat = etat
	var en_cours = etat == Etat.EN_COURS

	# Le mode manuel garde la fiche et les boutons de sortie, mais rien qui prétende
	# calculer : ni dés, ni esquive, ni écart (review-combat.md §3.11).
	_banner.visible = not _automatise
	_mid_row.visible = _automatise and en_cours
	_enemy_gauge.visible = _automatise
	_actions_row.visible = _automatise and en_cours
	_journal.visible = _automatise and en_cours

	_issue_panel.visible = not en_cours
	match etat:
		Etat.VICTOIRE:
			_peindre(_issue_panel, 'panel', _COULEUR_VICTOIRE)
			_issue_label.text = "%s est vaincu !" % _nom.text
			_styler_gagner(_COULEUR_VICTOIRE, Color(1, 1, 1))
		Etat.DEFAITE:
			_peindre(_issue_panel, 'panel', _COULEUR_DEFAITE)
			_issue_label.text = "Tu es tombé. Tu peux quand même déclarer la victoire."
			_styler_gagner(_COULEUR_DEFAITE, Color(1, 1, 1))
		_:
			_styler_gagner(_COULEUR_NEUTRE, Color(0, 0, 0))

	_refresh_stats()


## Chaque panneau a son propre StyleBox dans la scène : le recolorer n'affecte que
## lui. Un stylebox partagé aurait repeint les dés en même temps que le bouton.
func _peindre(noeud: Control, cle: String, couleur: Color) -> void:
	var style = noeud.get('theme_override_styles/%s' % cle)
	if style != null:
		style.set_bg_color(couleur)


## En défaite le bouton devient rouge mais **reste actif** : seul son style dit « mes
## calculs disent que tu es mort », jamais « tu n'as pas le droit » (review-combat.md §3.6).
func _styler_gagner(fond: Color, texte: Color) -> void:
	for etat in ['normal', 'hover', 'pressed']:
		_peindre(_gagner, etat, fond)
	for cle in ['font_color', 'font_hover_color', 'font_pressed_color']:
		_gagner.add_theme_color_override(cle, texte)


func _refresh_stats() -> void:
	if not visible:
		return
	_moi_hab.text = '%d' % PlayerStats.get_stat('hab')
	_moi_arm.text = '%d' % PlayerStats.get_stat('arm')
	_moi_deg.text = '%d' % PlayerStats.get_stat('deg')
	_moi_adr.text = '%d' % PlayerStats.get_stat('adr')

	if not _automatise:
		return

	_enemy_gauge.refresh()
	_tour_label.text = "tour %s" % (CombatEngine.get_tour() + 1)

	var brut = CombatEngine.get_ecart_brut()
	_ecart.text = "%+d" % brut
	_situation.text = CombatEngine.get_situation()
	_detail.text = "hab %d%s contre %d" % [
		PlayerStats.get_stat('hab'),
		_signe(int(CombatEngine.get_enemy().get('pyro', 0)), " pyro"),
		int(CombatEngine.get_enemy().get('hab', 0)),
	]
	_plafonne.visible = CombatEngine.is_ecart_plafonne()
	if _plafonne.visible:
		_plafonne.text = "hors table, lu sur %+d" % CombatEngine.get_ecart()

	_refresh_actions()


func _refresh_actions() -> void:
	var en_cours = _etat == Etat.EN_COURS
	# Au-delà de +7 d'écart, la victoire est acquise sans lancer un seul dé.
	var auto_win = CombatEngine.is_auto_win()
	# Le bouton principal est à deux temps : il lance, puis il valide. C'est ce qui
	# laisse la place aux deux décisions du joueur (relancer, esquiver) entre les deux.
	var de_en_attente = CombatEngine.get_de() != 0
	_lancer.disabled = _anime or auto_win
	if auto_win:
		_lancer.text = "Victoire acquise"
	elif de_en_attente:
		_lancer.text = "Valider l'assaut"
	else:
		_lancer.text = "Lancer le dé"
	_relancer.visible = CombatEngine.can_reroll() and not _anime
	_esquiver.disabled = _anime or not CombatEngine.can_dodge()
	# Deux esquives coexistent et ne se confondent pas : celle à l'ADRESSE lance un second
	# dé et peut rater ; celle du PRUDENT se paie en chance et ne rate jamais. Le coût est
	# écrit sur le bouton, comme sur « Fuir ».
	_esquive_chance.visible = CombatEngine.can_dodge_with_chance() and not _anime
	_esquive_chance.text = "Esquive (%d ch)" % CombatEngine.PRUDENT_COUT_ESQUIVE

	# Le coût en chance est écrit sur le bouton, et sa couleur vient de la scène : jaune
	# — le jaune de la jauge de chance, pour dire ce qu'on dépense — quand la fuite est
	# possible, gris sinon. C'est l'état `disabled` qui bascule les deux styleboxes,
	# rien n'est recoloré à l'exécution. Trois boutons se partagent la largeur, d'où
	# l'abréviation.
	var cout = CombatEngine.get_fuite_cost()
	_fuir.text = "Fuir (%d ch)" % cout if cout > 0 else "Fuir"
	_fuir.disabled = not en_cours or not CombatEngine.can_fuir()
	_annuler.disabled = not CombatEngine.can_cancel()


## " +2 pyro" ou "" — on ne montre un terme du calcul que s'il pèse.
func _signe(valeur: int, etiquette: String) -> String:
	if valeur == 0:
		return ""
	return " %+d%s" % [valeur, etiquette]


#
#    Actions du joueur
#

## Deux temps sur le même bouton : un dé en attente veut dire « valide », sinon
## « lance ». Sans ce second temps, un joueur qui ne veut pas esquiver n'aurait aucun
## moyen de résoudre son assaut.
func _on_lancer() -> void:
	if _anime or not _automatise or _etat != Etat.EN_COURS:
		return
	if CombatEngine.get_de() != 0:
		_resoudre()
		return
	_dice_dodge.visible = false
	await _animer_de(_dice_sprite, CombatEngine.roll(), 'b')
	_refresh_actions()


func _on_relancer() -> void:
	if _anime or not CombatEngine.can_reroll():
		return
	await _animer_de(_dice_sprite, CombatEngine.reroll(), 'b')
	_refresh_actions()


func _on_esquiver() -> void:
	if _anime or not CombatEngine.can_dodge():
		return
	_dice_dodge.visible = true
	await _animer_de(_dice_dodge_sprite, CombatEngine.roll_dodge(), 'r')
	_resoudre()


## Pas d'animation de dé ici : il n'y a pas de jet. Le PRUDENT paie, l'attaque ne porte
## pas, et l'assaut se résout immédiatement avec le dé déjà lancé.
func _on_esquive_chance() -> void:
	if _anime or not CombatEngine.can_dodge_with_chance():
		return
	CombatEngine.dodge_with_chance()
	_resoudre()


## Le dé roule pour l'œil, mais la valeur vient du moteur : l'animation n'illustre
## qu'un résultat déjà décidé, sinon la face affichée et celle appliquée divergent.
func _animer_de(sprite: TextureRect, resultat: int, couleur: String) -> void:
	_anime = true
	_refresh_actions()
	var ecoule := 0.0
	while ecoule < _ANIM_DUREE:
		sprite.texture = _face(Utils.roll_a_dice(1, 6), couleur)
		await get_tree().create_timer(_ANIM_PAS).timeout
		ecoule += _ANIM_PAS
	sprite.texture = _face(resultat, couleur)
	_anime = false


func _face(valeur: int, couleur: String) -> Texture2D:
	return Utils.load_external_texture('res://images/dice/%s-%s.svg' % [valeur, couleur])


## Un assaut se résout après l'esquive, ou directement si le joueur ne l'a pas tentée.
func _resoudre() -> void:
	var rapport = CombatEngine.resolve()
	_remplir_journal(rapport)
	if rapport['ennemi_suivant']:
		# Nouvel adversaire : la fiche entière change, pas seulement les jauges.
		set_enemy(BookData.get_chapter_node(Player.get_current_node_id()))
	if _etat == Etat.EN_COURS:
		_refresh_stats()


## Le résumé est un tableau, aux mêmes colonnes que la grille de stats : les chiffres
## de deux assauts successifs restent alignés, ce qu'une phrase ne permet pas.
##
## Ce qui n'est pas chiffrable (critique, esquive, pouvoir de CARACTÈRE) va dans la note
## en dessous, cachée quand il n'y a rien à dire. Elle ne coûte donc rien la plupart du
## temps, et signale exactement les assauts où le calcul mérite un coup d'œil.
func _remplir_journal(rapport: Dictionary) -> void:
	if rapport['de'] == 0:
		return
	_val_de.text = '%d' % rapport['de']
	_val_esq.text = '%d' % rapport['de_esquive'] if rapport['esquive_tentee'] else '-'
	_val_inf.text = '%d' % rapport['degats_infliges']
	_val_rec.text = '%d' % rapport['degats_recus']

	var notes := []
	if rapport['critique']:
		notes.append("CRITIQUE, armure ignorée")
	elif rapport['esquive_reussie']:
		notes.append("esquivé")
	if rapport['coup_fatal_evite']:
		notes.append("tué avant que son coup ne porte")
	if rapport['ennemi_suivant']:
		notes.append("adversaire suivant : %s" % CombatEngine.get_enemy().get("nom", ""))
	if rapport['esquive_chance']:
		notes.append("esquive payée en chance, PRUDENT")
	if 'paysan' in rapport['pouvoirs']:
		notes.append("plafonné à 3, PAYSAN")
	# `pouvoirs` contient « prudent » pour DEUX règles distinctes — l'esquive payée et le jet
	# de survie. `de_survie` les sépare : il ne vaut autre chose que 0 que si un dé a
	# réellement été lancé. Sans ce test, une esquive affichait « survie sur 0 ».
	if rapport['de_survie'] != 0 and 'prudent' in rapport['pouvoirs']:
		notes.append("survie sur %d, PRUDENT" % rapport['de_survie'])
	_journal_note.text = " · ".join(notes)
	_journal_note.visible = not notes.is_empty()


func _on_fuir() -> void:
	if CombatEngine.fuir():
		_terminer()


func _on_annuler() -> void:
	# `cancel()` navigue lui-même vers le chapitre d'avant, ce qui déclenche
	# `chapter_changed` : l'écran se repeindra tout seul.
	CombatEngine.cancel()


func _on_dice_pressed() -> void:
	_on_lancer()


## « Gagner » : la sortie manuelle, disponible dans les trois états — y compris en
## défaite. Voir l'en-tête de ce fichier.
func _on_gagner() -> void:
	CombatEngine.stop()
	_terminer()


func _terminer() -> void:
	visible = false
	combat_finished.emit()
