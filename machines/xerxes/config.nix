{ self, pkgs, ... }:
{
  imports = [
    ../../2configs
    ../../2configs/network-manager.nix
    ../../2configs/pipewire.nix
    ../../2configs/yubikey.nix
    ../../2configs/tpm2.nix
    ../../2configs/desktops/sway/default.nix
    ../../2configs/power-action.nix
    ../../2configs/sunshine.nix
    ../../2configs/rtl-sdr.nix
    ../../2configs/browsers.nix
    ../../2configs/container-bridge.nix
    ../../2configs/android-webcam.nix
  ];
  system.stateVersion = "25.05";

  boot.tmp.cleanOnBoot = true;

  krebs.build.host = self.inputs.stockholm.kartei.hosts.xerxes;

  environment.systemPackages = [
    pkgs.bitwarden-desktop
    pkgs.rbw
    # retroarch with patched dolphin core (fixes shader compiler thread issue)
    (pkgs.retroarch.withCores (
      _cores:
      builtins.filter (c: c.pname or "" != "libretro-dolphin") pkgs.retroarch-free.cores
      ++ [ self.packages.${pkgs.system}.libretro-dolphin ]
    ))
    pkgs.pavucontrol
    pkgs.claude-code
    pkgs.ripgrep
    self.packages.${pkgs.system}.mpv
  ];

  documentation.nixos.enable = true;
  programs.steam.enable = true;

  services.ollama = {
    enable = true;
    package = pkgs.ollama-rocm;
    environmentVariables = {
      HSA_OVERRIDE_GFX_VERSION = "11.0.0"; # Radeon 890M (gfx1150/RDNA 3.5) - fallback to gfx1100
    };
  };

  # extra-container for testing declarative containers without full rebuilds
  programs.extra-container.enable = true;
}
