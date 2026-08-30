class_name CombatAssaultResolver
extends RefCounted
## Calcule le résultat d'UN assaut, à partir des dés déjà mémorisés par `CombatEngine` et de
## la ligne de frise qui correspond à l'écart — sans rien écrire nulle part : `CombatEngine.
## resolve()` applique le résultat (pv de l'ennemi, tour, adversaire suivant, pv du joueur)
## une fois ce calcul terminé. Extrait de `CombatEngine::resolve()` (review-code.md 4.1) pour
## se lire comme une fonction pure plutôt que noyé dans l'orchestration d'un autoload.
##
## POUR AJOUTER UNE RÈGLE (un 5ᵉ pouvoir de CARACTÈRE, une 3ᵉ forme d'esquive) : écrire une
## méthode `_etape_xxx(a: Assaut) -> void` qui lit/écrit les champs d'`Assaut` qui la
## concernent, puis l'ajouter à la liste dans `resolve()`. ⚠️ **L'ORDRE COMPTE** — chaque
## étape explique pourquoi elle vient après celle d'avant (armure après esquive, plafond du
## PAYSAN après armure, coup fatal évité après le plafond, survie du PRUDENT en tout
## dernier) : ce n'est pas une liste de plugins indépendants, une nouvelle règle doit être
## positionnée en connaissance de cause vis-à-vis des autres, pas juste ajoutée en fin de
## liste sans y réfléchir.


## Tout ce qu'un assaut lit et produit, réuni pour ne pas se passer sept paramètres entre les
## étapes. `CombatEngine.resolve()` remplit les entrées depuis son propre état ; chaque étape
## complète `infliges`/`recus`/`ignore_armure`/`rapport`.
class Assaut:
	# Entrées, posées par CombatEngine.resolve() avant l'appel :
	var enemy: Dictionary
	var enemy_pv_avant: int
	var de: int
	var de_esquive: int
	var ecart: int
	## Vrai si `CombatEngine.dodge_with_chance()` a déjà été payé pour cet assaut.
	var esquive_chance_payee: bool
	var billy_type: String
	var dice_roller: Callable
	var base: Array  ## [infliges, recus] lus dans la frise pour `ecart`/`de`
	var max_degats_ecart: int  ## frise, colonne infligés, dé 6 — pour la contre-attaque critique

	# Calcul, rempli par les étapes ci-dessous :
	var infliges: int
	var recus: int
	var ignore_armure := false
	## Le rapport de `CombatEngine.resolve()`, déjà rempli de ses champs par défaut
	## (`esquive_tentee`, `de`, `ecart`, ...) — les étapes n'y ajoutent que ce qui leur
	## revient.
	var rapport: Dictionary


## Renvoie `a.rapport`, complété de `degats_infliges`/`degats_recus` et de tout ce que les
## étapes y auront ajouté (`critique`, `esquive_reussie`, `esquive_chance`,
## `coup_fatal_evite`, `de_survie`, `pouvoirs`).
func resolve(a: Assaut) -> Dictionary:
	# Les chiffres de la frise sont une BASE : les dégâts supplémentaires s'ajoutent
	# par-dessus, et l'armure se retire ensuite (review-combat.md §3.10 étape 5).
	a.infliges = a.base[0] + PlayerStats.get_stat("deg")
	a.recus = a.base[1] + a.enemy["deg"]

	_etape_esquive_adresse(a)
	_etape_esquive_chance_prudent(a)
	_etape_armure(a)
	_etape_plafond_paysan(a)
	_etape_coup_fatal_evite(a)
	_etape_survie_prudent(a)

	a.rapport["degats_infliges"] = a.infliges
	a.rapport["degats_recus"] = a.recus
	return a.rapport


## Esquive à l'ADRESSE : ouverte à tous ceux qui ont adr ≥ 2 (`CombatEngine.can_dodge()`),
## et qui **peut rater**. Un 1 est une contre-attaque critique (dégâts maximaux de l'écart,
## armure ignorée, rien d'encaissé) ; un dé ≤ adresse sans être 1 n'annule que ce qu'on
## encaisse.
func _etape_esquive_adresse(a: Assaut) -> void:
	if a.de_esquive == 0:
		return
	if a.de_esquive == 1:
		a.rapport["critique"] = true
		a.rapport["esquive_reussie"] = true
		a.infliges = a.max_degats_ecart + PlayerStats.get_stat("crit")
		a.ignore_armure = true
		a.recus = 0
	elif a.de_esquive <= PlayerStats.get_stat("adr"):
		a.rapport["esquive_reussie"] = true
		a.recus = 0


