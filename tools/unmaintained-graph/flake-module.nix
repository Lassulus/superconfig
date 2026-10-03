{ ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      d3 = pkgs.fetchurl {
        url = "https://cdn.jsdelivr.net/npm/d3@7.9.0/dist/d3.min.js";
        hash = "sha256-8glLv2FBs1lyLE/kVOtsSw8OQswQzHr5IfwVj864ZTk=";
      };
    in
    {
      # nix itself is deliberately not a runtime input: use the caller's nix,
      # which matches the flake's lock file and the local store.
      packages.unmaintained-graph =
        (pkgs.writeShellApplication {
          name = "unmaintained-graph";
          runtimeInputs = [ pkgs.python3 ];
          text = ''
            export UNMAINTAINED_GRAPH_TEMPLATE=${./graph.html}
            export UNMAINTAINED_GRAPH_D3=${d3}
            exec python3 ${./unmaintained_graph.py} "$@"
          '';
        }).overrideAttrs
          { passthru.usage = builtins.readFile ./usage.kdl; };
    };
}
