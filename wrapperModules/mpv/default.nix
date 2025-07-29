{
  self,
  lib,
  ...
}:
{
  perSystem =
    { pkgs, self', ... }:
    {
      legacyPackages.wrappers.mpv = self.wrapLib.mkWrapper (wlib: {
        inherit pkgs;
        module =
          { config, ... }:
          {
            options = {
              scripts = lib.mkOption {
                type = lib.types.listOf lib.types.package;
                default = [ ];
                description = "Scripts to add to mpv via override.";
              };
              "mpv.input" = lib.mkOption {
                type = wlib.types.file;
                default.content = "";
              };
              "mpv.conf" = lib.mkOption {
                type = wlib.types.file;
                default.content = ''
                  osd-font-size=20
                '';
              };
            };
            config.flags = {
              "--no-config" = { };
              "--input-conf" = config."mpv.input".path;
              "--include" = config."mpv.conf".path;
              "--ytdl-format" = "best[height<1081]";
              "--script-opts" = "ytdl_hook-ytdl_path=${pkgs.yt-dlp}/bin/yt-dlp";
              "--script-opts-append" = "sponsorblock-local_database=no";
              "--audio-channels" = "2";
              "--script" = config.scripts;
            };
          };
      });
      packages.mpv_test = self'.legacyPackages.wrappers.mpv {
      };
    };
  flake.wrapLib.mkWrapper =
    argsFun: settings:
    let
      args = argsFun wrapperLib;
      pkgs = args.pkgs;
      module = args.module;

      wrapperLib = {
        types = {
          inherit file;
        };
      };
      file = lib.types.submodule (
        { name, config, ... }:
        {
          options = {
            content = lib.mkOption {
              type = lib.types.lines;
              description = ''
                content of file
              '';
            };
            path = lib.mkOption {
              type = lib.types.path;
              description = ''
                the path to the file
              '';
              default = pkgs.writeText name config.content;
            };
          };
        }
      );
      eval = lib.evalModules {
        modules = [
          module
          {
            options = {
              package = lib.mkOption {
                type = lib.types.package;
                default = pkgs.mpv;
                description = "The base mpv package to use.";
              };
              extraPackages = lib.mkOption {
                type = lib.types.listOf lib.types.package;
                default = [ ];
              };
              flags = lib.mkOption {
                type = lib.types.attrsOf lib.types.unspecified; # TODO add list handling
                default = { };
              };
              # scripts = lib.mkOption {
              #   type = lib.types.listOf lib.types.package;
              #   default = [ ];
              #   description = "Scripts to add to mpv via override.";
              # };
              # "mpv.input" = lib.mkOption {
              #   type = file;
              #   default.content = "";
              # };
              # "mpv.conf" = lib.mkOption {
              #   type = file;
              #   default.content = ''
              #     osd-font-size=20
              #   '';
              # };
            };
            config = settings;
          }
        ];
      };
      config = eval.config;
      options = eval.options;
    in
    self.libWithPkgs.${pkgs.system}.makeWrapper config.package {
      runtimeInputs = config.extraPackages;
      flagSeparator = "=";
      flags = config.flags;
      passthru = {
        inherit options config settings;
      };
    };
}
