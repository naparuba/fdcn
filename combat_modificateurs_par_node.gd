extends RefCounted

const Mods = preload('res://combat_modificateurs.gd')
const CombatEngine = preload('res://combat.gd')

# Registre node_id -> Array[Modificateur], SEPARE PAR LIVRE (les numeros de
# nœud ne sont PAS uniques entre les deux tomes -- ex: le nœud 321 existe
# dans les deux avec un sens totalement different, cf _tome1()/_tome2()
# ci-dessous). Avant ce fichier, aucun code applicatif ne construisait ces
# instances de Modificateur en dehors des tests -- combat_modificateurs.gd
# ne contient que les classes, jamais reliees a un vrai node_id
# (PR16_RECOVERY_PLAN.md §0). main.gd appelle for_node() et passe le
# resultat dans opts["modificateurs"] de Combat.new().
#
# PORTEE : uniquement les nœuds dont la construction est verrouillee par un
# test dedie dans test_combat_regles_speciales_tome1.gd/_tome2.gd (56 nœuds
# au total, cf le comptage du plan). Quelques nœuds partagent la classe/les
# parametres exacts d'un nœud-frere deja teste mais n'ont pas leur propre
# fonction de test (40, 155, 268, 518) -- chacun documente ci-dessous,
# valeurs confirmees par COMBATS_REGLES_SPECIALES(_TOME2).md, jamais
# inventees.
#
# EXCLUS DELIBEREMENT de ce registre (todo, pas fait ici) :
# - 36/97 : la variante "surpris" (limite de tours etendue a 8, via les
#   INFOS du joueur) n'a pas de seuil d'INFOS determinable depuis les tests
#   ou les docs consultes -- seule la variante par defaut (non surpris) est
#   cablee. 97 lui-meme n'a QUE son brasier periodique cable ici : la
#   LimiteDeTours evoquee dans l'en-tete de classe pour ce nœud n'a aucune
#   fonction test_node97_limite_de_tours dediee (contrairement a 36) --
#   parametre non verrouille par un test, donc absent d'ici.
# - 306 : mentionne en commentaire (combat_modificateurs.gd) comme motivant
#   la creation de HabiliteAdverseDecroissanteParTour, mais AUCUNE fonction
#   test_node306 n'existe -- pas dans le compte des 56 nœuds du plan.
# - 475/607 (Virilus, combat final) : DeSupplementaireParTour (le "Gant de
#   Virilus") n'est exerce par AUCUN test -- construire ses parametres a la
#   main serait du code de production non verrouille, contraire a la
#   discipline du projet. Les deux nœuds necessitent en plus un CHAINAGE
#   D'ETAT entre deux instances Combat successives (malus d'Habileté
#   applique en phase 1 a ne pas cumuler en phase 2 si l'armee de
#   squelettes est detruite) : une orchestration cote main.gd qui n'existe
#   pas non plus aujourd'hui (cf COMBATS_REGLES_SPECIALES.md, note d'archi
#   en tete du fichier). Seule ImmuniteContreAttaqueCritique (testee
#   isolement pour 475) serait triviale a cabler, mais la cabler SEULE sans
#   le Gant donnerait un combat partiellement correct qui semblerait fini --
#   pire qu'une absence totale, donc les deux nœuds restent hors registre.
# - Les ajustements FIXES d'Arme/Adresse "cote appelant" documentes dans
#   COMBATS_REGLES_SPECIALES(_TOME2).md (ex: -1 a -3 Adresse d'encerclement
#   aux nœuds 155/518, ARC ineqippable/+2 degats Morgenstern aux nœuds
#   squelettes 76/155/231/370/518) : un DEUXIEME sous-systeme manquant,
#   totalement distinct de ce registre de Modificateurs (ce ne sont pas des
#   classes Modificateur -- l'appelant est cense calculer directement la
#   stat finale et la passer a Combat.new()). Decouvert en construisant ce
#   registre, decision explicite de l'utilisateur (session du 2026-09-01) :
#   hors perimetre ici, a traiter separement.
#
# 5 nœuds ont une regle qui depend d'un etat que combat.gd/main.gd ne
# peuvent pas determiner aujourd'hui (resultat d'un Jet de Chance retente
# CHAQUE tour, un test de reflexes, ou un choix narratif fait PENDANT le
# combat -- aucune UI existante pour capturer quoi que ce soit de tout ca).
# Cables ci-dessous avec la condition gelee a sa valeur NEUTRE : la regle
# de BASE du nœud s'applique normalement, seul l'effet EXCEPTIONNEL
# (conditionne par l'etat manquant) ne se declenche jamais -- ni pire ni
# meilleur qu'aujourd'hui (rien n'etait cable), decision explicite de
# l'utilisateur (session du 2026-09-01) plutot que de bloquer sur une UI de
# Jet de Chance/choix a construire :
# - 387 (Tome 1) : AttaqueBonusSiConditionExterne -- Jet de Chance rate.
# - 474 (Tome 2) : AdversaireNAttaquePasSiConditionParTour -- test de
#   reflexes 2d6, explicitement "cote appelant" dans le commentaire du test
#   (PlafondDegatsInflige, la 2eme regle du meme nœud, N'A rien d'externe et
#   reste cablee normalement).
# - 514 (Tome 2) : les 3 regles du Gardien de la Necropole que Frere Plouf
#   permet de suspendre (une par tour, au choix de Billy) -- jamais figees,
#   donc cablees ici comme TOUJOURS ACTIVES (etat neutre = rien n'est
#   jamais suspendu). Le volet Khazin du meme nœud N'A rien d'externe
#   (KHAZIN est un vrai item suivi par Player.possessed_items) et reste
#   conditionne normalement plus bas.
# - 584 (Tome 2) : MultiplieDegatsSiConditionExterne -- Jet de Chance
#   reevalue CHAQUE tour.
# - 686 (Tome 2) : AttaqueBonusSiConditionExterne -- choix volontaire
#   d'encaisser le rayon (DegatsAdverseFixesSiTouche, la 1ere regle du meme
#   nœud, N'A rien d'externe et reste cablee normalement).
#
# (339 depend AUSSI d'un etat additionnel -- mais contrairement aux 5
# ci-dessus, c'est un OBJET reellement suivi par Player.possessed_items
# ("PETIT MEDAILLON" ou "MEDAILLON DE RUNIR") : verifiable directement,
# donc cable normalement, pas dans le lot "neutre". Meme chose pour 240,
# LANCE/ARC, et l'archetype de Billy pour 576/630, AppParameters.get_billy_type().)


