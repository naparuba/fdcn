extends Node
## CombatEngine — les règles d'un affrontement, sans aucune interface.
##
## Les règles viennent du marque-page « table des situations », normalisé
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
## PAS ENCORE FAIT : la persistance de l'état de combat en sauvegarde (fermer l'app pendant
## un affrontement le perd) et une question encore ouverte sur le pouvoir du PRUDENT — voir
## `_etape_survie_prudent()` dans `combat_assault_resolver.gd`.
##
## Les combats à plusieurs adversaires **sont** gérés : ils se mènent **dans l'ordre du
## tableau**, un adversaire à la fois. Seul fdcn ch274 s'en sert (GUARDES CORROMPUS puis
## TROLESSE).
##
## TROIS FICHIERS, UN AUTOLOAD. `resolve()` était la fonction la plus
## complexe du dépôt — ~120 lignes calculant l'assaut, les deux formes d'esquive, le plafond
## du PAYSAN, le coup fatal évité et le jet de survie du PRUDENT, tout dans un seul bloc.
## Ce fichier reste le SEUL autoload et garde tout l'état d'un combat en cours (`_enemy`,
## `_de`, `_tour`, ...) ainsi que toute l'API publique — rien de ce qui suit n'a changé pour
## `screens/aventure_menu/combat.gd`, `ui/resource_gauge.gd` ni les tests. Deux morceaux sans
## état propre en sont sortis :
##   - `CombatTable` (`autoload/combat_table.gd`) — la frise `data/combat-table.json` :
##     chargement, normalisation, lectures. Donnée statique, ne dépend d'aucun combat en cours.
##   - `CombatAssaultResolver` (`autoload/combat_assault_resolver.gd`) — le calcul d'UN
##     assaut, en étapes nommées et ordonnées. C'est là qu'ajouter un 5ᵉ pouvoir de
##     CARACTÈRE ou une 3ᵉ forme d'esquive : voir l'en-tête de ce fichier.

## Émis après chaque `resolve()`, avec le rapport détaillé de l'assaut.
signal assault_resolved(rapport)
signal combat_won()
signal combat_lost()

## Adresse minimale pour tenter une esquive : « au moins 2 », donc 2 exactement suffit.
const ADRESSE_MIN_ESQUIVE := 2

## Plafond de dégâts reçus du PAYSAN.
const PAYSAN_DEGATS_MAX := 3

## Coût en chance d'une esquive du PRUDENT.
##
## ⚠️ **Hypothèse** : 1 point par attaque esquivée. La règle dit « peut utiliser la chance
## pour esquiver une attaque » sans chiffrer le coût. Une seule constante à changer si le
## livre en demande davantage.
const PRUDENT_COUT_ESQUIVE := 1

## Un bloc `combat` dont tous les chiffres valent ça n'est pas un ennemi mais un
## marqueur (cdsi ch256 « Mimine ») : on refuse de l'automatiser.
const SENTINELLE := 99

const _TABLE_PATH := "res://data/combat-table.json"

## Remplaçable dans les tests pour forcer les dés.
var dice_roller: Callable = func() -> int: return Utils.roll_a_dice(1, 6)

var _table := CombatTable.new()
var _assault_resolver := CombatAssaultResolver.new()

# État du combat en cours. `_chapter_id` à -1 = aucun combat.
var _chapter_id := -1
## Tous les adversaires du chapitre et celui en cours. Un combat à plusieurs manches
## n'est gagné qu'une fois le dernier tombé.
var _enemies := []
var _enemy_index := 0
var _enemy := {}
var _enemy_pv := 0
var _tour := 0
var _hab_modifier := 0

# Dés de l'assaut en cours.
var _de := 0
var _de_esquive := 0
var _a_relance := false
## Le PRUDENT a payé son esquive pour cet assaut. Vrai jusqu'à la résolution.
var _esquive_chance := false



func _ready() -> void:
	if not _table.load_from(_TABLE_PATH):
		push_error("CombatEngine: table de combat illisible: %s" % _TABLE_PATH)


#
#    Cycle de vie
#

