{ self, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    {
      packages.pass-otp = pkgs.writeShellApplication {
        name = "pass-otp";
        runtimeInputs = [ pkgs.passage pkgs.oath-toolkit ];
        text = ''
          # Handle OTP commands for passage-based password store
          
          show_usage() {
            echo "Usage: pass-otp [show] [--clip,-c] pass-name"
            echo "       pass-otp insert [--secret,-s] [--issuer,-i issuer] [--account,-a account] [--echo,-e] pass-name"
          }
          
          case "''${1:-}" in
            "")
              show_usage
              exit 1
              ;;
            "show")
              shift
              clip=false
              pass_name="''${1:-}"
              ;;
            "--clip"|"-c")
              shift
              clip=true
              pass_name="''${1:-}"
              
              if [[ -z "$pass_name" ]]; then
                show_usage
                exit 1
              fi
              
              # Get the OTP secret from passage
              if secret=$(passage show "$pass_name" 2>/dev/null); then
                # Extract TOTP secret (assume it's on a line starting with "otpauth://" or just the secret)
                if echo "$secret" | grep -q "otpauth://"; then
                  # Extract secret from otpauth URL
                  secret_key=$(echo "$secret" | grep "otpauth://" | sed -n 's/.*secret=\([^&]*\).*/\1/p')
                else
                  # Assume the secret is on the second line or find a base32-looking string
                  secret_key=$(echo "$secret" | tail -n +2 | head -n 1 | tr -d ' ')
                fi
                
                if [[ -n "$secret_key" ]]; then
                  otp_code=$(oathtool --totp --base32 "$secret_key")
                  if [[ "$clip" == "true" ]]; then
                    if [[ "$(uname)" == "Darwin" ]]; then
                      echo -n "$otp_code" | pbcopy
                      echo "Copied OTP code to clipboard."
                    else
                      echo -n "$otp_code" | xclip -selection clipboard
                      echo "Copied OTP code to clipboard."
                    fi
                  else
                    echo "$otp_code"
                  fi
                else
                  echo "Error: Could not extract OTP secret from $pass_name"
                  exit 1
                fi
              else
                echo "Error: Could not read password entry $pass_name"
                exit 1
              fi
              ;;
            "insert")
              shift
              echo "OTP insert not yet implemented for passage. Please add OTP secrets manually."
              exit 1
              ;;
            *)
              # Default to show
              pass_name="$1"
              if secret=$(passage show "$pass_name" 2>/dev/null); then
                if echo "$secret" | grep -q "otpauth://"; then
                  secret_key=$(echo "$secret" | grep "otpauth://" | sed -n 's/.*secret=\([^&]*\).*/\1/p')
                else
                  secret_key=$(echo "$secret" | tail -n +2 | head -n 1 | tr -d ' ')
                fi
                
                if [[ -n "$secret_key" ]]; then
                  oathtool --totp --base32 "$secret_key"
                else
                  echo "Error: Could not extract OTP secret from $pass_name"
                  exit 1
                fi
              else
                echo "Error: Could not read password entry $pass_name"
                exit 1
              fi
              ;;
          esac
        '';
      };
    };
}