## L'esquive à la chance du PRUDENT est payée D'AVANCE (`CombatEngine.dodge_with_chance()`)
## et ne peut pas rater : elle annule ce qu'on encaisse, sans rien changer à ce qu'on
## infligera. Placée après l'esquive à l'adresse pour qu'une contre-attaque critique garde
## tous ses effets même si l'esquive à la chance était aussi payée sur le même assaut.
func _etape_esquive_chance_prudent(a: Assaut) -> void:
	if not a.esquive_chance_payee:
		return
	a.rapport["esquive_chance"] = true
	a.rapport["pouvoirs"].append("prudent")
	a.recus = 0


## L'armure se retire après l'esquive : si `recus` est déjà à 0, retirer l'armure du joueur
## ne changerait rien. L'armure de l'ennemi ne s'applique pas si `ignore_armure` (la
## contre-attaque critique l'a déjà décidé).
func _etape_armure(a: Assaut) -> void:
	if not a.ignore_armure:
		a.infliges -= a.enemy["arm"]
	if a.recus > 0:
		a.recus -= PlayerStats.get_stat("arm")
	a.infliges = maxi(a.infliges, 0)
	a.recus = maxi(a.recus, 0)


## Après l'armure : le plafond du PAYSAN s'applique au résultat final, pas à un chiffre
## intermédiaire qui pourrait encore changer derrière lui.
func _etape_plafond_paysan(a: Assaut) -> void:
	if a.recus > CombatEngine.PAYSAN_DEGATS_MAX and a.billy_type == "paysan":
		a.recus = CombatEngine.PAYSAN_DEGATS_MAX
		a.rapport["pouvoirs"].append("paysan")


## Coups simultanés : si l'ennemi tombe sur CET assaut, ses derniers dégâts ne comptent pas
## — on l'a tué avant qu'ils ne portent. Après le plafond du PAYSAN (sur le chiffre qu'il
## encaisserait vraiment) ; avant la survie du PRUDENT, pour ne pas dépenser un jet de
## survie sur un coup qui n'arrivera jamais.
func _etape_coup_fatal_evite(a: Assaut) -> void:
	if a.recus > 0 and a.enemy_pv_avant - a.infliges <= 0:
		a.recus = 0
		a.rapport["coup_fatal_evite"] = true


## Le PRUDENT survit à un coup mortel : un lancer de dé « après la mort », réussi si le dé
## ne dépasse pas la chance courante. Renvoie les dégâts à appliquer réellement — survivre
## veut dire tomber à 1 pv, pas annuler le coup. En tout dernier : c'est la dernière chance
## d'annuler des dégâts, seulement si rien avant elle n'y est déjà arrivé.
##
## ⚠️ Le jet ne **consomme pas** de chance : c'est décrit comme un simple lancer. Si
## c'était un « tentez votre chance » classique (qui décrémente), c'est ici et nulle
## part ailleurs qu'il faudrait ajouter `PlayerStats.del_chance(1)`.
##
## ⚠️⚠️ **À CONFIRMER (2026-08-12).** Cette règle vient de la question 14 de
## `review-combat.md`, où elle a été décrite comme un jet après la mort. L'énoncé des quatre
## pouvoirs de Billy donné depuis ne la mentionne pas : le PRUDENT y a « la chance pour
## esquiver une attaque ou le combat », rien de plus. Elle est donc **conservée telle
## quelle** — supprimer une règle demandée n'est pas à moi de le décider — mais elle donne
## aujourd'hui **trois** pouvoirs au PRUDENT. Trois lectures possibles : elle reste (il est
## le survivant), elle disparaît, ou elle devient générale (tout Billy tente de survivre).
## Un mot suffit.
func _etape_survie_prudent(a: Assaut) -> void:
	if not (a.recus > 0 and a.recus >= PlayerStats.get_pv()):
		return
	if a.billy_type != "prudent":
		return
	var de_survie = a.dice_roller.call()
	a.rapport["de_survie"] = de_survie
	if de_survie > PlayerStats.get_cha():
		return
	a.rapport["pouvoirs"].append("prudent")
	a.recus = PlayerStats.get_pv() - 1
