{ config, lib, pkgs, ... }:

{

  networking.firewall.allowedTCPPorts = [ 655 ];
  networking.firewall.allowedUDPPorts = [ 655 ];

  krebs.tinc.retiolum = {
    enable = true;
    connectTo = [
      "neoprism"
      "prism"
      "ni"
      "eve"
    ];
    extraConfig = ''
      AutoConnect = yes
      LocalDiscovery = yes
    '';
    privkey = config.clanCore.facts.services.retiolum."retiolum.rsa_key.priv".path;
    privkey_ed25519 = config.clanCore.facts.services.retiolum."retiolum.ed25519_key.priv".path;
  };

  clanCore.facts.services.retiolum = {
    secret."retiolum.rsa_key.priv" = { };
    secret."retiolum.ed25519_key.priv" = { };
    public."retiolum.rsa_key.pub" = { };
    public."retiolum.ed25519_key.pub" = { };
    generator.path = with pkgs; [
      coreutils
      tinc_pre
    ];
    generator.script = ''
      tinc --config "$secrets" generate-keys 4096 >/dev/null
      mv "$secrets"/rsa_key.priv "$secrets"/retiolum.rsa_key.priv
      mv "$secrets"/ed25519_key.priv "$secrets"/retiolum.ed25519_key.priv
      mv "$secrets"/rsa_key.pub "$facts"/retiolum.rsa_key.pub
      mv "$secrets"/ed25519_key.pub "$facts"/retiolum.ed25519_key.pub
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

  nixpkgs.config.packageOverrides = pkgs: {
    tinc = pkgs.tinc_pre;
  };

  environment.systemPackages = [
    pkgs.tinc
  ];
}