static func for_node(book_number: int, node_id: int) -> Array:
	if book_number == 1:
		return _tome1(node_id)
	elif book_number == 2:
		return _tome2(node_id)
	return []


static func _tome1(node_id: int) -> Array:
	match node_id:
		36:
			# "Massacre" -- variante par defaut (non surpris), cf note en tete
			# de fichier pour la variante "surpris" (8 tours) non cablee ici.
			return [Mods.LimiteDeTours.new(5, "adversaire")]
		76, 231:
			# 76 "squelettes", 231 "4 hommes d'armes" -- meme mecanique exacte.
			return [Mods.HabiliteAdverseDegressiveParDegatsCumules.new(4, 1)]
		97:
			# "Massacre" (brasier) -- cf note en tete pour la LimiteDeTours de
			# ce meme nœud, non testee, absente d'ici.
			return [Mods.DegatsPeriodiques.new(3, 3, "billy", false, false)]
		114, 422:
			# 114 "orc esclavagiste", 422 (miroir) -- l'adversaire gagne en cas
			# de mort simultanee.
			return [Mods.TrancheEgaliteSurMortSimultanee.new("adversaire")]
		155:
			# "5 GUERRIERS SQUELETTES" -- meme mecanique que 76 (cf
			# COMBATS_REGLES_SPECIALES.md, ligne "identique au nœud 76"),
			# aucune fonction test_node155 dediee. Le malus de -1 Adresse
			# d'encerclement documente pour ce nœud est un ajustement cote
			# appelant, hors perimetre (cf note en tete).
			return [Mods.HabiliteAdverseDegressiveParDegatsCumules.new(4, 1)]
		162:
			return [Mods.ContreAttaqueCritiqueSansBonusCritique.new()]
		173:
			return [Mods.EsquiveAdverseSurDe.new(func(d): return d == 1 or d == 2)]
		175:
			return [Mods.EsquiveAdverseSurDe.new(func(d): return d % 2 == 0)]
		240:
			# "Lorsque la créature atteint 3 PV ou moins, mettez fin du
			# combat" + esquive sur 1/2/3 SAUF si Billy porte la LANCE ou
			# l'ARC (LANCE/ARC = vrais items reels, verifiables directement --
			# contrairement aux 6 nœuds "condition externe" de la note en
			# tete, aucune UI manquante ici).
			var esquive_sauf_lance_arc = func(d):
				return d in [1, 2, 3] and !(Player.have_item('LANCE') or Player.have_item('ARC'))
			return [
				Mods.EsquiveAdverseSurDe.new(esquive_sauf_lance_arc),
				Mods.SeuilPV.new(3, "fin_combat_victoire"),
			]
		276:
			return [Mods.ImmuniteContreAttaqueCritique.new()]
		286:
			return [Mods.DegatsPeriodiques.new(1, 1, "billy", false, false)]
		320:
			return [
				Mods.EsquiveAdverseSurDe.new(func(d): return d % 2 == 1),
				Mods.BonusDegatsAdversaireSurDe.new([1], 2),
			]
		321:
			return [
				Mods.EsquiveAdverseSurDe.new(func(d): return d % 2 == 1),
				Mods.SansAttaqueTour.new(1),
			]
		339:
			# "Si vous avez le petit médaillon d'Atella ou le médaillon de
			# RUNIR, sa régénération est annulée" -- deux vrais items,
			# verifiables directement (contrairement aux 6 nœuds "condition
			# externe" de la note en tete).
			var possede_medaillon = Player.have_item('PETIT MEDAILLON') or Player.have_item('MEDAILLON DE RUNIR')
			return [Mods.RegenerationSurDe.new([1, 2], 1, possede_medaillon)]
		346:
			return [
				Mods.HabiliteAdverseAleatoire.new(func(): return 1 + CombatEngine.roll_die() * 2),
				Mods.HabiliteAdverseDecroissanteParTour.new(1, 2),
			]
		349:
			return [Mods.SansAttaqueTour.new(1)]
		350:
			return [Mods.SeuilPV.new(20, "fin_combat_victoire")]
		370:
			return [
				Mods.HabiliteAdverseDegressiveParDegatsCumules.new(2, 1),
				Mods.AdresseBillyProgressiveParDegatsCumules.new(10, 1),
			]
		387:
			# Jet de Chance -- condition externe, cf note en tete : gelee a
			# "jamais ratee" (l'attaque bonus ne se declenche jamais).
			return [Mods.AttaqueBonusSiConditionExterne.new(false, 5)]
		421:
			return [
				Mods.MalusHabiliteBillyParCoupRecu.new(1),
				Mods.Increvable.new(),
			]
		462:
			return [Mods.AttaquePosthume.new()]
		518:
			# "SOLDATS DE LA TAVERNE" -- identique au nœud 370 (cf
			# COMBATS_REGLES_SPECIALES.md), aucune fonction test_node518
			# dediee. Le malus de -3 Adresse de sous-nombre documente pour ce
			# nœud est un ajustement cote appelant, hors perimetre.
			return [
				Mods.HabiliteAdverseDegressiveParDegatsCumules.new(2, 1),
				Mods.AdresseBillyProgressiveParDegatsCumules.new(10, 1),
			]
		534:
			return [Mods.Intangible.new(3, 1)]
		574:
			return [
				Mods.EsquiveAdverseSurDe.new(func(d): return d == 6),
				Mods.BonusDegatsAdversaireSurDe.new([1], 3),
			]
		575:
			return [Mods.MalusHabiliteAdversePremierTourSeulement.new(2)]
		576:
			# "10 PV, non esquivable, non affecte par l'Armure" -- plafonne
			# selon l'archetype de Billy (3 PAYSAN / 5 PRUDENT / 10 sinon,
			# cf COMBATS_REGLES_SPECIALES.md -- AppParameters.get_billy_type()
			# est un vrai etat reel, pas une condition externe manquante).
			var degats_explosion = 10
			if AppParameters.get_billy_type() == 'paysan':
				degats_explosion = 3
			elif AppParameters.get_billy_type() == 'prudent':
				degats_explosion = 5
			return [Mods.DegatsPeriodiques.new(3, degats_explosion, "billy", false, true)]
	return []


