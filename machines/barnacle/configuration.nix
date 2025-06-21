{
  pkgs,
  self,
  lib,
  ...
}:

{
  imports = [
    self.inputs.nix-index-database.darwinModules.nix-index
    self.inputs.nix-rosetta-builder.darwinModules.default
  ];
  clan.core.networking.targetHost = "root@localhost";
  programs.nix-index-database.comma.enable = true;

  nixpkgs.hostPlatform = "aarch64-darwin";
  environment.systemPackages = [
    self.packages.${pkgs.system}.nvim
    self.packages.${pkgs.system}.pass
    self.packages.${pkgs.system}.passmenu
    self.packages.${pkgs.system}.tmux

    # zsh dependencies
    pkgs.fzf
    pkgs.atuin
    pkgs.gnupg
    pkgs.pinentry_mac
    pkgs.lazygit
    pkgs.sshuttle
    pkgs.git
    pkgs.element-desktop
    pkgs.iterm2
    (self.lib.halalify pkgs.firefox-bin-unwrapped)
    pkgs.ripgrep
    pkgs.alt-tab-macos
    pkgs.zed-editor
    pkgs.nixd
    pkgs.nil
  ];

  # Use a custom configuration.nix location.
  # $ darwin-rebuild switch -I darwin-config=$HOME/.config/nixpkgs/darwin/configuration.nix
  # environment.darwinConfig = "$HOME/.config/nixpkgs/darwin/configuration.nix";

  nix = {
    package = pkgs.nix;
    settings = {
      extra-experimental-features = [
        "nix-command"
        "flakes"
      ];
    };
  };

  # homebrew = {
  #   enable = true;
  #   casks = [
  #     "gpg-suite"
  #   ];
  # };

  # keyboard settings
  system.keyboard = {
    enableKeyMapping = true;
  };

  # Add skhd for keyboard shortcuts
  services.skhd = {
    enable = true;
    skhdConfig = ''
      # Open passmenu with Hyper-P
      ctrl + shift + alt + cmd - p : /run/current-system/sw/bin/passmenu
    '';
  };

  system.defaults = {
    # minimal dock
    dock = {
      autohide = true;
      orientation = "left";
      show-process-indicators = false;
      show-recents = false;
      static-only = true;
    };
    # a finder that tells me what I want to know and lets me work
    finder = {
      AppleShowAllExtensions = true;
      ShowPathbar = true;
      FXEnableExtensionChangeWarning = false;
    };
    # Tab between form controls and F-row that behaves as F1-F12
    NSGlobalDomain = {
      AppleKeyboardUIMode = 3;
      "com.apple.keyboard.fnState" = true;
    };
  };

  # Enable Rosetta builder for x86_64 builds
  nix-rosetta-builder = {
    enable = true;
    potentiallyInsecureExtraNixosModule = {
      # Fix DNS resolution in the VM
      networking.nameservers = [
        "8.8.8.8"
        "1.1.1.1"
      ];
    };
  };

  # Create /etc/zshrc that loads the nix-darwin environment.
  programs.zsh.enable = true; # default shell on catalina
  programs.zsh.shellInit = self.packages.${pkgs.system}.zsh.zshrc;
  programs.zsh.promptInit = ""; # Disable default prompt

  # enable sudo touch
  security.pam.services.sudo_local.touchIdAuth = true;

  # Enable Touch ID in tmux sessions with pam_reattach
  security.pam.services.sudo_local.text = lib.mkBefore ''
    auth       optional       ${pkgs.pam-reattach}/lib/pam/pam_reattach.so ignore_ssh
  '';

  # disable natural scrolling
  system.defaults.NSGlobalDomain."com.apple.swipescrolldirection" = false;
  programs.direnv.enable = true;
  programs.nix-index.enable = true;
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 6;

  system.primaryUser = "lassulus";

  services.openssh.enable = true;
  users.users.lassulus.openssh.authorizedKeys.keys = [ self.keys.ssh ];
  users.users.root.openssh.authorizedKeys.keys = [ self.keys.ssh ];

  users.users.root.shell = pkgs.zsh;
  users.users.root.uid = 0;
  users.knownUsers = [ "root" ];
}
