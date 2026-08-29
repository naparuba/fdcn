# Review — fdcn v4

État au **2026-08-12**, purgé de son contenu réglé le **2026-08-23**. **Ce document ne
contient que ce qui reste à faire, ou ce qui doit rester su** (décisions et conventions
encore en vigueur) : tout le reste est réglé, l'historique complet est dans `git log`.

Documents voisins : **`review-combat.md`** (spec complète du combat) et **`todo.md`** (la
liste d'actions du §10, en cases à cocher — même contenu que le §10 ci-dessous, format
checklist).

Mesures reproductibles :

```bash
# la suite de tests (à ne lancer que sur demande)
~/_Projects/godot/Godot_v4.7.1-stable_linux.x86_64 --headless -s test/all.gd --path .
```

---

## 1. Où en est l'app

**Ce qui tourne** : le boot, la navigation (5 pages, swipe + flèches + menu du haut),
l'écran Aventure complet (fil d'Ariane, position, choix de chapitre, **combat**), les
pages Chapitres et Succès (listes virtualisées), la popup d'options (inventaire, feuille
de stats + ressources, sélection de livre), les sauvegardes versionnées avec migration,
**le son** (intro, narration, type de Billy), **les annonces** d'objet gagné/perdu et de
nouveau succès, et **un thème global** (`themes/fdcn.tres`, palette documentée dans
`themes/README.md`). La parité avec l'archive est atteinte, les 5 écrans tournent.

| | valeur |
|---|---|
| code vivant | ~6 100 lignes de GDScript en 42 scripts, hors tests et hors `archive/` |
| scènes vivantes | 28. Les seuls nœuds encore en position absolue sont des atomes de dessin |

### 1.1 Écarté volontairement — à ne pas re-proposer

- **Persistance de l'état de combat.** Fermer l'app pendant un affrontement le perd (voir
  `review-combat.md` §3.3/§4 item 7, toujours ouvert). ⚠️ Conséquence connue : les pv déjà
  dépensés, eux, **restent** perdus (ils sont sauvegardés), donc reprendre un combat
  interrompu est désavantageux.
- **Affichage de `nb_infos`** dans la feuille de stats.
- **Encodage des règles spéciales de combat** dans les données des 85 combats : le moteur
  applique les règles générales, et le bouton « Gagner » est l'échappatoire.
