{ ... }:
{
  perSystem =
    {
      system,
      lib,
      pkgs,
      ...
    }:
    let
      nvim-appname = "lassvim";

      lsp-packages =
        with pkgs;
        [
          nodejs # copilot
          terraform-ls
          pyright

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
        ]
        ++ lib.optional (pkgs.stdenv.hostPlatform.system == "x86_64-linux") pkgs.deno
        ++ lib.optional (!pkgs.stdenv.hostPlatform.isDarwin) sumneko-lua-language-server;

      lspEnv = pkgs.buildEnv {
        name = "lspEnv";
        paths = lsp-packages;
      };

      treesitter-grammars =
        let
          grammars = lib.filterAttrs (
            n: _: lib.hasPrefix "tree-sitter-" n
          ) pkgs.vimPlugins.nvim-treesitter.builtGrammars;
          symlinks = lib.mapAttrsToList (
            name: grammar: "ln -s ${grammar}/parser $out/${lib.removePrefix "tree-sitter-" name}.so"
          ) grammars;
        in
        (pkgs.runCommand "treesitter-grammars" { } ''
          mkdir -p $out
          ${lib.concatStringsSep "\n" symlinks}
        '').overrideAttrs
          (_: {
            passthru.rev = pkgs.vimPlugins.nvim-treesitter.src.rev;
          });

    in
    {
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
        echo "${treesitter-grammars.rev}" > "$XDG_CONFIG_HOME/$NVIM_APPNAME/treesitter-rev"

        ${pkgs.neovim}/bin/nvim --headless -c 'quitall' # install plugins
        mkdir -p "$XDG_DATA_HOME/$NVIM_APPNAME/lib/" "$XDG_DATA_HOME/$NVIM_APPNAME/site/"
        ${pkgs.coreutils}/bin/ln -sfT "${pkgs.vimPlugins.telescope-fzf-native-nvim}/build/libfzf.so" "$XDG_DATA_HOME/$NVIM_APPNAME/lib/libfzf.so"
        ${pkgs.coreutils}/bin/ln -sfT "${treesitter-grammars}" "$XDG_DATA_HOME/$NVIM_APPNAME/site/parser"
        exec ${pkgs.neovim}/bin/nvim "$@"
      '';
    };
}
