{ config, pkgs, ... }:
let

  cname = "green-plain";

in
{
  imports = [
    <stockholm/lass/2configs/container-networking.nix>
    <stockholm/lass/2configs/syncthing.nix>
  ];

  programs.fuse.userAllowOther = true;

  services.syncthing.declarative.folders."/var/lib/containers/${cname}/var/state" = {
    devices = [
      "icarus"
      "skynet"
      "littleT"
      "shodan"
      "mors"
      "morpheus"
    ];
    ignorePerms = false;
  };

  krebs.permown."/var/lib/containers/${cname}/var/state" = {
    file-mode = "u+rw";
    directory-mode = "u+rwx";
    owner = "syncthing";
    keepGoing = true;
  };

  systemd.services."container@${cname}".reloadIfChanged = mkForce false;
  containers.${cname} = {
    config =
      { ... }:
      {
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
          deps = [ ];
        };
      };
    allowedDevices = [
      {
        modifier = "rwm";
        node = "/dev/fuse";
      }
    ];
    autoStart = false;
    enableTun = true;
    privateNetwork = true;
    hostAddress = "10.233.2.15"; # TODO find way to automatically calculate IPs
    localAddress = "10.233.2.16"; # TODO find way to automatically calculate IPs
  };

  environment.systemPackages = [
    (pkgs.writeDashBin "start-${cname}" ''
      set -euf
      set -x

      mkdir -p /var/lib/containers/${cname}/var/state

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
    '')
  ];
}
