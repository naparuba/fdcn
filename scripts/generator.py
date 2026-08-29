# -*- coding: utf-8 -*-

import argparse
import codecs
import json
import os
import sys

# NOTE: I don't want a real package name for just a couple of files, so keep like this currently
my_dir = os.path.dirname(__file__)
sys.path.insert(0, my_dir)

import logger
from graph import Graph
from graph_render import new_display_graph
from endings import ENDINGS

REGISTRE = 'books/books.json'

# Les 14 clés qu'un chapitre peut déclarer -- toute autre est une faute de saisie
# (`cond` au lieu de `stats_cond`, par exemple) qui passait jusqu'ici sans un mot (todo 3.2).
CHAPTER_ALLOWED_KEYS = {
    'success', 'combat', 'secret', 'conditions', 'label', 'secret_jumps',
    'aquire', 'remove', 'stats', 'stats_cond', 'goto', 'ending', 'ending_id', 'ending_txt',
}

# Vocabulaire de stats connu du MOTEUR (autoload/player_stats.gd) : les stats en couches
# (`_CHAPTER_LAYERED_KEYS`), les deux ressources et leurs modificateurs (plafond, gain), et
# le compteur commun aux deux livres. Les compteurs et clés ignorées PROPRES a un livre
# (`gloire`, `arc_et_couteau`, ...) viennent de son `compteurs.json` (todo 3.5, review §4.6),
# pas d'ici.
ENGINE_STATS_VOCABULARY = {
    'adr', 'arm', 'chance_max', 'crit', 'deg', 'end', 'hab',  # stats en couches
    'chance', 'pv', 'pv_max', 'pv_gain', 'chance_gain',        # ressources + modificateurs
    'richesse',                                                # compteur commun
}


def load_json_file(file_name: str):
    with codecs.open(file_name, 'r', 'utf8') as f:
        return json.loads(f.read())


def parse_args():
    parser = argparse.ArgumentParser(description="Compile all .json for the UI app")
    action = parser.add_mutually_exclusive_group(required=True)
    action.add_argument("--book", help=f"Nom du livre a compiler (le dossier books/<nom>/), ou son rang dans {REGISTRE}")
    action.add_argument("--nouveau", metavar="NOM",
                         help="Cree scripts/src/<nom>/ (chapitre 1 valide) et l'entree dans %s, prets a compiler" % REGISTRE)
    parser.add_argument("--verbose", action="store_true",
                         help="Affiche la trace detaillee par noeud/arc/sous-arc, silencieuse par defaut")
    return parser.parse_args()


def resolve_book_name(book_arg: str, book_names: list) -> str:
    # Retro-compatibilite : `--book 1` / `--book 2` designaient les livres par leur rang.
    book_name = book_arg
    if book_name.isdigit():
        rang = int(book_name) - 1
        if rang < 0 or rang >= len(book_names):
            print('ERROR: no book number %s, %s declares %d books' % (book_name, REGISTRE, len(book_names)))
            sys.exit(2)
        book_name = book_names[rang]
    if book_name not in book_names:
        print('ERROR: unknown book: %s. %s declares: %s' % (book_name, REGISTRE, ', '.join(book_names)))
        sys.exit(2)
    return book_name


