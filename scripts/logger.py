# -*- coding: utf-8 -*-

## Verbosite du compilateur. Sans `--verbose`, seuls les resultats qui comptent a chaque
## compilation sortent (resume, avertissement, erreur) : `trace()` noyait ca dans un
## evenement par noeud/arc, jusqu'a 66 print() rien que dans generator.py.

VERBOSE = False


def trace(msg):
    """Un evenement par noeud/arc/sous-arc : bruit utile seulement en debogage."""
    if VERBOSE:
        print(msg)


def info(msg):
    """Un resultat qui compte a chaque compilation : resume, validation, erreur."""
    print(msg)
