{ inputs , ...  }:
{
  perSystem = { system, lib, pkgs, ... }: let
    vim_appname = "lassvim";
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

      ${lib.concatMapStringsSep "\n" (name: ''
        ln -s ${pkgs.tree-sitter.builtGrammars."tree-sitter-${name}"}/parser $out/parser/${name}.so
      '') langs}
    '';
    # https://github.com/kmarius/jsregexp
    jsregexp = pkgs.stdenv.mkDerivation {
      name = "jsregexp";
      src = pkgs.fetchFromGitHub {
        owner = "kmarius";
        repo = "jsregexp";
        rev = "1f4fa8ff9570501230d88133537776869d333f12";
        sha256 = "sha256-vE2N1VKaEBeJ8IHuP+n0MwIzmkpgh/Ak50nWJUVqfgM=";
      };
      buildInputs = [ pkgs.luajit ];
      installPhase = ''
        runHook preInstall
        install -m755 -D jsregexp.so $out/lib/jsregexp.so
        runHook postInstall
      '';
    };
  in {
    packages.vim = pkgs.writeShellScriptBin "vim" ''
      set -efux
      unset VIMINIT
      export PATH=$PATH:${pkgs.buildEnv {
        name = "nvim_deps";
        paths = nvim_deps;
      }}/bin
      export NVIM_APPNAME=${vim_appname}
      mkdir -p $HOME/.config $HOME/.data/
      nvim --headless -c 'quitall'

      ln -sfT ${nvim_config} "$HOME"/.config/${vim_appname}
      if [[ -d $HOME/.data/lvim/lazy/telescope-fzf-native.nvim ]]; then
        mkdir -p "$HOME/.data/lvim/lazy/telescope-fzf-native.nvim/build"
        ln -sf "${pkgs.vimPlugins.telescope-fzf-native-nvim}/build/libfzf.so" "$HOME/.data/lvim/lazy/telescope-fzf-native.nvim/build/libfzf.so"
      fi
      if [[ -d $HOME/.data/lvim/lazy/LuaSnip/deps/jsregexp ]]; then
        ln -sf "${jsregexp}/lib/jsregexp.so" "$HOME/.data/lvim/lazy/LuaSnip/deps/jsregexp/jsregexp.so"
      fi

      exec nvim "$@"
    '';
  };
}