## Tous les adversaires du chapitre, en entiers (le json rend des float), **dans l'ordre où
## le livre les enchaîne**. Un chapitre n'en a normalement qu'un ; fdcn ch274 en a deux.
func read_enemies(chapter_id) -> Array:
	var node = BookData.get_chapter_node(chapter_id)
	if node == null or not node.is_combat():
		return []
	var enemies := []
	for brut in node.get_combats():
		# Les SIX champs servent : hab et pyro font l'écart, arm réduit ce qu'on inflige,
		# deg s'ajoute à ce qu'on encaisse, pv est la barre à descendre.
		enemies.append({
			"nom": brut["nom"],
			"hab": int(brut["hab"]),
			"pv": int(brut["pv"]),
			"arm": int(brut["arm"]),
			"deg": int(brut["deg"]),
			"pyro": int(brut["pyro"]),
		})
	return enemies


## Le premier adversaire, ou `{}` s'il n'y a pas de combat.
func read_enemy(chapter_id) -> Dictionary:
	var enemies = read_enemies(chapter_id)
	return enemies[0] if not enemies.is_empty() else {}


## Vrai si le moteur sait mener ce combat. Faux pour un chapitre sans combat **ou**
## pour un marqueur à 99 : deux cas que l'interface doit distinguer (ne rien
## afficher / afficher la fiche en mode manuel), d'où cette fonction publique.
func is_automatable(chapter_id) -> bool:
	var enemies = read_enemies(chapter_id)
	if enemies.is_empty():
		return false
	for enemy in enemies:
		if is_sentinelle(enemy):
			return false
	return true


## Démarre le combat du chapitre. Renvoie false si le moteur ne sait pas le mener —
## l'interface reste alors en mode manuel, elle **ne déclare jamais une défaite**.
func start(chapter_id) -> bool:
	if not is_automatable(chapter_id):
		return false

	_chapter_id = int(chapter_id)
	_enemies = read_enemies(chapter_id)
	_enemy_index = 0
	_enemy = _enemies[0]
	_enemy_pv = _enemy["pv"]
	_tour = 0
	_hab_modifier = 0
	_clear_dice()
	return true


func stop() -> void:
	_chapter_id = -1
	_enemies = []
	_enemy_index = 0
	_enemy = {}
	_enemy_pv = 0
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


## « adversaire 2 sur 2 » : l'écran doit pouvoir le dire, sinon un second ennemi qui
## surgit avec des pv pleins ressemble à un bug.
func get_enemy_index() -> int:
	return _enemy_index


func get_enemy_count() -> int:
	return _enemies.size()


func get_tour() -> int:
	return _tour


## La règle spéciale du combat, saisie à la main par le joueur : les données du livre ne
## la contiennent pas.
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
	return maxi(get_ecart_brut(), _table.ecart_min())


## Vrai quand l'écart dépasse la dernière ligne de la table : victoire sans un seul dé.
func is_auto_win() -> bool:
	return is_running() and get_ecart_brut() > _table.ecart_max()


## Vrai quand l'écart est si mauvais qu'on lit une ligne plus favorable que la
## réalité : l'interface doit le dire, sinon ça passe pour un bug.
func is_ecart_plafonne() -> bool:
	return get_ecart_brut() < _table.ecart_min()


## Le nom de la situation ("Désavantage lourd", ...) pour l'écart courant.
func get_situation() -> String:
	return get_situation_for(get_ecart())


## Publique pour pouvoir vérifier la table sans démarrer de combat.
func get_situation_for(ecart: int) -> String:
	var situation = _table.situation_for(ecart)
	return situation.get("nom", "") if situation else ""


## Coût en chance pour passer le combat, selon la situation.
func get_fuite_cost() -> int:
	var situation = _table.situation_for(get_ecart())
	return situation.get("fuite_chance", 0) if situation else 0


## ⚠️ **Réservé au PRUDENT.** « Seul lui peut esquiver les combats avec la chance » : c'est
## la moitié de son pouvoir, pas une option ouverte à tous. Les trois autres types doivent
## livrer l'affrontement (ou passer par « Gagner », l'échappatoire hors-règles).
func can_fuir() -> bool:
	if AppParameters.get_billy_type() != "prudent":
		return false
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
	return is_running() and int(Player.arrival_snapshot.get("retour", -1)) != -1


