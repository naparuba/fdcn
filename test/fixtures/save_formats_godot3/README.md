# Fixtures de sauvegarde Godot 3.6.2 (pré-JSON)

Vrais fichiers `.save` (format binaire `File.store_var`), générés en exécutant
le **vrai binaire Godot 3.6.2** sur le commit `971f69c` (le dernier commit
juste AVANT `af5c081`, qui a introduit le miroir JSON). Ce sont donc des
fixtures authentiques d'une sauvegarde de joueur antérieure à la migration
JSON — exactement le cas que `player.gd::_load_var()` doit gérer via son
fallback binaire (lecture unique, puis migration immédiate vers `.json`).

Ne JAMAIS régénérer ces fichiers avec du code Godot 4 — ils perdraient leur
valeur de fixture (le but est de figer ce qu'un vrai joueur Godot 3 a
réellement sur son disque, pas ce que Godot 4 écrirait).

## Scénario reproduit

Identique à `test/integration/test_save_reload_cycle.gd`
(`test_full_cycle_visit_acquire_save_reload_gives_identical_state`) :

```
AppParameters.set_book_number(1)
Player.insert_all_objects()
Player.launch_new_billy()
Player.go_to_node(1)
Player.go_to_node(128)   # NODE_WITH_END_STAT
Player.go_to_node(112)   # NODE_WITH_END_HAB_AND_ITEM
Player.add_item_from_options('EPEE')
```

## Valeurs attendues après chargement (contrat)

```
current_node_id        = 112
visited_nodes_all_times = [1, 128, 112]
session_visited_nodes   = [1, 128, 112]
possessed_items         = ["PALAIS DES PLAISIRS D'YTIA", "EPEE"]
```

(`PALAIS DES PLAISIRS D'YTIA` est acquis automatiquement en visitant le
nœud 112, cf sa colonne `aquire` dans les données de chapitre -- ce n'est
pas un objet ajouté manuellement.)

## Fichiers

- `current_node_id-1.save`
- `all_times_already_visited-1.save`
- `session_visited_nodes-1.save`
- `possessed_item-1.save`
- `parameters.save` (sélection du livre, écrit par `AppParameters`)

Le `-1` dans les noms correspond au livre n°1 (FDCN/Tome 1).

## Usage prévu (Phase 6 du plan de migration)

Écrire un test qui copie ces fichiers dans un `user://` isolé
(`XDG_DATA_HOME` temporaire), appelle `Player.do_load()` avec le code
Godot 4, et vérifie que les valeurs chargées correspondent exactement au
contrat ci-dessus -- PUIS vérifie qu'un miroir `.json` a bien été écrit à
côté. Ce test ne doit jamais "sauvegarder puis recharger avec le même
code Godot 4" en boucle fermée (c'est déjà couvert par
`test_save_reload_cycle.gd`) : sa valeur ajoutée est justement de partir
d'un binaire figé, écrit par un AUTRE moteur (Godot 3.6.2 réel).
