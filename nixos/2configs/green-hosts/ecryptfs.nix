{ config, lib, pkgs, ... }:
let

  cname = "green";

in {
  imports = [
    <stockholm/lass/2configs/container-networking.nix>
    <stockholm/lass/2configs/syncthing.nix>
  ];

  programs.fuse.userAllowOther = true;

  services.syncthing.declarative.folders."/var/lib/sync-containers/${cname}/ecryptfs" = {
    devices = [ "icarus" "skynet" "littleT" "shodan" "mors" "morpheus" ];
    ignorePerms = false;
  };

  krebs.permown."/var/lib/sync-containers/${cname}/ecryptfs" = {
    file-mode = "u+rw";
    directory-mode = "u+rwx";
    owner = "syncthing";
    keepGoing = false;
  };

  systemd.services."container@${cname}".reloadIfChanged = mkForce false;
  containers.${cname} = {
    config = { ... }: {
      environment.systemPackages = [
        pkgs.git
        pkgs.rxvt-unicode-unwrapped.terminfo
      ];
      services.openssh.enable = true;
      users.users.root.openssh.authorizedKeys.keys = [
        config.krebs.users.lass.pubkey
      ];
      system.activationScripts.fuse = {
        text = ''
          ${pkgs.coreutils}/bin/mknod /dev/fuse c 10 229
        '';
        deps = [];
      };
    };
    allowedDevices = [
      { modifier = "rwm"; node = "/dev/fuse"; }
    ];
    autoStart = false;
    enableTun = true;
    privateNetwork = true;
    hostAddress = "10.233.2.15"; # TODO find way to automatically calculate IPs
    localAddress = "10.233.2.16"; # TODO find way to automatically calculate IPs
  };

  environment.systemPackages = [
    pkgs.ecryptfs
    pkgs.keyutils
    (pkgs.writeDashBin "start-${cname}" ''
      set -euf
      set -x

      mkdir -p /var/lib/containers/${cname}/var/state

      if ! mount | grep -q '/var/lib/sync-containers/${cname}/ecryptfs on /var/lib/containers/${cname}/var/state type ecryptfs'; then
        if [ -e /var/lib/sync-containers/${cname}/ecryptfs/.cfg.json ]; then
          ${pkgs.ecrypt}/bin/ecrypt mount /var/lib/sync-containers/${cname}/ecryptfs /var/lib/containers/${cname}/var/state
        else
          ${pkgs.ecrypt}/bin/ecrypt init /var/lib/sync-containers/${cname}/ecryptfs /var/lib/containers/${cname}/var/state
        fi
      fi

      STATE=$(${pkgs.nixos-container}/bin/nixos-container status ${cname})
      if [ "$STATE" = 'down' ]; then
        ${pkgs.nixos-container}/bin/nixos-container start ${cname}
      fi

      ${pkgs.nixos-container}/bin/nixos-container run ${cname} -- ${pkgs.writeDash "deploy-${cname}" ''
        set -x

        mkdir -p /var/state/var_src
        ln -sfTr /var/state/var_src /var/src
        touch /etc/NIXOS
      ''}

      if [ -h /var/lib/containers/${cname}/var/src/nixos-config ] && (! ping -c1 -q -w5 ${cname}.r); then
        ${pkgs.nixos-container}/bin/nixos-container run ${cname} -- nixos-rebuild -I /var/src switch
      fi
    '')
    (pkgs.writeDashBin "stop-${cname}" ''
      set -euf

      ${pkgs.nixos-container}/bin/nixos-container stop ${cname}
      ${pkgs.ecrypt}/bin/ecrypt unmount /var/lib/sync-containers/${cname}/ecryptfs /var/lib/containers/${cname}/var/state
    '')
  ];
}