- **Re-porter quoi que ce soit de l'archive.** La parité est atteinte : les 5 écrans, le
  son, les annonces, les deux pages Lore et À propos. Ce qui venait de
  `archive/src/main.gd` vit désormais ici — grisage des portraits →
  `popups/sub/inventory.gd` · onglets → `popups/settings_popup.gd` · feuille de stats →
  `popups/sub/stats.gd` · liste d'objets → `popups/sub/inventory.gd` · succès →
  `screens/succes_menu.gd` · chapitres → `screens/chapitres_menu.gd` · barre de saut →
  `entities/ChapterChoice.gd` (via `ChoiceNextChapiter`) · chargement → `Player.do_load()`
  + `AppParameters._apply_book()` · type de Billy → signal `Inventory.billy_changed` ·
  combat → `screens/aventure_menu/combat.gd` · réglages → `ui/top_menu.gd` · livres →
  `popups/sub/book_selection.gd`.

  **Obsolètes, à ne pas porter** : `set_camera_to_pos` et `_on_main_background_gui_input`
  (l'ancienne caméra/swipe, remplacée par `ui/menu_page.gd`), `print_debug`, le pont
  `register_main`.
- **Dé-masquer les icônes de page et de Billy du menu du haut.** Tout afficher
  demanderait ~780 px pour **540 disponibles**, et l'information est déjà accessible deux
  fois : la navigation par balayage et par les deux flèches, le type de Billy écrit en
  texte dans la barre. ⚠️ Ne pas « nettoyer » `set_page()` ni `$Pages`/`$Billys` pour
  autant : leurs 4 boutons de type sont branchés et fonctionnels. C'est du code
  **dormant**, pas mort.

### 1.2 Décisions prises et pièges connus — à respecter, pas à redécouvrir

Ce qui suit n'est pas du travail à faire : ce sont les règles qu'un prochain lot doit
connaître pour ne pas défaire ce qui est en place.

**Widgets à polygones : atomes de taille fixe.** Le widget garde ses points en dur, et un
`Control` porteur d'un `custom_minimum_size` le place comme un bloc indéformable. Appliqué
à `ChapterChoice` (`Row/Rubans`, 158×75), `SuccessItem` (`Marker`, 96×69), `EndingChoice`
(`Ruban`, 75×260), `bread` et `NavButon` (la racine est l'atome).

Deux pièges déjà payés, et c'est ce qui a motivé la décision :

- **ne jamais *étirer* un polygone** — ça biaise l'angle, et l'échelle se transmet aux
  `Label` enfants ;
- **une pente est un décalage en pixels, jamais un ratio** — sinon une ligne plus haute
  penche plus loin et le ruban écrit par-dessus le texte.

⚠️ **`bread` : sa largeur minimale (70) est plus petite que son dessin (91),
volontairement.** C'est ce débordement qui fait chevaucher les chevrons du fil d'Ariane.
La « corriger » le déplierait.

**Le sélecteur de livre est une grille plus haute que large.**
`BookSelection.colonnes_pour(n)` cherche la grille **la plus carrée possible sans jamais
être plus large que haute** : 2 livres l'un au-dessus de l'autre, 3 et 4 en 2×2, 6 en
2 colonnes sur 3 lignes, 9 en 3×3. L'app est en portrait et les couvertures sont plus
hautes que larges — la hauteur est la ressource rare, une grille large rapetisse les
images. Les couvertures n'ont **pas** de taille fixe : `ignore_texture_size` +
`STRETCH_KEEP_ASPECT_CENTERED` les redessinent dans leur case.

**Les traces sont réservées aux événements, les anomalies passent par `push_warning()`.**
Un `print()` par chapitre visité, par objet ramassé et par condition évaluée noierait ce
qui compte ; il en reste 11 dans les autoloads, tous sur un événement unique — chargement
d'un livre, migration de sauvegarde, fichier illisible. Une anomalie (clé de stat
inconnue, stat inconnue dans un objet, effet illisible) part en `push_warning()` : elle
arrive dans le débogueur **avec sa pile d'appel**, ce qu'un `print()` ne donne pas.

Conventions à ne pas défaire : pas de `self.` sauf pour lever l'ombre d'un paramètre du
même nom que le champ (renommer le paramètre plutôt), `.size()` plutôt que `len()`,
`maxi()`/`mini()` pour des entiers, `minf()`/`maxf()` pour des `float`,
`randi_range()` plutôt que l'arithmétique modulo. Voir `review-code.md` pour le détail des
endroits où ces conventions restent à balayer ou à surveiller.

**Les propriétés Godot 3 meurent en silence.** Aucune ne produit d'erreur ; elles sont
simplement ignorées. Six familles rencontrées, chacune avait cassé quelque chose :

| propriété | conséquence observée |
|---|---|
| `popup(Rect2(...))` | un `Popup` est un `Window` en Godot 4 : l'appel réduisait `SuccessPopup` à **0 × 0** |
| `autowrap = true` | le texte des fins et des titres du Lore ne revenait **pas** à la ligne |
| `align = 2` | alignement perdu ; l'éditeur l'a converti en `1` (centré) au lieu de `2` (droite) |
| `size` / `font_data` sur `FontFile` | la police ne porte **aucune donnée** et **mesure 0** — tout widget dimensionné sur son texte le rogne |
| `anchor_right = 0.0` + `offset_right = -8` | largeur **négative** après conversion |
| `play("\"hide\"")` | guillemets **dans** la chaîne : aucune animation de ce nom |

Les mentions de « Godot 3 » qui subsistent dans les commentaires **expliquent des
corrections passées** : elles se lisent au passé et servent de garde-fous, il ne faut pas
les prendre pour des restes.

**18 styleboxes ne doivent pas rejoindre le thème.** Six scripts les lisent par
`get('theme_override_styles/panel')` et les **mutent en place** — les 8 blocs du menu du
haut, les 3 onglets de la popup d'options, la ligne d'objet, le bandeau de toast,
« Gagner » et `IssuePanel` du combat. Deux raisons : sans surcharge ce `get()` renvoie
`null`, et un stylebox venu du thème serait **partagé** entre tous les nœuds du même type,
donc le muter les repeindrait tous. Le cas le plus mordant est
`settings_popup.gd:_highlight_tab`, qui mute **sans garde `null`**.

Le reste du thème — palette, 15 variations, ce qui n'y est volontairement pas défini — vit
dans **`themes/README.md`**, à côté du fichier.

---

## 2. Tests : couverture et angles morts

### 2.1 Couverture réelle

| | script | ce qui est vérifié |
|---|---|---|
| ✅ | `autoload/combat_engine.gd` | **42 tests** : table, écart, bornes, dégâts, armures, esquive à l'adresse **et à la chance**, critique, relance qui garde le meilleur, fuite réservée au prudent, annulation |
| ✅ | `autoload/player_stats.gd` | couches de stats, ressources bornées/sauvegardées, rejeu |
| ✅ | `autoload/save_manager.gd` | versionnage, migration v1→v2, idempotence |
| ✅ | `autoload/inventory.gd` | déduction du type de Billy, surcharge, conditions |
| ✅ | `autoload/player.gd` | chargement, rejeu d'historique, nouveau Billy, aller-retour |
| 🟡 | `autoload/app_parameters.gd` | utilisé par les tests, mais aucun test ne le cible |
| ✅ | `ui/menu_page.gd`, `ui/top_menu.gd` | **dans l'arbre, `_ready()` compris** : navigation, bouclage des pages, popup qui bloque et grise les flèches, toast qui ne bloque pas, logo et titre du livre courant, type de Billy |
| 🟡 | toutes les scènes | se chargent et s'instancient, mais `_ready()` ne tourne que dans les deux tests d'interface ci-dessus |
| ✅ | `autoload/book_data.gd` | registre et fichiers d'un livre, **évaluateur de conditions** `$end`/`$or`/`$and` avec imbrication, listes vides et condition illisible, complétion, succès, objets |
| ❌ | `entities/chapter_data.gd` | rien |
| ❌ | 24 scripts d'interface | rien — détail par script en §8.3/todo 8 |

### 2.2 Les angles morts, par ordre de risque

1. 🟠 **La plupart des scripts d'interface ne sont pas testés** — le socle existe
   (`await` dans le lanceur, `afficher()` dans `test_case.gd`), mais les listes
   virtualisées et les 4 scripts de todo 8 n'ont toujours rien.
2. 🟠 **Rien ne teste encore la mise en page rendue.** La classe de bug propre à ce dépôt
   (lignes qui se chevauchent parce que `ROW_HEIGHT` est plus petit que la hauteur
   minimale réelle, débordement horizontal) reste **invisible** — mais `afficher()`
   attend deux images, donc les tailles sont mesurables si on écrit ce test un jour.
3. 🟡 `Sounder` n'a aucun test (todo 8.2). `Narrator` en a un seul, alors qu'il est de la
   donnée pure et se testerait entièrement sans interface.

### 2.3 Ce que la suite fait bien, à ne pas casser

- Elle **se sandboxe** : `SaveManager.base_dir`, `AppParameters.parameters_file` **et le
  livre courant** (`SANDBOX_BOOK`) sont neutralisés.
- Un test **sans aucune assertion compte comme un échec**.
- Les dés du combat sont **injectables** : aucun test n'est soumis au hasard.
- `test_scenes` vérifie que chaque `$Chemin/De/Noeud` d'un script existe réellement dans
  sa scène — le filet indispensable pour des scènes éditées en texte.

---

## 3. Ajouter un troisième livre

Constat de départ : **il n'existe aucun registre des livres au-delà de `books.json`**.

### 3.1 Ce qui ne demande rien — à ne surtout pas « compléter »

| | pourquoi c'est déjà bon |
|---|---|
| **Les sauvegardes** | fichiers `<clé>-<nom>.json` créés à la demande par `prepare_save()` |
| **La table de combat** | un seul fichier partagé — sauf si le marque-page du nouveau livre diffère, auquel cas il faut la passer par livre (`review-combat.md` §3.2) |

### 3.2 Les fichiers à fournir

**Une source, une sortie.** Tout ce qui s'écrit à la main est dans `scripts/src/<nom>/` (6
fichiers : le livre, ses trois tables de découpage, ses objets, ses succès) ;
`books/<nom>/data/` est produit par le générateur et ne s'édite pas. `scripts/` portant un
`.gdignore`, la source ne part même plus dans l'APK.

