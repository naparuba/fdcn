# Project review — fdcn (companion app for "La Forteresse du Chaudron Noir")

Reviewed on 2026-07-26, branch `LINKLINSSE/refacto_V4` (HEAD `88fbccb "en v4"`).
This file is a map: what the project is, how it's organized, and where to look
before making changes. `todo.md` has the concrete action items derived from it.

## 1. What this project is

Two independent halves:

1. **Python data pipeline** (repo root: `fdcn.py`, `node.py`, `condition_node.py`,
   `graph.py`, `endings.py`) — reads the hand-authored gamebook graph
   (`books/fdcn/fdcn.json`, `books/cdsi/cdsi.json`, one per book: FDCN and CDSI) and compiles it
   into the flattened JSON files the app consumes
   (`books/fdcn/fdcn-compilated-*.json`, `books/cdsi/cdsi-compilated-*.json`) plus a Graphviz visualization
   (`graph/fdcn_full-{book}.png`). Run via `python fdcn.py --book 1|2`.
   This half looked untouched by the current refactor — not reviewed in depth.

2. **Godot 4.7 app** (everything else) — a mobile/web/desktop app that lets a
   reader track their progress through the gamebook: which chapter they're on,
   which chapters/success/lore they've unlocked, inventory, and derived RPG
   stats (a "Billy" character build). This is the part the current branch is
   refactoring, and where all the findings below live.

Autoloads (`project.godot` `[autoload]`, i.e. global singletons): `Sounder`,
`Utils`, `BookData`, `AppParameters` (script `Parameters.gd`), `Swiper`
(script `swipe.gd`), `Player`.

## 2. Branch state — READ THIS FIRST

Commit history on this branch tells its own story:
```
d1169a4 Fix: passage en v4, cassé      ("moving to v4, broken")
4ca68d0 Fix: chargement des savec en json
eabcbbc Fix: des fonts
88fbccb en v4
```
This is a **mid-flight Godot 3 → Godot 4 migration + partial UI refactor**,
and it is currently broken at runtime, not just "rough". See §3.1 — the app
will throw on startup before ever showing the main screen.

The refactor appears to be introducing a new pattern (`ui/menu_page.gd`,
`ui/nav_buton.gd`, signal-driven popups under `popups/`) alongside the old
God-object pattern (`main.gd` owning ~800 lines of `$NodePath` calls into
every screen). Both patterns are live in the tree simultaneously, and they've
drifted out of sync with each other — that drift is the main risk area.

## 3. Where to look, by symptom

### 3.1 App is broken at startup / top menu buttons crash

`main.gd` still calls a `top_menu.gd` API that no longer fully exists:

- `main.gd:188` → `top_menu.register_main(self)` for each of the 5 top-menu
  instances (`_register_top_menus()`, `main.gd:180`). **`top_menu.gd` has no
  `register_main` function anymore** (confirmed via grep — only `swipe.gd`
  and `player.gd` still define one). This fires in `_ready()`, before
  anything else, so the app almost certainly errors immediately on boot.
- `main.gd:377-378` → `refresh()` calls `top_menu.set_spoils()` and
  `top_menu.set_sound()` on every top menu. **Neither function exists in
  `top_menu.gd`** (current file only has `set_billy`, `set_page`,
  `set_book_context`, plus the `focus_to_*` wrappers).
- `top_menu.tscn:440-443` wires the 4 Billy-type buttons
  (`BlockGuerrier/button` etc.) to `top_menu.gd`'s `_switch_to_guerrier` /
  `_switch_to_paysan` / `_switch_to_prudent` / `_switch_to_debrouillard`
  (`top_menu.gd:122-139`). Each of those calls `self.main._switch_to_X()` —
  **`main.gd` has no such methods** (grep across the whole codebase finds
  them nowhere except as commented-out dead code in `player.gd:721-739`,
  which itself expected `self._main._switch_to_X()`, i.e. `main.gd` again).
  `top_menu.gd`'s `main` var (`top_menu.gd:43`) is also never assigned by
  anyone — nothing calls a setter for it — so even fixing the target method
  wouldn't be enough by itself.

Net effect: the spoils toggle, sound toggle, and manual billy-type buttons in
the top menu are all pointing at functions that don't exist, and
`register_main` not existing likely breaks scene load before you even get
that far. Start here.

### 3.2 New `ui/` folder — is it live or a work-in-progress dead end?

`ui/menu_page.gd` + `ui/nav_buton.gd` (with scenes `ui/MenuPage.tscn`,
`ui/NavButon.tscn`) implement a self-contained swipeable page container with
its own left/right nav buttons — functionally overlapping with the existing
`Swiper` autoload (`swipe.gd`) that `main.tscn` currently uses via
`Swiper.compute_event()` / `focus_to_*()`. **Nothing references `ui/MenuPage`
or `ui/NavButon` from `main.tscn`** (grep confirms — only the two `.tscn`
files reference their own scripts). This looks like an in-progress
replacement for `Swiper` that was never wired in. Before touching swipe/nav
behavior, find out (ask the author / check for other branches) whether
`ui/` is meant to replace `swipe.gd` or is abandoned — don't maintain both.

### 3.3 Player stats / save data

- `player.gd` is the biggest single piece of game logic (844 lines): save/load
  (JSON files under `user://`), inventory, derived RPG stats, and the
  "Billy type" auto-detection from equipped items
  (`compute_my_billy_for_option`, `player.gd:743`).
