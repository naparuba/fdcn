# Journal de migration Godot 3.6.2 -> Godot 4.7

Voir le plan complet dans `/home/jgabes/.claude/plans/abundant-soaring-spark.md` (hors du repo,
côté outillage). Ce fichier journalise l'exécution réelle, phase par phase, avec les résultats de
vérification obtenus (pas juste "fait").

## Phase 0 — Référence "avant" (2026-07-09, sur `main`, Godot 3.6.2)

- Suite GDScript (GUT, `test/unit` + `test/integration`) : **33 scripts, 223 tests, 501 assertions,
  0 échec**. Commande :
  `xvfb-run ... Godot_v3.6.2-stable_x11.64 --path . -s addons/gut/gut_cmdln.gd -gdir=res://test/unit,res://test/integration -ginclude_subdirs -gexit`
- Suite Python (pytest, `tests/`) : sous-ensemble rapide (`test_condition_node.py`, `test_node.py`,
  `test_graph.py`, `test_endings.py`) = **75 passed**. `test_pipeline_integration.py` (13 tests,
  lents car chaque test relance `fdcn.py` + rendu graphe) déjà validé dans son intégralité plus tôt
  dans la session de travail (88/88 au total pour la suite Python complète) ; relancé en arrière-plan
  pour reconfirmation au moment de cette entrée de journal.
- E2E : 22 images golden committées dans `test/e2e/screenshots/golden/`, 14 fichiers de scénario
  dans `test/e2e/scenarios/` (couvrant E-1 à E-12, `fin_bonne`/`fin_mauvaise` comptés séparément
  sous E-4). Dernière validation complète (capture + diff Pillow) faite plus tôt dans la session,
  avant le début du travail de migration — pas rejouée intégralement à cette étape (coûteux, aucun
  changement de code depuis cette dernière validation).
- Branche de travail : `migration-godot4` (créée depuis `main`, vide). `main` reste inchangé.

**Référence à battre pour la Phase 9 (bascule finale)** : 223 tests / 501 assertions GDScript,
88 tests Python, 13 scénarios E2E — aucun chiffre ne doit descendre en dessous après la migration.

## Phase 1 — Conversion mécanique + fixes manuels (2026-07-09, en cours)

- `--validate-conversion-3to4` puis `--convert-3to4` : 539 fichiers touchés, commit isolé. Pièges
  anticipés confirmés à l'identique (idle_frame cassé dans exactement les 3 fichiers prédits).