Le dossier d'un livre garde donc **trois dossiers** : `data/` (la sortie, plus
`compteurs.json` qui n'intéresse que l'app), `img/` (logo, titre, couverture), `audio/`
(intro et narrations). Tout `img/` et `audio/` est facultatif — **rien ne les déclare**,
le fichier existe ou n'existe pas. Détail dans `books/README.md`.

### 3.4 Le piège qui coûtera le plus cher

`PlayerStats.apply_chapter_stat()` termine par un `_:` qui **imprime un avertissement et
jette la valeur**. Chaque livre invente son vocabulaire (§4). **Auditer les clés du
nouveau livre avant de le déclarer intégré** :

```bash
python3 -c "
import json,collections
b='<nom>'
d=json.load(open(f'books/{b}/{b}-compilated-data.json'))
c=collections.Counter()
for n in d.values():
    comp=n.get('computed') or {}
    for k in (comp.get('stats') or {}): c[k]+=1
    for p in (comp.get('stats_cond') or []):
        for k in (p.get('stats') or {}): c[k]+=1
print(sorted(c.items(), key=lambda x:-x[1]))"
```

### 3.5 À trancher **avant** d'intégrer

- **`ROW_HEIGHT`** des listes virtualisées si le nouveau livre a des libellés plus longs :
  la hauteur de ligne doit rester ≥ la hauteur minimale réelle à 416 px de large, sinon
  les lignes se chevauchent.
