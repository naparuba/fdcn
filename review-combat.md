# Review — Combat

Plan de chantier écrit le 2026-08-10, combat aujourd'hui implémenté
(`autoload/combat_engine.gd`, `screens/aventure_menu/Combat.tscn`, 33 tests) et purgé de
son contenu réglé le 2026-08-23 — les endroits où le plan et le code avaient divergé sont
restés signalés en 🔴. À lire avec `review.md` (le socle des ressources, sur lequel le
combat s'appuie).

**Une seule étape reste ouverte : §3.3 / §4 item 7, la persistance de l'état de combat.**

---

## 1. Décisions de conception encore actives

### 1.2 Les règles spéciales de combat ne sont pas automatisées — décision active

**Le moteur applique les règles générales, et ne sait pas lire le texte du livre.** Un
bloc `combat` compilé ne contient que 6 champs (`nom`, `hab`, `pv`, `arm`, `deg`, `pyro`)
— les règles spéciales (« les Gnolls divisent l'habileté par deux », etc.) vivent dans le
texte, pas dans les données. Les encoder demanderait de toucher la source des 85 combats
**et** le compilateur (`scripts/node.py`) : un chantier distinct, écarté pour l'instant.

🔴 **Aucun moyen de correction fine côté joueur.** Un champ « modificateur d'habileté »
était prévu dans l'interface, mais a été retiré à la compaction du 2026-08-11
(`CombatEngine.set_hab_modifier()` existe toujours côté moteur, rien ne l'appelle). Pour
un combat à règle spéciale, le moteur donnera donc **un résultat faux**, sans que le
joueur puisse le corriger autrement qu'en déclarant lui-même la victoire — c'est pourquoi
le bouton « Gagner » doit rester disponible en toutes circonstances (§3.6).

Rien dans les données ne dit non plus ce qui arrive à un Billy mort, ni où s'arrête une
limite de tours parfois imposée par le texte : le moteur **signale** la défaite
(`combat_lost`) et laisse le joueur naviguer, il ne décide jamais à sa place.

## 2. Ce que les données contiennent (et leurs pièges) — repère pour un nouveau livre

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

Pièges gérés par le moteur, à garder en tête pour un troisième livre :

1. **L'écart sort souvent de la table**, et les deux côtés sont asymétriques (§3.10 étape
   0) : au-delà de +7 → victoire automatique sans lancer de dé ; en-dessous de −7 → borné
   à la ligne −7 (une chance reste, au pire 12 dégâts sur un 1).
2. **Valeurs sentinelles à 99** (`cdsi` ch256 « Mimine ») : pas un ennemi, un marqueur —
   `is_sentinelle()` fait tomber le combat en mode manuel (§3.11).
3. **`deg: -1` existe** (3 combats cdsi) : pris au pied de la lettre, l'ennemi fait 1
   dégât de moins (plancher 0).
4. **Les combats à plusieurs ennemis sont gérés** (`_enemies`/`_enemy_index`) — seul cas
   du dépôt : **fdcn ch274**, `GUARDES CORROMPUS` puis `TROLESSE`. L'ordre du tableau est
   l'ordre du combat, le suivant arrive à pv pleins et tour remis à zéro.

---

## 3. Le moteur

### 3.1 Pourquoi un autoload et pas la scène

Le calcul ne vit pas dans `combat.gd` (une scène qui se détruit), pour trois raisons : il
doit être testable sans interface, l'état doit survivre à un changement d'écran, et le
combat doit pouvoir se poursuivre après fermeture de l'app (⚠️ ce dernier point n'est pas
encore vrai — voir §3.3). L'API réelle est celle exposée par `combat_engine.gd`
(`roll()` / `can_reroll()` / `roll_dodge()` / `resolve()` / `fuir()` / `cancel()` / …), les
trois signaux `assault_resolved(rapport)` / `combat_won()` / `combat_lost()` n'ont pas
changé depuis le plan initial. `resolve()` renvoie un rapport plutôt que de peindre :
c'est ce rapport qui permet un affichage lisible **et** des tests sur chaque règle
isolément.

### 3.2 La table de combat

**`data/combat-table.json`**, chargé par le moteur, partagé par les deux livres (sauf si
le marque-page d'un futur livre diffère, auquel cas il faudra le passer par livre). Trois
entrées : `situations` (nom + écarts couverts + coût de fuite), `assauts`
(`[ecart][de] = [infligés, reçus]`) et les bornes `ecart_min`/`ecart_max`.

🔴 **Piège Godot à retenir pour toute table chargée en json** : les nombres arrivent en
**float**, et `-2 in [-2.0]` est **faux** en GDScript. `_normalize_table()` convertit tout
en entiers une fois au chargement, jamais par comparaison au vol — le même piège existe
pour les identifiants de chapitre (`review.md`).

⚠️ Le JSON se régénère à partir de la table markdown en bas de ce fichier (« Table des
situations ») — ne pas éditer `combat-table.json` à la main sans repasser par cette table.

### 3.3 Les PV de l'ennemi ne sont pas encore persistés — ⚠️ SEUL POINT OUVERT (vérifié 2026-08-23)

Un combat dure plusieurs assauts. Si l'app se ferme au milieu, les PV de l'ennemi (et le
tour, le modificateur d'habileté) devraient être retrouvés — même raisonnement que pour
les pv du joueur, ce n'est pas redérivable.

🔴 **`SaveManager.KEY_COMBAT` n'existe nulle part dans le dépôt** (grep vérifié sur tout
`.gd`, et `combat_engine.gd` le dit lui-même dans son en-tête). `CombatEngine` garde son
état **uniquement en mémoire** : ça survit à un changement d'écran (autoload), **pas** à
une fermeture de l'app — rouvrir en plein combat le relance à zéro via `start()`. C'est
l'item **7** de §4.

La décision de principe — quitter un combat ne force rien, le joueur peut naviguer
ailleurs ou passer le combat — est prise et implémentée ; seule la persistance sur disque
manque pour qu'elle tienne aussi à travers un redémarrage de l'app.

### 3.5 Les pouvoirs de CARACTÈRE

| type | effet en combat |
|---|---|
| GUERRIER | +1 dégât — **déjà couvert par `PlayerStats.BILLY_MODIFIERS`** (couche stats, `deg`), ne pas le recoder dans le moteur sous peine de le compter deux fois |
| PAYSAN | ne peut pas perdre plus de 3 pv par assaut |
| DÉBROUILLARD | relance le dé d'attaque une fois, **garde le meilleur** (jamais remplacé), au choix du joueur |
| PRUDENT | esquive une attaque ou fuit le combat en dépensant de la chance — seul type qui peut fuir avec la chance |
| PÉGU | aucun |

L'esquive à la chance du PRUDENT (`can_dodge_with_chance()`/`dodge_with_chance()`) ne se
confond pas avec l'esquive à l'Adresse (second dé, ouverte à tous ceux qui ont adr ≥ 2,
peut rater) : celle du PRUDENT se paie (1 chance, constante `PRUDENT_COUT_ESQUIVE`), ne
rate jamais, et annule seulement les dégâts reçus.

🔴 **Le jet de survie du PRUDENT reste une question ouverte non tranchée.**
`_test_survie_prudent()` porte encore dans son propre commentaire « trois lectures
possibles — il reste, il disparaît, ou il devient général (tout Billy tente de
survivre) ». Le PRUDENT a donc *dans les faits* trois pouvoirs, pas quatre. Personne n'a
encore choisi ; le comportement actuel (le PRUDENT seul en profite, le jet ne consomme
pas de chance) reste le défaut tant que ça n'est pas tranché.

**La séquence d'un assaut** n'est pas atomique — jusqu'à deux décisions du joueur au
milieu :

```gdscript
func roll() -> int                     # 1. dé d'assaut, mémorisé, rien résolu
func can_reroll() -> bool              # 2. vrai pour un DÉBROUILLARD qui n'a pas relancé
func roll_dodge() -> int               # 3. SECOND dé, indépendant, si adresse >= 2
func resolve() -> Dictionary           # 4. résout avec les dés mémorisés
```

L'ordre — dé d'assaut, relance éventuelle, esquive éventuelle — vient du fait qu'un échec
d'esquive ne coûte rien : décider d'esquiver *après* le résultat de l'assaut est toujours
au moins aussi bon pour le joueur.

### 3.6 L'interface — `combat.gd` + `Combat.tscn`

Le script est une **vue pure** : il lit `CombatEngine`, lui transmet les décisions, et
peint — aucune règle dedans, ce qui garde les 33 tests du moteur valables. Trois choix pas
cosmétiques :

- **Contenu dans un `ScrollContainer`** : le panneau réclame ~780 px de haut, `AventureMenu`
  n'en laisse que ~650 après la barre de progression et le fil d'Ariane. Sans ça, les
  boutons du bas (dont « Gagner ») étaient hors écran sur un 16:9.
- **Le bouton principal est à deux temps** : « Lancer le dé » puis « Valider l'assaut ». La
  relance et l'esquive s'intercalent entre les deux.
- **`_anime` bloque les clics pendant le roulement du dé**, pour que la face affichée soit
  toujours celle appliquée.

**Trois états, un seul panneau** (le style des boutons en découle, posé par une seule
fonction `_apply_state(etat)`) :

| état | déclencheur | bouton « Gagner » |
|---|---|---|
| en cours | `is_running()` | style neutre |
| victoire | `combat_won` ou écart > +7 | style **valider**, mis en avant |
| défaite | `combat_lost` | style **danger**, mais **toujours cliquable** |

Le point qui compte : en défaite, « Gagner » reste actif. Le moteur se trompera sur les
combats à règle spéciale (§1.2) ; un joueur qui sait avoir gagné doit pouvoir le dire même
si le moteur le déclare mort — le style dit « d'après mes calculs tu as perdu », jamais
« tu n'as pas le droit ».

⚠️ **Deux pistes laissées ouvertes, jamais tranchées :**
- un **interrupteur sur le Pyro-Barbare** : le champ `pyro` du bloc de combat est purement
  déclaratif, rien dans les données ne dit si le PB est mort ou absent dans l'histoire du
  joueur — l'app applique son bonus sans le savoir, sur **29 des 46 combats de fdcn et 24
  des 40 de cdsi**. Retiré de la maquette compactée faute de place, jamais reproposé
  ailleurs.
- un **« annuler le dernier assaut »** (rendre les pv, remonter ceux de l'ennemi,
  décrémenter le tour), moins violent que « annuler tout le combat » quand le moteur se
  trompe d'un seul coup. Le rapport du dernier assaut suffirait à le défaire, mais rien
  n'est écrit.

#### Le bouton « annuler le combat »

`CombatEngine` photographie l'état au `start()` (pv, chance, objets portés, chapitre de
retour) et `cancel()` le repose. **L'ordre des opérations n'est pas négociable** : on
navigue *d'abord* (`jump_back()`), on restaure *ensuite* — sinon `go_to_node()`
réapplique les stats du chapitre neuf (dont un éventuel `max_pv`) par-dessus la
restauration, et le retour soigne le joueur au lieu de l'annuler. `cancel()` ne remet
**pas** `visited_nodes_all_times` : le chapitre a bien été vu une fois, ce que suivent
succès et marqueurs « déjà lu ».

### 3.9 Passer le combat : le coût en chance

Le coût dépend de la situation — plus le rapport de force est mauvais, plus fuir coûte
cher :

| situation | écarts | coût en chance |
|---|---|---|
| Désavantage lourd | −7 → −5 | **5** |
| Désavantage | −4, −3 | **3** |
| Désavantage léger | −2, −1 | 1 |
| Égalité | 0 | 1 |
| Avantage léger | +1, +2 | 1 |
| Avantage | +3, +4 | 1 |
| Avantage lourd | +5 → +7 | **0** (gratuit) |

⚠️ **Point non confirmé, assumé volontaire** : en désavantage lourd il faut 5 points de
chance pour fuir, or `chamax` démarre à 3 — un Billy de départ **ne peut pas** fuir un
combat très défavorable. Ça a l'air d'être exactement le propos de la règle, mais jamais
formellement confirmé.

Ne pas confondre avec l'**esquive par assaut** de l'étape 4 (basée sur l'Adresse, à
chaque tour, gratuite) : deux mécaniques différentes.

### 3.10 L'algorithme complet d'un assaut

```
0. VICTOIRE AUTOMATIQUE
   écart > +7  ->  gagné, aucun dé lancé.

1. ÉCART
   écart = hab_joueur + modificateur_manuel + pyro_ennemi − hab_ennemi
   puis plancher à −7 (le plafond +7 est déjà sorti à l'étape 0)

2. DÉ D'ASSAUT (1..6)
   base_infligés, base_reçus = table.assauts[écart][dé]

3. RELANCE — DÉBROUILLARD seulement, une fois par assaut, au choix du joueur
   garde le MEILLEUR des deux dés, il ne remplace pas
   -> retour à l'étape 2 avec le dé retenu
3 bis. ESQUIVE À LA CHANCE — PRUDENT seulement, au choix du joueur, avant résolution
   paie 1 chance, annule les dégâts reçus, ne peut pas rater
   -> ne relance rien : l'assaut se résout avec le dé déjà en main

4. ESQUIVE — au choix, si adresse >= 2. SECOND dé, indépendant.
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
   (testé AVANT le PRUDENT, pour ne pas dépenser un jet de survie pour rien)

8. PRUDENT — si les reçus feraient tomber à 0
   lancer un dé « après la mort » ; <= chance courante -> on survit à 1 pv
   (le jet ne consomme pas de chance, §3.5)

9. ISSUES
   pv_ennemi <= 0  -> victoire
   pv_joueur == 0  -> défaite (état affiché, rien de forcé, §1.2)
```

**Où atterrit chaque stat de l'ennemi** — les six champs du livre servent, aucun n'est
oublié :

| champ | où il agit |
|---|---|
| `hab` | dans l'écart, soustrait (étape 1) |
| `pyro` | dans l'écart, ajouté automatiquement (étape 1) |
| `pv` | la barre à faire descendre (étapes 7, 9) |
| `deg` | s'ajoute aux dégâts qu'on **encaisse** (étape 5) |
| `arm` | se retire des dégâts qu'on **inflige**, sauf critique (étapes 4-5) |
| `nom` | affichage |

Trois remarques qui ne sautent pas aux yeux : **`max_écart`** = la valeur du dé 6 de la
ligne (la table étant croissante en dé) ; une esquive réussie n'annule **que** les dégâts
reçus, le joueur inflige quand même les siens ; le critique est **triplement** avantageux
— dégâts maximaux, armure ignorée, et aucun dégât reçu (un 1 est forcément ≤ adresse).

### 3.11 Combat non automatisable : mode manuel, jamais une défaite

Trois raisons, dans l'ordre d'importance : marquer une défaite affirmerait quelque chose
de faux (le combat n'est pas perdu, l'app ne sait juste pas le mener) ; ça contredirait la
décision qu'une vraie défaite n'est qu'un état affiché ; et ça enverrait le joueur dans la
mauvaise branche (« Mimine », cdsi ch256, est probablement gagnable en lisant le texte).

`is_automatable(chapter_id)` distingue *pas de combat ici* (ne rien afficher) de *combat
non automatisable* (afficher la fiche, mode manuel — boutons ± pv/chance et « Gagner »
restent là, le moteur n'émet aucune issue). ⚠️ Le mode manuel n'est pas marginal : les
règles spéciales n'étant pas encodées (§1.2), **beaucoup** de combats seront calculés de
travers, le joueur doit toujours pouvoir reprendre la main.

---

## 4. Ordre de chantier

**Une seule étape reste ouverte : la 7, persistance de l'état de combat (`KEY_COMBAT`,
§3.3).** Tout le reste — table, moteur, coût de fuite, armures/critiques/esquive, pouvoirs
de CARACTÈRE, tests, annulation, interface à 3 états, jauge d'ennemi, multi-ennemis et
sentinelles à 99 — est fait, détail dans `git log`.

---

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
