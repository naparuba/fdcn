# Plan de test — FDCN

Basé sur l'analyse du pipeline Python (`fdcn.py`, `node.py`, `graph.py`, `condition_node.py`, `endings.py`) et de l'application Godot 3.6 (GDScript : `player.gd`, `Parameters.gd`, `BookData.gd`, `main.gd`, scènes UI).

Constat de départ : 1 seul fichier de test existant (`test/unit/test_player.gd`, 2 tests). Aucun test côté pipeline Python. Ce plan couvre les deux.

Priorités : **P0** = bug avéré ou silencieux à fort impact (corruption de données/état, crash), **P1** = risque de régression réel identifié dans le code actuel, **P2** = couverture de robustesse/nice-to-have.

---

## 0. Infrastructure nécessaire

| Côté | Outil | État |
|---|---|---|
| Python | `pytest` + `graphviz` | Installés dans `.venv/` (`python3 -m venv .venv && ./.venv/bin/pip install pytest graphviz`) |
| GDScript | GUT (`addons/gut`) | Présent, `test/integration/` créé (était référencé dans `test/all.tscn` mais absent) |
| Affichage | `xvfb-run` (`sudo apt install xvfb`) | Nécessaire pour lancer Godot (GUT et E2E) sans ouvrir de fenêtre ni voler le focus sur le poste du développeur — voir note ci-dessous |
| CI | — | Toujours aucune (pas de `.github/workflows`) — à ajouter séparément |

### Comment lancer les tests

Définir une fois `GODOT_BIN` (chemin vers le binaire Godot 3.6.2, propre à chaque poste) :

```bash
export GODOT_BIN=/path/to/Godot_v3.6.2-stable_x11.64
```

**IMPORTANT — `xvfb-run` par défaut** : Godot (même en mode test/script) ouvre une vraie fenêtre X11. Sur un poste de développeur avec un bureau graphique, la lancer sur le `DISPLAY` réel (`:0`) fait apparaître la fenêtre et **vole le focus**. `xvfb-run` la fait tourner dans un serveur X virtuel (framebuffer invisible) : aucune fenêtre, aucun vol de focus, et le rendu (nécessaire aux captures E2E) fonctionne quand même.

Le écran virtuel par défaut de `xvfb-run` (1280×1024) est **plus bas** que la fenêtre du jeu (558×1046, cf `project.godot`) : sans `--server-args` explicite, Godot redimensionne discrètement sa fenêtre pour rentrer dans l'écran virtuel, ce qui décale légèrement le rendu capturé. Toujours préciser une taille d'écran virtuel confortablement plus grande :

```bash
# Python (unitaires + intégration pipeline)
./.venv/bin/python -m pytest tests/ -v

# GDScript (unitaires + intégration Godot) -- IMPORTANT: XDG_DATA_HOME
# isole les fichiers user:// dans un répertoire temporaire, pour ne jamais
# écraser une vraie sauvegarde de développeur sur cette machine.
XDG_DATA_HOME=$(mktemp -d) xvfb-run --auto-servernum --server-args="-screen 0 1920x1080x24" \
  "$GODOT_BIN" --path . -s addons/gut/gut_cmdln.gd -gdir=res://test/unit,res://test/integration -gexit
```

---

## 1. Tests unitaires — Pipeline Python

### 1.1 `condition_node.py` — Parseur d'expressions (P0)

C'est le composant le plus mécanique et le plus testable en isolation (pas de dépendance I/O). Prioritaire car une régression ici fausse silencieusement toutes les conditions du jeu.

- `parse_expr_simple` : un simple token → `ConditionNode` sans enfants
- `parse_expr_complex` :
  - `A & B` → `$and`
  - `A | B` → `$or`
  - `A & B & C` (chaînage) → arbre correctement associé
  - `(A & B) | C` — parenthèses + priorité
  - `A & (B | C)` — parenthèses imbriquées
  - `((A|B)&(C|D))` — 2 niveaux de parenthèses (vérifier avant la limite empirique de 60 rencontrée dans `set_in_sub_arc`)
  - Cas d'erreur : `)` en excès → doit lever/`exit(2)` proprement (tester via `pytest.raises` ou capture de `SystemExit`)
  - Cas d'erreur : `&` ou `|` sans opérande (ex. `& ITEM`) — **actuellement risque de laisser un nœud vide silencieusement** ⇒ test qui verrouille le comportement voulu (erreur explicite, pas silence)
  - `to_json()` : vérifier la sérialisation exacte (`$or`/`$and`/`$end`) pour chaque cas ci-dessus

