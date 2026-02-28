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
    ../../2configs/radicle.nix
    ../../2configs/steam.nix
    ../../2configs/auto-timezone.nix
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
    self.packages.${pkgs.system}.s
    pkgs.gh
  ];

  documentation.nixos.enable = true;
  lass.workspace-manager.enable = true;

  services.ollama =
    let
      gpuTargets = [ "gfx1100" ]; # Radeon 890M (gfx1150/RDNA 3.5) - only build for fallback target
      customRocblas = pkgs.rocmPackages.rocblas.override {
        withHipBlasLt = false; # hipblaslt takes extremely long to build; rocblas's own Tensile kernels work fine
        inherit gpuTargets;
      };
      customRocsparse = pkgs.rocmPackages.rocsparse.override {
        inherit gpuTargets;
      };
      customRocsolver = pkgs.rocmPackages.rocsolver.override {
        inherit gpuTargets;
        rocblas = customRocblas;
        rocsparse = customRocsparse;
      };
      customHipblas = pkgs.rocmPackages.hipblas.override {
        rocblas = customRocblas;
        rocsolver = customRocsolver;
        rocsparse = customRocsparse;
      };
      customRocmPackages = pkgs.rocmPackages // {
        rocblas = customRocblas;
        hipblas = customHipblas;
        rocsolver = customRocsolver;
        rocsparse = customRocsparse;
      };
    in
    {
      enable = true;
      package = pkgs.ollama-rocm.override {
        rocmGpuTargets = gpuTargets;
        rocmPackages = customRocmPackages;
      };
      environmentVariables = {
        HSA_OVERRIDE_GFX_VERSION = "11.0.0"; # Radeon 890M (gfx1150/RDNA 3.5) - fallback to gfx1100
        OLLAMA_NUM_CTX = "16384"; # 48 GiB RAM shared with GPU; 32k OOMs with 32B model
      };
    };

  # extra-container for testing declarative containers without full rebuilds
  programs.extra-container.enable = true;

  nix.settings.trusted-users = [ "root" "lass" ];

  systemd.services.nix-daemon.environment.SSH_AUTH_SOCK = "/run/user/1000/ssh-tpm-agent.sock";
}
