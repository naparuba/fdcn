# Review — fdcn v4

État au **2026-08-12**, branche `LINKLINSSE/refacto_V4`. **Ce document ne contient que ce
qui reste à faire** : tout ce qui a été réglé en a été retiré, l'historique est dans
`git log`.

Documents voisins : **`combat.md`** (spec complète du combat) et **`todo.md`** (la liste
d'actions du §10, en cases à cocher).

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
`themes/README.md`).

**La parité avec l'archive est atteinte** (2026-08-12). Les 5 écrans tournent, y compris les
deux derniers : la page **Lore** (17 entrées avec portrait et voix, ses 2 liens branchés) et
la page **À propos**, reconstruite en conteneurs. Il n'y a plus d'écran en attente.

| | valeur |
|---|---|
| code vivant | **6 102** lignes de GDScript en 40 scripts, hors tests et hors `archive/` |
| tests | 1 671 lignes — **100 tests**, dernier passage vert **avant** les lots des 11 et 12 |
| scripts sans aucun test | **26 sur 39** — dont 24 d'interface |
| scènes vivantes | **28**. Les seuls nœuds encore en position absolue sont des atomes de dessin |

### 1.1 Écarté volontairement — à ne pas re-proposer

- **Persistance de l'état de combat.** Fermer l'app pendant un affrontement le perd.
  ⚠️ Conséquence connue : les pv déjà dépensés, eux, **restent** perdus (ils sont
  sauvegardés), donc reprendre un combat interrompu est désavantageux.
- **Affichage de `nb_infos`** dans la feuille de stats.
- **Encodage des règles spéciales de combat** dans les données des 85 combats : le moteur
  applique les règles générales, et le bouton « Gagner » est l'échappatoire.
- **Re-porter quoi que ce soit de l'archive.** La parité est **atteinte** (2026-08-12) : les
  5 écrans, le son, les annonces, les deux pages Lore et À propos. Ce qui venait de
  `archive/src/main.gd` vit désormais ici —

  Grisage des portraits → `popups/sub/inventory.gd` · onglets → `popups/settings_popup.gd` ·
  feuille de stats → `popups/sub/stats.gd` · liste d'objets → `popups/sub/inventory.gd` ·
  succès → `screens/succes_menu.gd` · chapitres → `screens/chapitres_menu.gd` · barre de
  saut → `entities/ChapterChoice.gd` (via `ChoiceNextChapiter`) · chargement → `Player.do_load()` +
  `AppParameters._apply_book()` · type de Billy → signal `Inventory.billy_changed` · combat →
  `screens/aventure_menu/combat.gd` · réglages → `ui/top_menu.gd` · livres →
  `popups/sub/book_selection.gd`.
  
  **Obsolètes, à ne pas porter** : `set_camera_to_pos` et `_on_main_background_gui_input`
  (l'ancienne caméra/swipe, remplacée par `ui/menu_page.gd`), `print_debug`, le pont
  `register_main`.
- **Dé-masquer les icônes de page et de Billy du menu du haut** (2026-08-12). Tout afficher
  demanderait ~780 px pour **540 disponibles**, et l'information est déjà accessible deux
  fois : la navigation par balayage et par les deux flèches, le type de Billy écrit en texte
  dans la barre. ⚠️ Ne pas « nettoyer » `set_page()` ni `$Pages`/`$Billys` pour autant : leurs
  4 boutons de type sont branchés et fonctionnels. C'est du code **dormant**, pas mort.

### 1.2 Décisions prises et pièges connus — à respecter, pas à redécouvrir

Ce qui suit n'est pas du travail à faire : ce sont les règles qu'un prochain lot doit
connaître pour ne pas défaire ce qui est en place. Les chantiers « composants non flex » et
« thème » sont **terminés** et ont donc quitté ce document ; il n'en reste que ceci.

**Widgets à polygones : atomes de taille fixe** (tranché le 2026-08-12). Le widget garde ses
points en dur, et un `Control` porteur d'un `custom_minimum_size` le place comme un bloc
indéformable. Appliqué à `ChapterChoice` (`Row/Rubans`, 158×75), `SuccessItem` (`Marker`,
96×69), `EndingChoice` (`Ruban`, 75×260), `bread` et `NavButon` (la racine est l'atome).

Deux pièges déjà payés, et c'est ce qui a motivé la décision :

- **ne jamais *étirer* un polygone** — ça biaise l'angle, et l'échelle se transmet aux `Label`
  enfants ;
- **une pente est un décalage en pixels, jamais un ratio** — sinon une ligne plus haute penche
  plus loin et le ruban écrit par-dessus le texte.

⚠️ **`bread` : sa largeur minimale (70) est plus petite que son dessin (91), volontairement.**
C'est ce débordement qui fait chevaucher les chevrons du fil d'Ariane. La « corriger » le
déplierait.

**Le sélecteur de livre est une grille plus haute que large** (tranché le 2026-08-12).
`BookSelection.colonnes_pour(n)` cherche la grille **la plus carrée possible sans jamais
être plus large que haute** : 2 livres l'un au-dessus de l'autre, 3 et 4 en 2×2, 6 en
2 colonnes sur 3 lignes, 9 en 3×3. L'app est en portrait et les couvertures sont plus
hautes que larges — la hauteur est la ressource rare, une grille large rapetisse les
images. Les couvertures n'ont **pas** de taille fixe : `ignore_texture_size` +
`STRETCH_KEEP_ASPECT_CENTERED` les redessinent dans leur case. Le `custom_minimum_size` de
400×400 qu'elles portaient débordait déjà l'écran à deux colonnes.

**Les traces sont réservées aux événements, les anomalies passent par `push_warning()`**
(tranché le 2026-08-12, en relisant les 10 autoloads). Un `print()` par chapitre visité, par
objet ramassé et par condition évaluée noyait ce qui compte ; il en reste 11 dans les
autoloads, tous sur un événement unique — chargement d'un livre, migration de sauvegarde,
fichier illisible. Une anomalie (clé de stat inconnue, stat inconnue dans un objet, effet
illisible) part en `push_warning()` : elle arrive dans le débogueur **avec sa pile
d'appel**, ce qu'un `print()` ne donne pas.

Trois conventions appliquées dans la foulée, à ne pas défaire : pas de `self.` (GDScript
n'en a pas besoin, et deux fichiers sur dix en étaient truffés), `.size()` plutôt que
`len()`, `maxi()`/`randi_range()` plutôt que `max()` et l'arithmétique modulo.

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

✅ **Plus aucune propriété Godot 3 dans l'app** (vérifié le 2026-08-12 : ni `rect_*`,
`autowrap`, `align`, `valign`, `bbcode_text`, `font_data`, `Pool*Array`, `yield`,
`.instance()`, `File`/`Directory`, ni `onready`/`export` sans arobase). `AboutMenu.tscn`,
la dernière scène en position absolue, est passée aux conteneurs. Il ne restait qu'une
ligne `.import/` dans le `.gitignore` — le cache d'import de Godot 3, remplacé par
`.godot/imported/` — supprimée.

Les mentions de « Godot 3 » qui subsistent dans les commentaires **expliquent des
corrections passées** : elles se lisent au passé et servent de garde-fous, il ne faut pas
les prendre pour des restes. Les scènes d'`archive/` en contiennent encore, et c'est sans
importance.

**18 styleboxes ne doivent pas rejoindre le thème.** Six scripts les lisent par
`get('theme_override_styles/panel')` et les **mutent en place** — les 8 blocs du menu du haut,
les 3 onglets de la popup d'options, la ligne d'objet, le bandeau de toast, « Gagner » et
`IssuePanel` du combat. Deux raisons : sans surcharge ce `get()` renvoie `null`, et un
stylebox venu du thème serait **partagé** entre tous les nœuds du même type, donc le muter
les repeindrait tous. Le cas le plus mordant est `settings_popup.gd:_highlight_tab`, qui mute
**sans garde `null`**.

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
| 🟡 | `autoload/Parameters.gd` | utilisé par les tests, mais aucun test ne le cible |
| ✅ | `ui/menu_page.gd`, `ui/top_menu.gd` | **dans l'arbre, `_ready()` compris** : navigation, bouclage des pages, popup qui bloque et grise les flèches, toast qui ne bloque pas, logo et titre du livre courant, type de Billy |
| 🟡 | toutes les scènes | se chargent et s'instancient, mais `_ready()` ne tourne que dans les deux tests d'interface ci-dessus |
| ✅ | `autoload/BookData.gd` | registre et fichiers d'un livre (`test_books.gd`), **évaluateur de conditions** `$end`/`$or`/`$and` avec imbrication, listes vides et condition illisible, complétion, succès, objets (`test_book_data.gd`) |
| ❌ | `entities/chapter_data.gd` | rien |
| ❌ | 24 scripts d'interface | rien |

### 2.2 Les angles morts, par ordre de risque

1. 🟠 **La plupart des scripts d'interface ne sont pas testés.** Le socle existe depuis le
   2026-08-12 (`await` dans le lanceur, `afficher()` dans `test_case.gd`) et deux écrans en
   profitent, mais les ~400 lignes de `combat.gd` et les listes virtualisées n'ont toujours
   rien.
2. 🟠 **Rien ne teste encore la mise en page rendue.** La classe de bug propre à ce dépôt
   (lignes qui se chevauchent parce que `ROW_HEIGHT` est plus petit que la hauteur minimale
   réelle, débordement horizontal) reste **invisible** — mais elle est désormais *à portée* :
   `afficher()` attend deux images, donc les tailles sont mesurables.
3. 🟠 **608 objets fuités à la sortie.** Tant que ce bruit existe, une vraie fuite passera
   inaperçue.
4. 🟡 `Sounder` n'a aucun test. `Narrator` en a un seul (la convention `audio/<chapitre>.mp3`),
   alors qu'il est de la donnée pure et se testerait entièrement sans interface.

### 2.3 Ce que la suite fait bien, à ne pas casser

- Elle **se sandboxe** : `SaveManager.base_dir`, `AppParameters.parameters_file` **et le
  livre courant** (`SANDBOX_BOOK`) sont neutralisés. Une partie réelle a déjà été perdue
  par un test, et la suite a déjà basculé de 54 assertions parce qu'elle héritait du livre
  choisi dans l'app.
- Un test **sans aucune assertion compte comme un échec**.
- Les dés du combat sont **injectables** : aucun test n'est soumis au hasard.
- `test_scenes` vérifie que chaque `$Chemin/De/Noeud` d'un script existe réellement dans sa
  scène — le filet indispensable pour des scènes éditées en texte.

---

## 3. Ajouter un troisième livre

Constat de départ : **il n'existe aucun registre des livres**. Aucune liste, aucun scan de
`books/*/` — la popup de sélection *est* la liste.

### 3.1 Ce qui ne demande rien — à ne surtout pas « compléter »

| | pourquoi c'est déjà bon |
|---|---|
| **Les sauvegardes** | fichiers `<clé>-<nom>.json` créés à la demande par `prepare_save()` |
| ~~**Les tables `{1: 'fdcn', 2: 'cdsi'}`**~~ (`Parameters.gd`, `save_manager.gd`) | ✅ supprimées le 2026-08-12 : le numéro d'une vieille sauvegarde est traduit par le **rang dans le registre**. Toujours rien à y ajouter — un livre neuf n'a jamais eu de sauvegarde numérotée |
| ~~**`ui/top_menu.tscn`** qui référence `books/fdcn/logo.png`~~ | ✅ retiré le 2026-08-12 : l'aperçu d'éditeur faisait de fdcn une **dépendance de la scène**. `set_book_context()` pose logo et titre à l'exécution |
| **La table de combat** | un seul fichier partagé — sauf si le marque-page du nouveau livre diffère, auquel cas il faut la passer par livre (`combat.md` §3.2) |

### 3.2 Les fichiers à fournir — ✅ tranché le 2026-08-13

**Une source, une sortie.** Tout ce qui s'écrit à la main est dans `scripts/src/<nom>/` (6
fichiers : le livre, ses trois tables de découpage, ses objets, ses succès) ;
`books/<nom>/data/` est produit par le générateur et ne s'édite pas. `scripts/` portant un
`.gdignore`, la source ne part même plus dans l'APK.

Le dossier d'un livre garde donc **trois dossiers** : `data/` (la sortie, plus
`compteurs.json` qui n'intéresse que l'app), `img/` (logo, titre, couverture), `audio/`
(intro et narrations). Tout `img/` et `audio/` est facultatif.

