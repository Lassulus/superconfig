{ self, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      packages.passmenu = pkgs.writeShellApplication {
        name = "passmenu";
        runtimeInputs =
          with pkgs;
          [
            self.packages.${pkgs.system}.menu
            self.packages.${pkgs.system}.pass
          ]
          ++ pkgs.lib.optionals pkgs.stdenv.isLinux [
            wtype
            xdotool
          ];
        text = ''
          set -eu
          shopt -s nullglob globstar

          typeit=0
          if [[ $# -gt 0 && $1 == "--type" ]]; then
            typeit=1
            shift
          fi

          prefix=''${PASSWORD_STORE_DIR-~/.password-store}
          password_files=( "$prefix"/**/*.gpg )
          password_files=( "''${password_files[@]#"$prefix"/}" )
          password_files=( "''${password_files[@]%.gpg}" )

          password=$(printf '%s\n' "''${password_files[@]}" | menu "$@")

          filename=$(basename "$password")
          if [[ "$filename" == "otp" ]]; then
            if [[ $typeit -eq 1 ]]; then
              # Type OTP code
              otp_code=$(pass otp "$password" | tr -d '\n')
              if [[ "$(uname)" == "Darwin" ]]; then
                # On macOS, use osascript to type the code
                osascript -e "tell application \"System Events\" to keystroke \"$otp_code\"" 2>/dev/null
              elif [[ -n "$WAYLAND_DISPLAY" ]]; then
                echo -n "$otp_code" | wtype -d 10 -s 400 -
              else
                echo -n "$otp_code" | xdotool type --clearmodifiers --file -
              fi
            else
              pass otp --clip "$password" 2>/dev/null
            fi
          else
            if [[ $typeit -eq 1 ]]; then
              # Type password
              pw=$(pass show "$password" | head -n1 | tr -d '\n')
              if [[ "$(uname)" == "Darwin" ]]; then
                # On macOS, use osascript to type the password
                osascript -e "tell application \"System Events\" to keystroke \"$pw\"" 2>/dev/null
              elif [[ -n "$WAYLAND_DISPLAY" ]]; then
                echo -n "$pw" | wtype -d 10 -s 400 -
              else
                echo -n "$pw" | xdotool type --clearmodifiers --file -
              fi
            else
              pass show --clip "$password" 2>/dev/null
            fi
          fi
        '';
      };
    };
}