def creer_nouveau_livre(nom: str) -> None:
    """Un livre neuf part de quelque chose qui COMPILE deja (todo 3.9), pas d'une page
    blanche et de sept champs a deviner : un chapitre 1 qui est sa propre fin, le
    `<nom>.livre.json` vide qui va avec, et l'entree dans le registre."""
    registre = load_json_file(REGISTRE)
    if any(livre['nom'] == nom for livre in registre['livres']):
        print('ERROR: le livre %s existe deja dans %s' % (nom, REGISTRE))
        sys.exit(2)

    src_dir = f'scripts/src/{nom}'
    if os.path.isdir(src_dir):
        print('ERROR: %s existe deja' % src_dir)
        sys.exit(2)
    os.makedirs(src_dir)

    chapitres = {
        '1': {
            'label': 'Premier chapitre',
            'ending': 'good',
            'ending_id': 'PREMIER-PAS',
            'ending_txt': 'Votre histoire commence ici.',
        }
    }
    with codecs.open(f'{src_dir}/{nom}.json', 'w', 'utf8') as f:
        f.write(json.dumps(chapitres, indent=4, ensure_ascii=False, sort_keys=True))

    # Vide plutot qu'absent : `ecrire_les_json()` fait `livre['objets']`/`livre['succes']`
    # sans `.get()`, comme pour le chapitre 1 lui-meme -- un livre neuf n'a besoin
    # d'aucun objet ni d'aucun succes pour compiler.
    livre = {
        'actes': [{'depart': 1, 'nom': 'Acte 1'}],
        'sous_arcs': [],
        'sous_arcs_manuels': {},
        'objets': {},
        'succes': [],
        'compteurs': [],
        'ignorees': [],
    }
    with codecs.open(f'{src_dir}/{nom}.livre.json', 'w', 'utf8') as f:
        f.write(json.dumps(livre, indent=4, ensure_ascii=False, sort_keys=True))

    # A la fin, jamais ailleurs : une sauvegarde d'avant 2026 range le livre courant par
    # RANG dans cette liste (review §3.6 / books/README.md) -- s'insérer plus tot decalerait
    # les livres suivants.
    registre['livres'].append({'nom': nom, 'titre': nom})
    with codecs.open(REGISTRE, 'w', 'utf8') as f:
        f.write(json.dumps(registre, indent=4, ensure_ascii=False, sort_keys=False))

    print('Livre %s cree : %s/, entree ajoutee a %s.' % (nom, src_dir, REGISTRE))
    print('Reste : books/%s/img/, books/%s/audio/ (facultatifs), puis compiler avec '
          'python3 scripts/generator.py --book %s' % (nom, nom, nom))


def lire_les_noeuds(book_data: dict, node_graph: Graph) -> None:
    """Cree tous les noeuds puis remplit chacun depuis son bloc JSON : deux passes, car un
    noeud peut sauter vers un chapitre pas encore cree en premiere passe."""
    for node_id_str in book_data.keys():
        node_graph.create_node(node_id_str)

    for idx, n in book_data.items():
        idx = int(idx)
        node = node_graph.get_node(idx)

        clefs_inconnues = set(n.keys()) - CHAPTER_ALLOWED_KEYS
        if clefs_inconnues:
            print('ERROR: node %s uses unknown chapter key(s): %s (allowed: %s)' %
                  (idx, sorted(clefs_inconnues), sorted(CHAPTER_ALLOWED_KEYS)))
            sys.exit(2)

        success = n.get('success', None)
        if success:
            node.set_sucess(success)

        combat = n.get('combat', None)
        if combat is not None:
            node.set_combat(combat)

        secret = n.get('secret', False)
        if secret:
            node.set_secret()

        conditions = n.get('conditions', "")
        if conditions:
            node.set_conditions(conditions)

        label = n.get('label', None)
        if label:
            node.set_label(label)

        secret_jumps = n.get('secret_jumps', None)
        if secret_jumps is not None:
            node.set_secret_jumps(secret_jumps)

        node.set_aquire(n.get('aquire', []))
        node.set_remove(n.get('remove', []))
        node.set_stats(n.get('stats', {}))
        node.set_stats_cond(n.get('stats_cond', {}))

        goto = n.get('goto', [])
        if isinstance(goto, int):
            goto = [goto]
        goto = node.get_all_possibles_goto(goto)
        logger.trace(f' possible goto:{n.get("goto", [])} => {goto}')

        # Une FIN se reconnait a sa cle `ending`, et a rien d'autre -- ni a un numero de
        # chapitre ni a un numero de livre. Ce bloc testait `goto == 608 and book_number == 1`,
        # ce qui n'a jamais compile la moindre fin de cdsi (ses 16 fins n'ecrivent pas de goto,
        # et son chapitre 608 est un vrai chapitre).
        #
        # Une fin n'a PAS de suite : son goto eventuel n'est pas suivi. fdcn fait pointer les
        # siennes sur un 608 qui n'existe pas chez lui, cdsi n'en met pas du tout.
        ending = n.get('ending')
        if ending is not None:
            _ending = {'good': ENDINGS.GOOD, 'bad': ENDINGS.BAD}.get(ending, None)
            if _ending is None:
                print('ERROR: node %s have an unknown ending string: %s' % (idx, ending))
                sys.exit(2)
            node.set_ending(_ending)
            ending_id = n.get('ending_id', None)
            if ending_id:
                node.set_ending_id(ending_id)
                node.set_ending_txt(n.get('ending_txt'))
        else:
            for dest_idx in goto:
                # Un saut hors du livre ne peut etre qu'une fin mal declaree : sans ce test,
                # le graphe se fabrique un chapitre fantome et l'app le proposerait au lecteur.
                if str(dest_idx) not in book_data:
                    print('ERROR: node %s jumps to %s, which is not a chapter of this book '
                          '(a chapter that ends the story must declare `ending`)' % (idx, dest_idx))
                    sys.exit(2)
                son = node_graph.get_node(dest_idx)
                node.add_son(son)