**Facultatifs** : `data/compteurs.json`, `audio/intro.mp3`, `audio/<chapitre>.mp3`. Rien ne
les déclare — **le fichier existe ou n'existe pas**.

**Produits par le générateur** : il en écrivait 11, `BookData` en chargeait 10. Il en écrit
**3**, et l'app en ouvre **5** (les 3 calculés plus les 2 tables recopiées). Ont disparu :
5 sorties que personne ne chargeait, et 3 copies qui répétaient des valeurs déjà écrites à
la main. Détail dans `books/README.md`.

### 3.3 Les trois endroits de code à modifier — ✅ faits le 2026-08-12

| | fichier | quoi |
|---|---|---|
| 1 | ~~**`scripts/generator.py`**~~ | ✅ `--book` prend le **nom** du livre (le rang reste accepté), la liste vient du registre, et le cas particulier `goto == 608 and book_number == 1` a disparu (§6.1) |
| 2 | ~~**`popups/sub/book_selection.gd` + `BookSelection.tscn`**~~ | ✅ une couverture par livre du registre, construite au `_ready()`. La scène ne contient plus qu'un `VBoxContainer` vide |
| 3 | ~~**`autoload/inventory.gd`** `MIGRATION_GUESS`~~ | ✅ déjà déplacé dans `books/<nom>/<nom>.migration_items.json` |

La table en oubliait quatre, tous traités dans la foulée : `narrator.gd` (les tables
`NARRATIONS` / `INTROS`, devenues des fichiers dans `books/<nom>/audio/`), le livre par
défaut d'`AppParameters`, la conversion des sauvegardes numérotées de `save_manager.gd`, et
l'aperçu d'éditeur de `top_menu.tscn`.

### 3.4 Le piège qui coûtera le plus cher

`PlayerStats.apply_chapter_stat()` termine par un `_:` qui **imprime un avertissement et
jette la valeur**. Chaque livre invente son vocabulaire (§4). **Auditer les clés du nouveau
livre avant de le déclarer intégré** :

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

✅ **Dossiers d'assets renommés par nom de livre** (2026-08-22, todo 3.7) : `images/dieux/1`
et `2`, `sounds/dieux/1` et `2` sont devenus `dieux/fdcn/` et `dieux/cdsi/`.
`entities/LoreEntry.gd` prend un `book_name: String` (défaut `'fdcn'`) au lieu d'un
`book_number: int` — la page Lore n'affiche toujours que fdcn (`screens/LoreMenu.tscn` ne
positionne `book_name` sur aucune instance, donc elles gardent le défaut), cdsi reste en
attente d'une page qui sache présenter deux livres.

- **`ROW_HEIGHT`** des listes virtualisées si le nouveau livre a des libellés plus longs :
  la hauteur de ligne doit rester ≥ la hauteur minimale réelle à 416 px de large, sinon les
  lignes se chevauchent.

### 3.6 Le registre — ✅ fait le 2026-08-12

`books/books.json` liste les livres, **et rien d'autre** :

```json
{ "livres": [ {"nom": "fdcn", "titre": "La Forteresse du Chaudron Noir"} ] }
```

Tout le reste est **un fichier facultatif dans le dossier du livre**, jamais une
déclaration : `data/compteurs.json`, `audio/intro.mp3`, `audio/<chapitre>.mp3`. Le fichier
existe, la fonctionnalité existe. `books/README.md` porte le mode d'emploi.

⚠️ **L'ordre de la liste compte** : le numéro d'une sauvegarde d'avant 2026 est traduit par
le rang du livre, donc un nouveau livre s'ajoute **à la fin**.

Ajouter un livre est redevenu : **déposer un dossier, ajouter une ligne, compiler**.

Le dossier lui-même est rangé en `data/` / `img/` / `audio/` / `archive/` (§3.2). Reste le
**poids** de la sortie compilée — **3.6** dans le todo.

---

### 3.7 Plan : simplifier l'encodage d'un livre

Constat de départ, mesuré sur les deux livres : un auteur écrit **8 fichiers à la main**
(606 à 691 chapitres, 8 à 10 actes, 11 à 35 sous-arcs, 60 à 86 objets, 51 à 52 succès, plus
trois petites tables), dans **quatre formats différents** — un dictionnaire de chapitres,
des tableaux **positionnels**, un dictionnaire de tables, et un mini-langage d'expressions.
Et le compilateur **accepte tout ce qu'il ne comprend pas**.

C'est ce dernier point qui coûte le plus cher, parce qu'il est silencieux. Les quatre fautes
trouvées jusqu'ici l'ont toutes été **à l'œil**, jamais par un outil :

| faute réelle | ce qui s'est passé |
|---|---|
| `cond` au lieu de `stats_cond` (cdsi ch69, ch72) | deux bonus conditionnels jamais appliqués |
| `critique` au lieu de `crit` (cdsi ×5) | cinq bonus de critique perdus |
| `pv_1_4_max` **et** `1_4_pv_max` (fdcn) | la même règle sous deux orthographes, aucune des deux gérée |
| `goto: 608` + `book_number == 1` (fdcn) | **cdsi n'a jamais eu une seule fin compilée** |

#### Étape 1 — le compilateur refuse ce qu'il ne comprend pas

**Aucun changement de format, et c'est ce qui rend les étapes suivantes sûres.** Le
compilateur lit 14 clés de chapitre ; toute autre est aujourd'hui recopiée sans un mot.

- **clé de chapitre inconnue → erreur.** Aurait attrapé `cond` le jour même ;
- **clé de stat hors vocabulaire → erreur** (déjà **3.2**) : il les collecte et les imprime,
  il manque la liste de référence ;
- **`success` inconnu → erreur** au lieu d'une trace Python ;
- **expression malformée → message**, au lieu du code 2 muet d'aujourd'hui ;
- **`&` et `|` mélangés sans parenthèses → refus**, au lieu d'un arbre faux en silence.

Coût : une liste de clés autorisées et cinq `sys.exit(2)`. Bénéfice : les quatre fautes du
tableau deviennent impossibles, et un troisième livre ne peut plus se tromper en silence.

