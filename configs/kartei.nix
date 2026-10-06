# Host and user data from the kartei flake input, rendered straight into
# NixOS options; stockholm's krebs.hosts (and its hosts/ssh/build modules) is
# not used. Hosts are kartei's plus the superconfig-only cards in ../retiolum.
# Our own users are defined here from ../keys, not taken from kartei.
{
  config,
  lib,
  self,
  ...
}:
let
  inherit (self.inputs) kartei;

  hosts = kartei.hosts // self.retiolum.hosts;

  # Name suffixes that go into /etc/hosts; ".r" names also get a bare short
  # form (barnacle.r -> barnacle), as stockholm's krebs.dns did.
  domains = [
    "r"
    "i"
    "w"
    "shack"
  ];
  hostDomain = alias: lib.any (d: lib.hasSuffix ".${d}" alias) domains;
  shortsOf = aliases: map (lib.removeSuffix ".r") (lib.filter (lib.hasSuffix ".r") aliases);

  # superconfig's own cards (../retiolum) only carry ip4/ip6/aliases
  netAddrs =
    net:
    net.addrs or (
      lib.optional (net.ip4 or null != null) net.ip4.addr
      ++ lib.optional (net.ip6 or null != null) net.ip6.addr
    );
  netAliases = net: net.aliases or [ ];
  sshPort = net: net.ssh.port or 22;

  allNets = lib.concatMap (host: lib.attrValues (host.nets or { })) (lib.attrValues hosts);

  ownUsers = {
    lass = {
      mail = "lass@green.r";
      pgp.pubkeys.default = builtins.readFile ../keys/pgp/yubi_pgp.pgp;
      pubkey = lib.removeSuffix "\n" (builtins.readFile ../keys/ssh/yubi_pgp.pub);
    };
  };
in
{
  options.krebs.users = lib.mkOption {
    type = lib.types.attrsOf self.inputs.stockholm.lib.types.user;
  };

  config = {
    networking.hosts = lib.filterAttrs (_: names: names != [ ]) (
      lib.zipAttrsWith (_: lib.concatLists) (
        lib.concatMap (
          net:
          let
            longs = lib.filter hostDomain (netAliases net);
            names = longs ++ shortsOf longs;
          in
          map (addr: { ${addr} = names; }) (netAddrs net)
        ) allNets
      )
    );

    services.openssh.knownHosts =
      lib.filterAttrs (_: known: known.publicKey != null && known.hostNames != [ ])
        (
          lib.mapAttrs (_: host: {
            publicKey = host.ssh.pubkey or null;
            hostNames = lib.concatMap (
              net:
              map (name: if sshPort net != 22 then "[${name}]:${toString (sshPort net)}" else name) (
                shortsOf (netAliases net) ++ netAliases net ++ netAddrs net
              )
            ) (lib.attrValues (host.nets or { }));
          }) hosts
          // {
            localhost = {
              publicKey = hosts.${config.networking.hostName}.ssh.pubkey or null;
              hostNames = [
                "localhost"
                "127.0.0.1"
                "::1"
              ];
            };
          }
        );

    programs.ssh.extraConfig = lib.mkBefore (
      lib.concatMapStrings (net: ''
        Host ${toString (netAliases net ++ netAddrs net)}
          Port ${toString (sshPort net)}
      '') (lib.filter (net: sshPort net != 22) allNets)
    );

    # drop null fields so they keep the krebs.users type defaults
    krebs.users =
      lib.mapAttrs (_: lib.filterAttrs (_: v: v != null)) (
        removeAttrs kartei.users (lib.attrNames ownUsers)
      )
      // ownUsers;
  };
}
