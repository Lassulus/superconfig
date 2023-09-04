{ config, lib, pkgs, ... }:
let
  ctr.name = "red";
in
{

  krebs.sync-containers3.containers.red = {
    sshKey = "${config.krebs.secret.directory}/containers/red/sync.key";
    ephemeral = true;
  };

  # containers.${ctr.name} = {
  #   config = {
  #     environment.systemPackages = [
  #       pkgs.dhcpcd
  #       pkgs.git
  #       pkgs.jq
  #     ];
  #     networking.useDHCP = lib.mkForce true;
  #     systemd.services.autoswitch = {
  #       environment = {
  #         NIX_REMOTE = "daemon";
  #       };
  #       wantedBy = [ "multi-user.target" ];
  #       serviceConfig.ExecStart = pkgs.writers.writeDash "autoswitch" ''
  #         if test -e /var/src/nixos-config; then
  #           /run/current-system/sw/bin/nixos-rebuild -I /var/src switch || :
  #         fi
  #       '';
  #       unitConfig.X-StopOnRemoval = false;
  #     };
  #   };
  #   autoStart = false;
  #   enableTun = true;
  #   privateNetwork = true;
  #   hostBridge = "ctr0";
  #   bindMounts = {
  #     "/etc/resolv.conf".hostPath = "/etc/resolv.conf";
  #     "/var/lib/self-state/disk-image" = {
  #       hostPath = "/var/lib/sync-containers3/${ctr.name}";
  #       isReadOnly = true;
  #     };
  #   };
  # };

  # systemd.services."${ctr.name}_scheduler" = {
  #   wantedBy = [ "multi-user.target" ];
  #   path = with pkgs; [
  #     coreutils
  #     consul
  #     cryptsetup
  #     mount
  #     util-linux
  #     systemd
  #     untilport
  #   ];
  #   serviceConfig = {
  #     Restart = "always";
  #     RestartSec = "15s";
  #     ExecStart = "${pkgs.consul}/bin/consul lock container_${ctr.name} ${pkgs.writers.writeDash "${ctr.name}-start" ''
  #       set -efux
  #       trap ${pkgs.writers.writeDash "stop-${ctr.name}" ''
  #         set -efux
  #         /run/current-system/sw/bin/nixos-container stop ${ctr.name} || :
  #         umount /var/lib/nixos-containers/${ctr.name}/var/state || :
  #         cryptsetup luksClose ${ctr.name} || :
  #       ''} INT TERM EXIT
  #       consul kv put containers/${ctr.name}/host ${config.networking.hostName}
  #       cryptsetup luksOpen --key-file /var/src/secrets/containers/${ctr.name}/luks /var/lib/sync-containers3/${ctr.name}/disk ${ctr.name}
  #       mkdir -p /var/lib/nixos-containers/${ctr.name}/var/state
  #       mount /dev/mapper/${ctr.name} /var/lib/nixos-containers/${ctr.name}/var/state
  #       ln -frs /var/lib/nixos-containers/${ctr.name}/var/state/var_src /var/lib/nixos-containers/${ctr.name}/var/src
  #       /run/current-system/sw/bin/nixos-container start ${ctr.name}
  #       set +x
  #       until /run/wrappers/bin/ping -q -c 1 ${ctr.name}.r > /dev/null; do sleep 5; done
  #       while /run/wrappers/bin/ping -q -c 1 ${ctr.name}.r > /dev/null; do sleep 5; done
  #     ''}";
  #   };
  # };

  # users.groups."container_${ctr.name}" = {};
  # users.users."container_${ctr.name}" = {
  #   group = "container_${ctr.name}";
  #   isSystemUser = true;
  #   home = "/var/lib/sync-containers3/${ctr.name}";
  #   createHome = true;
  #   homeMode = "705";
  #   openssh.authorizedKeys.keys = [
  #     config.krebs.users.lass.pubkey
  #   ];
  # };

  # systemd.timers."${ctr.name}_syncer" = {
  #   timerConfig = {
  #     RandomizedDelaySec = 300;
  #   };
  # };
  # systemd.services."${ctr.name}_syncer" = {
  #   path = with pkgs; [
  #     coreutils
  #     rsync
  #     openssh
  #     systemd
  #   ];
  #   startAt = "*:0/1";
  #   serviceConfig = {
  #     User = "container_${ctr.name}";
  #     LoadCredential = [
  #       "ssh_key:${toString <secrets>}/containers/${ctr.name}/sync.key"
  #     ];
  #     ExecCondition = pkgs.writers.writeDash "${ctr.name}_checker" ''
  #       set -efu
  #       ! systemctl is-active --quiet container@${ctr.name}.service
  #     '';
  #     ExecStart = pkgs.writers.writeDash "${ctr.name}_syncer" ''
  #       set -efu
  #       rsync -a -e "ssh -i $CREDENTIALS_DIRECTORY/ssh_key" --inplace container_sync@${ctr.name}.r:disk-image/disk $HOME/disk
  #     '';
  #   };
  # };

  # # networking
  # networking.networkmanager.unmanaged = [ "ctr0" ];
  # networking.interfaces.dummy0.virtual = true;
  # networking.bridges.ctr0.interfaces = [ "dummy0" ];
  # networking.interfaces.ctr0.ipv4.addresses = [{
  #   address = "10.233.0.1";
  #   prefixLength = 24;
  # }];
  # systemd.services."dhcpd-ctr0" = {
  #   wantedBy = [ "multi-user.target" ];
  #   after = [ "network.target" ];
  #   serviceConfig = {
  #     Type = "forking";
  #     Restart = "always";
  #     DynamicUser = true;
  #     StateDirectory = "dhcpd-ctr0";
  #     User = "dhcpd-ctr0";
  #     Group = "dhcpd-ctr0";
  #     AmbientCapabilities = [
  #      "CAP_NET_RAW"          # to send ICMP messages
  #      "CAP_NET_BIND_SERVICE" # to bind on DHCP port (67)
  #     ];
  #     ExecStartPre = "${pkgs.coreutils}/bin/touch /var/lib/dhcpd-ctr0/dhcpd.leases";
  #     ExecStart = "${pkgs.dhcp}/bin/dhcpd -4 -lf /var/lib/dhcpd-ctr0/dhcpd.leases -cf ${pkgs.writeText "dhpd.conf" ''
  #         default-lease-time 600;
  #         max-lease-time 7200;
  #         authoritative;
  #         ddns-update-style interim;
  #         log-facility local1; # see dhcpd.nix

  #         option subnet-mask 255.255.255.0;
  #         option routers 10.233.0.1;
  #         # option domain-name-servers 8.8.8.8; # TODO configure dns server
  #         subnet 10.233.0.0 netmask 255.255.255.0 {
  #           range 10.233.0.10 10.233.0.250;
  #         }
  #       ''} ctr0";
  #   };
  # };

}

