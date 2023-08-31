{ inputs , ...  }:
{
  perSystem = { system, lib, pkgs, ... }: let
    langs = [
      # "agda"
      # "bash" # throws an error
      "c"
      "c-sharp"
      "cpp"
      "css"
      "elm"
      "elisp"
      #"fluent"
      "go"
      "hcl"
      "haskell"
      "html"
      "janet-simple"
      "java"
      "javascript"
      "jsdoc"
      "json"
      "julia"
      "ocaml"
      "pgn"
      "php"
      "python"
      "ruby"
      "rust"
      "scala"
      # "swift"
      "typescript"
      "yaml"
      "nix"
      "lua"
      "markdown-inline"
      "perl"
      "make"
      "toml"
    ];
    nvim_deps = with pkgs; [
      nodejs # copilot
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

      ${lib.concatMapStringsSep "\n" (name: ''
        ln -s ${pkgs.tree-sitter.builtGrammars."tree-sitter-${name}"}/parser $out/parser/${name}.so
      '') langs}
    '';
  in {
    packages.asvim = pkgs.writers.writeDashBin "asvim" ''
      set -efux
      unset VIMINIT
      export PATH=$PATH:${lib.makeBinPath nvim_deps}
      ln -sfT ${nvim_config} "$HOME"/.config/lvim
      NVIM_APPNAME=lvim ${pkgs.neovim}/bin/nvim "$@"
    '';
  };
}