- La page Lore ne présente encore que fdcn (`screens/LoreMenu.tscn` ne positionne
  `book_name` sur aucune instance) : cdsi reste en attente d'une page qui sache présenter
  deux livres.

### 3.6 Le registre

`books/books.json` liste les livres, **et rien d'autre** :

```json
{ "livres": [ {"nom": "fdcn", "titre": "La Forteresse du Chaudron Noir"} ] }
```

⚠️ **L'ordre de la liste compte** : le numéro d'une sauvegarde d'avant 2026 est traduit
par le rang du livre, donc un nouveau livre s'ajoute **à la fin**.

Ajouter un livre est : **déposer un dossier, ajouter une ligne, compiler**.

### 3.7 Plan : simplifier l'encodage d'un livre

Constat de départ, mesuré sur les deux livres : un auteur écrit **8 fichiers à la main**
(606 à 691 chapitres, 8 à 10 actes, 11 à 35 sous-arcs, 60 à 86 objets, 51 à 52 succès, plus
trois petites tables), dans **quatre formats différents** — un dictionnaire de chapitres,
des tableaux **positionnels**, un dictionnaire de tables, et un mini-langage
d'expressions. Et le compilateur **accepte tout ce qu'il ne comprend pas**.

C'est ce dernier point qui coûte le plus cher, parce qu'il est silencieux. Les quatre
fautes trouvées jusqu'ici l'ont toutes été **à l'œil**, jamais par un outil :

| faute réelle | ce qui s'est passé |
|---|---|
| `cond` au lieu de `stats_cond` (cdsi ch69, ch72) | deux bonus conditionnels jamais appliqués |
| `critique` au lieu de `crit` (cdsi ×5) | cinq bonus de critique perdus |
| `pv_1_4_max` **et** `1_4_pv_max` (fdcn) | la même règle sous deux orthographes, aucune des deux gérée |
| `goto: 608` + `book_number == 1` (fdcn) | **cdsi n'a jamais eu une seule fin compilée** |

#### Étape 1 — le compilateur refuse ce qu'il ne comprend pas ✅ fait (2026-08-29, todo 3.2)

Aucun changement de format. `CHAPTER_ALLOWED_KEYS` (14 clés) et `ENGINE_STATS_VOCABULARY`
dans `generator.py`, plus `MalformedExpressionError` dans `condition_node.py` :

- **clé de chapitre inconnue → erreur.** Testé en réinjectant `cond` sur cdsi ch69 : rejeté ;
- **clé de stat hors vocabulaire → erreur**, vocabulaire moteur + compteurs du livre
  (`compteurs.json`). Testé avec `critique` : rejeté ;
- **`success` inconnu → erreur** au lieu d'une trace Python ;
- **expression malformée → message** (parenthèse non fermée/non ouverte) ;
- **`&` et `|` mélangés sans parenthèses → refus**. Testé avec
  `PAYSAN&FER A CHEVAL|GUERRIER` : rejeté ; les expressions parenthésées légitimes du livre
  (`KIT DE SOIN&(PAYSAN|DEBROUILLARD)`, `(ARC&FLECHES EXPLOSIVES)|EXPLOSIFS`) compilent
  toujours.

Les deux livres recompilent à l'identique (aucun diff dans `books/`) avec ces cinq garde-fous
actifs.

#### Étape 2 — un seul fichier écrit à la main, en plus des chapitres (todo 3.8)

Sept des huit fichiers sont de **petites tables** (moins de 6 Ko) qui décrivent le livre,
pas son texte. Elles tiennent dans un seul `<nom>.livre.json`, et surtout **avec des
champs nommés** :

