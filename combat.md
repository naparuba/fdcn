# Combat — ce qu'il faut changer pour que ça fonctionne

Écrit le 2026-08-10, à partir des règles dictées (7 étapes) + audit du code et des
données des deux livres. À lire avec `review.md` §4.8 (le socle des ressources, sur
lequel le combat s'appuie).

---

## 0. Ce qui existe aujourd'hui

`screens/aventure_menu/combat.gd` (65 lignes) est une **fiche de combat en lecture
seule**, pas un moteur :

| Il fait | Il ne fait pas |
|---|---|
| se montrer si `node.is_combat()` | calculer l'écart d'habileté |
| afficher nom / pv / arm / hab / deg de l'ennemi | consulter une table |
| afficher pv / arm / hab / deg du joueur | appliquer des dégâts (`get_pv()` est lu, jamais écrit) |
| afficher `+N` si l'ennemi a un `pyro` | suivre les PV de l'ennemi |
| lancer un D6 et afficher sa face | l'esquive, les armures, les pouvoirs de CARACTÈRE |
| un bouton « j'ai gagné » → `combat_finished` | la défaite, la limite de tours |

Autrement dit : c'est le joueur qui fait toute l'arithmétique de tête, et le bouton
« j'ai gagné » est la seule sortie. Le socle §4.8 fournit maintenant ce qui manquait
pour écrire dedans : `PlayerStats.del_pv(x)` / `add_pv(x)`, bornés et sauvegardés.

---

## 1. Les trois entrées qui manquent — bloquantes

### 1.1 La table de combat ✅ TRANSCRITE (2026-08-10)

Je ne peux pas lire l'image du marque-page (c'est un PNG). Pierre-Alexandre l'a donc
saisie à la main en bas de ce fichier, section **« Table des situations »**, et elle
est normalisée dans **`data/combat-table.json`** :

```json
"assauts": { "0": {"1": [3,5], "2": [3,4], ... }, ... }   // [infligés, reçus]
```

15 écarts (−7 → +7) × 6 dés = 90 cases, plus les 7 **situations** nommées, qui portent
chacune son coût de fuite (§3.9).

**La transcription est validée mécaniquement** : à écart constant, monter le dé ne
peut jamais faire baisser les dégâts infligés ni monter les dégâts reçus. Les 15
lignes respectent cette monotonie dans les deux sens — une coquille de saisie l'aurait
presque sûrement cassée. Les deux extrêmes correspondent bien aux règles dictées :
écart −7 + dé 1 → `[0, 12]` (12 encaissés, « généralement fatal »), écart +7 + dé 6 →
`[12, 0]`.

Fichier **partagé par les deux livres** (Q4 = oui), d'où `data/` et non
`books/<nom>/`.

### 1.2 Les règles spéciales ne sont **pas** dans les données — ⏸️ REPORTÉ (décidé 2026-08-10)

**Décision : on ne les encode pas.** Le moteur applique les règles générales, et
l'écran expose un champ « modificateur d'habileté » que tu ajustes à la main quand le
texte l'exige (`÷2` pour les Gnolls, etc.) — c'est la v1 ci-dessous. Encoder les 85
combats reste possible plus tard sans rien jeter : le champ manuel devient alors une
valeur par défaut venue des données.

⚠️ Corollaire à assumer : pour les combats à règle spéciale, **le moteur donnera un
résultat faux si le joueur ne saisit pas le modificateur**. C'est la raison pour
laquelle le bouton « j'ai gagné » doit rester (§3.6) : il faut toujours une
échappatoire manuelle.

Le détail du choix, pour mémoire :

