# -*- coding: utf-8 -*-

import contextlib
import json
import sys
import codecs
import os
import argparse

# graphviz ne sert QU'A dessiner le png de relecture : l'app ne le lit jamais, et le
# compilateur produisait pourtant zero json sans lui. Refuser de compiler les donnees du
# jeu faute d'une dependance de confort est le mauvais arbitrage -- d'ou l'import garde.
try:
    import graphviz
except ImportError:
    graphviz = None


class GrapheMuet(object):
    """Bouchon de graphviz : accepte tout, ne dessine rien."""

    def node(self, *args, **kwargs):
        pass

    def edge(self, *args, **kwargs):
        pass

    def edges(self, *args, **kwargs):
        pass

    def attr(self, *args, **kwargs):
        pass

    def render(self, *args, **kwargs):
        print('NOTE: graphviz absent, pas de rendu du graphe (pip install graphviz + le binaire dot)')

    @contextlib.contextmanager
    def subgraph(self, *args, **kwargs):
        yield self

# NOTE: I don't want a real package name for just a couple of files, so keep like this currently
my_dir = os.path.dirname(__file__)
sys.path.insert(0, my_dir)

from graph import Graph
from endings import ENDINGS

REGISTRE = 'books/books.json'

parser = argparse.ArgumentParser(description="Compile all .json for the UI app")
parser.add_argument("--book", help=f"Nom du livre a compiler (le dossier books/<nom>/), ou son rang dans {REGISTRE}")

args = parser.parse_args()

if args.book is None:
    print('ERROR: Missing --book parameter')
    sys.exit(2)


def load_json_file(file_name):
    # type: (str) -> Any
    with codecs.open(file_name, 'r', 'utf8') as f:
        data = json.loads(f.read())
    return data


# Le registre est la SEULE liste de livres du depot : le compilateur la lit comme l'app,
# donc ajouter un livre ne demande de rouvrir ni ce fichier ni le moindre script Godot.
livres = load_json_file(REGISTRE)['livres']
book_names = [livre['nom'] for livre in livres]

book_name = args.book
# Retro-compatibilite : `--book 1` / `--book 2` designaient les livres par leur rang.
if book_name.isdigit():
    rang = int(book_name) - 1
    if rang < 0 or rang >= len(book_names):
        print('ERROR: no book number %s, %s declares %d books' % (book_name, REGISTRE, len(book_names)))
        sys.exit(2)
    book_name = book_names[rang]

if book_name not in book_names:
    print('ERROR: unknown book: %s. %s declares: %s' % (book_name, REGISTRE, ', '.join(book_names)))
    sys.exit(2)

print(f'Vous avez choisi le livre {book_name}.')

if graphviz is None:
    print('NOTE: graphviz absent : les json seront compiles, mais pas le graphe png')
    display_graph = GrapheMuet()
else:
    display_graph = graphviz.Digraph('G', filename=f'scripts/graph/fdcn_full-{book_name}', format='png')

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

node_created = set()

node_graph = Graph()
for node_id_str in book_data.keys():
    node_graph.create_node(node_id_str)

for idx, n in book_data.items():
    idx = int(idx)
    
    node = node_graph.get_node(idx)
    
    # Get the success entry if any
    success = n.get('success', None)
    if success:
        node.set_sucess(success)
    
    # Get the combat entry if any
    combat = n.get('combat', None)
    if combat is not None:
        node.set_combat(combat)
    
    # Get the combat entry if any
    secret = n.get('secret', False)
    if secret:
        node.set_secret()
    
    # Get the conditions
    conditions = n.get('conditions', "")
    if conditions:
        node.set_conditions(conditions)
    
    # Get the label if any
    label = n.get('label', None)
    if label:
        node.set_label(label)
    
    secret_jumps = n.get('secret_jumps', None)
    if secret_jumps is not None:
        node.set_secret_jumps(secret_jumps)
    
    aquire = n.get('aquire', [])
    node.set_aquire(aquire)
    
    remove = n.get('remove', [])
    node.set_remove(remove)
    
    stats = n.get('stats', {})
    node.set_stats(stats)
    
    stats_cond = n.get('stats_cond', {})
    node.set_stats_cond(stats_cond)
    
    goto = n.get('goto', [])
    if isinstance(goto, int):
        goto = [goto]
    goto = node.get_all_possibles_goto(goto)
    print(f' possible goto:{n.get("goto", [])} => {goto}')
    # goto = n['goto']
    
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