```json
{ "actes":   [ {"depart": 100, "nom": "Lenonia"} ],
  "sous_arcs": [ {"acte": "Invasion", "depart": 148, "nom": "Quartier boulanger",
                  "fins": [496, 285, 353]} ],
  "objets":  { "EPEE": {"categorie": "ARME", "stats": {"deg": 1}} },
  "succes":  { "TROIE": {"label": "Le cheval des trois", "txt": "…"} },
  "compteurs": [...], "objets_supposes": {...} }
```

Ce que ça change vraiment : `["Invasion", 148, "Quartier boulanger", [496, 285, 353]]` est
un tableau **positionnel de quatre champs**. Rien ne dit lequel est quoi, et intervertir
le départ et une fin ne produit aucune erreur — juste un découpage faux. Les nommer
supprime une classe entière de fautes muettes.

⚠️ **Ne PAS déplacer l'acte dans le chapitre.** Un acte se déclare à son chapitre de
départ et se propage par le graphe : 8 lignes couvrent 606 chapitres. L'écrire chapitre
par chapitre multiplierait la saisie par 75.

#### Étape 3 — une seule sortie compilée (todo 3.6)

`chapter_data.gd` accepte déjà les deux formes (`book_data.get("computed", book_data)`),
ce qui permet de laisser cette étape pour plus tard sans rien casser : `BookData` ouvre
aujourd'hui 3 fichiers calculés + 2 tables recopiées là où un seul suffirait.

⚠️ Le prix de l'allègement déjà fait : `Node.NEUTRES` et les `.get(clé, défaut)` de
`chapter_data.gd` sont **les deux moitiés d'un seul contrat**. `test_book_data.gd` le
garde — un chapitre dépouillé, ses 16 valeurs neutres vérifiées une par une.

#### Étape 4 — un squelette qui compile (todo 3.9)

`python3 scripts/generator.py --nouveau <nom>` créerait le dossier, les deux fichiers à la
main avec un chapitre 1 valide, et l'entrée dans `books/books.json`. Ajouter un livre
commencerait par quelque chose qui **compile déjà**, au lieu d'une page blanche et de six
formats à deviner.

#### Où vit quoi

| | contenu | statut |
|---|---|---|
| `scripts/src/<nom>/` | **tout ce qui s'écrit à la main** : chapitres, actes, sous-arcs, objets, succès (68 Ko) | la **source**, unique, hors de l'APK |
| `books/<nom>/data/` | 3 sorties calculées + les 2 tables recopiées (388 Ko pour les deux livres) | une **sortie**, regénérable, à ne pas éditer |

La distinction n'est pas « une fois chacun » mais **« édité, ou généré »**. Les objets et
les succès existent des deux côtés : l'app les lit et ne peut pas aller les chercher dans
`scripts/`, que Godot ignore — le compilateur les y dépose. Une copie générée ne diverge
pas, elle se refait ; deux fichiers *édités* au même titre, si.

Reste un doublon **non résolu** (todo 3.13, pipeline `src/` → `gen/` → `books/`) :
`<nom>.all_objects.json` et `<nom>.all_success.json` sont intégralement contenus dans les
fichiers compilés qui les enrichissent, et pourtant les deux partent dans l'APK — avec le
livre source lui-même.

#### Ce qu'il ne faut PAS toucher

- **le langage des conditions** (`MORGENSTERN|GUERRIER`, `PAYSAN&FER A CHEVAL`) : 141
  expressions distinctes, compact et lisible pour un auteur. Ses trois pièges se
  corrigent à l'étape 1, pas en changeant la syntaxe ;
- **le dictionnaire de chapitres** : une entrée par chapitre, éditée à la main, c'est la
  forme juste pour 600 entrées ;
- **la double validation objets** (utilisés ⊆ déclarés **et** déclarés ⊆ utilisés) : elle
  a déjà attrapé de vraies fautes.

---

## 4. Vocabulaire de stats par livre

### 4.1 La mesure

| clé | fdcn | cdsi | |
|---|---|---|---|
| `richesse` | **15** | **13** | partagée |
| `gloire` | **19** | **0** | fdcn seulement |
| `info` | **20** | **0** | fdcn seulement |
| `rancune` | **0** | **18** | cdsi seulement |
| `respect` | **0** | **14** | cdsi seulement |

