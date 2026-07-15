extends RefCounted

# Modificateurs de combat -- une classe par mecanique speciale REUTILISABLE,
# derivee du catalogue COMBATS_REGLES_SPECIALES.md (Tome 1, 45 combats).
#
# ARCHITECTURE (cf discussion : "une pile de regles" vs "des sous-classes de
# Combat" -- choix retenu : composition de petits modificateurs plutot que
# l'un ou l'autre). Chaque combat special du livre n'est presque jamais un
# algorithme de resolution DIFFERENT, juste une VARIATION PARAMETREE d'un
# petit nombre de motifs qui reviennent sur plusieurs nœuds (esquive
# adverse conditionnee au de, effet declenche tous les N tours, seuil de
# PV qui change une mecanique...). Une sous-classe de Combat par nœud
# aurait force a re-ecrire play_turn() presque a l'identique 45 fois. Une
# liste de petits objets Modificateur, attaches a un Combat via
# opts.modificateurs et appeles a des points d'accroche fixes dans
# play_turn()/is_over()/get_winner(), permet de reutiliser le meme
# modificateur (avec des parametres differents) sur plusieurs combats --
# ex: EsquiveAdverseSurDe couvre a lui seul les nœuds 173, 175, 240, 320,
# 321 et 574, juste avec un predicat different.
#
# Implemente pour de vrai (plus de squelettes) -- les tests dans
# test/unit/test_combat_regles_speciales_tome1.gd ont ete ecrits AVANT
# cette implementation (rouge intentionnel), pour verrouiller le
# comportement attendu avant de coder quoi que ce soit.
#
# CE QUI N'A PAS BESOIN D'UN MODIFICATEUR ICI (deja possible avec les
# opts existants de combat.gd, cote APPELANT, pas cote Combat) : tout
# malus/bonus FIXE pour toute la duree du combat (-1 Adresse, Habileté
# divisee par 2 une fois pour toutes, plancher d'Habileté, override de
# degats par arme) -- l'appelant calcule la valeur finale et la passe
# directement a Combat.new(). Voir COMBATS_REGLES_SPECIALES.md pour le
# detail nœud par nœud de ce qui est "cote appelant" vs "modificateur ici".


# Classe de base : chaque methode est un point d'accroche optionnel
# (no-op/valeur neutre par defaut). Un Modificateur concret n'override
# que ce dont il a besoin. "combat" (parametre recu partout) est
# l'instance Combat en cours, pour lire pile/tour/pv_billy/etc. si besoin
# (ex: degats totaux deja infliges via combat.get_pv_delta_adversaire()).
class Modificateur:
	# Habileté effective de l'ADVERSAIRE pour CE tour, avant le jet de
	# phase d'attaque. Recoit la valeur courante (deja modifiee par
	# d'eventuels modificateurs precedents dans la liste), renvoie la
	# valeur a utiliser.
	func hab_adversaire_pour_ce_tour(combat, hab_adversaire_actuelle, tour):
		return hab_adversaire_actuelle

	# Idem pour l'Adresse de Billy (certains combats la font varier en
	# cours de route, ex: regagnee au fil des degats infliges).
	func adresse_billy_pour_ce_tour(combat, adresse_billy_actuelle, tour):
		return adresse_billy_actuelle

	# Idem pour l'Habileté de BILLY (distinct de hab_adversaire_pour_ce_tour
	# ci-dessus) -- ex: baisse a chaque coup recu, cf nœud 421.
	func hab_billy_pour_ce_tour(combat, hab_billy_actuelle, tour):
		return hab_billy_actuelle

	# L'ADVERSAIRE esquive-t-il l'attaque normale de Billy ce tour,
	# INDEPENDAMMENT du mecanisme d'esquive de Billy (qui ne concerne que
	# ce qu'il subit, pas ce qu'il infligé) ? Si true : degats_billy et
	# une eventuelle contre-attaque critique sont annules pour ce tour.
	func adversaire_esquive_attaque_normale(combat, attack_die_roll, tour):
		return false

	# Permet d'ajouter/retirer des degats bruts (avant Armure/plafond).
	# Recoit le degats_billy/degats_adversaire deja calcules par la Table
	# des Situations (+ esquive/critique de Billy), renvoie la paire
	# (potentiellement modifiee). contexte = dict avec au moins
	# 'attack_die_roll', 'esquive', 'contre_attaque_critique'.
	func modifie_degats_bruts(combat, degats_billy, degats_adversaire, contexte):
		return [degats_billy, degats_adversaire]

	# Un coup critique (contre-attaque suite a esquive de Billy) doit-il
	# etre supprime pour cet adversaire ? Deux niveaux possibles cf
	# COMBATS_REGLES_SPECIALES.md : immunite totale (aucun degat, juste
	# une esquive simple) vs bonus de Critique seulement retire (degats
	# maximum de la situation conserves). Renvoie une des constantes
	# CRITIQUE_NORMAL / CRITIQUE_SANS_BONUS / CRITIQUE_IMMUNITE_TOTALE.
	func traitement_critique(combat, tour):
		return Modificateur.CRITIQUE_NORMAL

	const CRITIQUE_NORMAL = 0
	const CRITIQUE_SANS_BONUS = 1
	const CRITIQUE_IMMUNITE_TOTALE = 2

	# Appele juste apres qu'un tour normal a ete resolu et empile. Peut
	# renvoyer des degats SUPPLEMENTAIRES a appliquer immediatement (dict
	# optionnel {"billy": X, "adversaire": Y}, defaut 0/0) -- typiquement
	# pour des effets periodiques (tous les N tours) ou une regeneration.
	# etat_tour = l'EtatTour qui vient d'etre empile (deja finalise).
	func effet_apres_tour(combat, etat_tour):
		return null

	# Force la fin du combat / le vainqueur, independamment des PV (ex:
	# limite de tours, survie jusqu'a un tour donne). Renvoie null (pas
	# d'avis, laisser Combat decider normalement) ou "billy"/"adversaire"/
	# "egalite".
	func vainqueur_force(combat):
		return null

	# Override du cas "egalite" (mort simultanee) de get_winner() -- par
	# defaut Combat renvoie "egalite" si pv_billy<=0 ET pv_adversaire<=0
	# le meme tour ; certains combats decident explicitement qui gagne
	# dans ce cas precis. Renvoie null (garder "egalite") ou "billy"/
	# "adversaire".
	func tranche_egalite(combat):
		return null

	# Billy peut-il mourir dans ce combat precis ? Si false, pv_billy a 0
	# ne doit jamais se traduire par une defaite (cf nœud 421).
	func billy_peut_perdre(combat):
		return true


