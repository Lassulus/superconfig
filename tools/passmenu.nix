{ self, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      packages.passmenu = pkgs.writeShellApplication {
        name = "passmenu";
        runtimeInputs = [
          self.packages.${pkgs.system}.menu
        ];
        text = ''
          set -eu
          shopt -s nullglob globstar

          # typeit=0
          # if [[ $1 == "--type" ]]; then
          #   typeit=1
          #   shift
          # fi

          prefix=''${PASSWORD_STORE_DIR-~/.password-store}
          password_files=( "$prefix"/**/*.gpg )
          password_files=( "''${password_files[@]#"$prefix"/}" )
          password_files=( "''${password_files[@]%.gpg}" )

          password=$(printf '%s\n' "''${password_files[@]}" | menu "$@")

          filename=$(basename "$password")
          if [[ "$filename" == "otp" ]]; then
            pass otp -c "$password" 2>/dev/null
          else
            pass show -c "$password" 2>/dev/null
          fi
        '';
      };
    };
}
