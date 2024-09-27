{ config, pkgs, ... }:

{
  imports = [
    ../../2configs/retiolum.nix
    ../../2configs/exim-retiolum.nix
    ../../2configs/desktops/xmonad
    ../../2configs/pipewire.nix
    ../../2configs/browsers.nix
    ../../2configs/programs.nix
    ../../2configs/network-manager.nix
    ../../2configs/syncthing.nix
    ../../2configs/games.nix
    ../../2configs/steam.nix
    ../../2configs/wine.nix
    ../../2configs/fetchWallpaper.nix
    ../../2configs/yellow-mounts/samba.nix
    ../../2configs/pass.nix
    ../../2configs/mail.nix
    ../../2configs/bitcoin.nix
    ../../2configs/review.nix
    ../../2configs/dunst.nix
    ../../2configs/print.nix
    ../../2configs/br.nix
    ../../2configs/c-base.nix
    {
      # autorandrs
      services.autorandr = {
        enable = true;
        hooks.postswitch.reset_usb = ''
          echo 0 > /sys/bus/usb/devices/usb9/authorized; echo 1 > /sys/bus/usb/devices/usb9/authorized
          ${pkgs.xorg.xmodmap}/bin/xmodmap -e 'keycode 96 = F12 Insert F12 F12' # rebind shift + F12 to shift + insert
        '';
        profiles = {
          default = {
            fingerprint = {
              eDP = "00ffffffffffff00288931000100000016200104805932780a0dc9a05747982712484c0000000101010101010101010101010101010108700088a1401360c820a300d9870000001ead4a0088a1401360c820a30020c23100001e000000fd0016480f5a1e000a202020202020000000fc0047504431303031480a2020202000cf";
            };
            config = {
              eDP = {
                enable = true;
                primary = true;
                position = "0x0";
                mode = "2560x1600";
                rate = "60.01";
              };
            };
          };
          docked2 = {
            fingerprint = {
              eDP = config.services.autorandr.profiles.default.fingerprint.eDP;
              DisplayPort-8 = "00ffffffffffff0010ac39d14c3346300f200104b5462878fb26f5af4f46a5240f5054a54b00714f8140818081c081009500b300d1c0565e00a0a0a0295030203500b9882100001a000000ff00444342375847330a2020202020000000fc0044454c4c204733323233440a20000000fd0030a5fafa41010a2020202020200181020332f149030212110490131f3f2309070783010000e200eae305c000e606050162622c6d1a0000020b30a50007622c622c5a8780a070384d4030203500b9882100001af4fb0050a0a0285008206800b9882100001a40e7006aa0a0675008209804b9882100001a6fc200a0a0a0555030203500b9882100001a000000000009";
              DisplayPort-7 = "00ffffffffffff0020a32f00010000000c190103807341780acf74a3574cb02309484c21080081c0814081800101010101010101010104740030f2705a80b0588a00501d7400001e023a801871382d40582c4500501d7400001e000000fc00484953454e53450a2020202020000000fd00324b0f451e000a2020202020200172020333714f5f5e5d01020400101113001f2021222909070715075057070083010000e200f96d030c002000183c200060010203662150b051001b304070360056005300001e011d8018711c1620582c2500c48e2100009e011d007251d01e206e285500c48e2100001800000000000000000000000000000000000000000000ea";
            };
            config = {
              DisplayPort-7 = {
                enable = true;
                position = "2560x0";
                mode = "1920x1080";
                rate = "60.00";
              };
              DisplayPort-8 = config.services.autorandr.profiles.docked1.config.DisplayPort-1;
              eDP = config.services.autorandr.profiles.docked1.config.eDP;
            };
          };
          docked1 = {
            fingerprint = {
              eDP = config.services.autorandr.profiles.default.fingerprint.eDP;
              DisplayPort-1 = "00ffffffffffff0010ac39d14c3346300f200104b5462878fb26f5af4f46a5240f5054a54b00714f8140818081c081009500b300d1c0565e00a0a0a0295030203500b9882100001a000000ff00444342375847330a2020202020000000fc0044454c4c204733323233440a20000000fd0030a5fafa41010a2020202020200181020332f149030212110490131f3f2309070783010000e200eae305c000e606050162622c6d1a0000020b30a50007622c622c000000000000000000000000000000000000f4fb0050a0a0285008206800b9882100001a40e7006aa0a0675008209804b9882100001a6fc200a0a0a0555030203500b9882100001a000000000040";
            };
            config = {
              DisplayPort-1 = {
                enable = true;
                primary = true;
                position = "0x0";
                mode = "2560x1440";
                rate = "165.08";
              };
              eDP = config.services.autorandr.profiles.default.config.eDP // {
                primary = false;
                position = "640x1440";
              };
            };
          };
          docked1_hack = {
            fingerprint = {
              eDP = config.services.autorandr.profiles.default.fingerprint.eDP;
              HDMI-A-0 = "00ffffffffffff0010ac31d14c3346300f20010380462878ea26f5af4f46a5240f5054a54b00714f8140818081c081009500b300d1c0565e00a0a0a0295030203500b9882100001a000000ff00444342375847330a2020202020000000fc0044454c4c204733323233440a20000000fd0030901ee63c000a20202020202001db020346f14d030212110113042f141f05103f2309070783010000e200ea67030c001000383c67d85dc4017888006d1a0000020b3090e607622c622ce305c000e606050162622c40e7006aa0a0675008209804b9882100001a6fc200a0a0a05550302035001d4e3100001a000000000000000000000000000000000000000000fc";
            };
            config = {
              HDMI-A-0 = {
                enable = true;
                primary = true;
                position = "0x0";
                mode = "2560x1440";
                rate = "165.08";
              };
              eDP = config.services.autorandr.profiles.default.config.eDP // {
                primary = false;
                position = "640x1440";
              };
            };
          };
        };
      };
    }
  ];

  system.stateVersion = "22.11";

  krebs.build.host = config.krebs.hosts.aergia;

  environment.systemPackages = [
    pkgs.brain
    pkgs.bank
    pkgs.l-gen-secrets
    pkgs.generate-secrets
    pkgs.nixpkgs-review
    pkgs.pipenv
    # self.inputs.clan-core.packages.${pkgs.system}.clan-cli
  ];

  programs.adb.enable = true;

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
  hardware.pulseaudio.package = pkgs.pulseaudioFull;

  nix.trustedUsers = [
    "root"
    "lass"
  ];

  services.tor = {
    enable = true;
    client.enable = true;
  };

  documentation.nixos.enable = true;
  boot.binfmt.emulatedSystems = [
    "aarch64-linux"
  ];

  boot.cleanTmpDir = true;
  programs.noisetorch.enable = true;
}
