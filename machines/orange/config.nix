{ config, pkgs, ... }:
{
  clan.core.vars.password-store.secretLocation = "/var/state/secret-vars";

  imports = [
    ../../2configs
    ../../2configs/retiolum.nix
    ../../2configs/mumble-reminder.nix
    ../../2configs/services/git
    ../../2configs/nginx.nix
  ];

  krebs.build.host = config.krebs.hosts.orange;
  system.stateVersion = "24.05";

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
  clan.core.vars.generators.orange-container = {
    files."orange.sync.key" = { };
    files."orange.sync.pub".secret = false;
    runtimeInputs = with pkgs; [
      coreutils
      openssh
    ];
    script = ''
      ssh-keygen -t ed25519 -N "" -f "$out"/orange.sync.key
      mv "$out"/orange.sync.key.pub "$out"/orange.sync.pub
    '';
  };
}