static func _tome2(node_id: int) -> Array:
	match node_id:
		11:
			return [Mods.AjustementSeuilPV.new(6, "hab_adversaire", -2, false)]
		16:
			return [Mods.HabiliteAdverseMalusDecroissantParTour.new(3, 1)]
		31, 40:
			# 31 "le cri", 40 "CHASSEURS DE PRIMES TERRIFIES" -- meme
			# mecanique exacte (cf COMBATS_REGLES_SPECIALES_TOME2.md, "vous
			# perdez 1 point d'Habileté par tour"), 40 sans fonction de test
			# dediee.
			return [Mods.DecroissanceParIntervalle.new("hab_billy", 1, 1)]
		68:
			return [Mods.SansBonusPyroTour.new(1)]
		73:
			return [
				Mods.AjustementTemporaireParTour.new("hab_adversaire", -2, null, 2),
				Mods.DegatsPeriodiques.new(2, 3, "adversaire", false, true),
			]
		113:
			return [
				Mods.SupprimeDegAdversaireApresSeuilPV.new(10),
				Mods.EsquiveAdverseSurDeApresSeuilPV.new(10, func(d): return d % 2 == 1),
			]
		180, 268:
			# 180 "TROIS ASSASSINS MONSTRUEUX", 268 "2 assassins monstrueux"
			# -- meme mecanique exacte (cf COMBATS_REGLES_SPECIALES_TOME2.md),
			# 268 sans fonction de test dediee.
			return [Mods.BonusDegatsBillyDevientMalus.new()]
		197:
			return [Mods.DecroissanceParIntervalle.new("hab_billy", 1, 2)]
		225:
			return [
				Mods.ImmuniteHorsPlageDegats.new(3, 8),
				Mods.DoubleAttaqueAdverse.new(func(): return CombatEngine.roll_die()),
				Mods.LimiteDeTours.new(3, "fuite"),
			]
		234:
			return [
				Mods.AjustementSeuilPV.new(5, "adresse_billy", -1, true),
				Mods.BonusDegatsAdversaireApresSeuilPV.new(5, 1),
			]
		250:
			return [Mods.IgnoreArmureBilly.new()]
		256:
			return [
				Mods.FinCombatSurParitesConsecutives.new(3),
				Mods.DegatsPeriodiques.new(1, 1, "billy", true, false, 2),
			]
		282:
			return [Mods.DegatsPeriodiques.new(2, 2, "billy", false, false)]
		293:
			return [Mods.LimiteDeTours.new(1, "billy")]
		321:
			return [Mods.BonusDegatsBillyDevientMalus.new(1)]
		323:
			return [
				Mods.SansAttaqueTour.new(1, 2),
				Mods.EvenementAleatoireGardienSurpris.new(func(): return CombatEngine.roll_die()),
			]
		436:
			return [
				Mods.AjustementTemporaireParTour.new("adresse_billy", -2, 2),
				Mods.AjustementTemporaireParTour.new("hab_adversaire", 3, 2),
			]
		474:
			# Test de reflexes 2d6 -- condition externe, cf note en tete :
			# gelee a "jamais reussi" (le requin riposte toujours). Le
			# plafond de degats infliges N'A rien d'externe et reste actif.
			return [
				Mods.AdversaireNAttaquePasSiConditionParTour.new(func(tour): return false),
				Mods.PlafondDegatsInflige.new(4),
			]
		480:
			return [
				Mods.ImmuniteContreAttaqueCritique.new(),
				Mods.LimiteDeTours.new(3, "billy"),
			]
		514:
			var modificateurs = [
				# Les 3 regles du Gardien de la Necropole -- Frere Plouf
				# permet normalement d'en suspendre UNE par tour, choix jamais
				# capture aujourd'hui (cf note en tete) : cablees comme
				# TOUJOURS ACTIVES, l'etat neutre de cette suspension.
				Mods.AjustementTemporaireParTour.new("adresse_billy", -1, null, null),
				Mods.ImmuniteContreAttaqueCritique.new(),
				Mods.BonusDegatsAdversaireFixe.new(1),
			]
			if Player.have_item('KHAZIN'):
				modificateurs.append(Mods.DegatsPeriodiques.new(1, 2, "adversaire", false, false))
			return modificateurs
		532:
			return [Mods.ModificateurConditionnel.new(
				Mods.IgnoreArmureBilly.new(),
				func(combat, tour): return tour == 1)]
		584:
			# Jet de Chance reevalue chaque tour -- condition externe, cf
			# note en tete : gelee a "jamais reussi" (jamais de quadruplement).
			return [Mods.MultiplieDegatsSiConditionExterne.new(func(tour): return false, 4)]
		608:
			return [Mods.LimiteDeTours.new(2, "adversaire")]
		630:
			var modificateurs = [
				Mods.DivisionDegats.new("adversaire", 2, func(d): return d % 2 == 1),
				Mods.HabiliteAdverseDegressiveParDegatsCumules.new(3, 1),
			]
			var billy_type = AppParameters.get_billy_type()
			if billy_type == 'paysan':
				modificateurs.append(Mods.DegatsPeriodiques.new(1, 1, "adversaire", false, false))
			elif billy_type == 'prudent':
				modificateurs.append(Mods.ModificateurConditionnel.new(
					Mods.DegatsPeriodiques.new(1, 2, "billy", false, false),
					func(combat, tour): return combat.pile.size() > 0 and combat.pile[combat.pile.size() - 1].attack_die_roll % 2 == 0))
			return modificateurs
		649:
			return [
				Mods.DecroissanceParIntervalle.new("hab_adversaire", 1, 3),
				Mods.BillyEsquiveAttaqueSurDe.new(func(d): return d % 2 == 1),
			]
		686:
			# Choix volontaire d'encaisser le rayon -- condition externe, cf
			# note en tete : gelee a "jamais choisi" (jamais le bonus de +4).
			# Le montant absolu fixe N'A rien d'externe et reste actif.
			return [
				Mods.DegatsAdverseFixesSiTouche.new(4),
				Mods.AttaqueBonusSiConditionExterne.new(false, 4),
			]
		689:
			return [Mods.DivisionDegats.new("billy", 2)]
	return []
