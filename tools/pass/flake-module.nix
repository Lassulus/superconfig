{ self, inputs, ... }:
{
  perSystem =
    {
      pkgs,
      system,
      ...
    }:
    {
      packages.pass = inputs.wrappers.lib.wrapPackage {
        pkgs = pkgs;
        package = pkgs.passage;
        runtimeInputs = [
          pkgs.age-plugin-fido2-hmac
          pkgs.age-plugin-yubikey
          pkgs.age-plugin-tpm
          self.packages.${system}.pass-otp
          self.packages.${system}.age-detect
        ]
        ++ (pkgs.lib.optionals pkgs.stdenv.isLinux [
          self.packages.${system}.pinentry-rofi-age
        ])
        ++ (pkgs.lib.optionals pkgs.stdenv.isDarwin [
          pkgs.age-plugin-se
        ])
        ++ (pkgs.lib.optionals (!pkgs.stdenv.isDarwin) [
          # Dummy age-plugin-se for Linux (encryption only, no Secure Enclave hardware)
          (pkgs.writeShellScriptBin "age-plugin-se" ''
            exec env PYTHONUNBUFFERED=1 ${
              pkgs.python3.withPackages (ps: [ ps.cryptography ])
            }/bin/python3 ${./age-plugin-se-dummy.py} "$@"
          '')
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
                          export AGE_DETECT_KEYS_DIR="${self}/keys"
                          eval "$(age-detect)"

                          # Set up identity file if detected
                          if [[ -n "''${IDENTITY_FILE:-}" ]]; then
                            export PASSAGE_IDENTITIES_FILE="$IDENTITY_FILE"
                            trap 'rm -f "$IDENTITY_FILE"' EXIT
                          fi
                        fi

            ${
              if pkgs.stdenv.isLinux then
                ''
                  maybe_set_tpm_pin() {
                    local target="''${1:-<stdin>}"
                    if [[ "''${KEY_TYPE:-}" != "tpm" ]]; then
                      return 0
                    fi
                    if [[ -n "''${AGE_TPM_PIN:-}" ]]; then
                      return 0
                    fi
                    AGE_TPM_PIN="$(${self.packages.${system}.pinentry-rofi-age}/bin/pinentry-rofi-age "$target")"
                    export AGE_TPM_PIN
                  }

                  decrypt_target=""
                  if [[ "''${1:-}" == "show" ]]; then
                    decrypt_target="''${2:-}"
                  elif [[ -n "''${1:-}" ]] && [[ "''${1:-}" != -* ]] && [[ "''${1:-}" != "otp" ]]; then
                    decrypt_target="''${1:-}"
                  fi

                  if [[ -n "$decrypt_target" ]]; then
                    maybe_set_tpm_pin "$decrypt_target"
                  fi
                ''
              else
                ''
                  # No TPM on Darwin, define no-op
                  maybe_set_tpm_pin() { :; }
                ''
            }

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
                          maybe_set_tpm_pin "$pass_name"
                          ${exePath} show "$pass_name" | pass-otp $clip_arg
                        else
                          # Pass all other commands directly to passage (identities already set up)
                          ${exePath} "$@"
                        fi
          '';
      };
    };
}
