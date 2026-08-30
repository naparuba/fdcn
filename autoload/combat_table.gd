class_name CombatTable
extends RefCounted
## La table des situations de combat (`data/combat-table.json`) : chargement, normalisation
## des types, et les lectures qui s'en servent. Extraite de `CombatEngine` (review-code.md
## 4.1) : c'est de la donnée statique, sans aucun état de combat en cours — rien ici ne
## change d'un assaut à l'autre, contrairement au reste de l'autoload.
##
## Instanciée par `CombatEngine` (`CombatTable.new()`), pas un autoload elle-même : rien ici
## n'a besoin d'être unique ou de survivre seul.


var _table := {}


## Faux si le fichier est illisible ou ne porte pas la clé "assauts" — à l'appelant de
## traiter ça comme une erreur fatale.
func load_from(path: String) -> bool:
	_table = Utils.load_json_file(path)
	if _table == null or not _table.has("assauts"):
		_table = {}
		return false
	_normalize()
	return true


## Le json rend TOUS ses nombres en float, et en GDScript `-2 in [-2.0]` est **faux**.
## Les listes d'écarts des situations arrivaient donc en `[-2.0, -1.0]` et aucune
## recherche par écart entier ne pouvait aboutir : plus de nom de situation, coût de
## fuite à 0, donc aucune chance consommée en fuyant. Trois symptômes, une seule cause.
##
## On convertit une fois pour toutes au chargement plutôt que de bricoler chaque
## comparaison. C'est le même piège que celui documenté dans `review.md` pour les
## identifiants de chapitre.
func _normalize() -> void:
	for situation in _table.get("situations", []):
		var entiers := []
		for ecart in situation.get("ecarts", []):
			entiers.append(int(ecart))
		situation["ecarts"] = entiers
		situation["fuite_chance"] = int(situation.get("fuite_chance", 0))

	for ligne in _table.get("assauts", {}).values():
		for de in ligne.keys():
			ligne[de] = [int(ligne[de][0]), int(ligne[de][1])]

	_table["ecart_min"] = int(_table.get("ecart_min", -7))
	_table["ecart_max"] = int(_table.get("ecart_max", 7))


## `[dégâts_infligés, dégâts_reçus]` de base pour un écart et un dé donnés.
func cell(ecart: int, de: int) -> Array:
	var ligne = _table.get("assauts", {}).get(str(ecart))
	if ligne == null:
		push_error("CombatTable: écart %s absent de la table" % ecart)
		return [0, 0]
	var cellule = ligne.get(str(de))
	if cellule == null:
		push_error("CombatTable: dé %s absent de la ligne %s" % [de, ecart])
		return [0, 0]
	return cellule


## Dégâts maximaux d'un écart : la table étant croissante en dé, c'est la valeur du
## dé 6 de la ligne. Sert à la contre-attaque critique.
func max_degats(ecart: int) -> int:
	return cell(ecart, 6)[0]


func situation_for(ecart: int):
	for situation in _table.get("situations", []):
		if ecart in situation.get("ecarts", []):
			return situation
	return null


## Les bornes de la table, converties une fois pour toutes par `_normalize()` — d'où
## l'absence d'`int()` ici comme dans les autres lectures de la table.
func ecart_min() -> int:
	return _table.get("ecart_min", -7)


func ecart_max() -> int:
	return _table.get("ecart_max", 7)
