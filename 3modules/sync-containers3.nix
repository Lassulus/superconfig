{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.krebs.sync-containers3;
in
{
  options.krebs.sync-containers3 = {
    inContainer = {
      enable = lib.mkEnableOption "container config for syncing";
      pubkey = lib.mkOption {
        type = lib.types.str;
      };
    };
    containers = lib.mkOption {
      default = { };
      type = lib.types.attrsOf (
        lib.types.submodule (
          { config, ... }:
          {
            options = {
              name = lib.mkOption {
                type = lib.types.str;
                default = config._module.args.name;
              };
              sshKey = lib.mkOption {
                type = lib.types.str;
              };
              luksKey = lib.mkOption {
                type = lib.types.str;
                default = config.sshKey;
              };
              ephemeral = lib.mkOption {
                type = lib.types.bool;
                default = false;
              };
              runContainer = lib.mkOption {
                type = lib.types.bool;
                default = true;
              };
              startCommand = lib.mkOption {
                type = lib.types.str;
                default = ''
                  set -efu
                  mkdir -p /var/state/var_src
                  ln -Tfrs /var/state/var_src /var/src
                  if test -e /var/src/nixos-config; then
                    /run/current-system/sw/bin/nixos-rebuild -I /var/src switch || :
                  fi
                '';
              };
              hostname = lib.mkOption {
                type = lib.types.str;
                description = ''
                  hostname of the container,
                  this is continuously checked by ping and the container is restarted if unreachable
                '';
                default = config.name;
              };
            };
          }
        )
      );
    };
  };
  config = lib.mkMerge [
    (lib.mkIf (cfg.containers != { }) {

      containers = lib.mapAttrs' (
        _n: ctr:
        lib.nameValuePair ctr.name {
          config = {
            environment.systemPackages = [
              pkgs.dhcpcd
              pkgs.git
              pkgs.jq
            ];
            networking.useDHCP = lib.mkForce true;
            networking.useHostResolvConf = false;
            services.resolved.enable = true;
            systemd.services.autoswitch = {
              environment = {
                NIX_REMOTE = "daemon";
              };
              wantedBy = [ "multi-user.target" ];
              serviceConfig.ExecStart = pkgs.writers.writeDash "autoswitch" ctr.startCommand;
              unitConfig.X-StopOnRemoval = false;
            };
            # get rid of stateVersion not set warning;
            system.stateVersion = config.system.nixos.release;
          };
          autoStart = false;
          enableTun = true;
          ephemeral = ctr.ephemeral;
          privateNetwork = true;
          hostBridge = "ctr0";
          bindMounts = {
            "/var/lib/self/disk" = {
              hostPath = "/var/lib/sync-containers3/${ctr.name}/disk";
              isReadOnly = false;
            };
            "/var/state" = {
              hostPath = "/var/lib/sync-containers3/${ctr.name}/state";
              isReadOnly = false;
            };
          };
        }
      ) (lib.filterAttrs (_: ctr: ctr.runContainer) cfg.containers);

      systemd.services = lib.foldr lib.recursiveUpdate { } (
        lib.flatten (
          map (ctr: [
            {
              "${ctr.name}_syncer" = {
                path = with pkgs; [
                  coreutils
                  inetutils
                  rsync
                  openssh
                  systemd
                  util-linux
                ];
                startAt = "*:0/1";
                serviceConfig = {
                  User = "${ctr.name}_container";
                  LoadCredential = [
                    "ssh_key:${ctr.sshKey}"
                  ];
                  ExecCondition = pkgs.writers.writeDash "${ctr.name}_checker" ''
                    set -efu
                    ! systemctl is-active --quiet container@${ctr.name}.service
                  '';
                  ExecStart = pkgs.writers.writeDash "${ctr.name}_syncer" ''
                    set -efux
                    flock -n "$HOME"/sync.lock ${pkgs.writers.writeDash "${ctr.name}-sync" ''
                      set -efux
                      if ping -c 1 ${ctr.hostname}; then
                        nice --adjustment=30 rsync -a -e "ssh -i $CREDENTIALS_DIRECTORY/ssh_key" --timeout=30 --inplace --sparse container_sync@${ctr.hostname}:disk "$HOME"/disk.rsync
                        touch "$HOME"/incomplete
                        nice --adjustment=30 rsync --inplace "$HOME"/disk.rsync "$HOME"/disk
                        rm -f "$HOME"/incomplete
                      fi
                    ''}
                  '';
                };
              };
            }
            {
              "${ctr.name}_watcher" = lib.mkIf ctr.runContainer {
                path = with pkgs; [
                  coreutils
                  inetutils
                  cryptsetup
                  mount
                  util-linux
                  retry
                ];
                serviceConfig = {
                  ExecStart = pkgs.writers.writeDash "${ctr.name}_watcher" ''
                    set -efux
                    while sleep 5; do
                      if ! $(retry -t 10 -d 10 -- ping -q -c 1 ${ctr.hostname} > /dev/null); then
                        echo 'container seems dead, killing'
                        break
                      fi
                    done
                    /run/current-system/sw/bin/nixos-container stop ${ctr.name} || :
                    umount /var/lib/sync-containers3/${ctr.name}/state || :
                    cryptsetup luksClose ${ctr.name} || :
                  '';
                };
              };
            }
            {
              "${ctr.name}_scheduler" = lib.mkIf ctr.runContainer {
                wantedBy = [ "multi-user.target" ];
                path = with pkgs; [
                  coreutils
                  inetutils
                  cryptsetup
                  mount
                  util-linux
                  systemd
                  retry
                ];
                serviceConfig = {
                  Restart = "always";
                  RestartSec = "30s";
                  ExecStart = pkgs.writers.writeBash "${ctr.name}_scheduler" ''
                    set -efu
                    cryptsetup luksOpen --key-file ${ctr.luksKey} /var/lib/sync-containers3/${ctr.name}/disk ${ctr.name} || :
                    mkdir -p /var/lib/sync-containers3/${ctr.name}/state
                    mountpoint /var/lib/sync-containers3/${ctr.name}/state || mount /dev/mapper/${ctr.name} /var/lib/sync-containers3/${ctr.name}/state
                    /run/current-system/sw/bin/nixos-container start ${ctr.name}
                    # wait for system to become reachable for the first time
                    systemctl start ${ctr.name}_watcher.service
                    retry -t 10 -d 10 -- ping -q -c 1 ${ctr.hostname} > /dev/null
                    while systemctl is-active container@${ctr.name}.service >/dev/null && ping -q -c 3 ${ctr.hostname} >/dev/null; do
                      sleep 10
                    done
                  '';
                };
              };
            }
            {
              "container@${ctr.name}" = lib.mkIf ctr.runContainer {
                serviceConfig = {
                  ExecStop = pkgs.writers.writeDash "remove_interface" ''
                    ${pkgs.iproute2}/bin/ip link del vb-${ctr.name}
                  '';
                  ExecStartPost = [
                    (pkgs.writers.writeDash "bind-to-bridge" ''
                      ${pkgs.iproute2}/bin/ip link set "vb-$INSTANCE" master ctr0
                    '')
                  ];
                };
              };
            }
          ]) (lib.attrValues cfg.containers)
        )
      );

      systemd.timers = lib.mapAttrs' (
        _n: ctr:
        lib.nameValuePair "${ctr.name}_syncer" {
          timerConfig = {
            RandomizedDelaySec = 100;
          };
        }
      ) cfg.containers;

      users.groups = lib.mapAttrs' (
        _: ctr:
        lib.nameValuePair "${ctr.name}_container" {
        }
      ) cfg.containers;
      users.users = lib.mapAttrs' (
        _: ctr:
        lib.nameValuePair "${ctr.name}_container" ({
          group = "${ctr.name}_container";
          isNormalUser = true;
          home = "/var/lib/sync-containers3/${ctr.name}";
          createHome = true;
          homeMode = "705";
        })
      ) cfg.containers;

      environment.systemPackages = lib.mapAttrsToList (
        _: ctr:
        (pkgs.writers.writeDashBin "${ctr.name}_init" ''
          set -efux
          export PATH=${
            lib.makeBinPath [
              pkgs.coreutils
              pkgs.cryptsetup
              pkgs.libxfs.bin
            ]
          }:$PATH
          truncate -s 5G /var/lib/sync-containers3/${ctr.name}/disk
          cryptsetup luksFormat /var/lib/sync-containers3/${ctr.name}/disk ${ctr.luksKey}
          cryptsetup luksOpen --key-file ${ctr.luksKey} /var/lib/sync-containers3/${ctr.name}/disk ${ctr.name}
          mkfs.xfs /dev/mapper/${ctr.name}
          mkdir -p /var/lib/sync-containers3/${ctr.name}/state
          mountpoint /var/lib/sync-containers3/${ctr.name}/state || mount /dev/mapper/${ctr.name} /var/lib/sync-containers3/${ctr.name}/state
          /run/current-system/sw/bin/nixos-container start ${ctr.name}
          /run/current-system/sw/bin/nixos-container run ${ctr.name} -- ${pkgs.writeDash "init" ''
            mkdir -p /var/state
          ''}
        '')
      ) cfg.containers;
    })
    (lib.mkIf (cfg.containers != { }) {
      # networking

      boot.kernel.sysctl."net.ipv4.ip_forward" = lib.mkForce 1;
      systemd.network.networks.ctr0 = {
        name = "ctr0";
        address = [
          "10.233.0.1/24"
        ];
        networkConfig = {
          ConfigureWithoutCarrier = true;
          DHCPServer = "yes";
        };
        dhcpServerConfig = {
          DNS = "9.9.9.9";
        };
      };
      systemd.network.netdevs.ctr0.netdevConfig = {
        Kind = "bridge";
        Name = "ctr0";
      };
      networking.networkmanager.unmanaged = [ "ctr0" ];
      krebs.iptables.tables.filter.INPUT.rules = [
        {
          predicate = "-i ctr0";
          target = "ACCEPT";
        }
      ];
      krebs.iptables.tables.filter.FORWARD.rules = [
        {
          predicate = "-i ctr0";
          target = "ACCEPT";
        }
        {
          predicate = "-o ctr0";
          target = "ACCEPT";
        }
      ];
      krebs.iptables.tables.nat.POSTROUTING.rules = [
        {
          v6 = false;
          predicate = "-s 10.233.0.0/24";
          target = "MASQUERADE";
        }
      ];
    })
    (lib.mkIf cfg.inContainer.enable {
      users.groups.container_sync = { };
      users.users.container_sync = {
        group = "container_sync";
        isNormalUser = true;
        home = "/var/lib/self";
        createHome = true;
        openssh.authorizedKeys.keys = [
          cfg.inContainer.pubkey
        ];
      };

      networking.useHostResolvConf = false;
      networking.useNetworkd = true;
      services.resolved = {
        enable = true;
        settings.Resolve.Domains = [ "~." ];
      };
      systemd.network = {
        enable = true;
        networks.eth0 = {
          matchConfig.Name = "eth0";
          DHCP = "yes";
          dhcpV4Config.UseDNS = true;
        };
      };
    })
  ];
}
