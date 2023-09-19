{ inputs , ...  }:
{
  perSystem = { system, lib, pkgs, ... }: let
    vim_appname = "lassvim";
    nvim_deps = with pkgs; [
      nodejs # copilot
      neovim
      vale
      terraform-ls
      nodePackages.pyright
      sumneko-lua-language-server

      # based on ./suggested-pkgs.json nvim
      delve
      gopls
      golangci-lint
      nodePackages.bash-language-server
      taplo-lsp
      marksman
      rust-analyzer
      yaml-language-server
      nil
      gomodifytags
      gofumpt
      iferr
      impl
      gotools
      shellcheck
      shfmt
      isort
      black
      ruff
      nixpkgs-fmt
      terraform-ls
      clang-tools
      nodePackages.prettier
      stylua
      # does not build yet on aarch64
    ] ++ lib.optional (pkgs.stdenv.hostPlatform.system == "x86_64-linux") pkgs.deno; # lsp
    nvim_config = pkgs.runCommand "nvim_config" { } ''
      mkdir -p $out/parser

      ln -s ${inputs.astro-nvim}/* $out/
      rm $out/lua
      mkdir -p $out/lua
      ln -s ${inputs.astro-nvim}/lua/* $out/lua
      ln -s ${./user} $out/lua/user

      ${lib.concatMapStringsSep "\n" (grammar: ''
        ln -s $(readlink -f ${grammar}/parser/*.so) $out/parser/${lib.last (builtins.split "-" grammar.name)}.so
      '') pkgs.vimPlugins.nvim-treesitter.withAllGrammars.dependencies}
    '';
  in {
    packages.vim = pkgs.writeShellScriptBin "vim" ''
      set -efux
      unset VIMINIT
      export PATH=$PATH:${pkgs.buildEnv {
        name = "nvim_deps";
        paths = nvim_deps;
      }}/bin
      export NVIM_APPNAME=${vim_appname}
      mkdir -p $HOME/.config $HOME/.local/share/
      ln -sfT ${nvim_config} "$HOME"/.config/${vim_appname}
      nvim --headless -c 'quitall'
      if [[ -d $HOME/.local/share/lassvim/lazy/telescope-fzf-native.nvim ]]; then
        mkdir -p "$HOME/.local/share/lassvim/vim/lazy/telescope-fzf-native.nvim/build"
        ln -sf "${pkgs.vimPlugins.telescope-fzf-native-nvim}/build/libfzf.so" "$HOME/.local/share/lassvim/lazy/telescope-fzf-native.nvim/build/libfzf.so"
      fi
      exec nvim "$@"
    '';
  };
}
