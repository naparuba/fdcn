"""
Compare les captures d'écran E2E (test/e2e/screenshots/actual/) aux images
de référence (test/e2e/screenshots/golden/), voir TEST_PLAN.md §5.

Usage:
    ./.venv/bin/python tests/e2e_compare_screenshots.py
    ./.venv/bin/python tests/e2e_compare_screenshots.py --update-golden

--update-golden écrase les images de référence par les captures actuelles.
À utiliser UNIQUEMENT après revue humaine d'un changement visuel volontaire
(jamais automatiquement en CI).
"""
import argparse
import shutil
import sys
from pathlib import Path

from PIL import Image, ImageChops

REPO_ROOT = Path(__file__).resolve().parent.parent
ACTUAL_DIR = REPO_ROOT / "test" / "e2e" / "screenshots" / "actual"
GOLDEN_DIR = REPO_ROOT / "test" / "e2e" / "screenshots" / "golden"

# Tolérance : pourcentage de pixels autorisés à différer (anti-aliasing,
# rendu de police légèrement différent selon la machine) avant de
# considérer qu'il y a une vraie régression visuelle.
DEFAULT_THRESHOLD_PCT = 0.5


def compare_one(actual_path, golden_path, threshold_pct=DEFAULT_THRESHOLD_PCT):
    actual_img = Image.open(actual_path).convert("RGB")
    golden_img = Image.open(golden_path).convert("RGB")

    if actual_img.size != golden_img.size:
        return False, f"tailles différentes: actual={actual_img.size} golden={golden_img.size}", None

    diff = ImageChops.difference(actual_img, golden_img)
    bbox = diff.getbbox()
    if bbox is None:
        return True, "identique", None

    diff_pixels = sum(1 for px in diff.getdata() if px != (0, 0, 0))
    total_pixels = actual_img.size[0] * actual_img.size[1]
    diff_pct = 100.0 * diff_pixels / total_pixels

    ok = diff_pct <= threshold_pct
    msg = f"{diff_pct:.3f}% de pixels différents (seuil {threshold_pct}%)"
    return ok, msg, diff


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--update-golden", action="store_true",
                         help="Écrase les images de référence par les captures actuelles (après revue humaine)")
    parser.add_argument("--threshold", type=float, default=DEFAULT_THRESHOLD_PCT)
    args = parser.parse_args()

    if not ACTUAL_DIR.exists() or not any(ACTUAL_DIR.glob("*.png")):
        print(f"Aucune capture dans {ACTUAL_DIR} -- lancer d'abord les scénarios e2e_runner.tscn.")
        sys.exit(1)

    if args.update_golden:
        GOLDEN_DIR.mkdir(parents=True, exist_ok=True)
        for actual_path in sorted(ACTUAL_DIR.glob("*.png")):
            shutil.copy(actual_path, GOLDEN_DIR / actual_path.name)
            print(f"golden mis à jour: {actual_path.name}")
        return

    failures = []
    checked = 0
    for actual_path in sorted(ACTUAL_DIR.glob("*.png")):
        golden_path = GOLDEN_DIR / actual_path.name
        if not golden_path.exists():
            failures.append((actual_path.name, "pas d'image de référence -- lancer --update-golden après revue"))
            continue
        checked += 1
        ok, msg, diff = compare_one(actual_path, golden_path, args.threshold)
        status = "OK" if ok else "FAIL"
        print(f"[{status}] {actual_path.name}: {msg}")
        if not ok:
            diff_path = actual_path.with_name(actual_path.stem + ".diff.png")
            if diff is not None:
                diff.save(diff_path)
                print(f"       diff sauvegardée: {diff_path}")
            failures.append((actual_path.name, msg))

    print(f"\n{checked} image(s) comparée(s), {len(failures)} échec(s).")
    if failures:
        sys.exit(1)


if __name__ == "__main__":
    main()
