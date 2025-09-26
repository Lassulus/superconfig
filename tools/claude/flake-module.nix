{ self, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    let
      # Get paths to MCP servers
      gitMcpPath = "${self.packages.${system}.git-mcp}/bin/git-mcp";
      tmuxMcpPath = "${self.packages.${system}.tmux-mcp}/bin/tmux-mcp";

      # Path to CLAUDE.md
      claudeMd = ./CLAUDE.md;
    in
    {
      packages.claude = self.wrapLib.makeWrapper {
        pkgs = pkgs;
        package = (self.lib.halalify pkgs.claude-code);
        wrapper =
          { exePath, ... }:
          ''
            set -efu
            set -x
            # Configure MCP servers using Claude CLI
            if ${exePath} mcp add git-mcp "${gitMcpPath}" 2>/dev/null && \
               ${exePath} mcp add tmux-mcp "${tmuxMcpPath}" 2>/dev/null; then
              echo "MCP servers configured successfully" >&2
            else
              echo "Warning: Could not configure MCP servers" >&2
            fi

            # Set up CLAUDE.md if it doesn't exist
            CLAUDE_MD_DIR="''${CLAUDE_MD_DIR:-$HOME/.claude}"
            mkdir -p "$CLAUDE_MD_DIR"
            if [[ ! -f "$CLAUDE_MD_DIR/CLAUDE.md" ]]; then
              cp ${claudeMd} "$CLAUDE_MD_DIR/CLAUDE.md"
            fi
            exec ${exePath} "$@"
          '';
      };
    };
}
