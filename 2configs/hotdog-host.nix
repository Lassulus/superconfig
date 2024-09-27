{ config, pkgs, ... }:
{
  krebs.sync-containers3.containers.hotdog = {
    sshKey = "${config.krebs.secret.directory}/hotdog.sync.key";
    startCommand = ''
      export PATH=$PATH:${pkgs.git}/bin
      ln -sfrT /var/lib/var_src /var/src
      until ${pkgs.dig.host}/bin/host github.com; do sleep 1; done
      ${pkgs.nixos-rebuild}/bin/nixos-rebuild --refresh --flake 'git+https://cgit.lassul.us/stockholm#hotdog' switch --no-write-lock-file
    '';
  };
  containers.hotdog.bindMounts."/var/lib" = {
    hostPath = "/var/lib/sync-containers3/hotdog/state";
    isReadOnly = false;
  };
  clanCore.facts.services.hotdog-container = {
    secret."hotdog.sync.key" = { };
    public."hotdog.sync.pub" = { };
    generator.path = with pkgs; [
      coreutils
      openssh
    ];
    generator.script = ''
      ssh-keygen -t ed25519 -N "" -f "$secrets"/hotdog.sync.key
      mv "$secrets"/hotdog.sync.key.pub "$facts"/hotdog.sync.pub
    '';
  };
}
