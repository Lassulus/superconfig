{ inputs , ...  }:
{
  perSystem = { system, lib, pkgs, ... }: let
    langs = [
      # "agda"
      "bash"
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
      mkdir -p $out/nvim/parser

      ln -s ${inputs.astro-nvim}/* $out/nvim/
      rm $out/nvim/lua
      mkdir -p $out/nvim/lua
      ln -s ${inputs.astro-nvim}/lua/* $out/nvim/lua
      ln -s ${./user} $out/nvim/lua/user

      ${lib.concatMapStringsSep "\n" (name: ''
        ln -s ${pkgs.tree-sitter.builtGrammars."tree-sitter-${name}"}/parser $out/nvim/parser/${name}.so
      '') langs}
    '';
  in {
    packages.asvim = pkgs.writers.writeDashBin "asvim" ''
      unset VIMINIT
      export PATH=$PATH:${lib.makeBinPath nvim_deps}
      XDG_CONFIG_HOME=${nvim_config} ${pkgs.neovim}/bin/nvim "$@"
    '';
  };
}
