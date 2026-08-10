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
## elles ont leurs propres accesseurs et ne font pas partie de BASE_STATS. Parmi
## elles, `pv` et `cha` sont des **ressources** — bornées, sauvegardées, et hors du
## rejeu d'historique. Voir la section « Ressources ».

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

## Clés de stats de chapitre qui touchent aux RESSOURCES et non à un cumul. Le
## rejeu de l'historique les ignore : les ressources viennent de la sauvegarde,
## pas d'un recalcul. Voir la section « Ressources » plus bas.
const _CHAPTER_RESOURCE_KEYS := ["chance", "half_pv", "max_chance", "max_pv", "pv"]

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


## Plafond de la chance. `chamax` est une vraie stat en couches (base 3), au
## contraire de `pv_max` qui est dérivé de l'endurance.
func get_chance_max() -> int:
	return get_stat("chamax")


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
##
## Écrit `pv` / `cha` sans passer par leurs setters bornés, volontairement : les
## plafonds ne valent plus rien à cet instant. L'appelant doit enchaîner sur
## `recompute()` puis `fill_resources()` — c'est ce que fait `launch_new_billy()`.
func full_reset() -> void:
	reset_base()
	_reset_layer(_chapters)
	pv_max_bonus = 0
	nb_infos = 0
	gloire = 0
	richesse = 0
	cha = 0
	pv = 0


## Remet à zéro tout ce que les chapitres ont donné, pour pouvoir rejouer un
## historique sans compter en double les valeurs du rejeu précédent.
##
## Ça comprend la couche `chapters` **et** les quatre compteurs cumulatifs, qui
## viennent eux aussi exclusivement des chapitres (`apply_chapter_stat` est leur
## unique source). Les oublier rendait le rejeu non idempotent : un second
## `do_load()` — au changement de livre, par exemple — doublait la gloire, la
## richesse, le nombre d'infos et le bonus de pv max.
##
## Les ressources (`pv`, `cha`) ne sont PAS touchées ici : elles viennent de la
## sauvegarde, pas du rejeu (voir la section « Ressources »).
func reset_chapter_layer() -> void:
	_reset_layer(_chapters)
	pv_max_bonus = 0
	nb_infos = 0
	gloire = 0
	richesse = 0


#
#    Ressources (pv / chance)
#
# Les pv et la chance ne sont pas des stats mais des RESSOURCES : on les consomme.
# Trois différences de nature, qui expliquent tout ce qui suit.
#
# 1. Elles sont bornées. Toute écriture passe par `_set_pv` / `_set_chance`, qui
#    ramènent la valeur entre 0 et son plafond (`pv_max`, `get_chance_max()`).
#    Aucun autre code ne doit toucher `pv` ou `cha` directement.
# 2. Elles sont sauvegardées. Contrairement aux couches de stats, elles ne sont
#    pas redérivables de l'historique des chapitres : une perte en combat ou un
#    ajustement manuel du joueur ne se rejoue pas. Le rejoueur d'historique les
#    ignore donc (`apply_chapter_stats(id, false)`).
# 3. Trois sources les modifient, toutes via les fonctions ci-dessous : les
#    chapitres, les boutons + / − de l'onglet ressources, et un jour le combat.

func add_pv(x := 1) -> void:
	_set_pv(pv + x)


func del_pv(x := 1) -> void:
	_set_pv(pv - x)


func add_chance(x := 1) -> void:
	_set_chance(cha + x)


func del_chance(x := 1) -> void:
	_set_chance(cha - x)


func _set_pv(value: int) -> void:
	var bounded = clampi(value, 0, pv_max)
	if bounded == pv:
		return
	pv = bounded
	save_resources()
	stats_changed.emit()


func _set_chance(value: int) -> void:
	var bounded = clampi(value, 0, get_chance_max())
	if bounded == cha:
		return
	cha = bounded
	save_resources()
	stats_changed.emit()


## Repose les deux ressources d'un coup, bornées. Sert aux retours en arrière : le
## moteur de combat photographie les ressources avant l'affrontement pour pouvoir
## l'annuler (`CombatEngine.cancel()`).
func set_resources(nouveaux_pv: int, nouvelle_cha: int) -> void:
	pv = clampi(nouveaux_pv, 0, pv_max)
	cha = clampi(nouvelle_cha, 0, get_chance_max())
	save_resources()
	stats_changed.emit()


