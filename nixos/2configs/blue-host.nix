{ config, lib, pkgs, ... }:
let
  all_hosts = [
    "icarus"
    "shodan"
    "daedalus"
    "skynet"
    "prism"
    "littleT"
  ];
  remote_hosts = filter (h: h != config.networking.hostName) all_hosts;

in {
  imports = [
    <stockholm/lass/2configs/container-networking.nix>
    { #hack for already defined
      systemd.services."container@blue".reloadIfChanged = mkForce false;
      systemd.services."container@blue".preStart = ''
        ${pkgs.mount}/bin/mount | ${pkgs.gnugrep}/bin/grep -q '^encfs on /var/lib/containers/blue'
      '';
      systemd.services."container@blue".preStop = ''
        /run/wrappers/bin/fusermount -u /var/lib/containers/blue
      '';
    }
  ];

  system.activationScripts.containerPermissions = ''
    mkdir -p /var/lib/containers
    chmod 711 /var/lib/containers
  '';

  containers.blue = {
    config = { ... }: {
      environment.systemPackages = [
        pkgs.git
        pkgs.rxvt-unicode-unwrapped.terminfo
      ];
      services.openssh.enable = true;
      users.users.root.openssh.authorizedKeys.keys = [
        config.krebs.users.lass.pubkey
      ];
    };
    autoStart = false;
    enableTun = true;
    privateNetwork = true;
    hostAddress = "10.233.2.9";
    localAddress = "10.233.2.10";
  };


  #systemd.services = builtins.listToAttrs (map (host:
  #  let
  #  in nameValuePair "sync-blue-${host}" {
  #  bindsTo = [ "container@blue.service" ];
  #  wantedBy = [ "container@blue.service" ];
  #  # ssh needed for rsync
  #  path = [ pkgs.openssh ];
  #  serviceConfig = {
  #    Restart = "always";
  #    RestartSec = 10;
  #    ExecStart = pkgs.writeDash "sync-blue-${host}" ''
  #      set -efu
  #      #make sure blue is running
  #      /run/wrappers/bin/ping -c1 blue.r > /dev/null

  #      #make sure the container is unlocked
  #      ${pkgs.mount}/bin/mount | ${pkgs.gnugrep}/bin/grep -q '^encfs on /var/lib/containers/blue'

  #      #make sure our target is reachable
  #      ${pkgs.untilport}/bin/untilport ${host}.r 22 2>/dev/null

  #      #start sync
  #      ${pkgs.lsyncd}/bin/lsyncd -log scarce ${pkgs.writeText "lsyncd-config.lua" ''
  #        settings {
  #          nodaemon = true,
  #          inotifyMode = "CloseWrite or Modify",
  #        }
  #        sync {
  #          default.rsyncssh,
  #          source = "/var/lib/containers/.blue",
  #          host = "${host}.r",
  #          targetdir = "/var/lib/containers/.blue",
  #          rsync = {
  #            archive = true,
  #            owner = true,
  #            group = true,
  #          };
  #          ssh = {
  #            binary = "${pkgs.openssh}/bin/ssh";
  #            identityFile = "/var/lib/containers/blue/home/lass/.ssh/id_rsa",
  #          },
  #        }
  #      ''}
  #    '';
  #  };
  #  unitConfig.ConditionPathExists = "!/var/run/ppp0.pid";
  #  }
  #) remote_hosts);

  environment.systemPackages = [
    (pkgs.writeDashBin "start-blue" ''
      set -ef
      if ! $(mount | ${pkgs.gnugrep}/bin/grep -qi '^encfs on /var/lib/containers/blue'); then
        ${pkgs.encfs}/bin/encfs --public /var/lib/containers/.blue /var/lib/containers/blue
      fi
      nixos-container start blue
      nixos-container run blue -- nixos-rebuild -I /var/src dry-build
      if ping -c1 blue.r >/dev/null; then
        echo 'blue is already running. bailing out'
        exit 23
      fi
      nixos-container run blue -- nixos-rebuild -I /var/src switch
    '')
  ];
}
