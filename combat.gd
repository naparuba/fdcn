extends RefCounted

const CombatModificateurs = preload('res://combat_modificateurs.gd')

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
# - DEGATS : bonus plat AJOUTE aux degats infliges par une attaque normale
#   (symetrique de l'ARMURE, qui les REDUIT) -- PAS sourcee par une citation
#   directe comme l'Armure, mais inferee par symetrie : "DEGATS" est liste
#   comme stat secondaire sur la fiche officielle exactement au meme rang
#   qu'ARMURE/CRITIQUE/PV MAX, et player.gd/chapter_data.gd la trackent de
#   la meme maniere (self.deg/deg_items/deg_chapters, node.get_combat_degat())
#   qu'ARMURE (self.arm/...) et CRITIQUE (self.crit/...). Ne s'ajoute PAS a
#   la contre-attaque critique (la formule sourcee pour celle-ci ne
#   mentionne que "degats maximum + Critique", rien de plus) ; ne s'ajoute
#   pas non plus au cote qui vient d'esquiver (une esquive reussie annule
#   integralement l'attaque, DEGATS inclus).
#
# PAS COUVERT PAR DEFAUT (aucune donnee generique sourcee) : esquive ou
# contre-attaque critique cote adversaire -- mais voir "Modificateurs"
# ci-dessous, qui couvrent ces cas nœud par nœud une fois sourcees.
#
# --- Modificateurs (regles SPECIFIQUES a un combat precis, cf
# COMBATS_REGLES_SPECIALES.md) : contrairement aux mecaniques ci-dessus
# (universelles, valables partout), le Tome 1 a 42 combats sur 45 avec au
# moins une regle propre (gnoll qui divise l'Habileté, adversaire qui
# esquive sur un jet pair, effet declenche tous les 3 tours...). Plutot
# qu'une sous-classe de Combat par nœud (autant de quasi-doublons de
# play_turn()), chaque regle est un petit objet Modificateur (cf
# combat_modificateurs.gd) attache via opts.modificateurs, appele a des
# points d'accroche fixes dans play_turn()/is_over()/get_winner(). Les
# memes classes se reutilisent tel quel entre plusieurs combats (ex.
# EsquiveAdverseSurDe couvre 6 nœuds differents avec un predicat different
# a chaque fois).
#
# --- Contrat avec l'appelant (important pour l'integration future dans
# main.gd/player.gd) :
# - Cette classe ne detient JAMAIS de reference a Player ni a aucun noeud
#   de la scene -- seulement des valeurs numeriques copiees a la creation
#   (hab/pv/armure/adresse/critique). Rejouer, annuler des tours ou
#   abandonner le combat ne modifie donc jamais l'etat reel du joueur.
# - Tant que l'appelant n'appelle pas explicitement get_pv_delta_billy()
#   (ou n'importe quelle info du combat) pour l'appliquer lui-meme a
#   Player, rien de ce combat n'est "reel" -- exactement ce qu'il faut
#   pour permettre un ecran de resume ("valider" / "annuler tout le
#   combat") avant integration definitive.
# - undo_last_turn() permet a l'UI de proposer un "annuler ce tour, le
#   rejouer" ; appelable plusieurs fois de suite pour revenir sur
#   plusieurs tours.

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


# Etat (copie) d'un seul combattant a un instant du combat. Minimal pour
# l'instant (seuls les PV changent tour apres tour dans les regles
# sourcees) -- prevu pour accueillir plus tard des effets temporaires
# (ex: Habileté divisee par les gnolls, cf le Guide detaille) sans casser
# l'API si une regle numerique est un jour sourcee pour ca.
class EtatCombattant:
	var pv: int

	func _init(p_pv):
		self.pv = p_pv

	func copie():
		return EtatCombattant.new(self.pv)


