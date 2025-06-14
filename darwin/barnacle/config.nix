{ pkgs, self, ... }:

{
  imports = [
    # ./rosetta.nix
    self.inputs.nix-index-database.darwinModules.nix-index
  ];
  programs.nix-index-database.comma.enable = true;

  nixpkgs.hostPlatform = "aarch64-darwin";
  environment.systemPackages = [
    self.packages.${pkgs.system}.nvim
    self.packages.${pkgs.system}.pass
    self.packages.${pkgs.system}.passmenu

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
    (pkgs.firefox-devedition-bin-unwrapped.overrideAttrs (o: {
      meta = o.meta // {
        license = pkgs.lib.licenses.free;
      };
    }))
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

  nix.linux-builder.enable = true;
  nix.linux-builder.supportedFeatures = [
    "benchmark"
    "big-parallel"
    "kvm"
    "nixos-test"
    "uid-range"
  ];
  nix.linux-builder.config = {
    imports = [
     ../../2configs/container-tests.nix
    ];
  };

  # Create /etc/zshrc that loads the nix-darwin environment.
  programs.zsh.enable = true; # default shell on catalina
  programs.zsh.shellInit = self.packages.${pkgs.system}.zsh.zshrc;

  # enable sudo touch
  security.pam.services.sudo_local.touchIdAuth = true;

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
  # enable ssh in the macos system settings:
  # apple -> system settings -> general -> sharing -> remote login
  users.users.lassulus.openssh.authorizedKeys.keys = [
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDIb3uuMqE/xSJ7WL/XpJ6QOj4aSmh0Ga+GtmJl3CDvljGuIeGCKh7YAoqZAi051k5j6ZWowDrcWYHIOU+h0eZCesgCf+CvunlXeUz6XShVMjyZo87f2JPs2Hpb+u/ieLx4wGQvo/Zw89pOly/vqpaX9ZwyIR+U81IAVrHIhqmrTitp+2FwggtaY4FtD6WIyf1hPtrrDecX8iDhnHHuGhATr8etMLwdwQ2kIBx5BBgCoiuW7wXnLUBBVYeO3II957XP/yU82c+DjSVJtejODmRAM/3rk+B7pdF5ShRVVFyB6JJR+Qd1g8iSH+2QXLUy3NM2LN5u5p2oTjUOzoEPWZo7lykZzmIWd/5hjTW9YiHC+A8xsCxQqs87D9HK9hLA6udZ6CGkq4hG/6wFwNjSMnv30IcHZzx6IBihNGbrisrJhLxEiKWpMKYgeemhIirefXA6UxVfiwHg3gJ8BlEBsj0tl/HVARifR2y336YINEn8AsHGhwrPTBFOnBTmfA/VnP1NlWHzXCfVimP6YVvdoGCCnAwvFuJ+ZuxmZ3UzBb2TenZZOzwzV0sUzZk0D1CaSBFJUU3oZNOkDIM6z5lIZgzsyKwb38S8Vs3HYE+Dqpkfsl4yeU5ldc6DwrlVwuSIa4vVus4eWD3gDGFrx98yaqOx17pc4CC9KXk/2TjtJY5xmQ== lass@yubikey"
  ];
}
