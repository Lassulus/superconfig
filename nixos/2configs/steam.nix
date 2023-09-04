{ config, pkgs, ... }:

{
  #
  # Steam stuff
  # source: https://nixos.org/wiki/Talk:Steam
  #
  ##TODO: make steam module
  nixpkgs.config.steam.java = true;
  hardware.opengl.extraPackages32 = with pkgs.pkgsi686Linux; [ libva ];

  users.users.mainUser.packages = [ (pkgs.steam.override {
    extraPkgs = p: with p; [
      gnutls # needed for Halo MCC
    ];
  }) ];

  #ports for inhome streaming
  krebs.iptables = {
    tables = {
      filter.INPUT.rules = [
        { predicate = "-p tcp --dport 27031"; target = "ACCEPT"; }
        { predicate = "-p tcp --dport 27036"; target = "ACCEPT"; }
        { predicate = "-p udp --dport 27031"; target = "ACCEPT"; }
        { predicate = "-p udp --dport 27036"; target = "ACCEPT"; }
      ];
    };
  };
}