### 1.2 `node.py` — Logique du nœud (P0/P1)

- `get_all_possibles_goto()` (P0) : fusion goto statique + conditions + secret_jumps
  - goto seul (int) → liste à 1 élément
  - goto liste
  - conditions ajoutant des destinations non présentes dans goto
  - secret_jumps ajoutant des destinations
  - déduplication si une destination est présente dans plusieurs sources
- `parse_conditions()` (P0) : condition référençant un ID qui n'est pas un fils réel → doit échouer explicitly (actuellement `exit(2)`, à convertir en exception testable)
- `parse_stats_conditions()` (P1) : mêmes cas que `parse_conditions` mais pour les stats conditionnelles
- `set_in_arc()` (P1) : propagation descendante, une seule assignation par nœud — test qu'un nœud avec deux parents de deux arcs différents garde l'arc du **premier** visité (ordre `reversed`), pas overwrite
- `set_in_sub_arc()` (P1) : comportement à la limite de récursion (actuellement une limite arbitraire ~60) — test avec une chaîne artificiellement longue (mock) pour vérifier qu'on échoue proprement plutôt qu'un comportement erratique
- `set_in_sub_arc_not_recursive()` (P2) : override manuel appliqué correctement, n'écrase pas un tag existant sans raison

### 1.3 `fdcn.py` — Orchestration/validation globale (P0/P1)

Actuellement peu unitaire (script procédural) — recommandation : extraire la logique de validation dans des fonctions pures testables (`validate_objects_consistency(nodes, all_objects)`, etc.) avant de tester. À défaut, tester via les scénarios d'intégration (section 2).

