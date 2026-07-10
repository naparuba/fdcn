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

	func _init(p_intervalle: int, p_degats: int, p_cible: String = "billy",
			p_esquivable: bool = false, p_une_seule_fois: bool = false):
		self.intervalle = p_intervalle
		self.degats = p_degats
		self.cible = p_cible
		self.esquivable = p_esquivable
		self.une_seule_fois = p_une_seule_fois

	func effet_apres_tour(combat, etat_tour):
		var declenche = false
		if self.une_seule_fois:
			declenche = etat_tour.tour == self.intervalle
		else:
			declenche = etat_tour.tour % self.intervalle == 0
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

	func _init(p_numero_tour: int = 1):
		self.numero_tour = p_numero_tour

	func modifie_degats_bruts(combat, degats_billy, degats_adversaire, contexte):
		if contexte['tour'] == self.numero_tour:
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