func save_resources() -> void:
	SaveManager.save_value(SaveManager.KEY_PV, pv)
	SaveManager.save_value(SaveManager.KEY_CHANCE, cha)


## Relit les ressources sauvegardées. À appeler APRÈS `recompute()` : les plafonds
## doivent être connus pour borner ce qu'on relit.
##
## Une sauvegarde qui n'a jamais enregistré ses ressources — toutes celles d'avant
## cette version — démarre **au plein** et non à zéro : c'est le seul défaut qui
## ne pénalise pas une partie en cours.
func load_resources() -> void:
	pv = clampi(int(SaveManager.load_value(SaveManager.KEY_PV, pv_max)), 0, pv_max)
	cha = clampi(int(SaveManager.load_value(SaveManager.KEY_CHANCE, get_chance_max())), 0, get_chance_max())
	stats_changed.emit()


## Ressources au maximum. Pour un Billy tout neuf, à appeler après un
## `recompute()` : sans lui les plafonds seraient encore ceux du Billy précédent.
func fill_resources() -> void:
	pv = pv_max
	cha = get_chance_max()
	save_resources()
	stats_changed.emit()


## Le plafond bouge : `pv_max` suit l'endurance, donc les objets et le type de
## Billy. Retirer une cotte de mailles peut faire descendre `pv_max` sous les pv
## courants, et on rogne alors la ressource — une jauge qui afficherait 9/6 serait
## un bug visible. C'est acceptable *parce que* l'onglet ressources permet de
## rattraper à la main. L'inverse n'est pas vrai : remonter le plafond ne soigne
## personne, c'est tout le sens d'une ressource.
func _bound_resources_to_ceilings() -> void:
	var bounded_pv = clampi(pv, 0, pv_max)
	var bounded_cha = clampi(cha, 0, get_chance_max())
	if bounded_pv == pv and bounded_cha == cha:
		return
	pv = bounded_pv
	cha = bounded_cha
	save_resources()


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
	_bound_resources_to_ceilings()
	stats_changed.emit()


## Applique un effet de stat `clé: valeur` venant d'un chapitre.
##
## `with_resources` à faux ignore les clés de ressources : c'est le mode du rejeu
## d'historique, qui reconstruit les cumuls mais ne doit surtout pas re-créditer
## les pv et la chance par-dessus la valeur sauvegardée.
func apply_chapter_stat(k: String, v, with_resources := true) -> void:
	if not with_resources and k in _CHAPTER_RESOURCE_KEYS:
		return
	if _CHAPTER_LAYERED_KEYS.has(k):
		_add_chapter_stat(_CHAPTER_LAYERED_KEYS[k], v)
		return
	if k in _CHAPTER_UNMANAGED_KEYS:
		print('apply_chapter_stat:: %s IS NOT CURRENTLY MANAGED :( )' % k)
		return
	# Le json rend tous ses nombres en float, d'où les `int()` avant les
	# ressources, qui sont des entiers bornés.
	match k:
		"chance":
			add_chance(int(v))
		"gloire":
			gloire += v
		"half_pv":
			_set_pv(pv / 2)
		"info":
			nb_infos += v
		"max_chance":
			_set_chance(get_chance_max())
		"max_pv":
			_set_pv(pv_max)
		"pv":
			add_pv(int(v))
		"pv_max":
			pv_max_bonus += v
		"richesse":
			richesse += v
		_:
			print('THE STATS KEY %s is NOT managed ' % k)


## Un chapitre vient d'être atteint : on applique ses stats (simples + sous
## condition) puis on recalcule.
##
## `with_resources` à faux pour rejouer un historique — voir `apply_chapter_stat`.
func apply_chapter_stats(node_id, with_resources := true) -> void:
	print('apply_chapter_stats:: for node: %s' % node_id)
	var all_stats = BookData.get_chapter_stats(node_id)
	for k in all_stats['stats'].keys():
		apply_chapter_stat(k, all_stats['stats'][k], with_resources)
	for stats_cond in all_stats['stats_conds']:
		for k in stats_cond.keys():
			apply_chapter_stat(k, stats_cond[k], with_resources)
	recompute()
