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

## 2026-07-09 (bis) — Régression de taille de police (`DynamicFont`→`FontFile`)

Régénération complète des 22 golden ci-dessus **corrigée après coup** : l'utilisateur a repéré
manuellement un bloc gris parasite à côté du "1" dans le breadcrumb de `E1` (golden précédente),
signalant que ma revue humaine de la première régénération n'avait pas été assez attentive.

Root cause, en deux bugs distincts trouvés en creusant ce signalement :
- `bread.tscn` (`Label2`/`ElLabel`, des `RichTextLabel`) : `scroll_active` vaut `true` par défaut
  en Godot 4 (`false` en Godot 3), et le contenu du label dépasse marginalement — d'où le
  scrollbar-thumb gris parasite. Fixé avec `scroll_active = false` sur les deux nœuds.
- **Bien plus large** : la conversion `DynamicFont`→`FontFile` du convertisseur CLI ne préserve
  jamais la taille (`size` en Godot 3, baked dans la ressource de police) — Godot 4 exige un
  `theme_override_font_sizes/font_size` explicite sur chaque nœud consommateur, que ni le
  convertisseur ni le resave de scènes n'ajoutent. Toutes les polices concernées retombaient donc
  silencieusement à 16px (le défaut Godot 4), la plupart de façon peu visible sauf pour les grandes
  tailles (`NumeroChapitreBig` en `main.tscn`, censé faire 64px, ne faisait plus que 16px — le
  gros numéro de chapitre teal, censé remplir tout le panneau "Position", devenait un trait à peine
  visible). Vérifié exhaustivement (`grep` de tous les `sub_resource type="FontFile"` + tous les
  `theme_override_fonts/*` qui les référencent) sur les 9 fichiers concernés : `main.tscn`,
  `ChapterChoice.tscn`, `EndingChoice.tscn`, `Item.tscn`, `ItemPopup.tscn`, `LoreEntry.tscn`,
  `Success.tscn`, `scenes/GenericConfirmationPopup.tscn`, `top_menu.tscn`. Fixé en ajoutant
  `theme_override_font_sizes/font_size` (ou `normal_font_size` pour le seul `RichTextLabel`
  concerné) juste après chaque `theme_override_fonts/font`, avec la taille exacte lue dans
  `git show main:<fichier>` pour chaque `DynamicFont` d'origine.

Vérification, pas juste supposée : un troisième cas (`EndingChoice.tscn`, bouton rotatif "Oups"/">"
qui se superposent en tampon "griffonné") semblait à première vue être une RÉGRESSION après le fix
(le texte "Oups" débordait largement de sa petite case grise, alors que la golden précédente le
montrait bien contenu sur une ligne "Oups <"). Plutôt que de conclure sans preuve, comparaison
directe avec un rendu réel sous **Godot 3.6.2** (worktree temporaire sur `main`, même scénario
`fin_bonne.json`, même méthode de capture) : confirme que le débordement/chevauchement "< / Oups"
est le rendu D'ORIGINE en Godot 3 — c'est la golden précédente (taille 16 au lieu de 40) qui était
fausse, pas le fix. Cette même comparaison Godot 3 confirme aussi indépendamment le fix du gros
numéro de chapitre (`224` bien géant en Godot 3, comme dans le résultat post-fix).

Diffs pixel obtenus après ce fix (vs golden précédente, non vs Godot 3) : 1.5% à 15.4% selon
l'écran — nettement plus bas que les 11%-44% de la régénération précédente, cohérent avec le fait
que cette régénération corrige une vraie divergence visuelle plutôt que d'en accepter une nouvelle.

## 2026-07-09 (ter) — Étiquettes-rubans diagonales décalées ("Déjà Vu", "Ce Billy", "Combat", "Fin",
"Succès", "Secret", "Bonne fin"/"Mauvaise fin", "Obtenu")

Deuxième signalement utilisateur sur la même golden `E1` : les étiquettes du breadcrumb ont bien le
bon angle de rotation (déjà vérifié via la Décision `rect_rotation`→`rotation`), mais le texte est
décalé vers la droite et dépasse de son ruban gris.

Root cause différente des deux précédentes : ces `Label` (8 au total, dans `ChapterChoice.tscn`,
`EndingChoice.tscn` et `Success.tscn`) n'ont **jamais eu de police explicite**, ni en Godot 3 ni
après conversion — ils utilisent la police par défaut du moteur, faute d'un thème projet. Or la
police par défaut intégrée à Godot a changé entre 3.6 et 4.7 (confirmé empiriquement : un `Label`
sans override affichant "Déjà Vu Test" mesure 80×14px sous Godot 3.6.2 contre 96×23px sous Godot
4.7 — pas juste une différence de taille, une police différente aux métriques différentes). Le
texte, non tronqué (`clip_text` désactivé par défaut dans les deux moteurs), déborde donc plus loin
le long de l'axe de rotation, sortant visuellement du ruban qui avait été ajusté à l'œil pour
l'ancienne police par défaut.

Pas de police par défaut fiable entre versions de moteur = pas quelque chose qu'on peut se permettre
de laisser implicite. Fixé en rendant la police explicite (`RobotoCondensed-Regular.ttf`, déjà
utilisée partout ailleurs dans l'appli, référencée `ExtResource("3")` dans les 3 fichiers) à une
taille choisie empiriquement (16 — mesuré via une scène de sondage isolée comparant la largeur
rendue de "Déjà Vu Test" avec `RobotoCondensed` à différentes tailles jusqu'à retrouver ~80px,
la largeur d'origine Godot 3) sur les 8 nœuds concernés.

Suite GDScript revérifiée après ce fix (33 scripts / 221 passing + 2 Risky préexistants /
504 assertions, 0 crash, identique à la référence) puis 22/22 golden E2E régénérées après revue
humaine (diffs 0.04% à 18.9% vs la régénération précédente — le cas à 18.9%, `E6_retour_livre_fdcn`,
vérifié visuellement identique à l'œil, du bruit d'anti-aliasing sur un écran à beaucoup d'icônes/
toggles, pas une régression).
