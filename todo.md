# TODO — fdcn v4 refactor

Derived from `review.md`. Ordered roughly by priority: blocking bugs first,
then correctness risks, then hygiene/cleanup.

## Blocking — app is currently broken

- [ ] **Fix `top_menu.gd` missing `register_main`.** `main.gd:188` calls
      `top_menu.register_main(self)` on every top menu at startup; the method
      was removed from `top_menu.gd` during the refactor. Add it back (store
      `self.main = main`, mirroring `swipe.gd:15`/`player.gd:250`), or update
      `main.gd` if the new design intends something else.
- [ ] **Fix `top_menu.gd` missing `set_spoils` / `set_sound`.** Called from
      `main.gd:377-378` in `refresh()`, not defined anywhere in `top_menu.gd`.
      Decide: does the top menu still need to reflect spoils/sound state
      itself, or did that move to `popups/SettingsPopup.tscn` /
      `settings_popup.gd` entirely? If the latter, remove the calls from
      `main.gd` instead of re-adding dead methods.
- [ ] **Fix billy-switch buttons calling nonexistent methods.**
      `top_menu.tscn:440-443` wires 4 buttons to `top_menu.gd:_switch_to_*`,
      which call `self.main._switch_to_*()` — not defined on `main.gd`
      anywhere. `player.gd` already has the real logic
      (`_switch_to_billy(billy_type)`, `player.gd:711`) plus commented-out
      wrapper stubs (`player.gd:721-739`) that suggest the intended call
      chain was `top_menu → main → Player`. Either restore that chain or
      simplify to `top_menu → Player._switch_to_billy(type)` directly. Also
      note `top_menu.gd`'s `main` var (`top_menu.gd:43`) is never set by
      anyone currently — needs `register_main` fixed first (see above) for
      this to even have a chance of working.
- [ ] Once the three items above are fixed, do a manual smoke test: launch,
      confirm no console errors on boot, open the top menu settings, toggle
      spoils/sound, tap each billy-type button, switch page via swipe.

## Correctness — needs investigation before trusting stats

