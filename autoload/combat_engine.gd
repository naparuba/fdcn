extends Node
## CombatEngine — les règles d'un affrontement, sans aucune interface.
##
## Spec complète et raisonnement dans `combat.md` (§3.10 pour l'algorithme d'un
## assaut). Les règles viennent du marque-page « table des situations », normalisé
## dans `data/combat-table.json`.
##
## POURQUOI UN AUTOLOAD ET PAS LA SCÈNE : l'état d'un combat doit survivre à un
## changement d'écran (le joueur a le droit de partir consulter son inventaire) et
## à une fermeture de l'app. La scène `screens/aventure_menu/Combat.tscn` n'est
## qu'une vue par-dessus.
##
## UN ASSAUT N'EST PAS ATOMIQUE. Il y a jusqu'à deux décisions du joueur au milieu :
##
##     roll()          -> lance le dé d'assaut, ne résout rien
##     can_reroll()    -> le DÉBROUILLARD peut relancer une fois
##     roll_dodge()    -> SECOND dé, indépendant, si l'adresse le permet
##     resolve()       -> résout avec les dés mémorisés
##
## Les dés sont injectables (`dice_roller`) : sans ça les tests seraient non
## déterministes. Ne JAMAIS appeler `Utils.roll_a_dice()` directement d'ici.
##
## PAS ENCORE FAIT (voir `combat.md` §4) : la persistance de l'état en sauvegarde
## (étape 7), le pouvoir du PRUDENT (Q14 ouverte) et les combats à plusieurs ennemis
## (fdcn ch276, étape 11).

## Émis après chaque `resolve()`, avec le rapport détaillé de l'assaut.
signal assault_resolved(rapport)
signal combat_won()
signal combat_lost()

## Adresse minimale pour tenter une esquive : « au moins 2 », donc 2 exactement suffit.
const ADRESSE_MIN_ESQUIVE := 2

## Plafond de dégâts reçus du PAYSAN.
const PAYSAN_DEGATS_MAX := 3

## Un bloc `combat` dont tous les chiffres valent ça n'est pas un ennemi mais un
## marqueur (cdsi ch256 « Mimine ») : on refuse de l'automatiser.
const SENTINELLE := 99

const _TABLE_PATH := "res://data/combat-table.json"

## Remplaçable dans les tests pour forcer les dés.
var dice_roller: Callable = func() -> int: return Utils.roll_a_dice(1, 6)

var _table := {}

# État du combat en cours. `_chapter_id` à -1 = aucun combat.
var _chapter_id := -1
var _enemy := {}
var _enemy_pv := 0
var _tour := 0
var _hab_modifier := 0

# Dés de l'assaut en cours.
var _de := 0
var _de_esquive := 0
var _a_relance := false

# Photo de l'état du joueur avant l'affrontement, pour pouvoir tout annuler.
var _snapshot := {}


func _ready() -> void:
	_table = Utils.load_json_file(_TABLE_PATH)
	if _table == null or not _table.has("assauts"):
		push_error("CombatEngine: table de combat illisible: %s" % _TABLE_PATH)
		_table = {}


#
#    Cycle de vie
#

## Les six champs du bloc `combat` du livre, en entiers (le json rend des float).
func read_enemy(chapter_id) -> Dictionary:
	var node = BookData.get_chapter_node(chapter_id)
	if node == null or not node.is_combat():
		return {}
	# Les SIX champs servent : hab et pyro font l'écart, arm réduit ce qu'on inflige,
	# deg s'ajoute à ce qu'on encaisse, pv est la barre à descendre.
	return {
		"nom": node.get_combat_name(),
		"hab": int(node.get_combat_hab()),
		"pv": int(node.get_combat_pv()),
		"arm": int(node.get_combat_armure()),
		"deg": int(node.get_combat_degat()),
		"pyro": int(node.get_combat_pyro()),
	}


## Vrai si le moteur sait mener ce combat. Faux pour un chapitre sans combat **ou**
## pour un marqueur à 99 : deux cas que l'interface doit distinguer (ne rien
## afficher / afficher la fiche en mode manuel), d'où cette fonction publique.
func is_automatable(chapter_id) -> bool:
	var enemy = read_enemy(chapter_id)
	return not enemy.is_empty() and not is_sentinelle(enemy)


