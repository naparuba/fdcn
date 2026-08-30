# Review-code — pistes de refactor

État au **2026-08-23** pour le GDScript, complété le **2026-08-30** pour `scripts/` (§6) et
pour les 4 scripts `.gd` de logique modifiés depuis le 23 (§1.7, fin de §1). Lecture
complète des 42 fichiers `.gd` de l'app (hors `archive/` et `test/`, ~6 700 lignes :
`entities/`, `screens/` (et sous-dossiers), `autoload/`, `popups/` (et `sub/`), `ui/`),
croisée avec `todo.md`/`review.md` pour ne pas répéter ce qui y est déjà — catégories
1/4/5/6/7 et le point 9.1 sont réglés, 2/3/8/9.2 sont déjà au backlog. §6 ci-dessous couvre
en plus les 7 fichiers `.py` de `scripts/` (~1 170 lignes), seule partie du dépôt que
`review.md` §8 avait explicitement laissée hors de sa revue de propreté 2026-08-22 →
2026-08-23 ("hors `scripts/`") — ce générateur a par ailleurs beaucoup changé depuis (todo
3.2 → 3.13), jamais relu ligne à ligne pour ce genre de piste.

**2026-08-30 : re-lu en entier les 4 fichiers `.gd` de logique touchés par todo 3.4/3.5/3.6/
3.8 et par le fix du 2026-08-29** (`autoload/book_data.gd`, `autoload/player_stats.gd`,
`entities/chapter_data.gd`, `screens/aventure_menu/position.gd` — les autres `.gd` listés
dans `git log --since=2026-08-23` appartiennent au commit `4dff83e` du 23 lui-même, déjà
couvert). `player_stats.gd`/`chapter_data.gd`/`position.gd` : rien à signaler, bien
commentés, cohérents avec les conventions de `review.md` §1.2. Un point trouvé dans
`book_data.gd`, ajouté en fin de §1 ci-dessous pour rester dans la bonne catégorie plutôt
que d'ouvrir une section à part pour un seul item.

**Ce fichier ne couvre que le code lui-même** (duplication, complexité, nommage,
couplage) — pas les données de livre, ni les tests manquants, déjà suivis ailleurs.

Rien à signaler sur `book_data.gd`, `save_archive.gd`, `sounder.gd`, `utils.gd`,
`chapter_data.gd`, `resource_gauge.gd`, `gauge_inside_circle.gd`, `yes_no_switch.gd`,
`menu_page.gd`, `lore_menu.gd`, `virtual_list_pool.gd` — lus en entier, propres.

---

## 1 — Duplication

### 1.1 Repli d'icône svg→png→placeholder, 3 copies quasi identiques — ✅ fait (2026-08-30)

- `entities/Item.gd:46-53`, `popups/ItemPopup.gd:39-46`, `entities/success_item.gd:133-140`
- Même séquence partout : construire `<dossier>/<nom>.svg`, tester son existence, sinon
  `.png`, sinon un repli — seuls le dossier (`images/items/` vs `images/success/`) et le
  repli (`_ICONE_INCONNUE` vs `null`) changent.
- **Fait** : `Utils.load_icon_with_fallback(dossier: String, nom: String, repli:
  Texture2D = null) -> Texture2D`, qui fait le svg→png→repli une fois pour toutes. Les
  trois appelants passent de ~8 lignes à 1.

### 1.2 `ShaderMaterial` gris construit à l'identique dans 2 fichiers — ✅ fait (2026-08-30)

- `popups/sub/inventory.gd:52-54` et `popups/sub/book_selection.gd:103-105` : `ShaderMaterial.new()` + `.shader = _gray_shader` (`shaders/gray.gdshader`) + assignation à `.material`, 3 lignes identiques.
- **Fait** : `Utils.make_gray_material() -> ShaderMaterial`.

### 1.3 « Trouver l'ancêtre avec cette méthode, avertir et sortir sinon » — ✅ fait (2026-08-30), et un correctif au passage

- Sites recensés : `screens/about_menu.gd:56,168,221`, `screens/about_menu.gd:68,183`,
  `screens/aventure_menu/choice_next_chapiter.gd:86`, `ui/top_menu.gd:143`.
