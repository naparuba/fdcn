# Journal des régénérations de golden images

## 2026-07-09 — Migration Godot 3.6.2 → Godot 4.7

Les 22 golden images ont été régénérées après revue humaine (pas un `--update-golden` en masse
sans regard — chaque paire actual/golden a été examinée visuellement, en particulier les cas à
fort pourcentage de diff, avant décision). Deux catégories de changements :

**Différences cosmétiques attendues, acceptées consciemment** (fonts `DynamicFont`→`FontFile`
reconverties, renderer Compatibility au lieu de GLES2, alpha-blending légèrement différent sur les
popups semi-transparents, positions aléatoires des particules d'animation) : présentes sur les 22
images à des degrés variables (11% à 44% de pixels différents selon le contenu), mais structure et
contenu visuel identiques à la revue humaine.

**Vraies régressions trouvées et corrigées avant régénération** (pas de golden mis à jour pour
masquer un bug) :
- `E10_succes_seul_sans_fin.png` / `E4_fin_bonne_224.png` (~99% de diff avant fix, popup absent) :
  `SuccessPopup` héritait de `Popup`, qui hérite de `Window` en Godot 4 (une vraie fenêtre OS
  séparée, invisible dans le viewport capturé) au lieu de `Control` comme en Godot 3 — corrigé en
  repassant `SuccessPopup.gd`/`.tscn` sur `Control`. Un bug de données préexistant (argument
  d'animation malformé, présent aussi sur `main`/Godot 3.6.2 mais tombant en erreur silencieuse
  plutôt que fatale) a été corrigé au passage.
- Plusieurs scénarios montraient l'écran Options au lieu de l'écran attendu — pas un bug produit,
  mais une erreur de méthodologie de capture (chaque scénario doit partager le même `XDG_DATA_HOME`
  qu'un scénario "amorce" comme `acquisition_objet.json`, qui valide un inventaire de départ ;
  lancé isolément avec un répertoire complètement vierge, `Player.need_force_display_options` force
  l'ouverture des Options dès le boot, ce qui est le comportement RÉEL et VOULU pour un joueur qui
  n'a jamais rien configuré — voir `TEST_PLAN.md` §5.3).

Pas de régénération en masse sans regard : chaque cas à diff anormalement élevé (>90%) a été
identifié et sa cause root-causée avant toute mise à jour de golden.