## Démarre le combat du chapitre. Renvoie false si le moteur ne sait pas le mener —
## l'interface reste alors en mode manuel, elle **ne déclare jamais une défaite**
## (voir `combat.md` §3.11).
func start(chapter_id) -> bool:
	var enemy = read_enemy(chapter_id)
	if enemy.is_empty():
		return false
	if is_sentinelle(enemy):
		print('COMBAT: %s est un marqueur, pas un ennemi — mode manuel' % enemy['nom'])
		return false

	_chapter_id = int(chapter_id)
	_enemy = enemy
	_enemy_pv = enemy["pv"]
	_tour = 0
	_hab_modifier = 0
	_clear_dice()
	_snapshot = {
		"pv": PlayerStats.get_pv(),
		"cha": PlayerStats.get_cha(),
		"items": Inventory.get_possessed_items().duplicate(),
		"retour": Player.jump_to_previous_chapter(),
	}
	return true


func stop() -> void:
	_chapter_id = -1
	_enemy = {}
	_enemy_pv = 0
	_snapshot = {}
	_clear_dice()


func is_running() -> bool:
	return _chapter_id != -1


## Un ennemi dont tout est à 99 est un marqueur du livre, pas un adversaire.
func is_sentinelle(enemy: Dictionary) -> bool:
	for key in ["hab", "pv", "arm", "deg"]:
		if enemy.get(key) != SENTINELLE:
			return false
	return true


#
#    Lecture de l'état
#

func get_enemy() -> Dictionary:
	return _enemy


func get_enemy_pv() -> int:
	return _enemy_pv


func get_tour() -> int:
	return _tour


## La règle spéciale du combat, saisie à la main par le joueur (combat.md §1.2) :
## les données du livre ne la contiennent pas.
func set_hab_modifier(v: int) -> void:
	_hab_modifier = v


func get_hab_modifier() -> int:
	return _hab_modifier


## Écart brut, avant tout plafonnement — c'est celui à montrer au joueur.
## Le bonus du Pyro-Barbare s'applique dès qu'il est non nul (pas de bascule).
func get_ecart_brut() -> int:
	if not is_running():
		return 0
	return (PlayerStats.get_stat("hab") + _hab_modifier + _enemy["pyro"]) - _enemy["hab"]


## Écart réellement utilisé pour lire la table : borné au plancher de la table.
## Le plafond, lui, n'existe pas — au-delà on a déjà gagné (`is_auto_win()`).
func get_ecart() -> int:
	return maxi(get_ecart_brut(), _ecart_min())


## Vrai quand l'écart dépasse la dernière ligne de la table : victoire sans un seul dé.
func is_auto_win() -> bool:
	return is_running() and get_ecart_brut() > _ecart_max()


## Vrai quand l'écart est si mauvais qu'on lit une ligne plus favorable que la
## réalité : l'interface doit le dire, sinon ça passe pour un bug.
func is_ecart_plafonne() -> bool:
	return get_ecart_brut() < _ecart_min()


## Le nom de la situation ("Désavantage lourd", ...) pour l'écart courant.
func get_situation() -> String:
	var situation = _situation_for(get_ecart())
	return situation.get("nom", "") if situation else ""


## Coût en chance pour passer le combat, selon la situation (combat.md §3.9).
func get_fuite_cost() -> int:
	var situation = _situation_for(get_ecart())
	return int(situation.get("fuite_chance", 0)) if situation else 0


func can_fuir() -> bool:
	return is_running() and PlayerStats.get_cha() >= get_fuite_cost()


## Passer le combat en dépensant de la chance. Renvoie false si elle manque — c'est
## un cas réel : fuir un désavantage lourd coûte 5 alors que chamax démarre à 3.
func fuir() -> bool:
	if not can_fuir():
		return false
	PlayerStats.del_chance(get_fuite_cost())
	stop()
	return true


## Faux quand il n'y a pas de chapitre où revenir (premier chapitre de la partie) :
## le bouton d'annulation doit alors être grisé, pas absent.
func can_cancel() -> bool:
	return is_running() and _snapshot.get("retour", -1) != -1


