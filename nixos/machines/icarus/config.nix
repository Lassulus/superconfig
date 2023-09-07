{ config, lib, pkgs, ... }:

{
  imports = [
    ../../.

    ../../2configs/mouse.nix
    ../../2configs/retiolum.nix
    ../../2configs/git.nix
    ../../2configs/exim-retiolum.nix
    ../../2configs/baseX.nix
    ../../2configs/pipewire.nix
    ../../2configs/browsers.nix
    ../../2configs/programs.nix
    ../../2configs/fetchWallpaper.nix
    ../../2configs/games.nix
    ../../2configs/bitcoin.nix
    ../../2configs/wine.nix
    ../../2configs/network-manager.nix
    ../../2configs/red-host.nix
    ../../2configs/ipfs.nix
    ../../2configs/snapclient.nix
    ../../2configs/consul.nix
    { # === logging playground ===
      # --- client ---

      # services.fluentd = {
      #   enable = true;
      #   config = ''
      #   '';
      # };

      # services.netdata = {
      #   enable = true;
      #   config = {
      #     global = {
      #       "debug log" = "syslog";
      #       "error log" = "syslog";
      #     };

      #     backend = {
      #       enabled = "yes";
      #       type = "opentsdb";
      #       destination = "tcp:localhost:4242";
      #       prefix = "netdata";
      #       hostname = config.networking.hostName;
      #     };
      #     # "exporting:global" = {
      #     #   enabled = "yes";
      #     #   "update every" = "60";
      #     # };
      #     # "graphite:icarus" = {
      #     #   enabled = "yes";
      #     #   destination = "localhost:8086";
      #     #   "data source" = "average";
      #     #   prefix = "netdata";
      #     #   hostname = config.networking.hostName;
      #     #   "send charts matching" = "*";
      #     #   "send hosts matching" = "localhost *";
      #     #   "send names instead of ids" = "yes";
      #     # };
      #   };
      # };

      # - metrics
      services.telegraf = {
        enable = true;
        extraConfig = {
          inputs = {
            cpu = {};
            mem = {};
            net = {
              ignore_protocol_stats = true;
            };
            exec = {
              command = pkgs.writers.writePython3 "get_bat_stats" {} /* python */ ''
                import json
                import os


                values_to_fetch = [
                    "capacity",
                    "energy_now",
                    "energy_full",
                    "energy_full_design",
                    "charge_now",
                    "charge_full",
                    "charge_full_design",
                ]

                result = {}
                for sup in os.listdir('/sys/class/power_supply'):
                    with open('/sys/class/power_supply/{}/type'.format(sup)) as f:
                        if f.read().strip() != "Battery":
                            continue
                    for val in values_to_fetch:
                        try:
                            with open('/sys/class/power_supply/{}/{}'.format(sup, val)) as f:
                                key = '{}_{}'.format(sup, val)
                                try:
                                    result[key] = int(f.read().strip())
                                except ValueError:
                                    result[key] = f.read().strip()
                        except:  # noqa
                            pass

                print(json.dumps(result))
              '';
              data_format = "json";
              name_suffix = "_bat";
              interval = "10s";
            };
          };
          outputs = {
            influxdb = { database = "telegraf"; urls = [ "http://localhost:8086" ]; };
          };
        };
      };

      # --- server ---

      # - metrics
      services.influxdb = {
        enable = true;
        extraConfig = {
          opentsdb = [{
            enabled = true;
            bind-address = ":4242";
            database = "opentsdb";
            retention-policy = "";

            batch-size = 1000;
            batch-pending = 5;
            batch-timeout = "1s";
          }];
        };
      };

      # - logs
      services.graylog = {
        enable = true;
        passwordSecret = "AmjUYosI6hXKyI1MLEusupZy7srxQxZOowpHSmvF0ekMoi19go5qmnqd3po4VcQahdR1AKZ3Yk9tP6nLUbgmzLwQFodIc5g8";
        rootPasswordSha2 = "cf80cd8aed482d5d1527d7dc72fceff84e6326592848447d2dc0b0e87dfc9a90"; # testing
        elasticsearchHosts = [ "http://localhost:9200" ];
      };

      services.elasticsearch = {
        enable = true;
      };
      # services.loki = {
      #   enable = true;
      #   configuration = {
      #     auth_enabled = false;
      #     server.http_listen_port = 3100;
      #     ingester = {
      #       lifecycler = {
      #         address = "127.0.0.1";
      #         ring = {
      #           kvstore.store = "inmemory";
      #           replication_factor = 1;
      #         };
      #         final_sleep = "0s";
      #       };
      #     };
      #     schema_config = {
      #       configs = [
      #         {
      #           from = "2018-04-15";
      #           store = "inmemory";
      #           object_store = "filesystem";
      #           schema = "v9";
      #         }
      #       ];
      #     };
      #     storage_config = {
      #       filesystem.directory = "/tmp/loki/chunks";
      #     };
      #     #table_manager = {
      #     #  chunk_tables_provisioning = {
      #     #    inactive_read_throughput = 0;
      #     #    inactive_write_throughput = 0;
      #     #    provisioned_read_throughput = 0;
      #     #    provisioned_write_throughput = 0;
      #     #  };
      #     #  index_tables_provisioning = {
      #     #    inactive_read_throughput = 0;
      #     #    inactive_write_throughput = 0;
      #     #    provisioned_read_throughput = 0;
      #     #    provisioned_write_throughput = 0;
      #     #  };
      #     #  retention_deletes_enabled = false;
      #     #  retention_period = 0;
      #     #};
      #   };
      # };

      services.grafana = {
        enable = true;
        addr = "0.0.0.0";
        auth.anonymous.enable = true;
        auth.anonymous.org_role = "Admin";
      };
      krebs.iptables.tables.filter.INPUT.rules = [
        { predicate = "-p tcp --dport 3000"; target = "ACCEPT"; } # grafana
      ];
    }
  ];

  krebs.build.host = config.krebs.hosts.icarus;

  # services.xrdp = {
  #   enable = true;
  #   defaultWindowManager = "xmonad";
  # };
  # krebs.iptables.tables.filter.INPUT.rules = [
  #   { predicate = "-p tcp --dport 3389"; target = "ACCEPT"; } # xrdp
  # ];

  environment.systemPackages = [ pkgs.chromium ];

  # users.users.lass.openssh.authorizedKeys = [ config.krebs.users.mic92.pubkey ];
  system.stateVersion = "22.05";
}
