{ self, inputs, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    let
      claude = inputs.wrappers.lib.wrapModule {
        imports = [ self.wrapperModules.claude-code ];
        inherit pkgs;

        claudeMd = ./CLAUDE.md;

        mcpServers = {
          git-mcp = {
            command = "${self.packages.${system}.git-mcp}/bin/git-mcp";
          };
          tmux-mcp = {
            command = "${self.packages.${system}.tmux-mcp}/bin/tmux-mcp";
          };
        };

        # Seed permission rules from the same set we trust in pi.
        permissions = {
          allow = [
            "Bash(nix build:*)"
            "Bash(nix eval:*)"
            "Bash(nix fmt:*)"
          ];
        };
      };
    in
    {
      packages.claude = claude.wrapper;
    };
}