## Annule tout l'affrontement : on retourne au chapitre d'avant et on repose l'état
## du joueur tel qu'il était en y arrivant.
##
## L'ORDRE COMPTE. On navigue d'abord, on restaure ensuite : `go_to_node()` traite le
## chapitre de retour comme neuf (il vient d'être dépilé du fil d'Ariane) et
## réapplique donc ses stats — dont un éventuel `max_pv` qui remettrait les pv au
## plein. La restauration doit avoir le dernier mot.
##
## Ce que ça remet exactement : pv, chance, objets portés, et la couche de stats
## « chapitres » recalculée depuis l'historique dépilé. ⚠️ Ce que ça ne remet pas :
## `visited_nodes_all_times` (volontaire — le chapitre a bien été vu une fois, c'est
## ce que suivent les succès) et les objets vus/succès obtenus au passage.
func cancel() -> bool:
	if not can_cancel():
		return false
	var retour = int(_snapshot["retour"])
	var pv = int(_snapshot["pv"])
	var cha = int(_snapshot["cha"])
	var items: Array = _snapshot["items"]
	stop()

	if not Player.jump_back(retour):
		return false
	Player.go_to_node(retour)

	# Le fil d'Ariane est plus court : la couche « chapitres » doit être refaite,
	# sinon le chapitre annulé continue de compter.
	Player.rebuild_chapter_stats()
	Inventory.restore_items(items)
	PlayerStats.set_resources(pv, cha)
	return true


#
#    Un assaut
#

## Lance le dé d'assaut et le mémorise. Ne résout rien : le joueur peut encore
## vouloir relancer (DÉBROUILLARD) ou esquiver.
func roll() -> int:
	_de = dice_roller.call()
	_de_esquive = 0
	_a_relance = false
	return _de


func get_de() -> int:
	return _de


func get_de_esquive() -> int:
	return _de_esquive


## Le DÉBROUILLARD relance une fois par assaut, et c'est son choix.
func can_reroll() -> bool:
	return _de != 0 and not _a_relance and AppParameters.get_billy_type() == "debrouillard"


func reroll() -> int:
	if not can_reroll():
		return _de
	_de = dice_roller.call()
	_a_relance = true
	return _de


func can_dodge() -> bool:
	return _de != 0 and PlayerStats.get_stat("adr") >= ADRESSE_MIN_ESQUIVE


## Second dé, indépendant de celui de l'assaut. Un échec ne coûte rien, d'où
## l'intérêt de ne le lancer qu'après avoir vu le dé d'assaut.
func roll_dodge() -> int:
	if not can_dodge():
		return 0
	_de_esquive = dice_roller.call()
	return _de_esquive


