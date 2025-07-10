{ config, pkgs, ... }:
{
  imports = [
    ../../2configs
    ../../2configs/retiolum.nix
    ../../2configs/syncthing.nix
    ../../2configs/services/radio
    ../../2configs/autoupdate.nix
  ];

  clan.password-store.targetDirectory = "/var/state/secrets";
  clan.core.vars.password-store.secretLocation = "/var/state/secret-vars";

  krebs.build.host = config.krebs.hosts.radio;
  system.stateVersion = "24.05";

  security.acme = {
    acceptTerms = true;
    defaults.email = "acme@lassul.us";
  };

  krebs.sync-containers3.inContainer = {
    enable = true;
    pubkey = builtins.readFile ./facts/radio.sync.pub;
  };

  clanCore.facts.services.radio-container = {
    secret."radio.sync.key" = { };
    public."radio.sync.pub" = { };
    generator.path = with pkgs; [
      coreutils
      openssh
    ];
    generator.script = ''
      ssh-keygen -t ed25519 -N "" -f "$secrets"/radio.sync.key
      mv "$secrets"/radio.sync.key "$facts"/radio.sync.pub
    '';
  };
}
