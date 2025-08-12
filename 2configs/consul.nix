{
  config,
  lib,
  pkgs,
  ...
}:
{
  services.consul = {
    enable = true;
    # dropPrivileges = false;
    webUi = true;
    # interface.bind = "retiolum";
    extraConfig = {
      bind_addr = config.krebs.build.host.nets.retiolum.ip4.addr;
      bootstrap_expect = 3;
      server = true;
      # retry_join = config.services.consul.extraConfig.start_join;
      retry_join = lib.mapAttrsToList (_n: h: lib.head h.nets.retiolum.aliases) (
        lib.filterAttrs (_n: h: h.consul) config.krebs.hosts
      );
      rejoin_after_leave = true;

      # try to fix random lock loss on leader reelection
      retry_interval = "3s";

      # Autopilot configuration for better automatic failure handling
      autopilot = {
        # Automatically clean up dead servers
        cleanup_dead_servers = true;
        # How long a server must be stable before promoting
        server_stabilization_time = "10s";
        # Only requires 3 servers minimum instead of all configured servers
        min_quorum = 3;
      };

      # Performance tuning for faster leader elections
      performance = {
        # Reduce raft timing for faster recovery
        raft_multiplier = 1;
      };

      # Leave on terminate for cleaner shutdowns
      leave_on_terminate = true;
    };
  };

  # Add systemd override for easier recovery
  systemd.services.consul = {
    # Add pre-start script to clean up potential issues
    preStart = ''
      # Remove any stale peers.json from failed recovery attempts
      rm -f /var/lib/consul/raft/peers.json

      # Ensure proper permissions
      chown -R consul:consul /var/lib/consul
    '';

    # Add recovery commands to service
    serviceConfig = {
      # Allow consul to restart on failure
      Restart = "on-failure";
      RestartSec = "5s";
      StartLimitBurst = 3;
      StartLimitInterval = "60s";
    };
  };

  # Add recovery helper script
  environment.systemPackages = [
    (pkgs.writeScriptBin "consul-recover" ''
      #!${pkgs.stdenv.shell}
      set -e

      echo "Consul Recovery Tool"
      echo "==================="
      echo ""

      case "''${1:-}" in
        force-leave)
          if [ -z "''$2" ]; then
            echo "Usage: consul-recover force-leave <node-name>"
            exit 1
          fi
          echo "Force removing node ''$2 from cluster..."
          consul force-leave "''$2"
          ;;

        reset-cluster)
          echo "WARNING: This will completely reset the local consul cluster data!"
          echo "Only use this if the cluster is completely broken."
          read -p "Are you sure? (yes/no): " confirm
          if [ "''$confirm" = "yes" ]; then
            echo "Stopping consul..."
            systemctl stop consul
            echo "Clearing consul data..."
            rm -rf /var/lib/consul/*
            echo "Starting consul..."
            systemctl start consul
            echo "Reset complete. This node will rejoin or form a new cluster."
          else
            echo "Cancelled."
          fi
          ;;

        bootstrap-single)
          echo "WARNING: This will force this node to bootstrap as a single-node cluster!"
          echo "Only use this in emergency recovery scenarios."
          read -p "Are you sure? (yes/no): " confirm
          if [ "''$confirm" = "yes" ]; then
            echo "Stopping consul..."
            systemctl stop consul
            echo "Clearing consul data..."
            rm -rf /var/lib/consul/*
            echo "Creating temporary bootstrap configuration..."
            cat /etc/consul.json | ${pkgs.jq}/bin/jq '.bootstrap_expect = 1' > /tmp/consul-bootstrap.json
            echo "Starting consul in bootstrap mode..."
            consul agent -server -data-dir=/var/lib/consul -config-file=/tmp/consul-bootstrap.json -config-file=/etc/consul-addrs.json -config-dir=/etc/consul.d &
            CONSUL_PID=$!
            sleep 10
            echo "Checking cluster status..."
            if consul operator raft list-peers; then
              echo "Bootstrap successful! Restarting with normal configuration..."
              kill $CONSUL_PID
              systemctl start consul
            else
              echo "Bootstrap failed!"
              kill $CONSUL_PID 2>/dev/null || true
              exit 1
            fi
          else
            echo "Cancelled."
          fi
          ;;

        status)
          echo "Consul Cluster Status:"
          echo "====================="
          echo ""
          echo "Members:"
          consul members || echo "Failed to get members (no leader?)"
          echo ""
          echo "Raft Peers:"
          consul operator raft list-peers || echo "Failed to get raft peers (no leader?)"
          echo ""
          echo "Service Status:"
          systemctl status consul --no-pager | head -20
          ;;

        *)
          echo "Usage: consul-recover <command>"
          echo ""
          echo "Commands:"
          echo "  status              - Show cluster status"
          echo "  force-leave <node>  - Force remove a node from the cluster"
          echo "  reset-cluster       - Completely reset local consul data"
          echo "  bootstrap-single    - Emergency: Bootstrap as single-node cluster"
          ;;
      esac
    '')
  ];

  environment.etc."consul.d/testservice.json".text = builtins.toJSON {
    service = {
      name = "testing";
    };
  };

  krebs.iptables.tables.filter.INPUT.rules = [
    {
      predicate = "-i retiolum -p tcp --dport 8300";
      target = "ACCEPT";
    }
    {
      predicate = "-i retiolum -p tcp --dport 8301";
      target = "ACCEPT";
    }
    {
      predicate = "-i retiolum -p udp --dport 8301";
      target = "ACCEPT";
    }
    {
      predicate = "-i retiolum -p tcp --dport 8302";
      target = "ACCEPT";
    }
    {
      predicate = "-i retiolum -p udp --dport 8302";
      target = "ACCEPT";
    }
    {
      predicate = "-i retiolum -p tcp --dport 8400";
      target = "ACCEPT";
    }
    {
      predicate = "-i retiolum -p tcp --dport 8500";
      target = "ACCEPT";
    }
    {
      predicate = "-i retiolum -p tcp --dport 8600";
      target = "ACCEPT";
    }
    {
      predicate = "-i retiolum -p udp --dport 8500";
      target = "ACCEPT";
    }
  ];
}
