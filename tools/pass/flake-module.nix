{ self, ... }:
{
  perSystem =
    {
      pkgs,
      system,
      ...
    }:
    {
      packages.pass = self.libWithPkgs.${system}.makeWrapper pkgs.passage {
        runtimeInputs = [
          pkgs.age-plugin-se
          pkgs.age-plugin-fido2-hmac
          pkgs.age-plugin-yubikey
          self.packages.${system}.pass-otp
        ];
        aliases = [ "pass" ];
        wrapper =
          {
            exePath,
            envString,
            preHook,
            ...
          }:
          ''
            ${envString}
            ${preHook}

            # Check if bulk key file should be used for decryption
            if [[ -n "''${PASS_BULK_KEY_FILE:-}" ]]; then
              if [[ ! -f "$PASS_BULK_KEY_FILE" ]] || [[ ! -s "$PASS_BULK_KEY_FILE" ]]; then
                mkdir -p "$(dirname "$PASS_BULK_KEY_FILE")"
                ${exePath} show bulk-operations/age-key > "$PASS_BULK_KEY_FILE" 2>/dev/null || true
              fi
            fi

            # Handle OTP commands by delegating to pass-otp
            if [[ "''${1:-}" == "otp" ]]; then
              shift
              # Extract pass name and options
              clip_arg=""
              pass_name=""
              for arg in "$@"; do
                case "$arg" in
                  "--clip"|"-c")
                    clip_arg="--clip"
                    ;;
                  *)
                    pass_name="$arg"
                    ;;
                esac
              done

              if [[ -z "$pass_name" ]]; then
                echo "Usage: pass otp [--clip,-c] pass-name"
                exit 1
              fi

              # Use bulk key for decryption if available
              if [[ -n "''${PASS_BULK_KEY_FILE:-}" ]] && [[ -f "$PASS_BULK_KEY_FILE" ]] && [[ -s "$PASS_BULK_KEY_FILE" ]]; then
                PASSAGE_IDENTITIES_FILE="$PASS_BULK_KEY_FILE" ${exePath} show "$pass_name" | pass-otp $clip_arg
              else
                ${exePath} show "$pass_name" | pass-otp $clip_arg
              fi
            # Handle show commands with bulk key optimization
            elif [[ "''${1:-}" == "show" ]]; then
              if [[ -n "''${PASS_BULK_KEY_FILE:-}" ]] && [[ -f "$PASS_BULK_KEY_FILE" ]] && [[ -s "$PASS_BULK_KEY_FILE" ]]; then
                PASSAGE_IDENTITIES_FILE="$PASS_BULK_KEY_FILE" ${exePath} "$@"
              else
                ${exePath} "$@"
              fi
            else
              # Pass all other commands directly to passage
              ${exePath} "$@"
            fi
          '';
      };
    };
}