**Un compteur commun + deux propres à chaque livre**, aucun croisement. `richesse` reste
une variable en dur de `PlayerStats` ; les quatre autres sont **déclarés par le livre**
(§4.6), et la feuille de stats génère leurs lignes.

### 4.3 Les « règles ponctuelles » : encore une vraie règle non codée (todo 3.5)

| clé | où | verdict |
|---|---|---|
| `arc_et_couteau` | fdcn **ch284** | 🔴 **trou de saisie** dans le livre lui-même : l'effet déclaré est le nom de la condition recopié dans la case de l'effet, l'effet réel n'est écrit nulle part. Rien à faire côté moteur, la condition s'évalue déjà correctement |

`pv_win_plus_1` (fdcn ch126, PAYSAN) est réglé ✅ le 2026-08-29 : voir §4.5.

### 4.4 Notation d'effet

Le moteur (`PlayerStats`, section « Notation d'effet ») accepte, sur les **ressources**
uniquement (seules à avoir un `max`) :

```json
"stats": { "pv": 5 }            // NOMBRE  -> += 5, comportement additif classique
"stats": { "pv": "= max" }      // CHAÎNE  -> une expression
"stats": { "pv": "= max/4" }
"stats": { "pv": "= moi/2" }    // moitié de la valeur COURANTE
"stats": { "pv": "- max/2" }
"stats": { "chance": "= max" }
```

Une chaîne sur toute autre clé que les ressources est signalée au lieu d'être
additionnée. Les deux jetons possibles sont **`max`** (le plafond de la stat) et
**`moi`** (sa valeur courante), éventuellement divisés par un entier.

### 4.5 `pv_gain` : le modificateur de gain ✅ fait (2026-08-29, todo 3.4)

```json
"stats": { "pv_gain": 1 }     // chaque gain de pv est majoré de 1
"stats": { "chance_gain": 1 } // même mécanique pour n'importe quelle ressource
```

`pv_gain_bonus`/`chance_gain_bonus` dans `PlayerStats`, un par ressource, **dans la couche
« chapitres »** : posés par `apply_chapter_stat()`, remis à zéro par `reset_chapter_layer()`
et reconstruits par le rejeu, exactement comme `pv_max_bonus`. Appliqués dans `add_pv()` /
`add_chance()`, **uniquement sur un delta positif** (`if x > 0`) — un bonus de gain n'amortit
pas les dégâts, qui passent par `del_pv()`/`del_chance()` ou un `add_pv(-N)` négatif. **Jamais
sur une affectation** : `_apply_effect()` (`"= max"`) appelle le setter borné directement,
jamais `add_pv()`, donc hérite du garde sans code dédié.

fdcn ch126 s'écrit maintenant `"PAYSAN": {"pv_gain": 1}` au lieu de `pv_win_plus_1` — la
donnée dit enfin ce qu'elle veut dire. Testé (`test_stats_effects.gd`) : le bonus double bien
un gain de 1, ne s'applique ni à une perte ni à une affectation, et disparaît au rejeu.

### 4.6 La forme du vocabulaire — todo 3.5

`books/<nom>/data/compteurs.json`, **fichier facultatif** :

```json
{ "compteurs": [ {"cle": "rancune", "libelle": "Rancune"},
                 {"cle": "respect", "libelle": "Respect"} ],
  "ignorees":  [ "arc_et_couteau" ] }
```

Pas de liste d'alias : les orthographes se corrigent à la source, les entretenir dans le
moteur serait entretenir la faute.

`ignorees` reste à raccorder : `PlayerStats._CHAPTER_UNMANAGED_KEYS` (`arc_et_couteau`
seul, depuis que `pv_win_plus_1` en est sorti le 2026-08-29) doit en sortir une fois §4.3
tranché, pour que la déclaration vive dans le livre plutôt que dans le moteur.

---

## 5. Export / import d'une sauvegarde

### 5.1 Format

Une sauvegarde complète = **7 fichiers JSON par livre** + `parameters.json`. Le zip est un
**conteneur**, pas un compresseur : ce qu'on gagne, c'est un seul fichier déplaçable
(sauvegarde de secours, changement de téléphone, envoyer sa partie). `ZIPPacker` /
`ZIPReader` sont natifs dans Godot 4.7.1, aucune dépendance.

```
fdcn-save-2026-08-11.zip
├── manifest.json          <- version d'archive, date, livre courant, save_version par livre
├── parameters.json
├── fdcn/  {all_times_already_visited,current_node_id,session_visited_nodes,
│           possessed_item,pv,chance,save_version}.json
└── cdsi/  idem
```

Le manifeste permet à l'import de *décrire ce qu'il va écraser avant de l'écraser* et de
refuser une archive trop récente avec un message utile.

### 5.3 Android — le vrai obstacle, et ce qui reste à vérifier (todo 2.3)

L'app n'est livrée qu'en Android. `user://` y est privé à l'app, invisible du gestionnaire
de fichiers ; le *scoped storage* (API 30+) rend l'écriture externe capricieuse. Le
**Storage Access Framework** est la porte que le système ouvre à une app qui n'a pas le
droit d'écrire hors de chez elle, et Godot 4.7.1 l'expose sous
`FEATURE_NATIVE_DIALOG_FILE`/`_MIME` : un `FileDialog` natif s'y branche seul, sans aucune
permission à demander, avec un filtre par **type MIME** (`application/zip`, pas
`*.zip` — Android ne filtre pas par extension).

Là où ce sélecteur n'existe pas, pas de bouton mort : l'export écrit dans le dossier de
l'app et **affiche le chemin**, l'import reprend la **dernière archive locale** — au
minimum la sauvegarde de secours du dernier import.

⚠️ **Ce qui ne se vérifie que sur un appareil physique** (todo 2.3), le code étant écrit
et ne demandant aucune permission :
- le sélecteur s'ouvre bien à l'export **et** à l'import ;
- le chemin rendu par le système est lisible par `FileAccess` (l'export le vérifie déjà et
  le dit s'il ne l'est pas) ;
- l'archive est visible depuis Téléchargements / Drive une fois écrite.

### 5.3bis L'import est atomique

1. décompresser en mémoire (une quinzaine de fichiers de quelques Ko, pas besoin d'un
   dossier temporaire) ;
2. **tout valider** : fichiers attendus, JSON qui parse, `save_version` connue et pas
   supérieure à `CURRENT_SAVE_VERSION` ;
3. **sauvegarder l'état actuel** automatiquement, avant d'écraser quoi que ce soit ;
4. basculer, puis `Player.do_load()`.

Quatre refus, tous testés : archive illisible, manifeste absent, version d'archive ou de
partie supérieure à ce que l'app sait lire, et partie amputée (il manque un des cinq
fichiers obligatoires). `pv` et `chance` restent facultatifs : leur absence veut dire
« jamais enregistrés, démarre au plein ».

