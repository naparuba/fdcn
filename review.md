# Project review — fdcn (companion app for "La Forteresse du Chaudron Noir")

Reviewed 2026-08-10, branch `LINKLINSSE/refacto_V4`.
This file is the map + the audit. `todo.md` holds the day-to-day task list.
**§7 is the ordered master action list** — start there.

---

## 1. What this project is

Two independent halves:

1. **Python data pipeline** (`scripts/`: `fdcn.py`, `node.py`, `condition_node.py`,
   `graph.py`, `endings.py`, `requirements.txt`) — reads the hand-authored gamebook
   graph (`books/fdcn/fdcn.json`, `books/cdsi/cdsi.json`) and compiles it into the
   flattened JSON the app consumes (`books/<name>/<name>-compilated-*.json`) plus a
   Graphviz render (`graph/fdcn_full-{book}.png`).
   Run from repo root: `python scripts/fdcn.py --book 1|2` (paths are CWD-relative).

2. **Godot 4.7 app** (everything else) — mobile/web/desktop reader-progress tracker:
   current chapter, unlocked chapters/success/lore, inventory, derived RPG stats
   ("Billy" build). This is what the branch is rebuilding.

### Current entry point (changed — important)

`project.godot` → `run/main_scene = uid://dh580xaobsllt` → **`main.tscn` (root)** →
instances `ui/MenuPage.tscn`. The old `archive/main.tscn` is **no longer booted**.

That single change is what makes §2 urgent: everything the old `main.gd` did on
startup now simply never happens.

### Autoloads (`project.godot` `[autoload]`)

| Name | Script | Role |
|---|---|---|
| `Sounder` | `autoload/Sounder.tscn`+`.gd` | sound player + cache |
| `Utils` | `autoload/utils.gd` | json/texture load, dice, delete_children |
| `BookData` | `autoload/BookData.gd` | loads compiled book JSON, chapter lookups, condition evaluator |
| `AppParameters` | `autoload/Parameters.gd` | user settings (billy/spoils/sound/current_book) + `book_changed` |
| `SaveManager` | `autoload/save_manager.gd` | per-book `user://` JSON I/O, save versioning + migrations |
| `PlayerStats` | `autoload/player_stats.gd` | the 3-layer stat engine (`get_stat(name, layer)`) |
| `Inventory` | `autoload/inventory.gd` | carried items + derived Billy type (data only, no UI) |
| `Player` | `autoload/player.gd` | current chapter, visit history, navigation, `chapter_changed` |

> Découpage fait le 2026-08-10 (§4.1) : `player.gd` est passé de 852 à ~220 lignes.
> Les commentaires des autoloads sont en français.

---

## 2. BLOCKING — the new app cannot work yet

These are not polish items. With `main.tscn` as entry point, the app boots into a
shell with no data and several guaranteed crash paths.

### 2.1 Player save data is never loaded ✅ FAIT (2026-08-10)

`Player._ready()` appelle maintenant `do_load()` au démarrage, et se réabonne à
`AppParameters.book_changed` pour recharger la sauvegarde quand le joueur change
de livre. L'ordre des autoloads garantit que `BookData` a déjà chargé le livre
quand `Player._ready()` tourne (AppParameters est déclaré avant Player).

**Identité du livre** : un livre est identifié **uniquement par son nom**
(`'fdcn'` / `'cdsi'`), le même que le dossier `books/<nom>/`. Les fichiers de
sauvegarde s'appellent donc `<clé>-<nom>.json`. La table numéro→nom ne subsiste
qu'à un seul endroit, `SaveManager._LEGACY_BOOK_NUMBERS`, utilisée *seulement*
par la migration v1→v2. (`archive/main.gd` garde un
`_LEGACY_ASSET_BOOK_NUMBERS`, sans rapport : il sert aux dossiers d'assets
numérotés `images/dieux/<n>/`.)

**Versionnage des sauvegardes** (`autoload/save_manager.gd`) :
- Les migrations sont un **tableau ordonné** : `_migrations[i]` fait passer de la
  version `i+1` à `i+2`. `CURRENT_SAVE_VERSION` en est **déduite**
  (`_migrations.size() + 1`), il est donc impossible d'ajouter une migration en
  oubliant de monter la version, ou l'inverse. Ajouter un palier = ajouter une
  fonction au tableau, rien d'autre.
- `prepare_save()` est appelé en tête de `do_load()` :
  - aucune sauvegarde, même ancienne → création d'une sauvegarde vierge à jour ;
  - sauvegarde sans fichier de version → considérée **v1** puis migrée ;
  - sauvegarde plus récente que le code → laissée intacte + `push_warning`.
- `_migrate_1_to_2()` est une **vraie** migration : elle renomme les fichiers
  suffixés par le numéro du livre (`possessed_item-1.json`) vers le suffixe par
  nom (`possessed_item-fdcn.json`), pour les deux livres d'un coup, et supprime
  l'ancien fichier de version numéroté. Idempotente.
- `SaveManager.base_dir` existe pour que les tests écrivent dans un dossier
  jetable et ne puissent jamais toucher la sauvegarde du joueur.
- À part : `parameters.json` (global, pas par livre) stockait `current_book` en
  numérique ; `AppParameters._migrate_legacy_book_number()` le convertit et
  **persiste** désormais la conversion au lieu de la refaire à chaque lancement.

**Tests** : voir §6bis. `test/unit/test_save_migration.gd` couvre 10 scénarios
(création à vide, renommage v1→v2, préservation du contenu, les deux livres, pas
de re-migration, idempotence, conflit ancien/nouveau fichier, version future, et
« une vieille sauvegarde ne doit pas passer pour une absence de sauvegarde »).

Corrigé au passage, parce que le chemin « changement de livre » en dépend :
- **#13** `_apply_parameters()` est scindé en `_apply_sound()` / `_apply_book()` :
  couper le son ne recharge plus tout le livre ;
- **#11** `popups/sub/book_selection.gd` passe par `AppParameters.set_book_name()`
  au lieu d'appeler `BookData.do_load_book()` dans son coin (le choix est donc
  persisté et Player est prévenu) ;
- **#7** `BookData.do_load_book()` vide `all_nodes` avant de le remplir ;
- l'inventaire deviné après migration est désormais **sauvegardé immédiatement**
  (sinon il était redeviné à chaque lancement).

Restent liés à cette section :
- `Player.insert_all_objects()` / `compute_my_billy()` ont disparu avec le
  découpage de `player.gd` (§4.1) ; l'inventaire construit ses lignes lui-même.

Vérifié en bac à sable (`HOME` isolé, jamais sur la vraie sauvegarde) : les 29
tests passent, plus un essai sur une **copie** de la vraie sauvegarde du joueur
(fichiers `-1.json` → `-fdcn.json`, 103 chapitres et objets préservés).

### 2.2 `Swiper` ✅ SUPPRIMÉ (2026-08-10)

`autoload/swipe.gd` et son entrée d'autoload sont supprimés. C'était le système
de pagination hérité (déplacement d'une caméra entre cinq pages côte à côte, avec
des positions en dur), dont le `main` n'était jamais renseigné dans le nouveau
flux : ses appels partaient donc sur une instance nulle.

