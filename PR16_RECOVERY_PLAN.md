# Plan de récupération — apports de la PR #16

Comparaison entre notre branche (`ux-combat-screen`) et la PR #16
(`linklinsse/refacto_V4`, réécriture complète Godot 4), bloc par bloc.
Décisions actées au fil de l'analyse. Rien n'est codé encore — ce document
est le backlog de référence pour la suite.

Méthode constante sur chaque bloc : lecture seule (jamais de checkout de
`ux-combat-screen`, uniquement `git show ux-combat-screen:<path>`), et
chaque affirmation vérifiée contre le vrai code des deux côtés avant
d'être notée — pas une impression de lecture.

Blocs traités : Combat (§1), Popups (§2), Fins/Succès (§3), Son/Thème (§4),
Santé générale du code (§5).

**Incident de parcours (pour mémoire)** : un agent de recherche dispatché
en lecture seule sur le bloc Fins/Succès a accidentellement supprimé ce
fichier (`rm -f`) avant de l'avoir lu, malgré une consigne stricte. Non
récupérable via git (jamais indexé). Reconstruit à l'identique depuis le
contexte de la conversation — aucun contenu perdu, mais leçon retenue :
les agents de recherche doivent être encore plus explicitement mis en
garde contre toute écriture, même accidentelle.

**Revue adversariale (2026-08-31)** : les 29 points ci-dessous ont
ensuite été contre-vérifiés par 5 agents indépendants (un par bloc),
consigne explicite de chercher à RÉFUTER chaque affirmation avant de la
valider. Résultat : 22 points confirmés tels quels, 6 imprécisions
mineures corrigées en place (comptages/attributions), et **1 correction
majeure qui inverse une conclusion** (§10-11, cf plus bas) grâce à une
preuve tierce trouvée dans l'historique git de la PR16 (transcription
manuelle indépendante de la table de combat). Les corrections sont
intégrées directement dans le texte ci-dessous ; les points laissés tels
quels ont donc déjà survécu à cette contre-expertise.

---

# Bloc 1 — Combat

Sources lues :
- PR16 : `autoload/combat_engine.gd`, `autoload/combat_assault_resolver.gd`,
  `autoload/combat_table.gd`, `data/combat-table.json`,
  `screens/aventure_menu/combat.gd`, `test/unit/test_combat.gd`.
- Nous : `combat.gd`, `combat_modificateurs.gd`, `combat_screen_controller.gd`,
  `CombatScreen.gd`, `main.gd`.

## 0. Bug pré-existant chez nous, découvert en creusant (PRIORITÉ — indépendant de la PR)

Deux mécaniques codées et testées chez nous ne sont **jamais appliquées en
jeu réel** parce que `main.gd` (appel à `$Combat.start_combat_multi()`,
~ligne 115) ne transmet ni `plafond_degats_subis_billy` ni `modificateurs`
dans les `opts` du vrai appel :

- **Plafond PAYSAN** (3 PV/tour max) : `combat.gd` le sait faire, testé en
  isolation, jamais branché. Un PAYSAN en jeu réel n'en bénéficie jamais.
- **Modificateurs par chapitre** (125 tests : gnoll qui divise l'Habileté,
  esquive adverse sur dé pair, dégâts périodiques, `FinCombatSurParitesConsecutives`
  pour le nœud 256 "Mimine"...) : système entier jamais transmis, donc
  jamais actif.

**Conséquence concrète vérifiée** : le nœud 256 (cdsi, "Mimine") a un bloc
combat `hab=99, pv=99, arm=99, deg=99` (confirmé identique dans les deux
compilations — attention, côté PR16 c'est dans `books/cdsi/data/cdsi-compilated.json`,
pas dans `books/fdcn/data/fdcn-compilated.json` où le nœud 256 est un
chapitre "Lenonia" sans rapport) — un marqueur narratif, pas un vrai adversaire.
La règle qui doit le neutraliser existe (`combat_modificateurs.gd`) mais
n'est jamais appliquée : un joueur qui atteint ce chapitre aujourd'hui
affronte un ennemi à 99 PV/99 armure/99 dégâts sans aucune protection.

**Action** : rebrancher `plafond_degats_subis_billy` (via `AppParameters.get_billy_type() == 'paysan'`)
et `modificateurs` (lookup par `node_id`, à construire — actuellement rien
n'associe un nœud à ses Modificateurs côté `main.gd`/`chapter_data.gd`)
dans l'appel réel. À faire **avant** ou **avec** l'item 8 ci-dessous, pas
après — sinon la détection sentinelle de la PR n'a rien à remplacer.

### Plan de correction

**Ampleur réelle, vérifiée** : `test_combat_regles_speciales_tome1.gd` +
`_tome2.gd` couvrent **56 nœuds distincts** (chapitres avec au moins une
règle spéciale testée), sur les deux livres. Ce n'est pas une poignée
d'entrées oubliées — c'est un sous-système entier (les Modificateurs)
écrit, testé, jamais connecté à la partie réelle. `combat_modificateurs.gd`
lui-même ne contient QUE des classes ; aucun registre `node_id -> Array[Modificateur]`
n'existe nulle part dans le code applicatif (confirmé par grep sur tout le
dépôt) — seuls les tests construisent des instances directement.

