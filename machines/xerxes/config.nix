{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ../../2configs/retiolum.nix
    ../../2configs/exim-retiolum.nix
    ../../2configs/baseX.nix
    ../../2configs/pipewire.nix
    ../../2configs/browsers.nix
    ../../2configs/programs.nix
    ../../2configs/network-manager.nix
    ../../2configs/syncthing.nix
    ../../2configs/sync/sync.nix
    ../../2configs/steam.nix
    ../../2configs/wine.nix
    ../../2configs/fetchWallpaper.nix
    ../../2configs/pass.nix
    ../../2configs/mail.nix
  ];

  krebs.build.host = config.krebs.hosts.xerxes;

  environment.shellAliases = {
    deploy = pkgs.writeDash "deploy" ''
      set -eu
      export SYSTEM="$1"
      $(nix-build $HOME/sync/stockholm/lass/krops.nix --no-out-link --argstr name "$SYSTEM" -A deploy)
    '';
    usb-tether-on = pkgs.writeDash "usb-tether-on" ''
      adb shell su -c service call connectivity 33 i32 1 s16 text
    '';
    usb-tether-off = pkgs.writeDash "usb-tether-off" ''
      adb shell su -c service call connectivity 33 i32 0 s16 text
    '';
  };

  services.xserver = {
    displayManager.lightdm.autoLogin.enable = true;
    displayManager.lightdm.autoLogin.user = "lass";
  };

  boot.blacklistedKernelModules = [ "xpad" ];
  systemd.services.xboxdrv = {
    wantedBy = [ "multi-user.target" ];
    script = ''
      ${
        pkgs.xboxdrv.overrideAttrs (o: {
          patches = o.patches ++ [
            (pkgs.fetchurl {
              url = "https://patch-diff.githubusercontent.com/raw/xboxdrv/xboxdrv/pull/251.patch";
              sha256 = "17784y20mxqrlhgvwvszh8lprxrvgmb7ah9dknmbhj5jhkjl8wq5";
            })
          ];
        })
      }/bin/xboxdrv --type xbox360 --dbus disabled -D
    '';
  };

  programs.adb.enable = true;

  services.logind.lidSwitch = "suspend";
  lass.screenlock.enable = lib.mkForce false;

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
  hardware.pulseaudio.package = pkgs.pulseaudioFull;
  # hardware.pulseaudio.configFile = pkgs.writeText "default.pa" ''
  #   load-module module-bluetooth-policy
  #   load-module module-bluetooth-discover
  #   ## module fails to load with
  #   ##   module-bluez5-device.c: Failed to get device path from module arguments
  #   ##   module.c: Failed to load module "module-bluez5-device" (argument: ""): initialization failed.
  #   # load-module module-bluez5-device
  #   # load-module module-bluez5-discover
  # '';
}