- **Fait** : `Utils.find_ancestor_with_method_or_warn(node, methode, appelant)`, appliqué aux
  2 sites qui font vraiment `push_warning()` + sortie (`about_menu.gd:56,168`). Le 3ᵉ site
  annoncé comme « avec avertissement » (`about_menu.gd:221`, `_dire()`) s'est révélé, à la
  relecture, faire `print(texte)` en repli — un comportement différent (afficher quand même
  le message plutôt qu'avorter), donc **pas touché**. Les 4 sites sans avertissement gardent
  `find_ancestor_with_method()` tel quel, comme prévu.

### 1.4 Résolution du numéro de livre legacy → nom, codée deux fois — ✅ fait (2026-08-30)

- `autoload/app_parameters.gd:_resoudre_livre_courant()` et
  `autoload/save_manager.gd:_legacy_book_numbers()` relisaient chacun `BookData.get_books()`
  et reconstruisaient une table rang→nom, l'une indexée à partir de 1, l'autre de 0.
- **Fait** : `BookData.get_book_name_for_legacy_number(numero: int) -> String`, 1-based, que
  les deux appellent désormais.

### 1.5 Types de Billy en chaînes littérales, ~75 fois dans 9 fichiers — ✅ fait (2026-08-30)

- `'guerrier'`/`'paysan'`/`'prudent'`/`'debrouillard'`/`'pegu'` tapés en dur dans
  `autoload/app_parameters.gd`, `autoload/inventory.gd`, `autoload/player_stats.gd`,
  `autoload/narrator.gd`, `autoload/combat_engine.gd`, `ui/top_menu.gd`,
  `popups/sub/inventory.gd`, `entities/LoreEntry.gd`, `screens/aventure_menu/combat.gd` —
  75 occurrences au total, aucune liste de référence partagée. Une faute de frappe dans
  l'une des chaînes compile sans erreur et casse silencieusement la comparaison.
- **Fait, partiellement par choix** : `Inventory.BILLY_TYPES` est la source de vérité, mais
  les ~75 sites n'ont pas tous été réécrits pour la lire — la plupart sont des clés de
  dictionnaire ou des littéraux d'un `if`/`elif` où l'indirection nuirait à la lisibilité
  pour un gain nul. À la place, un nouveau test
  (`test_player.gd::test_billy_modifiers_couvre_exactement_billy_types`) épingle
  `PlayerStats.BILLY_MODIFIERS.keys()` à `Inventory.BILLY_TYPES` : les deux tables qui
  comptent vraiment ne peuvent plus diverger sans faire échouer la suite.

### 1.6 `set_main(x): main = x` répété dans 4 fichiers

- `entities/ChapterChoice.gd`, `entities/EndingChoice.gd`, `entities/success_item.gd`,
  `ui/bread.gd` : même setter d'une ligne, mais les 4 classes n'ont pas de type de base
  commun (`Panel`, `Panel`, `PanelContainer`, `Control`) pour l'y accrocher sans imposer
  une hiérarchie artificielle.
- **Solution** : aucune pour l'instant — noté pour mémoire, pas une vraie duplication
  gênante (une ligne, quatre fichiers sans rien d'autre en commun).
- Effort : — — Valeur : spéculatif, ne pas faire sans un 5ᵉ cas qui change la donne.

### 1.7 `book_data.gd` : deux passes séparées sur `all_nodes` pour deux cartes complémentaires — ✅ fait (2026-08-30)

- `autoload/book_data.gd::_completer_succes()` et `::_index_succes_par_chapitre()` itéraient
  chacune sur tout `all_nodes` en appelant `get_success()` par nœud, pour construire deux
  structures complémentaires : succès → [chapitres] d'un côté, chapitre → succès de l'autre.
- **Fait** : `_completer_succes()` construit désormais les deux dans sa boucle existante et
  renvoie `{"succes": ..., "index": ...}` ; `_index_succes_par_chapitre()` a disparu.

---

## 2 — Code mort — ✅ tout fait (2026-08-30)

| # | où | quoi | solution |
|---|---|---|---|
| 2.1 | `entities/Item.gd:79` | `is_ok_to_be_shown()` jamais appelée (vérifié `.gd` et `.tscn`) | ✅ supprimée |
| 2.2 | `autoload/player.gd:189` | `have_previous_chapters()` jamais appelée | ✅ supprimée |
| 2.3 | `autoload/narrator.gd:83` | `replay_narration()` jamais appelée — ressemble à un bouton « rejouer la voix » jamais câblé | ✅ supprimée (décision par défaut, pas de bouton demandé — récupérable depuis `git log` si besoin plus tard) |
| 2.4 | `ui/bread.gd:41-43` | `_ready()` ne fait que `#_set_color()` (commenté) + `pass` : ne fait rien | ✅ supprimée |
| 2.5 | `popups/GenericConfirmationPopup.gd:3` | `@export var content = "" # (String, MULTILINE)` : annotation Godot 3 en commentaire, jamais migrée | ✅ `@export_multiline var content := ""` |
| 2.6 | `entities/Item.gd:30-33`, `popups/ItemPopup.gd:22-25` | `_ready(): pass # Replace with function body.` — résidu du gabarit par défaut de Godot | ✅ supprimées |

---

## 3 — Nommage — ✅ tout fait (2026-08-30)

| # | où | quoi | solution |
|---|---|---|---|
| 3.1 | `entities/ChapterChoice.gd:31` | `var COLOR_NOT_SET = Color('e0e2e5')` : nom ALL_CAPS sur une `var` alors qu'elle n'est jamais réassignée | ✅ `const COLOR_NOT_SET := Color('e0e2e5')` |
| 3.2 | `ui/nav_buton.gd:95,107` | `setDisabled()`/`setMirror()` : seules méthodes publiques camelCase de tout le dépôt hors tests | ✅ `set_disabled()`/`set_mirror()`, les 2 sites d'appel dans `ui/menu_page.gd` mis à jour |
| 3.3 | `ui/nav_buton.gd:24` | `signal _on_nav_pressed()` : le préfixe `_on_` est réservé aux handlers privés partout ailleurs | ✅ `pressed_for_navigation`, les 2 `.connect()` mis à jour |
| 3.4 | `ui/nav_buton.gd:115` | `emit_signal("_on_nav_pressed")` : seul appel par chaîne de caractères de tout le dépôt | ✅ `pressed_for_navigation.emit()` |
| 3.5 | `entities/EndingChoice.gd:41-46` | `set_ending_type()` compare `ending_type == 1` (commentaire `# GOOD` à côté) : nombre magique | ✅ `const ENDING_TYPE_GOOD := 1` / `ENDING_TYPE_BAD := 2` |

---

## 4 — Complexité / couplage

### 4.1 `autoload/combat_engine.gd:resolve()` — la fonction la plus complexe du dépôt — ✅ fait (2026-08-30, sur demande explicite)

- `resolve()` faisait ~120 lignes : calcul de l'assaut, les deux formes d'esquive, le
  plafond du PAYSAN, le coup fatal évité, le jet de survie du PRUDENT, et la transition vers
  l'ennemi suivant, tout dans une seule fonction. Cette entrée disait « à faire seulement à
  la prochaine règle de combat ajoutée, pas maintenant » — l'utilisateur a explicitement
  demandé de le faire quand même, pour préparer l'ajout de règles futures.
- **Fait**, en **3 fichiers** plutôt qu'en fonctions privées dans le même fichier (au-delà de
  la solution initialement envisagée ici) :
  - `autoload/combat_engine.gd` reste le seul autoload et garde tout l'état (`_enemy`, `_de`,
    `_tour`, ...) et toute l'API publique, **inchangée** — aucun appelant externe
    (`combat.gd`, `resource_gauge.gd`, `test_combat.gd`) n'a dû bouger.
  - `autoload/combat_table.gd` (`CombatTable`, `class_name`) — chargement/normalisation/
    lecture de `data/combat-table.json`, donnée statique sans état de combat.
  - `autoload/combat_assault_resolver.gd` (`CombatAssaultResolver`, `class_name`) — le
    calcul d'UN assaut, en 6 étapes nommées et **ordonnées** (`_etape_esquive_adresse`,
    `_etape_esquive_chance_prudent`, `_etape_armure`, `_etape_plafond_paysan`,
    `_etape_coup_fatal_evite`, `_etape_survie_prudent`) sur un objet `Assaut` partagé —
    l'en-tête du fichier explique où insérer un 5ᵉ pouvoir ou une 3ᵉ forme d'esquive, et
    pourquoi l'ordre n'est pas arbitraire.