Points d'appel réorientés vers `ui/menu_page.gd` :
- `ui/top_menu.gd:focus_to_main/chapitres/success/lore()` → `MenuPage.go_to_page(<nom>)`
- `ui/left_backer.gd` → `go_to_page(dest)`, et `BACK` passe désormais par
  `Player.jump_to_previous_chapter()` / `jump_back()` directement.

Ces deux widgets sont réutilisables et n'ont pas de référence vers leur
conteneur : ils le retrouvent en remontant l'arbre, via le nouvel utilitaire
`Utils.find_ancestor_with_method(node, "go_to_page")`. Hors d'un `MenuPage` (cas
de l'archive), l'appel ne fait rien au lieu de planter.

`MenuPage` expose maintenant `go_to_page(nom)` et `page_names`
(`aventure`/`chapitres`/`lore`/`succes`/`about`, dans l'ordre de `scenes`).

**Navigation neutralisée quand une popup est ouverte** — les popups sont ajoutées
dans `PopupContainer`, qui recouvre la page : sans garde-fou, un balayage fait
*dans* la popup changeait la page derrière elle, et les flèches restaient actives
sous la popup. Balayage, flèches et `go_to_page()` sont donc bloqués tant qu'une
popup est affichée, et **les flèches sont grisées** pour que ce soit visible.
`is_popup_open()` ignore les nœuds en cours de `queue_free()`, sinon la
navigation restait bloquée une frame de trop après fermeture.

Vérifié : navigation normale OK ; popup ouverte → flèches grisées, flèche,
`go_to_page` et balayage sans effet ; popup fermée → tout revient.

L'archive garde ses appels neutralisés par des commentaires : sa pagination
interne ne fonctionne plus, ce qui est assumé (elle est vouée à disparaître).

### 2.3 `settings_loaded` déclaré mais jamais émis ✅ FAIT (2026-08-10)

`autoload/Parameters.gd` déclarait `signal settings_loaded` que **personne
n'émettait**, et `ui/top_menu.gd` s'en servait comme garde « est-ce que j'arrive
trop tôt ? » :

```gdscript
if AppParameters.is_node_ready():
    _apply_settings()
else:
    AppParameters.settings_loaded.connect(_apply_settings)   # ne part jamais
```

La branche `else` était un cul-de-sac : un TopMenu prêt avant `AppParameters`
n'initialisait jamais ses interrupteurs spoils/son (ni, depuis §2.4, son type de
Billy) et affichait silencieusement les valeurs codées en dur dans le `.tscn`.
Bug **latent** en pratique — les autoloads sont prêts avant la scène principale,
donc `is_node_ready()` était toujours vrai — mais un piège sans signal d'échec.

**Corrigé en supprimant le cas particulier plutôt qu'en le réparant** :
`settings_loaded` est supprimé, et `settings_changed` (déjà émis par
`_save_parameters()`) devient l'unique signal « les réglages valent ceci,
repeins-toi », désormais aussi émis en fin de `Parameters._ready()`.
`ui/top_menu.gd` adopte le schéma que `screens/chapitres_menu.gd` et
`screens/succes_menu.gd` utilisaient déjà — branchement **inconditionnel** +
peinture initiale par l'abonné lui-même, sans garde :

```gdscript
AppParameters.settings_changed.connect(_apply_settings)
_apply_settings()
```

Deux conséquences à connaître :

- **Bénéfice en prime** : le menu du haut suit maintenant un réglage changé
  ailleurs, ce qui n'était pas le cas avant (il écrivait sans jamais écouter).
  Se contenter de renommer le signal dans la garde aurait été une *régression* :
  la branche `if` étant toujours prise, il n'aurait été abonné à rien.
- **`set_pressed_no_signal()`** est obligatoire dans `_apply_settings()` :
  `settings_changed` part souvent parce que le joueur vient de cliquer un de ces
  deux `CheckButton`. Pas de boucle infinie sans ça (`BaseButton.set_pressed()`
  et `set_spoils()` sortent tôt sur valeur identique) mais c'était sûr par
  accident et non par construction.

L'émission en fin de `_ready()` ne réveille personne aujourd'hui (aucun abonné
n'existe encore à cet instant, les autoloads passant avant la scène) : elle ne
couvre que le cas « une interface a peint les défauts avant la lecture du
fichier ». `_load_parameters()` n'émettait rien de lui-même, sauf migration
(`_migrate_legacy_book_number()` → `_save_parameters()`).

⚠️ `settings_changed` est **gros-grain** : il part pour n'importe quel réglage,
donc un changement de type de Billy repeint aussi les deux listes virtualisées.
Borné à la taille du pool (~15 lignes, pas 606 chapitres), donc indolore — mais
c'est un choix « simplicité > précision ». Le jour où un abonné y fait quelque
chose de coûteux, il faudra des signaux par domaine (`spoils_changed`, …).

### 2.4 `Player._main` god-object bridge ✅ FAIT (2026-08-10)

Le pont `_main` / `register_main()` a disparu avec le découpage (§4.1). Les
signaux qui le remplacent existent et sont émis :
`Inventory.items_changed`, `Inventory.billy_changed`, `PlayerStats.stats_changed`.

Déjà branchés : `popups/sub/inventory.gd` (sur `items_changed`) et
`popups/sub/stats.gd` (sur `stats_changed`) — la popup des stats se met donc à
jour en direct, ce qui règle aussi **#36**.

Branché depuis : `ui/top_menu.gd` s'abonne à `Inventory.billy_changed` dans son
`_ready()` et repeint via `set_billy()`, avec la peinture initiale dans
`_apply_settings()` (le type vit dans les paramètres persistés, il hérite donc de
la même garde `AppParameters.is_node_ready()`).

Dernier reste du pont supprimé au passage : `var main = null` et les quatre
`_switch_to_*()` qui l'appelaient (c'était §2.5), plus l'appel mort
`top_menu.register_main(self)` de `archive/main.gd`. Plus une seule occurrence de
`register_main` / `_main` dans le dépôt.

⚠️ Corrigé dans la foulée : `set_billy()` et `set_page()` cherchaient
`$Billys/...` et `$Pages/...` alors que ces nœuds sont sous `HBoxContainer`.
Brancher le signal sur la fonction telle quelle plantait donc sur un `null` au
premier changement de type.

### 2.5 `ui/top_menu.gd` billy buttons call a null `main` ✅ FAIT (2026-08-10)