## Annule tout l'affrontement : on retourne au chapitre d'avant et on repose l'état
## du joueur tel qu'il était en y arrivant.
##
## L'ORDRE COMPTE. On navigue d'abord, on restaure ensuite : `go_to_node()` traite le
## chapitre de retour comme neuf (il vient d'être dépilé du fil d'Ariane) et
## réapplique donc ses stats — dont un éventuel `"pv": "= max"` qui remettrait les pv au
## plein. La restauration doit avoir le dernier mot.
##
## Ce que ça remet exactement : pv, chance, objets portés, et la couche de stats
## « chapitres » recalculée depuis l'historique dépilé.
##
## ⚠️ Deux limites assumées :
##  - `visited_nodes_all_times` n'est pas dépilé, volontairement : le chapitre a bien
##    été vu une fois, et c'est ce que suivent les succès et les marqueurs « déjà lu » ;
##  - les succès obtenus et les chapitres marqués « vus » au passage restent acquis.
##
## La photo vient de `Player.arrival_snapshot`, prise en tête de `go_to_node()` **avant**
## que le chapitre n'applique quoi que ce soit : les 6 chapitres de combat qui donnent
## aussi des pv (fdcn 54/58/133, cdsi 40/68/73) sont donc correctement défaits, ce qui
## n'était pas le cas quand le moteur prenait la photo lui-même sur `chapter_changed`.
func cancel() -> bool:
	if not can_cancel():
		return false
	# On copie AVANT de naviguer : `Player.go_to_node()` réécrit `arrival_snapshot`.
	var photo = Player.arrival_snapshot.duplicate(true)
	var retour = int(photo["retour"])
	var pv = int(photo["pv"])
	var cha = int(photo["cha"])
	var items: Array = photo["items"]
	stop()

	# `go_back_to()` dépile, renavigue et refait la couche « chapitres » : sans ce
	# dernier point, le chapitre annulé continuerait de compter.
	if not Player.go_back_to(retour):
		return false
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


## ⚠️ **Garde le meilleur des deux dés**, il ne remplace pas. C'est la règle : « relancer le
## dé d'attaque et garder le meilleur ». La version précédente écrasait le premier jet, ce
## qui rendait le pouvoir *risqué* au lieu d'être un avantage — relancer un 6 pouvait
## donner un 1.
##
## « Meilleur » = le plus haut, sans ambiguïté : sur les 15 écarts de la table, un dé plus
## haut donne **plus de dégâts infligés et moins de dégâts reçus** (vérifié, la table est
## monotone sur les deux colonnes).
func reroll() -> int:
	if not can_reroll():
		return _de
	var second = dice_roller.call()
	_a_relance = true
	_de = maxi(_de, second)
	return _de


## Esquive à l'ADRESSE : un second dé, ouvert à tous ceux qui ont adr ≥ 2, et qui **peut
## rater**. À ne pas confondre avec l'esquive à la chance du PRUDENT juste en dessous.
func can_dodge() -> bool:
	return _de != 0 and PlayerStats.get_stat("adr") >= ADRESSE_MIN_ESQUIVE


## L'autre moitié du pouvoir du PRUDENT : dépenser de la chance pour annuler les dégâts
## d'un assaut. Une fois par assaut.
func can_dodge_with_chance() -> bool:
	if AppParameters.get_billy_type() != "prudent":
		return false
	if not is_running() or _de == 0 or _esquive_chance:
		return false
	return PlayerStats.get_cha() >= PRUDENT_COUT_ESQUIVE


## La chance est consommée **tout de suite** : le joueur décide avant la résolution, et
## `resolve()` en tient compte. Contrairement à l'esquive à l'adresse, celle-ci ne peut
## pas échouer — c'est précisément ce qu'on paie.
func dodge_with_chance() -> bool:
	if not can_dodge_with_chance():
		return false
	PlayerStats.del_chance(PRUDENT_COUT_ESQUIVE)
	_esquive_chance = true
	return true