⚠️ Effet de bord accepté : une sauvegarde exportée est du JSON dans un zip, donc
modifiable à la main. Pour un compagnon de livre-jeu solo, ce n'est pas un problème.

---

## 6. Le générateur Python (`scripts/`)

Son mode d'emploi complet est dans **[`scripts/README.md`](scripts/README.md)** : entrées,
sorties, pipeline en 8 étapes, langage des conditions et ses trois pièges, refus en code
2, et les points de contact à ne pas oublier quand on y touche.

### 6.2 Ce qui reste difficile à lire, par choix

`generator.py:` 10 lectures de champ suivent le motif `x = n.get('x', défaut)` /
`if x: node.set_x(x)`, avec des défauts incohérents (`{}` pour `stats_cond` alors que
`node.py` l'initialise à `None`). **Volontairement pas touché** : chaque champ a sa propre
condition (`is not None` pour `combat`/`secret_jumps`, valeur truthy pour
`label`/`success`/`conditions`) — les collapser sans connaître l'intention livre par livre
serait un changement de comportement, pas une simplification.

### 6.3 Ce qui est sain, à ne pas casser

- La **séparation `Graph` / `Node` / `ConditionNode`** est correcte, et le parseur de
  conditions produit bien deux sorties (l'arbre pour le moteur, le texte pour
  l'affichage).
- Les **validations existent** (secrets à deux entrées, fin sans type, objets sans
  chapitre) et sont visibles par défaut (`logger.info`) ; c'est la trace par nœud/arc qui
  est silencieuse sauf `--verbose`.
- La **sortie est déterministe** (`sort()`, `sort_keys=True`) : les json compilés ne
  bougent pas sans raison, ce qui rend un diff lisible.

---

## 7. Bugs et risques ouverts

| | gravité | quoi |
|---|---|---|
| 10.3 | 🟡 | **4 clés de stats ignorées** — élucidées en §4.3, deviennent la liste `ignorees` du vocabulaire (todo 3.5) |

---

## 8. Revue de propreté — 2026-08-22 → 2026-08-23

Revue faite sur l'ensemble du dépôt (code GDScript, documentation, tests, assets), hors
`scripts/` (§6) et `archive/` (supprimé le 2026-08-21). Catégories 6 à 9 du §10.

Catégories **GDScript** et **Documentation** intégralement soldées le 2026-08-23 (détail
dans `git log` — renommage des autoloads en snake_case, suppression de 4 signaux morts,
`self.` balayé, pool de liste virtualisée factorisé dans `ui/virtual_list_pool.gd`,
`README.md` racine + `autoload/README.md` écrits, `entities/Item.gd`/`ui/top_menu.gd`
documentés, `review-combat.md` corrigé). Pistes de refactor supplémentaires identifiées le
2026-08-23, non urgentes : voir **`review-code.md`**.

### 8.3 Tests — angles morts restants (todo 8)

| | quoi |
|---|---|
| `entities/LoreEntry.gd` | zéro test — `_chemin_image()`/`_chemin_son()` sont de la pure construction de chaîne, faciles à tester |
| `autoload/sounder.gd` | seul autoload sans aucun test comportemental |
| `entities/Item.gd`, `popups/ItemPopup.gd` | zéro test ; le repli `question.svg` n'est vérifié par rien |
| `screens/aventure_menu.gd` | probablement le contrôleur le plus complexe de l'app (combat, choix, fil d'Ariane) — zéro test |

### 8.4 Assets — un trou d'illustration hérité du projet source (todo 9.2)

**11 fins nommées sur 14 n'ont aucune image** : les 10 de cdsi, plus `TRICHE` (fdcn).
Seules `SOUFLE`, `TULIPES`, `VIGNES` (fdcn) en ont une. Silencieux (`push_warning` dans
`Utils.load_external_texture`), pas un crash — mais l'écran de fin de cdsi n'a jamais eu
d'illustration. **Confirmé sur le projet source** (`naparuba/fdcn`, les 5 branches
distantes) : le trou d'illustration est d'origine — 7 des 10 fins cdsi ont un repli via
leur icône de succès (comme en local), mais `MIRROIRS-OVERLOAD`, `SOUFFLER`, `VALKAR` et
`TRICHE` n'ont **aucune** image nulle part dans le dépôt source, sur aucune branche —
l'auteur original ne les a jamais dessinées. À trancher en connaissance de cause :
dessiner, ou assumer l'absence.

