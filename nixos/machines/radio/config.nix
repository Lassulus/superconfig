{ config, lib, pkgs, ... }:
{
  imports = [
    <stockholm/lass>
    <stockholm/lass/2configs>
    <stockholm/lass/2configs/retiolum.nix>

    <stockholm/lass/2configs/syncthing.nix>
    <stockholm/lass/2configs/services/radio>
  ];

  krebs.build.host = config.krebs.hosts.radio;

  security.acme = {
    acceptTerms = true;
    defaults.email = "acme@lassul.us";
  };

  krebs.sync-containers3.inContainer = {
    enable = true;
    pubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOvPKdbVwMEFCDMyNAzR8NdVjTbQL2G+03Xomxn6KKFt";
  };
}
