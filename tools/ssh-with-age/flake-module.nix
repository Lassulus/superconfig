{ self, ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      lib = pkgs.lib;

      # Generate key entries from flake structure
      sshKeyEntries = lib.concatStringsSep "\n" (
        lib.mapAttrsToList (
          name: key:
          if key.encrypted && key.private != null then
            ''
              ["${name}"]="${key.private}"
            ''
          else
            ""
        ) self.keys.ssh
      );
    in
    {
      packages.ssh-with-age = pkgs.writeShellApplication {
        name = "ssh-with-age";
        runtimeInputs = [
          pkgs.openssh
          pkgs.age
          pkgs.age-plugin-se
          pkgs.age-plugin-yubikey
          pkgs.libfido2
        ];
        text = ''
          # SSH wrapper that tries each encrypted SSH key with the connected FIDO2 device

          # Key mapping from flake
          declare -A SSH_KEYS
          ${sshKeyEntries}

          usage() {
            echo "Usage: ssh-with-age [ssh_options...] destination"
            echo "       ssh-with-age --list-keys"
            echo "       ssh-with-age --list-devices"
            echo ""
            echo "Tries each encrypted SSH key to find one that works with the connected FIDO2 device."
            exit 1
          }

          list_keys() {
            echo "Available encrypted SSH keys:"
            for key in "''${!SSH_KEYS[@]}"; do
              echo "  $key"
            done
          }

          list_devices() {
            echo "Connected FIDO2 devices:"
            fido2-token -L
          }

          if [[ "$1" == "--list-keys" ]]; then
            list_keys
            exit 0
          fi

          if [[ "$1" == "--list-devices" ]]; then
            list_devices
            exit 0
          fi

          if [[ "$1" == "-h" || "$1" == "--help" ]]; then
            usage
          fi

          # Create temporary file for decrypted key
          temp_key=$(mktemp)
          trap 'rm -f "$temp_key"' EXIT

          # Try each encrypted SSH key
          found_key=""
          for key_name in "''${!SSH_KEYS[@]}"; do
            encrypted_key="''${SSH_KEYS[$key_name]}"
            
            if [[ ! -f "$encrypted_key" ]]; then
              continue
            fi

            echo "Trying key: $key_name..."
            
            # Try to decrypt with hardware plugins
            decrypted=false
            # Try each hardware plugin method
            if age -d -j fido2-hmac "$encrypted_key" > "$temp_key" 2>/dev/null || \
               age -d -j se "$encrypted_key" > "$temp_key" 2>/dev/null || \
               age -d -j yubikey "$encrypted_key" > "$temp_key" 2>/dev/null; then
              decrypted=true
            fi
            
            if [[ "$decrypted" == "true" ]]; then
              
              # Check if this is a FIDO2 key by looking at the key type
              if grep -q "sk-" "$temp_key"; then
                # Try to use the key with SSH agent to verify it works with connected device
                chmod 600 "$temp_key"
                
                # Test if the key works by trying ssh-add
                if SSH_ASKPASS=/bin/false ssh-add -T "$temp_key" 2>/dev/null; then
                  found_key="$key_name"
                  echo "✓ Found working key: $key_name"
                  break
                else
                  echo "  Key $key_name requires a different FIDO2 device"
                fi
              else
                echo "  Key $key_name is not a FIDO2 key"
              fi
            else
              echo "  Could not decrypt $key_name (missing age identity?)"
            fi
          done

          if [[ -z "$found_key" ]]; then
            echo "No matching SSH key found for the connected FIDO2 device." >&2
            echo "Make sure:" >&2
            echo "  1. Your FIDO2 device is connected" >&2
            echo "  2. You have the correct age identity to decrypt the keys" >&2
            echo "  3. The SSH key was generated with this FIDO2 device" >&2
            exit 1
          fi

          # Use the found key with SSH
          ssh -i "$temp_key" "$@"
        '';
      };
    };
}