**1. Plafond PAYSAN** — trivial. Un seul endroit à changer :
`main.gd`, le point d'appel `$Combat.start_combat_multi(...)` (~ligne 115) :
ajouter `"plafond_degats_subis_billy": 3 if AppParameters.get_billy_type() == 'paysan' else null`
dans le dict `opts`. Pas de nouveau fichier, pas de nouvelle donnée.

**2. Registre de Modificateurs par nœud** — le vrai chantier :
- Construire un registre `node_id -> Array[Modificateur]` (nouveau fichier,
  ex. `combat_modificateurs_par_node.gd`, ou une fonction dédiée dans
  `combat_modificateurs.gd`).
- Reprendre les 56 nœuds un par un : chaque commentaire "Nœud NNN" en
  tête de classe dans `combat_modificateurs.gd` donne déjà la bonne
  instanciation à répliquer (paramètres, callables de dé à injecter le
  cas échéant — ex. `EvenementAleatoireGardienSurpris` pour le nœud 323).
  Croiser avec les tests (`test_combat_regles_speciales_tome1/2.gd`) pour
  ne rien oublier et récupérer les valeurs exactes des constructeurs.
- Câbler `main.gd` pour lire ce registre par `node_id` et le passer dans
  `opts["modificateurs"]`.
- **Ne pas se fier aux seuls tests unitaires existants comme preuve de
  succès** (ils construisent les Modificateurs directement, donc restent
  verts même si le câblage réel reste cassé). Vérifier avec un vrai
  playthrough E2E sur au moins 2-3 nœuds emblématiques (256 "Mimine", 97
  "brasier périodique", 649 "bénédiction de Neit") pour avoir une preuve
  que la règle s'applique vraiment en jeu, pas seulement en isolation.
- Ordre de grandeur : gros morceau, à traiter comme sa propre phase, pas
  un "quick fix" annexe à autre chose.

**Décision d'implémentation reportée** — ce document reste un plan, rien
n'est codé. À valider avant de commencer : fait-on cette correction avant
tout portage d'éléments de la PR16 (recommandé, cf remarque en tête de
§0), ou en parallèle ?

### Fait (session du 2026-09-01)