# [1, "Plante-Citrouille"]
arcs = load_json_file(f'{src_dir}/{book_name}.arcs.json')

# (arc_name, Start of sub, name, stops)
sub_arcs = load_json_file(f'{src_dir}/{book_name}.sub_arcs.json')

manual_sub_arcs = load_json_file(f'{src_dir}/{book_name}.manual_sub_arcs.json')

# Tag nodes with arc, from lower to higher so we don't rewrite them
for arc_start, arc_name in reversed(arcs):
    print('Tagging arc: %s (%s)' % (arc_start, arc_name))
    arc_node_start = node_graph.get_node(arc_start)  # type: Node
    arc_node_start.set_in_arc(arc_name)

for arc_name, sub_arc_start, sub_arc_name, sub_arc_stops in sub_arcs:
    node_start = node_graph.get_node(sub_arc_start)
    node_start.set_in_sub_arc(sub_arc_name, sub_arc_stops, 0)

for sub_arc_name, node_ids in manual_sub_arcs.items():
    print('Sub arc (manual): %s => %s' % (sub_arc_name, node_ids))
    for node_id in node_ids:
        node = node_graph.get_node(node_id)
        node.set_in_sub_arc_not_recursive(sub_arc_name)

arc_graphs = {None: []}
for _, arc_name in arcs:
    arc_graphs[arc_name] = []

print('Adding nodes to display graph:')
node_graph.add_nodes_to_display_graph(display_graph)
print('Adding edges to display graph:')
node_graph.add_edges_to_display_graph(arc_graphs)

# Now put nodes into graphs and clusters
for arc_name, arc_edges in arc_graphs.items():
    print('Arc %s => size=%s' % (arc_name, len(arc_edges)))
    if arc_name is None:
        for start, end in arc_edges:
            display_graph.edge(start, end)
    else:
        with display_graph.subgraph(name='cluster_%s' % arc_name) as cluster:
            sub_arc_edges = {}
            for edges in arc_edges[:]:
                edge_start_node = node_graph.get_node(int(edges[0]))  # type: Node
                edge_start_sub_arc = edge_start_node.get_sub_arc()
                try:
                    end_id = int(edges[1])
                except ValueError:  # not a classic node, skip this
                    continue
                edge_end_node = node_graph.get_node(end_id)  # type: Node
                
                # Maybe the two nodes are not in the same sub_arc, so don't link them here
                if edge_end_node.get_sub_arc() != edge_start_sub_arc:
                    print('%s => skipping not related edge: %s' % (sub_arc_name, edges))
                    continue
                if edge_start_sub_arc is not None:
                    if edge_start_sub_arc not in sub_arc_edges:
                        sub_arc_edges[edge_start_sub_arc] = []
                    sub_arc_edges[edge_start_sub_arc].append(edges)
                    arc_edges.remove(edges)
            print('%s => sub arcs= %s' % (arc_name, sub_arc_edges))
            for sub_arc_name, sub_arc_edges in sub_arc_edges.items():
                with cluster.subgraph(name='cluster_%s' % sub_arc_name) as sub_cluster:
                    print('SUB-ARC=[%s] nb jumps:%s' % (sub_arc_name, len(sub_arc_edges)))
                    # Now put the edges in the global cluster, not in a sub arcs
                    sub_cluster.attr(style='filled', color='grey')
                    sub_cluster.edges(sub_arc_edges)
                    sub_cluster.attr(label=sub_arc_name)
                    sub_cluster.attr(fontsize="72", fontcolor='red')
            
            # Now put the edges in the global cluster, not in a sub arcs
            cluster.attr(style='filled', color='lightgrey')
            cluster.edges(arc_edges)
            cluster.attr(label=arc_name)
            cluster.attr(fontsize="72", fontcolor='red')

print('Writing compilated data')
# Modify the book data with what we did compute

print('Conditions parsing:')
for node_id_str in book_data.keys():
    node = node_graph.get_node(int(node_id_str))
    node.parse_conditions()
    node.parse_stats_conditions()

