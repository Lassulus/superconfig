{ config, lib, ... }:
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

  # starkstrom is not (yet) in the shared kartei registry, so its retiolum
  # identity is declared here. Migrate this block into kartei/lass to give the
  # rest of the fleet starkstrom's keys (full mesh); until then only starkstrom
  # knows the peers it ConnectTo's.
  # Pubkeys are read from this machine's clan vars, so they always match the
  # private keys deployed to the host.
  krebs.hosts.starkstrom = {
    owner = config.krebs.users.lass;
    monitoring = true;
    nets.retiolum = {
      ip4.addr = "10.243.0.100";
      ip6.addr = "42:0:ce16::100";
      aliases = [ "starkstrom.r" ];
      tinc.pubkey = config.clan.core.vars.generators.retiolum.files."retiolum.rsa_key.pub".value;
      # tincr writes the pub as `Ed25519PublicKey = <key>`; keep only the key.
      tinc.pubkey_ed25519 = lib.last (
        lib.splitString " " (
          lib.removeSuffix "\n"
            config.clan.core.vars.generators.retiolum.files."retiolum.ed25519_key.pub".value
        )
      );
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
