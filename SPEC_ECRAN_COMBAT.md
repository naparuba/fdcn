# Spécification fonctionnelle — Écran de combat

Statut : validé sur prototype interactif (maquette HTML/CSS/JS), prêt pour implémentation Godot.
Périmètre : remplace le panneau `Combat` actuel de `main.tscn` (décoratif, cf. `NotFinish` label
"Les combats ne sont pas encore fini, dev en cours ^^") par un écran qui exécute réellement
`combat.gd`.

## 1. Contexte et objectif

Le moteur de résolution (`combat.gd` + `combat_modificateurs.gd`, ~1500 lignes, testé par
`test/unit/test_combat_resolver.gd` et `test_combat_regles_speciales_tome{1,2}.gd`) n'est
aujourd'hui appelé par **aucun code de jeu** — ni `main.gd`, ni `chapter_data.gd`. Le panneau
`Combat` actuel affiche des stats statiques et un dé cosmétique (`_on_dice_pressed`,
`main.gd:667`) sans effet de jeu.

Le vainqueur réel d'un combat est décidé par le livre : le joueur choisit le paragraphe suivant,
qui porte un delta de PV pré-calculé (`player.gd::_apply_chapter_stat`). **L'écran de combat ne
décide donc jamais seul de l'issue** — il sert à jouer/visualiser l'échange tour par tour, mais
le joueur garde toujours la main pour clore le combat manuellement (§7).

## 2. Principes directeurs (décisions actées)

1. **Un tour = un geste.** Un seul bouton principal ("Lancer le dé"), en bas d'écran, zone du
   pouce sur téléphone tenu à une main. Aucune action répétée à chaque tour ne doit changer de
   place.
2. **Un seul dé, visible, sert à tout.** La même valeur d6 pilote la Table des Situations (si pas
   d'esquive), la réussite de l'esquive, et le seuil critique (face 1). Jamais de second jet
   caché que le joueur ne voit pas — c'était un bug du premier jet d'implémentation, corrigé.
3. **Esquive activée par défaut** dès que `Adresse >= 2` (aucun risque à esquiver dans les règles
   actuelles, seulement des cas où le joueur préfère "sentir" chaque coup sans filtre) —
   désactivable via un interrupteur, jamais forcée.
4. **Prévisualisation avant de lancer.** Une bande de 6 cases (une par face possible) montre ce
   que Billy infligerait/subirait pour chaque valeur de dé, recalculée à chaque tour à partir des
   stats *effectives* du moment (pas les stats de base). Les cases couvertes par l'esquive sont
   distinguées visuellement (bordure cyan, or pour le seuil critique).
5. **Deux coups séquentiels, jamais simultanés.** Façon Hearthstone : l'attaquant bondit vers le
   défenseur, impact, pause (~300 ms), puis l'autre camp riposte. Dans le cas esquive, l'ordre
   s'inverse (l'ennemi attaque en premier, Billy se dérobe, contre-attaque seulement sur
   critique).
6. **Intensité proportionnelle aux dégâts.** Secousse, flash de couleur et taille du nombre
   flottant grandissent avec la valeur du coup. Un coup à 1 PV se voit à peine, un critique se
   sent.
7. **Sémantique des couleurs, pas de décoration.** Cyan = esquive (interrupteur, bordures de la
   prévisualisation, stat Adresse). Or = critique (seuil, stat Critique, texte flottant). Corail =
   dégât subi. Vert = dégât infligé. Orange = événement environnemental/périodique (hors échange
   normal, ex. salve de flèches). Gris = bloqué/neutre.
8. **Historique cliquable, retour libre.** Une strip horizontale de tours (tuiles compactes :
   numéro, icône de résultat, PV des deux camps à cet instant) permet de revenir avant n'importe
   quel tour joué, **sans confirmation ni pénalité** — le joueur a le droit de refaire un jet qui
   ne lui plaît pas. Une tuile en pointillés annonce toujours le prochain tour à venir.
9. **Fin de combat toujours réversible.** Victoire/défaite automatique (PV à 0) ou manuelle (§7)
   ouvrent un écran de résolution qui propose aussi de revenir en arrière plutôt qu'un cul-de-sac.
10. **Règles spéciales visibles, pas seulement dans le code.** Chaque règle spéciale active sur
    le combat en cours est affichée en tuile sur le panneau ennemi. Toute variation d'une stat
    effective (ex. Habileté qui baisse) déclenche une animation dédiée (pulse + delta flottant
    +N/−N), jamais un changement silencieux.

## 3. Layout de l'écran (de haut en bas)

Écran portrait, ratio 558×1046 (celui du projet), pensé pour un pouce.

1. **Barre d'app** (existante, inchangée).
2. **En-tête Combat** : titre "Combat", numéro de tour courant, bouton "J'ai gagné" (icône coche,
   `tick.png`) — voir §7.
3. **Panneau Ennemi** : glyphe, nom, tags de règles spéciales actives (texte descriptif, une tuile
   par règle), PV actuel/max + barre, stats Hab/Armure/Dégât.