# --- Modificateurs concrets (un par mecanique du catalogue Tome 1) -----


# Nœuds 173, 175, 240, 320, 321, 574 : l'adversaire esquive l'attaque
# normale de Billy selon un predicat sur le jet d'attaque (pas celui
# d'esquive de Billy). "predicat" est un Callable(int)->bool.
class EsquiveAdverseSurDe extends Modificateur:
	var predicat: Callable

	func _init(p_predicat: Callable):
		self.predicat = p_predicat

	func adversaire_esquive_attaque_normale(combat, attack_die_roll, tour):
		return self.predicat.call(attack_die_roll)


# Nœuds 574 (die=1 -> +3), 320 (die=1 -> +2, cumule avec une esquive ce
# meme tour) : bonus de degats subis par Billy quand le jet d'attaque
# tombe sur une valeur precise.
class BonusDegatsAdversaireSurDe extends Modificateur:
	var valeurs_de: Array
	var bonus: int

	func _init(p_valeurs_de: Array, p_bonus: int):
		self.valeurs_de = p_valeurs_de
		self.bonus = p_bonus

	func modifie_degats_bruts(combat, degats_billy, degats_adversaire, contexte):
		if contexte['attack_die_roll'] in self.valeurs_de:
			degats_adversaire += self.bonus
		return [degats_billy, degats_adversaire]


# Nœuds 36, 97 (defaite au bout de 5 ou 8 tours), 607 (victoire si survie
# 8 tours). "resultat" = "billy"/"adversaire", applique seulement si le
# combat n'est pas deja termine par ailleurs au tour N.
class LimiteDeTours extends Modificateur:
	var n: int
	var resultat: String

	func _init(p_n: int, p_resultat: String):
		self.n = p_n
		self.resultat = p_resultat

	func vainqueur_force(combat):
		if combat.tour >= self.n:
			return self.resultat
		return null


# Nœuds 76, 155, 231, 370, 518 : l'adversaire perd de l'Habileté au fur
# et a mesure des degats CUMULES que Billy lui infligé (pas juste ce
# tour) -- ex: -1 Habileté tous les 4 PV retires.
class HabiliteAdverseDegressiveParDegatsCumules extends Modificateur:
	var pas: int
	var perte: int

	func _init(p_pas: int, p_perte: int):
		self.pas = p_pas
		self.perte = p_perte

	func hab_adversaire_pour_ce_tour(combat, hab_adversaire_actuelle, tour):
		var degats_cumules = -combat.get_pv_delta_adversaire()
		var paliers = int(degats_cumules / self.pas)
		return maxi(0, hab_adversaire_actuelle - paliers * self.perte)


# Nœuds 370, 518 : Billy regagne de l'Adresse au fur et a mesure des
# degats cumules infliges (typiquement pour compenser un malus initial
# d'encerclement, deja applique cote appelant).
class AdresseBillyProgressiveParDegatsCumules extends Modificateur:
	var pas: int
	var gain: int

	func _init(p_pas: int, p_gain: int):
		self.pas = p_pas
		self.gain = p_gain

	func adresse_billy_pour_ce_tour(combat, adresse_billy_actuelle, tour):
		var degats_cumules = -combat.get_pv_delta_adversaire()
		var paliers = int(degats_cumules / self.pas)
		return adresse_billy_actuelle + paliers * self.gain


# Nœuds 97 (tous les 3 tours, 3 PV, esquivable sans possibilite de
# contre-attaque critique, ignore le plafond PAYSAN), 286 (tous les
# tours, 1 PV, non esquivable), 576 (une seule fois au tour 3, 10 PV,
# non esquivable, non affecte par l'Armure, plafond special selon
# l'archetype -- calcule cote appelant et passe ici en parametre
# "degats", PAS devine par ce modificateur).
class DegatsPeriodiques extends Modificateur:
	var intervalle: int
	var degats: int
	var cible: String  # "billy" ou "adversaire"
	var esquivable: bool
	var une_seule_fois: bool
	var tour_de_debut: int

	func _init(p_intervalle: int, p_degats: int, p_cible: String = "billy",
			p_esquivable: bool = false, p_une_seule_fois: bool = false, p_tour_de_debut: int = 1):
		self.intervalle = p_intervalle
		self.degats = p_degats
		self.cible = p_cible
		self.esquivable = p_esquivable
		self.une_seule_fois = p_une_seule_fois
		self.tour_de_debut = p_tour_de_debut

	func effet_apres_tour(combat, etat_tour):
		var declenche = false
		if self.une_seule_fois:
			declenche = etat_tour.tour == self.intervalle
		else:
			# tour_de_debut=1 (defaut) redonne exactement l'ancienne formule
			# "tour % intervalle == 0" -- Nœud 256 (Tome 2) a besoin de
			# "chaque tour a partir du 2eme" (intervalle=1, tour_de_debut=2).
			declenche = etat_tour.tour >= self.tour_de_debut \
				and (etat_tour.tour - self.tour_de_debut + 1) % self.intervalle == 0
		if !declenche:
			return null
		if self.esquivable:
			var jet = etat_tour.esquive_die_roll
			if jet != null and jet <= combat.adresse_billy:
				return null
		var cle = "adversaire" if self.cible == "billy" else "billy"
		return {cle: self.degats}


