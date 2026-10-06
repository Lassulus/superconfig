{
  config,
  lib,
  pkgs,
  ...
}:
let
  domains = [
    "hackerfleet.eu"
    "hackerfleet.de"
  ];
in
{
  containers.riot = {
    config = {
      environment.systemPackages = [
        pkgs.git
        pkgs.jq
      ];
      services.openssh.enable = true;
      users.users.root.openssh.authorizedKeys.keys = [
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC6o6sdTu/CX1LW2Ff5bNDqGEAGwAsjf0iIe5DCdC7YikCct+7x4LTXxY+nDlPMeGcOF88X9/qFwdyh+9E4g0nUAZaeL14Uc14QDqDt/aiKjIXXTepxE/i4JD9YbTqStAnA/HYAExU15yqgUdj2dnHu7OZcGxk0ZR1OY18yclXq7Rq0Fd3pN3lPP1T4QHM9w66r83yJdFV9szvu5ral3/QuxQnCNohTkR6LoJ4Ny2RbMPTRtb+jPbTQYTWUWwV69mB8ot5nRTP4MRM9pu7vnoPF4I2S5DvSnx4C5zdKzsb7zmIvD4AmptZLrXj4UXUf00Xf7Js5W100Ne2yhYyhq+35 riot@lagrange"
      ];
      networking.defaultGateway = "10.233.1.1";
      systemd.services.autoswitch = {
        environment = {
          NIX_REMOTE = "daemon";
        };
        wantedBy = [ "multi-user.target" ];
        serviceConfig.ExecStart = pkgs.writers.writeDash "autoswitch" ''
          set -efu
          if test -e /etc/nixos/configuration.nix; then
            /run/current-system/sw/bin/nixos-rebuild switch \
              -I nixpkgs=channel:$(cat /etc/nixos/channel) \
              -I nixos-config=/etc/nixos/configuration.nix \
              || :
          fi
        '';
        unitConfig.X-StopOnRemoval = false;
      };
      system.stateVersion = config.system.nixos.release;
    };
    autoStart = true;
    enableTun = true;
    privateNetwork = true;
    hostAddress = "10.233.1.1";
    localAddress = "10.233.1.2";
  };
  systemd.services."container@riot".restartIfChanged = lib.mkForce false;

  systemd.network.networks."50-ve-riot" = {
    matchConfig.Name = "ve-riot";

    networkConfig = {
      # weirdly we have to use POSTROUTING MASQUERADE here
      # and set ip_forward manually
      # IPForward = "yes";
      # IPMasquerade = "both";
      LinkLocalAddressing = "no";
      KeepConfiguration = "static";
    };
    # The container start script adds this route, but networkd drops it as
    # foreign the next time it reconfigures ve-riot (e.g. when networkd
    # restarts), and container@riot is never restarted to re-add it.
    routes = [ { Destination = "${config.containers.riot.localAddress}/32"; } ];
  };

  boot.kernel.sysctl."net.ipv4.ip_forward" = lib.mkDefault 1;

  networking.firewall.extraForwardRules = ''
    iifname "ve-riot" accept
    oifname "ve-riot" accept
  '';
  # ssh into the container on 45622
  networking.nftables.tables.riot = {
    family = "ip";
    content = ''
      chain prerouting {
        type nat hook prerouting priority dstnat; policy accept;
        tcp dport 45622 dnat to ${config.containers.riot.localAddress}:22
      }
      chain postrouting {
        type nat hook postrouting priority srcnat; policy accept;
        ip saddr ${config.containers.riot.localAddress} masquerade
      }
    '';
  };

  # non container stuff

  services.nginx.virtualHosts.riot = {
    serverName = null;
    serverAliases = domains;
  };

}
