# Review — fdcn v4

État au **2026-08-11**, branche `LINKLINSSE/refacto_V4`. Remplace la review
précédente (audit initial du refacto, dont les constats sont désormais soit réglés,
soit repris ici).

Toutes les mesures de ce document sont reproductibles :

```bash
# la suite de tests
~/_Projects/godot/Godot_v4.7.1-stable_linux.x86_64 --headless -s test/all.gd --path .
# un seul fichier
... -s test/all.gd --path . -- test_combat
```

Documents voisins : **`combat.md`** (spec complète du combat, ses 14 questions
tranchées) et **`todo.md`** (la même liste d'actions, en cases à cocher).

---

## 0. Où en est l'app, en une page

**Ce qui tourne** : le boot, la navigation (5 pages, swipe + flèches + menu du haut),
l'écran Aventure complet (fil d'Ariane, position, choix de chapitre, **combat**), les
pages Chapitres et Succès (listes virtualisées), la popup d'options (inventaire,
feuille de stats + ressources, sélection de livre), les sauvegardes versionnées avec
migration.

**Ce qui ne tourne pas** : **tout le son**, les popups d'objet gagné/perdu et de
nouveau succès, les pages **Lore** et **À propos** (coquilles sans script), et les
icônes de page/Billy du menu du haut (masquées).

**Écarté volontairement** : la persistance de l'état de combat (§4.4) — fermer l'app
pendant un affrontement le perd, et c'est assumé.

**Les trois chiffres qui résument la dette** :

| | valeur |
|---|---|
| code vivant | **6 159 lignes** de GDScript (hors `archive/`) |
| suite de tests | **68 tests, 408 assertions, tout vert** |
| scripts sans aucun test | **26 sur 38** — et ce sont tous des scripts d'interface |

Le déséquilibre de la troisième ligne est le fait marquant de cette review : la
**couche de données est solidement testée, l'interface ne l'est pas du tout**.

---

## 1. Tests : ce que la suite couvre, et ses angles morts

### 1.1 Résultat du dernier passage

```
68 tests — 408 assertions — TOUT PASSE
WARNING: 608 ObjectDB instances were leaked at exit
ERROR: 1 resources still in use at exit
```

6 fichiers : `test_chapter_ids`, `test_combat` (34 tests), `test_player`,
`test_resources`, `test_save_migration`, `test_scenes`.

Deux choses que ce passage a produites, et qui valent d'être dites :

- **Un test faux, pas un bug** : `test_une_ressource_modifiee_est_sauvegardee`
  essayait « d'abîmer la valeur en mémoire » avec `add_pv()` avant de relire le
  disque — or `add_pv()` écrit aussi sur le disque. Le test se contredisait. Scindé en
  deux (écriture / lecture), parce qu'on **ne peut pas** désynchroniser la mémoire du
  disque via l'API publique : c'est une propriété du design, maintenant affirmée.
- **Le bug le plus coûteux de la session aurait été attrapé ici.** La table de combat
  chargée en float (`-2 in [-2.0]` faux en GDScript) cassait le nom de situation, le
  coût de fuite *et* la consommation de chance. `test_les_situations_portent_le_cout_de_fuite`
  l'affirmait déjà — le test existait, il n'avait simplement jamais été lancé.

### 1.2 Couverture réelle

| couvert | script | ce que les tests vérifient |
|---|---|---|
| ✅ | `autoload/combat_engine.gd` (491 l.) | 34 tests : table, écart, bornes, dégâts, armures, esquive, critique, 3 pouvoirs, fuite, annulation |
| ✅ | `autoload/player_stats.gd` (377 l.) | couches de stats, ressources bornées/sauvegardées, rejeu |
| ✅ | `autoload/save_manager.gd` (281 l.) | versionnage, migration v1→v2, idempotence, cas limites |
| ✅ | `autoload/inventory.gd` (338 l.) | déduction du type de Billy, surcharge, conditions |
| ✅ | `autoload/player.gd` (246 l.) | chargement, rejeu d'historique, nouveau Billy |
| 🟡 | `autoload/Parameters.gd` (139 l.) | utilisé par les tests, mais aucun test ne le cible |
| 🟡 | toutes les scènes | se chargent et s'instancient (`test_scenes`), mais `_ready()` ne tourne pas |
| ❌ | **`autoload/BookData.gd` (280 l.)** | **rien** |
| ❌ | `entities/chapter_data.gd` (126 l.) | rien |
| ❌ | 26 scripts d'interface | rien |

### 1.3 Les angles morts, par ordre de risque

1. 🔴 **`BookData` n'a aucun test, et `_check_cond_rec` (`:201`) non plus.** C'est
   l'évaluateur d'arbres de conditions `$or`/`$and`/`$end` : **c'est lui qui décide
   quels chapitres sont accessibles**. Logique pure, sans interface, donc trivialement
   testable — et sans filet. Une régression ici ouvre ou ferme des chemins de
   l'aventure sans que rien ne le signale. C'est le trou le plus grave de la review.
2. 🔴 **Aucun script d'interface n'est testé.** `test_scenes` valide la *structure*
   des scènes, pas leur comportement : `instantiate()` n'appelle pas `_ready()`, donc
   ni le branchement des signaux, ni la peinture initiale, ni la logique d'affichage
   ne sont exercés. Concrètement : les 353 lignes de `combat.gd` et les 148 de
   `top_menu.gd` ne sont couvertes par rien.
3. 🟠 **La suite est synchrone.** `test_case.gd` ne gère pas `await`, donc tout ce qui
   attend est hors de portée — dont l'animation de dé du combat.
4. 🟠 **Rien ne teste la mise en page rendue.** La classe de bug documentée dans ce
   dépôt (lignes qui se chevauchent parce que `ROW_HEIGHT` est plus petit que la
   hauteur minimale réelle, débordement horizontal) est **invisible** pour la suite.
   Mesurer une taille demande un arbre affiché, donc un test asynchrone.
5. 🟠 **608 objets fuités à la sortie.** Les tests ne libèrent pas tout (les scènes
   instanciées par `test_chapter_ids`, notamment). Tant que ce bruit existe, une vraie
   fuite de l'app passera inaperçue.
6. 🟡 `Sounder` n'a aucun test — mais rien ne l'appelle non plus (§2.1).

**Corrigé le 2026-08-11 — la suite dépendait du livre choisi par le développeur.**
`AppParameters` lit le vrai `parameters.json` au démarrage, et le bac à sable ne
redirigeait que le *chemin* d'écriture : les tests tournaient donc sur le livre
sélectionné dans l'app. Le jour où il est passé à cdsi, **54 assertions ont basculé** —
`test_combat` cite fdcn 114, `test_player` fdcn 112, `test_resources` fdcn 111. Le
lanceur épingle maintenant `fdcn` (`SANDBOX_BOOK`) et recharge le livre du joueur en
sortant. C'était le dernier morceau d'état réel qui fuyait dans la suite.

### 1.4 Ce que la suite fait bien, et qu'il faut garder

- Elle **se sandboxe** : `SaveManager.base_dir` et `AppParameters.parameters_file`
  sont redirigés vers `user://test_sandbox/`. Une partie réelle a déjà été perdue par
  un test, ça ne peut plus arriver.
- Un test **sans aucune assertion compte comme un échec**.
- Les dés du combat sont **injectables** (`CombatEngine.dice_roller`) : aucun test
  n'est soumis au hasard.
- `test_scenes` vérifie aussi que chaque `$Chemin/De/Noeud` d'un script existe
  réellement dans sa scène. C'est le filet qui manquait pour les scènes éditées en
  texte.

---

## 2. Parité avec l'archive : ce qui n'est pas récupéré

`archive/main.gd` = 833 lignes, **65 fonctions**. Classées par capacité (et non par
nom : la plupart ont été portées ailleurs sous un autre nom).

### 2.1 Manquant pour de vrai