# Nœuds 232 (PV<=10 -> double degats), 555 (PV<10 -> double degats), 240
# (PV<=3 -> fin de combat/victoire), 350 (PV<=20 -> fin de combat/
# victoire). "effet" = "double_degats_adversaire" ou "fin_combat_victoire".
class SeuilPV extends Modificateur:
	var seuil: int
	var effet: String
	var cible: String  # PV de qui on surveille : "adversaire" (tous les cas connus)

	func _init(p_seuil: int, p_effet: String, p_cible: String = "adversaire"):
		self.seuil = p_seuil
		self.effet = p_effet
		self.cible = p_cible

	func modifie_degats_bruts(combat, degats_billy, degats_adversaire, contexte):
		if self.effet == "double_degats_adversaire" and combat.pv_adversaire <= self.seuil:
			degats_adversaire *= 2
		return [degats_billy, degats_adversaire]

	func vainqueur_force(combat):
		if self.effet == "fin_combat_victoire" and combat.pv_adversaire <= self.seuil:
			return "billy"
		return null


# Nœuds 276, 475/607 (Virilus) : l'adversaire est totalement immunise
# contre la contre-attaque critique de Billy (esquive simple, 0 degat,
# meme sur un jet d'esquive de 1).
class ImmuniteContreAttaqueCritique extends Modificateur:
	func traitement_critique(combat, tour):
		return Modificateur.CRITIQUE_IMMUNITE_TOTALE


# Nœud 162 : la contre-attaque critique de Billy a toujours lieu (degats
# maximum de la situation), mais sans le bonus de son score de CRITIQUE.
class ContreAttaqueCritiqueSansBonusCritique extends Modificateur:
	func traitement_critique(combat, tour):
		return Modificateur.CRITIQUE_SANS_BONUS


# Nœud 339 (vampiresse) : sur un jet d'attaque parmi "valeurs_de",
# l'adversaire ne subit aucun degat et regenere. Desactivable via un
# indicateur externe fourni par l'appelant (ex: possession d'un objet).
class RegenerationSurDe extends Modificateur:
	var valeurs_de: Array
	var regen: int
	var desactivee: bool

	func _init(p_valeurs_de: Array, p_regen: int, p_desactivee: bool = false):
		self.valeurs_de = p_valeurs_de
		self.regen = p_regen
		self.desactivee = p_desactivee

	func modifie_degats_bruts(combat, degats_billy, degats_adversaire, contexte):
		if !self.desactivee and !contexte['contre_attaque_critique'] \
				and contexte['attack_die_roll'] in self.valeurs_de:
			degats_billy = 0
		return [degats_billy, degats_adversaire]

	func effet_apres_tour(combat, etat_tour):
		if !self.desactivee and !etat_tour.contre_attaque_critique \
				and etat_tour.attack_die_roll in self.valeurs_de:
			return {"billy": -self.regen}
		return null


# Nœuds 321, 349 : l'adversaire ne porte aucune attaque lors d'un tour
# precis (typiquement le premier -- "LENT" ou "entree spectaculaire").
class SansAttaqueTour extends Modificateur:
	var numero_tour: int
	var duree: int

	func _init(p_numero_tour: int = 1, p_duree: int = 1):
		self.numero_tour = p_numero_tour
		self.duree = p_duree

	func modifie_degats_bruts(combat, degats_billy, degats_adversaire, contexte):
		# duree=1 (defaut) redonne exactement l'ancienne condition d'egalite
		# stricte -- Nœud 323 (Tome 2) a besoin de "pas d'attaque pendant 2
		# tours consecutifs" (numero_tour=1, duree=2).
		if contexte['tour'] >= self.numero_tour and contexte['tour'] < self.numero_tour + self.duree:
			degats_adversaire = 0
		return [degats_billy, degats_adversaire]


# Nœud 575 : malus d'Habileté adverse limite au premier tour SEULEMENT
# (contrairement a un malus permanent, qui est cote appelant).
class MalusHabiliteAdversePremierTourSeulement extends Modificateur:
	var malus: int

	func _init(p_malus: int):
		self.malus = p_malus

	func hab_adversaire_pour_ce_tour(combat, hab_adversaire_actuelle, tour):
		if tour == 1:
			return maxi(0, hab_adversaire_actuelle - self.malus)
		return hab_adversaire_actuelle


# Nœud 421 : chaque fois que Billy encaisse des degats (degats_adversaire
# final > 0 ce tour), son Habileté baisse pour la suite du combat.
class MalusHabiliteBillyParCoupRecu extends Modificateur:
	var malus_par_coup: int

	func _init(p_malus_par_coup: int):
		self.malus_par_coup = p_malus_par_coup

	func hab_billy_pour_ce_tour(combat, hab_billy_actuelle, tour):
		var coups_recus = 0
		for etat in combat.pile:
			if etat.degats_adversaire > 0:
				coups_recus += 1
		return maxi(0, hab_billy_actuelle - coups_recus * self.malus_par_coup)


# Nœud 421 : Billy ne peut pas perdre ce combat (0 PV n'est pas une
# defaite).
class Increvable extends Modificateur:
	func billy_peut_perdre(combat):
		return false


# Nœud 462 : l'adversaire porte une derniere attaque APRES avoir atteint
# 0 PV, avant que le combat ne se termine reellement.
class AttaquePosthume extends Modificateur:
	func effet_apres_tour(combat, etat_tour):
		if etat_tour.adversaire.pv <= 0:
			var resultat = combat.resolve_round(combat.hab_billy, combat.hab_adversaire, etat_tour.attack_die_roll)
			return {"adversaire": resultat['degats_adversaire']}
		return null


