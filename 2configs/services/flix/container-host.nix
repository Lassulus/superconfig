{ config, pkgs, ... }:
{
  krebs.sync-containers3.containers.yellow = {
    sshKey = "${config.krebs.secret.directory}/yellow.sync.key";
    startCommand = ''
      export PATH=$PATH:${pkgs.git}/bin
      until ${pkgs.dig.host}/bin/host github.com; do sleep 1; done
      ${pkgs.nixos-rebuild}/bin/nixos-rebuild --refresh --flake github:lassulus/superconfig#yellow switch --no-write-lock-file
    '';
  };
  containers.yellow.bindMounts."/var/lib" = {
    hostPath = "/var/lib/sync-containers3/yellow/state";
    isReadOnly = false;
  };
  containers.yellow.bindMounts."/var/download" = {
    hostPath = "/var/download";
    isReadOnly = false;
  };
  networking.firewall.allowedTCPPorts = [
    8096
    8920
  ];
  networking.firewall.allowedUDPPorts = [
    1900
    7359
  ];
  containers.yellow.forwardPorts = [
    {
      hostPort = 8096;
      containerPort = 8096;
      protocol = "tcp";
    }
    {
      hostPort = 8920;
      containerPort = 8920;
      protocol = "tcp";
    }
    {
      hostPort = 1900;
      containerPort = 1900;
      protocol = "udp";
    }
    {
      hostPort = 7359;
      containerPort = 7359;
      protocol = "udp";
    }
  ];

  services.nginx.virtualHosts."flix.lassul.us" = {
    # forceSSL = true;
    # enableACME = true;
    locations."/" = {
      proxyPass = "http://yellow.r:8096";
      proxyWebsockets = true;
      recommendedProxySettings = true;
    };
  };
  clan.core.vars.generators.yellow-container = {
    files."yellow.sync.key" = { };
    prompts.key.description = ''
      copy or reference the secret key from the container into here, so we can actually start/sync the container
    '';
    script = ''
      cat "$prompts"/key > "$out"/yellow.sync.key
    '';
  };
}
