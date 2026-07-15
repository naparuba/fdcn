# Règles spéciales de combat — Tome 2 (La Corne des Sables d'Ivoire)

Catalogue de tous les combats du livre 2 (40 au total, cf `fdcn-2-compilated-combats.json`).
But : lister les règles spéciales propres à CHAQUE combat (régénération, immunité à
certaines plages de dégâts, fuite forcée, debuff temporaire, esquive/critique adverse...)
avant de chercher à généraliser quoi que ce soit dans `combat_modificateurs.gd` — même
démarche que pour le [Tome 1](COMBATS_REGLES_SPECIALES.md) : catalogue d'abord, généralisation
ensuite.

Colonnes Hab/PV/Arm/Deg/Pyro = données déjà dans `fdcn-2-compilated-data.json` (le combat
"standard", cf Table des Situations). La colonne "Règle spéciale" est à remplir au fur et
à mesure (lecture du livre physique) — vide = pas encore vérifié, PAS "aucune règle spéciale".
"PB"/"Pyro-Barbare" dans le texte du livre désigne le bonus déjà présent dans la colonne Pyro
(terminologie de personnage conservée du Tome 1, même si les archétypes du Tome 2 s'appellent
GUERRIER/PAYSAN/PRUDENT/DÉBROUILLARD).

Source des nœuds/stats : `fdcn-2-compilated-combats.json` + `fdcn-2-compilated-data.json`
(déjà présents dans le repo, mêmes fichiers que ceux qui avaient donné la liste du Tome 1).
Règles spéciales : dictée directe du livre physique par l'utilisateur (2026-07-13).

## Décisions tranchées (2026-07-13)

- **256 (Mimine)** : confirmé -- reste un vrai `Combat` normal, juste basé entièrement sur la
  parité des dés (pas de PV/Hab/Arm/Deg au sens standard malgré les stats 99/99/99/99 dans les
  données). Un seul Modificateur suffit (compteur de jets consécutifs de même parité).
- **584 (Armée de Creux), 630 (L'Usurpatrice), 649 (Zarh du souffle), 514 (Gardien de la
  Nécropole)** : confirmé -- toutes ces règles dépendent d'informations qui vivent déjà dans
  les **objets** du joueur (`fdcn-2-compilated-all-objects.json`) :
  - l'archétype de Billy est un objet de `category: "BILLY"` acquis au nœud 1 (`GUERRIER`,
    `PAYSAN`, `PRUDENT`, `DEBROUILLARD`) ;
  - les compagnons/flags narratifs sont des objets de `category: "OBJET"` acquis en cours de
    partie (`KHAZIN` nœud 14, `PLOUF` nœud 147, `NADEE` nœud 207, `TURBAN POUR KHAZIN` nœud
    536, `MIROIR DE NADEE` nœud 471).
  - Donc **pas de nouveau Modificateur générique par archétype/compagnon** : l'appelant lit
    `Player`/l'inventaire (archétype + `has_object("KHAZIN")` etc.), calcule les valeurs
    finales, et les passe en paramètre aux Modificateurs existants (ou nouveaux mais
    paramétrés), exactement comme `AttaqueBonusSiConditionExterne` au Tome 1 (`condition_vraie`
    calculée côté appelant).
- **225 (La Poigne Filante)** : confirmé -- **immunité totale hors de la plage [3, 8] PV**
  (pas un plafonnement/clampage). Une attaque qui infligerait moins de 3 ou plus de 8 PV
  bruts n'a AUCUN effet ce tour-là, comme si elle n'avait jamais eu lieu.
- **474 (Banc de requins des sables)** : confirmé -- le combat CONTINUE après avoir réussi le
  test de réflexes (pas de fin de combat immédiate). Interprétation retenue, fidèle au texte
  dicté : réussir le test = ce tour-là, Billy attaque normalement mais ne subit AUCUN dégât en
  retour (le requin abattu ne porte pas son coup) -- c'est ça, "l'ennemi diminué" : moins de
  requins qui ressortent du sable pour attaquer, pas un décompte de PV/Habileté séparé. Plafond
  de 4 dégâts/tour infligés par Billy inchangé, dans les deux cas (réussite ou échec du test).
- **584 (Armée de Creux)** : confirmé (2026-07-13, revue) -- le jet de Chance du PRUDENT
  ("quadruple ses dégâts sur un jet de Chance réussi") est vérifié à CHAQUE tour, pas une seule
  fois pour tout le combat. Ce n'est donc PAS côté appelant comme supposé initialement : voir
  `MultiplieDegatsSiConditionExterne` ci-dessous.

## Revue de couverture (2026-07-13) : trous trouvés et corrigés

