# crit (https://crit.md): agents run `crit` to open their diff/plan for review
# in the browser and block until it is finished. Each review session is its
# own daemon on its own port, reachable over retiolum as
# http://<host>.r:<port>.
#
# SECURITY: crit has no authentication, and comments left in a review are fed
# to the agent as instructions. Whoever can reach a daemon can steer an agent
# running here, so the ports are only open on retiolum.
{
  self,
  config,
  pkgs,
  ...
}:
let
  firstPort = 7700;
  lastPort = 7719;
  crit-unwrapped = self.inputs.llm-agents.packages.${pkgs.system}.crit;

  # crit binds 127.0.0.1 on a random port by default. Bind all interfaces on a
  # free port from the firewalled range instead and advertise the retiolum URL.
  # Only the invocation that starts a daemon binds the port; reconnecting to a
  # running session uses the port and URL recorded in ~/.crit/sessions.
  crit = pkgs.symlinkJoin {
    name = "crit";
    paths = [
      (pkgs.writeShellScriptBin "crit" ''
        if [ -z "''${CRIT_PORT:-}" ]; then
          for p in $(${pkgs.coreutils}/bin/seq ${toString firstPort} ${toString lastPort}); do
            if [ -z "$(${pkgs.iproute2}/bin/ss -Htln "sport = :$p")" ]; then
              export CRIT_PORT=$p
              break
            fi
          done
        fi
        if [ -n "''${CRIT_PORT:-}" ]; then
          export CRIT_PUBLIC_URL="''${CRIT_PUBLIC_URL:-http://${config.networking.hostName}.r:$CRIT_PORT}"
        else
          echo "crit: ports ${toString firstPort}-${toString lastPort} all busy, using a random port (not reachable over retiolum)" >&2
        fi
        export CRIT_HOST="''${CRIT_HOST:-0.0.0.0}"
        export CRIT_ALLOW_UNAUTHENTICATED_NETWORK=1
        exec ${crit-unwrapped}/bin/crit "$@"
      '')
      crit-unwrapped
    ];
  };
in
{
  environment.systemPackages = [ crit ];

  networking.firewall.interfaces.retiolum.allowedTCPPortRanges = [
    {
      from = firstPort;
      to = lastPort;
    }
  ];
}
