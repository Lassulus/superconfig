{
  config,
  lib,
  pkgs,
  self,
  ...
}:
let
  flake = "github:lassulus/superconfig";

  # Timestamp of the flake revision this system was built from, baked into the
  # closure so the running system knows how old its own source is.
  stampFile = "/run/current-system/source-lastModified";

  # system.autoUpgrade switches to whatever the flake currently evaluates to,
  # forwards or backwards. A machine deployed from an unpushed local checkout
  # therefore gets reverted to the older remote HEAD on the next timer run.
  # Refuse to move backwards in time.
  guard = pkgs.writeShellApplication {
    name = "autoupgrade-forward-only";
    runtimeInputs = [
      config.nix.package
      pkgs.coreutils
      pkgs.jq
    ];
    text = ''
      stamp=''${1:-${stampFile}}
      current=$(cat "$stamp" 2>/dev/null || echo 0)
      if ! meta=$(nix flake metadata --refresh --json ${lib.escapeShellArg flake}); then
        echo "autoupgrade: cannot reach ${flake}; letting nixos-upgrade report the error"
        exit 0
      fi
      remote=$(jq -r '.lastModified // 0' <<<"$meta")
      if [ "$remote" -gt "$current" ]; then
        exit 0
      fi
      echo "autoupgrade: ${flake} is at $remote, running system is at $current; skipping"
      exit 1
    '';
  };
in
{
  system.autoUpgrade = {
    enable = true;
    inherit flake;
    randomizedDelaySec = "6h";
  };

  system.extraSystemBuilderCmds = ''
    echo -n ${toString (self.lastModified or 0)} > $out/source-lastModified
  '';

  systemd.services.nixos-upgrade.serviceConfig.ExecCondition = lib.getExe guard;
}