print('Compute all conditions')
all_conditions = set()
for node_id_str in book_data.keys():
    node = node_graph.get_node(int(node_id_str))
    conds = node.get_all_conditions_token()
    all_conditions |= conds

print('All conditions:\n%s' % '\n'.join(sorted([' - %s' % s for s in all_conditions])))

print('Compute aquire objects')
all_aquire = set()
for node_id_str in book_data.keys():
    node = node_graph.get_node(int(node_id_str))
    for obj in node._aquire:
        all_aquire.add(obj)
print('All aquire:\n%s' % '\n'.join(sorted([' - %s' % s for s in all_aquire])))

all_remove = set()
for node_id_str in book_data.keys():
    node = node_graph.get_node(int(node_id_str))
    for obj in node._remove:
        all_remove.add(obj)
print('All remove:\n%s' % '\n'.join(sorted([' - %s' % s for s in all_remove])))

add_no_remove = all_aquire - all_remove
print('Add without remove:\n%s' % '\n'.join(sorted([' - %s' % s for s in add_no_remove])))

conditions_not_aquire = all_conditions - all_aquire
print('Condition NOT aquired:\n%s' % '\n'.join(sorted([' - %s' % s for s in conditions_not_aquire])))

conditions_not_remove = all_conditions - all_remove
print('Condition NOT remove:\n%s' % '\n'.join(sorted([' - %s' % s for s in conditions_not_remove])))

all_discoverd_objects = all_remove | all_aquire | all_conditions

all_objs = load_json_file(f'{src_dir}/{book_name}.all_objects.json')
all_objs_names = set(all_objs.keys())

if all_discoverd_objects != all_objs_names:
    used_but_not_declared = all_discoverd_objects - all_objs_names
    if used_but_not_declared:
        used_but_not_declared = sorted(used_but_not_declared)
        print('ERROR: some objects are USED but not declared: %s' % used_but_not_declared)
        sys.exit(2)
    declared_but_not_used = all_objs_names - all_discoverd_objects
    if declared_but_not_used:
        declared_but_not_used = sorted(list(declared_but_not_used))
        print('ERROR: some objects are DECLARED but not used: %s' % declared_but_not_used)
        sys.exit(2)

remove_but_not_add = all_remove - all_aquire
if remove_but_not_add:
    print('ERROR: Remove but NOT add:\n%s' % '\n'.join(sorted([' - %s' % s for s in remove_but_not_add])))
    sys.exit(2)

# On n'exporte que le CALCULE, et a plat. Le chapitre ecrit a la main vit dans
# `scripts/src/`, il n'a aucune raison d'etre recopie ici : c'etait 28 % du plus gros
# fichier du depot, et un deuxieme endroit ou lire la meme chose.
print('Export computed nodes:')
computed_nodes = {}
for node_id_str in book_data:
    computed_nodes[node_id_str] = node_graph.get_node(int(node_id_str)).get_computed()

new_book_data_string = json.dumps(computed_nodes, indent=4, ensure_ascii=False, sort_keys=True)  # allow utf8
with codecs.open(f'{data_dir}/{book_name}-compilated-data.json', 'w', 'utf8') as f:
    f.write(new_book_data_string)

sucess_txt = load_json_file(f'{src_dir}/{book_name}.all_success.json')
print('Success txt', sucess_txt)


def get_success_txt(_id):
    for success in sucess_txt:
        if success['id'] == _id:
            return success['label'], success['txt']
    raise Exception('Success: %s not found' % _id)


reverse_jumps = {}

