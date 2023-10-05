{ config, lib, pkgs, ... }:
{
  #prometheus
  krebs.iptables = {
    enable = true;
    tables.filter.INPUT.rules = [
      { predicate = "-i retiolum -p tcp --dport 80"; target = "ACCEPT"; } # nginx
      # { predicate = "-i retiolum -p tcp --dport 3012"; target = "ACCEPT"; } # grafana
      # { predicate = "-i retiolum -p tcp --dport 9093"; target = "ACCEPT"; } # alertmanager
      # { predicate = "-i retiolum -p tcp --dport 9223"; target = "ACCEPT"; } # alertmanager
    ];
  };

  services.nginx = {
    enable = true;
    virtualHosts = {
      "prometheus.lass.r" = {
        locations."/".proxyPass = "http://localhost:9090";
      };
      "alert.lass.r" = {
        locations."/".proxyPass = "http://localhost:9093";
      };
      "grafana.lass.r" = {
        locations."/".proxyPass = "http://localhost:3012";
      };
    };
  };

  services.grafana = {
    enable = true;
    addr = "0.0.0.0";
    port = 3012;
    auth.anonymous = {
      enable = true;
      org_role = "Admin";
    };
  };
  services.prometheus = {
    enable = true;
    ruleFiles = [
      (pkgs.writeText "prometheus-rules.yml" (builtins.toJSON {
        groups = [{
          name = "alerting-rules";
          rules = import ./alert-rules.nix { inherit lib; };
        }];
      }))
    ];
    scrapeConfigs = [
      {
        job_name = "telegraf";
        scrape_interval = "60s";
        metrics_path = "/metrics";
        static_configs = [
          {
            targets = [
              "prism.r:9273"
              "dishfire.r:9273"
              "yellow.r:9273"
            ];
          }
        ];
      }
    ];
    alertmanagers = [
      { scheme = "http";
        path_prefix = "/";
        static_configs = [ { targets = [ "localhost:9093" ]; } ];
      }
    ];
    alertmanager = {
      enable = true;
      webExternalUrl = "https://alert.lass.r";
      listenAddress = "[::1]";
      configuration = {
        global = {
          # The smarthost and SMTP sender used for mail notifications.
          smtp_smarthost = "localhost:587";
          smtp_from = "alertmanager@alert.lass.r";
          # smtp_auth_username = "alertmanager@thalheim.io";
          # smtp_auth_password = "$SMTP_PASSWORD";
        };
        route = {
          receiver = "default";
          routes = [
            {
              group_by = [ "host" ];
              group_wait = "30s";
              group_interval = "2m";
              repeat_interval = "2h";
              receiver = "all";
            }
          ];
        };
        receivers = [
          {
            name = "all";
            webhook_configs = [{
              url = "http://127.0.0.1:9223/";
              max_alerts = 5;
            }];
          }
          {
            name = "default";
          }
        ];
      };
    };
  };

}
