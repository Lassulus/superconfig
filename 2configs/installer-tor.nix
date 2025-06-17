{
  lib,
  pkgs,
  modulesPath,
  ...
}:

{
  imports = [
    # Import the images.nix module to enable image building
    (modulesPath + "/image/images.nix")

    # Include your Tor SSH configuration
    ./tor-ssh.nix
  ];

  # Enable SSH in the installer
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "yes";
      PasswordAuthentication = true;
    };
  };

  # Set a default root password for the installer
  users.users.root.initialPassword = "nixos";

  # Ensure Tor starts automatically
  systemd.services.tor = {
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
  };

  # Add a script to display the Tor hostname
  environment.systemPackages = with pkgs; [
    (writeScriptBin "show-tor-address" ''
      #!${pkgs.bash}/bin/bash
      echo "Waiting for Tor hidden service to be created..."
      while [ ! -f /var/lib/tor/onion/ssh/hostname ]; do
        sleep 1
      done
      echo ""
      echo "==============================================="
      echo "SSH is available via Tor at:"
      echo ""
      cat /var/lib/tor/onion/ssh/hostname
      echo ""
      echo "To connect from another machine:"
      echo "torify ssh root@$(cat /var/lib/tor/onion/ssh/hostname)"
      echo "==============================================="
      echo ""
    '')
  ];

  # Add message to installer greeting
  services.getty.helpLine = lib.mkAfter ''

    >>> To see the Tor hidden service address for SSH, run: show-tor-address
    >>> Default root password is: nixos
  '';

  # Automatically show Tor address on login
  programs.bash.loginShellInit = ''
    if [ -f /var/lib/tor/onion/ssh/hostname ]; then
      show-tor-address
    fi
  '';
}