#### Étape 2 — un seul fichier écrit à la main, en plus des chapitres

Sept des huit fichiers sont de **petites tables** (moins de 6 Ko) qui décrivent le livre, pas
son texte. Elles tiennent dans un seul `<nom>.livre.json`, et surtout **avec des champs
nommés** :

```json
{ "actes":   [ {"depart": 100, "nom": "Lenonia"} ],
  "sous_arcs": [ {"acte": "Invasion", "depart": 148, "nom": "Quartier boulanger",
                  "fins": [496, 285, 353]} ],
  "objets":  { "EPEE": {"categorie": "ARME", "stats": {"deg": 1}} },
  "succes":  { "TROIE": {"label": "Le cheval des trois", "txt": "…"} },
  "compteurs": [...], "objets_supposes": {...} }
```

Ce que ça change vraiment : `["Invasion", 148, "Quartier boulanger", [496, 285, 353]]` est un
tableau **positionnel de quatre champs**. Rien ne dit lequel est quoi, et intervertir le
départ et une fin ne produit aucune erreur — juste un découpage faux. Les nommer supprime
une classe entière de fautes muettes.

⚠️ **Ne PAS déplacer l'acte dans le chapitre.** Un acte se déclare à son chapitre de départ
et se propage par le graphe : 8 lignes couvrent 606 chapitres. L'écrire chapitre par chapitre
multiplierait la saisie par 75.

#### Étape 3 — une seule sortie compilée, sans le doublon (**3.6**)

✅ **Le doublon est parti le 2026-08-13, côté données.** `-compilated-data.json` ne contient
plus que le calculé, et **à plat** : le niveau `computed` n'avait plus de raison d'être une
fois la source retirée. Résultat, sur les deux livres :

| | avant | après |
|---|---|---|
| fdcn | 552 Ko | **401 Ko** (−27 %) |
| cdsi | 613 Ko | **453 Ko** (−26 %) |

`chapter_data.gd` accepte les deux formes (`book_data.get("computed", book_data)`) : une
recompilation avec le compilateur actuel regonfle les fichiers **sans rien casser**. C'est
ce qui permet de laisser les scripts pour plus tard.

✅ **Et les valeurs neutres ne s'écrivent plus** (2026-08-13). Un chapitre ne porte que ce
qui le distingue : `{"id": 1, "chapter": "Plante-Citrouille", "sons": [2]}`. Sur fdcn,
**9 538 des 12 120 clés** ne disaient rien — `"ending": false`, `"secret_jumps": []`,
`"ending_id": null`… Deux clés ont disparu en prime, `ending` et `is_combat`, booléens
dérivés de `ending_type` et `combat` (vérifiés identiques sur les 1 297 chapitres).

| | avant la journée | après |
|---|---|---|
| fdcn | 552 Ko | **149 Ko** (−73 %) |
| cdsi | 613 Ko | **173 Ko** (−72 %) |

⚠️ Le prix : `Node.NEUTRES` et les `.get(clé, défaut)` de `chapter_data.gd` sont **les deux
moitiés d'un seul contrat**. `test_book_data.gd` le garde — un chapitre dépouillé, ses
16 valeurs neutres vérifiées une par une.

Reste à réunir les 3 sorties compilées en un fichier — `BookData` ferait un chargement au
lieu de cinq.

#### Étape 4 — un squelette qui compile

`python3 scripts/generator.py --nouveau <nom>` crée le dossier, les deux fichiers à la main avec
un chapitre 1 valide, et l'entrée dans `books/books.json`. Ajouter un livre commencerait par
quelque chose qui **compile déjà**, au lieu d'une page blanche et de six formats à deviner.

#### Où vit quoi, depuis le 2026-08-13

La séparation est devenue nette, et c'est elle qui rend la suite lisible :

| | contenu | statut |
|---|---|---|
| `scripts/src/<nom>/` | **tout ce qui s'écrit à la main** : chapitres, actes, sous-arcs, objets, succès (68 Ko) | la **source**, unique, hors de l'APK |
| `books/<nom>/data/` | 3 sorties calculées + les 2 tables recopiées (388 Ko pour les deux livres) | une **sortie**, regénérable, à ne pas éditer |

La distinction n'est pas « une fois chacun » mais **« édité, ou généré »**. Les objets et
les succès existent des deux côtés : l'app les lit et ne peut pas aller les chercher dans
`scripts/`, que Godot ignore — le compilateur les y dépose. Une copie générée ne diverge
pas, elle se refait ; deux fichiers *édités* au même titre, si.

#### Deux doublons supprimés le 2026-08-13

- **l'index des chapitres à succès** : `-compilated-success-chapters.json` était exactement
  `-compilated-success.json` retourné, chaque succès portant déjà son `chapter`. Vérifié
  entrée par entrée (51 pour fdcn, 53 pour cdsi) avant suppression ; `BookData` le rebâtit
  au chargement. ⚠️ Un index n'est pas une règle : il ne peut pas diverger de sa source,
  contrairement à une interprétation du livre — qui reste au compilateur ;
- **l'équipement deviné** (`<nom>.migration_items.json`) : voir §11.

Reste un doublon **non résolu** : `<nom>.all_objects.json` et `<nom>.all_success.json` sont
intégralement contenus dans les fichiers compilés qui les enrichissent, et pourtant les deux
partent dans l'APK — avec le livre source lui-même. → **3.12**

#### Ce qu'il ne faut PAS toucher

- **le langage des conditions** (`MORGENSTERN|GUERRIER`, `PAYSAN&FER A CHEVAL`) : 141
  expressions distinctes, compact et lisible pour un auteur. Ses trois pièges se corrigent
  à l'étape 1, pas en changeant la syntaxe ;
- **le dictionnaire de chapitres** : une entrée par chapitre, éditée à la main, c'est la
  forme juste pour 600 entrées ;
- **la double validation objets** (utilisés ⊆ déclarés **et** déclarés ⊆ utilisés) : elle a
  déjà attrapé de vraies fautes. ✅ **Angle mort corrigé** (2026-08-22) : un objet cité
  **uniquement** dans un `stats_cond` compte désormais comme utilisé
  (`Node.get_all_stats_cond_tokens()`) — aucun des deux livres n'avait de cas réel, la
  recompilation est identique octet pour octet, mais un futur livre en aurait profité pour
  échouer à tort.

#### §11 — la sauvegarde sans objets, et la promesse qui n'était pas tenue

Une table `type de Billy -> 3 objets`, écrite à la main dans chaque livre, servait à
reconstituer l'équipement d'une sauvegarde qui ne contenait pas la liste des objets. Trois
raisons de l'avoir supprimée le 2026-08-13 :

1. **elle inventait.** La vieille sauvegarde connaissait le *type*, jamais les objets. Le
   type se **déduit** des objets partout ailleurs (`Inventory.compute_billy_for_option()`, à
   partir des catégories déclarées dans `all_objects.json`) : cette table était le seul
   endroit du dépôt à écrire la relation à l'envers, livre par livre ;
2. **elle empilait sans compter.** Ses 3 objets s'ajoutaient par-dessus le rejeu des
   chapitres, par `_raw_add()`, sans passer par `clean_overload()` : un Billy migré pouvait
   porter 6 objets, tous comptés dans ses stats ;
3. 🔴 **et l'interface ne prévenait de rien.** `do_load()` renvoyait bien
   `need_force_display_options`, les commentaires annonçaient un inventaire ouvert d'office —
   **aucun appelant ne lisait ce retour**. La promesse n'était tenue nulle part.

À la place : le rejeu des chapitres (du réel), un **signal** `Player.items_need_review` — un
signal a un abonné ou n'en a pas, il ne se perd pas par distraction —, une popup qui explique
ce qui manque et pourquoi, puis l'inventaire ouvert. C'est le seul écran où le joueur peut
rétablir la vérité, et lui seul la connaît : l'équipement de départ se choisit **avant** le
chapitre 1, aucun chapitre ne le donne.

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

**Un compteur commun + deux propres à chaque livre**, aucun croisement.

⚠️ Conséquence immédiate : la ligne « Gloire » de la feuille de stats affiche **0 pour
toujours** quand cdsi est chargé, et deux compteurs cdsi sur trois sont invisibles. Le
codage en dur est structurellement faux, pas seulement incomplet.

✅ **Tranché et fait le 2026-08-12.** `richesse` — le seul compteur que les deux livres
partagent — **reste une variable en dur** de `PlayerStats`, avec sa ligne dans
`Stats.tscn`. Les quatre autres sont **déclarés par le livre** (§4.6) et la feuille de
stats génère leurs lignes, `info` compris : il était accumulé mais jamais affiché.

### 4.2 Les variantes d'orthographe sont un défaut de saisie

| source écrite à la main | contenu |
|---|---|
| `scripts/src/fdcn/fdcn.json` | `"crit"` ×5, `"half_pv"` ×1 |
| `scripts/src/cdsi/cdsi.json` | `"critique"` ×5, `"pv_1_2_max"` ×1, et `"cond"` ×2 au lieu de `"stats_cond"` |

Le compilateur n'invente rien (`node.py:set_stats()` recopie tel quel). 🔴 **Et il avait
déjà tout pour l'attraper** : `scripts/generator.py` collecte et **imprime** toutes les clés
de stats du livre — il lui manque la **liste de référence** et un `sys.exit(2)`. `critique`
était listé à chaque compilation de cdsi, noyé dans les traces.