- [ ] **Investigate double-application of chapter stats.**
      `Player.do_load()` (`player.gd:221`) is called twice in a row at
      startup: once via `main.gd:_reload_all_player()` → `Player.do_load()`
      (`main.gd:41`), and again explicitly at `main.gd:59`
      (`Player.do_load()  # TEST` — looks like a debug leftover). It's called
      again on every book switch via `_change_book_number()`
      (`main.gd:556-562`, which calls both `_do_load_book_context()` and
      `_reload_all_player()`, each triggering `do_load()`).
      `do_load()` → `_redo_all_my_chapters_stats()` (`player.gd:212`) replays
      `apply_one_chapter_stats()` for every chapter in
      `session_visited_nodes`, and that function accumulates into
      `end_chapters`, `hab_chapters`, `adr_chapters`, `chamax_chapters`,
      `deg_chapters`, `arm_chapters`, `crit_chapters`, `cha`, `pv`, `gloire`,
      `richesse`, `nb_infos` via `+=` (`_apply_chapter_stat`,
      `player.gd:779`) **without resetting them first** (they're only reset
      in `_fully_reset_our_stats()`, called solely from `launch_new_billy()`).
      Net effect: every extra `do_load()` call re-adds the full history's
      worth of chapter stat bonuses on top of what's already there.
      - Confirm this is actually a bug (vs. something elsewhere resetting
        state that I missed) by adding a temporary print of `end_chapters`
        before/after each `do_load()` call and watching it grow.
      - If confirmed: remove the redundant `Player.do_load()` call at
        `main.gd:59`, and reset chapter accumulators to 0 at the top of
        `_redo_all_my_chapters_stats()` before replaying, so calling
        `do_load()` more than once is idempotent instead of cumulative.
      - This may well be a live production bug too (not v4-specific) —
        commit `95ec4c3` ("les stats de chapitres n'étaient pas reset lors
        qu'on avait un nouveau Billy") fixed a related-sounding symptom but
        only touched the new-billy path, not regular boot/book-switch.
- [ ] Decide the fate of the unimplemented stat keys in
      `_apply_chapter_stat` (`player.gd:779`): `1_4_pv_max`,
      `arc_et_couteau`, `pv_1_4_max`, `pv_win_plus_1`. Either implement them
      or confirm no chapter in either book currently uses them (check the
      compiled JSON: `grep` those keys in `fdcn-1-compilated-data.json` /
      `fdcn-2-compilated-data.json`).

## Architecture — resolve duplicated/competing implementations

- [ ] **Decide the fate of `ui/menu_page.gd` + `ui/nav_buton.gd`.** Not
      referenced from `main.tscn` or anywhere else — dead code, or an
      in-progress replacement for the `Swiper` autoload (`swipe.gd`)? If it's
      the intended replacement, finish wiring it in and remove `swipe.gd`'s
      overlapping responsibility; if abandoned, delete it (and its scenes)
      rather than leaving two nav systems to keep in sync.
- [ ] **Decide the fate of `main.gd`'s inline `$Options` panel** vs. the
      newer `popups/sub/Inventory.tscn` + `Stats.tscn` + `BookSelection.tscn`
      pattern. Both currently implement equipment/stats/book-select UI
      (`main.gd:631-777` vs. `popups/sub/*.gd`). Consolidate on one.
- [ ] Once the above two are settled, consider whether `main.gd` (833 lines,
      God-object owning every screen via `$NodePath`) should be broken up
      following whatever pattern `popups/` establishes — but don't start this
      until the app actually boots (see Blocking section) and the duplicated
      patterns are resolved, or it'll multiply the sync-drift problem in
      §3.1/§3.2 of review.md.

## Hygiene / repo cleanup

- [ ] Add Godot entries to `.gitignore` (it's currently 100% a Python
      template — see `review.md` §4): at minimum `.godot/`, and decide on
      `.import/` (legacy Godot 3 cache — likely stale and removable now that
      `.godot/imported/` exists for Godot 4).
- [ ] `git rm --cached` the 1196 tracked files under `.godot/` and 861 under
      `.import/` after adding the ignore rules, then commit as a dedicated
      "stop tracking engine cache" change (large diff, keep it isolated from
      functional changes).
- [ ] Delete the 6 committed Godot editor temp files and add a pattern to
      `.gitignore` to prevent recurrence (`*.tscn*.tmp` or similar):
      - `ui/MenuPage.tscn2311070487.tmp`
      - `ui/MenuPage.tscn2316903278.tmp`
      - `ui/MenuPage.tscn2324407141.tmp`
      - `popups/sub/Inventory.tscn3254941844.tmp`
      - `popups/sub/Inventory.tscn4156609483.tmp`
      - `popups/sub/Inventory.tscn4203287309.tmp`
- [ ] Look into why `LoreEntry.tscn` is 2.7 MB when comparable scenes are
      under 100 KB — likely embedded binary resources that should be
      external `.png`/etc. files referenced by path instead.
- [ ] Clean up leftover Godot-3-only keys in `project.godot`'s `[rendering]`
      section (`quality/driver/driver_name`, `vram_compression/import_etc`) —
      harmless but stale; Godot 4 equivalent is
      `rendering/renderer/rendering_method`.
- [ ] Remove the untracked `.godot/editor/editor_script_doc_cache.res` from
      the working tree (regenerable editor cache) once `.godot/` is
      gitignored — no action needed if it's just going to be ignored anyway.

## Test coverage

- [ ] `test/unit/test_player.gd` only covers billy-type detection (2 tests).
      Once the double-`do_load()` bug above is fixed, add a regression test
      that calls `Player.do_load()` (or the startup sequence it's part of)
      twice and asserts chapter-derived stats don't change on the second
      call.
- [ ] Add coverage for `BookData._check_cond_rec` (the `$or`/`$and`/`$end`
      condition evaluator, `BookData.gd:194`) — currently untested and it's
      what gates secret chapters/jumps being shown.