# Nœud 346 : l'Habileté adverse est entierement recalculee chaque tour
# via une formule aleatoire (1 + 1d6*2 pour ce nœud precis). "formule" =
# Callable()->int, injectee plutot que codee en dur (reutilisable si
# d'autres combats du Tome 2 ont une formule differente).
class HabiliteAdverseAleatoire extends Modificateur:
	var formule: Callable

	func _init(p_formule: Callable):
		self.formule = p_formule

	func hab_adversaire_pour_ce_tour(combat, hab_adversaire_actuelle, tour):
		return self.formule.call()


# Nœud 306/346 : l'Habileté adverse baisse de "perte_par_tour" a partir du
# tour "tour_de_debut" (inclus), un palier de plus par tour ecoule --
# distinct de HabiliteAdverseDegressiveParDegatsCumules (qui decroit avec
# les degats CUMULES infliges, pas avec le simple NUMERO de tour).
class HabiliteAdverseDecroissanteParTour extends Modificateur:
	var perte_par_tour: int
	var tour_de_debut: int

	func _init(p_perte_par_tour: int, p_tour_de_debut: int):
		self.perte_par_tour = p_perte_par_tour
		self.tour_de_debut = p_tour_de_debut

	func hab_adversaire_pour_ce_tour(combat, hab_adversaire_actuelle, tour):
		var decrements = maxi(0, tour - self.tour_de_debut + 1)
		return maxi(0, hab_adversaire_actuelle - decrements * self.perte_par_tour)


# Nœud 387 : si une condition externe est vraie (ex: Jet de Chance rate,
# determine par l'appelant HORS combat.gd), l'adversaire porte une
# attaque bonus non esquivable/non ripostable ce tour-la.
class AttaqueBonusSiConditionExterne extends Modificateur:
	var condition_vraie: bool
	var degats_bonus: int

	func _init(p_condition_vraie: bool, p_degats_bonus: int):
		self.condition_vraie = p_condition_vraie
		self.degats_bonus = p_degats_bonus

	func modifie_degats_bruts(combat, degats_billy, degats_adversaire, contexte):
		if self.condition_vraie:
			degats_adversaire += self.degats_bonus
		return [degats_billy, degats_adversaire]


# Nœuds 114/422 : en cas de mort simultanee, decide explicitement qui
# gagne plutot que "egalite" (114 : l'adversaire ; 422 : Billy perd).
class TrancheEgaliteSurMortSimultanee extends Modificateur:
	var gagnant: String

	func _init(p_gagnant: String):
		self.gagnant = p_gagnant

	func tranche_egalite(combat):
		return self.gagnant


# Nœud 534 (panthère invoquée) : l'adversaire ignore l'Armure de Billy
# sur ses propres attaques, et sa contre-attaque critique est totalement
# immunisee (cf ImmuniteContreAttaqueCritique). Sa propre puissance de
# frappe est reduite au debut du combat (malus qui se resorbe au fil des
# tours).
class Intangible extends Modificateur:
	var malus_initial: int
	var reduction_par_tour: int

	func _init(p_malus_initial: int, p_reduction_par_tour: int):
		self.malus_initial = p_malus_initial
		self.reduction_par_tour = p_reduction_par_tour

	func traitement_critique(combat, tour):
		return Modificateur.CRITIQUE_IMMUNITE_TOTALE

	func modifie_degats_bruts(combat, degats_billy, degats_adversaire, contexte):
		# play_turn soustrait armure_billy APRES ce hook -- on l'ajoute ici
		# pour que la soustraction s'annule et que l'Armure de Billy
		# n'ait au final aucun effet sur les degats_adversaire.
		degats_adversaire += combat.armure_billy
		var malus = maxi(0, self.malus_initial - self.reduction_par_tour * (contexte['tour'] - 1))
		degats_adversaire = maxi(0, degats_adversaire - malus)
		return [degats_billy, degats_adversaire]


# Nœud 475 (Virilus, phase 1) : chaque tour, un de SUPPLEMENTAIRE (le
# "Gant de Virilus") est lance en plus des phases d'attaque/esquive.
# "effets" = Dictionary {valeur_de: Callable(combat, etat_tour_en_cours)}
# ou une valeur speciale par tranche (1-3, 4-5, 6 dans le cas de ce
# nœud) -- injecte plutot que code en dur pour rester generique.
class DeSupplementaireParTour extends Modificateur:
	var de_roll: Callable  # Callable()->int, permet un jet fourni en test
	var effets: Dictionary  # {[1,2,3]: Callable, [4,5]: Callable, [6]: Callable} (cles = Array de valeurs)

	func _init(p_de_roll: Callable, p_effets: Dictionary):
		self.de_roll = p_de_roll
		self.effets = p_effets

	func effet_apres_tour(combat, etat_tour):
		var valeur = self.de_roll.call()
		for tranche in self.effets:
			if valeur in tranche:
				return self.effets[tranche].call(combat, etat_tour)
		return null


# =========================================================================
# Tome 2 (La Corne des Sables d'Ivoire) -- cf COMBATS_REGLES_SPECIALES_TOME2.md
# pour le detail nœud par nœud de qui utilise quoi.
# =========================================================================


# Nœuds 436 (Tome 2) : ajuste hab_billy/hab_adversaire/adresse_billy d'un
# delta (+/-) tant que le tour courant est <= dernier_tour. Generalise
# MalusHabiliteAdversePremierTourSeulement (Tome 1, dernier_tour fixe a 1)
# a une fenetre de tours et a 3 cibles possibles.
class AjustementTemporaireParTour extends Modificateur:
	var cible: String  # "hab_billy", "hab_adversaire" ou "adresse_billy"
	var delta: int
	var dernier_tour  # int ou null (null = pas de borne haute)
	var premier_tour  # int ou null (null = actif depuis le tour 1 -- nœud 73 : premier_tour=2, dernier_tour=null pour un malus PERMANENT a partir du tour 2)

	func _init(p_cible: String, p_delta: int, p_dernier_tour = null, p_premier_tour = null):
		self.cible = p_cible
		self.delta = p_delta
		self.dernier_tour = p_dernier_tour
		self.premier_tour = p_premier_tour

	func _actif(tour):
		if self.premier_tour != null and tour < self.premier_tour:
			return false
		if self.dernier_tour != null and tour > self.dernier_tour:
			return false
		return true

	func hab_billy_pour_ce_tour(combat, hab_billy_actuelle, tour):
		if self.cible == "hab_billy" and self._actif(tour):
			return maxi(0, hab_billy_actuelle + self.delta)
		return hab_billy_actuelle

	func hab_adversaire_pour_ce_tour(combat, hab_adversaire_actuelle, tour):
		if self.cible == "hab_adversaire" and self._actif(tour):
			return maxi(0, hab_adversaire_actuelle + self.delta)
		return hab_adversaire_actuelle

	func adresse_billy_pour_ce_tour(combat, adresse_billy_actuelle, tour):
		if self.cible == "adresse_billy" and self._actif(tour):
			return maxi(0, adresse_billy_actuelle + self.delta)
		return adresse_billy_actuelle


