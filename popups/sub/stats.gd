extends Panel
## Stats view — the Billy sheet, with the base/items/chapters breakdown.
##
## Scene node naming is regular: a row `Player<X>` holds `Player<X>Value` and
## `Player<X>ValueDetail`, so the rows are driven from `_STAT_ROWS` instead of
## being spelled out one by one.

## Scene row node -> stat name in PlayerStats.
const _STAT_ROWS := {
	"PlayerEnd": "end",
	"PlayerHab": "hab",
	"PlayerAdr": "adr",
	"PlayerCrit": "crit",
	"PlayerDeg": "deg",
	"PlayerArm": "arm",
}

@onready var _rows = $VBoxContainer


func _ready() -> void:
	PlayerStats.stats_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	for row_name in _STAT_ROWS.keys():
		var stat_name = _STAT_ROWS[row_name]
		_set_row(row_name, PlayerStats.get_stat(stat_name), _detail(stat_name))

	# Chance shows current/max, and its breakdown is the one of chamax.
	_set_row("PlayerCha",
		"%s/%s" % [PlayerStats.get_cha(), PlayerStats.get_stat("chamax")],
		_detail("chamax"))

	# Pv is dynamic: no layers to break down.
	_set_row("PlayerPv", PlayerStats.get_pv(), "")


func _set_row(row_name: String, value, detail: String) -> void:
	var row = _rows.get_node_or_null(row_name)
	if row == null:
		push_warning("Stats: ligne introuvable dans la scène: %s" % row_name)
		return
	row.get_node("%sValue" % row_name).text = "%s" % value
	row.get_node("%sValueDetail" % row_name).text = detail


## "(base:2, item/billy:1, chapitres:0)" — the base part is dropped when the stat
## starts from 0.
func _detail(stat_name: String) -> String:
	var base = PlayerStats.BASE_STATS.get(stat_name, 0)
	var parts := []
	if base > 0:
		parts.append("base:%s" % base)
	parts.append("item/billy:%s" % PlayerStats.get_stat(stat_name, PlayerStats.LAYER_ITEMS))
	parts.append("chapitres:%s" % PlayerStats.get_stat(stat_name, PlayerStats.LAYER_CHAPTERS))
	return "(%s)" % ", ".join(parts)