- **Plafond PAYSAN** : rebranché dans `main.gd` (opts `plafond_degats_subis_billy`).
- **Registre de Modificateurs** : nouveau `combat_modificateurs_par_node.gd`
  (`for_node(book_number, node_id) -> Array`), câblé dans `main.gd` (opts
  `modificateurs`). Couvre 50 des 56 nœuds testés (catalogue complet
  construit puis chaque nœud revérifié directement contre
  `test_combat_regles_speciales_tome1/2.gd` + `COMBATS_REGLES_SPECIALES(_TOME2).md`
  avant câblage — deux erreurs trouvées et corrigées en cours de route :
  le nœud 339 avait été classé à tort "condition externe" par un premier
  passage alors que son médaillon est un vrai item suivi par
  `Player.possessed_items` ; un test a aussi attrapé un nœud 607 câblé par
  erreur malgré la décision de l'exclure). Vérifié par :
  - `test/unit/test_combat_modificateurs_par_node.gd` (structure du registre).
  - `test/integration/test_combat_modificateurs_wiring.gd` (câblage réel
    via `main.gd`, avec effet observable pour les 3 nœuds emblématiques du
    plan : 256 "Mimine", 97 "brasier périodique", 649 "bénédiction de Neit").
  - `tous_les_combats.json` (E2E existant, visite déjà TOUS les nœuds de
    combat du jeu, y compris les exclus) : aucun crash après câblage.
  - Suite complète : 567 tests, 559 passent (8 échecs pré-existants, sans
    rapport — simulation tactile sous Xvfb headless).

  **Décisions actées explicitement par l'utilisateur (session du
  2026-09-01)** :
  - 5 nœuds dépendent d'un état introuvable aujourd'hui (Jet de Chance
    réévalué chaque tour, test de réflexes, choix narratif fait PENDANT le
    combat, sans aucune UI pour le capturer) : **câblés avec la condition
    gelée à sa valeur neutre** (la règle de base s'applique, l'effet
    exceptionnel ne se déclenche jamais) plutôt que construire l'UI
    manquante ou les exclure entièrement — 387 (Tome 1), 474, 514 (volet
    Frère Plouf seulement — le volet Khazin du même nœud est un vrai item,
    câblé normalement), 584, 686 (Tome 2).
  - **Nouveau sous-système découvert, hors périmètre, todo distinct** : en
    construisant le registre, plusieurs nœuds (au moins 76/155/231/370/518)
    se sont révélés avoir AUSSI une règle "côté appelant" documentée dans
    `COMBATS_REGLES_SPECIALES(_TOME2).md` — un ajustement fixe d'Arme/Adresse
    (ex: ARC inéquipable contre les squelettes, +2 dégâts avec Morgenstern,
    -1 à -3 Adresse d'encerclement) que `main.gd` ne calcule pas non plus
    aujourd'hui. Ce n'est PAS une classe `Modificateur` — un DEUXIÈME
    registre distinct serait nécessaire (nœud -> ajustement de stat direct
    passé à `Combat.new()`), non construit ici sur décision explicite.
  - **Exclus du registre, todo distinct** : 306 (aucun test dédié — motivé
    seulement par un commentaire de classe) ; 475/607 "Virilus" (combat
    final) -- `DeSupplementaireParTour` ("Gant de Virilus") n'est exercé
    par AUCUN test, et les deux nœuds nécessitent en plus un chaînage
    d'état entre deux instances `Combat` successives (malus d'Habileté à
    ne pas cumuler en phase 2 si déjà appliqué en phase 1), une
    orchestration côté `main.gd` qui n'existe pas non plus aujourd'hui.
  - La variante "surpris" de 36/97 (limite de tours étendue à 8 via les
    INFOS du joueur) n'a pas de seuil d'INFOS déterminable depuis les
    tests/docs consultés -- seule la variante par défaut (5 tours,
    non-surpris) est câblée pour le nœud 36. 97 n'a que son brasier
    périodique câblé (sa `LimiteDeTours` n'a aucun test dédié).

---

## 1. À reprendre — DÉBROUILLARD : relance et garde le meilleur dé

**État chez nous** : absent. Le type DÉBROUILLARD n'a que des bonus de
stats statiques à la création (`player.gd::_apply_billy_stats()`), aucun
pouvoir dynamique en combat.

**Référence PR16** : `CombatEngine.can_reroll()`/`reroll()` — relance une
fois par assaut, garde le **plus haut** des deux dés (jamais un remplacement
qui pourrait donner pire). Bouton "Relancer" visible seulement pour ce
type, désactivé après usage.

**À faire** : ajouter le pouvoir dans `combat.gd::play_turn()` (ou en
paramètre optionnel comme le fait déjà `attack_die_roll`), + bouton dans
`CombatScreen.gd`, + tests.

---

## 2-4. À noter dans la todo — pouvoirs PRUDENT

Absents chez nous, présents et câblés côté PR16 :

- **Esquive à la chance** (distincte de l'esquive à l'adresse qu'on a
  déjà) : annule les dégâts reçus, coûte 1 chance, ne peut jamais rater.
- **Fuir le combat entier** contre de la chance (coût variable selon la
  situation — cf `FUITE_COST` chez nous, déjà écrit mais **mort**, aucun
  appelant).
- **Survie à un coup mortel** (jet après la "mort", réussi si ≤ chance
  courante, tombe à 1 PV). ⚠️ **PR16 flague elle-même cette règle comme
  non confirmée** — la liste officielle récente des 4 pouvoirs ne mentionne
  que "chance pour esquiver une attaque ou le combat", pas ce 3ᵉ effet.
  **Ne pas porter avant vérification à la source.**

**Action** : entrée todo, pas de priorité immédiate. Vérifier la règle de
survie avant toute implémentation.

---

## 5. À reprendre — table de combat data-driven (JSON)

**État chez nous** : `SITUATION_TABLE`/`FUITE_COST`/`TIER_NAMES`, trois
constantes GDScript éparpillées dans `combat.gd`.

**Référence PR16** : un seul `data/combat-table.json`, situations nommées
("Désavantage lourd", etc.) avec leur coût de fuite associé, chargé et
normalisé par `CombatTable` (`autoload/combat_table.gd`).

**Action** : migrer vers un fichier JSON unique, plus facile à auditer/
corriger sans toucher au code. **Utiliser nos valeurs numériques
actuelles** (cf §10-11 — confirmées correctes par vérification directe
contre la source), pas celles du fichier PR16 tel quel.

---

## 6. À reprendre — victoire automatique au-delà de la table (`is_auto_win()`)

Si l'écart réel dépasse la borne haute de la table (+7), victoire sans
lancer le moindre dé. Actuellement chez nous, `clamp_diff()` clampe
silencieusement à [-7, 7] et on rejoue quand même le tour à cette borne —
correct au niveau des dégâts, mais on pourrait aussi juste déclarer la
victoire sans passer par un jet de dé.

**Précision vérifiée** : côté PR16, ce court-circuit est **asymétrique** —
`is_auto_win()` ne vaut que dans le sens favorable à Billy (écart > +7).
En-dessous de -7, pas de "défaite automatique" équivalente : le tour se
joue quand même sur la ligne -7, exactement comme chez nous, avec juste
`is_ecart_plafonne()` qui prévient l'UI (cf §7). Si repris, ne pas
introduire de défaite automatique symétrique sans base sourcée pour ça.

---

## 7. À reprendre — signal "écart plafonné" (`is_ecart_plafonne()`)

Prévenir l'UI quand l'écart réel dépasse ce que couvre la table, pour ne
pas donner l'impression d'un bug quand la situation affichée est "plus
favorable" que la réalité brute.

---

## 8. Détection "sentinelle" (bloc 99/99/99/99) — rattaché à l'item 0

Cf explication détaillée en tête de document. Ne pas traiter isolément :
d'abord rebrancher nos propres modificateurs (item 0). Une fois ça fait,
évaluer si on veut EN PLUS le filet de sécurité générique de la PR
("si les 4 stats valent 99, ne pas automatiser, quel que soit le nœud")
en complément de nos règles bespoke par nœud — utile pour tout futur nœud
avec la même convention qu'on n'aurait pas encore repéré.

**Décision finale en attente.**

---

## 9. À reprendre — abandon total du combat (`cancel()`)

Retour au chapitre précédent avec restauration exacte (PV/chance/objets +
recalcul de la couche "chapitres") via un instantané pris avant que le
chapitre n'applique quoi que ce soit (`Player.arrival_snapshot` côté
PR16 — équivalent à créer chez nous). **Complémentaire**, pas remplaçant,
de notre undo par tour existant (`_on_undo_pressed()`/`_on_turn_chip_pressed()`).

