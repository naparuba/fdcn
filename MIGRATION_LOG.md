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
- **État à cet instant** : le projet démarre sous Godot 4.7 headless sans AUCUNE erreur de script
  (0 SCRIPT ERROR). Un smoke-test avec rendu réel (Xvfb) affiche un premier écran, mais avec des
  bugs visuels réels non résolus : texte "XXX" non remplacé par les vraies valeurs (Acte/Arc/
  Chapitre), et une forme graphique mal positionnée en diagonale sur tout l'écran. **Phase 1 pas
  encore terminée** — investigation à poursuivre avant de passer à la Phase 2.
