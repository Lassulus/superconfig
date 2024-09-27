{ inputs, ... }:
{
  imports = [ inputs.treefmt-nix.flakeModule ];
  perSystem =
    { pkgs, ... }:
    {
      treefmt.projectRootFile = ".git/config";
      treefmt.programs.shellcheck.enable = true;

      treefmt.programs.nixfmt.enable = true;
      treefmt.programs.nixfmt.package = pkgs.nixfmt-rfc-style;
      treefmt.programs.deadnix.enable = true;
      treefmt.settings.global.excludes = [
        "*.png"
        "*.jpeg"
        "*.gitignore"
        ".vscode/*"
        "*.toml"
        "*.clan-flake"
        "*.code-workspace"
        "*.pub"
        "*.typed"
        "*.age"
        "*.list"
        "*.desktop"
      ];
      treefmt.programs.prettier = {
        enable = true;
        includes = [
          "*.cjs"
          "*.css"
          "*.html"
          "*.js"
          "*.json5"
          "*.jsx"
          "*.mdx"
          "*.mjs"
          "*.scss"
          "*.ts"
          "*.tsx"
          "*.vue"
          "*.yaml"
          "*.yml"
        ];
      };
    };
}
