extends Node

# Autoload : charge la Table des Situations depuis combat-table.json (un seul
# fichier a auditer/corriger, plutot que les 3 constantes GDScript eparpillees
# qu'etait combat.gd avant (cf PR16_RECOVERY_PLAN.md §5) -- valeurs
# numeriques inchangees, seul le stockage change. combat.gd reste le seul
# consommateur (get_pair/get_tier_name/get_fuite_cost, appeles depuis ses
# fonctions statiques resolve_round/get_tier_name/get_fuite_cost).

# Cle = diff brute (int, -7..7, DEJA plafonnee par combat.gd::clamp_diff --
# cet autoload ne clampe jamais lui-meme). Valeur = Array de 6 paires
# [degats_billy, degats_adversaire], index 0 = jet de 1.
var _table_by_diff := {}
var _tier_by_diff := {}
var _fuite_cost_by_diff := {}


func _ready():
	self._load()


func _load():
	var data = Utils.load_json_file("res://combat-table.json")
	for situation in data["situations"]:
		var diff = situation["diff"]
		self._table_by_diff[diff] = situation["table"]
		self._tier_by_diff[diff] = situation["tier"]
		self._fuite_cost_by_diff[diff] = situation["fuite_cost"]


func get_pair(diff: int, die_roll: int) -> Array:
	assert(die_roll >= 1 and die_roll <= 6, "die_roll doit etre entre 1 et 6")
	return self._table_by_diff[diff][die_roll - 1]


func get_tier_name(diff: int) -> String:
	return self._tier_by_diff[diff]


func get_fuite_cost(diff: int) -> int:
	return self._fuite_cost_by_diff[diff]
