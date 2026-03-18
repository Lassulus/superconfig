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

  # llama-swap: on-demand model hot-swapping proxy for llama.cpp
  # Models are stored in /data/models/ as GGUF files
  services.llama-swap =
    let
      llama-server = "${pkgs.llama-cpp-rocm}/bin/llama-server";
    in
    {
      enable = true;
      port = 11434;
      settings = {
        healthCheckTimeout = 300;
        models = {
          qwen3-32b = {
            cmd = "${llama-server} --port \${PORT} --model /data/models/qwen3-32b.gguf --ctx-size 16384 --jinja";
            ttl = 300;
          };
          qwen-coder-next = {
            cmd = "${llama-server} --port \${PORT} --model /data/models/Qwen3-Coder-Next-Q4_K_M/Qwen3-Coder-Next-Q4_K_M-00001-of-00004.gguf --ctx-size 16384 --jinja";
            ttl = 300;
          };
        };
      };
    };
  # ROCm GPU access and environment for llama-swap spawned llama-server processes
  systemd.services.llama-swap.environment.HSA_OVERRIDE_GFX_VERSION = "11.0.0"; # Radeon 890M (gfx1150/RDNA 3.5) - fallback to gfx1100
  systemd.services.llama-swap.serviceConfig.SupplementaryGroups = [
    "render"
    "video"
  ];

  # extra-container for testing declarative containers without full rebuilds
  programs.extra-container.enable = true;

  nix.settings.trusted-users = [
    "root"
    "lass"
  ];

  systemd.services.nix-daemon.environment.SSH_AUTH_SOCK = "/run/user/1000/ssh-tpm-agent.sock";
}
