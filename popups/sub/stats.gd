extends Panel
## Stats view — the Billy sheet, with the base/items/chapters breakdown.
##
## Scene node naming is regular: a row `Player<X>` holds `Player<X>Value` and
## `Player<X>ValueDetail`, so the rows are driven from `_STAT_ROWS` instead of
## being spelled out one by one.
##
## Les deux RESSOURCES (pv, chance) sont sur cette même page plutôt que dans un
## onglet à part : elles y étaient déjà affichées, et les dédoubler aurait mis le
## même nombre à deux endroits. Chacune a sa jauge (`ui/ResourceGauge.tscn`) juste
## sous sa ligne, encadrée par les boutons − / +. Elles n'ont donc **pas** de label
## de valeur : c'est la jauge qui porte le « courant / max ».
##
## Les COMPTEURS propres au livre (gloire et info dans fdcn, rancune et respect dans
## cdsi) ne peuvent pas être dans la scène : leurs lignes sont construites au
## `_ready()` depuis `BookData.get_counters()`. La scène n'en garde qu'une en dur,
## `PlayerRichesse` — le seul compteur que les deux livres partagent.

## Ligne de la scène -> nom de la stat dans PlayerStats.
const _STAT_ROWS := {
	"PlayerEnd": "end",
	"PlayerHab": "hab",
	"PlayerAdr": "adr",
	"PlayerCrit": "crit",
	"PlayerDeg": "deg",
	"PlayerArm": "arm",
}

@onready var _rows = $VBoxContainer

@onready var _pv_moins: Button = $VBoxContainer/PvBlock/PvControls/Moins
@onready var _pv_plus: Button = $VBoxContainer/PvBlock/PvControls/Plus
@onready var _cha_moins: Button = $VBoxContainer/ChaBlock/ChaControls/Moins
@onready var _cha_plus: Button = $VBoxContainer/ChaBlock/ChaControls/Plus

## Clé du compteur -> le Label qui porte sa valeur. Rempli par `_build_counter_rows()`.
var _counter_values := {}


func _ready() -> void:
	# Avant le premier `_refresh()` : il a besoin des lignes pour les remplir. La
	# popup réinstancie cette scène à chaque ouverture d'onglet, donc les lignes
	# suivent toujours le livre courant, sans reconstruction à surveiller.
	_build_counter_rows()

	# `.bind(1)` explicite le pas : une paire de boutons ±5 se brancherait ici de
	# la même façon. Le bornage vit dans PlayerStats, marteler un bouton ne peut
	# pas sortir des limites.
	_pv_moins.pressed.connect(PlayerStats.del_pv.bind(1))
	_pv_plus.pressed.connect(PlayerStats.add_pv.bind(1))
	_cha_moins.pressed.connect(PlayerStats.del_chance.bind(1))
	_cha_plus.pressed.connect(PlayerStats.add_chance.bind(1))

	PlayerStats.stats_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	for row_name in _STAT_ROWS.keys():
		var stat_name = _STAT_ROWS[row_name]
		_set_row(row_name, PlayerStats.get_stat(stat_name), _detail(stat_name))

	# Les ressources n'ont pas de label de valeur (la jauge s'en charge) : on ne
	# pose que la ventilation. Celle de la chance est celle de son plafond.
	_set_detail("PlayerCha", _detail("chamax"))
	_set_detail("PlayerPv", "")

	# Compteurs cumulatifs : ils viennent des chapitres, pas des trois couches, donc
	# pas de ventilation à afficher.
	_set_row("PlayerRichesse", PlayerStats.get_richesse(), "")
	for cle in _counter_values:
		_counter_values[cle].text = "%s" % PlayerStats.get_compteur(cle)

	_refresh_buttons()


## Une ligne par compteur déclaré par le livre, à l'image de celles de la scène :
## trois colonnes de largeur égale, texte centré, la troisième vide (un compteur n'a
## pas de ventilation à montrer).
func _build_counter_rows() -> void:
	for compteur in BookData.get_counters():
		var row := HBoxContainer.new()
		row.name = "Compteur%s" % compteur["cle"]
		row.add_child(_counter_label("%s:" % compteur["libelle"]))

		var value := _counter_label("0")
		row.add_child(value)
		row.add_child(_counter_label(""))

		_rows.add_child(row)
		_counter_values[compteur["cle"]] = value


func _counter_label(txt: String) -> Label:
	var label := Label.new()
	label.text = txt
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


## Un bouton qui ne peut plus rien faire est grisé : à zéro ou au plafond, un
## bouton qui ne réagit pas passerait pour cassé.
func _refresh_buttons() -> void:
	_pv_moins.disabled = PlayerStats.get_pv() <= 0
	_pv_plus.disabled = PlayerStats.get_pv() >= PlayerStats.get_pv_max()
	_cha_moins.disabled = PlayerStats.get_cha() <= 0
	_cha_plus.disabled = PlayerStats.get_cha() >= PlayerStats.get_chance_max()


func _set_row(row_name: String, value, detail: String) -> void:
	var row = _find_row(row_name)
	if row == null:
		return
	row.get_node("%sValue" % row_name).text = "%s" % value
	row.get_node("%sValueDetail" % row_name).text = detail


func _set_detail(row_name: String, detail: String) -> void:
	var row = _find_row(row_name)
	if row == null:
		return
	row.get_node("%sValueDetail" % row_name).text = detail


## Recherche récursive : les deux lignes de ressources sont désormais imbriquées
## dans un bloc (`PvBlock`, `ChaBlock`) qui rapproche la jauge de sa ligne.
func _find_row(row_name: String) -> Node:
	var row = _rows.find_child(row_name, true, false)
	if row == null:
		push_warning("Stats: ligne introuvable dans la scène: %s" % row_name)
	return row


## "(base:2, item/billy:1, chapitres:0)" — la part de base disparaît quand la stat
## part de 0.
func _detail(stat_name: String) -> String:
	var base = PlayerStats.BASE_STATS.get(stat_name, 0)
	var parts := []
	if base > 0:
		parts.append("base:%s" % base)
	parts.append("item/billy:%s" % PlayerStats.get_stat(stat_name, PlayerStats.LAYER_ITEMS))
	parts.append("chapitres:%s" % PlayerStats.get_stat(stat_name, PlayerStats.LAYER_CHAPTERS))
	return "(%s)" % ", ".join(parts)