nodes_by_chapter = {}
nodes_by_sub_arc = {}
all_stats_keys = set()
for node_id_str in book_data.keys():
    node = node_graph.get_node(int(node_id_str))
    # Flag reverse jumps
    for son in node.get_sons():
        son_id = son.get_id()
        if son_id not in reverse_jumps:
            reverse_jumps[son_id] = []
        reverse_jumps[son_id].append(int(node_id_str))
    
    arc = node.get_arc()
    if arc:
        if arc not in nodes_by_chapter:
            nodes_by_chapter[arc] = []
        nodes_by_chapter[arc].append(int(node_id_str))
    
    sub_arc = node.get_sub_arc()
    if sub_arc:
        if sub_arc not in nodes_by_sub_arc:
            nodes_by_sub_arc[sub_arc] = []
        nodes_by_sub_arc[sub_arc].append(int(node_id_str))
    
    success = node.get_success()
    if success:
        # L'appel VALIDE : un succes que `<nom>.all_success.json` ne declare pas leve une
        # exception. Le resultat, lui, ne sert plus a rien -- l'app lit la table elle-meme
        # et y ajoute le chapitre au chargement.
        get_success_txt(success)
    
    # If the node have some items, list them
    aquire = set(node.get_aquire())
    remove = set(node.get_remove())
    node_all_objs = aquire | remove
    # print('NODE %s have objects: %s' % (node_id_str, node_all_objs))
    for obj in node_all_objs:
        entry = all_objs[obj]
        in_chapters = entry.get('in_chapters', [])
        in_chapters.append(int(node_id_str))
        entry['in_chapters'] = in_chapters
    
    n_stats_keys = node.get_all_stats_keys()
    all_stats_keys = all_stats_keys.union(n_stats_keys)

# Set objects that are not in specific chapter that they are ok since chapter 1
for obj_name, entry in all_objs.items():
    if 'in_chapters' not in entry:
        entry['in_chapters'] = [1]  # so will be seens always
        print('  ** Defaulting object: %s' % obj_name)
    if 'stats' not in entry:
        entry['stats'] = {}

# Check for secrets that should NOT be accessible by 2 ways
print('Checking for secret reverse jump:')
print('  - Must be one source')
print('  - or multiple but ALL are real secret jump')
print('    => if not, must use secret_jump key in .json, like fdcn1 234->76')

for node_id, froms in reverse_jumps.items():
    node = node_graph.get_node(node_id)
    prefix = 'OK: ' if node.is_secret() else ''
    if not node.is_secret():
        continue
    if len(froms) != 1:
        prefix = '!!! WARNING => '
    print('%s%3d <- %s' % (prefix, node_id, ', '.join(['%s' % i for i in froms])))

print('Checking all stats keys: %d' % len(all_stats_keys))
all_stats_keys = list(all_stats_keys)
all_stats_keys.sort()
for stat_key in all_stats_keys:
    print(' - %s' % stat_key)

# CE QUE L'APP OUVRE, ET RIEN D'AUTRE. Sept sorties ont disparu le 2026-08-13 :
#
#   combats, secrets, endings, good-endings, bad-endings   personne ne les chargeait : tout
#       ca se lit chapitre par chapitre dans `-compilated-data.json` ;
#   success, success-chapters, all-objects   des copies enrichies qui repetaient les
#       libelles, categories et textes de `<nom>.all_success.json` et
#       `<nom>.all_objects.json`. `BookData` lit ces deux-la et les complete au chargement
#       (`in_chapters`, `chapter`, index chapitre -> succes).
#
to_dump_as_json = {
    'nodes-by-chapter': nodes_by_chapter,
    'nodes-by-sub-arc': nodes_by_sub_arc,
}

# Les deux tables ecrites a la main que l'app lit AUSSI : elle ne peut pas aller les
# chercher dans `scripts/` (dossier ignore par Godot), donc le compilateur les recopie
# telles quelles. C'est une sortie comme une autre -- la source, elle, reste unique.
for a_copier in (f'{book_name}.all_objects.json', f'{book_name}.all_success.json'):
    with codecs.open(f'{src_dir}/{a_copier}', 'r', 'utf8') as source:
        with codecs.open(f'{data_dir}/{a_copier}', 'w', 'utf8') as destination:
            destination.write(source.read())
    print(' - %s = COPIE' % a_copier)

print('Generating json files for UI')
for (k, v) in to_dump_as_json.items():
    with codecs.open(f'{data_dir}/{book_name}-compilated-{k}.json', 'w', 'utf8') as f:
        f.write(json.dumps(v, indent=4, ensure_ascii=False, sort_keys=True))
        print(' - %s = OK' % k)

# Windows need too many deps, like dot.exe, so skip on it
if os.name != 'nt':
    print('Rendering')
    # display_graph.render(filename='hello.gv', view=True)#format='json')
    display_graph.render()  # format='png')

print('Finish')
