{ pkgs, ... }:
pkgs.writers.writePython3Bin "graphml2json" { libraries = [ pkgs.python3Packages.networkx ]; } ''
  import networkx as nx
  import json
  import sys


  G = nx.read_graphml(sys.argv[1])
  data = nx.readwrite.json_graph.node_link_data(G)

  print(json.dumps(data, indent=2))
''
