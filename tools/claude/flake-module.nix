{ self, inputs, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    let
      claude = inputs.wrappers.lib.wrapModule {
        imports = [ self.wrapperModules.claude-code ];
        inherit pkgs;

        package = self.lib.halalify self.legacyPackages.${system}.llm.claude-code;

        claudeMd = ./CLAUDE.md;

        mcpServers = {
          git-mcp = {
            command = "${self.packages.${system}.git-mcp}/bin/git-mcp";
          };
        };

        skills = {
          hedgedoc = "${self.legacyPackages.${system}.skills.hedgedoc}/share/hedgedoc";
          notify = "${self.legacyPackages.${system}.skills.notify}/share/notify";
          reverse-engineering = "${
            self.legacyPackages.${system}.skills.reverse-engineering
          }/share/reverse-engineering";
          tmux = "${self.legacyPackages.${system}.skills.tmux}/share/tmux";
          websearch = "${self.legacyPackages.${system}.skills.websearch}/share/websearch";
        };

        permissions = {
          defaultMode = "auto";
          allow = [
            # nix operations
            "Bash(nix build:*)"
            "Bash(nix eval:*)"
            "Bash(nix fmt:*)"
            "Bash(nix flake:*)"
            "Bash(nix develop:*)"
            "Bash(nix run:*)"
            "Bash(nix search:*)"
            "Bash(nix log:*)"
            "Bash(nix path-info:*)"
            "Bash(nix store:*)"
            "Bash(nix derivation:*)"
            "Bash(nix hash:*)"
            "Bash(nix-build:*)"
            "Bash(nix-instantiate:*)"
            "Bash(nix-locate:*)"
            "Bash(nix-prefetch-url:*)"
            "Bash(nixos-rebuild:*)"
            "Bash(darwin-rebuild:*)"
            # clan
            "Bash(clan:*)"
            # git read operations
            "Bash(git status:*)"
            "Bash(git diff:*)"
            "Bash(git log:*)"
            "Bash(git show:*)"
            "Bash(git branch:*)"
            "Bash(git remote:*)"
            "Bash(git stash list:*)"
            "Bash(git rev-parse:*)"
            "Bash(git describe:*)"
            "Bash(git tag:*)"
            "Bash(git ls-files:*)"
            "Bash(git ls-remote:*)"
            # git write operations
            "Bash(git add:*)"
            "Bash(git commit:*)"
            "Bash(git checkout:*)"
            "Bash(git switch:*)"
            "Bash(git merge:*)"
            "Bash(git rebase:*)"
            "Bash(git stash:*)"
            "Bash(git cherry-pick:*)"
            "Bash(git fetch:*)"
            "Bash(git pull:*)"
            # common read-only tools
            "Bash(cat:*)"
            "Bash(ls:*)"
            "Bash(find:*)"
            "Bash(grep:*)"
            "Bash(rg:*)"
            "Bash(fd:*)"
            "Bash(head:*)"
            "Bash(tail:*)"
            "Bash(wc:*)"
            "Bash(sort:*)"
            "Bash(uniq:*)"
            "Bash(jq:*)"
            "Bash(tree:*)"
            "Bash(file:*)"
            "Bash(which:*)"
            "Bash(realpath:*)"
            "Bash(readlink:*)"
            "Bash(dirname:*)"
            "Bash(basename:*)"
            "Bash(stat:*)"
            "Bash(du:*)"
            "Bash(df:*)"
            "Bash(env:*)"
            "Bash(echo:*)"
            "Bash(printf:*)"
            "Bash(test:*)"
            "Bash(tr:*)"
            "Bash(sed:*)"
            "Bash(awk:*)"
            "Bash(cut:*)"
            "Bash(diff:*)"
            "Bash(tee:*)"
            "Bash(xargs:*)"
            "Bash(mkdir:*)"
            "Bash(cp:*)"
            "Bash(mv:*)"
            "Bash(touch:*)"
            "Bash(chmod:*)"
            "Bash(ln:*)"
            # dev tools
            "Bash(gh:*)"
            "Bash(shellcheck:*)"
            "Bash(ruff:*)"
            "Bash(kagi-search:*)"
            "Bash(curl:*)"
            "Bash(tmux:*)"
            "Bash(s:*)"
            # file edits
            "Edit"
            "Write"
            "Read"
          ];
        };

        extraPackages = [
          self.packages.${system}.kagi-search
          pkgs.curl
          pkgs.jq
          pkgs.python3
          pkgs.ripgrep
          pkgs.fd
          pkgs.tmux
          pkgs.tree
        ];

        settings = {
          # Prefer compact output for better context usage
          verbose = true;
        };
      };
    in
    {
      packages.claude = claude.wrapper;
    };
}
