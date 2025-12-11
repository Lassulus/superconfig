{ config, pkgs, ... }:
{
  imports = [
    ../../2configs
    ../../2configs/retiolum.nix
    ../../2configs/syncthing.nix
    ../../2configs/services/radio
    ../../2configs/autoupdate.nix
  ];

  clan.core.vars.password-store.secretLocation = "/var/state/secret-vars";

  krebs.build.host = config.krebs.hosts.radio;
  system.stateVersion = "24.05";

  security.acme = {
    acceptTerms = true;
    defaults.email = "acme@lassul.us";
  };

  krebs.sync-containers3.inContainer = {
    enable = true;
    pubkey = config.clan.core.vars.generators.radio-sync.files."radio.sync.pub".value;
  };

  clan.core.vars.generators.radio-sync = {
    files."radio.sync.key" = { };
    files."radio.sync.pub".secret = false;
    runtimeInputs = with pkgs; [
      coreutils
      openssh
    ];
    script = ''
      ssh-keygen -t ed25519 -N "" -f "$out"/radio.sync.key
      mv "$out"/radio.sync.key.pub "$out"/radio.sync.pub
    '';
  };
}