# Un tour joue = une entree de la pile. Contient une COPIE de l'etat des
# deux combattants APRES ce tour, jamais une reference partagee -- deux
# EtatTour de la pile ne pointent donc jamais sur le meme EtatCombattant.
class EtatTour:
	var tour: int
	var billy: EtatCombattant
	var adversaire: EtatCombattant
	var attack_die_roll = null
	var esquive_die_roll = null
	var esquive := false
	var contre_attaque_critique := false
	var degats_billy := 0
	var degats_adversaire := 0
	# Degats supplementaires appliques par un Modificateur APRES la
	# resolution normale du tour (ex: brasier periodique tous les 3
	# tours) -- distincts de degats_billy/degats_adversaire pour qu'un
	# test puisse verifier separement "le tour normal" et "l'effet
	# special", cf DegatsPeriodiques dans combat_modificateurs.gd.
	var degats_supplementaires_billy := 0
	var degats_supplementaires_adversaire := 0
	# true si un Modificateur a signale que l'adversaire n'attaque pas DU
	# TOUT ce tour (ex: SansAttaqueTour) -- distinct d'un degats_adversaire
	# naturellement a 0 (Table des Situations), pour que l'UI puisse
	# afficher un message explicite plutot qu'un "0" qui ressemblerait a un
	# bug.
	var sans_attaque_adversaire := false
	# Stats EFFECTIVES de ce tour precis (apres application des Modificateurs
	# type HabiliteAdverseDegressiveParDegatsCumules) -- distinctes des
	# champs permanents hab_billy/hab_adversaire/adresse_billy de Combat, qui
	# ne varient jamais eux-memes. Persistees ici pour qu'un appelant (l'UI)
	# puisse les afficher/reconstruire sans dupliquer la logique des hooks
	# hab_billy_pour_ce_tour/hab_adversaire_pour_ce_tour/adresse_billy_pour_ce_tour.
	var hab_billy_tour: int
	var hab_adversaire_tour: int
	var adresse_billy_tour: int

	func _init(p_tour, p_billy, p_adversaire):
		self.tour = p_tour
		self.billy = p_billy
		self.adversaire = p_adversaire


# Composant "combat en cours" : une PILE d'EtatTour (un par tour joue),
# comme la Feuille de Combat officielle (colonnes PV/Billy/Adv., une ligne
# par Tour) mais avec de vrais objets plutot que des colonnes. L'etat
# courant est toujours le sommet de la pile (ou l'etat initial si aucun
# tour n'a encore ete joue) -- annuler un tour = depiler, et l'etat
# courant redevient automatiquement celui d'avant, sans recalcul.
#
# Reste volontairement decouple de Player/BookData -- l'appelant (plus
# tard main.gd) est responsable de lui fournir les valeurs de depart
# (dont le bonus du Pyro-Barbare, deja ajoute a l'Habileté de Billy quand
# c'est pertinent) et de lire les resultats.
var hab_billy = 0
var hab_adversaire = 0
var armure_billy = 0
var armure_adversaire = 0
var adresse_billy = 0
var critique_billy = 0
var deg_billy = 0
var deg_adversaire = 0
var pyro_bonus = 0
var plafond_degats_subis_billy = null  # ex: 3 pour un Billy PAYSAN
var modificateurs: Array = []  # Array[Modificateur], cf combat_modificateurs.gd

var _etat_initial: EtatTour
var pile: Array = []  # Array[EtatTour], un par tour joue, empile dans l'ordre