| # | capacité | fonctions de l'archive | constat |
|---|---|---|---|
| **A** | 🔴 **Tout le son** | `_play_intro`, `_play_node_sound`, `change_sound` (partiel) | `Sounder` existe, l'interrupteur son le pilote — mais **aucun appel à `Sounder.play()` dans tout le code vivant**. Pas d'intro de livre, pas de narration de chapitre, pas de son au changement de Billy. Vérifié par recherche exhaustive |
| **B** | 🔴 **Popup d'objet gagné / perdu** | `popup_new_item`, `popup_remove_item`, `_create_popup_item` | `popups/ItemPopup.tscn` n'est instanciée **que par l'archive**. `Inventory.apply_chapter_items()` renvoie déjà `[gagnés, perdus]` et `Player.go_to_node()` fait remonter la paire — **personne ne la consomme** |
| **C** | 🔴 **Popup de nouveau succès** | `_check_new_success` | `popups/SuccessPopup.tscn` n'est instanciée que par l'archive. Son jingle non plus |
| **D** | 🔴 **Page Lore** | `insert_all_lore` | `screens/LoreMenu.tscn` **n'a aucun script**. `entities/LoreEntry.gd` (82 l.) existe et sait jouer un son, mais rien ne l'instancie |
| **E** | 🟠 **Page À propos** — *partiellement fait (2026-08-11)* | reste `_on_image_author_button_pressed`, `_on_morelore_button_pressed` | `screens/about_menu.gd` existe désormais et branche **nouveau Billy** (avec confirmation), **rapport de bug** et **Twitter**. Manquent les liens auteur et wiki, et la scène reste à reconstruire en conteneurs (14 nœuds fixes) |
| **F** | 🟠 **Confirmation « nouveau Billy »** | `_on_GenericTextPopup_generic_popup_accept` | `popups/GenericConfirmationPopup.gd` (26 l.) existe, aucun appelant. Or `choice_next_chapiter.launch_new_billy()` **efface la partie sans demander confirmation** |
| **G** | 🟠 **Icônes de page et de Billy du menu du haut** | `_register_top_menus`, `update_page_in_top_menus` | `$Pages` et `$Billys` sont `visible = false` dans `ui/top_menu.tscn`, et `set_page()` n'est appelée par personne. `set_billy()`, elle, est branchée |
| ~~**H**~~ | ✅ **FAIT (2026-08-11)** | `_refresh_options_book_select_display` | `book_selection.gd` grise la couverture du livre non chargé avec `gray.gdshader`, un matériau par couverture, et se repeint sur `AppParameters.book_changed` |

### 2.2 Porté sous un autre nom — rien à faire

Pour mémoire, afin qu'on ne « re-porte » pas du déjà-fait :
grisage des portraits (`__set_sprite_to_grey`) → `popups/sub/inventory.gd` ·
onglets (`__set_tab_selected`, `show_options`, `_options_show_*`) →
`popups/settings_popup.gd` · feuille de stats (`_refresh_options_stats`) →
`popups/sub/stats.gd` · liste d'objets (`display_all_objects`, `refresh_all_objects`)
→ `popups/sub/inventory.gd` · succès (`insert_all_success`, `_update_all_success`) →
`screens/succes_menu.gd` · chapitres (`_update_all_chapters`) →
`screens/chapitres_menu.gd` · barre de saut (les 8 `jump_to_chapter_*`) →
`ui/going_to_line.gd` · chargement (`_reload_all_player`, `_do_load_book_context`) →
`Player.do_load()` + `AppParameters._apply_book()` · type de Billy
(`billy_type_is_changed`) → signal `Inventory.billy_changed` · combat
(`_update_billy_in_combat`, `_on_combat_validate_button_pressed`) →
`screens/aventure_menu/combat.gd` · réglages (`change_spoils`) → `ui/top_menu.gd` ·
livres (`_switch_to_book_*`, `_change_book_number`) → `popups/sub/book_selection.gd`.

**Obsolètes, à ne pas porter** : `set_camera_to_pos` et
`_on_main_background_gui_input` (l'ancienne caméra/swipe, remplacée par
`ui/menu_page.gd`), `print_debug`, et le pont `register_main` (remplacé par des
signaux).

---

## 2bis. Ajouter un troisième livre : ce qu'il faut faire

Question posée le 2026-08-11. Constat de départ : **il n'existe aucun registre des
livres**. Aucune liste, aucun scan de `books/*/` — la popup de sélection *est* la liste.
Ajouter un livre demande donc de toucher du code, pas seulement de déposer un dossier.

### 2bis.1 Ce qui ne demande rien (à ne surtout pas « compléter »)

| | pourquoi c'est déjà bon |
|---|---|
| **Les sauvegardes** | les fichiers sont `<clé>-<nom>.json`, créés à la demande par `prepare_save()`. Un nouveau livre obtient une sauvegarde vierge tout seul |
| **Les tables `{1: 'fdcn', 2: 'cdsi'}`** (`Parameters.gd:61`, `save_manager.gd:233`) | ⚠️ **ne rien y ajouter.** Elles servent *uniquement* à la migration v1→v2 des sauvegardes suffixées par un numéro. Un livre neuf n'a jamais eu de sauvegarde numérotée |
| **`ui/top_menu.tscn`** qui référence `books/fdcn/logo.png` | ce n'est que l'aperçu de l'éditeur : `top_menu.set_book_context()` échange logo et titre à l'exécution, par nom |
| **La table de combat** | un seul fichier partagé (`data/combat-table.json`). Rien à faire — **sauf si le marque-page du nouveau livre diffère**, auquel cas il faut la passer par livre (voir `combat.md` §3.2) |
| **Les défauts `'fdcn'`** (`BookData.gd:5`, `Parameters.gd:8`) | ce sont des valeurs de repli, pas des listes |

### 2bis.2 Les fichiers à fournir dans `books/<nom>/`

**Écrits à la main** (6) : `<nom>.json` (le livre lui-même), `<nom>.arcs.json`,
`<nom>.sub_arcs.json`, `<nom>.manual_sub_arcs.json`, `<nom>.all_objects.json`,
`all-success.json` — plus **`logo.png`** et **`title.png`**.

**Produits par le compilateur** : les 11 `<nom>-compilated-*.json`. `BookData` en lit
**10** ; `<nom>-compilated-combats.json` est généré et **relu par personne** (les données
de combat vivent dans `-compilated-data.json`). À supprimer du compilateur ou à assumer.

### 2bis.3 Les trois endroits de code à modifier

| # | fichier | ce qu'il faut y faire |
|---|---|---|
| 1 | **`scripts/fdcn.py`** | `--book` est un `int` avec `choices=[1, 2]`, et `book_names = {1: 'fdcn', 2: 'cdsi'}` (`:39`). Il faut y ajouter le livre. ⚠️ Il contient aussi un **cas particulier codé en dur** : `if goto == 608 and book_number == 1` (`:104`) — à vérifier qu'il ne s'applique pas au nouveau |
| 2 | **`popups/sub/book_selection.gd` + `BookSelection.tscn`** | 🔴 **le vrai point de friction.** Une méthode par livre (`_on_bool_select_fcdn_pressed`) et un `TextureButton` par livre dans la scène, avec sa couverture en `ext_resource`. Rien n'est piloté par les données |
| 3 | **`autoload/inventory.gd`** `MIGRATION_GUESS` (`:25`) | table des objets de départ *devinés*, indexée par nom de livre. Sans entrée, une sauvegarde migrée du nouveau livre repart **sans aucun objet**, en silence |

### 2bis.4 Le piège qui coûtera le plus cher : les clés de stats inconnues

`PlayerStats.apply_chapter_stat()` termine par un `_:` qui **imprime un avertissement et
jette la valeur**. Or chaque livre invente son vocabulaire : fdcn a `gloire` et `info`,
cdsi a `rancune`, `respect`, `critique`, `pv_1_2_max` — dont **quatre sont perdus
aujourd'hui** (§4.6). Un troisième livre en apportera très probablement d'autres.

**Donc : auditer les clés du nouveau livre avant de le déclarer intégré.**

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

Toute clé absente de `_CHAPTER_LAYERED_KEYS`, du `match` et de
`_CHAPTER_UNMANAGED_KEYS` sera silencieusement perdue.

### 2bis.5 À trancher **avant** d'intégrer, pas après

