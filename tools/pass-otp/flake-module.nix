{ ... }:
{
  perSystem =
    { pkgs, lib, ... }:
    {
      packages.pass-otp = pkgs.writeShellApplication {
        name = "pass-otp";
        runtimeInputs = [
          pkgs.oath-toolkit
        ]
        ++ lib.optionals (!pkgs.stdenv.isDarwin) [
          pkgs.xclip
          pkgs.wl-clipboard
        ];
        text = ''
          set -euo pipefail
          # Tool-agnostic OTP generator that accepts secret via stdin or args

          show_usage() {
            echo "Usage: pass-otp [--clip,-c] <secret>"
            echo "       echo <secret> | pass-otp [--clip,-c]"
            echo ""
            echo "Accepts OTP secret as argument or via stdin"
            echo "Secret can be:"
            echo "  - Raw base32 secret"
            echo "  - otpauth:// URL"
            echo "  - Multi-line text with secret on line 2+"
          }

          clip=false
          secret_input=""

          # Parse arguments
          while [[ $# -gt 0 ]]; do
            case "$1" in
              "--clip"|"-c")
                clip=true
                shift
                ;;
              "--help"|"-h")
                show_usage
                exit 0
                ;;
              *)
                secret_input="$1"
                shift
                ;;
            esac
          done

          # If no argument provided, read from stdin
          if [[ -z "$secret_input" ]]; then
            secret_input=$(cat)
          fi

          if [[ -z "$secret_input" ]]; then
            echo "Error: No OTP secret provided"
            show_usage
            exit 1
          fi

          # Extract TOTP secret from input
          if echo "$secret_input" | grep -q "^otpauth://"; then
            # Extract secret from otpauth URL
            secret_key=$(echo "$secret_input" | sed -n 's/.*secret=\([^&]*\).*/\1/p')
          elif echo "$secret_input" | wc -l | grep -q "^1$"; then
            # Single line - assume it's the raw secret
            secret_key=$(echo "$secret_input" | tr -d ' ')
          else
            # Multi-line - assume secret is on line 2 or later
            secret_key=$(echo "$secret_input" | tail -n +2 | head -n 1 | tr -d ' ')
          fi

          if [[ -z "$secret_key" ]]; then
            echo "Error: Could not extract OTP secret from input"
            exit 1
          fi

          # Generate OTP code
          otp_code=$(oathtool --totp --base32 "$secret_key")

          # Output or copy to clipboard
          if [[ "$clip" == "true" ]]; then
            if [[ "$(uname)" == "Darwin" ]]; then
              echo -n "$otp_code" | pbcopy
              echo "Copied OTP code to clipboard."
            elif [[ -n "''${WAYLAND_DISPLAY:-}" ]] && command -v wl-copy >/dev/null 2>&1; then
              echo -n "$otp_code" | wl-copy
              echo "Copied OTP code to clipboard (Wayland)."
            elif [[ -n "''${DISPLAY:-}" ]] && command -v xclip >/dev/null 2>&1; then
              echo -n "$otp_code" | xclip -selection clipboard
              echo "Copied OTP code to clipboard (X11)."
            else
              echo "Error: No clipboard tool found (tried pbcopy, wl-copy, xclip)"
              echo "$otp_code"
              exit 1
            fi
          else
            echo "$otp_code"
          fi
        '';
      };
    };
}
