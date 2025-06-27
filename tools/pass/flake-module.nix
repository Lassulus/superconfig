{ self, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    {
      packages.pass = pkgs.writeShellApplication {
        name = "pass";
        runtimeInputs = [
          pkgs.passage
          pkgs.age-plugin-se
          pkgs.age-plugin-fido2-hmac
          pkgs.age-plugin-yubikey
          self.packages.${system}.pass-otp
        ];
        text = ''
          # Ensure age identity exists
          if [ ! -f ~/.passage/identities ]; then
            echo "Error: Age identity not found at ~/.passage/identities"
            echo "Please copy your age private key to ~/.passage/identities"
            exit 1
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

            # Get the password entry and pipe to pass-otp
            passage show "$pass_name" | pass-otp $clip_arg
          # Handle bulk operations and reencrypt with bulk key + SE fallback
          elif [[ "''${1:-}" == "bulk" ]] || [[ "''${1:-}" == "reencrypt" ]]; then
            if [[ "''${1:-}" == "bulk" ]]; then
              shift # Remove 'bulk' from args
            fi

            # For reencrypt, try bulk key first, fallback to SE for failures
            if [[ "''${1:-}" == "reencrypt" ]]; then
              echo "Re-encrypting with bulk key first, SE fallback for failures..."

              # First pass: try with bulk operations key
              temp_bulk_identity=$(mktemp)
              temp_se_identity=$(mktemp)
              cleanup() { rm -f "$temp_bulk_identity" "$temp_se_identity"; }
              trap cleanup EXIT

              # Extract bulk key (this requires one hardware auth)
              if passage show bulk-operations/age-key > "$temp_bulk_identity" 2>/dev/null; then
                echo "First pass: using bulk operations key..."
                PASSAGE_IDENTITIES_FILE="$temp_bulk_identity" passage reencrypt 2>/dev/null || {
                  echo "Some files failed with bulk key, retrying failed files with SE..."
                  # Re-enable SE identity for fallback
                  sed 's/^# AGE-PLUGIN-SE/AGE-PLUGIN-SE/' ~/.passage/identities > "$temp_se_identity"
                  PASSAGE_IDENTITIES_FILE="$temp_se_identity" passage reencrypt
                }
              else
                echo "Bulk key not available, using SE for all files..."
                passage reencrypt
              fi
            else
              # Regular bulk operations
              temp_identity=$(mktemp)
              trap 'rm -f "$temp_identity"' EXIT

              if passage show bulk-operations/age-key > "$temp_identity" 2>/dev/null; then
                echo "Using bulk operations key..."
                PASSAGE_IDENTITIES_FILE="$temp_identity" passage "$@"
              else
                echo "Bulk key not available, using normal identities..."
                passage "$@"
              fi
            fi
          else
            # Pass all other commands directly to passage
            passage "$@"
          fi
        '';
      };
    };
}
