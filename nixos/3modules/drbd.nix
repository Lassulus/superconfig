{ config, lib, pkgs, self, ... }: let
  cfg = config.lass.drbd;
  slib = self.inputs.stockholm.lib;
in {
  options = {
    lass.drbd = lib.mkOption {
      default = {};
      type = lib.types.attrsOf (lib.types.submodule ({ config, ... }: {
        options = {
          name = lib.mkOption {
            type = lib.types.str;
            default = config._module.args.name;
          };
          blockMinor = lib.mkOption {
            type = lib.types.int;
            default = lib.mod (slib.genid config.name) 16000; # TODO get max_id fron drbd
          };
          port = lib.mkOption {
            type = lib.types.int;
            default = 20000 + config.blockMinor;
          };
          peers = lib.mkOption {
            type = lib.types.listOf slib.types.host;
          };
          disk = lib.mkOption {
            type = lib.types.str;
            default = "/dev/loop${toString config.blockMinor}";
          };
          drbdConfig = lib.mkOption {
            type = lib.types.path;
            internal = true;
            default = pkgs.writeText "drbd-${config.name}.conf" ''
              resource ${config.name} {
                net {
                  protocol a;
                  ping-int 10;
                  csums-alg crc32c;
                  connect-int 3;
                  after-sb-0pri discard-older-primary;
                  after-sb-1pri discard-secondary;

                  # seems to be drbd-proxy premium feature
                  on-congestion pull-ahead;
                  congestion-fill 1G;
                  congestion-extents 500;

                  sndbuf-size 10M;
                  max-epoch-size 20000;
                }
                device minor ${toString config.blockMinor};
                disk ${config.disk};
                meta-disk internal;
                ${slib.indent (lib.concatStrings (lib.imap1 (i: peer: /* shell */ ''
                  on ${peer.name} {
                    address ${peer.nets.retiolum.ip4.addr}:${toString config.port};
                    node-id ${toString i};
                  }
                '') config.peers))}
                connection-mesh {
                  hosts ${lib.concatMapStringsSep " " (peer: peer.name) config.peers};
                }
              }
            '';
          };
        };
      }));
    };
  };
  config = lib.mkIf (cfg != {}) {
    boot.extraModulePackages = [
      (pkgs.linuxPackages.callPackage ../5pkgs/drbd9/default.nix {})
    ];
    boot.extraModprobeConfig = ''
      options drbd usermode_helper=/run/current-system/sw/bin/drbdadm
    '';
    services.udev.packages = [ pkgs.drbd ];
    boot.kernelModules = [ "drbd" ];

    environment.systemPackages = [
      pkgs.drbd
      (pkgs.writers.writeDashBin "drbd-change-nodeid" ''
        # https://linbit.com/drbd-user-guide/drbd-guide-9_0-en/#s-using-truck-based-replication
        set -efux

        if [ "$#" -ne 2 ]; then
          echo '$1 needs to be drbd volume name'
          echo '$2 needs to be new node id'
          exit 1
        fi


        TMPDIR=$(mktemp -d)
        trap 'rm -rf $TMPDIR' EXIT

        V=$1
        NODE_TO=$2
        META_DATA_LOCATION=internal

        ${pkgs.drbd}/bin/drbdadm -- --force dump-md $V > "$TMPDIR"/md_orig.txt
        NODE_FROM=$(cat "$TMPDIR"/md_orig.txt | ${pkgs.gnused}/bin/sed -n 's/^node-id \(.*\);$/\1/p')
        ${pkgs.gnused}/bin/sed -e "s/node-id $NODE_FROM/node-id $NODE_TO/" \
          -e "s/^peer.$NODE_FROM. /peer-NEW /" \
          -e "s/^peer.$NODE_TO. /peer[$NODE_FROM] /" \
          -e "s/^peer-NEW /peer[$NODE_TO] /" \
          < "$TMPDIR"/md_orig.txt > "$TMPDIR"/md.txt

        drbdmeta --force $(drbdadm sh-minor $V) v09 $(drbdadm sh-md-dev $V) $META_DATA_LOCATION restore-md "$TMPDIR"/md.txt
      '')
    ];

    networking.firewall.allowedTCPPorts = map (device: device.port) (lib.attrValues cfg);
    systemd.services = lib.mapAttrs' (_: device:
      lib.nameValuePair "drbd-${device.name}" {
        after = [ "systemd-udev.settle.service" "network.target" "retiolum.service" ];
        wants = [ "systemd-udev.settle.service" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          RemainAfterExit = true;
          ExecStart = pkgs.writers.writeDash "start-drbd-${device.name}" ''
            set -efux
            mkdir -p /var/lib/sync-containers2
            ${lib.optionalString (device.disk == "/dev/loop${toString device.blockMinor}") ''
              if ! test -e /var/lib/sync-containers2/${device.name}.disk; then
                truncate -s 10G /var/lib/sync-containers2/${device.name}.disk
              fi
              if ! ${pkgs.util-linux}/bin/losetup /dev/loop${toString device.blockMinor}; then
                ${pkgs.util-linux}/bin/losetup /dev/loop${toString device.blockMinor} /var/lib/sync-containers2/${device.name}.disk
              fi
            ''}
            if ! ${pkgs.drbd}/bin/drbdadm adjust ${device.name}; then
              ${pkgs.drbd}/bin/drbdadm down ${device.name}
              ${pkgs.drbd}/bin/drbdadm create-md ${device.name}/0 --max-peers 31
              ${pkgs.drbd}/bin/drbdadm up ${device.name}
            fi
          '';
          ExecStop = pkgs.writers.writeDash "stop-drbd-${device.name}" ''
            set -efux
            ${pkgs.drbd}/bin/drbdadm -c ${device.drbdConfig} down ${device.name}
            ${lib.optionalString (device.disk == "/dev/loop${toString device.blockMinor}") ''
              ${pkgs.util-linux}/bin/losetup -d /dev/loop${toString device.blockMinor}
            ''}
          '';
        };
      }
    ) cfg;


    environment.etc."drbd.conf".text = ''
      global {
        usage-count yes;
      }

      ${lib.concatMapStrings (device: /* shell */ ''
        include ${device.drbdConfig};
      '') (lib.attrValues cfg)}
    '';
  };
}

