{
  self,
  config,
  pkgs,
  ...
}:

{
  imports = [
    ../../2configs
    ../../2configs/retiolum.nix
    # ../../2configs/baseX.nix
    ../../2configs/desktops/sway/default.nix
    self.wrapperModules.workspace-manager
    # ../../2configs/desktops/xmonad
    ../../2configs/power-action.nix
    ../../2configs/yubikey.nix
    ../../2configs/pipewire.nix
    ../../2configs/udisks.nix
    ../../2configs/browsers.nix
    ../../2configs/network-manager.nix
    ../../2configs/syncthing.nix
    # ../../2configs/games.nix
    ../../2configs/steam.nix
    # ../../2configs/wine.nix
    ../../2configs/yellow-mounts/samba.nix
    ../../2configs/pass.nix
    ../../2configs/mail.nix
    ../../2configs/printing
    ../../2configs/auto-timezone.nix
    # ../../2configs/bitcoin.nix
    ../../2configs/review.nix
    ../../2configs/dunst.nix
    ../../2configs/yggdrasil.nix
    ../../2configs/container-tests.nix
    # ../../2configs/sunshine.nix
    # ../../2configs/br.nix
    # ../../2configs/c-base.nix
  ];

  system.stateVersion = "23.11";

  krebs.build.host = config.krebs.hosts.ignavia;

  nix.settings.trusted-users = [
    "root"
    "lass"
  ];

  services.tor = {
    enable = true;
    client.enable = true;
  };

  lass.workspace-manager.enable = true;

  # Suspend on power button press instead of shutting down.
  services.logind.settings.Login.HandlePowerKey = "suspend";

  # Auto-GC during builds when store free space drops below 10 GB,
  # freeing down to 20 GB free. (gc.automatic is off for ignavia.)
  nix.settings.min-free = 10240 * 1024 * 1024;
  nix.settings.max-free = 20480 * 1024 * 1024;

  # Framework 13 panel (2256x1504). wlroots' HiDPI heuristic auto-picks
  # scale 2 on every sway start, which is far too large. Pin the internal
  # panel to 1.0; external outputs keep sway's default.
  environment.etc."sway/config.d/scale.conf".text = ''
    output eDP-1 scale 1
  '';

  documentation.nixos.enable = true;
  boot.binfmt.emulatedSystems = [
    "aarch64-linux"
  ];

  boot.tmp.cleanOnBoot = true;
  programs.noisetorch.enable = true;

  environment.systemPackages = [
    pkgs.android-tools
    pkgs.gh
    self.packages.${pkgs.system}.bank
    pkgs.mycelium
    pkgs.tmate
    pkgs.rbw
  ];

  krebs.hosts.styx.nets.retiolum.tinc.extraConfig = "Address = 10.42.0.1 655";

  virtualisation.podman.enable = true;

  hardware.keyboard.qmk.enable = true;
  hardware.xpadneo.enable = true;
  hardware.bluetooth.settings.General = {
    # Xbox Wireless Controllers fail LE authentication without these:
    # JustWorksRepairing lets bluez accept fresh pairings without manual remove,
    # Privacy = device makes the host use a static address so the controller's
    # bond key doesn't get invalidated by RPA rotation.
    JustWorksRepairing = "always";
    Privacy = "device";
  };

  users.users.mainUser.extraGroups = [ "wireshark" ];
  programs.wireshark.enable = true;
  programs.wireshark.package = pkgs.wireshark-qt;

  services.udev.packages = [ pkgs.libmtp.out ];

}