def taguer_les_arcs(node_graph: Graph, arcs: list, sub_arcs: list, manual_sub_arcs: dict) -> None:
    """Propage arc et sous-arc aux noeuds. Les arcs sont parcourus du plus haut vers le plus
    bas (`reversed`) pour qu'un arc parent ne recouvre pas un arc deja pose."""
    for arc_start, arc_name in reversed(arcs):
        logger.trace('Tagging arc: %s (%s)' % (arc_start, arc_name))
        arc_node_start = node_graph.get_node(arc_start)
        arc_node_start.set_in_arc(arc_name)

    for arc_name, sub_arc_start, sub_arc_name, sub_arc_stops in sub_arcs:
        node_start = node_graph.get_node(sub_arc_start)
        node_start.set_in_sub_arc(sub_arc_name, sub_arc_stops, 0)

    for sub_arc_name, node_ids in manual_sub_arcs.items():
        logger.trace('Sub arc (manual): %s => %s' % (sub_arc_name, node_ids))
        for node_id in node_ids:
            node = node_graph.get_node(node_id)
            node.set_in_sub_arc_not_recursive(sub_arc_name)


def construire_le_graphe(node_graph: Graph, display_graph, arcs: list) -> None:
    """Peuple le graphe d'affichage (graphviz) : noeuds, puis aretes reparties par arc et
    sous-arc en clusters imbriques."""
    arc_graphs = {None: []}
    for _, arc_name in arcs:
        arc_graphs[arc_name] = []

    logger.trace('Adding nodes to display graph:')
    node_graph.add_nodes_to_display_graph(display_graph)
    logger.trace('Adding edges to display graph:')
    node_graph.add_edges_to_display_graph(arc_graphs)

    for arc_name, arc_edges in arc_graphs.items():
        logger.trace('Arc %s => size=%s' % (arc_name, len(arc_edges)))
        if arc_name is None:
            for start, end in arc_edges:
                display_graph.edge(start, end)
            continue

        with display_graph.subgraph(name='cluster_%s' % arc_name) as cluster:
            sub_arc_edges = {}
            for edges in arc_edges[:]:
                edge_start_node = node_graph.get_node(int(edges[0]))
                edge_start_sub_arc = edge_start_node.get_sub_arc()
                try:
                    end_id = int(edges[1])
                except ValueError:  # not a classic node, skip this
                    continue
                edge_end_node = node_graph.get_node(end_id)

                # Maybe the two nodes are not in the same sub_arc, so don't link them here
                if edge_end_node.get_sub_arc() != edge_start_sub_arc:
                    logger.trace('%s => skipping not related edge: %s' % (arc_name, edges))
                    continue
                if edge_start_sub_arc is not None:
                    sub_arc_edges.setdefault(edge_start_sub_arc, []).append(edges)
                    arc_edges.remove(edges)
            logger.trace('%s => sub arcs= %s' % (arc_name, sub_arc_edges))
            for sub_arc_name, edges_of_sub_arc in sub_arc_edges.items():
                with cluster.subgraph(name='cluster_%s' % sub_arc_name) as sub_cluster:
                    logger.trace('SUB-ARC=[%s] nb jumps:%s' % (sub_arc_name, len(edges_of_sub_arc)))
                    # Now put the edges in the global cluster, not in a sub arcs
                    sub_cluster.attr(style='filled', color='grey')
                    sub_cluster.edges(edges_of_sub_arc)
                    sub_cluster.attr(label=sub_arc_name)
                    sub_cluster.attr(fontsize="72", fontcolor='red')

            # Now put the edges in the global cluster, not in a sub arcs
            cluster.attr(style='filled', color='lightgrey')
            cluster.edges(arc_edges)
            cluster.attr(label=arc_name)
            cluster.attr(fontsize="72", fontcolor='red')


