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

**Les trois chiffres qui résument la dette** :

| | valeur |
|---|---|
| code vivant | **6 159 lignes** de GDScript (hors `archive/`) |
| suite de tests | **66 tests, 396 assertions, tout vert** |
| scripts sans aucun test | **26 sur 38** — et ce sont tous des scripts d'interface |

Le déséquilibre de la troisième ligne est le fait marquant de cette review : la
**couche de données est solidement testée, l'interface ne l'est pas du tout**.

---

## 1. Tests : ce que la suite couvre, et ses angles morts

### 1.1 Résultat du dernier passage

```
66 tests — 396 assertions — TOUT PASSE
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
| **E** | 🔴 **Page À propos** | `_on_button_bug`, `_on_button_pressed_twitter`, `_on_image_author_button_pressed`, `_on_morelore_button_pressed`, `_on_button_new_billy` | `screens/AboutMenu.tscn` **n'a aucun script**. Elle référence `GenericConfirmationPopup` mais rien ne la déclenche |
| **F** | 🟠 **Confirmation « nouveau Billy »** | `_on_GenericTextPopup_generic_popup_accept` | `popups/GenericConfirmationPopup.gd` (26 l.) existe, aucun appelant. Or `choice_next_chapiter.launch_new_billy()` **efface la partie sans demander confirmation** |
| **G** | 🟠 **Icônes de page et de Billy du menu du haut** | `_register_top_menus`, `update_page_in_top_menus` | `$Pages` et `$Billys` sont `visible = false` dans `ui/top_menu.tscn`, et `set_page()` n'est appelée par personne. `set_billy()`, elle, est branchée |
| **H** | 🟡 **Grisage du livre non sélectionné** | `_refresh_options_book_select_display` | `popups/sub/book_selection.gd` fait 13 lignes : il sélectionne, il ne grise pas. Le shader `gray.gdshader` est pourtant là et sert déjà aux portraits de Billy |

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

## 3. Composants non flex

Mesure : nœuds `layout_mode = 0` (positionnés à la main) et lignes `offset_*` brutes,
contre le nombre de conteneurs. Beaucoup d'offsets + peu de conteneurs = mise en page
en pixels fixes, qui ne suivra aucune taille d'écran.

| scène | nœuds | `lm=0` | `offset_*` | conteneurs | priorité |
|---|---|---|---|---|---|
| **`ui/top_menu.tscn`** | 45 | **19** | **73** | 4 | 🔴 **le pire, et sur toutes les pages** |
| `screens/AboutMenu.tscn` | 32 | 14 | 69 | **0** | 🟡 coquille à refaire de toute façon (§2.1 E) |
| **`entities/ChapterChoice.tscn`** | 21 | 8 | 52 | **0** | 🔴 instanciée ~15× dans la liste virtualisée |
| `screens/LoreMenu.tscn` | 26 | 7 | 23 | 2 | 🟡 coquille à refaire (§2.1 D) |
| `ui/right_nexter.tscn` | 5 | 2 | 12 | 0 | 🟠 |
| `entities/EndingChoice.tscn` | 13 | 0 | 36 | **0** | 🟠 |
| `ui/bread.tscn` | 7 | 0 | 17 | **0** | 🟡 polygones dessinés à la main, cas à part (§3.2) |
| `popups/GenericConfirmationPopup.tscn` | 4 | 0 | 16 | **0** | 🟠 |
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

### 3.1 Pourquoi `top_menu.tscn` est la priorité

19 nœuds à position fixe et 73 offsets, dans une scène **instanciée sur chacune des
5 pages**. C'est aussi elle qui contient les blocs `$Pages` et `$Billys` masqués
(§2.1 G) : les rendre visibles sans les passer en conteneurs les placera de travers
sur tout écran qui n'est pas exactement 540 de large. Les deux chantiers sont donc à
faire ensemble.

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
| 4.1 | 🔴 | **`launch_new_billy()` efface la partie sans confirmation** (`choice_next_chapiter.gd:60`). Un clic détruit l'historique, l'inventaire et les stats. C'est §2.1 F, mais c'est d'abord un risque de perte de données |
| 4.2 | 🟠 | **La photo d'annulation de combat est prise trop tard.** `CombatEngine.start()` s'exécute sur `chapter_changed`, donc **après** que le chapitre a appliqué ses effets. Les 6 chapitres de combat qui donnent aussi des pv/chance (fdcn 54/58/133, cdsi 40/68/73) gardent ce gain quand on annule. Vrai correctif : une photo prise par `Player.go_to_node()` avant d'appliquer, ce qui offrirait un « annuler l'arrivée » pour n'importe quel chapitre |
| 4.3 | 🟠 | **Retour en arrière = stats de chapitre réappliquées.** `jump_back()` dépile le chapitre de retour, si bien que le `go_to_node()` suivant le croit neuf et rejoue ses stats. `Player.rebuild_chapter_stats()` corrige le cas depuis l'annulation de combat, mais `ui/left_backer.gd` et `screens/aventure_menu/breadcrumb.gd` ne l'appellent pas |
| 4.4 | 🟠 | **L'état de combat n'est pas sauvegardé.** Fermer l'app au milieu d'un affrontement le perd (pv de l'ennemi, tour). `combat.md` étape 7 |
| 4.5 | 🟠 | **`_check_cond_rec` sans `return false` explicite** en sortie de boucle (`BookData.gd:201`) — et sans test (§1.3) |
| 4.6 | 🟡 | **cdsi perd deux compteurs.** `rancune` (18 chapitres) et `respect` (14) tombent dans le `_:` de `apply_chapter_stat` et sont jetés. `critique` est l'orthographe cdsi de `crit`, `pv_1_2_max` celle de `half_pv` — deux alias manquants |
| 4.7 | 🟡 | **`richesse`, `gloire`, `nb_infos` sont accumulés et jamais affichés.** Aucune vue ne les lit |
| 4.8 | 🟡 | **Combats à plusieurs ennemis tronqués.** `chapter_data._get_combat()` fait `return combat[0]` : dans fdcn ch276, la `TROLESSE` (hab 13, pv 16) qui suit les gardes n'existe pas pour l'app. 1 cas sur 85 |
| 4.9 | 🟡 | **`ItemPopup` ne charge que le `.svg`**, alors que `entities/Item.gd` fait un repli svg→png. Les objets en PNG s'afficheront vides — dès que la popup sera branchée (§2.1 B) |
| 4.10 | 🟡 | **4 clés de stats de chapitre ignorées** : `1_4_pv_max`, `arc_et_couteau`, `pv_1_4_max`, `pv_win_plus_1`. Elles impriment un avertissement, à implémenter ou à retirer formellement |

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

## 6. Liste d'actions ordonnée

### P0 — perte de données et angles morts critiques

| # | tag | action | réf |
|---|---|---|---|
| 1 | `[bug]` | Confirmation avant `launch_new_billy()` via `GenericConfirmationPopup` | 4.1 / 2.1 F |
| 2 | `[test]` | Tester `BookData`, en commençant par `_check_cond_rec` (`$or`/`$and`/`$end`, imbrication, condition absente) | 1.3.1 / 4.5 |
| 3 | `[bug]` | `rebuild_chapter_stats()` après tout retour en arrière (`left_backer`, `breadcrumb`) | 4.3 |
| 4 | `[bug]` | Sauvegarder l'état de combat (`KEY_COMBAT`) | 4.4 |

### P1 — parité avec l'archive

| # | tag | action | réf |
|---|---|---|---|
| 5 | `[feature]` | **Son** : intro de livre, narration de chapitre, son de changement de Billy | 2.1 A |
| 6 | `[feature]` | **`ItemPopup`** sur objet gagné/perdu — la donnée remonte déjà de `go_to_node()` | 2.1 B |
| 7 | `[feature]` | **`SuccessPopup`** sur nouveau succès + jingle | 2.1 C |
| 8 | `[feature]` | **Page Lore** : script + reconstruction de la scène en conteneurs | 2.1 D / §3 |
| 9 | `[feature]` | **Page À propos** : script + reconstruction en conteneurs | 2.1 E / §3 |
| 10 | `[feature]` | Menu du haut : `set_page()`, dé-masquer `$Pages`/`$Billys` — **avec** le passage en conteneurs | 2.1 G / 3.1 |
| 11 | `[feature]` | Griser le livre non sélectionné dans la sélection de livre | 2.1 H |

### P2 — correction des données de livre

| # | tag | action | réf |
|---|---|---|---|
| 12 | `[bug]` | Alias `critique`→`crit` et `pv_1_2_max`→`half_pv` | 4.6 |
| 13 | `[feature]` | Implémenter `rancune` / `respect` (cdsi) — décider s'ils sont deux compteurs ou un axe signé, et par livre ou partagés | 4.6 |
| 14 | `[feature]` | Afficher `richesse` / `gloire` / `nb_infos` quelque part | 4.7 |
| 15 | `[logic]` | Trancher les 4 clés de stats ignorées | 4.10 |
| 16 | `[bug]` | Combats à plusieurs ennemis (fdcn ch276) | 4.8 |
| 17 | `[bug]` | Photo d'annulation prise par `go_to_node()` avant application des effets | 4.2 |

### P3 — flex

| # | tag | action | réf |
|---|---|---|---|
| 18 | `[style]` | **`ui/top_menu.tscn` → conteneurs** (le plus rentable : sur les 5 pages) | 3.1 |
| 19 | `[style]` | `entities/ChapterChoice.tscn` → conteneurs (×15 dans la liste virtualisée) | §3 |
| 20 | `[style]` | `EndingChoice`, `left_backer`, `right_nexter` → conteneurs | §3 |
| 21 | `[style]` | Les 3 popups (`ItemPopup`, `SuccessPopup`, `GenericConfirmationPopup`) → conteneurs | §3 |
| 22 | `[style]` | `ui/gauge` : passer en `Control`, rayon déduit de `size`, supprimer `GaugeSizer` | §3 |
| 23 | `[style]` | Trancher la politique des widgets à polygones | 3.2 |
| 24 | `[style]` | Insets de `MenuPage` (nav 50 px, haut 48 px) → constantes de thème | §3 |

### P4 — tests et hygiène

| # | tag | action | réf |
|---|---|---|---|
| 25 | `[test]` | Rendre `test_case.gd` capable d'`await`, pour ouvrir les tests d'interface et de mise en page | 1.3.3-4 |
| 26 | `[test]` | Libérer les nœuds instanciés par les tests (608 fuites) | 1.3.5 |
| 27 | `[test]` | Tests de `menu_page.gd` (blocage de navigation quand une popup est ouverte) et `top_menu.gd` | 1.3.2 |
| 28 | `[hygiene]` | `entities/LoreEntry.tscn` : externaliser les 2,7 Mo | 5.1 |
| 29 | `[hygiene]` | Purger les clés `[rendering]` Godot 3 de `project.godot` | 5.2 |
| 30 | `[hygiene]` | Supprimer `shaders/shader_grey.tres` | 5.3 |
| 31 | `[refacto]` | Unifier les 3 variantes de décoration de ligne | 5.6 |
| 32 | `[refacto]` | Helper `_set()` pour les setters de `Parameters` | 5.7 |
| 33 | `[place]` | `MIGRATION_GUESS` → `books/<nom>/` | 5.8 |
| 34 | `[refacto]` | `chapter_data.gd` → `RefCounted`, libération au changement de livre | 5.9 |
| 35 | `[place]` | Décider la fin de vie d'`archive/` une fois P1 terminé | 5.5 |

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