4. **Panneau Joueur (Billy)** : glyphe, nom, tag du bonus Pyro-Barbare si actif, PV actuel/max +
   barre, stats Hab/Armure/Dégât/Adresse/Critique (les deux dernières absentes du panneau actuel
   — gap identifié : elles pilotent l'esquive/critique et doivent être visibles sans changer
   d'écran).
5. **Strip de tours** : historique horizontal scrollable, tuiles cliquables (§2.8) + tuile
   "prochain tour" en pointillés.
6. **Ligne "dernier tour"** : résumé texte du tour le plus récent (dé, dégâts exacts, mentions des
   effets spéciaux du tour — esquive, critique, surprise, salve périodique).
7. **Barre d'action** (bas d'écran, zone du pouce) :
   - Bande de prévisualisation par face (§2.4).
   - Interrupteur esquive (visible seulement si Adresse ≥ 2).
   - Bouton "Annuler le dernier tour" (raccourci équivalent à taper la dernière tuile de la
     strip).
   - Bouton "Lancer le dé" (action principale).
8. **Overlay de résolution** : Victoire / Défaite / manuel — icône, titre, sous-texte, CTA
   "Continuer l'aventure", lien secondaire "Revenir en arrière".

## 4. Modèle de données pendant un combat

État à tenir en mémoire côté écran (au-delà de ce que `combat.gd` gère déjà) :

- **Combattant ennemi** : `pv`, `pv_max`, `hab_effective` (recalculée), `armure`, `degat`, tags de
  règles spéciales actives (liste de libellés courts + description longue).
- **Combattant Billy** : `pv`, `pv_max`, `hab_effective`, `armure`, `degat`, `adresse`, `critique`,
  bonus Pyro-Barbare (booléen + valeur).
- **Historique de tours** : pile de snapshots `{tour, pv_ennemi, pv_billy}` pour le rewind. **Point
  d'attention technique** : `EtatTour` (`combat.gd:179-200`) ne stocke aujourd'hui que PV/dégâts/
  jets, pas les valeurs Hab/Adresse *effectives* du tour (ce sont des variables locales de
  `play_turn()`). Pour que l'écran puisse les afficher et les reconstruire fidèlement après un
  rewind, deux options à trancher en implémentation :
  a. Étendre `EtatTour` pour y persister `hab_billy_tour`/`hab_adversaire_tour`/
     `adresse_billy_tour` (préférable, source de vérité unique) ;
  b. Recalculer côté écran à partir des mêmes hooks de modificateurs (duplique la logique,
     risque de divergence).
  → **Recommandation : option (a)**, à faire dans `combat.gd` avant de brancher l'écran.
- **Modificateurs actifs** : liste des instances `Modificateur` passées à `Combat.new(...,
  {"modificateurs": [...]})`, utilisées à la fois pour la résolution ET pour générer les tags de
  règles spéciales affichés (le libellé de chaque tag doit pouvoir être dérivé de la classe du
  modificateur, cf. §6).

## 5. Séquencement de la résolution d'un tour

1. Le joueur appuie sur "Lancer le dé". Animation de lancer (~480 ms), puis affichage de la face
   tirée.
2. Surlignage de la case correspondante dans la bande de prévisualisation.
3. Détermination de l'esquive : `interrupteur ON ET Adresse >= 2 ET face <= Adresse`.
   - Si esquive et face = 1 → critique (contre-attaque à dégâts maximum + bonus Critique, Armure
     adverse ignorée, cf. `combat.gd::play_turn` lignes 398-408, 436-437).
   - Si esquive sans critique → 0 dégât subi ce tour.
   - Si pas d'esquive → lecture de la Table des Situations (`SITUATION_TABLE`, diff d'Habileté
     clampé à [-7,7], face du dé) → dégâts bruts des deux côtés, puis Armure et plafond PAYSAN
     appliqués côté Billy.
4. **Affichage séquentiel** (jamais simultané) :
   - Cas normal : Billy bondit vers l'ennemi → réaction ennemi (choc/bloqué) → pause ~300 ms →
     ennemi bondit vers Billy → réaction Billy (choc/bloqué).
   - Cas esquive : ennemi bondit vers Billy → réaction Billy (esquive, pas de bond en retour) →
     si critique, pause puis Billy bondit vers l'ennemi → réaction ennemi.
5. **Effets hors échange** (troisième temps, si applicable ce tour-là, sans bond directionnel
   puisqu'ils ne viennent pas d'un combattant qui attaque) : dégâts périodiques, absence
   d'attaque programmée, etc. — cf. catalogue §6.
6. Recalcul des stats effectives (ex. Habileté ennemie après dégâts cumulés) → si une valeur
   affichée change, déclencher l'animation de changement de stat (pulse + delta flottant).
7. Mise à jour de la strip de tours (nouvelle tuile), de la ligne "dernier tour", et de la bande
   de prévisualisation pour le tour suivant.