# opts (toutes optionnelles, defaut = aucun effet) :
#   armure_billy, armure_adversaire, adresse_billy, critique_billy,
#   deg_billy, deg_adversaire, pyro_bonus (ajoute a p_hab_billy pour toute
#   la duree du combat), plafond_degats_subis_billy (ex: 3 pour un Billy
#   PAYSAN, applique apres l'Armure), modificateurs (Array d'instances
#   Modificateur, cf combat_modificateurs.gd, pour les regles specifiques
#   a CE combat precis).
func _init(p_hab_billy, p_hab_adversaire, p_pv_billy, p_pv_adversaire, opts = {}):
	self.pyro_bonus = opts.get('pyro_bonus', 0)
	self.hab_billy = p_hab_billy + self.pyro_bonus
	self.hab_adversaire = p_hab_adversaire
	self.armure_billy = opts.get('armure_billy', 0)
	self.armure_adversaire = opts.get('armure_adversaire', 0)
	self.adresse_billy = opts.get('adresse_billy', 0)
	self.critique_billy = opts.get('critique_billy', 0)
	self.deg_billy = opts.get('deg_billy', 0)
	self.deg_adversaire = opts.get('deg_adversaire', 0)
	self.plafond_degats_subis_billy = opts.get('plafond_degats_subis_billy', null)
	self.modificateurs = opts.get('modificateurs', [])
	self._etat_initial = EtatTour.new(0, EtatCombattant.new(p_pv_billy), EtatCombattant.new(p_pv_adversaire))
	# Avant le premier tour, les stats "effectives" sont simplement les
	# stats de base -- permet a l'appelant de lire etat_courant().hab_*_tour
	# sans condition particuliere meme quand aucun tour n'a encore ete joue.
	self._etat_initial.hab_billy_tour = self.hab_billy
	self._etat_initial.hab_adversaire_tour = self.hab_adversaire
	self._etat_initial.adresse_billy_tour = self.adresse_billy


# L'etat courant est toujours le sommet de la pile, ou l'etat initial si
# aucun tour n'a encore ete joue -- jamais recalcule, juste lu.
func etat_courant() -> EtatTour:
	if len(self.pile) > 0:
		return self.pile[-1]
	return self._etat_initial


var pv_billy: int:
	get: return self.etat_courant().billy.pv

var pv_adversaire: int:
	get: return self.etat_courant().adversaire.pv

var tour: int:
	get: return self.etat_courant().tour


func _billy_peut_perdre():
	for m in self.modificateurs:
		if !m.billy_peut_perdre(self):
			return false
	return true


func _vainqueur_force_par_modificateur():
	for m in self.modificateurs:
		var force = m.vainqueur_force(self)
		if force != null:
			return force
	return null


func is_over():
	if self.pv_adversaire <= 0:
		return true
	if self.pv_billy <= 0 and self._billy_peut_perdre():
		return true
	return self._vainqueur_force_par_modificateur() != null


# Retourne "billy", "adversaire", "egalite" (les deux tombent le meme
# tour) ou null si le combat n'est pas encore termine.
func get_winner():
	var force = self._vainqueur_force_par_modificateur()
	if force != null:
		return force
	if !self.is_over():
		return null
	if self.pv_billy <= 0 and self.pv_adversaire <= 0:
		for m in self.modificateurs:
			var tranche = m.tranche_egalite(self)
			if tranche != null:
				return tranche
		return "egalite"
	elif self.pv_adversaire <= 0:
		return "billy"
	else:
		return "adversaire"


func peut_esquiver():
	return self.adresse_billy >= 2


func peut_annuler_dernier_tour():
	return len(self.pile) > 0


# Difference entre les PV de depart et les PV courants -- c'est la SEULE
# chose que l'appelant a besoin de lire pour integrer (ou pas) l'effet du
# combat sur le vrai Player (ex: Player.pv += combat.get_pv_delta_billy()).
# Reflete l'etat courant, donc APRES d'eventuels undo_last_turn().
func get_pv_delta_billy():
	return self.pv_billy - self._etat_initial.billy.pv


func get_pv_delta_adversaire():
	return self.pv_adversaire - self._etat_initial.adversaire.pv


# Annule le dernier tour joue : depile. L'etat courant (pv_billy,
# pv_adversaire, tour) redevient automatiquement celui du nouveau sommet
# de pile (ou l'etat initial si la pile est vide), sans rien recalculer.
# Pensé pour une UI "annuler ce tour / le rejouer" -- rappelable plusieurs
# fois de suite pour revenir sur plusieurs tours. Retourne l'EtatTour
# depile, ou null s'il n'y en a aucun.
func undo_last_turn() -> EtatTour:
	if !self.peut_annuler_dernier_tour():
		push_error("Combat.undo_last_turn: aucun tour a annuler")
		return null
	return self.pile.pop_back()