✅ **Corrigé le 2026-08-12** : `critique`→`crit`, `cond`→`stats_cond` (deux bonus
conditionnels que personne n'appliquait : un `end +1` sur PAYSAN, un `richesse +2` sur
COUTEAU CEREMONIAL|PIOCHE), et les six mots-clés passés à la notation d'effet. **Les deux
livres emploient maintenant le même vocabulaire**, aux compteurs propres et aux deux
règles ponctuelles près. Le garde-fou du compilateur, lui, reste à poser (**3.2**) — sans
lui, la prochaine faute repassera.

### 4.3 Les « règles ponctuelles » : 3 sur 4 sont des défauts de données

| clé | où | verdict |
|---|---|---|
| `arc_et_couteau` | fdcn **ch284**, condition *« ARC et COUTEAU »* | 🔴 **trou de saisie** : l'effet déclaré est le **nom de la condition recopié dans la case de l'effet**. L'effet réel n'est écrit nulle part. ✅ Rien à faire côté condition : l'arbre `$and` sur ARC + COUTEAU s'évalue déjà, et les deux objets existent |
| `pv_win_plus_1` | fdcn **ch126**, condition PAYSAN | 🟠 **vraie règle** : « gagner 1 pv en donne 2 ». Les 3 autres types du même chapitre ont des bonus chiffrés, le PAYSAN un booléen |
| ~~`pv_1_4_max` / `1_4_pv_max`~~ | fdcn **ch178** et **ch448**, arc « Prison » | ✅ **réglé le 2026-08-12** : c'était la même règle sous deux orthographes, toutes deux écrites `"pv": "= max/4"` |

### 4.4 Notation d'effet plutôt qu'un mot-clé par règle

Elle **absorbe six mots-clés existants**, soit 16 occurrences : `max_pv` ×10,
`max_chance` ×2, `half_pv`, `pv_1_4_max`, `1_4_pv_max`, `pv_1_2_max`.

```json
"stats": { "pv": 5 }            // NOMBRE  -> += 5. Comportement actuel, inchangé
"stats": { "pv": "= max" }      // CHAÎNE  -> une expression
"stats": { "pv": "= max/4" }
"stats": { "pv": "= moi/2" }    // moitié de la valeur COURANTE
"stats": { "pv": "- max/2" }
"stats": { "chance": "= max" }  // remplace `max_chance`, sans code dédié
```

- une **valeur numérique** garde le sens additif actuel → **aucune migration** des ~200
  entrées chiffrées existantes ;
- une **chaîne** commence par l'opérateur (`=`, `+`, `-`) et porte une expression sur deux
  jetons : **`max`** (le plafond de la stat) et **`moi`** (sa valeur courante),
  éventuellement divisés par un entier.

⚠️ **Pourquoi `moi` et `max` doivent être explicites** : `half_pv` fait aujourd'hui
`pv /= 2`, soit la moitié du **courant**, alors que `pv_1_2_max` dit « max ». Ce ne sont
**peut-être pas la même règle**, et les unifier sous un seul mot-clé serait une régression
silencieuse. **À vérifier dans le livre avant d'unifier les orthographes**, pas après —
c'est la seule question que les données ne tranchent pas.

✅ **Fait le 2026-08-12**, moteur et données. Le moteur (`PlayerStats`, section
« Notation d'effet ») ne l'accepte que sur les **ressources**, seules à avoir un `max` ;
une chaîne sur toute autre clé est signalée au lieu d'être additionnée. Les **16
occurrences** des deux livres sont migrées, `_LEGACY_EFFECTS` a disparu avec elles.

✅ **Transcription confirmée dans le livre** (2026-08-22) : `pv_1_2_max` (cdsi ch249) redonne
la moitié des pv en soin, pas une fusion avec `half_pv` ni une remise à plat — c'est un
gain, donc `"pv": "= max/2"` est devenu `"pv": "+ max/2"`.

### 4.5 `pv_win_plus_1` est un modificateur de gain

```json
"stats": { "pv_gain": 1 }     // chaque gain de pv est majoré de 1
"stats": { "chance_gain": 1 } // même mécanique pour n'importe quelle ressource
```

- un `_gain_bonus` par ressource, **dans la couche « chapitres »** : il vient d'un
  chapitre, donc remis à zéro par `reset_chapter_layer()` et reconstruit par le rejeu,
  exactement comme `pv_max_bonus` ;
- appliqué dans `add_pv()` / `add_chance()`, **uniquement sur un delta positif** — un bonus
  de gain ne doit pas amortir les dégâts ;
- **jamais sur une affectation** (`"= max"`), sinon « pv au plein » devient « au plein + 1 »,
  donc au-dessus du plafond.

### 4.6 La forme du vocabulaire

`books/<nom>/data/compteurs.json`, **fichier facultatif** :

```json
{ "compteurs": [ {"cle": "rancune", "libelle": "Rancune"},
                 {"cle": "respect", "libelle": "Respect"} ],
  "ignorees":  [ "arc_et_couteau" ] }
```

Pas de liste d'alias : les orthographes se corrigent à la source (§4.2), les entretenir
dans le moteur serait entretenir la faute.

Ce que ça change : `PlayerStats` perd ses variables en dur `gloire` et `nb_infos` pour un
dictionnaire `_compteurs` ; `apply_chapter_stat()` y range toute clé déclarée, et son `_:`
continue d'avertir sur une clé inconnue — c'est ce qui sépare `rancune` (déclaré) de
`critique` (faute de saisie) ; **la feuille de stats génère ses lignes** depuis le livre
courant. Rien à sauvegarder — les compteurs restent dérivés des chapitres.

✅ **`compteurs` fait le 2026-08-12.** `richesse` n'y figure pas : partagée par les deux
livres, elle reste en dur (§4.1). La liste **`ignorees` attend §4.3** — d'ici là les deux
clés non gérées qui restent (`arc_et_couteau`, `pv_win_plus_1`) sont dans
`PlayerStats._CHAPTER_UNMANAGED_KEYS`.

---

## 5. Export / import d'une sauvegarde

### 5.1 Ce que ça vaut

Une sauvegarde complète = **7 fichiers JSON par livre** + `parameters.json`, soit une
quinzaine de fichiers de quelques kilo-octets. **La compression ne sert à rien pour le
poids** : ce qu'on gagne, c'est **un seul fichier déplaçable** (sauvegarde de secours,
changement de téléphone, envoyer sa partie). Le zip est un conteneur, pas un compresseur.

### 5.2 Format : zip, et pas rar

`ZIPPacker` et `ZIPReader` sont **natifs dans Godot 4.7.1** (vérifié) : aucune dépendance.
**Rar est à écarter** : format propriétaire, aucun encodeur disponible.

```
fdcn-save-2026-08-11.zip
├── manifest.json          <- version d'archive, date, livre courant, save_version par livre
├── parameters.json
├── fdcn/  {all_times_already_visited,current_node_id,session_visited_nodes,
│           possessed_item,pv,chance,save_version}.json
└── cdsi/  idem
```

Le **manifeste n'est pas décoratif** : il permet à l'import de *décrire ce qu'il va écraser
avant de l'écraser* et de refuser une archive trop récente avec un message utile.

### 5.3 Le vrai obstacle : sortir du bac à sable

| plateforme | difficulté |
|---|---|
| **Windows / Linux** | 🟢 `FileDialog`, direct |
| **Android** | 🔴 `user://` est **privé à l'app**, invisible du gestionnaire de fichiers ; le *scoped storage* (API 30+) rend l'écriture externe capricieuse |
| **HTML5** | 🔴 `user://` est de l'IndexedDB : export = **téléchargement navigateur** via `JavaScriptBridge`, import = `<input type=file>` |

D'où la contrainte de conception : **un moteur d'archive découplé du transport**.
Empaqueter, valider, appliquer est identique partout ; seul « où poser le fichier » change.
Desktop d'abord.

✅ **Fait le 2026-08-13, Android compris** — et par le même chemin de code que le desktop.

L'app ne sera livrée **qu'en Android**, donc c'est lui qui commande. La bonne nouvelle est
qu'il n'y a rien à contourner : le **Storage Access Framework** est précisément la porte que
le système ouvre à une application qui n'a pas le droit d'écrire hors de chez elle, et Godot
4.7.1 l'expose sous `FEATURE_NATIVE_DIALOG_FILE` — vérifié dans le binaire, avec son pendant
`FEATURE_NATIVE_DIALOG_FILE_MIME`. Un `FileDialog` en mode natif s'y branche seul.

Trois conséquences, toutes déjà dans le code :

- **aucune permission à demander** : `WRITE_EXTERNAL_STORAGE` ne sert plus à rien depuis
  l'API 30, et c'est le système qui ouvre le fichier pour nous ;
- **le filtre est un type MIME** (`application/zip`) et non `*.zip` — Android ne filtre pas
  par extension, un `*.zip` n'y sélectionnerait **rien** ;
- **l'export vérifie que le fichier existe** après écriture au lieu de croire son propre
  rapport : le chemin vient du système, annoncer « réussi » sans rien avoir écrit serait le
  pire des messages.

Là où ce sélecteur n'existe pas, pas de bouton mort : l'export écrit dans le dossier de
l'app et **affiche le chemin**, l'import reprend la **dernière archive locale** — au
minimum la sauvegarde de secours du dernier import.

⚠️ Ce qui reste **ne se vérifie que sur un appareil** : que le chemin rendu par le SAF soit
lisible par `FileAccess`. → **2.3**

### 5.4 L'import doit être atomique — ✅ fait le 2026-08-12

Un import à moitié appliqué produit une **sauvegarde Frankenstein** — les objets d'une
partie avec le chapitre d'une autre — bien pire qu'un import raté. Donc :

1. décompresser dans `user://import_tmp/` ;
2. **tout valider** : fichiers attendus, JSON qui parse, `save_version` connue et pas
   supérieure à `CURRENT_SAVE_VERSION` ;
3. **sauvegarder l'état actuel** dans `user://backup-avant-import.zip` — le filet doit être
   automatique, pas un conseil dans une notice ;
4. basculer, puis `Player.do_load()`.

**Gratuit grâce au versionnage existant** : `prepare_save()` applique déjà la chaîne de
migrations et refuse déjà une version future. L'import n'a rien à réimplémenter.

✅ `autoload/save_archive.gd`, avec **un écart assumé sur l'étape 1** : l'archive est lue
**en mémoire** au lieu d'être décompressée dans `user://import_tmp/`. Une quinzaine de
fichiers de quelques kilo-octets y tiennent sans peine, et *rien ne touche le disque avant
que tout soit validé* — c'est exactement ce que le dossier temporaire cherchait à garantir,
avec une étape et un nettoyage en moins.

Quatre refus, tous testés : archive illisible, manifeste absent, version d'archive ou de
partie supérieure à ce que l'app sait lire, et **partie amputée** (il manque un des cinq
fichiers obligatoires). `pv` et `chance` restent facultatifs : leur absence veut dire
« jamais enregistrés, démarre au plein ».

