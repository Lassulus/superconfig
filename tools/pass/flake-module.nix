{ self, ... }:
{
  perSystem =
    {
      pkgs,
      system,
      ...
    }:
    {
      packages.pass = self.wrapLib.makeWrapper {
        pkgs = pkgs;
        package = pkgs.passage;
        runtimeInputs = [
          pkgs.age-plugin-fido2-hmac
          pkgs.age-plugin-yubikey
          self.packages.${system}.pass-otp
          self.packages.${system}.age-detect
        ] ++ (pkgs.lib.optionals pkgs.stdenv.isDarwin [
          pkgs.age-plugin-se
        ]);
        aliases = [ "pass" ];
        wrapper =
          {
            exePath,
            envString,
            preHook,
            ...
          }:
          ''
            set -x
            ${envString}
            ${preHook}

            # Check if bulk key file should be used for decryption
            if [[ -n "''${PASS_BULK_KEY_FILE:-}" ]]; then
              if [[ ! -f "$PASS_BULK_KEY_FILE" ]] || [[ ! -s "$PASS_BULK_KEY_FILE" ]]; then
                mkdir -p "$(dirname "$PASS_BULK_KEY_FILE")"
                ${exePath} show bulk-operations/age-key > "$PASS_BULK_KEY_FILE" 2>/dev/null || true
              fi
            fi

            # Set up identities for age decryption
            if [[ -n "''${PASS_BULK_KEY_FILE:-}" ]] && [[ -f "$PASS_BULK_KEY_FILE" ]] && [[ -s "$PASS_BULK_KEY_FILE" ]]; then
              # Use bulk key if available
              export PASSAGE_IDENTITIES_FILE="$PASS_BULK_KEY_FILE"
            else
              # Detect available age keys
              eval "$(age-detect)"

              # Set up identity file if detected
              if [[ -n "''${IDENTITY_FILE:-}" ]]; then
                export PASSAGE_IDENTITIES_FILE="$IDENTITY_FILE"
                trap 'rm -f "$IDENTITY_FILE"' EXIT
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

              # Show pass and pipe to OTP (identities already set up by age-detect)
              ${exePath} show "$pass_name" | pass-otp $clip_arg
            else
              # Pass all other commands directly to passage (identities already set up)
              ${exePath} "$@"
            fi
          '';
      };
    };
}
