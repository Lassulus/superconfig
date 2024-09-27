{ config, pkgs, ... }:
{
  imports = [
    ../../2configs
    ../../2configs/retiolum.nix
    ../../2configs/mumble-reminder.nix
    ../../2configs/services/git
    ../../2configs/nginx.nix
  ];

  krebs.build.host = config.krebs.hosts.orange;
  system.stateVersion = "24.05";
  clan.password-store.targetDirectory = "/var/state/secrets";

  services.nginx.enable = true;
  networking.firewall.allowedTCPPorts = [
    80
    443
  ];
  security.acme = {
    acceptTerms = true;
    defaults.email = "acme@lassul.us";
  };

  krebs.sync-containers3.inContainer = {
    enable = true;
    pubkey = builtins.readFile ./facts/orange.sync.pub;
  };
  clanCore.facts.services.orange-container = {
    secret."orange.sync.key" = { };
    public."orange.sync.pub" = { };
    generator.path = with pkgs; [
      coreutils
      openssh
    ];
    generator.script = ''
      ssh-keygen -t ed25519 -N "" -f "$secrets"/orange.sync.key
      mv "$secrets"/orange.sync.key "$facts"/orange.sync.pub
    '';
  };
}