## Résout l'assaut avec les dés mémorisés et applique les dégâts. Renvoie le
## rapport détaillé (voir `combat.md` §3.1) plutôt que de peindre quoi que ce soit.
func resolve() -> Dictionary:
	var rapport = {
		"de": _de,
		"de_esquive": _de_esquive,
		"ecart": get_ecart(),
		"ecart_brut": get_ecart_brut(),
		"esquive_tentee": _de_esquive != 0,
		"esquive_reussie": false,
		"critique": false,
		"degats_infliges": 0,
		"degats_recus": 0,
		"pv_ennemi_restant": _enemy_pv,
		"coup_fatal_evite": false,
		"de_survie": 0,
		"pouvoirs": [],
	}
	if not is_running() or _de == 0:
		return rapport

	var ecart = get_ecart()
	# Les chiffres de la frise sont une BASE : les dégâts supplémentaires s'ajoutent
	# par-dessus, et l'armure se retire ensuite (combat.md §3.10 étape 5).
	var base = _cell(ecart, _de)
	var infliges = int(base[0]) + PlayerStats.get_stat("deg")
	var recus = int(base[1]) + _enemy["deg"]
	var ignore_armure = false

	if _de_esquive != 0:
		if _de_esquive == 1:
			# Contre-attaque critique : dégâts maximaux de l'écart, armure ignorée,
			# et rien d'encaissé (un 1 est forcément une esquive réussie).
			rapport["critique"] = true
			rapport["esquive_reussie"] = true
			infliges = get_max_degats(ecart) + PlayerStats.get_stat("crit")
			ignore_armure = true
			recus = 0
		elif _de_esquive <= PlayerStats.get_stat("adr"):
			# Esquive réussie : seuls les dégâts reçus sont annulés.
			rapport["esquive_reussie"] = true
			recus = 0

	if not ignore_armure:
		infliges -= _enemy["arm"]
	if recus > 0:
		recus -= PlayerStats.get_stat("arm")

	infliges = maxi(infliges, 0)
	recus = maxi(recus, 0)

	if recus > PAYSAN_DEGATS_MAX and AppParameters.get_billy_type() == "paysan":
		recus = PAYSAN_DEGATS_MAX
		rapport["pouvoirs"].append("paysan")

	# Coups simultanés : si l'ennemi tombe sur cet assaut, ses derniers dégâts ne
	# comptent pas — on l'a tué avant qu'ils ne portent. Testé AVANT le PRUDENT, pour
	# ne pas dépenser un jet de survie sur un coup qui n'arrivera jamais.
	if recus > 0 and _enemy_pv - infliges <= 0:
		recus = 0
		rapport["coup_fatal_evite"] = true

	if recus > 0 and recus >= PlayerStats.get_pv():
		recus = _test_survie_prudent(recus, rapport)

	_enemy_pv = maxi(_enemy_pv - infliges, 0)
	if recus > 0:
		PlayerStats.del_pv(recus)
	_tour += 1
	_clear_dice()

	rapport["degats_infliges"] = infliges
	rapport["degats_recus"] = recus
	rapport["pv_ennemi_restant"] = _enemy_pv

	assault_resolved.emit(rapport)
	if _enemy_pv <= 0:
		combat_won.emit()
	elif PlayerStats.get_pv() <= 0:
		combat_lost.emit()
	return rapport


## Le PRUDENT survit à un coup mortel : un lancer de dé « après la mort », réussi si le
## dé ne dépasse pas la chance courante. Renvoie les dégâts à appliquer réellement —
## survivre veut dire tomber à 1 pv, pas annuler le coup.
##
## ⚠️ Le jet ne **consomme pas** de chance : tu l'as décrit comme un simple lancer. Si
## c'était un « tentez votre chance » classique (qui décrémente), c'est ici et nulle
## part ailleurs qu'il faut ajouter `PlayerStats.del_chance(1)`.
func _test_survie_prudent(recus: int, rapport: Dictionary) -> int:
	if AppParameters.get_billy_type() != "prudent":
		return recus
	var de_survie = dice_roller.call()
	rapport["de_survie"] = de_survie
	if de_survie > PlayerStats.get_cha():
		return recus
	rapport["pouvoirs"].append("prudent")
	return PlayerStats.get_pv() - 1


#
#    Table
#

## Dégâts maximaux d'un écart : la table étant croissante en dé, c'est la valeur du
## dé 6 de la ligne. Sert à la contre-attaque critique.
func get_max_degats(ecart: int) -> int:
	return int(_cell(ecart, 6)[0])


## `[dégâts_infligés, dégâts_reçus]` de base pour un écart et un dé donnés.
func _cell(ecart: int, de: int) -> Array:
	var ligne = _table.get("assauts", {}).get(str(ecart))
	if ligne == null:
		push_error("CombatEngine: écart %s absent de la table" % ecart)
		return [0, 0]
	var cellule = ligne.get(str(de))
	if cellule == null:
		push_error("CombatEngine: dé %s absent de la ligne %s" % [de, ecart])
		return [0, 0]
	return cellule


func _situation_for(ecart: int):
	for situation in _table.get("situations", []):
		if ecart in situation.get("ecarts", []):
			return situation
	return null


func _ecart_min() -> int:
	return int(_table.get("ecart_min", -7))


func _ecart_max() -> int:
	return int(_table.get("ecart_max", 7))


func _clear_dice() -> void:
	_de = 0
	_de_esquive = 0
	_a_relance = false
