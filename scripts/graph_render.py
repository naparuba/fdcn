# -*- coding: utf-8 -*-

## Tout ce qui transforme un Node en apparence graphviz (couleur, forme, libelle HTML). Le
## modele de donnees (`node.py`, `graph.py`) ne sait rien de graphviz -- seul ce module et
## `generator.py` l'importent. Lit les attributs de `Node` directement (deja la convention
## de `generator.py` sur `_aquire`/`_remove`), plutot que d'ajouter des accesseurs qui
## n'existent que pour cet usage.

import contextlib

from endings import ENDINGS

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


def new_display_graph(book_name: str):
    """`graphviz.Digraph` si la dependance est installee, sinon un bouchon qui ne dessine
    rien : le compilateur ne doit jamais refuser d'ecrire les json d'un livre faute d'un
    outil de rendu qui ne sert qu'a la relecture humaine."""
    if graphviz is None:
        print('NOTE: graphviz absent : les json seront compiles, mais pas le graphe png')
        return GrapheMuet()
    return graphviz.Digraph('G', filename=f'scripts/graph/fdcn_full-{book_name}', format='png')


def get_label(node):
    if node._label:
        return '<%s-<FONT COLOR="blue" POINT-SIZE="20">%s</FONT> >' % (node._id, node._label)
    if node._secret:
        return '<<B><FONT COLOR="orange" POINT-SIZE="20">%s</FONT></B>>' % (node._id)
    if node._combat is not None:
        return '<<B><FONT COLOR="red" POINT-SIZE="20">%s</FONT></B>>' % (node._id)
    return '%s' % node._id


def _get_ending_color(node):
    return {ENDINGS.GOOD: 'darkseagreen1', ENDINGS.BAD: 'crimson'}.get(node._ending)  # on est sur que c'est l'une de ces valeurs


def _get_border_color(node):
    if node._success is not None:
        return 'gold'
    return 'black'


def _get_penwidth(node):
    if node._success is not None:
        return '3.0'
    return '1.0'


def add_node_to_display_graph(node, display_graph):
    border_color = _get_border_color(node)
    penwidth = _get_penwidth(node)

    if node._ending is not None:
        node_id_string = '%s' % node._id
        display_graph.node(node_id_string, shape='ellipse', style='solid', color=border_color, penwidth=penwidth,
                            fillcolor='white', label=get_label(node))

        node_id_string = "end-from-%s" % node._id
        display_graph.node(node_id_string, shape='doubleoctagon', style='filled', color=border_color,
                            penwidth=penwidth, fillcolor=_get_ending_color(node), label='End (%s)' % node._id)
    else:  # classic node
        node_id_string = '%s' % node._id
        display_graph.node(node_id_string, color=border_color, penwidth=penwidth, shape='ellipse', style='solid',
                            fillcolor='white', label=get_label(node))


def _get_graph_from_nodes(node, other, arc_graphs):
    if node._arc is None or other.get_arc() is None:
        return arc_graphs[None]
    if node._arc == other.get_arc():
        return arc_graphs[node._arc]
    return arc_graphs[None]


def add_edges_to_display_graph(node, arc_graphs):
    node_string = '%s' % node._id

    if node._ending is not None:
        end_node_string = "end-from-%s" % node._id
        _graph = _get_graph_from_nodes(node, node, arc_graphs)  # C'est nous-memes : on sera dans notre propre arc
        _graph.append((node_string, end_node_string))
    else:  # classic node
        for son in node.get_sons():
            son_string = '%s' % son.get_id()
            _graph = _get_graph_from_nodes(node, son, arc_graphs)
            _graph.append((node_string, son_string))
