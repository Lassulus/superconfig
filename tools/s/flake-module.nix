{ self, ... }:
{
  perSystem =
    { pkgs, lib, ... }:
    let
      # Collect all completable package names
      packageNames = builtins.attrNames self.packages.${pkgs.system};
      legacyPackageNames =
        let
          lp = self.legacyPackages.${pkgs.system} or { };
          flatten =
            prefix: attrs:
            lib.concatLists (
              lib.mapAttrsToList (
                name: value:
                let
                  path = if prefix == "" then name else "${prefix}.${name}";
                in
                if lib.isDerivation value then
                  [ path ]
                else if builtins.isAttrs value then
                  flatten path value
                else
                  [ ]
              ) attrs
            );
        in
        flatten "" lp;
      allNames = packageNames ++ legacyPackageNames;

      completionPath = lib.makeBinPath [
        pkgs.nix
        pkgs.jq
        pkgs.usage
      ];

      zshCompletion = pkgs.writeText "_s" ''
        #compdef s

        _s() {
          local -x PATH="${completionPath}:$PATH"

          if (( CURRENT == 2 )); then
            # Complete package name
            local -a packages
            packages=(
              ${lib.concatMapStringsSep "\n    " (name: "'${name}'") allNames}
            )
            _describe 'package' packages
          else
            # Complete args for the selected package using usage spec
            local pkg="''${words[2]}"
            [[ -z "$pkg" ]] && return

            # Resolve flake path (same logic as s itself)
            local flake
            if [[ -d "$HOME/src/superconfig" ]]; then
              flake="$HOME/src/superconfig"
            elif [[ -d "$HOME/sync/superconfig" ]]; then
              flake="$HOME/sync/superconfig"
            else
              flake="${self}"
            fi

            # Cache directory
            local cache_dir="''${XDG_CACHE_HOME:-$HOME/.cache}/s-completions"

            # Get cache key from flake narHash (~0.1s)
            local cache_key
            cache_key=$(nix flake metadata "$flake" --json 2>/dev/null | jq -r '.locked.narHash // .narHash // (.lastModified | tostring)' 2>/dev/null) || return
            [[ -z "$cache_key" ]] && return
            cache_key=''${cache_key//\//_}

            local cached_file="$cache_dir/''${cache_key}/''${pkg}.kdl"

            if [[ ! -f "$cached_file" ]]; then
              # Cache miss: fetch usage spec via nix eval (~3.6s, first time only)
              mkdir -p "$cache_dir/$cache_key"
              local sys
              sys=$(nix eval --impure --raw --expr 'builtins.currentSystem' 2>/dev/null) || return
              nix eval "''${flake}#packages.''${sys}.''${pkg}.usage" --raw 2>/dev/null > "$cached_file" || {
                rm -f "$cached_file"
                return
              }
              # Empty file means no usage spec
              [[ -s "$cached_file" ]] || { rm -f "$cached_file"; return; }
            fi

            # Feed to usage complete-word (~4ms), using the ((...)) format that _arguments expects
            _arguments "*: :(($(usage complete-word --shell zsh -f "$cached_file" -- "''${words[@]:1}")))"
          fi
        }

        _s "$@"
      '';
    in
    {
      packages.s =
        (pkgs.writeShellApplication {
          name = "s";
          runtimeInputs = [ pkgs.nix ];
          text = ''
            # Use local checkout if it exists, otherwise fall back to self
            if [ -d "$HOME/src/superconfig" ]; then
              flake="$HOME/src/superconfig"
            elif [ -d "$HOME/sync/superconfig" ]; then
              flake="$HOME/sync/superconfig"
            else
              flake="${self}"
            fi

            if [ $# -eq 0 ]; then
              echo "Usage: s <package> [args...]" >&2
              echo "Runs a package from superconfig ($flake)" >&2
              exit 1
            fi

            pkg="$1"
            shift

            exec nix run "$flake#$pkg" -- "$@"
          '';
        }).overrideAttrs
          (old: {
            buildCommand = old.buildCommand + ''
              mkdir -p $out/share/zsh/site-functions
              cp ${zshCompletion} $out/share/zsh/site-functions/_s
            '';
            passthru = (old.passthru or { }) // {
              usage = builtins.readFile ./usage.kdl;
            };
          });
    };
}
