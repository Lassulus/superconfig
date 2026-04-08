{ self, ... }:
{
  flake.wrapperModules.claude-code =
    {
      config,
      lib,
      ...
    }:
    let
      pkgs = config.pkgs;
      jsonFormat = pkgs.formats.json { };

      # Assemble a single Claude Code plugin directory containing skills,
      # commands, and agents. Claude Code discovers a directory as a plugin
      # when it contains `.claude-plugin/plugin.json`.
      pluginDir =
        pkgs.runCommand "claude-plugin-${config.pluginName}"
          {
            passthru = { inherit (config) pluginManifest; };
          }
          ''
            mkdir -p $out/.claude-plugin
            cp ${jsonFormat.generate "plugin.json" config.pluginManifest} \
               $out/.claude-plugin/plugin.json

            ${lib.optionalString (config.skills != { }) ''
              mkdir -p $out/skills
              ${lib.concatStringsSep "\n" (
                lib.mapAttrsToList (name: src: "ln -s ${src} $out/skills/${name}") config.skills
              )}
            ''}

            ${lib.optionalString (config.commands != { }) ''
              mkdir -p $out/commands
              ${lib.concatStringsSep "\n" (
                lib.mapAttrsToList (name: src: "ln -s ${src} $out/commands/${name}") config.commands
              )}
            ''}

            ${lib.optionalString (config.agents != { }) ''
              mkdir -p $out/agents
              ${lib.concatStringsSep "\n" (
                lib.mapAttrsToList (name: src: "ln -s ${src} $out/agents/${name}") config.agents
              )}
            ''}

            ${lib.optionalString (config.pluginExtraFiles != { }) ''
              ${lib.concatStringsSep "\n" (
                lib.mapAttrsToList (path: src: ''
                  mkdir -p "$out/$(dirname ${path})"
                  ln -s ${src} "$out/${path}"
                '') config.pluginExtraFiles
              )}
            ''}
          '';

      # Compose a settings.json from the typed options + freeform overrides.
      # Order matters: typed options take precedence over freeform `settings`
      # for the keys they own, but freeform can still set anything else.
      mergedSettings = lib.foldl' lib.recursiveUpdate config.settings (
        lib.optional (config.mcpServers != { }) { mcpServers = config.mcpServers; }
        ++ lib.optional (config.hooks != { }) { hooks = config.hooks; }
        ++ lib.optional (config.permissions != { }) { permissions = config.permissions; }
      );

      settingsFile = jsonFormat.generate "claude-settings.json" mergedSettings;

      levenshtein = self.packages.${pkgs.system}.levenshtein-merge;
    in
    {
      _class = "wrapper";

      options = {
        pluginName = lib.mkOption {
          type = lib.types.str;
          default = "superconfig";
          description = "Name of the bundled plugin directory.";
        };

        pluginManifest = lib.mkOption {
          type = jsonFormat.type;
          default = {
            name = config.pluginName;
            version = "0.0.0";
            description = "Nix-managed Claude Code plugin bundle.";
          };
          defaultText = lib.literalExpression ''
            { name = config.pluginName; version = "0.0.0"; description = "..."; }
          '';
          description = "Contents of `.claude-plugin/plugin.json` for the bundled plugin.";
        };

        skills = lib.mkOption {
          type = lib.types.attrsOf lib.types.path;
          default = { };
          example = lib.literalExpression ''
            {
              websearch = ./skills/websearch;
            }
          '';
          description = ''
            Skills to bundle. Each entry is a directory containing `SKILL.md`
            and any helper scripts/resources. Symlinked into
            `<plugin>/skills/<name>` and discovered by Claude Code automatically.
          '';
        };

        commands = lib.mkOption {
          type = lib.types.attrsOf lib.types.path;
          default = { };
          description = ''
            Slash commands. Each entry is a markdown file (or directory)
            symlinked into `<plugin>/commands/<name>`.
          '';
        };

        agents = lib.mkOption {
          type = lib.types.attrsOf lib.types.path;
          default = { };
          description = ''
            Sub-agents. Each entry is a markdown file (or directory) symlinked
            into `<plugin>/agents/<name>`.
          '';
        };

        pluginExtraFiles = lib.mkOption {
          type = lib.types.attrsOf lib.types.path;
          default = { };
          example = lib.literalExpression ''
            {
              "hooks/format.sh" = ./hooks/format.sh;
            }
          '';
          description = ''
            Additional files to drop into the plugin directory. Keys are
            relative paths inside the plugin directory; values are paths to
            symlink in. Use this for hook scripts or anything else not covered
            by the typed options above.
          '';
        };

        mcpServers = lib.mkOption {
          type = jsonFormat.type;
          default = { };
          example = lib.literalExpression ''
            {
              git-mcp = {
                command = "''${pkgs.git-mcp}/bin/git-mcp";
              };
              tmux-mcp = {
                type = "stdio";
                command = "''${pkgs.tmux-mcp}/bin/tmux-mcp";
                args = [ ];
                env = { };
              };
            }
          '';
          description = ''
            MCP servers to register. Merged into `settings.json` under
            `mcpServers`. Each entry follows Claude Code's MCP server schema
            (stdio: `{ command, args, env }`; http/sse: `{ type, url, headers }`).
          '';
        };

        hooks = lib.mkOption {
          type = jsonFormat.type;
          default = { };
          example = lib.literalExpression ''
            {
              PreToolUse = [
                {
                  matcher = "*";
                  hooks = [
                    {
                      type = "command";
                      command = "''${pkgs.my-permission-bridge}/bin/permission-forward";
                    }
                  ];
                }
              ];
            }
          '';
          description = ''
            Hook definitions. Shape matches Claude Code's `settings.json` hooks
            field. Supported events include `PreToolUse`, `PostToolUse`,
            `UserPromptSubmit`, `Stop`, `SessionStart`, `Notification`, and
            `PreCompact`.
          '';
        };

        permissions = lib.mkOption {
          type = jsonFormat.type;
          default = { };
          example = lib.literalExpression ''
            {
              defaultMode = "acceptEdits";
              allow = [
                "Bash(nix build:*)"
                "Bash(nix eval:*)"
                "Bash(nix fmt:*)"
                "Bash(git status:*)"
                "Bash(git diff:*)"
              ];
              deny = [ ];
              ask = [ ];
            }
          '';
          description = ''
            Permission rules. Shape matches Claude Code's `settings.json`
            `permissions` field. Use `allow`/`deny`/`ask` pattern lists to
            short-circuit the permission flow before any hook fires.
          '';
        };

        settings = lib.mkOption {
          type = jsonFormat.type;
          default = { };
          description = ''
            Freeform additional `settings.json` content. Merged with the
            typed options above (which take precedence on conflict). Use this
            for anything not covered by a dedicated option.
          '';
        };

        claudeMd = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          description = ''
            Optional `CLAUDE.md` whose lines are fuzzy-merged into
            `$CLAUDE_MD_DIR/CLAUDE.md` (default `~/.claude/CLAUDE.md`) on
            every invocation. Only adds lines, never removes user content.
            Each non-blank managed line is skipped when a line within
            `claudeMdMergeThreshold` (Levenshtein ratio) already exists in
            the target file.
          '';
        };

        claudeMdMergeThreshold = lib.mkOption {
          type = lib.types.float;
          default = 0.15;
          description = ''
            Levenshtein distance ratio (distance / max-length) below which
            two normalized lines are considered the same during
            `claudeMd` merging. 0.0 requires exact match; higher values
            tolerate more typos. Default 0.15 allows roughly one typo per
            seven characters.
          '';
        };

        pluginDir = lib.mkOption {
          type = lib.types.package;
          readOnly = true;
          default = pluginDir;
          defaultText = "<assembled plugin directory>";
          description = "The assembled plugin directory passed via `--plugin-dir`.";
        };

        settingsFile = lib.mkOption {
          type = lib.types.package;
          readOnly = true;
          default = settingsFile;
          defaultText = "<assembled settings.json>";
          description = "The assembled settings.json passed via `--settings`.";
        };
      };

      config.package = lib.mkDefault (self.lib.halalify pkgs.claude-code);

      # Always inject our plugin dir + settings file into every invocation.
      # `--plugin-dir` is repeatable so users can still pass more on the CLI.
      config.flags."--plugin-dir" = {
        value = [ "${pluginDir}" ];
        order = 100;
      };
      config.flags."--settings" = {
        value = "${settingsFile}";
        order = 101;
      };

      config.preHook = lib.optionalString (config.claudeMd != null) ''
        CLAUDE_MD_DIR="''${CLAUDE_MD_DIR:-$HOME/.claude}"
        mkdir -p "$CLAUDE_MD_DIR"
        touch "$CLAUDE_MD_DIR/CLAUDE.md"
        ${levenshtein}/bin/levenshtein-merge merge \
          ${config.claudeMd} \
          "$CLAUDE_MD_DIR/CLAUDE.md" \
          ${toString config.claudeMdMergeThreshold} \
          || echo "levenshtein merge failed; leaving CLAUDE.md untouched" >&2
      '';

      config.meta.maintainers = [
        {
          name = "lassulus";
          github = "lassulus";
          githubId = 621375;
        }
      ];
      config.meta.platforms = lib.platforms.all;
    };
}