### 5.5 Deux dépendances

- **Confirmation avant écrasement** : `MenuPage.confirm()` existe déjà.
- **Où le mettre** : la page **À propos**, déjà à construire — une scène au lieu de deux.

### 5.6 Pourquoi le faire tôt

C'est **entièrement couvrable par la suite existante** : empaqueter → décompresser →
valider → appliquer est de l'I/O dans `user://`, et le lanceur sandboxe déjà tout. Un
aller-retour complet, une archive tronquée, une archive de version future, une archive d'un
seul livre : tout se teste sans interface et sans appareil.

⚠️ Effet de bord accepté : une sauvegarde exportée est du JSON dans un zip, donc modifiable
à la main. Pour un compagnon de livre-jeu solo, ce n'est pas un problème.

---

## 6. Le générateur Python (`scripts/`, 1 028 lignes)

`generator.py` (430 l.), `node.py` (304), `condition_node.py` (131), `graph_render.py` (115,
depuis 2026-08-22), `graph.py` (26), `logger.py` (18, depuis 2026-08-22), `endings.py` (4).
S'appelait `fdcn.py` jusqu'au 2026-08-13 — un nom de livre pour un outil qui les compile
tous.

**Son mode d'emploi complet est dans [`scripts/README.md`](scripts/README.md)** : entrées,
sorties, pipeline en 8 étapes, langage des conditions et ses trois pièges, refus en code 2,
et les points de contact à ne pas oublier quand on y touche.

### 6.1 🔴 Le traitement des fins était du code mort — ✅ réparé le 2026-08-12

```python
goto = n.get('goto', [])
if isinstance(goto, int):
    goto = [goto]                        # (1) goto devient TOUJOURS une liste
goto = node.get_all_possibles_goto(goto) # (2) et cette fonction renvoie list(...)

if isinstance(goto, int):                # (3) donc ceci ne peut JAMAIS être vrai
    ...
        node.set_ending(_ending)         # (4) seul appel de set_ending du projet
```

`get_all_possibles_goto()` se termine par `return list(goto)`. La condition (3) est donc
**toujours fausse** et tout le bloc des fins est **inatteignable** — y compris ses deux
`sys.exit(2)` de validation et l'unique `set_ending()` du dépôt.

**L'historique git le confirme** :

| | commit | date |
|---|---|---|
| introduction de `goto = [goto]` | `2c02496` | **2026-08-10** |
| dernière génération des json compilés | `f31b957` | **2026-08-09** |

Les données actuelles ont été produites **la veille** de la régression : elles contiennent
bien 19 fins pour fdcn, mais **ne sont plus reproductibles**. Recompiler viderait
`endings`, `good-endings`, `bad-endings` et mettrait `computed.ending` à faux partout,
**sans un seul message d'erreur**.

✅ **Correctif appliqué** — la seconde option, la bonne : « ce nœud est une fin » ne se
mêle plus à « où va-t-il ». Une fin est un chapitre qui déclare `ending`, et **une fin n'a
pas de suite** : son `goto` éventuel n'est pas suivi.

Le numéro 608 a disparu du compilateur, et c'est essentiel : il n'était valable que pour
fdcn, où il ne correspond à **aucun chapitre**, alors que **608 est un vrai chapitre de
cdsi**. D'où le `and book_number == 1` — et d'où le fait que **cdsi n'a jamais eu une
seule fin compilée** : ses 16 fins n'écrivent pas de `goto` du tout, elles ne pouvaient
donc pas entrer dans un bloc conditionné par lui.

En remplacement, une validation que les données passent aujourd'hui : un `goto` vers un
chapitre absent du livre est une **erreur de compilation** (`sys.exit(2)`) au lieu de
fabriquer un chapitre fantôme. Vérifié sur les deux livres, sauts conditionnels et secrets
compris : les seuls sauts hors du livre sont les 19 fins de fdcn, qui déclarent toutes
`ending`.

✅ **Les deux livres ont été recompilés** dans la foulée, et le diff relu :

| | avant | après |
|---|---|---|
| fdcn, `computed.ending` | 19 | **19** — inchangé, comme prévu |
| cdsi, `computed.ending` | **0** | **16** (5 bonnes, 11 mauvaises) |
| fils hors du livre | 0 | **0** — aucun chapitre fantôme |
| chapitres dont les fils changent | — | **2** (fdcn ch33 et ch34) |

Ces deux-là méritent l'explication : leur `goto` liste **185 deux fois**, et les json
d'avant recopiaient le doublon. `get_all_possibles_goto()` déduplique désormais, donc le
lecteur ne verra plus deux fois le même choix. C'est un gain, pas une perte — et c'est la
preuve concrète de ce que « ne sont plus reproductibles » voulait dire.

Enfin, `graphviz` est passé en import **facultatif** : il ne sert qu'au png de relecture,
que l'app ne lit jamais. Sans lui, tous les json sortent quand même — refuser de compiler
les données du jeu faute d'une dépendance de confort était le mauvais arbitrage.

### 6.2 Ce qui rend le code difficile à lire

Réglé le 2026-08-22 (todo `4.1`-`4.4`), sauf une ligne :