def _valider_les_objets(book_data: dict, node_graph: Graph, all_objs: dict) -> None:
    """Un objet doit etre a la fois declare (`all_objects.json`) et utilise (aquire/remove/
    condition quelque part) -- dans un sens comme dans l'autre, une divergence est une faute
    de saisie et arrete la compilation."""
    logger.trace('Compute all conditions')
    all_conditions = set()
    for node_id_str in book_data.keys():
        node = node_graph.get_node(int(node_id_str))
        all_conditions |= node.get_all_conditions_token()
        # Un objet cite UNIQUEMENT dans un stats_cond (jamais aquire/remove/condition de
        # saut) doit compter comme utilise : sans cette ligne, il ressort a tort en
        # « declare mais pas utilise » (todo 3.10).
        all_conditions |= node.get_all_stats_cond_tokens()
    logger.trace('All conditions:\n%s' % '\n'.join(sorted([' - %s' % s for s in all_conditions])))

    logger.trace('Compute aquire objects')
    all_aquire = set()
    for node_id_str in book_data.keys():
        node = node_graph.get_node(int(node_id_str))
        for obj in node.get_aquire():
            all_aquire.add(obj)
    logger.trace('All aquire:\n%s' % '\n'.join(sorted([' - %s' % s for s in all_aquire])))

    all_remove = set()
    for node_id_str in book_data.keys():
        node = node_graph.get_node(int(node_id_str))
        for obj in node.get_remove():
            all_remove.add(obj)
    logger.trace('All remove:\n%s' % '\n'.join(sorted([' - %s' % s for s in all_remove])))

    logger.trace('Add without remove:\n%s' % '\n'.join(sorted([' - %s' % s for s in all_aquire - all_remove])))
    logger.trace('Condition NOT aquired:\n%s' % '\n'.join(sorted([' - %s' % s for s in all_conditions - all_aquire])))
    logger.trace('Condition NOT remove:\n%s' % '\n'.join(sorted([' - %s' % s for s in all_conditions - all_remove])))

    all_discoverd_objects = all_remove | all_aquire | all_conditions
    all_objs_names = set(all_objs.keys())

    if all_discoverd_objects != all_objs_names:
        used_but_not_declared = sorted(all_discoverd_objects - all_objs_names)
        if used_but_not_declared:
            print('ERROR: some objects are USED but not declared: %s' % used_but_not_declared)
            sys.exit(2)
        declared_but_not_used = sorted(all_objs_names - all_discoverd_objects)
        if declared_but_not_used:
            print('ERROR: some objects are DECLARED but not used: %s' % declared_but_not_used)
            sys.exit(2)

    remove_but_not_add = all_remove - all_aquire
    if remove_but_not_add:
        print('ERROR: Remove but NOT add:\n%s' % '\n'.join(sorted([' - %s' % s for s in remove_but_not_add])))
        sys.exit(2)


def _valider_les_stats(all_stats_keys: set, livre: dict) -> None:
    """Une cle de stat hors vocabulaire (`critique` au lieu de `crit`, par exemple) passait
    jusqu'ici jusqu'a l'app, qui se contentait d'un `push_warning` (todo 3.2). Le vocabulaire
    PROPRE au livre (ses compteurs, ex. `gloire`/`info`, et ses clefs sans effet comme
    `arc_et_couteau` -- todo 3.5, review §4.6) vient de `<nom>.livre.json`, pas d'ici."""
    compteurs = {c['cle'] for c in livre.get('compteurs', []) if 'cle' in c}
    vocabulaire = ENGINE_STATS_VOCABULARY | compteurs | set(livre.get('ignorees', []))
    inconnues = all_stats_keys - vocabulaire
    if inconnues:
        print('ERROR: unknown stat key(s): %s (known: %s)' % (sorted(inconnues), sorted(vocabulaire)))
        sys.exit(2)