8. Vérification fin de combat (PV ≤ 0 d'un côté) → overlay de résolution si oui.

## 6. Catalogue des règles spéciales — périmètre du MVP vs. reporté

Recensement complet fait sur `combat_modificateurs.gd` : ~41 classes regroupées en 20 familles
(A à T). Catalogue détaillé conservé pour référence (cf. rapport d'analyse dans l'historique de
conception) ; **le MVP de l'écran Godot couvre uniquement les mécaniques déjà validées sur le
prototype** :

- **Base du moteur** : échange normal, esquive, critique, Armure, plafond PAYSAN, victoire/
  défaite par PV, fuite (non encore maquetté à l'écran — bouton à prévoir).
- **Famille A — Dégradation progressive liée aux dégâts cumulés** (`HabiliteAdverseDegressive
  ParDegatsCumules` et son inverse côté Billy) : stat effective recalculée + animation de
  changement.
- **Famille C — Dégâts périodiques** (`DegatsPeriodiques`) : troisième coup hors échange, non
  esquivable, notification distincte.
- **Famille I — Absence d'attaque programmée** (`SansAttaqueTour`) : badge + note explicite pour
  éviter la confusion "0 dégât = bug ?".

**Reporté** (17 familles restantes : seuils de PV/phases, immunités/intangibilité, attaque
posthume, double attaque, fin de combat par motif de dés ou limite de tours, régénération,
increvabilité, choix actif du joueur type "Frère Plouf", etc.) — chacune nécessite un traitement
UI distinct (badge d'état, jauge non liée aux PV, interaction de choix) qui n'a pas encore été
maquetté. À reprendre nœud par nœud une fois le MVP en jeu.

**Hors périmètre explicite** : mécanique de Jet de Chance (2d6 vs `get_cha()`, décompte). Le code
actuel ne l'implémente nulle part (traité comme condition externe fournie par l'appelant dans
`combat_modificateurs.gd`) et la règle exacte du jeu n'a pas encore été vérifiée dans le livre
papier — **ne pas l'inventer**, à spécifier séparément une fois la règle confirmée.

## 7. Fin de combat — trois chemins, toujours réversibles

1. **Victoire automatique** : PV ennemi ≤ 0 (et PV Billy > 0).
2. **Défaite automatique** : PV Billy ≤ 0.
3. **Fin manuelle ("J'ai gagné")** : bouton toujours disponible (icône coche, coin supérieur droit
   du panneau Combat), y compris avant le premier tour joué. Justification : le vainqueur réel est
   décidé par le choix de paragraphe dans le livre, pas par les PV simulés à l'écran — l'écran ne
   doit jamais bloquer le joueur qui sait déjà comment le combat se termine réellement.

Dans les trois cas, l'overlay de résolution propose un CTA principal ("Continuer l'aventure") et
un lien secondaire ("Revenir en arrière") qui annule le dernier tour joué (ou simplement rouvre la
main sur le combat si aucun tour n'a encore été joué).

## 8. Identité visuelle (reprise de l'app existante, pas une nouvelle charte)

**Priorité : coller au reste de l'app telle qu'elle existe déjà**, pas à cette liste. Les valeurs
ci-dessous viennent de `main.tscn` et servent de point de départ documenté, mais l'implémentation
Godot doit se réconcilier avec les vraies ressources du projet au fur et à mesure (StyleBox/Theme
existants, styles déjà en place sur les autres écrans) plutôt que les traiter comme figées —
notamment la teinte "or" du critique, choisie pour le prototype, sans équivalent connu ailleurs
dans l'app à ce stade.

- **Police** : RobotoCondensed (seule police réellement utilisée dans l'app — `Pancis-Regular`
  présent dans `fonts/` mais jamais référencé dans le code, à ne pas introduire).
- **Couleurs** (extraites de `main.tscn`, valeurs `Color()` réelles) :
  - Navy `#313B47` — chrome/en-têtes.
  - Cyan `#01BCDB` — accent, esquive.
  - Or `#E0A52C` — critique (nouvelle teinte, cohérente avec le sens donné au critique ; à
    valider dans la palette Godot si elle diffère).
  - Corail `#F45858` — dégât subi/défaite.
  - Vert `#2F9E63`/mint `#4FCF8C` — dégât infligé/victoire.
  - Orange `#C27200` — dés, événements périodiques/environnementaux.
  - Gris clairs `#E0E2E5`/`#E9EAEC`/`#ECEDF2` — fonds de carte/page.
- **Icônes réutilisées telles quelles** : `res://images/fight.svg` (épées croisées), `res://
  images/tick.png` (bouton "J'ai gagné"), sprites de dés existants (`res://images/dice/*.svg`,
  modulate orange).

## 9. Chantiers d'intégration (au-delà de l'écran lui-même)

- Étendre `EtatTour` pour persister les stats effectives par tour (§4).
- Brancher réellement `combat.gd` depuis `main.gd`/`chapter_data.gd` — aujourd'hui `is_combat()`
  ne fait qu'afficher des stats statiques, jamais instancier `Combat`.
- Choisir le premier nœud de combat réel à brancher pour valider l'intégration bout-en-bout
  (privilégier un combat simple du Tome 1 sans modificateur avant les familles A/C/I).
- Ajouter le bouton "Fuite" (coût en Points de Chance, `combat.gd::FUITE_COST`) — mentionné dans
  le moteur mais absent du prototype actuel, à statuer si le MVP le couvre ou pas.