| | constat |
|---|---|
| **Copié-collé du bloc de lecture** | 10 fois `x = n.get('x', défaut)` / `if x: node.set_x(x)`, avec des défauts incohérents (`{}` pour `stats_cond` alors que `node.py` l'initialise à `None`). **Pas touché** : chaque champ a sa propre condition (`is not None` pour `combat`/`secret_jumps`, valeur truthy pour `label`/`success`/`conditions`) — les collapser sans connaître l'intention livre par livre serait un changement de comportement, pas une simplification |
| ~~**Script à plat**~~ | ✅ `generator.py` découpé en fonctions (`lire_les_noeuds`, `taguer_les_arcs`, `construire_le_graphe`, `ecrire_les_json`, `main`) |
| ~~**66 `print()`**~~ | ✅ `--verbose` sépare trace et validation (`scripts/logger.py`) |
| ~~**Code commenté laissé en place**~~ | ✅ retiré de `generator.py`, `condition_node.py`, `graph.py` |
| ~~**Deux commentaires « Get the combat entry if any »**~~ | ✅ les commentaires ont disparu avec le bloc qu'ils décrivaient |
| ~~**Mélange des responsabilités**~~ | ✅ présentation graphviz sortie vers `scripts/graph_render.py` |
| ~~**Annotations de type en commentaire**~~ | ✅ converties en vraies annotations Python 3 |
| ~~**`get_all_stats_keys()` imprime**~~ | ✅ le `print` a disparu de la fonction |

### 6.3 Ce qui est sain, à ne pas casser

- La **séparation `Graph` / `Node` / `ConditionNode`** est correcte, et le parseur de
  conditions produit bien deux sorties (l'arbre pour le moteur, le texte pour l'affichage).
- Les **validations existent** (secrets à deux entrées, fin sans type, objets sans
  chapitre) et sont visibles par défaut (`logger.info`) ; c'est la trace par nœud/arc qui
  est maintenant silencieuse sauf `--verbose` (2026-08-22).
- La **sortie est déterministe** (`sort()`, `sort_keys=True`) : les json compilés ne bougent
  pas sans raison, ce qui rend un diff lisible.

---

## 7. Bugs et risques ouverts

| | gravité | quoi |
|---|---|---|
| 10.1 | 🔴 | **Le compilateur perdrait les fins à la prochaine exécution** (§6.1). Ne pas recompiler avant correction |
| 10.2 | ✅ | ~~**cdsi perd deux compteurs** : `rancune` (18 chapitres) et `respect` (14) tombent dans le `_:` de `apply_chapter_stat`~~ — corrigé le 2026-08-12, les compteurs sont déclarés par le livre (§4.6) |
| 10.3 | 🟡 | **4 clés de stats ignorées** — élucidées en §4.3, elles deviennent la liste `ignorees` du vocabulaire |
| 10.4 | ✅ | ~~**La ligne « Gloire » de la feuille de stats affiche 0 pour toujours sur cdsi**~~ (§4.1) — corrigé le 2026-08-12 : la feuille génère ses lignes depuis le livre |

---

## 8. Dette et hygiène — soldée

Toutes les lignes de cette section sont traitées (2026-08-12) :

| | ce qui a été fait |
|---|---|
| clés Godot 3 de `project.godot` | `[rendering] quality/driver/driver_name` et `vram_compression/import_etc` supprimées — la section `[rendering]` était devenue vide |
| **608 objets fuités** aux tests | c'étaient les **606 `chapter_data`** de fdcn, des `Node` jamais ajoutés à l'arbre donc jamais libérés, plus 2 nœuds de test en `queue_free()` que le `quit()` du lanceur devançait. `chapter_data` est passé en `RefCounted`, les 2 en `free()` |
| 3 variantes de décoration de ligne | les **deux** vraies (`ChapterChoice`) partagent un `_poser_marqueurs()`. `success_item.update()` n'en partageait qu'**une ligne** : autre widget, 2 marqueurs sur 8 — l'unifier aurait couplé deux classes pour rien |
| 4 setters de `Parameters.gd` | un `_ecrire_parametre(clé, valeur) -> bool`. ⚠️ **pas** nommé `_set` : `Object._set()` est une virtuelle de Godot, la surcharger casserait toute affectation de propriété sur l'autoload |
| `MIGRATION_GUESS` | sorti en `books/<nom>/<nom>.migration_items.json`. Les 10 noms d'objets sont vérifiés contre les données des deux livres |
| `chapter_data extends Node` | → `RefCounted`. Aucune des 27 méthodes ne touchait l'API `Node`, et aucun appelant ne traitait le résultat comme un nœud |

⚠️ Le compte de 608 est une **inférence**, pas une mesure : 606 chapitres + 2 nœuds de test.
La suite de tests doit tourner pour le confirmer.

| `archive/` sans `.gdignore` | ✅ **posé le 2026-08-12**. La parité étant atteinte, plus rien de vivant n'en dépend : Godot cesse de scanner le dossier, qui reste dans le dépôt comme référence historique. `archive/src/main.tscn` n'est donc plus ouvrable dans l'éditeur — c'était le seul prix, et il est accepté |
| assets non triés | ✅ **passage piloté par les données** (voir §8.2) : 24 fichiers déplacés dans `archive/unuzed/assets/`, 3 `.import` sans source supprimés, et un `default_env.tres` en double à la racine |

### 8.2 Le tri d'`archive/`

Graphe de références reconstruit depuis les vraies racines — `run/main_scene` et les
10 autoloads de `project.godot`, plus `test/all.gd` — en suivant à la fois les chemins
`res://` **et** les `uid://` (une scène peut ne citer que l'uid). Résultat : **71 fichiers
vivants**, et 13 qui ne l'étaient pas.

`archive/src/` — l'ancienne app, cohérente et **toujours ouvrable dans l'éditeur** :

| fichier | pourquoi |
|---|---|
| `main.tscn` + `main.gd` | l'archive elle-même, déplacée pour que `archive/` n'ait plus de fichiers en vrac |
| `left_backer.tscn` + `left_backer.gd` | flèche de navigation de l'ancienne app, instanciée 5× par `main.tscn` **et par personne d'autre**. Remplacée par `ui/NavButon.tscn` |
| `right_nexter.tscn` | même chose côté droit — et elle **partage le script de `left_backer`** |

`archive/unuzed/` — référencé par **rien du tout**, ni vivant ni archive :

| fichier | pourquoi |
|---|---|
| `going_to_line.tscn` + `going_to_line.gd` | ancêtre de `ChapterChoice` : `format=2`, et son script pilote encore un `father` que plus personne ne lui donne |
| `side_buttons_background_style.tres` | l'unique `.tres` de `themes/`, référencé par personne |
| `shader_grey.tres` | `ShaderMaterial` vide, `format=2`. Le vrai grisage passe par `shaders/gray.gdshader`, bien vivant |
| `default_env.tres` | seule référence : `[rendering] environment/defaults/default_environment`. Un environnement 3D dans une app **sans un seul nœud 3D** — la ligne a été retirée de `project.godot` |

✅ **`.gdignore` posé le 2026-08-12.** Plus rien de vivant ne dépend d'`archive/`, Godot
cesse de le scanner. Le dossier reste dans le dépôt comme référence, mais ses scènes ne
s'ouvrent plus dans l'éditeur.

### 8.3 Le tri des assets — ✅ fait, piloté par les données

`images/` et `sounds/` sont chargés par des noms **construits à l'exécution**
(`images/items/%s.svg`, `images/endings/%s.png`, `images/dice/%s-%s.svg`, `sounds/%s`,
`images/dieux/<n>/` pour le Lore), qui viennent des json de livres : aucune analyse statique
ne peut conclure. Le croisement a donc été fait dans les deux sens, **objets, succès et fins
des deux livres contre les fichiers**, en n'oubliant ni `project.godot` ni
`export_presets.cfg` (c'est là que vivent les icônes de l'app).

**363 fichiers → 339.** Ce qui est parti dans `archive/unuzed/assets/` :

| | |
|---|---|
| 6 images | référencées **uniquement par `archive/`** : `fight.png` (le seul lecteur était `going_to_line`), `tick`, `blue-tick`, `soon`, `stop`, `white` |
| 8 images | référencées par **personne** : `bongo-phumtar.gif`, `button_back`, `end`, `header`, `fleche.jpg`, `fond_livre.jpg`, `element-flat-design.jpg`, `test.png` |
| 9 icônes d'objets | pour des objets qui n'existent dans **aucun** des deux livres, dont trois doublons parlants : `PETITE MASSUE-old.svg`, `PETITE-MASSE.svg`, `PERROQUET----.svg` — les vrais `PETITE MASSUE.svg` et `PERROQUET.svg` sont bien là |
| 1 son | `lennon-rire.mp3`, que même l'archive n'appelle pas |
| 3 `.import` | sans source : `CHUT.png`, `endings/TULIPE.png` (renommé `TULIPES`), `items/TONIQUE MYSTERIEU.svg` (renommé `…MYSTERIEUX`) |

⚠️ `archive/unuzed/assets/` a survécu à la suppression des `books/<nom>/archive/` du
2026-08-13 : ce sont deux choses différentes — des assets mis de côté d'un côté, des
sorties de compilateur inutiles de l'autre.

**Deux choses gardées, exprès** : les icônes de l'app (`fdcn_icon_512.png` sert à la fiche du
magasin, pas au build) et les **7 fichiers `dieux/cdsi/`** (`images/` et `sounds/`, renommés
depuis `dieux/2/` le 2026-08-22, **3.7**) — les dieux de cdsi, que la page Lore n'affiche pas
encore faute de savoir présenter deux livres. C'est du contenu en attente, pas un orphelin.

✅ Le passage avait aussi révélé l'inverse : **14 objets sans icône**, réglé le 2026-08-22
par une icône générique (**5.5**) plutôt que par du dessin.

---

## 9. Revue de propreté — 2026-08-22

Revue demandée sur l'ensemble du dépôt (code GDScript, documentation, tests, assets), hors
`scripts/` (revu en détail en §6 le même jour) et `archive/` (supprimé le 2026-08-21).
Détail des actions en §10 sous les catégories **6 à 9**.

### 9.1 Code GDScript — ✅ soldé (2026-08-23)

| | quoi |
|---|---|
| ✅ bug mineur | **4 signaux jamais connectés** : `chapter_selected`/`chapter_chosen` (`breadcrumb.gd:44`), `new_billy_requested`/`previous_chapter_requested` (`choice_next_chapiter.gd:81,101,109`) étaient déclarés et émis sans aucun `.connect()` nulle part. Supprimés (déclarations + `.emit()`) : le vrai travail passait déjà par un appel direct (`Player.go_to_node()` etc.) juste avant chaque `emit` |
| ✅ conventions balayées | `self.` retiré des 8 fichiers qui en portaient en code réel (pas juste en commentaire, contrairement au compte initial de 12) — y compris les 3 setters (`ChapterChoice.gd`/`EndingChoice.gd`/`bread.gd:set_main`, `EndingChoice.gd:set_ending_type`) où un paramètre du même nom que le champ rendait `self.` nécessaire : réglé en renommant le paramètre plutôt qu'en gardant `self.`. `max()`/`min()` → `maxi()`/`mini()` sur les sites entiers, mais → `minf()`/`maxf()` dans `nav_buton.gd` (des `float`, que `maxi()`/`mini()` auraient tronqués — la convention telle qu'écrite ne distinguait pas les deux). `len()` → `.size()` partout |
| ✅ casse des autoloads | Les 3 fichiers en PascalCase renommés en snake_case : `BookData.gd`→`book_data.gd`, `Sounder.gd`/`.tscn`→`sounder.gd`/`.tscn`, `Parameters.gd`→`app_parameters.gd` (aligné sur l'alias `AppParameters`). Les noms de *singleton* (`BookData`, `AppParameters`, `Sounder`, utilisés dans des dizaines de scripts) restent inchangés à dessein — ils sont indépendants du nom de fichier en Godot, les renommer aurait un rayon d'effet sans rapport avec le gain |
| ✅ duplication | Les ~100 lignes de liste virtualisée (pool, recyclage au scroll) partagées par `succes_menu.gd` et `chapitres_menu.gd` sont factorisées dans `ui/virtual_list_pool.gd` (`class_name VirtualListPool`) ; chaque écran ne garde que ce qui lui est propre. ⚠️ Comportement vérifié à la lecture contre l'original, mais **pas rejoué dans l'éditeur** (indisponible ici) — à valider visuellement sur les deux écrans |
| ✅ référence obsolète | `succes_menu.gd` citait « review §5bis/§5ter », sections disparues à une renumérotation. Repointées : la première vers l'en-tête de `chapitres_menu.gd` (qui documente le motif en clair), la seconde vers `review §3.5` |

Vérifié sain au passage : pas de `TODO`/`FIXME`, pas de RNG en modulo, `push_warning`/
`push_error` appliqués partout où regardé, `screens/aventure_menu/combat.gd` (le fichier le
plus complexe et le seul non testé de cette taille) relu à la main sans trouver de bug.

### 9.2 Documentation

| | quoi |
|---|---|
| le plus visible | **le `README.md` racine ne mentionne jamais cdsi** — ne décrit que fdcn alors que l'app embarque deux livres et que `docs/playstore/` a déjà des captures cdsi |
| carte manquante | **`autoload/` n'a pas de README** malgré 10 singletons couplés entre eux ; chaque fichier est bien documenté seul, mais rien n'explique qui fait quoi entre eux |
| fichiers creux | `entities/Item.gd` (~10 % de lignes documentées) et `ui/top_menu.gd` (~2 %) sont les plus bas de leur dossier, malgré une logique non triviale |
| dérive possible | `combat.md` (2026-08-10) prescrit 3 fichiers de test séparés ; le système livré n'en a qu'un, `test_combat.gd` (544 lignes) — à relire pour voir si le doc a dérivé de l'implémentation, ou l'inverse |
| en-têtes absents | `aventure_menu.gd`, `global_completion.gd`, `breadcrumb.gd`, `position.gd` n'ont aucun commentaire de tête de fichier |

### 9.3 Tests — angles morts restants

Au-delà du chiffre déjà connu (26/39 scripts sans test, dont 24 d'interface, §2) :

| | quoi |
|---|---|
| `entities/LoreEntry.gd` | zéro test — `_chemin_image()`/`_chemin_son()` sont de la pure construction de chaîne, faciles à tester, et viennent de changer (**3.7**, `book_number` → `book_name`) : le renommage n'est vérifié que par « ça compile » |
| `autoload/Sounder.gd` | seul autoload sans aucun test comportemental |
| `entities/Item.gd`, `popups/ItemPopup.gd` | zéro test ; le repli `question.svg` (**5.5**) n'est vérifié par rien |
| `screens/aventure_menu.gd` | probablement le contrôleur le plus complexe de l'app (combat, choix, fil d'Ariane) — zéro test |

### 9.4 Assets — un angle mort du tri du 2026-08-12 (§8.3)

Le tri précédent croisait **objets, succès et fins contre les fichiers** — mais par nom, pas
par dossier. Conséquence découverte le 2026-08-22 :

✅ **16 images de `images/endings/` traitées** (2026-08-23) : `ARSENE`, `BULIAAA`, `METAAAL`,
`HONNEUR`, `TU-QUOQUE-BILLY`, `PERSONNEL`, `VIVANT`, `CERCLE-VICIEUX`, `INNOCENT`, `SEYMOUR`,
`SABOT`, `ESCALADED-QUICKLY`, `TRAVAIL-TERMINE`, `ROI-LICHE`, `MEMOIRE-HONOREE`, `FLEURS`
(296 Ko) ne correspondaient à aucun `ending_id` (`entities/EndingChoice.gd:30` ne charge que
par `ending_id`, jamais par `success`), mais à des **identifiants de succès valides** déjà
illustrés dans `images/success/`. Vérifié au hash (sha256) : 15 sur 16 différaient
réellement de leur homonyme — et la différence n'était pas un brouillon concurrent mais une
**résolution différente** (128×128 dans `endings/` contre 40×40 partout dans `success/`,
confirmé aux dimensions sur les 15). `images/success/<nom>.png` mis à jour avec la version
128×128 pour les 15 ; `FLEURS.png` était un doublon octet pour octet, ignoré. Les 16 fichiers
(`.png` + `.import`) supprimés de `images/endings/`, `.import` de `images/success/` laissés
intacts (même chemin/uid). ⚠️ Reste à constater dans l'éditeur Godot que les 15 icônes
réimportent sans régression visuelle (pas testable hors Godot).

⚠️ **11 fins nommées sur 14 n'ont aucune image** : les 10 de cdsi, plus `TRICHE` (fdcn).
Seules `SOUFLE`, `TULIPES`, `VIGNES` (fdcn) en ont une. Silencieux (`push_warning` dans
`Utils.load_external_texture`), pas un crash — mais l'écran de fin de cdsi n'a jamais eu
d'illustration. **Confirmé sur le projet source** (2026-08-23, `naparuba/fdcn`, les 5
branches distantes) : `images/endings/` y contient exactement le même mélange que celui
nettoyé ci-dessus (les 3 légitimes de fdcn + les 16 mêmes fichiers mal placés) — le mélange
préexistait, il n'a pas été introduit par ce refacto. Et le trou d'illustration est bien
d'origine : 7 des 10 fins cdsi ont un repli via leur icône de succès (comme en local), mais
`MIRROIRS-OVERLOAD`, `SOUFFLER`, `VALKAR` et `TRICHE` n'ont **aucune** image nulle part dans
le dépôt source, sur aucune branche — l'auteur original ne les a jamais dessinées. À trancher
en connaissance de cause : dessiner, ou assumer l'absence sur cdsi/`TRICHE`.

