extends RefCounted

# Composant de resolution de combat, base sur la "Table des Situations"
# officielle du livre-jeu (fiche PDF/PNG fournie par l'auteur, cf
# https://saga-de-billy.fandom.com/fr/wiki/Fichier:SDB_Table_des_Situations.png
# -- transcrite et verifiee chiffre par chiffre le 2026-07-10).
#
# Principe (cf https://saga-de-billy.fandom.com/fr/wiki/FDCN/FAQ) : chaque
# tour on lance 1d6, on regarde la colonne correspondant a la difference
# d'HABILETE (Billy - adversaire, plafonnee a [-7, 7] -- le livre ne
# documente rien au-dela), et la cellule donne les degats causes par Billy
# et par l'adversaire ce tour-la. On repete jusqu'a ce qu'un des deux PV
# tombe a 0 (cf la "Feuille de Combat" officielle, qui suit PV/Billy/Adv.
# tour par tour de la meme maniere).
#
# CE QUI N'EST PAS ENCORE COUVERT ICI (pas de source texte fiable, cf le
# Guide detaille qui les mentionne seulement en prose sans formule
# chiffree) : application de l'ARMURE, des DEGATS/CRITIQUE bonus
# d'equipement, de l'Esquive, du reduction de degats du PAYSAN (max 3 PV/
# tour), du bonus du Pyro-Barbare sur l'Habileté, ou de la regle spatiale
# DOMINATION evoquee par les joueurs (elle ne correspond a aucune case
# specifique de cette table -- c'est le nom fan pour l'Avantage Lourd
# extreme, diff >= 5, ou l'adversaire peut ne subir aucun degat sur un tour
# donne). A ajouter plus tard une fois ces regles sourcees avec certitude.

const SITUATION_TABLE = {
	-7: [[0, 12], [0, 9], [1, 8], [2, 6], [2, 5], [3, 4]],
	-6: [[1, 8], [1, 7], [1, 6], [2, 5], [2, 5], [3, 4]],
	-5: [[1, 7], [1, 6], [1, 5], [2, 5], [3, 4], [4, 4]],
	-4: [[1, 6], [2, 6], [2, 5], [2, 4], [3, 3], [4, 3]],
	-3: [[2, 6], [2, 5], [2, 4], [3, 4], [3, 3], [4, 3]],
	-2: [[2, 6], [2, 5], [2, 4], [3, 3], [4, 3], [5, 3]],
	-1: [[3, 6], [3, 5], [3, 4], [3, 3], [4, 3], [5, 3]],
	0: [[3, 5], [3, 4], [3, 3], [3, 3], [4, 3], [5, 3]],
	1: [[3, 5], [3, 4], [3, 3], [4, 3], [5, 3], [6, 3]],
	2: [[3, 5], [3, 4], [3, 3], [4, 2], [5, 2], [6, 2]],
	3: [[3, 4], [3, 3], [4, 3], [4, 2], [5, 2], [6, 2]],
	4: [[3, 4], [3, 3], [4, 2], [5, 2], [6, 2], [6, 1]],
	5: [[4, 4], [4, 3], [5, 2], [5, 1], [6, 1], [7, 1]],
	6: [[4, 3], [5, 2], [5, 2], [6, 1], [7, 1], [8, 1]],
	7: [[4, 3], [5, 2], [6, 2], [8, 1], [9, 0], [12, 0]],
}

# Cout de fuite en Points de Chance -- identique pour toutes les
# differences d'un meme palier, mais stocke par difference brute (comme
# sur la fiche) pour eviter une couche de mapping palier<->difference.
const FUITE_COST = {
	-7: 5, -6: 5, -5: 5,
	-4: 3, -3: 3,
	-2: 2, -1: 2,
	0: 1,
	1: 1, 2: 1,
	3: 1, 4: 1,
	5: 0, 6: 0, 7: 0,
}

const TIER_NAMES = {
	-7: "DESAVANTAGE_LOURD", -6: "DESAVANTAGE_LOURD", -5: "DESAVANTAGE_LOURD",
	-4: "DESAVANTAGE", -3: "DESAVANTAGE",
	-2: "DESAVANTAGE_LEGER", -1: "DESAVANTAGE_LEGER",
	0: "EGALITE",
	1: "AVANTAGE_LEGER", 2: "AVANTAGE_LEGER",
	3: "AVANTAGE", 4: "AVANTAGE",
	5: "AVANTAGE_LOURD", 6: "AVANTAGE_LOURD", 7: "AVANTAGE_LOURD",
}


static func clamp_diff(diff):
	return clampi(diff, -7, 7)


static func get_tier_name(hab_billy, hab_adversaire):
	return TIER_NAMES[clamp_diff(hab_billy - hab_adversaire)]


static func get_fuite_cost(hab_billy, hab_adversaire):
	return FUITE_COST[clamp_diff(hab_billy - hab_adversaire)]


static func roll_die():
	return randi_range(1, 6)


# Resout un seul tour a partir d'un jet de de deja connu (1-6), sans
# appliquer Armure/Degats/Critique/Esquive -- voir le commentaire d'en-tete.
static func resolve_round(hab_billy, hab_adversaire, die_roll):
	assert(die_roll >= 1 and die_roll <= 6, "die_roll doit etre entre 1 et 6")
	var diff = clamp_diff(hab_billy - hab_adversaire)
	var pair = SITUATION_TABLE[diff][die_roll - 1]
	return {"degats_billy": pair[0], "degats_adversaire": pair[1], "diff": diff}


# Composant "combat en cours" : suit les PV des deux cotes tour par tour,
# comme la Feuille de Combat officielle (colonnes PV/Billy/Adv., une ligne
# par Tour). Reste volontairement decouple de Player/BookData -- l'appelant
# (plus tard main.gd) est responsable de lui fournir les valeurs de depart
# et de lire les resultats.
var hab_billy = 0
var hab_adversaire = 0
var pv_billy = 0
var pv_adversaire = 0
var tour = 0
var historique = []


func _init(p_hab_billy, p_hab_adversaire, p_pv_billy, p_pv_adversaire):
	self.hab_billy = p_hab_billy
	self.hab_adversaire = p_hab_adversaire
	self.pv_billy = p_pv_billy
	self.pv_adversaire = p_pv_adversaire


func is_over():
	return self.pv_billy <= 0 or self.pv_adversaire <= 0


# Retourne "billy", "adversaire", "egalite" (les deux tombent le meme
# tour) ou null si le combat n'est pas encore termine.
func get_winner():
	if !self.is_over():
		return null
	if self.pv_billy <= 0 and self.pv_adversaire <= 0:
		return "egalite"
	elif self.pv_adversaire <= 0:
		return "billy"
	else:
		return "adversaire"


# Joue un tour. die_roll est optionnel (roll_die() est utilise par defaut) --
# le passer explicitement permet de rejouer un tour de maniere deterministe
# (tests, ou "relance" du DEBROUILLARD une fois cette mecanique sourcee).
func play_turn(die_roll = null):
	if self.is_over():
		push_error("Combat.play_turn: le combat est deja termine")
		return null
	if die_roll == null:
		die_roll = roll_die()
	self.tour += 1
	var result = resolve_round(self.hab_billy, self.hab_adversaire, die_roll)
	self.pv_adversaire = maxi(0, self.pv_adversaire - result['degats_billy'])
	self.pv_billy = maxi(0, self.pv_billy - result['degats_adversaire'])
	result['tour'] = self.tour
	result['die_roll'] = die_roll
	result['pv_billy'] = self.pv_billy
	result['pv_adversaire'] = self.pv_adversaire
	self.historique.append(result)
	return result
