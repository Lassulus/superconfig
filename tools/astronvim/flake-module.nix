{ inputs , ...  }:
{
  perSystem = { system, lib, pkgs, ... }: let
    nvim-appname = "lassvim";

    lsp-packages = with pkgs; [
      nodejs # copilot
      terraform-ls
      nodePackages.pyright
    
      # based on ./suggested-pkgs.json
      gopls
      golangci-lint
      nodePackages.bash-language-server
      taplo-lsp
      marksman
      selene
      rust-analyzer
      yaml-language-server
      nil
      shellcheck
      shfmt
      ruff
      ruff-lsp
      nixfmt-rfc-style
      terraform-ls
      clang-tools
      nodePackages.prettier
      stylua
      # based on https://github.com/ray-x/go.nvim#go-binaries-install-and-update
      go
      gofumpt
      gomodifytags
      gotools
      delve
      golines
      gomodifytags
      gotests
      iferr
      impl
      reftools
      ginkgo
      richgo
      govulncheck
    
      #ocaml-ng.ocamlPackages_5_0.ocaml-lsp
      #ocaml-ng.ocamlPackages_5_0.ocamlformat
      # does not build yet on aarch64
    ] ++ lib.optional (pkgs.stdenv.hostPlatform.system == "x86_64-linux") pkgs.deno
    ++ lib.optional (!pkgs.stdenv.hostPlatform.isDarwin) sumneko-lua-language-server;

    lspEnv = pkgs.buildEnv {
      name = "lspEnv";
      paths = lsp-packages;
    };

    treesitter-grammars = pkgs.runCommand "treesitter-grammars" { } (
      lib.concatMapStringsSep "\n" (grammar: ''
        mkdir -p $out
        ln -s $(readlink -f ${grammar}/parser/*.so) $out/${lib.last (builtins.split "-" grammar.name)}.so
      '') pkgs.vimPlugins.nvim-treesitter.withAllGrammars.dependencies
    );

  in {
    packages.vim = pkgs.writeShellScriptBin "vim" ''
      set -efux
      unset VIMINIT
      export PATH=${lspEnv}/bin:$PATH
      export NVIM_APPNAME=${nvim-appname}

      XDG_CONFIG_HOME=''${XDG_CONFIG_HOME:-$HOME/.config}
      XDG_DATA_HOME=''${XDG_DATA_HOME:-$HOME/.local/share}

      mkdir -p "$XDG_CONFIG_HOME/$NVIM_APPNAME" "$XDG_DATA_HOME"
      chmod -R u+w "$XDG_CONFIG_HOME/$NVIM_APPNAME"
      rm -rf "$XDG_CONFIG_HOME/$NVIM_APPNAME"
      ${pkgs.coreutils}/bin/cp -arfT '${./config}'/ "$XDG_CONFIG_HOME/$NVIM_APPNAME"
      chmod -R u+w "$XDG_CONFIG_HOME/$NVIM_APPNAME"
      ${pkgs.neovim}/bin/nvim --headless -c 'quitall' # install plugins
      mkdir -p "$XDG_DATA_HOME/$NVIM_APPNAME/lib/" "$XDG_DATA_HOME/$NVIM_APPNAME/site/"
      ${pkgs.coreutils}/bin/ln -sfT "${pkgs.vimPlugins.telescope-fzf-native-nvim}/build/libfzf.so" "$XDG_DATA_HOME/$NVIM_APPNAME/lib/libfzf.so"
      ${pkgs.coreutils}/bin/ln -sfT "${treesitter-grammars}" "$XDG_DATA_HOME/$NVIM_APPNAME/site/parser"
      exec ${pkgs.neovim}/bin/nvim "$@"
    '';
  };
}
