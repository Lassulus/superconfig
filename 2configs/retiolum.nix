{
  self,
  config,
  pkgs,
  ...
}:

let
  tincr = self.packages.${pkgs.system}.tincr;
  # krebs.tinc invokes ${tincPackage}/sbin/{tinc,tincd}; tincr ships in /bin.
  tincrPkg = pkgs.runCommand "tincr-sbin-${tincr.version}" { } ''
    mkdir -p $out
    cp -r ${tincr}/* $out/
    chmod -R u+w $out
    ln -s bin $out/sbin
  '';
in

{

  networking.firewall.allowedTCPPorts = [ 655 ];
  networking.firewall.allowedUDPPorts = [ 655 ];

  krebs.tinc.retiolum = {
    enable = true;
    tincPackage = tincrPkg;
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
    privkey = config.clan.core.vars.generators.retiolum.files."retiolum.rsa_key.priv".path;
    privkey_ed25519 = config.clan.core.vars.generators.retiolum.files."retiolum.ed25519_key.priv".path;
  };

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
