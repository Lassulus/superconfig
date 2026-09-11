{ lib }:

# Retiolum nodes that deliberately have no card in the shared kartei registry:
# they exist only inside superconfig, so every superconfig machine has to be
# told about them explicitly. Exposed as self.retiolum (see ./flake-module.nix)
# and consumed by 2configs/retiolum.nix (NixOS, via nixpkgs services.tinc) and
# machines/barnacle/retiolum.nix (darwin, via kartei's tincr module), so both
# platforms agree on the peer set.
#
# This is data, not a module -- same shape as keys/.
#
# Cards use the same nets.<net> layout as kartei and krebs.hosts, and the
# renderer below mirrors kartei's modules/retiolum/hosts.nix, so an entry can
# move into kartei/lass unchanged if it should become reachable by the rest of
# krebs rather than just the fleet.
let
  # Only the public half, and only from the node's own committed clan vars --
  # nothing secret and no second copy to keep in sync. tincr writes it as a
  # ready-made `Ed25519PublicKey = <key>` line, so keep just the key.
  ed25519 =
    machine:
    lib.last (
      lib.splitString " " (
        lib.removeSuffix "\n" (
          builtins.readFile (../vars/per-machine + "/${machine}/retiolum/retiolum.ed25519_key.pub/value")
        )
      )
    );

  retiolumOf = host: host.nets.retiolum;

  # Own addresses in the net, rendered as Subnet lines (implicit /32 and /128).
  addrsOf =
    net:
    lib.optional (net.ip4 or null != null) net.ip4.addr
    ++ lib.optional (net.ip6 or null != null) net.ip6.addr;

  tincHostFile =
    name: host:
    let
      net = retiolumOf host;
      tinc = net.tinc or { };
      # A node with a via net is dialable there; everyone else is relayed.
      via = if net.via or null != null then host.nets.${net.via} else null;
    in
    lib.concatStringsSep "\n" (
      lib.optionals (via != null) (
        map (addr: "Address = ${addr} ${toString (tinc.port or 655)}") via.addrs
      )
      ++ map (addr: "Subnet = ${addr}") (addrsOf net)
      # bare labels: tincr's DNS stub appends its suffix
      ++ map (alias: "Alias = ${alias}") (
        lib.filter (alias: alias != name) (
          map (lib.removeSuffix ".r") (lib.filter (lib.hasSuffix ".r") (net.aliases or [ ]))
        )
      )
      ++ [ "Ed25519PublicKey = ${tinc.pubkey_ed25519}" ]
      ++ lib.optional (tinc.weight or 300 != null) "Weight = ${toString (tinc.weight or 300)}"
    );
in
rec {
  hosts = {
    starkstrom = {
      nets = {
        # Hetzner KVM box; static address, and 2configs/retiolum.nix opens 655,
        # so peers dial it directly instead of relaying through neoprism/prism.
        internet.addrs = [ "194.110.87.67" ];
        retiolum = {
          via = "internet";
          ip4.addr = "10.243.0.100";
          ip6.addr = "42:0:ce16::100";
          aliases = [ "starkstrom.r" ];
          tinc.pubkey_ed25519 = ed25519 "starkstrom";
        };
      };
    };
  };

  # Same interface kartei's modules/retiolum/hosts.nix exposes, so consumers
  # can treat both sources the same way.
  tincHosts = lib.mapAttrs tincHostFile hosts;

  own = lib.mapAttrs (_: host: {
    ip4 = (retiolumOf host).ip4.addr or null;
    ip6 = (retiolumOf host).ip6.addr or null;
  }) hosts;
}
