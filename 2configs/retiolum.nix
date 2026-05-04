{
  self,
  config,
  pkgs,
  lib,
  ...
}:

let
  tincr = self.packages.${pkgs.system}.tincr;
  tincrPkg = pkgs.runCommand "tincr-sbin-${tincr.version}" { version = tincr.version; } ''
    mkdir -p $out
    cp -r ${tincr}/* $out/
    chmod -R u+w $out
    ln -s bin $out/sbin
  '';
in

{

  networking.firewall.allowedTCPPorts = [ 655 ];
  networking.firewall.allowedUDPPorts = [ 655 ];

  services.tinc.networks.retiolum = {
    package = tincrPkg;
    debugLevel = 3;
    hosts = lib.mapAttrs' (name: host: lib.nameValuePair name host.nets.retiolum.tinc.config) (
      lib.filterAttrs (_: host: host.nets.retiolum.tinc.config or null != null) config.krebs.hosts
    );
    extraConfig = ''
      AutoConnect = yes
      LocalDiscovery = yes
    '';
    settings = {
      Interface = "retiolum";
      Name = config.krebs.build.host.name;
      ConnectTo = [
        "neoprism"
        "prism"
        "ni"
        "eve"
      ];
    };
  };

  # Copy keys into the tinc config directory before tinc starts.
  # Running before nixpkgs' preStart ensures key generation is skipped.
  systemd.services."tinc.retiolum".preStart = lib.mkBefore ''
    rm -f /etc/tinc/retiolum/rsa_key.priv /etc/tinc/retiolum/ed25519_key.priv /etc/tinc/retiolum/tinc-up
    cp ${
      config.clan.core.vars.generators.retiolum.files."retiolum.rsa_key.priv".path
    } /etc/tinc/retiolum/rsa_key.priv
    cp ${
      config.clan.core.vars.generators.retiolum.files."retiolum.ed25519_key.priv".path
    } /etc/tinc/retiolum/ed25519_key.priv
    chown tinc-retiolum /etc/tinc/retiolum/rsa_key.priv /etc/tinc/retiolum/ed25519_key.priv
    chmod 600 /etc/tinc/retiolum/rsa_key.priv /etc/tinc/retiolum/ed25519_key.priv
  '';

  clan.core.vars.generators.retiolum = {
    files."retiolum.rsa_key.priv" = { };
    files."retiolum.ed25519_key.priv" = { };
    files."retiolum.rsa_key.pub".secret = false;
    files."retiolum.ed25519_key.pub".secret = false;
    migrateFact = "retiolum";
    runtimeInputs = with pkgs; [
      coreutils
      tinc_pre
    ];
    script = ''
      tinc --config "$out" generate-keys 4096 >/dev/null
      mv "$out"/rsa_key.priv "$out"/retiolum.rsa_key.priv
      mv "$out"/ed25519_key.priv "$out"/retiolum.ed25519_key.priv
      mv "$out"/rsa_key.pub "$out"/retiolum.rsa_key.pub
      mv "$out"/ed25519_key.pub "$out"/retiolum.ed25519_key.pub
    '';
  };

  systemd.network.networks.retiolum = {
    matchConfig.Name = "retiolum";
    address = [
      "${config.krebs.build.host.nets.retiolum.ip4.addr}/16"
      "${config.krebs.build.host.nets.retiolum.ip6.addr}/16"
    ];
    linkConfig = {
      MTUBytes = "1377";
      RequiredForOnline = "no";
    };
    networkConfig = {
      LinkLocalAddressing = "no";
    };
  };

  environment.systemPackages = [
    tincrPkg
  ];
}