# Stats effectives (Habileté Billy/adversaire, Adresse Billy) qui
# s'appliqueraient si "numero_tour" etait joue MAINTENANT, sans rien jouer
# ni modifier l'etat -- extrait du debut de play_turn() pour que l'appelant
# puisse previsualiser un tour a venir (ex: bande "ce que vous risquez par
# face de de", cf SPEC_ECRAN_COMBAT.md) sans dupliquer cette boucle de
# hooks. Les deux endroits partagent donc le meme calcul, jamais deux
# versions qui pourraient diverger.
func stats_effectives_pour_tour(numero_tour: int) -> Dictionary:
	var hab_billy_tour = self.hab_billy
	var hab_adversaire_tour = self.hab_adversaire
	var adresse_billy_tour = self.adresse_billy
	for m in self.modificateurs:
		hab_billy_tour = m.hab_billy_pour_ce_tour(self, hab_billy_tour, numero_tour)
		hab_adversaire_tour = m.hab_adversaire_pour_ce_tour(self, hab_adversaire_tour, numero_tour)
		adresse_billy_tour = m.adresse_billy_pour_ce_tour(self, adresse_billy_tour, numero_tour)
	return {
		"hab_billy": hab_billy_tour,
		"hab_adversaire": hab_adversaire_tour,
		"adresse_billy": adresse_billy_tour,
	}


