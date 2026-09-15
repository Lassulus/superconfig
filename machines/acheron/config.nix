{
  self,
  config,
  ...
}:
let
  # acheron replaces styx as the gg23 router. Like starkstrom it has no card in
  # the shared kartei registry; its retiolum identity lives in retiolum/
  # (self.retiolum), which every superconfig machine injects into its tinc
  # host set. Move that entry into kartei/lass if the rest of krebs should be
  # able to reach it too.
  net = self.retiolum.hosts.acheron.nets.retiolum;
in
{
  imports = [
    ../../2configs
    ../../2configs/retiolum.nix
    ../../2configs/gg23.nix
  ];

  # krebs.build.host and the monitoring/dns bits still read this card, so build
  # it from the same data rather than repeating the addresses and keys.
  # stockholm's host type additionally insists on the legacy RSA pubkey, which
  # tincr ignores.
  krebs.hosts.acheron = {
    owner = config.krebs.users.lass;
    monitoring = true;
    nets.retiolum = {
      inherit (net) ip4 ip6 aliases;
      tinc = {
        pubkey = config.clan.core.vars.generators.retiolum.files."retiolum.rsa_key.pub".value;
        inherit (net.tinc) pubkey_ed25519;
      };
    };
  };

  krebs.build.host = config.krebs.hosts.acheron;

  services.earlyoom.enable = true;

  system.stateVersion = "25.11";
}