- **[RÉVISÉ]** Décision de format de sauvegarde changée en cours de route : JSON devient le format
  primaire (pas le binaire), avec fallback binaire à usage unique — voir décision #1 révisée dans le
  plan. Implémenté dans `player.gd`/`Parameters.gd` (`_load_var`/`_save_var`), plus
  `utils.gd::ints_from_json()` partagé (JSON n'a pas de type entier distinct).
- Bugs réels trouvés en testant le vrai boot Godot 4 (au-delà de l'inventaire initial) :
  - `Directory.new()` → convertisseur produit `DirAccess.new()`, invalide (API statique requise).
  - `utils.gd::load_json_file()` : convertisseur laissait du code référençant `.error`/`.result`
    sur un objet qui ne les a plus — cassé, réécrit.
  - `BookData.gd::get_node()` et `Item.gd::get_name()` entrent en collision avec des méthodes
    natives de `Node` en Godot 4 (erreur bloquante au chargement) — renommés
    `get_chapter_data()`/`get_item_name()` partout (app + tests).
  - `fonts/RobotoCondensed-Regular.ttf.import` resté sur `importer="keep"` (config Godot 3) après
    la conversion CLI — le texte des `.tres` est bien renommé `DynamicFont`→`FontFile` mais pas la
    config d'import du fichier source lui-même. Fixé via suppression + `--import`.
  - `utils.gd::load_external_texture()` : `Texture.get_data()` → `get_image()`,
    `ImageTexture.create_from_image()` devenu statique.
  - **Découverte non anticipée** : `'%s' % 100.0` (formatage string d'un float rond) produit `"100"`
    en Godot 3.6 mais `"100.0"` en Godot 4.7 — cassait tous les lookups par clé-chaîne dérivés des
    ids JSON (`BookData.all_nodes`, `sons`, `secret_jumps`...), qui n'ont jamais de type entier
    distinct côté JSON et étaient donc silencieusement "protégés" par ce comportement Godot 3.
    Fix à la racine dans `utils.gd::load_json_file()` (cast systématique via `ints_from_json`).
- Bugs visuels réels trouvés en testant le vrai rendu (Xvfb) — voir commit dédié :
  - `Control.rect_rotation` (degrés en Godot 3) fusionné dans `rotation` (radians en Godot 4) :
    le convertisseur renomme la propriété mais ne convertit jamais la valeur — c'était la "forme
    diagonale" qui traversait tout l'écran (les onglets latéraux "Chapitre précédent"/"Tous les
    chapitres"). Corrigé dans les 5 fichiers concernés (15 occurrences, vérifié exhaustivement
    contre `main`).
  - `OS.get_cmdline_args()` ne renvoie plus les arguments après `--` en Godot 4 (changement de
    sémantique, pas un renommage) — il faut `OS.get_cmdline_user_args()`. A nécessité de fixer
    entièrement `test/e2e/e2e_runner.gd` (yield/await, FileAccess/DirAccess, `GDScriptFunctionState`
    supprimé, `Camera2D.get_camera_screen_center()` → `get_screen_center_position()`) pour établir
    un moyen fiable de diagnostiquer visuellement — travail normalement prévu en vague H, avancé ici.
  - Renderer enfin fixé explicitement sur Compatibility (`gl_compatibility`) — la clé Godot 3
    `quality/driver/driver_name="GLES2"` n'a aucun effet en Godot 4, le projet tournait par défaut
    sur Forward+. Vérifié : rendu identique, aucune régression visuelle pour cet écran.
- Resave complet de toutes les scènes/ressources (23 fichiers restés en `format=2`) via un script
  one-shot (`load()` + `ResourceSaver.save()`), équivalent à un ouvrir/sauvegarder manuel dans
  l'éditeur mais scriptable. Effet de bord : fait disparaître un warning shader récurrent
  (`gray.gdshader` "deprecated parameter names") lié à un format de stockage obsolète invisible en
  diff texte.
- Remplacement GUT 7.2.0 → 9.7.0 (Phase 3), plugin activé dans `project.godot`. Test canari
  (`test_player.gd`) vert. Puis correction fichier par fichier jusqu'à couvrir toute la suite —
  détail complet des bugs trouvés (crash mémoire double-free, `BaseButton.pressed` devenu un signal,
  `InputEventScreenTouch`/`InputEventMouseButton` sur-convertis en `.button_pressed` par le CLI,
  nettoyage d'objets inter-livres manquant, littéraux de test float périmés) dans les messages de
  commit dédiés.
- **5 scripts de test invisibles à GUT** (compilation échouait silencieusement à cause de `File`
  class supprimée ou de coroutines appelées sans `await` — GUT rapportait juste moins de scripts/
  tests sans erreur explicite) : `test_parameters.gd`, `test_external_links_wiring.gd`,
  `test_migration.gd`, `test_real_swipe_navigation.gd`, `test_save_reload_cycle.gd`. Trouvés en
  comparant le compte de scripts/tests/assertions au baseline Phase 0 (33/223/501) plutôt que de
  faire confiance à "la suite est verte" — un run partiel silencieux aurait masqué des régressions.
  `test_migration.gd` a aussi nécessité une vraie révision : ses fixtures "vieux fichier .save"
  utilisaient `Player._save_var()`, qui écrit désormais en JSON — ne simulait donc plus un vrai
  vieux fichier binaire. Nouveau helper `_save_old_format_binary()` dédié.
- **Bug d'infrastructure de test découvert et corrigé** : le panneau du test-runner GUT
  (`GutRunner/GutLayer`, visible même en `-gexit`) couvre presque tout l'écran avec
  `mouse_filter=STOP` et interceptait donc toute simulation réelle de clic/swipe avant qu'elle
  n'atteigne `main.tscn` — invisible dans les tests qui appellent les handlers directement, fatal
  pour `test_real_swipe_navigation.gd`/`test_swipe.gd` qui testent le vrai pipeline d'input. Fixé
  sans toucher `addons/gut/` via le point d'extension officiel `-gpre_run_script`
  (`test/gut_hooks/disable_runner_input_blocking.gd`) : désormais **obligatoire** dans toute
  commande de lancement des tests GDScript.

**Résultat Phase 1 (mécanique) + une bonne partie de la Phase 3-5 (GUT + corrections) : suite
complète verte** — 33 scripts, 223 tests, 221 passing + 2 Risky préexistants non bloquants,
504 assertions (≥ 501 baseline), 0 crash, exit code 0. Commande de référence à partir de maintenant :
```bash
XDG_DATA_HOME=$(mktemp -d) xvfb-run --auto-servernum --server-args="-screen 0 1920x1080x24" \
  "$GODOT4" --path . -s addons/gut/gut_cmdln.gd \
  -gdir=res://test/unit,res://test/integration -ginclude_subdirs \
  -gpre_run_script=res://test/gut_hooks/disable_runner_input_blocking.gd -gexit
```
Reste à faire : Phase 6 (procédure spéciale fixtures figées, en partie déjà couverte par
`test_migration.gd`), Phase 7 (revue golden E2E), Phase 8 (export Android), Phase 9 (nettoyage
final + bascule).
