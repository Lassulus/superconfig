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

  # Peer keys and addresses come straight from kartei, not through
  # stockholm's krebs.hosts: stockholm pins an older kartei and its host type
  # still requires the legacy RSA pubkey. This is only the host database --
  # the daemon stays on nixpkgs' services.tinc (kartei's own retiolum module
  # is nix-darwin only here, see machines/barnacle/retiolum.nix).
  #
  # tincHosts is already filtered to SPTPS-capable nodes, so the RSA-only
  # leftovers tincr refuses per connection attempt are gone.
  kartei = import (self.inputs.kartei + "/modules/retiolum/hosts.nix") { inherit lib; };

  name = config.networking.hostName;

  # Nodes with no kartei card, known only inside superconfig. Exposes the same
  # interface as kartei's hosts.nix, so both sources merge the same way.
  local = self.retiolum;

  own = kartei.own.${name} or local.own.${name};
in

{

  networking.firewall.allowedTCPPorts = [ 655 ];
  networking.firewall.allowedUDPPorts = [ 655 ];

  services.tinc.networks.retiolum = {
    package = tincrPkg;
    # 1+ maps to per-packet Debug/Trace in tincr, which floods journald
    # (tens of thousands of suppressed messages per minute) and rotates
    # all other units' logs out of the journal within hours
    debugLevel = 0;
    hosts = kartei.tincHosts // local.tincHosts;
    extraConfig = ''
      AutoConnect = yes
      LocalDiscovery = yes
    '';
    settings = {
      Interface = "retiolum";
      Name = name;
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
    address = lib.optional (own.ip4 != null) "${own.ip4}/16" ++ [ "${own.ip6}/16" ];
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

  # Upstream nixos/tinc preStart chowns hosts/ and invitations/ but not
  # the network dir itself, so tincr (and tinc 1.1pre18) can't persist
  # its address-cache there. Drop this once nixpkgs#520533 lands.
  systemd.tmpfiles.rules = [
    "z /etc/tinc/retiolum 0755 tinc-retiolum - -"
  ];
}