---

## 10-11. Vérifié — nos valeurs sont correctes, pas d'action (confirmé par l'utilisateur contre la source)

**Historique de ce point** : la revue adversariale (agent) avait d'abord
trouvé une transcription manuelle tierce dans l'historique git de
`pr-16-review` (fichier `combat.md`, commits `0e7144e`→`2c69ef7`, par un
contributeur "Pierre-Alexandre") qui semblait corroborer les valeurs PR16
sur deux cellules litigieuses (écart -3/dé 4, coût de fuite "Désavantage
léger") plutôt que les nôtres. Sur cette seule base indirecte, la
conclusion avait été inversée.

**Tranché depuis par l'utilisateur, qui a vérifié directement contre la
source (le livre physique/l'image officielle) : notre version est la
bonne.** La transcription tierce trouvée dans l'historique PR16 contient
donc elle-même une erreur sur ces deux cellules — ce n'est pas la
première fois qu'une transcription manuelle indépendante se trompe, et
ça illustre bien pourquoi une preuve indirecte (une transcription d'un
contributeur, elle-même non vérifiée à la source) ne doit pas l'emporter
sur une vérification directe.

**Action** : aucune. Garder notre table telle quelle, sur ces deux
cellules comme sur le reste — ne PAS reprendre les valeurs du JSON PR16
lors du portage de l'item 5.

---

# Bloc 2 — Popups

Sources lues :
- PR16 : `popups/GenericConfirmationPopup.gd/.tscn`, `popups/ItemPopup.gd/.tscn`,
  `popups/SuccessPopup.gd`, `popups/settings_popup.gd`,
  `popups/sub/stats.gd`, `popups/sub/inventory.gd`, `popups/sub/book_selection.gd`.
- Nous : `scenes/GenericConfirmationPopup.gd/.tscn`, `ItemPopup.gd/.tscn`,
  `SuccessPopup.gd/.tscn`, `StatsScreen.gd`, `Item.gd`, `main.gd`/`main.tscn`
  (onglets Options, sélection de livre).

Recoupe fortement le travail fait cette session (opacité du popup,
bandeau animé, recherche équipement) — plusieurs bugs listés ici sont
**vérifiés existants dans notre code actuel**, pas des suppositions.

## 12. À reprendre — logs de debug qui spamment la console (bug réel, déjà observé)

**Vérifié, corrigé après contre-expertise** : `Item.gd` a 7 `print()` non
commentés au total (lignes 76, 79, 84, 100, 103, 109, 126) — pas "5-6".
La ligne 126 appartient en réalité à `_on_button_toggled()`, pas à
`refresh()`. Dans `refresh()` lui-même, l'exécution réelle par appel est
de **2 à 3** `print()` (ligne 100 toujours, puis 0 ou 1 parmi 76/79/84 via
`_can_item_be_shown()` qui `return` dès le premier match, puis 103 ou 109)
— pas 5-6 par appel comme écrit initialement. Le fond du problème reste
entier : appelé pour CHAQUE ligne à chaque ouverture de l'onglet
Équipement et à chaque case cochée, avec ~56-100+ objets ça fait bien des
centaines de lignes de console à chaque fois — **déjà vu concrètement
dans les logs E2E de cette session** ("ITEM:: BROCHE DOREE do have item?
false" répété en boucle).

**Référence PR16** : même diagnostic exact fait de leur côté ("`entities/
Item.gd` imprimait 2 à 4 lignes de debug par objet, soit 200 à 350
écritures console à chaque ouverture et à chaque case cochée"), corrigé
en supprimant les prints.

**Action** : supprimer/passer derrière un flag de debug les `print()` de
`Item.gd::refresh()`/`load_item_data()`/`_on_button_toggled()`. Trivial,
zéro risque.

---

## 13. À reprendre — jauge/bouton non désactivés aux bornes (Stats)

**Vérifié** : dans `StatsScreen.gd`, `disabled` n'est utilisé que pour le
verrou combat (`control.disabled = en_combat`), jamais pour signaler
qu'un bouton +/- est déjà à sa borne. Appuyer sur "+" quand PV est déjà au
max (ou "−" à 0) ne fait rien, sans aucun retour visuel — le bouton a
l'air cassé plutôt qu'inutile à cet instant.

**Référence PR16** : `stats.gd::_refresh_buttons()` grise explicitement
les boutons PV/Chance à leurs bornes ("un bouton qui ne peut plus rien
faire est grisé : à zéro ou au plafond, un bouton qui ne réagit pas
passerait pour cassé").

**Action** : ajouter le même grisage sur nos boutons +/- PV/Chance (et
pourquoi pas Chapitres/Autre par stat, même logique) dans `refresh()`.

---

## 14. À noter dans la todo — compteurs narratifs jamais affichés (`gloire`, etc.)

**Vérifié** : `player.gd` accumule bien un champ `gloire` (`self.gloire += v`,
via un effet de chapitre), mais **aucun écran ne l'affiche** —
`StatsScreen.gd::STAT_DEFS` ne couvre que les 7 stats de combat
(hab/end/adr/chamax/crit/deg/arm). Un joueur qui accumule de la gloire au
fil de l'aventure n'a aucun moyen de le voir en jeu.

**Référence PR16** : les compteurs propres à chaque livre (gloire/info
pour fdcn, rancune/respect pour cdsi) sont affichés génériquement sur
l'écran Stats, construits dynamiquement depuis `BookData.get_counters()`
plutôt que codés en dur.

**Action** : todo, pas urgent (aucun joueur ne s'est plaint de ne pas
voir sa gloire). Si repris, s'inspirer de l'approche data-driven plutôt
que d'ajouter une ligne en dur pour chaque compteur trouvé.

---

## 15. À reprendre — un seul point de branchement pour le changement d'onglet

**Vérifié, précisé après contre-expertise** : `main.gd` a bien 3 fonctions
quasi-dupliquées (`_options_show_equipement`, `_options_show_stats`,
`_options_show_book_select`), chacune appelant `__set_tab_selected`/
`__set_tab_not_selected` sur les 3 onglets à la main + 3 lignes
`.visible = true/false` séparées. **Précision** : le code mort en
commentaire ne traîne que dans 2 des 3 fonctions (`_options_show_stats`
lignes 796-816, `_options_show_book_select` lignes 831-844)
— `_options_show_equipement` (lignes 777-788) est propre, sans code mort
commenté. La triplication du schéma reste bien réelle sur les 3.

**Référence PR16** : `settings_popup.gd` pilote clic ET coloration depuis
une SEULE table `{onglet: scène}` — "une seule table pour brancher les
clics ET pour la coloration, sinon on finit par oublier un onglet d'un
côté".

**Action** : remplacer les 3 fonctions par une seule table
`{onglet_node: panel_node}` parcourue en boucle. Petit refactor, risque
faible, corrige un vrai defaut de maintenabilité (pas juste cosmétique —
la duplication a déjà laissé du code mort derrière elle).

**Note** : ceci ne veut PAS dire adopter l'architecture complète de PR16
(instancier/libérer chaque onglet à la demande plutôt que garder les 3
panneaux vivants en permanence) — juste le petit pattern de table
unique, sans changer notre structure "3 panneaux toujours en mémoire".

---

## 16. À noter dans la todo — sélection de livre en dur (2 boutons nommés)

**Vérifié** : notre sélection de livre repose sur 2 boutons nommés en dur
(`BoolSelectFcdn`/`BoolSelectCdsi`) avec une fonction dédiée chacun
(`_switch_to_book_fcdn`/`_switch_to_book_cdsi`). Ajouter un 3ᵉ livre
demanderait un nouveau bouton dans `main.tscn` + une nouvelle fonction +
un nouveau branchement.

**Référence PR16** : `book_selection.gd` construit une couverture par
livre déclaré dans `books/books.json`, dans une grille qui s'adapte au
nombre de livres — ajouter un livre ne touche à aucun code, juste au
registre + l'image de couverture. Livre sans image = bouton texte,
sélectionnable quand même.

**Action** : todo, pas urgent tant qu'on reste à 2 livres. Vaut le coup
si un 3ᵉ livre est un jour envisagé — sinon, changement d'architecture
sans bénéfice immédiat.

---

## 17. Vérifié — pas de bug chez nous (déjà correct, pour mémoire)

Trois bugs Godot 3→4 trouvés et corrigés côté PR16 sur `SuccessPopup`,
**vérifiés absents chez nous** :
- `Popup` (Godot 3) → `Window` (Godot 4) qui réduisait l'écran à 0×0 :
  **déjà corrigé indépendamment chez nous** (`SuccessPopup.gd` a le même
  diagnostic en commentaire, `extends Control` au lieu de `Popup`).
- Nom d'animation avec guillemets littéraux artefact de conversion :
  absent (`resource_name = "hide"/"show"`, propre).
- Ancre `anchor_right=0.0` + `offset_right=-8` donnant une largeur de
  -16 qui écrasait la carte de succès : absent (nos offsets donnent une
  largeur positive normale).

Matériaux de portrait Billy (grayscale) : PR16 avait un bug de matériau
partagé sur une version antérieure de leur code, **absent chez nous**
(6 `ShaderMaterial` distincts confirmés dans `main.tscn`, un par
portrait).

Rafraîchissement live de la liste Équipement au toggle Spoils : **déjà
correct chez nous** (`change_spoils()` → `refresh()` → `_refresh_options()`
→ `refresh_all_objects()` → `item.refresh()` par ligne).

**Aucune action.** Listé pour ne pas re-vérifier ces points plus tard.

---

# Bloc 3 — Fins / Succès

Sources lues :
- PR16 : `scripts/generator.py`, `autoload/book_data.gd`,
  `entities/EndingChoice.gd/.tscn`, `screens/succes_menu.gd`,
  `books/cdsi/data/cdsi-compilated.json`.
- Nous : `fdcn.py`, `BookData.gd`, `EndingChoice.gd/.tscn`, `Success.gd`,
  `main.gd::insert_all_success()`, fichiers `fdcn-N-compilated-*.json`.

## 18. Vérifié — le bug "cdsi n'a jamais eu de fin compilée" était déjà corrigé chez nous, avant la PR16

**Vérifié** : PR16 documente dans `scripts/generator.py` avoir corrigé un
test `goto == 608 and book_number == 1`, qui ne compilait jamais aucune
fin de cdsi. **Nous avions le même bug, corrigé nous-mêmes avant même
l'existence de la PR16** : commit `7a5612a` (2026-07-08, *"Fix: fdcn.py
détectait les fins de livre via le type de `goto` (sentinel "ending"
désormais, indépendante de goto. Données livre 1/2 régénérées.)"*), avec
un commentaire quasi identique dans notre `fdcn.py` actuel expliquant le
même diagnostic.

**Vérification chiffrée** : nos données compilées (`fdcn-2-compilated-endings.json`)
contiennent 16 fins pour cdsi (5 bonnes/11 mauvaises) — chiffre **identique**
à celui vérifié côté PR16 (`books/cdsi/data/cdsi-compilated.json`, 5
`ending_type=1` + 11 `ending_type=2`). Même résultat final, corrigé
indépendamment des deux côtés.

**Renforcé après contre-expertise** : le fix équivalent côté PR16 est
daté du commit `2c69ef7` (2026-08-13) — plus d'un mois **après** notre
`7a5612a` (2026-07-08). `7a5612a` n'est pas un ancêtre de `pr-16-review` :
deux corrections bien indépendantes, la nôtre antérieure.

**Action** : aucune. Déjà bon.

---

## 19. À reprendre — succès multi-chapitres mal géré (`PHOBIE-ADMINISTRATIVE`, cdsi)

**Vérifié, vrai bug fonctionnel chez nous** : le succès cdsi
`PHOBIE-ADMINISTRATIVE` est déclaré à DEUX chapitres (98 et 498) dans
`fdcn-2-compilated-success-chapters.json`, et apparaît donc **en double**
dans `fdcn-2-compilated-success.json` (seul doublon du fichier, aucun
équivalent côté livre 1).

**Mécanisme du bug** : `main.gd::insert_all_success()` boucle sur la
liste brute (avec doublon) et instancie une ligne `Success.tscn` par
entrée — deux lignes identiques affichées. Chaque ligne vérifie
`Player.did_all_times_seen(chapter_id)` avec **son propre** `chap_number`
(98 OU 498). Conséquence vérifiée : un joueur qui obtient ce succès
uniquement via le chapitre 498 voit la ligne "chapitre 98" rester grisée
("non obtenu") alors que le succès est réellement acquis — faux négatif,
en plus de l'affichage dupliqué.

**Référence PR16** : `autoload/book_data.gd::_completer_succes()`
dédoublonne par `success['id']` à la construction, et
`is_success_obtenu(success_id)` parcourt TOUS les chapitres associés à
cet id (pas un seul `chap_number`) pour décider si le succès est obtenu.

**Action** : à reprendre. Dédupliquer `all_success` par `id` dans
`BookData.gd`, et faire dépendre l'état "obtenu" de tous les chapitres
associés à l'id plutôt que du seul chapitre affiché sur la ligne. Le motif
(un succès, plusieurs chapitres déclencheurs) pourrait réapparaître dans
un futur contenu, pas seulement ce cas précis.

---

## 20. Vérifié — ruban "Bonne fin / Mauvaise fin" : rien à changer

**Vérifié** : couleurs (`Color('00c2aa')`/`Color('ff6f04')`) et
géométrie du polygone identiques au pixel près des deux côtés — PR16 n'a
PAS de système data-driven pour ça non plus (couleurs codées en dur chez
eux aussi, dans plusieurs fichiers). Pas un gap, juste un portage 1:1.

**Action** : aucune.

---

# Bloc 4 — Son / Thème

Sources lues :
- PR16 : `autoload/sounder.gd`, `autoload/narrator.gd`, `autoload/README.md`,
  `themes/README.md`, `themes/fdcn.tres`, `sounds/`.
- Nous : `Sounder.gd/.tscn`, `main.gd` (fonctions son), `SuccessPopup.gd/.tscn`,
  `LoreEntry.gd/.tscn`, `CombatScreen.gd`, `StatsScreen.gd`,
  `scenes/GenericConfirmationPopup.gd`, `project.godot`, `themes/`.

## 21. À noter dans la todo — `AudioStreamPlayer2D` au lieu de `AudioStreamPlayer` (piège dormant)

**Vérifié** : `Sounder.tscn::Player` est un `AudioStreamPlayer2D`
(positionnel), alors qu'aucun son de l'app n'a de position réelle.
Actuellement sans effet visible, mais c'est exactement le même piège que
PR16 documente avoir corrigé délibérément dans leur `sounder.gd`
("Node2D / AudioStreamPlayer2D … c'était un piège dormant").

**Action** : todo, correction mineure et sûre (changer le type de nœud).

---

## 22. À reprendre — trois lecteurs audio différents au lieu d'un point unique

**Vérifié** : en plus de `Sounder` (le point de lecture censé être
central), TROIS autres endroits jouent du son directement, en dupliquant
la logique charger/jouer/stopper et en contournant le cache/l'exclusivité
de `Sounder` :
- `main.tscn`/`main.gd::_play_node_sound()` : un `AudioStreamPlayer2D`
  `AudioPlayer` propre, qui semble mort (arrêté mais jamais joué — la
  lecture réelle passe par `Sounder.play()` juste après).
- `SuccessPopup.tscn`/`SuccessPopup.gd::_new_success_play_sound()` : son
  propre `AudioStreamPlayer`, `load()`+`play()` directs, ne consulte
  `Sounder` que pour la garde `is_enabled()`.
- `LoreEntry.tscn`/`LoreEntry.gd::_on_play_pressed()` : même chose.

Conséquence : un son de succès ou une narration de lore peut en théorie
se superposer au son `Sounder` en cours, alors que `Sounder` est conçu
pour n'en jouer qu'un à la fois.

**Référence PR16** : `autoload/sounder.gd` est l'unique point de lecture
de toute l'app (confirmé par leur propre doc `autoload/README.md`).

**Fait** : `main.gd::_play_node_sound()` (le `$AudioPlayer` mort, node +
.tscn supprimés) et `SuccessPopup.gd::_new_success_play_sound()` (remplacé
par `Sounder.play('lennon-c-beau.mp3')`, `$AudioPlayer` local supprimé)
passent désormais par `Sounder`. Piège trouvé et corrigé au passage : le
nœud 338 (fdcn, "CHUT") est À LA FOIS un chapitre à narration dédiée ET un
succès — les deux appelaient `Sounder.play()` l'un après l'autre, le
second écrasant le premier. `go_to_node()` déclenche maintenant le jingle
de succès AVANT la narration du chapitre, pour que celle-ci reste ce qui
joue une fois la page affichée.

**Décision explicite : `LoreEntry.gd` reste avec son lecteur local**,
pas unifié. Raison : c'est un vrai bouton play/pause (pas un son
ponctuel), et jusqu'à 18 instances peuvent coexister à l'écran — les
unifier vers `Sounder` aurait exigé un signal de synchronisation pour que
l'icône d'une autre entrée se remette à "lecture" quand une nouvelle
commence (`Sounder.player.stop()` ne déclenche pas `finished`). Jugé hors
scope pour cette passe ; à reprendre séparément si souhaité.

---

## 23. À noter dans la todo — pas de `Narrator` découplé (dette de maintenabilité, pas un bug)

**Vérifié, précisé après contre-expertise** : chez nous,
`main.gd::_play_node_sound()`/`_play_intro()` contiennent des tables
codées en dur par livre/chapitre — ajouter un livre ou une narration
impose de modifier ce fichier central. **Précision** : le dict vide pour
cdsi ne concerne QUE `_play_node_sound()` (`node_sound_fnames[2] = {}`) ;
`_play_intro()` a bien une entrée pour cdsi (`intro_sound[2] = 'intro-cdsi.mp3'`).
Pas de fonction équivalente à `has_narration(node_id)` dans les deux cas.

**Référence PR16** : `autoload/narrator.gd`, autoload dédié piloté par
signaux (`book_changed`, `chapter_changed`), qui teste juste l'existence
du fichier audio plutôt que de le déclarer dans une table ("un livre muet
est un livre sans dossier audio, pas une erreur").

**Action** : todo, refonte plus profonde, pas urgente — fonctionnellement
nos sons jouent correctement aujourd'hui.

---

## 24. Vérifié — contenu audio équivalent, aucune action

Mêmes fichiers son des deux côtés (billy-*, lennon-c-beau, intros, dieux/*),
seule différence organisationnelle (PR16 range par nom de livre et sort
les narrations de chapitre vers `books/<nom>/audio/`). **Précisé après
contre-expertise** : `lennon-rire.mp3` est présent chez nous mais
inutilisé (orphelin) — côté PR16, il n'est pas "présent mais inutilisé",
il **n'existe carrément pas** dans leur arbre (confirmé par
`ls-tree`). La conclusion pratique ne change pas (hors périmètre, aucune
action), juste la formulation qui suggérait à tort une symétrie.

**Action** : aucune action urgente.

---

## 25. À reprendre — pas de thème central, stylisation dupliquée dans le code (écart le plus net du bloc)

**Vérifié, chiffré précisément (corrigé après contre-expertise)** :
- `project.godot` chez nous n'a **aucune** ligne `theme/custom` — pas de
  Theme Godot central.
- `themes/` chez nous ne contient qu'un fichier orphelin
  (`side_buttons_background_style.tres`, référencé par AUCUN `.tscn`/`.gd`).
- `COL_NAVY`/`COL_TEAL` et consorts sont dupliquées à l'identique (mêmes
  valeurs flottantes à la décimale) dans 3 fichiers, mais **pas dans la
  même proportion** : `CombatScreen.gd` (11 constantes), `StatsScreen.gd`
  (9), `scenes/GenericConfirmationPopup.gd` (**4 seulement**, pas 9-11 —
  correction du chiffrage initial qui groupait les 3 fichiers sous une
  même fourchette). Le cœur de l'affirmation (duplication à l'identique
  des valeurs communes `COL_NAVY`/`COL_CARD`/`COL_CARD_ALT`/`COL_INK`)
  reste confirmé dans les 3. `_style_solid_button()` est une fonction
  quasi-identique dupliquée dans ces 3 mêmes fichiers.
  `StyleBoxFlat.new()` apparaît **25 fois** au total dans le dépôt (pas
  23 — le chiffre initial ne comptait que les 3 fichiers ci-dessus
  (12+8+3=23) en oubliant `Item.gd` (1) et `ItemPopup.gd` (1)).

**Référence PR16** : `Theme` Godot central (`themes/fdcn.tres`, appliqué
via `project.godot`), avec **101 variations nommées** (`theme_type_variation`)
posées scène par scène — leur README chiffre le gain : "570 → 41" surcharges
de style. Palette mesurée directement dans leurs scènes et cataloguée
(13 couleurs avec hex + nombre d'usages). Variation "Voile" confirmée
(fond assombri des popups — le même concept que le fond de nos popups,
qu'on a codé à la main cette session au lieu de le nommer une fois pour
toutes).

**Action** : à reprendre — c'est l'écart le plus net et le plus outillable
du bloc. La PR16 fournit un exemple directement transposable (palette déjà
mesurée, méthode de migration documentée) sans nécessiter de réécriture
Godot 4 complète pour en profiter.

---

# Bloc 5 — Santé générale du code (mémoire, code mort)

Sources lues :
- PR16 : `screens/chapitres_menu.gd`, `ui/virtual_list_pool.gd`,
  `autoload/utils.gd`, commits `6dc1e2f`/`d4c5868`.
- Nous : `utils.gd`, `main.gd`, `player.gd`, `Item.gd`/`Success.gd`.

## 26. Vérifié — pas de fuite de nœuds au changement de livre (le "~600 objets" de la PR n'est pas une fuite chez nous)

**Vérifié** : `Utils.delete_children()` fait un vrai `queue_free()` sur
chaque enfant (pas un simple `remove_child()`) — confirmé en lisant
`utils.gd` directement. Chaque changement de livre libère donc
correctement l'ancien lot avant de recréer le nouveau. **Ce n'est pas une
fuite qui s'accumule.**

**Coût réel mesuré** (pas une fuite, un churn de performance) : environ
**13 680 nœuds détruits + 15 559 recréés** dans le pire cas (livre 1→2) —
606→691 chapitres × 21 nœuds/ligne, + succès/objets/lore. **Chiffres
recalculés indépendamment depuis zéro lors de la contre-expertise et
confirmés exacts au nœud près.** Note méthodologique (n'invalide pas le
résultat, à garder en tête) : le compte d'objets (60/86) est le compte
brut avant filtrage — 4 items de catégorie "BILLY" par livre sont
instanciés puis immédiatement libérés (`Item.gd::is_ok_to_be_shown()` les
exclut), donc le vrai nombre de nœuds *affichés* est légèrement inférieur
au pic d'instanciation compté ici. Le chiffre "~600" de la description
PR16 correspond très probablement à "~600 entités de chapitre recréées",
pas à une fuite au sens strict — leur propre commentaire de code
(`chapitres_menu.gd`) cite littéralement notre fonction
`insert_all_chapters` comme exemple de l'ancien comportement lent, pas
fuyant.

**Référence PR16** : liste virtualisée (`ui/virtual_list_pool.gd`), pool
fixe de lignes recyclées couvrant la zone visible.

**Action** : à noter en todo — pas une fuite à corriger en urgence, mais
un vrai coût de performance mesuré. La virtualisation reste une piste
valable si l'écran Chapitres montre un jour un ralentissement perceptible.

---

## 27. À noter dans la todo — cache de textures jamais vidé (fuite réelle mais bornée)

**Vérifié** : `Utils._texture_cache` (dict statique dans `utils.gd`) n'est
**jamais vidé ni réinitialisé**, y compris au changement de livre — grep
sur tout le dépôt confirme qu'il n'est lu/écrit qu'à 4 endroits, tous dans
`utils.gd` lui-même. Les textures GPU (icônes objets/succès/lore) restent
en cache pour toute la durée de vie du process. Fuite réelle mais bornée
(nombre de chemins distincts fini, pas de croissance illimitée par
changement répété de livre).

**Référence PR16** : leur `Utils.load_external_texture()` ne maintient
aucun cache applicatif — s'appuie sur le cache natif de `ResourceLoader`
de Godot, qui gère lui-même le cycle de vie.

**Action** : todo, pas critique (impact modéré et borné) — soit vider le
cache au changement de livre, soit s'aligner sur l'approche PR16.

---

## 28. À reprendre — code mort trivial + duplication svg/png à factoriser

**Vérifié** : `player.gd` lignes 857-875 contiennent 5 fonctions
entièrement commentées (`#func switch_to_guerrier()`, etc.), remplacées
depuis par `_switch_to_billy(billy_type)` — 19 lignes mortes à supprimer,
récupérables via git si besoin.

**Vérifié** : le motif "fallback svg→png→null" pour charger une icône est
dupliqué à l'identique dans `Item.gd` (lignes 27-35) et `Success.gd`
(lignes 54-60), sans fonction commune.

**Référence PR16** : même genre de nettoyage fait via des commits dédiés
et documentés (`d4c5868` factorise exactement ce même fallback svg/png en
`Utils.load_icon_with_fallback()`).

**Action** : à reprendre — suppression des 5 fonctions mortes (trivial,
zéro risque). À noter en todo — factoriser le fallback svg/png dans un
helper `Utils` commun.

**Note méthode** : les refactors PR16 examinés (`6dc1e2f`, `d4c5868`)
suivent un principe simple à retenir même si l'architecture a trop
divergé pour un cherry-pick direct : un petit refactor documenté par item
de dette, jamais un big-bang, suite de tests inchangée vérifiée à chaque
étape.

---

## 29. Vérifié — pas de fuite via ShaderMaterial/StyleBoxFlat

**Vérifié** : aucune instanciation dynamique de `ShaderMaterial` trouvée
dans nos `.gd` (le grayscale des portraits Billy réutilise le matériau
déjà assigné dans la scène). `StyleBoxFlat.new()` (25 occurrences, cf §25)
ne fuite pas non plus : `StyleBoxFlat`/`ShaderMaterial` étendent
`RefCounted` en Godot 4, libérés automatiquement dès que le nœud
propriétaire est `queue_free()`.

**Action** : aucune.