# Nœuds 31/40 (tous les tours), 197 (tous les 2 tours), 649 (adversaire,
# tous les 3 tours) : reduit hab_billy OU hab_adversaire de "perte" tous
# les "intervalle" tours, INDEPENDAMMENT des degats infliges -- distinct de
# HabiliteAdverseDegressiveParDegatsCumules (qui suit les degats cumules,
# pas le numero de tour) et de HabiliteAdverseDecroissanteParTour (qui
# decroit a partir d'un tour de debut donne, pas de facon periodique).
class DecroissanceParIntervalle extends Modificateur:
	var cible: String  # "hab_billy" ou "hab_adversaire"
	var perte: int
	var intervalle: int

	func _init(p_cible: String, p_perte: int, p_intervalle: int):
		self.cible = p_cible
		self.perte = p_perte
		self.intervalle = p_intervalle

	func hab_billy_pour_ce_tour(combat, hab_billy_actuelle, tour):
		if self.cible == "hab_billy":
			# (tour-1) et non tour : "a la fin de chaque tour" (nœud 31) veut
			# dire qu'aucune baisse n'affecte le tour 1 lui-meme, seulement
			# les tours suivants -- decrements=0 tant que tour<=intervalle.
			var decrements = int((tour - 1) / self.intervalle)
			return maxi(0, hab_billy_actuelle - decrements * self.perte)
		return hab_billy_actuelle

	func hab_adversaire_pour_ce_tour(combat, hab_adversaire_actuelle, tour):
		if self.cible == "hab_adversaire":
			var decrements = int((tour - 1) / self.intervalle)
			return maxi(0, hab_adversaire_actuelle - decrements * self.perte)
		return hab_adversaire_actuelle


# Nœud 11 (malus d'Habileté adverse permanent une fois l'ennemi sous un
# seuil de PV) et nœud 234 (malus d'Adresse de Billy actif seulement AVANT
# le seuil, retire une fois le seuil franchi) : ajuste hab_billy/
# hab_adversaire/adresse_billy d'un delta, actif avant OU apres le
# franchissement d'un seuil de PV adverses (au choix via avant_seuil).
class AjustementSeuilPV extends Modificateur:
	var seuil: int
	var cible: String  # "hab_billy", "hab_adversaire" ou "adresse_billy"
	var delta: int
	var avant_seuil: bool

	func _init(p_seuil: int, p_cible: String, p_delta: int, p_avant_seuil: bool = false):
		self.seuil = p_seuil
		self.cible = p_cible
		self.delta = p_delta
		self.avant_seuil = p_avant_seuil

	func _actif(combat):
		var sous_seuil = combat.pv_adversaire <= self.seuil
		return sous_seuil if !self.avant_seuil else !sous_seuil

	func hab_billy_pour_ce_tour(combat, hab_billy_actuelle, tour):
		if self.cible == "hab_billy" and self._actif(combat):
			return maxi(0, hab_billy_actuelle + self.delta)
		return hab_billy_actuelle

	func hab_adversaire_pour_ce_tour(combat, hab_adversaire_actuelle, tour):
		if self.cible == "hab_adversaire" and self._actif(combat):
			return maxi(0, hab_adversaire_actuelle + self.delta)
		return hab_adversaire_actuelle

	func adresse_billy_pour_ce_tour(combat, adresse_billy_actuelle, tour):
		if self.cible == "adresse_billy" and self._actif(combat):
			return maxi(0, adresse_billy_actuelle + self.delta)
		return adresse_billy_actuelle


# Nœud 234 : une fois l'ennemi sous la moitie de ses PV, le garde restant
# inflige un bonus de degats permanent (deg_adversaire n'a pas de hook
# per-tour dedie comme hab/adresse -- on passe donc par modifie_degats_bruts).
class BonusDegatsAdversaireApresSeuilPV extends Modificateur:
	var seuil: int
	var bonus: int

	func _init(p_seuil: int, p_bonus: int):
		self.seuil = p_seuil
		self.bonus = p_bonus

	func modifie_degats_bruts(combat, degats_billy, degats_adversaire, contexte):
		if !contexte['esquive'] and combat.pv_adversaire <= self.seuil:
			degats_adversaire += self.bonus
		return [degats_billy, degats_adversaire]


# Nœud 113 : une fois l'Elfe-panthère sous la moitie de ses PV, elle
# n'infligé plus son bonus de degats de base (deg_adversaire).
class SupprimeDegAdversaireApresSeuilPV extends Modificateur:
	var seuil: int

	func _init(p_seuil: int):
		self.seuil = p_seuil

	func modifie_degats_bruts(combat, degats_billy, degats_adversaire, contexte):
		if !contexte['esquive'] and combat.pv_adversaire <= self.seuil:
			degats_adversaire = maxi(0, degats_adversaire - combat.deg_adversaire)
		return [degats_billy, degats_adversaire]


