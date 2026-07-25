{ self, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    let
      # Client omp carrying covibe's env-driven headless collab autostart
      # (OMP_COLLAB_*) -- the exact patch the neoprism covibe service uses. A
      # session started from any machine hosts natively against the covibe
      # relay and is immediately joinable / browser-viewable. It does NOT show
      # up in the covibe dashboard overview: that list is built from a local
      # spool dir + local pid liveness + a per-session unix socket, so it only
      # enumerates sessions running on the dashboard host.
      ompCollab = self.legacyPackages.${system}.llm.omp.overrideAttrs (o: {
        patches = (o.patches or [ ]) ++ [ ../../2configs/omp-collab-autostart.patch ];
      });
    in
    {
      packages.covibe =
        (pkgs.writeShellApplication {
          name = "covibe";
          runtimeInputs = [
            pkgs.coreutils
            pkgs.qrencode
          ];
          text = ''
            relay="''${COVIBE_RELAY:-wss://covibe.lassul.us}"
            web="''${COVIBE_WEB:-https://covibe.lassul.us/c}"
            host="''${COVIBE_RELAY_HOST:-covibe.lassul.us}"

            # Mint an omp-compatible collab room, matching covibe's collablink:
            #   room   = base64url(16 random bytes)                -> 22 chars
            #   secret = base64url(32-byte AES key + 16-byte token) -> 64 chars
            # Handing these to omp via OMP_COLLAB_ROOM/KEY makes the shareable
            # link stable and known up front (no scraping the TUI).
            room="$(head -c 16 /dev/urandom | basenc --base64url -w0 | tr -d '=')"
            secret="$(head -c 48 /dev/urandom | basenc --base64url -w0 | tr -d '=')"

            join="''${host}/r/''${room}.''${secret}"
            browser="''${web}/#''${join}"

            export OMP_COLLAB_RELAY="$relay"
            export OMP_COLLAB_WEB="$web"
            export OMP_COLLAB_ROOM="$room"
            export OMP_COLLAB_KEY="$secret"

            {
              printf '\n  covibe: hosting this session on %s\n\n' "$host"
              printf '  omp join   %s\n' "$join"
              printf '  browser    %s\n\n' "$browser"
              qrencode -t UTF8 -m 2 "$browser" || true
              printf '\n'
            } >&2

            exec ${ompCollab}/bin/omp "$@"
          '';
        }).overrideAttrs
          { passthru.usage = builtins.readFile ./usage.kdl; };
    };
}
