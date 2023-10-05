{ config, lib, pkgs, ... }:
{
  imports = [
    ../../2configs
    ../../2configs/retiolum.nix
    ../../2configs/mumble-reminder.nix
    ../../2configs/services/git
  ];

  krebs.build.host = config.krebs.hosts.orange;

  services.nginx.enable = true;
  networking.firewall.allowedTCPPorts = [ 80 443 ];
  security.acme = {
    acceptTerms = true;
    defaults.email = "acme@lassul.us";
  };

  krebs.sync-containers3.inContainer = {
    enable = true;
    pubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFQWzKuXrwQopBc1mzb2VpljmwAs7Y8bRl9a8hBXLC+l";
  };
}
