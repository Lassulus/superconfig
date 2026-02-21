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

      # Fetch an npm tarball and unpack it into lib/node_modules/<name>
      fetchPlugin =
        pkg:
        let
          source = pkg.source or pkg;
          name = lib.removePrefix "npm:" source;
          tarball = pkgs.fetchurl {
            url = "https://registry.npmjs.org/${name}/-/${name}-${pkg.version}.tgz";
            hash = pkg.hash;
          };
          deps = map fetchPlugin (pkg.deps or [ ]);
        in
        pkgs.runCommand "pi-plugin-${name}"
          {
            nativeBuildInputs = [
              pkgs.gnutar
              pkgs.gzip
            ];
          }
          ''
            mkdir -p $out/lib/node_modules/${name}
            tar xzf ${tarball} --strip-components=1 -C $out/lib/node_modules/${name}
            ${lib.concatMapStringsSep "\n" (
              dep:
              "mkdir -p $out/lib/node_modules/${name}/node_modules"
              + "\ncp -a ${dep}/lib/node_modules/* $out/lib/node_modules/${name}/node_modules/"
              + "\ncp -a ${dep}/lib/node_modules/* $out/lib/node_modules/"
            ) deps}
          '';

      fetchedPlugins = map fetchPlugin npmPackages;

      # Strip hash and null-valued attrs from package entries before writing settings.json
      cleanPackage =
        p:
        if builtins.isAttrs p then
          lib.filterAttrs (k: v: k != "hash" && k != "version" && k != "deps" && v != null) p
        else
          p;

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
                    options.version = lib.mkOption {
                      type = lib.types.str;
                      description = "Exact version to pin (e.g. 1.0.3). Ensures reproducible fetching.";
                    };
                    options.deps = lib.mkOption {
                      type = lib.types.listOf (lib.types.attrsOf lib.types.anything);
                      default = [ ];
                      description = "Transitive npm dependencies as {source, version, hash} attrsets.";
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
