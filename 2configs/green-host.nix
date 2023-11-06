{ config, pkgs, ... }:
{
  krebs.sync-containers3.containers.green = {
    sshKey = "${config.krebs.secret.directory}/green.sync.key";
    startCommand = ''
      export PATH=$PATH:${pkgs.git}/bin
      until ${pkgs.dig.host}/bin/host github.com; do sleep 1; done
      ${pkgs.nixos-rebuild}/bin/nixos-rebuild --refresh --flake github:lassulus/superconfig#green switch
    '';
  };
}