## Second dé, indépendant de celui de l'assaut. Un échec ne coûte rien, d'où
## l'intérêt de ne le lancer qu'après avoir vu le dé d'assaut.
func roll_dodge() -> int:
	if not can_dodge():
		return 0
	_de_esquive = dice_roller.call()
	return _de_esquive


## Résout l'assaut avec les dés mémorisés et applique les dégâts. Renvoie le
## rapport détaillé plutôt que de peindre quoi que ce soit.
##
## Le calcul lui-même — écart, esquives, armure, pouvoirs de CARACTÈRE — vit dans
## `CombatAssaultResolver` (voir l'en-tête du fichier) ; cette fonction ne fait plus que
## préparer ses entrées et appliquer son résultat à l'état du combat.
func resolve() -> Dictionary:
	var rapport = {
		"de": _de,
		"de_esquive": _de_esquive,
		"ecart": get_ecart(),
		"ecart_brut": get_ecart_brut(),
		"esquive_tentee": _de_esquive != 0,
		"esquive_reussie": false,
		"esquive_chance": false,
		"critique": false,
		"degats_infliges": 0,
		"degats_recus": 0,
		"pv_ennemi_restant": _enemy_pv,
		"ennemi_suivant": false,
		"coup_fatal_evite": false,
		"de_survie": 0,
		"pouvoirs": [],
	}
	if not is_running() or _de == 0:
		return rapport

	var ecart = get_ecart()
	var a := CombatAssaultResolver.Assaut.new()
	a.enemy = _enemy
	a.enemy_pv_avant = _enemy_pv
	a.de = _de
	a.de_esquive = _de_esquive
	a.ecart = ecart
	a.esquive_chance_payee = _esquive_chance
	a.billy_type = AppParameters.get_billy_type()
	a.dice_roller = dice_roller
	a.base = _cell(ecart, _de)
	a.max_degats_ecart = get_max_degats(ecart)
	a.rapport = rapport
	rapport = _assault_resolver.resolve(a)

	_enemy_pv = maxi(_enemy_pv - rapport["degats_infliges"], 0)
	if rapport["degats_recus"] > 0:
		PlayerStats.del_pv(rapport["degats_recus"])
	_tour += 1
	_clear_dice()

	rapport["pv_ennemi_restant"] = _enemy_pv

	# Un adversaire tombé n'est pas forcément la fin : fdcn ch274 en enchaîne deux. Le
	# suivant arrive avec ses pv pleins et le compteur de tours remis à zéro ; le combat
	# n'est gagné qu'une fois le dernier à terre, et l'écart se recalcule tout seul
	# puisqu'il est lu depuis `_enemy`.
	var reste_un_ennemi = _enemy_pv <= 0 and _enemy_index + 1 < _enemies.size()
	if reste_un_ennemi:
		_enemy_index += 1
		_enemy = _enemies[_enemy_index]
		_enemy_pv = _enemy["pv"]
		_tour = 0
		rapport["ennemi_suivant"] = true
		rapport["pv_ennemi_restant"] = _enemy_pv

	assault_resolved.emit(rapport)
	if _enemy_pv <= 0 and not reste_un_ennemi:
		combat_won.emit()
	elif PlayerStats.get_pv() <= 0:
		combat_lost.emit()
	return rapport


#
#    Table
#
# Le chargement, la normalisation et les lectures vivent dans `CombatTable`
# (`autoload/combat_table.gd`) — les deux wrappers ci-dessous ne font que le relayer, pour
# que les appelants existants (tests compris, `_cell()` est privée par convention mais un
# test a le droit de la lire) n'aient rien à changer.

## Dégâts maximaux d'un écart : la table étant croissante en dé, c'est la valeur du
## dé 6 de la ligne. Sert à la contre-attaque critique.
func get_max_degats(ecart: int) -> int:
	return _table.max_degats(ecart)


## `[dégâts_infligés, dégâts_reçus]` de base pour un écart et un dé donnés.
func _cell(ecart: int, de: int) -> Array:
	return _table.cell(ecart, de)


func _clear_dice() -> void:
	_de = 0
	_de_esquive = 0
	_a_relance = false
	_esquive_chance = false
