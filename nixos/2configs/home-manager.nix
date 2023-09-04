{ config, lib, pkgs, ... }: let
  vim_nix = import ./vim.nix { inherit lib pkgs; config = {}; };
in {
  programs.git = {
    enable = true;
    userName = "lassulus";
    userEmail = "lassulus@lassul.us";
    extraConfig = {
      rebase.autostash = true;
    };
  };

  home.packages = [
    (pkgs.writers.writeDashBin "vim" ''
      ${vim_nix.environment.etc.vim.source}/bin/vim -u ${vim_nix.environment.etc.vimrc.source} "$@"
    '')
    pkgs.mosh
    pkgs.direnv
  ];

  programs.home-manager.enable = true;
}
