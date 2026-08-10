extends Node
## PlayerStats — le moteur de statistiques du Billy.
##
## Sept stats (end/adr/hab/chamax/deg/arm/crit) sont suivies en trois couches
## additives, pour que la popup des stats puisse montrer d'où vient un chiffre :
##
##   base      ce avec quoi tout Billy démarre        (BASE_STATS)
##   items     les modificateurs du type de Billy + les objets portés
##   chapters  ce que les chapitres visités ont donné définitivement
##
## `get_stat(nom)` renvoie base+items+chapters. `get_stat(nom, LAYER_ITEMS)`
## renvoie une seule couche. Toute nouvelle source de stat DOIT passer par un des
## helpers `_add_*_stat()`, sinon les trois couches se désynchronisent.
##
## Quelques valeurs sont dynamiques plutôt qu'en couches (pv, cha, gloire, ...) :
## elles ont leurs propres accesseurs et ne font pas partie de BASE_STATS.

signal stats_changed

const LAYER_TOTAL := "total"
const LAYER_ITEMS := "items"
const LAYER_CHAPTERS := "chapters"

## Les sept stats en couches, et la valeur de départ de tout Billy.
const BASE_STATS := {
	"end": 2,
	"adr": 1,
	"hab": 2,
	"chamax": 3,
	"deg": 0,
	"arm": 0,
	"crit": 0,
}

## Modificateurs par type de Billy, appliqués dans la couche `items`.
const BILLY_MODIFIERS := {
	"guerrier": {"hab": 2, "chamax": -1, "deg": 1},
	"prudent": {"hab": -1, "chamax": 2},
	"paysan": {"adr": -1, "end": 2},
	"debrouillard": {"adr": 2, "end": -1},
	"pegu": {},
}

## Le json des objets dit `cha` là où la stat s'appelle en fait `chamax`.
const ITEM_STAT_ALIASES := {"cha": "chamax"}

## Clés de stats de chapitre qui alimentent la couche `chapters` : clé json -> stat.
const _CHAPTER_LAYERED_KEYS := {
	"adr": "adr",
	"arm": "arm",
	"chance_max": "chamax",
	"crit": "crit",
	"deg": "deg",
	"end": "end",
	"hab": "hab",
}

## Clés de stats de chapitre connues mais pas encore implémentées (review #25).
const _CHAPTER_UNMANAGED_KEYS := ["1_4_pv_max", "arc_et_couteau", "pv_1_4_max", "pv_win_plus_1"]

var _total := {}
var _items := {}
var _chapters := {}

# Valeurs dynamiques — pas en couches.
var pv := 0
var pv_max := 0
var pv_max_bonus := 0
var cha := 0
var gloire := 0
var richesse := 0
var nb_infos := 0


func _init() -> void:
	full_reset()


#
#    Lecture
#

## `layer` vaut LAYER_TOTAL (défaut) / LAYER_ITEMS / LAYER_CHAPTERS.
func get_stat(stat_name: String, layer := LAYER_TOTAL) -> int:
	match layer:
		LAYER_ITEMS:
			return _items.get(stat_name, 0)
		LAYER_CHAPTERS:
			return _chapters.get(stat_name, 0)
		_:
			return _total.get(stat_name, 0)


func get_pv() -> int:
	return pv

func get_pv_max() -> int:
	return pv_max

func get_cha() -> int:
	return cha

func get_gloire() -> int:
	return gloire

func get_richesse() -> int:
	return richesse

func get_nb_infos() -> int:
	return nb_infos


#
#    Remises à zéro
#

func _reset_layer(layer: Dictionary, defaults := {}) -> void:
	for k in BASE_STATS.keys():
		layer[k] = defaults.get(k, 0)


## Remet base + items à zéro. Chaque recompute() part de là ; la couche
## `chapters` est conservée car elle représente des gains définitifs.
func reset_base() -> void:
	_reset_layer(_total, BASE_STATS)
	_reset_layer(_items)


## Remet absolument tout à zéro, y compris les gains de chapitres et les
## valeurs dynamiques. Utilisé au démarrage d'un tout nouveau Billy.
func full_reset() -> void:
	reset_base()
	_reset_layer(_chapters)
	pv_max_bonus = 0
	nb_infos = 0
	gloire = 0
	richesse = 0
	cha = 0
	pv = 0


## Remet à zéro la seule couche `chapters`, pour pouvoir rejouer un historique
## de chapitres sans compter en double les valeurs du rejeu précédent.
func reset_chapter_layer() -> void:
	_reset_layer(_chapters)


#
#    Écriture
#

func _add_item_stat(stat_name: String, v) -> void:
	if not _total.has(stat_name):
		print('ERROR: STATS INCONNUE DANS OBJET: %s' % stat_name)
		return
	_total[stat_name] += v
	_items[stat_name] += v


func _add_chapter_stat(stat_name: String, v) -> void:
	_chapters[stat_name] = _chapters.get(stat_name, 0) + v


func _apply_billy_modifiers() -> void:
	var billy_type = AppParameters.get_billy_type()
	if not BILLY_MODIFIERS.has(billy_type):
		print('ERROR: the billy type: %s is unknown' % billy_type)
		return
	var modifiers = BILLY_MODIFIERS[billy_type]
	for stat_name in modifiers.keys():
		_add_item_stat(stat_name, modifiers[stat_name])


## Recalcul complet : base -> modificateurs du Billy -> objets portés -> couche chapitres.
func recompute() -> void:
	reset_base()
	_apply_billy_modifiers()

	for item_name in Inventory.get_possessed_items():
		var item_data = BookData.get_item_data(item_name)
		var stats = item_data.get('stats', {})
		for k in stats.keys():
			_add_item_stat(ITEM_STAT_ALIASES.get(k, k), stats[k])

	# Les gains de chapitres se posent par-dessus base+items.
	for stat_name in BASE_STATS.keys():
		_total[stat_name] += _chapters[stat_name]

	pv_max = _total["end"] * 3 + pv_max_bonus
	stats_changed.emit()


## Applique un effet de stat `clé: valeur` venant d'un chapitre.
func apply_chapter_stat(k: String, v) -> void:
	if _CHAPTER_LAYERED_KEYS.has(k):
		_add_chapter_stat(_CHAPTER_LAYERED_KEYS[k], v)
		return
	if k in _CHAPTER_UNMANAGED_KEYS:
		print('apply_chapter_stat:: %s IS NOT CURRENTLY MANAGED :( )' % k)
		return
	match k:
		"chance":
			cha += v  # TODO(review #25): à plafonner à chamax
		"gloire":
			gloire += v
		"half_pv":
			pv /= 2
		"info":
			nb_infos += v
		"max_chance":
			cha = get_stat("chamax")
		"max_pv":
			pv = pv_max
		"pv":
			pv += v  # TODO(review #25): à plafonner entre 0 et pv_max
		"pv_max":
			pv_max_bonus += v
		"richesse":
			richesse += v
		_:
			print('THE STATS KEY %s is NOT managed ' % k)


## Un chapitre vient d'être atteint : on applique ses stats (simples + sous
## condition) puis on recalcule.
func apply_chapter_stats(node_id) -> void:
	print('apply_chapter_stats:: for node: %s' % node_id)
	var all_stats = BookData.get_chapter_stats(node_id)
	for k in all_stats['stats'].keys():
		apply_chapter_stat(k, all_stats['stats'][k])
	for stats_cond in all_stats['stats_conds']:
		for k in stats_cond.keys():
			apply_chapter_stat(k, stats_cond[k])
	recompute()
