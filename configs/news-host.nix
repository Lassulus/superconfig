{ config, pkgs, ... }:
{
  krebs.sync-containers3.containers.news = {
    sshKey = "${config.krebs.secret.directory}/news.sync.key";
    startCommand = ''
      export PATH=$PATH:${pkgs.git}/bin
      until ${pkgs.dig.host}/bin/host github.com; do sleep 1; done
      ${pkgs.nixos-rebuild}/bin/nixos-rebuild --refresh --flake git+https://cgit.lassul.us/stockholm#news switch
    '';
  };
}
