# Review — fdcn v4

État au **2026-08-12**, branche `LINKLINSSE/refacto_V4`. **Ce document ne contient que ce
qui reste à faire** : tout ce qui a été réglé en a été retiré, l'historique est dans
`git log`.

Documents voisins : **`combat.md`** (spec complète du combat) et **`todo.md`** (la liste
d'actions du §9, en cases à cocher).

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

### 3.2 Les fichiers à fournir dans `books/<nom>/`

✅ **Rangé le 2026-08-12** en quatre dossiers : `data/` (ce que l'app et le compilateur
ouvrent), `img/` (logo, titre, couverture), `audio/` (intro et narrations), `archive/` (ce
que personne ne lit). Plus rien à la racine d'un livre.

**Écrits à la main** (6, dans `data/`) : `<nom>.json`, `<nom>.arcs.json`,
`<nom>.sub_arcs.json`, `<nom>.manual_sub_arcs.json`, `<nom>.all_objects.json`,
`<nom>.all_success.json` (renommé : c'était le seul fichier non préfixé) — plus
**`img/logo.png`**, **`img/title.png`** et **`img/cover.jpg`**.

**Facultatifs** : `data/compteurs.json`, `audio/intro.mp3`, `audio/<chapitre>.mp3`,
`data/<nom>.migration_items.json`. Rien ne les déclare — **le fichier existe ou n'existe
pas**.

**Produits par le compilateur** : les 11 `<nom>-compilated-*.json`, dont `BookData` chargeait
10. 🔴 **5 ne servaient à personne** (mesuré le 2026-08-12) :

| fichier | état |
|---|---|
| `-compilated-combats.json` | **jamais chargé** — les combats vivent dans `-compilated-data.json` |
| `-compilated-secrets.json` | chargé, **jamais lu** : `is_node_id_secret()` n'avait aucun appelant |
| `-compilated-endings.json` + `-good-endings` + `-bad-endings` | chargés à chaque changement de livre, **jamais lus** : les écrans passent par `computed.ending`, chapitre par chapitre |

Ni l'app ni `archive/` ne les ont jamais consultés. ✅ Rangés dans `books/<nom>/archive/`
le 2026-08-12, où le compilateur continue de les écrire ; `BookData` ne charge plus que
**6** fichiers, et `is_node_id_secret()` a été supprimé avec les trois listes de fins.

### 3.3 Les trois endroits de code à modifier — ✅ faits le 2026-08-12

| | fichier | quoi |
|---|---|---|
| 1 | ~~**`scripts/fdcn.py`**~~ | ✅ `--book` prend le **nom** du livre (le rang reste accepté), la liste vient du registre, et le cas particulier `goto == 608 and book_number == 1` a disparu (§6.1) |
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

- **Les dossiers d'assets numérotés.** `images/dieux/1`, `images/dieux/2`,
  `sounds/dieux/1`, `sounds/dieux/2` existent. Dans l'app vivante **rien ne les lit
  encore** — mais la page Lore en a besoin. Décider **maintenant** entre
  `dieux/3` et `dieux/<nom>/` : la page Lore écrite avant ce choix héritera d'une
  numérotation que le reste du dépôt a abandonnée au profit des noms.
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
| `books/fdcn/data/fdcn.json` | `"crit"` ×5, `"half_pv"` ×1 |
| `books/cdsi/data/cdsi.json` | `"critique"` ×5, `"pv_1_2_max"` ×1, et `"cond"` ×2 au lieu de `"stats_cond"` |

Le compilateur n'invente rien (`node.py:set_stats()` recopie tel quel). 🔴 **Et il avait
déjà tout pour l'attraper** : `scripts/fdcn.py` collecte et **imprime** toutes les clés
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

⚠️ **Une transcription reste à confirmer dans le livre papier** : `pv_1_2_max` (cdsi ch249)
est devenu `"pv": "= max/2"` — la lecture littérale de son propre nom, pas une fusion avec
`half_pv`. La question ci-dessus n'est donc pas tranchée, seulement **rendue visible dans
les données** : avant, la règle ne faisait **rien du tout** (clé non gérée), toute lecture
fidèle est déjà un gain. → todo 1.1

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

✅ **Desktop fait le 2026-08-12** : deux boutons dans « À propos », un `FileDialog` natif
créé à la demande, et la confirmation de `MenuPage` avant tout écrasement — elle annonce la
date et les livres de l'archive, lus dans le manifeste. Sur les autres plateformes, l'export
écrit dans le dossier de l'app et **affiche le chemin** plutôt que d'échouer, et l'import se
déclare indisponible : ni mensonge, ni bouton mort.

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

## 6. Le compilateur Python (`scripts/`, 959 lignes)

`fdcn.py` (405 l.), `node.py` (379), `condition_node.py` (144), `graph.py` (27),
`endings.py` (4).

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

| | constat |
|---|---|
| **Script à plat** | `fdcn.py` n'a **aucune fonction** hors `load_json_file` : 405 lignes de haut en bas, **40 variables globales** mutées au fil du fichier |
| **66 `print()`** | 42 + 15 + 9. Aucun niveau de log : la validation utile est noyée. **C'est pour ça que `critique` est passé inaperçu** (§4.2) |
| **Code commenté laissé en place** | `# goto = n['goto']` juste sous la ligne qui le remplace, `# print(...)` en série |
| **Copié-collé du bloc de lecture** | 10 fois `x = n.get('x', défaut)` / `if x: node.set_x(x)`, avec des défauts incohérents (`{}` pour `stats_cond` alors que `node.py` l'initialise à `None`) |
| **Deux commentaires « Get the combat entry if any »** | à la suite, dont un sur le bloc `secret` |
| **Mélange des responsabilités** | `node.py` fait le modèle, la sérialisation **et** la présentation graphviz (`get_label()` renvoie du HTML coloré) |
| **Annotations de type en commentaire** | `# type: (list) -> list`, style Python 2, alors que le projet est en f-strings |
| **`get_all_stats_keys()` imprime** | une fonction « get » qui écrit sur la sortie standard |

### 6.3 Ce qui est sain, à ne pas casser

- La **séparation `Graph` / `Node` / `ConditionNode`** est correcte, et le parseur de
  conditions produit bien deux sorties (l'arbre pour le moteur, le texte pour l'affichage).
- Les **validations existent** (secrets à deux entrées, fin sans type, objets sans
  chapitre) : elles sont juste invisibles faute de niveaux de log.
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

**Deux choses gardées, exprès** : les icônes de l'app (`fdcn_icon_512.png` sert à la fiche du
magasin, pas au build) et les **10 fichiers `dieux/2/`** — images et voix des dieux de cdsi,
que la page Lore n'affiche pas encore faute de savoir présenter deux livres. C'est du contenu
en attente, pas un orphelin ; il déménagera avec **3.7**.

⚠️ Le passage a aussi révélé l'inverse, plus intéressant : **14 objets n'ont aucune icône**
et affichent donc « ? » dans l'inventaire. → **5.5**

---

## 9. Liste d'actions

Numérotation **catégorie.rang**, les catégories étant dans l'ordre de priorité.

**22 actions en 5 catégories.** La catégorie « Style et flex » a disparu : ses deux
dernières actions sont closes — ce qu'il en reste à savoir est en §1.2.

### 1 — Perte de données et angles morts critiques

| # | tag | action | réf |
|---|---|---|---|
| 1.1 | `[bug]` | ✅ **Branche des fins réparée et les deux livres recompilés** (2026-08-12) : fdcn inchangé (19 fins), **cdsi a gagné les 16 siennes**. Reste à vérifier deux règles dans le livre papier (todo 1.1) | §6.1 |
| 1.2 | `[test]` | ✅ **`BookData` testé** (2026-08-12) : `_check_cond_rec` sous toutes ses formes, plus les conditions de saut réelles de fdcn | §2.2 |

### 2 — Export / import d'une sauvegarde

| # | tag | action | réf |
|---|---|---|---|
| 2.1 | `[feature]` | ✅ **Moteur d'archive** (2026-08-12) : `autoload/save_archive.gd`, `export_to()` / `describe()` / `import_from()`, aucun chemin en dur | §5.2 |
| 2.2 | `[feature]` | ✅ **Import atomique** (2026-08-12) : tout valider en mémoire → sauvegarde de secours automatique → bascule → rechargement | §5.4 |
| 2.3 | `[feature]` | Transport **Android et HTML5** — le desktop est fait (2026-08-12), avec un repli honnête ailleurs | §5.3 |
| 2.4 | `[test]` | ✅ **13 tests** (2026-08-12) : aller-retour, contenu de l'archive, `describe()` sans effet, quatre refus, filet de secours réimportable, archive d'un seul livre | §5.6 |

### 3 — Données de livre

| # | tag | action | réf |
|---|---|---|---|
| 3.1 | `[bug]` | ✅ **Orthographes corrigées à la source** (2026-08-12) : `critique`→`crit` ×5, le `cond` de cdsi ch69/ch72 →`stats_cond`, et les six mots-clés passés à la notation. Les deux livres emploient désormais **le même vocabulaire** | §4.2, §4.4 |
| 3.2 | `[bug]` | **Faire échouer `scripts/fdcn.py`** sur une clé de stat hors vocabulaire : il les collecte et les imprime déjà, il manque la liste de référence et un `sys.exit(2)` | §4.2 |
| 3.3 | `[data]` | ✅ **16 occurrences migrées vers la notation d'effet** (2026-08-12) — `_LEGACY_EFFECTS` a disparu avec elles, le moteur n'a plus qu'un chemin | §4.4 |
| 3.4 | `[feature]` | **`pv_gain`** : modificateur de gain dans la couche chapitres, delta positif seulement, jamais sur une affectation | §4.5 |
| 3.5 | `[refacto]` | **Compléter le vocabulaire par livre avec `ignorees`** — les `compteurs` sont faits (2026-08-12) ; dépend de §4.3 | §4.6 |
| 3.6 | `[refacto]` | **Alléger la sortie compilée** : `-compilated-data.json` recopie la source à côté de `computed` (28 % du fichier), et les 6 sorties de `data/` tiendraient en une. Registre et rangement faits | §3.2, §3.6 |
| 3.7 | `[place]` | Trancher `images/dieux/<n>` → `dieux/<nom>/` **avant** d'écrire la page Lore | §3.5 |

### 4 — Compilateur Python

| # | tag | action | réf |
|---|---|---|---|
| 4.1 | `[refacto]` | **Des niveaux de log** (`--verbose`) : 66 `print()` noient les validations utiles | §6.2 |
| 4.2 | `[refacto]` | **Découper `fdcn.py`** : `lire_les_noeuds()` / `taguer_les_arcs()` / `construire_le_graphe()` / `ecrire_les_json()`. Le graphviz est la moitié du fichier et l'app ne s'en sert pas | §6.2 |
| 4.3 | `[refacto]` | Sortir la présentation graphviz de `node.py` (`get_label()`) | §6.2 |
| 4.4 | `[hygiene]` | Nettoyer : code commenté, commentaires dupliqués, annotations Python 2, `get_all_stats_keys()` qui imprime | §6.2 |
| 4.5 | `[hygiene]` | ✅ **Le cas particulier `goto == 608 and book_number == 1` a disparu** (2026-08-12) : une fin se reconnaît à sa clé `ending`, et fdcn n'écrit plus de `goto` sur les siennes | §3.3, §6.1 |

### 5 — Tests et hygiène

| # | tag | action | réf |
|---|---|---|---|
| 5.1 | `[test]` | ✅ **Le lanceur sait `await`** (2026-08-12) : il détecte une méthode asynchrone et l'attend, et `test_case.gd` offre `afficher()` / `attendre_une_frame()` | §2.2 |
| 5.2 | `[test]` | ✅ **`menu_page` et `top_menu` testés dans l'arbre** (2026-08-12), 15 tests | §2.2 |
| 5.3 | `[place]` | ✅ **`.gdignore` posé dans `archive/`** (2026-08-12) : le dossier reste comme référence, Godot ne le scanne plus | §8.2 |
| 5.4 | `[test]` | ✅ **Assets triés par les données** (2026-08-12) : 24 fichiers rangés dans `archive/unuzed/assets/`, 3 `.import` sans source | §8.3 |
| 5.5 | `[bug]` | **14 objets sans icône** affichent « ? » dans l'inventaire — 2 dans fdcn, 12 dans cdsi dont 8 `EVENEMENT` | §8.3 |
