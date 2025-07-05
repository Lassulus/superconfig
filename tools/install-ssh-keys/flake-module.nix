{ self, ... }:
{
  perSystem =
    { pkgs, lib, ... }:
    let
      authorizedKeysFile = pkgs.writeText "authorized_keys" ''
        # SSH keys installed by install-ssh-keys tool
        # Generated from self.keys.ssh

        ${lib.concatMapStringsSep "\n" (key: key.public) (lib.attrValues self.keys.ssh)}
      '';
    in
    {
      packages.install-ssh-keys = pkgs.writeShellApplication {
        name = "install-ssh-keys";
        runtimeInputs = [ ];
        text = ''
          set -euo pipefail

          # Check if we're running as root
          if [[ $EUID -ne 0 ]]; then
              echo "Not running as root. Using sudo to install keys to /root/.ssh/authorized_keys"
              exec sudo "$0" "$@"
          fi

          # Create /root/.ssh directory if it doesn't exist
          mkdir -p /root/.ssh
          chmod 700 /root/.ssh

          # Append the authorized_keys
          cat ${authorizedKeysFile} >> /root/.ssh/authorized_keys
          chmod 600 /root/.ssh/authorized_keys

          echo "Appended SSH keys to /root/.ssh/authorized_keys: ${lib.concatStringsSep ", " (lib.attrNames self.keys.ssh)}"
        '';
      };
    };
}
