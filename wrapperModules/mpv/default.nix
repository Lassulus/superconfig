{
  self,
  lib,
  ...
}:
{
  perSystem =
    { pkgs, ... }:
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
              extraFlags = lib.mkOption {
                type = lib.types.attrsOf lib.types.unspecified; # TODO add list handling
                default = { };
                description = "Extra flags to pass to mpv.";
              };
            };
            config.flags = {
              "--no-config" = { };
              "--input-conf" = config."mpv.input".path;
              "--include" = config."mpv.conf".path;
            }
            // config.extraFlags;
            config.package = lib.mkDefault (
              pkgs.mpv.override {
                scripts = config.scripts;
              }
            );
          };
      });
    };
}
