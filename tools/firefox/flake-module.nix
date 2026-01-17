{
  perSystem =
    { pkgs, ... }:
    let
      tridactylrc = ./tridactylrc;

      firefoxBase = pkgs.wrapFirefox pkgs.firefox-unwrapped {
        nativeMessagingHosts = [
          pkgs.tridactyl-native
        ];
      };

      # Wrapper that sets up tridactylrc symlink before starting Firefox
      firefox = pkgs.writeShellScriptBin "firefox" ''
        # Tridactyl config setup
        config_dir="$HOME/.config/tridactyl"
        config_file="$config_dir/tridactylrc"
        repo_config="$HOME/src/superconfig/tools/firefox/tridactylrc"
        store_config="${tridactylrc}"

        mkdir -p "$config_dir"

        # Prefer repo version if it exists, otherwise use store version
        if [[ -f "$repo_config" ]]; then
          target="$repo_config"
        else
          target="$store_config"
        fi

        # Update symlink if needed
        if [[ ! -L "$config_file" ]] || [[ "$(readlink "$config_file")" != "$target" ]]; then
          ln -sf "$target" "$config_file"
        fi

        exec ${firefoxBase}/bin/firefox "$@"
      '';
    in
    {
      packages.firefox = firefox;
    };
}
