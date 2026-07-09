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