Une relecture complète du catalogue contre `test_combat_regles_speciales_tome2.gd`, nœud par
nœud, a trouvé plusieurs mécaniques conçues pendant le design mais jamais réellement codées ni
testées. Toutes corrigées dans cette même passe (voir sections ci-dessous pour le détail des
classes) :
- **16** : aucune classe n'existait pour le malus d'Habileté adverse démarrant à -3 et se
  résorbant de +1/tour -- ajouté `HabiliteAdverseMalusDecroissantParTour`.
- **68** : aucune classe pour "le Pyro-Barbare est absent pendant 1 tour" -- ajouté
  `SansBonusPyroTour`.
- **73** : aucune classe pour l'événement du tour 2 (3 PV + malus permanent) -- couvert par
  `AjustementTemporaireParTour` étendu (`premier_tour`) + `DegatsPeriodiques` (une_seule_fois).
- **225** : la clause "s'il n'est pas vaincu en 3 tours, il s'échappe" n'était pas testée --
  `LimiteDeTours` la couvre déjà nativement (accepte n'importe quelle chaîne de résultat),
  ajouté un test avec `resultat="fuite"`.
- **514** : aucun test du tout. La branche Khazin (`DegatsPeriodiques` avec `cible="adversaire"`)
  était une branche de code JAMAIS exercée par aucun test (Tome 1 ou Tome 2, seul `cible="billy"`
  l'était) -- trou de couverture sur du code déjà écrit, pas juste un nœud non testé. La branche
  Frère Plouf n'était testée qu'avec un exemple synthétique générique -- ajouté un test avec les
  3 VRAIES règles du Gardien, chacune suspendable indépendamment (voir `BonusDegatsAdversaireFixe`
  ci-dessous, nécessaire pour rendre la règle des "lames dentelées" suspendable).
- **630** : la branche PAYSAN (djinns de terre, même branche `cible="adversaire"` que Khazin)
  n'était pas testée -- ajouté. Les branches archétype restent essentiellement côté appelant
  (voir correction du traitement du Critique ci-dessous).
- **649** : la bénédiction de Neit ("esquive tous les dommages sur un dé impair, sans phase
  d'esquive") n'avait ni classe ni test -- ajouté `BillyEsquiveAttaqueSurDe`.
- **686** : "4 dégâts absolus s'il touche" n'avait ni classe ni test -- ajouté
  `DegatsAdverseFixesSiTouche`.
- **630 (correction)** : le tableau reuse listait à tort `ImmuniteContreAttaqueCritique` pour ce
  nœud. Erreur d'analyse : "votre Critique est réduit à 0" est le score de CRITIQUE de Billy mis
  à 0 (`critique_billy=0` côté appelant -- un critique a toujours lieu, juste sans bonus, exactement
  l'effet de `ContreAttaqueCritiqueSansBonusCritique`, voire aucun Modificateur du tout puisque
  `critique_billy=0` suffit), PAS une immunité qui annule le critique lui-même. `DÉBROUILLARD`
  restaure `critique_billy` à sa valeur normale +2, toujours côté appelant.
- **`EvenementAleatoireGardienSurpris` (323)** : la mise en cache par NUMÉRO DE TOUR (limite
  documentée à l'origine) a été remplacée par un cache invalidé à CHAQUE appel réel de
  `hab_billy_pour_ce_tour` (le 1er hook appelé par tour, systématiquement, rejeu ou pas) --
  supprime la limite : un rejeu après annulation relance bien le dé, au lieu de renvoyer la
  valeur de la tentative précédente.

Tous les cas d'annulation/rejeu des nouvelles mécaniques ont des tests dédiés, en particulier
pour les mécanismes pilotés par une condition CONTRÔLÉE PAR L'APPELANT (Frère Plouf, Chance du
PRUDENT) : annuler un tour puis le rejouer avec un choix DIFFÉRENT doit refléter le nouveau
choix, pas un résultat figé de la tentative annulée.

## Architecture retenue (2026-07-13) : classes réutilisées vs nouvelles

Même philosophie que le [Tome 1](COMBATS_REGLES_SPECIALES.md) : composition de petits
`Modificateur`, pas de sous-classe de `Combat` par nœud. Légende : **[R]** = classe déjà
existante (Tome 1), réutilisée telle quelle ; **[E]** = classe existante étendue avec un
paramètre optionnel par défaut rétro-compatible (aucune régression sur les tests Tome 1) ;
**[N]** = nouvelle classe ; **[A]** = rien à coder, valeur fixe côté appelant (`Combat.new()`)
ou système hors `combat.gd` (Chance/Domination/fuite, choix narratif).

### Classes étendues (rétro-compatibles, vérifié par re-run de la suite Tome 1)

- **`DegatsPeriodiques`** *(+`tour_de_debut=1`)* : permet "chaque tour à partir du Nᵉ" (256 :
  intervalle=1, tour_de_debut=2) sans changer le comportement par défaut (formule
  `tour >= tour_de_debut and (tour - tour_de_debut + 1) % intervalle == 0`, identique à
  l'ancienne `tour % intervalle == 0` quand tour_de_debut=1).
- **`SansAttaqueTour`** *(+`duree=1`)* : permet "pas d'attaque pendant N tours consécutifs"
  (323 : numero_tour=1, duree=2) au lieu d'un seul tour fixe.
- **`AjustementTemporaireParTour`** *(+`premier_tour=null`, revue 2026-07-13)* : `dernier_tour`
  et `premier_tour` acceptent désormais `null` (= pas de borne). `dernier_tour=null,
  premier_tour=X` donne un malus PERMANENT à partir du tour X (73), `dernier_tour=null,
  premier_tour=null` donne un ajustement actif tout le combat, utile combiné à
  `ModificateurConditionnel` (514, Frère Plouf) puisqu'un `AjustementTemporaireParTour`
  "toujours actif" devient alors "actif sauf les tours où Plouf le suspend".

### Nouvelles classes génériques (réutilisées sur plusieurs nœuds)

- **`AjustementTemporaireParTour(cible, delta, dernier_tour)`** -- ajuste hab_billy/
  hab_adversaire/adresse_billy d'un delta (+/-) tant que `tour <= dernier_tour`. Couvre 436
  (deux instances : adresse_billy -2 et hab_adversaire +3, dernier_tour=2).
- **`DecroissanceParIntervalle(cible, perte, intervalle)`** -- réduit hab_billy ou
  hab_adversaire de `perte` tous les `intervalle` tours (indépendamment des dégâts, contrairement
  à `HabiliteAdverseDegressiveParDegatsCumules`). Couvre 31/40 (cible=hab_billy, intervalle=1),
  197 (cible=hab_billy, intervalle=2), 649 (cible=hab_adversaire, intervalle=3).
- **`AjustementSeuilPV(seuil, cible, delta, avant_seuil=false)`** -- ajuste hab_billy/
  hab_adversaire/adresse_billy d'un delta tant que la condition de seuil (PV adverses) est
  respectée. Couvre 11 (cible=hab_adversaire, delta=-2, avant_seuil=false -- malus permanent
  une fois le seuil franchi) et la restauration d'Adresse de 234 (cible=adresse_billy, delta=-1,
  avant_seuil=true -- malus actif seulement AVANT le seuil).
- **`BonusDegatsAdversaireApresSeuilPV(seuil, bonus)`** / **`SupprimeDegAdversaireApresSeuilPV(seuil)`**
  -- variantes seuil-PV pour deg_adversaire (pas de hook per-turn dédié comme pour hab/adresse,
  donc modifient `modifie_degats_bruts` directement). Couvrent 234 (bonus +1 après seuil) et 113
  (suppression du deg_adversaire de base après seuil).
- **`EsquiveAdverseSurDeApresSeuilPV(seuil, predicat)`** -- variante seuil-PV de
  `EsquiveAdverseSurDe`. Couvre 113 (esquive sur dé impair une fois sous la moitié des PV).
- **`BonusDegatsBillyDevientMalus(numero_tour=null)`** -- transforme le bonus `deg_billy` en
  malus symétrique (`-2*deg_billy` net) ; `numero_tour=null` = tout le combat. Couvre 180, 268
  (toujours actif) et 321 (premier tour seulement).
- **`ImmuniteHorsPlageDegats(min_deg, max_deg)`** -- annule `degats_billy` si hors de
  `[min_deg, max_deg]` (immunité totale, pas un plafonnement). Couvre 225.
- **`AdversaireNAttaquePasSiConditionParTour(condition: Callable)`** -- annule
  `degats_adversaire` ce tour si `condition.call(tour)` est vrai (condition externe, ex. test de
  réflexes injecté par l'appelant/test). Couvre 474 (réussite du test de réflexes 2d6 ≤
  Habileté).
- **`PlafondDegatsInflige(plafond)`** -- plafonne `degats_billy` (symétrique de
  `plafond_degats_subis_billy` déjà existant sur `Combat`, mais côté dégâts infligés). Couvre 474.
- **`IgnoreArmureBilly()`** -- ré-ajoute `armure_billy` à `degats_adversaire` pour annuler la
  soustraction faite plus loin dans `play_turn` (même technique que `Intangible`, extraite en
  classe autonome). Couvre 250, et 282 en pose conditionnelle (flammes non neutralisées).
- **`DivisionDegats(cible, diviseur, condition: Callable = null)`** -- divise (floor)
  `degats_billy` ou `degats_adversaire` (selon `cible`, même convention que `DegatsPeriodiques` :
  cible="billy" affecte ce que Billy reçoit) par `diviseur`, sous condition optionnelle sur le
  dé d'attaque. Couvre 630 (cible="adversaire", diviseur=2, condition=dé impair) et 689
  (cible="billy", diviseur=2, pas de condition).
- **`ModificateurConditionnel(interieur: Modificateur, condition: Callable)`** -- décorateur qui
  ne transmet les hooks du Modificateur enveloppé que si `condition.call(combat, tour)` est
  vrai ce tour-ci ; sinon comportement neutre. Permet de rendre N'IMPORTE QUEL Modificateur
  existant activable/désactivable tour par tour sans dupliquer sa logique. Couvre 514 (Frère
  Plouf choisit, au début de chaque tour, laquelle des 3 règles du Gardien suspendre).
- **`FinCombatSurParitesConsecutives(n_requis=3)`** -- force `vainqueur_force` en faveur de
  Billy dès que `n_requis` tours consécutifs ont le même die d'attaque de même parité (dérivé de
  `combat.pile`, donc undo-safe). Couvre 256.
- **`HabiliteAdverseMalusDecroissantParTour(malus_initial, reduction_par_tour)`** -- malus
  d'Habileté adverse qui se résorbe linéairement par NUMÉRO de tour (miroir de `Intangible` du
  Tome 1, mais appliqué à l'Habileté plutôt qu'aux dégâts). Couvre 16.
- **`SansBonusPyroTour(numero_tour)`** -- suspend `pyro_bonus` (déjà ajouté à `hab_billy` à la
  construction) pour UN tour précis. Couvre 68.
- **`BillyEsquiveAttaqueSurDe(predicat)`** -- Billy esquive TOTALEMENT les dégâts adverses ce
  tour si le jet d'ATTAQUE (pas un jet d'esquive dédié) vérifie le prédicat -- contrairement à
  `EsquiveAdverseSurDe` (l'ADVERSAIRE esquive l'attaque de Billy), celle-ci annule les dégâts
  SUBIS par Billy, sans passer par le mécanisme d'esquive normal. Couvre 649 (bénédiction de
  Neit).
