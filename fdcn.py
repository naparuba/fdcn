# -*- coding: utf-8 -*-

import graphviz
import json
import sys

display_graph = graphviz.Digraph('G', filename='graph/fdcn', format='png')

with open('fdcn-1.json', 'r') as f:
    book_data = json.loads(f.read())

# print(book_data)


node_created = set()


class ENDINGS:
    GOOD = 1
    BAD = 2


class Graph(object):
    def __init__(self):
        self._nodes = {}
    
    
    def create_node(self, nid):
        nid = int(nid)
        node = Node(nid)
        self._nodes[nid] = node
        # print(' - %s created' % nid)
    
    
    def set_ending_node(self, nid, ending):
        node = self._nodes[nid]
        node.set_ending(ending)
    
    
    def get_node(self, node_id):
        return self._nodes[node_id]
    
    
    def add_nodes_to_display_graph(self, display_graph):
        for node in self._nodes.values():
            node.add_node_to_display_graph(display_graph)
    
    
    def add_edges_to_display_graph(self, arc_graphs):
        for node in self._nodes.values():
            node.add_edges_to_display_graph(arc_graphs)


class Node(object):
    def __init__(self, nid):
        _id = int(nid)
        self._id = _id
        
        self._ending = None
        self._success = None
        
        self._sons = []
        
        self._is_chapter_start = False
        
        self._arc = None
    
    
    def get_id(self):
        return self._id
    
    
    def get_arc(self):
        return self._arc
    
    
    def set_ending(self, ending):
        self._ending = ending
    
    
    def set_sucess(self, success):
        self._success = success
    
    
    def _get_ending_color(self):
        return {ENDINGS.GOOD: 'darkseagreen1', ENDINGS.BAD: 'crimson'}.get(self._ending)  # we are sure it's one of this value
    
    
    def _get_border_color(self):
        if self._success is not None:
            return 'gold'
        return 'black'
    
    def _get_penwidth(self):
        if self._success is not None:
            return '3.0'
        return '1.0'
    
    
    def add_son(self, son):
        self._sons.append(son)
    
    
    def add_node_to_display_graph(self, display_graph):
        graph = display_graph
        
        border_color= self._get_border_color()
        penwidth = self._get_penwidth()
        
        if self._is_chapter_start:
            node_id_string = '%s' % self._id
            graph.node(node_id_string, shape='doubleoctagon', style='filled', color=border_color, penwidth=penwidth, fillcolor='green', label='%s' % (node_id_string))
        elif self._ending is not None:
            # First myself
            node_id_string = '%s' % self._id
            graph.node(node_id_string, shape='ellipse', style='solid', color=border_color, penwidth=penwidth, fillcolor='white', label='%s' % (node_id_string))
            
            # And also add the visual ending node
            node_id_string = "end-from-%s" % self._id
            graph.node(node_id_string, shape='doubleoctagon', style='filled', color=border_color, penwidth=penwidth, fillcolor=self._get_ending_color(), label='End (%s)' % self._id)
        else:  # classic node
            node_id_string = '%s' % self._id
            graph.node(node_id_string, label='%s' % (node_id_string), color=border_color, penwidth=penwidth, shape='ellipse', style='solid', fillcolor='white')
    
    
    def _get_graph_from_nodes(self, other, arc_graphs):
        # type (Node, Any) -> None
        if self._arc is None or other.get_arc() is None:
            return arc_graphs[None]
        if self._arc == other.get_arc():
            graph = arc_graphs[self._arc]
            # print(' %s && %s == %s' % (self.get_id(), other.get_id(), self._arc))
            return graph
        return arc_graphs[None]
    
    
    def add_edges_to_display_graph(self, arc_graphs):
        node_string = '%s' % self._id
        
        if self._ending is not None:
            # And also add the visual ending node
            end_node_string = "end-from-%s" % self._id
            _graph = self._get_graph_from_nodes(self, arc_graphs)  # Lie: it's us, so we will be in our arc
            # _graph.edges([(node_string, end_node_string)])
            _graph.append((node_string, end_node_string))
            # print('%s -> %s' % (node_string, end_node_string))
        else:  # classic node
            for son in self._sons:
                son_string = '%s' % son.get_id()
                _graph = self._get_graph_from_nodes(son, arc_graphs)
                # _graph.edges([(node_string, son_string)])
                _graph.append((node_string, son_string))
                # print('%s -> %s' % (node_string, son_string))
    
    
    def set_in_arc(self, arc_name):
        if self._arc is not None:
            return
        self._arc = arc_name
        # print('   [%s] Set in arc=%s' % (self._id, self._arc))
        for son in self._sons:
            #if son in not_allowed_nodes:
            #    print('  [%s] Skipping breaking son: %s ' % (self._id, son.get_id()))
            #    continue
            son.set_in_arc(arc_name)


node_graph = Graph()
for node_id_str in book_data.keys():
    node_graph.create_node(node_id_str)

for idx, n in book_data.items():
    idx = int(idx)
    
    node = node_graph.get_node(idx)

    success = n.get('success', None)
    if success:
        node.set_sucess(success)
    
    goto = n['goto']
    
    gotos = []
    if isinstance(goto, int):
        if goto == 608:
            ending = n.get('ending', None)
            if ending is None:
                print('ERROR: node %s is an end without ending' % idx)
                sys.exit(2)
            _ending = {'good': ENDINGS.GOOD, 'bad': ENDINGS.BAD}.get(ending, None)
            if _ending is None:
                print('ERROR: node %s have an unknown ending string: %s' % (idx, ending))
                sys.exit(2)
            
            node.set_ending(_ending)
        else:
            son = node_graph.get_node(goto)
            node.add_son(son)
    else:  # list
        for dest_idx in goto:
            son = node_graph.get_node(dest_idx)
            node.add_son(son)
        # gotos = [dest_idx for dest_idx in goto]
    
    # for dest_idx in gotos:
    #    display_graph.edge('%s' % idx, dest_idx)

# g.edge('Hello', 'World')


arcs = [(1, 'start'),
        (100, 'Lenonia'),
        (193, 'Cathedrale'),
        (216, 'Tour des mages'),
        (323, 'Prison'),
        (300, 'Invasion'),
        (400, 'Forteresse'),
        (500, 'Virilus')
        ]

#stopping_arc_ids = []  # some nodes are breaking the arc tagging, tag them
#not_allowed_nodes = [node_graph.get_node(stopping_id) for stopping_id in stopping_arc_ids]

for arc_start, arc_name in reversed(arcs):
    print('Tagging arc: %s (%s)' % (arc_start, arc_name))
    arc_node_start = node_graph.get_node(arc_start)  # type: Node
    arc_node_start.set_in_arc(arc_name)

arc_graphs = {None: []}
for _, arc_name in arcs:
    arc_graphs[arc_name] = []

print('Adding nodes to display graph:')
node_graph.add_nodes_to_display_graph(display_graph)
print('Adding edges to display graph:')
node_graph.add_edges_to_display_graph(arc_graphs)

for arc_name, arc_edges in arc_graphs.items():
    print('Arc %s => size=%s' % (arc_name, len(arc_edges)))
    if arc_name is None:
        for start, end in arc_edges:
            display_graph.edge(start, end)
    else:
        with display_graph.subgraph(name='cluster_%s' % arc_name) as cluster:
            cluster.attr(style='filled', color='lightgrey')
            cluster.edges(arc_edges)
            cluster.attr(label=arc_name)
            cluster.attr(fontsize="72", fontcolor='red')

print('Rendering')
display_graph.render(renderer='gdiplus', formatter='gdiplus')
# g.view()