def _verifier_les_secrets(node_graph: Graph, reverse_jumps: dict) -> None:
    """Un secret ne doit avoir qu'un seul chemin d'acces, sauf a le dire explicitement via
    `secret_jumps` -- sinon ce n'en est plus vraiment un."""
    logger.info('Checking for secret reverse jump:')
    logger.info('  - Must be one source')
    logger.info('  - or multiple but ALL are real secret jump')
    logger.info('    => if not, must use secret_jump key in .json, like fdcn1 234->76')
    for node_id, froms in reverse_jumps.items():
        node = node_graph.get_node(node_id)
        if not node.is_secret():
            continue
        prefix = 'OK: ' if len(froms) == 1 else '!!! WARNING => '
        logger.info('%s%3d <- %s' % (prefix, node_id, ', '.join(['%s' % i for i in froms])))


def ecrire_les_json(book_name: str, data_dir: str, book_data: dict, livre: dict, node_graph: Graph,
                     display_graph) -> None:
    """Valide les donnees calculees puis ecrit tout ce que l'app ouvre, en UN SEUL fichier
    (todo 3.6) : les chapitres a plat, les deux tables recopiees telles quelles, et les deux
    index generes pour l'UI. Rien n'est ecrit avant que toutes les validations passent --
    contrairement aux 5 fichiers d'avant, une compilation refusee ne laisse plus le dossier
    de sortie a moitie a jour."""
    logger.info('Conditions parsing:')
    for node_id_str in book_data.keys():
        node = node_graph.get_node(int(node_id_str))
        node.parse_conditions()
        node.parse_stats_conditions()

    all_objs = livre['objets']
    _valider_les_objets(book_data, node_graph, all_objs)

    # Le CALCULE, et a plat. Le chapitre ecrit a la main vit dans `scripts/src/`, il n'a
    # aucune raison d'etre recopie ici : c'etait 28 % du plus gros fichier du depot, et un
    # deuxieme endroit ou lire la meme chose.
    logger.info('Export computed nodes:')
    computed_nodes = {node_id_str: node_graph.get_node(int(node_id_str)).get_computed() for node_id_str in book_data}

    all_success = livre['succes']
    logger.trace('Success txt %s' % all_success)

    def get_success_txt(_id):
        for success in all_success:
            if success['id'] == _id:
                return success['label'], success['txt']
        print('ERROR: success %s is not declared in %s.livre.json (succes)' % (_id, book_name))
        sys.exit(2)

    reverse_jumps = {}
    nodes_by_chapter = {}
    nodes_by_sub_arc = {}
    all_stats_keys = set()
    for node_id_str in book_data.keys():
        node = node_graph.get_node(int(node_id_str))
        # Flag reverse jumps
        for son in node.get_sons():
            reverse_jumps.setdefault(son.get_id(), []).append(int(node_id_str))

        arc = node.get_arc()
        if arc:
            nodes_by_chapter.setdefault(arc, []).append(int(node_id_str))

        sub_arc = node.get_sub_arc()
        if sub_arc:
            nodes_by_sub_arc.setdefault(sub_arc, []).append(int(node_id_str))

        success = node.get_success()
        if success:
            # L'appel VALIDE : un succes que `succes` de `<nom>.livre.json` ne declare pas
            # refuse la compilation. Le resultat, lui, ne sert plus a rien -- l'app lit la
            # table elle-meme et y ajoute le chapitre au chargement.
            get_success_txt(success)

        all_stats_keys |= node.get_all_stats_keys()

    _verifier_les_secrets(node_graph, reverse_jumps)

    logger.info('Checking all stats keys: %d' % len(all_stats_keys))
    for stat_key in sorted(all_stats_keys):
        logger.info(' - %s' % stat_key)
    _valider_les_stats(all_stats_keys, livre)

    # CE QUE L'APP OUVRE, ET RIEN D'AUTRE, EN UN SEUL FICHIER (todo 3.6). Sept sorties
    # avaient deja disparu le 2026-08-13 (combats, secrets, endings, good-endings,
    # bad-endings -- tout ca se lit chapitre par chapitre dans `chapters` ; success,
    # success-chapters, all-objects -- des copies enrichies que `BookData` refait elle-meme
    # au chargement). Il restait 3 fichiers calcules + 2 tables recopiees telles quelles :
    # `objects`/`success` sont ces memes tables, RAW -- `BookData` les complete encore au
    # chargement (`in_chapters`, `chapter`, index chapitre -> succes), rien ne change de ce
    # cote-la. `counters`/`ignored` viennent de `<nom>.livre.json` (todo 3.8) : plus de
    # `compteurs.json` a part dans `data/`.
    compiled = {
        'chapters': computed_nodes,
        'nodes_by_chapter': nodes_by_chapter,
        'nodes_by_sub_arc': nodes_by_sub_arc,
        'objects': all_objs,
        'success': all_success,
        'counters': livre.get('compteurs', []),
        'ignored': livre.get('ignorees', []),
    }
    with codecs.open(f'{data_dir}/{book_name}-compilated.json', 'w', 'utf8') as f:
        f.write(json.dumps(compiled, indent=4, ensure_ascii=False, sort_keys=True))
    logger.info(' - %s-compilated.json = OK' % book_name)

    # Windows need too many deps, like dot.exe, so skip on it
    if os.name != 'nt':
        logger.info('Rendering')
        display_graph.render()


