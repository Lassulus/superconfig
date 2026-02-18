{ self, ... }:
{
  flake.wrapperModules.pi =
    {
      config,
      lib,
      ...
    }:
    let
      pkgs = config.pkgs;

      # Extract npm packages with hashes from settings.packages
      npmPackages = lib.filter (p: builtins.isAttrs p && p ? hash) (config.settings.packages or [ ]);
      fetchPlugin =
        pkg:
        let
          source = pkg.source or pkg;
          name = lib.removePrefix "npm:" source;
        in
        pkgs.runCommand "pi-plugin-${name}"
          {
            nativeBuildInputs = [
              pkgs.nodejs
              pkgs.cacert
            ];
            outputHashMode = "recursive";
            outputHashAlgo = "sha256";
            outputHash = pkg.hash;
            impureEnvVars = [
              "http_proxy"
              "https_proxy"
            ];
            SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
          }
          ''
            export HOME=$TMPDIR
            export npm_config_prefix=$out
            npm install -g ${name}
          '';

      fetchedPlugins = map fetchPlugin npmPackages;

      # Strip hash and null-valued attrs from package entries before writing settings.json
      cleanPackage =
        p: if builtins.isAttrs p then lib.filterAttrs (k: v: k != "hash" && v != null) p else p;

      cleanSettings = config.settings // {
        packages = map cleanPackage (config.settings.packages or [ ]);
      };

      settingsFile = pkgs.writeText "pi-settings.json" (builtins.toJSON cleanSettings);
    in
    {
      _class = "wrapper";

      options = {
        settings = lib.mkOption {
          type = lib.types.submodule {
            freeformType = (pkgs.formats.json { }).type;
            options.packages = lib.mkOption {
              type = lib.types.listOf (
                lib.types.either lib.types.str (
                  lib.types.submodule {
                    freeformType = (pkgs.formats.json { }).type;
                    options.hash = lib.mkOption {
                      type = lib.types.str;
                      description = "Fixed-output hash for fetching this npm package.";
                    };
                    options.source = lib.mkOption {
                      type = lib.types.str;
                      description = "Package source (e.g. npm:package-name).";
                    };
                    options.extensions = lib.mkOption {
                      type = lib.types.nullOr (lib.types.listOf lib.types.str);
                      default = null;
                      description = ''
                        Extension filter patterns following pi's native syntax.
                        When null (default), all extensions from the package are loaded.
                        An empty list explicitly disables all extensions.
                        Patterns use prefixes to control inclusion:
                        - `"!pattern"` — exclude matching extensions
                        - `"+pattern"` — force-include (overrides excludes)
                        - `"-pattern"` — force-exclude (overrides includes)
                        - `"path"` — plain path to include
                      '';
                      example = [
                        "!./extensions/resistance.ts"
                      ];
                    };
                  }
                )
              );
              default = [ ];
              description = "Pi packages list. Object entries may include a `hash` for Nix fetching.";
            };
          };
          default = { };
          description = "Pi settings.json content.";
        };

        pluginOverrides = lib.mkOption {
          type = lib.types.str;
          default = "";
          description = ''
            Shell commands to run after assembling the plugin prefix.
            The variable `$out` points to the mutable copy.
          '';
        };

        pluginPrefix = lib.mkOption {
          type = lib.types.package;
          description = "The final npm prefix with all plugins merged and overrides applied.";
          default = pkgs.runCommand "pi-plugins" { } ''
            mkdir -p $out
            ${lib.concatMapStringsSep "\n" (p: "cp -a --no-preserve=mode ${p}/* $out/") fetchedPlugins}
            ${lib.optionalString (config.pluginOverrides != "") config.pluginOverrides}
          '';
        };
      };

      config.package = lib.mkDefault (
        self.legacyPackages.${pkgs.system}.llm.pi.overrideAttrs (old: {
          postInstall = (old.postInstall or "") + ''
            patch $out/lib/node_modules/@mariozechner/pi-coding-agent/dist/core/settings-manager.js \
              ${./settings-env.patch}
          '';
        })
      );

      config.extraPackages = [ pkgs.nodejs ];

      config.env.npm_config_prefix = "${config.pluginPrefix}";
      config.env.PI_SETTINGS_FILE = "${settingsFile}";

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