- Stats are split into three additive layers per stat (e.g. `hab`, `hab_items`,
  `hab_chapters`) — base + items + accumulated chapter effects — recombined in
  `_recompute_stats()` (`player.gd:516`). Any new stat source must follow this
  three-layer pattern or `_refresh_options_stats()` in `main.gd:785` (which
  prints all three) will be misleading.
- `_apply_chapter_stat()` (`player.gd:779`) is where per-chapter stat effects
  from the book (`stats`/`stats_cond` in the compiled JSON) get applied. Several
  keys are explicitly unimplemented and just log a warning:
  `1_4_pv_max`, `arc_et_couteau`, `pv_1_4_max`, `pv_win_plus_1`
  (search `IS NOT CURRENTLY MANAGED`). If a save file exercises one of these,
  the stat is silently dropped — worth knowing before trusting stat totals.
- **Suspected double-apply bug**, see `todo.md` item 1 — `Player.do_load()` is
  called twice back-to-back at startup and again on every book switch, and the
  chapter-derived stat accumulators (`end_chapters`, `hab_chapters`, `cha`,
  `pv`, `gloire`, `richesse`, `nb_infos`, …) are never reset before being
  replayed from `session_visited_nodes`. Trace this before changing anything
  stats-related — it may explain "my stats look too high" reports.

### 3.4 Book data / conditions

- `BookData.gd` loads the compiled JSON for whichever book is selected
  (`do_load_book`, `BookData.gd:24`) and exposes lookups: chapter data
  (wrapped in `chapter_data.gd`, one instance per node), success/ending
  lookups, arc/sub-arc completion %, and the jump-condition evaluator
  (`_check_cond_rec`, `BookData.gd:194`) which walks a `$or`/`$and`/`$end`
  condition tree against `Player.get_all_matched_conditions()`.
- `chapter_data.gd` is a thin dict wrapper around one node's `"computed"`
  JSON blob (see the example schema in its header comment) — if you need to
  know what fields a chapter node has, read that comment first.
- Condition trees, stat trees, and node graph structure are all produced by
  the Python pipeline (`node.py`, `condition_node.py`) — if data looks wrong
  for a specific chapter, the bug is more likely in the Python compiler than
  in the Godot side.

### 3.5 UI screens

- `main.tscn` is one big scene with five "pages" side by side
  (`Background`/main, `Chapitres`, `Succes`, `Lore`, `About`), and `Swiper`
  moves a camera (`main.gd:576`, `set_camera_to_pos`) between fixed x-offsets
  hardcoded in `swipe.gd:75-103` (278 / 876 / 1471 / 2058 / 2648). Adding or
  reordering a page means updating those hardcoded offsets by hand.
- Each "top_menu" (`top_menu.tscn`, one instance per page) is otherwise
  identical UI duplicated across pages, driven by `top_menu.gd`. Bugs found in
  one usually apply to all five.
- Popups: `popups/SettingsPopup.tscn` + `popups/settings_popup.gd`,
  `popups/sub/Inventory.tscn` + `inventory.gd`, `popups/sub/Stats.tscn` +
  `stats.gd`, `popups/sub/BookSelection.tscn` — these look like the newer,
  cleaner pattern (self-contained scene + script, opened on demand into a
  `popup_container`) compared to `main.gd`'s inline `$Options` panel
  (`main.gd:631-777`, `_options_show_equipement/_stats/_book_select`) which
  does the same job (equipment/stats/book-select tabs) the old way. These
  look like two competing implementations of the same "options" concept —
  same ambiguity as §3.2.

### 3.6 Tests

- `addons/gut/` — GUT (Godot Unit Test) 7.2.0, compatible with Godot 4.
- Only one test file: `test/unit/test_player.gd`, 2 tests, both about Billy
  type detection from items. Nothing covers save/load, condition evaluation,
  BookData, or the stat computation described in §3.3 — exactly the area with
  the suspected bug.
- `test/all.tscn` is the GUT runner scene; `.gut_editor_config.json` /
  `.gut_editor_shortcuts.cfg` at repo root configure the in-editor GUT panel.

## 4. Repo hygiene (see `todo.md` for actions)

- `.gitignore` is a stock **Python** template (Django/Flask/PyInstaller/etc
  sections) with **no Godot-specific entries at all**. As a result:
  - `.godot/` (Godot's own regenerated editor/import cache) is tracked:
    **1196 files** in git (`git ls-files .godot | wc -l`).
  - `.import/` (legacy Godot 3 import cache directory) is also tracked:
    **861 files**.
  - Six Godot-editor crash-recovery temp files got committed by accident in
    `88fbccb`: `ui/MenuPage.tscn2311070487.tmp` (+2 siblings) and
    `popups/sub/Inventory.tscn3254941844.tmp` (+2 siblings).
- `LoreEntry.tscn` is 2.7 MB (vs. everything else under 100 KB) — worth
  checking whether it has large resources embedded inline instead of
  referenced externally.
- `project.godot`'s `[rendering]` section still has Godot-3-only keys
  (`quality/driver/driver_name="GLES2"`, `vram_compression/import_etc`) that
  don't exist in the Godot 4 settings schema — harmless (Godot 4 ignores
  unknown keys) but a sign the migration wasn't fully cleaned up; Godot 4's
  equivalent is `rendering/renderer/rendering_method`.