`_switch_to_guerrier/paysan/prudent/debrouillard()` appelaient
`self.main._switch_to_*()`, avec un `var main = null` que personne n'assignait
(l'assignation venait de `register_main`, supprimé en §2.4).

Ils appellent désormais `Inventory.force_billy_type('<type>')`, nouvelle méthode
publique : le vrai `_switch_to_billy()` reste privé et renvoie maintenant un
booléen (« le type a-t-il changé »), ce qui permet à `force_billy_type()` de ne
recalculer les stats que si nécessaire. Ce recalcul est indispensable : les
modificateurs de type (`PlayerStats.BILLY_MODIFIERS`) vivent dans la couche
`items`. Couvert par `test/unit/test_player.gd`.

### 2.6 `window/stretch/mode` ✅ FAIT (2026-08-10)

`"2d"` était une valeur Godot 3, silencieusement ignorée par Godot 4 : l'app ne
s'adaptait donc à aucune taille d'écran, quel que soit le travail fait sur les
conteneurs. Corrigé en :

```
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"
```

**Pourquoi `expand`** plutôt que `keep_width` : sur un écran plus *haut* que le
16:9 de base (tous les téléphones modernes), les deux donnent le même résultat.
Ils ne divergent que sur un écran plus *large* que la base : `keep_width`
écraserait alors la hauteur logique (1920×1080 → 540×304, inutilisable) alors
qu'`expand` garde 960 de haut et élargit. Comme l'app tourne aussi en fenêtre
sur desktop et web, `expand` est le seul des deux qui ne casse jamais.

Viewport logique obtenu :

| écran physique | viewport logique | effet |
|---|---|---|
| 1080×1920 (16:9) | 540×960 | identique à la base |
| 1080×2400 (20:9) | 540×1200 | +240 px de hauteur utile |
| 1440×3120 | 540×1170 | +210 px de hauteur utile |
| 1920×1080 (desktop) | 1707×960 | +1167 px de largeur utile |

**Effet de bord corrigé dans la foulée** : activer l'étirement a révélé une
hypothèse de taille fixe dans `ui/nav_buton.gd`. La barre de navigation est un
`Polygon2D` dessiné à la main pour 960 px de haut ; sur un 20:9 elle laissait un
**trou de 240 px** en bas. Elle est désormais étirée à l'exécution
(`_fit_poly_to_height()`), et le `pivot_offset` suit le centre pour que le
miroir de la flèche droite reste juste. Vérifié : la barre couvre exactement la
hauteur du viewport en 960 / 1170 / 1200, et le tracé reste dans l'écran
(`NavLeft` x=[0..50], `NavRight` x=[490..540]).

Les autres éléments à coordonnées figées (`bread`, `gauge`, les rubans de
`ChapterChoice`) sont des éléments de **hauteur fixe dans des conteneurs flex** :
ils n'ont pas à s'étirer, et ne sont donc pas concernés.

---

## 3. Feature parity vs `archive/main.gd` (837 lines, 64 funcs)

Only the **main page** has been rebuilt (`screens/AventureMenu.tscn` + `screens/aventure_menu/*`).

| Feature | Archive source | New home | Status |
|---|---|---|---|
| Global completion gauge | `refresh()` :402 | `main_menu/global_completion.gd` | ✅ ported, reactive |
| Position (acte/arc/chapter) | `refresh()` :411–456 | `main_menu/position.gd` | ✅ ported, reactive |
| Breadcrumb trail | `refresh()` :459 | `main_menu/breadcrumb.gd` | ✅ ported, reactive |
| Next-chapter choices | `refresh()` :491 | `main_menu/choice_next_chapiter.gd` | ✅ ported, reactive |
| Ending choice card | `refresh()` :505–523 | `choice_next_chapiter.add_ending_choice` | ✅ ported |
| Combat panel | :103–132 | `main_menu/combat.gd` | ✅ ported, reactive |
| Settings popup (spoils/sound) | `_refresh_options` :325 | `popups/SettingsPopup` + `ui/top_menu.gd` | 🟡 partial (§2.3) |
| Inventory tab | `_options_show_equipement` :692 | `popups/sub/inventory.gd` | 🟡 partial + bugs (§4.6) |
| Stats tab | `_refresh_options_stats` :789 | `popups/sub/stats.gd` | 🟡 no live refresh |
| Book selection | `_switch_to_book_*` :814–830 | `popups/sub/book_selection.gd` | 🟡 broken (§4.7) |
| **Chapters page** | `insert_all_chapters` :229, `_update_all_chapters` :245 | `screens/chapitres_menu.gd` | ✅ **portée + virtualisée** |
| **Success page** | `insert_all_success` :252, `_update_all_success` :319 | `screens/succes_menu.gd` | ✅ **portée + virtualisée** |
| **Lore page** | `insert_all_lore` :262 | `screens/LoreMenu.tscn` | ❌ **no script — static shell** |
| **About page** | (static + buttons :620–628, :832–838) | `screens/AboutMenu.tscn` | ❌ **no script — buttons dead** |
| **Jump to chapter 1/100/…/600** | `jump_to_chapter_100aine` :208 + :584–603 | — | ❌ not ported |
| **New-success popup + sound** | `_check_new_success` :134 | `popups/SuccessPopup` exists, unused | ❌ not wired |
| **Item acquired/lost popups** | `popup_new_item` :659, `popup_remove_item` :665 | `popups/ItemPopup` exists, unused | ❌ not wired |
| **Intro music per book** | `_play_intro` :142 | — | ❌ not ported |
| **Per-chapter narration audio** | `_play_node_sound` :151 | — | ❌ not ported |
| **Billy-change sound** | `billy_type_is_changed` :553 | — | ❌ not ported |
| **New Billy flow + confirm popup** | `_on_button_new_billy` :605, `launch_new_billy` :613 | `choice_next_chapiter.launch_new_billy` | 🟡 no confirmation popup |
| **Bug-report / Twitter / wiki links** | :620, :624, :832, :836 | — | ❌ not ported (About) |
| **Billy type display in top menu** | `set_billy` | `ui/top_menu.gd:46` exists | 🟡 never called |
| **Page highlight in top menu** | `set_page` | `ui/top_menu.gd:72` exists | 🟡 never called; `$Pages/*` nodes hidden |

**Summary: 4 of 5 screens are empty shells; all audio, all popups, and chapter-jump
navigation are unported.**

---

## 4. Autoload review — duplication, misplaced logic, bugs

### 4.1 `player.gd` (852 lines) — far too big, mixes 5 responsibilities

It is simultaneously: save-file I/O, inventory model, stat engine, navigation
controller, **and a UI factory**. Suggested split:
`PlayerSave` (I/O) / `Inventory` / `Stats` / `Player` (navigation + state).

**Duplication — save-file quartets (`:91–181`)**
Four near-identical blocks (`all_times_already_visited`, `current_node_id`,
`session_visited_nodes`, `possessed_items`), each with its own
`_get_*_file()` + `load_*()` + `save_*()`, and each repeating
`_BOOK_NUMBERS[AppParameters.get_book_name()]`. Collapse to:

```gdscript
func _save_path(key) -> String
func _load_array(key, default) / _save_json(key, value)
```

**Duplication — 24 one-line getters (`:433–480`)**
`get_end/adr/hab/cha/chamax/deg/arm/crit` × base/`_chapters`/`_items`.
Replace with a stat dict + `get_stat(name, layer := "total")`.

**Duplication — `_apply_billy_stats()` (`:484`)** writes each stat twice
(`self.hab += 2; self.hab_items += 2`). A helper `_add_stat(name, v, layer)` removes
the whole class of copy-paste typos.

**Misplaced — `insert_all_objects()` (`:239`) builds UI inside the data layer** 🔴
It instantiates `entities/Item.tscn` **scene nodes** and stores them in
`Player.all_items`; `_compute_item_by_categories()` (`:647`) then reads game data
back off those UI nodes (`item.get_item_name()`, `item.get_category()`).
So the billy-type algorithm depends on UI nodes existing. This is the worst
architectural smell in the codebase.
**Fix**: keep `all_items` as plain data from `BookData.get_all_objects()`; let the
inventory *view* build nodes.

**Misplaced — hardcoded migration table (`:195–210`)** the per-book/per-billy
starting-item `guess` dict is content, not code → move to `books/<name>/`.

**Dead code**: `:728–746` five commented-out `switch_to_*` stubs;
`:666–683` `billy_overload_size()` has 3 unused locals (`nb_to_remove`, `nb_remove`,
`to_remove`); `:752` unused `categories` local in `compute_my_billy_for_option`.

### 4.2 `player.gd` — confirmed logic bugs

- **Stats double-apply on reload** 🔴 (already in `todo.md`, still open)
  `do_load()` → `_redo_all_my_chapters_stats()` (`:218`) replays
  `apply_one_chapter_stats()` over the whole history, and `_apply_chapter_stat()`
  (`:786`) only ever does `+=`. Nothing resets the `*_chapters` accumulators first,
  so each extra `do_load()` re-adds the entire history's bonuses.
  Note `archive/main.gd:62` even calls `Player.do_load()` a second time (`# TEST`).

- **`_fully_reset_our_stats()` (`:421`) is incomplete** 🔴
  Resets `adr/hab/chamax/deg/arm/crit_chapters` but **omits `end_chapters`**
  (declared `:48`), plus `pv_max_bonus`, `nb_infos`, `gloire`, `richesse`, `cha`, `pv`.
  → Starting a new Billy silently inherits the previous run's endurance, PV-max
  bonus, glory and wealth.

- **`clean_billy_overload()` (`:686`) can hang or mis-count** 🟠
  `while nb_removed < billy_overload:` with an inner `for` that only breaks on a
  removal. If `all_billy_equip` is empty or contains only `new_option`, the loop
  never terminates. Also `all_billy_equip` is a snapshot, so later passes re-pick
  an already-removed name, incrementing `nb_removed` without removing anything.

- **4 chapter-stat keys silently dropped** 🟠 `_apply_chapter_stat` (`:786`):
  `1_4_pv_max`, `arc_et_couteau`, `pv_1_4_max`, `pv_win_plus_1` only print a warning.
  `pv` and `chance` are marked `TODO: cap min/max` and are uncapped.

### 4.3 `BookData.gd` — book-switch leak 🔴

`do_load_book()` fills `self.all_nodes[node_id_str] = ...` **without clearing
`all_nodes` first**. Switching fdcn → cdsi leaves every fdcn chapter whose ID is
absent from cdsi still resolvable, so `get_chapter_node()` can silently return
data from the *other book*. Same risk for the other dicts that are wholesale
reassigned (those are fine) — only `all_nodes` accumulates.
**Fix**: `self.all_nodes = {}` (and `chapter_data` instances are `Node`s created with
`.new()` and never freed → also a slow leak; `RefCounted` would be the right base).

Also: `_check_cond_rec()` (`:197`) falls off the end returning `null` when a
condition dict has none of `$end`/`$or`/`$and` — callers treat that as false by
accident. `chapter_data.gd` `extends Node` but is pure data → should be `RefCounted`.

### 4.4 `Parameters.gd` — over-eager reload + setter duplication

- `_apply_parameters()` (`:55`) calls `BookData.do_load_book(...)` — and it is
  invoked from `set_sound()` (`:85`). **Toggling sound reloads the entire book.** 🟠
  Split into `_apply_sound()` / `_apply_book()`.
- Four setters (`set_spoils`/`set_sound`/`set_billy_type`/`set_book_name`) repeat
  the identical read→compare→print→assign→save shape. One `_set(key, value)` helper.
- No granular signals: only a generic `settings_changed`. `spoils` changing should
  re-render every `ChapterChoice`; nothing listens. Add `spoils_changed`,
  `billy_changed`, `book_changed`.
- `settings_loaded` never emitted → §2.3.

### 4.5 `swipe.gd` — 100% legacy (see §2.2). Candidate for deletion.

### 4.6 `Sounder.gd` / `utils.gd` — mostly fine

- `Sounder` has a single `$Player` stream: `play()` stops the previous sound, so
  narration + billy sound + success jingle cannot overlap. Fine today; note it.
- `utils.gd:load_external_texture(path, logger)` — `logger` is unused everywhere.
- `utils.gd:delete_children` does `remove_child` + `queue_free` (correct).
- `utils.gd:roll_a_dice` uses `randi()` with no `randomize()`/seed anywhere in the
  project → identical dice sequence every launch. 🟠

### 4.7 Non-autoload logic that is in the wrong place

- **`popups/sub/inventory.gd:8–19` duplicates `Player.insert_all_objects()`** —
  same instantiate/`load_item_data`/`is_ok_to_be_shown` loop, **but without the
  `all_items = []` reset that the Player version does (`:241`)**. So every time the
  inventory popup is opened it *appends another full copy* of every item into
  `Player.all_items`, which then corrupts `_compute_item_by_categories()` → billy
  detection. 🔴
- **`popups/sub/inventory.gd:29–46` `refresh_all_objects()` is dead and broken**:
  references `$Options/Equipement/BlockGuerrier/sprite` (nodes that exist only in
  the old `main.tscn`) and uses `set_shader_param()` — the **Godot 3** name
  (Godot 4 = `set_shader_parameter`). It would crash if ever called; the call site
  is commented out (`:22`).
- **`popups/sub/book_selection.gd` calls `BookData.do_load_book()` directly** 🔴
  instead of `AppParameters.set_book_name()`. The choice is therefore **not
  persisted**, `_apply_parameters()` never runs, and `Player` is not reloaded for
  the new book. Two sources of truth for "current book".
- `popups/sub/stats.gd` reads 24 `Player.get_*` in `_ready()` only — no signal, so
  values freeze if stats change while the tab is open.
- `entities/ChapterChoice.gd` `update_from_son_node()` (`:104`) and
  `update_when_in_all_chapters()` (`:140`) duplicate ~80% of the same
  spoil/seen/ending/success/secret decoration logic. `entities/Success.gd:update()`
  repeats a third variant.
- `popups/ItemPopup.gd:23` loads `.svg` only, while `entities/Item.gd:26–33` does
  svg→png fallback. Inconsistent; PNG items show blank in the popup.

### 4.8 Ressources vs stats ✅ SOCLE FAIT (2026-08-10)

Les pv et la chance ne sont pas des stats mais des **ressources** : on les
consomme. Le code le supposait déjà à moitié (variables simples au lieu des trois
couches, hors de `BASE_STATS`) mais il en manquait tout le reste, et le symptôme
était spectaculaire : **un Billy neuf démarrait à 0 pv sur 6**.
`launch_new_billy()` → `full_reset()` met `pv = 0`, et le chapitre 1 des deux
livres n'accorde aucune stat (vérifié dans les données) — donc rien ne remplissait
jamais la jauge.

Trois propriétés désormais tenues, toutes dans `autoload/player_stats.gd`,
section « Ressources » :

1. **Bornées.** Toute écriture passe par `_set_pv` / `_set_chance`, qui ramènent
   entre 0 et le plafond (`pv_max`, `get_chance_max()`). API publique :
   `add_pv(x=1)` / `del_pv(x=1)` / `add_chance(x=1)` / `del_chance(x=1)`. Ferme la
   moitié « cap `pv`/`chance` » de **#25**.
2. **Sauvegardées.** Nouvelles clés `SaveManager.KEY_PV` / `KEY_CHANCE`.
   **Aucune migration** : un fichier absent veut dire « jamais enregistré », que
   `load_resources()` traduit par « au plein » — le seul défaut qui ne pénalise pas
   une partie en cours. `_create_empty_save()` ne les écrit donc volontairement
   pas (les plafonds n'y sont pas encore connus).
3. **Hors du rejeu d'historique.** C'est le point le moins évident.
   `Player.do_load()` reconstruit la couche « chapitres » en rejouant les chapitres
   visités ; une ressource, elle, n'est pas redérivable (un dégât de combat ou un
   ajustement manuel ne se rejoue pas). `apply_chapter_stat(k, v, with_resources)`
   et `apply_chapter_stats(id, with_resources)` prennent donc un mode
   cumuls-seuls, utilisé par `_redo_all_my_chapters_stats()`. Sans ça le rejeu
   **écrivait** des pv gonflés sur le disque (les setters sauvegardent), que le
   `load_resources()` suivant relisait : chaque démarrage effaçait les dégâts.
   Verrouillé par `test/unit/test_resources.gd`.

Le partage se lit dans `_CHAPTER_RESOURCE_KEYS` = `chance`, `half_pv`,
`max_chance`, `max_pv`, `pv`. Tout le reste (`gloire`, `richesse`, `info`,
`pv_max`) est un **cumul** dérivable de l'historique et reste dans le rejeu.

⚠️ **Le plafond bouge** (`pv_max = end × 3`, donc il suit les objets et le type de
Billy). `recompute()` rogne les ressources au nouveau plafond : une jauge à 9/6
serait un bug visible. Choix assumé et destructif — décocher un objet par erreur
coûte des pv qui ne reviennent pas au recochage (monter le plafond ne soigne pas,
c'est le sens d'une ressource). Acceptable **uniquement** parce que l'onglet
ressources permet de rattraper à la main.

Interface : `ui/ResourceGauge.tscn` (barre + « courant / max », affichage seul,
réglée par `kind` + `show_title`), instanciée **deux fois dans la feuille de stats**
(`popups/sub/Stats.tscn`), chaque jauge sous la ligne de sa ressource et encadrée
des boutons − / +, grisés aux bornes.

**Pourquoi dans la feuille et pas dans un 4e onglet** (essayé, puis abandonné) :
pv et chance y étaient *déjà* affichés, un onglet dédié aurait mis le même nombre
à deux endroits. Les deux lignes ont donc perdu leur label de valeur — la jauge
porte le « courant / max » — et sont enveloppées dans un bloc (`PvBlock`,
`ChaBlock`) qui resserre la jauge contre sa ligne, la séparation du `VBoxContainer`
de la feuille étant de 35 px. `stats.gd` cherche ses lignes récursivement à cause
de cette imbrication.

Le vrai argument est ailleurs : la manipulation *pendant* une partie (chaque round
de combat) n'a pas sa place dans une popup à deux taps. La jauge est autonome
(abonnée à `stats_changed`, aucune dépendance à son hôte) précisément pour pouvoir
être posée à côté du panneau de combat sur l'écran Aventure. La popup reste ce
qu'elle doit être : là où on consulte et où on corrige.

**Reste à faire** : le combat (`screens/aventure_menu/combat.gd` lit `get_pv()` mais
n'écrit rien). Plan complet, audit des données et questions ouvertes dans
**`combat.md`** — dont deux blocages : la table du marque-page n'existe nulle part en
données, et les règles spéciales de chaque combat ne sont **pas** dans le JSON (6
champs seulement : `nom`/`hab`/`pv`/`arm`/`deg`/`pyro`). En attendant, les boutons ±
*sont* le mécanisme de combat. Voir aussi **#52** (`rancune`/`respect` de cdsi
perdus) et **#53** (`richesse`/`gloire`/`nb_infos` jamais affichés).

---

## 5. Flex / dynamic styling audit

Metric = absolute-positioned nodes (`layout_mode = 0`) + raw `offset_*` lines vs
container nodes. High offsets + low containers = fixed pixel layout.

| Scene | nodes | containers | layout0 | offsets | verdict |
|---|---:|---:|---:|---:|---|
| `screens/AventureMenu.tscn` | 8 | 3 | 0 | 0 | ✅ flex |
| `screens/aventure_menu/GlobalCompletion.tscn` | 10 | 5 | 0 | 0 | ✅ flex |
| `screens/aventure_menu/Position.tscn` | 21 | 9 | 0 | 0 | ✅ flex |
| `screens/aventure_menu/Breadcrumb.tscn` | 5 | 4 | 0 | 0 | ✅ flex |
| `screens/aventure_menu/ChoiceNextChapiter.tscn` | 7 | 5 | 0 | 0 | ✅ flex |
| `screens/aventure_menu/Combat.tscn` | 38 | 12 | 0 | 0 | ✅ flex |
| `main.tscn` | 2 | 0 | 0 | 0 | ✅ flex |
| `popups/sub/Stats.tscn` | 35 | 9 | 0 | 2 | ✅ flex |
| `popups/sub/BookSelection.tscn` | 6 | 3 | 0 | 0 | ✅ flex |
| `popups/sub/Inventory.tscn` | 13 | 3 | 0 | 2 | ✅ mostly |
| `entities/Item.tscn` | 6 | 1 | 0 | 4 | ✅ flex |
| `screens/SuccesMenu.tscn` | 7 | 3 | 0 | 0 | ✅ flex + **liste virtualisée** |
| `popups/SettingsPopup.tscn` | 10 | 1 | 0 | 3 | 🟡 header tabs fixed |
| `ui/MenuPage.tscn` | 6 | 1 | 0 | 5 | 🟡 insets nav/top encore en dur (50/48 px), mais padding centralisé |
| `entities/ChapterChoice.tscn` | 21 | 0 | 8 | 52 | 🟠 anchored by me; inner still absolute |
| `ui/gauge.tscn` | 2 | 0 | 0 | 4 | 🟠 `Node2D`, fixed radius 50 |
| `ui/NavButon.tscn` | 5 | 0 | 0 | 10 | 🟠 fixed 480-tall polygon |
| `ui/right_nexter.tscn` | 5 | 0 | 2 | 12 | 🟠 legacy |
| `ui/left_backer.tscn` | 5 | 0 | 0 | 16 | 🟠 legacy |
| `ui/bread.tscn` | 7 | 0 | 0 | 17 | 🟠 fixed 93×40 polygon |
| `ui/going_to_line.tscn` | 6 | 1 | 0 | 8 | 🟠 legacy |
| `entities/LoreEntry.tscn` | 8 | 0 | 0 | 12 | 🟠 (2.7 MB file!) |
| `entities/EndingChoice.tscn` | 13 | 0 | 0 | 36 | 🔴 fully absolute |
| `entities/SuccessItem.tscn` | 13 | 4 | 0 | 8 | ✅ flex (offsets = ancrages du ruban/icône) |
| `popups/ItemPopup.tscn` | 4 | 0 | 0 | 6 | 🔴 absolute |
| `popups/SuccessPopup.tscn` | 7 | 0 | 0 | 15 | 🔴 absolute |
| `popups/GenericConfirmationPopup.tscn` | 4 | 0 | 0 | 16 | 🔴 absolute |
| `screens/LoreMenu.tscn` | 26 | 2 | 7 | 23 | 🔴 needs rebuild |
| `ui/top_menu.tscn` | 45 | 4 | 19 | 73 | 🔴 **live on every page** |
| `screens/AboutMenu.tscn` | 32 | 0 | 14 | 69 | 🔴 needs rebuild |
| `screens/ChapitresMenu.tscn` | 9 | 5 | 0 | 0 | ✅ flex + **liste virtualisée** |
| `archive/main.tscn` | 264 | 13 | 180 | 703 | ⬛ archive — reference only |

Notes:
- **`ui/top_menu.tscn` is the priority**: it is instanced on every page, and its
  `Pages` + `Billys` sub-panels (currently `visible = false`) are pure absolute
  layout with hand-tuned offsets.
- `ui/gauge.tscn` is a `Node2D` drawing at a fixed `radius = 50`; it cannot
  participate in container layout — that is why `GlobalCompletion` needs the
  `GaugeSizer` `Control` wrapper. Consider a `Control`-based gauge with
  `radius = min(size.x, size.y)/2`.
- Several polygon-based widgets (`bread`, `NavButon`, `ChapterChoice` ribbons) use
  baked `PackedVector2Array` coordinates — genuinely fixed-size art. Either accept
  them as fixed-size atoms inside flex parents, or redraw in `_draw()` from `size`.

---

## 5ter. Padding : centralisé dans MenuPage

Le padding autour du contenu d'un écran est appliqué **une seule fois**, par
`ui/MenuPage.tscn` → `SceneContainer` (passé de `Container` à `MarginContainer`,
seul capable d'appliquer réellement des marges). Chaque écran reçoit donc sa
zone déjà en retrait et n'a pas à s'en occuper — le `MarginContainer` « Padding »
qui existait dans l'ancien MainMenu a été supprimé.

Raison : un écran n'a pas à connaître l'habillage qui l'entoure. `MenuPage` gère
déjà les 50 px réservés aux flèches de navigation et les 48 px du top menu ; le
padding est de la même famille. Les écrans restants (#17 Succès, #18 Lore,
#19 À propos) en hériteront gratuitement.

Vérifié : largeur utile d'un écran = 540 − 100 (flèches) − 24 (padding) = **416 px**.

## 5bis. Listes longues : virtualisation

`archive/main.gd:insert_all_chapters()` instanciait **une ligne par chapitre**.
Or un livre fait 606 (fdcn) à 691 (cdsi) chapitres et `ChapterChoice.tscn` pèse
21 nœuds : soit ~13 000 nœuds pour ce seul écran. C'est la cause des
ralentissements sur la page Chapitres.

`screens/chapitres_menu.gd` applique donc une **liste virtualisée** :

- le `Content` du `ScrollContainer` n'empile rien ; il a simplement la hauteur
  qu'aurait la liste complète (`nb × ROW_HEIGHT`), ce qui donne à la barre de
  défilement exactement la course attendue ;
- seules ~15 lignes existent (hauteur visible + `BUFFER_ROWS` de marge) ; elles
  sont **recyclées** au défilement et repositionnées via `offset_top/bottom` ;
- les ancrages gauche/droite des lignes sont conservés : leur largeur suit le
  conteneur toute seule (c'est la partie « flex » ; seul le Y est piloté) ;
- une ligne n'est réalimentée (`set_chapitre` + `update_when_in_all_chapters`)
  que si elle **change de chapitre**, pas à chaque pixel de défilement.

Mesuré : **606 chapitres → 15 lignes, 331 nœuds** pour tout l'écran (au lieu de
~13 000), et ce nombre **ne bouge pas** quand on défile ni quand le livre change.

Appliqué aussi à **SuccesMenu** (#17). Attention, le profil y est différent : il
n'y a que **51 succès**, la virtualisation n'y est donc pas un enjeu de
performance — elle est gardée pour n'avoir **qu'un seul motif** de liste.

⚠️ **Piège n°1 — rubans `Polygon2D` adaptatifs.** Deux erreurs commises et
corrigées sur `SuccessItem`, à connaître avant de refaire un ruban :

1. **Ne pas mettre le `Polygon2D` à l'échelle.** Ça fausse l'angle de la bande,
   et surtout les `Label` qui en sont *enfants* héritent de l'échelle : le texte
   « Obtenu » se retrouvait étiré de 83 %. Il faut **recalculer les points**.
   (`ui/nav_buton.gd` peut se permettre l'échelle : son polygone n'a pas d'enfant.)
2. **La pente doit être un décalage fixe en pixels, pas un ratio.** Avec un
   ratio, une ligne plus haute penche proportionnellement plus : à 88 px la bande
   filait jusqu'à x=95 alors que la colonne de libellés commence à x=70 — le
   ruban et son texte écrivaient **par-dessus le libellé du succès**, rendant les
   deux illisibles. À décalage fixe, la bande occupe toujours la même bande
   horizontale et se redresse simplement quand la ligne grandit.

3. **Le texte doit pivoter avec la bande.** Conséquence du point 2 : à pente
   fixe, l'angle de la bande **dépend de la hauteur** (74,9° du vertical à 50 px,
   81,3° à 88 px, 84,1° à 130 px). Garder la rotation d'origine, calée sur une
   ligne de 48 px, fait diverger le texte de sa bande. `_place_ribbon_label()`
   recalcule donc l'angle *et* recentre le texte sur la bande à chaque
   redimensionnement.

La zone `Marker` doit être assez large pour contenir l'icône **et** le ruban
incliné (96 px ici : bande jusqu'à x=84, texte jusqu'à x=93).

Vérifié sur les 51 succès à plusieurs positions de défilement : écart d'angle
texte/bande **0,00°**, écart de centre **0,00 px**, **0** coin de texte hors zone.

⚠️ **Piège n°3 — changer les ancrages de la racine d'une scène casse ses
instances.** En passant `SuccessItem` en `anchor_right = 1.0`, l'instance de
`SuccessPopup.tscn` qui portait `offset_right = 454.9` (écrit quand l'ancrage
valait 0) s'est mise à signifier « largeur du parent **+ 455** » : la ligne
faisait 910 px de large. Après un changement d'ancrage sur une racine, **vérifier
toutes les scènes qui l'instancient**.

⚠️ **Piège n°2** : `ROW_HEIGHT` doit être **≥ la plus grande hauteur qu'une
ligne puisse réclamer**. La `size.y` d'un `Control` ne descend jamais sous sa
taille minimale ; si on positionne les lignes tous les 80 px alors que les plus
bavardes en exigent 86, **elles se recouvrent**. Mesuré à la largeur d'écran la
plus étroite (416 px) : 45 succès tiennent en 80 px, 6 réclament 86 → `ROW_HEIGHT
= 88`. À revérifier en cas de changement de police ou de gabarit de ligne.

Reste **#18** (Lore) sur le même modèle.

### Nommage

`entities/Success.tscn` → **`entities/SuccessItem.tscn`** (+ `success_item.gd`).
Trois choses s'appelaient « Success » : la ligne de liste, la racine de
`SuccesMenu.tscn`, et `SuccessPopup`. La ligne est désormais un *Item*, comme
`entities/Item.tscn` pour l'inventaire, et la racine de l'écran a été renommée
`SuccesMenu`.

Le nœud instancié dans `SuccessPopup.tscn` garde le nom `Success` : c'est un nom
d'instance, indépendant de la racine de la scène source, et sa piste
d'animation (`wholebackground/PanelBorder/Success` → `set_already_seen`) reste
valide.

### ⚠️ Identifiants de chapitre : float vs int

Le JSON du livre rend **tous les nombres en float** (`chapter_data.get_id()` →
`26.0`, `success['chapter']` → `26.0`), alors que `visited_nodes_all_times` et
`session_visited_nodes` contiennent des **int**. Or en GDScript :

```gdscript
26.0 in [26]   # false !
```

Conséquence : tous les marqueurs « déjà vu » restaient éteints — ruban « Obtenu »
gris sur un succès pourtant acquis, et sur l'écran Aventure les choix de chapitre
n'étaient jamais marqués comme visités.

Corrigé **à la source**, dans les prédicats, pour que tous les appelants en
profitent : `Player.did_all_times_seen()`, `Player.did_billy_seen()`,
`BookData.is_node_id_secret()`. Et les entités stockent désormais un entier
(`SuccessItem.set_chapitre()`, `ChapterChoice.set_chapitre()`).

Verrouillé par `test/unit/test_chapter_ids.gd` (15 assertions), qui teste aussi
la sémantique GDScript elle-même : si `26.0 in [26]` devient vrai un jour, le
test le signalera.

## 6. Repo hygiene

- ✅ `.gitignore` now Godot-focused; `scripts/.gitignore` holds the Python rules;
  `.godot/`, `.import/`, `builds/`, `.idea/` untracked (2 163 files removed).
- ⚠️ `.git/` is still ~202 MB — history already contains the caches. Only a history
  rewrite would shrink it; not urgent.
- `entities/LoreEntry.tscn` is **2.7 MB** vs <100 KB for every other scene — almost
  certainly embedded binary resources that should be external files.
- `project.godot` `[rendering]` still has Godot-3-only keys
  (`quality/driver/driver_name = "GLES2"`, `vram_compression/import_etc`) — ignored
  by Godot 4, but stale. Godot 4 equivalent: `rendering/renderer/rendering_method`.
- `shaders/gray.gdshader` is referenced only by `archive/main.tscn`;
  `shaders/shader_grey.tres` is referenced by nothing. One is dead.
- **GUT a été supprimé** (2026-08-10). La version embarquée (7.2.0) était un addon
  **Godot 3** qui ne se chargeait pas du tout sous Godot 4.7 (`File` ×19,
  `OS.exit_code` ×4, `GDScriptFunctionState`, `MARGIN_*`) : `extends
  "res://addons/gut/test.gd"` échouait sur `Could not resolve class`, donc
  `test/unit/test_player.gd` ne tournait plus depuis la migration Godot 4.
  Supprimés : `addons/gut/`, `.gut_editor_config.json`, `.gut_editor_shortcuts.cfg`.
  Remplacé par un mini-framework maison (§6bis).
- Untracked leftovers in the working tree: a `<null>` file at repo root.

---

## 6bis. Tests

Mini-framework maison, sans dépendance (GUT supprimé, voir §6).

```
test/test_case.gd     classe de base : assert_eq/ne/true/false/null + crochets
                      before_all / before_each / after_each / after_all
test/test_runner.gd   découverte + exécution + rapport
test/all.gd           point d'entrée LIGNE DE COMMANDE  (code de sortie 0/1)
test/all.tscn         point d'entrée ÉDITEUR (F6) -> test/all_scene.gd
test/unit/test_*.gd   un fichier par sujet
```

Écrire un test :

```gdscript
extends "res://test/test_case.gd"

func test_quelque_chose():
    assert_eq(2 + 2, 4, "les maths marchent")
```

Lancer :

```bash
godot --headless -s test/all.gd --path .                  # tout
godot --headless -s test/all.gd --path . -- save_migration # filtré
```
…ou ouvrir `test/all.tscn` dans l'éditeur et faire **F6**.

Points de conception :
- **Bac à sable automatique** : avant d'exécuter quoi que ce soit, le lanceur
  redirige `SaveManager.base_dir` *et* `AppParameters.parameters_file` vers
  `user://test_sandbox/`, puis restaure tout et nettoie à la fin. Un test ne
  *peut pas* abîmer la partie du joueur, même en appelant
  `Player.launch_new_billy()`. C'est délibéré : ce projet a déjà perdu une
  sauvegarde à cause d'un test lancé sur les vraies données.
- Un test **sans aucune assertion est compté en échec** (il ne prouve rien).
- Les autoloads sont accessibles par leur nom dans les tests : ils sont chargés
  à l'exécution. Attention, ce n'est PAS vrai dans un script lancé avec `-s`
  (d'où le fait que `test/all.gd` charge le lanceur via `load()`).
- Tests synchrones uniquement pour l'instant (aucun `await` dans un `test_*`).

État actuel : **45 assertions, 2 fichiers, tout passe**.

## 7. ORDERED ACTION LIST

Tags: `[bug]` `[logic]` `[refacto]` `[feature]` `[style]` `[place]` `[hygiene]`

### P0 — make the new app actually run

| # | Tag | Action | Ref |
|---|---|---|---|
| ~~1~~ | `[bug]` | ~~Call `Player.do_load()` at startup and on book switch~~ — ✅ **FAIT**, + versionnage/migration des sauvegardes | §2.1 |
| ~~2~~ | `[bug]` | ~~`window/stretch/mode` `"2d"` → `canvas_items`~~ — ✅ **FAIT** : + `aspect=expand`, + correction de `nav_buton` (§2.6) | §2.6 |
| ~~3~~ | `[bug]` | ~~Emit `settings_loaded` at end of `Parameters._ready()` (or delete signal + its `top_menu` branch)~~ — ✅ **FAIT** : signal supprimé, `settings_changed` devient l'unique signal et est émis en fin de `_ready()` | §2.3 |
| ~~4~~ | `[bug]` | ~~`ui/top_menu.gd` → `Player._switch_to_billy(<type>)`; delete the null `main` var~~ — ✅ **FAIT** : `Inventory.force_billy_type()` (§2.5) | §2.5 |
| ~~5~~ | `[logic]` | ~~Sort du `Swiper`~~ — ✅ **FAIT** : supprimé, appels réorientés vers `MenuPage`, navigation bloquée si popup ouverte | §2.2 |
| ~~6~~ | `[bug]` | ~~Replace `Player._main` callbacks with signals (`items_changed`, `billy_changed`); remove `register_main`~~ — ✅ **FAIT** : `top_menu` s'abonne à `billy_changed`, `main`/`register_main` supprimés | §2.4 |

### P1 — correctness / data-loss

| # | Tag | Action | Ref |
|---|---|---|---|
| ~~7~~ | `[bug]` | ~~`BookData.do_load_book`: reset `all_nodes`~~ — ✅ **FAIT** (§2.1) | §4.3 |
| ~~8~~ | `[bug]` | ~~`inventory.gd` re-appending into `Player.all_items`~~ — ✅ **FAIT** (§4.1, `all_items` supprimé) | §4.7 |
| ~~9~~ | `[bug]` | ~~`_fully_reset_our_stats()` incomplet~~ — ✅ **FAIT** (§4.1, `PlayerStats.full_reset()`) | §4.2 |
| ~~10~~ | `[bug]` | ~~Chapter-stat double-apply~~ — ✅ **FAIT** (§4.1, `reset_chapter_layer()`) ; **complété 2026-08-11** : la fonction laissait `gloire`/`richesse`/`nb_infos`/`pv_max_bonus`, donc chaque changement de livre les doublait (`combat.md` §3.6) | §4.2 |
| ~~11~~ | `[bug]` | ~~`book_selection.gd` → `AppParameters.set_book_name()`~~ — ✅ **FAIT** (§2.1) | §4.7 |
| ~~12~~ | `[bug]` | ~~`clean_billy_overload()` boucle infinie~~ — ✅ **FAIT** (§4.1, `Inventory.clean_overload()`) | §4.2 |
| ~~13~~ | `[bug]` | ~~Sound toggle reloads the book~~ — ✅ **FAIT** (§2.1, `_apply_sound`/`_apply_book`) | §4.4 |
| ~~14~~ | `[bug]` | ~~Seed RNG once (`randomize()`) — dice are currently deterministic per launch~~ — ✅ **FAIT** : `Utils._ready()`, prérequis du combat (`combat.md` §3.0) | §4.6 |
| 15 | `[logic]` | `_check_cond_rec` explicit `return false` fallthrough | §4.3 |

### P2 — missing features (port from archive)

| # | Tag | Action | Ref |
|---|---|---|---|
| ~~16~~ | `[feature]` | ~~**Chapters page**~~ — ✅ **FAIT** : `screens/chapitres_menu.gd`, flex + liste virtualisée + barre de saut (§5bis) | §3 |
| ~~17~~ | `[feature]` | ~~**Success page**~~ — ✅ **FAIT** : `screens/succes_menu.gd`, flex + virtualisée + compteur obtenus/total | §3 |
| 18 | `[feature]` | **Lore page** — script + rebuild `screens/LoreMenu.tscn` (per-book refs table) | §3 |
| 19 | `[feature]` | **About page** — wire bug-report / Twitter / wiki / new-Billy buttons | §3 |
| 20 | `[feature]` | Wire `SuccessPopup` on new success (`_check_new_success`) + its jingle | §3 |
| 21 | `[feature]` | Wire `ItemPopup` for acquired/lost items on chapter change | §3 |
| 22 | `[feature]` | Audio: intro per book, per-chapter narration, billy-change sound | §3 |
| 23 | `[feature]` | New-Billy confirmation via `GenericConfirmationPopup` | §3 |
| 24 | `[feature]` | Call `top_menu.set_page()` (existe, jamais appelée) ; un-hide `$Pages`/`$Billys` — `set_billy()` est branchée (§2.4) | §3 |
| 25 | `[logic]` | Implement or formally drop the 4 unmanaged chapter-stat keys — ~~cap `pv`/`chance`~~ ✅ **FAIT** (§4.8) | §4.2 |
| 52 | `[feature]` | Livre cdsi : `rancune` (18 chap.) et `respect` (14) tombent dans le `_:` de `apply_chapter_stat` et sont perdus ; `critique` est l'orthographe cdsi de `crit`, `pv_1_2_max` celle de `half_pv` | §4.8 |
| 53 | `[feature]` | `richesse` / `gloire` / `nb_infos` sont accumulés et jamais affichés (aucune vue ne les lit) | §4.8 |

### P3 — architecture / refactor

| # | Tag | Action | Ref |
|---|---|---|---|
| ~~26~~ | `[place]` | ~~UI construction out of the data layer~~ — ✅ **FAIT** | §4.1 |
| ~~27~~ | `[refacto]` | ~~Collapse the 4 save-file quartets~~ — ✅ **FAIT** (`SaveManager`) | §4.1 |
| ~~28~~ | `[refacto]` | ~~24 stat getters + `_apply_billy_stats`~~ — ✅ **FAIT** (`PlayerStats.get_stat`) | §4.1 |
| ~~29~~ | `[refacto]` | ~~Split `player.gd`~~ — ✅ **FAIT** : `SaveManager`/`PlayerStats`/`Inventory`/`Player` | §4.1 |
| 30 | `[refacto]` | Unify `ChapterChoice.update_from_son_node` + `update_when_in_all_chapters` + `Success.update` | §4.7 |
| 31 | `[refacto]` | One `_set(key, value)` helper for the 4 `Parameters` setters; add granular signals | §4.4 |
| 32 | `[place]` | Move the `guess` starting-item table out of `player.gd` into `books/<name>/` | §4.1 |
| 33 | `[refacto]` | `chapter_data.gd` `extends Node` → `RefCounted`; free/replace instances on book switch | §4.3 |
| ~~34~~ | `[refacto]` | ~~Delete dead code~~ — ✅ **FAIT** | §4.1 |
| 35 | `[bug]` | `ItemPopup` svg→png fallback, matching `Item.gd` | §4.7 |
| ~~36~~ | `[logic]` | ~~`stats.gd` refresh on a signal~~ — ✅ **FAIT** (`stats_changed`) | §4.7 |

### P4 — flex / styling

| # | Tag | Action | Ref |
|---|---|---|---|
| 37 | `[style]` | **`ui/top_menu.tscn`** → containers (highest impact: on every page) | §5 |
| 38 | `[style]` | ~~`entities/Success.tscn`~~ ✅ **FAIT** ; reste `EndingChoice.tscn` → conteneurs | §5 |
| 39 | `[style]` | `entities/ChapterChoice.tscn` inner nodes → containers (anchors done, layout still absolute) | §5 |
| 40 | `[style]` | The 3 popups (`ItemPopup`, `SuccessPopup`, `GenericConfirmationPopup`) → containers | §5 |
| 41 | `[style]` | `ui/MenuPage.tscn` : insets nav 50 px / top 48 px encore en dur → constantes de thème (le **padding** des écrans, lui, est déjà centralisé ici) | §5 |
| 42 | `[style]` | `gauge`: `Control`-based, radius from `size`, drop the `GaugeSizer` workaround | §5 |
| 43 | `[style]` | Re-tune `GlobalCompletion`/`Position` min-widths (140/170) once padding is final | §5 |
| 44 | `[style]` | Decide policy for polygon widgets (`bread`, `NavButon`, ribbons): fixed atoms vs `_draw()` from `size` | §5 |

### P5 — hygiene

| # | Tag | Action | Ref |
|---|---|---|---|
| 45 | `[hygiene]` | Investigate `entities/LoreEntry.tscn` @ 2.7 MB — externalise embedded resources | §6 |
| 46 | `[hygiene]` | Remove Godot-3 `[rendering]` keys from `project.godot` | §6 |
| 47 | `[hygiene]` | Delete whichever of `shaders/gray.gdshader` / `shader_grey.tres` is dead | §6 |
| ~~48~~ | `[hygiene]` | ~~GUT 7.2.0 (addon Godot 3) ne charge pas~~ — ✅ **FAIT** : supprimé, remplacé par le framework maison (§6bis) | §6 |
| 49 | `[hygiene]` | Delete the stray `<null>` file at repo root | §6 |
| 50 | `[hygiene]` | Tests : ✅ migration des sauvegardes + type de Billy (45 assertions, §6bis). Restent `_check_cond_rec` et l'idempotence de `do_load()` | §6bis |
| 51 | `[place]` | Decide `archive/`'s end-of-life (delete once §3 is complete) | §3 |