Vérifié sain : `images/items/` (119 fichiers, 0 orphelin réel — les deux faux positifs sont
`question.svg`, le repli **5.5**, et `backpack.svg`, référencé en dur par `top_menu.tscn`),
`images/success/` (103/103), `images/dice/` (12/12, les 6 valeurs × 2 couleurs), `sounds/`
racine (6/6), `images/dieux/` et `sounds/dieux/` (cohérents avec **3.7**).

---

## 10. Liste d'actions

Numérotation **catégorie.rang**, les catégories étant dans l'ordre de priorité.

**46 actions en 9 catégories.** La catégorie « Style et flex » a disparu : ses deux
dernières actions sont closes — ce qu'il en reste à savoir est en §1.2. Les catégories 6 à 9
viennent de la revue de propreté du 2026-08-22 (§9) : code GDScript, documentation, tests,
assets.

### 1 — Perte de données et angles morts critiques

| # | tag | action | réf |
|---|---|---|---|
| 1.1 | `[bug]` | ✅ **Branche des fins réparée et les deux livres recompilés** (2026-08-12) : fdcn inchangé (19 fins), **cdsi a gagné les 16 siennes**. Les deux règles transcrites de mémoire sont vérifiées (2026-08-22, voir §4.4) | §6.1 |
| 1.4 | `[data]` | ✅ **85 combats relus contre le livre.** Deux fautes trouvées en en vérifiant un seul (ch276 portait les adversaires de ch274, ch274 un bouche-trou `XXXX`), corrigées | §6.3 |
| 1.2 | `[test]` | ✅ **`BookData` testé** (2026-08-12) : `_check_cond_rec` sous toutes ses formes, plus les conditions de saut réelles de fdcn | §2.2 |

### 2 — Export / import d'une sauvegarde

| # | tag | action | réf |
|---|---|---|---|
| 2.1 | `[feature]` | ✅ **Moteur d'archive** (2026-08-12) : `autoload/save_archive.gd`, `export_to()` / `describe()` / `import_from()`, aucun chemin en dur | §5.2 |
| 2.2 | `[feature]` | ✅ **Import atomique** (2026-08-12) : tout valider en mémoire → sauvegarde de secours automatique → bascule → rechargement | §5.4 |
| 2.3 | `[test]` | **Vérifier sur un téléphone** : le transport Android passe par le Storage Access Framework, sans aucune permission (2026-08-13). Seul le comportement du chemin rendu par le système reste à constater | §5.3 |
| 2.4 | `[test]` | ✅ **13 tests** (2026-08-12) : aller-retour, contenu de l'archive, `describe()` sans effet, quatre refus, filet de secours réimportable, archive d'un seul livre | §5.6 |

### 3 — Données de livre

