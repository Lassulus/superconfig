{ config, lib, pkgs, ... }: let
  domains = [
    "hackerfleet.eu"
    "hackerfleet.de"
  ];
in {
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
  };

  boot.kernel.sysctl."net.ipv4.ip_forward" = lib.mkDefault 1;

  krebs.iptables.tables.nat.POSTROUTING.rules = [
    { v6 = false; predicate = "-s ${config.containers.riot.localAddress}"; target = "MASQUERADE"; }
  ];

  # networking.nat can be used instead of this
  krebs.iptables.tables.nat.PREROUTING.rules = [
    { predicate = "-p tcp --dport 45622"; target = "DNAT --to-destination ${config.containers.riot.localAddress}:22"; v6 = false; }
  ];
  krebs.iptables.tables.filter.FORWARD.rules = [
    { predicate = "-i ve-riot"; target = "ACCEPT"; }
    { predicate = "-o ve-riot"; target = "ACCEPT"; }
  ];


  # non container stuff

  services.nginx.virtualHosts.riot = {
    serverName = null;
    serverAliases = domains;
  };

  krebs.exim-smarthost.extraRouters = ''
    forward_riot:
      driver = manualroute
      domains = ${lib.concatStringsSep ":" domains}
      transport = remote_smtp
      route_list = * riot
      no_more
  '';
}