- **`DegatsAdverseFixesSiTouche(montant)`** -- remplace `degats_adversaire` par un montant fixe
  quand l'attaque touche (`degats_adversaire > 0` avant remplacement). Couvre 686.
- **`BonusDegatsAdversaireFixe(bonus)`** -- bonus de `degats_adversaire` fixe et inconditionnel
  (hors esquive), sans seuil de PV -- distinct de `BonusDegatsAdversaireApresSeuilPV`. Rend la
  règle des "lames dentelées" du nœud 514 suspendable via `ModificateurConditionnel` (Frère
  Plouf).
- **`MultiplieDegatsSiConditionExterne(condition: Callable, multiplicateur)`** -- comme
  `AttaqueBonusSiConditionExterne`, mais la condition est un Callable réévalué à CHAQUE tour
  (`condition.call(tour)`) plutôt qu'un booléen fixé une fois à la construction -- nécessaire
  quand la condition externe (ex. un Jet de Chance) peut changer d'un tour à l'autre. Couvre 584
  (PRUDENT).

### Classes réutilisées telles quelles (Tome 1)

`LimiteDeTours` (166 : survie 3 tours ; 225 : `resultat="fuite"` si pas vaincu en 3 tours ; 293 :
victoire immédiate tour 1 -- `LimiteDeTours(1, "billy")` ; 480 : PB arrive tour 3 ; 608 : défaite
si pas gagné en 2 tours), `SansAttaqueTour` (180 premier tour), `ImmuniteContreAttaqueCritique`
(480, 514 -- "les coups critiques ne lui infligent aucun dommage" est le même effet mécanique
que "l'adversaire est immunisé au critique" ; **PAS 630**, cf correction dans "Revue de
couverture" -- 630 met `critique_billy` à 0 côté appelant, ce n'est pas une immunité),
`HabiliteAdverseDegressiveParDegatsCumules` (630 : -1 Hab tous les 3 PV perdus),
`DegatsPeriodiques` (79, 81, 282, 630 -- bloc de marbre ; cible="adversaire" pour 514/Khazin et
630/PAYSAN, branche vérifiée par un test dédié depuis la revue de couverture),
`AttaqueBonusSiConditionExterne` (686 -- encaisser volontairement pour +4 dégâts, réutilisé à
l'identique du nœud 387).

### Côté appelant, aucun code combat.gd/combat_modificateurs.gd nécessaire

Mains nues / retrait des stats d'objet (11, 43, 125), bonus fixe d'objet trouvé (11 : pied de
chaise +2 Hab), +1 Adresse d'avantage numérique (43), armes spécifiques (+1/-1 dégâts avec Arc/
Lance/Fléau/Sabre/Morgenstern selon nœud), `plafond_degats_subis_billy` déjà existant (584
PAYSAN), tout ce qui touche Chance/Domination/fuite (237, 296, 312, 584) qui sont des systèmes
hors `Combat`, choix narratif d'épargner l'adversaire (125), et toutes les valeurs déjà
directement reflétées dans les colonnes Hab/PV/Arm/Deg/Pyro (514 : +1 dégât "lames dentelées"
déjà dans Deg=1 ; 649 : Hab=Chance max+Endurance+Adresse calculé une fois à la construction ;
689 : Adresse/Critique/Armure mis à 0 et convertis en `deg_billy` bonus, calculé une fois à la
construction). Le choix de dé à l'avance (649, 3 fois pendant le combat) utilise directement les
paramètres `attack_die_roll`/`esquive_die_roll` déjà acceptés par `play_turn()` -- aucune
extension d'API nécessaire.

### Nœuds les plus complexes, une classe dédiée non réutilisable ailleurs

- **323 (Gardien surpris)** : `EvenementAleatoireGardienSurpris(de_roll: Callable)` -- un jet de
  dé dédié par tour (injecté par callable comme `HabiliteAdverseAleatoire` au Tome 1) pilotant 4
  branches (1 : Billy -2 PV instantané ; 2-3 : -2 Hab Billy ce tour ; 4-5 : +2 Hab Billy ce
  tour ; 6 : +2 dégâts infligés et 0 dégât subi ce tour).
- **225 (La Poigne Filante)** : `DoubleAttaqueAdverse(esquive_die_roll: Callable)` -- décision
  tranchée (2026-07-13). Le texte dicté dit explicitement "2 fois les MÊMES dommages" : la 2ᵉ
  attaque réutilise donc exactement `etat_tour.degats_adversaire` (déjà finalisé -- esquive/
  Armure/plafond de la 1ère attaque déjà appliqués), ce n'est PAS une simplification qui
  s'éloigne du texte, c'est ce que le texte dit littéralement. Ce qui reste réellement
  INDÉPENDANT entre les deux attaques, et donc modélisé séparément, c'est l'esquive : la 2ᵉ a
  son propre jet dédié (injecté par Callable, comme `EvenementAleatoireGardienSurpris`, plutôt
  que d'étendre `play_turn()`), comparé à `combat.adresse_billy` directement. Jamais de
  contre-attaque critique sur cette 2ᵉ attaque (pas de jet de 1 traité dans cette classe).

| Nœud | Lieu/Arc | Ennemi | Hab | PV | Arm | Deg | Pyro | Règle spéciale |
|---|---|---|---|---|---|---|---|---|
| 11 | Nouvelle-Nouvelle-Azur | SERGENT ET TROUFION | 5 | 9 | 1 | 0 | 4 | Combattez sans les statistiques de votre équipement (mains nues), mais un **pied de chaise** trouvé sur place vous donne **+2 Habileté**. Une fois l'ennemi sous **6 PV**, le Troufion est assommé : le Sergent perd **2 Habileté**. |
| 16 | L'Exode | JEUNE KRÄNELORNIEN EPUISE | 10 | 12 | 0 | 1 | 0 | Exténué par son escalade, il commence le combat avec **-3 Habileté**, qu'il regagne à raison de **+1 point à la fin de chaque tour**. Le bonus du Pyro-Barbare ne s'applique pas sur ce combat. |
| 31 | L'Exode | PERRODACTYLE | 8 | 10 | 0 | 0 | 2 | Son cri réduit votre Habileté de **1 point à la fin de chaque tour**, cumulatif jusqu'à la fin du combat. Le Nain (compagnon) est figé : le bonus du Pyro-Barbare est limité à **+2 Habileté** *(déjà reflété dans la colonne Pyro)*. Vous infligez **+1 dégât** avec l'Arc ou la Lance. |
| 40 | Nouvelle-Nouvelle-Azur | CHASSEURS DE PRIMES TERRIFIES | 5 | 8 | 0 | 0 | 0 | Vous perdez **1 point d'Habileté par tour**. Le bonus du Pyro-Barbare ne s'applique pas. |
| 43 | Nouvelle-Nouvelle-Azur | SERGENT | 3 | 6 | 0 | -1 | 4 | Le Troufion est assommé dès le début, mais vous devez combattre le Sergent sans les caractéristiques de votre équipement (mains nues). Votre avantage numérique vous donne **+1 Adresse**. |
| 68 | Nouvelle-Nouvelle-Azur | CHASSEURS DE PRIMES | 7 | 11 | 0 | 0 | 4 | Le Pyro-Barbare est absent pendant **1 tour**. |
| 73 | Nouvelle-Nouvelle-Azur | CHASSEURS DE PRIMES SURPRIS | 7 | 11 | 0 | 0 | 4 | À la fin du **2ᵉ tour**, le Pyro-Barbare assomme un des Chasseurs : **3 PV** infligés à l'ennemi et **-2 Habileté** adverse. |
| 79 | L'Exode | ELFE SAUVAGE | 6 | 9 | 0 | 0 | 4 | Le Nain (compagnon) refuse de vous accorder le moindre bonus d'Habileté, mais inflige **2 PV** à l'ennemi à chaque tour. |
| 81 | L'Exode | JEUNE POUSSE CARNITREX | 10 | 8 | 0 | 0 | 4 | Le Pyro-Barbare s'occupe du rat, reste la plante : son acide ignore votre Armure et vous fait perdre **1 PV par tour**, non esquivable. Avec le Fléau à Grain ou le Sabre, votre Habileté gagne **+2 points**. |
| 113 | L'Exode | Elfe-panthère | 12 | 15 | 0 | 1 | 7 | Une fois tombé sous la **moitié de ses PV**, l'Elfe-panthère arrête d'infliger son **+1 PV bonus**, mais esquive désormais vos attaques si vous obtenez un **dé impair**. |
| 125 | L'Exode | Champion nain | 5 | 10 | 1 | 0 | 4 | Retirez l'Habileté, les dégâts et le Critique conférés par vos objets tenus en main : combat à mains nues. Le Turban amortit les chocs. Vous pouvez choisir d'arrêter le combat et d'épargner votre adversaire lorsqu'il atteint **3 PV ou moins** — sauf en cas de victoire par CHANCE, qui ne permet jamais de l'épargner. |
| 166 | L'Exode | Mastodonte | 15 | 20 | 1 | 1 | 7 | L'air saturé de fumée réduit votre Adresse de **1 point**. Pas de Domination ni de victoire par Chance possible. Si vous êtes toujours vivant, le combat s'arrête après **3 tours**, juste avant que le monstre puisse répliquer à votre 3ᵉ attaque. |
| 180 | La cité des Reflets | TROIS ASSASSINS MONSTRUEUX | 9 | 9 | 1 | 0 | 3 | Avoir pris l'initiative vous permet de porter votre première attaque sans subir de dommages. Leurs mouvements aberrants et l'horreur de leur visage vous perturbent : vos dégâts supplémentaires se transforment en **malus** qui réduisent vos dommages. |
| 197 | L'Exode | Perrodactyle vexé | 6 | 10 | 0 | 0 | 2 | Perturbé par votre intervention, son cri réduit votre Habileté de **1 point tous les 2 tours**, cumulatif jusqu'à la fin du combat. Le Nain est figé : le Pyro-Barbare ne donne que **+2 Habileté**. Vous infligez **+1 dégât supplémentaire** avec l'Arc ou la Lance. |
| 225 | Violence Vraie | La poigne filante | 7 | 14 | 0 | 0 | 0 | Il ne reçoit de dégâts que pour les attaques infligeant entre **3 et 8 PV inclus** (sinon aucun effet). Il vous attaque **deux fois par tour** (2 jets de dégâts identiques, chacun esquivable séparément, mais seul le premier peut donner lieu à une contre-attaque critique). Si vous ne l'avez pas vaincu en **3 tours**, il s'échappe vers le module 206. N'oubliez pas d'appliquer les conditions spéciales déclenchées au module précédent. |
| 234 | Justice Juste | Garde des nains | 9 | 11 | 1 | 0 | 0 | Vous êtes en infériorité numérique : **-1 Adresse**. Dès que les PV adverses passent sous la moitié, vous tuez un des gardes : votre Adresse est restaurée, mais le garde restant, furieux, gagne **+1 dégât** pour le reste du combat. |
| 237 | La cité des Reflets | Abomination de plus | 5 | 5 | 1 | 0 | 0 | Ses mouvements aberrants et l'horreur de son visage vous horrifient : vous ne pouvez pas faire appel à la CHANCE durant ce combat. |
| 250 | La cité des Reflets | Trois sans visages | 9 | 9 | 1 | 0 | 3 | Ses mouvements aberrants et l'horreur de son visage vous horrifient : vous subissez tous les dommages sans pouvoir les réduire. |
| 256 | Violence Vraie | Mimine | 99 | 99 | 99 | 99 | 0 | Chaque tour après le premier, Mimine vous retire **1 PV** en vous picorant (esquivable, mais non réductible). Faites un seul jet de dé par tour et notez sa parité. Le combat continue tant que vous n'avez pas obtenu **3 jets pairs consécutifs OU 3 jets impairs consécutifs** ; dès que c'est le cas, le combat s'arrête. |
| 268 | La cité des Reflets | 2 assassins monstrueux | 7 | 7 | 1 | 0 | 3 | Ses mouvements aberrants et l'horreur de son visage vous horrifient : vos bonus de dégâts se transforment en **malus** de dégâts. |
| 282 | Violence Vraie | Torche dardante | 11 | 17 | 0 | 0 | 0 | Ce Nain vous envoie une boule de feu tous les **2 tours**, infligeant **2 PV non esquivables**. Avec la Crème Solaire, ces dégâts sont réduits de moitié. Si vous n'avez pas neutralisé ses flammes, ses attaques physiques ignorent votre Armure. N'oubliez pas d'appliquer les conditions du module précédent. |
| 293 | La Larme | Gnoll surpris | 3 | 7 | 0 | -1 | 0 | Vous gagnez dès la première attaque (le combat se termine immédiatement en votre faveur). |
| 296 | Le Guide | Creuse de la fontaine | 6 | 6 | 1 | 0 | 0 | Pas de CHANCE possible durant le premier tour. |
| 312 | La cité des Reflets | Cushom le garde | 7 | 9 | 1 | 0 | 0 | Vous perdez **1 point de Chance à chaque tour**, et vous ne pouvez pas gagner ce combat automatiquement (pas de victoire par Domination). |
| 321 | Le Guide | Creux de la caserne | 10 | 10 | 1 | 0 | 4 | Vos bonus de dégâts deviennent des **malus** de dégâts lors du premier tour seulement ; à partir du 2ᵉ tour, combat normal. |
| 323 | La Larme | Gardien surpris | 12 | 24 | 1 | 1 | 6 | Votre stratégie réduit votre Adresse de **1 point**, mais l'effarement de votre adversaire l'empêche d'attaquer pendant **2 tours**. Avant chaque phase d'attaque, lancez un dé : **1** → vous perdez 2 PV ; **2-3** → malus de 2 Habileté pour ce tour ; **4-5** → bonus de 2 Habileté ; **6** → vous infligez +2 dégâts et ne subissez aucun dégât ce tour. |
| 432 | Le Guide | Creux isolé | 6 | 6 | 1 | 0 | 0 | Même si le Pyro-Barbare ne peut pas intervenir pendant votre duel, vous refusez de vous laisser intimider : combat à la régulière (aucun effet particulier). |
| 436 | Le Guide | Creux vizir | 8 | 8 | 1 | 0 | 0 | Vous ne pouvez pas relancer votre dé durant le premier tour. Deux gardes viennent en aide au Creux : **-2 Adresse** pour vous, **+3 Habileté** pour lui. Votre lampe fait effet à la fin du **2ᵉ tour** : les gardes restent paralysés par sa soudaine révélation pour le reste du combat. |
| 474 | La Larme | Banc de requins des sables | 10 | 20 | 0 | 2 | 4 | Votre Adresse est réduite de **1 point**. Au début de chaque tour, testez vos réflexes en lançant 2 dés : si le total est **inférieur ou égal à votre Habileté**, vous abattez un requin dès sa sortie du sable et menez une phase d'attaque sans subir de dégâts en retour ; sinon, tour de combat normal. Vous ne pouvez infliger que **4 points de dégâts maximum par tour**. |
| 480 | La cité des Reflets | DEUX INCARNATIONS DU VIDE | 7 | 7 | 1 | 0 | 0 | Vous subissez **-1 Adresse**. Leurs mouvements aberrants et l'horreur de leur visage vous écœurent : vous ne pouvez ni relancer vos dés, ni obtenir de Critique. Le Pyro-Barbare arrive à votre rescousse à la fin du **3ᵉ tour** et met fin au combat. |
| 481 | Le Guide | CREUX ISOLE | 6 | 6 | 1 | 0 | 0 | Même si le Pyro-Barbare ne peut pas intervenir pendant votre duel, vous ne vous laissez pas intimider (aucun effet particulier). |
| 514 | La Larme | GARDIEN DE LA NECROPOLE | 14 | 24 | 1 | 1 | 4 | Votre adversaire est prodigieusement agile et expérimenté : même votre supériorité numérique ne l'empêche pas d'utiliser ses 4 bras pour vous réduire de **1 Adresse**. Les coups critiques ne lui infligent aucun dommage. Ses lames dentelées vous infligent **+1 PV supplémentaire à chaque tour** si vous n'avez pas esquivé. Si **Khazin** vous accompagne : il inflige 2 PV de dégâts par tour à l'ennemi et vous donne **+3 Habileté**. Si **Frère Plouf** vous accompagne : il arbitre le combat et contraint la créature à ne pas appliquer une de ses 3 règles ci-dessus, au choix de Billy au début de chaque tour. |
| 532 | Le Guide | CREUX DES ECURIES | 10 | 10 | 1 | 0 | 4 | Vous subissez tous les dommages sans pouvoir les réduire durant le premier tour ; vous parvenez ensuite à dominer votre répugnance et à combattre normalement à partir du 2ᵉ tour. |
| 564 | Le Guide | SCORPYDRE A QUATRE QUEUES | 8 | 12 | 3 | 1 | 4 | Malgré l'avantage offensif de ses nombreuses queues, leur simple volume empêche la créature de toutes les surveiller à la fois : vous bénéficiez de **+1 Adresse** pour ce combat. Sa carapace, en revanche, reste formidablement épaisse *(Armure=3, déjà reflétée dans la colonne Arm)*. |
| 584 | Le Guide | ARMEE DE CREUX | 32 | 32 | 1 | -1 | 30 | Investi des pleins pouvoirs de la Guide et de la confiance des nains, votre pouvoir de classe est décuplé : **GUERRIER** → +2 dégâts ; **PAYSAN** → plafond de 2 PV subis max ; **DÉBROUILLARD** → peut relancer son dé d'esquive ; **PRUDENT** → quadruple ses dégâts sur un jet de Chance réussi (même si la fuite est impossible dans ce combat). Aucune Domination possible : battez-vous jusqu'au bout ! |
| 608 | Le Guide | CREUX DE LA PRISON | 7 | 7 | 1 | 0 | 4 | L'urgence de la situation vous fait oublier l'angoisse que ces créatures vous inspirent habituellement. Vous avez **2 tours** pour vaincre les Creux, sinon votre plan est découvert et des renforts venus de la porte principale vous submergent (défaite forcée). |
| 630 | Le Guide | L'Usurpatrice | 16 | 26 | 1 | 1 | 0 | Les nains sont paralysés, le destin de Stia est entre vos mains : plus de Domination ni de fuite possible, c'est vous (et vos djinns) contre le pouvoir de la Larme. À chaque tour, elle projette un bloc de marbre infligeant **2 points de dégâts**, esquivable mais sans contre-attaque critique possible. Son camouflage vous déstabilise : tous vos dégâts sont **divisés par deux (arrondi à l'inférieur)** lorsque vous obtenez un **dé impair** en phase d'attaque. Elle est pleine maîtresse de la situation : votre **Critique est réduit à 0**. Selon votre archétype : **GUERRIER** → vos djinns de feu embrasent vos armes, **+3 dégâts** ; **PAYSAN** → vos djinns de terre bloquent et renvoient les projectiles, **1 PV/tour** infligé à l'adversaire ; **PRUDENT** → vos djinns d'eau brisent ses illusions, lui retirent projectiles et protection sur vos dés impairs, et elle perd **1 point à ses 4 caractéristiques** ; **DÉBROUILLARD** → vos djinns de vent restaurent votre CRITIQUE et l'augmentent de **+2**. Le visage de la traîtresse se délite : elle perd **1 point d'Habileté tous les 3 PV perdus**. Si Nadee a été neutralisée avant ce combat, le Pyro-Barbare se joint à vous : **+5 Habileté**. |
| 649 | Les Sables d'Ivoire | Zarh du souffle de Zarh | 40 | 40 | 4 | 4 | 20 | Vous êtes l'Avatar de Phumta lui-même. La bénédiction de Mutra ajoute vos points de **Chance max, Endurance et Adresse** à votre Habileté pour porter des coups furieux. La bénédiction de Neit vous fait **esquiver tous les dommages** si vous obtenez un **dé impair** en phase d'attaque, sans même passer par une phase d'esquive. La bénédiction de Phumta vous permet de **choisir à l'avance la valeur d'un dé, 3 fois pendant ce combat**. Aucune Domination ni victoire par Chance possible, et dépêchez-vous : leur pouvoir s'amenuise déjà, vous perdez **1 point d'Habileté tous les 3 tours**. |
| 686 | Le Guide | Avatar de Vetherr | 0 | 30 | 0 | 0 | 5 | L'Avatar de Vetherr, matérialisé sous sa forme la plus abjecte et inhumaine, n'existe que pour vous anéantir, vous et tout ce que vous représentez, à n'importe quel prix. À chaque tour, il tire un unique trait d'énergie pure infligeant **4 dégâts absolus** s'il vous touche. Il n'attaque d'aucune autre manière et n'esquive jamais vos coups, vous plaçant en **AVANTAGE LOURD complet**. Vous pouvez choisir d'encaisser volontairement son rayon sans tenter de l'esquiver, pour un bonus de **+4 dégâts**. |
| 689 | Les Sables d'Ivoire | Titan des glaces | 0 | 40 | 0 | 0 | 0 | Vous concentrez la rage pure de Phumta dans vos armes et l'amplifiez grâce au feu sacré du Pyro-Barbare : vous perdez la totalité de votre **Adresse, Critique et Armure**, mais convertissez chaque point perdu en **dégâts supplémentaires**, en y ajoutant le total de votre **Rancune**. Vous n'esquivez plus rien : **DÉSAVANTAGE LOURD total**. Peu importe : aucune Domination, aucune victoire par Chance, et **ignorez la moitié de ses dommages**. |
