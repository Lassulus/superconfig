{ config, lib, pkgs, ... }:

{

  krebs.iptables = {
    tables = {
      filter.INPUT.rules = let
        tincport = toString config.krebs.build.host.nets.retiolum.tinc.port;
      in [
        { predicate = "-p tcp --dport ${tincport}"; target = "ACCEPT"; }
        { predicate = "-p udp --dport ${tincport}"; target = "ACCEPT"; }
      ];
    };
  };

  krebs.tinc.retiolum = {
    enable = true;
    connectTo = [
      "prism"
      "ni"
      "eve"
    ];
    extraConfig = ''
      AutoConnect = no
      ${lib.optionalString (config.krebs.build.host.nets.retiolum.via != null) ''
        LocalDiscovery = no
      ''}
    '';
    tincUp = lib.mkIf config.systemd.network.enable "";
    privkey = "${config.krebs.secret.directory}/retiolum.rsa_key.priv";
    privkey_ed25519 = "${config.krebs.secret.directory}/retiolum.ed25519_key.priv";
  };

  clanCore.secrets.retiolum = {
    secrets."retiolum.rsa_key.priv" = { };
    secrets."retiolum.ed25519_key.priv" = { };
    facts."retiolum.rsa_key.pub" = { };
    facts."retiolum.ed25519_key.pub" = { };
    generator = ''
      ${pkgs.tinc_pre}/bin/tinc --config "$secrets" generate-keys 4096 >/dev/null
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
      IgnoreCarrierLoss = "10s";
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