def main():
    args = parse_args()
    logger.VERBOSE = args.verbose

    if args.nouveau is not None:
        creer_nouveau_livre(args.nouveau)
        return

    # Le registre est la SEULE liste de livres du depot : le compilateur la lit comme l'app,
    # donc ajouter un livre ne demande de rouvrir ni ce fichier ni le moindre script Godot.
    livres = load_json_file(REGISTRE)['livres']
    book_names = [livre['nom'] for livre in livres]
    book_name = resolve_book_name(args.book, book_names)
    print(f'Vous avez choisi le livre {book_name}.')

    display_graph = new_display_graph(book_name)

    # DEUX dossiers, et la separation est nette :
    #
    #   scripts/src/<nom>/   ce qu'un humain ECRIT, et que l'app n'ouvre jamais : le livre et
    #                        son decoupage en actes. `scripts/` porte un `.gdignore`, donc rien
    #                        de tout ca ne part dans l'application.
    #   books/<nom>/data/    ce que l'app LIT : les sorties compilees, plus les objets et les
    #                        succes -- ecrits a la main mais completes au chargement par
    #                        `BookData`, donc de vrais fichiers d'application.
    #
    # Voir books/README.md et l'entete de ce README.
    src_dir = f'scripts/src/{book_name}'
    book_dir = f'books/{book_name}'
    data_dir = f'{book_dir}/data'

    # Cree AVANT la premiere ecriture : un livre neuf n'a pas encore de dossier de sortie, et
    # echouer au milieu du travail serait le pire moment.
    if not os.path.isdir(data_dir):
        os.makedirs(data_dir)

    book_data = load_json_file(f'{src_dir}/{book_name}.json')
    # Les tables du livre (todo 3.8) : actes, sous-arcs (propages et manuels), objets,
    # succes, compteurs et clefs ignorees -- tout ce qu'un auteur ecrit a la main a cote du
    # dictionnaire de chapitres, dans UN fichier a champs nommes plutot que 5 tableaux
    # positionnels.
    livre = load_json_file(f'{src_dir}/{book_name}.livre.json')
    node_graph = Graph()
    lire_les_noeuds(book_data, node_graph)

    arcs = [(acte['depart'], acte['nom']) for acte in livre['actes']]
    sub_arcs = [(sa['acte'], sa['depart'], sa['nom'], sa['fins']) for sa in livre['sous_arcs']]
    manual_sub_arcs = livre['sous_arcs_manuels']
    taguer_les_arcs(node_graph, arcs, sub_arcs, manual_sub_arcs)

    construire_le_graphe(node_graph, display_graph, arcs)

    print('Writing compilated data')
    ecrire_les_json(book_name, data_dir, book_data, livre, node_graph, display_graph)

    print('Finish')


if __name__ == '__main__':
    main()
