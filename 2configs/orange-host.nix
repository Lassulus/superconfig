{ config, pkgs, ... }:
{
  krebs.sync-containers3.containers.orange = {
    sshKey = "${config.krebs.secret.directory}/orange.sync.key";
    startCommand = ''
      export PATH=$PATH:${pkgs.git}/bin
      until ${pkgs.dig.host}/bin/host github.com; do sleep 1; done
      ${pkgs.nixos-rebuild}/bin/nixos-rebuild --refresh --flake github:lassulus/superconfig#orange switch
    '';
  };
  containers.orange.bindMounts."/var/lib" = {
    hostPath = "/var/lib/sync-containers3/orange/state";
    isReadOnly = false;
  };
  services.nginx.virtualHosts."lassul.us" = {
    # enableACME = config.security;
    # forceSSL = true;
    locations."/" = {
      recommendedProxySettings = true;
      proxyWebsockets = true;
      proxyPass = "http://orange.r";
    };
  };
}
