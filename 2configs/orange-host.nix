{ config, pkgs, ... }:
{
  krebs.sync-containers3.containers.orange = {
    sshKey = "${config.krebs.secret.directory}/orange.sync.key";
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