# Nœud 113 : variante seuil-PV de EsquiveAdverseSurDe -- l'adversaire
# n'esquive l'attaque normale de Billy qu'une fois sous le seuil de PV.
class EsquiveAdverseSurDeApresSeuilPV extends Modificateur:
	var seuil: int
	var predicat: Callable

	func _init(p_seuil: int, p_predicat: Callable):
		self.seuil = p_seuil
		self.predicat = p_predicat

	func adversaire_esquive_attaque_normale(combat, attack_die_roll, tour):
		return combat.pv_adversaire <= self.seuil and self.predicat.call(attack_die_roll)


# Nœuds 180, 268 (tout le combat), 321 (premier tour seulement) : les
# degats supplementaires de Billy (deg_billy) se transforment en MALUS au
# lieu d'un bonus -- l'horreur/l'aberration du combat le perturbe. deg_billy
# est deja ajoute a degats_billy par play_turn AVANT ce hook (sauf
# contre-attaque critique ou esquive adverse normale) ; on retire donc 2x
# deg_billy pour transformer +N en -N.
class BonusDegatsBillyDevientMalus extends Modificateur:
	var numero_tour  # int ou null (null = actif tout le combat)

	func _init(p_numero_tour = null):
		self.numero_tour = p_numero_tour

	func modifie_degats_bruts(combat, degats_billy, degats_adversaire, contexte):
		if self.numero_tour != null and contexte['tour'] != self.numero_tour:
			return [degats_billy, degats_adversaire]
		if !contexte['contre_attaque_critique'] and !contexte['adversaire_esquive_normale']:
			degats_billy = maxi(0, degats_billy - 2 * combat.deg_billy)
		return [degats_billy, degats_adversaire]


# Nœud 225 : La Poigne Filante ne reçoit de degats que si l'attaque de
# Billy est comprise entre min_deg et max_deg INCLUS -- immunite totale en
# dehors de cette plage (pas un plafonnement/clampage).
class ImmuniteHorsPlageDegats extends Modificateur:
	var min_deg: int
	var max_deg: int

	func _init(p_min_deg: int, p_max_deg: int):
		self.min_deg = p_min_deg
		self.max_deg = p_max_deg

	func modifie_degats_bruts(combat, degats_billy, degats_adversaire, contexte):
		if degats_billy < self.min_deg or degats_billy > self.max_deg:
			degats_billy = 0
		return [degats_billy, degats_adversaire]


# Nœud 474 : si "condition" (typiquement un test de reflexes 2d6 <=
# Habileté, injecte par l'appelant/test) est vraie ce tour, le requin abattu
# ne porte pas son coup -- annule degats_adversaire pour ce tour uniquement.
class AdversaireNAttaquePasSiConditionParTour extends Modificateur:
	var condition: Callable  # Callable(tour) -> bool

	func _init(p_condition: Callable):
		self.condition = p_condition

	func modifie_degats_bruts(combat, degats_billy, degats_adversaire, contexte):
		if self.condition.call(contexte['tour']):
			degats_adversaire = 0
		return [degats_billy, degats_adversaire]


# Nœud 474 : plafonne les degats INFLIGES par Billy (symetrique de
# plafond_degats_subis_billy, deja existant sur Combat, mais cote sortant).
class PlafondDegatsInflige extends Modificateur:
	var plafond: int

	func _init(p_plafond: int):
		self.plafond = p_plafond

	func modifie_degats_bruts(combat, degats_billy, degats_adversaire, contexte):
		degats_billy = mini(degats_billy, self.plafond)
		return [degats_billy, degats_adversaire]


# Nœuds 250 (tout le combat), 282 (pose conditionnelle si les flammes ne
# sont pas neutralisees) : l'Armure de Billy n'a aucun effet contre cet
# adversaire. play_turn soustrait armure_billy APRES modifie_degats_bruts --
# on la rajoute donc ici pour annuler cette soustraction (meme technique que
# Intangible au Tome 1, extraite en classe autonome et reutilisable seule).
class IgnoreArmureBilly extends Modificateur:
	func modifie_degats_bruts(combat, degats_billy, degats_adversaire, contexte):
		degats_adversaire += combat.armure_billy
		return [degats_billy, degats_adversaire]


# Nœuds 630 (cible="adversaire" : degats infliges par Billy divises par 2
# sur un jet impair), 689 (cible="billy" : tous les degats subis par Billy
# divises par 2, sans condition) -- division entiere (floor), meme
# convention cible que DegatsPeriodiques (cible="billy" affecte ce que
# Billy REÇOIT, cible="adversaire" affecte ce que Billy INFLIGE).
class DivisionDegats extends Modificateur:
	var cible: String  # "billy" ou "adversaire"
	var diviseur: int
	var condition  # Callable(attack_die_roll) -> bool, ou null = toujours actif

	func _init(p_cible: String, p_diviseur: int, p_condition = null):
		self.cible = p_cible
		self.diviseur = p_diviseur
		self.condition = p_condition

	func modifie_degats_bruts(combat, degats_billy, degats_adversaire, contexte):
		if self.condition != null and !self.condition.call(contexte['attack_die_roll']):
			return [degats_billy, degats_adversaire]
		if self.cible == "adversaire":
			degats_billy = degats_billy / self.diviseur
		else:
			degats_adversaire = degats_adversaire / self.diviseur
		return [degats_billy, degats_adversaire]