Tu dis « presque chaque affrontement a une règle spéciale » (les Gnolls qui divisent
l'habileté par deux, etc.). Or un bloc `combat` compilé contient **exactement six
champs** : `nom`, `hab`, `pv`, `arm`, `deg`, `pyro`. Rien d'autre. Vérifié sur les
85 combats des deux livres.

Ces règles vivent donc dans le **texte du livre**, pas dans le JSON. Conséquence :
elles ne peuvent pas être automatisées sans toucher la source des livres **et** le
compilateur Python (`scripts/node.py`), ce qui est un chantier distinct de celui du
moteur. Deux stratégies possibles, à choisir (Q9) :

- **v1 honnête** : le moteur applique les règles générales, et l'écran affiche un
  champ « modificateur d'habileté » que le joueur ajuste à la main quand le texte
  l'exige (`÷2` pour les Gnolls, etc.). Zéro modification des livres, utilisable tout
  de suite.
- **v2** : ajouter un champ `regle` au bloc `combat` côté source + compilateur, et
  encoder les règles une par une. Gros travail de saisie sur 85 combats.

Je recommande **v1**, quitte à migrer ensuite : sans ça, le combat reste bloqué
derrière une saisie de données de plusieurs heures.

### 1.3 Les limites de tours et le « si vous mourez, allez à X » non plus

Même problème, même conclusion : l'étape 7 parle d'une limite de tours « indiquée par
le texte », et rien dans les données ne dit où va un Billy mort. Le moteur doit donc
**signaler** la défaite (`combat_lost`) et laisser le joueur naviguer, pas décider à
sa place.

---

## 2. Ce que les données contiennent vraiment (et leurs pièges)

Schéma d'un bloc `combat` (dans `computed.combat`) :

```json
{"nom": "ORC ESCLAVAGISTE", "hab": 10, "pv": 10, "arm": 0, "deg": 0, "pyro": 4}
```

| | fdcn (45 combats) | cdsi (40 combats) |
|---|---|---|
| `hab` ennemi | 1 → 30 | 0 → 99 |
| `pv` ennemi | 1 → 40 | 5 → 99 |
| `arm` ennemi | 0, 1, 3 | 0, 1, 3, 4, 99 |
| `deg` ennemi | 0, 1, 2 | **−1**, 0, 1, 2, 4, 99 |
| `pyro` | 0 → 10 | 0 → 30 |

Quatre pièges à traiter explicitement dans le moteur :

1. **L'écart sort très souvent de la table**, et les deux côtés ne se traitent pas
   pareil (Q8 tranché) :
   - **au-delà de +7 → victoire automatique**, sans lancer un seul dé. Ce n'est donc
     pas un plafonnement mais une **sortie anticipée**, à tester *avant* tout assaut :
     ça change l'entrée du moteur, pas seulement sa table.
   - **en-dessous de −7 → on borne à la ligne −7.** Pas de défaite automatique
     symétrique : la ligne −7 existe et laisse une chance (au pire 12 dégâts sur un 1),
     et tu décrivais ce pire cas comme jouable. L'ennemi montant à hab 30 (fdcn) et 99
     (cdsi), le cas sera fréquent — contre l'`ARMEE DE CREUX` (hab 32) l'écart vaut ~−27.
     L'interface doit l'afficher en clair (« −27 → plafonné à −7 »), sinon ça passe pour
     un bug. ⚠️ Asymétrie **déduite**, pas dictée : à confirmer.
2. **Des valeurs sentinelles à 99.** `cdsi` ch256 « Mimine » a `hab/pv/arm/deg` tous
   à 99 : ce n'est pas un ennemi, c'est un marqueur. Le moteur ne doit pas le traiter
   comme un combat normal (probablement : afficher la fiche, refuser d'automatiser).
3. **`deg: -1`** existe (ch293 « Gnoll surpris », ch43 « SERGENT », ch584). À
   confirmer : dégâts réduits, ou autre sentinelle ? → Q10.
4. **Les combats à plusieurs ennemis sont silencieusement tronqués.**
   `entities/chapter_data.gd:_get_combat()` fait `return combat[0]` quand le champ est
   un tableau : dans fdcn ch276, la `TROLESSE` (hab 13, pv 16) qui suit les
   `GUARDES CORROMPUS` **n'est jamais affichée**. Un seul cas dans les deux livres,
   mais il faut soit le gérer (combat en deux manches), soit l'assumer par écrit.

---

## 3. Les changements, par étage

### 3.0 Prérequis — `randomize()` (review #14) ✅ FAIT (2026-08-10)

`Utils.roll_a_dice()` utilisait `randi()` sans jamais avoir semé le générateur : **les
dés étaient identiques à chaque lancement de l'app.** Défaut cosmétique jusqu'ici,
rédhibitoire pour un combat automatisé — le même affrontement se serait déroulé
exactement pareil à chaque partie.

→ Fait : `randomize()` dans `Utils._ready()`.

⚠️ Conséquence pour la suite : le moteur ne doit **pas** appeler `Utils.roll_a_dice()`
directement, sinon ses tests deviennent non déterministes. Le lancer doit être
injectable (§3.8).

### 3.1 Nouveau : `autoload/combat_engine.gd` — les règles, sans interface

Le calcul ne doit pas vivre dans `combat.gd` (une scène qui se détruit), pour trois
raisons : il doit être testable sans interface, l'état doit survivre à un changement
d'écran, et le combat doit pouvoir se poursuivre après fermeture de l'app.

Surface publique visée :

```gdscript
signal assault_resolved(rapport)   # ce qui s'est passé, pour l'affichage
signal combat_won()
signal combat_lost()

func start(chapter_id) -> void      # lit le bloc combat, initialise l'état
func is_running() -> bool
func get_ecart() -> int             # habileté joueur (+bonus) − habileté ennemi
func set_hab_modifier(v) -> void    # la règle spéciale saisie à la main (§1.2)
func set_pyro_active(b) -> void     # le Pyro-Barbare assiste ou non (Q5)
func resolve_assault(dodge: bool) -> Dictionary
func flee() -> void
```

`resolve_assault()` renvoie un rapport plutôt que de peindre : `{de, ecart_utilise,
esquive_tentee, esquive_reussie, critique, degats_infliges, degats_recus,
pv_ennemi_restant, pouvoirs_appliques: [...]}`. C'est ce rapport qui permet un
affichage lisible (« tu as fait 4 : 2 dégâts infligés, 1 reçu, armure −1 ») **et**
des tests sur chaque règle isolément.

### 3.2 La table, en données et non en code ✅ FAIT (2026-08-10)

**`data/combat-table.json`**, chargé par le moteur — pas un dictionnaire GDScript :
c'est de la donnée de jeu, elle doit rester relisible et corrigeable sans toucher au
code. Un seul fichier pour les deux livres (Q4 = oui).

Trois entrées : `situations` (nom + écarts couverts + coût de fuite), `assauts`
(`[ecart][de] = [infligés, reçus]`) et les bornes `ecart_min` / `ecart_max`.

Si tu corriges une case de la table dans ce fichier-ci, le JSON se régénère
mécaniquement à partir du markdown — ne le réécris pas à la main, dis-le moi.

### 3.3 Les PV de l'ennemi sont une ressource, donc à sauvegarder

Un combat dure plusieurs assauts, donc plusieurs interactions. Si l'app se ferme au
milieu (ou si on change d'écran), les PV de l'ennemi doivent être retrouvés. Même
raisonnement qu'en §4.8 pour les pv du joueur : ce n'est **pas** redérivable.

→ nouvelle clé `SaveManager.KEY_COMBAT` contenant l'état du combat en cours :
`{chapitre, pv_ennemi, tour, modificateur_hab, pyro_actif}`, ou `null` hors combat.
Pas de migration nécessaire (clé absente = pas de combat en cours), comme pour
`KEY_PV` / `KEY_CHANCE`.

Q7 tranché : quitter un combat **ne force rien**. Le joueur peut naviguer ailleurs, ou
passer le combat s'il le veut. L'état reste donc en sauvegarde plutôt que d'être
effacé — c'est une *suspension*, et revenir au chapitre reprend là où on en était.

### 3.4 `PlayerStats` — presque tout est déjà là

Bonne nouvelle, les quatre stats dont le combat a besoin existent déjà en couches
avec leur ventilation : `hab`, `adr`, `arm`, `deg`, plus `crit` pour les dégâts
critiques de l'étape 5. Rien à ajouter côté stats.

La chance se consomme pour **passer** le combat (Q3, §3.9) : le moteur appelle
`PlayerStats.del_chance(cout)` — déjà disponible, borné et sauvegardé.

### 3.5 Les quatre pouvoirs de CARACTÈRE

Ils vivent dans le moteur, dans **une seule** table lisible à côté de
`PlayerStats.BILLY_MODIFIERS` (qui, lui, ne gère que les bonus de stats) :

| type | effet en combat | où ça s'applique |
|---|---|---|
| GUERRIER | +1 dégât infligé | ⚠️ **NE PAS CODER** — voir ci-dessous |
| PAYSAN | plafonne les dégâts reçus à 3 | tout à la fin du calcul des dégâts reçus |
| DÉBROUILLARD | relance le dé une fois par assaut | **au choix du joueur** (Q6) : il voit le dé, puis décide |
| PRUDENT | survit à un coup mortel via un test de Chance | quand les dégâts reçus feraient tomber à 0 |
| PÉGU | aucun | — |

🔴 **Le +1 dégât du GUERRIER est déjà implémenté.** `PlayerStats.BILLY_MODIFIERS` vaut
`"guerrier": {"hab": 2, "chamax": -1, "deg": 1}` : ce `+1` est déjà dans la couche
`items` de la stat `deg`, donc dans `get_stat('deg')` — et il est même déjà affiché sur
la fiche de combat. Le recoder dans le moteur **le compterait deux fois**. C'est le
piège le plus facile de tout ce chantier : la règle est écrite dans le livre comme un
pouvoir de combat, mais le code la traite (correctement) comme un modificateur de stat.

Même vigilance pour les trois autres : leurs modificateurs de stats sont déjà là
(`prudent` hab −1 / chamax +2, `paysan` adr −1 / end +2, `debrouillard` adr +2 / end −1).
Le moteur n'implémente donc **que** ce que la table de stats ne peut pas exprimer : le
plafond à 3 du PAYSAN, la relance du DÉBROUILLARD, la survie du PRUDENT.

**La séquence d'un assaut**, une fois Q2 et Q6 tranchés :

```gdscript
func roll() -> int                     # 1. dé d'assaut, mémorisé, rien résolu
func can_reroll() -> bool              # 2. vrai pour un DÉBROUILLARD qui n'a pas relancé
func roll_dodge() -> int               # 3. SECOND dé, indépendant (Q2), si adresse >= 2
func resolve() -> Dictionary           # 4. résout avec les dés mémorisés
```

Un assaut n'est donc pas une fonction atomique : il y a jusqu'à deux décisions du
joueur au milieu (relancer ? esquiver ?). L'ordre retenu — dé d'assaut, puis relance
éventuelle, puis esquive éventuelle — vient du fait qu'un **échec d'esquive ne coûte
rien** : décider d'esquiver *après* avoir vu le résultat de l'assaut est toujours au
moins aussi bon pour le joueur, et ne casse aucune règle. Bénéfice collatéral : les dés
étant injectables, les tests sont déterministes par construction.

### 3.10 L'algorithme complet d'un assaut ✅ SPÉCIFIÉ (2026-08-10)

C'est la spec que le moteur implémente, dans cet ordre. Tout est tranché sauf les
points marqués ⚠️.

```
0. VICTOIRE AUTOMATIQUE
   écart > +7  ->  gagné, aucun dé lancé. (§2 piège 1)

1. ÉCART
   écart = hab_joueur + modificateur_manuel + pyro_ennemi − hab_ennemi
   puis plancher à −7 (le plafond +7 est déjà sorti à l'étape 0)

2. DÉ D'ASSAUT (1..6)
   base_infligés, base_reçus = table.assauts[écart][dé]

3. RELANCE — DÉBROUILLARD seulement, une fois par assaut, au choix du joueur
   -> retour à l'étape 2 avec le nouveau dé

4. ESQUIVE — au choix, si adresse > 2. SECOND dé, indépendant.
   dé_esquive == 1        -> CONTRE-ATTAQUE CRITIQUE
                             infligés = max_écart + crit_joueur   (IGNORE arm_ennemi)
                             reçus    = 0
   dé_esquive <= adresse  -> esquive réussie : reçus = 0
                             (les dégâts infligés restent ceux de l'étape 5)
   sinon                  -> échec, ne coûte rien, on continue en 5

5. DÉGÂTS — les chiffres de la frise sont une BASE, pas un total
   infligés = base_infligés + deg_joueur  − arm_ennemi   (plancher 0)
   reçus    = base_reçus    + deg_ennemi  − arm_joueur   (plancher 0)

6. PAYSAN
   reçus = min(reçus, 3)

7. APPLICATION
   pv_ennemi −= infligés
   PlayerStats.del_pv(reçus)

7bis. COUPS SIMULTANÉS
   si l'ennemi tombe sur cet assaut -> reçus = 0
   (on l'a tué avant que son coup ne porte ; testé AVANT le PRUDENT, pour ne pas
    dépenser un jet de survie sur un coup qui n'arrivera jamais)

8. PRUDENT — si les reçus feraient tomber à 0
   lancer un dé « après la mort » ; <= chance courante -> on survit à 1 pv
   (le jet ne consomme pas de chance — voir la note de `_test_survie_prudent`)

9. ISSUES
   pv_ennemi <= 0  -> victoire
   pv_joueur == 0  -> défaite (état affiché, rien de forcé, §3.7)
```

**Où atterrit chaque stat de l'ennemi** — les six champs du livre servent, aucun n'est
oublié :

| champ | où il agit | ligne |
|---|---|---|
| `hab` | dans l'écart, soustrait | étape 1 |
| `pyro` | dans l'écart, ajouté (automatique, Q5) | étape 1 |
| `pv` | la barre à faire descendre | étapes 7 et 9 |
| `deg` | s'ajoute aux dégâts qu'on **encaisse** | étape 5 |
| `arm` | se retire des dégâts qu'on **inflige** (sauf critique) | étapes 4-5 |
| `nom` | affichage | — |

Trois remarques qui ne sautent pas aux yeux :

- **`max_écart` = la valeur du dé 6 de la ligne** (Q11) : écart 0 → 5, +7 → 12, −7 → 3.
  La table étant croissante en dé, c'est bien le maximum réel de la ligne.
- une esquive réussie n'annule **que** les dégâts reçus : le joueur inflige quand même
  les siens.
- le critique est **doublement** avantageux — dégâts maximaux *et* armure ignorée *et*
  aucun dégât reçu (un 1 est forcément ≤ adresse). C'est cohérent avec « beaucoup de
  joueurs sous-estiment cette étape ».

### 3.11 Combat non automatisable : mode manuel, **jamais** une défaite

Question posée : « si le combat n'est pas automatisable, on marque comme perdu ? »
**Non.** Trois raisons, dans l'ordre d'importance :

1. **Ce serait affirmer quelque chose de faux.** Le combat n'est pas perdu : l'app ne
   sait simplement pas le mener. Marquer une défaite, c'est mentir au joueur sur l'état
   de sa partie.
2. **Ça contredit Q7.** On vient de décider qu'une *vraie* défaite n'est qu'un état
   affiché, sans conséquence forcée. Déclarer d'office une défaite là où on ne sait pas
   calculer serait plus brutal que le cas réel.
3. **Ça enverrait le joueur dans la mauvaise branche.** « Mimine » (cdsi ch256) est très
   probablement une rencontre scriptée, gagnable en lisant le texte. Une défaite
   automatique pousserait vers le mauvais chapitre.

Comportement retenu : **mode manuel**, exactement ce qui existe aujourd'hui et qu'on a
décidé de garder de toute façon (§1.2, §3.6) — la fiche de l'ennemi s'affiche, les
boutons ± pv/chance et « j'ai gagné » restent là, et un message dit pourquoi (« ce
combat n'est pas automatisé »). Le moteur, lui, **n'émet aucune issue**.

Côté API : `is_automatable(chapter_id)` distingue les deux cas que l'interface doit
traiter différemment — *pas de combat ici* (ne rien afficher) et *combat non
automatisable* (afficher la fiche, mode manuel). `start()` renvoyant simplement `false`
dans les deux cas ne suffisait pas.

⚠️ À garder en tête : le mode manuel n'est pas un cas marginal réservé aux marqueurs à
99. Les règles spéciales n'étant pas encodées (§1.2), **beaucoup** de combats seront
calculés de travers par le moteur, et le joueur doit toujours pouvoir reprendre la main.

### 3.6 L'interface — `combat.gd` + `Combat.tscn`

La scène a déjà la grille joueur/ennemi, le dé, le pyro et un bouton de victoire. À
ajouter :

- **l'écart affiché en grand** avec son origine (« hab 6 − 4 = +2 »), parce que c'est
  le nombre que le joueur veut vérifier contre son marque-page ;
- **la situation en clair** à côté (« Désavantage léger »), puisque c'est le vocabulaire
  du marque-page et que c'est elle qui fixe le prix de la fuite ;
- un **champ de modificateur d'habileté** (la règle spéciale saisie à la main, §1.2) ;
- **pas de bascule Pyro-Barbare** : Q5 → le bonus s'applique **automatiquement** dès
  que `pyro != 0`. Il reste affiché (`+N`) pour que le joueur voie d'où vient son
  écart ;
- un **bouton « passer le combat »** avec son prix en chance et grisé si insuffisant
  (§3.9) ;
- un **bouton « esquiver »** distinct du bouton « assaut » — tant que l'adresse ≥ 2 — et
  grisé sinon, avec l'adresse affichée à côté (le joueur doit voir *pourquoi*). Il
  déclenche un **second dé** (Q2), donc l'écran doit montrer **deux dés** : celui de
  l'assaut et celui de l'esquive, sinon le joueur ne peut plus recouper avec son
  marque-page ;
- un **bouton « relancer »** pour le DÉBROUILLARD, visible seulement après un lancer et
  une fois par assaut (Q6) ;
- **les PV de l'ennemi qui descendent**, idéalement avec le widget existant
  `ui/ResourceGauge.tscn`. ⚠️ il est aujourd'hui câblé sur `PlayerStats` via son
  `kind` : pour l'ennemi il faudra le rendre alimentable de l'extérieur (une source
  injectée plutôt qu'un `kind` en dur). C'est le moment prévu en §4.8 où la jauge
  sort de la popup ;
- **le journal du dernier assaut** en une ligne, depuis le rapport ;
- **la fin de combat** : victoire (pv ennemi ≤ 0) et défaite (pv joueur = 0) comme
  états explicites, plus « fuir ». Le bouton « j'ai gagné » actuel doit rester
  disponible comme **échappatoire manuelle** — les règles spéciales non encodées
  garantissent des combats que le moteur calculera mal.

Et **poser les deux jauges pv/chance du joueur ici**, comme prévu en §4.8 : c'est
pendant un combat qu'on en a besoin, pas dans une popup à deux taps.

#### Maquette retenue (2026-08-11)

Demandé : animation de lancer de dé, barre de vie ennemie + la nôtre, bouton de fuite
grisable, stats ennemies et nos totaux, bouton « gagner », bouton pour lancer le dé,
affichage de défaite qui n'empêche pas de déclarer la victoire.

```
┌──────────────────────────────────────────┐
│ ORC ESCLAVAGISTE            tour 3       │
│ ██████████░░░░  6 / 10                   │  jauge ennemie (rouge)
├──────────────────────────────────────────┤
│         hab   pv   arm  deg              │
│ moi      6     4    1    2               │  totaux joueur (déjà là)
│ lui     10    --    0    0   pyro +4     │
├──────────────────────────────────────────┤
│  ÉCART  −4   « Désavantage »             │  gros, avec son calcul
│  6 +4 pyro −10   [ mod. règle : ␣ ]      │
├──────────────────────────────────────────┤
│    ⚁ assaut        ⚄ esquive             │  deux dés, deux couleurs
│  [ Lancer ]  [ Relancer ]  [ Esquiver ]  │
├──────────────────────────────────────────┤
│ dé 4 → 3 infligés (2 frise +1 deg),      │  journal du dernier assaut
│        1 reçu (3 −2 armure)              │
├──────────────────────────────────────────┤
│ ██████░░░░ PV 4/9   ███░ CHANCE 3/3      │  jauges joueur (§4.8)
│ [ Fuir — 3 chance ]        [ Gagner ]    │
│ [ Annuler le combat ]                    │  retour au chapitre d'avant
└──────────────────────────────────────────┘
```

**Les deux dés en deux couleurs** : `images/dice/N-b.svg` (bleu) et `N-r.svg` (rouge)
existent déjà pour 1 à 6 — bleu pour l'assaut, rouge pour l'esquive. Aucun asset à
produire. L'animation la moins coûteuse et la plus lisible : faire défiler des faces
aléatoires ~0,4 s puis s'arrêter sur le résultat. ⚠️ Le tirage doit venir du **moteur**
(`roll()`), pas de l'animation : celle-ci n'illustre qu'un résultat déjà décidé, sinon
la valeur affichée et la valeur appliquée peuvent divergerence.

**Ce que j'ajoute à ta liste, et pourquoi :**

1. **L'esquive et la relance.** Tu ne les as pas citées, mais ce sont deux mécaniques
   entières (étape 5, et le pouvoir du DÉBROUILLARD) avec chacune sa décision de joueur.
   Sans ces boutons, la moitié des règles est inaccessible.
2. **L'écart en grand avec son calcul détaillé** (`6 +4 pyro −10`). C'est *le* nombre que
   le joueur recoupe avec son marque-page. Sans le détail, un écart faux est
   indiagnosticable.
3. **Le journal du dernier assaut**, avec la décomposition. Le moteur se trompera sur les
   combats à règle spéciale (§1.2) : montrer son arithmétique est ce qui permet de s'en
   apercevoir au lieu de le subir.
4. **Le champ de modificateur de règle**, sans lequel les combats à règle spéciale sont
   calculés faux en silence.
5. **Le compteur de tours**, parce que le livre impose parfois une limite de tours que les
   données ne contiennent pas (§1.3) : c'est au joueur de la surveiller.
6. **Le bandeau « écart plafonné »** quand l'écart brut passe sous −7, et l'état **victoire
   automatique** au-delà de +7 (dans ce cas : pas de dé du tout, juste le bouton
   « Gagner »).
7. **Le bandeau « combat non automatisé »** en mode manuel (§3.11), qui masque dés,
   esquive et journal mais garde tout le reste.
8. **Le prix de la fuite écrit sur le bouton** (« Fuir — 3 chance »), et grisé avec la
   raison visible : sinon un bouton inerte passe pour cassé.

#### Les trois états de l'écran (2026-08-11)

L'écran de combat a **trois** états, et le style des boutons en découle. Ce ne sont pas
trois écrans séparés : c'est le même panneau, dont la moitié basse change.

| état | déclencheur | ce que ça montre | bouton « Gagner » |
|---|---|---|---|
| **en cours** | `is_running()` | dés, esquive, journal, jauges | style neutre |
| **victoire** | `combat_won` ou écart > +7 | bandeau vert « X vaincu », dés masqués | style **valider** (mis en avant) |
| **défaite** | `combat_lost` | bandeau rouge « tu es tombé », dés masqués | style **danger**, mais **toujours cliquable** |

Le point important, c'est le dernier : en défaite le bouton « Gagner » **reste actif**.
C'est la conséquence directe de Q7 (l'app ne force jamais rien) et de §1.2 (le moteur se
trompera sur les combats à règle spéciale). Un joueur qui sait avoir gagné doit pouvoir
le dire même si le moteur le déclare mort. Le changement de style dit « d'après mes
calculs tu as perdu » sans jamais dire « tu n'as pas le droit ».

Implémentation : une seule fonction `_apply_state(etat)` qui pose les `visible` et les
`theme_type_variation` des boutons, appelée depuis les signaux du moteur. Pas d'états
dupliqués entre la scène et le script — c'est ce qui produit les incohérences d'affichage.

#### Le bouton « annuler le combat » ✅ FAIT côté moteur

Demandé : revenir au chapitre d'avant, avec les pv et le reste d'avant. C'est plus
qu'annuler un assaut : c'est annuler **l'arrivée dans le chapitre**. `CombatEngine`
photographie donc l'état au `start()` — pv, chance, objets portés, chapitre de retour —
et `cancel()` le repose.

**L'ordre des opérations n'est pas négociable** : on navigue *d'abord*, on restaure
*ensuite*. `jump_back()` dépile le chapitre de retour du fil d'Ariane, si bien que le
`go_to_node()` suivant le considère comme neuf et **réapplique ses stats** — dont un
éventuel `max_pv` qui remettrait les pv au plein. La restauration doit avoir le dernier
mot, sinon le retour soigne le joueur.

Ce que `cancel()` remet : pv, chance, objets portés, et la couche de stats « chapitres »
recalculée depuis le fil d'Ariane dépilé (`Player.rebuild_chapter_stats()`).
Ce qu'il ne remet **pas**, volontairement : `visited_nodes_all_times` — le chapitre a bien
été vu une fois, et c'est ce que suivent les succès et les marqueurs « déjà lu ».

🔴 **Bug corrigé au passage, indépendant du combat.** `PlayerStats.reset_chapter_layer()`
ne remettait à zéro que la couche `chapters`, en laissant `gloire`, `richesse`,
`nb_infos` et `pv_max_bonus` — qui viennent pourtant *exclusivement* des chapitres. Le
rejeu d'historique n'était donc **pas idempotent** : chaque `do_load()` supplémentaire
doublait ces quatre valeurs, ce qui arrive déjà à chaque **changement de livre**
(`Player._on_book_changed` → `do_load()`). Corrigé, sans quoi l'annulation de combat
aurait hérité du même défaut.

**Suggestion restante, à toi de dire :** en plus d'annuler tout le combat, un
**« annuler le dernier assaut »** (rendre les pv, remonter ceux de l'ennemi, décrémenter
le tour) serait moins violent quand le moteur se trompe d'un seul coup — garder le
rapport précédent suffit à le défaire.

### 3.7 Fin de combat — Q7 tranché : on ne force jamais rien

`combat_finished` existe et `screens/aventure_menu.gd:_on_combat_finished()` remet les
choix de chapitre visibles. À étendre en trois issues distinctes (gagné / perdu / fui),
parce que le livre n'envoie pas au même endroit.

**La défaite est un simple état affiché.** Le moteur ne doit rien décider : pas de
`Player.launch_new_billy()`, pas de navigation forcée, pas de blocage. Rien dans les
données ne dit ce qui arrive à un Billy mort (§1.3), et une remise à zéro automatique
détruirait une partie sur une simple erreur de calcul du moteur — dont on sait déjà
qu'il en fera sur les combats à règle spéciale (§1.2).

Dans le même esprit, le joueur garde à tout moment le droit de **passer le combat**
(avec son coût en chance, §3.9), de **naviguer ailleurs** (le combat est suspendu, pas
abandonné, §3.3) et de cliquer **« j'ai gagné »** sans que le moteur soit d'accord.

### 3.8 Tests

Le moteur étant des données pures, il est entièrement testable — et il **doit** l'être,
parce qu'une erreur d'arithmétique de combat est invisible à l'œil :

- `test/unit/test_combat_table.gd` : la table se charge, toutes les lignes attendues
  existent, l'écart hors bornes est bien ramené à la ligne extrême ;
- `test/unit/test_combat_engine.gd` : un cas par règle — armure du joueur, armure de
  l'ennemi, critique qui perce l'armure, esquive réussie/ratée, contre-attaque sur un
  1, et **un test par pouvoir de CARACTÈRE** ;
- l'aléatoire doit être injectable (un `dice_roller` remplaçable, ou un paramètre
  `forced_roll`) : sans ça les tests sont non déterministes. Le découpage
  `roll()` / `resolve()` de §3.5 le donne presque gratuitement ;
- `test/unit/test_combat_fuite.gd` : le coût en chance par situation, et le refus quand
  la chance est insuffisante (§3.9).

### 3.9 Passer le combat : le coût en chance ✅ SPÉCIFIÉ (2026-08-10)

Mécanique **découverte dans la table** que tu as transcrite, absente de ma première
version du plan : la ligne « Coup de fuite en chance ». Le joueur qui préfère ne pas se
battre dépense de la chance, et le coût dépend de la situation — plus le rapport de
force est mauvais, plus fuir coûte cher :

| situation | écarts | coût en chance |
|---|---|---|
| Désavantage lourd | −7 → −5 | **5** |
| Désavantage | −4, −3 | **3** |
| Désavantage léger | −2, −1 | 1 |
| Égalité | 0 | 1 |
| Avantage léger | +1, +2 | 1 |
| Avantage | +3, +4 | 1 |
| Avantage lourd | +5 → +7 | **0** (gratuit) |

Conséquences pour le moteur :

- il lui faut **deux lectures** de la table : écart → ligne d'assaut, et écart →
  situation (pour le coût *et* pour le libellé affiché) ;
- le bouton « passer le combat » doit afficher son prix (« Fuir — 3 chance ») et être
  **grisé si la chance est insuffisante**, avec la raison visible. C'est le seul endroit
  où le joueur peut se retrouver coincé : en désavantage lourd il faut 5 points de
  chance, or `chamax` démarre à 3 — donc un Billy de départ **ne peut pas** fuir un
  combat très défavorable. À confirmer que c'est voulu (ça a l'air d'être exactement le
  propos de la règle) ;
- un coût de 0 en avantage lourd n'est pas un cas particulier : juste un
  `del_chance(0)` qui ne fait rien.

⚠️ À ne pas confondre avec l'**esquive par assaut** de l'étape 5 (basée sur l'Adresse, à
chaque tour, gratuite) : deux mécaniques différentes. Voir Q2.

---

## 4. Ordre de chantier

| # | quoi | dépend de |
|---|---|---|
| ~~1~~ | ~~`randomize()` dans `Utils` (review #14)~~ ✅ **FAIT** (2026-08-10) | — |
| ~~2~~ | ~~Transcrire la table en JSON~~ ✅ **FAIT** : `data/combat-table.json`, validée | — |
| ~~3~~ | ~~`combat_engine.gd` : état, écart borné, situation, `roll()` / `resolve()`~~ ✅ **FAIT** | — |
| ~~4~~ | ~~Passer le combat (coût en chance selon la situation, §3.9)~~ ✅ **FAIT** | — |
| ~~5~~ | ~~Armures + critiques + esquive par assaut (second dé)~~ ✅ **FAIT** | — |
| ~~6~~ | ~~Les pouvoirs de CARACTÈRE~~ ✅ **FAIT** : PAYSAN, DÉBROUILLARD, PRUDENT (Q14 tranchée) | — |
| 7 | Persistance de l'état de combat (`KEY_COMBAT`) | 3 |
| ~~8~~ | ~~Tests unitaires du moteur~~ ✅ **FAIT** : `test/unit/test_combat.gd`, 33 tests | — |
| ~~8bis~~ | ~~Annuler le combat (photo + retour au chapitre d'avant)~~ ✅ **FAIT** côté moteur | — |
| 9 | `Combat.tscn` / `combat.gd` : écart, situation, boutons, 3 états, jauges, journal | 3 → 7 |
| 10 | Jauge d'ennemi (source injectable dans `ResourceGauge`) | 9 |
| 11 | Multi-ennemis (fdcn ch276) et sentinelles à 99 | 3 |

**Plus aucune étape n'est bloquée** : les 13 questions sont tranchées, et les 4
dernières ont un défaut proposé qu'un simple « ok » valide (§5).

Les étapes 3 à 7 sont du calcul pur, sans interface : elles peuvent être écrites et
validées par les tests avant qu'un seul pixel ne bouge. C'est là que doit aller
l'effort de rigueur.

---

## 5. Questions à trancher

### Tranchées

- ~~**Q1**~~ ✅ Table transcrite et validée → `data/combat-table.json` (§1.1).
- ~~**Q3**~~ ✅ La chance se consomme pour **passer** le combat, avec un coût qui dépend
  de la situation (§3.9). Ce n'est pas lié à l'esquive par assaut.
- ~~**Q4**~~ ✅ Même marque-page pour les deux livres → un seul fichier partagé.
- ~~**Q5**~~ ✅ Bonus du Pyro-Barbare **automatique** dès que `pyro != 0`, pas de bascule.
- ~~**Q6**~~ ✅ Relance du DÉBROUILLARD **au choix du joueur** → l'assaut se découpe en
  `roll()` puis `resolve()` (§3.5).
- ~~**Q7**~~ ✅ Défaite = un état affiché, on ne force jamais rien ; le joueur peut passer
  le combat, naviguer ailleurs, ou déclarer la victoire lui-même (§3.7).
- ~~**Q2**~~ ✅ L'esquive par assaut se joue sur un **second lancer**, indépendant du dé
  d'assaut. ⚠️ Marqué comme **interprétation** et non comme règle vérifiée (« je dirais,
  cela a plus de logique ») : le moteur doit garder ce choix isolé en un seul endroit,
  pour pouvoir le basculer sans réécriture si un combat sonne faux à l'usage.
- ~~**Q9**~~ ✅ v1, modificateur d'habileté saisi à la main, encodage des 85 combats
  reporté (§1.2).
- ~~**Q12**~~ ✅ DOMINATION = « avantage lourd », deux mots pour la même chose. Le moteur
  n'aura donc **qu'un** vocabulaire : les 7 noms de situation de la table.

- ~~**Q8**~~ ✅ Écart > +7 → **victoire automatique** ; sous −7 → on borne à la ligne −7
  (asymétrie déduite, §2 piège 1).
- ~~**Q11**~~ ✅ « Dégâts maximaux de l'écart » = la valeur du **dé 6** de la ligne, utilisée
  par la contre-attaque critique.
- ~~**Q13**~~ ✅ Les chiffres de la frise sont une **base** : on ajoute les dégâts
  supplémentaires (`deg`) par-dessus, et on retire l'armure des dégâts subis. Le critique
  ignore l'armure (§3.10 étapes 4-5).

### Encore ouvertes — défauts retenus, corrige seulement si c'est faux

Rien de bloquant. Ces cinq points sont isolés derrière une constante ou une seule
fonction dans le moteur : les changer coûtera une ligne, pas une réécriture.

- ~~**Q14**~~ ✅ Le PRUDENT lance un dé « après la mort » : réussi si ≤ chance courante, il
  survit à 1 pv. ⚠️ Le jet **ne consomme pas** de chance — tu l'as décrit comme un simple
  lancer. Si c'est en réalité un « tentez votre chance » classique qui décrémente, une
  ligne à ajouter dans `_test_survie_prudent()`.
- ~~**Adresse**~~ ✅ **≥ 2** : 2 pile suffit pour esquiver (`ADRESSE_MIN_ESQUIVE = 2`),
  verrouillé par un test dédié puisque c'était le point litigieux.
- ~~**Armure ennemie**~~ ✅ oui, elle réduit les dégâts qu'on inflige (sauf critique).
- ~~**Q10**~~ ✅ classé sous les règles spéciales, ignoré pour le moment. `deg: -1` reste
  donc pris **au pied de la lettre** (l'ennemi fait 1 dégât de moins, plancher 0) : c'est
  de l'arithmétique de données, pas une règle à interpréter. 3 combats cdsi concernés.
- ~~**Sentinelles à 99 / non automatisable**~~ ✅ → **mode manuel, jamais une défaite**
  (§3.11).


## Table des situations


|                         |  Désaventage lours       | désaventage      | desaventage leger| egalité  | avantage léger | avantage      | avantage lours            |
| Coup de fuite en chance |  5                       | 3                | 1                | 1     | 1               | 1               | 0                         |
| différence d'habiliter  | -7      / -6     / -5     | -4     / -3     | -2     / -1     | 0      | 1      / 2      | 3      / 4      |  5     / 6      / 7       |
| Dice 1                  | 0 -- 12 / 1 -- 8 / 1 -- 7 | 1 -- 6 / 2 -- 6 | 2 -- 6 / 3 -- 6 | 3 -- 5 | 3 -- 5 / 3 -- 5 | 3 -- 4 / 3 -- 4 | 4 -- 4 / 4 -- 3 / 4 -- 3  |
| Dice 2                  | 0 -- 9 / 1 -- 7 / 1 -- 6  | 2 -- 6 / 2 -- 5 | 2 -- 5 / 3 -- 5 | 3 -- 4 | 3 -- 4 / 3 -- 4 | 3 -- 3 / 3 -- 3 | 4 -- 3 / 5 -- 2 / 5 -- 2  |
| Dice 3                  | 1 -- 8 / 1 -- 6 / 1 -- 5  | 2 -- 5 / 2 -- 4 | 2 -- 4 / 3 -- 4 | 3 -- 3 | 3 -- 3 / 3 -- 3 | 4 -- 3 / 4 -- 2 | 5 -- 2 / 5 -- 2 / 6 -- 2  |
| Dice 4                  | 2 -- 6 / 2 -- 5 / 2 -- 5  | 2 -- 4 / 3 -- 3 | 3 -- 3 / 3 -- 3 | 3 -- 3 | 4 -- 3 / 4 -- 2 | 4 -- 2 / 5 -- 2 | 5 -- 1 / 6 -- 1 / 8 -- 1  |
| Dice 5                  | 2 -- 5 / 2 -- 5 / 3 -- 4  | 3 -- 3 / 3 -- 3 | 4 -- 3 / 4 -- 3 | 4 -- 3 | 5 -- 3 / 5 -- 2 | 5 -- 2 / 6 -- 2 | 6 -- 1 / 7 -- 1 / 9 -- 0  |
| Dice 6                  | 3 -- 4 / 3 -- 4 / 4 -- 4  | 4 -- 3 / 4 -- 3 | 5 -- 3 / 5 -- 3 | 5 -- 3 | 6 -- 3 / 6 -- 2 | 6 -- 2 / 6 -- 1 | 7 -- 1 / 8 -- 1 / 12 -- 0 |