- Validation objets (P0) : un item utilisé en `aquire`/`remove`/condition mais absent de `.all_objects.json` → doit bloquer la compilation (actuellement le cas symétrique — item déclaré mais jamais utilisé — n'est pas forcément une erreur bloquante ; à clarifier et verrouiller par un test)
- **Bug silencieux identifié** : un item référencé dans une condition mais jamais acquis nulle part (`conditions_not_aquire`) n'est **que loggé**, pas bloquant (P0 — décider si c'est un vrai bug de contenu à corriger dans les données, et si oui, transformer le warning en échec de build testé)
- Nœud hardcodé `608` comme fin de livre 1 (P1) : test que le livre 2 ne dépend pas de cet ID, et qu'un changement de structure du livre 1 ne casse pas silencieusement cette référence
- `ending_id` / `ending_txt` manquants (P0) : nœud marqué `success`/fin sans ces champs → doit échouer à la compilation plutôt que produire `None` (qui fait crasher l'UI Godot plus tard)

### 1.4 `graph.py` (P2)

Conteneur simple — tests basiques : ajout de nœud, récupération par ID, ID inexistant lève une erreur claire.

---

## 2. Tests d'intégration — Pipeline Python

Le plus grand gain de confiance pour un coût raisonnable : compiler les vraies données (`fdcn-1.json`, `fdcn-2.json`) de bout en bout et vérifier des invariants globaux.

| # | Scénario | Vérifie | Priorité |
|---|---|---|---|
| I-1 | Compiler livre 1 et livre 2 en entier (`fdcn.py --book 1`, `--book 2`) sans erreur | Le pipeline tourne de bout en bout sur les vraies données actuelles (régression de base) | P0 |
| I-2 | Aucun nœud orphelin | Tout nœud (sauf racine) est atteignable depuis le nœud 1 par au moins un chemin (goto/condition/secret) | P0 |
| I-3 | Aucun cycle infini dans la propagation d'arc/sub-arc | `set_in_arc`/`set_in_sub_arc` terminent sur le vrai graphe (pas de hang) — actuellement aucune détection de cycle | P0 |
| I-4 | Cohérence objets globale | Tout objet dans `.all_objects.json` est bien acquis au moins une fois ET toute condition référence un objet qui est acquis ailleurs dans le graphe (zéro `conditions_not_aquire` sur les données réelles) | P0 |
| I-5 | Chaque nœud avec conditions a une branche par défaut accessible | Pas de joueur bloqué : au moins un chemin de sortie valable indépendamment de l'état (sauf fins volontaires) | P1 |
| I-6 | Fins (`endings.py` + nœuds `success`) | Chaque fin a un `ending_id`, un type (bonne/mauvaise) cohérent avec `ENDINGS`, pas de doublon d'ID | P0 |
| I-7 | Secrets à source unique | Les nœuds secrets sans multi-source ne lèvent pas de warning ; ceux qui en ont un sont bien intentionnels (liste connue en dur dans le test, à faire valider par l'auteur) | P1 |
| I-8 | Stabilité des fichiers compilés | Comparer les JSON générés à une référence figée (snapshot) pour détecter toute régression non intentionnelle lors d'un refactor du pipeline | P1 |
| I-9 | Génération du graphe visuel | `graph/fdcn_full-N.png` se génère sans erreur graphviz (dépendance système `dot` présente) | P2 |

---

## 3. Tests unitaires — GDScript (GUT)

### 3.1 `player.gd` — cœur métier (P0, le plus critique)

- **Type de Billy** (`compute_my_billy_for_option`)
  - 0 item → `pégu`
  - 1 arme + 1 équipement + 1 outil → `débrouillard`
  - ≥2 armes (+1 autre) → `guerrier` (cas déjà couvert par le test existant, à garder)
  - ≥2 équipements → type équipement correspondant
  - 4e item ajouté → `clean_billy_overload()` retire le bon item (le plus ancien ? le moins pertinent ? — **vérifier la règle réelle et la verrouiller par un test**, actuellement risque d'ambiguïté)
- **Stats** (`_recompute_stats`)
  - Stats de base par type de Billy (chaque type testé individuellement : guerrier +2 hab, paysan +2 end, etc.)
  - Stats items : ajout/retrait d'un item modifie `*_items` et le total, retrait total revient à l'état initial
  - **Stats chapitres ne doublent pas au reload** (P0 — bug déjà corrigé une fois selon l'historique git ; test de non-régression explicite : visiter un chapitre, sauvegarder, recharger, `end_chapters` inchangé)
  - Stats chapitres jamais soustraites (comportement actuel "ADD only") — test qui documente ce comportement pour qu'un futur retrait de stats ne soit pas silencieusement ignoré
- **Navigation** (`go_to_node`)
  - Nouveau nœud pour ce Billy → stats chapitre appliquées, retour `is_new=true`
  - Nœud déjà visité dans la session courante → stats **non** ré-appliquées, `is_new=false`
  - Retour correct des `aquires`/`removes` du nœud
- **Reset de partie** (`launch_new_billy`)
  - `session_visited_nodes` et `possessed_items` vidés
  - `visited_nodes_all_times` **conservé** (comportement voulu, à verrouiller)
  - Stats items/base réinitialisées à zéro avant réapplication du type par défaut
- **Persistance** (`do_load`/`do_save`, P0)
  - Cycle save → reload produit un état strictement identique (nœud courant, items possédés, stats, historique) — c'est LE test d'intégration le plus rentable, voir section 4
  - Migration ancienne sauvegarde `.save` → nouveau format JSON : données préservées, ancien fichier nettoyé une seule fois
  - Idempotence : lancer `do_load()` deux fois de suite ne duplique rien
- **Migration book-2 one-time** (`_assert_bug_book_2_preload_is_fixed`, P1)
  - Premier appel avec fichiers orphelins présents → nettoyés, flag posé
  - Second appel → aucune action (flag déjà présent)
  - Appel avec flag absent mais fichiers déjà absents → ne crashe pas, pose le flag quand même

### 3.2 `Parameters.gd` (P1)

- Changement de livre (1 ↔ 2) : les getters (`get_book_number`, chemins de fichiers) reflètent bien le nouveau contexte
- Options son/spoils : persistées et rechargées correctement
- Isolation entre tests : **actuellement singleton global mutable** — chaque test GUT doit explicitement reset `Parameters`/`Player` en `before_each`/`after_each` pour éviter la pollution inter-tests (risque déjà identifié par l'agent d'exploration UI)

### 3.3 `BookData.gd` (P1)

- Chargement livre 1 vs livre 2 : bons fichiers compilés chargés, caches (`chapters_by_arc`, `chapters_by_sub_arc`, `all_objects`) cohérents avec les données sources
- `match_chapter_conditions()` : condition remplie/non remplie selon `possessed_items` + type de Billy, y compris cas combinés `&`/`|` réels tirés des données du livre

### 3.4 `chapter_data.gd` / `Item.gd` (P2)

- Getters exposent bien les champs bruts du JSON compilé (test de contrat, un par champ critique : stats, aquire, remove, combat)
- `Item.gd` : un item est affiché si possédé OU spoils actif OU chapitre contenant l'item déjà visité — tester les 3 branches indépendamment

---

## 4. Tests d'intégration — GDScript / Godot (le plus important selon la demande)

GUT permet d'instancier de vraies scènes (`add_child_autofree`), de mocker des autoloads (`double_script`) et de dérouler des scénarios multi-étapes — donc des tests d'intégration réels sont possibles, avec les limites suivantes constatées : pas de simulation tactile réaliste (à contourner en appelant directement les handlers), pas de rendu visuel vérifiable (on teste l'état, pas le pixel).

### 4.1 Cycle de vie complet du joueur (P0)

> Le scénario le plus important, mentionné explicitement comme fragile dans l'historique (bug de stats dupliquées déjà corrigé une fois).

1. `launch_new_billy()` → état initial connu
2. Visiter une séquence de chapitres réels (ex. les 5 premiers nœuds du livre 1) via `Player.go_to_node()`
3. Acquérir/perdre des objets déclenchés par ces chapitres
4. Sauvegarder (`do_save`)
5. Simuler un redémarrage : nouvelle instance logique, `do_load()`
6. **Assertion** : nœud courant, items possédés, toutes les stats (base/items/chapitres), type de Billy, historique — strictement identiques avant/après reload

### 4.2 Migration d'ancienne sauvegarde (P0)

1. Poser manuellement d'anciens fichiers `.save` (ancien format, éventuellement sans suffixe de livre) dans le répertoire user
2. Démarrer le chargement (`do_load`)
3. Vérifier que l'état migré correspond à ce que l'ancien format représentait, que les anciens fichiers sont nettoyés, et que relancer le chargement une seconde fois ne change plus rien (idempotence)

### 4.3 Navigation UI bout-en-bout (P0/P1)

1. `main._ready()` sur une scène réelle (`add_child_autofree(main_scene)`) avec `Player`/`BookData` réels (pas mockés, pour un vrai test d'intégration) mais sur un run isolé (répertoire user temporaire)
2. Vérifier l'affichage initial (nœud 1, breadcrumbs vides, jauge à l'état initial)
3. Appeler le handler de clic d'un `ChapterChoice` (directement, sans simulation tactile) → vérifier `Player.go_to_node` appelé, `refresh()` a bien mis à jour breadcrumbs/jauge/popup d'item le cas échéant
4. Atteindre un nœud de fin → `EndingChoice` instancié avec le bon type (bonne/mauvaise fin)
5. Déclencher "Nouvelle partie" via le popup de confirmation → vérifier reset complet et retour au nœud 1

### 4.4 Changement de livre FDCN ↔ CDSI (P1)

1. Démarrer sur livre 1, visiter quelques nœuds, acquérir un item
2. Basculer vers livre 2 (`Parameters.set_book_number` + rechargement `BookData`)
3. Vérifier que les données affichées sont bien celles du livre 2, qu'aucune stat/nœud du livre 1 ne "fuite" dans le contexte livre 2, et que revenir au livre 1 restaure l'état livre 1 intact
4. **Point identifié comme fragile** : stats de chapitre potentiellement non isolées entre livres — ce test doit explicitement vérifier l'isolation

### 4.5 Cohérence type de Billy / stats de chapitre après changement de type (P1)

1. Visiter un chapitre dont une stat est conditionnelle au type de Billy (ex. bonus si `GUERRIER`)
2. Changer de type de Billy via retrait d'objet (sans revisiter le chapitre)
3. Documenter le comportement actuel par un test explicite (les stats du chapitre ne sont **pas** recalculées rétroactivement) — ce test sert de garde-fou : si quelqu'un "corrige" ce comportement plus tard, le test échoue et force une décision consciente plutôt qu'une régression silencieuse

### 4.6 Compilation → Application (test d'intégration croisé pipeline/app, P1)

1. Générer les fichiers compilés via `fdcn.py --book 1` dans un environnement de test
2. Charger ces fichiers dans `BookData` (Godot) et vérifier qu'ils sont bien consommés sans erreur de parsing, sur un échantillon représentatif de nœuds (avec conditions, combats, secrets, items)
3. Détecte les régressions de contrat entre le format produit par le pipeline et ce que l'app attend (le point de couture le plus dangereux entre les deux parties du projet, actuellement non testé du tout)

### 4.7 Son (P2)

- `Sounder.play()` appelé deux fois rapidement → pas de crash, dernier son gagne (documente le comportement non thread-safe actuel plutôt que le corriger dans ce plan)
- Son d'intro correct selon le livre (FDCN vs CDSI)

### 4.8 Boutons Spoils / Son du bandeau supérieur (P1)

**Implémenté** — `test/integration/test_top_menu_buttons.gd` instancie le vrai `main.tscn` (pas un double de main comme les tests unitaires de `top_menu.gd`) :
1. `main.tscn` a 5 instances de `top_menu.tscn` (une par page) : cliquer le bouton sur l'une doit synchroniser les 4 autres via `refresh()`
2. Spoils off + chapitre secret jamais vu → `ChapterChoice.spoil_enabled` reste `false` dans la vraie liste "Tous les chapitres" ; déjà vu → reste `true` même sans spoils
3. Son off → se répercute jusqu'à `Sounder.is_enabled() == false` ET empêche réellement une lecture (`Sounder.player.playing == false`), pas juste un flag isolé
4. Les handlers `_on_spoil_button_toggled`/`_on_sound_button_toggled` (connectés aux vrais signaux des boutons) délèguent bien à `main.change_spoils`/`change_sound`

Piège rencontré : instancier `main.tscn` complet (606 `ChapterChoice` + tout le catalogue d'objets) coûte cher — le faire dans `before_each()` (8 tests) faisait timeout au-delà de 30s. Déplacé en `before_all()`/`after_all()` (une seule instance pour tout le fichier), le reste (spoils/son) réinitialisé en `before_each()`/`after_each()`.

---

## 5. Tests end-to-end / visuels

Contrairement à une approche qui se contenterait de l'état logique, on veut ici de vrais tests qui font tourner **le jeu réel** (le même binaire Godot 3.6.2 que celui utilisé en prod, pas un mock) et vérifient ce qui apparaît réellement à l'écran. Ce n'est possible qu'*après* que les couches unitaire et intégration (logique pure) soient vertes — les tests visuels sont chers (lents, plus fragiles aux changements de layout) et ne doivent pas porter la charge de vérifier la logique métier, seulement le rendu.

### 5.1 Principe technique

- Godot 3.6 headless (`--headless`/serveur) **ne rend rien** : pas de GPU, pas de screenshot possible. On utilise donc le binaire GUI réel (`Godot_v3.6.2-stable_x11.64`) piloté avec un `DISPLAY` X11 (confirmé disponible dans cet environnement, `DISPLAY=:0`) — soit le display réel, soit un `Xvfb` dédié en CI pour l'isolation.
- Un **runner de scénario** embarqué dans le projet (autoload activé seulement via une option `--e2e-script=<path>` ou variable d'env `FDCN_E2E_SCRIPT`) : au lieu de simuler des événements X11 bas niveau, il pilote l'appli **par les mêmes points d'entrée que l'UI** (`main.go_to_node()`, clic sur `ChapterChoice`, etc. — donc du vrai code de prod, pas un événement OS simulé), mais restitue un vrai rendu puisque le jeu tourne pour de vrai.
- Après chaque étape du scénario, capture d'écran via `get_viewport().get_texture().get_data()` → `Image.save_png()` dans `test/e2e/screenshots/actual/<nom_etape>.png`.
- **Comparaison golden image** : script Python (`tests/e2e/compare_screenshots.py`, Pillow) qui diffe `actual/` vs `golden/` avec un seuil de tolérance (anti-aliasing/police) et remonte un pourcentage de pixels différents + une image de diff visuelle en cas d'échec.
- Les golden images sont committées dans le repo (`test/e2e/screenshots/golden/`) et régénérées consciemment (`--update-golden`) après une revue humaine d'un changement visuel volontaire — jamais auto-régénérées par la CI.

### 5.2 Scénarios E2E prioritaires

| # | Scénario | Vérifie visuellement |
|---|---|---|
| E-1 | Démarrage nouvelle partie | Écran principal, chapitre 1, breadcrumbs vides, jauge à l'état initial — pas de texture manquante (carré magenta Godot), pas de layout cassé |
| E-2 | Navigation vers un chapitre avec choix multiples | `ChapterChoice` bien rendus (texte, icônes de condition/combat visibles) |
| E-3 | Acquisition d'objet | `ItemPopup` apparaît avec la bonne icône/couleur, disparaît après ~3s |
| E-4 | Écran de fin (bonne/mauvaise fin) | `EndingChoice` avec la bonne couleur/icône selon le type, boutons visibles |
| E-5 | Écran Succès / Lore | Icônes de succès débloqués vs verrouillés, fiches de personnage avec image correcte |
| E-6 | Changement de livre FDCN ↔ CDSI | Assets (icônes, couleurs, titres) bien basculés, pas de résidu visuel de l'autre livre |
| E-7 | Popup de confirmation reset | Rendu correct, bouton Accept déclenche bien le reset (vérifié à la fois visuellement et sur l'état après) |
| E-8 | Boutons Spoils / Son du bandeau supérieur | Bouton visuellement ON/OFF, et effet réel : sans spoils, les tags Combat/Fin/Succès/Secret et les labels de chapitre disparaissent de toute la liste "Tous les chapitres" (pas juste sur un secret isolé) |

### 5.3 État d'implémentation

Infrastructure posée et vérifiée avec de vraies captures (voir `test/e2e/`) :
- `test/e2e/e2e_runner.tscn` + `.gd` : instancie le vrai `main.tscn`, joue un scénario JSON, capture des PNG réels via `get_viewport().get_texture()`. Actions disponibles : `wait_frames`, `go_to_node`, `add_item`/`remove_item`, `launch_new_billy`, `show_options`/`validate_options`, `focus_page`, `change_book`, `open_new_billy_popup`/`accept_new_billy_popup`, `screenshot`. Avant chaque capture, le runner attend explicitement (au lieu de deviner un nombre de frames fixe) :
  - que la caméra (smoothing activé sur `main.tscn`, `smoothing_speed=20`) ait fini de glisser vers sa position cible — un `wait_frames` fixe s'est révélé insuffisant pour les grands déplacements (main → succès/lore/à propos), produisant des captures "en pleine transition" ;
  - que `$SuccessPopup` (déclenché par TOUT chapitre qui est à la fois une fin et un succès — c'est le cas de chacune des 11 bonnes fins du livre 1) ait atteint le plateau stable de son animation "show" (5s, fondu sur les 2 premières secondes) plutôt que de capturer en plein fondu.
- `test/e2e/scenarios/` (8 scénarios, E-1 à E-7) : chacun passe maintenant par l'écran Options + validation (comme un vrai joueur qui choisit son équipement) avant de naviguer, condition nécessaire pour que `$ItemPopups` (caché par défaut dans la scène) soit visible et que les popups d'acquisition d'objet s'affichent réellement. Le chapitre choisi pour la démo d'acquisition d'objet (106) est volontairement un chapitre qui N'EST PAS aussi un succès, pour ne pas être parasité par `$SuccessPopup` (dont l'attente de ~5s ferait sinon disparaître le popup d'objet, qui a son propre timer d'auto-fermeture à 3s).
- `test/e2e/screenshots/golden/` : 12 images de référence, revues visuellement.
- `tests/e2e_compare_screenshots.py` : diff Pillow avec seuil de tolérance, `--update-golden` pour resynchroniser après revue.

**Toujours lancer via `xvfb-run`** (voir §0) pour ne jamais voler le focus sur le poste du développeur, avec un écran virtuel explicitement plus grand que la fenêtre du jeu (558×1046) :
```bash
XDG_DATA_HOME=$(mktemp -d) xvfb-run --auto-servernum --server-args="-screen 0 1920x1080x24" \
  "$GODOT_BIN" --path . test/e2e/e2e_runner.tscn -- \
  --e2e-script=res://test/e2e/scenarios/navigation_choix_multiples.json \
  --e2e-out=res://test/e2e/screenshots/actual
./.venv/bin/python tests/e2e_compare_screenshots.py
```

Scénarios E-4 à E-7 (fins, succès/lore, changement de livre, popup de reset) : mécanisme identique, juste ajouter un fichier JSON dans `scenarios/` — non couverts encore par manque de temps, mais le pipeline est prêt.

### 5.4 Limites assumées même pour l'E2E

- Pas de vérification de timing d'animation frame-par-frame (juste l'état stabilisé après un court délai) — trop fragile pour la valeur apportée
- Pas de test sur build Android réel (SDK, permissions) — reste hors périmètre, testable uniquement manuellement sur device
- Simulation d'entrée tactile bas niveau (vrai swipe du doigt) non reproduite ; on pilote via les handlers de haut niveau, qui déclenchent le même code que l'input réel

---

## 6. Ordre de mise en œuvre recommandé

1. **P0 Python** : `condition_node.py` (parseur) + scénarios d'intégration I-1 à I-4, I-6 — verrouille la donnée source, le plus gros risque de bug silencieux
2. **P0 GDScript** : cycle save/reload (4.1) + non-régression stats chapitre dupliquées (3.1) — verrouille un bug déjà survenu une fois
3. **P0 GDScript** : migration ancienne sauvegarde (4.2) — verrouille une migration en cours, risque élevé si des utilisateurs ont encore l'ancien format
4. **P1** : navigation UI bout-en-bout (4.3), multi-livre (4.4), reste des unitaires `player.gd`/`BookData.gd`
5. **P1** : test croisé pipeline → app (4.6) — comble le trou de test le plus structurel (aucun lien testé entre les deux parties du projet)
6. **P2** : reste (graph.py, Sounder, Item.gd affichage)
7. **E2E** (§5) : uniquement une fois 1-5 verts — capture des scénarios E-1 à E-7, génération des golden images de référence après revue humaine

---

## 7. État final de couverture (implémenté)

| Côté | Fichiers | Tests |
|---|---|---|
| Python (unitaire + intégration pipeline) | `condition_node.py`, `node.py`, `graph.py`, `endings.py` + intégration `fdcn.py` (livre 1 et 2, subprocess) | 88 |
| GDScript unitaire | 22 fichiers dans `test/unit/` — couvre `player.gd`, `Parameters.gd`, `BookData.gd`, `Item.gd`, `ItemPopup.gd`, `ChapterChoice.gd`, `EndingChoice.gd`, `Success.gd`, `SuccessPopup.gd`, `LoreEntry.gd`, `bread.gd`, `top_menu.gd`, `swipe.gd` (Swiper), `Sounder.gd`, `utils.gd`, `GenericConfirmationPopup.gd`, `gauge_inside_circle.gd`, `going_to_line.gd`, `left_backer.gd` | 157 |
| GDScript intégration | `test/integration/` : cycle save/reload complet, migration ancienne sauvegarde, boutons Spoils/Son via le vrai `main.tscn` | 17 |
| E2E visuel | `test/e2e/` : 9 scénarios (E-1 à E-8), 16 golden images | — |

**Non couvert** : `main.gd` n'a pas de test unitaire dédié (orchestrateur épais, fortement couplé à Player/BookData/Swiper — mocker massivement ces singletons serait nécessaire), mais est maintenant exercé en intégration (boutons Spoils/Son, §4.8) et en E2E. Build Android réel. Timing d'animation frame par frame (sauf le plateau stable de `SuccessPopup`, explicitement attendu par le runner E2E).

### Bugs trouvés en écrivant ces tests

| # | Bug | Sévérité | Statut |
|---|---|---|---|
| 1 | `fdcn.py --book 1` crashe (`KeyError: 608`, sentinel de fin de livre devenu du code mort après le refactor CDSI) | Bloquant pour la maintenance des données livre 1 | **Corrigé** — détection de "ending" déplacée avant tout traitement de `goto`, indépendante du sentinel 608/de l'absence de `goto` (voir détail ci-dessous) |
| 2 | Livre 2 (CDSI) : 16 chapitres de fin perdent silencieusement leur statut de fin (même cause racine) — **déjà présent dans les données commitées actuelles** | Bug live en production | **Corrigé** (même fix que #1) |
| 3 | `player.gd::_fully_reset_our_stats()` oubliait `end_chapters`, `pv_max_bonus`, `nb_infos` — fix incomplet du bug historique "stats infinies" (commit `95ec4c3`) | Stats gonflées entre parties | **Corrigé** |
| 4 | `gauge_inside_circle.gd::set_parameters()` fait `self.color = ...`, propriété qui n'existe pas sur `Node2D` → erreur script à l'exécution | Faible (fonction jamais appelée ailleurs, code mort) | Signalé, non corrigé |
| 5 | `EndingChoice.tscn` : le texte du ruban ("Bonne fin") est codé en dur dans la scène et n'est jamais mis à jour selon le type de fin — seule la couleur change. Une **mauvaise** fin affiche un ruban orange qui dit "Bonne fin" | Cosmétique mais trompeur pour le joueur, trouvé uniquement grâce aux captures E2E | Signalé, non corrigé |
| 6 | `player.gd::insert_all_objects()` fuyait des nœuds `Item` (Node non comptés par référence en Godot 3.x) à chaque appel sans écran principal (cas des tests) | A rendu la suite de tests complète gourmande en RAM (~plusieurs Go) au point de menacer la machine hôte | **Corrigé** (+ réduction du nombre d'appels côté tests, `before_each` → `before_all` là où c'est possible) |

Pic mémoire mesuré après corrections pour la suite GDScript complète (166 tests) : **~227 Mo**.

### Détail du fix #1/#2 (`fdcn.py`)

Root cause commune : `get_all_possibles_goto()` transforme toujours `goto` en liste, rendant mort le `if isinstance(goto, int)` qui gérait le cas "fin de livre" (sentinel `608` pour le livre 1, absence totale de `goto` pour le livre 2/CDSI). Vérifié sur les données réelles : le livre 1 a 19 nœuds avec une clé `"ending"`, **tous** avec `"goto": 608` ; le livre 2 en a 16, **tous sans** clé `"goto"`. Aucun des deux ne mélange les conventions, et aucun nœud de fin n'a de `secret_jumps`/`conditions`.

Le fix détecte maintenant une fin via la présence de la clé `"ending"` **avant** tout traitement de `goto`, indépendamment de sa forme — ce qui gère les deux conventions uniformément sans branchement sur `book_number`. Un garde-fou explicite est conservé si `goto: 608` apparaît sans clé `"ending"` (erreur de données).

Vérifié : les deux livres compilent (exit 0), 19 et 16 fins détectées respectivement (comptes attendus), aucun nœud orphelin, et le livre 1 recompilé est identique au fichier actuellement commité à un détail près : un doublon (`185` apparaissant deux fois dans les fils des nœuds 33/34) présent dans la donnée source `fdcn-1.json` elle-même est maintenant dédupliqué (effet de bord du merge via `get_all_possibles_goto`, déjà utilisé pour les nœuds non-terminaux avant ce fix) — amélioration, pas une régression.

**Décision encore ouverte** : les fichiers `fdcn-{1,2}-compilated-*.json` et `graph/fdcn_full-{1,2}.png` actuellement commités dans le repo n'ont pas été régénérés/écrasés par ce fix (changement de données livrées = décision séparée). Le pipeline peut désormais les régénérer correctement pour les deux livres à la demande.
