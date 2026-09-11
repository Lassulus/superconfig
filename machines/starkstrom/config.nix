{
  self,
  config,
  ...
}:
let
  # starkstrom is deliberately not in the shared kartei registry; its retiolum
  # identity lives in retiolum/ (self.retiolum), which every superconfig
  # machine injects into its tinc host set. Move that entry into kartei/lass if
  # the rest of krebs should be able to reach it too.
  net = self.retiolum.hosts.starkstrom.nets.retiolum;
in
{
  imports = [
    ../../2configs
    ../../2configs/retiolum.nix
    ../../2configs/ssh-redirect.nix
    ../../2configs/autoupdate.nix
    ../../2configs/sigexec/executor.nix
    ./ipfs.nix
    ./ipfs-endpoint.nix
  ];

  # krebs.build.host and the monitoring/dns bits still read this card, so build
  # it from the same data rather than repeating the addresses and keys.
  # stockholm's host type additionally insists on the legacy RSA pubkey, which
  # tincr ignores; via is left out because stockholm resolves it to a net
  # submodule, not a name.
  krebs.hosts.starkstrom = {
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

  krebs.build.host = config.krebs.hosts.starkstrom;

  # The fleet has no retiolum route here (see kartei note above), so the
  # sigexec dashboard on neoprism reaches this executor over public TLS
  # instead: nginx strips /sigexec/ so the executor verifies the same paths
  # the statements were signed over (/jobs etc).
  services.nginx.virtualHosts."starkstrom.lassul.us".locations."/sigexec/" = {
    proxyPass = "http://127.0.0.1:7601/";
    extraConfig = ''
      # Long-lived chunked job streams: unbuffered, generous timeouts (logs on
      # a pending job blocks until approval).
      proxy_buffering off;
      proxy_read_timeout 1d;
      proxy_send_timeout 1d;
    '';
  };

  system.stateVersion = "25.11";
}