- **Les dossiers d'assets numérotés.** `images/dieux/1`, `images/dieux/2`,
  `sounds/dieux/1`, `sounds/dieux/2` existent. Dans l'app vivante **rien ne les lit
  encore** (seule l'archive le fait, via `_LEGACY_ASSET_BOOK_NUMBERS`) — mais la page
  Lore (action #8) en aura besoin. Décider **maintenant** entre `dieux/3` et
  `dieux/<nom>/` : la page Lore écrite avant ce choix héritera de la numérotation, que
  le reste du dépôt a justement abandonnée au profit des noms.
- **Le nombre de succès et de chapitres** n'est jamais codé en dur (les listes sont
  virtualisées et dimensionnées depuis les données) — rien à ajuster. Vérifier tout de
  même `ROW_HEIGHT` si le nouveau livre a des libellés plus longs : la hauteur de ligne
  doit rester ≥ la hauteur minimale réelle à 416 px de large, sinon les lignes se
  chevauchent.

### 2bis.6 Recommandation : un registre, et le problème disparaît

Un `books/books.json` — ou un simple scan de `books/*/` — listant `{nom, titre,
couverture}` permettrait de :

- rendre **`BookSelection` piloté par les données** (une ligne par livre, générée), donc
  supprimer le point de friction #2 ;
- déplacer `MIGRATION_GUESS` dans `books/<nom>/` (c'est du contenu de livre, action #36),
  donc supprimer le #3 ;
- réduire l'ajout d'un livre à : **déposer un dossier, compiler, ajouter une ligne**.

Reste alors le compilateur Python (#1), qui est un outil hors application et peut vivre
avec un argument nommé plutôt qu'un numéro.

---

## 3. Composants non flex

Mesure : nœuds `layout_mode = 0` (positionnés à la main) et lignes `offset_*` brutes,
contre le nombre de conteneurs. Beaucoup d'offsets + peu de conteneurs = mise en page
en pixels fixes, qui ne suivra aucune taille d'écran.

| scène | nœuds | `lm=0` | `offset_*` | conteneurs | priorité |
|---|---|---|---|---|---|
| ~~`ui/top_menu.tscn`~~ | 61 | **0** | **1** | 20 | ✅ **FAIT (2026-08-11)** — entièrement en conteneurs |
| `screens/AboutMenu.tscn` | 32 | 14 | 69 | **0** | 🟡 coquille à refaire de toute façon (§2.1 E) |
| **`entities/ChapterChoice.tscn`** | 21 | 8 | 52 | **0** | 🔴 instanciée ~15× dans la liste virtualisée |
| `screens/LoreMenu.tscn` | 26 | 7 | 23 | 2 | 🟡 coquille à refaire (§2.1 D) |
| `ui/right_nexter.tscn` | 5 | 2 | 12 | 0 | 🟠 |
| `entities/EndingChoice.tscn` | 13 | 0 | 36 | **0** | 🟠 |
| `ui/bread.tscn` | 7 | 0 | 17 | **0** | 🟡 polygones dessinés à la main, cas à part (§3.2) |
| ~~`popups/GenericConfirmationPopup.tscn`~~ | 11 | 0 | **0** | 5 | ✅ **FAIT** — boîte centrée, voile sombre |
| `ui/left_backer.tscn` | 5 | 0 | 16 | **0** | 🟠 |
| `popups/SuccessPopup.tscn` | 7 | 0 | 15 | **0** | 🟠 |
| `entities/LoreEntry.tscn` | 8 | 0 | 12 | **0** | 🟠 (et 2,7 Mo, §5) |
| `ui/NavButon.tscn` | 5 | 0 | 10 | **0** | 🟡 polygone (§3.2) |
| `popups/ItemPopup.tscn` | 4 | 0 | 6 | **0** | 🟠 |
| `ui/gauge.tscn` | 2 | 0 | 4 | **0** | 🟠 `Node2D`, d'où le contournement `GaugeSizer` |

**Déjà pilotées par conteneurs** (rien à faire) : `screens/aventure_menu/Combat.tscn`
(73 nœuds, 24 conteneurs, 0 offset), `popups/sub/Stats.tscn` (43/13/2),
`screens/aventure_menu/Position.tscn` (21/9/0), `ChapitresMenu`, `SuccesMenu`,
`AventureMenu`, `GlobalCompletion`, `Breadcrumb`, `ChoiceNextChapiter`,
`popups/sub/Inventory.tscn`, `popups/sub/BookSelection.tscn`, `ui/ResourceGauge.tscn`,
`entities/Item.tscn`, `entities/SuccessItem.tscn`, `ui/MenuPage.tscn`.

### 3.1 `top_menu.tscn` ✅ FAIT (2026-08-11)

Réécrite : **0 nœud à position fixe, 20 conteneurs**, un seul `offset_*` (celui de la
racine, qui fixe la hauteur de 48 px). Conversions clés :

- chaque `Block*` passe de `Panel` + enfants à offsets → **`PanelContainer`** qui ajuste
  tout seul son icône et son bouton ;
- les `Sprite2D` deviennent des **`TextureRect`**. C'était obligatoire : un `Sprite2D` est
  un `Node2D`, **aucun conteneur ne peut le positionner** (piège documenté dans la mémoire
  projet, déjà payé sur `ui/gauge`) ;
- `Pages` et `Billys` passent de `Panel` à **`HBoxContainer`**, les blocs restant leurs
  enfants **directs** pour ne casser aucun chemin du script ;
- un `MarginContainer` de 4 px et un `Spacer` extensible remplacent le calage manuel.

🔴 **Deux bugs latents corrigés au passage** : `OptionsBtn` partageait sa `StyleBox` avec
`BlockMain`, et `BlockOptions` avec `BlockDebrouillard`. Comme `set_page()` et
`set_billy()` **mutent** ces styleboxes, sélectionner la page « aventure » aurait recoloré
le bouton d'options, et devenir DÉBROUILLARD aussi. Chaque bloc a désormais la sienne.

⚠️ À savoir pour l'action #10 (dé-masquer `$Pages`/`$Billys`) : tout afficher demande
38 + 100 + 160 + 260 + 220 px de large, soit bien plus que les 540 disponibles. Avec des
conteneurs le débordement est au moins **gracieux** (les enfants se compriment) au lieu de
se superposer en silence — mais il faudra choisir : déplacer spoils/son dans la popup
d'options, ou réduire les icônes.

### 3.1bis Ce qui reste, et pourquoi ce n'est pas « ajouter des conteneurs »

Mesure faite sur les 13 scènes de §3 : **6 sont bloquées par de la géométrie manuelle**
(`Polygon2D` et/ou `rotation`), et ce ne sont pas des cas isolés mais la majorité du
reliquat.

| scène | blocage |
|---|---|
| `entities/ChapterChoice.tscn` | **6 `Polygon2D` + 6 rotations.** Le script n'en pilote que la *couleur*, les points sont écrits en dur et calés sur une ligne de 75 px. Passer les libellés en conteneurs désaligne les rubans |
| `entities/EndingChoice.tscn` | 1 polygone, 3 rotations, 2 `Node2D` |
| `ui/left_backer.tscn`, `ui/right_nexter.tscn` | des barres **entières tournées à 90°** avec un polygone dessiné à la main. « Mettre des conteneurs » n'a pas de sens : c'est une refonte |
| `ui/bread.tscn`, `ui/NavButon.tscn` | 2 polygones / 1 polygone + rotations |

Elles attendent donc **la décision de §3.2**, pas du travail de conversion.

Deux autres sont volontairement laissées :

- `screens/AboutMenu.tscn` et `screens/LoreMenu.tscn` : ce sont les pages à **reconstruire**
  avec leur script (actions #8 et #9). Les convertir maintenant serait à refaire.
- `popups/SuccessPopup.tscn` : ses animations (`AnimationPlayer`) ciblent des **chemins de
  nœuds et des `scale`**. Restructurer l'arbre casse les pistes ; à faire avec l'action #7,
  qui la branchera de toute façon.
- `ui/gauge.tscn` : sa conversion **est** une action à part (#26, `Node2D` → `Control`).

⚠️ Trouvé au passage : `left_backer.tscn`, `EndingChoice.tscn`, `LoreEntry.tscn`,
`ItemPopup.tscn` et `SuccessPopup.tscn` sont encore au **format Godot 3** (`format=2`), et
trois d'entre eux utilisent l'API `align`/`valign` des `Label`, **qui n'existe plus en
Godot 4** — leur alignement est donc silencieusement perdu. À traiter avec leur conversion.

### 3.2 Les widgets à polygones ne sont pas « non flex » par négligence

`ui/bread.tscn`, `ui/NavButon.tscn`, les rubans de `SuccessItem` : ce sont des
`Polygon2D` dont les points sont écrits en dur. Ils ne peuvent pas être « passés en
conteneurs » ; il faut décider entre deux politiques — atomes de taille fixe (et un
conteneur autour), ou points recalculés depuis `size` dans `_draw()`. Deux pièges déjà
payés sont documentés dans la mémoire projet : **ne jamais *étirer* un polygone**
(ça biaise l'angle et l'échelle se transmet aux `Label` enfants), et **une pente doit
être un décalage en pixels, pas un ratio**.

---

## 4. Bugs et risques ouverts

| # | gravité | quoi |
|---|---|---|
| ~~4.1~~ | ✅ | ~~`launch_new_billy()` efface la partie sans confirmation~~ **FAIT (2026-08-11)** : passe par `GenericConfirmationPopup`, ouvert via le nouveau `MenuPage.open_popup()`. Si aucun conteneur de popup n'est trouvé, l'action **ne fait rien** plutôt que d'effacer sans demander |
| ~~4.2~~ | ✅ | ~~La photo d'annulation de combat est prise trop tard~~ **FAIT (2026-08-11)** : `Player.arrival_snapshot` est prise **en tête de `go_to_node()`**, avant tout effet du chapitre. ⚠️ Piège évité : le chapitre de retour est `session_visited_nodes[-1]` et non `[-2]` — à cet instant le chapitre d'arrivée n'est pas encore empilé, `jump_to_previous_chapter()` aurait sauté un cran. Bénéfice au-delà du combat : l'app dispose maintenant d'un « annuler l'arrivée » générique. `CombatEngine.start()` s'exécute sur `chapter_changed`, donc **après** que le chapitre a appliqué ses effets. Les 6 chapitres de combat qui donnent aussi des pv/chance (fdcn 54/58/133, cdsi 40/68/73) gardent ce gain quand on annule. Vrai correctif : une photo prise par `Player.go_to_node()` avant d'appliquer, ce qui offrirait un « annuler l'arrivée » pour n'importe quel chapitre |
| ~~4.3~~ | ✅ | ~~Retour en arrière = stats de chapitre réappliquées~~ **FAIT (2026-08-11)** : nouveau `Player.go_back_to()` qui dépile, renavigue **et** refait la couche « chapitres ». Les 4 sites qui enchaînaient `jump_back()` + `go_to_node()` à la main (`left_backer`, `breadcrumb`, `choice_next_chapiter`, `CombatEngine.cancel`) passent par lui. Bug confirmé réel : sans le rejeu, un aller-retour faisait passer l'habileté de 3 à 4. Verrouillé par `test_un_aller_retour_ne_gonfle_pas_les_stats`, vérifié comme échouant sans le correctif |
| ~~4.4~~ | ⏸️ | ~~L'état de combat n'est pas sauvegardé~~ **ÉCARTÉ (2026-08-11, décision produit)** : fermer l'app au milieu d'un affrontement le perd, et c'est assumé. La fiche de l'ennemi se réaffiche au retour sur le chapitre, le combat repart du premier tour. Conséquence à connaître : les pv déjà dépensés, eux, **restent** perdus (ils sont sauvegardés, §4.8 des ressources) — donc reprendre un combat interrompu est désavantageux. Le bouton « Annuler le combat » ne peut pas aider, sa photo disparaît avec l'app |
| ~~4.5~~ | ✅ | ~~`_check_cond_rec` sans `return false` explicite~~ **FAIT (2026-08-11)** : typée `-> bool`, `return false` explicite, et **deux `push_warning`** — sur un arbre qui n'est pas un dictionnaire, et sur une clé hors `$end`/`$or`/`$and`. Vérifié sur les données : les **620** conditions des deux livres n'emploient que ces trois opérateurs et aucun dictionnaire vide, donc un repli ne peut signaler qu'une anomalie réelle. Sans lui, un `null` implicite se lisait « condition non remplie » : une faute de frappe fermait un chemin en silence. **Toujours aucun test** (§1.3.1) |
| 4.6 | 🟡 | **cdsi perd deux compteurs.** `rancune` (18 chapitres) et `respect` (14) tombent dans le `_:` de `apply_chapter_stat` et sont jetés. `critique` est l'orthographe cdsi de `crit`, `pv_1_2_max` celle de `half_pv` — deux alias manquants. **Cause commune et correctif unique en §4ter** |
| ~~4.7~~ | ✅ | ~~`richesse`, `gloire`, `nb_infos` accumulés et jamais affichés~~ **FAIT (2026-08-11)** : `Richesse` et `Gloire` ont leur ligne dans la feuille de stats, sans ventilation (ce sont des compteurs, pas des stats en couches). **`nb_infos` reste volontairement masqué** |
| ~~4.8~~ | ✅ | ~~Combats à plusieurs ennemis tronqués~~ **FAIT (2026-08-11)** : `chapter_data.get_combats()` normalise dict et liste ; le moteur garde `_enemies` + `_enemy_index` et **enchaîne les manches** — un adversaire tombé fait surgir le suivant à pv pleins, `combat_won` n'est émis qu'au dernier. Le rapport porte `ennemi_suivant`, l'écran affiche « (2/2) » et le journal l'annonce, sinon un ennemi qui réapparaît en pleine forme ressemble à un bug |
| ~~4.9~~ | ✅ | ~~`ItemPopup` ne charge que le `.svg`~~ **FAIT (2026-08-11)** : même repli svg→png que `entities/Item.gd` |
| 4.10 | 🟡 | **4 clés de stats de chapitre ignorées** — **élucidées en §4ter.2ter** : `pv_1_4_max` et `1_4_pv_max` sont **la même règle** (pv au quart du max, famille de `half_pv`) écrite de deux façons dans le même livre ; `pv_win_plus_1` est une vraie règle au sens ambigu (les 3 autres types du ch126 ont des bonus chiffrés, le PAYSAN un booléen) ; `arc_et_couteau` est un **trou de saisie** — le nom de la condition recopié dans la case de l'effet, l'effet réel n'existe nulle part |

---

## 4bis. Export / import d'une sauvegarde (chantier neuf)

Demandé le 2026-08-11 : pouvoir sortir et réinjecter une sauvegarde sous forme d'un
fichier compressé.

### 4bis.1 Ce que ça vaut, et ce que ça ne vaut pas

Une sauvegarde complète, c'est **7 fichiers JSON par livre** (`all_times_already_visited`,
`current_node_id`, `session_visited_nodes`, `possessed_item`, `pv`, `chance`,
`save_version`) **plus `parameters.json`** — soit une quinzaine de fichiers de quelques
kilo-octets. **La compression ne sert donc à rien pour le poids** : ce qu'on gagne,
c'est **un seul fichier déplaçable** (sauvegarde de secours, changement de téléphone,
envoyer sa partie à quelqu'un). Il faut le dire, parce que ça évite de sur-concevoir :
le zip est un conteneur, pas un compresseur.

### 4bis.2 Format : zip, et pas rar

`ZIPPacker` et `ZIPReader` sont **natifs dans Godot 4.7.1** (vérifié sur le binaire du
poste) : aucune dépendance à ajouter. **Rar est à écarter** — format propriétaire, aucun
encodeur disponible dans Godot ni dans le moteur, et rien n'y gagnerait.

Contenu proposé de l'archive :

```
fdcn-save-2026-08-11.zip
├── manifest.json          <- version d'archive, date, livre courant, save_version par livre
├── parameters.json
├── fdcn/  {all_times_already_visited,current_node_id,session_visited_nodes,
│           possessed_item,pv,chance,save_version}.json
└── cdsi/  idem
```

Le **manifeste n'est pas décoratif** : c'est lui qui permet à l'import de *décrire ce
qu'il va écraser avant de l'écraser* (« partie fdcn au chapitre 212, 3 objets ») et de
refuser une archive trop récente avec un message utile plutôt qu'un plantage.

### 4bis.3 Le vrai obstacle n'est pas le zip, c'est la sortie du bac à sable

`export_presets.cfg` cible **Windows, Android et HTML5**. `user://` est
`~/.local/share/godot/app_userdata/fdcn/` sur ce poste — mais ailleurs :

| plateforme | où va le fichier | difficulté |
|---|---|---|
| **Windows / Linux** | `FileDialog` native, le joueur choisit | 🟢 direct |
| **Android** | `user://` est **privé à l'app**, invisible du gestionnaire de fichiers. `OS.get_system_dir(SYSTEM_DIR_DOWNLOADS)` existe mais le *scoped storage* (API 30+) rend l'écriture hors bac à sable capricieuse ; un partage par intent demanderait un plugin | 🔴 à valider sur appareil réel |
| **HTML5** | `user://` est de l'IndexedDB, aucun fichier au sens usuel. L'export doit **déclencher un téléchargement navigateur** via `JavaScriptBridge`, l'import passer par un `<input type=file>` | 🔴 code spécifique |

`FileDialog` et `JavaScriptBridge` existent bien dans ce Godot, donc rien n'est bloqué —
mais **c'est trois implémentations de transport pour un seul moteur d'archive**.
Recommandation : livrer le **desktop d'abord**, avec le moteur d'archive découplé du
transport, puis traiter Android et web comme deux chantiers séparés. Le moteur (empaqueter,
valider, appliquer) est identique partout ; seul « où poser le fichier » change.

### 4bis.4 L'import doit être atomique, et c'est le point critique

Un import à moitié appliqué produit une **sauvegarde Frankenstein** — les objets d'une
partie avec le chapitre d'une autre — bien pire qu'un import raté. Donc :

1. décompresser dans un dossier **temporaire** (`user://import_tmp/`) ;
2. **tout valider** : fichiers attendus présents, JSON qui parse, `save_version` connue
   et pas supérieure à `CURRENT_SAVE_VERSION`, cohérence du manifeste ;
3. **sauvegarder l'état actuel** dans `user://backup-avant-import.zip` — un import est
   destructeur, et le filet doit être automatique, pas un conseil dans une notice ;
4. seulement alors, basculer les fichiers ;
5. puis `Player.do_load()`.

**Bonne nouvelle héritée du versionnage** : une archive plus ancienne se migre
**gratuitement**. `SaveManager.prepare_save()` applique déjà la chaîne de migrations et
refuse déjà une version future avec un avertissement. L'import n'a donc rien à
réimplémenter — il pose les fichiers et laisse la machinerie existante faire son travail.

### 4bis.5 Deux dépendances et une place dans l'interface

- **Confirmation obligatoire avant d'écraser** → même pièce manquante qu'en §4.1
  (`GenericConfirmationPopup` existe, sans appelant). Les deux chantiers partagent
  la dépendance.
- **Où le mettre** : la page **À propos** (action #9), qui est déjà à construire et qui
  est la page « méta » naturelle. Une scène à faire au lieu de deux, plutôt qu'un
  cinquième onglet dans la popup d'options.

### 4bis.6 Pourquoi le faire tôt : c'est testable

Contrairement à presque tout le reste de P1, ce chantier est **entièrement couvrable par
la suite existante** : empaqueter → décompresser → valider → appliquer est de l'I/O dans
`user://`, et le lanceur redirige déjà `SaveManager.base_dir` vers un dossier jetable.
Un aller-retour complet, une archive tronquée, une archive de version future, une
archive d'un seul livre : tout ça se teste sans interface et sans appareil.

⚠️ Effet de bord accepté : une sauvegarde exportée est **modifiable à la main** (c'est du
JSON dans un zip), donc triche possible. Pour un compagnon de livre-jeu solo, ce n'est
pas un problème — mais autant que ce soit écrit noir sur blanc plutôt que découvert.

---

## 4ter. Vocabulaire de stats par livre : un mécanisme générique

Question posée le 2026-08-11 : « la gloire et la richesse sont-elles utilisées dans
cdsi ? Chaque livre a peut-être 2 variables à lui — on pourrait faire un fonctionnement
générique ? » Les données répondent oui aux deux, très nettement.

### 4ter.1 La mesure

| clé | fdcn | cdsi | |
|---|---|---|---|
| `richesse` | **15** | **13** | ✅ partagée par les deux |
| `gloire` | **19** | **0** | fdcn seulement |
| `info` | **20** | **0** | fdcn seulement |
| `rancune` | **0** | **18** | cdsi seulement |
| `respect` | **0** | **14** | cdsi seulement |

Le motif est exactement celui deviné : **un compteur commun (`richesse`) + deux
compteurs propres à chaque livre.** fdcn a `gloire` et `info`, cdsi a `rancune` et
`respect`. Aucun croisement.

⚠️ **Conséquence immédiate** : la ligne « Gloire » ajoutée à la feuille de stats
(§4.7) affichera **0 pour toujours** quand cdsi est chargé, et deux compteurs cdsi sur
trois restent invisibles. Le codage en dur est donc structurellement faux, pas seulement
incomplet.

### 4ter.2 Le piège : toutes les clés inconnues ne sont pas des compteurs

C'est le point qui décide de la forme du mécanisme. Parmi les clés que
`apply_chapter_stat()` ne connaît pas, il y a **trois natures différentes** :

| clé | occurrences | nature réelle |
|---|---|---|
| `gloire`, `info`, `rancune`, `respect` | 19 / 20 / 18 / 14 | **de vrais compteurs** propres à un livre |
| `critique` | 5 (cdsi) | **orthographe cdsi de `crit`** — une stat en couches ! |
| `pv_1_2_max` | 1 (cdsi) | **orthographe cdsi de `half_pv`** — une ressource ! |
| `arc_et_couteau`, `pv_win_plus_1` | 1 chacune (fdcn) | règles ponctuelles, non implémentées |

Un mécanisme qui traiterait « toute clé inconnue = compteur » transformerait donc
`critique` en une ligne « Critique : 5 » inutile **au lieu de donner +5 de dégâts
critiques**. La généricité ne peut pas être une simple découverte automatique.

### 4ter.2bis Les variantes sont un défaut de saisie, à attraper au compilateur

Vérifié dans les sources **écrites à la main** :

| source | contenu |
|---|---|
| `books/fdcn/fdcn.json` | `"crit"` ×5, `"half_pv"` ×1 |
| `books/cdsi/cdsi.json` | `"critique"` ×5, `"pv_1_2_max"` ×1 |

Le compilateur n'invente rien : `node.py:set_stats()` recopie le dictionnaire tel quel.
C'est donc une **incohérence de transcription entre les deux livres**, pas un problème de
moteur — et fdcn en contient une à lui tout seul (voir 4ter.2ter, `pv_1_4_max` contre
`1_4_pv_max`).

🔴 **Le compilateur avait déjà tout ce qu'il faut pour l'attraper.** `scripts/fdcn.py:374`
fait littéralement :

```python
print('Checking all stats keys: %d' % len(all_stats_keys))
for stat_key in all_stats_keys:
    print(' - %s' % stat_key)
```

Il **collecte et affiche** toutes les clés de stats du livre (via
`node.get_all_stats_keys()`) — il lui manque seulement la **liste de référence** à
laquelle les comparer. `critique` était donc listé noir sur blanc à chaque compilation de
cdsi, noyé parmi des centaines de lignes de trace.

**Correctif en deux temps** :

1. **Corriger les sources** : `critique` → `crit` (5 occurrences) et `pv_1_2_max` →
   `half_pv` (1) dans `cdsi.json` ; unifier `pv_1_4_max` / `1_4_pv_max` dans `fdcn.json`.
2. **Faire échouer le compilateur** sur une clé hors vocabulaire, au lieu de l'imprimer :
   un `set` des clés canoniques, et `sys.exit(2)` sur une inconnue — le script sort déjà
   comme ça ailleurs (`fdcn.py:107`). Une faute de frappe dans un futur livre devient
   alors impossible à rater.

Conséquence sur le mécanisme de §4ter.3 : **la liste `alias` n'a plus à exister à
demeure**. Les sources corrigées, il ne reste que `compteurs` et `ignorees`. Garder les
alias serait entretenir la faute plutôt que la réparer.

### 4ter.2ter Les « règles ponctuelles » : 3 sur 4 sont des défauts de données

Inventaire complet, avec le chapitre et le contexte :

| clé | où | verdict |
|---|---|---|
| `arc_et_couteau` | fdcn **ch284** « Lenonia », sous condition dont le texte est *« ARC et COUTEAU »* | 🔴 **trou de données, pas une règle.** L'effet déclaré est le **nom de la condition recopié dans la case de l'effet** (`{"arc_et_couteau": true}`). Ce que le livre accorde vraiment à qui possède l'arc *et* le couteau n'est **écrit nulle part** — il faut rouvrir le livre |
| `pv_win_plus_1` | fdcn **ch126** « Cathédrale », sous condition PAYSAN | 🟠 **vraie règle, formulation ambiguë.** Les trois autres types du même chapitre reçoivent des bonus chiffrés (GUERRIER `hab +1`, PRUDENT `chance_max +3`, DÉBROUILLARD `crit +3`) ; le PAYSAN reçoit un **booléen**. Deux lectures : « +1 pv » (et c'est alors juste mal saisi), ou « gagne 1 pv de plus à chaque victoire » (une règle persistante, ce qui expliquerait le booléen). **Les données ne peuvent pas trancher**, le texte du livre oui |
| `pv_1_4_max` | fdcn **ch178** « Prison » | 🟡 **même règle que la suivante, autre orthographe** |
| `1_4_pv_max` | fdcn **ch448** « Prison » | 🟡 « les pv tombent au quart du maximum » — la famille de `half_pv` (fdcn ch323, « Prison » aussi). Une ligne à écrire, exactement comme `half_pv`, **une fois les deux orthographes unifiées** |

Autrement dit : sur les 4 clés « non gérées », **une seule est une vraie règle à
implémenter** (`pv_1_4_max`, quart des pv max), **une est une vraie règle dont le sens
manque** (`pv_win_plus_1`), et **une est un trou de saisie** (`arc_et_couteau`). La
quatrième n'était qu'un doublon d'orthographe.

Le motif « Prison » est cohérent et rassurant : `half_pv` au ch323, quart des pv aux
ch178 et ch448 — c'est une pénalité d'arc narratif, pas une bizarrerie isolée.

### 4ter.2quater Notation d'effet plutôt qu'un mot-clé par règle

Décidé le 2026-08-11 : au lieu d'un mot-clé ad hoc par règle (`half_pv`, `pv_1_4_max`,
`max_pv`…), une **petite notation** sur la valeur. Elle ne sert pas qu'aux deux cas
problématiques : elle **absorbe six mots-clés existants**, soit 16 occurrences dans les
deux livres (`max_pv` ×10, `max_chance` ×2, `half_pv`, `pv_1_4_max`, `1_4_pv_max`,
`pv_1_2_max`).

```json
"stats": { "pv": 5 }            // NOMBRE  -> += 5. Comportement actuel, inchangé
"stats": { "pv": "= max" }      // CHAÎNE  -> une expression
"stats": { "pv": "= max/4" }
"stats": { "pv": "= moi/2" }    // moitié de la valeur COURANTE
"stats": { "pv": "- max/2" }
"stats": { "chance": "= max" }  // remplace `max_chance`, sans code dédié
```

Deux règles seulement :

- une **valeur numérique** garde le sens additif actuel — donc **aucune migration** des
  ~200 entrées chiffrées déjà écrites ;
- une **chaîne** commence par l'opérateur (`=`, `+`, `-`) et porte une expression sur deux
  jetons : **`max`** (le plafond de la stat : `pv_max`, `chamax`…) et **`moi`** (sa valeur
  courante), éventuellement divisés par un entier.

⚠️ **Pourquoi `moi` et `max` doivent être explicites** — et c'est une correction à ce que
j'affirmais en §4ter.2ter : `half_pv` et `pv_1_2_max` ne sont **peut-être pas la même
règle**. Le code actuel fait `pv /= 2`, soit la moitié de la valeur **courante** ; or
`pv_1_2_max` contient « max », donc probablement la moitié du **maximum**. Les unifier
sous un seul mot-clé serait une régression silencieuse. Avec la notation, la différence
s'écrit et ne peut plus se perdre :

| ancien | notation | sens |
|---|---|---|
| `half_pv` (fdcn ch323) | `"pv": "= moi/2"` | la moitié de ce qu'il reste |
| `pv_1_2_max` (cdsi ch249) | `"pv": "= max/2"` | la moitié du maximum |
| `pv_1_4_max` / `1_4_pv_max` | `"pv": "= max/4"` | le quart du maximum |
| `max_pv` | `"pv": "= max"` | au plein |
| `max_chance` | `"chance": "= max"` | au plein |

**À confirmer dans le livre avant d'unifier** : lequel des deux référents s'applique au
ch323 de fdcn et au ch249 de cdsi. C'est la seule question que les données ne tranchent
pas, et elle doit être posée *avant* l'action « unifier les orthographes », pas après.

### 4ter.2quinquies `arc_et_couteau` : la condition marche déjà, seul l'effet manque

Vérifié dans les données compilées :

```json
{ "condition": { "$and": [ {"$end": "ARC"}, {"$end": "COUTEAU"} ] },
  "stats":     { "arc_et_couteau": true },
  "txt":       "ARC et COUTEAU" }
```

Et les deux objets existent bien dans `fdcn-compilated-all-objects.json` : **ARC**
(catégorie ARME) et **COUTEAU** (OUTIL). Or `_check_cond_rec` évalue les arbres `$and`
contre `Inventory.get_all_matched_conditions()`, qui contient les noms d'objets portés.

**Donc rien n'est à faire côté condition ni côté objets** : l'app sait déjà dire si le
joueur a les deux. Le seul manque est **l'effet**, et il n'existe dans aucune donnée.
« On peut ignorer » est donc sans risque technique — à un détail près : le joueur perd
silencieusement ce que le livre lui accorde là. La clé va dans `ignorees`, ce qui éteint
l'avertissement tout en gardant la trace du trou.

### 4ter.2sexies `pv_win_plus_1` : un modificateur de gain, pas un effet ponctuel

Sens donné : **« quand on gagne 1 pv, on en gagne 2 »** — un bonus permanent sur les
gains, pas un effet immédiat. Ça en fait une catégorie à part, et le nom générique
s'impose :

```json
"stats": { "pv_gain": 1 }        // chaque gain de pv est majoré de 1
"stats": { "chance_gain": 1 }    // fonctionne pareil pour n'importe quelle ressource
```

Implémentation :

- un `_gain_bonus` par ressource dans `PlayerStats`, **dans la couche « chapitres »** —
  il vient d'un chapitre, donc il doit être remis à zéro par `reset_chapter_layer()` et
  reconstruit par le rejeu, exactement comme `pv_max_bonus` ;
- appliqué **dans `add_pv()` / `add_chance()`**, et **uniquement sur un delta positif** :
  un bonus de gain ne doit pas amortir les dégâts ;
- pas appliqué aux affectations (`"= max"`), qui posent une valeur au lieu d'en gagner.

Ce dernier point est le piège : sans la distinction gain / affectation, un « pv au
plein » deviendrait « au plein + 1 », donc au-dessus du plafond.

### 4ter.3 Forme proposée : un vocabulaire déclaré par livre

Un fichier écrit à la main par livre, `books/<nom>/<nom>.vocabulaire.json`, avec les
**trois** natures :

```json
{
  "compteurs":  [ {"cle": "richesse", "libelle": "Richesse"},
                  {"cle": "rancune",  "libelle": "Rancune"},
                  {"cle": "respect",  "libelle": "Respect"} ],
  "ignorees":   [ "arc_et_couteau" ]
}
```

Deux listes, pas trois : les **alias disparaissent** puisque les orthographes se
corrigent à la source (4ter.2bis). `ignorees` ne garde que les trous assumés — pour
l'instant `arc_et_couteau`, dont l'effet réel n'est écrit nulle part.

Ce que ça change dans le code :

1. **`PlayerStats`** perd ses trois variables codées en dur (`gloire`, `richesse`,
   `nb_infos`) au profit d'un unique dictionnaire `_compteurs`, alimenté depuis la
   déclaration du livre courant. `get_gloire()` / `get_richesse()` / `get_nb_infos()`
   deviennent `get_compteur(cle)`.
2. **`apply_chapter_stat()`** range dans `_compteurs` toute clé déclarée comme telle. Le
   `_:` final continue d'avertir : une clé qui n'est ni une stat connue, ni un compteur
   déclaré, ni dans `ignorees` reste une anomalie signalée — c'est ce qui garde le filet
   côté application, en plus du refus du compilateur côté génération.
3. **La feuille de stats génère ses lignes** depuis la liste `compteurs` du livre, au
   lieu des `PlayerRichesse` / `PlayerGloire` posés en dur. Un livre affiche ses
   compteurs, et seulement les siens.
4. **Rien à sauvegarder** : les compteurs restent dérivés des chapitres, donc
   reconstruits par le rejeu (`reset_chapter_layer()` les remet à zéro, cf. §7).

### 4ter.4 Pourquoi c'est le bon moment

- Ça **supprime trois actions** de la liste d'un coup (alias manquants, `rancune`/`respect`
  perdus, clés ignorées à trancher) au lieu de les traiter une par une.
- Ça règle par avance le piège du **troisième livre** (§2bis.4) : la commande d'audit
  des clés devient actionnable — on la lance, et on range chaque clé dans l'une des
  trois listes. Plus aucune valeur ne peut être perdue en silence.
- C'est **entièrement testable** sans interface : appliquer une stat de chapitre et lire
  un compteur, c'est de la donnée pure.
- Et ça va dans le sens déjà pris deux fois : `MIGRATION_GUESS` (action #36) et la table
  de combat sont du **contenu de livre** qui n'a rien à faire dans le code.

---

## 5. Dette et hygiène

| # | quoi |
|---|---|
| 5.1 | **`entities/LoreEntry.tscn` pèse 2,7 Mo** — des ressources embarquées à externaliser. C'est 99 % du poids des scènes du dépôt |
| 5.2 | **`project.godot` garde des clés Godot 3** : `[rendering] quality/driver/driver_name="GLES2"`, `vram_compression/import_etc`. Ignorées par Godot 4, trompeuses |
| 5.3 | **`shaders/shader_grey.tres`** est un `ShaderMaterial` vide au format Godot 3, sans shader assigné, référencé par personne. `gray.gdshader`, lui, sert |
| 5.4 | **608 objets fuités** à la fin des tests (§1.3) |
| 5.5 | **`archive/` (833 lignes + sa scène)** : sa fin de vie se décide quand §2 est terminé. Elle reste la seule source de vérité sur le son et les popups |
| 5.6 | **Duplication de décoration de ligne** : `ChapterChoice.update_from_son_node` + `update_when_in_all_chapters` + `success_item.update` refont trois fois la même logique spoil/vu/fin/succès/secret |
| 5.7 | **4 setters quasi identiques dans `Parameters.gd`** (`set_spoils`/`set_sound`/`set_billy_type`/`set_book_name`) : un helper `_set(clé, valeur)` suffirait |
| 5.8 | **La table d'objets de départ devinés** (`MIGRATION_GUESS`) est du contenu de livre codé dans `autoload/inventory.gd` : sa place est dans `books/<nom>/` |
| 5.9 | **`chapter_data.gd extends Node`** alors que c'est une donnée pure : `RefCounted` conviendrait, et les instances ne sont pas libérées au changement de livre |

---

## 5bis. Il n'y a aucun thème : 563 surcharges posées à la main

Constat parti d'une observation à l'usage — « la popup ne suit pas le style de l'app ».
La cause est plus large que la popup.

### 5bis.1 Le diagnostic

`project.godot` n'a **aucune section `[gui]`**, donc aucun `gui/theme/custom` : tous les
`Control` de l'app tournent sur le **thème par défaut de Godot**. Le look de l'app ne
vient pas d'un thème mais de **563 `theme_override_*` posés nœud par nœud**, dans
**31 scènes** :

| catégorie | nombre |
|---|---|
| `theme_override_constants/*` | 223 |
| `theme_override_fonts/*` | 135 |
| `theme_override_colors/*` | 122 |
| `theme_override_styles/*` | 76 |
| `theme_override_font_sizes/*` | 7 |

Les plus chargées : `popups/sub/Stats.tscn` (155), `Combat.tscn` (119),
`AboutMenu.tscn` (70), `Position.tscn` (50), `top_menu.tscn` (31).

**D'où le symptôme** : `GenericConfirmationPopup` est à peu près le seul widget *sans*
surcharges. Ce n'est donc pas elle qui est mal habillée — c'est elle qui montre à quoi
ressemble l'app **sans** habillage, parce que tout le reste est peint localement.

Et `themes/` contient exactement **un** fichier,
`side_buttons_background_style.tres`, **référencé par personne** — un `StyleBoxFlat` dont
la couleur (`#313b47`) est par ailleurs recopiée 14 fois en dur ailleurs.

### 5bis.2 Ce que la répétition dit du thème à écrire

Les valeurs qui reviennent sont peu nombreuses et parlantes — c'est exactement la liste
des entrées d'un thème :

| valeur | occurrences | rôle évident |
|---|---|---|
| `Color(0,0,0,1)` | 85 | couleur de texte par défaut |
| `theme_override_fonts/font` | **135** (84 en `ExtResource`, 49 en `SubResource`) | les deux polices `amon_font` / `amon_font_small` |
| `shadow_offset_x/y = 0` + `shadow_outline_size = 0` | **55 fois chacun** | *le même trio recopié sur 55 `Label`*, juste pour éteindre l'ombre du thème par défaut |
| `#00c2aa` (teal) | 27 | couleur d'accent |
| `#313b47` (bleu nuit) | 14 | fond des en-têtes |
| `#e9eaec` (gris clair) | 14 | fond neutre / état inactif |

Le trio d'ombre est le plus révélateur : **55 nœuds ne font que désactiver un défaut de
Godot**. Un thème le règle une fois. Et les 49 `SubResource` de police sont des
enveloppes `FontFile` reconstruites scène par scène autour du même `.ttf` —
`Stats.tscn` en déclare deux à lui seul.

### 5bis.3 Comment le faire sans big-bang

1. **`themes/fdcn.tres`** : polices par défaut, couleur de texte, les 3 constantes
   d'ombre, et les `StyleBox` des types utilisés (`Panel`, `Button`, `Label`,
   `ProgressBar`, `CheckButton`). Déclaré une fois dans `project.godot`
   (`gui/theme/custom`), il s'applique à tout l'arbre sans toucher une scène.
2. **Vérifier ce qui change tout seul** : les 55 trios d'ombre et les 84 `fonts/font`
   deviennent redondants — mais tant qu'ils sont là, ils **gagnent** sur le thème. Rien
   ne casse, rien ne change : c'est ce qui rend la migration sûre.
3. **Supprimer les surcharges scène par scène**, en commençant par la popup de
   confirmation (elle n'en a presque pas : elle sera correcte *immédiatement*).
4. Les couleurs récurrentes deviennent des entrées de thème ; les couleurs vraiment
   locales (le rouge/jaune des jauges, le vert/rouge des issues de combat) restent en
   code, où elles sont déjà des constantes nommées.

⚠️ **Ordre par rapport au chantier flex (§3)** : faire le **thème d'abord**. Les scènes à
repasser en conteneurs (`top_menu` : 31 surcharges, `AboutMenu` : 70,
`ChapterChoice` : 24) traînent chacune leur habillage ; avec le thème en place, la
réécriture **supprime** ces lignes au lieu de les recopier. L'inverse ferait faire le
travail deux fois.

⚠️ Piège Godot 3 : `GenericConfirmationPopup.tscn` est encore en `format=2` et utilise
`theme_override_fonts/normal_font` — un nom de propriété qui n'existe plus sous ce nom en
Godot 4 pour un `RichTextLabel`. La convertir fait partie du même passage.

---

## 5ter. Le compilateur Python (`scripts/`, 959 lignes)

Petite review demandée le 2026-08-11. 5 fichiers : `fdcn.py` (405 l.), `node.py` (379),
`condition_node.py` (144), `graph.py` (27), `endings.py` (4).

### 5ter.1 🔴 Le traitement des fins est du code mort — et recompiler perdrait les fins

Le bug le plus grave du dépôt à ce jour, et il est silencieux. `fdcn.py:96-124` :

```python
goto = n.get('goto', [])
if isinstance(goto, int):
    goto = [goto]                        # (1) goto devient TOUJOURS une liste
goto = node.get_all_possibles_goto(goto) # (2) et cette fonction renvoie list(...)

if isinstance(goto, int):                # (3) donc ceci ne peut JAMAIS être vrai
    if goto == 608 and book_number == 1:
        ...
        node.set_ending(_ending)         # (4) seul appel de set_ending du projet
```

`get_all_possibles_goto()` se termine par `goto = list(goto); return goto`. La condition
en (3) est donc **toujours fausse**, et tout le bloc des fins est **inatteignable** — y
compris ses deux `sys.exit(2)` de validation, et l'unique `set_ending()` du dépôt.

**L'historique git le confirme** :

| | commit | date |
|---|---|---|
| introduction de `goto = [goto]` | `2c02496` | **2026-08-10** |
| dernière génération des json compilés | `f31b957` | **2026-08-09** |

Les données compilées actuelles ont donc été produites **la veille** de la régression :
elles contiennent bien 19 fins pour fdcn (`computed.ending = true`), mais elles ne sont
plus reproductibles. **Recompiler un livre aujourd'hui viderait `endings`,
`good-endings`, `bad-endings` et mettrait `computed.ending` à faux partout**, sans un
seul message d'erreur — les validations étant elles aussi dans le bloc mort.

Correctif : la branche doit tester la **liste** (`len(goto) == 1 and goto[0] == 608`), ou
mieux, ne pas mêler « ce nœud est une fin » à « où va-t-il ». Le marqueur de fin est déjà
dans la source (`ending`), il n'a aucune raison de dépendre du `goto`.

⚠️ Et `goto == 608 and book_number == 1` est un **cas particulier codé en dur** : le
chapitre 608 de fdcn. Un troisième livre devra le contourner (§2bis.3).

### 5ter.2 Ce qui rend le code difficile à lire

| | constat |
|---|---|
| **Script à plat** | `fdcn.py` n'a **aucune fonction** hors `load_json_file` : 405 lignes qui s'exécutent de haut en bas, avec **40 variables globales** mutées au fil du fichier. Impossible de tester un morceau, impossible d'en lire un sans avoir lu tout ce qui précède |
| **66 `print()`** | 42 dans `fdcn.py`, 15 dans `node.py`, 9 dans `condition_node.py`. Aucun niveau de log : la validation utile (« Checking all stats keys », les avertissements de secrets) est noyée dans la trace de chaque nœud. C'est **exactement pour ça que `critique` est passé inaperçu** (§4ter.2bis) |
| **Code commenté laissé en place** | `# goto = n['goto']` juste sous la ligne qui le remplace, `# print(...)` en série, un `set_label` qui garde en commentaire l'ancienne mise en forme HTML. On ne sait plus ce qui est intentionnel |
| **Copié-collé du bloc de lecture** | 10 fois le même motif `x = n.get('x', défaut)` / `if x: node.set_x(x)`, avec des défauts incohérents : `{}` pour `stats_cond` alors que `node.py` l'initialise à `None`, `""` pour `conditions`, `None` pour `label` |
| **Deux commentaires « Get the combat entry if any »** | à la suite, dont un sur le bloc `secret` (`:60` et `:65`) — un copié-collé jamais relu |
| **Mélange des responsabilités** | `node.py` fait à la fois le modèle de données, la sérialisation (`get_computed`), **et la présentation graphviz** (`get_label()` renvoie du HTML coloré). Un changement d'affichage du graphe touche le modèle |
| **Annotations de type en commentaire** | `# type: (list) -> list` — style Python 2. Le projet tourne en Python 3 (f-strings partout), les annotations natives seraient vérifiables |
| **`get_all_stats_keys()` imprime** | une fonction nommée « get » qui écrit sur la sortie standard à chaque appel |

### 5ter.3 Ce qui est sain, et qu'il ne faut pas casser en refactorant

- La **séparation `Graph` / `Node` / `ConditionNode`** est correcte : le parseur de
  conditions est isolé et produit deux sorties (l'arbre pour le moteur, le texte pour
  l'affichage), ce qui est exactement ce dont l'app a besoin.
- Les **validations existent** : secrets accessibles par deux chemins, fin sans type,
  objets sans chapitre. Elles sont juste invisibles faute de niveaux de log.
- La **sortie est déterministe** (`son_ids.sort()`, `sort_keys=True` au dump), donc les
  json compilés ne bougent pas sans raison — précieux pour lire un diff.

### 5ter.4 Ordre de travail suggéré

1. 🔴 **Réparer la branche des fins** (5ter.1) — et **ne pas recompiler avant** : les
   données actuelles sont correctes, une recompilation les casserait.
2. **Ajouter la validation du vocabulaire de stats** avec sortie en erreur (§4ter.2bis) :
   c'est le garde-fou qui aurait attrapé `critique`, et il se pose au même endroit.
3. **Des niveaux de log** (`--verbose`) pour que les 66 traces cessent de noyer les
   avertissements.
4. **Découper `fdcn.py` en fonctions** — au minimum `lire_les_noeuds()`,
   `taguer_les_arcs()`, `construire_le_graphe()`, `ecrire_les_json()`. Le graphviz est le
   candidat évident à l'extraction : c'est la moitié du fichier et l'app ne s'en sert pas.
5. **Sortir la présentation graphviz de `node.py`** (`get_label()`).

---

## 6. Liste d'actions ordonnée

### P0 — perte de données et angles morts critiques

| # | tag | action | réf |
|---|---|---|---|
| ~~1~~ | `[bug]` | ~~Confirmation avant `launch_new_billy()`~~ ✅ **FAIT** | 4.1 |
| 2 | `[test]` | Tester `BookData`, en commençant par `_check_cond_rec` (`$or`/`$and`/`$end`, imbrication, condition absente) | 1.3.1 / 4.5 |
| ~~3~~ | `[bug]` | ~~`rebuild_chapter_stats()` après tout retour en arrière~~ ✅ **FAIT** : `Player.go_back_to()` | 4.3 |
| ~~4~~ | `[bug]` | ~~Sauvegarder l'état de combat (`KEY_COMBAT`)~~ ⏸️ **ÉCARTÉ** — décision produit | 4.4 |
| 5 | `[bug]` | 🔴 **Réparer la branche des fins de `scripts/fdcn.py`** (code mort depuis le 2026-08-10) — **et ne pas recompiler un livre avant** : les json actuels sont bons, une recompilation viderait les 19 fins de fdcn sans un message d'erreur | 5ter.1 |

### P1 — parité avec l'archive

| # | tag | action | réf |
|---|---|---|---|
| 6 | `[feature]` | **Son** : intro de livre, narration de chapitre, son de changement de Billy | 2.1 A |
| 7 | `[feature]` | **`ItemPopup`** sur objet gagné/perdu — la donnée remonte déjà de `go_to_node()` | 2.1 B |
| 8 | `[feature]` | **`SuccessPopup`** sur nouveau succès + jingle | 2.1 C |
| 9 | `[feature]` | **Page Lore** : script + reconstruction de la scène en conteneurs | 2.1 D / §3 |
| 10 | `[feature]` | **Page À propos** : ✅ script + 3 boutons branchés ; **restent** les liens auteur/wiki et la reconstruction en conteneurs | 2.1 E / §3 |
| 11 | `[feature]` | Menu du haut : `set_page()`, dé-masquer `$Pages`/`$Billys` — **avec** le passage en conteneurs | 2.1 G / 3.1 |
| ~~12~~ | `[feature]` | ~~Griser le livre non sélectionné~~ ✅ **FAIT** | 2.1 H |
| 13 | `[feature]` | **Export d'une sauvegarde en zip** : moteur d'archive (`ZIPPacker`, manifeste) découplé du transport | 4bis.2 |
| 14 | `[feature]` | **Import atomique** : dossier temporaire, validation complète, sauvegarde de secours automatique, puis bascule | 4bis.4 |
| 15 | `[feature]` | Transport par plateforme : `FileDialog` desktop d'abord, Android et HTML5 en chantiers séparés | 4bis.3 |

### P2 — correction des données de livre

| # | tag | action | réf |
|---|---|---|---|
| 16 | `[bug]` | **Corriger les orthographes à la source** : `critique`→`crit` (×5) et `pv_1_2_max`→`half_pv` dans `cdsi.json` ; unifier `pv_1_4_max`/`1_4_pv_max` dans `fdcn.json` | 4ter.2bis |
| 17 | `[bug]` | **Faire échouer `scripts/fdcn.py` sur une clé de stat hors vocabulaire.** Il les collecte et les imprime déjà (`:374`) — il manque la liste de référence et un `sys.exit(2)` | 4ter.2bis |
| 18 | `[refacto]` | **Vocabulaire de stats déclaré par livre** (`books/<nom>/<nom>.vocabulaire.json` : alias + compteurs + ignorées). **Remplace les actions 16 et 18** et prépare le 3ᵉ livre | 4ter.3 |
| 19 | `[feature]` | ~~Implémenter `rancune`/`respect`, aliaser `critique`/`pv_1_2_max`~~ → **absorbé par #15** | 4ter |
| ~~20~~ | `[feature]` | ~~Afficher `richesse` / `gloire`~~ ✅ **FAIT** — ⚠️ mais en dur : « Gloire » affichera 0 pour toujours sur cdsi jusqu'à #15 | 4.7 / 4ter.1 |
| 21 | `[logic]` | ~~Trancher les 4 clés de stats ignorées~~ → **absorbé par #15** (elles deviennent la liste `ignorees` du vocabulaire) | 4ter |
| ~~22~~ | `[bug]` | ~~Combats à plusieurs ennemis (fdcn ch276)~~ ✅ **FAIT** : manches enchaînées | 4.8 |
| ~~23~~ | `[bug]` | ~~Photo d'annulation prise par `go_to_node()`~~ ✅ **FAIT** : `Player.arrival_snapshot` | 4.2 |

### P3 — flex

| # | tag | action | réf |
|---|---|---|---|
| 24 | `[style]` | **Créer `themes/fdcn.tres` et le déclarer dans `project.godot`** — à faire **avant** le reste de P3 : la réécriture des scènes supprimera alors les surcharges au lieu de les recopier | 5bis.3 |
| 25 | `[style]` | Purger les 563 `theme_override_*` scène par scène, en commençant par `GenericConfirmationPopup` (et sa conversion depuis le format Godot 3) | 5bis.1 |
| ~~26~~ | `[style]` | ~~`ui/top_menu.tscn` → conteneurs~~ ✅ **FAIT** (+ 2 styleboxes partagées séparées) | 3.1 |
| 27 | `[style]` | `entities/ChapterChoice.tscn` → conteneurs (×15 dans la liste virtualisée) | §3 |
| 28 | `[style]` | `EndingChoice`, `left_backer`, `right_nexter` → conteneurs | §3 |
| 29 | `[style]` | Popups → conteneurs : `GenericConfirmationPopup` ✅ **FAIT** ; restent `ItemPopup` et `SuccessPopup` (ses animations ciblent des chemins et des `scale`), à faire avec #6/#7 | §3 / 3.1bis |
| 30 | `[style]` | `ui/gauge` : passer en `Control`, rayon déduit de `size`, supprimer `GaugeSizer` | §3 |
| 31 | `[style]` | Trancher la politique des widgets à polygones | 3.2 |
| 32 | `[style]` | Insets de `MenuPage` (nav 50 px, haut 48 px) → constantes de thème | §3 |

### P4 — tests et hygiène

| # | tag | action | réf |
|---|---|---|---|
| 33 | `[test]` | Rendre `test_case.gd` capable d'`await`, pour ouvrir les tests d'interface et de mise en page | 1.3.3-4 |
| 34 | `[test]` | Libérer les nœuds instanciés par les tests (608 fuites) | 1.3.5 |
| 35 | `[test]` | Tests de `menu_page.gd` (blocage de navigation quand une popup est ouverte) et `top_menu.gd` | 1.3.2 |
| 36 | `[hygiene]` | `entities/LoreEntry.tscn` : externaliser les 2,7 Mo | 5.1 |
| 37 | `[hygiene]` | Purger les clés `[rendering]` Godot 3 de `project.godot` | 5.2 |
| 38 | `[hygiene]` | Supprimer `shaders/shader_grey.tres` | 5.3 |
| 39 | `[refacto]` | Unifier les 3 variantes de décoration de ligne | 5.6 |
| 40 | `[refacto]` | Helper `_set()` pour les setters de `Parameters` | 5.7 |
| 41 | `[place]` | `MIGRATION_GUESS` → `books/<nom>/` | 5.8 |
| 42 | `[refacto]` | `chapter_data.gd` → `RefCounted`, libération au changement de livre | 5.9 |
| 43 | `[place]` | Décider la fin de vie d'`archive/` une fois P1 terminé | 5.5 |

---

## 7. Historique — ce qui a été réglé pendant le refacto

Gardé court, pour ne pas re-litiger des décisions déjà prises. Le détail du combat est
dans `combat.md`.

**Boot et sauvegardes** · chargement de la sauvegarde au démarrage et au changement de
livre · versionnage + migration v1→v2 (fichiers suffixés par nom de livre et non par
numéro) · `BookData.do_load_book` remet `all_nodes` à zéro · le toggle son ne recharge
plus le livre.

**Responsivité** · `window/stretch/mode` `"2d"` (valeur Godot 3, silencieusement
ignorée) → `canvas_items` + `aspect=expand`, ce qui a débloqué toute la mise à
l'échelle · `nav_buton` étiré à l'exécution · padding centralisé dans `MenuPage` ·
largeur minimale de `Item` (450 px) supprimée, qui provoquait une barre de défilement
horizontale.

**Architecture** · `Swiper` supprimé, remplacé par `MenuPage` · le pont god-object
`Player._main` / `register_main` remplacé par des signaux (`items_changed`,
`billy_changed`, `stats_changed`) · `settings_loaded`, déclaré mais jamais émis,
supprimé au profit d'un unique `settings_changed` · `player.gd` découpé (852 → 246
lignes) en `PlayerStats` / `Inventory` / `Player`.

**Correction de données** · identifiants de chapitre : les floats du json comparés à
des listes d'entiers cassaient tous les marqueurs « déjà vu » · `reset_chapter_layer()`
laissait `gloire`/`richesse`/`nb_infos`/`pv_max_bonus`, donc chaque changement de livre
les doublait · `full_reset()` incomplet · double application des stats de chapitre ·
boucle infinie de `clean_billy_overload()` · RNG jamais semé (`randomize()`).

**Écrans faits** · Chapitres et Succès, avec listes virtualisées (606 chapitres → 15
lignes recyclées, 331 nœuds) · feuille de stats avec ventilation base/objets/chapitres ·
ressources pv/chance bornées, sauvegardées et hors du rejeu · **combat complet**
(moteur testé + écran).