- Suite `test_combat.gd` (40 tests) intégralement verte après coup, sans qu'aucun test
  n'ait eu besoin d'être modifié — la sortie de `resolve()` est identique bit à bit.
- ⚠️ **Piège rencontré, à connaître avant d'ajouter un autre fichier `class_name`** :
  `CombatTable`/`CombatAssaultResolver` ne sont résolus par leur nom que via
  `.godot/global_script_class_cache.cfg` (gitignoré), reconstruit par l'éditeur — **pas**
  par `godot --headless -s test/all.gd`. Une compilation a échoué ("Identifier ... not
  declared") jusqu'à un `godot --headless --editor --quit --path .` explicite. Documenté
  dans `autoload/README.md`.

### 4.2 `screens/about_menu.gd` — page « À propos » + fonctionnalité export/import complète — ✅ fait (2026-08-30)

- Le fichier faisait 225 lignes ; ~150 étaient entièrement l'export/import de sauvegarde en
  zip (dialogues, filtre MIME, confirmation), greffées sur le contrôleur de la page
  « À propos » qui n'a par ailleurs rien à voir avec la sauvegarde.
- **Fait** : extrait en `screens/save_export_import.gd`, un `Node` simple (pas de scène à
  lui, instancié en code) qu'`about_menu.gd` ajoute comme enfant et à qui il passe le
  conteneur de ses boutons via `setup()`. `about_menu.gd` retombe à ~75 lignes. Ni l'un ni
  l'autre n'est couvert par la suite automatisée — vérifié par un script de fumée
  instanciant `AboutMenu.tscn` en isolation (voir le commit).

---

## 5 — Références à `review.md` obsolètes dans les commentaires de code — ✅ fait (2026-08-30)

Trouvé le 2026-08-23 en réconciliant `review.md` avec ses renumérotations successives —
même défaut que celui déjà corrigé pour `succes_menu.gd` (§5bis/§5ter, todo 6.6), mais pas
balayé sur le reste du dépôt :

| fichier:ligne | citait | correction |
|---|---|---|
| `entities/LoreEntry.gd:9` | `review §6.1` (§ disparu) | ✅ `review.md` §1.2 |
| `entities/LoreEntry.gd:18` | `review §11.1` (jamais existé) | ✅ pointeur retiré, fait autonome |
| `screens/aventure_menu/global_completion.gd:6` | `review §6.1` | ✅ `review.md` §1.2 |
| `entities/EndingChoice.gd:17`, `entities/ChapterChoice.gd:11`, `ui/gauge_inside_circle.gd:11`, `ui/bread.gd:4` | `review §6.3` (§ disparu) | ✅ `review.md` §1.2 |
| `test/unit/test_player.gd:58` | `review §2.4` | ✅ pointeur retiré — vérifié dans `git log -p review.md` : c'était l'ancien §2.4 (« `Player._main` god-object bridge », ✅ FAIT 2026-08-10, purgé depuis), le fait qu'il documente (le signal `billy_changed`) tient seul |
| `ui/nav_buton.gd:6` | `review §2.6` | ✅ pointeur retiré — même vérification, ancien §2.6 (`window/stretch/mode`, ✅ FAIT 2026-08-10, purgé) |
| `entities/Item.gd:44` | `review §5.5` | ✅ pointeur retiré, fait autonome |

Vérifié après coup (`grep -rn "review §6\.1\|review §6\.3\|review §11\.1\|review §2\.4\|review §2\.6\|review §5\.5"`) :
plus aucune occurrence dans `*.gd`.

---

## 6 — `scripts/` (Python)

Les 7 fichiers (`generator.py` 533 lignes, `node.py` 327, `condition_node.py` 150,
`graph_render.py` 115, `graph.py` 26, `logger.py` 18, `endings.py` 4) lus en entier. Aucun
code mort (toute fonction/méthode non-dunder est appelée quelque part dans `scripts/`).
`condition_node.py`, `graph.py`, `logger.py`, `endings.py` : rien à signaler.

### 6.1 Un vrai relâchement dans le fail-fast que todo 3.2 venait d'installer — ✅ fait (2026-08-30)

- `node.py:227-230` (`get_all_possibles_goto`) : quand une clé de `conditions` n'est pas un
  entier, le code fait `print('ERROR: invalid condition jump')` puis `continue` — **sans
  `sys.exit(2)`**. C'est le seul endroit de tout `scripts/` où un message `ERROR:` n'arrête
  pas la compilation ; partout ailleurs (`generator.py` ×10, `node.py:196,202,254`) les deux
  vont toujours ensemble.
- Ça ne casse rien **aujourd'hui** : la clé fautive n'est jamais ajoutée à `goto`, donc jamais
  transformée en fils (`add_son`) ; `parse_conditions()`, appelée plus tard dans
  `ecrire_les_json()`, retombe dessus (`k not in sons_ids`) et sort bien en code 2. Mais c'est
  un hasard d'ordonnancement, pas une garantie lue au même endroit — et le message trompe :
  il a l'air de stopper la compilation, il ne le fait pas.
- **Fait** : `sys.exit(2)` ajouté juste après le `print`, avec le numéro de chapitre et la
  clé fautive dans le message. Les deux livres recompilent à l'identique.

### 6.2 Duplication : le même formatage de condition en texte, deux fois — ✅ fait (2026-08-30)

- `node.py:206` (`parse_conditions`) et `node.py:257` (`parse_stats_conditions`) : la même
  ligne, caractère pour caractère.
- **Fait** : `_expr_to_txt(expr: str) -> str` en fonction de module, appelée aux deux
  endroits.

### 6.3 Trois boucles séparées sur les mêmes nœuds pour construire trois ensembles — ✅ fait (2026-08-30)

- `generator.py:_valider_les_objets` : trois boucles `for node_id_str in book_data.keys():
  node = node_graph.get_node(int(node_id_str))`, une par ensemble (`all_conditions`,
  `all_aquire`, `all_remove`) — chacune refaisait le même lookup.
- **Fait** : une seule boucle alimente les trois ensembles à la fois.

### 6.4 Nommage : `set_sucess()` / `get_success()` — ✅ fait (2026-08-30)

- `node.py:148` déclarait `set_sucess()` (faute de frappe, un seul appelant), alors que le
  getter correspondant, `get_success()`, est bien orthographié.
- **Fait** : renommé en `set_success()`, l'unique appel mis à jour.

### 6.5 `graph_render.py` : accès direct à l'attribut *et* accesseur public pour le même champ — ✅ fait (2026-08-30)

- `_get_graph_from_nodes` lisait `node._arc` en accès direct mais `other.get_arc()` par
  l'accesseur — pour le **même champ**, sur deux `Node` différents, à trois lignes d'écart.
  `add_edges_to_display_graph` faisait pareil avec l'id.
- **Fait** : les deux comparaisons utilisent l'accesseur des deux côtés
  (`node._ending`, sans accesseur existant, reste en accès direct — cohérent avec le reste
  du fichier).

### 6.6 Un swap silencieux mais correct — à épingler avant qu'on le "corrige" par erreur — ✅ fait (2026-08-30)

- `node.py:get_computed()` (lignes 76-78) écrit `'chapter': self._arc` et
  `'arc': self._sub_arc` — en apparence inversé. C'est **juste**, vérifié contre
  `entities/chapter_data.gd:17,45,48` : le JSON compilé appelle "chapter" ce que le code
  Python et `review.md` appellent un **acte**, et "arc" ce qu'ils appellent un **sous-arc**.
  `Node._arc`/`get_arc()`/`set_in_arc()` portent donc en réalité l'acte, et
  `Node._sub_arc`/`get_sub_arc()` le sous-arc — le nom python et le nom JSON du même champ
  ne coïncident pas.
- Rien à corriger dans le comportement : `nodes_by_chapter` (généré depuis `get_arc()`) et
  `nodes_by_sub_arc` (depuis `get_sub_arc()`) sont cohérents, `test_book_data.gd` couvre le
  contrat. Le risque est qu'un futur passage de nettoyage, en lisant `'chapter':
  self._arc, 'arc': self._sub_arc` sans ce contexte, le lise comme une erreur et "répare" en
  inversant les deux — inversant alors tous les actes et sous-arcs du livre compilé, en
  silence (`test_book_data.gd` ne couvre que les valeurs neutres, pas cette correspondance
  précise).
- **Fait** : commentaire ajouté à l'endroit même du swap dans `get_computed()`. Les deux
  livres recompilent à l'identique.

---

## 7 — Revue fraîche du 2026-08-30, indépendante des dates de modification

À la demande de l'utilisateur, relecture complète des 42 `.gd` **sans présumer qu'un
fichier non modifié depuis le 2026-08-23 est encore à jour** — les 4 fichiers déjà relus le
2026-08-30 (`book_data.gd`, `player_stats.gd`, `chapter_data.gd`, `position.gd`, voir la
note en tête de fichier) et le reste, jusque-là seulement couverts par la lecture du 23.
Les trois points ci-dessous s'ajoutent à ceux déjà en §1-4.

### 7.1 `autoload/player.gd::jump_back()` — état à moitié détruit sur l'échec — ✅ fait (2026-08-30)

```gdscript
func jump_back(previous_id) -> bool:
	if session_visited_nodes.size() == 1:
		return false
	while not session_visited_nodes.is_empty():
		if session_visited_nodes.pop_back() == previous_id:
			return true
	push_warning("Player: chapitre de retour introuvable dans l'historique: %s" % previous_id)
	return false
```

- Le docstring promet : « Renvoie false s'il n'est pas du tout dans l'historique » — lu
  comme « rien ne bouge si ça échoue ». Faux : si `previous_id` n'est pas dans
  `session_visited_nodes`, la boucle le vide **entièrement** via `pop_back()` avant de
  renvoyer `false`. Le fil d'Ariane du Billy courant disparaît de la mémoire (pas du
  fichier de sauvegarde, `save_session_visited_nodes()` n'étant pas appelé sur ce chemin)
  sans qu'aucune valeur de retour ne le signale à l'appelant.
- **Pas un bug actif aujourd'hui** : le seul appelant trouvé, `CombatEngine.cancel()` (via
  `go_back_to()`), passe toujours un `previous_id` qui vient de
  `session_visited_nodes[-1]` — donc toujours présent, la branche destructrice n'est jamais
  prise en pratique.
- **Fait** : `rfind()` cherche l'index, `resize()` ne tronque le tableau qu'après avoir
  confirmé que `previous_id` y est — un échec ne touche plus rien. Couvert par les tests
  déjà existants (`test_go_back_to_refuse_un_chapitre_hors_historique`,
  `test_un_aller_retour_ne_gonfle_pas_les_stats`).

### 7.2 Blocs `combat` non validés à la compilation — le seul endroit où todo 3.2 n'est pas allé — ✅ fait (2026-08-30)

- `autoload/combat_engine.gd:126-133` (`read_enemies`) indexe `brut["nom"]`/`["hab"]`/
  `["pv"]`/`["arm"]`/`["deg"]`/`["pyro"]` sans `.get()` ni validation ; même motif côté
  lecture dans `entities/chapter_data.gd:122-138` (`_get_combat()` et ses 6 accesseurs).
- Le générateur Python (`scripts/node.py::set_combat()`) recopie le bloc `combat` d'un
  chapitre tel quel — contrairement à toutes les autres fautes de saisie que todo 3.2 a
  fermées (clé de chapitre, clé de stat, `success`, expression malformée). Une clé de
  combat mal orthographiée dans un livre (`"habilite"` au lieu de `"hab"`) compilerait sans
  erreur et ne se découvrirait qu'à l'exécution, en erreur GDScript générique
  d'indexation — au chapitre précis où un joueur la déclenche, pas à la compilation.
- **Fait, côté générateur** : `generator.py::_valider_le_combat()` vérifie que chaque
  adversaire (forme dict ou liste) porte exactement les 6 clés attendues, avant compilation.
  Les deux livres recompilent à l'identique — les 85 combats existants avaient déjà toutes
  les bonnes clés.

### 7.3 `succes_menu.gd` / `chapitres_menu.gd` : le câblage autour de `VirtualListPool` reste dupliqué — ✅ fait (2026-08-30)

- `_on_scroll_resized()`/`_ensure_pool()`/`_refresh_rows(force)` étaient quasi identiques
  dans les deux écrans (~15-20 lignes chacun), ne différant que par la variable de comptage
  passée au pool.
- **Fait** : `VirtualListPool` prend `item_count`/`update_row` (deux `Callable`) au
  constructeur, et porte lui-même `on_scroll_resized()`/`refresh_rows(force)` sans paramètre
  de compte. Les 3 wrappers ont disparu des deux écrans, qui connectent directement leurs
  signaux à `_pool.on_scroll_resized`/`_pool.refresh_rows`. Non couvert par la suite
  automatisée (jamais testé) — vérifié par un script de fumée instanciant les deux scènes à
  taille réelle et confirmant que le pool construit des lignes et survit à un défilement/
  redimensionnement.

### Vérifié propre au passage (pas des findings)

- `ui/resource_gauge.gd::_maximum()`/`_courant()` pour `Kind.ENNEMI` lisent respectivement
  `CombatEngine.get_enemy().get("pv", 0)` et `CombatEngine.get_enemy_pv()` — en apparence
  deux sources différentes pour le même adversaire. Vérifié contre
  `autoload/combat_engine.gd:166-168,509-510` : `_enemy` (le dictionnaire brut du chapitre)
  n'est **jamais** muté, seul `_enemy_pv` (une variable séparée) décrémente pendant le
  combat — le plafond lu depuis `_enemy["pv"]` reste donc juste le PV de départ. Pas un bug.
- `entities/EndingChoice.gd:49-54` (`_on_bouton_billy_pressed`/`_on_oups_pressed`) appelle
  `main.launch_new_billy()`/`main.jump_to_previous_chapter()` sans garde `if main != null:`,
  contrairement à `entities/success_item.gd:172-174` qui en a un. Vérifié dans
  `screens/aventure_menu/choice_next_chapiter.gd:63-71` : `set_main()` est **toujours**
  appelé avant `add_child()`, donc avant que le bouton devienne cliquable — l'asymétrie
  avec `success_item.gd` est une différence de style défensif, pas un chemin d'appel
  atteignable avec `main == null` aujourd'hui.

---

## Résumé pour la prochaine session

**2026-08-30 : le backlog entier de ce fichier est traité et commité**, y compris 4.1
(`combat_engine.gd` séparé en 3 fichiers, demandé explicitement par l'utilisateur alors que
cette entrée recommandait d'attendre). Seul **1.6** reste délibérément non fait
(`set_main` dupliqué×4, "pas une vraie duplication gênante", à ne factoriser qu'avec un 5ᵉ
cas). Tout le reste — 1.1 à 1.5, 1.7, 2.1-2.6, 3.1-3.5, 4.1, 4.2, §5, 6.1-6.6, 7.1-7.3 — est
✅. Suite Godot à 783 assertions, les deux livres recompilent à l'identique après chaque
changement côté générateur. 9 commits séparés au total, voir `git log` (à partir de
`a46f842`) pour le détail par lot ; `about_menu.gd` et les deux écrans-listes, jamais
couverts par la suite automatisée, ont chacun été vérifiés par un script de fumée jetable
avant son commit.

Une future session qui rouvre ce fichier n'a donc plus de backlog à piocher — seulement 1.6
à surveiller (agir seulement si un 5ᵉ setter du même genre apparaît) et, comme toujours, une
relecture de ce qui a changé depuis pour repérer de nouvelles pistes. Si un futur changement
touche `autoload/combat_engine.gd`, lire d'abord son en-tête et celui de
`combat_assault_resolver.gd` : la séparation en 3 fichiers et le cache de classes
(`.godot/global_script_class_cache.cfg`, voir `autoload/README.md`) y sont expliqués.

Cette revue de qualité/refactor couvre désormais l'intégralité du dépôt (42 `.gd` + 7 `.py`,
relus sans filtrer par date de modification, deux fois pour certains fichiers) — une future
session qui reprend ce fichier n'a plus besoin de repartir de zéro, seulement de relire ce
qui a changé depuis.
