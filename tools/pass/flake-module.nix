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
            pass-otp "$@"
          else
            # Pass all other commands directly to passage
            passage "$@"
          fi
        '';
      };
    };
}
