{ config, lib, pkgs, ... }:

{
  imports = [
    <stockholm/lass>
    <stockholm/lass/2configs/retiolum.nix>
    <stockholm/lass/2configs/mail/internet-gateway.nix>
    <stockholm/lass/2configs/binary-cache/server.nix>
    <stockholm/lass/2configs/matrix.nix>
    <stockholm/lass/2configs/gsm-wiki.nix>

    # sync-containers
    <stockholm/lass/2configs/consul.nix>
    <stockholm/lass/2configs/services/flix/container-host.nix>
    <stockholm/lass/2configs/services/radio/container-host.nix>
    <stockholm/lass/2configs/ubik-host.nix>
    <stockholm/lass/2configs/orange-host.nix>
    <stockholm/krebs/2configs/hotdog-host.nix>

    # other containers
    <stockholm/lass/2configs/riot.nix>

    # proxying of services
    <stockholm/lass/2configs/services/radio/proxy.nix>
    <stockholm/lass/2configs/services/flix/proxy.nix>
    <stockholm/lass/2configs/services/coms/proxy.nix>
  ];

  krebs.build.host = config.krebs.hosts.neoprism;

  networking.firewall.allowedTCPPorts = [ 80 443 ];
  security.acme.acceptTerms = true;
  security.acme.defaults.email = "acme@lassul.us";
  services.nginx = {
    enable = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedTlsSettings = true;

    enableReload = true;

    virtualHosts.default = {
      default = true;
      locations."= /etc/os-release".extraConfig = ''
        default_type text/plain;
        alias /etc/os-release;
      '';
      locations."~ ^/.well-known/acme-challenge/".root = "/var/lib/acme/acme-challenge";
    };
  };
}