# Nœud 514 : Frère Plouf arbitre le combat et permet de suspendre, au choix
# de Billy au debut de chaque tour, UNE des 3 regles du Gardien -- plutot que
# de dupliquer chaque regle en variante "suspendable", ce decorateur rend
# N'IMPORTE QUEL Modificateur existant activable/desactivable tour par tour.
# "condition" recoit (combat, tour) et renvoie true si le Modificateur
# interieur doit s'appliquer CE tour (false = comportement neutre, comme si
# le Modificateur interieur etait absent).
#
# ATTENTION (trouve en ecrivant les tests) : ce decorateur transmet TOUS les
# hooks vers "condition", meme ceux que le Modificateur interieur n'implemente
# meme pas (ex: envelopper un DegatsPeriodiques -- qui n'override QUE
# effet_apres_tour -- appelle quand meme condition() depuis
# hab_billy_pour_ce_tour/modifie_degats_bruts/etc, sans consequence sur le
# resultat mais l'APPEL a lieu). "condition" doit donc etre ecrite de facon
# DEFENSIVE (ex: verifier combat.pile.size() > 0 avant de lire
# combat.pile[combat.pile.size()-1]) plutot que de supposer qu'elle n'est
# invoquee que depuis le hook qui nous interesse -- au 1er tour, avant que le
# nouvel EtatTour ne soit empile, combat.pile peut encore etre vide.
class ModificateurConditionnel extends Modificateur:
	var interieur: Modificateur
	var condition: Callable

	func _init(p_interieur: Modificateur, p_condition: Callable):
		self.interieur = p_interieur
		self.condition = p_condition

	func hab_adversaire_pour_ce_tour(combat, hab_adversaire_actuelle, tour):
		if self.condition.call(combat, tour):
			return self.interieur.hab_adversaire_pour_ce_tour(combat, hab_adversaire_actuelle, tour)
		return hab_adversaire_actuelle

	func adresse_billy_pour_ce_tour(combat, adresse_billy_actuelle, tour):
		if self.condition.call(combat, tour):
			return self.interieur.adresse_billy_pour_ce_tour(combat, adresse_billy_actuelle, tour)
		return adresse_billy_actuelle

	func hab_billy_pour_ce_tour(combat, hab_billy_actuelle, tour):
		if self.condition.call(combat, tour):
			return self.interieur.hab_billy_pour_ce_tour(combat, hab_billy_actuelle, tour)
		return hab_billy_actuelle

	func adversaire_esquive_attaque_normale(combat, attack_die_roll, tour):
		if self.condition.call(combat, tour):
			return self.interieur.adversaire_esquive_attaque_normale(combat, attack_die_roll, tour)
		return false

	func modifie_degats_bruts(combat, degats_billy, degats_adversaire, contexte):
		if self.condition.call(combat, contexte['tour']):
			return self.interieur.modifie_degats_bruts(combat, degats_billy, degats_adversaire, contexte)
		return [degats_billy, degats_adversaire]

	func traitement_critique(combat, tour):
		if self.condition.call(combat, tour):
			return self.interieur.traitement_critique(combat, tour)
		return Modificateur.CRITIQUE_NORMAL

	func effet_apres_tour(combat, etat_tour):
		if self.condition.call(combat, etat_tour.tour):
			return self.interieur.effet_apres_tour(combat, etat_tour)
		return null

	func vainqueur_force(combat):
		if self.condition.call(combat, combat.tour):
			return self.interieur.vainqueur_force(combat)
		return null

	func tranche_egalite(combat):
		if self.condition.call(combat, combat.tour):
			return self.interieur.tranche_egalite(combat)
		return null

	func billy_peut_perdre(combat):
		if self.condition.call(combat, combat.tour):
			return self.interieur.billy_peut_perdre(combat)
		return true


# Nœud 256 (Mimine) : Mimine cesse le combat (victoire de Billy) dès que
# "n_requis" tours consecutifs ont un attack_die_roll de la meme parite --
# derive de combat.pile (donc undo-safe), pas d'un compteur interne.
class FinCombatSurParitesConsecutives extends Modificateur:
	var n_requis: int

	func _init(p_n_requis: int = 3):
		self.n_requis = p_n_requis

	func vainqueur_force(combat):
		var pile = combat.pile
		if pile.size() < self.n_requis:
			return null
		var derniere_parite = pile[pile.size() - 1].attack_die_roll % 2
		for i in range(1, self.n_requis):
			if pile[pile.size() - 1 - i].attack_die_roll % 2 != derniere_parite:
				return null
		return "billy"


# Nœud 323 (Gardien surpris) : un jet de de DEDIE (injecte par callable,
# comme HabiliteAdverseAleatoire) est lance avant chaque phase d'attaque et
# pilote 4 branches. Les 3 hooks utilises pour un meme tour (Habileté de
# Billy, degats, effet apres tour) doivent voir la MEME valeur -- mais
# l'undo/rejeu doit quand meme provoquer un VRAI nouveau jet, pas la valeur
# figee de la tentative precedente. Solution : hab_billy_pour_ce_tour est
# le PREMIER hook appele par play_turn() a CHAQUE invocation reelle (rejeu
# ou pas) -- c'est donc lui, et lui seul, qui relance le de et met a jour
# _valeur_courante ; les 2 hooks suivants (modifie_degats_bruts,
# effet_apres_tour) ne font que LIRE cette valeur pour rester coherents
# avec le meme tirage DANS le meme appel a play_turn(). Contrairement a un
# cache par numero de tour, ceci relance bien a chaque appel reel, y
# compris un rejeu apres annulation.
class EvenementAleatoireGardienSurpris extends Modificateur:
	var de_roll: Callable
	var _valeur_courante: int = 0

	func _init(p_de_roll: Callable):
		self.de_roll = p_de_roll

	func hab_billy_pour_ce_tour(combat, hab_billy_actuelle, tour):
		self._valeur_courante = self.de_roll.call()
		var v = self._valeur_courante
		if v == 2 or v == 3:
			return maxi(0, hab_billy_actuelle - 2)
		elif v == 4 or v == 5:
			return hab_billy_actuelle + 2
		return hab_billy_actuelle

	func modifie_degats_bruts(combat, degats_billy, degats_adversaire, contexte):
		if self._valeur_courante == 6:
			degats_billy += 2
			degats_adversaire = 0
		return [degats_billy, degats_adversaire]

	func effet_apres_tour(combat, etat_tour):
		if self._valeur_courante == 1:
			return {"adversaire": 2}
		return null


