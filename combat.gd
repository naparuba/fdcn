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
# Remarque sur DOMINATION : le terme evoque par les joueurs ne correspond
# a aucune case specifique de cette table -- c'est le nom fan pour
# l'Avantage Lourd extreme (diff >= 5), ou l'adversaire peut ne subir
# aucun degat sur un tour donne.
#
# --- Mecaniques additionnelles : ARMURE, ESQUIVE, CONTRE-ATTAQUE CRITIQUE,
# plafond du PAYSAN, bonus du Pyro-Barbare.
#
# Sourcees via la page de regles non-officielle
# https://webacademy.be/projets/2021/Forteresse_du_chaudron_noir/regles.php
# (ecrite par "naparuba", qui est aussi le contact developpeur de cette
# app -- cf l'ecran "A propos" -- donc une source quasi-officielle pour ce
# projet precis), plus le Guide detaille pour le plafond du PAYSAN. Le
# domaine ne resout pas en DNS depuis cet environnement de dev : contenu
# obtenu par recherche web (extraits concordants sur plusieurs requetes
# independantes), PAS relu integralement a l'oeil comme la Table des
# Situations -- a revalider contre le livre physique si un doute survient.
#
# - ARMURE : reduction directe des degats recus, 1 pour 1 (2 ARMURE = 2
#   degats en moins), plancher a 0.
# - ESQUIVE : possible seulement si ADRESSE >= 2. Un d6 SEPARE du jet
#   d'attaque est lance chaque tour ; si le resultat est <= ADRESSE, le
#   defenseur esquive integralement (0 degat subi ce tour-la).
# - CONTRE-ATTAQUE CRITIQUE : si le jet d'esquive donne exactement 1, en
#   plus d'esquiver, le defenseur infligé ses degats MAXIMUM (comme un 6
#   au jet d'attaque pour sa situation actuelle) + son score de CRITIQUE,
#   en ignorant l'ARMURE adverse.
# - PAYSAN (Guide detaille, prose uniquement -- cf commit precedent) :
#   plafond de 3 PV subis par tour max, applique APRES l'Armure.
# - Pyro-Barbare : bonus plat d'Habileté pour Billy pendant le combat (cf
#   chapter_data.gd::get_combat_pyro(), affiche "+N" en jeu) -- fourni en
#   entree de Combat plutot que devine.
#
# PAS COUVERT (aucune donnee/formule sourcee) : esquive ou contre-attaque
# critique cote adversaire (mentionnee en prose pour certains ennemis,
# mais chapter_data.gd n'expose aucune ADRESSE/CRITIQUE d'adversaire pour
# l'appliquer -- a activer si cette donnee est un jour sourcee).

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
# (dont le bonus du Pyro-Barbare, deja ajoute a l'Habileté de Billy quand
# c'est pertinent) et de lire les resultats.
var hab_billy = 0
var hab_adversaire = 0
var pv_billy = 0
var pv_adversaire = 0
var armure_billy = 0
var armure_adversaire = 0
var adresse_billy = 0
var critique_billy = 0
var pyro_bonus = 0
var plafond_degats_subis_billy = null  # ex: 3 pour un Billy PAYSAN
var tour = 0
var historique = []


# opts (toutes optionnelles, defaut = aucun effet) :
#   armure_billy, armure_adversaire, adresse_billy, critique_billy,
#   pyro_bonus (ajoute a p_hab_billy pour toute la duree du combat),
#   plafond_degats_subis_billy (ex: 3 pour un Billy PAYSAN, applique
#   apres l'Armure).
func _init(p_hab_billy, p_hab_adversaire, p_pv_billy, p_pv_adversaire, opts = {}):
	self.pyro_bonus = opts.get('pyro_bonus', 0)
	self.hab_billy = p_hab_billy + self.pyro_bonus
	self.hab_adversaire = p_hab_adversaire
	self.pv_billy = p_pv_billy
	self.pv_adversaire = p_pv_adversaire
	self.armure_billy = opts.get('armure_billy', 0)
	self.armure_adversaire = opts.get('armure_adversaire', 0)
	self.adresse_billy = opts.get('adresse_billy', 0)
	self.critique_billy = opts.get('critique_billy', 0)
	self.plafond_degats_subis_billy = opts.get('plafond_degats_subis_billy', null)


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


func peut_esquiver():
	return self.adresse_billy >= 2


# Joue un tour complet : jet d'attaque, puis jet d'esquive de Billy si son
# ADRESSE le permet, application de l'Armure et du plafond de degats subis
# (PAYSAN). Les deux jets sont optionnels (roll_die() par defaut) pour
# permettre des tours deterministes en test.
func play_turn(attack_die_roll = null, esquive_die_roll = null):
	if self.is_over():
		push_error("Combat.play_turn: le combat est deja termine")
		return null
	if attack_die_roll == null:
		attack_die_roll = roll_die()
	self.tour += 1

	var base = resolve_round(self.hab_billy, self.hab_adversaire, attack_die_roll)
	var degats_billy_bruts = base['degats_billy']  # subis par l'adversaire
	var degats_adversaire_bruts = base['degats_adversaire']  # subis par Billy

	var esquive = false
	var contre_attaque_critique = false
	if self.peut_esquiver():
		if esquive_die_roll == null:
			esquive_die_roll = roll_die()
		if esquive_die_roll <= self.adresse_billy:
			esquive = true
			degats_adversaire_bruts = 0
			if esquive_die_roll == 1:
				contre_attaque_critique = true
				var degats_max = resolve_round(self.hab_billy, self.hab_adversaire, 6)['degats_billy']
				degats_billy_bruts = degats_max + self.critique_billy
	else:
		esquive_die_roll = null  # pas de tentative -- ignore un jet fourni par erreur

	# La contre-attaque critique ignore l'Armure adverse (regle sourcee) ;
	# une attaque normale la subit normalement.
	var degats_billy_final = degats_billy_bruts if contre_attaque_critique \
		else maxi(0, degats_billy_bruts - self.armure_adversaire)
	var degats_adversaire_final = maxi(0, degats_adversaire_bruts - self.armure_billy)
	if self.plafond_degats_subis_billy != null:
		degats_adversaire_final = mini(degats_adversaire_final, self.plafond_degats_subis_billy)

	self.pv_adversaire = maxi(0, self.pv_adversaire - degats_billy_final)
	self.pv_billy = maxi(0, self.pv_billy - degats_adversaire_final)

	var result = {
		"tour": self.tour,
		"attack_die_roll": attack_die_roll,
		"esquive_die_roll": esquive_die_roll,
		"esquive": esquive,
		"contre_attaque_critique": contre_attaque_critique,
		"degats_billy": degats_billy_final,
		"degats_adversaire": degats_adversaire_final,
		"pv_billy": self.pv_billy,
		"pv_adversaire": self.pv_adversaire,
	}
	self.historique.append(result)
	return result
