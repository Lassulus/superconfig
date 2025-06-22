{ self, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    let
      # Get paths to MCP servers
      gitMcpPath = "${self.packages.${system}.git-mcp}/bin/git-mcp";
      tmuxMcpPath = "${self.packages.${system}.tmux-mcp}/bin/tmux-mcp";

      # Claude configuration
      claudeConfig = pkgs.writeText "claude-config.json" (builtins.toJSON {
        mcpServers = {
          "git-mcp" = {
            command = gitMcpPath;
            args = [];
          };
          "tmux-mcp" = {
            command = tmuxMcpPath;
            args = [];
          };
        };
      });

      # Path to CLAUDE.md
      claudeMd = ./CLAUDE.md;
    in
    {
      packages.claude = self.libWithPkgs.${system}.makeWrapper pkgs.claude {
        preHook = ''
          # Set up Claude config directory
          export CLAUDE_CONFIG_DIR="$HOME/Library/Application Support/Claude"
          mkdir -p "$CLAUDE_CONFIG_DIR"

          # Copy our config to Claude's config location
          cp ${claudeConfig} "$CLAUDE_CONFIG_DIR/claude_desktop_config.json"

          # Set up CLAUDE.md if it doesn't exist
          CLAUDE_MD_DIR="''${CLAUDE_MD_DIR:-$HOME/.claude}"
          mkdir -p "$CLAUDE_MD_DIR"
          if [[ ! -f "$CLAUDE_MD_DIR/CLAUDE.md" ]]; then
            cp ${claudeMd} "$CLAUDE_MD_DIR/CLAUDE.md"
          fi
        '';
      };
    };
}