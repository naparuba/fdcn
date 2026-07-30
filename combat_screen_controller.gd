extends RefCounted

# Couche fine entre l'ecran de combat (Combat.gd, noeuds/animations) et le
# moteur de resolution (combat.gd, deja teste). Aucune logique de regle ici
# -- seulement ce qu'il faut pour piloter l'ecran : previsualisation par
# face avant de lancer le de, et "revenir avant le tour N" (undo repete)
# pour la strip de tours cliquable. Cf SPEC_ECRAN_COMBAT.md.

const CombatEngine = preload('res://combat.gd')

var combat


func _init(hab_billy, hab_adversaire, pv_billy, pv_adversaire, opts = {}):
	self.combat = CombatEngine.new(hab_billy, hab_adversaire, pv_billy, pv_adversaire, opts)


func is_resolved() -> bool:
	return self.combat.is_over()


func get_winner():
	return self.combat.get_winner()


func peut_esquiver() -> bool:
	return self.combat.peut_esquiver()


func peut_annuler() -> bool:
	return self.combat.peut_annuler_dernier_tour()


# Le tour qui sera joue au PROCHAIN appel de jouer_tour() (1 si aucun tour
# n'a encore ete joue).
func prochain_tour() -> int:
	return self.combat.tour + 1


func etat_courant():
	return self.combat.etat_courant()


# Ce que Billy infligerait/subirait pour une face d'ATTAQUE donnee au
# PROCHAIN tour, en supposant qu'il n'esquive pas (l'esquive tire son
# propre de, separe -- cf combat.gd -- donc hors de cette previsualisation
# par construction). Recalcule les stats effectives pour ce tour a venir
# via combat.gd::stats_effectives_pour_tour() -- pas etat_courant(), qui ne
# reflete que le DERNIER tour DEJA joue et serait perime juste apres qu'un
# palier de Modificateur vienne d'etre franchi.
func previsualisation(face: int) -> Dictionary:
	assert(face >= 1 and face <= 6, "face doit etre entre 1 et 6")
	var stats = self.combat.stats_effectives_pour_tour(self.prochain_tour())
	var res = CombatEngine.resolve_round(stats['hab_billy'], stats['hab_adversaire'], face)
	var dmg_ennemi = res['degats_billy'] + self.combat.deg_billy
	var dmg_billy = maxi(0, res['degats_adversaire'] - self.combat.armure_billy)
	return {"dmg_ennemi": dmg_ennemi, "dmg_billy": dmg_billy}


# Joue un tour complet (les deux des si non fournis -- utile pour des
# tests deterministes). Retourne l'EtatTour empile, ou null si le combat
# est deja termine.
func jouer_tour(attack_die = null, esquive_die = null):
	if self.is_resolved():
		return null
	return self.combat.play_turn(attack_die, esquive_die)


func annuler_dernier_tour():
	return self.combat.undo_last_turn()


# Depile jusqu'a ce que le tour courant soit strictement avant "numero_tour"
# -- permet a la strip de tours de proposer "revenir avant N'IMPORTE QUEL
# tour joue", pas seulement le dernier. Pas d'effet si numero_tour est deja
# dans le futur ou si la pile est vide.
func revenir_avant_tour(numero_tour: int) -> void:
	while self.combat.tour >= numero_tour and self.combat.peut_annuler_dernier_tour():
		self.combat.undo_last_turn()
