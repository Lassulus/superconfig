{
  self,
  config,
  lib,
  pkgs,
  ...
}:
let
  stockholmPkgs = self.inputs.stockholm.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  imports = [
    ../../alacritty.nix
    ../../xdg-open.nix
    ../../yubikey.nix
    ../../pipewire.nix
    ../../themes.nix
    ../../fonts.nix
    {
      users.users.mainUser.packages = [
        pkgs.sshuttle
        self.packages.${pkgs.system}.mpv
      ];
      security.sudo.extraConfig = ''
        lass ALL= (root) NOPASSWD:SETENV: ${pkgs.sshuttle}/bin/.sshuttle-wrapped
      '';
    }
    {
      #font magic
      options.lass.fonts = {
        regular = lib.mkOption {
          type = lib.types.str;
          default = "xft:Iosevka Term SS15:style=regular";
        };
        bold = lib.mkOption {
          type = lib.types.str;
          default = "xft:Iosevka Term SS15:style=bold";
        };
        italic = lib.mkOption {
          type = lib.types.str;
          default = "xft:Iosevka Term SS15:style=italic";
        };
      };
      config.services.xserver.displayManager.sessionCommands =
        let
          xres = pkgs.writeText "xreources" ''
            *.font:       ${config.lass.fonts.regular}
            *.boldFont:   ${config.lass.fonts.bold}
            *.italicFont: ${config.lass.fonts.italic}
          '';
        in
        ''
          ${pkgs.xorg.xrdb}/bin/xrdb -merge ${xres}
        '';
    }
  ];

  users.users.mainUser.extraGroups = [
    "audio"
    "video"
  ];

  time.timeZone = "Europe/Berlin";

  programs.ssh.agentTimeout = "10m";
  programs.ssh.startAgent = false;
  services.openssh.forwardX11 = true;

  environment.systemPackages = with pkgs; [
    acpi
    acpilight
    ripgrep
    dmenu
    stockholmPkgs.fzfmenu
    dconf
    libarchive
    ncdu
    nix-index
    nixpkgs-review
    nmap
    pavucontrol
    sxiv
    nsxiv
    wirelesstools
    x11vnc
    xclip
    xorg.xmodmap
    xorg.xhost
    xdotool
    xsel
    zathura
    flameshot
    (pkgs.writers.writeDashBin "screenshot" ''
      ${pkgs.flameshot}/bin/flameshot gui
    '')
    (pkgs.writers.writeDashBin "deploy_hm" ''
      target=$1
      shift

      hm_profile=$(${pkgs.home-manager}/bin/home-manager -f ~/sync/stockholm/lass/2configs/home-manager.nix build "$@")
      nix-copy-closure --to "$target" "$hm_profile"
      ssh "$target" -- "$hm_profile"/activate
    '')
    zbar
  ];

  services.udev.extraRules = ''
    SUBSYSTEM=="backlight", ACTION=="add", \
    RUN+="${pkgs.coreutils}/bin/chgrp video /sys/class/backlight/%k/brightness", \
    RUN+="${pkgs.coreutils}/bin/chmod g+w /sys/class/backlight/%k/brightness"
  '';

  services.xserver = {
    enable = true;
    layout = "us";
    display = lib.mkForce 0;
    xkbVariant = "altgr-intl";
    xkbOptions = "caps:escape";
    libinput.enable = true;
    exportConfiguration = true;
    displayManager = {
      lightdm.enable = true;
      defaultSession = "none+xmonad";
      sessionCommands = ''
        ${pkgs.xorg.xhost}/bin/xhost +LOCAL:
      '';
    };
  };

  nixpkgs.config.packageOverrides = _super: {
    dmenu = pkgs.writers.writeDashBin "dmenu" ''
      ${stockholmPkgs.fzfmenu}/bin/fzfmenu "$@"
    '';
  };

  services.clipmenu.enable = true;

  # synchronize all the clipboards
  systemd.user.services.autocutsel = {
    enable = true;
    wantedBy = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    serviceConfig = {
      Type = "forking";
      ExecStart = pkgs.writers.writeDash "autocutsel" ''
        ${pkgs.autocutsel}/bin/autocutsel -fork -selection PRIMARY
        ${pkgs.autocutsel}/bin/autocutsel -fork -selection CLIPBOARD
      '';
    };
  };
  systemd.services.xsettingsd = {
    wantedBy = [ "multi-user.target" ];
    after = [ "display-manager.service" ];
    environment.DISPLAY = ":0";
    serviceConfig = {
      ExecStart = "${pkgs.xsettingsd}/bin/xsettingsd -c /var/theme/config/xsettings.conf";
      User = "lass";
      Restart = "always";
      RestartSec = "15s";
    };
  };
}