# Joue un tour complet : recalcul des stats effectives du tour (via les
# Modificateurs), jet d'attaque, esquive adverse eventuelle, esquive de
# Billy si son ADRESSE le permet, application de l'Armure et du plafond
# de degats subis (PAYSAN), puis effets apres-tour (brasiers periodiques,
# etc.). Les deux jets sont optionnels (roll_die() par defaut) pour
# permettre des tours deterministes en test. Empile un nouvel EtatTour
# (copie de l'etat precedent + les degats de ce tour) -- ne modifie jamais
# un EtatTour deja empile.
func play_turn(attack_die_roll = null, esquive_die_roll = null) -> EtatTour:
	if self.is_over():
		push_error("Combat.play_turn: le combat est deja termine")
		return null
	if attack_die_roll == null:
		attack_die_roll = roll_die()
	var precedent = self.etat_courant()
	var numero_tour = precedent.tour + 1

	var stats_tour = self.stats_effectives_pour_tour(numero_tour)
	var hab_billy_tour = stats_tour['hab_billy']
	var hab_adversaire_tour = stats_tour['hab_adversaire']
	var adresse_billy_tour = stats_tour['adresse_billy']

	var adversaire_esquive_normale = false
	for m in self.modificateurs:
		if m.adversaire_esquive_attaque_normale(self, attack_die_roll, numero_tour):
			adversaire_esquive_normale = true

	var adversaire_n_attaque_pas = false
	for m in self.modificateurs:
		if m.adversaire_n_attaque_pas_ce_tour(self, numero_tour):
			adversaire_n_attaque_pas = true

	var base = resolve_round(hab_billy_tour, hab_adversaire_tour, attack_die_roll)
	var degats_billy_bruts = 0 if adversaire_esquive_normale else base['degats_billy']  # subis par l'adversaire
	var degats_adversaire_bruts = base['degats_adversaire']  # subis par Billy

	var traitement_critique = CombatModificateurs.Modificateur.CRITIQUE_NORMAL
	for m in self.modificateurs:
		var t = m.traitement_critique(self, numero_tour)
		if t != CombatModificateurs.Modificateur.CRITIQUE_NORMAL:
			traitement_critique = t

	var esquive = false
	var contre_attaque_critique = false
	if adresse_billy_tour >= 2:
		if esquive_die_roll == null:
			esquive_die_roll = roll_die()
		if esquive_die_roll <= adresse_billy_tour:
			esquive = true
			degats_adversaire_bruts = 0
			if esquive_die_roll == 1 and !adversaire_esquive_normale:
				var degats_max = resolve_round(hab_billy_tour, hab_adversaire_tour, 6)['degats_billy']
				match traitement_critique:
					CombatModificateurs.Modificateur.CRITIQUE_IMMUNITE_TOTALE:
						degats_billy_bruts = 0
					CombatModificateurs.Modificateur.CRITIQUE_SANS_BONUS:
						contre_attaque_critique = true
						degats_billy_bruts = degats_max
					_:
						contre_attaque_critique = true
						degats_billy_bruts = degats_max + self.critique_billy
	else:
		esquive_die_roll = null  # pas de tentative -- ignore un jet fourni par erreur

	# DEGATS : bonus plat sur une attaque normale uniquement -- ni sur la
	# contre-attaque critique (formule sourcee = degats max + Critique,
	# rien de plus), ni sur le cote qui vient d'esquiver (0 reste 0).
	if !contre_attaque_critique and !adversaire_esquive_normale:
		degats_billy_bruts += self.deg_billy
	if !esquive:
		degats_adversaire_bruts += self.deg_adversaire

	# Point d'accroche des Modificateurs restants (bonus/malus divers sur
	# les degats bruts : bonus sur un jet precis, seuil de PV, absence
	# d'attaque un tour donne, regeneration conditionnelle, intangibilite...).
	# Applique APRES tout ce qui precede, AVANT Armure/plafond.
	var contexte = {
		"attack_die_roll": attack_die_roll, "esquive_die_roll": esquive_die_roll,
		"esquive": esquive, "contre_attaque_critique": contre_attaque_critique,
		"adversaire_esquive_normale": adversaire_esquive_normale, "tour": numero_tour,
	}
	for m in self.modificateurs:
		var paire = m.modifie_degats_bruts(self, degats_billy_bruts, degats_adversaire_bruts, contexte)
		degats_billy_bruts = paire[0]
		degats_adversaire_bruts = paire[1]

	# La contre-attaque critique ignore l'Armure adverse (regle sourcee) ;
	# une attaque normale la subit normalement.
	var degats_billy_final = degats_billy_bruts if contre_attaque_critique \
		else maxi(0, degats_billy_bruts - self.armure_adversaire)
	var degats_adversaire_final = maxi(0, degats_adversaire_bruts - self.armure_billy)
	if self.plafond_degats_subis_billy != null:
		degats_adversaire_final = mini(degats_adversaire_final, self.plafond_degats_subis_billy)

	var nouveau_billy = EtatCombattant.new(maxi(0, precedent.billy.pv - degats_adversaire_final))
	var nouvel_adversaire = EtatCombattant.new(maxi(0, precedent.adversaire.pv - degats_billy_final))
	var nouveau_tour = EtatTour.new(numero_tour, nouveau_billy, nouvel_adversaire)
	nouveau_tour.attack_die_roll = attack_die_roll
	nouveau_tour.esquive_die_roll = esquive_die_roll
	nouveau_tour.esquive = esquive
	nouveau_tour.contre_attaque_critique = contre_attaque_critique
	nouveau_tour.degats_billy = degats_billy_final
	nouveau_tour.degats_adversaire = degats_adversaire_final
	nouveau_tour.hab_billy_tour = hab_billy_tour
	nouveau_tour.hab_adversaire_tour = hab_adversaire_tour
	nouveau_tour.adresse_billy_tour = adresse_billy_tour
	nouveau_tour.sans_attaque_adversaire = adversaire_n_attaque_pas

	self.pile.append(nouveau_tour)

	# Effets apres-tour (brasiers periodiques, attaque posthume...) :
	# peuvent infliger des degats SUPPLEMENTAIRES, distincts du tour
	# normal ci-dessus, une fois celui-ci deja empile.
	for m in self.modificateurs:
		var extra = m.effet_apres_tour(self, nouveau_tour)
		if extra != null:
			nouveau_tour.degats_supplementaires_billy += extra.get('billy', 0)
			nouveau_tour.degats_supplementaires_adversaire += extra.get('adversaire', 0)
			nouvel_adversaire.pv = maxi(0, nouvel_adversaire.pv - extra.get('billy', 0))
			nouveau_billy.pv = maxi(0, nouveau_billy.pv - extra.get('adversaire', 0))

	return nouveau_tour