| # | tag | action | réf |
|---|---|---|---|
| 3.1 | `[bug]` | ✅ **Orthographes corrigées à la source** (2026-08-12) : `critique`→`crit` ×5, le `cond` de cdsi ch69/ch72 →`stats_cond`, et les six mots-clés passés à la notation. Les deux livres emploient désormais **le même vocabulaire** | §4.2, §4.4 |
| 3.2 | `[bug]` | **Le compilateur doit refuser ce qu'il ne comprend pas** : clé de chapitre inconnue, clé de stat hors vocabulaire, `success` inconnu, expression malformée, `&`/`|` mélangés — **étape 1 du plan** | §3.7, §4.2 |
| 3.3 | `[data]` | ✅ **16 occurrences migrées vers la notation d'effet** (2026-08-12) — `_LEGACY_EFFECTS` a disparu avec elles, le moteur n'a plus qu'un chemin | §4.4 |
| 3.4 | `[feature]` | **`pv_gain`** : modificateur de gain dans la couche chapitres, delta positif seulement, jamais sur une affectation | §4.5 |
| 3.5 | `[refacto]` | **Compléter le vocabulaire par livre avec `ignorees`** — les `compteurs` sont faits (2026-08-12) ; dépend de §4.3 | §4.6 |
| 3.6 | `[refacto]` | **Réunir les 3 sorties calculées en une** — le poids est réglé (2026-08-13 : 1 340 → 388 Ko pour les deux livres) | §3.2, §3.6 |
| 3.7 | `[place]` | ✅ **`images/dieux/<n>` → `dieux/<nom>/`** (2026-08-22) : dossiers renommés, `LoreEntry.gd` prend `book_name` au lieu de `book_number` | §3.5 |
| 3.8 | `[refacto]` | **Un seul fichier de tables par livre** (`<nom>.livre.json`), à champs nommés : 7 fichiers en 1, et plus un seul tableau positionnel — **étape 2** | §3.7 |
| 3.9 | `[feature]` | **Squelette de livre** (`--nouveau <nom>`) : un livre neuf part de quelque chose qui compile — **étape 4** | §3.7 |
| 3.10 | `[bug]` | ✅ **Corrigé** (2026-08-22) : un objet cité **uniquement** dans un `stats_cond` compte désormais comme utilisé, ne fait plus échouer la compilation à tort | §3.7 |
| 3.11 | `[place]` | ✅ **Mode d'emploi écrit** (2026-08-22) dans `books/README.md` — décrit le format actuel (6 fichiers), à revoir quand 3.8 fondra tout en `<nom>.livre.json` | §3.7 |
| 3.12 | `[refacto]` | ✅ **Le livre écrit à la main est passé dans `scripts/src/<nom>/`** (2026-08-13) : `scripts/` porte un `.gdignore`, l'APK n'embarque plus 136 Ko qu'il n'ouvrait jamais | §3.7 |
| 3.13 | `[refacto]` | **Le pipeline visé `src/` → `gen/` → `books/`** : moitié faite (2026-08-13), reste à écrire dans `gen/` puis copier vers `books/`, et trancher si `gen/` est commité | §3.7 *Plan* |

### 4 — Compilateur Python

| # | tag | action | réf |
|---|---|---|---|
| 4.1 | `[refacto]` | ✅ **Des niveaux de log** (2026-08-22) : `--verbose` (`scripts/logger.py`), silencieux par défaut — un run de fdcn passe de 2 050 à 56 lignes | §6.2 |
| 4.2 | `[refacto]` | ✅ **`generator.py` découpé** (2026-08-22) : `lire_les_noeuds()` / `taguer_les_arcs()` / `construire_le_graphe()` / `ecrire_les_json()` / `main()`, plus de variables globales mutées | §6.2 |
| 4.3 | `[refacto]` | ✅ **Présentation graphviz sortie de `Node`** (2026-08-22) vers `scripts/graph_render.py` : le modèle de données ne connaît plus graphviz | §6.2 |
| 4.4 | `[hygiene]` | ✅ **Nettoyé** (2026-08-22) : code commenté (`condition_node.py`, `graph.py`), annotations Python 2, `get_all_stats_keys()` qui imprimait, accesseurs morts (`have_combat`, `is_good_ending`, `is_bad_ending`, `have_ending`, `get_ending_id`), et le `sub_arc_name` hérité dans le `print` « skipping not related edge » | §6.2 |
| 4.5 | `[hygiene]` | ✅ **Le cas particulier `goto == 608 and book_number == 1` a disparu** (2026-08-12) : une fin se reconnaît à sa clé `ending`, et fdcn n'écrit plus de `goto` sur les siennes | §3.3, §6.1 |

### 5 — Tests et hygiène

| # | tag | action | réf |
|---|---|---|---|
| 5.1 | `[test]` | ✅ **Le lanceur sait `await`** (2026-08-12) : il détecte une méthode asynchrone et l'attend, et `test_case.gd` offre `afficher()` / `attendre_une_frame()` | §2.2 |
| 5.2 | `[test]` | ✅ **`menu_page` et `top_menu` testés dans l'arbre** (2026-08-12), 15 tests | §2.2 |
| 5.3 | `[place]` | ✅ **`.gdignore` posé dans `archive/`** (2026-08-12) : le dossier reste comme référence, Godot ne le scanne plus | §8.2 |
| 5.4 | `[test]` | ✅ **Assets triés par les données** (2026-08-12) : 24 fichiers rangés dans `archive/unuzed/assets/`, 3 `.import` sans source | §8.3 |
| 5.5 | `[bug]` | ✅ **14 objets sans icône** (2 dans fdcn, 12 dans cdsi dont 8 `EVENEMENT`) affichent désormais l'icône générique `question.svg`, tranché plutôt que de les dessiner (2026-08-22) | §8.3 |

### 6 — Code GDScript (revue du 2026-08-22)

| # | tag | action | réf |
|---|---|---|---|
| 6.1 | `[bug]` | ✅ **4 signaux morts supprimés** (2026-08-23) : `chapter_selected`/`chapter_chosen`/`new_billy_requested`/`previous_chapter_requested`, aucun n'était connecté | §9.1 |
| 6.2 | `[hygiene]` | ✅ **`self.` retiré** (2026-08-23) des 8 fichiers concernés — 3 setters renommaient un paramètre pour éviter le conflit avec le champ plutôt que de garder `self.` | §9.1 |
| 6.3 | `[hygiene]` | ✅ **`maxi()`/`mini()`/`.size()` appliqués** (2026-08-23) — sauf `nav_buton.gd`, en `minf()`/`maxf()` (des `float`, pas des int) | §9.1 |
| 6.4 | `[hygiene]` | ✅ **Casse des autoloads uniformisée en snake_case** (2026-08-23) : `book_data.gd`, `app_parameters.gd`, `sounder.gd`/`.tscn` — noms de singleton inchangés | §9.1 |
| 6.5 | `[refacto]` | ✅ **Pool de liste virtualisée factorisé** (2026-08-23) dans `ui/virtual_list_pool.gd` | §9.1 |
| 6.6 | `[place]` | ✅ **Références obsolètes corrigées** (2026-08-23) : `succes_menu.gd` pointe maintenant vers `chapitres_menu.gd` et `review §3.5` | §9.1 |

### 7 — Documentation (revue du 2026-08-22)

| # | tag | action | réf |
|---|---|---|---|
| 7.1 | `[place]` | **Le `README.md` racine ne mentionne jamais cdsi**, alors que l'app embarque deux livres | §9.2 |
| 7.2 | `[place]` | **`autoload/` n'a pas de README** malgré 10 singletons couplés entre eux | §9.2 |
| 7.3 | `[hygiene]` | **`entities/Item.gd` et `ui/top_menu.gd` sous-documentés** (~10 % et ~2 % de lignes commentées) malgré une logique non triviale | §9.2 |
| 7.4 | `[place]` | **`combat.md` potentiellement désynchronisé** : prescrit 3 fichiers de test séparés, le système livré n'en a qu'un | §9.2 |

### 8 — Tests (revue du 2026-08-22)

| # | tag | action | réf |
|---|---|---|---|
| 8.1 | `[test]` | **`entities/LoreEntry.gd` : zéro test**, alors que `book_number` → `book_name` (**3.7**) n'est vérifié que par la compilation | §9.3 |
| 8.2 | `[test]` | **`autoload/Sounder.gd` : zéro test**, seul autoload dans ce cas | §9.3 |
| 8.3 | `[test]` | **`entities/Item.gd`, `popups/ItemPopup.gd` : zéro test**, le repli `question.svg` (**5.5**) n'est vérifié par rien | §9.3 |
| 8.4 | `[test]` | **`screens/aventure_menu.gd` : zéro test**, probablement le contrôleur le plus complexe de l'app | §9.3 |

### 9 — Assets (revue du 2026-08-22)

| # | tag | action | réf |
|---|---|---|---|
| 9.1 | `[bug]` | ✅ **16 images orphelines de `images/endings/` corrigées** (2026-08-23) : c'était un upscale 128×128 jamais intégré des icônes de succès (vérifié au hash) — `images/success/` mis à jour pour les 15 concernées, les 16 fichiers supprimés de `endings/` | §9.4 |
| 9.2 | `[content]` | **11 fins nommées sur 14 sans image** (tout cdsi, + `TRICHE` de fdcn) — silencieux, mais l'écran de fin de cdsi n'a jamais eu d'illustration. Confirmé sur le projet source (2026-08-23) : gap hérité, jamais dessiné par l'auteur original non plus | §9.4 |