---

## 10. Liste d'actions

Numérotation **catégorie.rang**, reprise telle quelle dans `todo.md` en cases à cocher.

### 2 — Export / import d'une sauvegarde

| # | tag | action | réf |
|---|---|---|---|
| 2.3 | `[test]` | **Vérifier sur un téléphone** : le transport Android passe par le Storage Access Framework, sans aucune permission. Seul le comportement du chemin rendu par le système reste à constater | §5.3 |

### 3 — Données de livre

| # | tag | action | réf |
|---|---|---|---|
| 3.5 | `[refacto]` | **Compléter le vocabulaire par livre avec `ignorees`** — dépend de §4.3 | §4.6 |
| 3.6 | `[refacto]` | **Réunir les 3 sorties calculées en une** — le poids est déjà réglé | §3.7 |
| 3.8 | `[refacto]` | **Un seul fichier de tables par livre** (`<nom>.livre.json`), à champs nommés — **étape 2** | §3.7 |
| 3.9 | `[feature]` | **Squelette de livre** (`--nouveau <nom>`) — **étape 4** | §3.7 |
| 3.13 | `[refacto]` | **Le pipeline visé `src/` → `gen/` → `books/`** : moitié faite, reste à écrire dans `gen/` puis copier vers `books/`, et trancher si `gen/` est commité | §3.7 |

### 8 — Tests

| # | tag | action | réf |
|---|---|---|---|
| 8.1 | `[test]` | **`entities/LoreEntry.gd` : zéro test** | §8.3 |
| 8.2 | `[test]` | **`autoload/sounder.gd` : zéro test**, seul autoload dans ce cas | §8.3 |
| 8.3 | `[test]` | **`entities/Item.gd`, `popups/ItemPopup.gd` : zéro test** | §8.3 |
| 8.4 | `[test]` | **`screens/aventure_menu.gd` : zéro test**, probablement le contrôleur le plus complexe de l'app | §8.3 |

### 9 — Assets

| # | tag | action | réf |
|---|---|---|---|
| 9.2 | `[content]` | **11 fins nommées sur 14 sans image** — gap hérité du projet source, à trancher : dessiner ou assumer l'absence | §8.4 |
