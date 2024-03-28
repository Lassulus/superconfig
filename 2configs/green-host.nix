{ config, pkgs, ... }:
{
  krebs.sync-containers3.containers.green = {
    sshKey = config.clanCore.facts.services.green-container.secret."green.sync.key".path;
    startCommand = ''
      export PATH=$PATH:${pkgs.git}/bin
      until ${pkgs.dig.host}/bin/host github.com; do sleep 1; done
      ${pkgs.nixos-rebuild}/bin/nixos-rebuild --refresh --flake github:lassulus/superconfig#green switch --no-write-lock-file
    '';
  };
  clanCore.facts.services.green-container = {
    secret."green.sync.key" = { };
    generator.script = ":";
    generator.prompt = ''
      copy or reference the secret key from the container into here, so we can actually start/sync the container
    '';
  };
}