# Nœud 225 (La Poigne Filante) : l'adversaire attaque DEUX fois par tour,
# "2 fois les mêmes dommages" -- la 2eme attaque reutilise donc le MEME
# montant que la 1ere (etat_tour.degats_adversaire, deja finalise :
# esquive/Armure/plafond de la 1ere attaque deja appliques), mais avec sa
# PROPRE esquive independante (chacune esquivable separement) et JAMAIS de
# contre-attaque critique (pas de jet de 1 traite ici, contrairement a la
# 1ere attaque). Le jet d'esquive dedie est injecte via un Callable (comme
# EvenementAleatoireGardienSurpris) plutot que d'etendre la signature de
# play_turn() avec un second parametre -- simplification retenue plutot
# que deux jets d'attaque bruts totalement independants, fidele au texte
# ("memes dommages") qui rend cette simplification exacte, pas approximative.
class DoubleAttaqueAdverse extends Modificateur:
	var esquive_die_roll: Callable  # Callable()->int, jet d'esquive DEDIE a la 2eme attaque

	func _init(p_esquive_die_roll: Callable):
		self.esquive_die_roll = p_esquive_die_roll

	func effet_apres_tour(combat, etat_tour):
		if etat_tour.degats_adversaire <= 0:
			return null
		var jet = self.esquive_die_roll.call()
		if jet <= combat.adresse_billy:
			return null
		return {"adversaire": etat_tour.degats_adversaire}


# Nœud 16 : l'ennemi commence le combat avec un malus d'Habileté qui se
# resorbe au fil des tours (miroir de Intangible/nœud 534 -- decroissance
# lineaire par NUMERO de tour -- mais applique a l'Habileté adverse, pas
# aux degats). Formule live (tour parametre direct), undo-safe par
# construction : aucun compteur interne.
class HabiliteAdverseMalusDecroissantParTour extends Modificateur:
	var malus_initial: int
	var reduction_par_tour: int

	func _init(p_malus_initial: int, p_reduction_par_tour: int):
		self.malus_initial = p_malus_initial
		self.reduction_par_tour = p_reduction_par_tour

	func hab_adversaire_pour_ce_tour(combat, hab_adversaire_actuelle, tour):
		var malus = maxi(0, self.malus_initial - self.reduction_par_tour * (tour - 1))
		return maxi(0, hab_adversaire_actuelle - malus)


# Nœud 68 : le bonus du Pyro-Barbare (deja ajoute a hab_billy a la
# construction de Combat, cf pyro_bonus) est suspendu pour UN tour precis.
class SansBonusPyroTour extends Modificateur:
	var numero_tour: int

	func _init(p_numero_tour: int):
		self.numero_tour = p_numero_tour

	func hab_billy_pour_ce_tour(combat, hab_billy_actuelle, tour):
		if tour == self.numero_tour:
			return maxi(0, hab_billy_actuelle - combat.pyro_bonus)
		return hab_billy_actuelle


# Nœud 649 (bénédiction de Neit) : Billy esquive TOTALEMENT les degats
# adverses ce tour si le jet d'ATTAQUE (pas un jet d'esquive dedie) verifie
# le predicat -- contrairement a EsquiveAdverseSurDe (qui annule les degats
# de BILLY quand l'ADVERSAIRE esquive), cette classe annule les degats
# subis PAR Billy, sans jamais passer par le mecanisme d'esquive normal
# (adresse_billy/esquive_die_roll).
class BillyEsquiveAttaqueSurDe extends Modificateur:
	var predicat: Callable

	func _init(p_predicat: Callable):
		self.predicat = p_predicat

	func modifie_degats_bruts(combat, degats_billy, degats_adversaire, contexte):
		if self.predicat.call(contexte['attack_die_roll']):
			degats_adversaire = 0
		return [degats_billy, degats_adversaire]


# Nœud 686 (Avatar de Vetherr) : quand le rayon touche (degats_adversaire
# bruts > 0), il infligé un montant FIXE "absolu" a la place de la valeur de
# la Table des Situations (au lieu d'esquiver completement quand il rate).
class DegatsAdverseFixesSiTouche extends Modificateur:
	var montant: int

	func _init(p_montant: int):
		self.montant = p_montant

	func modifie_degats_bruts(combat, degats_billy, degats_adversaire, contexte):
		if degats_adversaire > 0:
			degats_adversaire = self.montant
		return [degats_billy, degats_adversaire]


# Nœud 514 (règle des "lames dentelées", rendue suspendable par Frère
# Plouf via ModificateurConditionnel) : bonus de degats_adversaire FIXE et
# inconditionnel (hors esquive), distinct de BonusDegatsAdversaireApresSeuilPV
# qui necessite un seuil de PV -- ici aucune condition, juste "+bonus" tant
# que Billy n'esquive pas.
class BonusDegatsAdversaireFixe extends Modificateur:
	var bonus: int

	func _init(p_bonus: int):
		self.bonus = p_bonus

	func modifie_degats_bruts(combat, degats_billy, degats_adversaire, contexte):
		if !contexte['esquive']:
			degats_adversaire += self.bonus
		return [degats_billy, degats_adversaire]


# Nœud 584 (PRUDENT) : si une condition externe (typiquement un Jet de
# Chance, hors combat.gd) reussit CE TOUR (verifiee a CHAQUE tour, pas une
# seule fois pour tout le combat -- contrairement a
# AttaqueBonusSiConditionExterne qui prend un booleen fixe a la
# construction), les degats infliges par Billy sont multiplies.
class MultiplieDegatsSiConditionExterne extends Modificateur:
	var condition: Callable  # Callable(tour) -> bool
	var multiplicateur: int

	func _init(p_condition: Callable, p_multiplicateur: int):
		self.condition = p_condition
		self.multiplicateur = p_multiplicateur

	func modifie_degats_bruts(combat, degats_billy, degats_adversaire, contexte):
		if self.condition.call(contexte['tour']):
			degats_billy *= self.multiplicateur
		return [degats_billy, degats_adversaire]
